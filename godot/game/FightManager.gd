class_name FightManager
extends RefCounted

const PHASE_DODGE   := "dodge"
const PHASE_COUNTER := "counter"

var boss_data:      Dictionary
var beat_clock:     BeatClock
var audio:          AudioManager
var arena:          Rect2
var player:         Player
var boss:           BossController
var pool:           BulletPool
var pattern_engine: PatternEngine
var counter:        CounterWindow
var aux:            Array = []

var phase:             String  = PHASE_DODGE
var fired:             Array   = []   # fired event objects
var timeline:          Array   = []
var outcome:           String  = ""   # "victory" | "defeat" | ""
var defeat_reason:     String  = ""
var feedback           = null  # {text, color}
var feedback_timer:    float   = 0.0
var recent_hit         = null
var bullet_damage:     float   = 1.0  # always 1 -- difficulty is set by player HP via Difficulty

# Multi-phase
var _phases:            Array   = []
var _music_buffers:     Dictionary = {}
var _current_phase_idx: int    = 0
var current_phase:      Dictionary = {}
var _phase_transitioning: bool  = false
var _phase_trans_timer: float   = 0.0

# Visual state
var use_inversion:    bool   = false
var floor_state:      String = "white"
var floor_flash_timer: float  = 0.0
var red_cracks:       bool   = false
var full_red_floor:   bool   = false
var boss_color_mode:  String = "color"
var fall_on_death:    bool   = false

# Music tracking
var _song_end_time:   float = -1.0
var _song_start_time: float = -1.0
var _song_duration:   float = 0.0
var _music_playing:   bool  = false

var active_walls:     Dictionary = {}  # line_id -> expire_time (seconds)
var requires_perfect: bool       = false
var perfect_broken:   bool       = false  # true once a hit or miss breaks combo on a requires_perfect fight
var worst_efficiency: float      = 0.0    # monotonic high-water-mark of hp_remaining / max_remaining_damage

var _beat_unsub: Callable

func _init(p_boss_data: Dictionary, p_pattern_lib: Dictionary,
           p_beat_clock: BeatClock, p_audio: AudioManager, p_arena: Rect2,
           music_buffer = null, music_buffers = null) -> void:
	boss_data   = p_boss_data
	beat_clock  = p_beat_clock
	audio       = p_audio
	arena       = p_arena

	if p_boss_data.has("phases") and p_boss_data.phases is Array and p_boss_data.phases.size() > 0:
		_phases = p_boss_data.phases
	else:
		_phases = [{
			"displayPhase": p_boss_data.get("displayPhase", null),
			"music":        p_boss_data.get("music", ""),
			"bpm":          p_boss_data.get("bpm", 120),
			"musicVolume":  p_boss_data.get("musicVolume", 0.85),
			"musicOffset":  p_boss_data.get("musicOffset", 0),
			"useInversion": p_boss_data.get("useInversion", false),
			"startFloor":   p_boss_data.get("startFloor", "white"),
			"redCracks":    false,
			"fullRedFloor": false,
			"bossColorMode": "inversion" if p_boss_data.get("useInversion", false) else "color",
			"fallOnDeath":  false,
			"hp":           p_boss_data.get("maxHP", 1000),
			"bulletDamage": p_boss_data.get("bulletDamage", 8),
			"timeline":     p_boss_data.get("timeline", []),
		}]

	if music_buffers != null:
		_music_buffers = music_buffers
	elif music_buffer != null:
		_music_buffers = {0: music_buffer}

	requires_perfect = bool(boss_data.get("requiresPerfect", false))
	player        = Player.new(arena)
	boss          = BossController.new(p_boss_data, arena)
	pool          = BulletPool.new(1500)
	pattern_engine = PatternEngine.new(pool, p_pattern_lib)
	counter       = CounterWindow.new(beat_clock)

	boss.on_phase_change  = Callable(self, "_on_phase_change")
	counter.on_hit        = Callable(self, "_apply_damage")
	counter.on_close      = func(): phase = PHASE_DODGE

	_beat_unsub = beat_clock.on(Callable(self, "_on_beat"))
	_apply_phase_config(0)

# ─── Phase machinery ──────────────────────────────────────────────────────────

func _apply_phase_config(idx: int) -> void:
	var ph: Dictionary = _phases[idx]
	_current_phase_idx = idx
	current_phase      = ph

	boss.set_phase_hp(float(ph.get("hp", 1000)))
	var raw_tl: Array = ph.get("timeline", [])
	timeline = raw_tl.duplicate()
	timeline.sort_custom(func(a, b): return int(a.get("beat",0)) < int(b.get("beat",0)))
	fired.clear()

	beat_clock.set_bpm(float(ph.get("bpm", 120)))

	use_inversion  = bool(ph.get("useInversion",  false))
	floor_state    = ph.get("startFloor",  floor_state if floor_state != "" else "white")
	red_cracks     = bool(ph.get("redCracks",    false))
	full_red_floor = bool(ph.get("fullRedFloor", false))
	boss_color_mode = ph.get("bossColorMode", "color")
	fall_on_death  = bool(ph.get("fallOnDeath",  false))
	floor_flash_timer = 0.0
	bullet_damage  = 1.0  # boss data ignored -- every bullet is 1 dmg by design

	counter.combo  = 0
	counter.zone   = null
	counter.active = false
	active_walls.clear()
	phase = PHASE_DODGE

func _start_phase_music(idx: int) -> void:
	var ph: Dictionary = _phases[idx]
	var buffer = _music_buffers.get(idx, null)
	if buffer != null:
		beat_clock.start()
		var offset := float(ph.get("musicOffset", 0))
		var vol    := float(ph.get("musicVolume",  0.85))
		audio.play_music(buffer, offset, vol)
		_music_playing   = true
		_song_start_time = beat_clock.get_current_time()
		_song_duration   = max(0.0, float(buffer.get_length()) - offset)
		_song_end_time   = _song_start_time + _song_duration
	else:
		beat_clock.start()
		_song_end_time   = -1.0
		_song_start_time = -1.0
		_song_duration   = 0.0
		_music_playing   = false

func _begin_phase_transition() -> void:
	_phase_transitioning = true
	_phase_trans_timer   = 1.4
	pool.clear()
	aux.clear()
	boss.flash_timer = 1.4
	if _music_playing:
		audio.fade_out_music(0.6)
		_music_playing = false
	counter.combo   = 0
	counter.active  = false
	counter.zone    = null
	active_walls.clear()
	phase = PHASE_DODGE
	_show_feedback("PHASE " + str(_current_phase_idx + 2), "#ff3a3a", 1.6)

func _update_phase_transition(dt: float) -> void:
	_phase_trans_timer -= dt
	if _phase_trans_timer <= 0.0:
		_phase_transitioning = false
		var next := _current_phase_idx + 1
		_apply_phase_config(next)
		_start_phase_music(next)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func start() -> void:
	perfect_broken   = false
	worst_efficiency = 0.0
	_start_phase_music(0)

func destroy() -> void:
	if _beat_unsub.is_valid():
		_beat_unsub.call()
	if _music_playing:
		audio.fade_out_music(0.5)
		_music_playing = false

func get_song_time_remaining() -> float:
	if _song_end_time < 0.0:
		return -1.0
	var elapsed := beat_clock.get_current_time()
	return maxf(0.0, _song_end_time - elapsed)

func get_song_progress() -> float:
	if _song_end_time < 0.0 or _song_duration <= 0.0:
		return 0.0
	var elapsed := beat_clock.get_current_time()
	return clampf((elapsed - _song_start_time) / _song_duration, 0.0, 1.0)

func is_final_phase() -> bool:
	return _current_phase_idx >= _phases.size() - 1

func get_max_remaining_damage() -> float:
	# Simulates perfect play from the player's CURRENT combo state.
	# Counts the in-progress counter's unhit prompts (so the value doesn't
	# spike artificially at the moment a counter event fires) plus every
	# prompt in every unfired counter event in the current/future phases.
	var base_dmg: float = float(boss_data.get("counterBaseDamage", 40))
	var combo: int = counter.combo
	var total: float = 0.0

	if counter.active:
		for p in counter.prompts:
			if not p.hit:
				combo += 1
				var mult: float = 1.0 + minf(1.0, float(combo) / 16.0)
				total += base_dmg * mult

	for idx in range(_current_phase_idx, _phases.size()):
		var ph: Dictionary = _phases[idx]
		var tl: Array = ph.get("timeline", [])
		for evt in tl:
			if evt.get("type", "") != "counterattack_window":
				continue
			if idx == _current_phase_idx and fired.has(evt):
				continue
			var dur: int = int(evt.get("duration_beats", 8))
			for _i in range(dur):
				combo += 1
				var mult: float = 1.0 + minf(1.0, float(combo) / 16.0)
				total += base_dmg * mult
	return total

# ─── Beat event handling ──────────────────────────────────────────────────────

func _on_beat(beat: int) -> void:
	if _phase_transitioning:
		return
	for evt in timeline:
		if int(evt.get("beat", 0)) > beat:
			break
		if fired.has(evt):
			continue
		fired.append(evt)
		_handle_event(evt, beat)

func _handle_event(evt: Dictionary, beat: int) -> void:
	var t: String = evt.get("type", "")
	if t == "pattern":
		if phase == PHASE_COUNTER:
			return
		var pattern_data = evt.get("patternData", null)
		var pattern_id   = evt.get("id", "")
		var to_fire      = pattern_data if pattern_data != null else pattern_id
		pattern_engine.fire(to_fire, {
			"bossX":    boss.x,
			"bossY":    boss.get_display_y(),
			"bossRef":  boss,
			"targetX":  player.x,
			"targetY":  player.y,
			"arena":    {"x": arena.position.x, "y": arena.position.y, "w": arena.size.x, "h": arena.size.y},
			"beatIndex": beat,
			"beatInterval": beat_clock.beat_interval,
			"spawnAux": Callable(self, "_spawn_aux"),
			"activeWalls": active_walls,
		})
	elif t == "counterattack_window":
		phase = PHASE_COUNTER
		pool.clear()
		active_walls.clear()
		var lead_beats := int(evt.get("lead_beats", 2))
		var zone_data   = evt.get("zone", null)
		var zone        = _resolve_zone(zone_data) if zone_data != null else null
		counter.open(int(evt.get("beat", 0)) + lead_beats, int(evt.get("duration_beats", 8)), zone)
	elif t == "grid_wall":
		var line_id: String = evt.get("line", "")
		var dur_beats: int = int(evt.get("duration_beats", 8))
		var expire: float = beat_clock.get_current_time() + float(dur_beats) * beat_clock.beat_interval
		active_walls[line_id] = expire
		var pair_line: String = evt.get("pair_line", "")
		if pair_line != "" and boss.get_hp_ratio() <= 0.5:
			active_walls[pair_line] = expire
	elif t == "line_storm":
		var dur_beats: int = int(evt.get("duration_beats", 4))
		var expire: float = beat_clock.get_current_time() + float(dur_beats) * beat_clock.beat_interval
		var lines: Array = evt.get("lines", [])
		if lines.is_empty():
			lines = ["h0","h1","h2","h3","h4","h5","v0","v1","v2","v3"]
		for line_id in lines:
			active_walls[line_id] = expire
	elif t == "floor_invert":
		floor_state       = evt.get("to", "black" if floor_state == "white" else "white")
		floor_flash_timer = 0.45

func _resolve_zone(zone_data: Dictionary):
	var r: float = float(zone_data.get("radius", 70))
	var anchors: Dictionary = {
		"center":      [0.5, 0.5],  "top":         [0.5, 0.22],
		"bottom":      [0.5, 0.78], "left":        [0.22, 0.5],
		"right":       [0.78, 0.5], "topLeft":     [0.22, 0.25],
		"topRight":    [0.78, 0.25],"bottomLeft":  [0.22, 0.75],
		"bottomRight": [0.78, 0.75]
	}
	if zone_data.get("type", "") == "spotlight":
		var raw_wps: Array = zone_data.get("waypoints", [])
		var wps: Array = []
		for wp_anchor in raw_wps:
			var a_: Array = anchors.get(str(wp_anchor), [0.5, 0.5])
			wps.append({
				"x": arena.position.x + arena.size.x * float(a_[0]),
				"y": arena.position.y + arena.size.y * float(a_[1])
			})
		var sx: float = 0.0
		var sy: float = 0.0
		if wps.size() > 0:
			sx = float(wps[0].get("x", 0.0))
			sy = float(wps[0].get("y", 0.0))
		return {"type": "spotlight", "x": sx, "y": sy, "radius": r,
		        "speed": float(zone_data.get("speed", 150.0)), "waypoints": wps}
	if zone_data.has("anchor"):
		var a_: Array = anchors.get(zone_data.anchor, [0.5, 0.5])
		return {"x": arena.position.x + arena.size.x * float(a_[0]),
		        "y": arena.position.y + arena.size.y * float(a_[1]),
		        "radius": r}
	return {"x": arena.position.x + arena.size.x * float(zone_data.get("x", 0.5)),
	        "y": arena.position.y + arena.size.y * float(zone_data.get("y", 0.5)),
	        "radius": r}

func _on_phase_change(_n: int) -> void:
	pass

func _apply_damage(grade: Dictionary, dmg: float) -> void:
	if dmg > 0.0:
		boss.take_damage(dmg)
		recent_hit = {"grade": grade, "t": 0.0}

func _show_feedback(text: String, color: String, duration: float) -> void:
	feedback       = {"text": text, "color": color}
	feedback_timer = duration

func _spawn_aux(a) -> void:
	aux.append(a)

# ─── Input ────────────────────────────────────────────────────────────────────

func handle_attack_press() -> void:
	if phase != PHASE_COUNTER or _phase_transitioning:
		return
	var base_dmg := float(boss_data.get("counterBaseDamage", 40))
	counter.register_press(base_dmg, player.x, player.y)

func debug_kill_phase() -> void:
	if _phase_transitioning or outcome != "" or boss.dying:
		return
	boss.hp         = 0.0
	boss.flash_timer = 0.4

# ─── Update ───────────────────────────────────────────────────────────────────

func update(dt: float, input: InputManager) -> void:
	if outcome != "":
		return

	if _phase_transitioning:
		_update_phase_transition(dt)
		player.update(dt, input)
		boss.update(dt, beat_clock.get_beat_position())
		counter.update(dt)
		if feedback_timer > 0.0: feedback_timer -= dt
		if floor_flash_timer > 0.0: floor_flash_timer -= dt
		return

	var prev_px: float = player.x
	var prev_py: float = player.y
	player.update(dt, input)

	var now: float = beat_clock.get_current_time()
	var expired: Array = []
	for wall_id in active_walls:
		if now >= float(active_walls[wall_id]):
			expired.append(wall_id)
	for wall_id in expired:
		active_walls.erase(wall_id)

	for wall_id in active_walls:
		if wall_id.begins_with("h"):
			var idx: int = int(wall_id.substr(1))
			var wy: float = arena.position.y + arena.size.y * float(idx + 1) / 7.0
			var was_above: bool = prev_py < wy
			if (player.y < wy) != was_above:
				player.y = wy - player.hitbox_radius if was_above else wy + player.hitbox_radius
		elif wall_id.begins_with("v"):
			var idx: int = int(wall_id.substr(1))
			var wx: float = arena.position.x + arena.size.x * float(idx + 1) / 5.0
			var was_left: bool = prev_px < wx
			if (player.x < wx) != was_left:
				player.x = wx - player.hitbox_radius if was_left else wx + player.hitbox_radius

	boss.update(dt, beat_clock.get_beat_position())
	pool.update(dt, arena, player.x, player.y)
	counter.update(dt)
	if requires_perfect and counter.had_miss:
		perfect_broken = true
	pattern_engine.record_player_trail(player, beat_clock.get_song_time())

	# SlowZone updates every frame (persistent field effect, runs during
	# counter too); other aux only tick during dodge phase.
	for a in aux:
		var persistent: bool = a is AuxAttacks.SlowZone
		if persistent or phase == PHASE_DODGE:
			a.update(dt, player, pool)
	if aux.size() > 0:
		aux = aux.filter(func(a): return not a.dead)

	if feedback_timer > 0.0: feedback_timer -= dt
	if floor_flash_timer > 0.0: floor_flash_timer -= dt

	if phase == PHASE_DODGE:
		var floor_for_collide := floor_state if use_inversion else ""
		var hit = pool.collide_with(player.x, player.y, player.alive, player.iframes,
		                            player.hitbox_radius, floor_for_collide)
		if hit != null:
			var dmg := bullet_damage
			if player.take_damage(dmg):
				counter.combo = 0
				hit.active = false
				var idx := pool.active.find(hit)
				if idx >= 0:
					pool.active.remove_at(idx)
				if requires_perfect:
					perfect_broken = true

	if not player.alive:
		outcome       = "defeat"
		defeat_reason = "death"
		return

	if _song_end_time >= 0.0 and not requires_perfect and boss.hp > 0.0:
		var mx: float = get_max_remaining_damage()
		if mx > 0.0:
			var eff: float = boss.hp / mx
			if eff > worst_efficiency:
				worst_efficiency = eff

	if boss.is_defeated():
		if not is_final_phase():
			_begin_phase_transition()
			return
		if fall_on_death:
			if not boss.dying:
				boss.begin_fall()
			if boss.death_done:
				outcome = "victory"
		else:
			outcome = "victory"
		return

	var remaining := get_song_time_remaining()
	if remaining >= 0.0 and remaining <= 0.01:
		if is_final_phase():
			outcome       = "defeat"
			defeat_reason = "time_up"
		else:
			_begin_phase_transition()

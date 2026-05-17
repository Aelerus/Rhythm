class_name FightGame
extends RefCounted

const CANVAS_W := 1280.0
const CANVAS_H := 720.0
const ARENA    := Rect2(160, 60, 960, 600)

var _fight:       FightManager
var _bg_r:        CanvasBackground
var _boss_r:      BossRenderer
var _bullet_r:    BulletRenderer
var _player_r:    PlayerRenderer
var _hud_r:       HUDRenderer
var _audio:       AudioManager
var _beat_clock:  BeatClock

var _on_victory:  Callable
var _on_defeat:   Callable
var _on_restart:  Callable
var _on_quit:     Callable

var _paused:          bool  = false
var _pause_cursor:    int   = 0
var _pause_btn_rects: Array = []
var _settings_open:   bool  = false

const INTRO_TOTAL     := 3.0
const INTRO_WALK_DUR  := 1.2
const INTRO_DOORS_DUR := 1.2

var _intro_active:        bool  = true
var _intro_timer:         float = INTRO_TOTAL
var _doors_progress:      float = 0.0
var _intro_player_placed: bool  = false
var _intro_target_x:      float = 0.0
var _intro_target_y:      float = 0.0
var _intro_entry_y:       float = 0.0

var _initial_hp:       float = 100.0
var _total_prompts:    int   = 0
var _score_snap:       float = 0.0
var _max_combo_snap:   int   = 0
var _perfect_snap:     int   = 0
var _total_hits_snap:  int   = 0
var _uses_grid_walls:  bool  = false

func _init(boss_data: Dictionary, pattern_lib: Dictionary,
		   audio: AudioManager, beat_clock: BeatClock,
		   music_buf, on_victory: Callable, on_defeat: Callable,
		   on_restart: Callable, on_quit: Callable) -> void:
	_audio      = audio
	_beat_clock = beat_clock
	_on_victory = on_victory
	_on_defeat  = on_defeat
	_on_restart = on_restart
	_on_quit    = on_quit

	_fight    = FightManager.new(boss_data, pattern_lib, beat_clock, audio, ARENA, null, null)
	# Supply music buffers
	if music_buf is Dictionary:
		_fight._music_buffers = music_buf
	elif music_buf != null:
		_fight._music_buffers = {0: music_buf}

	_bg_r     = CanvasBackground.new()
	_boss_r   = BossRenderer.new()
	_bullet_r = BulletRenderer.new()
	_player_r = PlayerRenderer.new()
	_hud_r    = HUDRenderer.new()

	_initial_hp = _fight.player.max_hp
	_total_prompts = 0
	_uses_grid_walls = false
	var all_phases: Array = _fight._phases
	for ph in all_phases:
		for evt in ph.get("timeline", []):
			var et: String = evt.get("type", "")
			if et == "counterattack_window":
				_total_prompts += int(evt.get("duration_beats", 8))
			elif et == "grid_wall":
				_uses_grid_walls = true

func enter() -> void:
	pass

func exit() -> void:
	_fight.destroy()

func update(dt: float, input: InputManager) -> void:
	if _intro_active:
		if not _intro_player_placed:
			_intro_target_x = _fight.player.x
			_intro_target_y = _fight.player.y
			_intro_entry_y  = ARENA.position.y + ARENA.size.y + 50.0
			_fight.player.y = _intro_entry_y
			_fight.player.angle = 0.0
			_intro_player_placed = true

		_intro_timer -= dt
		var elapsed: float = INTRO_TOTAL - _intro_timer

		if elapsed < INTRO_WALK_DUR:
			var t:     float = clampf(elapsed / INTRO_WALK_DUR, 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - t, 2.0)
			_fight.player.y = lerpf(_intro_entry_y, _intro_target_y, eased)
			_doors_progress = 0.0
		else:
			_fight.player.y = _intro_target_y
			var de: float = elapsed - INTRO_WALK_DUR
			_doors_progress = clampf(de / INTRO_DOORS_DUR, 0.0, 1.0)

		if _intro_timer <= 0.0 or input.consume_press_accept():
			_intro_active   = false
			_intro_timer    = 0.0
			_doors_progress = 1.0
			_fight.player.x = _intro_target_x
			_fight.player.y = _intro_target_y
			_fight.start()
		return

	if _paused:
		input.consume_press([KEY_SPACE, KEY_Z])
		if _settings_open:
			_update_settings(input)
			return
		if input.consume_press_back():
			_resume()
			return
		if input.consume_press_down():
			_pause_cursor = (_pause_cursor + 1) % 4
		if input.consume_press_up():
			_pause_cursor = (_pause_cursor - 1 + 4) % 4
		if input.consume_press([KEY_ENTER, KEY_KP_ENTER, InputManager.ACTION_ACCEPT]):
			_activate_pause_btn(_pause_cursor)

		# Mouse over buttons
		var mp := input.mouse_pos()
		for i in range(_pause_btn_rects.size()):
			if _pause_btn_rects[i].has_point(mp):
				_pause_cursor = i
		if input.mouse_clicked():
			var mp2 := input.mouse_pos()
			for i in range(_pause_btn_rects.size()):
				if _pause_btn_rects[i].has_point(mp2):
					_activate_pause_btn(i)
		return

	if input.consume_press_pause():
		_pause()
		return

	# Attack / debug
	if input.was_pressed_accept() or input.was_pressed(KEY_Z):
		_fight.handle_attack_press()
	if input.was_pressed(KEY_K):
		_fight.debug_kill_phase()

	_fight.beat_clock.tick()
	_fight.update(dt, input)

	_score_snap      = _fight.counter.score
	_max_combo_snap  = _fight.counter.max_combo
	_perfect_snap    = _fight.counter.perfect_hits
	_total_hits_snap = _fight.counter.total_hits

	if _fight.outcome == "victory":
		var song_prog: float = 0.0 if _fight.boss_data.get("requiresPerfect", false) else _fight.get_song_progress()
		_on_victory.call({
			"bossName":     _fight.boss_data.get("name", "???"),
			"bossId":       _fight.boss_data.get("id",   ""),
			"score":        _score_snap,
			"perfectHits":  _perfect_snap,
			"totalPrompts": _total_prompts,
			"maxCombo":     _max_combo_snap,
			"damageTaken":  _initial_hp - _fight.player.hp,
			"grade":        _compute_grade(song_prog),
		})
	elif _fight.outcome == "defeat":
		_on_defeat.call({
			"bossName": _fight.boss_data.get("name", "???"),
			"reason":   _fight.defeat_reason,
		})

func draw(canvas: Node2D) -> void:
	var beat_pos:   float = _fight.beat_clock.get_beat_position()
	var beat_pulse: float = max(0.0, 1.0 - fmod(beat_pos, 1.0)) * 0.85

	var inversion = null
	if _fight.use_inversion:
		inversion = {"floor": _fight.floor_state, "flash": _fight.floor_flash_timer}
	var red_cracks = null
	if _fight.red_cracks:
		red_cracks = {"progress": 1.0 - _fight.boss.get_hp_ratio()}
	var full_red: bool = _fight.full_red_floor

	_bg_r.draw_background(canvas, beat_pulse, _fight.boss.color, inversion, ARENA, red_cracks, full_red)
	_bg_r.draw_arena_frame(canvas, ARENA, beat_pulse, _fight.boss.color, inversion, red_cracks, full_red)
	_bg_r.draw_arena_doors(canvas, ARENA, _doors_progress, _fight.boss.color, beat_pulse)
	if _uses_grid_walls:
		_bg_r.draw_grid_walls(canvas, ARENA, _fight.active_walls, beat_pulse)
	_boss_r.draw(canvas, _fight.boss, beat_pulse, inversion, _fight.boss_color_mode, _fight.overdrive_active)

	for a in _fight.aux:
		if a is AuxAttacks.TetherAttack:
			a.render(canvas, _fight.player)
		elif a is AuxAttacks.GravityWell:
			a.render(canvas)
		elif a is AuxAttacks.RealityTear:
			a.render(canvas)
		elif a is AuxAttacks.SlowZone:
			a.render(canvas)

	_bullet_r.draw(canvas, _fight.pool, inversion)
	_player_r.draw(canvas, _fight.player, _fight.player.iframes > 0.0 and _fight.beat_clock.running, inversion)

	var font := ThemeDB.fallback_font
	_hud_r.draw(canvas, font, _fight, beat_pulse, beat_pos)

	if _paused:
		if _settings_open:
			_draw_settings(canvas, font)
		else:
			_draw_pause(canvas, font)

	if _intro_active:
		_draw_intro(canvas, font)

func _pause() -> void:
	if _paused or _fight.outcome != "":
		return
	_paused       = true
	_pause_cursor = 0

func _resume() -> void:
	_paused = false

func _activate_pause_btn(i: int) -> void:
	match i:
		0: _resume()
		1: _settings_open = true
		2: _on_restart.call()
		3: _on_quit.call()

func _draw_pause(canvas: Node2D, font: Font) -> void:
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.039, 0.043, 0.086, 0.78))
	var accent := Color(_fight.boss.color) if _fight.boss.color != "" else Color("#5dd6ff")
	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 140.0 + 36.0),
					   "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 64, Color.WHITE)

	var labels := ["RESUME", "SETTINGS", "RESTART", "QUIT TO MENU"]
	var btn_w  := 320.0;  var btn_h := 56.0;  var gap := 18.0
	var total_h := float(labels.size()) * btn_h + float(labels.size() - 1) * gap
	var start_y := CANVAS_H / 2.0 - total_h / 2.0 + 10.0
	_pause_btn_rects.clear()

	for i in range(labels.size()):
		var bx := (CANVAS_W - btn_w) / 2.0
		var by := start_y + float(i) * (btn_h + gap)
		_pause_btn_rects.append(Rect2(bx, by, btn_w, btn_h))
		var focused := i == _pause_cursor
		canvas.draw_rect(Rect2(bx, by, btn_w, btn_h), Color("#1f1640") if focused else Color("#13111f"))
		canvas.draw_rect(Rect2(bx, by, btn_w, btn_h), accent if focused else Color("#444466"),
						 false, 3.0 if focused else 1.0)
		var tc := accent if focused else Color("#aaaadd")
		canvas.draw_string(font, Vector2(bx, by + btn_h / 2.0 + 8.0),
						   labels[i], HORIZONTAL_ALIGNMENT_CENTER, btn_w, 22, tc)

	canvas.draw_string(font, Vector2(0.0, CANVAS_H - 50.0),
					   "↑ ↓  Choose      ENTER  Confirm      ESC  Resume",
					   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14, Color("#aaaadd"))

func _update_settings(input: InputManager) -> void:
	if input.consume_press_back() or input.consume_press_accept():
		_settings_open = false

func _draw_settings(canvas: Node2D, font: Font) -> void:
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.85))
	canvas.draw_string(font, Vector2(0.0, 200.0), "SETTINGS",
					   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 48, Color.WHITE)
	canvas.draw_string(font, Vector2(0.0, 280.0), "Press ESC to close",
					   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 18, Color("#aaaadd"))

func _draw_intro(canvas: Node2D, font: Font) -> void:
	var fade_in  := 0.4
	var hold     := 1.4
	var fade_out := 1.2
	var total    := fade_in + hold + fade_out
	var elapsed  := total - _intro_timer
	var alpha: float
	if elapsed < fade_in:
		alpha = elapsed / fade_in
	elif elapsed < fade_in + hold:
		alpha = 1.0
	else:
		alpha = 1.0 - (elapsed - fade_in - hold) / fade_out
	alpha = clampf(alpha, 0.0, 1.0)

	var boss_name := str(_fight.boss_data.get("name", "")).to_upper()
	var boss_col  := Color(_fight.boss.color) if _fight.boss.color != "" else Color("#5dd6ff")
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, alpha * 0.65))
	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 + 30.0),
					   boss_name, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 80,
					   Color(boss_col.r, boss_col.g, boss_col.b, alpha))

func _compute_grade(song_progress: float) -> String:
	if song_progress <= 0.84:
		return "S"
	if song_progress <= 0.89:
		return "A"
	if song_progress <= 0.94:
		return "B"
	return "C"

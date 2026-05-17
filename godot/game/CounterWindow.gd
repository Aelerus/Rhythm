class_name CounterWindow
extends RefCounted

const GRADES := {
	"PERFECT": {"name": "PERFECT", "multiplier": 1.0, "points": 100, "color": "#ffe25d"},
	"GOOD":    {"name": "GOOD",    "multiplier": 0.6, "points": 60,  "color": "#5dffae"},
	"MISS":    {"name": "MISS",    "multiplier": 0.0, "points": 0,   "color": "#ff5d5d"},
}
const PERFECT_WINDOW := 0.05
const GOOD_WINDOW    := 0.12

var clock: BeatClock
var active: bool = false
var start_beat: int = 0
var duration_beats: int = 8
var prompts: Array = []
var combo: int = 0
var max_combo: int = 0
var flash_grade = null
var flash_timer: float = 0.0
var total_damage: float = 0.0
var score: float = 0.0
var total_hits: int = 0
var perfect_hits: int = 0
var zone = null  # Dictionary{x,y,radius} or spotlight dict
var out_of_range_flash: float = 0.0
var had_miss: bool = false

var _spotlight_wps: Array = []
var _spotlight_speed: float = 0.0
var _spotlight_wp_idx: int = 0

var on_hit: Callable
var on_close: Callable

func _init(p_clock: BeatClock) -> void:
	clock = p_clock

func open(p_start_beat: int, p_duration: int, p_zone = null) -> void:
	active         = true
	start_beat     = p_start_beat
	duration_beats = p_duration
	zone               = p_zone
	out_of_range_flash = 0.0
	had_miss           = false
	_spotlight_wps.clear()
	_spotlight_wp_idx  = 0
	_spotlight_speed   = 0.0
	if zone != null and zone.get("type", "") == "spotlight":
		_spotlight_wps   = zone.get("waypoints", [])
		_spotlight_speed = float(zone.get("speed", 150.0))
		_spotlight_wp_idx = 1 if _spotlight_wps.size() > 1 else 0
	prompts.clear()
	for i in range(p_duration):
		var beat := p_start_beat + i
		prompts.append({
			"beat": beat,
			"time": clock.beat_time(beat),
			"hit":  false,
			"grade": null,
		})

func is_in_zone(player_x: float, player_y: float) -> bool:
	if zone == null:
		return true
	var dx := player_x - float(zone.get("x", 0))
	var dy := player_y - float(zone.get("y", 0))
	var r   := float(zone.get("radius", 70))
	return dx*dx + dy*dy <= r*r

func close() -> void:
	if not active:
		return
	active = false
	if on_close.is_valid():
		on_close.call()

func update(dt: float) -> void:
	if flash_timer > 0.0:         flash_timer        -= dt
	if out_of_range_flash > 0.0:  out_of_range_flash -= dt
	if not active:
		return
	if zone != null and zone.get("type", "") == "spotlight" and _spotlight_wps.size() > 1:
		if _spotlight_wp_idx >= _spotlight_wps.size():
			_spotlight_wp_idx = 0
		var target: Dictionary = _spotlight_wps[_spotlight_wp_idx]
		var tx: float = float(target.get("x", 0.0))
		var ty: float = float(target.get("y", 0.0))
		var cx: float = float(zone.get("x", 0.0))
		var cy: float = float(zone.get("y", 0.0))
		var dx: float = tx - cx
		var dy: float = ty - cy
		var dist: float = sqrt(dx * dx + dy * dy)
		var step: float = _spotlight_speed * dt
		if dist <= step:
			zone["x"] = tx
			zone["y"] = ty
			_spotlight_wp_idx += 1
			if _spotlight_wp_idx >= _spotlight_wps.size():
				_spotlight_wp_idx = 0
		else:
			zone["x"] = cx + dx / dist * step
			zone["y"] = cy + dy / dist * step
	var t := clock.get_current_time()
	for p in prompts:
		if not p.hit and t > float(p.time) + GOOD_WINDOW:
			p.hit     = true
			p.grade   = GRADES.MISS
			combo     = 0
			had_miss  = true
			_flash(GRADES.MISS)
	if prompts.size() > 0:
		var last: Dictionary = prompts[prompts.size() - 1]
		if t > float(last.time) + GOOD_WINDOW + 0.1:
			close()

func register_press(base_damage: float, player_x: float, player_y: float) -> Dictionary:
	if not active:
		return {}
	if zone != null and not is_in_zone(player_x, player_y):
		out_of_range_flash = 0.45
		return {"rejected": "out_of_range"}
	var t   := clock.get_current_time()
	var best = null
	var best_dist := INF
	for p in prompts:
		if p.hit:
			continue
		var d: float = abs(float(p.time) - t)
		if d < best_dist:
			best_dist = d
			best      = p
	if best == null:
		return {}
	if best_dist > GOOD_WINDOW + 0.05:
		return {}

	var grade: Dictionary
	if best_dist <= PERFECT_WINDOW:
		grade = GRADES.PERFECT
	elif best_dist <= GOOD_WINDOW:
		grade = GRADES.GOOD
	else:
		grade = GRADES.MISS

	best.hit   = true
	best.grade = grade

	if grade == GRADES.MISS:
		combo = 0
	elif grade == GRADES.PERFECT:
		combo += 1
		if combo > max_combo:
			max_combo = combo
		total_hits  += 1
		perfect_hits += 1
	else:
		total_hits += 1

	var combo_mult: float = 1.0 + min(1.0, float(combo) / 16.0)
	var damage     := base_damage * float(grade.get("multiplier", 0)) * combo_mult
	total_damage   += damage
	score          += float(grade.get("points", 0)) * combo_mult

	_flash(grade)
	if on_hit.is_valid():
		on_hit.call(grade, damage)
	return {"grade": grade, "damage": damage}

func _flash(grade: Dictionary) -> void:
	flash_grade = grade
	flash_timer = 0.55

func visible_prompts() -> Array:
	if not active:
		return []
	var t := clock.get_current_time()
	var result := []
	for p in prompts:
		result.append({
			"beat":  p.beat,
			"time":  p.time,
			"hit":   p.hit,
			"grade": p.grade,
			"delta": float(p.time) - t,
		})
	return result

class_name BossController
extends RefCounted

var data: Dictionary
var arena: Rect2
var max_hp: float
var hp: float
var x: float
var y: float
var color: String
var flash_timer: float = 0.0
var bob_phase: float = 0.0
var phase: int = 1
var phase_thresholds: Array = [0.75, 0.5, 0.25]
var on_phase_change: Callable

var dying: bool = false
var fall_velocity: float = 0.0
var fall_y: float = 0.0
var fall_alpha: float = 1.0
var death_done: bool = false

func _init(p_data: Dictionary, p_arena: Rect2) -> void:
	data    = p_data
	arena   = p_arena
	max_hp  = float(p_data.get("maxHP", 1000))
	hp      = max_hp
	x       = p_arena.position.x + p_arena.size.x / 2.0
	y       = p_arena.position.y + 110.0
	color   = p_data.get("color", "#ff5dd6")
	phase_thresholds = p_data.get("phaseThresholds", [0.75, 0.5, 0.25])

func set_phase_hp(new_hp: float) -> void:
	max_hp = new_hp
	hp     = new_hp

func begin_fall() -> void:
	if dying:
		return
	dying         = true
	fall_velocity = -40.0

func update(dt: float, beat_position: float) -> void:
	bob_phase = beat_position * TAU
	if flash_timer > 0.0:
		flash_timer -= dt

	if dying and not death_done:
		fall_velocity += 800.0 * dt
		fall_y        += fall_velocity * dt
		if fall_y > 200.0:
			fall_alpha = maxf(0.0, fall_alpha - dt * 0.7)
		if fall_y > 900.0 or fall_alpha <= 0.0:
			death_done = true

func get_display_y() -> float:
	return y + sin(bob_phase) * 6.0 + fall_y

func take_damage(amount: float) -> void:
	if dying:
		return
	hp = maxf(0.0, hp - amount)
	flash_timer = 0.18
	var ratio := hp / max_hp
	var new_phase := 1
	for i in range(phase_thresholds.size()):
		if ratio < float(phase_thresholds[i]):
			new_phase = i + 2
	if new_phase != phase:
		phase = new_phase
		if on_phase_change.is_valid():
			on_phase_change.call(phase)

func get_hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0

func is_defeated() -> bool:
	return hp <= 0.0

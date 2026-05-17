class_name Player
extends RefCounted

var arena: Rect2
var x: float
var y: float
var base_speed: float = 322.0
var focus_speed: float = 149.5
var radius: float = 14.0
var hitbox_radius: float = 4.0
var max_hp: float = Difficulty.player_hp()
var hp: float = Difficulty.player_hp()
var iframes: float = 0.0
var iframe_duration: float = 0.7
var alive: bool = true
var flash_timer: float = 0.0
var shape: String = "arrow"
var color: String = "#e8e8f0"
var angle: float = 0.0
var speed_multiplier: float = 1.0  # external slow/buff (e.g. SlowZone)

func _init(p_arena: Rect2) -> void:
	arena = p_arena
	max_hp = Difficulty.player_hp()
	hp = max_hp
	x = arena.position.x + arena.size.x / 2.0
	y = arena.position.y + arena.size.y * 0.75

func reset() -> void:
	x = arena.position.x + arena.size.x / 2.0
	y = arena.position.y + arena.size.y * 0.75
	hp = max_hp
	iframes = 0.0
	alive = true
	flash_timer = 0.0
	speed_multiplier = 1.0

func update(dt: float, input: InputManager) -> void:
	if not alive:
		return
	var v := input.movement_vector()
	var focus := input.is_focus()
	var speed: float = (focus_speed if focus else base_speed) * speed_multiplier
	x += v.x * speed * dt
	y += v.y * speed * dt
	if v.x != 0.0 or v.y != 0.0:
		angle = atan2(v.y, v.x) + PI / 2.0

	var pad := radius
	x = clampf(x, arena.position.x + pad, arena.position.x + arena.size.x - pad)
	y = clampf(y, arena.position.y + pad, arena.position.y + arena.size.y - pad)

	if iframes > 0.0:
		iframes -= dt
	if flash_timer > 0.0:
		flash_timer -= dt

func take_damage(amount: float) -> bool:
	if not alive or iframes > 0.0:
		return false
	hp -= amount
	iframes = iframe_duration
	flash_timer = 0.2
	if hp <= 0.0:
		hp = 0.0
		alive = false
	return true

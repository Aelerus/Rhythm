class_name InputManager
extends RefCounted

var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _mouse_pos: Vector2 = Vector2.ZERO
var _mouse_clicked: bool = false
var _wheel_delta: int = 0  # +1 per scroll-up tick, -1 per scroll-down tick

func handle_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var kc: int = event.keycode
		if event.pressed and not event.echo:
			_held[kc] = true
			_pressed[kc] = true
		elif not event.pressed:
			_held.erase(kc)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_clicked = true
				_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_wheel_delta += 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_wheel_delta -= 1
	elif event is InputEventMouseMotion:
		_mouse_pos = event.position

func end_frame() -> void:
	_pressed.clear()
	_mouse_clicked = false
	_wheel_delta = 0

func consume_wheel() -> int:
	var d := _wheel_delta
	_wheel_delta = 0
	return d

func is_down(key: int) -> bool:
	return _held.get(key, false)

func is_down_any(keys: Array) -> bool:
	for k in keys:
		if _held.get(k, false):
			return true
	return false

func was_pressed(key: int) -> bool:
	return _pressed.get(key, false)

func consume_press(keys: Array) -> bool:
	for k in keys:
		if _pressed.get(k, false):
			_pressed.erase(k)
			return true
	return false

func is_focus() -> bool:
	return is_down(KEY_SHIFT)

func movement_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if is_down_any([KEY_A, KEY_LEFT]):  x -= 1.0
	if is_down_any([KEY_D, KEY_RIGHT]): x += 1.0
	if is_down_any([KEY_W, KEY_UP]):    y -= 1.0
	if is_down_any([KEY_S, KEY_DOWN]):  y += 1.0
	if x != 0.0 and y != 0.0:
		x *= 0.7071
		y *= 0.7071
	return Vector2(x, y)

func mouse_pos() -> Vector2:
	return _mouse_pos

func mouse_clicked() -> bool:
	return _mouse_clicked

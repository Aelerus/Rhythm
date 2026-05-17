class_name InputManager
extends RefCounted

# Virtual action codes (negative so they never collide with KEY_* keycodes,
# which are all positive). Used for gamepad buttons and stick-derived
# directional presses. Stored in the same _held / _pressed dicts as keys
# so all existing consume_press/is_down/was_pressed plumbing works unchanged.
const ACTION_UP     := -100
const ACTION_DOWN   := -101
const ACTION_LEFT   := -102
const ACTION_RIGHT  := -103
const ACTION_ACCEPT := -104  # A / Cross
const ACTION_BACK   := -105  # B / Circle
const ACTION_PAUSE  := -106  # Start / Options

const STICK_DEADZONE  := 0.55
const REPEAT_INITIAL  := 0.40   # delay before first repeat while stick held
const REPEAT_RATE     := 0.12   # subsequent repeat interval
const MOVE_DEADZONE   := 0.18   # for analog player movement (lower than menu nav)

var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _mouse_pos: Vector2 = Vector2.ZERO
var _mouse_clicked: bool = false
var _wheel_delta: int = 0  # +1 per scroll-up tick, -1 per scroll-down tick

# Stick-held timers (seconds remaining until next repeat for that action).
var _stick_held:    Dictionary = {}   # action code -> float
var _scroll_held:   float      = 0.0  # right stick Y held time for scroll repeat

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
	elif event is InputEventJoypadButton:
		var action: int = _joy_button_to_action(event.button_index)
		if action == 0:
			return
		if event.pressed:
			_held[action] = true
			_pressed[action] = true
		else:
			_held.erase(action)

func _joy_button_to_action(btn: int) -> int:
	match btn:
		JOY_BUTTON_A:           return ACTION_ACCEPT
		JOY_BUTTON_B:           return ACTION_BACK
		JOY_BUTTON_START:       return ACTION_PAUSE
		JOY_BUTTON_DPAD_UP:     return ACTION_UP
		JOY_BUTTON_DPAD_DOWN:   return ACTION_DOWN
		JOY_BUTTON_DPAD_LEFT:   return ACTION_LEFT
		JOY_BUTTON_DPAD_RIGHT:  return ACTION_RIGHT
		_:                       return 0

# Called once per frame from Main.gd before screen.update(). Polls left
# stick to synthesize directional press events with hold-to-repeat, and
# polls right stick Y to synthesize scroll-wheel ticks.
func tick(dt: float) -> void:
	_tick_stick_dir(dt, ACTION_LEFT,  JOY_AXIS_LEFT_X, -1.0)
	_tick_stick_dir(dt, ACTION_RIGHT, JOY_AXIS_LEFT_X,  1.0)
	_tick_stick_dir(dt, ACTION_UP,    JOY_AXIS_LEFT_Y, -1.0)
	_tick_stick_dir(dt, ACTION_DOWN,  JOY_AXIS_LEFT_Y,  1.0)

	var rsy: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rsy) >= STICK_DEADZONE:
		var sign_y: float = 1.0 if rsy > 0.0 else -1.0
		# Mouse-wheel convention: +1 scrolls up, -1 scrolls down. Push stick
		# down (positive Y) -> scroll down -> -1.
		var tick_val: int = -1 if sign_y > 0.0 else 1
		if _scroll_held <= 0.0:
			_wheel_delta += tick_val
			_scroll_held = REPEAT_INITIAL
		else:
			_scroll_held -= dt
			if _scroll_held <= 0.0:
				_wheel_delta += tick_val
				_scroll_held = REPEAT_RATE
	else:
		_scroll_held = 0.0

func _tick_stick_dir(dt: float, action: int, axis: int, dir_sign: float) -> void:
	var value: float = Input.get_joy_axis(0, axis)
	var active: bool = (dir_sign > 0.0 and value >=  STICK_DEADZONE) \
	                or (dir_sign < 0.0 and value <= -STICK_DEADZONE)
	if active:
		var t: float = float(_stick_held.get(action, -1.0))
		if t < 0.0:
			_pressed[action] = true
			_stick_held[action] = REPEAT_INITIAL
		else:
			t -= dt
			if t <= 0.0:
				_pressed[action] = true
				t = REPEAT_RATE
			_stick_held[action] = t
	else:
		_stick_held.erase(action)

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

# ─── Abstract menu actions (keyboard + gamepad + d-pad + left stick) ─────────

func consume_press_up() -> bool:
	return consume_press([KEY_UP, KEY_W, ACTION_UP])

func consume_press_down() -> bool:
	return consume_press([KEY_DOWN, KEY_S, ACTION_DOWN])

func consume_press_left() -> bool:
	return consume_press([KEY_LEFT, KEY_A, ACTION_LEFT])

func consume_press_right() -> bool:
	return consume_press([KEY_RIGHT, KEY_D, ACTION_RIGHT])

func consume_press_accept() -> bool:
	return consume_press([KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, ACTION_ACCEPT])

func consume_press_back() -> bool:
	return consume_press([KEY_ESCAPE, ACTION_BACK])

func consume_press_pause() -> bool:
	return consume_press([KEY_ESCAPE, ACTION_PAUSE])

# Non-consuming check for accept (used in fight loop for parry / intro skip).
func was_pressed_accept() -> bool:
	return was_pressed(KEY_SPACE) or was_pressed(KEY_Z) or was_pressed(ACTION_ACCEPT)

# ─── Focus (in-game) ─────────────────────────────────────────────────────────

func is_focus() -> bool:
	return is_down(KEY_SHIFT) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) >= 0.5

# ─── Movement (in-game player input) ─────────────────────────────────────────

func movement_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if is_down_any([KEY_A, KEY_LEFT]):  x -= 1.0
	if is_down_any([KEY_D, KEY_RIGHT]): x += 1.0
	if is_down_any([KEY_W, KEY_UP]):    y -= 1.0
	if is_down_any([KEY_S, KEY_DOWN]):  y += 1.0
	var sx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var sy: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(sx) > MOVE_DEADZONE:
		x += sx
	if absf(sy) > MOVE_DEADZONE:
		y += sy
	var v := Vector2(x, y)
	if v.length() > 1.0:
		v = v.normalized()
	return v

func mouse_pos() -> Vector2:
	return _mouse_pos

func mouse_clicked() -> bool:
	return _mouse_clicked

class_name GameOver
extends RefCounted

const CANVAS_W := 1280.0
const CANVAS_H := 720.0

var _info:          Dictionary
var _on_retry:      Callable
var _on_back:       Callable
var _t:             float = 0.0
var _cursor:        int   = 0  # 0 = retry, 1 = back
var _btn_rects:     Array = []

func _init(info: Dictionary, on_retry: Callable, on_back: Callable) -> void:
	_info     = info
	_on_retry = on_retry
	_on_back  = on_back

func update(dt: float, input: InputManager) -> void:
	_t += dt

	var mp := input.mouse_pos()
	for i in range(_btn_rects.size()):
		if _btn_rects[i].has_point(mp):
			_cursor = i
	if input.mouse_clicked():
		for i in range(_btn_rects.size()):
			if _btn_rects[i].has_point(mp):
				_activate(_cursor)
				return

	if input.consume_press([KEY_LEFT, KEY_A, KEY_UP, KEY_W]):
		_cursor = 0
	if input.consume_press([KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S]):
		_cursor = 1
	if input.consume_press([KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]):
		_activate(_cursor)
	if input.consume_press([KEY_R]):
		_activate(0)

func _activate(i: int) -> void:
	if i == 0: _on_retry.call()
	else:       _on_back.call()

func draw(canvas: Node2D) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color("#0a0b16"))

	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 140.0 + 36.0),
	                   "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 64, Color("#ff5d5d"))

	var boss_nm := str(_info.get("bossName", "???"))
	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 80.0 + 15.0),
	                   boss_nm, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 24, Color("#aaaadd"))

	var reason_str := ""
	match _info.get("reason", "death"):
		"death":   reason_str = "Eliminated"
		"time_up": reason_str = "Time's up"
		_:         reason_str = str(_info.get("reason", ""))
	if reason_str != "":
		canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 44.0 + 15.0),
		                   reason_str, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 18, Color("#ff9090"))

	var labels    := ["RETRY", "BACK TO SELECT"]
	var btn_w     := 240.0;  var btn_h := 56.0;  var gap := 24.0
	var total_w   := float(labels.size()) * btn_w + float(labels.size() - 1) * gap
	var start_x   := (CANVAS_W - total_w) / 2.0
	var by        := CANVAS_H / 2.0 + 30.0
	_btn_rects.clear()

	for i in range(labels.size()):
		var bx  := start_x + float(i) * (btn_w + gap)
		_btn_rects.append(Rect2(bx, by, btn_w, btn_h))
		var focused := i == _cursor
		canvas.draw_rect(Rect2(bx, by, btn_w, btn_h), Color("#1f1640") if focused else Color("#13111f"))
		canvas.draw_rect(Rect2(bx, by, btn_w, btn_h),
		                 Color("#ff5d5d") if focused else Color("#444466"),
		                 false, 3.0 if focused else 1.0)
		var tc := Color("#ff5d5d") if focused else Color("#aaaadd")
		canvas.draw_string(font, Vector2(bx, by + btn_h / 2.0 + 8.0),
		                   labels[i], HORIZONTAL_ALIGNMENT_CENTER, btn_w, 20, tc)

	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	canvas.draw_string(font, Vector2(0.0, CANVAS_H - 50.0 + 12.0),
	                   "← → Choose      ENTER Confirm      R Retry",
	                   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
	                   Color(0.667, 0.667, 0.867, pulse * 0.7))

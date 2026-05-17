class_name VictoryScreen
extends RefCounted

const CANVAS_W := 1280.0
const CANVAS_H := 720.0

var _summary:     Dictionary
var _on_continue: Callable
var _t:           float = 0.0

func _init(summary: Dictionary, on_continue: Callable) -> void:
	_summary     = summary
	_on_continue = on_continue

func update(dt: float, input: InputManager) -> void:
	_t += dt
	if input.consume_press([KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_KP_ENTER]):
		_on_continue.call()

func draw(canvas: Node2D) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.039, 0.043, 0.086, 0.92))

	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 110.0 + 36.0),
	                   "VICTORY", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 64, Color("#ffe25d"))

	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 - 70.0 + 15.0),
	                   str(_summary.get("bossName", "")) + " defeated",
	                   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 20, Color("#aaaadd"))

	var grade_col := _grade_color(_summary.get("grade", "C"))
	canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 + 30.0 + 82.0),
	                   str(_summary.get("grade", "C")),
	                   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 110, grade_col)

	var lines := [
		"Score:  " + str(int(_summary.get("score", 0))),
		"Perfect Hits:  " + str(_summary.get("perfectHits", 0)) + " / " + str(_summary.get("totalPrompts", 0)),
		"Max Combo:  " + str(_summary.get("maxCombo", 0)),
		"Damage Taken:  " + str(int(_summary.get("damageTaken", 0))),
	]
	for i in range(lines.size()):
		canvas.draw_string(font, Vector2(0.0, CANVAS_H / 2.0 + 80.0 + float(i) * 26.0 + 14.0),
		                   lines[i], HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 18, Color.WHITE)

	var pulse := 0.6 + 0.4 * sin(_t * 4.0)
	canvas.draw_string(font, Vector2(0.0, CANVAS_H - 50.0 + 12.0),
	                   "Press ENTER to continue",
	                   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 18,
	                   Color(0.365, 0.839, 1.0, pulse))

func _grade_color(g: String) -> Color:
	match g:
		"S": return Color("#ffe25d")
		"A": return Color("#5dffae")
		"B": return Color("#5dd6ff")
		"C": return Color("#aaaadd")
		_:   return Color("#ff5d5d")

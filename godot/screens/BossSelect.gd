class_name BossSelect
extends RefCounted

const CANVAS_W := 1280.0
const CANVAS_H := 720.0

const TOP_PAD     := 100.0       # y where the first row starts
const BOTTOM_PAD  := 90.0        # reserved at bottom for the difficulty selector

var _stages:       Array
var _worlds:       Array
var _stage_by_id:  Dictionary = {}
var _on_pick:      Callable
var _rows:         Array = []     # [{ label, color_hint, cards: [{ stage, rect }] }]
var _hover_card:   Dictionary
var _diff_hover:   int   = 0
var _scroll_y:     float = 0.0
var _content_h:    float = 0.0
# Controller / keyboard cursor — points at either a card in the grid, or
# the difficulty bar when _cursor_on_diff is true.
var _cursor_row:     int  = 0
var _cursor_col:     int  = 0
var _cursor_on_diff: bool = false

func _init(stages: Array, worlds: Array, on_pick: Callable) -> void:
	_stages  = stages
	_worlds  = worlds
	_on_pick = on_pick
	for s in _stages:
		_stage_by_id[s.get("id", "")] = s
	_build_rows()

func _build_rows() -> void:
	_rows.clear()
	var y: float = TOP_PAD
	var header_h := 28.0
	var card_w   := 200.0
	var card_h   := 90.0
	var gap_x    := 16.0
	var gap_y    := 12.0
	for w in _worlds:
		if w.get("secret", false):
			continue
		var stage_ids: Array = w.get("stages", [])
		var cards: Array = []
		var row_total_w: float = float(stage_ids.size()) * card_w + float(max(0, stage_ids.size() - 1)) * gap_x
		var start_x := (CANVAS_W - row_total_w) / 2.0
		for i in range(stage_ids.size()):
			var sid: String = stage_ids[i]
			if not _stage_by_id.has(sid):
				continue
			var stage = _stage_by_id[sid]
			var rect := Rect2(start_x + float(i) * (card_w + gap_x), y + header_h, card_w, card_h)
			cards.append({"stage": stage, "rect": rect})
		_rows.append({"label": w.get("label", ""), "cards": cards, "y": y, "header_h": header_h})
		y += header_h + card_h + gap_y * 2.0
	_content_h = y - TOP_PAD

func _max_scroll() -> float:
	var visible_h: float = CANVAS_H - TOP_PAD - BOTTOM_PAD
	return maxf(0.0, _content_h - visible_h)

func update(_dt: float, input: InputManager) -> void:
	# Free-scroll: mouse wheel + right stick Y (both go through consume_wheel).
	var wheel := input.consume_wheel()
	if wheel != 0:
		_scroll_y = clampf(_scroll_y - float(wheel) * 60.0, 0.0, _max_scroll())

	# Cursor navigation (arrow keys / WASD / d-pad / left stick).
	if _cursor_on_diff:
		if input.consume_press_up():
			_cursor_on_diff = false
			_cursor_row = maxi(0, _rows.size() - 1)
			_cursor_col = clampi(_cursor_col, 0, _row_card_count(_cursor_row) - 1)
		if input.consume_press_left():
			Difficulty.cycle_prev()
		if input.consume_press_right():
			Difficulty.cycle_next()
	else:
		if input.consume_press_up():
			if _cursor_row > 0:
				_cursor_row -= 1
				_cursor_col = clampi(_cursor_col, 0, _row_card_count(_cursor_row) - 1)
		if input.consume_press_down():
			if _cursor_row < _rows.size() - 1:
				_cursor_row += 1
				_cursor_col = clampi(_cursor_col, 0, _row_card_count(_cursor_row) - 1)
			else:
				_cursor_on_diff = true
		if input.consume_press_left():
			_cursor_col = maxi(0, _cursor_col - 1)
		if input.consume_press_right():
			_cursor_col = mini(_row_card_count(_cursor_row) - 1, _cursor_col + 1)
		_scroll_to_show_cursor_card()

	# Mouse hover: take priority over the cursor when the mouse moves to a card.
	var mp := input.mouse_pos()
	_hover_card = {}
	var mouse_picked: bool = false
	for ri in range(_rows.size()):
		var row = _rows[ri]
		for ci in range(row.cards.size()):
			var c = row.cards[ci]
			var hit := Rect2(c.rect.position.x, c.rect.position.y - _scroll_y, c.rect.size.x, c.rect.size.y)
			if hit.has_point(mp) and mp.y >= TOP_PAD and mp.y <= CANVAS_H - BOTTOM_PAD:
				_hover_card = c
				_cursor_row = ri
				_cursor_col = ci
				_cursor_on_diff = false
				mouse_picked = true
				break
		if mouse_picked:
			break

	# If no mouse hover, fall back to highlighting the cursor card.
	if not mouse_picked and not _cursor_on_diff and _cursor_row < _rows.size():
		var row2 = _rows[_cursor_row]
		if _cursor_col < row2.cards.size():
			_hover_card = row2.cards[_cursor_col]

	_diff_hover = 0
	if _diff_prev_rect().has_point(mp):
		_diff_hover = -1
		_cursor_on_diff = true
	elif _diff_next_rect().has_point(mp):
		_diff_hover = 1
		_cursor_on_diff = true
	elif _diff_label_rect().has_point(mp):
		_diff_hover = 2
		_cursor_on_diff = true
	elif _cursor_on_diff and not mouse_picked:
		# Show the label as focused when controller-cursor is on diff bar.
		_diff_hover = 2

	# Accept (Enter / Space / A button / mouse click).
	if input.consume_press_accept():
		if _cursor_on_diff:
			Difficulty.cycle_next()
		elif not _hover_card.is_empty():
			_on_pick.call(_hover_card.stage)

	if input.mouse_clicked():
		if _diff_hover == -1:
			Difficulty.cycle_prev()
		elif _diff_hover == 1 or _diff_hover == 2:
			Difficulty.cycle_next()
		elif not _hover_card.is_empty():
			_on_pick.call(_hover_card.stage)

func _row_card_count(row_i: int) -> int:
	if row_i < 0 or row_i >= _rows.size():
		return 0
	return _rows[row_i].cards.size()

func _scroll_to_show_cursor_card() -> void:
	if _cursor_row >= _rows.size():
		return
	var row = _rows[_cursor_row]
	var card_top: float = row.y + row.header_h
	var card_bot: float = card_top + 90.0
	var visible_top: float = TOP_PAD + _scroll_y
	var visible_bot: float = (CANVAS_H - BOTTOM_PAD) + _scroll_y
	if card_top < visible_top:
		_scroll_y = card_top - TOP_PAD
	elif card_bot > visible_bot:
		_scroll_y = card_bot - (CANVAS_H - BOTTOM_PAD)
	_scroll_y = clampf(_scroll_y, 0.0, _max_scroll())

func draw(canvas: Node2D) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color("#0a0b16"))
	canvas.draw_string(font, Vector2(0.0, 50.0), "SELECT FIGHT",
					   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 32, Color("#ffffff"))

	# Cover the area above TOP_PAD so scrolled rows don't overlap the title.
	for row in _rows:
		var ry: float = row.y - _scroll_y
		# Skip rows fully outside visible area
		if ry + row.header_h + 90.0 < TOP_PAD or ry > CANVAS_H - BOTTOM_PAD:
			continue
		canvas.draw_string(font, Vector2(80.0, ry + 20.0),
						   str(row.label).to_upper(),
						   HORIZONTAL_ALIGNMENT_LEFT, CANVAS_W - 160.0, 18, Color("#8a8aaa"))
		canvas.draw_line(Vector2(80.0, ry + row.header_h - 4.0),
						 Vector2(CANVAS_W - 80.0, ry + row.header_h - 4.0),
						 Color(0.4, 0.4, 0.6, 0.25), 1.0)
		for c in row.cards:
			var cr := Rect2(c.rect.position.x, c.rect.position.y - _scroll_y, c.rect.size.x, c.rect.size.y)
			_draw_card(canvas, font, c.stage, cr, c == _hover_card)

	# Mask the top edge (above content area) and the bottom (above the diff bar).
	canvas.draw_rect(Rect2(0, 0, CANVAS_W, TOP_PAD - 6.0), Color("#0a0b16"))
	canvas.draw_rect(Rect2(0, CANVAS_H - BOTTOM_PAD + 6.0, CANVAS_W, BOTTOM_PAD - 6.0), Color("#0a0b16"))

	# Scroll indicator (if scrollable)
	var maxs := _max_scroll()
	if maxs > 0.0:
		var track_h: float = CANVAS_H - TOP_PAD - BOTTOM_PAD - 20.0
		var bar_h: float = maxf(30.0, track_h * (track_h / (track_h + maxs)))
		var bar_y: float = TOP_PAD + 10.0 + (track_h - bar_h) * (_scroll_y / maxs)
		canvas.draw_rect(Rect2(CANVAS_W - 18.0, TOP_PAD + 10.0, 4.0, track_h), Color(0.3, 0.3, 0.45, 0.4))
		canvas.draw_rect(Rect2(CANVAS_W - 18.0, bar_y, 4.0, bar_h), Color(0.6, 0.6, 0.8, 0.7))

	_draw_difficulty(canvas, font)

func _draw_card(canvas: Node2D, font: Font, stage: Dictionary, r: Rect2, hov: bool) -> void:
	var col: Color = Color(stage.get("color", "#ff5dd6")) if stage.has("color") else Color("#ff5dd6")
	var bg := Color("#1a1040") if hov else Color("#0f0c1e")
	canvas.draw_rect(r, bg)
	var border_col := col if hov else Color(col.r, col.g, col.b, 0.4)
	canvas.draw_rect(r, border_col, false, 2.0 if hov else 1.0)

	var name_col := col if hov else Color(col.r, col.g, col.b, 0.85)
	canvas.draw_string(font, Vector2(r.position.x, r.position.y + 32.0),
					   str(stage.get("name", "???")),
					   HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, name_col)

	var bpm_str := str(stage.get("bpm", 0)) + " BPM"
	canvas.draw_string(font, Vector2(r.position.x, r.position.y + 54.0),
					   bpm_str, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color("#aaaadd"))

	canvas.draw_circle(Vector2(r.get_center().x, r.position.y + 74.0), 5.0, col)

# Difficulty selector layout (bottom of screen)
func _diff_label_rect() -> Rect2: return Rect2(CANVAS_W * 0.5 - 130.0, CANVAS_H - 72.0, 260.0, 44.0)
func _diff_prev_rect()  -> Rect2: return Rect2(CANVAS_W * 0.5 - 200.0, CANVAS_H - 68.0, 40.0, 36.0)
func _diff_next_rect()  -> Rect2: return Rect2(CANVAS_W * 0.5 + 160.0, CANVAS_H - 68.0, 40.0, 36.0)

func _draw_difficulty(canvas: Node2D, font: Font) -> void:
	var diff_col := Difficulty.color()
	var lbl_r := _diff_label_rect()
	var prev_r := _diff_prev_rect()
	var next_r := _diff_next_rect()

	canvas.draw_rect(lbl_r, Color(0.06, 0.04, 0.12, 0.9))
	canvas.draw_rect(lbl_r, diff_col if _diff_hover == 2 else Color(diff_col.r, diff_col.g, diff_col.b, 0.5), false, 2.0 if _diff_hover == 2 else 1.0)

	canvas.draw_rect(prev_r, diff_col if _diff_hover == -1 else Color(diff_col.r, diff_col.g, diff_col.b, 0.3), false, 2.0)
	canvas.draw_rect(next_r, diff_col if _diff_hover == 1 else Color(diff_col.r, diff_col.g, diff_col.b, 0.3), false, 2.0)
	canvas.draw_string(font, Vector2(prev_r.position.x, prev_r.position.y + 26.0),
					   "<", HORIZONTAL_ALIGNMENT_CENTER, prev_r.size.x, 22, diff_col)
	canvas.draw_string(font, Vector2(next_r.position.x, next_r.position.y + 26.0),
					   ">", HORIZONTAL_ALIGNMENT_CENTER, next_r.size.x, 22, diff_col)

	canvas.draw_string(font, Vector2(lbl_r.position.x, lbl_r.position.y + 20.0),
					   Difficulty.label(), HORIZONTAL_ALIGNMENT_CENTER, lbl_r.size.x, 20, diff_col)
	var hp_lbl := "HP " + str(int(Difficulty.player_hp()))
	canvas.draw_string(font, Vector2(lbl_r.position.x, lbl_r.position.y + 38.0),
					   hp_lbl, HORIZONTAL_ALIGNMENT_CENTER, lbl_r.size.x, 12, Color("#aaaadd"))

	canvas.draw_string(font, Vector2(0.0, CANVAS_H - 14.0),
					   "DIFFICULTY  -  ← / →  to change",
					   HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 11, Color("#666688"))

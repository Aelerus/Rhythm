class_name HUDRenderer
extends RefCounted

const CANVAS_W := 1280.0
const CANVAS_H := 720.0

func draw(canvas: Node2D, font: Font, fight: FightManager, beat_pulse: float, beat_pos: float) -> void:
	_draw_boss_bar(canvas, font, fight, beat_pulse)
	_draw_song_timer(canvas, font, fight)
	_draw_player_bar(canvas, font, fight)
	_draw_beat_indicator(canvas, beat_pulse, fight.boss.color)
	_draw_combo(canvas, font, fight, beat_pulse)
	_draw_parry_zone(canvas, font, fight, beat_pulse)
	_draw_counter_prompts(canvas, font, fight, beat_pos)
	_draw_grade_flash(canvas, font, fight)
	_draw_feedback(canvas, font, fight)

func _draw_boss_bar(canvas: Node2D, font: Font, fight: FightManager, beat_pulse: float) -> void:
	var boss := fight.boss
	var bw   := CANVAS_W * 0.7
	var bh   := 18.0
	var bx   := (CANVAS_W - bw) / 2.0
	var by   := 22.0

	canvas.draw_rect(Rect2(bx - 2, by - 2, bw + 4, bh + 4), Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(bx, by, bw, bh), Color("#33223a"))

	var hp_ratio := boss.get_hp_ratio()
	var fill_col := _pace_color(fight, hp_ratio)
	canvas.draw_rect(Rect2(bx, by, bw * hp_ratio, bh), fill_col)

	for t in boss.phase_thresholds:
		var tx: float = bx + bw * float(t)
		var na: float = 0.45 + 0.55 * beat_pulse
		canvas.draw_line(Vector2(tx, by - 2), Vector2(tx, by + bh + 2), Color(1, 1, 1, na * 0.3), 5.0)
		canvas.draw_line(Vector2(tx, by), Vector2(tx, by + bh), Color(1, 1, 1, na), 2.0)

func _pace_color(fight: FightManager, _hp_ratio: float) -> Color:
	# APEX-style perfect run: green by default, red the moment combo breaks.
	if fight.requires_perfect:
		if fight.perfect_broken:
			return Color("#ff3a3a")
		return Color("#3aff5d")
	# Fights with no song timer: just green.
	if fight._song_end_time < 0.0:
		return Color("#3aff5d")
	# Monotonic high-water-mark of "perfect play from here can't catch up".
	# fight.worst_efficiency is computed each frame in FightManager and only
	# ever increases, so once the bar goes yellow/red it stays there.
	var eff: float = fight.worst_efficiency
	if eff >= 1.0:
		return Color("#ff3a3a")   # truly impossible -- even perfect play can't finish
	if eff >= 0.75:
		return Color("#ffd25d")   # warning -- need near-perfect play to win
	return Color("#3aff5d")       # green -- have buffer for normal play

func _draw_song_timer(canvas: Node2D, font: Font, fight: FightManager) -> void:
	if fight._song_end_time < 0.0:
		return
	var remaining := fight.get_song_time_remaining()
	var very_urg  := remaining < 15.0
	var mm: int   = int(remaining) / 60
	var ss        := int(remaining) % 60
	var lbl       := str(mm) + ":" + str(ss).pad_zeros(2)
	var lc: Color = Color("#ff3a3a") if very_urg else Color("#888899")
	_draw_text_left(canvas, font, 24.0, 36.0, lbl, 14, lc)

func _draw_player_bar(canvas: Node2D, font: Font, fight: FightManager) -> void:
	var player := fight.player
	var bw := 220.0;  var bh := 16.0
	var bx := 24.0;   var by := CANVAS_H - 40.0

	canvas.draw_rect(Rect2(bx - 2, by - 2, bw + 4, bh + 4), Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(bx, by, bw, bh), Color("#33223a"))
	var ratio := player.hp / player.max_hp
	var bar_col := Color("#5dffae") if ratio > 0.5 else (Color("#ffd25d") if ratio > 0.25 else Color("#ff5d5d"))
	canvas.draw_rect(Rect2(bx, by, bw * ratio, bh), bar_col)
	_draw_text_left(canvas, font, bx, by - 6.0,
	                "HP " + str(int(ceil(player.hp))) + " / " + str(int(player.max_hp)), 13, Color.WHITE)

func _draw_beat_indicator(canvas: Node2D, beat_pulse: float, boss_color: String) -> void:
	var r   := 12.0 + beat_pulse * 14.0
	var cx  := CANVAS_W / 2.0
	var cy  := CANVAS_H - 36.0
	var col := Color(boss_color) if boss_color != "" else Color("#5dd6ff")
	canvas.draw_circle(Vector2(cx, cy), r, Color(col.r, col.g, col.b, 0.4 + beat_pulse * 0.5))

func _draw_combo(canvas: Node2D, font: Font, fight: FightManager, beat_pulse: float) -> void:
	if fight.requires_perfect or fight.counter.combo <= 1:
		return
	var combo    := fight.counter.combo
	var progress: float = minf(1.0, float(combo) / 16.0)
	var mult: float = 1.0 + progress
	var rx       := CANVAS_W - 24.0
	var top_y    := 70.0

	var sz: int = 28 + mini(8, combo / 4)
	var num_col  := Color("#ffe25d").lerp(Color("#ff8844"), progress)
	var pulse_sc := 1.0 + beat_pulse * 0.06
	_draw_text_right(canvas, font, rx, top_y,
	                 "x%.2f" % mult, int(float(sz) * pulse_sc), num_col)
	var lbl_y: float = top_y + float(sz) * 0.9 + 4.0
	_draw_text_right(canvas, font, rx, lbl_y, "COMBO", 12, Color.WHITE)

	var bar_w  := 100.0
	var bar_h  := 4.0
	var bar_x  := rx - bar_w
	var bar_y  := lbl_y + 14.0
	canvas.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.12, 0.2, 0.9))
	canvas.draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), num_col)

func _draw_parry_zone(canvas: Node2D, font: Font, fight: FightManager, beat_pulse: float) -> void:
	if fight.phase != FightManager.PHASE_COUNTER:
		return
	var zone = fight.counter.zone
	if zone == null:
		return
	var zx     := float(zone.get("x", 0))
	var zy     := float(zone.get("y", 0))
	var zr     := float(zone.get("radius", 70))
	var inside := fight.counter.is_in_zone(fight.player.x, fight.player.y)
	var t      := Time.get_ticks_usec() / 1_000_000.0

	var ring_col: Color
	var acc_in:   Color
	var acc_out:  Color
	if fight.use_inversion:
		ring_col = Color("#0a0a0a") if fight.floor_state == "white" else Color("#f4f4f4")
		acc_in  = Color("#39d68d")
		acc_out = Color("#e22b8a")
	else:
		ring_col = Color("#5dffae") if inside else Color("#ff5dd6")
		acc_in  = Color("#5dffae")
		acc_out = Color("#ff5dd6")
	var accent := acc_in if inside else acc_out

	canvas.draw_circle(Vector2(zx, zy), zr,
	                   Color(accent.r, accent.g, accent.b, 0.18 + 0.18 * beat_pulse + (0.12 if inside else 0.0)))
	var ring_r := zr + 4.0 + sin(t * 6.0) * 3.0
	canvas.draw_arc(Vector2(zx, zy), ring_r, 0.0, TAU, 64,
	                ring_col, 4.0 if inside else 3.0)

	if inside:
		for i in range(2):
			var phase := fmod(t * 0.9 + float(i) * 0.5, 1.0)
			canvas.draw_arc(Vector2(zx, zy), zr + phase * 38.0, 0.0, TAU, 32,
			                Color(ring_col.r, ring_col.g, ring_col.b, (1.0 - phase) * 0.45), 2.0)
	else:
		_draw_text_centered(canvas, font, zx, zy - zr - 14.0, "ENTER THE CIRCLE", 18, ring_col)

	if fight.counter.out_of_range_flash > 0.0:
		var k: float = min(1.0, fight.counter.out_of_range_flash / 0.45)
		canvas.draw_arc(Vector2(zx, zy), zr + 16.0 + (1.0 - k) * 22.0, 0.0, TAU, 64,
		                Color(acc_out.r, acc_out.g, acc_out.b, k * 0.9), 5.0)

func _draw_counter_prompts(canvas: Node2D, font: Font, fight: FightManager, _beat_pos: float) -> void:
	if fight.phase != FightManager.PHASE_COUNTER:
		return
	var cy := CANVAS_H / 2.0 + 60.0
	var cx := CANVAS_W / 2.0
	var prompts := fight.counter.visible_prompts()
	var in_zone := fight.counter.is_in_zone(fight.player.x, fight.player.y) if fight.counter.zone != null else true

	var inv := fight.use_inversion
	var inv_col := Color("#0a0a0a") if fight.floor_state == "white" else Color("#f4f4f4")
	var hit_zone_col := inv_col if inv else Color("#ffe25d")
	var lane_col  := Color(inv_col.r, inv_col.g, inv_col.b, 0.28) if inv else Color(1,1,1,0.18)

	canvas.draw_line(Vector2(cx - 320.0, cy), Vector2(cx + 320.0, cy), lane_col, 2.0)
	canvas.draw_arc(Vector2(cx, cy), 26.0, 0.0, TAU, 32, hit_zone_col, 3.0)

	var px_per_sec := 320.0
	for p in prompts:
		var px := cx + float(p.delta) * px_per_sec
		if px < cx - 360.0 or px > cx + 360.0:
			continue
		var col : Color
		var alpha := 1.0
		if p.hit:
			col = Color(p.grade.get("color", "#888")) if p.grade != null else Color("#888888")
			alpha = 0.4
		else:
			col = inv_col
		canvas.draw_arc(Vector2(px, cy), 18.0, 0.0, TAU, 32,
		                Color(col.r, col.g, col.b, alpha), 3.0)

	var label: String
	var label_col: Color
	if fight.counter.zone != null:
		label     = "PARRY READY — press SPACE on beat" if in_zone else "MOVE TO THE CIRCLE"
		label_col = Color("#5dffae") if in_zone else Color("#ff5dd6")
	else:
		label     = "COUNTERATTACK — press SPACE on beat"
		label_col = Color("#ffe25d")
	_draw_text_centered(canvas, font, cx, cy - 50.0, label, 22, label_col)

func _draw_grade_flash(canvas: Node2D, font: Font, fight: FightManager) -> void:
	if fight.counter.flash_timer <= 0.0 or fight.counter.flash_grade == null:
		return
	var g = fight.counter.flash_grade
	var t_    := fight.counter.flash_timer / 0.55
	var col: Color = Color(g.get("color", "#ffffff"))
	var sz    := int(52.0 + (1.0 - t_) * 12.0)
	_draw_text_centered(canvas, font, CANVAS_W / 2.0, CANVAS_H / 2.0 - 60.0,
	                    str(g.get("name", "")), sz, Color(col.r, col.g, col.b, min(1.0, t_ * 2.0)))

func _draw_feedback(canvas: Node2D, font: Font, fight: FightManager) -> void:
	if fight.feedback_timer <= 0.0 or fight.feedback == null:
		return
	var t_: float = min(1.0, fight.feedback_timer / 1.6)
	var col: Color = Color(fight.feedback.get("color", "#ffffff"))
	_draw_text_centered(canvas, font, CANVAS_W / 2.0, CANVAS_H / 2.0 - 120.0,
	                    str(fight.feedback.get("text", "")), 36,
	                    Color(col.r, col.g, col.b, t_))


# ─── Text helpers ─────────────────────────────────────────────────────────────
# Godot 4 draw_string: pos is top-left baseline area.
# We offset by ~font_size * 0.75 to approximate baseline positioning.

func _draw_text_centered(canvas: Node2D, font: Font, _cx: float, baseline_y: float,
                          text: String, size: int, color: Color) -> void:
	var w := CANVAS_W
	var y := baseline_y - size * 0.75
	canvas.draw_string(font, Vector2(0.0, y), text,
	                   HORIZONTAL_ALIGNMENT_CENTER, w, size, color)

func _draw_text_left(canvas: Node2D, font: Font, x: float, baseline_y: float,
                      text: String, size: int, color: Color) -> void:
	canvas.draw_string(font, Vector2(x, baseline_y - size * 0.75), text,
	                   HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_text_right(canvas: Node2D, font: Font, right_x: float, baseline_y: float,
                       text: String, size: int, color: Color) -> void:
	canvas.draw_string(font, Vector2(0.0, baseline_y - size * 0.75), text,
	                   HORIZONTAL_ALIGNMENT_RIGHT, right_x, size, color)

class_name BossRenderer
extends RefCounted

func draw(canvas: Node2D, boss: BossController, beat_pulse: float, inversion,
          mode: String, overdrive: bool = false) -> void:
	var x := boss.x
	var y := boss.get_display_y()
	# When overdrive is active the boss stays in the "flash" (inverted)
	# colors permanently; a damage flash temporarily reveals their normal
	# colors instead. Outside overdrive: standard flash-on-hit behavior.
	var hit_flash := boss.flash_timer > 0.0
	var flash: bool = (not hit_flash) if overdrive else hit_flash
	var r     := 60.0 + beat_pulse * 6.0

	var body_col:    Color
	var aura_col:    Color
	var outline_col: Color
	var core_inner:  Color
	var core_center: Color

	if mode == "drainGold":
		var t := 1.0 - boss.get_hp_ratio()
		var gold_full := Color("#ffd25d");  var gold_edge := Color("#a87c1f")
		var grey_full := Color("#7f7f7f");  var grey_edge := Color("#3a3a3a")
		body_col    = Color("#ff5d5d") if flash else gold_full.lerp(grey_full, t)
		aura_col    = gold_full.lerp(grey_full, t)
		outline_col = gold_edge.lerp(grey_edge, t)
		core_inner  = Color.WHITE
		core_center = gold_edge.lerp(grey_edge, t)
	elif mode == "inversion" and inversion != null:
		if inversion.get("floor", "white") == "white":
			body_col    = Color("#c9001f") if flash else Color("#0a0a0a")
			aura_col    = Color("#222222")
			outline_col = Color("#f4f4f4")
			core_inner  = Color("#ffffff") if flash else Color("#3a3a3a")
			core_center = Color("#f4f4f4")
		else:
			body_col    = Color("#c9001f") if flash else Color("#f4f4f4")
			aura_col    = Color("#dddddd")
			outline_col = Color("#0a0a0a")
			core_inner  = Color("#000000") if flash else Color("#cfcfcf")
			core_center = Color("#0a0a0a")
	else:
		var bc := Color(boss.color) if boss.color != "" else Color("#ff5dd6")
		body_col    = Color.WHITE if flash else bc
		aura_col    = bc
		outline_col = Color.BLACK
		core_inner  = bc if flash else Color.WHITE
		core_center = Color.BLACK

	var base_alpha := boss.fall_alpha if boss.dying else 1.0

	# Hexagon body
	var hex_pts := PackedVector2Array()
	for i in range(6):
		var a := float(i) / 6.0 * TAU + PI / 6.0
		hex_pts.append(Vector2(x + cos(a) * r, y + sin(a) * r))
	var body_draw := Color(body_col.r, body_col.g, body_col.b, base_alpha)
	canvas.draw_colored_polygon(hex_pts, body_draw)
	# Outline
	hex_pts.append(hex_pts[0])
	canvas.draw_polyline(hex_pts, Color(outline_col.r, outline_col.g, outline_col.b, base_alpha), 4.0)

	# Inner core
	var ci := Color(core_inner.r, core_inner.g, core_inner.b, base_alpha)
	canvas.draw_circle(Vector2(x, y), 14.0 + beat_pulse * 4.0, ci)
	var cc := Color(core_center.r, core_center.g, core_center.b, base_alpha)
	canvas.draw_circle(Vector2(x, y), 6.0, cc)

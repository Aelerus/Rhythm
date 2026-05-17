class_name PlayerRenderer
extends RefCounted

func draw(canvas: Node2D, player: Player, focus: bool, inversion) -> void:
	var flash    := player.flash_timer > 0.0
	var blinking := player.iframes > 0.0 and int(player.iframes * 20.0) % 2 == 0

	var body_col: Color
	var glow_col: Color
	if inversion != null:
		if inversion.get("floor", "white") == "white":
			body_col = Color("#1d6dff")
			glow_col = Color("#5da0ff")
		else:
			body_col = Color("#ff2a3d")
			glow_col = Color("#ff6680")
	else:
		body_col = Color(player.color) if player.color != "" else Color("#e8e8f0")
		glow_col = body_col

	if flash:
		body_col = Color("#ff5d5d")

	var base_alpha := 0.5 if blinking else 1.0

	# Shape (drawn as a polygon, rotated)
	var pts := _get_shape_points(player.shape, player.x, player.y, player.radius, player.angle)
	if pts.size() >= 3:
		var col := Color(body_col.r, body_col.g, body_col.b, base_alpha)
		canvas.draw_colored_polygon(pts, col)

	# Outline
	var stroke_col: Color
	if inversion != null:
		stroke_col = Color("#06040d") if inversion.get("floor","white") == "white" else Color("#fff8f8")
	else:
		stroke_col = Color("#1b1130")
	var outline := PackedVector2Array(pts)
	if outline.size() >= 2:
		outline.append(outline[0])
		canvas.draw_polyline(outline, Color(stroke_col.r, stroke_col.g, stroke_col.b, base_alpha), 2.0)

	# Hitbox core
	var core_alpha  := (1.0 if focus else 0.55) * (0.5 if blinking else 1.0)
	var core_col: Color
	if inversion != null:
		core_col = Color("#ff8a00") if inversion.get("floor","white") == "white" else Color("#ffe25d")
	else:
		core_col = Color("#ffe25d")

	canvas.draw_circle(Vector2(player.x, player.y), player.hitbox_radius + 4.0,
	                   Color(core_col.r, core_col.g, core_col.b, 0.2 * core_alpha))
	canvas.draw_circle(Vector2(player.x, player.y), player.hitbox_radius,
	                   Color(core_col.r, core_col.g, core_col.b, core_alpha))

	if focus:
		canvas.draw_arc(Vector2(player.x, player.y), player.hitbox_radius + 6.0,
		                0.0, TAU, 32,
		                Color(core_col.r, core_col.g, core_col.b, 0.4 * base_alpha), 1.0)

func _get_shape_points(shape: String, cx: float, cy: float, r: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"arrow":
			pts.append(Vector2(0, -r))
			pts.append(Vector2(r * 0.85, r * 0.7))
			pts.append(Vector2(0, r * 0.35))
			pts.append(Vector2(-r * 0.85, r * 0.7))
		"square":
			var hw := r * 0.82
			pts.append(Vector2(-hw, -hw))
			pts.append(Vector2( hw, -hw))
			pts.append(Vector2( hw,  hw))
			pts.append(Vector2(-hw,  hw))
		"star":
			var inner := r * 0.42
			for i in range(10):
				var a   := float(i) * PI / 5.0 - PI / 2.0
				var rad := r if i % 2 == 0 else inner
				pts.append(Vector2(rad * cos(a), rad * sin(a)))
		"hexagon":
			for i in range(6):
				var a := float(i) * PI / 3.0 - PI / 2.0
				pts.append(Vector2(r * cos(a), r * sin(a)))
		"octagon":
			for i in range(8):
				var a := float(i) * PI / 4.0 + PI / 8.0 - PI / 2.0
				pts.append(Vector2(r * cos(a), r * sin(a)))
		_:  # circle / fallback arrow
			pts.append(Vector2(0, -r))
			pts.append(Vector2(r * 0.85, r * 0.7))
			pts.append(Vector2(0, r * 0.35))
			pts.append(Vector2(-r * 0.85, r * 0.7))

	# Rotate and translate
	var rotated := PackedVector2Array()
	var c       := cos(angle)
	var s       := sin(angle)
	for p in pts:
		rotated.append(Vector2(cx + c * p.x - s * p.y, cy + s * p.x + c * p.y))
	return rotated


class_name BulletRenderer
extends RefCounted

func draw(canvas: Node2D, pool: BulletPool, inversion) -> void:
	for b in pool.active:
		var is_marker  := b.tag == "marker"
		var is_orbit: bool = b.orbit != null and b.life < float(b.orbit.get("until", 0))
		var is_delayed := b.delay > 0.0

		var bullet_col: Color
		var core_col:   Color
		if inversion != null:
			bullet_col = Color("#0a0a0a") if inversion.get("floor","white") == "white" else Color("#f4f4f4")
			core_col   = Color("#3a3a3a") if inversion.get("floor","white") == "white" else Color("#cfcfcf")
		else:
			bullet_col = Color(b.color) if b.color != "" else Color("#ff5dd6")
			core_col   = Color.WHITE

		if is_marker or is_delayed:
			var pulse: float = 0.4 + 0.6 * absf(sin(b.life * 14.0))
			var alpha := 0.35 + 0.45 * pulse
			canvas.draw_arc(Vector2(b.x, b.y), b.radius + 2.0, 0.0, TAU, 32,
							Color(bullet_col.r, bullet_col.g, bullet_col.b, alpha), 2.0)
			if b.radius >= 10.0:
				var cx := b.x;  var cy := b.y;  var rr := b.radius
				canvas.draw_line(Vector2(cx - rr - 4, cy), Vector2(cx - rr + 4, cy),
								 Color(bullet_col.r, bullet_col.g, bullet_col.b, alpha), 2.0)
				canvas.draw_line(Vector2(cx + rr - 4, cy), Vector2(cx + rr + 4, cy),
								 Color(bullet_col.r, bullet_col.g, bullet_col.b, alpha), 2.0)
				canvas.draw_line(Vector2(cx, cy - rr - 4), Vector2(cx, cy - rr + 4),
								 Color(bullet_col.r, bullet_col.g, bullet_col.b, alpha), 2.0)
				canvas.draw_line(Vector2(cx, cy + rr - 4), Vector2(cx, cy + rr + 4),
								 Color(bullet_col.r, bullet_col.g, bullet_col.b, alpha), 2.0)
			continue

		var final_alpha := 1.0
		if is_orbit:
			final_alpha = 0.6
		var phase_ghosted := false
		if b.phase_lock_color != "" and inversion != null:
			if b.phase_lock_color != inversion.get("floor", "white"):
				phase_ghosted = true
		if phase_ghosted:
			final_alpha = 0.22

		# Main disc
		canvas.draw_circle(Vector2(b.x, b.y), b.radius,
						   Color(bullet_col.r, bullet_col.g, bullet_col.b, final_alpha))
		# Bright core
		canvas.draw_circle(Vector2(b.x, b.y), b.radius * 0.45,
						   Color(core_col.r, core_col.g, core_col.b, 0.85 * final_alpha))

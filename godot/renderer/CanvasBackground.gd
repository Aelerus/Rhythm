class_name CanvasBackground
extends RefCounted

# Seeded crack veins for the APEX phase 2/3 red-crack mechanic.
var _cracks: Array = []
var _cracks_built: bool = false

func draw_background(canvas: Node2D, beat_pulse: float, boss_color: String,
					 inversion, arena: Rect2, red_cracks, full_red_floor: bool) -> void:
	var W := 1280.0;  var H := 720.0

	if full_red_floor:
		canvas.draw_rect(Rect2(0, 0, W, H), Color("#05060a"))
		var base := Color("#7a0010");  var acc := Color("#c9001f")
		var mid  := base.lerp(acc, 0.3 + 0.4 * beat_pulse)
		canvas.draw_circle(Vector2(arena.get_center().x, arena.get_center().y),
						   arena.size.x * 0.4, Color(mid.r, mid.g, mid.b, 0.7))
		canvas.draw_rect(arena, base)
		return

	if inversion != null:
		canvas.draw_rect(Rect2(0, 0, W, H), Color("#05060a"))
		var is_white: bool = inversion.get("floor", "white") == "white"
		var base_col := Color("#f4f4f4") if is_white else Color("#0a0a0a")
		var acc_col  := Color("#e0e0e0") if is_white else Color("#181818")
		var mid_col  := base_col.lerp(acc_col, 0.2 + 0.3 * beat_pulse)
		canvas.draw_circle(Vector2(arena.get_center().x, arena.get_center().y),
						   arena.size.length() * 0.4, mid_col)
		canvas.draw_rect(arena, base_col)
		# Clean up circle bleed into top outer strip
		canvas.draw_rect(Rect2(arena.position.x, 0, arena.size.x, arena.position.y), Color("#05060a"))

		# Red cracks
		if red_cracks != null and float(red_cracks.get("progress", 0)) > 0.0:
			_draw_cracks(canvas, arena, float(red_cracks.get("progress", 0)))

		# Inversion flash
		var flash_t := float(inversion.get("flash", 0))
		if flash_t > 0.0:
			var k: float = min(1.0, flash_t / 0.45)
			canvas.draw_rect(arena, Color(1, 1, 1, k) if is_white else Color(0, 0, 0, k))
		return

	# Standard background — colored glow inside arena, outer strips stay black
	var bc    := Color(boss_color) if boss_color != "" else Color("#1b1130")
	var t     := beat_pulse
	var inner := Color("#0a0a12").lerp(bc, 0.45 + 0.35 * t)
	canvas.draw_rect(Rect2(0, 0, W, H), Color("#05060a"))
	canvas.draw_circle(Vector2(W / 2.0, H / 2.0), W * 0.62, inner)
	var blk := Color("#05060a")
	canvas.draw_rect(Rect2(0, 0, arena.position.x, H), blk)
	canvas.draw_rect(Rect2(arena.position.x + arena.size.x, 0, W - arena.position.x - arena.size.x, H), blk)
	canvas.draw_rect(Rect2(arena.position.x, 0, arena.size.x, arena.position.y), blk)
	canvas.draw_rect(Rect2(arena.position.x, arena.position.y + arena.size.y, arena.size.x, H - arena.position.y - arena.size.y), blk)

func draw_grid_walls(canvas: Node2D, arena: Rect2, active_walls: Dictionary, beat_pulse: float) -> void:
	var faint  := Color(0.8, 0.0, 0.85, 0.055)
	var bright := Color(1.0, 0.0, 0.85, 0.80 + 0.15 * beat_pulse)
	for i in range(6):
		var wy: float = arena.position.y + arena.size.y * float(i + 1) / 7.0
		var lid: String = "h" + str(i)
		var on: bool = active_walls.has(lid)
		canvas.draw_line(Vector2(arena.position.x, wy),
			Vector2(arena.position.x + arena.size.x, wy),
			bright if on else faint, 3.0 if on else 1.0)
	for i in range(4):
		var wx: float = arena.position.x + arena.size.x * float(i + 1) / 5.0
		var lid: String = "v" + str(i)
		var on: bool = active_walls.has(lid)
		canvas.draw_line(Vector2(wx, arena.position.y),
			Vector2(wx, arena.position.y + arena.size.y),
			bright if on else faint, 3.0 if on else 1.0)

func draw_arena_frame(canvas: Node2D, arena: Rect2, beat_pulse: float, boss_color: String,
					  inversion, _red_cracks, full_red_floor: bool) -> void:
	var glow    := 0.25 + beat_pulse * 0.5
	var fc: Color
	if full_red_floor:
		fc = Color("#9c0010")
	elif inversion != null:
		fc = Color("#1a1a1a") if inversion.get("floor", "white") == "white" else Color("#f0f0f0")
	else:
		fc = Color(boss_color) if boss_color != "" else Color("#5dd6ff")
	canvas.draw_rect(arena, Color(fc.r, fc.g, fc.b, 0.7 * glow), false, 2.0)

func draw_arena_doors(canvas: Node2D, arena: Rect2, progress: float, boss_color: String, _beat_pulse: float) -> void:
	var strip_y: float = arena.position.y + arena.size.y
	var strip_h: float = 720.0 - strip_y
	var inset:   float = 80.0
	var ax:      float = arena.position.x
	var aw:      float = arena.size.x
	var p:       float = clampf(progress, 0.0, 1.0)

	var trap_pts := PackedVector2Array([
		Vector2(ax,              strip_y),
		Vector2(ax + aw,         strip_y),
		Vector2(ax + aw - inset, strip_y + strip_h),
		Vector2(ax + inset,      strip_y + strip_h),
	])

	if p >= 1.0:
		canvas.draw_colored_polygon(trap_pts, Color.BLACK)
		return

	# Intro: arena color base, black doors shutting from outer edges inward
	var bc: Color = Color(boss_color) if boss_color != "" else Color("#5dd6ff")
	canvas.draw_colored_polygon(trap_pts, bc.lightened(0.35))

	if p > 0.0:
		var black := Color.BLACK
		var top_half: float = aw * 0.5 * p
		var bot_half: float = (aw - 2.0 * inset) * 0.5 * p
		var left_door := PackedVector2Array([
			Vector2(ax,                       strip_y),
			Vector2(ax + top_half,            strip_y),
			Vector2(ax + inset + bot_half,    strip_y + strip_h),
			Vector2(ax + inset,               strip_y + strip_h),
		])
		canvas.draw_colored_polygon(left_door, black)
		var right_door := PackedVector2Array([
			Vector2(ax + aw - top_half,             strip_y),
			Vector2(ax + aw,                        strip_y),
			Vector2(ax + aw - inset,                strip_y + strip_h),
			Vector2(ax + aw - inset - bot_half,     strip_y + strip_h),
		])
		canvas.draw_colored_polygon(right_door, black)

func _draw_cracks(canvas: Node2D, arena: Rect2, progress: float) -> void:
	if not _cracks_built:
		_build_cracks(arena)
		_cracks_built = true
	var vein_col  := Color("#c9001f")
	for c in _cracks:
		if float(c.spawnAt) > progress:
			continue
		var local_t: float = min(1.0, (progress - float(c.spawnAt)) * 6.0)
		var alpha   := 0.55 + 0.4 * local_t
		var width   := float(c.width) * (0.5 + 0.5 * local_t)
		var pts : PackedVector2Array = c.pts
		canvas.draw_polyline(pts, Color(vein_col.r, vein_col.g, vein_col.b, alpha), width)
		for branch in c.branches:
			canvas.draw_polyline(branch as PackedVector2Array,
								 Color(vein_col.r, vein_col.g, vein_col.b, alpha * 0.7),
								 width * 0.55)
	if progress > 0.6:
		var wash := (progress - 0.6) / 0.4
		canvas.draw_rect(arena, Color(0.627, 0.0, 0.094, 0.35 * wash))

func _build_cracks(arena: Rect2) -> void:
	_cracks.clear()
	var rng_seed  := int(arena.position.x * 31 + arena.position.y * 17 + arena.size.x + arena.size.y)
	var rng_state := [rng_seed]
	var rnd       := func():
		rng_state[0] = (rng_state[0] * 9301 + 49297) % 233280
		return float(rng_state[0]) / 233280.0

	for i in range(26):
		var side: int = int(float(rnd.call()) * 4)
		var sx: float;  var sy: float
		match side:
			0: sx = arena.position.x + float(rnd.call()) * arena.size.x;  sy = arena.position.y
			1: sx = arena.position.x + arena.size.x;                      sy = arena.position.y + float(rnd.call()) * arena.size.y
			2: sx = arena.position.x + float(rnd.call()) * arena.size.x;  sy = arena.position.y + arena.size.y
			_: sx = arena.position.x;                                      sy = arena.position.y + float(rnd.call()) * arena.size.y

		var tx:      float = arena.position.x + (0.2 + float(rnd.call()) * 0.6) * arena.size.x
		var ty:      float = arena.position.y + (0.2 + float(rnd.call()) * 0.6) * arena.size.y
		var seg_len: float = 18.0 + float(rnd.call()) * 22.0
		var seg_cnt: int   = 8 + int(float(rnd.call()) * 12)
		var base_a:  float = atan2(ty - sy, tx - sx)

		var pts := PackedVector2Array()
		pts.append(Vector2(sx, sy))
		var px := sx;  var py := sy
		for _s in range(seg_cnt):
			var wobble: float = (float(rnd.call()) - 0.5) * 0.85
			var a:      float = base_a + wobble
			px += cos(a) * seg_len
			py += sin(a) * seg_len
			pts.append(Vector2(px, py))

		var branches := []
		for _b in range(2 + int(float(rnd.call()) * 3)):
			var b_idx: int = 1 + int(float(rnd.call()) * int(max(1, pts.size() - 2)))
			var bp    := pts[b_idx]
			var b_ang: float = base_a + (float(rnd.call()) - 0.5) * 1.6
			var bpts  := PackedVector2Array()
			bpts.append(bp)
			var bx_ := bp.x;  var by_ := bp.y
			for _bs in range(3 + int(float(rnd.call()) * 4)):
				var a: float = b_ang + (float(rnd.call()) - 0.5) * 0.7
				bx_ += cos(a) * (seg_len * 0.7)
				by_ += sin(a) * (seg_len * 0.7)
				bpts.append(Vector2(bx_, by_))
			branches.append(bpts)

		_cracks.append({"spawnAt": float(i) / 26.0, "width": 2.0 + float(rnd.call()) * 3.0,
						"pts": pts, "branches": branches})

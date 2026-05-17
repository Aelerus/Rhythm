class_name AuxAttacks
extends RefCounted

# ─── TetherAttack ─────────────────────────────────────────────────────────────
class TetherAttack extends RefCounted:
	var boss: BossController
	var lifetime:         float
	var elapsed:          float = 0.0
	var _spawn_timer:     float = 0.45
	var spawn_interval:   float
	var bullet_speed:     float
	var bullet_color:     String
	var bullet_radius:    float
	var dead:             bool  = false

	func _init(opts: Dictionary) -> void:
		boss          = opts.get("boss")
		lifetime      = float(opts.get("duration",      1.8))
		spawn_interval = float(opts.get("spawnInterval", 0.16))
		bullet_speed  = float(opts.get("bulletSpeed",   220))
		bullet_color  = opts.get("color",               "#c9001f")
		bullet_radius = float(opts.get("radius",        6))

	func update(dt: float, player: Player, pool: BulletPool) -> void:
		elapsed  += dt
		lifetime -= dt
		if lifetime <= 0.0:
			dead = true
			return
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			var dx := player.x - boss.x
			var dy := player.y - boss.y
			var dist: float = sqrt(dx*dx + dy*dy)
			if dist <= 0.0:
				dist = 1.0
			pool.spawn({
				"x": boss.x, "y": boss.y,
				"vx": dx / dist * bullet_speed,
				"vy": dy / dist * bullet_speed,
				"radius": bullet_radius,
				"color":  bullet_color,
				"maxLife": 4,
			})

	func render(canvas: Node2D, player: Player) -> void:
		var t       := elapsed
		var telegraph: float = min(1.0, t / 0.45)
		var pulse   := 0.6 + 0.4 * sin(t * 16.0)
		var col     := Color(bullet_color)
		var bx      := boss.x
		var by      := boss.get_display_y()
		var px      := player.x
		var py      := player.y

		canvas.draw_line(Vector2(bx, by), Vector2(px, py),
			Color(col.r, col.g, col.b, 0.18 * telegraph * pulse), 14.0)
		canvas.draw_line(Vector2(bx, by), Vector2(px, py),
			Color(col.r, col.g, col.b, 0.55 * telegraph), 5.0)
		canvas.draw_line(Vector2(bx, by), Vector2(px, py),
			Color(col.r, col.g, col.b, 0.95 * telegraph), 1.5)


# ─── GravityWell ──────────────────────────────────────────────────────────────
class GravityWell extends RefCounted:
	var x:        float
	var y:        float
	var lifetime: float
	var elapsed:  float = 0.0
	var strength: float
	var radius:   float
	var color:    String
	var dead:     bool  = false

	func _init(opts: Dictionary) -> void:
		x        = float(opts.get("x",        0))
		y        = float(opts.get("y",        0))
		lifetime = float(opts.get("duration", 1.6))
		strength = float(opts.get("strength", 220))
		radius   = float(opts.get("radius",   240))
		color    = opts.get("color",  "#cdcdd6")

	func update(dt: float, player: Player, _pool: BulletPool) -> void:
		elapsed  += dt
		lifetime -= dt
		if lifetime <= 0.0:
			dead = true
			return
		if elapsed < 0.4:
			return
		var dx   := x - player.x
		var dy   := y - player.y
		var dist := sqrt(dx*dx + dy*dy)
		if dist > radius or dist < 8.0:
			return
		var falloff := 1.0 - dist / radius
		var ax := (dx / dist) * strength * falloff * dt
		var ay := (dy / dist) * strength * falloff * dt
		player.x += ax
		player.y += ay
		var a := player.arena
		var pad := player.radius
		player.x = clamp(player.x, a.position.x + pad, a.position.x + a.size.x - pad)
		player.y = clamp(player.y, a.position.y + pad, a.position.y + a.size.y - pad)

	func render(canvas: Node2D) -> void:
		var t          := elapsed
		var telegraph: float = min(1.0, t / 0.4)
		var col        := Color(color)
		var center     := Vector2(x, y)

		canvas.draw_circle(center, radius * 0.95, Color(col.r, col.g, col.b, 0.22 * telegraph))

		var arm_count := 5
		for i in range(arm_count):
			var phase := t * 4.0 + i * (TAU / arm_count)
			var pts := PackedVector2Array()
			var r := 8.0
			while r < radius:
				var a := phase + r * 0.04
				pts.append(center + Vector2(cos(a) * r, sin(a) * r))
				r += 5.0
			if pts.size() >= 2:
				canvas.draw_polyline(pts, Color(col.r, col.g, col.b, 0.55 * telegraph), 2.0)

		var core_r := 8.0 + 3.0 * sin(t * 18.0)
		canvas.draw_circle(center, core_r, Color(1, 1, 1, 0.9 * telegraph))


# ─── RealityTear ──────────────────────────────────────────────────────────────
class RealityTear extends RefCounted:
	var x:             float
	var y:             float
	var length:        float
	var angle:         float
	var lifetime:      float
	var elapsed:       float = 0.0
	var spawn_interval: float
	var _spawn_timer:  float = 0.55
	var bullet_speed:  float
	var bullet_color:  String
	var bullet_radius: float
	var bead_count:    int
	var dead:          bool  = false

	func _init(opts: Dictionary) -> void:
		x             = float(opts.get("x",            0))
		y             = float(opts.get("y",            0))
		length        = float(opts.get("length",       380))
		angle         = float(opts.get("angle",        0))
		lifetime      = float(opts.get("duration",     1.4))
		spawn_interval = float(opts.get("spawnInterval", 0.10))
		bullet_speed  = float(opts.get("bulletSpeed",  280))
		bullet_color  = opts.get("color",  "#c9001f")
		bullet_radius = float(opts.get("radius",       6))
		bead_count    = int(opts.get("beadCount",      9))

	func update(dt: float, _player: Player, pool: BulletPool) -> void:
		elapsed  += dt
		lifetime -= dt
		if lifetime <= 0.0:
			dead = true
			return
		if elapsed < 0.55:
			return
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			var c   := cos(angle)
			var s   := sin(angle)
			var px  := -s
			var py  :=  c
			for i in range(bead_count):
				var t := float(i) / float(bead_count - 1) - 0.5
				var sx := x + c * (t * length)
				var sy := y + s * (t * length)
				pool.spawn({"x": sx, "y": sy, "vx":  px * bullet_speed, "vy":  py * bullet_speed,
							 "radius": bullet_radius, "color": bullet_color})
				pool.spawn({"x": sx, "y": sy, "vx": -px * bullet_speed, "vy": -py * bullet_speed,
							 "radius": bullet_radius, "color": bullet_color})

	func render(canvas: Node2D) -> void:
		var t              := elapsed
		var telegraph_prog: float = min(1.0, t / 0.55)
		var is_open        := t > 0.55
		var c              := cos(angle)
		var s              := sin(angle)
		var x1             := Vector2(x - c * length / 2.0, y - s * length / 2.0)
		var x2             := Vector2(x + c * length / 2.0, y + s * length / 2.0)
		var col            := Color(bullet_color)

		if not is_open:
			canvas.draw_line(x1, x2, Color(col.r, col.g, col.b, 0.55 * telegraph_prog), 2.0)
		else:
			var wobble := 4.0 + sin(t * 30.0) * 1.5
			var px     := Vector2(-s, c) * wobble
			canvas.draw_line(x1 + px, x2 + px, Color(col.r, col.g, col.b, 0.8), 4.0)
			canvas.draw_line(x1 - px, x2 - px, Color(col.r, col.g, col.b, 0.8), 4.0)
			canvas.draw_line(x1,      x2,      Color(col.r, col.g, col.b, 1.0), 1.5)


# ─── SlowZone ─────────────────────────────────────────────────────────────────
# EIEN-only mechanic: a slow, erratic-drifting circle that slows the player
# while inside it. Persists the entire fight; updates every frame regardless
# of dodge/counter phase. Drift uses a sum of two non-commensurate sines per
# axis for quasi-random motion (Lissajous-like, never repeats predictably).
class SlowZone extends RefCounted:
	var x:             float = 0.0
	var y:             float = 0.0
	var radius:        float = 100.0
	var color:         String = "#5dd6ff"
	var slow_factor:   float = 0.4
	var arena:         Rect2 = Rect2()
	var elapsed:       float = 0.0
	var dead:          bool  = false
	var drift_freq_x:  float = 0.31
	var drift_freq_y:  float = 0.47
	var drift_freq_x2: float = 0.13
	var drift_freq_y2: float = 0.19
	var drift_range_x: float = 0.35  # fraction of arena width
	var drift_range_y: float = 0.30  # fraction of arena height

	func _init(opts: Dictionary) -> void:
		arena         = opts.get("arena", Rect2(160, 60, 960, 600))
		radius        = float(opts.get("radius",      100))
		color         = opts.get("color",             "#5dd6ff")
		slow_factor   = float(opts.get("slowFactor",  0.4))
		drift_freq_x  = float(opts.get("driftFreqX",  0.31))
		drift_freq_y  = float(opts.get("driftFreqY",  0.47))
		drift_freq_x2 = float(opts.get("driftFreqX2", 0.13))
		drift_freq_y2 = float(opts.get("driftFreqY2", 0.19))
		drift_range_x = float(opts.get("driftRangeX", 0.35))
		drift_range_y = float(opts.get("driftRangeY", 0.30))
		x = arena.position.x + arena.size.x * 0.5
		y = arena.position.y + arena.size.y * 0.5

	func update(dt: float, player: Player, _pool: BulletPool) -> void:
		elapsed += dt
		var cx: float = arena.position.x + arena.size.x * 0.5
		var cy: float = arena.position.y + arena.size.y * 0.5
		var rx: float = arena.size.x * drift_range_x
		var ry: float = arena.size.y * drift_range_y
		x = cx + rx * (sin(elapsed * drift_freq_x)       * 0.7
		             + sin(elapsed * drift_freq_x2)      * 0.3)
		y = cy + ry * (sin(elapsed * drift_freq_y + 1.2) * 0.7
		             + sin(elapsed * drift_freq_y2)      * 0.3)
		var pdx: float = player.x - x
		var pdy: float = player.y - y
		if pdx * pdx + pdy * pdy < radius * radius:
			player.speed_multiplier = slow_factor
		else:
			player.speed_multiplier = 1.0

	func render(canvas: Node2D) -> void:
		var col := Color(color)
		var center := Vector2(x, y)
		var pulse: float = 0.6 + 0.4 * sin(elapsed * 2.0)
		canvas.draw_circle(center, radius * 1.15, Color(col.r, col.g, col.b, 0.10 * pulse))
		canvas.draw_circle(center, radius,        Color(col.r, col.g, col.b, 0.22))
		canvas.draw_arc(center, radius, 0.0, TAU, 48,
		                Color(col.r, col.g, col.b, 0.75 * pulse), 2.5)
		var inner_r: float = radius * 0.55 + sin(elapsed * 3.0) * 6.0
		canvas.draw_arc(center, inner_r, 0.0, TAU, 32,
		                Color(col.r, col.g, col.b, 0.45 * pulse), 1.5)

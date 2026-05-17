class_name PatternEngine
extends RefCounted

var pool: BulletPool
var library: Dictionary
var _trail: Array = []  # [{x, y, t}]

func _init(p_pool: BulletPool, p_library: Dictionary) -> void:
	pool    = p_pool
	library = p_library

func record_player_trail(player: Player, t: float) -> void:
	_trail.append({"x": player.x, "y": player.y, "t": t})
	while _trail.size() > 0 and t - float(_trail[0].t) > 4.0:
		_trail.pop_front()

func fire(pattern_id_or_data, ctx: Dictionary) -> void:
	var pattern: Dictionary
	if pattern_id_or_data is String:
		pattern = library.get(pattern_id_or_data, {})
		if pattern.is_empty():
			push_warning("PatternEngine: unknown pattern '" + pattern_id_or_data + "'")
			return
	else:
		pattern = pattern_id_or_data

	match pattern.get("type", ""):
		"radial_burst":         _radial(pattern, ctx)
		"aimed_shot":           _aimed(pattern, ctx)
		"spiral":               _spiral(pattern, ctx)
		"wall":                 _wall(pattern, ctx)
		"cross":                _cross(pattern, ctx)
		"homing":               _homing(pattern, ctx)
		"rain":                 _rain(pattern, ctx)
		"converging":           _converging(pattern, ctx)
		"mirror_path":          _mirror_path(pattern, ctx)
		"arena_burst":          _arena_burst(pattern, ctx)
		"vortex":               _vortex(pattern, ctx)
		"echo":                 _echo(pattern, ctx)
		"laser_line":           _laser_line(pattern, ctx)
		"stutter_aim":          _stutter_aim(pattern, ctx)
		"split_wave":           _split_wave(pattern, ctx)
		"pulse_beam":           _pulse_beam(pattern, ctx)
		"tempo_grid":           _tempo_grid(pattern, ctx)
		"phase_locked_radial":  _phase_locked_radial(pattern, ctx)
		"phase_locked_aimed":   _phase_locked_aimed(pattern, ctx)
		"tether":               _tether(pattern, ctx)
		"gravity_well":         _gravity_well(pattern, ctx)
		"expanding_radial":     _expanding_radial(pattern, ctx)
		"reality_tear":         _reality_tear(pattern, ctx)
		"sw_arc":               _sw_arc(pattern, ctx)
		"sw_sine":              _sw_sine(pattern, ctx)
		"sw_bounce":            _sw_bounce(pattern, ctx)
		"sw_speedline":         _sw_speedline(pattern, ctx)
		"sw_grid_pulse":        _sw_grid_pulse(pattern, ctx)
		"sw_vector_burst":      _sw_vector_burst(pattern, ctx)
		"sub_slam":             _sub_slam(pattern, ctx)
		"hat_spray":            _hat_spray(pattern, ctx)
		"train_wall":           _train_wall(pattern, ctx)
		"strobe_line":          _strobe_line(pattern, ctx)
		"bass_drop":            _bass_drop(pattern, ctx)
		"slow_zone":            _slow_zone(pattern, ctx)
		_:
			push_warning("PatternEngine: unhandled type '" + str(pattern.get("type","")) + "'")

# ─── Pattern implementations ──────────────────────────────────────────────────

func _radial(p: Dictionary, ctx: Dictionary) -> void:
	var count  := int(p.get("count",  16))
	var speed  := float(p.get("speed", 180))
	var offset := float(p.get("rotateWithBeat", false)) * int(ctx.get("beatIndex", 0)) * float(p.get("rotateStep", 0.2))
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	for i in range(count):
		var a := float(i) / float(count) * TAU + offset
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ff5dd6")})

func _aimed(p: Dictionary, ctx: Dictionary) -> void:
	var speed     := float(p.get("speed",  280))
	var count     := int(p.get("count",   1))
	var spread    := float(p.get("spread", 0))
	var turn_rate := float(p.get("turnRate", 0))
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	var dx     := float(ctx.get("targetX", 0)) - bx
	var dy     := float(ctx.get("targetY", 0)) - by
	var base_a := atan2(dy, dx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		var spawn := {"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		              "radius": p.get("radius", 8), "color": p.get("color", "#ffd25d")}
		if turn_rate > 0.0:
			spawn["homing"]  = turn_rate
			spawn["maxLife"] = p.get("maxLife", 6)
		pool.spawn(spawn)

func _spiral(p: Dictionary, ctx: Dictionary) -> void:
	var arms   := int(p.get("arms",  3))
	var count  := int(p.get("count", 6))
	var speed  := float(p.get("speed", 200))
	var beat   := int(ctx.get("beatIndex", 0))
	var offset := float(beat % 360) * float(p.get("rotateStep", 0.18))
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	for a_idx in range(arms):
		var arm_a := float(a_idx) / float(arms) * TAU + offset
		for i in range(count):
			var a := arm_a + i * 0.06
			pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
			            "radius": p.get("radius", 6), "color": p.get("color", "#5dd6ff")})

func _wall(p: Dictionary, ctx: Dictionary) -> void:
	var arena     = ctx.get("arena", {})
	var ax        := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay        := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var count     := int(p.get("count",   16))
	var speed     := float(p.get("speed", 220))
	var gap_w     := int(p.get("gapWidth", 3))
	var radius    = p.get("radius", 8)
	var col       = p.get("color", "#a05dff")

	# APEX-style cross targeting: fire 2 dense bullet bands -- one from the
	# top down through the player's x axis, one from the left right through
	# the player's y axis. Forces movement in BOTH dimensions.
	if p.get("trackPlayer", false):
		var px      := float(ctx.get("targetX", ax + aw * 0.5))
		var py      := float(ctx.get("targetY", ay + ah * 0.5))
		var band    := int(p.get("bandCount", 5))     # bullets per axis band
		var spread  := float(p.get("bandSpread", 50.0))  # px around the player axis
		var spacing := spread * 2.0 / float(max(1, band - 1))
		for i in range(band):
			var off  := -spread + float(i) * spacing if band > 1 else 0.0
			# Vertical band: comes down at player's x
			pool.spawn({"x": px + off, "y": ay - 20.0, "vx": 0, "vy": speed,
			            "radius": radius, "color": col})
			# Horizontal band: comes right at player's y
			pool.spawn({"x": ax - 20.0, "y": py + off, "vx": speed, "vy": 0,
			            "radius": radius, "color": col})
		return

	var gap_start: int = randi() % int(max(1, count - gap_w))
	for i in range(count):
		if i >= gap_start and i < gap_start + gap_w:
			continue
		var xp := ax + (float(i) + 0.5) * (aw / float(count))
		pool.spawn({"x": xp, "y": ay - 20.0, "vx": 0, "vy": speed,
		            "radius": radius, "color": col})

func _cross(p: Dictionary, ctx: Dictionary) -> void:
	var speed  := float(p.get("speed", 240))
	var beat   := int(ctx.get("beatIndex", 0))
	var offset := float(beat % 4) * (PI / 8.0)
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	for i in range(4):
		var a := float(i) / 4.0 * TAU + offset
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 10), "color": p.get("color", "#ff8a5d")})

func _homing(p: Dictionary, ctx: Dictionary) -> void:
	var count     := int(p.get("count",   3))
	var speed     := float(p.get("speed", 140))
	var turn_rate := float(p.get("turnRate", 1.4))
	var bx        := float(ctx.get("bossX", 0))
	var by        := float(ctx.get("bossY", 0))
	for i in range(count):
		var a := float(i) / float(count) * TAU
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#5dffae"),
		            "homing": turn_rate, "maxLife": 6})

func _rain(p: Dictionary, ctx: Dictionary) -> void:
	var arena  = ctx.get("arena", {})
	var ax     := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay     := float(arena.get("y", 60))
	var count  := int(p.get("count",  12))
	var speed  := float(p.get("speed", 260))
	for _i in range(count):
		var xp := ax + 20.0 + randf() * (aw - 40.0)
		pool.spawn({"x": xp, "y": ay - 15.0, "vx": 0, "vy": speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ff5d6d")})

func _converging(p: Dictionary, ctx: Dictionary) -> void:
	var arena  = ctx.get("arena", {})
	var ax     := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay     := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var tx     := float(ctx.get("targetX", 0))
	var ty     := float(ctx.get("targetY", 0))
	var count  := int(p.get("count",  10))
	var speed  := float(p.get("speed", 270))
	var inset  := 8.0
	for _i in range(count):
		var side := randi() % 4
		var sx: float; var sy: float
		match side:
			0: sx = ax + randf() * aw;       sy = ay - inset
			1: sx = ax + aw + inset;          sy = ay + randf() * ah
			2: sx = ax + randf() * aw;       sy = ay + ah + inset
			_: sx = ax - inset;               sy = ay + randf() * ah
		var dx  := tx - sx;  var dy := ty - sy
		var dist: float = sqrt(dx*dx + dy*dy)
		if dist <= 0.0: dist = 1.0
		pool.spawn({"x": sx, "y": sy, "vx": dx/dist*speed, "vy": dy/dist*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ff3a55")})

func _mirror_path(p: Dictionary, ctx: Dictionary) -> void:
	if _trail.size() < 2:
		_aimed(p, ctx)
		return
	var count := int(p.get("count", 6))
	var speed := float(p.get("speed", 200))
	var tx    := float(ctx.get("targetX", 0))
	var ty    := float(ctx.get("targetY", 0))
	for i in range(count):
		var idx := int(float(i) / float(max(1, count - 1)) * float(_trail.size() - 1))
		var pt: Dictionary = _trail[idx]
		var dx  := tx - float(pt.x)
		var dy  := ty - float(pt.y)
		var dist: float = sqrt(dx*dx + dy*dy)
		if dist <= 0.0: dist = 1.0
		pool.spawn({"x": float(pt.x), "y": float(pt.y),
		            "vx": dx/dist*speed, "vy": dy/dist*speed,
		            "radius": p.get("radius", 6), "color": p.get("color", "#ffffff"),
		            "delay": p.get("telegraph", 0.25)})

func _arena_burst(p: Dictionary, ctx: Dictionary) -> void:
	var arena    = ctx.get("arena", {})
	var ax       := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay       := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var sites    := int(p.get("sites",   4))
	var arms     := int(p.get("arms",    6))
	var speed    := float(p.get("speed", 240))
	var telegraph := float(p.get("telegraph", 0.45))
	var inset    := 40.0
	for s in range(sites):
		var cx := ax + inset + randf() * (aw - 2.0 * inset)
		var cy := ay + inset + randf() * (ah - 2.0 * inset)
		pool.spawn({"x": cx, "y": cy, "vx": 0, "vy": 0,
		            "radius": p.get("markerRadius", 14), "color": p.get("markerColor", "#ffffff"),
		            "delay": telegraph, "maxLife": telegraph + 0.05, "tag": "marker"})
		for a_idx in range(arms):
			var a := float(a_idx) / float(arms) * TAU + float(s) * 0.13
			pool.spawn({"x": cx, "y": cy, "vx": cos(a)*speed, "vy": sin(a)*speed,
			            "radius": p.get("radius", 7), "color": p.get("color", "#ffffff"),
			            "delay": telegraph})

func _vortex(p: Dictionary, ctx: Dictionary) -> void:
	var count        := int(p.get("count",       14))
	var orbit_dur    := float(p.get("orbitDur",  0.9))
	var orbit_r      := float(p.get("orbitRadius", 90))
	var omega        := float(p.get("omega",     4.2)) * (-1.0 if p.get("reverse", false) else 1.0)
	var rel_speed    := float(p.get("releaseSpeed", 280))
	var aim_at_rel: bool = p.get("aimAtRelease", true)
	var bx           := float(ctx.get("bossX", 0))
	var by           := float(ctx.get("bossY", 0))
	for i in range(count):
		var a := float(i) / float(count) * TAU
		pool.spawn({
			"x": bx + cos(a) * orbit_r, "y": by + sin(a) * orbit_r,
			"radius": p.get("radius", 6), "color": p.get("color", "#ffffff"),
			"orbit": {"cx": bx, "cy": by, "radius": orbit_r, "omega": omega,
			           "until": orbit_dur, "aimAtRelease": aim_at_rel, "releaseSpeed": rel_speed},
			"maxLife": orbit_dur + 6.0,
		})

func _echo(p: Dictionary, ctx: Dictionary) -> void:
	var lookback := float(p.get("lookback", 1.0))
	var t_now    := float(_trail[_trail.size() - 1].t) if _trail.size() > 0 else 0.0
	var ghost    = _trail[0] if _trail.size() > 0 else null
	for pt in _trail:
		if t_now - float(pt.t) <= lookback:
			ghost = pt
			break
	if ghost == null:
		ghost = {"x": ctx.get("bossX", 0), "y": ctx.get("bossY", 0)}
	var tx     := float(ctx.get("targetX", 0))
	var ty     := float(ctx.get("targetY", 0))
	var gx     := float(ghost.x);  var gy := float(ghost.y)
	var dx     := tx - gx;         var dy  := ty - gy
	var speed  := float(p.get("speed",  320))
	var count  := int(p.get("count",   3))
	var spread := float(p.get("spread", 0.18))
	var tel    := float(p.get("telegraph", 0.35))
	var base_a := atan2(dy, dx)
	pool.spawn({"x": gx, "y": gy, "vx": 0, "vy": 0,
	            "radius": 18, "color": p.get("markerColor", "#ffffff"),
	            "delay": tel, "maxLife": tel + 0.05, "tag": "marker"})
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		pool.spawn({"x": gx, "y": gy, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ffffff"),
		            "delay": tel})

func _laser_line(p: Dictionary, ctx: Dictionary) -> void:
	var arena     = ctx.get("arena", {})
	var ax        := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay        := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var orient    : String = p.get("orient",  "h")
	var lanes     := int(p.get("lanes",      1))
	var speed     := float(p.get("speed",    520))
	var telegraph := float(p.get("telegraph", 0.55))
	var bead_cnt  := int(p.get("beadCount",  16))
	var count     := int(p.get("count",      5))
	var radius    := float(p.get("radius",   6))
	for _n in range(lanes):
		var pos: float
		if orient == "h":
			pos = ay + 30.0 + randf() * (ah - 60.0)
		else:
			pos = ax + 30.0 + randf() * (aw - 60.0)
		for i in range(bead_cnt):
			var t  := float(i) / float(bead_cnt - 1)
			var bx := ax + t * aw if orient == "h" else pos
			var by := pos          if orient == "h" else ay + t * ah
			pool.spawn({"x": bx, "y": by, "vx": 0, "vy": 0,
			            "radius": 3, "color": p.get("markerColor", "#ffffff"),
			            "delay": telegraph, "maxLife": telegraph + 0.05, "tag": "marker"})
		var dir_x := 1.0 if orient == "h" else 0.0
		var dir_y := 0.0 if orient == "h" else 1.0
		var sx    := ax - 20.0 if orient == "h" else pos
		var sy    := pos        if orient == "h" else ay - 20.0
		for i in range(count):
			pool.spawn({"x": sx - i*18.0*dir_x, "y": sy - i*18.0*dir_y,
			            "vx": dir_x*speed, "vy": dir_y*speed,
			            "radius": radius, "color": p.get("color", "#ffffff"),
			            "delay": telegraph})

func _stutter_aim(p: Dictionary, ctx: Dictionary) -> void:
	var count  := int(p.get("count",  5))
	var spread := float(p.get("spread", 0.4))
	var speed  := float(p.get("speed", 360))
	var on_t   := float(p.get("onTime",  0.32))
	var off_t  := float(p.get("offTime", 0.22))
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	var dx     := float(ctx.get("targetX", 0)) - bx
	var dy     := float(ctx.get("targetY", 0)) - by
	var base_a := atan2(dy, dx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ffffff"),
		            "stutter": {"onTime": on_t, "offTime": off_t}})

func _split_wave(p: Dictionary, ctx: Dictionary) -> void:
	var count       := int(p.get("count",       4))
	var spread      := float(p.get("spread",    0.7))
	var speed       := float(p.get("speed",     240))
	var split_time  := float(p.get("splitTime", 0.55))
	var child_count := int(p.get("childCount",  5))
	var child_spr   := float(p.get("childSpread", 1.4))
	var child_spd   := float(p.get("childSpeed",  280))
	var bx          := float(ctx.get("bossX", 0))
	var by          := float(ctx.get("bossY", 0))
	var dx          := float(ctx.get("targetX", 0)) - bx
	var dy          := float(ctx.get("targetY", 0)) - by
	var base_a      := atan2(dy, dx)
	for i in range(count):
		var t_   := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a    := base_a + t_ * spread
		var c    := cos(a);  var s := sin(a)
		pool.spawn({"x": bx, "y": by, "vx": c*speed, "vy": s*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#c8ff00"),
		            "maxLife": split_time})
		var sx := bx + c * speed * split_time
		var sy := by + s * speed * split_time
		for k in range(child_count):
			var tk := 0.0 if child_count == 1 else float(k) / float(child_count - 1) - 0.5
			var ca := a + tk * child_spr
			pool.spawn({"x": sx, "y": sy, "vx": cos(ca)*child_spd, "vy": sin(ca)*child_spd,
			            "radius": p.get("childRadius", 5),
			            "color": p.get("childColor", p.get("color", "#c8ff00")),
			            "delay": split_time})

func _pulse_beam(p: Dictionary, ctx: Dictionary) -> void:
	var arena     = ctx.get("arena", {})
	var ax        := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay        := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var orient    : String = p.get("orient", "h")
	var width     := float(p.get("width",  90))
	var speed     := float(p.get("speed",  380))
	var telegraph := float(p.get("telegraph", 0.7))
	var rows      := int(p.get("rows",    3))
	var bprow     := int(p.get("beadsPerRow", 14))
	var bul_row   := int(p.get("bulletsPerRow", 5))
	var radius    := float(p.get("radius", 6))
	var center: float
	if orient == "h":
		center = ay + width / 2.0 + randf() * (ah - width)
	else:
		center = ax + width / 2.0 + randf() * (aw - width)
	for r in range(rows):
		var offset  := (float(r) - float(rows - 1) / 2.0) * (width / float(rows))
		var line_pos := center + offset
		for i in range(bprow):
			var tt := float(i) / float(max(1, bprow - 1))
			var bx_ := ax + tt * aw if orient == "h" else line_pos
			var by_ := line_pos     if orient == "h" else ay + tt * ah
			pool.spawn({"x": bx_, "y": by_, "vx": 0, "vy": 0, "radius": 4,
			            "color": p.get("markerColor", "#c8ff00"),
			            "delay": telegraph, "maxLife": telegraph + 0.05, "tag": "marker"})
		var dir_x := 1.0 if orient == "h" else 0.0
		var dir_y := 0.0 if orient == "h" else 1.0
		var sx_   := ax - 20.0    if orient == "h" else line_pos
		var sy_   := line_pos     if orient == "h" else ay - 20.0
		for i in range(bul_row):
			pool.spawn({"x": sx_ - i*22.0*dir_x, "y": sy_ - i*22.0*dir_y,
			            "vx": dir_x*speed, "vy": dir_y*speed,
			            "radius": radius, "color": p.get("color", "#c8ff00"),
			            "delay": telegraph})

func _tempo_grid(p: Dictionary, ctx: Dictionary) -> void:
	var arena     = ctx.get("arena", {})
	var ax        := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay        := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var cols      := int(p.get("cols",  5))
	var rows      := int(p.get("rows",  4))
	var arms      := int(p.get("arms",  4))
	var speed     := float(p.get("speed", 200))
	var telegraph := float(p.get("telegraph", 0.4))
	var parity    := int(p.get("parity", 0))
	var cell_w    := aw / float(cols)
	var cell_h    := ah / float(rows)
	for r in range(rows):
		for c in range(cols):
			if (r + c) % 2 != parity:
				continue
			var cx_ := ax + (float(c) + 0.5) * cell_w
			var cy_ := ay + (float(r) + 0.5) * cell_h
			pool.spawn({"x": cx_, "y": cy_, "vx": 0, "vy": 0,
			            "radius": p.get("markerRadius", 10), "color": p.get("markerColor", "#c8ff00"),
			            "delay": telegraph, "maxLife": telegraph + 0.05, "tag": "marker"})
			for a_idx in range(arms):
				var a := float(a_idx) / float(arms) * TAU + 0.2 * float(r + c)
				pool.spawn({"x": cx_, "y": cy_, "vx": cos(a)*speed, "vy": sin(a)*speed,
				            "radius": p.get("radius", 6), "color": p.get("color", "#c8ff00"),
				            "delay": telegraph})

func _phase_locked_radial(p: Dictionary, ctx: Dictionary) -> void:
	var count  := int(p.get("count",  24))
	var speed  := float(p.get("speed", 200))
	var offset := float(p.get("rotateWithBeat", false)) * int(ctx.get("beatIndex", 0)) * float(p.get("rotateStep", 0.18))
	var lock   : String = p.get("lockColor", "white")
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	for i in range(count):
		var a := float(i) / float(count) * TAU + offset
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 6), "color": p.get("color", "#ffffff"),
		            "phaseLockColor": lock})

func _phase_locked_aimed(p: Dictionary, ctx: Dictionary) -> void:
	var count  := int(p.get("count",  5))
	var spread := float(p.get("spread", 0.32))
	var speed  := float(p.get("speed", 320))
	var lock   : String = p.get("lockColor", "white")
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	var dx     := float(ctx.get("targetX", 0)) - bx
	var dy     := float(ctx.get("targetY", 0)) - by
	var base_a := atan2(dy, dx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 7), "color": p.get("color", "#ffffff"),
		            "phaseLockColor": lock})

func _tether(p: Dictionary, ctx: Dictionary) -> void:
	var spawn_aux: Callable = ctx.get("spawnAux", Callable())
	var boss_ref  = ctx.get("bossRef")
	if not spawn_aux.is_valid() or boss_ref == null:
		return
	spawn_aux.call(AuxAttacks.TetherAttack.new({
		"boss": boss_ref,
		"duration":     p.get("duration",     1.8),
		"spawnInterval": p.get("spawnInterval", 0.16),
		"bulletSpeed":  p.get("bulletSpeed",  220),
		"color":        p.get("color",        "#c9001f"),
		"radius":       p.get("radius",       6),
	}))

func _gravity_well(p: Dictionary, ctx: Dictionary) -> void:
	var spawn_aux: Callable = ctx.get("spawnAux", Callable())
	if not spawn_aux.is_valid():
		return
	var arena = ctx.get("arena", {})
	var ax    := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay    := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var x_: float;  var y_: float
	if p.has("anchor"):
		var anchors := {"center":[0.5,0.5],"top":[0.5,0.25],"bottom":[0.5,0.75],
		                "left":[0.25,0.5],"right":[0.75,0.5],
		                "topLeft":[0.25,0.25],"topRight":[0.75,0.25],
		                "bottomLeft":[0.25,0.75],"bottomRight":[0.75,0.75]}
		var a_ : Array = anchors.get(p.anchor, [0.5, 0.5])
		x_ = ax + aw * float(a_[0]);  y_ = ay + ah * float(a_[1])
	elif p.get("atPlayer", false):
		x_ = float(ctx.get("targetX", ax + aw*0.5))
		y_ = float(ctx.get("targetY", ay + ah*0.5))
	else:
		x_ = ax + aw * float(p.get("x", 0.5))
		y_ = ay + ah * float(p.get("y", 0.5))
	spawn_aux.call(AuxAttacks.GravityWell.new({
		"x": x_, "y": y_,
		"duration": p.get("duration", 1.6),
		"strength": p.get("strength", 220),
		"radius":   p.get("radius",   240),
		"color":    p.get("color",    "#cdcdd6"),
	}))

func _expanding_radial(p: Dictionary, ctx: Dictionary) -> void:
	var count  := int(p.get("count",   16))
	var speed  := float(p.get("speed", 130))
	var grow   := float(p.get("growRate", 8))
	var offset := float(p.get("rotateWithBeat", false)) * int(ctx.get("beatIndex", 0)) * float(p.get("rotateStep", 0.18))
	var bx     := float(ctx.get("bossX", 0))
	var by     := float(ctx.get("bossY", 0))
	for i in range(count):
		var a := float(i) / float(count) * TAU + offset
		pool.spawn({"x": bx, "y": by, "vx": cos(a)*speed, "vy": sin(a)*speed,
		            "radius": p.get("radius", 4), "color": p.get("color", "#ffe25d"),
		            "growRate": grow, "maxLife": p.get("maxLife", 4)})

# =====================================================================
# SYNTHWAVE-ONLY PATTERNS
# These patterns DO NOT appear in any other world. They use bullet
# behaviors (curve, sine, bounce) unique to synthwave bullets.
# =====================================================================

# NEON ARC: a fan of bullets that CURVE inward toward each other,
# sweeping across the player like neon trails arcing through the arena.
func _sw_arc(p: Dictionary, ctx: Dictionary) -> void:
	var count       := int(p.get("count", 5))
	var spread      := float(p.get("spread", 1.2))   # total arc spread in rad
	var speed       := float(p.get("speed", 220))
	var curve       := float(p.get("curveRate", 1.6))  # rad/sec
	var bx          := float(ctx.get("bossX", 0))
	var by          := float(ctx.get("bossY", 0))
	var tx          := float(ctx.get("targetX", 0))
	var ty          := float(ctx.get("targetY", 0))
	var base_a      := atan2(ty - by, tx - bx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		# Each bullet curves OPPOSITE to its position offset so they converge.
		var rot := -curve * (t * 2.0)
		pool.spawn({"x": bx, "y": by, "vx": cos(a) * speed, "vy": sin(a) * speed,
		            "radius": p.get("radius", 6), "color": p.get("color", "#ff00aa"),
		            "curveRate": rot, "maxLife": 5.0})

# SINE DRIVE: bullets travel in a sine wave, perpendicular to their
# base velocity. Looks like neon trails snaking through the arena.
func _sw_sine(p: Dictionary, ctx: Dictionary) -> void:
	var count       := int(p.get("count", 3))
	var spread      := float(p.get("spread", 0.25))
	var speed       := float(p.get("speed", 200))
	var amp         := float(p.get("sineAmp", 40))
	var freq        := float(p.get("sineFreq", 1.2))
	var bx          := float(ctx.get("bossX", 0))
	var by          := float(ctx.get("bossY", 0))
	var tx          := float(ctx.get("targetX", 0))
	var ty          := float(ctx.get("targetY", 0))
	var base_a      := atan2(ty - by, tx - bx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		pool.spawn({"x": bx, "y": by, "vx": cos(a) * speed, "vy": sin(a) * speed,
		            "radius": p.get("radius", 6), "color": p.get("color", "#00d4ff"),
		            "sineAmp": amp, "sineFreq": freq, "maxLife": 5.0})

# BOUNCER: bullets that bounce N times off the arena walls before despawning.
# Aimed at the player initially; subsequent bounces become unpredictable.
func _sw_bounce(p: Dictionary, ctx: Dictionary) -> void:
	var count       := int(p.get("count", 3))
	var spread      := float(p.get("spread", 0.35))
	var speed       := float(p.get("speed", 240))
	var bounces     := int(p.get("bounces", 2))
	var bx          := float(ctx.get("bossX", 0))
	var by          := float(ctx.get("bossY", 0))
	var tx          := float(ctx.get("targetX", 0))
	var ty          := float(ctx.get("targetY", 0))
	var base_a      := atan2(ty - by, tx - bx)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a := base_a + t * spread
		pool.spawn({"x": bx, "y": by, "vx": cos(a) * speed, "vy": sin(a) * speed,
		            "radius": p.get("radius", 6), "color": p.get("color", "#ff00aa"),
		            "bounce": bounces, "maxLife": 6.0})

# SPEEDLINE: parallel "highway lanes" of fast bullets. Player has to
# find the gap between lanes. Lines either horizontal or vertical.
func _sw_speedline(p: Dictionary, ctx: Dictionary) -> void:
	var arena       = ctx.get("arena", {})
	var ax          := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay          := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var lanes       := int(p.get("lanes", 5))
	var bullets_per := int(p.get("bulletsPerLane", 4))
	var speed       := float(p.get("speed", 420))
	var orient      : String = p.get("orient", "h")
	var gap_lane    := int(p.get("gapLane", -1))   # -1 = random
	if gap_lane < 0:
		gap_lane = randi() % lanes
	for L in range(lanes):
		if L == gap_lane:
			continue
		var pos: float = 0.0
		if orient == "h":
			pos = ay + ah * (float(L) + 0.5) / float(lanes)
		else:
			pos = ax + aw * (float(L) + 0.5) / float(lanes)
		var dir_x := 1.0 if orient == "h" else 0.0
		var dir_y := 0.0 if orient == "h" else 1.0
		var sx0   := ax - 20.0    if orient == "h" else pos
		var sy0   := pos          if orient == "h" else ay - 20.0
		for k in range(bullets_per):
			pool.spawn({"x": sx0 - float(k) * 26.0 * dir_x, "y": sy0 - float(k) * 26.0 * dir_y,
			            "vx": dir_x * speed, "vy": dir_y * speed,
			            "radius": p.get("radius", 6), "color": p.get("color", "#00d4ff")})

# GRID PULSE: spawns bullets along the positions of currently-active
# grid walls, firing outward. Couples the grid mechanic directly to
# the bullet attacks -- when a grid line is up, it's also a bullet source.
# If `bidirectional` is true, fires from BOTH sides of each line so the
# player can never just be "on the other side" of the line to be safe.
func _sw_grid_pulse(p: Dictionary, ctx: Dictionary) -> void:
	var arena       = ctx.get("arena", {})
	var ax          := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay          := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var active_walls = ctx.get("activeWalls", {})
	var per_line    := int(p.get("bulletsPerLine", 8))
	var speed       := float(p.get("speed", 260))
	var bidi: bool  = p.get("bidirectional", false)
	var col         = p.get("color", "#ff00aa")
	var radius      = p.get("radius", 6)
	# Fallback: if no walls active, fire along the arena center cross
	var lines: Array = active_walls.keys() if active_walls.size() > 0 else ["h2", "v1"]
	for line_id in lines:
		if line_id.begins_with("h"):
			var idx: int = int(line_id.substr(1))
			var wy: float = ay + ah * float(idx + 1) / 7.0
			for k in range(per_line):
				var xp: float = ax + aw * (float(k) + 0.5) / float(per_line)
				pool.spawn({"x": xp, "y": wy, "vx": 0, "vy": speed,
				            "radius": radius, "color": col})
				if bidi:
					pool.spawn({"x": xp, "y": wy, "vx": 0, "vy": -speed,
					            "radius": radius, "color": col})
		else:
			var idx: int = int(line_id.substr(1))
			var wx: float = ax + aw * float(idx + 1) / 5.0
			for k in range(per_line):
				var yp: float = ay + ah * (float(k) + 0.5) / float(per_line)
				pool.spawn({"x": wx, "y": yp, "vx": speed, "vy": 0,
				            "radius": radius, "color": col})
				if bidi:
					pool.spawn({"x": wx, "y": yp, "vx": -speed, "vy": 0,
					            "radius": radius, "color": col})

# VECTOR BURST: bullets arranged as a geometric polygon (triangle, hex)
# that rotates and expands outward. Visually distinctive vector look.
func _sw_vector_burst(p: Dictionary, ctx: Dictionary) -> void:
	var sides       := int(p.get("sides", 6))
	var rings       := int(p.get("rings", 3))
	var ring_step   := float(p.get("ringStep", 18))
	var speed       := float(p.get("speed", 200))
	var spin        := float(p.get("spin", 0.18))     # rad offset per ring
	var bx          := float(ctx.get("bossX", 0))
	var by          := float(ctx.get("bossY", 0))
	var col         = p.get("color", "#ff00aa")
	var radius      = p.get("radius", 6)
	for r in range(rings):
		var ang_offset := float(r) * spin
		for s in range(sides):
			var a := float(s) / float(sides) * TAU + ang_offset
			pool.spawn({"x": bx, "y": by, "vx": cos(a) * speed, "vy": sin(a) * speed,
			            "radius": radius, "color": col,
			            "delay": float(r) * 0.08, "maxLife": 5.0})

# =====================================================================
# TECHNO-ONLY PATTERNS
# Bullet behaviors unique to the Techno world (subwoofer ping-pong, 16th-
# note hat texture). Should not be referenced by any other world's bosses.
# =====================================================================

# SUB SLAM: PULSE's signature attack. Border subwoofers fire a WALL of
# bullets that traverse the arena with continuous biased oscillation --
# forward/backward wiggle the whole way. Net motion = bias (forward);
# amplitude controls how pronounced the wiggle is. Defaults are tuned
# to feel like a serious boss move: most of an edge fills with bullets,
# fast forward bias, aggressive wiggle. Despawns naturally on exit.
# Sides: left/right/top/bottom (any axis).
#
# Default tuning: bias 220 px/s, amp 280 px/s -> peak forward 500,
# peak backward -60. ~78% of cycle going forward, 22% backward. Net
# crosses 960px arena in ~4.4 sec, wiggling ~12 times along the way.
func _sub_slam(p: Dictionary, ctx: Dictionary) -> void:
	var arena   = ctx.get("arena", {})
	var ax      := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay      := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var side    : String = p.get("side", "left")
	var count   := int(p.get("count",  7))
	var span    := float(p.get("span",  0.9))
	var bias    := float(p.get("bias",   220))    # net forward speed
	var amp     := float(p.get("amp",    280))    # oscillation amplitude
	var period  := float(p.get("period", 0.35))   # cycle period (sec)
	var radius  := float(p.get("radius", 9))
	var col     = p.get("color", "#00e5ff")

	var ax_x: float = 0.0;  var ax_y: float = 0.0
	match side:
		"left":   ax_x =  1.0
		"right":  ax_x = -1.0
		"top":    ax_y =  1.0
		"bottom": ax_y = -1.0
		_:        ax_x =  1.0

	for i in range(count):
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		t = 0.5 + (t - 0.5) * span
		var sx: float = 0.0;  var sy: float = 0.0
		match side:
			"left":   sx = ax;            sy = ay + ah * t
			"right":  sx = ax + aw;        sy = ay + ah * t
			"top":    sx = ax + aw * t;    sy = ay
			"bottom": sx = ax + aw * t;    sy = ay + ah
			_:        sx = ax;             sy = ay + ah * t
		pool.spawn({
			"x": sx, "y": sy,
			"vx": ax_x * bias, "vy": ax_y * bias,
			"radius": radius, "color": col,
			"ppBias":   bias,
			"ppAmp":    amp,
			"ppPeriod": period,
			"ppAxisX":  ax_x,
			"ppAxisY":  ax_y,
			"maxLife":  10.0,
		})

# TRAIN WALL: lines of bullets ("cars") streaming across the arena from
# a chosen border. Each car is a line of bullets perpendicular to the
# travel direction, with one gap; gap mode controls whether it stays put,
# shifts between cars, or randomizes. Tighter default bullet count means
# in-train spacing is risky to thread but the gap stays passable.
# Sides:
#   "left"/"right"          -> vertical line cars traveling horizontally
#   "top"                   -> horizontal line cars traveling down
#   "both"                  -> left + right simultaneously
#   "diag_tl" / "diag_tr"   -> tilted line cars traveling diagonally
#                              (NW->SE or NE->SW, perpendicular line)
func _train_wall(p: Dictionary, ctx: Dictionary) -> void:
	var arena    = ctx.get("arena", {})
	var ax       := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay       := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var side     : String = p.get("side", "left")
	var cars     := int(p.get("cars", 5))
	var car_step := float(p.get("carStep", 0.38))
	# Higher bullet count = tighter spacing in-train. gap_size scales with
	# bullet count so the player-facing opening remains passable.
	var bullets  := int(p.get("bullets", 11))
	var gap_size := int(p.get("gapSize", 3))
	var gap_mode : String = p.get("gapMode", "shift")
	var speed    := float(p.get("speed", 410))
	var radius   := float(p.get("radius", 7))
	var col      = p.get("color", "#00e5ff")

	var sides_to_fire: Array = []
	match side:
		"both":  sides_to_fire = ["left", "right"]
		_:       sides_to_fire = [side]

	var max_gap_pos: int = maxi(1, bullets - gap_size)

	for s in sides_to_fire:
		var gap_pos: int = randi() % max_gap_pos
		for car in range(cars):
			if gap_mode == "random":
				gap_pos = randi() % max_gap_pos
			elif gap_mode == "shift":
				var delta: int = 1 if randi() % 2 == 0 else -1
				gap_pos = clampi(gap_pos + delta, 0, max_gap_pos - 1)
			_spawn_train_car(s, ax, aw, ay, ah, bullets, gap_pos, gap_size,
			                 speed, radius, col, float(car) * car_step)

# Spawns one "car" -- a line of bullets perpendicular to the travel
# direction, with a gap. Handles all sides including diagonals.
func _spawn_train_car(s: String, ax: float, aw: float, ay: float, ah: float,
                       bullets: int, gap_pos: int, gap_size: int,
                       speed: float, radius: float, col,
                       delay_t: float) -> void:
	var dir_x: float = 0.0
	var dir_y: float = 0.0
	match s:
		"left":    dir_x =  1.0
		"right":   dir_x = -1.0
		"top":     dir_y =  1.0
		"bottom":  dir_y = -1.0
		"diag_tl": dir_x =  0.7071;  dir_y =  0.7071   # travel SE
		"diag_tr": dir_x = -0.7071;  dir_y =  0.7071   # travel SW
	# Perpendicular unit vector (rotate travel 90° CCW): (-dir_y, dir_x)
	var perp_x: float = -dir_y
	var perp_y: float =  dir_x
	# Where the center of the bullet line is at spawn time.
	# For straight sides, the line spans the perpendicular arena dimension.
	# For diagonals, line spans the arena diagonal so coverage holds.
	var line_len: float
	var center_x: float
	var center_y: float
	match s:
		"left":
			line_len = ah
			center_x = ax - 20.0
			center_y = ay + ah * 0.5
		"right":
			line_len = ah
			center_x = ax + aw + 20.0
			center_y = ay + ah * 0.5
		"top":
			line_len = aw
			center_x = ax + aw * 0.5
			center_y = ay - 20.0
		"bottom":
			line_len = aw
			center_x = ax + aw * 0.5
			center_y = ay + ah + 20.0
		"diag_tl":
			line_len = sqrt(aw * aw + ah * ah) * 0.85
			# Spawn line straddles top-left corner area, line is tilted at -45°
			center_x = ax + aw * 0.25
			center_y = ay - 20.0
		"diag_tr":
			line_len = sqrt(aw * aw + ah * ah) * 0.85
			center_x = ax + aw * 0.75
			center_y = ay - 20.0
		_:
			line_len = ah
			center_x = ax
			center_y = ay + ah * 0.5
	var step: float = line_len / float(bullets)
	for b in range(bullets):
		if b >= gap_pos and b < gap_pos + gap_size:
			continue
		var offset: float = (float(b) + 0.5 - float(bullets) * 0.5) * step
		var bx: float = center_x + perp_x * offset
		var by: float = center_y + perp_y * offset
		pool.spawn({
			"x": bx, "y": by,
			"vx": dir_x * speed, "vy": dir_y * speed,
			"radius": radius, "color": col,
			"delay": delay_t,
			"maxLife": 6.0,
		})

# HAT SPRAY: a stream of small, fast bullets aimed at the player's general
# direction, fired at sub-beat intervals (16th notes). Each bullet is chip
# damage; you don't dodge individually, you weave through. Texture, not threat.
func _hat_spray(p: Dictionary, ctx: Dictionary) -> void:
	var count        := int(p.get("count",       8))
	var duration_b   := float(p.get("durationBeats", 2.0))
	var spread       := float(p.get("spread",    0.18))
	var speed        := float(p.get("speed",     320))
	var radius       := float(p.get("radius",    4))
	var col          = p.get("color", "#00e5ff")
	var beat_int     := float(ctx.get("beatInterval", 0.43))
	var step: float  = (duration_b * beat_int) / float(maxi(1, count))
	var bx           := float(ctx.get("bossX", 0))
	var by           := float(ctx.get("bossY", 0))
	var tx           := float(ctx.get("targetX", 0))
	var ty           := float(ctx.get("targetY", 0))
	var base_a       := atan2(ty - by, tx - bx)
	for h in range(count):
		var jitter: float = (randf() - 0.5) * spread
		var a: float = base_a + jitter
		pool.spawn({
			"x": bx, "y": by,
			"vx": cos(a) * speed, "vy": sin(a) * speed,
			"radius": radius, "color": col,
			"delay": float(h) * step,
			"maxLife": 5.0,
		})

# STROBE LINE: Techno-only. A stationary wall of bullets across the arena
# that all stutter on/off in unison. Player picks a moment when the wall
# is "off" and crosses through. Forces timing-based dodging instead of
# gap-finding. Orient h = horizontal wall (bullets along X axis at a Y),
# orient v = vertical wall (bullets along Y axis at an X).
func _strobe_line(p: Dictionary, ctx: Dictionary) -> void:
	var arena    = ctx.get("arena", {})
	var ax       := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay       := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var orient   : String = p.get("orient", "h")
	var pos_frac := float(p.get("pos", 0.5))
	var bullets  := int(p.get("bullets", 16))
	var on_t     := float(p.get("onTime",  0.18))
	var off_t    := float(p.get("offTime", 0.22))
	var life     := float(p.get("maxLife", 3.5))
	var radius   := float(p.get("radius", 7))
	var col      = p.get("color", "#00e5ff")
	if orient == "h":
		var ypos: float = ay + ah * pos_frac
		for i in range(bullets):
			var xp: float = ax + (float(i) + 0.5) * (aw / float(bullets))
			pool.spawn({
				"x": xp, "y": ypos, "vx": 0.0, "vy": 0.0,
				"radius": radius, "color": col,
				"stutter": {"onTime": on_t, "offTime": off_t},
				"maxLife": life,
			})
	else:
		var xpos: float = ax + aw * pos_frac
		for i in range(bullets):
			var yp: float = ay + (float(i) + 0.5) * (ah / float(bullets))
			pool.spawn({
				"x": xpos, "y": yp, "vx": 0.0, "vy": 0.0,
				"radius": radius, "color": col,
				"stutter": {"onTime": on_t, "offTime": off_t},
				"maxLife": life,
			})

# BASS DROP: Techno-only. Telegraphed rings of small dots -- "subwoofer
# cones" that beat to the music. Each drop spawns a marker, holds for the
# telegraph, then drops a RING of small dots at evenly-spaced angles. Each
# dot's distance from the ring center oscillates sinusoidally at the song's
# beat frequency, so the ring breathes outward and back. As the ring
# expands the dots spread apart (longer circumference); as it contracts
# they cluster. Multiple drops in a single event are staggered.
func _bass_drop(p: Dictionary, ctx: Dictionary) -> void:
	var arena    = ctx.get("arena", {})
	var ax       := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay       := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var drops    := int(p.get("drops",       3))
	var dots     := int(p.get("dots",       24))    # dots per ring
	var dot_r    := float(p.get("radius",    5))    # individual dot radius
	var base_r   := float(p.get("baseR",    45))    # ring's base distance from center
	var pulse_amp := float(p.get("pulseAmp", 28))   # distance oscillation amplitude
	var beat_int := float(ctx.get("beatInterval", 0.428))
	var pulse_freq := float(p.get("pulseFreq", 1.0 / beat_int))  # default = song beat
	var life     := float(p.get("maxLife", 3.5))
	var telegraph := float(p.get("telegraph", 0.5))
	var drop_step := float(p.get("dropStep", 0.55))
	var col      = p.get("color", "#00e5ff")
	var inset    := 150.0
	for d in range(drops):
		var dx: float = ax + inset + randf() * (aw - 2.0 * inset)
		var dy: float = ay + inset + randf() * (ah - 2.0 * inset)
		var t_off: float = float(d) * drop_step
		# Telegraph marker at the ring center
		pool.spawn({
			"x": dx, "y": dy, "vx": 0.0, "vy": 0.0,
			"radius": 26.0, "color": col,
			"delay": t_off, "maxLife": telegraph,
			"tag": "marker",
		})
		# Ring of pulsing dots
		for i in range(dots):
			var ang: float = float(i) / float(dots) * TAU
			pool.spawn({
				"x": dx + cos(ang) * base_r,
				"y": dy + sin(ang) * base_r,
				"vx": 0.0, "vy": 0.0,
				"radius": dot_r, "color": col,
				"pulseCx":    dx,
				"pulseCy":    dy,
				"pulseAngle": ang,
				"pulseBaseR": base_r,
				"pulseAmp":   pulse_amp,
				"pulseFreq":  pulse_freq,
				"delay":      t_off + telegraph,
				"maxLife":    life,
			})

# SLOW ZONE: EIEN-only. Spawns a persistent drifting circle that slows
# the player while inside. Lives the entire fight. Drifts erratically via
# Lissajous-style sum of sines.
func _slow_zone(p: Dictionary, ctx: Dictionary) -> void:
	var spawn_aux: Callable = ctx.get("spawnAux", Callable())
	if not spawn_aux.is_valid():
		return
	var arena = ctx.get("arena", {})
	var ax    := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay    := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	spawn_aux.call(AuxAttacks.SlowZone.new({
		"arena":       Rect2(ax, ay, aw, ah),
		"radius":      p.get("radius",     100),
		"color":       p.get("color",      "#5dd6ff"),
		"slowFactor":  p.get("slowFactor", 0.4),
		"driftFreqX":  p.get("driftFreqX",  0.31),
		"driftFreqY":  p.get("driftFreqY",  0.47),
		"driftFreqX2": p.get("driftFreqX2", 0.13),
		"driftFreqY2": p.get("driftFreqY2", 0.19),
		"driftRangeX": p.get("driftRangeX", 0.35),
		"driftRangeY": p.get("driftRangeY", 0.30),
	}))

func _reality_tear(p: Dictionary, ctx: Dictionary) -> void:
	var spawn_aux: Callable = ctx.get("spawnAux", Callable())
	if not spawn_aux.is_valid():
		return
	var arena  = ctx.get("arena", {})
	var ax     := float(arena.get("x", 60));  var aw := float(arena.get("w", 840))
	var ay     := float(arena.get("y", 60));  var ah := float(arena.get("h", 600))
	var orient : String = p.get("orient", "h")
	var x_: float;  var y_: float;  var angle_: float
	if orient == "h":
		angle_ = 0.0
		y_     = ay + ah * float(p.get("y", 0.3 + randf() * 0.4))
		x_     = ax + aw * 0.5
	elif orient == "v":
		angle_ = PI / 2.0
		x_     = ax + aw * float(p.get("x", 0.3 + randf() * 0.4))
		y_     = ay + ah * 0.5
	else:
		angle_ = float(p.get("angle", PI / 4.0))
		x_     = ax + aw * 0.5
		y_     = ay + ah * 0.5
	spawn_aux.call(AuxAttacks.RealityTear.new({
		"x": x_, "y": y_, "angle": angle_,
		"length":       p.get("length",       min(aw, ah) * 0.7),
		"duration":     p.get("duration",     1.4),
		"spawnInterval": p.get("spawnInterval", 0.10),
		"bulletSpeed":  p.get("bulletSpeed",  280),
		"color":        p.get("color",        "#c9001f"),
		"radius":       p.get("radius",       6),
		"beadCount":    p.get("beadCount",    9),
	}))

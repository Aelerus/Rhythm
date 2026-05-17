class_name BulletPool
extends RefCounted

class Bullet extends RefCounted:
	var active:           bool    = false
	var x:                float   = 0.0
	var y:                float   = 0.0
	var vx:               float   = 0.0
	var vy:               float   = 0.0
	var radius:           float   = 6.0
	var base_radius:      float   = 6.0
	var color:            String  = "#ff5dd6"
	var life:             float   = 0.0
	var max_life:         float   = 8.0
	var homing:           float   = 0.0
	var delay:            float   = 0.0
	var orbit             = null  # Dictionary or null
	var accel:            float   = 0.0
	var stutter           = null  # Dictionary or null
	var tag:              String  = ""
	var phase_lock_color: String  = ""
	var grow_rate:        float   = 0.0
	# Synthwave-only behaviors:
	var curve_rate:       float   = 0.0   # rad/sec velocity rotation (curving arc bullets)
	var bounce:           int     = 0     # remaining wall bounces
	var sine_amp:         float   = 0.0   # perpendicular oscillation amplitude (px)
	var sine_freq:        float   = 0.0   # oscillation frequency (Hz)
	var sine_base_dx:     float   = 0.0   # base unit velocity direction
	var sine_base_dy:     float   = 0.0
	var sine_speed:       float   = 0.0   # base speed magnitude

var _pool: Array = []
var active: Array[Bullet] = []

func _init(capacity: int = 1500) -> void:
	_pool.resize(capacity)
	for i in range(capacity):
		_pool[i] = Bullet.new()

func spawn(opts: Dictionary) -> Bullet:
	var b: Bullet = null
	for candidate in _pool:
		if not candidate.active:
			b = candidate
			break
	if b == null:
		return null
	b.active          = true
	b.x               = float(opts.get("x", 0))
	b.y               = float(opts.get("y", 0))
	b.vx              = float(opts.get("vx", 0))
	b.vy              = float(opts.get("vy", 0))
	b.radius          = float(opts.get("radius", 6))
	b.base_radius     = b.radius
	b.color           = opts.get("color", "#ff5dd6")
	b.life            = 0.0
	b.max_life        = float(opts.get("maxLife", 8))
	b.homing          = float(opts.get("homing", 0))
	b.delay           = float(opts.get("delay", 0))
	b.orbit           = opts.get("orbit", null)
	b.accel           = float(opts.get("accel", 0))
	b.stutter         = opts.get("stutter", null)
	b.tag             = opts.get("tag", "")
	b.phase_lock_color = opts.get("phaseLockColor", "")
	b.grow_rate       = float(opts.get("growRate", 0))
	b.curve_rate      = float(opts.get("curveRate", 0))
	b.bounce          = int(opts.get("bounce", 0))
	b.sine_amp        = float(opts.get("sineAmp", 0))
	b.sine_freq       = float(opts.get("sineFreq", 0))
	if b.sine_amp > 0.0:
		var spd: float = sqrt(b.vx * b.vx + b.vy * b.vy)
		b.sine_speed = spd
		if spd > 0.0:
			b.sine_base_dx = b.vx / spd
			b.sine_base_dy = b.vy / spd
	active.append(b)
	return b

func clear() -> void:
	for b in active:
		b.active = false
	active.clear()

func update(dt: float, arena: Rect2, target_x: float, target_y: float) -> void:
	var i := active.size() - 1
	while i >= 0:
		var b: Bullet = active[i]
		b.life += dt

		if b.delay > 0.0:
			b.delay -= dt
			i -= 1
			continue

		# Orbit
		if b.orbit != null and b.life < float(b.orbit.get("until", 0)):
			var o: Dictionary = b.orbit
			var ang := atan2(b.y - float(o.get("cy", 0)), b.x - float(o.get("cx", 0))) + float(o.get("omega", 4.2)) * dt
			var orb_r := float(o.get("radius", 90))
			b.x = float(o.get("cx", 0)) + cos(ang) * orb_r
			b.y = float(o.get("cy", 0)) + sin(ang) * orb_r
			var rel_spd := float(o.get("releaseSpeed", 240))
			var omega_sign: float = sign(float(o.get("omega", 4.2)))
			b.vx = -sin(ang) * abs(rel_spd) * omega_sign
			b.vy =  cos(ang) * abs(rel_spd) * omega_sign
			i -= 1
			continue
		if b.orbit != null and b.life >= float(b.orbit.get("until", 0)):
			if b.orbit.get("aimAtRelease", false):
				var dx := target_x - b.x
				var dy := target_y - b.y
				var dist: float = sqrt(dx*dx + dy*dy)
				if dist > 0.0:
					var sp := float(b.orbit.get("releaseSpeed", 280))
					b.vx = dx / dist * sp
					b.vy = dy / dist * sp
			b.orbit = null

		# Stutter
		if b.stutter != null:
			var on_t  := float(b.stutter.get("onTime",  0.32))
			var off_t := float(b.stutter.get("offTime", 0.22))
			var total := on_t + off_t
			var phase := fmod(b.life, total)
			if phase >= on_t:
				i -= 1
				continue

		# Homing
		if b.homing > 0.0:
			var dx := target_x - b.x
			var dy := target_y - b.y
			var target_angle := atan2(dy, dx)
			var current_angle := atan2(b.vy, b.vx)
			var diff := target_angle - current_angle
			while diff > PI:  diff -= TAU
			while diff < -PI: diff += TAU
			var turn: float = clamp(diff, -b.homing * dt, b.homing * dt)
			var spd  := sqrt(b.vx*b.vx + b.vy*b.vy)
			var new_ang: float = current_angle + turn
			b.vx = cos(new_ang) * spd
			b.vy = sin(new_ang) * spd

		# Acceleration
		if b.accel != 0.0:
			var spd := sqrt(b.vx*b.vx + b.vy*b.vy)
			if spd > 0.0:
				b.vx += (b.vx / spd) * b.accel * dt
				b.vy += (b.vy / spd) * b.accel * dt

		# Curve (rotate velocity over time)
		if b.curve_rate != 0.0:
			var ca: float = cos(b.curve_rate * dt)
			var sa: float = sin(b.curve_rate * dt)
			var nvx: float = b.vx * ca - b.vy * sa
			var nvy: float = b.vx * sa + b.vy * ca
			b.vx = nvx
			b.vy = nvy

		# Sine wave motion -- perpendicular oscillation around base velocity direction
		if b.sine_amp > 0.0 and b.sine_speed > 0.0:
			var perp_dx: float = -b.sine_base_dy
			var perp_dy: float = b.sine_base_dx
			var wave: float = sin(b.life * b.sine_freq * TAU)
			var dwave: float = cos(b.life * b.sine_freq * TAU) * b.sine_freq * TAU
			b.x += (b.sine_base_dx * b.sine_speed + perp_dx * b.sine_amp * dwave) * dt
			b.y += (b.sine_base_dy * b.sine_speed + perp_dy * b.sine_amp * dwave) * dt
		else:
			b.x += b.vx * dt
			b.y += b.vy * dt

		# Wall bounce (synthwave bouncer bullets)
		if b.bounce > 0:
			var left   := arena.position.x
			var right  := arena.position.x + arena.size.x
			var top    := arena.position.y
			var bottom := arena.position.y + arena.size.y
			if b.x < left and b.vx < 0.0:
				b.x = left
				b.vx = -b.vx
				b.bounce -= 1
			elif b.x > right and b.vx > 0.0:
				b.x = right
				b.vx = -b.vx
				b.bounce -= 1
			if b.bounce > 0 and b.y < top and b.vy < 0.0:
				b.y = top
				b.vy = -b.vy
				b.bounce -= 1
			elif b.bounce > 0 and b.y > bottom and b.vy > 0.0:
				b.y = bottom
				b.vy = -b.vy
				b.bounce -= 1

		if b.grow_rate != 0.0:
			b.radius = b.base_radius + b.grow_rate * b.life

		var pad := 60.0
		var off := (b.x < arena.position.x - pad or b.x > arena.position.x + arena.size.x + pad or
					b.y < arena.position.y - pad or b.y > arena.position.y + arena.size.y + pad)
		if off or b.life > b.max_life:
			b.active = false
			active.remove_at(i)

		i -= 1

func collide_with(target_x: float, target_y: float, target_alive: bool, iframes: float,
				  hitbox_r: float, floor_state: String) -> Bullet:
	if not target_alive or iframes > 0.0:
		return null
	for b in active:
		if b.delay > 0.0:
			continue
		if b.orbit != null and b.life < float(b.orbit.get("until", 0)):
			continue
		if b.phase_lock_color != "" and floor_state != "" and b.phase_lock_color != floor_state:
			continue
		var dx := b.x - target_x
		var dy := b.y - target_y
		var rad := hitbox_r + b.radius * 0.6
		if dx*dx + dy*dy < rad*rad:
			return b
	return null

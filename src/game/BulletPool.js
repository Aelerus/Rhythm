// Pooled bullets. Each bullet has position, velocity, radius, color, and an active flag.
// Pool reuses inactive entries to avoid GC churn during dense patterns.
//
// Extended fields (most default to neutral / off):
//   homing      — turn-rate (rad/sec) toward target while > 0
//   delay       — seconds to wait before moving (telegraph)
//   orbit       — { cx, cy, radius, omega, until } — orbit a point until t=until, then release tangentially
//   accel       — px/sec^2 along the current heading (for stutter / accelerating bullets)
//   stutter     — { onTime, offTime } — alternates moving / frozen
//   ghost       — bullet only damages while ghost.armed; visual is dim when disarmed
//   shockOnCenter — fires perpendicular bullets when crossing the screen-center vertical line
//   tag         — opaque string for renderer/inversion logic (e.g. "ignore_inversion")

export class Bullet {
  constructor() {
    this.active = false;
    this.x = 0; this.y = 0;
    this.vx = 0; this.vy = 0;
    this.radius = 6;
    this.color = "#ff5dd6";
    this.life = 0;
    this.maxLife = 8;
    this.homing = 0;
    this.delay = 0;
    this.orbit = null;
    this.accel = 0;
    this.stutter = null;
    this._stutterPhase = 0;
    this.tag = null;
  }
}

export class BulletPool {
  constructor(capacity = 1500) {
    this.pool = Array.from({ length: capacity }, () => new Bullet());
    this.active = [];
  }

  spawn(opts) {
    let b = null;
    for (const candidate of this.pool) {
      if (!candidate.active) { b = candidate; break; }
    }
    if (!b) return null;
    b.active = true;
    b.x = opts.x; b.y = opts.y;
    b.vx = opts.vx ?? 0; b.vy = opts.vy ?? 0;
    b.radius = opts.radius ?? 6;
    b.color = opts.color ?? "#ff5dd6";
    b.life = 0;
    b.maxLife = opts.maxLife ?? 8;
    b.homing = opts.homing ?? 0;
    b.delay = opts.delay ?? 0;
    b.orbit = opts.orbit ?? null;
    b.accel = opts.accel ?? 0;
    b.stutter = opts.stutter ?? null;
    b._stutterPhase = 0;
    b.tag = opts.tag ?? null;
    this.active.push(b);
    return b;
  }

  clear() {
    for (const b of this.active) b.active = false;
    this.active.length = 0;
  }

  update(dt, arena, target) {
    for (let i = this.active.length - 1; i >= 0; i--) {
      const b = this.active[i];
      b.life += dt;

      // Telegraph delay: bullet sits still and visible
      if (b.delay > 0) {
        b.delay -= dt;
        continue;
      }

      // Orbit: bullet travels in a circle around (cx,cy) until release time
      if (b.orbit && b.life < b.orbit.until) {
        const o = b.orbit;
        const ang = Math.atan2(b.y - o.cy, b.x - o.cx) + o.omega * dt;
        b.x = o.cx + Math.cos(ang) * o.radius;
        b.y = o.cy + Math.sin(ang) * o.radius;
        // Velocity is tangent to circle (used at release time)
        b.vx = -Math.sin(ang) * Math.abs(o.releaseSpeed ?? 240) * Math.sign(o.omega);
        b.vy =  Math.cos(ang) * Math.abs(o.releaseSpeed ?? 240) * Math.sign(o.omega);
        continue;
      }
      if (b.orbit && b.life >= b.orbit.until) {
        // Release: aim at player if requested
        if (b.orbit.aimAtRelease && target) {
          const dx = target.x - b.x, dy = target.y - b.y;
          const len = Math.hypot(dx, dy) || 1;
          const sp = b.orbit.releaseSpeed ?? 280;
          b.vx = (dx / len) * sp;
          b.vy = (dy / len) * sp;
        }
        b.orbit = null;
      }

      // Stutter: toggle between moving & frozen
      if (b.stutter) {
        const total = b.stutter.onTime + b.stutter.offTime;
        const phase = (b.life % total);
        if (phase >= b.stutter.onTime) {
          // Frozen
          continue;
        }
      }

      // Homing
      if (b.homing && target) {
        const dx = target.x - b.x;
        const dy = target.y - b.y;
        const targetAngle = Math.atan2(dy, dx);
        const currentAngle = Math.atan2(b.vy, b.vx);
        let diff = targetAngle - currentAngle;
        while (diff > Math.PI) diff -= 2 * Math.PI;
        while (diff < -Math.PI) diff += 2 * Math.PI;
        const turn = Math.max(-b.homing * dt, Math.min(b.homing * dt, diff));
        const speed = Math.hypot(b.vx, b.vy);
        const newAngle = currentAngle + turn;
        b.vx = Math.cos(newAngle) * speed;
        b.vy = Math.sin(newAngle) * speed;
      }

      // Accelerate along current heading
      if (b.accel) {
        const speed = Math.hypot(b.vx, b.vy) || 1;
        const ax = (b.vx / speed) * b.accel * dt;
        const ay = (b.vy / speed) * b.accel * dt;
        b.vx += ax;
        b.vy += ay;
      }

      b.x += b.vx * dt;
      b.y += b.vy * dt;

      const pad = 60;
      const off =
        b.x < arena.x - pad || b.x > arena.x + arena.w + pad ||
        b.y < arena.y - pad || b.y > arena.y + arena.h + pad;

      if (off || b.life > b.maxLife) {
        b.active = false;
        this.active.splice(i, 1);
      }
    }
  }

  collideWith(target) {
    if (!target.alive || target.iframes > 0) return null;
    const r = target.hitboxRadius;
    for (const b of this.active) {
      // Telegraph bullets and orbiting bullets don't damage yet
      if (b.delay > 0) continue;
      if (b.orbit && b.life < b.orbit.until) continue;
      const dx = b.x - target.x;
      const dy = b.y - target.y;
      const rad = r + b.radius * 0.6;
      if (dx * dx + dy * dy < rad * rad) return b;
    }
    return null;
  }
}

// Pooled bullets. Each bullet has position, velocity, radius, color, and an active flag.
// Pool reuses inactive entries to avoid GC churn during dense patterns.

export class Bullet {
  constructor() {
    this.active = false;
    this.x = 0; this.y = 0;
    this.vx = 0; this.vy = 0;
    this.radius = 6;
    this.color = "#ff5dd6";
    this.life = 0;          // seconds since spawn
    this.maxLife = 8;
    this.homing = 0;        // 0 = no homing, otherwise turn-rate (rad/sec)
  }
}

export class BulletPool {
  constructor(capacity = 1024) {
    this.pool = Array.from({ length: capacity }, () => new Bullet());
    this.active = [];
  }

  spawn(opts) {
    let b = null;
    for (const candidate of this.pool) {
      if (!candidate.active) { b = candidate; break; }
    }
    if (!b) return null; // pool exhausted
    b.active = true;
    b.x = opts.x; b.y = opts.y;
    b.vx = opts.vx; b.vy = opts.vy;
    b.radius = opts.radius ?? 6;
    b.color = opts.color ?? "#ff5dd6";
    b.life = 0;
    b.maxLife = opts.maxLife ?? 8;
    b.homing = opts.homing ?? 0;
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
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life += dt;

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

  // Circle-circle collision against a target {x, y, hitboxRadius}.
  collideWith(target) {
    if (!target.alive || target.iframes > 0) return null;
    const r = target.hitboxRadius;
    for (const b of this.active) {
      const dx = b.x - target.x;
      const dy = b.y - target.y;
      const rad = r + b.radius * 0.6;
      if (dx * dx + dy * dy < rad * rad) return b;
    }
    return null;
  }
}

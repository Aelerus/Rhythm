// Stateful "aux" attacks that don't fit the simple bullet model:
//   - Tether:     a beam from the boss to the player that bleeds bullets along it
//   - GravityWell: a swirling point that pulls the player toward it
//   - RealityTear: a stationary line that pumps bullets perpendicular to itself
//
// Each has update(dt, ctx) and render(ctx, ctx2). They self-mark `dead = true`
// when their lifetime expires; the FightManager prunes dead ones each frame.

export class TetherAttack {
  constructor(opts) {
    this.boss = opts.boss; // { x, y } reference object (live)
    this.lifetime = opts.duration ?? 1.8;
    this.elapsed = 0;
    this._spawnTimer = 0.45; // initial telegraph delay before bullets begin
    this.spawnInterval = opts.spawnInterval ?? 0.16;
    this.bulletSpeed = opts.bulletSpeed ?? 220;
    this.bulletColor = opts.color ?? "#c9001f";
    this.bulletRadius = opts.radius ?? 6;
    this.dead = false;
    // Cached endpoint so bullets fire toward where the player WAS at this beat.
    // The visible beam re-targets each frame for visual feedback, but bullets
    // commit at their spawn moment so the player can always escape by moving.
  }

  update(dt, player, pool) {
    this.elapsed += dt;
    this.lifetime -= dt;
    if (this.lifetime <= 0) { this.dead = true; return; }

    this._spawnTimer -= dt;
    if (this._spawnTimer <= 0) {
      this._spawnTimer = this.spawnInterval;
      const dx = player.x - this.boss.x;
      const dy = player.y - this.boss.y;
      const len = Math.hypot(dx, dy) || 1;
      pool.spawn({
        x: this.boss.x, y: this.boss.y,
        vx: (dx / len) * this.bulletSpeed,
        vy: (dy / len) * this.bulletSpeed,
        radius: this.bulletRadius,
        color: this.bulletColor,
        maxLife: 4,
      });
    }
  }

  render(ctx, player) {
    // Pulse intensity over the tether's life — quiet at start (telegraph),
    // loud during the spawn-active phase.
    const t = this.elapsed;
    const telegraph = Math.min(1, t / 0.45);
    const pulse = 0.6 + 0.4 * Math.sin(t * 16);

    ctx.save();
    // Wide soft halo
    ctx.globalAlpha = 0.18 * telegraph * pulse;
    ctx.shadowColor = this.bulletColor;
    ctx.shadowBlur = 22;
    ctx.strokeStyle = this.bulletColor;
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.moveTo(this.boss.x, this.boss.y);
    ctx.lineTo(player.x, player.y);
    ctx.stroke();
    // Tighter beam
    ctx.globalAlpha = 0.55 * telegraph;
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(this.boss.x, this.boss.y);
    ctx.lineTo(player.x, player.y);
    ctx.stroke();
    // Bright core
    ctx.globalAlpha = 0.95 * telegraph;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(this.boss.x, this.boss.y);
    ctx.lineTo(player.x, player.y);
    ctx.stroke();
    ctx.restore();
  }
}

export class GravityWell {
  constructor(opts) {
    this.x = opts.x;
    this.y = opts.y;
    this.lifetime = opts.duration ?? 1.6;
    this.elapsed = 0;
    this.strength = opts.strength ?? 220;   // px/sec applied at well center, falls off with distance
    this.radius = opts.radius ?? 240;       // effect radius (px)
    this.color = opts.color ?? "#c0c0c8";
    this.dead = false;
  }

  update(dt, player) {
    this.elapsed += dt;
    this.lifetime -= dt;
    if (this.lifetime <= 0) { this.dead = true; return; }
    // Don't pull during the first 0.4s — that's the telegraph window.
    if (this.elapsed < 0.4) return;
    const dx = this.x - player.x;
    const dy = this.y - player.y;
    const dist = Math.hypot(dx, dy);
    if (dist > this.radius || dist < 8) return;
    const falloff = 1 - dist / this.radius;
    const ax = (dx / dist) * this.strength * falloff * dt;
    const ay = (dy / dist) * this.strength * falloff * dt;
    player.x += ax;
    player.y += ay;
    // Re-clamp to arena
    const a = player.arena;
    const pad = player.radius;
    if (player.x < a.x + pad) player.x = a.x + pad;
    if (player.x > a.x + a.w - pad) player.x = a.x + a.w - pad;
    if (player.y < a.y + pad) player.y = a.y + pad;
    if (player.y > a.y + a.h - pad) player.y = a.y + a.h - pad;
  }

  render(ctx) {
    const t = this.elapsed;
    const telegraph = Math.min(1, t / 0.4);
    ctx.save();
    ctx.translate(this.x, this.y);
    // Outer halo
    ctx.globalAlpha = 0.22 * telegraph;
    ctx.shadowColor = this.color;
    ctx.shadowBlur = 20;
    ctx.fillStyle = this.color;
    ctx.beginPath();
    ctx.arc(0, 0, this.radius * 0.95, 0, Math.PI * 2);
    ctx.fill();
    // Spinning galaxy arms
    const armCount = 5;
    for (let i = 0; i < armCount; i++) {
      const phase = t * 4 + i * (Math.PI * 2 / armCount);
      ctx.globalAlpha = 0.55 * telegraph;
      ctx.strokeStyle = this.color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let r = 8; r < this.radius; r += 5) {
        const a = phase + r * 0.04;
        const x = Math.cos(a) * r;
        const y = Math.sin(a) * r;
        if (r === 8) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }
    // Bright pulsating core
    ctx.shadowBlur = 16;
    ctx.globalAlpha = 0.9 * telegraph;
    ctx.fillStyle = "#ffffff";
    ctx.beginPath();
    ctx.arc(0, 0, 8 + 3 * Math.sin(t * 18), 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

export class RealityTear {
  // A stationary line in the arena that emits bullets perpendicularly for the
  // duration. Telegraphs as a thin glowing seam first, then the seam "tears"
  // open and bullets pour out both sides.
  constructor(opts) {
    this.x = opts.x;            // center of the tear (pixel coords)
    this.y = opts.y;
    this.length = opts.length ?? 380;
    this.angle = opts.angle ?? 0; // radians; 0 = horizontal seam
    this.lifetime = opts.duration ?? 1.4;
    this.elapsed = 0;
    this.spawnInterval = opts.spawnInterval ?? 0.10;
    this._spawnTimer = 0.55; // telegraph window before first emit
    this.bulletSpeed = opts.bulletSpeed ?? 280;
    this.bulletColor = opts.color ?? "#c9001f";
    this.bulletRadius = opts.radius ?? 6;
    this.beadCount = opts.beadCount ?? 9;
    this.dead = false;
  }

  update(dt, _player, pool) {
    this.elapsed += dt;
    this.lifetime -= dt;
    if (this.lifetime <= 0) { this.dead = true; return; }
    if (this.elapsed < 0.55) return; // telegraph window

    this._spawnTimer -= dt;
    if (this._spawnTimer <= 0) {
      this._spawnTimer = this.spawnInterval;
      // Emit perpendicular bullets out both sides at evenly-spaced points along the seam.
      const cos = Math.cos(this.angle), sin = Math.sin(this.angle);
      const px = -sin, py = cos; // perpendicular unit
      for (let i = 0; i < this.beadCount; i++) {
        const t = i / (this.beadCount - 1) - 0.5; // -0.5..0.5
        const sx = this.x + cos * (t * this.length);
        const sy = this.y + sin * (t * this.length);
        // +perpendicular
        pool.spawn({
          x: sx, y: sy,
          vx:  px * this.bulletSpeed, vy:  py * this.bulletSpeed,
          radius: this.bulletRadius, color: this.bulletColor,
        });
        // -perpendicular
        pool.spawn({
          x: sx, y: sy,
          vx: -px * this.bulletSpeed, vy: -py * this.bulletSpeed,
          radius: this.bulletRadius, color: this.bulletColor,
        });
      }
    }
  }

  render(ctx) {
    const t = this.elapsed;
    const telegraphProgress = Math.min(1, t / 0.55);
    const open = t > 0.55;
    const cos = Math.cos(this.angle), sin = Math.sin(this.angle);
    const x1 = this.x - cos * this.length / 2;
    const y1 = this.y - sin * this.length / 2;
    const x2 = this.x + cos * this.length / 2;
    const y2 = this.y + sin * this.length / 2;

    ctx.save();
    if (!open) {
      // Telegraph: a thin glowing seam pulsing
      ctx.globalAlpha = 0.55 * telegraphProgress;
      ctx.shadowColor = this.bulletColor;
      ctx.shadowBlur = 14;
      ctx.strokeStyle = this.bulletColor;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    } else {
      // Open: tear is visibly fractured (jagged double-line with offset)
      const wobble = 4 + Math.sin(t * 30) * 1.5;
      ctx.shadowColor = this.bulletColor;
      ctx.shadowBlur = 22;
      ctx.strokeStyle = this.bulletColor;
      ctx.lineWidth = 4;
      ctx.globalAlpha = 0.8;
      // Top edge of tear
      ctx.beginPath();
      const px = -sin, py = cos;
      ctx.moveTo(x1 + px * wobble, y1 + py * wobble);
      ctx.lineTo(x2 + px * wobble, y2 + py * wobble);
      ctx.stroke();
      // Bottom edge of tear
      ctx.beginPath();
      ctx.moveTo(x1 - px * wobble, y1 - py * wobble);
      ctx.lineTo(x2 - px * wobble, y2 - py * wobble);
      ctx.stroke();
      // Centerline (brightest)
      ctx.lineWidth = 1.5;
      ctx.globalAlpha = 1;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    }
    ctx.restore();
  }
}

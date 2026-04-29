// Reads pattern definitions and spawns bullets.
// Patterns are pure data: {type, count, speed, ...}. Engine knows how to interpret each type.

export class PatternEngine {
  constructor(bulletPool, patternLibrary) {
    this.pool = bulletPool;
    this.library = patternLibrary; // map: id -> pattern data
  }

  fire(patternId, ctx) {
    // ctx provides: boss {x,y}, target {x,y}, beatIndex
    const pattern = this.library[patternId];
    if (!pattern) {
      console.warn(`PatternEngine: unknown pattern '${patternId}'`);
      return;
    }
    switch (pattern.type) {
      case "radial_burst": this._radial(pattern, ctx); break;
      case "aimed_shot":   this._aimed(pattern, ctx); break;
      case "spiral":       this._spiral(pattern, ctx); break;
      case "wall":         this._wall(pattern, ctx); break;
      case "cross":        this._cross(pattern, ctx); break;
      case "homing":       this._homing(pattern, ctx); break;
      case "rain":         this._rain(pattern, ctx); break;
      case "converging":   this._converging(pattern, ctx); break;
      default:
        console.warn(`PatternEngine: unhandled pattern type '${pattern.type}'`);
    }
  }

  // Bullets spawn at random x-positions along the top of the arena and fall straight down.
  // Unpredictable, no telegraph — punishes camping the bottom edge.
  _rain(p, ctx) {
    const arena = ctx.arena;
    const count = p.count ?? 12;
    const speed = p.speed ?? 260;
    for (let i = 0; i < count; i++) {
      const x = arena.x + 20 + Math.random() * (arena.w - 40);
      this.pool.spawn({
        x, y: arena.y - 15,
        vx: 0, vy: speed,
        radius: p.radius ?? 7, color: p.color ?? "#ff5d6d"
      });
    }
  }

  // Bullets spawn at random points around the arena perimeter and converge toward
  // the player's position at the moment of firing — a closing crossfire.
  _converging(p, ctx) {
    const arena = ctx.arena;
    const count = p.count ?? 10;
    const speed = p.speed ?? 270;
    const inset = 8;
    for (let i = 0; i < count; i++) {
      // Pick a random perimeter point.
      const side = Math.floor(Math.random() * 4);
      let sx, sy;
      switch (side) {
        case 0: sx = arena.x + Math.random() * arena.w; sy = arena.y - inset; break;
        case 1: sx = arena.x + arena.w + inset; sy = arena.y + Math.random() * arena.h; break;
        case 2: sx = arena.x + Math.random() * arena.w; sy = arena.y + arena.h + inset; break;
        default: sx = arena.x - inset; sy = arena.y + Math.random() * arena.h; break;
      }
      const dx = ctx.target.x - sx;
      const dy = ctx.target.y - sy;
      const len = Math.hypot(dx, dy) || 1;
      this.pool.spawn({
        x: sx, y: sy,
        vx: (dx / len) * speed, vy: (dy / len) * speed,
        radius: p.radius ?? 7, color: p.color ?? "#ff3a55"
      });
    }
  }

  _radial(p, ctx) {
    const count = p.count ?? 16;
    const speed = p.speed ?? 180;
    const offset = (p.rotateWithBeat ? ctx.beatIndex * (p.rotateStep ?? 0.2) : 0);
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + offset;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 7, color: p.color ?? "#ff5dd6"
      });
    }
  }

  _aimed(p, ctx) {
    const speed = p.speed ?? 280;
    const count = p.count ?? 1;
    const spread = p.spread ?? 0; // total spread radians for fan
    const dx = ctx.target.x - ctx.boss.x;
    const dy = ctx.target.y - ctx.boss.y;
    const baseAngle = Math.atan2(dy, dx);
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1) - 0.5;
      const angle = baseAngle + t * spread;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 8, color: p.color ?? "#ffd25d"
      });
    }
  }

  _spiral(p, ctx) {
    const arms = p.arms ?? 3;
    const count = p.count ?? 6; // bullets per arm in this single fire
    const speed = p.speed ?? 200;
    const armOffset = (ctx.beatIndex % 360) * (p.rotateStep ?? 0.18);
    for (let a = 0; a < arms; a++) {
      const armAngle = (a / arms) * Math.PI * 2 + armOffset;
      for (let i = 0; i < count; i++) {
        const angle = armAngle + i * 0.06;
        this.pool.spawn({
          x: ctx.boss.x, y: ctx.boss.y,
          vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
          radius: p.radius ?? 6, color: p.color ?? "#5dd6ff"
        });
      }
    }
  }

  _wall(p, ctx) {
    // Horizontal wall above arena, with a gap
    const arena = ctx.arena;
    const count = p.count ?? 16;
    const speed = p.speed ?? 220;
    const gapStart = Math.floor(Math.random() * (count - 3));
    const gapWidth = p.gapWidth ?? 3;
    for (let i = 0; i < count; i++) {
      if (i >= gapStart && i < gapStart + gapWidth) continue;
      const x = arena.x + (i + 0.5) * (arena.w / count);
      this.pool.spawn({
        x, y: arena.y - 20,
        vx: 0, vy: speed,
        radius: p.radius ?? 8, color: p.color ?? "#a05dff"
      });
    }
  }

  _cross(p, ctx) {
    const speed = p.speed ?? 240;
    const offset = (ctx.beatIndex % 4) * (Math.PI / 8);
    for (let i = 0; i < 4; i++) {
      const angle = (i / 4) * Math.PI * 2 + offset;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 10, color: p.color ?? "#ff8a5d"
      });
    }
  }

  _homing(p, ctx) {
    const count = p.count ?? 3;
    const speed = p.speed ?? 140;
    const turnRate = p.turnRate ?? 1.4;
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 7, color: p.color ?? "#5dffae",
        homing: turnRate, maxLife: 6
      });
    }
  }
}

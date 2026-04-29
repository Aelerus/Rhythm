// Reads pattern definitions and spawns bullets.
// Patterns are pure data: {type, count, speed, ...}. Engine knows how to interpret each type.

import { TetherAttack, GravityWell, RealityTear } from "./AuxAttacks.js";

export class PatternEngine {
  constructor(bulletPool, patternLibrary) {
    this.pool = bulletPool;
    this.library = patternLibrary; // map: id -> pattern data
    // Player-position trail for mirror_path patterns (sampled by FightManager).
    this._trail = []; // [{ x, y, t }]
  }

  // Called by FightManager every frame so mirror_path can read recent positions.
  recordPlayerTrail(player, t) {
    this._trail.push({ x: player.x, y: player.y, t });
    // Keep only last 4 seconds.
    while (this._trail.length && t - this._trail[0].t > 4) this._trail.shift();
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
      case "mirror_path":  this._mirrorPath(pattern, ctx); break;
      case "arena_burst":  this._arenaBurst(pattern, ctx); break;
      case "vortex":       this._vortex(pattern, ctx); break;
      case "echo":         this._echo(pattern, ctx); break;
      case "laser_line":   this._laserLine(pattern, ctx); break;
      case "stutter_aim":  this._stutterAim(pattern, ctx); break;
      case "phase_locked_radial": this._phaseLockedRadial(pattern, ctx); break;
      case "phase_locked_aimed":  this._phaseLockedAimed(pattern, ctx); break;
      case "tether":              this._tether(pattern, ctx); break;
      case "gravity_well":        this._gravityWell(pattern, ctx); break;
      case "expanding_radial":    this._expandingRadial(pattern, ctx); break;
      case "reality_tear":        this._realityTear(pattern, ctx); break;
      default:
        console.warn(`PatternEngine: unhandled pattern type '${pattern.type}'`);
    }
  }

  // ─── Phase 2 + Phase 3 unique mechanics ───────────────────────────────

  // A radial burst whose bullets only damage during a specific floor color.
  // Phase 1's inversion mechanic becomes a literal weapon.
  _phaseLockedRadial(p, ctx) {
    const count = p.count ?? 24;
    const speed = p.speed ?? 200;
    const offset = (p.rotateWithBeat ? ctx.beatIndex * (p.rotateStep ?? 0.18) : 0);
    const lock = p.lockColor ?? "white";
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + offset;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 6,
        color: p.color ?? "#ffffff",
        phaseLockColor: lock,
      });
    }
  }

  // Aimed shot whose bullets only damage during a specific floor color.
  _phaseLockedAimed(p, ctx) {
    const count = p.count ?? 5;
    const spread = p.spread ?? 0.32;
    const speed = p.speed ?? 320;
    const lock = p.lockColor ?? "white";
    const dx = ctx.target.x - ctx.boss.x;
    const dy = ctx.target.y - ctx.boss.y;
    const baseAngle = Math.atan2(dy, dx);
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1) - 0.5;
      const angle = baseAngle + t * spread;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 7,
        color: p.color ?? "#ffffff",
        phaseLockColor: lock,
      });
    }
  }

  // Tether — beam from the boss to the player that bleeds bullets along it.
  _tether(p, ctx) {
    if (!ctx.spawnAux || !ctx.bossRef) return;
    ctx.spawnAux(new TetherAttack({
      boss: ctx.bossRef,
      duration: p.duration ?? 1.8,
      spawnInterval: p.spawnInterval ?? 0.16,
      bulletSpeed: p.bulletSpeed ?? 220,
      color: p.color ?? "#c9001f",
      radius: p.radius ?? 6,
    }));
  }

  // Gravity well — pulls the player toward a fixed arena point.
  _gravityWell(p, ctx) {
    if (!ctx.spawnAux) return;
    const A = ctx.arena;
    let x, y;
    if (p.anchor) {
      const anchors = {
        center: [0.5, 0.5], top: [0.5, 0.25], bottom: [0.5, 0.75],
        left: [0.25, 0.5], right: [0.75, 0.5],
        topLeft: [0.25, 0.25], topRight: [0.75, 0.25],
        bottomLeft: [0.25, 0.75], bottomRight: [0.75, 0.75],
      };
      const a = anchors[p.anchor] ?? [0.5, 0.5];
      x = A.x + A.w * a[0]; y = A.y + A.h * a[1];
    } else if (p.atPlayer) {
      // Spawn the well AT the player's current position — punishes camping.
      x = ctx.target.x; y = ctx.target.y;
    } else {
      x = A.x + A.w * (p.x ?? 0.5);
      y = A.y + A.h * (p.y ?? 0.5);
    }
    ctx.spawnAux(new GravityWell({
      x, y,
      duration: p.duration ?? 1.6,
      strength: p.strength ?? 220,
      radius: p.radius ?? 240,
      color: p.color ?? "#cdcdd6",
    }));
  }

  // Expanding-radial — radial burst whose bullets grow over their lifetime.
  _expandingRadial(p, ctx) {
    const count = p.count ?? 16;
    const speed = p.speed ?? 130;
    const grow = p.growRate ?? 8;
    const offset = (p.rotateWithBeat ? ctx.beatIndex * (p.rotateStep ?? 0.18) : 0);
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + offset;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        radius: p.radius ?? 4,
        color: p.color ?? "#ffe25d",
        growRate: grow,
        maxLife: p.maxLife ?? 4,
      });
    }
  }

  // Reality tear — stationary line that bleeds bullets perpendicularly.
  _realityTear(p, ctx) {
    if (!ctx.spawnAux) return;
    const A = ctx.arena;
    const orient = p.orient ?? "h"; // 'h' | 'v' | 'd' (diagonal)
    let x = A.x + A.w * 0.5, y = A.y + A.h * 0.5, angle = 0;
    if (orient === "h") {
      angle = 0;
      y = A.y + A.h * (p.y ?? (0.3 + Math.random() * 0.4));
    } else if (orient === "v") {
      angle = Math.PI / 2;
      x = A.x + A.w * (p.x ?? (0.3 + Math.random() * 0.4));
    } else {
      angle = (p.angle ?? Math.PI / 4);
    }
    ctx.spawnAux(new RealityTear({
      x, y, angle,
      length: p.length ?? Math.min(A.w, A.h) * 0.7,
      duration: p.duration ?? 1.4,
      spawnInterval: p.spawnInterval ?? 0.10,
      bulletSpeed: p.bulletSpeed ?? 280,
      color: p.color ?? "#c9001f",
      radius: p.radius ?? 6,
      beadCount: p.beadCount ?? 9,
    }));
  }

  // ─── APEX-tier unique patterns ─────────────────────────────────────────

  // Bullets spawn along the player's recent movement path, traveling toward
  // the player's current position at low speed. Punishes predictable movement.
  _mirrorPath(p, ctx) {
    const count = p.count ?? 6;
    const speed = p.speed ?? 200;
    if (this._trail.length < 2) {
      // Fallback: spawn from boss aimed at player
      this._aimed(p, ctx);
      return;
    }
    // Sample evenly over the trail (oldest → newest)
    for (let i = 0; i < count; i++) {
      const idx = Math.floor((i / (count - 1 || 1)) * (this._trail.length - 1));
      const pt = this._trail[idx];
      const dx = ctx.target.x - pt.x;
      const dy = ctx.target.y - pt.y;
      const len = Math.hypot(dx, dy) || 1;
      this.pool.spawn({
        x: pt.x, y: pt.y,
        vx: (dx / len) * speed, vy: (dy / len) * speed,
        radius: p.radius ?? 6, color: p.color ?? "#ffffff",
        delay: p.telegraph ?? 0.25,
      });
    }
  }

  // Bullets erupt FROM the arena floor at random positions: telegraph circle
  // (delay), then explode outward in N directions. Inverted bullet hell.
  _arenaBurst(p, ctx) {
    const arena = ctx.arena;
    const sites = p.sites ?? 4;
    const arms = p.arms ?? 6;
    const speed = p.speed ?? 240;
    const telegraph = p.telegraph ?? 0.45;
    const inset = 40;
    for (let s = 0; s < sites; s++) {
      const cx = arena.x + inset + Math.random() * (arena.w - 2 * inset);
      const cy = arena.y + inset + Math.random() * (arena.h - 2 * inset);
      // Telegraph: a non-damaging "marker" bullet that disappears at the burst time
      this.pool.spawn({
        x: cx, y: cy, vx: 0, vy: 0,
        radius: p.markerRadius ?? 14,
        color: p.markerColor ?? "#ffffff",
        delay: telegraph, maxLife: telegraph + 0.05,
        tag: "marker",
      });
      // Burst bullets — also telegraphed, so they appear AT the moment the marker dies
      for (let a = 0; a < arms; a++) {
        const angle = (a / arms) * Math.PI * 2 + (s * 0.13);
        this.pool.spawn({
          x: cx, y: cy,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          radius: p.radius ?? 7, color: p.color ?? "#ffffff",
          delay: telegraph,
        });
      }
    }
  }

  // Vortex: bullets orbit the boss for `orbitBeats` worth of time, then release
  // outward (optionally aimed at the player at release).
  _vortex(p, ctx) {
    const count = p.count ?? 14;
    const orbitDur = p.orbitDur ?? 0.9; // seconds before release
    const orbitR = p.orbitRadius ?? 90;
    const omega = (p.omega ?? 4.2) * (p.reverse ? -1 : 1);
    const releaseSpeed = p.releaseSpeed ?? 280;
    const aim = p.aimAtRelease !== false;
    for (let i = 0; i < count; i++) {
      const a = (i / count) * Math.PI * 2;
      this.pool.spawn({
        x: ctx.boss.x + Math.cos(a) * orbitR,
        y: ctx.boss.y + Math.sin(a) * orbitR,
        radius: p.radius ?? 6, color: p.color ?? "#ffffff",
        orbit: {
          cx: ctx.boss.x, cy: ctx.boss.y,
          radius: orbitR, omega,
          until: orbitDur,
          aimAtRelease: aim,
          releaseSpeed,
        },
        maxLife: orbitDur + 6,
      });
    }
  }

  // Echo: spawn a "ghost" of where the player WAS `lookback` seconds ago,
  // then fire an aimed shot from there toward the player's CURRENT position.
  // Punishes camping — stay still and your past self shoots you.
  _echo(p, ctx) {
    const lookback = p.lookback ?? 1.0;
    const tNow = (this._trail[this._trail.length - 1]?.t) ?? 0;
    let ghost = this._trail[0];
    for (const pt of this._trail) {
      if (tNow - pt.t <= lookback) { ghost = pt; break; }
    }
    if (!ghost) ghost = { x: ctx.boss.x, y: ctx.boss.y };

    const dx = ctx.target.x - ghost.x;
    const dy = ctx.target.y - ghost.y;
    const len = Math.hypot(dx, dy) || 1;
    const speed = p.speed ?? 320;
    const count = p.count ?? 3;
    const spread = p.spread ?? 0.18;
    const baseAngle = Math.atan2(dy, dx);

    // Telegraph "echo marker" at ghost position
    this.pool.spawn({
      x: ghost.x, y: ghost.y, vx: 0, vy: 0,
      radius: 18, color: p.markerColor ?? "#ffffff",
      delay: p.telegraph ?? 0.35,
      maxLife: (p.telegraph ?? 0.35) + 0.05,
      tag: "marker",
    });
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1) - 0.5;
      const angle = baseAngle + t * spread;
      this.pool.spawn({
        x: ghost.x, y: ghost.y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: p.radius ?? 7, color: p.color ?? "#ffffff",
        delay: p.telegraph ?? 0.35,
      });
    }
  }

  // Laser line: a row of fast bullets traveling in a straight line through the
  // arena, telegraphed as a thin marker line for `telegraph` seconds before firing.
  _laserLine(p, ctx) {
    const arena = ctx.arena;
    const orient = p.orient ?? "h"; // 'h' | 'v'
    const lanes = p.lanes ?? 1;
    const speed = p.speed ?? 520;
    const telegraph = p.telegraph ?? 0.55;
    const beadCount = p.beadCount ?? 16;
    const radius = p.radius ?? 6;

    for (let n = 0; n < lanes; n++) {
      let pos;
      if (orient === "h") {
        pos = arena.y + 30 + Math.random() * (arena.h - 60);
      } else {
        pos = arena.x + 30 + Math.random() * (arena.w - 60);
      }
      // Telegraph markers along the lane
      for (let i = 0; i < beadCount; i++) {
        const t = i / (beadCount - 1);
        const x = orient === "h" ? arena.x + t * arena.w : pos;
        const y = orient === "h" ? pos : arena.y + t * arena.h;
        this.pool.spawn({
          x, y, vx: 0, vy: 0,
          radius: 3,
          color: p.markerColor ?? "#ffffff",
          delay: telegraph,
          maxLife: telegraph + 0.05,
          tag: "marker",
        });
      }
      // The actual laser shot — a row of bullets fired from one edge along the lane
      const dirX = orient === "h" ? 1 : 0;
      const dirY = orient === "v" ? 1 : 0;
      const startX = orient === "h" ? arena.x - 20 : pos;
      const startY = orient === "v" ? arena.y - 20 : pos;
      for (let i = 0; i < (p.count ?? 5); i++) {
        this.pool.spawn({
          x: startX - i * 18 * dirX, y: startY - i * 18 * dirY,
          vx: dirX * speed, vy: dirY * speed,
          radius, color: p.color ?? "#ffffff",
          delay: telegraph,
        });
      }
    }
  }

  // Stutter-aim: aimed shots that move forward, freeze briefly, then continue.
  // Breaks expected arrival timing — players panic-dodge and over-correct.
  _stutterAim(p, ctx) {
    const count = p.count ?? 5;
    const spread = p.spread ?? 0.4;
    const speed = p.speed ?? 360;
    const dx = ctx.target.x - ctx.boss.x;
    const dy = ctx.target.y - ctx.boss.y;
    const baseAngle = Math.atan2(dy, dx);
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1) - 0.5;
      const angle = baseAngle + t * spread;
      this.pool.spawn({
        x: ctx.boss.x, y: ctx.boss.y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: p.radius ?? 7, color: p.color ?? "#ffffff",
        stutter: { onTime: p.onTime ?? 0.32, offTime: p.offTime ?? 0.22 },
      });
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

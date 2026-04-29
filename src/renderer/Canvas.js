// Canvas setup. Owns the 2D context. Responsible for clearing each frame
// and drawing the floor / arena frame in any of:
//   - normal (color-tinted radial)
//   - inversion (white or black floor with optional flash flip)
//   - inversion + redCracks (b/w floor with red veins growing as boss HP drops)
//   - fullRedFloor (solid red, no inversion)

export class CanvasRenderer {
  constructor(canvasEl) {
    this.canvas = canvasEl;
    this.ctx = canvasEl.getContext("2d");
    this.width = canvasEl.width;
    this.height = canvasEl.height;
    // Pre-generate crack veins once per fight; the same set is revealed
    // progressively as boss HP drops.
    this._cracks = null;
    this._cracksFor = null; // identifies which fight the cracks were generated for
  }

  // Lazy-build a deterministic-looking set of crack veins from arena edges
  // toward the center. Each vein has a "spawnAt" 0..1 — the fraction of
  // damage taken at which it should appear.
  _generateCracks(arena) {
    const cracks = [];
    const seed = (arena.x * 31 + arena.y * 17 + arena.w + arena.h);
    let rng = seed;
    const rnd = () => {
      rng = (rng * 9301 + 49297) % 233280;
      return rng / 233280;
    };
    const veinCount = 26;
    for (let i = 0; i < veinCount; i++) {
      const side = Math.floor(rnd() * 4);
      let sx, sy, dx, dy;
      const cx = arena.x + arena.w / 2;
      const cy = arena.y + arena.h / 2;
      switch (side) {
        case 0: sx = arena.x + rnd() * arena.w; sy = arena.y;            break;
        case 1: sx = arena.x + arena.w;          sy = arena.y + rnd() * arena.h; break;
        case 2: sx = arena.x + rnd() * arena.w; sy = arena.y + arena.h;  break;
        default: sx = arena.x;                   sy = arena.y + rnd() * arena.h; break;
      }
      // Direction generally inward toward a random midpoint
      const tx = arena.x + (0.2 + rnd() * 0.6) * arena.w;
      const ty = arena.y + (0.2 + rnd() * 0.6) * arena.h;
      dx = tx - sx;
      dy = ty - sy;
      const segLen = 18 + rnd() * 22;
      const segCount = 8 + Math.floor(rnd() * 12);

      // Build the polyline by jittering toward the target
      const pts = [{ x: sx, y: sy }];
      let px = sx, py = sy;
      const baseAngle = Math.atan2(dy, dx);
      for (let s = 0; s < segCount; s++) {
        const wobble = (rnd() - 0.5) * 0.85;
        const a = baseAngle + wobble;
        px += Math.cos(a) * segLen;
        py += Math.sin(a) * segLen;
        pts.push({ x: px, y: py });
      }
      // A few branches for fractal-y look
      const branches = [];
      for (let b = 0; b < 2 + Math.floor(rnd() * 3); b++) {
        const bIdx = 1 + Math.floor(rnd() * (pts.length - 2));
        const bp = pts[bIdx];
        const bAngle = baseAngle + (rnd() - 0.5) * 1.6;
        const branchPts = [{ x: bp.x, y: bp.y }];
        let bx = bp.x, by = bp.y;
        const bSegs = 3 + Math.floor(rnd() * 4);
        for (let s = 0; s < bSegs; s++) {
          const a = bAngle + (rnd() - 0.5) * 0.7;
          bx += Math.cos(a) * (segLen * 0.7);
          by += Math.sin(a) * (segLen * 0.7);
          branchPts.push({ x: bx, y: by });
        }
        branches.push(branchPts);
      }

      cracks.push({
        spawnAt: i / veinCount, // 0 = appears at first tiny damage; 1 = full red
        width: 2 + rnd() * 3,
        pts,
        branches,
      });
    }
    return cracks;
  }

  clear(color = "#0a0b16") {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(0, 0, this.width, this.height);
  }

  drawArenaFrame(arena, beatPulse, color = "#5dd6ff", inversion = null, _redCracks = null, fullRedFloor = false) {
    const ctx = this.ctx;
    const glow = 0.25 + beatPulse * 0.5;
    ctx.save();
    let frameColor = color;
    if (fullRedFloor) {
      frameColor = "#9c0010";
    } else if (inversion) {
      frameColor = inversion.floor === "white" ? "#1a1a1a" : "#f0f0f0";
    }
    ctx.shadowColor = frameColor;
    ctx.shadowBlur = 24 * glow;
    ctx.strokeStyle = frameColor;
    ctx.globalAlpha = 0.7;
    ctx.lineWidth = 2;
    ctx.strokeRect(arena.x, arena.y, arena.w, arena.h);
    ctx.restore();
  }

  // `redCracks` is { progress: 0..1 } when active, null otherwise.
  // `fullRedFloor` true paints the floor solid red regardless of inversion.
  drawBackground(beatPulse, color = "#1b1130", inversion = null, arena = null, redCracks = null, fullRedFloor = false) {
    const ctx = this.ctx;

    if (fullRedFloor && arena) {
      // Outer canvas dark
      ctx.fillStyle = "#05060a";
      ctx.fillRect(0, 0, this.width, this.height);
      // Floor: solid deep red with a subtle gradient + pulse
      const baseRed = "#7a0010";
      const accentRed = "#c9001f";
      const grd = ctx.createRadialGradient(
        arena.x + arena.w / 2, arena.y + arena.h / 2, 60,
        arena.x + arena.w / 2, arena.y + arena.h / 2, arena.w * 0.7
      );
      grd.addColorStop(0, this._mix(baseRed, accentRed, 0.3 + 0.4 * beatPulse));
      grd.addColorStop(1, baseRed);
      ctx.fillStyle = grd;
      ctx.fillRect(arena.x, arena.y, arena.w, arena.h);
      return;
    }

    if (inversion && arena) {
      ctx.fillStyle = "#05060a";
      ctx.fillRect(0, 0, this.width, this.height);

      const baseWhite = "#f4f4f4";
      const baseBlack = "#0a0a0a";
      const floorBase = inversion.floor === "white" ? baseWhite : baseBlack;
      const accent = inversion.floor === "white" ? "#e0e0e0" : "#181818";
      const grd = ctx.createRadialGradient(
        arena.x + arena.w / 2, arena.y + arena.h / 2, 60,
        arena.x + arena.w / 2, arena.y + arena.h / 2, arena.w * 0.7
      );
      grd.addColorStop(0, this._mix(floorBase, accent, 0.2 + 0.3 * beatPulse));
      grd.addColorStop(1, floorBase);
      ctx.fillStyle = grd;
      ctx.fillRect(arena.x, arena.y, arena.w, arena.h);

      // Red cracks: paint over the b/w floor, do NOT respond to inversion.
      if (redCracks && redCracks.progress > 0) {
        if (!this._cracks || this._cracksFor !== arena) {
          this._cracks = this._generateCracks(arena);
          this._cracksFor = arena;
        }
        const p = Math.max(0, Math.min(1, redCracks.progress));
        ctx.save();
        // The "wound red" — same color the boss flashes when injured.
        const veinColor = "#c9001f";
        const veinGlow = "#ff3a3a";
        for (const c of this._cracks) {
          if (c.spawnAt > p) continue;
          // Each vein eases in over its first ~10% reveal window.
          const localT = Math.min(1, (p - c.spawnAt) * 6);
          ctx.globalAlpha = 0.55 + 0.4 * localT;
          ctx.shadowColor = veinGlow;
          ctx.shadowBlur = 6 + 4 * localT;
          ctx.strokeStyle = veinColor;
          ctx.lineWidth = c.width * (0.5 + 0.5 * localT);
          // Main vein
          ctx.beginPath();
          for (let i = 0; i < c.pts.length; i++) {
            const pt = c.pts[i];
            if (i === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y);
          }
          ctx.stroke();
          // Branches
          for (const branch of c.branches) {
            ctx.lineWidth = c.width * 0.55 * (0.5 + 0.5 * localT);
            ctx.beginPath();
            for (let i = 0; i < branch.length; i++) {
              const pt = branch[i];
              if (i === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y);
            }
            ctx.stroke();
          }
        }
        // Heavy reveal: at high progress, paint a translucent red wash so the
        // floor reads as bleeding rather than just lined.
        if (p > 0.6) {
          const wash = (p - 0.6) / 0.4;
          ctx.globalAlpha = 0.35 * wash;
          ctx.shadowBlur = 0;
          ctx.fillStyle = "#a00018";
          ctx.fillRect(arena.x, arena.y, arena.w, arena.h);
        }
        ctx.restore();
      }

      // Inversion flash overlay (briefly after a flip).
      if (inversion.flash > 0) {
        const k = Math.min(1, inversion.flash / 0.45);
        ctx.save();
        ctx.globalAlpha = k;
        ctx.fillStyle = inversion.floor === "white" ? "#ffffff" : "#000000";
        ctx.fillRect(arena.x, arena.y, arena.w, arena.h);
        ctx.globalAlpha = 1 - k;
        ctx.fillStyle = inversion.floor === "white" ? "#000000" : "#ffffff";
        ctx.fillRect(arena.x, arena.y, arena.w, arena.h);
        ctx.restore();
      }
      return;
    }

    // Standard non-inverted background
    const t = beatPulse;
    const grd = ctx.createRadialGradient(
      this.width / 2, this.height / 2, 100,
      this.width / 2, this.height / 2, this.width * 0.7
    );
    grd.addColorStop(0, this._mix("#1b1130", color, 0.4 + 0.4 * t));
    grd.addColorStop(1, "#05060a");
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, this.width, this.height);
  }

  // Reset cached cracks when switching arena/fight.
  resetCracks() { this._cracks = null; this._cracksFor = null; }

  _mix(a, b, t) {
    const pa = this._parse(a), pb = this._parse(b);
    const r = Math.round(pa.r + (pb.r - pa.r) * t);
    const g = Math.round(pa.g + (pb.g - pa.g) * t);
    const bl = Math.round(pa.b + (pb.b - pa.b) * t);
    return `rgb(${r}, ${g}, ${bl})`;
  }

  _parse(hex) {
    const v = hex.replace("#", "");
    return {
      r: parseInt(v.slice(0, 2), 16),
      g: parseInt(v.slice(2, 4), 16),
      b: parseInt(v.slice(4, 6), 16),
    };
  }
}

// Canvas setup. Owns the 2D context. Responsible for clearing each frame.

export class CanvasRenderer {
  constructor(canvasEl) {
    this.canvas = canvasEl;
    this.ctx = canvasEl.getContext("2d");
    this.width = canvasEl.width;
    this.height = canvasEl.height;
  }

  clear(color = "#0a0b16") {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(0, 0, this.width, this.height);
  }

  drawArenaFrame(arena, beatPulse, color = "#5dd6ff", inversion = null) {
    const ctx = this.ctx;
    const glow = 0.25 + beatPulse * 0.5;
    ctx.save();
    let frameColor = color;
    if (inversion) {
      frameColor = inversion.floor === "white" ? "#1a1a1a" : "#f0f0f0";
    }
    ctx.shadowColor = frameColor;
    ctx.shadowBlur = 24 * glow;
    ctx.strokeStyle = frameColor;
    ctx.globalAlpha = 0.55;
    ctx.lineWidth = 2;
    ctx.strokeRect(arena.x, arena.y, arena.w, arena.h);
    ctx.restore();
  }

  // Standard background OR inverted-floor background depending on `inversion`.
  drawBackground(beatPulse, color = "#1b1130", inversion = null, arena = null) {
    const ctx = this.ctx;
    if (inversion && arena) {
      // Outer canvas stays dark (so HUD reads), but the arena floor flips to white/black.
      ctx.fillStyle = "#05060a";
      ctx.fillRect(0, 0, this.width, this.height);

      // Floor color pulses slightly with the beat for life.
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

      // Inversion flash — a brief overlay when state just flipped.
      if (inversion.flash > 0) {
        const k = Math.min(1, inversion.flash / 0.45);
        ctx.save();
        ctx.globalAlpha = k;
        ctx.fillStyle = inversion.floor === "white" ? "#ffffff" : "#000000";
        ctx.fillRect(arena.x, arena.y, arena.w, arena.h);
        // Then the inverse fade-in (so it feels like a hard flip)
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

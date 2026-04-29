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

  drawArenaFrame(arena, beatPulse, color = "#5dd6ff") {
    const ctx = this.ctx;
    const glow = 0.25 + beatPulse * 0.5;
    ctx.save();
    ctx.shadowColor = color;
    ctx.shadowBlur = 24 * glow;
    ctx.strokeStyle = color;
    ctx.globalAlpha = 0.55;
    ctx.lineWidth = 2;
    ctx.strokeRect(arena.x, arena.y, arena.w, arena.h);
    ctx.restore();
  }

  drawBackground(beatPulse, color = "#1b1130") {
    const ctx = this.ctx;
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

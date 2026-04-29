// Stage select scene. Shows boss tiles in a grid; arrows + enter to choose.

export class StageSelectScene {
  constructor({ canvas, input, audio, stages, progress, onPick }) {
    this.canvas = canvas; this.input = input; this.audio = audio;
    this.stages = stages; this.progress = progress; this.onPick = onPick;
    this.cursor = 0;
    this.t = 0;
  }
  enter() {}
  exit() {}

  update(dt) {
    this.t += dt;
    if (this.input.consumePress("ArrowRight", "d")) this._move(1);
    if (this.input.consumePress("ArrowLeft", "a")) this._move(-1);
    if (this.input.consumePress("Enter", "space")) this._select();
  }

  _move(dir) {
    const max = this.stages.length;
    let next = this.cursor;
    for (let i = 0; i < max; i++) {
      next = (next + dir + max) % max;
      if (this._unlocked(next)) { this.cursor = next; this.audio.blip(660, 0.05, "square", 0.2); return; }
    }
  }

  _unlocked(i) {
    const stage = this.stages[i];
    if (stage?.defaultUnlocked) return true;
    if (i === 0) return true;
    return this.progress[this.stages[i - 1].id]?.cleared === true;
  }

  _select() {
    const stage = this.stages[this.cursor];
    if (!this._unlocked(this.cursor)) {
      this.audio.blip(160, 0.1, "sawtooth", 0.3);
      return;
    }
    this.audio.blip(880, 0.1, "square", 0.3);
    this.onPick(stage);
  }

  render(ctx) {
    const { width, height } = ctx.canvas;
    ctx.fillStyle = "#0a0b16";
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.fillStyle = "#5dd6ff";
    ctx.font = "bold 36px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SELECT STAGE", width / 2, 80);

    // Fit any number of stages into the canvas: shrink tiles when there are many.
    const gap = 20;
    const margin = 40;
    const maxTileW = 180;
    const available = width - margin * 2;
    const fitTileW = (available - gap * (this.stages.length - 1)) / this.stages.length;
    const tileW = Math.max(110, Math.min(maxTileW, Math.floor(fitTileW)));
    const tileH = Math.max(180, Math.floor(tileW * 1.22));
    const totalW = this.stages.length * tileW + (this.stages.length - 1) * gap;
    const startX = (width - totalW) / 2;
    const y = height / 2 - tileH / 2;

    this.stages.forEach((stage, i) => {
      const x = startX + i * (tileW + gap);
      const unlocked = this._unlocked(i);
      const focused = i === this.cursor;
      const cleared = this.progress[stage.id]?.cleared;

      ctx.save();
      if (focused) {
        ctx.shadowColor = stage.color;
        ctx.shadowBlur = 24 + 6 * Math.sin(this.t * 6);
      }
      ctx.fillStyle = unlocked ? "#1b1130" : "#0d0d18";
      ctx.fillRect(x, y, tileW, tileH);
      ctx.lineWidth = focused ? 3 : 1;
      ctx.strokeStyle = focused ? stage.color : (unlocked ? "#444466" : "#222233");
      ctx.strokeRect(x, y, tileW, tileH);

      // Boss "portrait" — colored hex (scales with tile size)
      ctx.shadowBlur = 0;
      ctx.globalAlpha = unlocked ? 1 : 0.3;
      ctx.fillStyle = stage.color;
      const hexR = Math.floor(tileW * 0.26);
      const cx = x + tileW / 2, cy = y + tileH * 0.4;
      ctx.beginPath();
      for (let k = 0; k < 6; k++) {
        const a = (k / 6) * Math.PI * 2 + Math.PI / 6;
        const px = cx + Math.cos(a) * hexR, py = cy + Math.sin(a) * hexR;
        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();

      const nameSize = Math.max(14, Math.floor(tileW * 0.1));
      const subSize = Math.max(11, Math.floor(tileW * 0.078));
      ctx.fillStyle = "#ffffff";
      ctx.font = `bold ${nameSize}px 'Segoe UI', sans-serif`;
      ctx.textAlign = "center";
      ctx.fillText(stage.name, cx, y + tileH * 0.77);

      ctx.font = `${subSize}px 'Segoe UI', sans-serif`;
      ctx.fillStyle = "#aaaadd";
      ctx.fillText(unlocked ? `${stage.bpm} BPM` : "LOCKED", cx, y + tileH * 0.88);

      if (cleared) {
        ctx.fillStyle = "#ffe25d";
        ctx.font = `bold ${subSize}px 'Segoe UI', sans-serif`;
        ctx.fillText(`Best: ${this.progress[stage.id].grade}`, cx, y + tileH - 8);
      }
      ctx.restore();
    });

    ctx.fillStyle = "#aaaadd";
    ctx.font = "14px 'Segoe UI', sans-serif";
    ctx.fillText("← →  Choose      ENTER  Start", width / 2, height - 40);
    ctx.restore();
  }
}

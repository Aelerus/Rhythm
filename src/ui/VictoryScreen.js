// Victory screen — grade breakdown, score, combo stats.

export class VictoryScene {
  constructor({ canvas, input, audio, summary, onContinue }) {
    this.canvas = canvas; this.input = input; this.audio = audio;
    this.summary = summary;
    this.onContinue = onContinue;
    this.t = 0;
  }

  enter() {
    this.audio.blip(880, 0.12, "square", 0.3);
    setTimeout(() => this.audio.blip(1320, 0.18, "square", 0.3), 120);
  }
  exit() {}

  update(dt) {
    this.t += dt;
    if (this.input.consumePress("Enter", "space", "Escape")) this.onContinue();
  }

  render(ctx) {
    const { width, height } = ctx.canvas;
    ctx.fillStyle = "rgba(10,11,22,0.92)";
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.fillStyle = "#ffe25d";
    ctx.shadowColor = "#ffe25d";
    ctx.shadowBlur = 22;
    ctx.font = "bold 64px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("VICTORY", width / 2, height / 2 - 110);

    ctx.shadowBlur = 0;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "20px 'Segoe UI', sans-serif";
    ctx.fillText(`${this.summary.bossName} defeated`, width / 2, height / 2 - 70);

    // Grade big
    ctx.fillStyle = this._gradeColor(this.summary.grade);
    ctx.shadowColor = this._gradeColor(this.summary.grade);
    ctx.shadowBlur = 24;
    ctx.font = "bold 110px 'Segoe UI', sans-serif";
    ctx.fillText(this.summary.grade, width / 2, height / 2 + 30);

    ctx.shadowBlur = 0;
    ctx.fillStyle = "#ffffff";
    ctx.font = "18px 'Segoe UI', sans-serif";
    const lines = [
      `Score:  ${Math.floor(this.summary.score)}`,
      `Perfect Hits:  ${this.summary.perfectHits} / ${this.summary.totalPrompts}`,
      `Max Combo:  ${this.summary.maxCombo}`,
      `Damage Taken:  ${this.summary.damageTaken}`,
    ];
    lines.forEach((l, i) => ctx.fillText(l, width / 2, height / 2 + 80 + i * 26));

    const pulse = 0.6 + 0.4 * Math.sin(this.t * 4);
    ctx.globalAlpha = pulse;
    ctx.fillStyle = "#5dd6ff";
    ctx.font = "bold 18px 'Segoe UI', sans-serif";
    ctx.fillText("Press ENTER to continue", width / 2, height - 50);
    ctx.restore();
  }

  _gradeColor(g) {
    return { S: "#ffe25d", A: "#5dffae", B: "#5dd6ff", C: "#aaaadd", F: "#ff5d5d" }[g] ?? "#ffffff";
  }
}

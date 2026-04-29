// Main menu, pause overlay, game-over screen.

export class MainMenuScene {
  constructor({ canvas, input, audio, onStart }) {
    this.canvas = canvas; this.input = input; this.audio = audio; this.onStart = onStart;
    this.t = 0;
  }
  enter() {}
  exit() {}
  update(dt) {
    this.t += dt;
    if (this.input.consumePress("Enter", "space")) {
      this.audio.blip(880, 0.1, "square", 0.3);
      this.onStart();
    }
  }
  render(ctx) {
    const { width, height } = ctx.canvas;
    ctx.fillStyle = "#0a0b16";
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.fillStyle = "#5dd6ff";
    ctx.shadowColor = "#5dd6ff";
    ctx.shadowBlur = 24;
    ctx.font = "bold 72px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("RHYTHM BULLET HELL", width / 2, height / 2 - 40);

    ctx.shadowBlur = 0;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "20px 'Segoe UI', sans-serif";
    ctx.fillText("Dodge to the beat. Strike on cue.", width / 2, height / 2 + 6);

    const pulse = 0.6 + 0.4 * Math.sin(this.t * 4);
    ctx.globalAlpha = pulse;
    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 22px 'Segoe UI', sans-serif";
    ctx.fillText("Press ENTER to begin", width / 2, height / 2 + 80);
    ctx.restore();
  }
}

export class GameOverScene {
  constructor({ canvas, input, audio, bossName, onRetry, onBackToSelect }) {
    this.canvas = canvas; this.input = input; this.audio = audio;
    this.bossName = bossName;
    this.onRetry = onRetry; this.onBackToSelect = onBackToSelect;
  }
  enter() { this.audio.blip(180, 0.4, "sawtooth", 0.4); }
  exit() {}
  update() {
    if (this.input.consumePress("Enter", "r")) this.onRetry();
    else if (this.input.consumePress("Escape", "Backspace")) this.onBackToSelect();
  }
  render(ctx) {
    const { width, height } = ctx.canvas;
    ctx.fillStyle = "rgba(10,11,22,0.92)";
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.fillStyle = "#ff5d5d";
    ctx.shadowColor = "#ff5d5d";
    ctx.shadowBlur = 22;
    ctx.font = "bold 64px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("GAME OVER", width / 2, height / 2 - 40);

    ctx.shadowBlur = 0;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "18px 'Segoe UI', sans-serif";
    ctx.fillText(`Defeated by ${this.bossName}`, width / 2, height / 2 + 4);

    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 18px 'Segoe UI', sans-serif";
    ctx.fillText("ENTER / R — Retry      ESC — Stage Select", width / 2, height / 2 + 70);
    ctx.restore();
  }
}

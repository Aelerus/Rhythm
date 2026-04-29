// Main menu, pause overlay, game-over screen.

export class MainMenuScene {
  constructor({ canvas, input, audio, onStart, isAdmin, onAdminToggle }) {
    this.canvas = canvas; this.input = input; this.audio = audio; this.onStart = onStart;
    this.isAdmin = !!isAdmin;
    this.onAdminToggle = onAdminToggle;
    this.t = 0;
    this._adminBtn = { x: 0, y: 0, w: 0, h: 0 };
    this._onClick = (e) => this._handleClick(e);
  }
  enter() { this.canvas.addEventListener("click", this._onClick); }
  exit() { this.canvas.removeEventListener("click", this._onClick); }

  _handleClick(e) {
    const rect = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / rect.width;
    const sy = this.canvas.height / rect.height;
    const x = (e.clientX - rect.left) * sx;
    const y = (e.clientY - rect.top) * sy;
    const b = this._adminBtn;
    if (x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) {
      this._promptAdmin();
    }
  }

  _promptAdmin() {
    if (this.isAdmin) {
      const ok = window.confirm("Admin mode is ON. Disable it?");
      if (ok) {
        this.isAdmin = false;
        this.onAdminToggle?.(false);
        this.audio.blip(220, 0.1, "sawtooth", 0.3);
      }
      return;
    }
    const entered = window.prompt("Enter admin password:");
    if (entered === null) return;
    if (entered === "widdleyotiddle") {
      this.isAdmin = true;
      this.onAdminToggle?.(true);
      this.audio.blip(1200, 0.15, "square", 0.3);
    } else {
      this.audio.blip(160, 0.2, "sawtooth", 0.3);
      window.alert("Incorrect password.");
    }
  }

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

    // Admin button — bottom right
    const btnW = 110, btnH = 32;
    const btnX = width - btnW - 16;
    const btnY = height - btnH - 16;
    this._adminBtn = { x: btnX, y: btnY, w: btnW, h: btnH };

    ctx.save();
    const active = this.isAdmin;
    ctx.fillStyle = active ? "#1b3a1b" : "#1b1130";
    ctx.fillRect(btnX, btnY, btnW, btnH);
    ctx.lineWidth = 1;
    ctx.strokeStyle = active ? "#5dff8a" : "#444466";
    ctx.strokeRect(btnX, btnY, btnW, btnH);
    ctx.fillStyle = active ? "#5dff8a" : "#aaaadd";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(active ? "ADMIN ✓" : "ADMIN", btnX + btnW / 2, btnY + btnH / 2 + 1);
    ctx.restore();
  }
}

// Brief scene shown while we download/decode boss music.
export class LoadingScene {
  constructor({ canvas, input, audio, stage }) {
    this.canvas = canvas; this.input = input; this.audio = audio;
    this.stage = stage; this.t = 0;
  }
  enter() {}
  exit() {}
  update(dt) { this.t += dt; }
  render(ctx) {
    const { width, height } = ctx.canvas;
    ctx.fillStyle = "#0a0b16";
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.fillStyle = this.stage.color;
    ctx.shadowColor = this.stage.color;
    ctx.shadowBlur = 24;
    ctx.font = "bold 56px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(this.stage.name, width / 2, height / 2 - 30);

    const dots = ".".repeat(1 + (Math.floor(this.t * 3) % 3));
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "20px 'Segoe UI', sans-serif";
    ctx.fillText(`Tuning the strings${dots}`, width / 2, height / 2 + 30);

    // Pulsing ring while we wait
    const r = 80 + Math.sin(this.t * 4) * 8;
    ctx.globalAlpha = 0.5 + 0.5 * Math.sin(this.t * 4);
    ctx.strokeStyle = this.stage.color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(width / 2, height / 2 + 90, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}

export class GameOverScene {
  constructor({ canvas, input, audio, bossName, reason = "death", onRetry, onBackToSelect }) {
    this.canvas = canvas; this.input = input; this.audio = audio;
    this.bossName = bossName;
    this.reason = reason;
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
    const isTimeUp = this.reason === "time_up";
    const headline = isTimeUp ? "TIME'S UP" : "GAME OVER";
    const subline = isTimeUp
      ? `${this.bossName} outlasted you.`
      : `Defeated by ${this.bossName}`;
    const headlineColor = isTimeUp ? "#ff8a5d" : "#ff5d5d";

    ctx.fillStyle = headlineColor;
    ctx.shadowColor = headlineColor;
    ctx.shadowBlur = 22;
    ctx.font = "bold 64px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(headline, width / 2, height / 2 - 40);

    ctx.shadowBlur = 0;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "18px 'Segoe UI', sans-serif";
    ctx.fillText(subline, width / 2, height / 2 + 4);

    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 18px 'Segoe UI', sans-serif";
    ctx.fillText("ENTER / R — Retry      ESC — Stage Select", width / 2, height / 2 + 70);
    ctx.restore();
  }
}

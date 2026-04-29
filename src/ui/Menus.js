// Main menu, pause overlay, game-over screen.

export class SettingsOverlay {
  constructor({ audio, onClose, accent = "#5dd6ff" }) {
    this.audio = audio;
    this.onClose = onClose;
    this.accent = accent;
    this._cursor = 0;
    this._items = [
      { label: "MUSIC VOLUME",  get: () => audio.getMusicVolume(),  set: (v) => audio.setMusicVolume(v)  },
      { label: "MASTER VOLUME", get: () => audio.getMasterVolume(), set: (v) => audio.setMasterVolume(v) },
    ];
  }

  handleInput(input) {
    if (input.consumePress("Escape", "Enter")) {
      this.audio.blip(440, 0.06, "square", 0.2);
      this.onClose();
      return;
    }
    if (input.consumePress("ArrowUp", "w")) {
      this._cursor = (this._cursor - 1 + this._items.length) % this._items.length;
      this.audio.blip(660, 0.04, "square", 0.15);
    }
    if (input.consumePress("ArrowDown", "s")) {
      this._cursor = (this._cursor + 1) % this._items.length;
      this.audio.blip(660, 0.04, "square", 0.15);
    }
    if (input.consumePress("ArrowLeft", "a")) {
      const item = this._items[this._cursor];
      item.set(Math.max(0, parseFloat((item.get() - 0.05).toFixed(2))));
      this.audio.blip(440, 0.04, "square", 0.15);
    }
    if (input.consumePress("ArrowRight", "d")) {
      const item = this._items[this._cursor];
      item.set(Math.min(1, parseFloat((item.get() + 0.05).toFixed(2))));
      this.audio.blip(660, 0.04, "square", 0.15);
    }
  }

  draw(ctx) {
    const { width, height } = ctx.canvas;
    ctx.save();

    ctx.fillStyle = "rgba(10,11,22,0.93)";
    ctx.fillRect(0, 0, width, height);

    ctx.fillStyle = "#ffffff";
    ctx.shadowColor = this.accent;
    ctx.shadowBlur = 22;
    ctx.font = "bold 52px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("SETTINGS", width / 2, height / 2 - 110);
    ctx.shadowBlur = 0;

    const sliderW = 400, sliderH = 12, rowH = 96;
    const firstLabelY = height / 2 - 40;

    this._items.forEach((item, i) => {
      const focused = i === this._cursor;
      const val = item.get();
      const labelY = firstLabelY + i * rowH;
      const barY   = labelY + 28;
      const barX   = (width - sliderW) / 2;

      ctx.fillStyle = focused ? this.accent : "#aaaadd";
      ctx.font = "bold 20px 'Segoe UI', sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "alphabetic";
      ctx.fillText(item.label, width / 2, labelY);

      ctx.fillStyle = focused ? "#ffffff" : "#888899";
      ctx.font = "16px 'Segoe UI', sans-serif";
      ctx.textAlign = "left";
      ctx.fillText(`${Math.round(val * 100)}%`, barX + sliderW + 14, labelY);

      ctx.fillStyle = "#1f1a30";
      ctx.fillRect(barX, barY, sliderW, sliderH);
      ctx.strokeStyle = focused ? this.accent : "#444466";
      ctx.lineWidth = focused ? 2 : 1;
      ctx.strokeRect(barX, barY, sliderW, sliderH);

      ctx.fillStyle = focused ? this.accent : "#556699";
      ctx.fillRect(barX, barY, sliderW * val, sliderH);

      const thumbX = barX + sliderW * val;
      ctx.fillStyle = focused ? "#ffffff" : "#aaaadd";
      ctx.beginPath();
      ctx.arc(thumbX, barY + sliderH / 2, 9, 0, Math.PI * 2);
      ctx.fill();
      if (focused) {
        ctx.strokeStyle = this.accent;
        ctx.lineWidth = 2;
        ctx.stroke();
      }
    });

    ctx.fillStyle = "#aaaadd";
    ctx.font = "14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("↑ ↓  Select      ← →  Adjust      ENTER / ESC  Back", width / 2, height - 50);

    ctx.restore();
  }
}

export class MainMenuScene {
  constructor({ canvas, input, audio, onStart, isAdmin, onAdminToggle }) {
    this.canvas = canvas; this.input = input; this.audio = audio; this.onStart = onStart;
    this.isAdmin = !!isAdmin;
    this.onAdminToggle = onAdminToggle;
    this.t = 0;
    this._adminBtn = { x: 0, y: 0, w: 0, h: 0 };
    this._settingsBtn = { x: 0, y: 0, w: 0, h: 0 };
    this._settingsOpen = false;
    this._settingsOverlay = null;
    this._onClick = (e) => this._handleClick(e);
  }
  enter() { this.canvas.addEventListener("click", this._onClick); }
  exit() { this.canvas.removeEventListener("click", this._onClick); }

  _openSettings() {
    this._settingsOpen = true;
    this._settingsOverlay = new SettingsOverlay({
      audio: this.audio,
      onClose: () => { this._settingsOpen = false; this._settingsOverlay = null; },
    });
  }

  _handleClick(e) {
    if (this._settingsOpen) return;
    const rect = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / rect.width;
    const sy = this.canvas.height / rect.height;
    const x = (e.clientX - rect.left) * sx;
    const y = (e.clientY - rect.top) * sy;
    const b = this._adminBtn;
    if (x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) {
      this._promptAdmin();
      return;
    }
    const sb = this._settingsBtn;
    if (x >= sb.x && x <= sb.x + sb.w && y >= sb.y && y <= sb.y + sb.h) {
      this._openSettings();
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
    if (this._settingsOpen) {
      this._settingsOverlay.handleInput(this.input);
      return;
    }
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

    // Settings button — bottom left
    const sBtnW = 110, sBtnH = 32;
    const sBtnX = 16, sBtnY = height - sBtnH - 16;
    this._settingsBtn = { x: sBtnX, y: sBtnY, w: sBtnW, h: sBtnH };

    ctx.save();
    ctx.fillStyle = "#1b1130";
    ctx.fillRect(sBtnX, sBtnY, sBtnW, sBtnH);
    ctx.lineWidth = 1;
    ctx.strokeStyle = "#444466";
    ctx.strokeRect(sBtnX, sBtnY, sBtnW, sBtnH);
    ctx.fillStyle = "#aaaadd";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("SETTINGS", sBtnX + sBtnW / 2, sBtnY + sBtnH / 2 + 1);
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

    if (this._settingsOpen) this._settingsOverlay.draw(ctx);
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
    ctx.fillText("ENTER / R — Retry      ESC — World Map", width / 2, height / 2 + 70);
    ctx.restore();
  }
}

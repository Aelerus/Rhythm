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

// ─── Character Creation ────────────────────────────────────────────────────────

export class CharacterCreationScene {
  static SHAPES = [
    { id: "arrow",   label: "ARROW"   },
    { id: "square",  label: "SQUARE"  },
    { id: "circle",  label: "CIRCLE"  },
    { id: "star",    label: "STAR"    },
    { id: "hexagon", label: "HEXAGON" },
    { id: "octagon", label: "OCTAGON" },
  ];

  // Colors chosen to stand out on the standard dark arena background.
  // Inversion mode overrides the body color anyway, so only dark-floor visibility matters here.
  static COLORS = [
    { id: "#e8e8f0", label: "WHITE"  },
    { id: "#5dd6ff", label: "CYAN"   },
    { id: "#7dff5d", label: "LIME"   },
    { id: "#ffe25d", label: "YELLOW" },
    { id: "#ff5dd6", label: "PINK"   },
    { id: "#ff9a3c", label: "ORANGE" },
    { id: "#b870ff", label: "VIOLET" },
    { id: "#ff5d5d", label: "RED"    },
  ];

  constructor({ canvas, input, audio, initial = {}, onConfirm, onBack }) {
    this.canvas = canvas;
    this.input = input;
    this.audio = audio;
    this.onConfirm = onConfirm;
    this.onBack = onBack;

    const si = CharacterCreationScene.SHAPES.findIndex((s) => s.id === initial.shape);
    const ci = CharacterCreationScene.COLORS.findIndex((c) => c.id === initial.color);
    this._shapeIdx = si >= 0 ? si : 0;
    this._colorIdx = ci >= 0 ? ci : 0;
    this.t = 0;
    this._shapeBoxes = [];
    this._colorSwatches = [];
    this._onClick = (e) => this._handleClick(e);
  }

  enter() { this.canvas.addEventListener("click", this._onClick); }
  exit()  { this.canvas.removeEventListener("click", this._onClick); }

  get _shape() { return CharacterCreationScene.SHAPES[this._shapeIdx].id; }
  get _color() { return CharacterCreationScene.COLORS[this._colorIdx].id; }

  update(dt) {
    this.t += dt;
    if (this.input.consumePress("ArrowLeft", "a")) {
      this._shapeIdx = (this._shapeIdx - 1 + CharacterCreationScene.SHAPES.length) % CharacterCreationScene.SHAPES.length;
      this.audio.blip(660, 0.04, "square", 0.15);
    }
    if (this.input.consumePress("ArrowRight", "d")) {
      this._shapeIdx = (this._shapeIdx + 1) % CharacterCreationScene.SHAPES.length;
      this.audio.blip(660, 0.04, "square", 0.15);
    }
    if (this.input.consumePress("ArrowUp", "w")) {
      this._colorIdx = (this._colorIdx - 1 + CharacterCreationScene.COLORS.length) % CharacterCreationScene.COLORS.length;
      this.audio.blip(550, 0.04, "square", 0.15);
    }
    if (this.input.consumePress("ArrowDown", "s")) {
      this._colorIdx = (this._colorIdx + 1) % CharacterCreationScene.COLORS.length;
      this.audio.blip(550, 0.04, "square", 0.15);
    }
    if (this.input.consumePress("Enter")) {
      this.audio.blip(880, 0.1, "square", 0.3);
      this.onConfirm({ shape: this._shape, color: this._color });
    }
    if (this.input.consumePress("Escape")) {
      this.audio.blip(330, 0.06, "square", 0.15);
      this.onBack?.();
    }
  }

  _handleClick(e) {
    const rect = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / rect.width;
    const sy = this.canvas.height / rect.height;
    const mx = (e.clientX - rect.left) * sx;
    const my = (e.clientY - rect.top) * sy;

    for (let i = 0; i < this._shapeBoxes.length; i++) {
      const b = this._shapeBoxes[i];
      if (mx >= b.x && mx <= b.x + b.w && my >= b.y && my <= b.y + b.h) {
        if (this._shapeIdx !== i) {
          this._shapeIdx = i;
          this.audio.blip(660, 0.04, "square", 0.15);
        }
        return;
      }
    }
    for (let i = 0; i < this._colorSwatches.length; i++) {
      const b = this._colorSwatches[i];
      if (mx >= b.x && mx <= b.x + b.w && my >= b.y && my <= b.y + b.h) {
        if (this._colorIdx !== i) {
          this._colorIdx = i;
          this.audio.blip(550, 0.04, "square", 0.15);
        }
        return;
      }
    }
  }

  render(ctx) {
    const { width, height } = ctx.canvas;

    ctx.fillStyle = "#0a0b16";
    ctx.fillRect(0, 0, width, height);

    // Title
    ctx.save();
    ctx.fillStyle = "#5dd6ff";
    ctx.shadowColor = "#5dd6ff";
    ctx.shadowBlur = 20;
    ctx.font = "bold 48px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("CHARACTER SELECT", width / 2, 68);
    ctx.shadowBlur = 0;
    ctx.restore();

    this._drawShapeRow(ctx, width);
    this._drawColorRow(ctx, width);
    this._drawPreview(ctx, width, height);

    // Controls hint
    ctx.save();
    ctx.fillStyle = "#555577";
    ctx.font = "13px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("← →  Shape      ↑ ↓  Color      ENTER  Confirm      ESC  Back", width / 2, height - 22);
    ctx.restore();
  }

  _drawShapeRow(ctx, width) {
    const shapes = CharacterCreationScene.SHAPES;
    const boxW = 120, boxH = 100, gap = 16;
    const totalW = shapes.length * boxW + (shapes.length - 1) * gap;
    const startX = (width - totalW) / 2;
    const startY = 102;

    ctx.save();
    ctx.fillStyle = "#aaaadd";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("SHAPE", startX, startY - 8);
    ctx.restore();

    this._shapeBoxes = [];
    shapes.forEach((shape, i) => {
      const bx = startX + i * (boxW + gap);
      const by = startY;
      this._shapeBoxes.push({ x: bx, y: by, w: boxW, h: boxH });
      const selected = i === this._shapeIdx;

      ctx.save();
      ctx.fillStyle = selected ? "#1f1640" : "#13111f";
      ctx.fillRect(bx, by, boxW, boxH);

      ctx.strokeStyle = selected ? "#5dd6ff" : "#333355";
      ctx.lineWidth = selected ? 2 : 1;
      if (selected) { ctx.shadowColor = "#5dd6ff"; ctx.shadowBlur = 10; }
      ctx.strokeRect(bx, by, boxW, boxH);
      ctx.shadowBlur = 0;

      // Mini shape preview inside box
      const cx = bx + boxW / 2;
      const cy = by + boxH / 2 - 8;
      ctx.fillStyle = selected ? (this._color) : "#555577";
      ctx.strokeStyle = "#1b1130";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      this._shapePath(ctx, shape.id, cx, cy, 22);
      ctx.closePath();
      ctx.fill();
      if (selected) { ctx.shadowColor = this._color; ctx.shadowBlur = 8; }
      ctx.stroke();
      ctx.shadowBlur = 0;

      ctx.fillStyle = selected ? "#ffffff" : "#666688";
      ctx.font = `${selected ? "bold " : ""}12px 'Segoe UI', sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "alphabetic";
      ctx.fillText(shape.label, cx, by + boxH - 8);
      ctx.restore();
    });
  }

  _drawColorRow(ctx, width) {
    const colors = CharacterCreationScene.COLORS;
    const swW = 72, swH = 46, gap = 10;
    const totalW = colors.length * swW + (colors.length - 1) * gap;
    const startX = (width - totalW) / 2;
    const startY = 240;

    ctx.save();
    ctx.fillStyle = "#aaaadd";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("COLOR", startX, startY - 8);
    ctx.restore();

    this._colorSwatches = [];
    colors.forEach((color, i) => {
      const bx = startX + i * (swW + gap);
      const by = startY;
      this._colorSwatches.push({ x: bx, y: by, w: swW, h: swH });
      const selected = i === this._colorIdx;

      ctx.save();
      ctx.fillStyle = color.id;
      if (selected) { ctx.shadowColor = color.id; ctx.shadowBlur = 14; }
      ctx.fillRect(bx, by, swW, swH);
      ctx.shadowBlur = 0;

      ctx.strokeStyle = selected ? "#ffffff" : "#444466";
      ctx.lineWidth = selected ? 2.5 : 1;
      ctx.strokeRect(bx, by, swW, swH);

      ctx.fillStyle = selected ? "#ffffff" : "#555577";
      ctx.font = `${selected ? "bold " : ""}11px 'Segoe UI', sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "alphabetic";
      ctx.fillText(color.label, bx + swW / 2, by + swH + 15);
      ctx.restore();
    });
  }

  _drawPreview(ctx, width, height) {
    const px = width / 2;
    const py = 478;
    const r = 34;

    // Section label
    ctx.save();
    ctx.fillStyle = "#aaaadd";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("PREVIEW", px, 365);
    ctx.restore();

    // Dark circle backdrop
    ctx.save();
    ctx.fillStyle = "#0d0e1f";
    ctx.strokeStyle = "#2a2a44";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(px, py, r + 28, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.restore();

    // Pulsing glow ring behind the character
    const pulse = 0.5 + 0.5 * Math.sin(this.t * 3);
    ctx.save();
    ctx.globalAlpha = 0.18 + 0.12 * pulse;
    ctx.fillStyle = this._color;
    ctx.shadowColor = this._color;
    ctx.shadowBlur = 30;
    ctx.beginPath();
    ctx.arc(px, py, r + 18, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Player shape
    ctx.save();
    ctx.fillStyle = this._color;
    ctx.strokeStyle = "#1b1130";
    ctx.lineWidth = 2;
    ctx.shadowColor = this._color;
    ctx.shadowBlur = 18;
    ctx.beginPath();
    this._shapePath(ctx, this._shape, px, py, r);
    ctx.closePath();
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.stroke();
    ctx.restore();

    // Hitbox core dot
    ctx.save();
    ctx.fillStyle = "#ffe25d";
    ctx.shadowColor = "#ffe25d";
    ctx.shadowBlur = 10;
    ctx.beginPath();
    ctx.arc(px, py, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Shape name below
    ctx.save();
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 16px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText(CharacterCreationScene.SHAPES[this._shapeIdx].label, px, py + r + 30);
    ctx.restore();

    // Confirm prompt
    const confirmPulse = 0.6 + 0.4 * Math.sin(this.t * 4);
    ctx.save();
    ctx.globalAlpha = confirmPulse;
    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 18px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    ctx.fillText("Press ENTER to confirm", px, py + r + 60);
    ctx.restore();
  }

  // Shared path helper — mirrors PlayerRenderer._drawShapePath exactly.
  _shapePath(ctx, shapeId, x, y, r) {
    switch (shapeId) {
      case "arrow":
        ctx.moveTo(x, y - r);
        ctx.lineTo(x + r * 0.85, y + r * 0.7);
        ctx.lineTo(x, y + r * 0.35);
        ctx.lineTo(x - r * 0.85, y + r * 0.7);
        break;
      case "square": {
        const hw = r * 0.82;
        ctx.moveTo(x - hw, y - hw);
        ctx.lineTo(x + hw, y - hw);
        ctx.lineTo(x + hw, y + hw);
        ctx.lineTo(x - hw, y + hw);
        break;
      }
      case "circle":
        ctx.arc(x, y, r, 0, Math.PI * 2);
        break;
      case "star": {
        const inner = r * 0.42;
        for (let i = 0; i < 10; i++) {
          const angle = (i * Math.PI / 5) - Math.PI / 2;
          const rad = i % 2 === 0 ? r : inner;
          const qx = x + rad * Math.cos(angle);
          const qy = y + rad * Math.sin(angle);
          if (i === 0) ctx.moveTo(qx, qy);
          else ctx.lineTo(qx, qy);
        }
        break;
      }
      case "hexagon":
        for (let i = 0; i < 6; i++) {
          const angle = (i * Math.PI / 3) - Math.PI / 2;
          const qx = x + r * Math.cos(angle);
          const qy = y + r * Math.sin(angle);
          if (i === 0) ctx.moveTo(qx, qy);
          else ctx.lineTo(qx, qy);
        }
        break;
      case "octagon":
        for (let i = 0; i < 8; i++) {
          const angle = (i * Math.PI / 4) + Math.PI / 8 - Math.PI / 2;
          const qx = x + r * Math.cos(angle);
          const qy = y + r * Math.sin(angle);
          if (i === 0) ctx.moveTo(qx, qy);
          else ctx.lineTo(qx, qy);
        }
        break;
      default:
        ctx.moveTo(x, y - r);
        ctx.lineTo(x + r * 0.85, y + r * 0.7);
        ctx.lineTo(x, y + r * 0.35);
        ctx.lineTo(x - r * 0.85, y + r * 0.7);
        break;
    }
  }
}

// ─── Loading screen ────────────────────────────────────────────────────────────

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

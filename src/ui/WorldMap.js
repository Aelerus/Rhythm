// World map scene. Worlds stack vertically; each world is a horizontal path
// of stage nodes. Worlds and stages unlock sequentially. The Pinnacle world
// is hidden until every other world is cleared, then revealed with a
// one-shot dramatic animation on the player's first visit afterwards.

const PINNACLE_SEEN_KEY = "rbh.pinnacleSeen";

export class WorldMapScene {
  constructor({ canvas, input, audio, worlds, stages, progress, onPick, isAdmin }) {
    this.canvas = canvas;
    this.input = input;
    this.audio = audio;
    this.worlds = worlds;
    this.stagesById = Object.fromEntries(stages.map((s) => [s.id, s]));
    this.progress = progress;
    this.onPick = onPick;
    this.isAdmin = !!isAdmin;
    this.t = 0;

    // Pinnacle dramatic reveal: trigger if it just became unlocked and the
    // player has not seen it yet. Admin mode never plays the reveal — they
    // already know it exists.
    const pinnacleUnlocked = this._isPinnacleUnlocked();
    const seen = this._loadPinnacleSeen();
    this.revealing = !this.isAdmin && pinnacleUnlocked && !seen;
    this.revealT = 0;
    this.revealDuration = 3.6;

    this.view = this._buildView();
    this.cursor = this._initialCursor();
    this.tooltip = null; // { text, until }
    this._mouse = { x: -1, y: -1 };
    this._nodeRects = [];
    this._onCanvasClick = (e) => this._handleClick(e);
    this._onCanvasMove = (e) => this._handleMove(e);
  }

  enter() {
    this.canvas.addEventListener("click", this._onCanvasClick);
    this.canvas.addEventListener("mousemove", this._onCanvasMove);
  }

  exit() {
    this.canvas.removeEventListener("click", this._onCanvasClick);
    this.canvas.removeEventListener("mousemove", this._onCanvasMove);
  }

  // --- progress / unlock helpers ---------------------------------------------

  _isCleared(stageId) {
    return this.progress[stageId]?.cleared === true;
  }

  _isWorldComplete(world) {
    return world.stages.every((id) => this._isCleared(id));
  }

  _isWorldUnlocked(world) {
    if (this.isAdmin) return true;
    if (world.secret) return this._isPinnacleUnlocked();
    const idx = this.worlds.indexOf(world);
    if (idx <= 0) return true;
    // Walk back through prior non-secret worlds; all must be complete.
    for (let i = idx - 1; i >= 0; i--) {
      const prev = this.worlds[i];
      if (prev.secret) continue;
      if (!this._isWorldComplete(prev)) return false;
    }
    return true;
  }

  _isPinnacleUnlocked() {
    if (this.isAdmin) return true;
    return this.worlds
      .filter((w) => !w.secret)
      .every((w) => this._isWorldComplete(w));
  }

  _isStageUnlocked(world, stageIdx) {
    if (this.isAdmin) return true;
    if (!this._isWorldUnlocked(world)) return false;
    if (stageIdx === 0) return true;
    const prevId = world.stages[stageIdx - 1];
    return this._isCleared(prevId);
  }

  _buildView() {
    const view = [];
    for (const world of this.worlds) {
      const unlocked = this._isWorldUnlocked(world);
      // Secret worlds are hidden entirely until unlocked (admin sees all).
      const visible = !world.secret || unlocked || this.isAdmin;
      if (!visible) continue;
      const stages = world.stages.map((id, i) => ({
        stage: this.stagesById[id],
        unlocked: this._isStageUnlocked(world, i),
        cleared: this._isCleared(id),
      }));
      view.push({ world, unlocked, stages });
    }
    return view;
  }

  _initialCursor() {
    // Land on the first unlocked-but-not-cleared stage; otherwise the first
    // stage of the first visible world.
    for (let w = 0; w < this.view.length; w++) {
      const ws = this.view[w];
      for (let s = 0; s < ws.stages.length; s++) {
        const node = ws.stages[s];
        if (node.unlocked && !node.cleared) return { w, s };
      }
    }
    return { w: 0, s: 0 };
  }

  // --- input -----------------------------------------------------------------

  update(dt) {
    this.t += dt;
    if (this.revealing) {
      this.revealT += dt;
      if (this.revealT >= this.revealDuration) {
        this.revealing = false;
        this._savePinnacleSeen();
      }
      // Block input during the dramatic reveal so it can't be skipped by accident.
      // Drain the obvious keys.
      this.input.consumePress("Enter", "space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "w", "s", "a", "d");
      return;
    }

    if (this.tooltip && this.t > this.tooltip.until) this.tooltip = null;

    if (this.input.consumePress("ArrowDown", "s")) this._moveWorld(1);
    if (this.input.consumePress("ArrowUp", "w")) this._moveWorld(-1);
    if (this.input.consumePress("ArrowRight", "d")) this._moveStage(1);
    if (this.input.consumePress("ArrowLeft", "a")) this._moveStage(-1);
    if (this.input.consumePress("Enter", "space")) this._select();
  }

  _moveWorld(dir) {
    if (this.view.length <= 1) return;
    const next = (this.cursor.w + dir + this.view.length) % this.view.length;
    if (next === this.cursor.w) return;
    const targetLen = this.view[next].stages.length;
    this.cursor = { w: next, s: Math.min(this.cursor.s, targetLen - 1) };
    this.audio.blip(660, 0.05, "square", 0.2);
  }

  _moveStage(dir) {
    const ws = this.view[this.cursor.w];
    if (!ws || ws.stages.length <= 1) return;
    const next = (this.cursor.s + dir + ws.stages.length) % ws.stages.length;
    if (next === this.cursor.s) return;
    this.cursor = { w: this.cursor.w, s: next };
    this.audio.blip(660, 0.05, "square", 0.2);
  }

  _select() {
    const ws = this.view[this.cursor.w];
    if (!ws) return;
    const node = ws.stages[this.cursor.s];
    if (!node.unlocked) {
      this.audio.blip(160, 0.1, "sawtooth", 0.3);
      this.tooltip = {
        text: ws.unlocked
          ? "Complete the previous level to unlock"
          : "Complete the previous world to unlock",
        until: this.t + 2.0,
      };
      return;
    }
    this.audio.blip(880, 0.1, "square", 0.3);
    this.onPick(node.stage);
  }

  _canvasCoords(e) {
    const rect = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / rect.width;
    const sy = this.canvas.height / rect.height;
    return { x: (e.clientX - rect.left) * sx, y: (e.clientY - rect.top) * sy };
  }

  _hitNode(x, y) {
    for (const r of this._nodeRects) {
      const dx = x - r.cx, dy = y - r.cy;
      if (dx * dx + dy * dy <= r.r * r.r) return r;
    }
    return null;
  }

  _handleClick(e) {
    if (this.revealing) return;
    const { x, y } = this._canvasCoords(e);
    const hit = this._hitNode(x, y);
    if (!hit) return;
    this.cursor = { w: hit.w, s: hit.s };
    this._select();
  }

  _handleMove(e) {
    const { x, y } = this._canvasCoords(e);
    this._mouse.x = x; this._mouse.y = y;
    if (this.revealing) return;
    const hit = this._hitNode(x, y);
    if (hit && (hit.w !== this.cursor.w || hit.s !== this.cursor.s)) {
      this.cursor = { w: hit.w, s: hit.s };
      this.audio.blip(660, 0.04, "square", 0.15);
    }
  }

  // --- persistence -----------------------------------------------------------

  _loadPinnacleSeen() {
    try { return localStorage.getItem(PINNACLE_SEEN_KEY) === "1"; }
    catch { return false; }
  }

  _savePinnacleSeen() {
    try { localStorage.setItem(PINNACLE_SEEN_KEY, "1"); }
    catch {}
  }

  // --- render ----------------------------------------------------------------

  render(ctx) {
    const { width, height } = ctx.canvas;
    this._nodeRects = [];

    // Background.
    const grad = ctx.createLinearGradient(0, 0, 0, height);
    grad.addColorStop(0, "#0a0b16");
    grad.addColorStop(1, "#11142a");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);

    // Title.
    ctx.save();
    ctx.fillStyle = "#5dd6ff";
    ctx.shadowColor = "#5dd6ff";
    ctx.shadowBlur = 18;
    ctx.font = "bold 32px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("WORLD MAP", width / 2, 50);
    ctx.restore();

    // Lay out world bands.
    const bandTop = 80;
    const bandBottom = height - 60;
    const usable = bandBottom - bandTop;
    const n = Math.max(1, this.view.length);
    const bandH = usable / n;

    for (let w = 0; w < this.view.length; w++) {
      this._drawWorldBand(ctx, this.view[w], w, bandTop + w * bandH, bandH, width);
    }

    // Footer / tooltip.
    ctx.save();
    ctx.textAlign = "center";
    ctx.font = "14px 'Segoe UI', sans-serif";
    if (this.tooltip) {
      ctx.fillStyle = "#ffae5d";
      ctx.fillText(this.tooltip.text, width / 2, height - 36);
    } else {
      ctx.fillStyle = "#aaaadd";
      ctx.fillText("↑ ↓  Switch World      ← →  Choose Level      ENTER  Start", width / 2, height - 36);
    }
    if (this.isAdmin) {
      ctx.fillStyle = "#5dff8a";
      ctx.font = "bold 12px 'Segoe UI', sans-serif";
      ctx.textAlign = "right";
      ctx.fillText("ADMIN MODE — ALL UNLOCKED", width - 16, height - 16);
    }
    ctx.restore();

    if (this.revealing) this._drawRevealOverlay(ctx);
  }

  _drawWorldBand(ctx, ws, wIdx, y, h, width) {
    const { world, unlocked, stages } = ws;
    const focused = this.cursor.w === wIdx;
    const isPinnacle = !!world.secret;

    // Band background — pinnacle gets a special gold-tinted treatment.
    ctx.save();
    if (isPinnacle && unlocked) {
      const pulse = 0.5 + 0.5 * Math.sin(this.t * 2);
      ctx.fillStyle = `rgba(255, 215, 80, ${0.06 + 0.04 * pulse})`;
      ctx.fillRect(8, y + 4, width - 16, h - 8);
      ctx.strokeStyle = `rgba(255, 215, 80, ${0.5 + 0.4 * pulse})`;
      ctx.lineWidth = 2;
      ctx.strokeRect(8, y + 4, width - 16, h - 8);
    } else {
      ctx.fillStyle = focused ? "rgba(93, 214, 255, 0.05)" : "rgba(255,255,255,0.015)";
      ctx.fillRect(8, y + 4, width - 16, h - 8);
    }
    ctx.restore();

    // Label.
    ctx.save();
    ctx.font = "bold 18px 'Segoe UI', sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "top";
    if (isPinnacle) {
      ctx.fillStyle = "#ffd750";
      ctx.shadowColor = "#ffd750";
      ctx.shadowBlur = 14;
    } else {
      ctx.fillStyle = unlocked ? "#ffffff" : "#666688";
    }
    ctx.fillText(world.label, 24, y + 12);
    ctx.restore();

    // Padlock (locked, non-secret world). Secret locked worlds aren't even rendered.
    if (!unlocked && !isPinnacle) {
      ctx.save();
      ctx.fillStyle = "#666688";
      ctx.font = "16px 'Segoe UI', sans-serif";
      ctx.textBaseline = "top";
      ctx.fillText("🔒 LOCKED", 24, y + 36);
      ctx.restore();
    }

    // Path & nodes.
    const pathLeft = 200;
    const pathRight = width - 60;
    const pathY = y + h * 0.55;
    const nodeR = Math.min(34, Math.max(22, Math.floor(h * 0.18)));
    const count = stages.length;

    // Dotted connecting path.
    if (count > 1) {
      ctx.save();
      ctx.strokeStyle = unlocked ? "rgba(255,255,255,0.35)" : "rgba(120,120,160,0.25)";
      ctx.lineWidth = 3;
      ctx.setLineDash([6, 8]);
      ctx.beginPath();
      ctx.moveTo(pathLeft, pathY);
      ctx.lineTo(pathRight, pathY);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.restore();
    }

    // Stage node positions.
    for (let s = 0; s < count; s++) {
      const t = count === 1 ? 0.5 : s / (count - 1);
      const cx = pathLeft + (pathRight - pathLeft) * t;
      const cy = pathY;
      this._drawStageNode(ctx, stages[s], cx, cy, nodeR, wIdx, s, isPinnacle);
    }
  }

  _drawStageNode(ctx, node, cx, cy, r, wIdx, sIdx, isPinnacle) {
    const focused = this.cursor.w === wIdx && this.cursor.s === sIdx;
    const { stage, unlocked, cleared } = node;
    this._nodeRects.push({ cx, cy, r: r + 6, w: wIdx, s: sIdx });

    ctx.save();

    // Pulse halo for the focused-and-available node.
    if (focused && unlocked) {
      const pulse = 0.5 + 0.5 * Math.sin(this.t * 6);
      ctx.beginPath();
      ctx.arc(cx, cy, r + 8 + pulse * 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${this._hexToRgb(stage.color)}, ${0.15 + 0.15 * pulse})`;
      ctx.fill();
    }

    // Pinnacle gold burst behind its node.
    if (isPinnacle && unlocked) {
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(this.t * 0.4);
      ctx.strokeStyle = "rgba(255, 215, 80, 0.55)";
      ctx.lineWidth = 2;
      for (let i = 0; i < 8; i++) {
        ctx.rotate(Math.PI / 4);
        ctx.beginPath();
        ctx.moveTo(0, r + 8);
        ctx.lineTo(0, r + 22);
        ctx.stroke();
      }
      ctx.restore();
    }

    // Body.
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fillStyle = unlocked ? "#1b1130" : "#0d0d18";
    ctx.fill();
    ctx.lineWidth = focused ? 3 : 2;
    if (isPinnacle && unlocked) {
      ctx.strokeStyle = "#ffd750";
      ctx.shadowColor = "#ffd750";
      ctx.shadowBlur = 18;
    } else {
      ctx.strokeStyle = focused ? stage.color : (unlocked ? "#444466" : "#222233");
    }
    ctx.stroke();
    ctx.shadowBlur = 0;

    // Inner color hex (boss icon).
    ctx.globalAlpha = unlocked ? 1 : 0.35;
    ctx.fillStyle = stage.color;
    const hexR = r * 0.55;
    ctx.beginPath();
    for (let k = 0; k < 6; k++) {
      const a = (k / 6) * Math.PI * 2 + Math.PI / 6;
      const px = cx + Math.cos(a) * hexR, py = cy + Math.sin(a) * hexR;
      if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;

    // Status overlay: ✓ for cleared, lock icon for locked.
    if (cleared) {
      ctx.fillStyle = "#ffe25d";
      ctx.shadowColor = "#ffe25d";
      ctx.shadowBlur = 10;
      ctx.font = `bold ${Math.floor(r * 0.9)}px 'Segoe UI', sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("★", cx + r * 0.7, cy - r * 0.7);
      ctx.shadowBlur = 0;
    } else if (!unlocked) {
      ctx.fillStyle = "rgba(0,0,0,0.55)";
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#888899";
      ctx.font = `${Math.floor(r * 0.95)}px 'Segoe UI', sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("🔒", cx, cy);
    }

    // Stage name + bpm below.
    ctx.fillStyle = unlocked ? "#ffffff" : "#666688";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    ctx.fillText(stage.name, cx, cy + r + 8);

    if (unlocked) {
      ctx.fillStyle = "#aaaadd";
      ctx.font = "11px 'Segoe UI', sans-serif";
      ctx.fillText(`${stage.bpm} BPM`, cx, cy + r + 26);
      const best = this.progress[stage.id]?.grade;
      if (best) {
        ctx.fillStyle = "#ffe25d";
        ctx.font = "bold 11px 'Segoe UI', sans-serif";
        ctx.fillText(`Best: ${best}`, cx, cy + r + 40);
      }
    }
    ctx.restore();
  }

  _drawRevealOverlay(ctx) {
    const { width, height } = ctx.canvas;
    const T = this.revealT;
    const D = this.revealDuration;
    const p = Math.min(1, T / D);

    // Three rough phases: darken (0..0.3), gold burst (0.3..0.7), fade out (0.7..1).
    let darkA = 0, burstA = 0, textA = 0;
    if (p < 0.3) {
      darkA = (p / 0.3) * 0.85;
    } else if (p < 0.7) {
      darkA = 0.85;
      burstA = (p - 0.3) / 0.4;
      textA = burstA;
    } else {
      const k = (p - 0.7) / 0.3;
      darkA = 0.85 * (1 - k);
      burstA = 1 - k;
      textA = 1 - k;
    }

    ctx.save();
    ctx.fillStyle = `rgba(0,0,0,${darkA})`;
    ctx.fillRect(0, 0, width, height);

    // Gold rays radiating from center.
    if (burstA > 0) {
      const cx = width / 2, cy = height / 2;
      const rays = 24;
      const radius = Math.max(width, height);
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(T * 0.5);
      ctx.strokeStyle = `rgba(255, 215, 80, ${0.5 * burstA})`;
      ctx.lineWidth = 4;
      for (let i = 0; i < rays; i++) {
        ctx.rotate((Math.PI * 2) / rays);
        ctx.beginPath();
        ctx.moveTo(0, 40);
        ctx.lineTo(0, radius);
        ctx.stroke();
      }
      ctx.restore();

      const rGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 280);
      rGrad.addColorStop(0, `rgba(255, 230, 120, ${0.55 * burstA})`);
      rGrad.addColorStop(1, "rgba(255, 215, 80, 0)");
      ctx.fillStyle = rGrad;
      ctx.fillRect(0, 0, width, height);
    }

    if (textA > 0) {
      ctx.globalAlpha = textA;
      ctx.fillStyle = "#ffd750";
      ctx.shadowColor = "#ffd750";
      ctx.shadowBlur = 30;
      ctx.font = "bold 22px 'Segoe UI', sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("A NEW WORLD HAS APPEARED", width / 2, height / 2 - 30);
      ctx.font = "bold 56px 'Segoe UI', sans-serif";
      ctx.fillText("THE PINNACLE", width / 2, height / 2 + 28);
      ctx.shadowBlur = 0;
    }
    ctx.restore();
  }

  _hexToRgb(hex) {
    const h = hex.replace("#", "");
    const v = h.length === 3
      ? h.split("").map((c) => parseInt(c + c, 16))
      : [0, 2, 4].map((i) => parseInt(h.substr(i, 2), 16));
    return v.join(",");
  }
}

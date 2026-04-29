// Entry point: loads data, boots scene manager, runs the main loop.

import { BeatClock } from "./core/BeatClock.js";
import { InputManager } from "./core/InputManager.js";
import { AudioManager } from "./core/AudioManager.js";
import { SceneManager } from "./core/SceneManager.js";

import { CanvasRenderer } from "./renderer/Canvas.js";
import { BulletRenderer } from "./renderer/BulletRenderer.js";
import { PlayerRenderer } from "./renderer/PlayerRenderer.js";
import { BossRenderer } from "./renderer/BossRenderer.js";

import { FightManager } from "./game/FightManager.js";
import { HUD } from "./ui/HUD.js";
import { StageSelectScene } from "./ui/StageSelect.js";
import { VictoryScene } from "./ui/VictoryScreen.js";
import { MainMenuScene, GameOverScene, LoadingScene } from "./ui/Menus.js";

const ARENA = { x: 60, y: 60, w: 840, h: 600 };

class FightScene {
  constructor({ canvas, input, audio, beatClock, bossData, patternLibrary, stage, musicBuffer, musicBuffers, onVictory, onDefeat, onRestart, onQuit }) {
    this.canvas = canvas;
    this.input = input;
    this.audio = audio;
    this.beatClock = beatClock;
    this.stage = stage;
    this.onVictory = onVictory;
    this.onDefeat = onDefeat;
    this.onRestart = onRestart;
    this.onQuit = onQuit;
    this.fight = new FightManager({ bossData, patternLibrary, beatClock, audio, arena: ARENA, musicBuffer, musicBuffers });
    this.bullets = new BulletRenderer();
    this.playerR = new PlayerRenderer();
    this.bossR = new BossRenderer();
    this.hud = new HUD();
    this.canvasR = new CanvasRenderer(canvas);
    this._unsubPress = null;
    this._initialHP = this.fight.player.maxHP;
    this._totalPrompts = 0;
    // Sum prompt counts across all phases for grade calculation.
    const allTimelines = Array.isArray(bossData.phases) && bossData.phases.length
      ? bossData.phases.flatMap((p) => p.timeline ?? [])
      : (bossData.timeline ?? []);
    for (const evt of allTimelines) {
      if (evt.type === "counterattack_window") this._totalPrompts += (evt.duration_beats ?? 8);
    }
    this._scoreSnapshot = 0;
    this._maxComboSnapshot = 0;
    this._perfectSnapshot = 0;
    this._totalHitsSnapshot = 0;

    this._paused = false;
    this._pauseCursor = 0;
    this._pauseButtons = [
      { label: "RESUME",        action: () => this._resume() },
      { label: "RESTART",       action: () => this._restart() },
      { label: "QUIT TO MENU",  action: () => this._quit() },
    ];
    this._pauseButtonRects = [];
    this._onCanvasClick = (e) => this._handlePauseClick(e);
    this._onCanvasMove = (e) => this._handlePauseMove(e);
  }

  enter() {
    this.fight.start();
    this._unsubPress = this.input.onPress((key) => {
      if (this._paused) return;
      if (key === "space" || key === "z") this.fight.handleAttackPress();
    });
    this.canvas.addEventListener("click", this._onCanvasClick);
    this.canvas.addEventListener("mousemove", this._onCanvasMove);
  }

  exit() {
    if (this._unsubPress) this._unsubPress();
    this.canvas.removeEventListener("click", this._onCanvasClick);
    this.canvas.removeEventListener("mousemove", this._onCanvasMove);
    // Make sure the audio context is running for whatever scene comes next.
    if (this.audio?.ctx?.state === "suspended") {
      this.audio.ctx.resume().catch(() => {});
    }
    this.fight.destroy();
  }

  _pause() {
    if (this._paused || this.fight.outcome) return;
    this._paused = true;
    this._pauseCursor = 0;
    if (this.audio?.ctx?.state === "running") {
      this.audio.ctx.suspend().catch(() => {});
    }
    this.audio.blip(440, 0.06, "square", 0.25);
  }

  _resume() {
    if (!this._paused) return;
    this._paused = false;
    if (this.audio?.ctx?.state === "suspended") {
      this.audio.ctx.resume().catch(() => {});
    }
    this.audio.blip(660, 0.06, "square", 0.25);
  }

  _restart() {
    if (this.audio?.ctx?.state === "suspended") {
      this.audio.ctx.resume().catch(() => {});
    }
    this.audio.blip(880, 0.1, "square", 0.3);
    this.onRestart?.();
  }

  _quit() {
    if (this.audio?.ctx?.state === "suspended") {
      this.audio.ctx.resume().catch(() => {});
    }
    this.audio.blip(330, 0.1, "sawtooth", 0.3);
    this.onQuit?.();
  }

  _canvasCoords(e) {
    const rect = this.canvas.getBoundingClientRect();
    const sx = this.canvas.width / rect.width;
    const sy = this.canvas.height / rect.height;
    return { x: (e.clientX - rect.left) * sx, y: (e.clientY - rect.top) * sy };
  }

  _hitButton(x, y) {
    for (let i = 0; i < this._pauseButtonRects.length; i++) {
      const r = this._pauseButtonRects[i];
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) return i;
    }
    return -1;
  }

  _handlePauseClick(e) {
    if (!this._paused) return;
    const { x, y } = this._canvasCoords(e);
    const i = this._hitButton(x, y);
    if (i >= 0) {
      this._pauseCursor = i;
      this._pauseButtons[i].action();
    }
  }

  _handlePauseMove(e) {
    if (!this._paused) return;
    const { x, y } = this._canvasCoords(e);
    const i = this._hitButton(x, y);
    if (i >= 0 && i !== this._pauseCursor) {
      this._pauseCursor = i;
      this.audio.blip(660, 0.04, "square", 0.15);
    }
  }

  update(dt) {
    if (this._paused) {
      // Drain the attack key so it doesn't fire on resume.
      this.input.consumePress("space", "z");

      if (this.input.consumePress("Escape")) { this._resume(); return; }
      if (this.input.consumePress("ArrowDown", "s")) {
        this._pauseCursor = (this._pauseCursor + 1) % this._pauseButtons.length;
        this.audio.blip(660, 0.04, "square", 0.15);
      }
      if (this.input.consumePress("ArrowUp", "w")) {
        this._pauseCursor = (this._pauseCursor - 1 + this._pauseButtons.length) % this._pauseButtons.length;
        this.audio.blip(660, 0.04, "square", 0.15);
      }
      if (this.input.consumePress("Enter")) {
        this._pauseButtons[this._pauseCursor].action();
      }
      return;
    }

    if (this.input.consumePress("Escape")) { this._pause(); return; }

    this.fight.update(dt, this.input);
    this._scoreSnapshot = this.fight.counter.score;
    this._maxComboSnapshot = this.fight.counter.maxCombo;
    this._perfectSnapshot = this.fight.counter.perfectHits;
    this._totalHitsSnapshot = this.fight.counter.totalHits;

    if (this.fight.outcome === "victory") {
      const damageTaken = this._initialHP - this.fight.player.hp;
      const grade = this._computeGrade(damageTaken);
      this.onVictory({
        bossName: this.fight.bossData.name,
        bossId: this.fight.bossData.id,
        score: this._scoreSnapshot,
        perfectHits: this._perfectSnapshot,
        totalPrompts: this._totalPrompts,
        maxCombo: this._maxComboSnapshot,
        damageTaken,
        grade,
      });
    } else if (this.fight.outcome === "defeat") {
      this.onDefeat({
        bossName: this.fight.bossData.name,
        reason: this.fight.defeatReason ?? "death",
      });
    }
  }

  _computeGrade(damageTaken) {
    const perfectRatio = this._totalPrompts > 0 ? this._perfectSnapshot / this._totalPrompts : 0;
    if (damageTaken === 0 && perfectRatio >= 0.9) return "S";
    if (damageTaken === 0 || perfectRatio >= 0.8) return "A";
    if (damageTaken < this._initialHP * 0.5 && perfectRatio >= 0.5) return "B";
    return "C";
  }

  render(ctx) {
    const beatPos = this.beatClock.beatPosition;
    const beatPulse = Math.max(0, 1 - (beatPos - Math.floor(beatPos))) * 0.85;

    const inversion = this.fight.useInversion
      ? { floor: this.fight.floorState, flash: this.fight.floorFlashTimer }
      : null;
    // Phase 2 red cracks reveal as boss HP drops in that phase.
    const redCracks = this.fight.redCracks
      ? { progress: 1 - this.fight.boss.hpRatio }
      : null;
    const fullRedFloor = !!this.fight.fullRedFloor;
    const bossColorMode = this.fight.bossColorMode || "color";

    this.canvasR.drawBackground(beatPulse, this.fight.boss.color, inversion, ARENA, redCracks, fullRedFloor);
    this.canvasR.drawArenaFrame(ARENA, beatPulse, this.fight.boss.color, inversion, redCracks, fullRedFloor);
    this.bossR.draw(ctx, this.fight.boss, beatPulse, inversion, bossColorMode);
    // Aux attacks render BENEATH bullets so bullets that travel along beams stay visible.
    if (this.fight.aux && this.fight.aux.length) {
      for (const a of this.fight.aux) a.render(ctx, this.fight.player);
    }
    this.bullets.draw(ctx, this.fight.pool, inversion);
    this.playerR.draw(ctx, this.fight.player, this.input.isFocus(), inversion);
    this.hud.draw(ctx, this.fight, beatPulse, beatPos);

    if (this._paused) this._drawPauseOverlay(ctx);
  }

  _drawPauseOverlay(ctx) {
    const { width, height } = ctx.canvas;
    ctx.save();
    ctx.fillStyle = "rgba(10,11,22,0.78)";
    ctx.fillRect(0, 0, width, height);

    const accent = this.fight.boss.color || "#5dd6ff";
    ctx.fillStyle = "#ffffff";
    ctx.shadowColor = accent;
    ctx.shadowBlur = 22;
    ctx.font = "bold 64px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("PAUSED", width / 2, height / 2 - 140);

    ctx.shadowBlur = 0;
    const btnW = 320, btnH = 56, gap = 18;
    const totalH = this._pauseButtons.length * btnH + (this._pauseButtons.length - 1) * gap;
    const startY = height / 2 - totalH / 2 + 10;
    this._pauseButtonRects = [];

    this._pauseButtons.forEach((btn, i) => {
      const x = (width - btnW) / 2;
      const y = startY + i * (btnH + gap);
      this._pauseButtonRects.push({ x, y, w: btnW, h: btnH });

      const focused = i === this._pauseCursor;
      ctx.fillStyle = focused ? "#1f1640" : "#13111f";
      ctx.fillRect(x, y, btnW, btnH);
      ctx.lineWidth = focused ? 3 : 1;
      ctx.strokeStyle = focused ? accent : "#444466";
      ctx.strokeRect(x, y, btnW, btnH);

      ctx.fillStyle = focused ? accent : "#aaaadd";
      ctx.font = "bold 22px 'Segoe UI', sans-serif";
      ctx.textBaseline = "middle";
      ctx.fillText(btn.label, x + btnW / 2, y + btnH / 2 + 1);
    });

    ctx.textBaseline = "alphabetic";
    ctx.fillStyle = "#aaaadd";
    ctx.font = "14px 'Segoe UI', sans-serif";
    ctx.fillText("↑ ↓  Choose      ENTER  Confirm      ESC  Resume", width / 2, height - 50);
    ctx.restore();
  }
}

class Game {
  constructor() {
    this.canvas = document.getElementById("game");
    this.ctx = this.canvas.getContext("2d");
    this.input = new InputManager();
    this.audio = new AudioManager();
    this.beatClock = null;
    this.scenes = new SceneManager();
    this.stages = [];
    this.patternLibrary = {};
    this.progress = this._loadProgress();
    this.isAdmin = this._loadAdmin();
    this.last = performance.now();
  }

  async boot() {
    // Audio context is created up front (suspended) so menu sounds don't error.
    // Browser autoplay policy only requires resume() to be called from a user gesture.
    await this.audio.init();
    this.beatClock = new BeatClock(this.audio.ctx);

    const stagesData = await fetch("data/stages.json").then((r) => r.json());
    this.stages = stagesData.stages;
    const patternList = await Promise.all(stagesData.patternFiles.map((p) => fetch(p).then((r) => r.json())));
    for (const pat of patternList) this.patternLibrary[pat.id] = pat;

    this.scenes.set(new MainMenuScene({
      canvas: this.canvas, input: this.input, audio: this.audio,
      onStart: () => this._resumeAudioAndGoToSelect(),
      isAdmin: this.isAdmin,
      onAdminToggle: (on) => { this.isAdmin = on; this._saveAdmin(); },
    }));
    requestAnimationFrame((t) => this._loop(t));
  }

  async _resumeAudioAndGoToSelect() {
    try { await this.audio.resume(); }
    catch (err) { console.warn("Audio resume failed:", err); }
    this._gotoStageSelect();
  }

  _gotoStageSelect() {
    this.scenes.set(new StageSelectScene({
      canvas: this.canvas, input: this.input, audio: this.audio,
      stages: this.stages, progress: this.progress,
      isAdmin: this.isAdmin,
      onPick: (stage) => this._startFight(stage),
    }));
  }

  async _startFight(stage) {
    // Show a loading screen while we fetch/decode the boss music (some are >50MB WAVs).
    if (stage.boss) {
      this.scenes.set(new LoadingScene({
        canvas: this.canvas, input: this.input, audio: this.audio, stage,
      }));
    }
    const bossData = await fetch(stage.boss).then((r) => r.json());

    // Multi-phase bosses have a `phases` array, each with its own music.
    // Single-phase bosses still have a top-level `music` field.
    let musicBuffer = null;
    let musicBuffers = null;
    if (Array.isArray(bossData.phases) && bossData.phases.length > 0) {
      musicBuffers = {};
      for (let i = 0; i < bossData.phases.length; i++) {
        const m = bossData.phases[i].music;
        if (!m) continue;
        try {
          musicBuffers[i] = await this.audio.loadBuffer(m);
        } catch (err) {
          console.warn(`Failed to load phase ${i} music (${m}):`, err);
        }
      }
    } else if (bossData.music) {
      try {
        musicBuffer = await this.audio.loadBuffer(bossData.music);
      } catch (err) {
        console.warn("Failed to load boss music, falling back to synth:", err);
      }
    }

    this.scenes.set(new FightScene({
      canvas: this.canvas,
      input: this.input,
      audio: this.audio,
      beatClock: this.beatClock,
      bossData,
      patternLibrary: this.patternLibrary,
      stage,
      musicBuffer,
      musicBuffers,
      onVictory: (summary) => this._onVictory(summary),
      onDefeat: (info) => this._onDefeat(info, stage, bossData),
      onRestart: () => this._startFight(stage),
      onQuit: () => this._gotoStageSelect(),
    }));
  }

  _onVictory(summary) {
    const prev = this.progress[summary.bossId] ?? {};
    const gradeRank = (g) => "FCBAS".indexOf(g);
    if (!prev.cleared || gradeRank(summary.grade) > gradeRank(prev.grade ?? "F")) {
      this.progress[summary.bossId] = {
        cleared: true,
        grade: summary.grade,
        score: Math.max(prev.score ?? 0, summary.score),
      };
    } else {
      this.progress[summary.bossId] = {
        ...prev,
        cleared: true,
        score: Math.max(prev.score ?? 0, summary.score),
      };
    }
    this._saveProgress();
    this.scenes.set(new VictoryScene({
      canvas: this.canvas, input: this.input, audio: this.audio,
      summary,
      onContinue: () => this._gotoStageSelect(),
    }));
  }

  _onDefeat(info, stage, bossData) {
    this.scenes.set(new GameOverScene({
      canvas: this.canvas, input: this.input, audio: this.audio,
      bossName: info.bossName,
      reason: info.reason,
      onRetry: () => this._startFight(stage),
      onBackToSelect: () => this._gotoStageSelect(),
    }));
  }

  _loadProgress() {
    try {
      const raw = localStorage.getItem("rbh.progress");
      if (raw) return JSON.parse(raw);
    } catch {}
    return {};
  }

  _saveProgress() {
    try { localStorage.setItem("rbh.progress", JSON.stringify(this.progress)); }
    catch {}
  }

  _loadAdmin() {
    try { return localStorage.getItem("rbh.admin") === "1"; }
    catch { return false; }
  }

  _saveAdmin() {
    try { localStorage.setItem("rbh.admin", this.isAdmin ? "1" : "0"); }
    catch {}
  }

  _loop(now) {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;

    try {
      if (this.beatClock) this.beatClock.tick();
      this.scenes.update(dt);
      this.scenes.render(this.ctx);
      this.input.endFrame();
    } catch (err) {
      console.error("Frame error:", err);
    }

    requestAnimationFrame((t) => this._loop(t));
  }
}

const game = new Game();
game.boot().catch((err) => {
  console.error("Boot failed:", err);
  const ctx = document.getElementById("game").getContext("2d");
  ctx.fillStyle = "#0a0b16";
  ctx.fillRect(0, 0, 960, 720);
  ctx.fillStyle = "#ff5d5d";
  ctx.font = "16px monospace";
  ctx.fillText("Failed to load. Run via local HTTP server (start.bat).", 40, 60);
  ctx.fillText(String(err), 40, 90);
});

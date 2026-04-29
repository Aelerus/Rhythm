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
  constructor({ canvas, input, audio, beatClock, bossData, patternLibrary, stage, musicBuffer, onVictory, onDefeat }) {
    this.canvas = canvas;
    this.input = input;
    this.audio = audio;
    this.beatClock = beatClock;
    this.stage = stage;
    this.onVictory = onVictory;
    this.onDefeat = onDefeat;
    this.fight = new FightManager({ bossData, patternLibrary, beatClock, audio, arena: ARENA, musicBuffer });
    this.bullets = new BulletRenderer();
    this.playerR = new PlayerRenderer();
    this.bossR = new BossRenderer();
    this.hud = new HUD();
    this.canvasR = new CanvasRenderer(canvas);
    this._unsubPress = null;
    this._initialHP = this.fight.player.maxHP;
    this._totalPrompts = 0;
    for (const evt of bossData.timeline) {
      if (evt.type === "counterattack_window") this._totalPrompts += (evt.duration_beats ?? 8);
    }
    this._scoreSnapshot = 0;
    this._maxComboSnapshot = 0;
    this._perfectSnapshot = 0;
    this._totalHitsSnapshot = 0;
  }

  enter() {
    this.fight.start();
    this._unsubPress = this.input.onPress((key) => {
      if (key === "space" || key === "z") this.fight.handleAttackPress();
    });
  }

  exit() {
    if (this._unsubPress) this._unsubPress();
    this.fight.destroy();
  }

  update(dt) {
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

    this.canvasR.drawBackground(beatPulse, this.fight.boss.color);
    this.canvasR.drawArenaFrame(ARENA, beatPulse, this.fight.boss.color);
    this.bossR.draw(ctx, this.fight.boss, beatPulse);
    this.bullets.draw(ctx, this.fight.pool);
    this.playerR.draw(ctx, this.fight.player, this.input.isFocus());
    this.hud.draw(ctx, this.fight, beatPulse, beatPos);
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
    let musicBuffer = null;
    if (bossData.music) {
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
      onVictory: (summary) => this._onVictory(summary),
      onDefeat: (info) => this._onDefeat(info, stage, bossData),
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

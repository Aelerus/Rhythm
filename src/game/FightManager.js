// Orchestrates a single boss fight: drives the timeline, ticks beats,
// schedules audio, and switches between dodge/counter phases.

import { Player } from "./Player.js";
import { BossController } from "./BossController.js";
import { BulletPool } from "./BulletPool.js";
import { PatternEngine } from "./PatternEngine.js";
import { CounterWindow } from "./CounterWindow.js";

export const PHASE_DODGE = "dodge";
export const PHASE_COUNTER = "counter";

export class FightManager {
  constructor({ bossData, patternLibrary, beatClock, audio, arena }) {
    this.bossData = bossData;
    this.beatClock = beatClock;
    this.audio = audio;
    this.arena = arena;

    this.player = new Player(arena);
    this.boss = new BossController(bossData, arena);
    this.pool = new BulletPool(1200);
    this.patternEngine = new PatternEngine(this.pool, patternLibrary);
    this.counter = new CounterWindow(beatClock);

    this.phase = PHASE_DODGE;
    this.timeline = [...(bossData.timeline ?? [])].sort((a, b) => a.beat - b.beat);
    this.fired = new Set();
    this.lastScheduledBeat = -1;

    this.outcome = null; // "victory" | "defeat"
    this.recentHit = null; // last grade flash for HUD
    this.feedback = null;  // ephemeral text bubble
    this.feedbackTimer = 0;

    this.beatClock.setBPM(bossData.bpm ?? 120);

    this.boss.onPhaseChange = (n) => this._onPhaseChange(n);
    this.counter.onHit = (grade, dmg) => this._applyDamage(grade, dmg);
    this.counter.onClose = () => { this.phase = PHASE_DODGE; };

    this._beatUnsub = this.beatClock.on((b) => this._onBeat(b));
  }

  start() {
    this.beatClock.start();
    this._scheduleAudioAhead();
  }

  destroy() {
    if (this._beatUnsub) this._beatUnsub();
  }

  // Schedule audio for the next ~2 seconds.
  _scheduleAudioAhead() {
    const lookahead = 2.0;
    const now = this.beatClock.ctx.currentTime;
    let beat = Math.max(0, this.lastScheduledBeat + 1);
    while (true) {
      const t = this.beatClock.beatTime(beat);
      if (t > now + lookahead) break;
      if (t >= now) {
        this.audio.scheduleKick(t, beat % 4 === 0);
        if (beat % 2 === 1) this.audio.scheduleHat(t);
      }
      this.lastScheduledBeat = beat;
      beat++;
    }
  }

  _onBeat(beat) {
    // Walk the timeline up to this beat, firing entries we haven't fired yet.
    for (const evt of this.timeline) {
      if (evt.beat > beat) break;
      if (this.fired.has(evt)) continue;
      this.fired.add(evt);
      this._handleEvent(evt);
    }
  }

  _handleEvent(evt) {
    if (evt.type === "pattern") {
      if (this.phase === PHASE_COUNTER) return; // bullets pause during counter
      this.patternEngine.fire(evt.id, {
        boss: { x: this.boss.x, y: this.boss.displayY },
        target: { x: this.player.x, y: this.player.y },
        arena: this.arena,
        beatIndex: evt.beat,
      });
    } else if (evt.type === "counterattack_window") {
      this.phase = PHASE_COUNTER;
      this.pool.clear();
      // Prompts begin 2 beats after the window opens so the player sees them approach.
      const leadBeats = 2;
      this.counter.open(evt.beat + leadBeats, evt.duration_beats ?? 8);
    } else if (evt.type === "phase_marker") {
      // pure annotation — no-op
    }
  }

  _onPhaseChange(n) {
    this._showFeedback(`PHASE ${n}`, "#ffd25d", 1.6);
  }

  _applyDamage(grade, dmg) {
    if (dmg > 0) {
      this.boss.takeDamage(dmg);
      this.recentHit = { grade, t: 0 };
    }
  }

  _showFeedback(text, color, duration) {
    this.feedback = { text, color };
    this.feedbackTimer = duration;
  }

  handleAttackPress() {
    if (this.phase !== PHASE_COUNTER) return;
    const baseDamage = this.bossData.counterBaseDamage ?? 40;
    this.counter.registerPress(baseDamage);
  }

  update(dt, input) {
    if (this.outcome) return;

    // Always allow audio scheduling to keep advancing
    this._scheduleAudioAhead();

    this.player.update(dt, input);
    this.boss.update(dt, this.beatClock.beatPosition);
    this.pool.update(dt, this.arena, { x: this.player.x, y: this.player.y });
    this.counter.update(dt);

    if (this.feedbackTimer > 0) this.feedbackTimer -= dt;

    // Bullet collisions only during dodge phase
    if (this.phase === PHASE_DODGE) {
      const hit = this.pool.collideWith(this.player);
      if (hit) {
        const dmg = this.bossData.bulletDamage ?? 8;
        if (this.player.takeDamage(dmg)) {
          hit.active = false;
          const idx = this.pool.active.indexOf(hit);
          if (idx >= 0) this.pool.active.splice(idx, 1);
        }
      }
    }

    if (!this.player.alive) this.outcome = "defeat";
    else if (this.boss.defeated) this.outcome = "victory";
  }
}

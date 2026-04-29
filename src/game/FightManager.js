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
  constructor({ bossData, patternLibrary, beatClock, audio, arena, musicBuffer = null }) {
    this.bossData = bossData;
    this.beatClock = beatClock;
    this.audio = audio;
    this.arena = arena;
    this.musicBuffer = musicBuffer;
    this._musicPlaying = false;

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
    this.defeatReason = null; // "death" | "time_up"
    this.recentHit = null; // last grade flash for HUD
    this.feedback = null;  // ephemeral text bubble
    this.feedbackTimer = 0;
    this._songEndTime = null; // AudioContext time when the song finishes; null = no time limit
    this._songStartTime = null;
    this._songDuration = 0;

    this.beatClock.setBPM(bossData.bpm ?? 120);

    this.boss.onPhaseChange = (n) => this._onPhaseChange(n);
    this.counter.onHit = (grade, dmg) => this._applyDamage(grade, dmg);
    this.counter.onClose = () => { this.phase = PHASE_DODGE; };

    this._beatUnsub = this.beatClock.on((b) => this._onBeat(b));
  }

  start() {
    if (this.musicBuffer) {
      // Schedule music + beat clock together at a small lead so AudioContext can deliver the buffer.
      const startAt = this.beatClock.ctx.currentTime + 0.12;
      this.beatClock.start(startAt);
      const offset = (this.bossData.musicOffset ?? 0);
      const volume = (this.bossData.musicVolume ?? 0.85);
      this.audio.playBuffer(this.musicBuffer, startAt, { offset, volume });
      this._musicPlaying = true;
      this._songStartTime = startAt;
      this._songDuration = Math.max(0, this.musicBuffer.duration - offset);
      this._songEndTime = startAt + this._songDuration;
    } else {
      this.beatClock.start();
      this._scheduleAudioAhead();
    }
  }

  // Seconds until the song ends (only meaningful when there's a music buffer).
  get songTimeRemaining() {
    if (!this._songEndTime) return null;
    return Math.max(0, this._songEndTime - this.beatClock.ctx.currentTime);
  }
  get songProgress() {
    if (!this._songEndTime || !this._songDuration) return 0;
    const elapsed = this.beatClock.ctx.currentTime - this._songStartTime;
    return Math.max(0, Math.min(1, elapsed / this._songDuration));
  }

  destroy() {
    if (this._beatUnsub) this._beatUnsub();
    if (this._musicPlaying) {
      this.audio.fadeOutMusic(0.5);
      this._musicPlaying = false;
    }
  }

  // Schedule synth percussion for the next ~2 seconds (only when there's no song).
  _scheduleAudioAhead() {
    if (this._musicPlaying) return;
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
      // Prompts begin `lead_beats` after the window opens so the player can travel
      // to the parry zone and see the prompts approach.
      const leadBeats = evt.lead_beats ?? 2;
      const zone = this._resolveZone(evt.zone);
      this.counter.open(evt.beat + leadBeats, evt.duration_beats ?? 8, zone);
    } else if (evt.type === "phase_marker") {
      // pure annotation — no-op
    }
  }

  _onPhaseChange(n) {
    this._showFeedback(`PHASE ${n}`, "#ffd25d", 1.6);
  }

  // Translate a timeline zone descriptor into arena pixel coordinates.
  // Supports either a named anchor or {x, y} fractions (0..1) of the arena.
  _resolveZone(zone) {
    if (!zone) return null;
    const A = this.arena;
    const r = zone.radius ?? 70;
    if (zone.anchor) {
      const anchors = {
        center:       [0.5,  0.5],
        top:          [0.5,  0.22],
        bottom:       [0.5,  0.78],
        left:         [0.22, 0.5],
        right:        [0.78, 0.5],
        topLeft:      [0.22, 0.25],
        topRight:     [0.78, 0.25],
        bottomLeft:   [0.22, 0.75],
        bottomRight:  [0.78, 0.75],
      };
      const a = anchors[zone.anchor] ?? [0.5, 0.5];
      return { x: A.x + A.w * a[0], y: A.y + A.h * a[1], radius: r };
    }
    const fx = zone.x ?? 0.5;
    const fy = zone.y ?? 0.5;
    return { x: A.x + A.w * fx, y: A.y + A.h * fy, radius: r };
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
    this.counter.registerPress(baseDamage, this.player);
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

    if (!this.player.alive) {
      this.outcome = "defeat";
      this.defeatReason = "death";
    } else if (this.boss.defeated) {
      this.outcome = "victory";
    } else if (this._songEndTime && this.beatClock.ctx.currentTime >= this._songEndTime) {
      // Song ran out and the boss is still standing — DPS check failed.
      this.outcome = "defeat";
      this.defeatReason = "time_up";
    }
  }
}

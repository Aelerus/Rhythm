// Orchestrates a single boss fight: drives the timeline, ticks beats,
// schedules audio, and switches between dodge/counter phases.
//
// Multi-phase support:
//   bossData.phases = [{ music, bpm, hp, bulletDamage, useInversion, ...,
//                        timeline: [...] }, ...]
// Each phase has its own song + timeline. When the current phase's HP hits 0,
// the FightManager fades out the music, briefly stuns the boss, then starts
// the next phase: new music, beat clock reset to 0, new timeline. Combo
// resets between phases. The final phase optionally plays a fall-off-screen
// death animation before declaring victory.
//
// Backward compatible: bosses without a `phases` array are wrapped as a
// single-phase fight using the legacy top-level fields.

import { Player } from "./Player.js";
import { BossController } from "./BossController.js";
import { BulletPool } from "./BulletPool.js";
import { PatternEngine } from "./PatternEngine.js";
import { CounterWindow } from "./CounterWindow.js";
import { TetherAttack, GravityWell, RealityTear } from "./AuxAttacks.js";

export const PHASE_DODGE = "dodge";
export const PHASE_COUNTER = "counter";

export class FightManager {
  // `musicBuffers` is now a map from phase index -> AudioBuffer (or a single
  // buffer for legacy single-phase). For convenience we also accept the
  // legacy `musicBuffer` arg.
  constructor({ bossData, patternLibrary, beatClock, audio, arena, musicBuffer = null, musicBuffers = null }) {
    this.bossData = bossData;
    this.beatClock = beatClock;
    this.audio = audio;
    this.arena = arena;

    // Build phases array. If the boss has no `phases` field, wrap the legacy
    // top-level fields as a single phase.
    if (Array.isArray(bossData.phases) && bossData.phases.length > 0) {
      this._phases = bossData.phases;
    } else {
      this._phases = [{
        displayPhase: bossData.displayPhase,
        music: bossData.music,
        bpm: bossData.bpm ?? 120,
        musicVolume: bossData.musicVolume,
        musicOffset: bossData.musicOffset,
        useInversion: bossData.useInversion,
        startFloor: bossData.startFloor,
        redCracks: false,
        fullRedFloor: false,
        bossColorMode: bossData.useInversion ? "inversion" : "color",
        fallOnDeath: false,
        hp: bossData.maxHP ?? 1000,
        bulletDamage: bossData.bulletDamage ?? 8,
        timeline: bossData.timeline ?? [],
      }];
    }

    // Music buffers: prefer the explicit map, fall back to legacy single buffer for phase 0.
    this._musicBuffers = musicBuffers ?? (musicBuffer ? { 0: musicBuffer } : {});

    this.player = new Player(arena);
    this.boss = new BossController(bossData, arena);
    this.pool = new BulletPool(1500);
    this.patternEngine = new PatternEngine(this.pool, patternLibrary);
    this.counter = new CounterWindow(beatClock);

    this.phase = PHASE_DODGE;
    this.fired = new Set();
    this.lastScheduledBeat = -1;
    this.timeline = [];

    // Aux attacks: persistent stateful attacks (tethers, gravity wells, tears).
    // PatternEngine queues them via FightManager.spawnAux(); we update + render.
    this.aux = [];

    this.outcome = null;
    this.defeatReason = null;
    this.recentHit = null;
    this.feedback = null;
    this.feedbackTimer = 0;
    this._songEndTime = null;
    this._songStartTime = null;
    this._songDuration = 0;
    this._musicPlaying = false;

    // Multi-phase + visual state
    this._currentPhaseIndex = 0;
    this._phaseTransitioning = false;
    this._phaseTransitionTimer = 0;
    this.floorState = "white";
    this.floorFlashTimer = 0;
    this.useInversion = false;
    this.redCracks = false;
    this.fullRedFloor = false;
    this.bossColorMode = "color";
    this.fallOnDeath = false;

    // Boss callbacks
    this.boss.onPhaseChange = (n) => this._onPhaseChange(n);
    this.counter.onHit = (grade, dmg) => this._applyDamage(grade, dmg);
    this.counter.onClose = () => { this.phase = PHASE_DODGE; };

    this._beatUnsub = this.beatClock.on((b) => this._onBeat(b));

    // Apply phase 0 config (music starts in start())
    this._applyPhaseConfig(0);
  }

  // --- Multi-phase machinery ---------------------------------------------

  // Apply data-only config for phase `idx` (timeline, BPM, HP, visual flags).
  // Music is started separately in _startPhaseMusic.
  _applyPhaseConfig(idx) {
    const phase = this._phases[idx];
    this._currentPhaseIndex = idx;
    this.currentPhase = phase;

    this.boss.setPhaseHP(phase.hp ?? 1000);
    this.timeline = [...(phase.timeline ?? [])].sort((a, b) => a.beat - b.beat);
    this.fired = new Set();
    this.lastScheduledBeat = -1;
    this.beatClock.setBPM(phase.bpm ?? 120);

    // Visual config
    this.useInversion = !!phase.useInversion;
    this.floorState = phase.startFloor ?? this.floorState ?? "white";
    this.redCracks = !!phase.redCracks;
    this.fullRedFloor = !!phase.fullRedFloor;
    this.bossColorMode = phase.bossColorMode ?? "color";
    this.fallOnDeath = !!phase.fallOnDeath;
    this.floorFlashTimer = 0;
    this.bulletDamage = phase.bulletDamage ?? 8;

    // Reset combo each phase (so per-phase HP math is independent).
    this.counter.combo = 0;
    this.counter.zone = null;
    this.counter.active = false;
    this.phase = PHASE_DODGE;
  }

  _startPhaseMusic(idx) {
    const phase = this._phases[idx];
    const buffer = this._musicBuffers[idx];
    if (buffer) {
      const startAt = this.beatClock.ctx.currentTime + 0.12;
      this.beatClock.start(startAt);
      const offset = phase.musicOffset ?? 0;
      const volume = phase.musicVolume ?? 0.85;
      this.audio.playBuffer(buffer, startAt, { offset, volume });
      this._musicPlaying = true;
      this._songStartTime = startAt;
      this._songDuration = Math.max(0, buffer.duration - offset);
      this._songEndTime = startAt + this._songDuration;
    } else {
      this.beatClock.start();
      this._songEndTime = null;
      this._songStartTime = null;
      this._songDuration = 0;
      this._musicPlaying = false;
    }
  }

  _beginPhaseTransition() {
    this._phaseTransitioning = true;
    this._phaseTransitionTimer = 1.4;
    // Visual: clear bullets, brief boss flash, fade music
    this.pool.clear();
    this.aux.length = 0;
    this.boss.flashTimer = 1.4;
    if (this._musicPlaying) {
      this.audio.fadeOutMusic(0.6);
      this._musicPlaying = false;
    }
    this.counter.combo = 0;
    this.counter.maxCombo = Math.max(this.counter.maxCombo, this.counter.combo);
    this.counter.active = false;
    this.counter.zone = null;
    this.phase = PHASE_DODGE;
    this._showFeedback(`PHASE ${this._currentPhaseIndex + 2}`, "#ff3a3a", 1.6);
  }

  _updatePhaseTransition(dt) {
    this._phaseTransitionTimer -= dt;
    if (this._phaseTransitionTimer <= 0) {
      this._phaseTransitioning = false;
      const next = this._currentPhaseIndex + 1;
      this._applyPhaseConfig(next);
      this._startPhaseMusic(next);
    }
  }

  // --- Lifecycle ----------------------------------------------------------

  start() {
    this._startPhaseMusic(0);
    if (!this._musicPlaying) {
      // No music for phase 0 — fall back to synth percussion (legacy bosses).
      this._scheduleAudioAhead();
    }
  }

  destroy() {
    if (this._beatUnsub) this._beatUnsub();
    if (this._musicPlaying) {
      this.audio.fadeOutMusic(0.5);
      this._musicPlaying = false;
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

  // True when this is the last phase in the fight.
  get isFinalPhase() {
    return this._currentPhaseIndex >= this._phases.length - 1;
  }
  get currentPhaseIndex() { return this._currentPhaseIndex; }

  // --- Audio scheduling (synth fallback) ----------------------------------

  _scheduleAudioAhead() {
    if (this._musicPlaying) return;
    if (this._phaseTransitioning) return;
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

  // --- Beat / event handling ----------------------------------------------

  _onBeat(beat) {
    if (this._phaseTransitioning) return;
    for (const evt of this.timeline) {
      if (evt.beat > beat) break;
      if (this.fired.has(evt)) continue;
      this.fired.add(evt);
      this._handleEvent(evt);
    }
  }

  _handleEvent(evt) {
    if (evt.type === "pattern") {
      if (this.phase === PHASE_COUNTER) return;
      this.patternEngine.fire(evt.patternData ?? evt.id, {
        boss: { x: this.boss.x, y: this.boss.displayY },
        bossRef: this.boss, // live reference for tethers
        target: { x: this.player.x, y: this.player.y },
        arena: this.arena,
        beatIndex: evt.beat,
        spawnAux: (a) => this.aux.push(a),
      });
    } else if (evt.type === "counterattack_window") {
      this.phase = PHASE_COUNTER;
      this.pool.clear();
      const leadBeats = evt.lead_beats ?? 2;
      const zone = this._resolveZone(evt.zone);
      this.counter.open(evt.beat + leadBeats, evt.duration_beats ?? 8, zone);
    } else if (evt.type === "floor_invert") {
      this.floorState = evt.to ?? (this.floorState === "white" ? "black" : "white");
      this.floorFlashTimer = 0.45;
    }
  }

  _onPhaseChange(_n) {
    // No-op: phase changes are now driven by HP-based phase transitions, not
    // boss.phaseThresholds. The HUD shows displayPhase from the current phase.
  }

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
    if (this._phaseTransitioning) return;
    const baseDamage = this.bossData.counterBaseDamage ?? 40;
    this.counter.registerPress(baseDamage, this.player);
  }

  // Debug: instantly drop the current phase's HP to 0. Triggers the normal
  // phase-transition flow (or victory/fall on the final phase). Admin-only —
  // FightScene gates this on the admin flag.
  debugKillPhase() {
    if (this._phaseTransitioning) return;
    if (this.outcome) return;
    if (this.boss.dying) return;
    this.boss.hp = 0;
    this.boss.flashTimer = 0.4;
  }

  // --- Per-frame update ---------------------------------------------------

  update(dt, input) {
    if (this.outcome) return;

    if (this._phaseTransitioning) {
      this._updatePhaseTransition(dt);
      // Still let player + boss visuals tick during the transition for smoothness.
      this.player.update(dt, input);
      this.boss.update(dt, this.beatClock.beatPosition);
      this.counter.update(dt);
      if (this.feedbackTimer > 0) this.feedbackTimer -= dt;
      if (this.floorFlashTimer > 0) this.floorFlashTimer -= dt;
      return;
    }

    this._scheduleAudioAhead();

    this.player.update(dt, input);
    this.boss.update(dt, this.beatClock.beatPosition);
    this.pool.update(dt, this.arena, { x: this.player.x, y: this.player.y });
    this.counter.update(dt);
    this.patternEngine.recordPlayerTrail(this.player, this.beatClock.songTime);

    // Tick aux attacks (tethers/wells/tears) and prune dead ones.
    if (this.phase === PHASE_DODGE) {
      for (const a of this.aux) a.update(dt, this.player, this.pool);
      if (this.aux.length) this.aux = this.aux.filter((a) => !a.dead);
    }

    if (this.feedbackTimer > 0) this.feedbackTimer -= dt;
    if (this.floorFlashTimer > 0) this.floorFlashTimer -= dt;

    if (this.phase === PHASE_DODGE) {
      const floorForCollide = this.useInversion ? this.floorState : null;
      const hit = this.pool.collideWith(this.player, floorForCollide);
      if (hit) {
        const dmg = this.bulletDamage ?? this.bossData.bulletDamage ?? 8;
        if (this.player.takeDamage(dmg)) {
          hit.active = false;
          const idx = this.pool.active.indexOf(hit);
          if (idx >= 0) this.pool.active.splice(idx, 1);
        }
      }
    }

    // Outcome resolution
    if (!this.player.alive) {
      this.outcome = "defeat";
      this.defeatReason = "death";
      return;
    }

    if (this.boss.defeated) {
      if (!this.isFinalPhase) {
        this._beginPhaseTransition();
        return;
      }
      // Final phase: optional fall-on-death animation, then victory.
      if (this.fallOnDeath) {
        if (!this.boss.dying) this.boss.beginFall();
        if (this.boss.deathDone) this.outcome = "victory";
      } else {
        this.outcome = "victory";
      }
      return;
    }

    if (this._songEndTime && this.beatClock.ctx.currentTime >= this._songEndTime) {
      // Per-phase time-up: if more phases remain, advance instead of defeat
      // (the song just timed out — let the boss carry into the next phase).
      // But if we're on the LAST phase, that's a real loss.
      if (this.isFinalPhase) {
        this.outcome = "defeat";
        this.defeatReason = "time_up";
      } else {
        this._beginPhaseTransition();
      }
    }
  }
}

// Manages a counterattack window: when active, beats produce prompts.
// Players hit the attack key on each prompt; timing is graded.

export const GRADES = {
  PERFECT: { name: "PERFECT", multiplier: 1.0, points: 100, color: "#ffe25d" },
  GOOD:    { name: "GOOD",    multiplier: 0.6, points: 60,  color: "#5dffae" },
  MISS:    { name: "MISS",    multiplier: 0.0, points: 0,   color: "#ff5d5d" },
};

const PERFECT_WINDOW = 0.05; // ±50ms
const GOOD_WINDOW    = 0.12; // ±120ms

export class CounterWindow {
  constructor(beatClock) {
    this.clock = beatClock;
    this.active = false;
    this.startBeat = 0;
    this.durationBeats = 8;
    this.prompts = [];        // [{ beat, time, hit, grade }]
    this.combo = 0;
    this.maxCombo = 0;
    this.flashGrade = null;
    this.flashTimer = 0;
    this.totalDamage = 0;
    this.score = 0;
    this.totalHits = 0;
    this.perfectHits = 0;

    // Parry-zone gating: if zone is set, player must be inside it to register a hit.
    this.zone = null;         // { x, y, radius } in arena pixels, or null = no gating
    this.outOfRangeFlash = 0; // brief HUD warning timer when a press is rejected for being outside the zone

    this.onHit = null;        // (grade, damage) => void
    this.onClose = null;      // (summary) => void
  }

  open(startBeat, durationBeats, zone = null) {
    this.active = true;
    this.startBeat = startBeat;
    this.durationBeats = durationBeats;
    this.zone = zone;
    this.outOfRangeFlash = 0;
    this.prompts = [];
    for (let i = 0; i < durationBeats; i++) {
      const beat = startBeat + i;
      this.prompts.push({
        beat, time: this.clock.beatTime(beat),
        hit: false, grade: null,
      });
    }
  }

  isInZone(player) {
    if (!this.zone || !player) return true;
    const dx = player.x - this.zone.x;
    const dy = player.y - this.zone.y;
    return dx * dx + dy * dy <= this.zone.radius * this.zone.radius;
  }

  close() {
    if (!this.active) return;
    this.active = false;
    const summary = {
      totalHits: this.totalHits,
      perfectHits: this.perfectHits,
      promptCount: this.prompts.length,
      damage: this.totalDamage,
      maxCombo: this.maxCombo,
    };
    if (this.onClose) this.onClose(summary);
  }

  update(dt) {
    if (this.flashTimer > 0) this.flashTimer -= dt;
    if (this.outOfRangeFlash > 0) this.outOfRangeFlash -= dt;
    if (!this.active) return;
    const t = this.clock.ctx.currentTime;
    // Auto-miss any prompts past the GOOD window with no hit
    for (const p of this.prompts) {
      if (!p.hit && t > p.time + GOOD_WINDOW) {
        p.hit = true;
        p.grade = GRADES.MISS;
        this.combo = 0;
        this._flash(GRADES.MISS);
      }
    }
    // Close when last prompt has been resolved
    const last = this.prompts[this.prompts.length - 1];
    if (last && t > last.time + GOOD_WINDOW + 0.1) this.close();
  }

  // Player pressed the attack key. Find the nearest unresolved prompt and grade it.
  // If a parry zone is active, player must be inside it for the press to count.
  registerPress(baseDamage = 40, player = null) {
    if (!this.active) return null;
    if (this.zone && !this.isInZone(player)) {
      this.outOfRangeFlash = 0.45;
      return { rejected: "out_of_range" };
    }
    const t = this.clock.ctx.currentTime;
    let best = null;
    let bestDist = Infinity;
    for (const p of this.prompts) {
      if (p.hit) continue;
      const d = Math.abs(p.time - t);
      if (d < bestDist) { bestDist = d; best = p; }
    }
    if (!best) return null;
    if (bestDist > GOOD_WINDOW + 0.05) return null; // ignore wild presses

    let grade;
    if (bestDist <= PERFECT_WINDOW) grade = GRADES.PERFECT;
    else if (bestDist <= GOOD_WINDOW) grade = GRADES.GOOD;
    else grade = GRADES.MISS;

    best.hit = true;
    best.grade = grade;

    if (grade === GRADES.MISS) {
      this.combo = 0;
    } else {
      this.combo++;
      if (this.combo > this.maxCombo) this.maxCombo = this.combo;
      this.totalHits++;
      if (grade === GRADES.PERFECT) this.perfectHits++;
    }

    const comboMult = 1 + Math.min(1, this.combo / 16); // up to 2x
    const damage = baseDamage * grade.multiplier * comboMult;
    this.totalDamage += damage;
    this.score += grade.points * comboMult;

    this._flash(grade);
    if (this.onHit) this.onHit(grade, damage);
    return { grade, damage };
  }

  _flash(grade) {
    this.flashGrade = grade;
    this.flashTimer = 0.55;
  }

  // Helper for renderer: returns prompts with timing data relative to "now"
  visiblePrompts() {
    if (!this.active) return [];
    const t = this.clock.ctx.currentTime;
    return this.prompts.map((p) => ({
      ...p,
      delta: p.time - t, // seconds until this prompt's beat
    }));
  }
}

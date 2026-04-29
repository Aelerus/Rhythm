// Boss state: HP, position, phase, hit reactions.
// Supports multi-phase fights — setPhaseHP() refills health for the next phase
// and beginFall() triggers a death animation that drops the boss off-screen.

export class BossController {
  constructor(data, arena) {
    this.data = data;
    this.arena = arena;
    this.maxHP = data.maxHP ?? 1000;
    this.hp = this.maxHP;
    this.x = arena.x + arena.w / 2;
    this.y = arena.y + 110;
    this.color = data.color ?? "#ff5dd6";
    this.flashTimer = 0;
    this.bobPhase = 0;
    this.phase = 1;
    this.phaseThresholds = data.phaseThresholds ?? [0.75, 0.5, 0.25];
    this.onPhaseChange = null;

    // Death-fall animation state
    this.dying = false;
    this.fallVelocity = 0;
    this.fallY = 0;
    this.fallAlpha = 1;
    this.deathDone = false;
  }

  // Reset HP for a new phase (max-HP also updates so the bar reads correctly).
  setPhaseHP(hp) {
    this.maxHP = hp;
    this.hp = hp;
  }

  // Start the falling-off-the-screen death animation. Triggered by FightManager
  // on the final phase when boss HP reaches 0 (only when phase has fallOnDeath).
  beginFall() {
    if (this.dying) return;
    this.dying = true;
    this.fallVelocity = -40; // small upward kick first, then gravity takes over
  }

  update(dt, beatPosition) {
    this.bobPhase = beatPosition * Math.PI * 2;
    if (this.flashTimer > 0) this.flashTimer -= dt;

    if (this.dying && !this.deathDone) {
      // Quadratic fall, slight fade
      this.fallVelocity += 800 * dt;
      this.fallY += this.fallVelocity * dt;
      // Fade only after we're below the arena floor
      if (this.fallY > 200) {
        this.fallAlpha = Math.max(0, this.fallAlpha - dt * 0.7);
      }
      if (this.fallY > 900 || this.fallAlpha <= 0) {
        this.deathDone = true;
      }
    }
  }

  get displayY() {
    return this.y + Math.sin(this.bobPhase) * 6 + this.fallY;
  }

  takeDamage(amount) {
    if (this.dying) return;
    this.hp = Math.max(0, this.hp - amount);
    this.flashTimer = 0.18;
    const ratio = this.hp / this.maxHP;
    let newPhase = 1;
    for (let i = 0; i < this.phaseThresholds.length; i++) {
      if (ratio < this.phaseThresholds[i]) newPhase = i + 2;
    }
    if (newPhase !== this.phase) {
      this.phase = newPhase;
      if (this.onPhaseChange) this.onPhaseChange(this.phase);
    }
  }

  get hpRatio() { return this.hp / this.maxHP; }
  // "Defeated" means HP is gone, but for the LAST phase with fallOnDeath the
  // FightManager waits for `deathDone` to mark the fight as victory.
  get defeated() { return this.hp <= 0; }
}

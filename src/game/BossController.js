// Boss state: HP, position, phase, hit reactions.

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
  }

  update(dt, beatPosition) {
    this.bobPhase = beatPosition * Math.PI * 2;
    if (this.flashTimer > 0) this.flashTimer -= dt;
  }

  get displayY() {
    return this.y + Math.sin(this.bobPhase) * 6;
  }

  takeDamage(amount) {
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
  get defeated() { return this.hp <= 0; }
}

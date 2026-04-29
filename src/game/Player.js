// Player state. Movement and health logic only — drawing lives in PlayerRenderer.

export class Player {
  constructor(arena) {
    this.arena = arena;          // { x, y, w, h }
    this.x = arena.x + arena.w / 2;
    this.y = arena.y + arena.h * 0.75;
    this.baseSpeed = 280;        // px/sec
    this.focusSpeed = 130;
    this.radius = 14;            // visual size
    this.hitboxRadius = 4;       // tiny core hitbox (bullet hell convention)
    this.maxHP = 100;
    this.hp = this.maxHP;
    this.iframes = 0;            // brief grace after a hit
    this.iframeDuration = 0.7;
    this.alive = true;
    this.flashTimer = 0;
  }

  reset() {
    this.x = this.arena.x + this.arena.w / 2;
    this.y = this.arena.y + this.arena.h * 0.75;
    this.hp = this.maxHP;
    this.iframes = 0;
    this.alive = true;
    this.flashTimer = 0;
  }

  update(dt, input) {
    if (!this.alive) return;
    const v = input.movementVector();
    const focus = input.isFocus();
    const speed = focus ? this.focusSpeed : this.baseSpeed;
    this.x += v.x * speed * dt;
    this.y += v.y * speed * dt;

    // Clamp to arena
    const pad = this.radius;
    if (this.x < this.arena.x + pad) this.x = this.arena.x + pad;
    if (this.x > this.arena.x + this.arena.w - pad) this.x = this.arena.x + this.arena.w - pad;
    if (this.y < this.arena.y + pad) this.y = this.arena.y + pad;
    if (this.y > this.arena.y + this.arena.h - pad) this.y = this.arena.y + this.arena.h - pad;

    if (this.iframes > 0) this.iframes -= dt;
    if (this.flashTimer > 0) this.flashTimer -= dt;
  }

  takeDamage(amount) {
    if (!this.alive || this.iframes > 0) return false;
    this.hp -= amount;
    this.iframes = this.iframeDuration;
    this.flashTimer = 0.2;
    if (this.hp <= 0) {
      this.hp = 0;
      this.alive = false;
    }
    return true;
  }

  isFocus(input) { return input.isFocus(); }
}

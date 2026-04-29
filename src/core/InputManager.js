// Keyboard abstraction. Tracks held keys for movement and edge-triggered presses for actions.

export class InputManager {
  constructor() {
    this.held = new Set();
    this.pressedThisFrame = new Set();
    this.pressCallbacks = new Set();

    window.addEventListener("keydown", (e) => {
      const key = this._normalize(e.key);
      if (!this.held.has(key)) {
        this.pressedThisFrame.add(key);
        for (const cb of this.pressCallbacks) cb(key, e);
      }
      this.held.add(key);
      if (["ArrowUp","ArrowDown","ArrowLeft","ArrowRight"," "].includes(e.key)) {
        e.preventDefault();
      }
    });

    window.addEventListener("keyup", (e) => {
      this.held.delete(this._normalize(e.key));
    });

    window.addEventListener("blur", () => this.held.clear());
  }

  _normalize(k) {
    if (k === " ") return "space";
    return k.length === 1 ? k.toLowerCase() : k;
  }

  isDown(...keys) {
    return keys.some((k) => this.held.has(this._normalize(k)));
  }

  consumePress(...keys) {
    for (const k of keys) {
      const nk = this._normalize(k);
      if (this.pressedThisFrame.has(nk)) {
        this.pressedThisFrame.delete(nk);
        return true;
      }
    }
    return false;
  }

  onPress(cb) { this.pressCallbacks.add(cb); return () => this.pressCallbacks.delete(cb); }

  // Called at end of frame
  endFrame() { this.pressedThisFrame.clear(); }

  // Movement vector with focus-modifier handling done elsewhere
  movementVector() {
    let x = 0, y = 0;
    if (this.isDown("a", "ArrowLeft")) x -= 1;
    if (this.isDown("d", "ArrowRight")) x += 1;
    if (this.isDown("w", "ArrowUp")) y -= 1;
    if (this.isDown("s", "ArrowDown")) y += 1;
    if (x !== 0 && y !== 0) { x *= 0.7071; y *= 0.7071; }
    return { x, y };
  }

  isFocus() { return this.isDown("Shift"); }
}

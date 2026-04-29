// Tiny scene stack. Active scene receives update() and render() each frame.

export class SceneManager {
  constructor() {
    this.current = null;
  }

  set(scene) {
    if (this.current && this.current.exit) this.current.exit();
    this.current = scene;
    if (scene && scene.enter) scene.enter();
  }

  update(dt) {
    if (this.current && this.current.update) this.current.update(dt);
  }

  render(ctx) {
    if (this.current && this.current.render) this.current.render(ctx);
  }

  handleInput(input) {
    if (this.current && this.current.handleInput) this.current.handleInput(input);
  }
}

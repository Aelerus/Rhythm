// Draws the player character + hitbox indicator.
// In inversion mode the player flips between blue (white floor) and red (black floor)
// regardless of the player's chosen cosmetic color, to preserve visibility.

export class PlayerRenderer {
  draw(ctx, player, focus, inversion = null) {
    const flash = player.flashTimer > 0;
    const blinking = player.iframes > 0 && Math.floor(player.iframes * 20) % 2 === 0;

    let bodyColor = player.color || "#e8e8f0";
    let glowColor = player.color || "#5dd6ff";
    if (inversion) {
      if (inversion.floor === "white") {
        bodyColor = "#1d6dff";
        glowColor = "#5da0ff";
      } else {
        bodyColor = "#ff2a3d";
        glowColor = "#ff6680";
      }
    }
    if (flash) bodyColor = "#ff5d5d";

    ctx.save();
    if (blinking) ctx.globalAlpha = 0.5;

    // Rotate shape around the player's centre to face movement direction
    ctx.save();
    ctx.translate(player.x, player.y);
    ctx.rotate(player.angle || 0);

    ctx.shadowColor = flash ? "#ff5d5d" : glowColor;
    ctx.shadowBlur = 16;
    ctx.fillStyle = bodyColor;
    ctx.strokeStyle = inversion
      ? (inversion.floor === "white" ? "#06040d" : "#fff8f8")
      : "#1b1130";
    ctx.lineWidth = 2;

    ctx.beginPath();
    this._drawShapePath(ctx, player.shape || "arrow", 0, 0, player.radius);
    ctx.closePath();
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.stroke();
    ctx.restore();

    // Hitbox core — always high-contrast yellow regardless of cosmetic color
    const coreAlpha = focus ? 1 : 0.55;
    ctx.globalAlpha = blinking ? coreAlpha * 0.5 : coreAlpha;
    const coreColor = inversion
      ? (inversion.floor === "white" ? "#ff8a00" : "#ffe25d")
      : "#ffe25d";
    ctx.shadowColor = coreColor;
    ctx.shadowBlur = focus ? 18 : 8;
    ctx.fillStyle = coreColor;
    ctx.beginPath();
    ctx.arc(player.x, player.y, player.hitboxRadius, 0, Math.PI * 2);
    ctx.fill();

    if (focus) {
      ctx.globalAlpha = blinking ? 0.2 : 0.4;
      ctx.strokeStyle = coreColor;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(player.x, player.y, player.hitboxRadius + 6, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  // Adds path commands for the given shape centered at (x, y) with outer radius r.
  // Caller must call ctx.beginPath() before and ctx.closePath()/fill()/stroke() after.
  _drawShapePath(ctx, shapeId, x, y, r) {
    switch (shapeId) {
      case "arrow":
        ctx.moveTo(x, y - r);
        ctx.lineTo(x + r * 0.85, y + r * 0.7);
        ctx.lineTo(x, y + r * 0.35);
        ctx.lineTo(x - r * 0.85, y + r * 0.7);
        break;

      case "square": {
        const hw = r * 0.82;
        ctx.moveTo(x - hw, y - hw);
        ctx.lineTo(x + hw, y - hw);
        ctx.lineTo(x + hw, y + hw);
        ctx.lineTo(x - hw, y + hw);
        break;
      }

      case "circle":
        ctx.arc(x, y, r, 0, Math.PI * 2);
        break;

      case "star": {
        const inner = r * 0.42;
        for (let i = 0; i < 10; i++) {
          const angle = (i * Math.PI / 5) - Math.PI / 2;
          const rad = i % 2 === 0 ? r : inner;
          const px = x + rad * Math.cos(angle);
          const py = y + rad * Math.sin(angle);
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        break;
      }

      case "hexagon":
        for (let i = 0; i < 6; i++) {
          const angle = (i * Math.PI / 3) - Math.PI / 2;
          const px = x + r * Math.cos(angle);
          const py = y + r * Math.sin(angle);
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        break;

      case "octagon":
        // Flat-top/bottom (stop-sign) orientation
        for (let i = 0; i < 8; i++) {
          const angle = (i * Math.PI / 4) + Math.PI / 8 - Math.PI / 2;
          const px = x + r * Math.cos(angle);
          const py = y + r * Math.sin(angle);
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        break;

      default:
        // Fallback to arrow
        ctx.moveTo(x, y - r);
        ctx.lineTo(x + r * 0.85, y + r * 0.7);
        ctx.lineTo(x, y + r * 0.35);
        ctx.lineTo(x - r * 0.85, y + r * 0.7);
        break;
    }
  }
}

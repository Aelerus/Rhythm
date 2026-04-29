// Draws the player character + hitbox indicator.

export class PlayerRenderer {
  draw(ctx, player, focus) {
    const flash = player.flashTimer > 0;
    const blinking = player.iframes > 0 && Math.floor(player.iframes * 20) % 2 === 0;

    ctx.save();
    if (blinking) ctx.globalAlpha = 0.5;

    // Outer body — diamond/anime arrow silhouette
    ctx.shadowColor = flash ? "#ff5d5d" : "#5dd6ff";
    ctx.shadowBlur = 16;
    ctx.fillStyle = flash ? "#ff5d5d" : "#e8e8f0";
    ctx.beginPath();
    ctx.moveTo(player.x, player.y - player.radius);
    ctx.lineTo(player.x + player.radius * 0.85, player.y + player.radius * 0.7);
    ctx.lineTo(player.x, player.y + player.radius * 0.35);
    ctx.lineTo(player.x - player.radius * 0.85, player.y + player.radius * 0.7);
    ctx.closePath();
    ctx.fill();

    ctx.shadowBlur = 0;
    ctx.strokeStyle = "#1b1130";
    ctx.lineWidth = 2;
    ctx.stroke();

    // Hitbox core — always faintly visible, bright when focusing
    const coreAlpha = focus ? 1 : 0.55;
    ctx.globalAlpha = coreAlpha;
    ctx.shadowColor = "#ffd25d";
    ctx.shadowBlur = focus ? 18 : 8;
    ctx.fillStyle = "#ffe25d";
    ctx.beginPath();
    ctx.arc(player.x, player.y, player.hitboxRadius, 0, Math.PI * 2);
    ctx.fill();

    if (focus) {
      ctx.globalAlpha = 0.4;
      ctx.strokeStyle = "#ffe25d";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(player.x, player.y, player.hitboxRadius + 6, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }
}

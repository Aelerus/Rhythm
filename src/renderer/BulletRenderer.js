// Draws bullets. Each bullet renders as a glowing disc with a bright core.

export class BulletRenderer {
  draw(ctx, pool) {
    for (const b of pool.active) {
      ctx.save();
      ctx.shadowColor = b.color;
      ctx.shadowBlur = 14;
      ctx.fillStyle = b.color;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.fillStyle = "#ffffff";
      ctx.globalAlpha = 0.85;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius * 0.45, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }
}

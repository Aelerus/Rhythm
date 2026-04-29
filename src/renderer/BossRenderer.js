// Draws the boss as a stylized geometric figure that pulses with the beat.

export class BossRenderer {
  draw(ctx, boss, beatPulse) {
    const x = boss.x;
    const y = boss.displayY;
    const flash = boss.flashTimer > 0;
    const baseColor = flash ? "#ffffff" : boss.color;
    const r = 60 + beatPulse * 6;

    ctx.save();
    // Aura
    ctx.shadowColor = boss.color;
    ctx.shadowBlur = 40 + beatPulse * 20;
    ctx.fillStyle = boss.color;
    ctx.globalAlpha = 0.18 + beatPulse * 0.18;
    ctx.beginPath();
    ctx.arc(x, y, r * 1.6, 0, Math.PI * 2);
    ctx.fill();

    // Body — hexagonal shape
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 18;
    ctx.fillStyle = baseColor;
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2 + Math.PI / 6;
      const px = x + Math.cos(a) * r;
      const py = y + Math.sin(a) * r;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = "#1b1130";
    ctx.lineWidth = 3;
    ctx.stroke();

    // Inner eye/core
    ctx.fillStyle = flash ? boss.color : "#ffffff";
    ctx.beginPath();
    ctx.arc(x, y, 14 + beatPulse * 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#1b1130";
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

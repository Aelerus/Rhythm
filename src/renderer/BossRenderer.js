// Draws the boss as a stylized geometric figure that pulses with the beat.
// In inversion mode the boss flips with the floor: black on white, white on black.

export class BossRenderer {
  draw(ctx, boss, beatPulse, inversion = null) {
    const x = boss.x;
    const y = boss.displayY;
    const flash = boss.flashTimer > 0;

    let bodyColor = flash ? "#ffffff" : boss.color;
    let auraColor = boss.color;
    let outlineColor = "#1b1130";
    let coreInner = flash ? boss.color : "#ffffff";
    let coreCenter = "#1b1130";

    if (inversion) {
      if (inversion.floor === "white") {
        bodyColor = flash ? "#ff5d5d" : "#0a0a0a";
        auraColor = "#222222";
        outlineColor = "#f4f4f4";
        coreInner = flash ? "#ffffff" : "#3a3a3a";
        coreCenter = "#f4f4f4";
      } else {
        bodyColor = flash ? "#ff5d5d" : "#f4f4f4";
        auraColor = "#dddddd";
        outlineColor = "#0a0a0a";
        coreInner = flash ? "#000000" : "#cfcfcf";
        coreCenter = "#0a0a0a";
      }
    }

    const r = 60 + beatPulse * 6;

    ctx.save();
    // Aura
    ctx.shadowColor = auraColor;
    ctx.shadowBlur = 40 + beatPulse * 20;
    ctx.fillStyle = auraColor;
    ctx.globalAlpha = 0.18 + beatPulse * 0.18;
    ctx.beginPath();
    ctx.arc(x, y, r * 1.6, 0, Math.PI * 2);
    ctx.fill();

    // Body — hexagonal shape
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 18;
    ctx.fillStyle = bodyColor;
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
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = 3;
    ctx.stroke();

    // Inner eye/core
    ctx.fillStyle = coreInner;
    ctx.beginPath();
    ctx.arc(x, y, 14 + beatPulse * 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = coreCenter;
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

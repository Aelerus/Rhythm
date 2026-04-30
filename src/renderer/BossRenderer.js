// Draws the boss as a stylized geometric figure that pulses with the beat.
// Color modes:
//   - "color"     : use boss.color directly (legacy)
//   - "inversion" : invert with the floor (Phases 1 & 2)
//   - "drainGold" : starts gold at full HP, lerps to grey as HP drops (Phase 3)
// When boss.dying is true, draw the boss falling off-screen with a fade.

const COLORS = {
  goldFull: "#ffd25d",
  goldEdge: "#a87c1f",
  greyFull: "#7f7f7f",
  greyEdge: "#3a3a3a",
};

function lerpHex(a, b, t) {
  const pa = parseInt(a.slice(1), 16);
  const pb = parseInt(b.slice(1), 16);
  const ar = (pa >> 16) & 255, ag = (pa >> 8) & 255, ab = pa & 255;
  const br = (pb >> 16) & 255, bg = (pb >> 8) & 255, bb = pb & 255;
  const r = Math.round(ar + (br - ar) * t);
  const g = Math.round(ag + (bg - ag) * t);
  const b2 = Math.round(ab + (bb - ab) * t);
  return `rgb(${r},${g},${b2})`;
}

export class BossRenderer {
  draw(ctx, boss, beatPulse, inversion = null, mode = "color") {
    const x = boss.x;
    const y = boss.displayY;
    const flash = boss.flashTimer > 0;

    let bodyColor, auraColor, outlineColor, coreInner, coreCenter;

    if (mode === "drainGold") {
      // Gold at full HP, drains toward grey as HP runs out.
      const t = 1 - boss.hpRatio; // 0 (gold) → 1 (grey)
      bodyColor = flash ? "#ff5d5d" : lerpHex(COLORS.goldFull, COLORS.greyFull, t);
      auraColor = lerpHex(COLORS.goldFull, COLORS.greyFull, t);
      outlineColor = lerpHex(COLORS.goldEdge, COLORS.greyEdge, t);
      coreInner = flash ? "#ffffff" : "#ffffff";
      coreCenter = lerpHex(COLORS.goldEdge, COLORS.greyEdge, t);
    } else if (mode === "inversion" && inversion) {
      if (inversion.floor === "white") {
        bodyColor = flash ? "#c9001f" : "#0a0a0a";
        auraColor = "#222222";
        outlineColor = "#f4f4f4";
        coreInner = flash ? "#ffffff" : "#3a3a3a";
        coreCenter = "#f4f4f4";
      } else {
        bodyColor = flash ? "#c9001f" : "#f4f4f4";
        auraColor = "#dddddd";
        outlineColor = "#0a0a0a";
        coreInner = flash ? "#000000" : "#cfcfcf";
        coreCenter = "#0a0a0a";
      }
    } else {
      // "color" mode (legacy)
      bodyColor = flash ? "#ffffff" : boss.color;
      auraColor = boss.color;
      outlineColor = "#1b1130";
      coreInner = flash ? boss.color : "#ffffff";
      coreCenter = "#1b1130";
    }

    const r = 60 + beatPulse * 6;

    ctx.save();
    if (boss.dying) ctx.globalAlpha = boss.fallAlpha ?? 1;

    // Aura
    ctx.shadowColor = auraColor;
    ctx.shadowBlur = 40 + beatPulse * 20;
    ctx.fillStyle = auraColor;
    ctx.globalAlpha = (boss.dying ? boss.fallAlpha : 1) * (0.18 + beatPulse * 0.18);
    ctx.beginPath();
    ctx.arc(x, y, r * 1.6, 0, Math.PI * 2);
    ctx.fill();

    // Body — hexagonal shape
    ctx.globalAlpha = boss.dying ? boss.fallAlpha : 1;
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

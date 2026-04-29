// Draws bullets. Each bullet renders as a glowing disc with a bright core.
// In inversion mode, bullets render as the opposite of the floor color
// (white floor = black bullets, black floor = white bullets) — overriding
// each bullet's authored color. Marker/telegraph bullets render as outlines.

export class BulletRenderer {
  draw(ctx, pool, inversion = null) {
    for (const b of pool.active) {
      const isMarker = b.tag === "marker";
      const isOrbit = b.orbit && b.life < (b.orbit.until ?? 0);
      const isDelayed = b.delay > 0;

      let bulletColor = b.color;
      let coreColor = "#ffffff";
      if (inversion) {
        bulletColor = inversion.floor === "white" ? "#0a0a0a" : "#f4f4f4";
        coreColor = inversion.floor === "white" ? "#3a3a3a" : "#cfcfcf";
      }

      ctx.save();
      if (isMarker || isDelayed) {
        // Telegraph: ringed outline that pulses
        const pulse = 0.4 + 0.6 * Math.abs(Math.sin(b.life * 14));
        ctx.globalAlpha = 0.35 + 0.45 * pulse;
        ctx.shadowColor = bulletColor;
        ctx.shadowBlur = 10;
        ctx.strokeStyle = bulletColor;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(b.x, b.y, b.radius + 2, 0, Math.PI * 2);
        ctx.stroke();
        // crosshair tick on big markers
        if (b.radius >= 10) {
          ctx.beginPath();
          ctx.moveTo(b.x - b.radius - 4, b.y);
          ctx.lineTo(b.x - b.radius + 4, b.y);
          ctx.moveTo(b.x + b.radius - 4, b.y);
          ctx.lineTo(b.x + b.radius + 4, b.y);
          ctx.moveTo(b.x, b.y - b.radius - 4);
          ctx.lineTo(b.x, b.y - b.radius + 4);
          ctx.moveTo(b.x, b.y + b.radius - 4);
          ctx.lineTo(b.x, b.y + b.radius + 4);
          ctx.stroke();
        }
        ctx.restore();
        continue;
      }

      // Orbiting bullets get a subtle trail ring to telegraph their imminent release
      if (isOrbit) {
        ctx.globalAlpha = 0.6;
      }

      // Phase-locked bullets ghost when their lock-color doesn't match the floor.
      // They're still visible (so the player can plan ahead), but clearly inert.
      let phaseGhosted = false;
      if (b.phaseLockColor && inversion && b.phaseLockColor !== inversion.floor) {
        phaseGhosted = true;
      }
      if (phaseGhosted) {
        ctx.globalAlpha = 0.22;
      }

      ctx.shadowColor = bulletColor;
      ctx.shadowBlur = 14;
      ctx.fillStyle = bulletColor;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.fillStyle = coreColor;
      ctx.globalAlpha = 0.85;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius * 0.45, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }
}

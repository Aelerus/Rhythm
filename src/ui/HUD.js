// In-fight HUD: HP bars, beat indicator, combo, timing grade flash, counterattack prompts.

import { PHASE_COUNTER } from "../game/FightManager.js";

export class HUD {
  draw(ctx, fight, beatPulse, beatPosition) {
    const { width, height } = ctx.canvas;
    this._drawBossBar(ctx, fight, width);
    this._drawSongTimer(ctx, fight, width);
    this._drawPlayerBar(ctx, fight, width, height);
    this._drawBeatIndicator(ctx, beatPulse, width, height, fight.boss.color);
    this._drawComboCounter(ctx, fight, width);
    this._drawParryZone(ctx, fight, beatPulse);
    this._drawCounterPrompts(ctx, fight, beatPosition, width, height);
    this._drawGradeFlash(ctx, fight, width, height);
    this._drawFeedback(ctx, fight, width, height);
    this._drawPhaseLabel(ctx, fight, width, height);
  }

  _drawBossBar(ctx, fight, width) {
    const boss = fight.boss;
    const w = width * 0.7;
    const h = 18;
    const x = (width - w) / 2;
    const y = 22;

    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(x - 2, y - 2, w + 4, h + 4);
    ctx.fillStyle = "#33223a";
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = boss.color;
    ctx.fillRect(x, y, w * boss.hpRatio, h);

    // Phase threshold tick marks
    ctx.strokeStyle = "rgba(255,255,255,0.4)";
    ctx.lineWidth = 1;
    for (const t of boss.phaseThresholds) {
      const tx = x + w * t;
      ctx.beginPath();
      ctx.moveTo(tx, y);
      ctx.lineTo(tx, y + h);
      ctx.stroke();
    }

    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 16px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    // Multi-phase fights expose the current phase's displayPhase via fight.currentPhase.
    // Single-phase bosses can also lock the display via bossData.displayPhase.
    const phaseLabel =
      fight.currentPhase?.displayPhase ??
      fight.bossData.displayPhase ??
      `Phase ${boss.phase}`;
    ctx.fillText(`${fight.bossData.name}  —  ${phaseLabel}`, width / 2, y - 6);
  }

  // Song-time progress bar fused to the underside of the boss HP. When this
  // reaches the right edge and the boss isn't dead, the run is lost.
  _drawSongTimer(ctx, fight, width) {
    if (!fight._songEndTime) return;
    const w = width * 0.7;
    const h = 4;
    const x = (width - w) / 2;
    const y = 22 + 18 + 2; // directly under the boss HP bar (boss bar y=22 h=18)
    const progress = fight.songProgress;
    const remaining = Math.max(0, fight.songTimeRemaining ?? 0);
    const veryUrgent = remaining < 15;
    const urgent = remaining < 30;

    ctx.save();
    ctx.fillStyle = "#22182a";
    ctx.fillRect(x, y, w, h);
    const barColor = veryUrgent ? "#ff3a3a" : (urgent ? "#ff8a5d" : "#7aa0d4");
    if (veryUrgent) {
      ctx.shadowColor = barColor;
      ctx.shadowBlur = 14;
    }
    ctx.fillStyle = barColor;
    ctx.fillRect(x, y, w * progress, h);
    ctx.shadowBlur = 0;

    // Compact time label at the right end of the bar (above the arena).
    const mm = Math.floor(remaining / 60);
    const ss = Math.floor(remaining % 60);
    const label = `${mm}:${ss.toString().padStart(2, "0")}`;
    ctx.fillStyle = veryUrgent ? "#ff3a3a" : "#aaaadd";
    ctx.font = "bold 11px 'Segoe UI', sans-serif";
    ctx.textAlign = "right";
    ctx.fillText(label, x + w, y - 4);
    ctx.restore();
  }

  _drawPlayerBar(ctx, fight, width, height) {
    const w = 220;
    const h = 16;
    const x = 24;
    const y = height - 40;
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(x - 2, y - 2, w + 4, h + 4);
    ctx.fillStyle = "#33223a";
    ctx.fillRect(x, y, w, h);
    const ratio = fight.player.hp / fight.player.maxHP;
    const color = ratio > 0.5 ? "#5dffae" : ratio > 0.25 ? "#ffd25d" : "#ff5d5d";
    ctx.fillStyle = color;
    ctx.fillRect(x, y, w * ratio, h);

    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 13px 'Segoe UI', sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(`HP ${Math.ceil(fight.player.hp)} / ${fight.player.maxHP}`, x, y - 6);
  }

  _drawBeatIndicator(ctx, beatPulse, width, height, color = "#5dd6ff") {
    const r = 12 + beatPulse * 14;
    const x = width / 2;
    const y = height - 36;
    ctx.save();
    ctx.globalAlpha = 0.4 + beatPulse * 0.5;
    ctx.shadowColor = color;
    ctx.shadowBlur = 18;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  _drawComboCounter(ctx, fight, width) {
    if (fight.counter.combo <= 1) return;
    ctx.save();
    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 28px 'Segoe UI', sans-serif";
    ctx.textAlign = "right";
    ctx.shadowColor = "#ffd25d";
    ctx.shadowBlur = 12;
    ctx.fillText(`x${fight.counter.combo}`, width - 24, 70);
    ctx.font = "12px 'Segoe UI', sans-serif";
    ctx.fillStyle = "#fff";
    ctx.shadowBlur = 0;
    ctx.fillText("COMBO", width - 24, 86);
    ctx.restore();
  }

  // Glowing target circle the player must occupy to land parries.
  _drawParryZone(ctx, fight, beatPulse) {
    if (fight.phase !== PHASE_COUNTER) return;
    const zone = fight.counter.zone;
    if (!zone) return;
    const inside = fight.counter.isInZone(fight.player);
    const t = performance.now() / 1000;
    const ringR = zone.radius + 4 + Math.sin(t * 6) * 3;

    // In inversion mode, ring outline = floor-inverse so the circle is always
    // visible. Status (in/out) is communicated by an inner accent + the label.
    let ringColor, accentInside, accentOutside;
    if (fight.useInversion) {
      ringColor = fight.floorState === "white" ? "#0a0a0a" : "#f4f4f4";
      // Inner accent uses saturated colors that contrast both floors.
      accentInside = "#39d68d";
      accentOutside = "#e22b8a";
    } else {
      ringColor = inside ? "#5dffae" : "#ff5dd6";
      accentInside = "#5dffae";
      accentOutside = "#ff5dd6";
    }
    const accent = inside ? accentInside : accentOutside;

    ctx.save();
    // Inner glow tinted by status (so player can still feel ready vs not)
    ctx.globalAlpha = 0.18 + 0.18 * beatPulse + (inside ? 0.12 : 0);
    ctx.shadowColor = accent;
    ctx.shadowBlur = 30;
    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.arc(zone.x, zone.y, zone.radius, 0, Math.PI * 2);
    ctx.fill();

    // Crisp ring — outlined in the floor-inverse color when inversion is on
    ctx.globalAlpha = 0.95;
    ctx.shadowBlur = inside ? 18 : 8;
    ctx.shadowColor = ringColor;
    ctx.strokeStyle = ringColor;
    ctx.lineWidth = inside ? 4 : 3;
    ctx.beginPath();
    ctx.arc(zone.x, zone.y, ringR, 0, Math.PI * 2);
    ctx.stroke();

    // Outward pulsing rings when ready (also floor-inverse so they read on either)
    if (inside) {
      for (let i = 0; i < 2; i++) {
        const phase = ((t * 0.9) + i * 0.5) % 1;
        ctx.globalAlpha = (1 - phase) * 0.45;
        ctx.lineWidth = 2;
        ctx.strokeStyle = ringColor;
        ctx.beginPath();
        ctx.arc(zone.x, zone.y, zone.radius + phase * 38, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else {
      // "MOVE!" hint floating above the circle
      ctx.globalAlpha = 0.9 + 0.1 * Math.sin(t * 9);
      ctx.shadowBlur = 14;
      ctx.shadowColor = ringColor;
      ctx.fillStyle = ringColor;
      ctx.font = "bold 18px 'Segoe UI', sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("ENTER THE CIRCLE", zone.x, zone.y - zone.radius - 14);
    }

    // Out-of-range rejection flash
    if (fight.counter.outOfRangeFlash > 0) {
      const k = Math.min(1, fight.counter.outOfRangeFlash / 0.45);
      ctx.globalAlpha = k * 0.9;
      ctx.shadowBlur = 30;
      ctx.shadowColor = accentOutside;
      ctx.strokeStyle = accentOutside;
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.arc(zone.x, zone.y, zone.radius + 16 + (1 - k) * 22, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  _drawCounterPrompts(ctx, fight, beatPosition, width, height) {
    if (fight.phase !== PHASE_COUNTER) return;
    const cy = height / 2 + 60;
    const cx = width / 2;
    const prompts = fight.counter.visiblePrompts();
    const inZone = fight.counter.zone ? fight.counter.isInZone(fight.player) : true;

    // In inversion mode, the prompt UI also flips to the floor-inverse so it
    // never disappears (yellow on white is unreadable, etc.).
    const inv = fight.useInversion;
    const invColor = inv
      ? (fight.floorState === "white" ? "#0a0a0a" : "#f4f4f4")
      : "#ffffff";
    const hitZoneColor = inv ? invColor : "#ffe25d";
    const laneColor = inv
      ? (fight.floorState === "white" ? "rgba(0,0,0,0.28)" : "rgba(255,255,255,0.28)")
      : "rgba(255,255,255,0.18)";

    // Lane line
    ctx.save();
    ctx.strokeStyle = laneColor;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx - 320, cy);
    ctx.lineTo(cx + 320, cy);
    ctx.stroke();

    // Hit zone (where the beat lands)
    ctx.shadowColor = hitZoneColor;
    ctx.shadowBlur = 16;
    ctx.strokeStyle = hitZoneColor;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(cx, cy, 26, 0, Math.PI * 2);
    ctx.stroke();
    ctx.shadowBlur = 0;

    // Approaching prompt rings — scroll from right to the hit zone
    const pxPerSec = 320;
    for (const p of prompts) {
      const x = cx + p.delta * pxPerSec;
      if (x < cx - 360 || x > cx + 360) continue;

      let color = invColor;
      let alpha = 1;
      if (p.hit) {
        color = p.grade ? p.grade.color : "#888";
        alpha = 0.4;
      }
      ctx.globalAlpha = alpha;
      ctx.shadowColor = color;
      ctx.shadowBlur = 10;
      ctx.strokeStyle = color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(x, cy, 18, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();

    // "ATTACK!" label — context-sensitive when a parry zone is active
    ctx.save();
    let label = "COUNTERATTACK — press SPACE on beat";
    let labelColor = "#ffe25d";
    if (fight.counter.zone) {
      label = inZone
        ? "PARRY READY — press SPACE on beat"
        : "MOVE TO THE CIRCLE";
      labelColor = inZone ? "#5dffae" : "#ff5dd6";
    }
    ctx.fillStyle = labelColor;
    ctx.font = "bold 22px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.shadowColor = labelColor;
    ctx.shadowBlur = 14;
    ctx.fillText(label, cx, cy - 50);
    ctx.restore();
  }

  _drawGradeFlash(ctx, fight, width, height) {
    if (fight.counter.flashTimer <= 0 || !fight.counter.flashGrade) return;
    const g = fight.counter.flashGrade;
    const t = fight.counter.flashTimer / 0.55;
    ctx.save();
    ctx.globalAlpha = Math.min(1, t * 2);
    ctx.fillStyle = g.color;
    ctx.font = `bold ${52 + (1 - t) * 12}px 'Segoe UI', sans-serif`;
    ctx.textAlign = "center";
    ctx.shadowColor = g.color;
    ctx.shadowBlur = 24;
    ctx.fillText(g.name, width / 2, height / 2 - 60);
    ctx.restore();
  }

  _drawFeedback(ctx, fight, width, height) {
    if (fight.feedbackTimer <= 0 || !fight.feedback) return;
    const t = Math.min(1, fight.feedbackTimer / 1.6);
    ctx.save();
    ctx.globalAlpha = t;
    ctx.fillStyle = fight.feedback.color;
    ctx.font = "bold 36px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.shadowColor = fight.feedback.color;
    ctx.shadowBlur = 18;
    ctx.fillText(fight.feedback.text, width / 2, height / 2 - 120);
    ctx.restore();
  }

  _drawPhaseLabel(ctx, fight, width, height) {
    if (fight.phase === PHASE_COUNTER) return;
    ctx.save();
    ctx.globalAlpha = 0.5;
    ctx.fillStyle = "#aaaadd";
    ctx.font = "12px 'Segoe UI', sans-serif";
    ctx.textAlign = "right";
    ctx.fillText("WASD/Arrows: move    Shift: focus    Space: attack (during counter)", width - 24, height - 14);
    ctx.restore();
  }
}

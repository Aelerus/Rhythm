// In-fight HUD: HP bars, beat indicator, combo, timing grade flash, counterattack prompts.

import { PHASE_COUNTER } from "../game/FightManager.js";

export class HUD {
  draw(ctx, fight, beatPulse, beatPosition) {
    const { width, height } = ctx.canvas;
    this._drawBossBar(ctx, fight, width);
    this._drawPlayerBar(ctx, fight, width, height);
    this._drawBeatIndicator(ctx, beatPulse, width, height);
    this._drawComboCounter(ctx, fight, width);
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
    ctx.fillText(`${fight.bossData.name}  —  Phase ${boss.phase}`, width / 2, y - 6);
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

  _drawBeatIndicator(ctx, beatPulse, width, height) {
    const r = 12 + beatPulse * 14;
    const x = width / 2;
    const y = height - 36;
    ctx.save();
    ctx.globalAlpha = 0.4 + beatPulse * 0.5;
    ctx.shadowColor = "#5dd6ff";
    ctx.shadowBlur = 18;
    ctx.fillStyle = "#5dd6ff";
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

  _drawCounterPrompts(ctx, fight, beatPosition, width, height) {
    if (fight.phase !== PHASE_COUNTER) return;
    const cy = height / 2 + 60;
    const cx = width / 2;
    const prompts = fight.counter.visiblePrompts();

    // Lane line
    ctx.save();
    ctx.strokeStyle = "rgba(255,255,255,0.18)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx - 320, cy);
    ctx.lineTo(cx + 320, cy);
    ctx.stroke();

    // Hit zone (where the beat lands)
    ctx.shadowColor = "#ffe25d";
    ctx.shadowBlur = 16;
    ctx.strokeStyle = "#ffe25d";
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

      let color = "#ffffff";
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

    // "ATTACK!" label
    ctx.save();
    ctx.fillStyle = "#ffe25d";
    ctx.font = "bold 22px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.shadowColor = "#ffd25d";
    ctx.shadowBlur = 14;
    ctx.fillText("COUNTERATTACK — press SPACE on beat", cx, cy - 50);
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

const REDUCED_MOTION = typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches;

class EffectsManager {
  constructor() {
    this._shakeX = 0;
    this._shakeY = 0;
    this._shakeIntensity = 0;
    this._shakeRemaining = 0;
    this._flashColor = null;
    this._flashAlpha = 0;
    this._flashDuration = 0;
    this._flashRemaining = 0;
    this._popups = [];
  }

  shake(intensity, duration) {
    if (REDUCED_MOTION) return;
    this._shakeIntensity = intensity;
    this._shakeRemaining = duration;
  }

  flash(color, duration) {
    this._flashColor = color;
    this._flashDuration = duration;
    this._flashRemaining = duration;
    this._flashAlpha = 1;
  }

  addScorePopup(x, y, text, color) {
    this._popups.push({
      x, y, text,
      color: color || '#ffd455',
      life: 0.8,
      maxLife: 0.8,
      alpha: 1,
    });
  }

  getBlinkAlpha(intervalMs) {
    return Math.floor(performance.now() / intervalMs) % 2 === 0 ? 1 : 0;
  }

  getShakeOffset() {
    return { x: this._shakeX, y: this._shakeY };
  }

  update(dt) {
    if (this._shakeRemaining > 0) {
      this._shakeRemaining -= dt;
      const ratio = Math.max(0, this._shakeRemaining / (this._shakeRemaining + dt));
      const intensity = this._shakeIntensity * ratio;
      this._shakeX = (Math.random() * 2 - 1) * intensity;
      this._shakeY = (Math.random() * 2 - 1) * intensity;
      if (this._shakeRemaining <= 0) {
        this._shakeX = 0;
        this._shakeY = 0;
      }
    }

    if (this._flashRemaining > 0) {
      this._flashRemaining -= dt;
      this._flashAlpha = Math.max(0, this._flashRemaining / this._flashDuration);
    }

    for (let i = this._popups.length - 1; i >= 0; i--) {
      const p = this._popups[i];
      p.life -= dt;
      p.y -= 40 * dt;
      p.alpha = Math.max(0, p.life / p.maxLife);
      if (p.life <= 0) this._popups.splice(i, 1);
    }
  }

  draw(ctx, width, height) {
    if (this._shakeX !== 0 || this._shakeY !== 0) {
      ctx.save();
      ctx.translate(this._shakeX, this._shakeY);
    }

    if (this._flashRemaining > 0 && this._flashColor) {
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = this._flashAlpha;
      ctx.fillStyle = this._flashColor;
      ctx.fillRect(0, 0, width, height);
      ctx.globalAlpha = saved;
    }

    for (const p of this._popups) {
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = p.alpha;
      ctx.fillStyle = p.color;
      ctx.font = '12px "Press Start 2P", monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(p.text, p.x, p.y);
      ctx.globalAlpha = saved;
    }

    if (this._shakeX !== 0 || this._shakeY !== 0) {
      ctx.restore();
    }
  }

  clear() {
    this._shakeX = 0;
    this._shakeY = 0;
    this._shakeRemaining = 0;
    this._flashRemaining = 0;
    this._popups.length = 0;
  }
}

export const effects = new EffectsManager();

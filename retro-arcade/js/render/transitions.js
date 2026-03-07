const TransitionType = Object.freeze({
  FADE: 'fade',
  WIPE_LEFT: 'wipeLeft',
  WIPE_DOWN: 'wipeDown',
  PIXEL_DISSOLVE: 'pixelDissolve',
  CRT_OFF: 'crtOff',
});

const PIXEL_BLOCK_SIZE = 16;

class TransitionManager {
  constructor() {
    this._active = false;
    this._type = null;
    this._duration = 0;
    this._elapsed = 0;
    this._onMidpoint = null;
    this._onComplete = null;
    this._midpointFired = false;
    this._dissolveOrder = null;
  }

  startTransition(type, duration, onMidpoint, onComplete) {
    this._type = type;
    this._duration = duration / 1000;
    this._elapsed = 0;
    this._onMidpoint = onMidpoint;
    this._onComplete = onComplete;
    this._midpointFired = false;
    this._active = true;

    if (type === TransitionType.PIXEL_DISSOLVE) {
      this._buildDissolveOrder();
    }
  }

  isActive() {
    return this._active;
  }

  update(dt) {
    if (!this._active) return;
    this._elapsed += dt;
    const progress = Math.min(this._elapsed / this._duration, 1);

    if (progress >= 0.5 && !this._midpointFired) {
      this._midpointFired = true;
      if (this._onMidpoint) this._onMidpoint();
    }

    if (progress >= 1) {
      this._active = false;
      if (this._onComplete) this._onComplete();
    }
  }

  draw(ctx, width, height) {
    if (!this._active) return;
    const progress = Math.min(this._elapsed / this._duration, 1);

    switch (this._type) {
      case TransitionType.FADE:
        this._drawFade(ctx, width, height, progress);
        break;
      case TransitionType.WIPE_LEFT:
        this._drawWipeLeft(ctx, width, height, progress);
        break;
      case TransitionType.WIPE_DOWN:
        this._drawWipeDown(ctx, width, height, progress);
        break;
      case TransitionType.PIXEL_DISSOLVE:
        this._drawPixelDissolve(ctx, width, height, progress);
        break;
      case TransitionType.CRT_OFF:
        this._drawCRTOff(ctx, width, height, progress);
        break;
    }
  }

  _drawFade(ctx, width, height, progress) {
    const alpha = progress < 0.5
      ? progress * 2
      : (1 - progress) * 2;
    ctx.fillStyle = '#000000';
    const saved = ctx.globalAlpha;
    ctx.globalAlpha = alpha;
    ctx.fillRect(0, 0, width, height);
    ctx.globalAlpha = saved;
  }

  _drawWipeLeft(ctx, width, height, progress) {
    const coverX = progress < 0.5
      ? (progress * 2) * width
      : (1 - (progress - 0.5) * 2) * width;
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, coverX, height);
  }

  _drawWipeDown(ctx, width, height, progress) {
    const coverY = progress < 0.5
      ? (progress * 2) * height
      : (1 - (progress - 0.5) * 2) * height;
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, width, coverY);
  }

  _drawPixelDissolve(ctx, width, height, progress) {
    if (!this._dissolveOrder) return;
    const total = this._dissolveOrder.length;
    const count = progress < 0.5
      ? Math.floor((progress * 2) * total)
      : Math.floor((1 - (progress - 0.5) * 2) * total);

    ctx.fillStyle = '#000000';
    for (let i = 0; i < count; i++) {
      const idx = this._dissolveOrder[i];
      const cols = Math.ceil(480 / PIXEL_BLOCK_SIZE);
      const col = idx % cols;
      const row = Math.floor(idx / cols);
      ctx.fillRect(
        col * PIXEL_BLOCK_SIZE, row * PIXEL_BLOCK_SIZE,
        PIXEL_BLOCK_SIZE, PIXEL_BLOCK_SIZE
      );
    }
  }

  _drawCRTOff(ctx, width, height, progress) {
    if (progress < 0.5) {
      const t = progress * 2;
      const scaleY = 1 - t * 0.97;
      const barHeight = Math.max(2, height * scaleY);
      const y = (height - barHeight) / 2;
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, width, y);
      ctx.fillRect(0, y + barHeight, width, height - y - barHeight);
    } else {
      const t = (progress - 0.5) * 2;
      const barHeight = 2;
      const y = (height - barHeight) / 2;
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, width, y);
      ctx.fillRect(0, y + barHeight, width, height - y - barHeight);
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = 1 - t;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, y, width, barHeight);
      ctx.globalAlpha = saved;
    }
  }

  _buildDissolveOrder() {
    const cols = Math.ceil(480 / PIXEL_BLOCK_SIZE);
    const rows = Math.ceil(640 / PIXEL_BLOCK_SIZE);
    const total = cols * rows;
    this._dissolveOrder = [];
    for (let i = 0; i < total; i++) this._dissolveOrder.push(i);
    for (let i = total - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = this._dissolveOrder[i];
      this._dissolveOrder[i] = this._dissolveOrder[j];
      this._dissolveOrder[j] = tmp;
    }
  }
}

export const transitions = new TransitionManager();
export { TransitionType };

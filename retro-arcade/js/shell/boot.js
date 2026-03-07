import { drawText, drawGlowText } from '../render/text.js';
import { LOGICAL_WIDTH, LOGICAL_HEIGHT } from '../platform/viewport.js';
import { audio } from '../platform/audio.js';

const TOTAL_DURATION = 4.0;
const SKIP_FLAG_KEY = 'retro-arcade-boot-shown';

const REDUCED_MOTION = typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches;

class BootScreen {
  constructor() {
    this._elapsed = 0;
    this._skipped = false;
    this._onComplete = null;
  }

  shouldSkip() {
    return sessionStorage.getItem(SKIP_FLAG_KEY) === '1';
  }

  activate(data) {
    this._elapsed = 0;
    this._skipped = false;
    this._onComplete = data?.onComplete || null;
    sessionStorage.setItem(SKIP_FLAG_KEY, '1');
    if (REDUCED_MOTION) this._elapsed = TOTAL_DURATION;
  }

  deactivate() {}

  update(dt, input) {
    this._elapsed += dt;

    if (!this._skipped) {
      const anyKey = input.consumePress && (
        input.isPressed('actionPrimary') ||
        input.isPressed('menuSelect') ||
        input.isPressed('pause') ||
        input.isPressed('moveUp') ||
        input.isPressed('moveDown')
      );
      if (anyKey) {
        this._skipped = true;
        this._elapsed = TOTAL_DURATION;
      }
    }

    if (this._elapsed >= TOTAL_DURATION && this._onComplete) {
      const cb = this._onComplete;
      this._onComplete = null;
      cb();
    }
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();
    const t = Math.min(this._elapsed / TOTAL_DURATION, 1);

    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);

    if (t < 0.075) {
      // Scan line sweep
      const lineY = (t / 0.075) * LOGICAL_HEIGHT;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, lineY - 1, LOGICAL_WIDTH, 2);
    } else if (t < 0.15) {
      // CRT power-on flash
      const flash = 1 - ((t - 0.075) / 0.075);
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = flash * 0.8;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
      ctx.globalAlpha = saved;
    } else if (t < 0.5) {
      // Typewriter text
      const textProgress = (t - 0.15) / 0.35;
      const fullText = 'RETRO ARCADE';
      const chars = Math.floor(textProgress * fullText.length);
      const display = fullText.substring(0, chars);
      const showCursor = Math.floor(this._elapsed * 4) % 2 === 0;

      drawText(ctx, display + (showCursor ? '_' : ''), LOGICAL_WIDTH / 2, LOGICAL_HEIGHT / 2 - 10, {
        font: 'title', align: 'center', color: '#00ff41',
      });
    } else if (t < 0.625) {
      // Fade to black
      const fade = (t - 0.5) / 0.125;
      drawText(ctx, 'RETRO ARCADE', LOGICAL_WIDTH / 2, LOGICAL_HEIGHT / 2 - 10, {
        font: 'title', align: 'center', color: '#00ff41', alpha: 1 - fade,
      });
    } else if (t <= 1) {
      // Title card with glow
      const cardProgress = (t - 0.625) / 0.375;
      const alpha = Math.min(cardProgress * 2, 1);

      const saved = ctx.globalAlpha;
      ctx.globalAlpha = alpha;
      drawGlowText(ctx, 'RETRO', LOGICAL_WIDTH / 2, LOGICAL_HEIGHT / 2 - 30, {
        font: 'title', align: 'center', color: '#ff4c60', glowColor: '#ff4c60',
      });
      drawGlowText(ctx, 'ARCADE', LOGICAL_WIDTH / 2, LOGICAL_HEIGHT / 2 + 10, {
        font: 'title', align: 'center', color: '#32e8ff', glowColor: '#32e8ff',
      });
      ctx.globalAlpha = saved;

      if (cardProgress > 0.3 && cardProgress < 0.35) {
        audio.playCoin();
      }
    }
  }
}

export const bootScreen = new BootScreen();

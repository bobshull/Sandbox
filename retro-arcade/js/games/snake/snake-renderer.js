import { SNAKE_CONFIG } from './snake-config.js';
import { SPRITES, drawSprite } from '../../render/sprites.js';
import { drawText, drawGlowText } from '../../render/text.js';
import { effects } from '../../render/effects.js';
import { LOGICAL_WIDTH } from '../../platform/viewport.js';

const OX = SNAKE_CONFIG.PLAY_AREA_OFFSET_X;
const OY = SNAKE_CONFIG.PLAY_AREA_OFFSET_Y;
const CS = SNAKE_CONFIG.CELL_SIZE;
const GW = SNAKE_CONFIG.GRID_WIDTH;
const GH = SNAKE_CONFIG.GRID_HEIGHT;

const HEAD_SPRITES = {
  '1,0': SPRITES.SNAKE_HEAD_RIGHT,
  '-1,0': SPRITES.SNAKE_HEAD_LEFT,
  '0,-1': SPRITES.SNAKE_HEAD_UP,
  '0,1': SPRITES.SNAKE_HEAD_DOWN,
};

export function renderSnakeGame(ctx, state) {
  drawGrid(ctx);
  drawFood(ctx, state);
  drawPowerUp(ctx, state);
  drawSnake(ctx, state);
  drawUI(ctx, state);
}

function drawGrid(ctx) {
  ctx.fillStyle = 'rgba(255,255,255,0.03)';
  for (let x = 0; x <= GW; x++) {
    ctx.fillRect(OX + x * CS, OY, 1, GH * CS);
  }
  for (let y = 0; y <= GH; y++) {
    ctx.fillRect(OX, OY + y * CS, GW * CS, 1);
  }
  ctx.strokeStyle = '#1a1d2a';
  ctx.lineWidth = 2;
  ctx.strokeRect(OX, OY, GW * CS, GH * CS);
}

function drawSnake(ctx, state) {
  const { snake, powerUpManager } = state;
  const isInvincible = powerUpManager.getActiveEffect()?.id === 'invincible';
  const segments = snake.segments;

  for (let i = segments.length - 1; i >= 0; i--) {
    const seg = segments[i];
    const px = OX + seg.x * CS;
    const py = OY + seg.y * CS;

    if (i === 0) {
      const key = `${snake.direction.x},${snake.direction.y}`;
      const sprite = HEAD_SPRITES[key] || SPRITES.SNAKE_HEAD_RIGHT;
      let color = '#00ff41';
      if (isInvincible) color = Math.floor(performance.now() / 100) % 2 === 0 ? '#ffd455' : '#00ff41';
      drawSprite(ctx, sprite, px, py, 2, color);
    } else {
      const alpha = 0.9 - (i / segments.length) * 0.4;
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = alpha;
      ctx.fillStyle = isInvincible && Math.floor(performance.now() / 100) % 2 === 0 ? '#ffd455' : '#00ff41';
      ctx.fillRect(px + 1, py + 1, CS - 2, CS - 2);
      ctx.globalAlpha = saved;
    }
  }
}

function drawFood(ctx, state) {
  const { foodManager } = state;
  if (!foodManager.position) return;

  const px = OX + foodManager.position.x * CS;
  const py = OY + foodManager.position.y * CS;
  const pulse = 1 + Math.sin(performance.now() / 200) * 0.1;
  const offset = (1 - pulse) * CS / 2;

  ctx.fillStyle = '#ff4c60';
  ctx.shadowColor = '#ff4c60';
  ctx.shadowBlur = 8;
  drawSprite(ctx, SPRITES.SNAKE_FOOD, px + offset, py + offset, 2 * pulse, '#ff4c60');
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';
}

function drawPowerUp(ctx, state) {
  const { powerUpManager } = state;
  const item = powerUpManager.item;
  if (!item) return;

  const px = OX + item.x * CS;
  const py = OY + item.y * CS;
  const timeLeft = powerUpManager.getDespawnTimeRemaining();
  const flash = timeLeft < 2 && Math.floor(performance.now() / 200) % 2 === 0;

  if (!flash) {
    ctx.strokeStyle = item.type.color;
    ctx.lineWidth = 2;
    ctx.strokeRect(px, py, CS, CS);
    drawText(ctx, item.type.label, px + CS / 2, py + 2, {
      font: 'score', align: 'center', color: item.type.color,
    });
  }
}

function drawUI(ctx, state) {
  drawText(ctx, 'SCORE', 30, 10, { font: 'score', color: '#6a6d7a' });
  drawText(ctx, String(state.score).padStart(6, '0'), 30, 28, {
    font: 'score', color: '#f1f2f6',
  });

  drawText(ctx, 'HI-SCORE', LOGICAL_WIDTH - 30, 10, {
    font: 'score', align: 'right', color: '#6a6d7a',
  });
  drawText(ctx, String(state.hiScore).padStart(6, '0'), LOGICAL_WIDTH - 30, 28, {
    font: 'score', align: 'right', color: '#ffd455',
  });

  const activeEffect = state.powerUpManager.getActiveEffect();
  if (activeEffect) {
    const remaining = state.powerUpManager.getEffectTimeRemaining();
    const ratio = remaining / activeEffect.duration;
    const barWidth = 200;
    const barX = (LOGICAL_WIDTH - barWidth) / 2;
    const barY = 48;

    ctx.fillStyle = '#1a1d2a';
    ctx.fillRect(barX, barY, barWidth, 6);
    ctx.fillStyle = activeEffect.color;
    ctx.fillRect(barX, barY, barWidth * ratio, 6);

    drawText(ctx, activeEffect.label, LOGICAL_WIDTH / 2, 35, {
      font: 'score', align: 'center', color: activeEffect.color,
    });
  }
}

export function renderReadyScreen(ctx, state) {
  renderSnakeGame(ctx, state);
  const saved = ctx.globalAlpha;
  ctx.globalAlpha = 0.7;
  ctx.fillStyle = '#070814';
  ctx.fillRect(0, 0, LOGICAL_WIDTH, 640);
  ctx.globalAlpha = saved;

  drawGlowText(ctx, 'SNAKE', LOGICAL_WIDTH / 2, 250, {
    font: 'title', align: 'center', color: '#00ff41', glowColor: '#00ff41',
  });
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, 320, {
    font: 'score', align: 'center', color: '#ffd455', alpha: blink,
  });
}

export function renderGameOver(ctx, state) {
  renderSnakeGame(ctx, state);
  const saved = ctx.globalAlpha;
  ctx.globalAlpha = 0.8;
  ctx.fillStyle = '#070814';
  ctx.fillRect(0, 0, LOGICAL_WIDTH, 640);
  ctx.globalAlpha = saved;

  drawGlowText(ctx, 'GAME OVER', LOGICAL_WIDTH / 2, 220, {
    font: 'title', align: 'center', color: '#ff4c60', glowColor: '#ff4c60',
  });
  drawText(ctx, 'SCORE', LOGICAL_WIDTH / 2, 280, {
    font: 'score', align: 'center', color: '#6a6d7a',
  });
  drawText(ctx, String(state.score), LOGICAL_WIDTH / 2, 310, {
    font: 'title', align: 'center', color: '#ffd455',
  });
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, 380, {
    font: 'score', align: 'center', color: '#f1f2f6', alpha: blink,
  });
}

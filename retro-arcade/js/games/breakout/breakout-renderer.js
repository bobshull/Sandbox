import { BREAKOUT_CONFIG } from './breakout-config.js';
import { SPRITES, drawSprite } from '../../render/sprites.js';
import { drawText, drawGlowText } from '../../render/text.js';
import { effects } from '../../render/effects.js';
import { LOGICAL_WIDTH, LOGICAL_HEIGHT } from '../../platform/viewport.js';

const LEFT = BREAKOUT_CONFIG.PLAY_AREA_LEFT;
const RIGHT = BREAKOUT_CONFIG.PLAY_AREA_RIGHT;
const TOP = BREAKOUT_CONFIG.PLAY_AREA_TOP;

export function renderBreakoutGame(ctx, state) {
  drawWalls(ctx);
  drawBricks(ctx, state);
  drawPaddle(ctx, state);
  drawBalls(ctx, state);
  drawPowerUpCapsules(ctx, state);
  drawUI(ctx, state);
}

function drawWalls(ctx) {
  ctx.fillStyle = '#1a1d2a';
  ctx.fillRect(LEFT - 4, TOP, 4, LOGICAL_HEIGHT - TOP);
  ctx.fillRect(RIGHT, TOP, 4, LOGICAL_HEIGHT - TOP);
  ctx.fillRect(LEFT - 4, TOP - 4, RIGHT - LEFT + 8, 4);

  ctx.fillStyle = 'rgba(50,232,255,0.15)';
  ctx.fillRect(LEFT - 1, TOP, 1, LOGICAL_HEIGHT - TOP);
  ctx.fillRect(RIGHT, TOP, 1, LOGICAL_HEIGHT - TOP);
  ctx.fillRect(LEFT, TOP - 1, RIGHT - LEFT, 1);
}

function drawBricks(ctx, state) {
  for (const brick of state.brickManager.bricks) {
    if (!brick.alive) continue;

    ctx.fillStyle = brick.color;
    ctx.fillRect(brick.x, brick.y, brick.width, brick.height);

    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 1;
    ctx.strokeRect(brick.x, brick.y, brick.width, brick.height);

    if (brick.typeName === 'SILVER' && brick.hitsRemaining === 1) {
      ctx.strokeStyle = 'rgba(255,255,255,0.3)';
      ctx.beginPath();
      ctx.moveTo(brick.x + 3, brick.y + brick.height - 2);
      ctx.lineTo(brick.x + brick.width / 2, brick.y + 2);
      ctx.lineTo(brick.x + brick.width - 3, brick.y + brick.height - 2);
      ctx.stroke();
    }

    if (brick.typeName === 'GOLD') {
      const shimmer = (Math.sin(performance.now() / 300 + brick.x) + 1) * 0.15;
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = shimmer;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(brick.x + 2, brick.y + 2, brick.width - 4, brick.height - 4);
      ctx.globalAlpha = saved;
    }
  }
}

function drawPaddle(ctx, state) {
  const p = state.paddle;
  const radius = 4;

  ctx.fillStyle = '#f1f2f6';
  ctx.beginPath();
  ctx.roundRect(p.x, p.y, p.width, p.height, radius);
  ctx.fill();

  if (p.laser) {
    ctx.fillStyle = '#ff4c60';
    ctx.fillRect(p.x + 2, p.y, 3, p.height);
    ctx.fillRect(p.x + p.width - 5, p.y, 3, p.height);
  }

  if (p.sticky) {
    ctx.fillStyle = '#00ff41';
    ctx.fillRect(p.x, p.y - 2, p.width, 2);
  }
}

function drawBalls(ctx, state) {
  for (const ball of state.ballManager.getActiveBalls()) {
    ctx.fillStyle = 'rgba(255,255,255,0.2)';
    ctx.beginPath();
    ctx.arc(ball.x - ball.vx * 0.02, ball.y - ball.vy * 0.02, ball.radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#f1f2f6';
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.radius, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawPowerUpCapsules(ctx, state) {
  for (const cap of state.powerUpManager.capsules) {
    const bounce = Math.sin(performance.now() / 150) * 2;
    ctx.fillStyle = cap.type.color;
    ctx.fillRect(cap.x, cap.y + bounce, cap.width, cap.height);
    drawText(ctx, cap.type.label, cap.x + cap.width / 2, cap.y + bounce + 1, {
      font: 'score', align: 'center', color: '#070814',
    });
  }
}

function drawUI(ctx, state) {
  drawText(ctx, 'SCORE', 30, 8, { font: 'score', color: '#6a6d7a' });
  drawText(ctx, String(state.score).padStart(6, '0'), 30, 24, {
    font: 'score', color: '#f1f2f6',
  });

  drawText(ctx, 'LV ' + (state.level + 1), LOGICAL_WIDTH / 2, 8, {
    font: 'score', align: 'center', color: '#6a6d7a',
  });

  if (state.combo > 1) {
    drawText(ctx, 'x' + state.combo.toFixed(1), LOGICAL_WIDTH / 2, 24, {
      font: 'score', align: 'center', color: '#ffd455',
    });
  }

  for (let i = 0; i < state.lives; i++) {
    ctx.fillStyle = '#f1f2f6';
    ctx.beginPath();
    ctx.arc(LOGICAL_WIDTH - 30 - i * 20, 20, BREAKOUT_CONFIG.BALL_RADIUS + 1, 0, Math.PI * 2);
    ctx.fill();
  }
}

export function renderServingScreen(ctx, state) {
  renderBreakoutGame(ctx, state);
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'SERVE', LOGICAL_WIDTH / 2, BREAKOUT_CONFIG.PADDLE_Y - 40, {
    font: 'score', align: 'center', color: '#ffd455', alpha: blink,
  });
}

export function renderReadyScreen(ctx, state) {
  renderBreakoutGame(ctx, state);
  const saved = ctx.globalAlpha;
  ctx.globalAlpha = 0.7;
  ctx.fillStyle = '#070814';
  ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
  ctx.globalAlpha = saved;

  drawGlowText(ctx, 'BREAKOUT', LOGICAL_WIDTH / 2, 250, {
    font: 'title', align: 'center', color: '#32e8ff', glowColor: '#32e8ff',
  });
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, 320, {
    font: 'score', align: 'center', color: '#ffd455', alpha: blink,
  });
}

export function renderGameOver(ctx, state) {
  renderBreakoutGame(ctx, state);
  const saved = ctx.globalAlpha;
  ctx.globalAlpha = 0.8;
  ctx.fillStyle = '#070814';
  ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
  ctx.globalAlpha = saved;

  drawGlowText(ctx, 'GAME OVER', LOGICAL_WIDTH / 2, 220, {
    font: 'title', align: 'center', color: '#ff4c60', glowColor: '#ff4c60',
  });
  drawText(ctx, String(state.score), LOGICAL_WIDTH / 2, 300, {
    font: 'title', align: 'center', color: '#ffd455',
  });
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, 370, {
    font: 'score', align: 'center', color: '#f1f2f6', alpha: blink,
  });
}

import { INVADERS_CONFIG } from './invaders-config.js';
import { SPRITES, drawSprite } from '../../render/sprites.js';
import { drawText, drawGlowText } from '../../render/text.js';
import { effects } from '../../render/effects.js';
import { LOGICAL_WIDTH, LOGICAL_HEIGHT } from '../../platform/viewport.js';

const ENEMY_SPRITES = {
  SQUID: [SPRITES.INVADER_SQUID_1, SPRITES.INVADER_SQUID_2],
  CRAB: [SPRITES.INVADER_CRAB_1, SPRITES.INVADER_CRAB_2],
  OCTOPUS: [SPRITES.INVADER_OCTOPUS_1, SPRITES.INVADER_OCTOPUS_2],
};

const ENEMY_COLORS = { SQUID: '#ff4c60', CRAB: '#32e8ff', OCTOPUS: '#00ff41' };
const SCALE = 2;

export function renderInvadersGame(ctx, state) {
  drawFormation(ctx, state);
  drawPlayer(ctx, state);
  drawPlayerBullet(ctx, state);
  drawEnemyBullets(ctx, state);
  drawShields(ctx, state);
  drawUFO(ctx, state);
  drawGroundLine(ctx);
  drawUI(ctx, state);
}

function drawFormation(ctx, state) {
  const { formation } = state;
  for (let r = 0; r < INVADERS_CONFIG.FORMATION_ROWS; r++) {
    for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
      const enemy = formation.grid[r][c];
      if (!enemy.alive) continue;

      const pos = formation.getEnemyWorldPos(r, c);
      const sprites = ENEMY_SPRITES[enemy.type];
      const sprite = sprites[enemy.animFrame];
      const color = ENEMY_COLORS[enemy.type];
      drawSprite(ctx, sprite, pos.x, pos.y, SCALE, color);
    }
  }
}

function drawPlayer(ctx, state) {
  const { player } = state;
  if (!player.alive) return;

  let color = '#00ff41';
  if (player.isInvincible()) {
    color = Math.floor(performance.now() / 100) % 2 === 0 ? '#00ff41' : 'transparent';
  }
  if (color !== 'transparent') {
    drawSprite(ctx, SPRITES.PLAYER_SHIP, player.x, player.y, SCALE, color);
  }
}

function drawPlayerBullet(ctx, state) {
  const b = state.player.bullet;
  if (!b.active) return;
  ctx.fillStyle = '#f1f2f6';
  ctx.fillRect(b.x, b.y, INVADERS_CONFIG.PLAYER_BULLET_WIDTH, INVADERS_CONFIG.PLAYER_BULLET_HEIGHT);
}

function drawEnemyBullets(ctx, state) {
  ctx.fillStyle = '#ff4c60';
  for (const b of state.enemyShooting.bullets) {
    ctx.fillRect(b.x, b.y, INVADERS_CONFIG.BULLET_WIDTH, INVADERS_CONFIG.BULLET_HEIGHT);
    ctx.fillRect(b.x - 1, b.y + 2, INVADERS_CONFIG.BULLET_WIDTH + 2, 2);
  }
}

function drawShields(ctx, state) {
  state.shieldSystem.render(ctx, SCALE);
}

function drawUFO(ctx, state) {
  if (!state.ufo || !state.ufo.active) return;
  drawSprite(ctx, SPRITES.INVADER_UFO, state.ufo.x, state.ufo.y, SCALE, '#ff4c60');
}

function drawGroundLine(ctx) {
  ctx.fillStyle = '#00ff41';
  ctx.fillRect(INVADERS_CONFIG.PLAY_AREA_LEFT, INVADERS_CONFIG.GROUND_Y,
    INVADERS_CONFIG.PLAY_AREA_RIGHT - INVADERS_CONFIG.PLAY_AREA_LEFT, 2);
}

function drawUI(ctx, state) {
  drawText(ctx, 'SCORE', 30, 8, { font: 'score', color: '#6a6d7a' });
  drawText(ctx, String(state.score).padStart(6, '0'), 30, 24, {
    font: 'score', color: '#f1f2f6',
  });

  drawText(ctx, 'WAVE ' + (state.wave + 1), LOGICAL_WIDTH / 2, 8, {
    font: 'score', align: 'center', color: '#6a6d7a',
  });

  drawText(ctx, 'HI-SCORE', LOGICAL_WIDTH - 30, 8, {
    font: 'score', align: 'right', color: '#6a6d7a',
  });
  drawText(ctx, String(state.hiScore).padStart(6, '0'), LOGICAL_WIDTH - 30, 24, {
    font: 'score', align: 'right', color: '#ffd455',
  });

  for (let i = 0; i < state.lives; i++) {
    drawSprite(ctx, SPRITES.PLAYER_SHIP, 30 + i * 35, LOGICAL_HEIGHT - 25, 1, '#00ff41');
  }
}

export function renderReadyScreen(ctx, state) {
  renderInvadersGame(ctx, state);
  const saved = ctx.globalAlpha;
  ctx.globalAlpha = 0.7;
  ctx.fillStyle = '#070814';
  ctx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
  ctx.globalAlpha = saved;

  drawGlowText(ctx, 'SPACE', LOGICAL_WIDTH / 2, 230, {
    font: 'title', align: 'center', color: '#32e8ff', glowColor: '#32e8ff',
  });
  drawGlowText(ctx, 'INVADERS', LOGICAL_WIDTH / 2, 260, {
    font: 'title', align: 'center', color: '#32e8ff', glowColor: '#32e8ff',
  });
  const blink = effects.getBlinkAlpha(600);
  drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, 340, {
    font: 'score', align: 'center', color: '#ffd455', alpha: blink,
  });
}

export function renderGameOver(ctx, state) {
  renderInvadersGame(ctx, state);
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

import { INVADERS_CONFIG } from './invaders-config.js';
import { rectIntersects } from '../../engine/collision.js';

export function checkPlayerBulletVsEnemies(bullet, formation) {
  if (!bullet.active) return null;
  for (let r = 0; r < INVADERS_CONFIG.FORMATION_ROWS; r++) {
    for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
      const enemy = formation.grid[r][c];
      if (!enemy.alive) continue;
      const pos = formation.getEnemyWorldPos(r, c);
      const enemyRect = { x: pos.x, y: pos.y, w: 16 * 2, h: 16 };
      const bulletRect = {
        x: bullet.x, y: bullet.y,
        w: INVADERS_CONFIG.PLAYER_BULLET_WIDTH, h: INVADERS_CONFIG.PLAYER_BULLET_HEIGHT,
      };
      if (rectIntersects(bulletRect, enemyRect)) {
        return { row: r, col: c };
      }
    }
  }
  return null;
}

export function checkPlayerBulletVsUFO(bullet, ufo) {
  if (!bullet.active || !ufo.active) return false;
  const ufoRect = { x: ufo.x, y: ufo.y, w: INVADERS_CONFIG.UFO_WIDTH, h: INVADERS_CONFIG.UFO_HEIGHT };
  const bulletRect = { x: bullet.x, y: bullet.y, w: INVADERS_CONFIG.PLAYER_BULLET_WIDTH, h: INVADERS_CONFIG.PLAYER_BULLET_HEIGHT };
  return rectIntersects(bulletRect, ufoRect);
}

export function checkEnemyBulletsVsPlayer(enemyBullets, player) {
  const playerRect = player.getRect();
  for (let i = enemyBullets.length - 1; i >= 0; i--) {
    const eb = enemyBullets[i];
    const ebRect = { x: eb.x, y: eb.y, w: INVADERS_CONFIG.BULLET_WIDTH, h: INVADERS_CONFIG.BULLET_HEIGHT };
    if (player.alive && !player.isInvincible() && rectIntersects(ebRect, playerRect)) {
      return i;
    }
  }
  return -1;
}

export function getRowPoints(row) {
  if (row === 0) return 30;
  if (row <= 2) return 20;
  return 10;
}

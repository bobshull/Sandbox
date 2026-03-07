import { INVADERS_CONFIG } from './invaders-config.js';
import { SPRITES } from '../../render/sprites.js';

export class ShieldSystem {
  constructor() {
    this.shields = [];
  }

  reset() {
    this.shields = [];
    const spacing = (INVADERS_CONFIG.PLAY_AREA_RIGHT - INVADERS_CONFIG.PLAY_AREA_LEFT) / (INVADERS_CONFIG.SHIELD_COUNT + 1);

    for (let i = 0; i < INVADERS_CONFIG.SHIELD_COUNT; i++) {
      const x = INVADERS_CONFIG.PLAY_AREA_LEFT + spacing * (i + 1) - INVADERS_CONFIG.SHIELD_WIDTH / 2;
      const pixels = [];
      for (let r = 0; r < SPRITES.SHIELD_TEMPLATE.length; r++) {
        pixels.push(new Uint8Array(SPRITES.SHIELD_TEMPLATE[r]));
      }
      this.shields.push({ x, y: INVADERS_CONFIG.SHIELD_Y, pixels });
    }
  }

  checkBulletHit(bullet, isPlayerBullet) {
    const bx = bullet.x;
    const by = bullet.y;

    for (const shield of this.shields) {
      const localX = Math.floor((bx - shield.x) / 2);
      const localY = Math.floor((by - shield.y) / 2);

      if (localX < 0 || localX >= INVADERS_CONFIG.SHIELD_WIDTH / 2 ||
          localY < 0 || localY >= INVADERS_CONFIG.SHIELD_HEIGHT / 2) continue;

      if (shield.pixels[localY] && shield.pixels[localY][localX]) {
        this._erode(shield, localX, localY, isPlayerBullet ? -1 : 1);
        return true;
      }
    }
    return false;
  }

  checkFormationErosion(formationBottomY) {
    for (const shield of this.shields) {
      if (formationBottomY < shield.y) continue;
      const erodeRow = Math.floor((formationBottomY - shield.y) / 2);
      for (let r = 0; r <= erodeRow && r < shield.pixels.length; r++) {
        shield.pixels[r].fill(0);
      }
    }
  }

  _erode(shield, cx, cy, direction) {
    const radius = INVADERS_CONFIG.SHIELD_EROSION_RADIUS;
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius) continue;
        const py = cy + dy * direction;
        const px = cx + dx;
        if (py >= 0 && py < shield.pixels.length && px >= 0 && px < shield.pixels[0].length) {
          shield.pixels[py][px] = 0;
        }
      }
    }
  }

  render(ctx, scale) {
    for (const shield of this.shields) {
      ctx.fillStyle = '#00ff41';
      for (let r = 0; r < shield.pixels.length; r++) {
        for (let c = 0; c < shield.pixels[r].length; c++) {
          if (shield.pixels[r][c]) {
            ctx.fillRect(shield.x + c * scale, shield.y + r * scale, scale, scale);
          }
        }
      }
    }
  }
}

export class EnemyShootingSystem {
  constructor() {
    this.bullets = [];
    this._shootAccum = 0;
    this._shotsFired = 0;
  }

  reset() {
    this.bullets.length = 0;
    this._shootAccum = 0;
    this._shotsFired = 0;
  }

  getShootInterval(aliveCount) {
    const total = INVADERS_CONFIG.FORMATION_COLS * INVADERS_CONFIG.FORMATION_ROWS;
    const ratio = aliveCount / total;
    const range = INVADERS_CONFIG.ENEMY_SHOOT_INTERVAL_MAX_MS - INVADERS_CONFIG.ENEMY_SHOOT_INTERVAL_MIN_MS;
    return INVADERS_CONFIG.ENEMY_SHOOT_INTERVAL_MIN_MS + range * ratio;
  }

  update(dt, formation, playerX) {
    this._shootAccum += dt * 1000;
    const interval = this.getShootInterval(formation.aliveCount);

    if (this._shootAccum >= interval && this.bullets.length < INVADERS_CONFIG.ENEMY_BULLET_MAX) {
      this._shootAccum -= interval;
      this._fireAt(formation, playerX);
    }

    for (let i = this.bullets.length - 1; i >= 0; i--) {
      this.bullets[i].y += INVADERS_CONFIG.ENEMY_BULLET_SPEED * dt;
      if (this.bullets[i].y > INVADERS_CONFIG.GROUND_Y) this.bullets.splice(i, 1);
    }
  }

  _fireAt(formation, playerX) {
    const cols = formation.getShootableColumns();
    if (cols.length === 0) return;

    let col;
    if (Math.random() < INVADERS_CONFIG.ENEMY_SHOOT_COLUMN_BIAS) {
      let nearest = cols[0];
      let minDist = Infinity;
      for (const c of cols) {
        const ex = formation.originX + c * INVADERS_CONFIG.ENEMY_SPACING_X;
        const dist = Math.abs(ex - playerX);
        if (dist < minDist) { minDist = dist; nearest = c; }
      }
      col = nearest;
    } else {
      col = cols[Math.floor(Math.random() * cols.length)];
    }

    const enemy = formation.getBottomEnemyInColumn(col);
    if (!enemy) return;

    const pos = formation.getEnemyWorldPos(enemy.row, enemy.col);
    this.bullets.push({
      x: pos.x + 8,
      y: pos.y + 16,
    });
    this._shotsFired++;
  }
}

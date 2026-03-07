import { INVADERS_CONFIG } from './invaders-config.js';

export { ShieldSystem, EnemyShootingSystem } from './invaders-shields.js';

export class Formation {
  constructor() {
    this.grid = [];
    this.originX = 0;
    this.originY = 0;
    this.directionX = 1;
    this.aliveCount = 0;
    this.animFrame = 0;
    this._tickAccum = 0;
  }

  reset(wave) {
    this.originX = INVADERS_CONFIG.FORMATION_START_X;
    this.originY = INVADERS_CONFIG.FORMATION_START_Y + wave * INVADERS_CONFIG.WAVE_DROP_PER_WAVE;
    this.directionX = 1;
    this.aliveCount = INVADERS_CONFIG.FORMATION_COLS * INVADERS_CONFIG.FORMATION_ROWS;
    this.animFrame = 0;
    this._tickAccum = 0;

    this.grid = [];
    for (let r = 0; r < INVADERS_CONFIG.FORMATION_ROWS; r++) {
      const row = [];
      let type;
      if (r === 0) type = 'SQUID';
      else if (r <= 2) type = 'CRAB';
      else type = 'OCTOPUS';

      for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
        row.push({ type, alive: true, animFrame: 0 });
      }
      this.grid.push(row);
    }
  }

  getTickInterval() {
    const ratio = this.aliveCount / (INVADERS_CONFIG.FORMATION_COLS * INVADERS_CONFIG.FORMATION_ROWS);
    const range = INVADERS_CONFIG.TICK_INTERVAL_MAX_MS - INVADERS_CONFIG.TICK_INTERVAL_MIN_MS;
    return INVADERS_CONFIG.TICK_INTERVAL_MIN_MS + range * ratio;
  }

  update(dt) {
    this._tickAccum += dt * 1000;
    const interval = this.getTickInterval();
    if (this._tickAccum < interval) return false;
    this._tickAccum -= interval;

    this.originX += INVADERS_CONFIG.STEP_X * this.directionX;
    this.animFrame = 1 - this.animFrame;
    this._updateAnimFrames();

    const left = this._getLeftmostCol();
    const right = this._getRightmostCol();
    const leftEdge = this.originX + left * INVADERS_CONFIG.ENEMY_SPACING_X;
    const rightEdge = this.originX + right * INVADERS_CONFIG.ENEMY_SPACING_X + 24;

    if (rightEdge >= INVADERS_CONFIG.PLAY_AREA_RIGHT || leftEdge <= INVADERS_CONFIG.PLAY_AREA_LEFT) {
      this.directionX = -this.directionX;
      this.originY += INVADERS_CONFIG.STEP_DOWN;
    }

    return true;
  }

  getEnemyWorldPos(row, col) {
    return {
      x: this.originX + col * INVADERS_CONFIG.ENEMY_SPACING_X,
      y: this.originY + row * INVADERS_CONFIG.ENEMY_SPACING_Y,
    };
  }

  killEnemy(row, col) {
    if (this.grid[row][col].alive) {
      this.grid[row][col].alive = false;
      this.aliveCount--;
    }
  }

  getBottomEnemyInColumn(col) {
    for (let r = INVADERS_CONFIG.FORMATION_ROWS - 1; r >= 0; r--) {
      if (this.grid[r][col].alive) return { row: r, col };
    }
    return null;
  }

  getShootableColumns() {
    const cols = [];
    for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
      if (this.getBottomEnemyInColumn(c)) cols.push(c);
    }
    return cols;
  }

  getLowestAliveY() {
    for (let r = INVADERS_CONFIG.FORMATION_ROWS - 1; r >= 0; r--) {
      for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
        if (this.grid[r][c].alive) {
          return this.originY + r * INVADERS_CONFIG.ENEMY_SPACING_Y + 16;
        }
      }
    }
    return 0;
  }

  isFormationAtPlayer() { return this.getLowestAliveY() >= INVADERS_CONFIG.PLAYER_Y; }
  isCleared() { return this.aliveCount <= 0; }

  _getLeftmostCol() {
    for (let c = 0; c < INVADERS_CONFIG.FORMATION_COLS; c++) {
      for (let r = 0; r < INVADERS_CONFIG.FORMATION_ROWS; r++) {
        if (this.grid[r][c].alive) return c;
      }
    }
    return 0;
  }

  _getRightmostCol() {
    for (let c = INVADERS_CONFIG.FORMATION_COLS - 1; c >= 0; c--) {
      for (let r = 0; r < INVADERS_CONFIG.FORMATION_ROWS; r++) {
        if (this.grid[r][c].alive) return c;
      }
    }
    return INVADERS_CONFIG.FORMATION_COLS - 1;
  }

  _updateAnimFrames() {
    for (const row of this.grid) {
      for (const enemy of row) {
        if (enemy.alive) enemy.animFrame = this.animFrame;
      }
    }
  }
}

export class PlayerShip {
  constructor() {
    this.x = 0;
    this.y = INVADERS_CONFIG.PLAYER_Y;
    this.width = INVADERS_CONFIG.PLAYER_WIDTH;
    this.height = INVADERS_CONFIG.PLAYER_HEIGHT;
    this.alive = true;
    this.bullet = { x: 0, y: 0, active: false };
    this._invincibleTimer = 0;
    this.shotsFired = 0;
  }

  reset() {
    this.x = (INVADERS_CONFIG.PLAY_AREA_LEFT + INVADERS_CONFIG.PLAY_AREA_RIGHT) / 2 - this.width / 2;
    this.alive = true;
    this.bullet.active = false;
    this._invincibleTimer = 0;
    this.shotsFired = 0;
  }

  moveLeft(dt) {
    this.x = Math.max(INVADERS_CONFIG.PLAY_AREA_LEFT, this.x - INVADERS_CONFIG.PLAYER_SPEED * dt);
  }

  moveRight(dt) {
    this.x = Math.min(INVADERS_CONFIG.PLAY_AREA_RIGHT - this.width, this.x + INVADERS_CONFIG.PLAYER_SPEED * dt);
  }

  fire() {
    if (this.bullet.active || !this.alive) return false;
    this.bullet.x = this.x + this.width / 2 - INVADERS_CONFIG.PLAYER_BULLET_WIDTH / 2;
    this.bullet.y = this.y;
    this.bullet.active = true;
    this.shotsFired++;
    return true;
  }

  updateBullet(dt) {
    if (!this.bullet.active) return;
    this.bullet.y -= INVADERS_CONFIG.PLAYER_BULLET_SPEED * dt;
    if (this.bullet.y < 0) this.bullet.active = false;
  }

  kill() {
    this.alive = false;
    this.bullet.active = false;
  }

  respawn() {
    this.x = (INVADERS_CONFIG.PLAY_AREA_LEFT + INVADERS_CONFIG.PLAY_AREA_RIGHT) / 2 - this.width / 2;
    this.alive = true;
    this._invincibleTimer = INVADERS_CONFIG.RESPAWN_INVINCIBILITY_S;
  }

  updateInvincibility(dt) { if (this._invincibleTimer > 0) this._invincibleTimer -= dt; }
  isInvincible() { return this._invincibleTimer > 0; }
  getRect() { return { x: this.x, y: this.y, w: this.width, h: this.height }; }
}

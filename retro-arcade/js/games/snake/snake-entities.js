import { SNAKE_CONFIG } from './snake-config.js';

const CellType = Object.freeze({
  EMPTY: 0,
  SNAKE: 1,
  FOOD: 2,
  POWERUP: 3,
});

export class SnakeGrid {
  constructor() {
    const size = SNAKE_CONFIG.GRID_WIDTH * SNAKE_CONFIG.GRID_HEIGHT;
    this._cells = new Uint8Array(size);
    this._occupied = 0;
  }

  setCell(x, y, type) {
    const prev = this._cells[y * SNAKE_CONFIG.GRID_WIDTH + x];
    this._cells[y * SNAKE_CONFIG.GRID_WIDTH + x] = type;
    if (prev === CellType.EMPTY && type !== CellType.EMPTY) this._occupied++;
    else if (prev !== CellType.EMPTY && type === CellType.EMPTY) this._occupied--;
  }

  getCell(x, y) {
    return this._cells[y * SNAKE_CONFIG.GRID_WIDTH + x];
  }

  isFree(x, y) {
    return this._cells[y * SNAKE_CONFIG.GRID_WIDTH + x] === CellType.EMPTY;
  }

  clear() {
    this._cells.fill(CellType.EMPTY);
    this._occupied = 0;
  }

  getRandomFreeCell() {
    const total = SNAKE_CONFIG.GRID_WIDTH * SNAKE_CONFIG.GRID_HEIGHT;
    if (this._occupied >= total) return null;
    const maxAttempts = total * 2;
    for (let i = 0; i < maxAttempts; i++) {
      const x = Math.floor(Math.random() * SNAKE_CONFIG.GRID_WIDTH);
      const y = Math.floor(Math.random() * SNAKE_CONFIG.GRID_HEIGHT);
      if (this.isFree(x, y)) return { x, y };
    }
    for (let y = 0; y < SNAKE_CONFIG.GRID_HEIGHT; y++) {
      for (let x = 0; x < SNAKE_CONFIG.GRID_WIDTH; x++) {
        if (this.isFree(x, y)) return { x, y };
      }
    }
    return null;
  }
}

export class Snake {
  constructor() {
    this.segments = [];
    this.direction = { x: 1, y: 0 };
    this._growing = false;
  }

  reset(startX, startY, startLength, dirX, dirY) {
    this.segments.length = 0;
    for (let i = 0; i < startLength; i++) {
      this.segments.push({ x: startX - i * dirX, y: startY - i * dirY });
    }
    this.direction = { x: dirX, y: dirY };
    this._growing = false;
  }

  getHead() {
    return this.segments[0];
  }

  move() {
    const head = this.segments[0];
    const newHead = { x: head.x + this.direction.x, y: head.y + this.direction.y };
    this.segments.unshift(newHead);
    if (this._growing) {
      this._growing = false;
    } else {
      this.segments.pop();
    }
    return newHead;
  }

  grow() {
    this._growing = true;
  }

  checkSelfCollision() {
    const head = this.segments[0];
    for (let i = 1; i < this.segments.length; i++) {
      if (this.segments[i].x === head.x && this.segments[i].y === head.y) return true;
    }
    return false;
  }

  applyToGrid(grid) {
    for (const seg of this.segments) {
      grid.setCell(seg.x, seg.y, CellType.SNAKE);
    }
  }
}

export class FoodManager {
  constructor(grid) {
    this._grid = grid;
    this.position = null;
  }

  spawn() {
    const cell = this._grid.getRandomFreeCell();
    if (cell) {
      this.position = cell;
      this._grid.setCell(cell.x, cell.y, CellType.FOOD);
    }
  }

  checkEaten(headX, headY) {
    return this.position && this.position.x === headX && this.position.y === headY;
  }

  respawn() {
    if (this.position) {
      this._grid.setCell(this.position.x, this.position.y, CellType.EMPTY);
    }
    this.spawn();
  }
}

export class PowerUpManager {
  constructor(grid) {
    this._grid = grid;
    this.item = null;
    this.activeEffect = null;
    this._effectTimer = 0;
    this._despawnTimer = 0;
  }

  trySpawn() {
    if (this.item) return;
    if (Math.random() > SNAKE_CONFIG.POWERUP_SPAWN_CHANCE) return;

    const types = Object.values(SNAKE_CONFIG.POWERUP_TYPES);
    const type = types[Math.floor(Math.random() * types.length)];
    const cell = this._grid.getRandomFreeCell();
    if (!cell) return;

    this.item = { x: cell.x, y: cell.y, type };
    this._despawnTimer = SNAKE_CONFIG.POWERUP_DESPAWN_TIME;
    this._grid.setCell(cell.x, cell.y, CellType.POWERUP);
  }

  checkCollected(headX, headY) {
    if (!this.item) return null;
    if (this.item.x === headX && this.item.y === headY) {
      const type = this.item.type;
      this._grid.setCell(this.item.x, this.item.y, CellType.EMPTY);
      this.item = null;
      this.activeEffect = type;
      this._effectTimer = type.duration;
      return type;
    }
    return null;
  }

  update(dt) {
    if (this.item) {
      this._despawnTimer -= dt;
      if (this._despawnTimer <= 0) {
        this._grid.setCell(this.item.x, this.item.y, CellType.EMPTY);
        this.item = null;
      }
    }
    if (this.activeEffect) {
      this._effectTimer -= dt;
      if (this._effectTimer <= 0) {
        this.activeEffect = null;
        this._effectTimer = 0;
      }
    }
  }

  getActiveEffect() { return this.activeEffect; }
  getEffectTimeRemaining() { return this._effectTimer; }
  getDespawnTimeRemaining() { return this._despawnTimer; }
  reset() {
    if (this.item) this._grid.setCell(this.item.x, this.item.y, CellType.EMPTY);
    this.item = null; this.activeEffect = null; this._effectTimer = 0; this._despawnTimer = 0;
  }
}

export { CellType };

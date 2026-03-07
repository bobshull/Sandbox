import { BREAKOUT_CONFIG } from './breakout-config.js';

const LEVEL_PATTERNS = {
  full(cols, rows) {
    const grid = [];
    for (let r = 0; r < rows; r++) {
      const row = [];
      for (let c = 0; c < cols; c++) row.push(true);
      grid.push(row);
    }
    return grid;
  },
  checkerboard(cols, rows) {
    const grid = [];
    for (let r = 0; r < rows; r++) {
      const row = [];
      for (let c = 0; c < cols; c++) row.push((r + c) % 2 === 0);
      grid.push(row);
    }
    return grid;
  },
  diamond(cols, rows) {
    const cx = Math.floor(cols / 2);
    const cy = Math.floor(rows / 2);
    const grid = [];
    for (let r = 0; r < rows; r++) {
      const row = [];
      for (let c = 0; c < cols; c++) {
        row.push(Math.abs(c - cx) + Math.abs(r - cy) <= Math.max(cx, cy));
      }
      grid.push(row);
    }
    return grid;
  },
  fortress(cols, rows) {
    const grid = [];
    for (let r = 0; r < rows; r++) {
      const row = [];
      for (let c = 0; c < cols; c++) {
        const isWall = c === 0 || c === cols - 1 || r === 0;
        const isInner = r >= 2 && r <= 4 && c >= 4 && c <= cols - 5;
        row.push(isWall || isInner);
      }
      grid.push(row);
    }
    return grid;
  },
  invader(cols, rows) {
    return this.full(cols, rows);
  },
};

const ROW_COLORS = ['RED', 'RED', 'ORANGE', 'ORANGE', 'GREEN', 'GREEN', 'CYAN', 'WHITE'];

export class BrickManager {
  constructor() {
    this.bricks = [];
  }

  buildLevel(levelIndex) {
    this.bricks.length = 0;
    const levelDef = BREAKOUT_CONFIG.LEVELS[levelIndex % BREAKOUT_CONFIG.LEVELS.length];
    const pattern = LEVEL_PATTERNS[levelDef.pattern](BREAKOUT_CONFIG.COLS, levelDef.rows);
    const types = BREAKOUT_CONFIG.BRICK_TYPES;

    for (let r = 0; r < levelDef.rows; r++) {
      for (let c = 0; c < BREAKOUT_CONFIG.COLS; c++) {
        if (!pattern[r][c]) continue;

        let typeName = ROW_COLORS[r] || 'WHITE';
        if (levelDef.hasGold && r === 0 && c % 3 === 1) typeName = 'GOLD';
        if (levelDef.hasSilver && r <= 1 && !levelDef.hasGold) typeName = 'SILVER';

        const type = types[typeName];
        const hasPowerUp = typeName !== 'GOLD' && Math.random() < BREAKOUT_CONFIG.POWERUP_SPAWN_CHANCE;

        this.bricks.push({
          x: BREAKOUT_CONFIG.BRICK_OFFSET_X + c * (BREAKOUT_CONFIG.BRICK_WIDTH + BREAKOUT_CONFIG.BRICK_GAP),
          y: BREAKOUT_CONFIG.BRICK_OFFSET_Y + r * (BREAKOUT_CONFIG.BRICK_HEIGHT + BREAKOUT_CONFIG.BRICK_GAP),
          width: BREAKOUT_CONFIG.BRICK_WIDTH,
          height: BREAKOUT_CONFIG.BRICK_HEIGHT,
          typeName,
          color: type.color,
          points: type.points,
          hitsRemaining: type.hits,
          alive: true,
          hasPowerUp,
          row: r,
        });
      }
    }
  }

  hitBrick(brick) {
    if (brick.hitsRemaining < 0) return false;
    brick.hitsRemaining--;
    if (brick.hitsRemaining <= 0) {
      brick.alive = false;
      return true;
    }
    return false;
  }

  isCleared() {
    return this.bricks.every(b => !b.alive || b.hitsRemaining < 0);
  }
}

export const BREAKOUT_CONFIG = Object.freeze({
  COLS: 14,
  ROWS: 8,
  BRICK_WIDTH: 30,
  BRICK_HEIGHT: 12,
  BRICK_GAP: 2,
  BRICK_OFFSET_X: 25,
  BRICK_OFFSET_Y: 80,

  PADDLE_WIDTH: 75,
  PADDLE_WIDTH_SMALL: 37,
  PADDLE_WIDTH_LARGE: 112,
  PADDLE_HEIGHT: 10,
  PADDLE_Y: 580,
  PADDLE_SPEED: 400,

  BALL_RADIUS: 4,
  BALL_BASE_SPEED: 280,
  BALL_SPEED_TIERS: Object.freeze([
    Object.freeze({ hitCount: 4, speedMult: 1.1 }),
    Object.freeze({ hitCount: 12, speedMult: 1.2 }),
    Object.freeze({ hitCount: 24, speedMult: 1.35 }),
    Object.freeze({ hitCount: 36, speedMult: 1.5 }),
  ]),
  BALL_MIN_ANGLE_DEG: 30,

  BRICK_TYPES: Object.freeze({
    WHITE: Object.freeze({ color: '#f1f2f6', points: 1, hits: 1 }),
    ORANGE: Object.freeze({ color: '#ff8c42', points: 3, hits: 1 }),
    CYAN: Object.freeze({ color: '#32e8ff', points: 5, hits: 1 }),
    GREEN: Object.freeze({ color: '#00ff41', points: 7, hits: 1 }),
    RED: Object.freeze({ color: '#ff4c60', points: 10, hits: 1 }),
    SILVER: Object.freeze({ color: '#a1a2a6', points: 15, hits: 2 }),
    GOLD: Object.freeze({ color: '#ffd455', points: 0, hits: -1 }),
  }),

  COMBO_INCREMENT: 0.1,

  LIVES: 3,
  EXTRA_LIFE_SCORE: 10000,

  POWERUP_SPAWN_CHANCE: 0.2,
  POWERUP_FALL_SPEED: 120,
  POWERUP_TYPES: Object.freeze({
    ENLARGE: Object.freeze({ id: 'enlarge', color: '#32e8ff', label: 'E' }),
    MULTI: Object.freeze({ id: 'multi', color: '#ff00ff', label: 'M' }),
    LASER: Object.freeze({ id: 'laser', color: '#ff4c60', label: 'L' }),
    CATCH: Object.freeze({ id: 'catch', color: '#00ff41', label: 'C' }),
    SLOW: Object.freeze({ id: 'slow', color: '#ffd455', label: 'S' }),
    EXTRA_LIFE: Object.freeze({ id: 'extraLife', color: '#8f47b5', label: '+' }),
  }),

  PLAY_AREA_LEFT: 20,
  PLAY_AREA_RIGHT: 460,
  PLAY_AREA_TOP: 50,

  LEVELS: Object.freeze([
    Object.freeze({ pattern: 'full', rows: 6 }),
    Object.freeze({ pattern: 'checkerboard', rows: 7 }),
    Object.freeze({ pattern: 'diamond', rows: 8 }),
    Object.freeze({ pattern: 'fortress', rows: 7 }),
    Object.freeze({ pattern: 'invader', rows: 8 }),
    Object.freeze({ pattern: 'full', rows: 8, hasSilver: true }),
    Object.freeze({ pattern: 'checkerboard', rows: 8, hasSilver: true }),
    Object.freeze({ pattern: 'diamond', rows: 8, hasGold: true }),
    Object.freeze({ pattern: 'fortress', rows: 8, hasGold: true }),
    Object.freeze({ pattern: 'full', rows: 8, hasSilver: true, hasGold: true }),
  ]),
});

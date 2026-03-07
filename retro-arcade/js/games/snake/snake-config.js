export const SNAKE_CONFIG = Object.freeze({
  GRID_WIDTH: 25,
  GRID_HEIGHT: 25,
  CELL_SIZE: 16,

  BASE_SPEED_MS: 150,
  MIN_SPEED_MS: 80,
  SPEED_DECREASE_PER_LENGTH: 2,

  POINTS_PER_FOOD: 10,
  SPEED_BONUS_THRESHOLD_MS: 120,
  SPEED_BONUS_POINTS: 5,

  STREAK_THRESHOLDS: Object.freeze([
    Object.freeze({ count: 5, multiplier: 1.5 }),
    Object.freeze({ count: 10, multiplier: 2.0 }),
    Object.freeze({ count: 15, multiplier: 3.0 }),
  ]),

  LENGTH_MILESTONES: Object.freeze([
    Object.freeze({ length: 10, points: 50 }),
    Object.freeze({ length: 25, points: 100 }),
    Object.freeze({ length: 50, points: 250 }),
    Object.freeze({ length: 75, points: 500 }),
    Object.freeze({ length: 100, points: 1000 }),
  ]),

  POWERUP_SPAWN_CHANCE: 0.15,
  POWERUP_DESPAWN_TIME: 8,

  POWERUP_TYPES: Object.freeze({
    SPEED_BOOST: Object.freeze({ id: 'speedBoost', duration: 5, color: '#ff4c60', label: 'S' }),
    SLOW_MO: Object.freeze({ id: 'slowMo', duration: 6, color: '#32e8ff', label: 'W' }),
    INVINCIBLE: Object.freeze({ id: 'invincible', duration: 4, color: '#ffd455', label: 'I' }),
    WALL_WRAP: Object.freeze({ id: 'wallWrap', duration: 8, color: '#8f47b5', label: 'P' }),
    DOUBLE_POINTS: Object.freeze({ id: 'doublePoints', duration: 7, color: '#00ff41', label: 'D' }),
  }),

  START_LENGTH: 3,
  START_X: 12,
  START_Y: 12,

  PLAY_AREA_OFFSET_X: 40,
  PLAY_AREA_OFFSET_Y: 60,
});

import { SNAKE_CONFIG } from './snake-config.js';
import { CellType } from './snake-entities.js';

export function handleDirectionInput(snake, input, Action) {
  const action = input.dequeueAction();
  if (!action) return;
  const dir = snake.direction;
  if (action === Action.MOVE_UP && dir.y !== 1) snake.direction = { x: 0, y: -1 };
  else if (action === Action.MOVE_DOWN && dir.y !== -1) snake.direction = { x: 0, y: 1 };
  else if (action === Action.MOVE_LEFT && dir.x !== 1) snake.direction = { x: -1, y: 0 };
  else if (action === Action.MOVE_RIGHT && dir.x !== -1) snake.direction = { x: 1, y: 0 };
}

export function getTickInterval(snake, powerUpManager) {
  const length = snake.segments.length;
  const decrease = (length - SNAKE_CONFIG.START_LENGTH) * SNAKE_CONFIG.SPEED_DECREASE_PER_LENGTH;
  let interval = SNAKE_CONFIG.BASE_SPEED_MS - decrease;
  const effect = powerUpManager.getActiveEffect();
  if (effect?.id === 'speedBoost') interval *= 0.6;
  if (effect?.id === 'slowMo') interval *= 1.5;
  return Math.max(SNAKE_CONFIG.MIN_SPEED_MS, interval);
}

export function addFoodScore(snake, powerUpManager, streak) {
  let points = SNAKE_CONFIG.POINTS_PER_FOOD;
  const interval = getTickInterval(snake, powerUpManager);
  if (interval <= SNAKE_CONFIG.SPEED_BONUS_THRESHOLD_MS) points += SNAKE_CONFIG.SPEED_BONUS_POINTS;

  let multiplier = 1;
  for (const t of SNAKE_CONFIG.STREAK_THRESHOLDS) {
    if (streak >= t.count) multiplier = t.multiplier;
  }
  points = Math.floor(points * multiplier);

  if (powerUpManager.getActiveEffect()?.id === 'doublePoints') points *= 2;
  return points;
}

export function checkMilestone(snake, milestonesClaimed) {
  const len = snake.segments.length;
  let bonusPoints = 0;
  for (const m of SNAKE_CONFIG.LENGTH_MILESTONES) {
    if (len >= m.length && !milestonesClaimed.has(m.length)) {
      milestonesClaimed.add(m.length);
      bonusPoints += m.points;
    }
  }
  return bonusPoints;
}

export function processTick(snake, grid, foodManager, powerUpManager, audio) {
  const oldTail = snake.segments[snake.segments.length - 1];
  grid.setCell(oldTail.x, oldTail.y, CellType.EMPTY);

  const head = snake.move();
  const effect = powerUpManager.getActiveEffect();
  const wallWrap = effect?.id === 'wallWrap';

  if (head.x < 0 || head.x >= SNAKE_CONFIG.GRID_WIDTH ||
      head.y < 0 || head.y >= SNAKE_CONFIG.GRID_HEIGHT) {
    if (wallWrap) {
      head.x = (head.x + SNAKE_CONFIG.GRID_WIDTH) % SNAKE_CONFIG.GRID_WIDTH;
      head.y = (head.y + SNAKE_CONFIG.GRID_HEIGHT) % SNAKE_CONFIG.GRID_HEIGHT;
      snake.segments[0] = head;
    } else {
      return { died: true, ateFood: false, collectedPowerUp: false };
    }
  }

  const isInvincible = effect?.id === 'invincible';
  if (!isInvincible && snake.checkSelfCollision()) {
    return { died: true, ateFood: false, collectedPowerUp: false };
  }

  let ateFood = false;
  if (foodManager.checkEaten(head.x, head.y)) {
    snake.grow();
    ateFood = true;
    foodManager.respawn();
    powerUpManager.trySpawn();
    audio.playCoin();
  }

  const collectedPowerUp = !!powerUpManager.checkCollected(head.x, head.y);
  if (collectedPowerUp) audio.playScore();

  grid.clear();
  snake.applyToGrid(grid);
  if (foodManager.position) grid.setCell(foodManager.position.x, foodManager.position.y, CellType.FOOD);
  if (powerUpManager.item) grid.setCell(powerUpManager.item.x, powerUpManager.item.y, CellType.POWERUP);

  return { died: false, ateFood, collectedPowerUp };
}

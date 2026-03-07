import { BREAKOUT_CONFIG } from './breakout-config.js';
import { circleRectIntersects } from '../../engine/collision.js';

export function checkWallCollision(ball) {
  if (ball.x - ball.radius <= BREAKOUT_CONFIG.PLAY_AREA_LEFT) {
    ball.x = BREAKOUT_CONFIG.PLAY_AREA_LEFT + ball.radius;
    ball.bounceX();
  }
  if (ball.x + ball.radius >= BREAKOUT_CONFIG.PLAY_AREA_RIGHT) {
    ball.x = BREAKOUT_CONFIG.PLAY_AREA_RIGHT - ball.radius;
    ball.bounceX();
  }
  if (ball.y - ball.radius <= BREAKOUT_CONFIG.PLAY_AREA_TOP) {
    ball.y = BREAKOUT_CONFIG.PLAY_AREA_TOP + ball.radius;
    ball.bounceY();
  }
}

export function checkPaddleCollision(ball, paddle, getBallSpeed, audio) {
  const result = circleRectIntersects(ball.getCircle(), paddle.getRect());
  if (!result.hit || ball.vy < 0) return 0;

  if (paddle.sticky) {
    ball.stickyAttach(paddle);
    return 0;
  }

  const norm = paddle.getNormalizedHitPosition(ball.x);
  const minAngle = (BREAKOUT_CONFIG.BALL_MIN_ANGLE_DEG * Math.PI) / 180;
  const angle = minAngle + (1 - Math.abs(norm)) * (Math.PI / 2 - minAngle);
  const speed = getBallSpeed();

  ball.vx = Math.cos(angle) * speed * (norm >= 0 ? 1 : -1);
  ball.vy = -Math.abs(Math.sin(angle) * speed);
  ball.y = paddle.y - ball.radius;

  audio.playBounce();
  return 1;
}

export function checkBrickCollisions(ball, brickManager, powerUpManager, audio) {
  let hitOne = false;
  let combo = 0;
  let scoreGained = 0;
  let hitCount = 0;

  for (const brick of brickManager.bricks) {
    if (!brick.alive || hitOne) continue;

    const result = circleRectIntersects(
      ball.getCircle(),
      { x: brick.x, y: brick.y, w: brick.width, h: brick.height }
    );
    if (!result.hit) continue;

    hitOne = true;
    hitCount = 1;
    const destroyed = brickManager.hitBrick(brick);

    if (result.side === 'left' || result.side === 'right') ball.bounceX();
    else ball.bounceY();

    if (destroyed) {
      combo = 1;
      scoreGained = brick.points;
      powerUpManager.spawnFromBrick(brick);
      audio.playHit();
    }
  }

  return { hitCount, combo, scoreGained };
}

import { BREAKOUT_CONFIG } from './breakout-config.js';

export { BrickManager } from './breakout-bricks.js';

export class Paddle {
  constructor() {
    this.x = 0; this.y = BREAKOUT_CONFIG.PADDLE_Y;
    this.width = BREAKOUT_CONFIG.PADDLE_WIDTH; this.height = BREAKOUT_CONFIG.PADDLE_HEIGHT;
    this.sticky = false; this.laser = false;
  }
  reset() {
    this.x = (BREAKOUT_CONFIG.PLAY_AREA_LEFT + BREAKOUT_CONFIG.PLAY_AREA_RIGHT) / 2 - this.width / 2;
    this.width = BREAKOUT_CONFIG.PADDLE_WIDTH; this.sticky = false; this.laser = false;
  }
  moveLeft(dt) { this.x = Math.max(BREAKOUT_CONFIG.PLAY_AREA_LEFT, this.x - BREAKOUT_CONFIG.PADDLE_SPEED * dt); }
  moveRight(dt) { this.x = Math.min(BREAKOUT_CONFIG.PLAY_AREA_RIGHT - this.width, this.x + BREAKOUT_CONFIG.PADDLE_SPEED * dt); }
  moveTo(targetX) {
    this.x = Math.max(BREAKOUT_CONFIG.PLAY_AREA_LEFT, Math.min(BREAKOUT_CONFIG.PLAY_AREA_RIGHT - this.width, targetX - this.width / 2));
  }
  setWidth(w) {
    const center = this.x + this.width / 2; this.width = w;
    this.x = Math.max(BREAKOUT_CONFIG.PLAY_AREA_LEFT, Math.min(BREAKOUT_CONFIG.PLAY_AREA_RIGHT - w, center - w / 2));
  }
  getNormalizedHitPosition(ballX) { return ((ballX - this.x) / this.width) * 2 - 1; }
  getRect() { return { x: this.x, y: this.y, w: this.width, h: this.height }; }
}

export class Ball {
  constructor() {
    this.x = 0; this.y = 0; this.vx = 0; this.vy = 0;
    this.radius = BREAKOUT_CONFIG.BALL_RADIUS; this.active = true;
    this._stuck = false; this._stuckOffset = 0;
  }
  reset(x, y) { this.x = x; this.y = y; this.vx = 0; this.vy = 0; this.active = true; this._stuck = false; }
  update(dt) { if (this._stuck) return; this.x += this.vx * dt; this.y += this.vy * dt; }
  launch(speed) {
    const angle = -Math.PI / 2 + (Math.random() - 0.5) * 0.5;
    this.vx = Math.cos(angle) * speed; this.vy = Math.sin(angle) * speed; this._stuck = false;
  }

  bounceX() { this.vx = -this.vx; }
  bounceY() { this.vy = -this.vy; }

  setAngle(angle, speed) {
    const minAngle = (BREAKOUT_CONFIG.BALL_MIN_ANGLE_DEG * Math.PI) / 180;
    const maxAngle = Math.PI - minAngle;
    const clamped = Math.max(minAngle, Math.min(maxAngle, Math.abs(angle)));
    this.vx = Math.cos(clamped) * speed * (this.vx >= 0 ? 1 : -1);
    this.vy = -Math.abs(Math.sin(clamped) * speed);
  }

  stickyAttach(paddle) {
    this._stuck = true; this._stuckOffset = this.x - (paddle.x + paddle.width / 2); this.y = paddle.y - this.radius;
  }
  stickyUpdate(paddle) {
    if (!this._stuck) return;
    this.x = paddle.x + paddle.width / 2 + this._stuckOffset; this.y = paddle.y - this.radius;
  }
  stickyRelease(speed) { this._stuck = false; this.launch(speed); }

  isStuck() { return this._stuck; }
  getCircle() { return { x: this.x, y: this.y, r: this.radius }; }
}

export class BallManager {
  constructor() { this.balls = []; }
  reset() { this.balls.length = 0; }
  addBall(x, y) {
    const b = new Ball(); b.reset(x, y); this.balls.push(b); return b;
  }

  splitBalls() {
    const current = this.balls.filter(b => b.active);
    for (const b of current) {
      const speed = Math.sqrt(b.vx * b.vx + b.vy * b.vy);
      const angle = Math.atan2(b.vy, b.vx);
      const spread = (15 * Math.PI) / 180;

      const b1 = new Ball();
      b1.reset(b.x, b.y);
      b1.vx = Math.cos(angle + spread) * speed;
      b1.vy = Math.sin(angle + spread) * speed;
      b1.active = true;

      const b2 = new Ball();
      b2.reset(b.x, b.y);
      b2.vx = Math.cos(angle - spread) * speed;
      b2.vy = Math.sin(angle - spread) * speed;
      b2.active = true;

      this.balls.push(b1, b2);
    }
  }

  allLost() { return this.balls.every(b => !b.active); }
  getActiveBalls() { return this.balls.filter(b => b.active); }
}

export class PowerUpCapsule {
  constructor(x, y, type) {
    this.x = x; this.y = y; this.type = type;
    this.width = 24; this.height = 12; this.active = true;
  }
  update(dt) { this.y += BREAKOUT_CONFIG.POWERUP_FALL_SPEED * dt; if (this.y > 650) this.active = false; }
  getRect() { return { x: this.x, y: this.y, w: this.width, h: this.height }; }
}

export class BreakoutPowerUpManager {
  constructor() { this.capsules = []; this.activeType = null; }
  spawnFromBrick(brick) {
    if (!brick.hasPowerUp) return;
    const types = Object.values(BREAKOUT_CONFIG.POWERUP_TYPES);
    const type = types[Math.floor(Math.random() * types.length)];
    this.capsules.push(new PowerUpCapsule(brick.x + brick.width / 2 - 12, brick.y, type));
  }

  update(dt) {
    for (let i = this.capsules.length - 1; i >= 0; i--) {
      this.capsules[i].update(dt);
      if (!this.capsules[i].active) this.capsules.splice(i, 1);
    }
  }

  checkCatch(paddle) {
    const pr = paddle.getRect();
    for (let i = this.capsules.length - 1; i >= 0; i--) {
      const c = this.capsules[i];
      if (c.x + c.width > pr.x && c.x < pr.x + pr.w &&
          c.y + c.height > pr.y && c.y < pr.y + pr.h) {
        this.capsules.splice(i, 1);
        this.activeType = c.type;
        return c.type;
      }
    }
    return null;
  }

  reset() { this.capsules.length = 0; this.activeType = null; }
}

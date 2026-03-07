import { BREAKOUT_CONFIG } from './breakout-config.js';
import { BrickManager, Paddle, BallManager, BreakoutPowerUpManager } from './breakout-entities.js';
import { renderBreakoutGame, renderServingScreen, renderReadyScreen, renderGameOver } from './breakout-renderer.js';
import { checkWallCollision, checkPaddleCollision, checkBrickCollisions } from './breakout-collisions.js';
import { StateMachine } from '../../engine/state-machine.js';
import { Action } from '../../platform/input.js';

const GameState = Object.freeze({
  READY: 'ready', SERVING: 'serving', PLAYING: 'playing',
  LEVEL_COMPLETE: 'levelComplete', GAME_OVER: 'gameOver',
});

export class BreakoutGame {
  constructor() {
    this.id = 'breakout';
    this.name = 'BREAKOUT';
    this.description = 'Break all the bricks';
    this._ctx = null; this._fsm = null; this._brickManager = null;
    this._paddle = null; this._ballManager = null; this._powerUpManager = null;
    this._score = 0; this._lives = 0; this._level = 0;
    this._combo = 0; this._hitCount = 0;
    this._levelCompleteTimer = 0; this._extraLifeAwarded = false;
  }

  init(ctx) {
    this._ctx = ctx;
    this._fsm = new StateMachine({ initial: GameState.READY, states: {
      [GameState.READY]: { transitions: [GameState.SERVING] },
      [GameState.SERVING]: { transitions: [GameState.PLAYING] },
      [GameState.PLAYING]: { transitions: [GameState.SERVING, GameState.LEVEL_COMPLETE, GameState.GAME_OVER] },
      [GameState.LEVEL_COMPLETE]: { transitions: [GameState.SERVING] },
      [GameState.GAME_OVER]: { transitions: [GameState.READY] },
    }});
    this._brickManager = new BrickManager();
    this._paddle = new Paddle();
    this._ballManager = new BallManager();
    this._powerUpManager = new BreakoutPowerUpManager();
    this._resetGame();
  }

  _resetGame() {
    this._score = 0; this._lives = BREAKOUT_CONFIG.LIVES;
    this._level = 0; this._combo = 0; this._hitCount = 0;
    this._extraLifeAwarded = false; this._setupLevel();
  }

  _setupLevel() {
    this._brickManager.buildLevel(this._level);
    this._paddle.reset(); this._ballManager.reset(); this._powerUpManager.reset();
    this._combo = 0; this._hitCount = 0; this._serveBall();
  }

  _serveBall() {
    const ball = this._ballManager.addBall(
      this._paddle.x + this._paddle.width / 2, this._paddle.y - BREAKOUT_CONFIG.BALL_RADIUS);
    ball.stickyAttach(this._paddle);
  }

  update(dt, input) {
    const state = this._fsm.getState();
    if (state === GameState.READY) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT))
        this._fsm.transition(GameState.SERVING);
      return;
    }
    if (state === GameState.GAME_OVER) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        this._fsm.transition(GameState.READY); this._resetGame();
      }
      return;
    }
    if (state === GameState.LEVEL_COMPLETE) {
      this._levelCompleteTimer -= dt;
      if (this._levelCompleteTimer <= 0) {
        this._level++; this._setupLevel(); this._fsm.transition(GameState.SERVING);
      }
      return;
    }
    this._handlePaddleInput(dt, input);
    if (state === GameState.SERVING) {
      for (const ball of this._ballManager.balls) ball.stickyUpdate(this._paddle);
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        for (const ball of this._ballManager.balls)
          if (ball.isStuck()) ball.stickyRelease(this._getBallSpeed());
        this._fsm.transition(GameState.PLAYING);
      }
      return;
    }
    this._powerUpManager.update(dt);
    for (const ball of this._ballManager.getActiveBalls()) {
      if (ball.isStuck()) { ball.stickyUpdate(this._paddle); continue; }
      ball.update(dt);
      checkWallCollision(ball);
      if (checkPaddleCollision(ball, this._paddle, () => this._getBallSpeed(), this._ctx.audio))
        this._combo = 0;
      const result = checkBrickCollisions(ball, this._brickManager, this._powerUpManager, this._ctx.audio);
      if (result.hitCount) {
        this._hitCount += result.hitCount;
        if (result.combo) {
          this._combo++;
          this._score += Math.floor(result.scoreGained * (1 + this._combo * BREAKOUT_CONFIG.COMBO_INCREMENT));
          this._checkExtraLife();
        }
      }
      if (ball.y - ball.radius > 650) ball.active = false;
    }
    const caught = this._powerUpManager.checkCatch(this._paddle);
    if (caught) this._applyPowerUp(caught);
    if (this._brickManager.isCleared()) {
      this._levelCompleteTimer = 1.5;
      this._fsm.transition(GameState.LEVEL_COMPLETE);
      this._ctx.audio.playCoin(); return;
    }
    if (this._ballManager.allLost()) {
      this._lives--;
      if (this._lives <= 0) { this._ctx.audio.playGameOver(); this._fsm.transition(GameState.GAME_OVER); }
      else {
        this._powerUpManager.reset(); this._paddle.reset();
        this._ballManager.reset(); this._serveBall(); this._fsm.transition(GameState.SERVING);
      }
    }
  }

  _handlePaddleInput(dt, input) {
    if (input.isHeld(Action.MOVE_LEFT)) this._paddle.moveLeft(dt);
    if (input.isHeld(Action.MOVE_RIGHT)) this._paddle.moveRight(dt);
  }

  _getBallSpeed() {
    let speed = BREAKOUT_CONFIG.BALL_BASE_SPEED;
    for (const tier of BREAKOUT_CONFIG.BALL_SPEED_TIERS)
      if (this._hitCount >= tier.hitCount) speed = BREAKOUT_CONFIG.BALL_BASE_SPEED * tier.speedMult;
    if (this._powerUpManager.activeType?.id === 'slow') speed *= 0.66;
    return speed;
  }

  _applyPowerUp(type) {
    this._ctx.audio.playScore();
    switch (type.id) {
      case 'enlarge': this._paddle.setWidth(BREAKOUT_CONFIG.PADDLE_WIDTH_LARGE); this._paddle.sticky = false; this._paddle.laser = false; break;
      case 'multi': this._ballManager.splitBalls(); break;
      case 'laser': this._paddle.laser = true; this._paddle.sticky = false; break;
      case 'catch': this._paddle.sticky = true; this._paddle.laser = false; break;
      case 'slow': break;
      case 'extraLife': this._lives++; break;
    }
  }

  _checkExtraLife() {
    if (!this._extraLifeAwarded && this._score >= BREAKOUT_CONFIG.EXTRA_LIFE_SCORE) {
      this._extraLifeAwarded = true; this._lives++; this._ctx.audio.playCoin();
    }
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();
    const state = this._getRenderState();
    switch (this._fsm.getState()) {
      case GameState.READY: renderReadyScreen(ctx, state); break;
      case GameState.SERVING: renderServingScreen(ctx, state); break;
      case GameState.GAME_OVER: renderGameOver(ctx, state); break;
      default: renderBreakoutGame(ctx, state); break;
    }
  }

  _getRenderState() {
    return {
      brickManager: this._brickManager, paddle: this._paddle,
      ballManager: this._ballManager, powerUpManager: this._powerUpManager,
      score: this._score, lives: this._lives, level: this._level,
      combo: 1 + this._combo * BREAKOUT_CONFIG.COMBO_INCREMENT,
    };
  }

  destroy() { this._ctx = null; }
  setState(s) { if (this._fsm.canTransition(s)) this._fsm.transition(s); }
  getScore() { return this._score; }
  getState() { return this._fsm.getState(); }
}

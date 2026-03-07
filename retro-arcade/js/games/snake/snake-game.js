import { SNAKE_CONFIG } from './snake-config.js';
import { SnakeGrid, Snake, FoodManager, PowerUpManager } from './snake-entities.js';
import { renderSnakeGame, renderReadyScreen, renderGameOver } from './snake-renderer.js';
import { handleDirectionInput, getTickInterval, addFoodScore, checkMilestone, processTick } from './snake-logic.js';
import { StateMachine } from '../../engine/state-machine.js';
import { Action } from '../../platform/input.js';

const GameState = Object.freeze({
  READY: 'ready',
  PLAYING: 'playing',
  PAUSED: 'paused',
  GAME_OVER: 'gameOver',
});

export class SnakeGame {
  constructor() {
    this.id = 'snake';
    this.name = 'SNAKE';
    this.description = 'Eat, grow, survive';
    this._ctx = null;
    this._fsm = null;
    this._grid = null;
    this._snake = null;
    this._foodManager = null;
    this._powerUpManager = null;
    this._score = 0;
    this._hiScore = 0;
    this._streak = 0;
    this._tickAccum = 0;
    this._milestonesClaimed = new Set();
  }

  init(ctx) {
    this._ctx = ctx;
    this._fsm = new StateMachine({
      initial: GameState.READY,
      states: {
        [GameState.READY]: { transitions: [GameState.PLAYING] },
        [GameState.PLAYING]: { transitions: [GameState.PAUSED, GameState.GAME_OVER] },
        [GameState.PAUSED]: { transitions: [GameState.PLAYING, GameState.READY] },
        [GameState.GAME_OVER]: { transitions: [GameState.READY] },
      },
    });
    this._grid = new SnakeGrid();
    this._snake = new Snake();
    this._foodManager = new FoodManager(this._grid);
    this._powerUpManager = new PowerUpManager(this._grid);
    this._resetGame();
    const scores = ctx.storage.getHighScores('snake');
    this._hiScore = scores.length > 0 ? scores[0].score : 0;
  }

  _resetGame() {
    this._grid.clear();
    this._snake.reset(SNAKE_CONFIG.START_X, SNAKE_CONFIG.START_Y, SNAKE_CONFIG.START_LENGTH, 1, 0);
    this._snake.applyToGrid(this._grid);
    this._foodManager.spawn();
    this._powerUpManager.reset();
    this._score = 0;
    this._streak = 0;
    this._tickAccum = 0;
    this._milestonesClaimed.clear();
  }

  update(dt, input) {
    const state = this._fsm.getState();

    if (state === GameState.READY) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        this._fsm.transition(GameState.PLAYING);
      }
      return;
    }

    if (state === GameState.PAUSED) {
      if (input.consumePress(Action.PAUSE) || input.consumePress(Action.ACTION_SECONDARY)) {
        this._fsm.transition(GameState.PLAYING);
      }
      return;
    }

    if (state === GameState.GAME_OVER) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        this._fsm.transition(GameState.READY);
        this._resetGame();
      }
      return;
    }

    if (input.consumePress(Action.PAUSE) || input.consumePress(Action.ACTION_SECONDARY)) {
      this._fsm.transition(GameState.PAUSED);
      return;
    }

    handleDirectionInput(this._snake, input, Action);
    this._powerUpManager.update(dt);

    this._tickAccum += dt * 1000;
    const speed = getTickInterval(this._snake, this._powerUpManager);

    if (this._tickAccum >= speed) {
      this._tickAccum -= speed;
      const result = processTick(this._snake, this._grid, this._foodManager, this._powerUpManager, this._ctx.audio);

      if (result.died) {
        this._ctx.audio.playGameOver();
        if (this._score > this._hiScore) this._hiScore = this._score;
        this._fsm.transition(GameState.GAME_OVER);
        return;
      }

      if (result.ateFood) {
        this._streak++;
        this._score += addFoodScore(this._snake, this._powerUpManager, this._streak);
        const bonus = checkMilestone(this._snake, this._milestonesClaimed);
        if (bonus > 0) {
          this._score += bonus;
          this._ctx.audio.playScore();
        }
      }
    }
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();
    const state = this._getRenderState();
    switch (this._fsm.getState()) {
      case GameState.READY: renderReadyScreen(ctx, state); break;
      case GameState.GAME_OVER: renderGameOver(ctx, state); break;
      default: renderSnakeGame(ctx, state); break;
    }
  }

  _getRenderState() {
    return {
      snake: this._snake, foodManager: this._foodManager,
      powerUpManager: this._powerUpManager,
      score: this._score, hiScore: this._hiScore,
    };
  }

  destroy() { this._ctx = null; }
  setState(s) { if (this._fsm.canTransition(s)) this._fsm.transition(s); }
  getScore() { return this._score; }
  getState() { return this._fsm.getState(); }
}

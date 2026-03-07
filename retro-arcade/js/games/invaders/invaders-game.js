import { INVADERS_CONFIG } from './invaders-config.js';
import { Formation, PlayerShip, ShieldSystem, EnemyShootingSystem } from './invaders-entities.js';
import { renderInvadersGame, renderReadyScreen, renderGameOver } from './invaders-renderer.js';
import { checkPlayerBulletVsEnemies, checkPlayerBulletVsUFO, checkEnemyBulletsVsPlayer, getRowPoints } from './invaders-collisions.js';
import { StateMachine } from '../../engine/state-machine.js';
import { Action } from '../../platform/input.js';

const GameState = Object.freeze({
  READY: 'ready', PLAYING: 'playing', PLAYER_DEATH: 'playerDeath',
  WAVE_COMPLETE: 'waveComplete', GAME_OVER: 'gameOver',
});

export class InvadersGame {
  constructor() {
    this.id = 'invaders';
    this.name = 'SPACE INVADERS';
    this.description = 'Defend Earth from alien invasion';
    this._ctx = null; this._fsm = null; this._formation = null;
    this._player = null; this._shieldSystem = null; this._enemyShooting = null;
    this._score = 0; this._hiScore = 0; this._lives = 0; this._wave = 0;
    this._ufo = { x: 0, y: INVADERS_CONFIG.UFO_Y, active: false };
    this._ufoTimer = 0; this._deathTimer = 0; this._waveTimer = 0;
  }

  init(ctx) {
    this._ctx = ctx;
    this._fsm = new StateMachine({ initial: GameState.READY, states: {
      [GameState.READY]: { transitions: [GameState.PLAYING] },
      [GameState.PLAYING]: { transitions: [GameState.PLAYER_DEATH, GameState.WAVE_COMPLETE, GameState.GAME_OVER] },
      [GameState.PLAYER_DEATH]: { transitions: [GameState.PLAYING, GameState.GAME_OVER] },
      [GameState.WAVE_COMPLETE]: { transitions: [GameState.PLAYING] },
      [GameState.GAME_OVER]: { transitions: [GameState.READY] },
    }});
    this._formation = new Formation();
    this._player = new PlayerShip();
    this._shieldSystem = new ShieldSystem();
    this._enemyShooting = new EnemyShootingSystem();
    this._resetGame();
    const scores = ctx.storage.getHighScores('invaders');
    this._hiScore = scores.length > 0 ? scores[0].score : 0;
  }

  _resetGame() {
    this._score = 0; this._lives = INVADERS_CONFIG.LIVES; this._wave = 0;
    this._ufo.active = false; this._ufoTimer = INVADERS_CONFIG.UFO_INTERVAL_S;
    this._setupWave();
  }

  _setupWave() {
    this._formation.reset(this._wave); this._player.reset();
    this._shieldSystem.reset(); this._enemyShooting.reset();
    this._ufo.active = false; this._ufoTimer = INVADERS_CONFIG.UFO_INTERVAL_S;
  }

  update(dt, input) {
    const state = this._fsm.getState();
    if (state === GameState.READY) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT))
        this._fsm.transition(GameState.PLAYING);
      return;
    }
    if (state === GameState.GAME_OVER) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        this._fsm.transition(GameState.READY); this._resetGame();
      }
      return;
    }
    if (state === GameState.PLAYER_DEATH) {
      this._deathTimer -= dt;
      if (this._deathTimer <= 0) {
        if (this._lives <= 0) this._fsm.transition(GameState.GAME_OVER);
        else { this._player.respawn(); this._fsm.transition(GameState.PLAYING); }
      }
      return;
    }
    if (state === GameState.WAVE_COMPLETE) {
      this._waveTimer -= dt;
      if (this._waveTimer <= 0) {
        this._wave++; this._setupWave(); this._fsm.transition(GameState.PLAYING);
      }
      return;
    }
    this._handlePlayerInput(dt, input);
    this._player.updateBullet(dt);
    this._player.updateInvincibility(dt);
    const stepped = this._formation.update(dt);
    if (stepped) this._shieldSystem.checkFormationErosion(this._formation.getLowestAliveY());
    this._enemyShooting.update(dt, this._formation, this._player.x + this._player.width / 2);
    this._updateUFO(dt);
    this._runCollisions();
    if (this._formation.isFormationAtPlayer()) {
      this._ctx.audio.playGameOver(); this._lives = 0;
      if (this._score > this._hiScore) this._hiScore = this._score;
      this._fsm.transition(GameState.GAME_OVER); return;
    }
    if (this._formation.isCleared()) {
      this._waveTimer = 2; this._fsm.transition(GameState.WAVE_COMPLETE); this._ctx.audio.playCoin();
    }
  }

  _handlePlayerInput(dt, input) {
    if (input.isHeld(Action.MOVE_LEFT)) this._player.moveLeft(dt);
    if (input.isHeld(Action.MOVE_RIGHT)) this._player.moveRight(dt);
    if (input.consumePress(Action.ACTION_PRIMARY))
      if (this._player.fire()) this._ctx.audio.playLaser();
  }

  _updateUFO(dt) {
    if (this._ufo.active) {
      this._ufo.x += INVADERS_CONFIG.UFO_SPEED * dt;
      if (this._ufo.x > INVADERS_CONFIG.PLAY_AREA_RIGHT + 40) this._ufo.active = false;
    } else {
      this._ufoTimer -= dt;
      if (this._ufoTimer <= 0) {
        this._ufo.x = INVADERS_CONFIG.PLAY_AREA_LEFT - 40;
        this._ufo.active = true; this._ufoTimer = INVADERS_CONFIG.UFO_INTERVAL_S;
      }
    }
  }

  _runCollisions() {
    const bullet = this._player.bullet;
    const enemyHit = checkPlayerBulletVsEnemies(bullet, this._formation);
    if (enemyHit) {
      this._formation.killEnemy(enemyHit.row, enemyHit.col);
      bullet.active = false; this._score += getRowPoints(enemyHit.row);
      this._ctx.audio.playHit(); return;
    }
    if (checkPlayerBulletVsUFO(bullet, this._ufo)) {
      bullet.active = false; this._ufo.active = false;
      const idx = this._player.shotsFired % INVADERS_CONFIG.UFO_SCORE_TABLE.length;
      this._score += INVADERS_CONFIG.UFO_SCORE_TABLE[idx]; this._ctx.audio.playExplosion();
    }
    if (bullet.active && this._shieldSystem.checkBulletHit(bullet, true)) bullet.active = false;
    const playerHitIdx = checkEnemyBulletsVsPlayer(this._enemyShooting.bullets, this._player);
    if (playerHitIdx >= 0) {
      this._enemyShooting.bullets.splice(playerHitIdx, 1);
      this._player.kill(); this._lives--; this._deathTimer = 2;
      this._ctx.audio.playExplosion();
      if (this._score > this._hiScore) this._hiScore = this._score;
      this._fsm.transition(GameState.PLAYER_DEATH); return;
    }
    for (let i = this._enemyShooting.bullets.length - 1; i >= 0; i--)
      if (this._shieldSystem.checkBulletHit(this._enemyShooting.bullets[i], false))
        this._enemyShooting.bullets.splice(i, 1);
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();
    const state = this._getRenderState();
    switch (this._fsm.getState()) {
      case GameState.READY: renderReadyScreen(ctx, state); break;
      case GameState.GAME_OVER: renderGameOver(ctx, state); break;
      default: renderInvadersGame(ctx, state); break;
    }
  }

  _getRenderState() {
    return {
      formation: this._formation, player: this._player,
      shieldSystem: this._shieldSystem, enemyShooting: this._enemyShooting,
      ufo: this._ufo, score: this._score, hiScore: this._hiScore,
      lives: this._lives, wave: this._wave,
    };
  }

  destroy() { this._ctx = null; }
  setState(s) { if (this._fsm.canTransition(s)) this._fsm.transition(s); }
  getScore() { return this._score; }
  getState() { return this._fsm.getState(); }
}

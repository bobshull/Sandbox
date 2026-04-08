import { viewport } from '../platform/viewport.js';
import { input } from '../platform/input.js';
import { audio } from '../platform/audio.js';
import { storage } from '../platform/storage.js';
import { gameLoop } from '../engine/loop.js';
import { ParticleSystem } from '../engine/particles.js';
import { StateMachine } from '../engine/state-machine.js';
import { renderer } from '../render/renderer.js';
import { effects } from '../render/effects.js';
import { crt } from '../render/crt.js';
import { transitions, TransitionType } from '../render/transitions.js';
import { gameManifest } from '../games/manifest.js';
import { createGameContext } from '../games/game-interface.js';
import { touchControls } from '../platform/touch-controls.js';

const AppScreen = Object.freeze({
  BOOT: 'boot',
  MENU: 'menu',
  GAME: 'game',
  HIGHSCORES: 'highscores',
  SETTINGS: 'settings',
});

class App {
  constructor() {
    this._fsm = new StateMachine({
      initial: AppScreen.BOOT,
      states: {
        [AppScreen.BOOT]: { transitions: [AppScreen.MENU] },
        [AppScreen.MENU]: { transitions: [AppScreen.GAME, AppScreen.HIGHSCORES, AppScreen.SETTINGS] },
        [AppScreen.GAME]: { transitions: [AppScreen.MENU, AppScreen.HIGHSCORES] },
        [AppScreen.HIGHSCORES]: { transitions: [AppScreen.MENU] },
        [AppScreen.SETTINGS]: { transitions: [AppScreen.MENU] },
      },
    });
    this._screens = {};
    this._activeScreen = null;
    this._particles = new ParticleSystem();
    this._currentGame = null;
    this._gameScreen = null;
  }

  init() {
    const canvas = document.getElementById('game-canvas');

    storage.init();
    viewport.init(canvas);
    input.init(canvas);
    audio.init();
    renderer.init();
    crt.init();
    touchControls.init(canvas, input);

    const settings = storage.getSettings();
    audio.setMasterVolume(settings.masterVolume);
    audio.setSfxVolume(settings.sfxVolume);
    audio.setMusicVolume(settings.musicVolume);

    gameLoop.setCallbacks(
      (dt) => this._update(dt),
      (alpha) => this._render(alpha)
    );
    gameLoop.setOnPerfWarning((avgMs) => {
      console.warn(`[Perf] Average frame time: ${avgMs.toFixed(1)}ms — disabling CRT`);
      crt.setEnabled(false);
    });

    this._gameScreen = this._createGameScreen();
    this.registerScreen(AppScreen.GAME, this._gameScreen);

    const bootScreen = this._screens[AppScreen.BOOT];
    if (bootScreen && !bootScreen.shouldSkip()) {
      this.setActiveScreen(AppScreen.BOOT, {
        onComplete: () => this.switchScreen(AppScreen.MENU),
      });
    } else {
      this._fsm.transition(AppScreen.MENU);
      this._activeScreen = this._screens[AppScreen.MENU];
      if (this._activeScreen?.activate) this._activeScreen.activate();
    }

    gameLoop.start();
  }

  _createGameScreen() {
    const self = this;
    return {
      activate(data) {
        if (!data || !data.gameId) return;
        const game = gameManifest.getGame(data.gameId);
        if (!game) return;
        self._currentGame = game;
        const ctx = createGameContext({
          viewport, input, audio, storage,
          renderer, particles: self._particles, effects,
        });
        game.init(ctx);
      },
      deactivate() {
        if (self._currentGame) {
          self._currentGame.destroy();
          self._currentGame = null;
        }
      },
      update(dt, inp) {
        if (self._currentGame) {
          self._currentGame.update(dt, inp);
          if (self._currentGame.getState() === 'gameOver') {
            // handled by game internally; user presses start to reset or we could navigate
          }
        }
      },
      render(r) {
        if (self._currentGame) self._currentGame.render(r);
      },
    };
  }

  registerScreen(id, screen) {
    this._screens[id] = screen;
  }

  switchScreen(screenId, data, transitionType = TransitionType.FADE, duration = 500) {
    if (!this._fsm.canTransition(screenId)) return;

    transitions.startTransition(
      transitionType,
      duration,
      () => {
        if (this._activeScreen && this._activeScreen.deactivate) {
          this._activeScreen.deactivate();
        }
        this._fsm.transition(screenId);
        this._activeScreen = this._screens[screenId] || null;
        if (this._activeScreen && this._activeScreen.activate) {
          this._activeScreen.activate(data);
        }
      },
      null
    );
  }

  setActiveScreen(screenId, data) {
    if (this._activeScreen && this._activeScreen.deactivate) {
      this._activeScreen.deactivate();
    }
    if (this._fsm.canTransition(screenId)) {
      this._fsm.transition(screenId);
    }
    this._activeScreen = this._screens[screenId] || null;
    if (this._activeScreen && this._activeScreen.activate) {
      this._activeScreen.activate(data);
    }
  }

  getCurrentScreen() {
    return this._fsm.getState();
  }

  getParticles() {
    return this._particles;
  }

  _update(dt) {
    transitions.update(dt);
    effects.update(dt);
    this._particles.update(dt);

    if (!transitions.isActive() && this._activeScreen && this._activeScreen.update) {
      this._activeScreen.update(dt, input);
    }

    input.update();
  }

  _render(_alpha) {
    renderer.beginFrame();

    if (this._activeScreen && this._activeScreen.render) {
      this._activeScreen.render(renderer);
    }

    const ctx = renderer.getOffscreenContext();
    const { width, height } = viewport.getLogicalSize();

    this._particles.draw(ctx);
    effects.draw(ctx, width, height);
    transitions.draw(ctx, width, height);
    touchControls.draw(ctx);

    renderer.endFrame();
  }
}

export const app = new App();
export { AppScreen };

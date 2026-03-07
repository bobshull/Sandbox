import { Action } from '../platform/input.js';
import { audio } from '../platform/audio.js';
import { app, AppScreen } from './app.js';
import { gameManifest } from '../games/manifest.js';
import { drawGlowText, drawText } from '../render/text.js';
import { SPRITES, drawSprite } from '../render/sprites.js';
import { effects } from '../render/effects.js';
import { LOGICAL_WIDTH, LOGICAL_HEIGHT } from '../platform/viewport.js';

const ATTRACT_TIMEOUT_S = 30;
const STAR_COUNT = 60;

class MenuScreen {
  constructor() {
    this._selectedIndex = 0;
    this._items = [];
    this._idleTimer = 0;
    this._attractActive = false;
    this._stars = [];
    this._initStars();
  }

  activate() {
    this._selectedIndex = 0;
    this._idleTimer = 0;
    this._attractActive = false;
    this._rebuildItems();
  }

  deactivate() {
    this._attractActive = false;
  }

  _rebuildItems() {
    const games = gameManifest.getAllGames();
    this._items = [
      ...games.map(g => ({ type: 'game', id: g.id, label: g.name, desc: g.description })),
      { type: 'nav', id: 'highscores', label: 'HIGH SCORES' },
      { type: 'nav', id: 'settings', label: 'SETTINGS' },
    ];
  }

  update(dt, input) {
    this._updateStars(dt);

    if (this._attractActive) {
      if (this._anyInput(input)) {
        this._attractActive = false;
        this._idleTimer = 0;
      }
      return;
    }

    if (this._anyInput(input)) {
      this._idleTimer = 0;
    } else {
      this._idleTimer += dt;
      if (this._idleTimer >= ATTRACT_TIMEOUT_S) {
        this._attractActive = true;
      }
    }

    if (input.consumePress(Action.MOVE_UP)) {
      this._selectedIndex = (this._selectedIndex - 1 + this._items.length) % this._items.length;
      audio.playMenuMove();
    }
    if (input.consumePress(Action.MOVE_DOWN)) {
      this._selectedIndex = (this._selectedIndex + 1) % this._items.length;
      audio.playMenuMove();
    }
    if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
      this._select();
    }
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();

    this._drawStars(ctx);

    drawGlowText(ctx, 'RETRO', LOGICAL_WIDTH / 2, 60, {
      font: 'title', align: 'center', color: '#ff4c60', glowColor: '#ff4c60',
    });
    drawGlowText(ctx, 'ARCADE', LOGICAL_WIDTH / 2, 90, {
      font: 'title', align: 'center', color: '#32e8ff', glowColor: '#32e8ff',
    });

    const startY = 180;
    const itemHeight = 80;

    for (let i = 0; i < this._items.length; i++) {
      const item = this._items[i];
      const y = startY + i * itemHeight;
      const selected = i === this._selectedIndex;

      if (selected) {
        renderer.fillRect(20, y - 5, LOGICAL_WIDTH - 40, itemHeight - 10, 'rgba(50,232,255,0.08)');
        renderer.strokeRect(20, y - 5, LOGICAL_WIDTH - 40, itemHeight - 10, '#32e8ff', 1);
        drawSprite(ctx, SPRITES.ARROW_RIGHT, 30, y + 18, 2, '#32e8ff');
      }

      const labelX = selected ? 60 : 40;
      const labelColor = selected ? '#f1f2f6' : '#6a6d7a';

      drawText(ctx, item.label, labelX, y + 10, {
        font: item.type === 'game' ? 'score' : 'ui',
        color: labelColor,
      });

      if (item.desc) {
        drawText(ctx, item.desc, labelX, y + 35, {
          font: 'body', color: '#6a6d7a', scale: 0.8,
        });
      }
    }

    const blinkAlpha = effects.getBlinkAlpha(600);
    drawText(ctx, 'PRESS START', LOGICAL_WIDTH / 2, LOGICAL_HEIGHT - 60, {
      font: 'score', align: 'center', color: '#ffd455', alpha: blinkAlpha,
    });

    if (this._attractActive) {
      drawText(ctx, 'ATTRACT MODE', LOGICAL_WIDTH / 2, LOGICAL_HEIGHT - 30, {
        font: 'body', align: 'center', color: '#6a6d7a',
      });
    }
  }

  _select() {
    const item = this._items[this._selectedIndex];
    audio.playMenuSelect();
    if (item.type === 'game') {
      app.switchScreen(AppScreen.GAME, { gameId: item.id });
    } else if (item.id === 'highscores') {
      app.switchScreen(AppScreen.HIGHSCORES);
    } else if (item.id === 'settings') {
      app.switchScreen(AppScreen.SETTINGS);
    }
  }

  _anyInput(input) {
    return input.isPressed(Action.MOVE_UP) ||
      input.isPressed(Action.MOVE_DOWN) ||
      input.isPressed(Action.ACTION_PRIMARY) ||
      input.isPressed(Action.MENU_SELECT) ||
      input.isPressed(Action.PAUSE);
  }

  _initStars() {
    this._stars = [];
    for (let i = 0; i < STAR_COUNT; i++) {
      this._stars.push({
        x: Math.random() * LOGICAL_WIDTH,
        y: Math.random() * LOGICAL_HEIGHT,
        speed: 10 + Math.random() * 30,
        size: 1 + Math.random(),
        alpha: 0.3 + Math.random() * 0.7,
      });
    }
  }

  _updateStars(dt) {
    for (const s of this._stars) {
      s.y += s.speed * dt;
      if (s.y > LOGICAL_HEIGHT) {
        s.y = 0;
        s.x = Math.random() * LOGICAL_WIDTH;
      }
    }
  }

  _drawStars(ctx) {
    for (const s of this._stars) {
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = s.alpha;
      ctx.fillStyle = '#f1f2f6';
      ctx.fillRect(s.x, s.y, s.size, s.size);
      ctx.globalAlpha = saved;
    }
  }
}

export const menuScreen = new MenuScreen();

import { Action } from '../platform/input.js';
import { audio } from '../platform/audio.js';
import { storage } from '../platform/storage.js';
import { app, AppScreen } from './app.js';
import { drawText, drawGlowText } from '../render/text.js';
import { SPRITES, drawSprite } from '../render/sprites.js';
import { effects } from '../render/effects.js';
import { LOGICAL_WIDTH } from '../platform/viewport.js';

const GAME_TABS = ['snake', 'breakout', 'invaders'];
const TAB_LABELS = { snake: 'SNAKE', breakout: 'BREAKOUT', invaders: 'INVADERS' };
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const ENTRY_TIMEOUT_S = 30;

class HighScoresScreen {
  constructor() {
    this._tabIndex = 0; this._entryMode = false; this._entryGameId = null;
    this._entryScore = 0; this._initials = ['A', 'A', 'A']; this._cursorPos = 0;
    this._entryTimer = 0; this._revealCount = 0; this._revealTimer = 0;
  }
  activate(data) {
    this._revealCount = 0; this._revealTimer = 0;
    if (data && data.newScore !== undefined && data.gameId) {
      this._entryMode = true; this._entryGameId = data.gameId;
      this._entryScore = data.newScore; this._initials = ['A', 'A', 'A'];
      this._cursorPos = 0; this._entryTimer = 0;
      this._tabIndex = GAME_TABS.indexOf(data.gameId);
    } else { this._entryMode = false; }
  }
  deactivate() {}

  update(dt, input) {
    this._revealTimer += dt;
    if (this._revealTimer > 0.08 && this._revealCount < 10) {
      this._revealCount++;
      this._revealTimer = 0;
    }

    if (this._entryMode) {
      this._updateEntry(dt, input);
    } else {
      this._updateView(input);
    }
  }

  _updateView(input) {
    if (input.consumePress(Action.MOVE_LEFT)) {
      this._tabIndex = (this._tabIndex - 1 + GAME_TABS.length) % GAME_TABS.length;
      this._revealCount = 0;
      audio.playMenuMove();
    }
    if (input.consumePress(Action.MOVE_RIGHT)) {
      this._tabIndex = (this._tabIndex + 1) % GAME_TABS.length;
      this._revealCount = 0;
      audio.playMenuMove();
    }
    if (input.consumePress(Action.ACTION_SECONDARY) || input.consumePress(Action.PAUSE)) {
      app.switchScreen(AppScreen.MENU);
    }
  }

  _updateEntry(dt, input) {
    this._entryTimer += dt;
    if (this._entryTimer >= ENTRY_TIMEOUT_S) {
      this._finishEntry();
      return;
    }

    if (input.consumePress(Action.MOVE_UP)) {
      const idx = ALPHABET.indexOf(this._initials[this._cursorPos]);
      this._initials[this._cursorPos] = ALPHABET[(idx - 1 + 26) % 26];
      audio.playMenuMove();
    }
    if (input.consumePress(Action.MOVE_DOWN)) {
      const idx = ALPHABET.indexOf(this._initials[this._cursorPos]);
      this._initials[this._cursorPos] = ALPHABET[(idx + 1) % 26];
      audio.playMenuMove();
    }
    if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
      this._cursorPos++;
      audio.playMenuSelect();
      if (this._cursorPos >= 3) {
        this._finishEntry();
      }
    }
  }

  _finishEntry() {
    const name = this._initials.join('');
    storage.addHighScore(this._entryGameId, name, this._entryScore);
    this._entryMode = false;
    this._revealCount = 0;
    audio.playCoin();
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();
    const gameId = GAME_TABS[this._tabIndex];

    drawGlowText(ctx, 'HIGH SCORES', LOGICAL_WIDTH / 2, 30, {
      font: 'title', align: 'center', color: '#ffd455', glowColor: '#ffd455',
    });

    this._drawTabs(ctx);

    if (this._entryMode) {
      this._drawEntryHeader(ctx);
    }

    this._drawScoreTable(ctx, gameId);

    drawText(ctx, 'ESC / BACK', LOGICAL_WIDTH / 2, 600, {
      font: 'body', align: 'center', color: '#6a6d7a',
    });
  }

  _drawTabs(ctx) {
    const tabWidth = 130, startX = (LOGICAL_WIDTH - tabWidth * GAME_TABS.length) / 2, y = 70;
    for (let i = 0; i < GAME_TABS.length; i++) {
      const selected = i === this._tabIndex;
      const x = startX + i * tabWidth + tabWidth / 2;
      drawText(ctx, TAB_LABELS[GAME_TABS[i]], x, y, {
        font: 'score',
        align: 'center',
        color: selected ? '#32e8ff' : '#6a6d7a',
      });
      if (selected) {
        ctx.fillStyle = '#32e8ff';
        ctx.fillRect(x - tabWidth / 2 + 10, y + 18, tabWidth - 20, 2);
      }
    }
  }

  _drawEntryHeader(ctx) {
    const blink = effects.getBlinkAlpha(400);
    drawText(ctx, 'NEW HIGH SCORE!', LOGICAL_WIDTH / 2, 100, {
      font: 'score', align: 'center', color: '#ff4c60', alpha: blink,
    });
    drawText(ctx, String(this._entryScore), LOGICAL_WIDTH / 2, 120, {
      font: 'title', align: 'center', color: '#ffd455',
    });

    const initX = LOGICAL_WIDTH / 2 - 30;
    for (let i = 0; i < 3; i++) {
      const isCurrent = i === this._cursorPos;
      const alpha = isCurrent ? effects.getBlinkAlpha(300) : 1;
      drawText(ctx, this._initials[i], initX + i * 24, 155, {
        font: 'title', color: '#f1f2f6', alpha,
      });
    }
  }

  _drawScoreTable(ctx, gameId) {
    const scores = storage.getHighScores(gameId);
    const startY = this._entryMode ? 200 : 110, rowHeight = 40;
    for (let i = 0; i < 10; i++) {
      const y = startY + i * rowHeight;
      if (i >= this._revealCount) break;
      const rank = i + 1, entry = scores[i];
      if (rank === 1 && entry) {
        drawSprite(ctx, SPRITES.CROWN, 30, y + 2, 2, '#ffd455');
      }

      const rankColor = rank === 1 ? '#ffd455' : '#6a6d7a';
      drawText(ctx, String(rank).padStart(2, ' ') + '.', 60, y, {
        font: 'score', color: rankColor,
      });

      if (entry) {
        drawText(ctx, entry.name, 120, y, { font: 'score', color: '#f1f2f6' });
        drawText(ctx, String(entry.score).padStart(8, '0'), 340, y, {
          font: 'score', color: '#32e8ff', align: 'right',
        });
        drawText(ctx, entry.date, 440, y, {
          font: 'body', color: '#6a6d7a', align: 'right', scale: 0.7,
        });
      } else {
        drawText(ctx, '---', 120, y, { font: 'score', color: '#3a3d4a' });
        drawText(ctx, '00000000', 340, y, {
          font: 'score', color: '#3a3d4a', align: 'right',
        });
      }
    }

    if (scores.length === 0 && this._revealCount >= 1) {
      drawText(ctx, 'NO HEROES YET', LOGICAL_WIDTH / 2, startY + 150, {
        font: 'body', align: 'center', color: '#6a6d7a',
      });
    }
  }
}

export const highScoresScreen = new HighScoresScreen();

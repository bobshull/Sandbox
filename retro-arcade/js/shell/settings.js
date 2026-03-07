import { Action } from '../platform/input.js';
import { audio } from '../platform/audio.js';
import { storage } from '../platform/storage.js';
import { app, AppScreen } from './app.js';
import { crt } from '../render/crt.js';
import { drawText } from '../render/text.js';
import { effects } from '../render/effects.js';
import { LOGICAL_WIDTH } from '../platform/viewport.js';
import { VERSION } from '../version.js';

const VOL_STEP = 0.1;

const ROWS = Object.freeze([
  { id: 'masterVolume', label: 'MASTER VOLUME', type: 'volume' },
  { id: 'sfxVolume', label: 'SFX VOLUME', type: 'volume' },
  { id: 'musicVolume', label: 'MUSIC VOLUME', type: 'volume' },
  { id: 'crtEffect', label: 'CRT EFFECT', type: 'toggle' },
  { id: 'scanlines', label: 'SCANLINES', type: 'toggle' },
  { id: 'screenShake', label: 'SCREEN SHAKE', type: 'toggle' },
  { id: 'touchLayout', label: 'TOUCH LAYOUT', type: 'option', options: ['swipe', 'dpad'] },
  { id: 'reset', label: 'RESET HIGH SCORES', type: 'action' },
  { id: 'back', label: 'BACK', type: 'nav' },
]);

class SettingsScreen {
  constructor() {
    this._selectedIndex = 0;
    this._confirmingReset = false;
  }

  activate() {
    this._selectedIndex = 0;
    this._confirmingReset = false;
  }

  deactivate() {}

  update(dt, input) {
    if (this._confirmingReset) {
      if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
        storage.resetAll();
        this._confirmingReset = false;
        audio.playCoin();
      }
      if (input.consumePress(Action.ACTION_SECONDARY) || input.consumePress(Action.PAUSE)) {
        this._confirmingReset = false;
      }
      return;
    }

    if (input.consumePress(Action.MOVE_UP)) {
      this._selectedIndex = (this._selectedIndex - 1 + ROWS.length) % ROWS.length;
      audio.playMenuMove();
    }
    if (input.consumePress(Action.MOVE_DOWN)) {
      this._selectedIndex = (this._selectedIndex + 1) % ROWS.length;
      audio.playMenuMove();
    }

    const row = ROWS[this._selectedIndex];

    if (input.consumePress(Action.MOVE_LEFT)) this._adjust(row, -1);
    if (input.consumePress(Action.MOVE_RIGHT)) this._adjust(row, 1);

    if (input.consumePress(Action.ACTION_PRIMARY) || input.consumePress(Action.MENU_SELECT)) {
      if (row.type === 'toggle') {
        this._adjust(row, 1);
      } else if (row.type === 'option') {
        this._adjust(row, 1);
      } else if (row.id === 'reset') {
        this._confirmingReset = true;
      } else if (row.id === 'back') {
        app.switchScreen(AppScreen.MENU);
      }
    }

    if (input.consumePress(Action.ACTION_SECONDARY) || input.consumePress(Action.PAUSE)) {
      app.switchScreen(AppScreen.MENU);
    }
  }

  _adjust(row, dir) {
    if (row.type === 'volume') {
      let val = storage.getSetting(row.id);
      val = Math.round((val + dir * VOL_STEP) * 10) / 10;
      val = Math.max(0, Math.min(1, val));
      storage.setSetting(row.id, val);
      this._applyVolume(row.id, val);
      audio.playBlip(660, 0.05);
    } else if (row.type === 'toggle') {
      const val = !storage.getSetting(row.id);
      storage.setSetting(row.id, val);
      if (row.id === 'crtEffect') crt.setEnabled(val);
      audio.playMenuSelect();
    } else if (row.type === 'option') {
      const opts = row.options;
      const cur = storage.getSetting(row.id);
      const idx = opts.indexOf(cur);
      storage.setSetting(row.id, opts[(idx + 1) % opts.length]);
      audio.playMenuSelect();
    }
  }

  _applyVolume(id, val) {
    if (id === 'masterVolume') audio.setMasterVolume(val);
    else if (id === 'sfxVolume') audio.setSfxVolume(val);
    else if (id === 'musicVolume') audio.setMusicVolume(val);
  }

  render(renderer) {
    const ctx = renderer.getOffscreenContext();

    drawText(ctx, 'SETTINGS', LOGICAL_WIDTH / 2, 30, {
      font: 'title', align: 'center', color: '#ffd455',
    });

    const startY = 90;
    const rowH = 55;

    for (let i = 0; i < ROWS.length; i++) {
      const row = ROWS[i];
      const y = startY + i * rowH;
      const selected = i === this._selectedIndex;
      const color = selected ? '#f1f2f6' : '#6a6d7a';

      if (selected) {
        renderer.fillRect(15, y - 5, LOGICAL_WIDTH - 30, rowH - 10, 'rgba(50,232,255,0.06)');
      }

      drawText(ctx, row.label, 30, y + 5, { font: 'score', color });

      if (row.type === 'volume') {
        this._drawVolumeBar(ctx, 30, y + 25, storage.getSetting(row.id), selected);
      } else if (row.type === 'toggle') {
        const val = storage.getSetting(row.id);
        this._drawToggle(ctx, 350, y + 5, val, selected);
      } else if (row.type === 'option') {
        const val = storage.getSetting(row.id);
        drawText(ctx, val.toUpperCase(), 350, y + 5, {
          font: 'score', color: selected ? '#32e8ff' : '#6a6d7a',
        });
      } else if (row.id === 'reset' && this._confirmingReset) {
        const blink = effects.getBlinkAlpha(400);
        drawText(ctx, 'ARE YOU SURE? [START]', 30, y + 25, {
          font: 'body', color: '#ff4c60', alpha: blink,
        });
      }
    }
    drawText(ctx, VERSION, LOGICAL_WIDTH / 2, 610, { font: 'body', align: 'center', color: '#3a3d4a', scale: 0.7 });
  }

  _drawVolumeBar(ctx, x, y, value, selected) {
    const blocks = 10;
    const filled = Math.round(value * blocks);
    const blockW = 28;
    const blockH = 12;
    const gap = 4;

    for (let i = 0; i < blocks; i++) {
      const bx = x + i * (blockW + gap);
      if (i < filled) {
        ctx.fillStyle = selected ? '#32e8ff' : '#6a6d7a';
        ctx.fillRect(bx, y, blockW, blockH);
      } else {
        ctx.strokeStyle = '#3a3d4a';
        ctx.lineWidth = 1;
        ctx.strokeRect(bx, y, blockW, blockH);
      }
    }

    const pct = Math.round(value * 100) + '%';
    drawText(ctx, pct, x + blocks * (blockW + gap) + 10, y - 2, {
      font: 'body', color: selected ? '#f1f2f6' : '#6a6d7a',
    });
  }

  _drawToggle(ctx, x, y, value, selected) {
    const onColor = value ? (selected ? '#00ff41' : '#6a6d7a') : '#3a3d4a';
    const offColor = !value ? (selected ? '#ff4c60' : '#6a6d7a') : '#3a3d4a';
    drawText(ctx, 'ON', x, y, { font: 'score', color: onColor });
    drawText(ctx, '/', x + 35, y, { font: 'score', color: '#3a3d4a' });
    drawText(ctx, 'OFF', x + 50, y, { font: 'score', color: offColor });
  }
}

export const settingsScreen = new SettingsScreen();

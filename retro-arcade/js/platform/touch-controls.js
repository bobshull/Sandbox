import { Action } from './input.js';

const DPAD_X = 85;
const DPAD_Y = 555;
const DPAD_R = 50;
const DEAD_ZONE = 14;

const BTN_A = { x: 400, y: 565, r: 30, action: Action.ACTION_PRIMARY, label: 'A' };
const BTN_B = { x: 400, y: 490, r: 24, action: Action.PAUSE, label: 'B' };
const BUTTONS = [BTN_A, BTN_B];

const DIR_MAP = [
  { min: -0.4, max: 0.4, action: Action.MOVE_RIGHT },
  { min: 0.4, max: 1.1, action: Action.MOVE_DOWN },
  { min: -1.1, max: -0.4, action: Action.MOVE_UP },
  { min: 1.1, max: 2.0, action: Action.MOVE_LEFT },
  { min: -2.0, max: -1.1, action: Action.MOVE_LEFT },
];

class TouchControls {
  constructor() {
    this._input = null;
    this._canvas = null;
    this._visible = false;
    this._touches = new Map();
    this._dpadAction = null;
    this._btnStates = new Map();
  }

  init(canvas, inputManager) {
    this._canvas = canvas;
    this._input = inputManager;
    if (!('ontouchstart' in window) && navigator.maxTouchPoints < 1) return;

    this._visible = true;
    inputManager.setTouchEnabled(false);

    const opts = { passive: false };
    canvas.addEventListener('touchstart', (e) => this._onStart(e), opts);
    canvas.addEventListener('touchmove', (e) => this._onMove(e), opts);
    canvas.addEventListener('touchend', (e) => this._onEnd(e), opts);
    canvas.addEventListener('touchcancel', (e) => this._onEnd(e), opts);
  }

  isVisible() { return this._visible; }

  _toLogi(clientX, clientY) {
    const r = this._canvas.getBoundingClientRect();
    return { x: (clientX - r.left) / r.width * 480, y: (clientY - r.top) / r.height * 640 };
  }

  _classifyTouch(lx, ly) {
    for (const btn of BUTTONS) {
      const dx = lx - btn.x, dy = ly - btn.y;
      if (dx * dx + dy * dy <= (btn.r + 10) * (btn.r + 10)) return { type: 'btn', btn };
    }
    const dx = lx - DPAD_X, dy = ly - DPAD_Y;
    if (dx * dx + dy * dy <= (DPAD_R + 20) * (DPAD_R + 20)) return { type: 'dpad', dx, dy };
    return null;
  }

  _dpadDir(dx, dy) {
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < DEAD_ZONE) return null;
    const angle = Math.atan2(dy, dx);
    for (const d of DIR_MAP) {
      if (angle >= d.min * Math.PI && angle < d.max * Math.PI) return d.action;
    }
    return null;
  }

  _onStart(e) {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const lp = this._toLogi(t.clientX, t.clientY);
      const zone = this._classifyTouch(lp.x, lp.y);
      if (!zone) continue;

      this._touches.set(t.identifier, { zone, lx: lp.x, ly: lp.y });

      if (zone.type === 'btn') {
        this._input._addAction(zone.btn.action);
        this._btnStates.set(zone.btn.label, true);
      } else if (zone.type === 'dpad') {
        const dir = this._dpadDir(zone.dx, zone.dy);
        if (dir) {
          this._setDpad(dir);
          this._input.queueAction(dir);
        }
      }
    }
  }

  _onMove(e) {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const info = this._touches.get(t.identifier);
      if (!info || info.zone.type !== 'dpad') continue;

      const lp = this._toLogi(t.clientX, t.clientY);
      const dx = lp.x - DPAD_X, dy = lp.y - DPAD_Y;
      const dir = this._dpadDir(dx, dy);
      if (dir !== this._dpadAction) {
        this._clearDpad();
        if (dir) {
          this._setDpad(dir);
          this._input.queueAction(dir);
        }
      }
    }
  }

  _onEnd(e) {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const info = this._touches.get(t.identifier);
      if (!info) continue;
      this._touches.delete(t.identifier);

      if (info.zone.type === 'btn') {
        this._input._removeAction(info.zone.btn.action);
        this._btnStates.delete(info.zone.btn.label);
      } else if (info.zone.type === 'dpad') {
        this._clearDpad();
      }
    }
  }

  _setDpad(action) {
    this._dpadAction = action;
    this._input._addAction(action);
  }

  _clearDpad() {
    if (this._dpadAction) {
      this._input._removeAction(this._dpadAction);
      this._dpadAction = null;
    }
  }

  draw(ctx) {
    if (!this._visible) return;
    const saved = ctx.globalAlpha;
    ctx.globalAlpha = 0.18;

    // D-pad background
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(DPAD_X, DPAD_Y, DPAD_R, 0, Math.PI * 2);
    ctx.fill();

    // D-pad arrows
    ctx.globalAlpha = this._dpadAction ? 0.5 : 0.35;
    const arrows = [
      { action: Action.MOVE_UP, x: 0, y: -22, rot: 0 },
      { action: Action.MOVE_DOWN, x: 0, y: 22, rot: Math.PI },
      { action: Action.MOVE_LEFT, x: -22, y: 0, rot: Math.PI / 2 },
      { action: Action.MOVE_RIGHT, x: 22, y: 0, rot: -Math.PI / 2 },
    ];
    for (const a of arrows) {
      ctx.fillStyle = this._dpadAction === a.action ? '#32e8ff' : '#ffffff';
      ctx.save();
      ctx.translate(DPAD_X + a.x, DPAD_Y + a.y);
      ctx.rotate(a.rot);
      ctx.beginPath();
      ctx.moveTo(-8, 4);
      ctx.lineTo(0, -8);
      ctx.lineTo(8, 4);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    // Buttons
    for (const btn of BUTTONS) {
      const active = this._btnStates.has(btn.label);
      ctx.globalAlpha = active ? 0.45 : 0.2;
      ctx.fillStyle = active ? '#32e8ff' : '#ffffff';
      ctx.beginPath();
      ctx.arc(btn.x, btn.y, btn.r, 0, Math.PI * 2);
      ctx.fill();

      ctx.globalAlpha = active ? 0.8 : 0.4;
      ctx.fillStyle = '#ffffff';
      ctx.font = '12px "Press Start 2P", monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(btn.label, btn.x, btn.y);
    }

    ctx.globalAlpha = saved;
  }
}

export const touchControls = new TouchControls();

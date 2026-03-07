const Action = Object.freeze({
  MOVE_UP: 'moveUp',
  MOVE_DOWN: 'moveDown',
  MOVE_LEFT: 'moveLeft',
  MOVE_RIGHT: 'moveRight',
  ACTION_PRIMARY: 'actionPrimary',
  ACTION_SECONDARY: 'actionSecondary',
  MENU_SELECT: 'menuSelect',
  MENU_BACK: 'menuBack',
  PAUSE: 'pause',
});

const OPPOSITES = Object.freeze({
  [Action.MOVE_UP]: Action.MOVE_DOWN,
  [Action.MOVE_DOWN]: Action.MOVE_UP,
  [Action.MOVE_LEFT]: Action.MOVE_RIGHT,
  [Action.MOVE_RIGHT]: Action.MOVE_LEFT,
});

const KEY_MAP = Object.freeze({
  ArrowUp: Action.MOVE_UP,
  ArrowDown: Action.MOVE_DOWN,
  ArrowLeft: Action.MOVE_LEFT,
  ArrowRight: Action.MOVE_RIGHT,
  KeyW: Action.MOVE_UP,
  KeyS: Action.MOVE_DOWN,
  KeyA: Action.MOVE_LEFT,
  KeyD: Action.MOVE_RIGHT,
  Space: Action.ACTION_PRIMARY,
  Enter: Action.MENU_SELECT,
  Escape: Action.PAUSE,
});

const MIN_SWIPE_DIST = 30;
const MAX_TAP_DIST = 10;
const MAX_TAP_MS = 200;
const INPUT_QUEUE_MAX = 2;

class InputManager {
  constructor() {
    this._canvas = null;
    this._held = new Set();
    this._pressed = new Set();
    this._queue = [];
    this._touchStartX = 0;
    this._touchStartY = 0;
    this._touchStartTime = 0;
    this._touchId = null;

    this._onKeyDown = this._handleKeyDown.bind(this);
    this._onKeyUp = this._handleKeyUp.bind(this);
    this._onTouchStart = this._handleTouchStart.bind(this);
    this._onTouchEnd = this._handleTouchEnd.bind(this);
    this._onTouchMove = this._handleTouchMove.bind(this);
  }

  init(canvas) {
    this._canvas = canvas;

    document.addEventListener('keydown', this._onKeyDown);
    document.addEventListener('keyup', this._onKeyUp);
    canvas.addEventListener('touchstart', this._onTouchStart, { passive: false });
    canvas.addEventListener('touchend', this._onTouchEnd, { passive: false });
    canvas.addEventListener('touchmove', this._onTouchMove, { passive: false });
  }

  destroy() {
    document.removeEventListener('keydown', this._onKeyDown);
    document.removeEventListener('keyup', this._onKeyUp);
    if (this._canvas) {
      this._canvas.removeEventListener('touchstart', this._onTouchStart);
      this._canvas.removeEventListener('touchend', this._onTouchEnd);
      this._canvas.removeEventListener('touchmove', this._onTouchMove);
    }
    this._canvas = null;
    this._held.clear();
    this._pressed.clear();
    this._queue.length = 0;
  }

  update() {
    this._pressed.clear();
  }

  isHeld(action) {
    return this._held.has(action);
  }

  isPressed(action) {
    return this._pressed.has(action);
  }

  consumePress(action) {
    if (this._pressed.has(action)) {
      this._pressed.delete(action);
      return true;
    }
    return false;
  }

  queueAction(action) {
    if (this._queue.length >= INPUT_QUEUE_MAX) return;
    const last = this._queue.length > 0
      ? this._queue[this._queue.length - 1]
      : null;
    if (last && OPPOSITES[action] === last) return;
    this._queue.push(action);
  }

  dequeueAction() {
    return this._queue.length > 0 ? this._queue.shift() : null;
  }

  clearQueue() { this._queue.length = 0; }
  getQueueLength() { return this._queue.length; }
  _addAction(action) { this._held.add(action); this._pressed.add(action); }
  _removeAction(action) { this._held.delete(action); }

  _handleKeyDown(e) {
    const action = KEY_MAP[e.code];
    if (!action) return;
    e.preventDefault();
    if (this._held.has(action)) return;
    this._addAction(action);

    if (OPPOSITES[action]) {
      this.queueAction(action);
    }
  }

  _handleKeyUp(e) {
    const action = KEY_MAP[e.code];
    if (!action) return;
    e.preventDefault();
    this._removeAction(action);
  }

  _handleTouchStart(e) {
    e.preventDefault();
    if (this._touchId !== null) return;
    const touch = e.changedTouches[0];
    this._touchId = touch.identifier;
    this._touchStartX = touch.clientX;
    this._touchStartY = touch.clientY;
    this._touchStartTime = performance.now();
  }

  _handleTouchMove(e) {
    e.preventDefault();
  }

  _handleTouchEnd(e) {
    e.preventDefault();
    const touch = this._findTouch(e.changedTouches, this._touchId);
    if (!touch) return;
    this._touchId = null;

    const dx = touch.clientX - this._touchStartX;
    const dy = touch.clientY - this._touchStartY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const elapsed = performance.now() - this._touchStartTime;

    if (dist < MAX_TAP_DIST && elapsed < MAX_TAP_MS) {
      this._addAction(Action.ACTION_PRIMARY);
      return;
    }

    if (dist >= MIN_SWIPE_DIST) {
      const action = this._swipeToAction(dx, dy);
      if (action) {
        this._addAction(action);
        this.queueAction(action);
      }
    }
  }

  _swipeToAction(dx, dy) {
    if (Math.abs(dx) > Math.abs(dy)) {
      return dx > 0 ? Action.MOVE_RIGHT : Action.MOVE_LEFT;
    }
    return dy > 0 ? Action.MOVE_DOWN : Action.MOVE_UP;
  }

  _findTouch(touchList, id) {
    for (let i = 0; i < touchList.length; i++) {
      if (touchList[i].identifier === id) return touchList[i];
    }
    return null;
  }
}

export const input = new InputManager();
export { Action };

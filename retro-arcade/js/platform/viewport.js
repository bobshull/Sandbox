const LOGICAL_WIDTH = 480;
const LOGICAL_HEIGHT = 640;
const RESIZE_DEBOUNCE_MS = 150;

class ViewportManager {
  constructor() {
    this._canvas = null;
    this._ctx = null;
    this._dpr = 1;
    this._cssWidth = 0;
    this._cssHeight = 0;
    this._resizeTimer = null;
    this._onResize = this._handleResize.bind(this);
  }

  init(canvas) {
    this._canvas = canvas;
    this._dpr = window.devicePixelRatio || 1;
    this._ctx = canvas.getContext('2d');

    this._applySize();

    window.addEventListener('resize', this._onResize);
    window.addEventListener('orientationchange', this._onResize);
  }

  destroy() {
    window.removeEventListener('resize', this._onResize);
    window.removeEventListener('orientationchange', this._onResize);
    clearTimeout(this._resizeTimer);
    this._canvas = null;
    this._ctx = null;
  }

  getContext() {
    return this._ctx;
  }

  getLogicalSize() {
    return { width: LOGICAL_WIDTH, height: LOGICAL_HEIGHT };
  }

  getCanvasElement() {
    return this._canvas;
  }

  toLogicalCoords(clientX, clientY) {
    const rect = this._canvas.getBoundingClientRect();
    const scaleX = LOGICAL_WIDTH / rect.width;
    const scaleY = LOGICAL_HEIGHT / rect.height;
    return {
      x: (clientX - rect.left) * scaleX,
      y: (clientY - rect.top) * scaleY,
    };
  }

  _handleResize() {
    clearTimeout(this._resizeTimer);
    this._resizeTimer = setTimeout(() => this._applySize(), RESIZE_DEBOUNCE_MS);
  }

  _applySize() {
    this._dpr = window.devicePixelRatio || 1;

    const safeTop = this._getCSSEnv('safe-area-inset-top');
    const safeBottom = this._getCSSEnv('safe-area-inset-bottom');
    const safeLeft = this._getCSSEnv('safe-area-inset-left');
    const safeRight = this._getCSSEnv('safe-area-inset-right');

    const availW = window.innerWidth - safeLeft - safeRight;
    const availH = window.innerHeight - safeTop - safeBottom;

    const scale = Math.min(availW / LOGICAL_WIDTH, availH / LOGICAL_HEIGHT);
    this._cssWidth = Math.floor(LOGICAL_WIDTH * scale);
    this._cssHeight = Math.floor(LOGICAL_HEIGHT * scale);

    this._canvas.width = LOGICAL_WIDTH * this._dpr;
    this._canvas.height = LOGICAL_HEIGHT * this._dpr;
    this._canvas.style.width = this._cssWidth + 'px';
    this._canvas.style.height = this._cssHeight + 'px';

    const offsetX = safeLeft + Math.floor((availW - this._cssWidth) / 2);
    const offsetY = safeTop + Math.floor((availH - this._cssHeight) / 2);
    this._canvas.style.position = 'absolute';
    this._canvas.style.left = offsetX + 'px';
    this._canvas.style.top = offsetY + 'px';

    this._ctx = this._canvas.getContext('2d');
    this._ctx.imageSmoothingEnabled = false;
    this._ctx.setTransform(this._dpr, 0, 0, this._dpr, 0, 0);
  }

  _getCSSEnv(name) {
    const probe = document.createElement('div');
    probe.style.position = 'fixed';
    probe.style.left = '0';
    probe.style.top = '0';
    probe.style.width = `env(${name}, 0px)`;
    document.body.appendChild(probe);
    const value = probe.getBoundingClientRect().width;
    document.body.removeChild(probe);
    return value;
  }
}

export const viewport = new ViewportManager();
export { LOGICAL_WIDTH, LOGICAL_HEIGHT };

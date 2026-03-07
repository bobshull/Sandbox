import { viewport, LOGICAL_WIDTH, LOGICAL_HEIGHT } from '../platform/viewport.js';

const Z_BACKGROUND = 0;
const Z_ENTITIES = 10;
const Z_EFFECTS = 20;
const Z_UI = 30;
const Z_OVERLAY = 40;

class Renderer {
  constructor() {
    this._visible = null;
    this._visibleCtx = null;
    this._offscreen = null;
    this._offCtx = null;
    this._commands = [];
    this._postProcessors = [];
    this._bgColor = '#070814';
  }

  init() {
    this._visible = viewport.getCanvasElement();
    this._visibleCtx = viewport.getContext();
    this._offscreen = document.createElement('canvas');
    this._offscreen.width = LOGICAL_WIDTH;
    this._offscreen.height = LOGICAL_HEIGHT;
    this._offCtx = this._offscreen.getContext('2d');
    this._offCtx.imageSmoothingEnabled = false;
  }

  setBackground(color) {
    this._bgColor = color;
  }

  beginFrame() {
    this._commands.length = 0;
    this._offCtx.fillStyle = this._bgColor;
    this._offCtx.fillRect(0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT);
  }

  endFrame() {
    this._commands.sort((a, b) => a.z - b.z);
    for (const cmd of this._commands) {
      this._execute(cmd);
    }
    for (const fn of this._postProcessors) {
      fn(this._offCtx, LOGICAL_WIDTH, LOGICAL_HEIGHT);
    }
    this._visibleCtx.save();
    this._visibleCtx.setTransform(1, 0, 0, 1, 0, 0);
    this._visibleCtx.clearRect(0, 0, this._visible.width, this._visible.height);
    this._visibleCtx.drawImage(
      this._offscreen, 0, 0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
      0, 0, this._visible.width, this._visible.height
    );
    this._visibleCtx.restore();
  }

  fillRect(x, y, w, h, color, z = Z_ENTITIES) {
    this._commands.push({ type: 'fillRect', x, y, w, h, color, z });
  }

  strokeRect(x, y, w, h, color, lineWidth = 1, z = Z_ENTITIES) {
    this._commands.push({ type: 'strokeRect', x, y, w, h, color, lineWidth, z });
  }

  fillCircle(x, y, radius, color, z = Z_ENTITIES) {
    this._commands.push({ type: 'fillCircle', x, y, radius, color, z });
  }

  strokeCircle(x, y, radius, color, lineWidth = 1, z = Z_ENTITIES) {
    this._commands.push({ type: 'strokeCircle', x, y, radius, color, lineWidth, z });
  }

  drawLine(x1, y1, x2, y2, color, lineWidth = 1, z = Z_ENTITIES) {
    this._commands.push({ type: 'drawLine', x1, y1, x2, y2, color, lineWidth, z });
  }

  drawSprite(spriteData, x, y, scale, color, z = Z_ENTITIES) {
    this._commands.push({ type: 'drawSprite', spriteData, x, y, scale, color, z });
  }

  drawText(text, x, y, options = {}, z = Z_UI) {
    this._commands.push({ type: 'drawText', text, x, y, options, z });
  }

  addPostProcess(fn) {
    if (!this._postProcessors.includes(fn)) {
      this._postProcessors.push(fn);
    }
  }

  removePostProcess(fn) {
    const idx = this._postProcessors.indexOf(fn);
    if (idx !== -1) this._postProcessors.splice(idx, 1);
  }

  getOffscreenContext() {
    return this._offCtx;
  }

  _execute(cmd) {
    const ctx = this._offCtx;
    switch (cmd.type) {
      case 'fillRect':
        ctx.fillStyle = cmd.color;
        ctx.fillRect(cmd.x, cmd.y, cmd.w, cmd.h);
        break;
      case 'strokeRect':
        ctx.strokeStyle = cmd.color;
        ctx.lineWidth = cmd.lineWidth;
        ctx.strokeRect(cmd.x, cmd.y, cmd.w, cmd.h);
        break;
      case 'fillCircle':
        ctx.fillStyle = cmd.color;
        ctx.beginPath();
        ctx.arc(cmd.x, cmd.y, cmd.radius, 0, Math.PI * 2);
        ctx.fill();
        break;
      case 'strokeCircle':
        ctx.strokeStyle = cmd.color;
        ctx.lineWidth = cmd.lineWidth;
        ctx.beginPath();
        ctx.arc(cmd.x, cmd.y, cmd.radius, 0, Math.PI * 2);
        ctx.stroke();
        break;
      case 'drawLine':
        ctx.strokeStyle = cmd.color;
        ctx.lineWidth = cmd.lineWidth;
        ctx.beginPath();
        ctx.moveTo(cmd.x1, cmd.y1);
        ctx.lineTo(cmd.x2, cmd.y2);
        ctx.stroke();
        break;
      case 'drawSprite':
        this._drawSprite(ctx, cmd.spriteData, cmd.x, cmd.y, cmd.scale, cmd.color);
        break;
      case 'drawText':
        this._drawText(ctx, cmd.text, cmd.x, cmd.y, cmd.options);
        break;
    }
  }

  _drawSprite(ctx, data, x, y, scale, color) {
    ctx.fillStyle = color;
    for (let row = 0; row < data.length; row++) {
      for (let col = 0; col < data[row].length; col++) {
        if (data[row][col]) {
          ctx.fillRect(x + col * scale, y + row * scale, scale, scale);
        }
      }
    }
  }

  _drawText(ctx, text, x, y, opts) {
    const font = opts.font || 'body';
    const color = opts.color || '#f1f2f6';
    const align = opts.align || 'left';
    const baseline = opts.baseline || 'top';

    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = baseline;

    switch (font) {
      case 'title': ctx.font = '16px "Press Start 2P", monospace'; break;
      case 'body': ctx.font = '24px "VT323", monospace'; break;
      case 'ui': ctx.font = '20px "Pixelify Sans", monospace'; break;
      case 'score': ctx.font = '12px "Press Start 2P", monospace'; break;
      default: ctx.font = font; break;
    }

    if (opts.alpha !== undefined) {
      const saved = ctx.globalAlpha;
      ctx.globalAlpha = opts.alpha;
      ctx.fillText(text, x, y);
      ctx.globalAlpha = saved;
    } else {
      ctx.fillText(text, x, y);
    }
  }
}

export const renderer = new Renderer();
export { Z_BACKGROUND, Z_ENTITIES, Z_EFFECTS, Z_UI, Z_OVERLAY };

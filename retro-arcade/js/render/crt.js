import { storage } from '../platform/storage.js';
import { renderer } from './renderer.js';

class CRTEffect {
  constructor() {
    this._enabled = true;
    this._chromaticAberration = false;
    this._process = this._process.bind(this);
  }

  init() {
    this._enabled = storage.getSetting('crtEffect') !== false;
    this._chromaticAberration = false;
    if (this._enabled) {
      renderer.addPostProcess(this._process);
    }
  }

  setEnabled(enabled) {
    this._enabled = enabled;
    if (enabled) {
      renderer.addPostProcess(this._process);
    } else {
      renderer.removePostProcess(this._process);
    }
    storage.setSetting('crtEffect', enabled);
  }

  isEnabled() {
    return this._enabled;
  }

  toggle() {
    this.setEnabled(!this._enabled);
  }

  setChromaticAberration(enabled) {
    this._chromaticAberration = enabled;
  }

  _process(ctx, width, height) {
    if (this._chromaticAberration) {
      this._applyChromaticAberration(ctx, width, height);
    }
  }

  _applyChromaticAberration(ctx, width, height) {
    try {
      const imageData = ctx.getImageData(0, 0, width, height);
      const src = imageData.data;
      const copy = new Uint8ClampedArray(src);
      const offset = 1;
      const stride = width * 4;

      for (let y = 0; y < height; y++) {
        for (let x = offset; x < width - offset; x++) {
          const i = y * stride + x * 4;
          src[i] = copy[y * stride + (x - offset) * 4];
          src[i + 2] = copy[y * stride + (x + offset) * 4 + 2];
        }
      }
      ctx.putImageData(imageData, 0, 0);
    } catch (e) {
      this._chromaticAberration = false;
    }
  }
}

export const crt = new CRTEffect();

export class ObjectPool {
  constructor(factory, initialSize) {
    this._factory = factory;
    this._available = [];
    this._active = new Set();

    for (let i = 0; i < initialSize; i++) {
      this._available.push(factory());
    }
  }

  acquire() {
    const obj = this._available.length > 0
      ? this._available.pop()
      : this._factory();
    this._active.add(obj);
    return obj;
  }

  release(obj) {
    if (!this._active.delete(obj)) return;
    if (obj.reset) obj.reset();
    this._available.push(obj);
  }

  releaseAll() {
    for (const obj of this._active) {
      if (obj.reset) obj.reset();
      this._available.push(obj);
    }
    this._active.clear();
  }

  getActive() {
    return this._active.values();
  }

  getActiveCount() {
    return this._active.size;
  }

  getAvailableCount() {
    return this._available.length;
  }

  destroy() {
    this._active.clear();
    this._available.length = 0;
  }
}

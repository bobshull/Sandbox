const TARGET_FPS = 60;
const FRAME_DURATION = 1000 / TARGET_FPS;
const MAX_ACCUMULATOR = FRAME_DURATION * 5;
const PERF_BUFFER_SIZE = 60;
const PERF_WARN_THRESHOLD_MS = 20;
const PERF_WARN_CONSECUTIVE = 10;

class GameLoop {
  constructor() {
    this._updateFn = null;
    this._renderFn = null;
    this._onPerfWarning = null;
    this._rafId = null;
    this._lastTime = 0;
    this._accumulator = 0;
    this._running = false;
    this._paused = false;
    this._frameTimes = new Float64Array(PERF_BUFFER_SIZE);
    this._frameIndex = 0;
    this._frameCount = 0;
    this._warnStreak = 0;
    this._tick = this._tick.bind(this);
  }

  setCallbacks(updateFn, renderFn) {
    this._updateFn = updateFn;
    this._renderFn = renderFn;
  }

  setOnPerfWarning(callback) {
    this._onPerfWarning = callback;
  }

  start() {
    if (this._running) return;
    this._running = true;
    this._paused = false;
    this._lastTime = 0;
    this._accumulator = 0;
    this._frameIndex = 0;
    this._frameCount = 0;
    this._warnStreak = 0;
    this._rafId = requestAnimationFrame(this._tick);
  }

  stop() {
    this._running = false;
    this._paused = false;
    if (this._rafId !== null) {
      cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
  }

  pause() {
    this._paused = true;
  }

  resume() {
    if (!this._paused) return;
    this._paused = false;
    this._lastTime = 0;
  }

  isRunning() {
    return this._running;
  }

  isPaused() {
    return this._paused;
  }

  getFPS() {
    const count = Math.min(this._frameCount, PERF_BUFFER_SIZE);
    if (count === 0) return 0;
    let sum = 0;
    for (let i = 0; i < count; i++) sum += this._frameTimes[i];
    return 1000 / (sum / count);
  }

  getFrameTime() {
    const count = Math.min(this._frameCount, PERF_BUFFER_SIZE);
    if (count === 0) return 0;
    let sum = 0;
    for (let i = 0; i < count; i++) sum += this._frameTimes[i];
    return sum / count;
  }

  _tick(timestamp) {
    if (!this._running) return;
    this._rafId = requestAnimationFrame(this._tick);

    if (this._lastTime === 0) {
      this._lastTime = timestamp;
      return;
    }

    const delta = timestamp - this._lastTime;
    this._lastTime = timestamp;

    this._recordFrameTime(delta);

    if (this._paused) {
      if (this._renderFn) this._renderFn(0);
      return;
    }

    this._accumulator += delta;
    if (this._accumulator > MAX_ACCUMULATOR) {
      this._accumulator = MAX_ACCUMULATOR;
    }

    while (this._accumulator >= FRAME_DURATION) {
      if (this._updateFn) this._updateFn(FRAME_DURATION / 1000);
      this._accumulator -= FRAME_DURATION;
    }

    const alpha = this._accumulator / FRAME_DURATION;
    if (this._renderFn) this._renderFn(alpha);
  }

  _recordFrameTime(ms) {
    this._frameTimes[this._frameIndex] = ms;
    this._frameIndex = (this._frameIndex + 1) % PERF_BUFFER_SIZE;
    this._frameCount++;

    if (ms > PERF_WARN_THRESHOLD_MS) {
      this._warnStreak++;
      if (this._warnStreak >= PERF_WARN_CONSECUTIVE && this._onPerfWarning) {
        this._onPerfWarning(this.getFrameTime());
        this._warnStreak = 0;
      }
    } else {
      this._warnStreak = 0;
    }
  }
}

export const gameLoop = new GameLoop();

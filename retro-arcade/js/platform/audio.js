import {
  Priority, blip, laser, explosion, coin, powerUp, gameOver,
  hit, score, menuMove, menuSelect, bounce,
} from './audio-sounds.js';

const MAX_CONCURRENT = 4;

class AudioManager {
  constructor() {
    this._ctx = null;
    this._masterGain = null;
    this._sfxGain = null;
    this._musicGain = null;
    this._muted = false;
    this._savedMasterVol = 0.7;
    this._active = [];
  }

  init() {}

  setMasterVolume(v) {
    this._savedMasterVol = v;
    if (this._masterGain && !this._muted) this._masterGain.gain.value = v;
  }

  setSfxVolume(v) { if (this._sfxGain) this._sfxGain.gain.value = v; }
  setMusicVolume(v) { if (this._musicGain) this._musicGain.gain.value = v; }

  mute() { this._muted = true; if (this._masterGain) this._masterGain.gain.value = 0; }
  unmute() { this._muted = false; if (this._masterGain) this._masterGain.gain.value = this._savedMasterVol; }
  toggleMute() { this._muted ? this.unmute() : this.mute(); }
  isMuted() { return this._muted; }

  isAvailable() {
    return typeof AudioContext !== 'undefined' || typeof webkitAudioContext !== 'undefined';
  }

  playBlip(freq, duration, wave) { this._play(Priority.LOW, (c, d) => blip(c, d, freq, duration, wave)); }
  playLaser() { this._play(Priority.HIGH, laser); }
  playExplosion() { this._play(Priority.CRITICAL, explosion); }
  playCoin() { this._play(Priority.MEDIUM, coin); }
  playPowerUp() { this._play(Priority.HIGH, powerUp); }
  playGameOver() { this._play(Priority.CRITICAL, gameOver); }
  playHit() { this._play(Priority.MEDIUM, hit); }
  playScore() { this._play(Priority.MEDIUM, score); }
  playMenuMove() { this._play(Priority.LOW, menuMove); }
  playMenuSelect() { this._play(Priority.MEDIUM, menuSelect); }
  playBounce() { this._play(Priority.LOW, bounce); }

  destroy() {
    if (this._ctx) { this._ctx.close().catch(() => {}); this._ctx = null; }
    this._masterGain = null;
    this._sfxGain = null;
    this._musicGain = null;
    this._active.length = 0;
  }

  _ensureContext() {
    if (this._ctx) {
      if (this._ctx.state === 'suspended') this._ctx.resume().catch(() => {});
      return true;
    }
    try {
      const Ctor = window.AudioContext || window.webkitAudioContext;
      if (!Ctor) return false;
      this._ctx = new Ctor();
      this._masterGain = this._ctx.createGain();
      this._masterGain.gain.value = this._muted ? 0 : this._savedMasterVol;
      this._masterGain.connect(this._ctx.destination);
      this._sfxGain = this._ctx.createGain();
      this._sfxGain.connect(this._masterGain);
      this._musicGain = this._ctx.createGain();
      this._musicGain.connect(this._masterGain);
      if (this._ctx.state === 'suspended') this._ctx.resume().catch(() => {});
      return true;
    } catch (e) {
      console.warn('[Audio] Failed to create AudioContext:', e.message);
      return false;
    }
  }

  _play(priority, buildFn) {
    try {
      if (!this._ensureContext()) return;
      this._pruneActive();
      if (this._active.length >= MAX_CONCURRENT) {
        const lowest = this._findLowestPriority();
        if (lowest && lowest.priority < priority) {
          this._active.splice(this._active.indexOf(lowest), 1);
        } else { return; }
      }
      const duration = buildFn(this._ctx, this._sfxGain);
      this._active.push({ priority, endTime: this._ctx.currentTime + duration });
    } catch (e) {
      console.warn('[Audio] Playback error:', e.message);
    }
  }

  _pruneActive() {
    const now = this._ctx.currentTime;
    for (let i = this._active.length - 1; i >= 0; i--) {
      if (this._active[i].endTime <= now) this._active.splice(i, 1);
    }
  }

  _findLowestPriority() {
    let lowest = null;
    for (const entry of this._active) {
      if (!lowest || entry.priority < lowest.priority) lowest = entry;
    }
    return lowest;
  }
}

export const audio = new AudioManager();

import { audio } from './audio.js';
import { storage } from './storage.js';

const TRACKS = Object.freeze({
  menu: Object.freeze([
    { note: 262, duration: 0.15, type: 'square' },
    { note: 330, duration: 0.15, type: 'square' },
    { note: 392, duration: 0.15, type: 'square' },
    { note: 523, duration: 0.15, type: 'square' },
    { note: 392, duration: 0.15, type: 'square' },
    { note: 330, duration: 0.15, type: 'square' },
    { note: 0, duration: 0.3, type: 'square' },
  ]),
});

class MusicManager {
  constructor() {
    this._ctx = null;
    this._gain = null;
    this._currentTrack = null;
    this._noteIndex = 0;
    this._nextNoteTime = 0;
    this._intervalId = null;
    this._playing = false;
  }

  play(trackId) {
    if (!TRACKS[trackId]) return;
    this.stop();
    this._currentTrack = TRACKS[trackId];
    this._noteIndex = 0;
    this._playing = true;

    try {
      const Ctor = window.AudioContext || window.webkitAudioContext;
      if (!Ctor) return;
      if (!this._ctx) {
        this._ctx = new Ctor();
        this._gain = this._ctx.createGain();
        this._gain.connect(this._ctx.destination);
      }
      this._gain.gain.value = 0.15 * (storage.getSetting('musicVolume') || 0.5);
      if (this._ctx.state === 'suspended') this._ctx.resume().catch(() => {});
      this._nextNoteTime = this._ctx.currentTime;
      this._intervalId = setInterval(() => this._schedule(), 25);
    } catch (e) {
      console.warn('[Music] Failed to start:', e.message);
    }
  }

  stop() {
    this._playing = false;
    if (this._intervalId) {
      clearInterval(this._intervalId);
      this._intervalId = null;
    }
  }

  pause() { this.stop(); }
  resume() { if (this._currentTrack) this.play(this._currentTrack); }

  setVolume(v) {
    if (this._gain) this._gain.gain.value = 0.15 * v;
  }

  _schedule() {
    if (!this._playing || !this._ctx || !this._currentTrack) return;
    const lookAhead = 0.1;

    while (this._nextNoteTime < this._ctx.currentTime + lookAhead) {
      const note = this._currentTrack[this._noteIndex];

      if (note.note > 0) {
        try {
          const osc = this._ctx.createOscillator();
          const env = this._ctx.createGain();
          osc.type = note.type;
          osc.frequency.value = note.note;
          env.gain.setValueAtTime(0.15, this._nextNoteTime);
          env.gain.exponentialRampToValueAtTime(0.001, this._nextNoteTime + note.duration * 0.9);
          osc.connect(env).connect(this._gain);
          osc.start(this._nextNoteTime);
          osc.stop(this._nextNoteTime + note.duration);
        } catch (e) { /* non-fatal */ }
      }

      this._nextNoteTime += note.duration;
      this._noteIndex = (this._noteIndex + 1) % this._currentTrack.length;
    }
  }

  destroy() {
    this.stop();
    if (this._ctx) {
      this._ctx.close().catch(() => {});
      this._ctx = null;
    }
  }
}

export const music = new MusicManager();

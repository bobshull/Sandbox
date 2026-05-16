import { voices } from './synths.js';
import { EventEmitter } from '../utils/events.js';
import { STEP_COUNT } from '../data/tracks.js';

const LOOKAHEAD_MS = 25;
const SCHEDULE_AHEAD = 0.1; // seconds

// Sample-accurate step sequencer. Uses Web Audio's clock for timing
// and a setTimeout-driven loop only to schedule notes ahead of time.
export class AudioEngine extends EventEmitter {
  #ctx = null;
  #master = null;
  #trackGains = new Map();
  #timerId = null;
  #currentStep = 0;
  #nextNoteTime = 0;
  #isPlaying = false;
  #tempo = 96;
  #swing = 0.18;
  #getState;

  constructor(getState) {
    super();
    this.#getState = getState;
  }

  get isPlaying() {
    return this.#isPlaying;
  }

  async ensureContext() {
    if (!this.#ctx) {
      const Ctor = window.AudioContext || window.webkitAudioContext;
      if (!Ctor) throw new Error('Web Audio API is not supported in this browser.');
      this.#ctx = new Ctor();
      this.#master = this.#ctx.createGain();
      this.#master.gain.value = 0.85;
      this.#master.connect(this.#ctx.destination);
    }
    if (this.#ctx.state === 'suspended') await this.#ctx.resume();
    return this.#ctx;
  }

  setTempo(bpm) {
    this.#tempo = Math.min(Math.max(bpm, 40), 220);
  }

  setSwing(value) {
    this.#swing = Math.min(Math.max(value, 0), 0.6);
  }

  setMasterGain(value) {
    if (!this.#master) return;
    this.#master.gain.setTargetAtTime(value, this.#ctx.currentTime, 0.02);
  }

  setTrackGain(trackId, value) {
    const node = this.#trackGains.get(trackId);
    if (!node || !this.#ctx) return;
    node.gain.setTargetAtTime(value, this.#ctx.currentTime, 0.02);
  }

  #trackDestination(trackId) {
    if (!this.#trackGains.has(trackId)) {
      const g = this.#ctx.createGain();
      const initial = this.#getState().volumes?.[trackId] ?? 0.8;
      g.gain.value = initial;
      g.connect(this.#master);
      this.#trackGains.set(trackId, g);
    }
    return this.#trackGains.get(trackId);
  }

  // Trigger a single voice immediately — used for preview taps on track headers.
  async preview(trackId, voiceKey) {
    await this.ensureContext();
    const dest = this.#trackDestination(trackId);
    const fn = voices[voiceKey];
    if (fn) fn(this.#ctx, this.#ctx.currentTime + 0.01, dest);
  }

  async start() {
    if (this.#isPlaying) return;
    await this.ensureContext();
    this.#isPlaying = true;
    this.#currentStep = 0;
    this.#nextNoteTime = this.#ctx.currentTime + 0.05;
    this.emit('start');
    this.#tick();
  }

  stop() {
    if (!this.#isPlaying) return;
    this.#isPlaying = false;
    if (this.#timerId) {
      clearTimeout(this.#timerId);
      this.#timerId = null;
    }
    this.emit('stop');
    this.emit('step', { step: -1, time: 0 });
  }

  #stepDuration() {
    // 16th note. 60/bpm = quarter, divide by 4.
    return 60 / this.#tempo / 4;
  }

  #advance() {
    const base = this.#stepDuration();
    // True swing: delay offbeats (odd 16ths) by `swing` * base, and shorten
    // the following gap by the same amount so total bar length is preserved.
    const nextStep = (this.#currentStep + 1) % STEP_COUNT;
    const nextIsOffbeat = nextStep % 2 === 1;
    const factor = nextIsOffbeat ? 1 + this.#swing : 1 - this.#swing;
    this.#nextNoteTime += base * factor;
    this.#currentStep = nextStep;
  }

  #scheduleNote(step, time) {
    const { tracks, pattern, mutes } = this.#getState();
    for (const track of tracks) {
      if (mutes[track.id]) continue;
      const row = pattern[track.id];
      if (!row || !row[step]) continue;
      const dest = this.#trackDestination(track.id);
      const fn = voices[track.voice];
      if (fn) fn(this.#ctx, time, dest);
    }
    this.emit('step', { step, time });
  }

  #tick = () => {
    if (!this.#isPlaying) return;
    while (this.#nextNoteTime < this.#ctx.currentTime + SCHEDULE_AHEAD) {
      this.#scheduleNote(this.#currentStep, this.#nextNoteTime);
      this.#advance();
    }
    this.#timerId = setTimeout(this.#tick, LOOKAHEAD_MS);
  };
}

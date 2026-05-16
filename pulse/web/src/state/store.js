import { EventEmitter } from '../utils/events.js';
import { TRACKS, STEP_COUNT } from '../data/tracks.js';

function emptyPattern() {
  const p = {};
  for (const t of TRACKS) p[t.id] = Array(STEP_COUNT).fill(false);
  return p;
}

function emptyMutes() {
  const m = {};
  for (const t of TRACKS) m[t.id] = false;
  return m;
}

function emptyVolumes() {
  const v = {};
  for (const t of TRACKS) v[t.id] = 0.8;
  return v;
}

// Reactive store. Components subscribe to 'change' with a section name in payload.
export class Store extends EventEmitter {
  #state;

  constructor() {
    super();
    this.#state = {
      tempo: 96,
      swing: 0.18,
      masterGain: 0.85,
      tracks: TRACKS,
      pattern: emptyPattern(),
      mutes: emptyMutes(),
      volumes: emptyVolumes(),
      activeStep: -1,
      patternName: 'Untitled',
    };
  }

  get state() {
    return this.#state;
  }

  #emit(section) {
    this.emit('change', { section, state: this.#state });
  }

  setTempo(bpm) {
    this.#state.tempo = bpm;
    this.#emit('tempo');
  }

  setSwing(value) {
    this.#state.swing = value;
    this.#emit('swing');
  }

  setMasterGain(value) {
    this.#state.masterGain = value;
    this.#emit('master');
  }

  toggleStep(trackId, step) {
    const row = this.#state.pattern[trackId];
    if (!row) return;
    row[step] = !row[step];
    this.#emit('pattern');
  }

  setStep(trackId, step, value) {
    const row = this.#state.pattern[trackId];
    if (!row) return;
    row[step] = !!value;
    this.#emit('pattern');
  }

  toggleMute(trackId) {
    this.#state.mutes[trackId] = !this.#state.mutes[trackId];
    this.#emit('mutes');
  }

  setVolume(trackId, value) {
    this.#state.volumes[trackId] = value;
    this.#emit('volumes');
  }

  setActiveStep(step) {
    this.#state.activeStep = step;
    this.#emit('step');
  }

  setPatternName(name) {
    this.#state.patternName = name;
    this.#emit('name');
  }

  loadPattern({ name = 'Untitled', tempo, swing, pattern }) {
    this.#state.patternName = name;
    if (typeof tempo === 'number') this.#state.tempo = tempo;
    if (typeof swing === 'number') this.#state.swing = swing;
    const next = emptyPattern();
    for (const [k, v] of Object.entries(pattern ?? {})) {
      if (next[k] && Array.isArray(v) && v.length === STEP_COUNT) {
        next[k] = v.map(Boolean);
      }
    }
    this.#state.pattern = next;
    this.#emit('load');
  }

  clearPattern() {
    this.#state.pattern = emptyPattern();
    this.#emit('pattern');
  }

  exportPattern() {
    return {
      name: this.#state.patternName,
      tempo: this.#state.tempo,
      swing: this.#state.swing,
      pattern: structuredClone(this.#state.pattern),
    };
  }
}

import { el, mount } from '../utils/dom.js';
import { TRACKS, STEP_COUNT } from '../data/tracks.js';
import { TrackPanel } from './TrackPanel.js';

// The 16-step grid. One row per track, each cell toggles a step.
export class Sequencer {
  #host;
  #store;
  #engine;
  #cells = new Map(); // `${trackId}:${step}` -> button
  #stepHeaders = [];
  #activeStep = -1;

  constructor({ host, store, engine }) {
    this.#host = host;
    this.#store = store;
    this.#engine = engine;
    this.#render();
    this.#store.on('change', ({ section, state }) => {
      if (section === 'pattern' || section === 'load') this.#syncPattern(state.pattern);
      if (section === 'step') this.#syncActiveStep(state.activeStep);
    });
  }

  #render() {
    const headerCells = [el('div', { class: 'sequencer__corner' }, '')];
    this.#stepHeaders = [];
    for (let i = 0; i < STEP_COUNT; i++) {
      const isBeat = i % 4 === 0;
      const h = el('div', {
        class: 'sequencer__step-header' + (isBeat ? ' is-beat' : ''),
      }, String(i + 1));
      this.#stepHeaders.push(h);
      headerCells.push(h);
    }
    const header = el('div', { class: 'sequencer__row sequencer__row--header' }, headerCells);

    const rows = TRACKS.map(track => {
      const panel = new TrackPanel({ track, store: this.#store, engine: this.#engine });
      const cells = [];
      for (let step = 0; step < STEP_COUNT; step++) {
        const active = this.#store.state.pattern[track.id]?.[step];
        const cell = el('button', {
          type: 'button',
          class: 'cell' + (active ? ' is-on' : '') + (step % 4 === 0 ? ' is-beat' : ''),
          dataset: { trackId: track.id, step: String(step) },
          aria: {
            label: `${track.name} step ${step + 1}`,
            pressed: String(!!active),
          },
          onClick: () => {
            this.#store.toggleStep(track.id, step);
          },
        });
        this.#cells.set(`${track.id}:${step}`, cell);
        cells.push(cell);
      }
      return el('div', {
        class: 'sequencer__row',
        dataset: { trackId: track.id },
        style: `--track-color:${track.color};--track-accent:${track.accent}`,
      }, [
        panel.element,
        ...cells,
      ]);
    });

    const grid = el('div', { class: 'sequencer__grid' }, [header, ...rows]);
    mount(this.#host, grid);
  }

  #syncPattern(pattern) {
    for (const [key, cell] of this.#cells.entries()) {
      const [trackId, stepStr] = key.split(':');
      const on = !!pattern[trackId]?.[Number(stepStr)];
      cell.classList.toggle('is-on', on);
      cell.setAttribute('aria-pressed', String(on));
    }
  }

  #syncActiveStep(step) {
    if (this.#activeStep === step) return;
    if (this.#activeStep >= 0) {
      this.#stepHeaders[this.#activeStep]?.classList.remove('is-active');
      for (const t of TRACKS) {
        this.#cells.get(`${t.id}:${this.#activeStep}`)?.classList.remove('is-playing');
      }
    }
    this.#activeStep = step;
    if (step >= 0) {
      this.#stepHeaders[step]?.classList.add('is-active');
      for (const t of TRACKS) {
        this.#cells.get(`${t.id}:${step}`)?.classList.add('is-playing');
      }
    }
  }
}

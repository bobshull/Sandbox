import { el, clamp } from '../utils/dom.js';

// Renders a single track's left-side controls (name, mute, volume, preview).
export class TrackPanel {
  #track;
  #store;
  #engine;
  #muteBtn;
  #volumeSlider;
  #root;

  constructor({ track, store, engine }) {
    this.#track = track;
    this.#store = store;
    this.#engine = engine;
    this.#root = this.#render();

    this.#store.on('change', ({ section, state }) => {
      if (section === 'mutes' || section === 'load') {
        this.#muteBtn.classList.toggle('is-muted', !!state.mutes[track.id]);
        this.#muteBtn.setAttribute('aria-pressed', String(!!state.mutes[track.id]));
      }
      if (section === 'volumes' || section === 'load') {
        this.#volumeSlider.value = String(Math.round(state.volumes[track.id] * 100));
      }
    });
  }

  get element() {
    return this.#root;
  }

  #render() {
    const t = this.#track;
    const s = this.#store.state;

    this.#muteBtn = el('button', {
      type: 'button',
      class: 'track__mute' + (s.mutes[t.id] ? ' is-muted' : ''),
      aria: { pressed: String(!!s.mutes[t.id]), label: `Mute ${t.name}` },
      onClick: () => this.#store.toggleMute(t.id),
    }, 'M');

    this.#volumeSlider = el('input', {
      type: 'range', min: '0', max: '100', step: '1',
      value: String(Math.round(s.volumes[t.id] * 100)),
      class: 'track__volume',
      aria: { label: `${t.name} volume` },
      onInput: (e) => {
        const v = clamp(Number(e.target.value), 0, 100) / 100;
        this.#store.setVolume(t.id, v);
        this.#engine.setTrackGain(t.id, v);
      },
    });

    return el('div', {
      class: 'track',
      dataset: { trackId: t.id },
    }, [
      el('button', {
        type: 'button',
        class: 'track__name',
        aria: { label: `Preview ${t.name}` },
        onClick: () => this.#engine.preview(t.id, t.voice),
      }, [
        el('span', { class: 'track__swatch', 'aria-hidden': 'true' }),
        el('span', { class: 'track__label' }, t.name),
      ]),
      this.#muteBtn,
      this.#volumeSlider,
    ]);
  }
}

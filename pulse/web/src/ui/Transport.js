import { el, mount, clamp } from '../utils/dom.js';

export class Transport {
  #host;
  #store;
  #engine;
  #playBtn;
  #tempoSlider;
  #tempoLabel;
  #swingSlider;
  #swingLabel;
  #masterSlider;

  constructor({ host, store, engine }) {
    this.#host = host;
    this.#store = store;
    this.#engine = engine;
    this.#render();
    this.#store.on('change', ({ section, state }) => {
      if (section === 'tempo' || section === 'load') this.#syncTempo(state.tempo);
      if (section === 'swing' || section === 'load') this.#syncSwing(state.swing);
      if (section === 'master' || section === 'load') this.#syncMaster(state.masterGain);
    });
    this.#engine.on('start', () => this.#setPlaying(true));
    this.#engine.on('stop', () => this.#setPlaying(false));
  }

  #syncTempo(bpm) {
    this.#tempoSlider.value = String(bpm);
    this.#tempoLabel.textContent = `${bpm} BPM`;
  }

  #syncSwing(swing) {
    this.#swingSlider.value = String(Math.round(swing * 100));
    this.#swingLabel.textContent = `${Math.round(swing * 100)}%`;
  }

  #syncMaster(value) {
    this.#masterSlider.value = String(Math.round(value * 100));
  }

  #setPlaying(playing) {
    this.#playBtn.classList.toggle('is-playing', playing);
    this.#playBtn.setAttribute('aria-pressed', String(playing));
    this.#playBtn.querySelector('.transport__icon').textContent = playing ? '■' : '▶';
    this.#playBtn.querySelector('.transport__label').textContent = playing ? 'Stop' : 'Play';
  }

  async #togglePlay() {
    try {
      if (this.#engine.isPlaying) this.#engine.stop();
      else await this.#engine.start();
    } catch (err) {
      console.error('[transport] play failed:', err);
    }
  }

  #render() {
    const { tempo, swing, masterGain } = this.#store.state;

    this.#playBtn = el('button', {
      type: 'button',
      class: 'transport__play',
      aria: { pressed: 'false', label: 'Play or stop the sequencer' },
      onClick: () => this.#togglePlay(),
    }, [
      el('span', { class: 'transport__icon', 'aria-hidden': 'true' }, '▶'),
      el('span', { class: 'transport__label' }, 'Play'),
    ]);

    this.#tempoLabel = el('span', { class: 'transport__value' }, `${tempo} BPM`);
    this.#tempoSlider = el('input', {
      type: 'range', min: '60', max: '200', step: '1', value: String(tempo),
      class: 'transport__range', aria: { label: 'Tempo in BPM' },
      onInput: (e) => {
        const v = clamp(Number(e.target.value), 60, 200);
        this.#store.setTempo(v);
        this.#engine.setTempo(v);
      },
    });

    this.#swingLabel = el('span', { class: 'transport__value' }, `${Math.round(swing * 100)}%`);
    this.#swingSlider = el('input', {
      type: 'range', min: '0', max: '60', step: '1', value: String(Math.round(swing * 100)),
      class: 'transport__range', aria: { label: 'Swing amount' },
      onInput: (e) => {
        const v = clamp(Number(e.target.value), 0, 60) / 100;
        this.#store.setSwing(v);
        this.#engine.setSwing(v);
      },
    });

    this.#masterSlider = el('input', {
      type: 'range', min: '0', max: '100', step: '1', value: String(Math.round(masterGain * 100)),
      class: 'transport__range', aria: { label: 'Master volume' },
      onInput: (e) => {
        const v = clamp(Number(e.target.value), 0, 100) / 100;
        this.#store.setMasterGain(v);
        this.#engine.setMasterGain(v);
      },
    });

    const layout = el('div', { class: 'transport__inner' }, [
      this.#playBtn,
      el('div', { class: 'transport__field' }, [
        el('label', { class: 'transport__legend' }, 'Tempo'),
        this.#tempoSlider,
        this.#tempoLabel,
      ]),
      el('div', { class: 'transport__field' }, [
        el('label', { class: 'transport__legend' }, 'Swing'),
        this.#swingSlider,
        this.#swingLabel,
      ]),
      el('div', { class: 'transport__field' }, [
        el('label', { class: 'transport__legend' }, 'Master'),
        this.#masterSlider,
      ]),
    ]);

    mount(this.#host, layout);
  }
}

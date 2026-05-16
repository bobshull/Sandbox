// Voice factories. Each function schedules a one-shot sound on the given AudioContext
// starting at `time` (audio-clock seconds) routed into `destination`.

function envGain(ctx, time, { attack = 0.001, decay = 0.2, peak = 1, sustain = 0, release = 0.05 } = {}) {
  const g = ctx.createGain();
  g.gain.setValueAtTime(0, time);
  g.gain.linearRampToValueAtTime(peak, time + attack);
  g.gain.exponentialRampToValueAtTime(Math.max(sustain, 0.0001), time + attack + decay);
  g.gain.exponentialRampToValueAtTime(0.0001, time + attack + decay + release);
  return g;
}

function noiseBuffer(ctx, duration = 0.5) {
  const len = Math.floor(ctx.sampleRate * duration);
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
  return buf;
}

export const voices = {
  kick(ctx, time, dest) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(150, time);
    osc.frequency.exponentialRampToValueAtTime(40, time + 0.18);
    gain.gain.setValueAtTime(0.0001, time);
    gain.gain.exponentialRampToValueAtTime(1, time + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.32);
    osc.connect(gain).connect(dest);
    osc.start(time);
    osc.stop(time + 0.4);
  },

  snare(ctx, time, dest) {
    const noise = ctx.createBufferSource();
    noise.buffer = noiseBuffer(ctx, 0.3);
    const noiseFilter = ctx.createBiquadFilter();
    noiseFilter.type = 'highpass';
    noiseFilter.frequency.value = 1500;
    const noiseGain = envGain(ctx, time, { attack: 0.001, decay: 0.12, peak: 0.7, release: 0.05 });
    noise.connect(noiseFilter).connect(noiseGain).connect(dest);
    noise.start(time);
    noise.stop(time + 0.25);

    const osc = ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(220, time);
    osc.frequency.exponentialRampToValueAtTime(110, time + 0.1);
    const oscGain = envGain(ctx, time, { attack: 0.001, decay: 0.08, peak: 0.4, release: 0.04 });
    osc.connect(oscGain).connect(dest);
    osc.start(time);
    osc.stop(time + 0.2);
  },

  hat(ctx, time, dest) {
    const noise = ctx.createBufferSource();
    noise.buffer = noiseBuffer(ctx, 0.08);
    const hp = ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 7000;
    const gain = envGain(ctx, time, { attack: 0.001, decay: 0.04, peak: 0.35, release: 0.02 });
    noise.connect(hp).connect(gain).connect(dest);
    noise.start(time);
    noise.stop(time + 0.08);
  },

  clap(ctx, time, dest) {
    // Multi-burst noise for clap thickness.
    const offsets = [0, 0.012, 0.025, 0.045];
    const merge = ctx.createGain();
    merge.gain.value = 1;
    merge.connect(dest);
    for (const off of offsets) {
      const noise = ctx.createBufferSource();
      noise.buffer = noiseBuffer(ctx, 0.1);
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = 1500;
      bp.Q.value = 0.8;
      const gain = envGain(ctx, time + off, {
        attack: 0.001,
        decay: off === offsets.at(-1) ? 0.12 : 0.02,
        peak: 0.5,
        release: 0.05,
      });
      noise.connect(bp).connect(gain).connect(merge);
      noise.start(time + off);
      noise.stop(time + off + 0.2);
    }
  },

  bass(ctx, time, dest) {
    const osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = 55; // A1
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.Q.value = 6;
    filter.frequency.setValueAtTime(1200, time);
    filter.frequency.exponentialRampToValueAtTime(180, time + 0.25);
    const gain = envGain(ctx, time, { attack: 0.005, decay: 0.18, peak: 0.6, release: 0.08 });
    osc.connect(filter).connect(gain).connect(dest);
    osc.start(time);
    osc.stop(time + 0.35);
  },

  pluck(ctx, time, dest) {
    const osc = ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(523.25, time); // C5
    osc.frequency.exponentialRampToValueAtTime(440, time + 0.2);
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 3000;
    const gain = envGain(ctx, time, { attack: 0.002, decay: 0.18, peak: 0.5, release: 0.1 });
    osc.connect(filter).connect(gain).connect(dest);
    osc.start(time);
    osc.stop(time + 0.4);
  },

  pad(ctx, time, dest) {
    // Two detuned saws → shared lowpass → envelope → destination.
    const gain = envGain(ctx, time, { attack: 0.06, decay: 0.4, peak: 0.35, sustain: 0.15, release: 0.4 });
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 1600;
    filter.connect(gain).connect(dest);

    for (const detune of [-12, 12]) {
      const osc = ctx.createOscillator();
      osc.type = 'sawtooth';
      osc.frequency.value = 261.63; // C4
      osc.detune.value = detune;
      osc.connect(filter);
      osc.start(time);
      osc.stop(time + 0.9);
    }
  },

  perc(ctx, time, dest) {
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, time);
    osc.frequency.exponentialRampToValueAtTime(440, time + 0.08);
    const gain = envGain(ctx, time, { attack: 0.001, decay: 0.06, peak: 0.4, release: 0.03 });
    osc.connect(gain).connect(dest);
    osc.start(time);
    osc.stop(time + 0.12);
  },
};

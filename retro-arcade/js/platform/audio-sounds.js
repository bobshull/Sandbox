export const Priority = Object.freeze({
  LOW: 1,
  MEDIUM: 2,
  HIGH: 3,
  CRITICAL: 4,
});

export function blip(ctx, dest, freq = 440, duration = 0.1, wave = 'square') {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = wave;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.3, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + duration);
  return duration;
}

export function laser(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'square';
  osc.frequency.setValueAtTime(880, ctx.currentTime);
  osc.frequency.exponentialRampToValueAtTime(110, ctx.currentTime + 0.2);
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.2);
  return 0.2;
}

export function explosion(ctx, dest) {
  const bufferSize = ctx.sampleRate * 0.5;
  const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) data[i] = Math.random() * 2 - 1;
  const noise = ctx.createBufferSource();
  noise.buffer = buffer;
  const filter = ctx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(1000, ctx.currentTime);
  filter.frequency.exponentialRampToValueAtTime(100, ctx.currentTime + 0.5);
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(0.4, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5);
  noise.connect(filter).connect(gain).connect(dest);
  noise.start();
  noise.stop(ctx.currentTime + 0.5);
  return 0.5;
}

export function coin(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'square';
  osc.frequency.setValueAtTime(988, ctx.currentTime);
  osc.frequency.setValueAtTime(1318, ctx.currentTime + 0.06);
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.setValueAtTime(0.25, ctx.currentTime + 0.06);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.15);
  return 0.15;
}

export function powerUp(ctx, dest) {
  const notes = [262, 330, 392, 523, 659, 784];
  const spacing = 0.08;
  const total = notes.length * spacing + 0.1;
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(0.2, ctx.currentTime);
  gain.gain.setValueAtTime(0.2, ctx.currentTime + total - 0.1);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + total);
  gain.connect(dest);
  for (let i = 0; i < notes.length; i++) {
    const osc = ctx.createOscillator();
    osc.type = 'square';
    osc.frequency.value = notes[i];
    osc.connect(gain);
    osc.start(ctx.currentTime + i * spacing);
    osc.stop(ctx.currentTime + i * spacing + spacing);
  }
  return total;
}

export function gameOver(ctx, dest) {
  const notes = [523, 494, 466, 440, 415, 392, 370, 349];
  const spacing = 0.12;
  const total = notes.length * spacing + 0.15;
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.setValueAtTime(0.25, ctx.currentTime + total - 0.15);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + total);
  gain.connect(dest);
  for (let i = 0; i < notes.length; i++) {
    const osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = notes[i];
    osc.connect(gain);
    osc.start(ctx.currentTime + i * spacing);
    osc.stop(ctx.currentTime + i * spacing + spacing);
  }
  return total;
}

export function hit(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'square';
  osc.frequency.value = 330;
  gain.gain.setValueAtTime(0.3, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.05);
  return 0.05;
}

export function score(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'square';
  osc.frequency.setValueAtTime(440, ctx.currentTime);
  osc.frequency.setValueAtTime(660, ctx.currentTime + 0.06);
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.12);
  return 0.12;
}

export function menuMove(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.value = 1000;
  gain.gain.setValueAtTime(0.15, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.02);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.02);
  return 0.02;
}

export function menuSelect(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'square';
  osc.frequency.value = 660;
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.08);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.08);
  return 0.08;
}

export function bounce(ctx, dest) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.value = 200;
  gain.gain.setValueAtTime(0.25, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);
  osc.connect(gain).connect(dest);
  osc.start();
  osc.stop(ctx.currentTime + 0.05);
  return 0.05;
}

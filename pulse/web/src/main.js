import { Store } from './state/store.js';
import { AudioEngine } from './audio/AudioEngine.js';
import { Sequencer } from './ui/Sequencer.js';
import { Transport } from './ui/Transport.js';
import { PatternLibrary } from './ui/PatternLibrary.js';
import { Toast } from './ui/Toast.js';
import { PRESETS } from './data/presets.js';

const store = new Store();

const engine = new AudioEngine(() => ({
  tracks: store.state.tracks,
  pattern: store.state.pattern,
  mutes: store.state.mutes,
  volumes: store.state.volumes,
}));
engine.setTempo(store.state.tempo);
engine.setSwing(store.state.swing);

// Mirror engine playhead into store so UI can react.
engine.on('step', ({ step }) => store.setActiveStep(step));

// Keep engine track gains in sync with the store on load events.
store.on('change', ({ section, state }) => {
  if (section === 'load' || section === 'master') {
    engine.setMasterGain(state.masterGain);
    engine.setTempo(state.tempo);
    engine.setSwing(state.swing);
    for (const [trackId, value] of Object.entries(state.volumes)) {
      engine.setTrackGain(trackId, value);
    }
  }
});

const toast = new Toast(document.getElementById('toast-root'));

new Transport({ host: document.getElementById('transport'), store, engine });
new Sequencer({ host: document.getElementById('sequencer-root'), store, engine });
new PatternLibrary({
  host: document.getElementById('pattern-library'),
  store,
  toast,
  onLoad: () => {/* already triggers store.load which propagates */},
});

// Load a default preset so the app isn't empty on first visit.
const first = PRESETS.find(p => p.id === 'lofi-shuffle') ?? PRESETS[0];
if (first) store.loadPattern(first);

// Keyboard shortcuts.
document.addEventListener('keydown', async (e) => {
  if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
  if (e.code === 'Space') {
    e.preventDefault();
    if (engine.isPlaying) engine.stop();
    else await engine.start();
  } else if (e.key.toLowerCase() === 'c') {
    store.clearPattern();
    toast.show('Pattern cleared');
  } else if (e.key.toLowerCase() === 's') {
    e.preventDefault();
    document.querySelector('.btn--primary')?.click();
  }
});

// Surface unexpected errors so the user is not left wondering.
window.addEventListener('error', (e) => {
  console.error(e.error || e.message);
  toast.show('Something went wrong — check the console', { tone: 'warn' });
});
window.addEventListener('unhandledrejection', (e) => {
  console.error(e.reason);
  toast.show('Audio error — try clicking Play again', { tone: 'warn' });
});

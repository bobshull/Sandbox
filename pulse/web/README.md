# Pulse

A lo-fi step sequencer that runs in the browser. Eight synthesized voices, sample-accurate timing, no audio files — every sound is built from oscillators and noise in the Web Audio API.

![pulse-screenshot](docs/screenshot.png)

## What it does

- **16-step grid** across 8 tracks: kick, snare, hat, clap, bass, pluck, pad, perc
- **Sample-accurate scheduling** via a look-ahead scheduler on the Web Audio clock (no `setInterval` drift)
- **Tempo** 60–200 BPM and **swing** 0–60% with bar-length preservation
- **Per-track** volume + mute, plus a master volume
- **Preview taps** — click any track name to audition the voice
- **Built-in presets**: Boom Bap, Lo-Fi Shuffle, House Pulse, Breakbeat, Half Time, Empty
- **Save/load** custom patterns to `localStorage`
- **Export** the current pattern as JSON
- **Keyboard**: `Space` play/stop, `C` clear, `S` save
- **Responsive** layout, accessible labels, visible focus rings

## Setup

```bash
cd pulse
npm install
npm run dev
```

Vite opens the app at `http://localhost:5173`. Modern browser required (Chrome, Firefox, Safari, Edge — anything with the Web Audio API).

### Production build

```bash
npm run build      # outputs dist/
npm run preview    # serves the built bundle
```

The whole bundle is ~22 KB minified, ~7.5 KB gzipped.

## Usage

1. Hit **Play** (or press `Space`). The page must receive a click first to unlock audio — that's just how browsers work.
2. Click cells in the grid to toggle steps. Each beat (every 4th step) is subtly highlighted.
3. Adjust **Tempo**, **Swing**, and the per-track volumes to taste.
4. Mute a track with the `M` button next to its name.
5. Load a preset from the right-hand library, or save your own with the **Save** button (or press `S`).
6. **Export JSON** dumps the current pattern (name, tempo, swing, grid) for sharing or backup.

## Architecture

```
src/
├── main.js               # Composition root — wires store + engine + UI
├── audio/
│   ├── AudioEngine.js    # AudioContext, look-ahead scheduler, transport
│   └── synths.js         # Voice factories (oscillators + envelopes + noise)
├── state/
│   ├── store.js          # Reactive pub/sub state container
│   └── patterns.js       # Pattern persistence (localStorage)
├── ui/
│   ├── Sequencer.js      # The 16-step grid
│   ├── Transport.js      # Play, tempo, swing, master
│   ├── TrackPanel.js     # Per-track row controls (name/mute/volume)
│   ├── PatternLibrary.js # Presets + saved patterns + save/export
│   └── Toast.js          # Lightweight notification rail
├── data/
│   ├── tracks.js         # Track metadata (id, color, voice)
│   └── presets.js        # Built-in grooves
├── utils/
│   ├── dom.js            # `el()` factory + DOM helpers
│   ├── events.js         # Minimal EventEmitter
│   └── storage.js        # localStorage wrapper with error handling
└── styles/
    ├── main.css          # Theme, layout, library, toasts
    ├── controls.css      # Transport + track controls
    └── grid.css          # Sequencer grid + cells
```

**Separation of concerns**

- `state/` knows nothing about audio or the DOM. It's a pure pub/sub.
- `audio/` knows nothing about the DOM. It pulls state through a `getState()` callback so it stays decoupled.
- `ui/` reads from the store and forwards user intent to both the store and the engine.
- `utils/` has no app knowledge — just primitives.

## How the scheduling works

A naive `setInterval(() => playStep(), stepDurationMs)` drifts by tens of milliseconds because JS timers aren't precise. Instead, Pulse uses Chris Wilson's two-clock pattern:

1. Every 25ms, a `setTimeout` loop runs.
2. It looks ahead 100ms on the `AudioContext` clock and schedules every step that falls in that window with sample-accurate timing.
3. Audio nodes are started with `oscillator.start(time)` where `time` is on the audio clock, so the OS sound card fires them at exactly the right moment.

Swing is applied per pair of 16th notes: offbeats are delayed by `swing × stepDuration`, and the following downbeat catches up by the same amount so the bar length stays constant — meaning swing changes the feel without changing the tempo.

## Future ideas

These are intentionally out of scope for v1 but would be natural extensions:

- Per-step velocity / accent
- Pattern chaining into songs
- Sample import (drop in your own WAVs)
- MIDI export
- Pitch per track (currently each track is one fixed note)

## License

MIT

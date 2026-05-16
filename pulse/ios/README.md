# Pulse — iOS (UIKit)

Native iPhone/iPad port of the web `pulse` app. Same architecture, same eight synthesized voices, same step-sequencer feel — built in Swift + UIKit + AVAudioEngine.

> **You need a Mac with Xcode to build this.** It cannot be compiled on Windows.

## Quick start

The repo ships the Swift sources and a [XcodeGen](https://github.com/yonaskolb/XcodeGen) project spec instead of a committed `.xcodeproj`. That way the project file is generated reproducibly from `project.yml` rather than hand-edited.

On macOS:

```bash
# One-time:
brew install xcodegen

# In this folder:
cd ios
xcodegen generate
open Pulse.xcodeproj
```

Pick an iPhone or iPad simulator and hit ⌘R. That's it.

### If you don't want XcodeGen

You can also build this without XcodeGen:

1. In Xcode: **File → New → Project → iOS → App**.
2. Product Name `Pulse`, language Swift, interface UIKit, life-cycle UIKit App Delegate.
3. Delete the auto-generated `ViewController.swift`, `Main.storyboard`, and `Info.plist`.
4. Drag the entire `ios/Pulse/` folder into the project navigator. Choose **Create groups**, target = Pulse.
5. In **Targets → Pulse → Build Settings**, set `INFOPLIST_FILE` to `Pulse/Resources/Info.plist` and `GENERATE_INFOPLIST_FILE` to `NO`.
6. In **Signing & Capabilities**, add **Background Modes → Audio, AirPlay, and Picture in Picture**.

Then ⌘R.

## Architecture

```
ios/Pulse/
├── App/                     # AppDelegate, SceneDelegate
├── Audio/
│   ├── AudioEngine.swift    # AVAudioEngine + sample-accurate scheduler
│   └── Synths.swift         # Pure-DSP voice rendering (one buffer per voice)
├── State/
│   ├── Store.swift          # Single source of truth, Combine publisher
│   └── PatternStore.swift   # UserDefaults persistence
├── Data/
│   ├── Tracks.swift         # Track metadata
│   └── Presets.swift        # Built-in grooves + Pattern model
├── UI/
│   ├── Theme.swift
│   ├── MainViewController.swift
│   ├── TransportView.swift
│   ├── SequencerView.swift
│   ├── TrackHeaderView.swift
│   ├── CellButton.swift
│   ├── PatternLibraryViewController.swift
│   └── ToastView.swift
└── Resources/
    └── Info.plist
```

**Mirrors the web version's separation:**

- `Audio/` has no UIKit imports — pure DSP and AVFoundation.
- `State/` has no UIKit either — just `Foundation` + `Combine`.
- `UI/` reads from the store and forwards intent to the store and engine. No business logic lives here.

## How the audio engine works

Each voice is rendered **once** at app launch from raw math (sines, sawtooths, noise, envelopes) into an `AVAudioPCMBuffer`. Every drum hit is just `playerNode.scheduleBuffer(buf, at: AVAudioTime, options: .interrupts)` — no per-hit allocations, no streaming, no audio files. The whole synth library is in [Pulse/Audio/Synths.swift](Pulse/Audio/Synths.swift).

Each track gets its own `AVAudioPlayerNode` → main mixer, so per-track volume is just `player.volume`.

The scheduler is a `DispatchSourceTimer` ticking every 25ms on a userInteractive queue. On each tick it looks ahead ~120ms on the audio clock (`mach_absolute_time` → `AVAudioTime`) and schedules every step that falls in that window with sample-accurate timing.

Swing is applied per pair of 16th notes: offbeats are delayed by `swing × stepDuration`, and the following downbeat catches up by the same amount — bar length stays constant so changing swing changes the feel, not the tempo.

## Features

- 8 tracks × 16 steps grid with horizontal scroll on narrow screens
- Per-track mute, volume, and tap-to-preview
- Tempo (60–200 BPM) and swing (0–60%)
- 6 built-in presets + unlimited saved patterns (UserDefaults)
- Export pattern JSON via the share sheet
- Background audio (keep playing when locked)
- Dark mode forced (the design only makes sense dark)
- Portrait + landscape, iPhone + iPad

## Bundle ID

The default in `project.yml` is `com.outdoorcap.pulse.Pulse`. Change it before signing for distribution.

## License

MIT

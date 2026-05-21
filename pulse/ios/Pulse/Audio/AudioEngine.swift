import AVFoundation
import Foundation
import Combine

/// Sample-accurate step sequencer driving AVAudioEngine.
/// Each track owns a dedicated AVAudioPlayerNode wired through a per-track mixer
/// into the main mixer, so per-track volume + mute work cleanly.
final class AudioEngine {

    enum Event {
        case started
        case stopped
        case step(Int)
    }

    let events = PassthroughSubject<Event, Never>()

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private let sampleRate: Double

    private let store: Store

    private var players: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let masterMixer = AVAudioMixerNode()

    private struct TrackFXChain {
        let distortion: AVAudioUnitDistortion
        let delay: AVAudioUnitDelay
        let reverb: AVAudioUnitReverb
    }
    private var fxChains: [String: TrackFXChain] = [:]

    private(set) var isPlaying = false

    // Scheduling
    private var schedulerTimer: DispatchSourceTimer?
    private let schedulerQueue = DispatchQueue(label: "pulse.audio.scheduler", qos: .userInteractive)
    private let lookahead: Double = 0.12   // schedule notes within this window (seconds)
    private let tickInterval: DispatchTimeInterval = .milliseconds(25)

    private var currentStep = 0
    private var nextNoteHostTime: Double = 0   // seconds on the engine's render clock
    private var startHostOffset: Double = 0

    init(store: Store) {
        self.store = store
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        self.sampleRate = format.sampleRate
    }

    // MARK: - Setup

    func prepare() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        engine.attach(masterMixer)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = store.masterGain

        for track in Tracks.all {
            let player = AVAudioPlayerNode()
            let dist   = AVAudioUnitDistortion()
            let delay  = AVAudioUnitDelay()
            let reverb = AVAudioUnitReverb()

            for node: AVAudioNode in [player, dist, delay, reverb] { engine.attach(node) }
            engine.connect(player, to: dist,        format: format)
            engine.connect(dist,   to: delay,       format: format)
            engine.connect(delay,  to: reverb,      format: format)
            engine.connect(reverb, to: masterMixer, format: format)

            player.volume = store.volumes(for: 0)[track.id] ?? 1.0

            dist.loadFactoryPreset(.multiDistortedFunk)
            reverb.loadFactoryPreset(.mediumRoom)
            let chain = TrackFXChain(distortion: dist, delay: delay, reverb: reverb)
            applyFX(store.effects[track.id] ?? .default, chain: chain, tempo: store.tempo)

            players[track.id]  = player
            fxChains[track.id] = chain

            // Pre-render the voice once and reuse for every hit.
            let samples = Synths.render(track.voice, kit: store.currentKitId, sampleRate: sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                buf.floatChannelData!.pointee.update(from: src.baseAddress!, count: samples.count)
            }
            buffers[track.id] = buf
        }

        try engine.start()
        for (_, player) in players { player.play() }
    }

    // MARK: - Transport

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        currentStep = 0
        // Begin 50ms in the future to give the audio thread headroom.
        startHostOffset = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        nextNoteHostTime = startHostOffset + 0.05
        events.send(.started)
        runScheduler()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        schedulerTimer?.cancel()
        schedulerTimer = nil
        for (_, player) in players { player.stop(); player.play() }
        events.send(.stopped)
        events.send(.step(-1))
    }

    func setMasterGain(_ value: Float) {
        engine.mainMixerNode.outputVolume = value
    }

    func setTrackGain(_ id: String, _ value: Float) {
        players[id]?.volume = value
    }

    func reloadKit(_ kitId: String) {
        var newBuffers: [String: AVAudioPCMBuffer] = [:]
        for track in Tracks.all {
            let samples = Synths.render(track.voice, kit: kitId, sampleRate: sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                buf.floatChannelData!.pointee.update(from: src.baseAddress!, count: samples.count)
            }
            newBuffers[track.id] = buf
        }
        schedulerQueue.async { [weak self] in self?.buffers = newBuffers }
    }

    /// Triggers a single voice immediately. Used for track-header preview taps.
    func preview(trackId: String) {
        guard let player = players[trackId], let buf = buffers[trackId] else { return }
        player.scheduleBuffer(buf, at: nil, options: [.interrupts], completionHandler: nil)
    }

    // MARK: - FX

    func setTrackEffects(_ id: String, _ fx: TrackEffects) {
        guard let chain = fxChains[id] else { return }
        applyFX(fx, chain: chain, tempo: store.tempo)
    }

    func updateDelayTimes(tempo: Double) {
        for track in Tracks.all {
            guard let chain = fxChains[track.id],
                  let fx = store.effects[track.id] else { continue }
            chain.delay.delayTime = min(fx.delaySyncDivision.quarterNoteMultiplier * (60.0 / tempo), 2.0)
        }
    }

    private func applyFX(_ fx: TrackEffects, chain: TrackFXChain, tempo: Double) {
        chain.distortion.wetDryMix = fx.distortionWet
        chain.delay.wetDryMix      = fx.delayWet
        chain.delay.delayTime      = min(fx.delaySyncDivision.quarterNoteMultiplier * (60.0 / tempo), 2.0)
        chain.delay.feedback       = 25
        chain.delay.lowPassCutoff  = 15000
        chain.reverb.wetDryMix     = fx.reverbWet
    }

    // MARK: - Scheduler

    private func stepDuration() -> Double {
        // 16th-note duration: 60 / BPM / 4
        return 60.0 / store.tempo / 4.0
    }

    private func runScheduler() {
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: tickInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        schedulerTimer = timer
    }

    private func tick() {
        guard isPlaying else { return }
        let now = AVAudioTime.seconds(forHostTime: mach_absolute_time())

        while nextNoteHostTime < now + lookahead {
            schedule(step: currentStep, atHostSeconds: nextNoteHostTime)
            advance()
        }
    }

    func applyBarSettings(barIndex: Int) {
        let vols = store.volumes(for: barIndex)
        let efxs = store.effects(for: barIndex)
        for track in Tracks.all {
            players[track.id]?.volume = vols[track.id] ?? 1.0
            if let chain = fxChains[track.id] {
                applyFX(efxs[track.id] ?? .default, chain: chain, tempo: store.tempo)
            }
        }
    }

    private func schedule(step: Int, atHostSeconds hostSeconds: Double) {
        let snap = store.audioSnapshot()

        // Switch to the correct bar's settings at each bar boundary
        if step == snap.sequenceStart || (snap.sequenceLength == 32 && step == snap.sequenceStart + 16) {
            let barIndex = step / 16
            applyBarSettings(barIndex: barIndex)
        }

        for track in Tracks.all {
            guard snap.mutes[track.id] != true,
                  let row = snap.rows[track.id], row.indices.contains(step), row[step],
                  let player = players[track.id],
                  let buf = buffers[track.id]
            else { continue }

            let host = AVAudioTime.hostTime(forSeconds: max(hostSeconds, 0))
            let when = AVAudioTime(hostTime: host)
            player.scheduleBuffer(buf, at: when, options: [.interrupts], completionHandler: nil)
        }

        // Notify the UI on main.
        DispatchQueue.main.async { [weak self] in
            self?.events.send(.step(step))
        }
    }

    private func advance() {
        let base = stepDuration()
        let snap = store.audioSnapshot()
        let seqStart = snap.sequenceStart
        let seqLen   = snap.sequenceLength
        let raw = (currentStep - seqStart + 1) % seqLen
        let nextStep = seqStart + (raw >= 0 ? raw : raw + seqLen)
        // Swing: delay offbeats by swing*base, compensate on the following downbeat.
        let nextIsOff = (nextStep % 2 == 1)
        let factor = nextIsOff ? (1 + store.swing) : (1 - store.swing)
        nextNoteHostTime += base * factor
        currentStep = nextStep
    }

    // MARK: - Export

    /// Renders `bars` bars offline into an AAC/M4A file and returns the URL.
    /// Runs entirely on a background thread; calls back on main.
    func exportMix(bars: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !buffers.isEmpty else {
            completion(.failure(ExportError.notPrepared)); return
        }

        let snap          = store.audioSnapshot()
        let bar0Volumes   = store.volumes(for: 0)
        let bar1Volumes   = store.volumes(for: 1)
        let master        = store.masterGain
        let tempo         = store.tempo
        let swing         = store.swing
        let patternLength = snap.patternLength
        let captured      = buffers
        let sr            = sampleRate

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1 — compute per-step start times (seconds from t=0)
                let stepDur   = 60.0 / tempo / 4.0
                let total     = bars * Tracks.stepCount
                var times     = [Double](repeating: 0, count: total)
                var t         = 0.0
                for i in 0..<total {
                    times[i] = t
                    let next   = (i + 1) % Tracks.stepCount
                    let isOff  = (next % 2 == 1)
                    t += stepDur * (isOff ? 1.0 + swing : 1.0 - swing)
                }
                let tail          = Double(captured.values.map { Int($0.frameLength) }.max() ?? 0) / sr
                let totalFrames   = Int(ceil((t + tail) * sr))

                // 2 — mix tracks into a mono float array
                var out = [Float](repeating: 0, count: totalFrames)
                for step in 0..<total {
                    let patStep = step % patternLength
                    let offset  = Int(times[step] * sr)
                    for track in Tracks.all {
                        guard snap.mutes[track.id] != true,
                              let row = snap.rows[track.id],
                              row.indices.contains(patStep), row[patStep],
                              let buf = captured[track.id],
                              let data = buf.floatChannelData?.pointee else { continue }
                        let barIdx = patStep / 16
                        let vol   = Float((barIdx == 1 ? bar1Volumes : bar0Volumes)[track.id] ?? 1.0)
                        let count = Int(buf.frameLength)
                        for i in 0..<count {
                            let idx = offset + i
                            if idx < totalFrames { out[idx] += data[i] * vol }
                        }
                    }
                }

                // 3 — master gain + tanh soft limiter
                for i in 0..<totalFrames { out[i] = tanh(out[i] * master) }

                // 4 — write PCM to a temp CAF
                let fmt    = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
                let cafURL = FileManager.default.temporaryDirectory.appendingPathComponent("pulse_mix.caf")
                try? FileManager.default.removeItem(at: cafURL)
                let cafFile = try AVAudioFile(forWriting: cafURL, settings: fmt.settings)
                let pcm     = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(totalFrames))!
                pcm.frameLength = AVAudioFrameCount(totalFrames)
                out.withUnsafeBufferPointer { src in
                    pcm.floatChannelData!.pointee.update(from: src.baseAddress!, count: totalFrames)
                }
                try cafFile.write(from: pcm)

                // 5 — transcode CAF → M4A (AAC)
                let ts     = Int(Date().timeIntervalSince1970)
                let m4aURL = FileManager.default.temporaryDirectory.appendingPathComponent("Pulse_Mix_\(ts).m4a")
                try? FileManager.default.removeItem(at: m4aURL)

                let asset   = AVURLAsset(url: cafURL)
                guard let session = AVAssetExportSession(asset: asset,
                                                         presetName: AVAssetExportPresetAppleM4A) else {
                    throw ExportError.sessionUnavailable
                }
                session.outputURL      = m4aURL
                session.outputFileType = .m4a

                let sem = DispatchSemaphore(value: 0)
                session.exportAsynchronously { sem.signal() }
                sem.wait()

                if session.status == .completed {
                    DispatchQueue.main.async { completion(.success(m4aURL)) }
                } else {
                    throw session.error ?? ExportError.exportFailed
                }

            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

enum ExportError: LocalizedError {
    case notPrepared, sessionUnavailable, exportFailed
    var errorDescription: String? {
        switch self {
        case .notPrepared:        return "Audio engine not ready — play the mix first"
        case .sessionUnavailable: return "Export session unavailable"
        case .exportFailed:       return "Export failed"
        }
    }
}

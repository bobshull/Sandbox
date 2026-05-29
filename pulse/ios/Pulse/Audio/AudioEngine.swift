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

    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var accentBuffers: [String: AVAudioPCMBuffer] = [:]
    private static let accentGains: [String: Float] = [
        "kick": 2.00, "snare": 2.00, "hat": 2.00,
        "clap": 2.00, "bass": 1.80, "pluck": 1.80,
        "pad":  1.60, "perc": 2.00,
    ]
    private let masterMixer = AVAudioMixerNode()

    private struct TrackFXChain {
        let player: AVAudioPlayerNode
        let eq: AVAudioUnitEQ
        let pitchNode: AVAudioUnitTimePitch
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
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        self.sampleRate = format.sampleRate
    }

    // MARK: - Setup

    func prepare() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        engine.attach(masterMixer)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: format)
        let snap = store.audioSnapshot()
        engine.mainMixerNode.outputVolume = snap.masterGain

        for track in Tracks.all {
            let player = AVAudioPlayerNode()
            let eq     = AVAudioUnitEQ(numberOfBands: 1)
            let ptch   = AVAudioUnitTimePitch()
            let dist   = AVAudioUnitDistortion()
            let delay  = AVAudioUnitDelay()
            let reverb = AVAudioUnitReverb()

            eq.bands[0].filterType = .lowPass
            eq.bands[0].bypass     = true
            dist.loadFactoryPreset(.multiDistortedFunk)
            reverb.loadFactoryPreset(.mediumRoom)

            for node: AVAudioNode in [player, eq, ptch, dist, delay, reverb] { engine.attach(node) }
            engine.connect(player, to: eq,          format: format)
            engine.connect(eq,     to: ptch,        format: format)
            engine.connect(ptch,   to: dist,        format: format)
            engine.connect(dist,   to: delay,       format: format)
            engine.connect(delay,  to: reverb,      format: format)
            engine.connect(reverb, to: masterMixer, format: format)

            player.volume = snap.barVolumes[0][track.id] ?? 1.0

            let chain = TrackFXChain(player: player, eq: eq, pitchNode: ptch,
                                     distortion: dist, delay: delay, reverb: reverb)
            applyFX(snap.barEffects[0][track.id] ?? .default, chain: chain, tempo: snap.tempo)

            fxChains[track.id] = chain

            // Pre-render the voice once and reuse for every hit.
            let samples = Synths.render(track.voice, kit: store.currentKitId, sampleRate: sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                let channels = buf.floatChannelData!
                channels[0].update(from: src.baseAddress!, count: samples.count)
                channels[1].update(from: src.baseAddress!, count: samples.count)
            }
            buffers[track.id] = buf
            let gain = AudioEngine.accentGains[track.id] ?? 1.25
            accentBuffers[track.id] = makeAccentBuffer(from: buf, gain: gain)
        }

        try engine.start()
        for (_, chain) in fxChains { chain.player.play() }
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
        for (_, chain) in fxChains { chain.player.stop(); chain.player.play() }
        events.send(.stopped)
        events.send(.step(-1))
    }

    func setMasterGain(_ value: Float) {
        engine.mainMixerNode.outputVolume = value
    }

    func setTrackGain(_ id: String, _ value: Float) {
        fxChains[id]?.player.volume = value
    }

    func reloadKit(_ kitId: String) {
        var newBuffers: [String: AVAudioPCMBuffer] = [:]
        for track in Tracks.all {
            let samples = Synths.render(track.voice, kit: kitId, sampleRate: sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                let channels = buf.floatChannelData!
                channels[0].update(from: src.baseAddress!, count: samples.count)
                channels[1].update(from: src.baseAddress!, count: samples.count)
            }
            newBuffers[track.id] = buf
        }
        var newAccentBuffers: [String: AVAudioPCMBuffer] = [:]
        for (id, buf) in newBuffers {
            let gain = AudioEngine.accentGains[id] ?? 1.25
            newAccentBuffers[id] = makeAccentBuffer(from: buf, gain: gain)
        }
        schedulerQueue.async { [weak self] in
            self?.buffers = newBuffers
            self?.accentBuffers = newAccentBuffers
        }
    }

    private func makeAccentBuffer(from buf: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
        let out = AVAudioPCMBuffer(pcmFormat: buf.format, frameCapacity: buf.frameCapacity)!
        out.frameLength = buf.frameLength
        let count = Int(buf.frameLength)
        guard let srcCh = buf.floatChannelData, let dstCh = out.floatChannelData else { return out }
        for ch in 0..<Int(buf.format.channelCount) {
            for i in 0..<count { dstCh[ch][i] = srcCh[ch][i] * gain }
        }
        return out
    }

    /// Triggers a single voice immediately. Used for track-header preview taps.
    func preview(trackId: String) {
        guard let chain = fxChains[trackId], let buf = buffers[trackId] else { return }
        chain.player.scheduleBuffer(buf, at: nil, options: [.interrupts], completionHandler: nil)
    }

    // MARK: - FX

    func setTrackEffects(_ id: String, _ fx: TrackEffects) {
        guard let chain = fxChains[id] else { return }
        applyFX(fx, chain: chain, tempo: store.audioSnapshot().tempo)
    }

    func updateDelayTimes(tempo: Double) {
        let snap = store.audioSnapshot()
        for track in Tracks.all {
            guard let chain = fxChains[track.id],
                  let fx = snap.barEffects[0][track.id] else { continue }
            chain.delay.delayTime = min(fx.delaySyncDivision.quarterNoteMultiplier * (60.0 / tempo), 2.0)
        }
    }

    private func applyFX(_ fx: TrackEffects, chain: TrackFXChain, tempo: Double) {
        chain.player.pan = fx.pan
        chain.pitchNode.pitch = fx.pitch * 100   // semitones → cents

        let filterOpen = fx.filterCutoff >= 100
        chain.eq.bands[0].bypass    = filterOpen
        chain.eq.bands[0].frequency = TrackEffects.filterFrequency(from: fx.filterCutoff)

        chain.distortion.wetDryMix = fx.distortionWet
        chain.delay.wetDryMix      = fx.delayWet
        chain.delay.delayTime      = min(fx.delaySyncDivision.quarterNoteMultiplier * (60.0 / tempo), 2.0)
        chain.delay.feedback       = 25
        chain.delay.lowPassCutoff  = 15000
        chain.reverb.wetDryMix     = fx.reverbWet
    }

    private func makeFXChain(in targetEngine: AVAudioEngine, output: AVAudioNode) -> TrackFXChain {
        let player = AVAudioPlayerNode()
        let eq     = AVAudioUnitEQ(numberOfBands: 1)
        let ptch   = AVAudioUnitTimePitch()
        let dist   = AVAudioUnitDistortion()
        let delay  = AVAudioUnitDelay()
        let reverb = AVAudioUnitReverb()

        eq.bands[0].filterType = .lowPass
        eq.bands[0].bypass     = true
        dist.loadFactoryPreset(.multiDistortedFunk)
        reverb.loadFactoryPreset(.mediumRoom)

        for node: AVAudioNode in [player, eq, ptch, dist, delay, reverb] { targetEngine.attach(node) }
        targetEngine.connect(player, to: eq,     format: format)
        targetEngine.connect(eq,     to: ptch,   format: format)
        targetEngine.connect(ptch,   to: dist,   format: format)
        targetEngine.connect(dist,   to: delay,  format: format)
        targetEngine.connect(delay,  to: reverb, format: format)
        targetEngine.connect(reverb, to: output, format: format)

        return TrackFXChain(player: player, eq: eq, pitchNode: ptch,
                            distortion: dist, delay: delay, reverb: reverb)
    }

    // MARK: - Scheduler

    private func stepDuration(tempo: Double) -> Double {
        // 16th-note duration: 60 / BPM / 4
        return 60.0 / tempo / 4.0
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

    func applyBarSettings(barIndex: Int, snapshot: Store.AudioSnapshot) {
        let safeIndex = min(max(barIndex, 0), snapshot.barVolumes.count - 1)
        let vols = snapshot.barVolumes[safeIndex]
        let efxs = snapshot.barEffects[safeIndex]
        for track in Tracks.all {
            guard let chain = fxChains[track.id] else { continue }
            chain.player.volume = vols[track.id] ?? 1.0
            applyFX(efxs[track.id] ?? .default, chain: chain, tempo: snapshot.tempo)
        }
    }

    private func schedule(step: Int, atHostSeconds hostSeconds: Double) {
        let snap = store.audioSnapshot()

        // Switch to the correct bar's settings at each bar boundary
        if step == snap.sequenceStart || (snap.sequenceLength == 32 && step == snap.sequenceStart + 16) {
            let barIndex = step / 16
            applyBarSettings(barIndex: barIndex, snapshot: snap)
        }

        let barIndex = step / 16
        let safeBarIndex = min(max(barIndex, 0), snap.barEffects.count - 1)
        let barEffects = snap.barEffects[safeBarIndex]

        for track in Tracks.all {
            guard snap.mutes[track.id] != true,
                  let row = snap.rows[track.id], row.indices.contains(step), row[step],
                  let chain = fxChains[track.id],
                  let normalBuf = buffers[track.id]
            else { continue }

            let isAccented = snap.accents[track.id]?.indices.contains(step) == true
                          && (snap.accents[track.id]?[step] ?? false)
            let buf = isAccented ? (accentBuffers[track.id] ?? normalBuf) : normalBuf
            #if DEBUG
            if isAccented {
                let gain = AudioEngine.accentGains[track.id] ?? 1.25
                print("[Pulse] accent hit: \(track.id) step=\(step) gain=\(gain)×")
            }
            #endif

            var hitTime = hostSeconds
            let humanize = Double(barEffects[track.id]?.humanize ?? 0)
            if humanize > 0 {
                hitTime += Double.random(in: -1...1) * humanize / 100.0 * stepDuration(tempo: snap.tempo) * 0.3
            }

            let host = AVAudioTime.hostTime(forSeconds: max(hitTime, 0))
            let when = AVAudioTime(hostTime: host)
            chain.player.scheduleBuffer(buf, at: when, options: [.interrupts], completionHandler: nil)
        }

        // Notify the UI on main.
        DispatchQueue.main.async { [weak self] in
            self?.events.send(.step(step))
        }
    }

    private func advance() {
        let snap = store.audioSnapshot()
        let base = stepDuration(tempo: snap.tempo)
        let seqStart = snap.sequenceStart
        let seqLen   = snap.sequenceLength
        let raw = (currentStep - seqStart + 1) % seqLen
        let nextStep = seqStart + (raw >= 0 ? raw : raw + seqLen)
        // Swing: delay offbeats by swing*base, compensate on the following downbeat.
        let nextIsOff = (nextStep % 2 == 1)
        let factor = nextIsOff ? (1 + snap.swing) : (1 - snap.swing)
        nextNoteHostTime += base * factor
        currentStep = nextStep
    }

    // MARK: - Export

    /// Renders `reps` full pattern loops offline into a WAV or AAC/M4A file and returns the URL.
    /// Runs entirely on a background thread; calls back on main.
    func exportMix(reps: Int, format: ExportFormat, completion: @escaping (Result<URL, Error>) -> Void) {
        var captured: [String: AVAudioPCMBuffer] = [:]
        var capturedAccentBuffers: [String: AVAudioPCMBuffer] = [:]
        schedulerQueue.sync {
            captured = buffers
            capturedAccentBuffers = accentBuffers
        }
        guard !captured.isEmpty else {
            completion(.failure(ExportError.notPrepared)); return
        }

        let snap          = store.audioSnapshot()
        let patternLength = snap.patternLength
        let sr            = sampleRate

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let stepDur = 60.0 / snap.tempo / 4.0
                let totalSteps = reps * patternLength
                var stepFrames = [AVAudioFramePosition](repeating: 0, count: totalSteps)
                var time = 0.0
                for i in 0..<totalSteps {
                    stepFrames[i] = AVAudioFramePosition((time * sr).rounded())
                    let nextStep = (i + 1) % Tracks.stepCount
                    let nextIsOffbeat = nextStep % 2 == 1
                    time += stepDur * (nextIsOffbeat ? 1.0 + snap.swing : 1.0 - snap.swing)
                }

                let loopEndFrame = AVAudioFramePosition((time * sr).rounded())
                let longestHit = AVAudioFramePosition(captured.values.map { Int($0.frameLength) }.max() ?? 0)
                let tailFrames = AVAudioFramePosition((3.0 * sr).rounded()) + longestHit
                let totalFrames = loopEndFrame + tailFrames

                let offlineEngine = AVAudioEngine()
                offlineEngine.mainMixerNode.outputVolume = snap.masterGain
                var exportChains: [String: TrackFXChain] = [:]
                for track in Tracks.all {
                    let chain = self.makeFXChain(in: offlineEngine, output: offlineEngine.mainMixerNode)
                    exportChains[track.id] = chain
                }

                try offlineEngine.enableManualRenderingMode(.offline,
                                                            format: self.format,
                                                            maximumFrameCount: 4096)
                try offlineEngine.start()

                var boundaries: [(frame: AVAudioFramePosition, bar: Int)] = []
                for rep in 0..<reps {
                    let start = rep * patternLength
                    if start < stepFrames.count {
                        boundaries.append((stepFrames[start], 0))
                    }
                    if patternLength == 32, start + 16 < stepFrames.count {
                        boundaries.append((stepFrames[start + 16], 1))
                    }
                }
                boundaries.sort { $0.frame < $1.frame }

                func applyExportBar(_ bar: Int) {
                    let safeBar = min(max(bar, 0), snap.barVolumes.count - 1)
                    let volumes = snap.barVolumes[safeBar]
                    let effects = snap.barEffects[safeBar]
                    for track in Tracks.all {
                        guard let chain = exportChains[track.id] else { continue }
                        chain.player.volume = volumes[track.id] ?? 1.0
                        self.applyFX(effects[track.id] ?? .default, chain: chain, tempo: snap.tempo)
                    }
                }

                applyExportBar(0)
                for chain in exportChains.values { chain.player.play() }

                for step in 0..<totalSteps {
                    let patStep = step % patternLength
                    let barIndex = patStep / 16
                    let safeBar = min(max(barIndex, 0), snap.barEffects.count - 1)
                    let barEffects = snap.barEffects[safeBar]
                    for track in Tracks.all {
                        guard snap.mutes[track.id] != true,
                              let row = snap.rows[track.id],
                              row.indices.contains(patStep), row[patStep],
                              let chain = exportChains[track.id],
                              let normalBuf = captured[track.id]
                        else { continue }

                        let isAccented = snap.accents[track.id]?.indices.contains(patStep) == true
                                      && (snap.accents[track.id]?[patStep] ?? false)
                        let buf = isAccented ? (capturedAccentBuffers[track.id] ?? normalBuf) : normalBuf
                        let humanize = Double(barEffects[track.id]?.humanize ?? 0)
                        let jitter = humanize > 0
                            ? Double.random(in: -1...1) * humanize / 100.0 * stepDur * 0.3
                            : 0
                        let sampleTime = max(stepFrames[step] + AVAudioFramePosition((jitter * sr).rounded()), 0)
                        let when = AVAudioTime(sampleTime: sampleTime, atRate: sr)
                        chain.player.scheduleBuffer(buf, at: when, options: [.interrupts], completionHandler: nil)
                    }
                }

                let ts        = Int(Date().timeIntervalSince1970)
                let exportFmt = format
                let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("Pulse_Mix_\(ts).wav")
                let pcmURL = FileManager.default.temporaryDirectory.appendingPathComponent("pulse_mix_\(ts).caf")
                let renderURL = exportFmt == .wav ? wavURL : pcmURL
                try? FileManager.default.removeItem(at: renderURL)
                let renderFile = try AVAudioFile(forWriting: renderURL, settings: offlineEngine.manualRenderingFormat.settings)
                let renderBuffer = AVAudioPCMBuffer(pcmFormat: offlineEngine.manualRenderingFormat,
                                                    frameCapacity: offlineEngine.manualRenderingMaximumFrameCount)!

                var renderedFrames: AVAudioFramePosition = 0
                var boundaryIndex = 0
                while renderedFrames < totalFrames {
                    while boundaryIndex < boundaries.count && boundaries[boundaryIndex].frame <= renderedFrames {
                        applyExportBar(boundaries[boundaryIndex].bar)
                        boundaryIndex += 1
                    }

                    let nextBoundary = boundaryIndex < boundaries.count ? boundaries[boundaryIndex].frame : totalFrames
                    let framesUntilBoundary = max(nextBoundary - renderedFrames, 1)
                    let remainingFrames = totalFrames - renderedFrames
                    let framesToRender = AVAudioFrameCount(min(AVAudioFramePosition(offlineEngine.manualRenderingMaximumFrameCount),
                                                              min(remainingFrames, framesUntilBoundary)))

                    switch try offlineEngine.renderOffline(framesToRender, to: renderBuffer) {
                    case .success:
                        try renderFile.write(from: renderBuffer)
                        renderedFrames += AVAudioFramePosition(renderBuffer.frameLength)
                    case .insufficientDataFromInputNode:
                        try renderFile.write(from: renderBuffer)
                        renderedFrames += AVAudioFramePosition(renderBuffer.frameLength)
                    case .cannotDoInCurrentContext:
                        continue
                    case .error:
                        throw ExportError.renderFailed
                    @unknown default:
                        throw ExportError.renderFailed
                    }
                }

                offlineEngine.stop()

                if exportFmt == .wav {
                    DispatchQueue.main.async { completion(.success(wavURL)) }
                } else {
                    let m4aURL = FileManager.default.temporaryDirectory.appendingPathComponent("Pulse_Mix_\(ts).m4a")
                    try? FileManager.default.removeItem(at: m4aURL)

                    let asset = AVURLAsset(url: pcmURL)
                    guard let session = AVAssetExportSession(asset: asset,
                                                             presetName: AVAssetExportPresetAppleM4A) else {
                        throw ExportError.sessionUnavailable
                    }
                    session.outputURL      = m4aURL
                    session.outputFileType = .m4a

                    let sem = DispatchSemaphore(value: 0)
                    session.exportAsynchronously { sem.signal() }
                    sem.wait()
                    try? FileManager.default.removeItem(at: pcmURL)

                    if session.status == .completed {
                        DispatchQueue.main.async { completion(.success(m4aURL)) }
                    } else {
                        throw session.error ?? ExportError.exportFailed
                    }
                }

            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

enum ExportError: LocalizedError {
    case notPrepared, sessionUnavailable, exportFailed, renderFailed
    var errorDescription: String? {
        switch self {
        case .notPrepared:        return "Audio engine not ready — play the mix first"
        case .sessionUnavailable: return "Export session unavailable"
        case .exportFailed:       return "Export failed"
        case .renderFailed:       return "Offline render failed"
        }
    }
}

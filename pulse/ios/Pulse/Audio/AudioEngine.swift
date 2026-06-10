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
        case engineFailed
    }

    let events = PassthroughSubject<Event, Never>()

    // Rebuilt after a media services reset. Reassigned on the main thread only.
    private var engine = AVAudioEngine()
    private let format: AVAudioFormat
    private let sampleRate: Double

    private let store: Store

    // schedulerQueue only.
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var accentBuffers: [String: AVAudioPCMBuffer] = [:]
    private static let accentGains: [String: Float] = [
        "kick": 2.00, "snare": 2.00, "hat": 2.00,
        "clap": 2.00, "bass": 1.80, "pluck": 1.80,
        "pad":  1.60, "perc": 2.00,
    ]
    // Recreated alongside the engine after a media services reset. Main thread only.
    private var masterMixer = AVAudioMixerNode()

    private struct TrackFXChain {
        let player: AVAudioPlayerNode
        let eq: AVAudioUnitEQ
        let pitchNode: AVAudioUnitTimePitch
        let distortion: AVAudioUnitDistortion
        let delay: AVAudioUnitDelay
        let reverb: AVAudioUnitReverb
    }
    // schedulerQueue only (swapped wholesale during graph builds).
    private var fxChains: [String: TrackFXChain] = [:]

    private let stateLock = NSLock()
    private var _isPlaying = false
    /// Thread-safe transport flag, readable from any thread.
    var isPlaying: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _isPlaying
    }

    /// True once prepare() succeeded and the graph is alive; false when prepare
    /// or a post-reset rebuild failed. The UI gates playback/export on this.
    /// Written on the main thread only.
    private(set) var isReady = false
    private var observers: [NSObjectProtocol] = []

    // Scheduling — all of this state lives on schedulerQueue only. The timer is
    // created and cancelled there, so a cancelled timer can never have an
    // in-flight tick mutating state behind a restart.
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
        try configureSession()
        buildGraph()

        // Pre-render each voice once and reuse for every hit.
        let rendered = renderVoiceBuffers(kit: store.currentKitId)
        schedulerQueue.sync {
            buffers = rendered.normal
            accentBuffers = rendered.accent
        }

        try engine.start()
        schedulerQueue.async { [weak self] in self?.playAllPlayersIfEngineRunning() }
        isReady = true
        installObservers()
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    /// Attaches a fresh master mixer and per-track FX chains to the current
    /// engine and publishes them to the scheduler queue. Called from prepare()
    /// and again with a brand-new engine after a media services reset.
    private func buildGraph() {
        let snap = store.audioSnapshot()
        masterMixer = AVAudioMixerNode()
        engine.attach(masterMixer)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = snap.masterGain

        var newChains: [String: TrackFXChain] = [:]
        for track in Tracks.all {
            let chain = makeFXChain(in: engine, output: masterMixer)
            chain.player.volume = snap.barVolumes[0][track.id] ?? 1.0
            applyFX(snap.barEffects[0][track.id] ?? .default, chain: chain, tempo: snap.tempo)
            newChains[track.id] = chain
        }
        schedulerQueue.sync { fxChains = newChains }
    }

    private func renderVoiceBuffers(kit: String) -> (normal: [String: AVAudioPCMBuffer],
                                                     accent: [String: AVAudioPCMBuffer]) {
        var normal: [String: AVAudioPCMBuffer] = [:]
        var accent: [String: AVAudioPCMBuffer] = [:]
        for track in Tracks.all {
            let samples = Synths.render(track.voice, kit: kit, sampleRate: sampleRate)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buf.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                let channels = buf.floatChannelData!
                channels[0].update(from: src.baseAddress!, count: samples.count)
                channels[1].update(from: src.baseAddress!, count: samples.count)
            }
            normal[track.id] = buf
            let gain = AudioEngine.accentGains[track.id] ?? 1.25
            accent[track.id] = makeAccentBuffer(from: buf, gain: gain)
        }
        return (normal, accent)
    }

    // MARK: - Transport

    func start() {
        stateLock.lock()
        guard !_isPlaying else { stateLock.unlock(); return }
        _isPlaying = true
        stateLock.unlock()

        guard ensureEngineRunning() else {
            stateLock.lock(); _isPlaying = false; stateLock.unlock()
            events.send(.engineFailed)
            return
        }

        events.send(.started)
        schedulerQueue.async { [weak self] in self?.beginTransport() }
    }

    func stop() {
        stateLock.lock()
        guard _isPlaying else { stateLock.unlock(); return }
        _isPlaying = false
        stateLock.unlock()

        schedulerQueue.async { [weak self] in self?.endTransport() }
        events.send(.stopped)
        events.send(.step(-1))
    }

    /// schedulerQueue only.
    private func beginTransport() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
        currentStep = 0
        // Begin 50ms in the future to give the audio thread headroom.
        startHostOffset = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        nextNoteHostTime = startHostOffset + 0.05
        playAllPlayersIfEngineRunning()

        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: tickInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        schedulerTimer = timer
    }

    /// schedulerQueue only.
    private func endTransport() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
        // Flush scheduled-but-unplayed hits. Players restart (engine permitting)
        // on the next transport start or preview.
        for (_, chain) in fxChains { chain.player.stop() }
    }

    /// schedulerQueue only. AVAudioPlayerNode.play() raises if the engine is not
    /// running (e.g. mid-interruption), so always guard.
    private func playAllPlayersIfEngineRunning() {
        guard engine.isRunning else { return }
        for (_, chain) in fxChains { chain.player.play() }
    }

    func setMasterGain(_ value: Float) {
        engine.mainMixerNode.outputVolume = value
    }

    func setTrackGain(_ id: String, _ value: Float) {
        schedulerQueue.async { [weak self] in
            self?.fxChains[id]?.player.volume = value
        }
    }

    func reloadKit(_ kitId: String) {
        let rendered = renderVoiceBuffers(kit: kitId)
        schedulerQueue.async { [weak self] in
            self?.buffers = rendered.normal
            self?.accentBuffers = rendered.accent
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
    /// Hops to the scheduler queue so it can never race a kit-reload buffer swap,
    /// and restarts the engine first if it idled in the background.
    func preview(trackId: String) {
        guard ensureEngineRunning() else { return }
        schedulerQueue.async { [weak self] in
            guard let self,
                  let chain = self.fxChains[trackId],
                  let buf = self.buffers[trackId],
                  self.engine.isRunning else { return }
            chain.player.play()
            chain.player.scheduleBuffer(buf, at: nil, options: [.interrupts], completionHandler: nil)
        }
    }

    // MARK: - FX

    func setTrackEffects(_ id: String, _ fx: TrackEffects) {
        let tempo = store.audioSnapshot().tempo
        schedulerQueue.async { [weak self] in
            guard let self, let chain = self.fxChains[id] else { return }
            self.applyFX(fx, chain: chain, tempo: tempo)
        }
    }

    func updateDelayTimes(tempo: Double) {
        let snap = store.audioSnapshot()
        schedulerQueue.async { [weak self] in
            guard let self else { return }
            for track in Tracks.all {
                guard let chain = self.fxChains[track.id],
                      let fx = snap.barEffects[0][track.id] else { continue }
                chain.delay.delayTime = min(fx.delaySyncDivision.quarterNoteMultiplier * (60.0 / tempo), 2.0)
            }
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

    private func applyEndFade(to buffer: AVAudioPCMBuffer,
                              renderedStartFrame: AVAudioFramePosition,
                              totalFrames: AVAudioFramePosition,
                              fadeFrames: AVAudioFramePosition) {
        guard fadeFrames > 0,
              let channels = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let fadeStart = max(totalFrames - fadeFrames, 0)
        guard renderedStartFrame + AVAudioFramePosition(frameCount) > fadeStart else { return }

        for frame in 0..<frameCount {
            let absoluteFrame = renderedStartFrame + AVAudioFramePosition(frame)
            guard absoluteFrame >= fadeStart else { continue }
            let remaining = max(totalFrames - absoluteFrame, 0)
            let gain = Float(remaining) / Float(fadeFrames)
            for channel in 0..<Int(buffer.format.channelCount) {
                channels[channel][frame] *= gain
            }
        }
    }

    private func deterministicJitter(trackId: String,
                                     step: Int,
                                     seed: UInt64,
                                     amount: Double,
                                     stepDuration: Double) -> Double {
        GrooveTiming.deterministicJitter(trackId: trackId, step: step, seed: seed,
                                         amount: amount, stepDuration: stepDuration)
    }

    // MARK: - Scheduler

    private func stepDuration(tempo: Double) -> Double {
        // 16th-note duration: 60 / BPM / 4
        return 60.0 / tempo / 4.0
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
                hitTime += deterministicJitter(trackId: track.id,
                                               step: step,
                                               seed: snap.grooveSeed,
                                               amount: humanize,
                                               stepDuration: stepDuration(tempo: snap.tempo))
            }

            let host = AVAudioTime.hostTime(forSeconds: max(hitTime, 0))
            let when = AVAudioTime(hostTime: host)
            chain.player.scheduleBuffer(buf, at: when, options: [.interrupts], completionHandler: nil)
        }

        // Notify the UI on main; drop the event if the transport stopped in the
        // meantime so a stale playhead never repaints after stop.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPlaying else { return }
            self.events.send(.step(step))
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

    // MARK: - Lifecycle

    /// Starts the session and engine if they are not running (after background
    /// idling, an interruption, or a config change). Main thread only.
    /// Returns false when the engine is unavailable.
    @discardableResult
    private func ensureEngineRunning() -> Bool {
        guard isReady else { return false }
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            schedulerQueue.async { [weak self] in self?.playAllPlayersIfEngineRunning() }
            return true
        } catch {
            return false
        }
    }

    /// Called by the UI layer when the app enters the background. Playing
    /// transport is legitimate background audio and is left alone; otherwise the
    /// engine pauses so the app stops rendering silence and can suspend.
    func handleAppBackgrounded() {
        perform(actions: AudioLifecyclePolicy.actions(for: .appBackgrounded, isPlaying: isPlaying))
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification,
                                        object: session, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                        object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.perform(actions: AudioLifecyclePolicy.actions(for: .mediaServicesReset,
                                                               isPlaying: self.isPlaying))
        })
        // object is nil because the engine instance can be replaced after a
        // reset; filter by identity so offline export engines are ignored.
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange,
                                        object: nil, queue: .main) { [weak self] note in
            guard let self, (note.object as? AVAudioEngine) === self.engine else { return }
            self.perform(actions: AudioLifecyclePolicy.actions(for: .configurationChange,
                                                               isPlaying: self.isPlaying))
        })
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        let event: AudioLifecycleEvent
        switch type {
        case .began:
            event = .interruptionBegan
        case .ended:
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            event = .interruptionEnded(shouldResume: shouldResume)
        @unknown default:
            return
        }
        perform(actions: AudioLifecyclePolicy.actions(for: event, isPlaying: isPlaying))
    }

    private func perform(actions: [AudioLifecycleAction]) {
        for action in actions {
            switch action {
            case .stopTransport:
                stop()
            case .reactivateEngine:
                // Non-fatal on failure: the next play/preview retries lazily.
                ensureEngineRunning()
            case .rebuildGraph:
                rebuildAfterReset()
            case .pauseEngineIfIdle:
                if !isPlaying { engine.pause() }
            }
        }
    }

    /// Media services reset: the engine and every attached node are dead.
    /// Rebuild from scratch; pre-rendered voice buffers are plain memory and
    /// remain valid.
    private func rebuildAfterReset() {
        isReady = false
        engine = AVAudioEngine()
        do {
            try configureSession()
            buildGraph()
            try engine.start()
            schedulerQueue.async { [weak self] in self?.playAllPlayersIfEngineRunning() }
            isReady = true
        } catch {
            events.send(.engineFailed)
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Export

    /// Cancellation token for an in-flight export. Safe to cancel from any thread.
    final class ExportHandle {
        private let lock = NSLock()
        private var cancelled = false
        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }
        func cancel() {
            lock.lock(); cancelled = true; lock.unlock()
        }
    }

    /// Filesystem-safe, collision-resistant export file name derived from the mix name.
    static func exportFileName(patternName: String, format: ExportFormat) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        var base = String(patternName.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        if base.isEmpty { base = "Pulse_Mix" }
        return "\(base)_\(UUID().uuidString.prefix(8)).\(format.rawValue)"
    }

    /// Consecutive .cannotDoInCurrentContext render statuses tolerated before failing.
    private static let renderStallLimit = 1_000

    /// Renders `reps` full pattern loops offline into a WAV or AAC/M4A file and returns the URL.
    /// Runs entirely on a background thread; calls back on main exactly once. Cancel via the
    /// returned handle; a cancelled export completes with `ExportError.cancelled` and removes
    /// any partial file.
    @discardableResult
    func exportMix(reps: Int, format: ExportFormat, completion: @escaping (Result<URL, Error>) -> Void) -> ExportHandle {
        let handle = ExportHandle()
        var captured: [String: AVAudioPCMBuffer] = [:]
        var capturedAccentBuffers: [String: AVAudioPCMBuffer] = [:]
        schedulerQueue.sync {
            captured = buffers
            capturedAccentBuffers = accentBuffers
        }
        guard !captured.isEmpty else {
            // Async so the caller has the handle before the completion runs.
            DispatchQueue.main.async { completion(.failure(ExportError.notPrepared)) }
            return handle
        }

        let snap          = store.audioSnapshot()
        let sr            = sampleRate
        let fileName      = AudioEngine.exportFileName(patternName: store.patternName, format: format)

        DispatchQueue.global(qos: .userInitiated).async {
            var partialURL: URL?
            do {
                let plan = ExportPlanBuilder.build(snapshot: snap, reps: reps, sampleRate: sr)
                let totalFrames = plan.totalFrames
                let boundaries = plan.barBoundaries

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
                // Tear the offline engine down on every exit path, including throws.
                defer { offlineEngine.stop() }

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

                applyExportBar(snap.sequenceStart / 16)
                for chain in exportChains.values { chain.player.play() }

                // Pre-mix each track into one buffer so hit timing is exact and a
                // later hit cuts the previous hit's tail, exactly like the live
                // scheduler's .interrupts behavior. One scheduled buffer per track
                // removes any dependence on AVAudioPlayerNode queue semantics.
                for track in Tracks.all {
                    if handle.isCancelled { throw ExportError.cancelled }
                    guard let chain = exportChains[track.id],
                          let events = plan.events[track.id],
                          let normalBuf = captured[track.id],
                          let render = OfflineTrackRenderer.render(events: events,
                                                                   normalBuffer: normalBuf,
                                                                   accentBuffer: capturedAccentBuffers[track.id],
                                                                   totalFrames: totalFrames,
                                                                   format: self.format)
                    else { continue }
                    let when = AVAudioTime(sampleTime: render.startFrame, atRate: sr)
                    chain.player.scheduleBuffer(render.buffer, at: when, options: [], completionHandler: nil)
                }

                let renderURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: renderURL)
                partialURL = renderURL
                let renderSettings: [String: Any] = format == .wav
                    ? offlineEngine.manualRenderingFormat.settings
                    : [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: sr,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey: 256_000
                    ]
                let renderFile = try AVAudioFile(forWriting: renderURL, settings: renderSettings)
                let renderBuffer = AVAudioPCMBuffer(pcmFormat: offlineEngine.manualRenderingFormat,
                                                    frameCapacity: offlineEngine.manualRenderingMaximumFrameCount)!

                var renderedFrames: AVAudioFramePosition = 0
                var boundaryIndex = 0
                var stallCount = 0
                let fadeFrames = AVAudioFramePosition((0.02 * sr).rounded())
                while renderedFrames < totalFrames {
                    if handle.isCancelled { throw ExportError.cancelled }
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
                    case .success, .insufficientDataFromInputNode:
                        stallCount = 0
                        self.applyEndFade(to: renderBuffer,
                                          renderedStartFrame: renderedFrames,
                                          totalFrames: totalFrames,
                                          fadeFrames: fadeFrames)
                        try renderFile.write(from: renderBuffer)
                        renderedFrames += AVAudioFramePosition(renderBuffer.frameLength)
                    case .cannotDoInCurrentContext:
                        stallCount += 1
                        guard stallCount < AudioEngine.renderStallLimit else {
                            throw ExportError.renderStalled
                        }
                        continue
                    case .error:
                        throw ExportError.renderFailed
                    @unknown default:
                        throw ExportError.renderFailed
                    }
                }

                if handle.isCancelled { throw ExportError.cancelled }
                DispatchQueue.main.async { completion(.success(renderURL)) }

            } catch {
                if let url = partialURL { try? FileManager.default.removeItem(at: url) }
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        return handle
    }
}

enum ExportError: LocalizedError {
    case notPrepared, sessionUnavailable, exportFailed, renderFailed, renderStalled, cancelled
    var errorDescription: String? {
        switch self {
        case .notPrepared:        return "Audio engine isn't ready — try restarting the app"
        case .sessionUnavailable: return "Export session unavailable"
        case .exportFailed:       return "Export failed"
        case .renderFailed:       return "Offline render failed"
        case .renderStalled:      return "Export stalled — please try again"
        case .cancelled:          return "Export cancelled"
        }
    }
}

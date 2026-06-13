import XCTest
import AVFoundation
import Combine
@testable import Pulse

/// End-to-end regression tests for the export pipeline through a real
/// AVAudioEngine. Each engine-backed test skips (not fails) in environments
/// where audio hardware/session setup is unavailable.
final class ExportIntegrationTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables = []
        super.tearDown()
    }

    /// 16 steps at 120 BPM, swing 0 → exactly 2.0s → 88_200 frames at 44.1kHz.
    private let expected16StepFrames: AVAudioFramePosition = 88_200

    private func makeStore() -> Store {
        let store = Store()
        store.setTempo(120)
        store.setSwing(0)
        for step in [0, 4, 8, 12] { store.toggleStep(trackId: "kick", step: step) }
        return store
    }

    private func makePreparedEngine(store: Store) throws -> AudioEngine {
        let engine = AudioEngine(store: store)
        do { try engine.prepare() } catch {
            throw XCTSkip("Audio engine unavailable in this environment: \(error)")
        }
        return engine
    }

    @discardableResult
    private func runExport(_ engine: AudioEngine,
                           reps: Int = 1,
                           cancelImmediately: Bool = false,
                           timeout: TimeInterval = 30) -> Result<URL, Error>? {
        let exp = expectation(description: "export completion")
        var result: Result<URL, Error>?
        let handle = engine.exportMix(reps: reps, format: .wav) {
            result = $0
            exp.fulfill()
        }
        if cancelImmediately { handle.cancel() }
        wait(for: [exp], timeout: timeout)
        return result
    }

    // MARK: - ExportHandle

    func test_exportHandle_cancelVisibleAcrossThreads() {
        let handle = AudioEngine.ExportHandle()
        XCTAssertFalse(handle.isCancelled)
        let exp = expectation(description: "cancelled off-main")
        DispatchQueue.global().async {
            handle.cancel()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        XCTAssertTrue(handle.isCancelled)
    }

    func test_exportHandle_cancelIsIdempotent() {
        let handle = AudioEngine.ExportHandle()
        handle.cancel()
        handle.cancel()
        XCTAssertTrue(handle.isCancelled)
    }

    // MARK: - Unprepared engine

    func test_exportMix_withoutPrepare_failsWithNotPreparedExactlyOnce() {
        let engine = AudioEngine(store: makeStore())
        let exp = expectation(description: "completion")
        var completions: [Result<URL, Error>] = []
        engine.exportMix(reps: 1, format: .wav) {
            completions.append($0)
            exp.fulfill()
        }
        // Completion must be asynchronous (caller holds the handle first).
        XCTAssertTrue(completions.isEmpty)
        wait(for: [exp], timeout: 5)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(completions.count, 1)
        guard case .failure(let error) = completions[0] else {
            return XCTFail("expected failure, got \(completions[0])")
        }
        XCTAssertEqual(error as? ExportError, .notPrepared)
    }

    // MARK: - Real renders

    func test_export_16step_rendersExactExpectedDuration() throws {
        let engine = try makePreparedEngine(store: makeStore())
        guard case .success(let url)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.length, expected16StepFrames)
    }

    func test_export_loopCountScalesFileDuration() throws {
        let engine = try makePreparedEngine(store: makeStore())
        guard case .success(let url)? = runExport(engine, reps: 4) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.length, 4 * expected16StepFrames)
    }

    func test_export_repeatedExportsAreByteIdenticalAndUniquelyNamed() throws {
        // Voice buffers render once per kit load, humanize is 0, and the offline
        // pipeline is deterministic — two exports of an unchanged mix must match.
        let engine = try makePreparedEngine(store: makeStore())
        guard case .success(let first)? = runExport(engine),
              case .success(let second)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        XCTAssertNotEqual(first.lastPathComponent, second.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func test_export_afterKitSwitch_producesDifferentAudio() throws {
        let engine = try makePreparedEngine(store: makeStore())
        guard case .success(let studioURL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: studioURL) }

        engine.reloadKit("808")
        // exportMix serializes its buffer capture behind the kit render queue,
        // so no explicit wait is required — that ordering is what this verifies.
        guard case .success(let kit808URL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: kit808URL) }

        XCTAssertNotEqual(try Data(contentsOf: studioURL), try Data(contentsOf: kit808URL))
    }

    func test_export_stepPitchVariation_producesDifferentAudio() throws {
        let store = Store()
        store.setTempo(120)
        store.setSwing(0)
        for step in [0, 4, 8, 12] { store.toggleStep(trackId: "bass", step: step) }
        let engine = try makePreparedEngine(store: store)
        guard case .success(let rootURL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: rootURL) }

        store.setStepPitch(trackId: "bass", step: 4, semitones: 12)
        guard case .success(let pitchedURL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: pitchedURL) }

        XCTAssertNotEqual(try Data(contentsOf: rootURL), try Data(contentsOf: pitchedURL))
    }

    /// RMS energy of a rendered audio file — perceived loudness, which is what
    /// "louder" means and which (unlike peak) still rises for the soft-limited
    /// drum voices once they have headroom to grow into.
    private func rmsEnergy(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                   frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        var sumSquares: Double = 0
        var n = 0
        for ch in 0..<Int(buf.format.channelCount) {
            let data = buf.floatChannelData![ch]
            for i in 0..<Int(buf.frameLength) { sumSquares += Double(data[i] * data[i]); n += 1 }
        }
        return n > 0 ? Float((sumSquares / Double(n)).squareRoot()) : 0
    }

    /// Accenting a step must raise that voice's energy — the regression guard for
    /// "accent sounds the same". Covers a clean-boost voice (bass), the pad the
    /// user flagged, and kick, the full-scale drum that used to clip away its boost.
    private func assertAccentLouder(trackId: String, minRatio: Float,
                                    file: StaticString = #file, line: UInt = #line) throws {
        let store = Store()
        store.setTempo(120)
        store.setSwing(0)
        store.toggleStep(trackId: trackId, step: 0)
        let engine = try makePreparedEngine(store: store)
        guard case .success(let normalURL)? = runExport(engine) else {
            return XCTFail("export failed", file: file, line: line)
        }
        defer { try? FileManager.default.removeItem(at: normalURL) }
        let normal = try rmsEnergy(of: normalURL)

        store.setStepAccent(trackId: trackId, step: 0, accented: true)
        guard case .success(let accentURL)? = runExport(engine) else {
            return XCTFail("export failed", file: file, line: line)
        }
        defer { try? FileManager.default.removeItem(at: accentURL) }
        let accent = try rmsEnergy(of: accentURL)

        XCTAssertGreaterThan(normal, 0, file: file, line: line)
        XCTAssertGreaterThan(accent, normal * minRatio,
                             "\(trackId): accent should be louder (normal \(normal), accent \(accent))",
                             file: file, line: line)
    }

    func test_export_accentedBass_isLouder() throws {
        try assertAccentLouder(trackId: "bass", minRatio: 1.3)
    }

    func test_export_accentedPad_isLouder() throws {
        try assertAccentLouder(trackId: "pad", minRatio: 1.3)
    }

    func test_export_accentedKick_isLouder() throws {
        // Kick renders near full scale; without voice headroom its accent clipped
        // back to roughly the normal level. This is the direct regression guard.
        try assertAccentLouder(trackId: "kick", minRatio: 1.15)
    }

    /// Spectral brightness: mean absolute first-difference normalized by RMS.
    /// Rises with high-frequency content independent of overall level, so it
    /// isolates "sharper attack" from "louder".
    private func brightness(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                   frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        var totalVariation: Double = 0, sumSquares: Double = 0
        var n = 0
        for ch in 0..<Int(buf.format.channelCount) {
            let data = buf.floatChannelData![ch]
            var prev: Float = 0
            for i in 0..<Int(buf.frameLength) {
                totalVariation += Double(abs(data[i] - prev))
                sumSquares += Double(data[i] * data[i])
                prev = data[i]
                n += 1
            }
        }
        let rms = n > 0 ? (sumSquares / Double(n)).squareRoot() : 0
        return rms > 0 ? Float((totalVariation / Double(n)) / rms) : 0
    }

    func test_export_accentedPad_isBrighterNotJustLouder() throws {
        // The user's complaint: a few dB of gain on a soft pad reads as "no
        // change". Accents now add high-frequency emphasis so they're sharper too.
        let store = Store()
        store.setTempo(120)
        store.setSwing(0)
        store.toggleStep(trackId: "pad", step: 0)
        let engine = try makePreparedEngine(store: store)
        guard case .success(let normalURL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: normalURL) }
        let normalBright = try brightness(of: normalURL)

        store.setStepAccent(trackId: "pad", step: 0, accented: true)
        guard case .success(let accentURL)? = runExport(engine) else {
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: accentURL) }
        let accentBright = try brightness(of: accentURL)

        XCTAssertGreaterThan(normalBright, 0)
        XCTAssertGreaterThan(accentBright, normalBright * 1.1,
                             "accented pad should be brighter (normal \(normalBright), accent \(accentBright))")
    }

    func test_export_cancelledImmediately_failsCancelledAndLeavesNoFile() throws {
        let engine = try makePreparedEngine(store: makeStore())
        let tmp = FileManager.default.temporaryDirectory
        let wavsBefore = Set(try FileManager.default.contentsOfDirectory(atPath: tmp.path)
            .filter { $0.hasSuffix(".wav") })

        guard case .failure(let error)? = runExport(engine, reps: 8, cancelImmediately: true) else {
            return XCTFail("expected cancelled failure")
        }
        XCTAssertEqual(error as? ExportError, .cancelled)

        let wavsAfter = Set(try FileManager.default.contentsOfDirectory(atPath: tmp.path)
            .filter { $0.hasSuffix(".wav") })
        XCTAssertEqual(wavsAfter, wavsBefore, "cancelled export must not leave a partial file")
    }

    func test_export_duringPlayback_leavesTransportPlaying() throws {
        let engine = try makePreparedEngine(store: makeStore())
        engine.start()
        XCTAssertTrue(engine.isPlaying)

        guard case .success(let url)? = runExport(engine) else {
            engine.stop()
            return XCTFail("export failed")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(engine.isPlaying, "export must not mutate live transport state")
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
    }

    // MARK: - Transport consistency with a real engine

    func test_rapidStartStop_withPreparedEngine_staysConsistent() throws {
        let engine = try makePreparedEngine(store: makeStore())
        for _ in 0..<30 {
            engine.start()
            engine.stop()
        }
        XCTAssertFalse(engine.isPlaying)

        // Transport must still be usable afterwards.
        engine.start()
        XCTAssertTrue(engine.isPlaying)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
    }
}

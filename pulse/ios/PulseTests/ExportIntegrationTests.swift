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

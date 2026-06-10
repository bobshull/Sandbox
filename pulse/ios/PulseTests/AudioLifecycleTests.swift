import XCTest
import Combine
@testable import Pulse

final class AudioLifecycleTests: XCTestCase {

    // MARK: - Policy table

    func test_interruptionBegan_whilePlaying_stopsTransport() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .interruptionBegan, isPlaying: true),
                       [.stopTransport])
    }

    func test_interruptionBegan_whileStopped_doesNothing() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .interruptionBegan, isPlaying: false), [])
    }

    func test_interruptionEnded_shouldResume_reactivatesEngineOnly() {
        // Engine readiness comes back; the sequencer does not auto-resume.
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .interruptionEnded(shouldResume: true),
                                                    isPlaying: false),
                       [.reactivateEngine])
    }

    func test_interruptionEnded_withoutResume_isLazy() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .interruptionEnded(shouldResume: false),
                                                    isPlaying: false), [])
    }

    func test_mediaServicesReset_whilePlaying_stopsThenRebuilds() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .mediaServicesReset, isPlaying: true),
                       [.stopTransport, .rebuildGraph])
    }

    func test_mediaServicesReset_whileStopped_stillRebuilds() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .mediaServicesReset, isPlaying: false),
                       [.rebuildGraph])
    }

    func test_configurationChange_whilePlaying_stopsAndReactivates() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .configurationChange, isPlaying: true),
                       [.stopTransport, .reactivateEngine])
    }

    func test_configurationChange_whileStopped_isLazy() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .configurationChange, isPlaying: false), [])
    }

    func test_background_whilePlaying_keepsEngineForBackgroundAudio() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .appBackgrounded, isPlaying: true), [])
    }

    func test_background_whileIdle_pausesEngine() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .appBackgrounded, isPlaying: false),
                       [.pauseEngineIfIdle])
    }

    func test_foreground_isLazy() {
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .appForegrounded, isPlaying: true), [])
        XCTAssertEqual(AudioLifecyclePolicy.actions(for: .appForegrounded, isPlaying: false), [])
    }

    // MARK: - Transport guards (no prepared engine needed)

    func test_engineNotReadyBeforePrepare() {
        XCTAssertFalse(AudioEngine(store: Store()).isReady)
    }

    func test_start_withoutPrepare_reportsEngineFailedAndStaysStopped() {
        let engine = AudioEngine(store: Store())
        var cancellables = Set<AnyCancellable>()
        var failed = false
        var started = false
        engine.events.sink { event in
            if case .engineFailed = event { failed = true }
            if case .started = event { started = true }
        }.store(in: &cancellables)

        engine.start()

        XCTAssertTrue(failed)
        XCTAssertFalse(started)
        XCTAssertFalse(engine.isPlaying)
    }

    func test_rapidStartStop_withoutPrepare_staysConsistent() {
        let engine = AudioEngine(store: Store())
        var cancellables = Set<AnyCancellable>()
        var stoppedEvents = 0
        engine.events.sink { event in
            if case .stopped = event { stoppedEvents += 1 }
        }.store(in: &cancellables)

        for _ in 0..<20 {
            engine.start()
            engine.stop()
        }

        XCTAssertFalse(engine.isPlaying)
        // start() never succeeded, so stop() must always be a guarded no-op.
        XCTAssertEqual(stoppedEvents, 0)
    }

    func test_stop_whenNotPlaying_emitsNothing() {
        let engine = AudioEngine(store: Store())
        var cancellables = Set<AnyCancellable>()
        var eventCount = 0
        engine.events.sink { _ in eventCount += 1 }.store(in: &cancellables)

        engine.stop()

        XCTAssertEqual(eventCount, 0)
    }

    // MARK: - Kit reload skipping

    func test_reloadKit_skipsWhenSameKitRequestedAgain() {
        let engine = AudioEngine(store: Store())
        engine.reloadKit("808")
        engine.reloadKit("808")
        engine.reloadKit("808")
        engine.waitForPendingKitRenders()
        XCTAssertEqual(engine.kitRenderCount, 1)
        XCTAssertEqual(engine.loadedKitId, "808")
    }

    func test_reloadKit_rendersWhenKitActuallyChanges() {
        let engine = AudioEngine(store: Store())
        engine.reloadKit("808")
        engine.reloadKit("jazz")
        engine.waitForPendingKitRenders()
        XCTAssertEqual(engine.kitRenderCount, 2)
        XCTAssertEqual(engine.loadedKitId, "jazz")
    }

    func test_reloadKit_lastRequestedKitWins() {
        let engine = AudioEngine(store: Store())
        for kit in ["808", "jazz", "arcade", "space"] { engine.reloadKit(kit) }
        engine.waitForPendingKitRenders()
        XCTAssertEqual(engine.kitRenderCount, 4)
        XCTAssertEqual(engine.loadedKitId, "space")
    }
}

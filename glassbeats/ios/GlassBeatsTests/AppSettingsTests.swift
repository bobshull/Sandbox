import XCTest
@testable import GlassBeats

final class AppSettingsTests: XCTestCase {

    private let hapticsKey   = "glassbeats.hapticsEnabled"
    private let tempoKey     = "glassbeats.defaultTempo"
    private let colorThemeKey = "glassbeats.colorThemeId"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: hapticsKey)
        UserDefaults.standard.removeObject(forKey: tempoKey)
        UserDefaults.standard.removeObject(forKey: colorThemeKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: hapticsKey)
        UserDefaults.standard.removeObject(forKey: tempoKey)
        UserDefaults.standard.removeObject(forKey: colorThemeKey)
        super.tearDown()
    }

    // MARK: - hapticsEnabled

    func test_hapticsEnabled_defaultsToTrue() {
        XCTAssertTrue(AppSettings.hapticsEnabled)
    }

    func test_hapticsEnabled_setFalse() {
        AppSettings.hapticsEnabled = false
        XCTAssertFalse(AppSettings.hapticsEnabled)
    }

    func test_hapticsEnabled_setTrue() {
        AppSettings.hapticsEnabled = false
        AppSettings.hapticsEnabled = true
        XCTAssertTrue(AppSettings.hapticsEnabled)
    }

    // MARK: - defaultTempo

    func test_defaultTempo_defaultIs96() {
        XCTAssertEqual(AppSettings.defaultTempo, 96)
    }

    func test_defaultTempo_set() {
        AppSettings.defaultTempo = 140
        XCTAssertEqual(AppSettings.defaultTempo, 140)
    }

    func test_defaultTempo_persistsAfterSet() {
        AppSettings.defaultTempo = 110
        XCTAssertEqual(AppSettings.defaultTempo, 110)
        AppSettings.defaultTempo = 95
        XCTAssertEqual(AppSettings.defaultTempo, 95)
    }

    // MARK: - colorThemeId

    func test_colorThemeId_defaultIsMangoTango() {
        XCTAssertEqual(AppSettings.colorThemeId, "mangoTango")
    }

    func test_colorThemeId_set() {
        AppSettings.colorThemeId = "bubblegumHaze"
        XCTAssertEqual(AppSettings.colorThemeId, "bubblegumHaze")
    }

    func test_colorThemeId_sendsNotification() {
        var received = false
        let obs = NotificationCenter.default.addObserver(
            forName: .colorThemeDidChange, object: nil, queue: .main
        ) { _ in received = true }
        AppSettings.colorThemeId = "plumCrazy"
        NotificationCenter.default.removeObserver(obs)
        XCTAssertTrue(received)
    }

    func test_colorThemeId_persistsValue() {
        AppSettings.colorThemeId = "seaGlass"
        XCTAssertEqual(AppSettings.colorThemeId, "seaGlass")
    }
}

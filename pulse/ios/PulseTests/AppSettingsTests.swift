import XCTest
@testable import Pulse

final class AppSettingsTests: XCTestCase {

    private let hapticsKey   = "pulse.hapticsEnabled"
    private let tempoKey     = "pulse.defaultTempo"
    private let colorThemeKey = "pulse.colorThemeId"

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

    func test_colorThemeId_defaultIsNeon() {
        XCTAssertEqual(AppSettings.colorThemeId, "neon")
    }

    func test_colorThemeId_set() {
        AppSettings.colorThemeId = "pastel"
        XCTAssertEqual(AppSettings.colorThemeId, "pastel")
    }

    func test_colorThemeId_sendsNotification() {
        var received = false
        let obs = NotificationCenter.default.addObserver(
            forName: .colorThemeDidChange, object: nil, queue: .main
        ) { _ in received = true }
        AppSettings.colorThemeId = "vapor"
        NotificationCenter.default.removeObserver(obs)
        XCTAssertTrue(received)
    }

    func test_colorThemeId_persistsValue() {
        AppSettings.colorThemeId = "amber"
        XCTAssertEqual(AppSettings.colorThemeId, "amber")
    }
}

import XCTest
@testable import Pulse

final class ColorThemeTests: XCTestCase {

    private let colorThemeKey = "pulse.colorThemeId"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: colorThemeKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: colorThemeKey)
        super.tearDown()
    }

    // MARK: - Catalogue

    func test_all_containsSixteenThemes() {
        XCTAssertEqual(ColorTheme.all.count, 16)
    }

    func test_all_idsAreUnique() {
        let ids = ColorTheme.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count,
                       "Duplicate theme ids in ColorTheme.all: \(ids)")
    }

    func test_every_theme_definesAllEightTrackColors() {
        let required: Set<String> = ["kick", "snare", "hat", "clap", "bass", "pluck", "pad", "perc"]
        for theme in ColorTheme.all {
            XCTAssertEqual(theme.definedTrackIds, required,
                           "Theme \(theme.id) is missing track colours: " +
                           "\(required.subtracting(theme.definedTrackIds))")
        }
    }

    // MARK: - current

    func test_current_returnsTheme_whenColorThemeIdMatches() {
        AppSettings.colorThemeId = "midnight"
        XCTAssertEqual(ColorTheme.current.id, "midnight")
    }

    func test_current_fallsBackToNeon_whenColorThemeIdUnknown() {
        AppSettings.colorThemeId = "definitely-not-a-real-theme"
        XCTAssertEqual(ColorTheme.current.id, "neon")
    }

    // MARK: - Compatibility aliases
    // These themes were removed from ColorTheme.all but still need to be
    // referenceable so old saved settings / old code paths don't crash.

    func test_alias_synthwave_resolvesToAValidTheme() {
        let theme = ColorTheme.synthwave
        XCTAssertFalse(theme.id.isEmpty)
        XCTAssertFalse(theme.definedTrackIds.isEmpty)
    }

    func test_alias_lava_resolvesToAValidTheme() {
        let theme = ColorTheme.lava
        XCTAssertFalse(theme.id.isEmpty)
        XCTAssertFalse(theme.definedTrackIds.isEmpty)
    }

    func test_alias_cherry_resolvesToAValidTheme() {
        let theme = ColorTheme.cherry
        XCTAssertFalse(theme.id.isEmpty)
        XCTAssertFalse(theme.definedTrackIds.isEmpty)
    }

    func test_alias_sand_resolvesToAValidTheme() {
        let theme = ColorTheme.sand
        XCTAssertEqual(theme.id, "sand")
        XCTAssertFalse(theme.definedTrackIds.isEmpty)
    }
}

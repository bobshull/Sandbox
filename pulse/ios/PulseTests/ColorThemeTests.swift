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

    func test_all_isSortedByPrimaryColorSimilarity() {
        XCTAssertEqual(ColorTheme.all.map(\.id), [
            "cherryBomb",
            "bubblegumHaze",
            "mangoTango",
            "goldfinger",
            "lemonDrop",
            "pickleJuice",
            "electricLime",
            "emeraldCity",
            "mintCondition",
            "poolParty",
            "aurora",
            "blueLagoon",
            "ultraviolet",
            "plumCrazy",
            "candyNoir",
            "silverLining",
        ])
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
        AppSettings.colorThemeId = "plumCrazy"
        XCTAssertEqual(ColorTheme.current.id, "plumCrazy")
    }

    func test_current_fallsBackToMangoTango_whenColorThemeIdUnknown() {
        AppSettings.colorThemeId = "definitely-not-a-real-theme"
        XCTAssertEqual(ColorTheme.current.id, "mangoTango")
    }
}

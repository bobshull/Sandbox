import XCTest
@testable import GlassBeats

final class ColorThemeTests: XCTestCase {

    private let colorThemeKey = "glassbeats.colorThemeId"

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
            "sourApple",
            "electricLime",
            "emeraldCity",
            "mintCondition",
            "seaGlass",
            "northernGlow",
            "nightSwim",
            "ultraviolet",
            "plumCrazy",
            "candyNoir",
            "silverLining",
        ])
    }

    func test_renamedThemes_useMatchingIds() {
        let namesById = Dictionary(uniqueKeysWithValues: ColorTheme.all.map { ($0.id, $0.name) })
        XCTAssertEqual(namesById["sourApple"], "Sour Apple")
        XCTAssertEqual(namesById["nightSwim"], "Night Swim")
        XCTAssertEqual(namesById["seaGlass"], "Sea Glass")
        XCTAssertEqual(namesById["northernGlow"], "Northern Glow")
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

import XCTest
@testable import Pulse

final class SampleKitsTests: XCTestCase {

    func test_all_notEmpty() {
        XCTAssertFalse(SampleKits.all.isEmpty)
    }

    func test_all_uniqueIds() {
        let ids = SampleKits.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_all_hasStudio() {
        XCTAssertNotNil(SampleKits.all.first { $0.id == "studio" })
    }

    func test_all_has808() {
        XCTAssertNotNil(SampleKits.all.first { $0.id == "808" })
    }

    func test_all_hasJungle() {
        XCTAssertNotNil(SampleKits.all.first { $0.id == "jungle" })
    }

    func test_find_existingId() {
        let kit = SampleKits.find("studio")
        XCTAssertEqual(kit.id, "studio")
        XCTAssertEqual(kit.name, "Studio")
    }

    func test_find_unknownId_returnsFirst() {
        let kit = SampleKits.find("nonexistent")
        XCTAssertEqual(kit.id, SampleKits.all[0].id)
    }

    func test_find_808() {
        let kit = SampleKits.find("808")
        XCTAssertEqual(kit.id, "808")
    }

    func test_find_jungle() {
        let kit = SampleKits.find("jungle")
        XCTAssertEqual(kit.name, "Jungle")
    }

    func test_all_noEmptyIds() {
        for kit in SampleKits.all {
            XCTAssertFalse(kit.id.isEmpty)
            XCTAssertFalse(kit.name.isEmpty)
        }
    }

    func test_all_presetKitsExist() {
        // Every kit referenced in Presets.all should exist in SampleKits
        let kitIds = Set(SampleKits.all.map { $0.id })
        for preset in Presets.all {
            if let kitId = preset.kitId {
                XCTAssertTrue(kitIds.contains(kitId), "Kit '\(kitId)' from preset '\(preset.id)' not in SampleKits")
            }
        }
    }
}

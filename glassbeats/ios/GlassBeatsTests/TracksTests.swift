import XCTest
@testable import GlassBeats

final class TracksTests: XCTestCase {

    // MARK: - Tracks.all

    func test_all_notEmpty() {
        XCTAssertFalse(Tracks.all.isEmpty)
    }

    func test_all_uniqueIds() {
        let ids = Tracks.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_all_uniqueNames() {
        let names = Tracks.all.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
    }

    func test_all_hasKick() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "kick" })
    }

    func test_all_hasSnare() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "snare" })
    }

    func test_all_hasHat() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "hat" })
    }

    func test_all_hasClap() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "clap" })
    }

    func test_all_hasBass() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "bass" })
    }

    func test_all_hasPluck() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "pluck" })
    }

    func test_all_hasPad() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "pad" })
    }

    func test_all_hasPerc() {
        XCTAssertNotNil(Tracks.all.first { $0.id == "perc" })
    }

    // MARK: - find

    func test_find_kick() {
        let t = Tracks.find("kick")
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.id, "kick")
        XCTAssertEqual(t?.name, "Kick")
        XCTAssertEqual(t?.voice, .kick)
    }

    func test_find_snare() {
        let t = Tracks.find("snare")
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.voice, .snare)
    }

    func test_find_hat() {
        XCTAssertEqual(Tracks.find("hat")?.voice, .hat)
    }

    func test_find_clap() {
        XCTAssertEqual(Tracks.find("clap")?.voice, .clap)
    }

    func test_find_bass() {
        XCTAssertEqual(Tracks.find("bass")?.voice, .bass)
    }

    func test_find_pluck() {
        XCTAssertEqual(Tracks.find("pluck")?.voice, .pluck)
    }

    func test_find_pad() {
        XCTAssertEqual(Tracks.find("pad")?.voice, .pad)
    }

    func test_find_perc() {
        XCTAssertEqual(Tracks.find("perc")?.voice, .perc)
    }

    func test_find_nonexistent_returnsNil() {
        XCTAssertNil(Tracks.find("nonexistent"))
    }

    func test_find_emptyString_returnsNil() {
        XCTAssertNil(Tracks.find(""))
    }

    // MARK: - stepCount

    func test_stepCount_is16() {
        XCTAssertEqual(Tracks.stepCount, 16)
    }

    // MARK: - VoiceKind

    func test_voiceKind_allCasesCount() {
        XCTAssertEqual(VoiceKind.allCases.count, 8)
    }

    func test_voiceKind_kickRawValue() {
        XCTAssertEqual(VoiceKind.kick.rawValue, "kick")
    }

    func test_voiceKind_snareRawValue() {
        XCTAssertEqual(VoiceKind.snare.rawValue, "snare")
    }

    func test_voiceKind_hatRawValue() {
        XCTAssertEqual(VoiceKind.hat.rawValue, "hat")
    }

    func test_voiceKind_clapRawValue() {
        XCTAssertEqual(VoiceKind.clap.rawValue, "clap")
    }

    func test_voiceKind_bassRawValue() {
        XCTAssertEqual(VoiceKind.bass.rawValue, "bass")
    }

    func test_voiceKind_pluckRawValue() {
        XCTAssertEqual(VoiceKind.pluck.rawValue, "pluck")
    }

    func test_voiceKind_padRawValue() {
        XCTAssertEqual(VoiceKind.pad.rawValue, "pad")
    }

    func test_voiceKind_percRawValue() {
        XCTAssertEqual(VoiceKind.perc.rawValue, "perc")
    }

    func test_voiceKind_rawValueRoundTrip() {
        for kind in VoiceKind.allCases {
            XCTAssertEqual(VoiceKind(rawValue: kind.rawValue), kind)
        }
    }

    func test_voiceKind_codable_roundTrip() throws {
        for kind in VoiceKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(VoiceKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }
}

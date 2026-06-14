import XCTest
@testable import GlassBeats

final class PresetsTests: XCTestCase {

    // MARK: - emptyRows

    func test_emptyRows_defaultLength_containsAllTracks() {
        let rows = Presets.emptyRows()
        for track in Tracks.all {
            XCTAssertNotNil(rows[track.id])
        }
    }

    func test_emptyRows_defaultLength_each16Steps() {
        let rows = Presets.emptyRows()
        for (_, row) in rows {
            XCTAssertEqual(row.count, Tracks.stepCount)
        }
    }

    func test_emptyRows_defaultLength_allFalse() {
        let rows = Presets.emptyRows()
        for (_, row) in rows {
            XCTAssertTrue(row.allSatisfy { !$0 })
        }
    }

    func test_emptyRows_customLength32() {
        let rows = Presets.emptyRows(length: 32)
        for (_, row) in rows {
            XCTAssertEqual(row.count, 32)
            XCTAssertTrue(row.allSatisfy { !$0 })
        }
    }

    func test_emptyRows_noExtraKeys() {
        let rows = Presets.emptyRows()
        XCTAssertEqual(rows.count, Tracks.all.count)
    }

    // MARK: - filledRows

    func test_filledRows_passesMatchingLengthRow() {
        let trackId = Tracks.all[0].id
        var source = [trackId: Array(repeating: false, count: 16)]
        source[trackId]![0] = true
        source[trackId]![5] = true
        let filled = Presets.filledRows(from: source)
        XCTAssertTrue(filled[trackId]?[0] == true)
        XCTAssertTrue(filled[trackId]?[5] == true)
    }

    func test_filledRows_truncatesLongerRow() {
        let trackId = Tracks.all[0].id
        let longRow = Array(repeating: true, count: 32)
        let filled = Presets.filledRows(from: [trackId: longRow], length: 16)
        XCTAssertEqual(filled[trackId]?.count, 16)
    }

    func test_filledRows_filledMissingTracksWithFalse() {
        let filled = Presets.filledRows(from: [:], length: 16)
        for track in Tracks.all {
            XCTAssertEqual(filled[track.id]?.count, 16)
            XCTAssertTrue(filled[track.id]?.allSatisfy { !$0 } == true)
        }
    }

    func test_filledRows_ignoresUnknownKeys() {
        let source = ["nonexistent": Array(repeating: true, count: 16)]
        let filled = Presets.filledRows(from: source)
        XCTAssertNil(filled["nonexistent"])
    }

    func test_filledRows_doesNotExpandShorterRow() {
        let trackId = Tracks.all[0].id
        // Row shorter than target — should be ignored, track stays all-false
        let shortRow: [Bool] = [true, false, true]
        let filled = Presets.filledRows(from: [trackId: shortRow], length: 16)
        XCTAssertEqual(filled[trackId]?.count, 16)
        XCTAssertTrue(filled[trackId]?.allSatisfy { !$0 } == true)
    }

    func test_filledRows_preservesAllTrueValues() {
        let trackId = Tracks.all[0].id
        let allTrue = Array(repeating: true, count: 16)
        let filled = Presets.filledRows(from: [trackId: allTrue])
        XCTAssertTrue(filled[trackId]?.allSatisfy { $0 } == true)
    }

    func test_filledRows_multipleTracksIndependent() {
        let id0 = Tracks.all[0].id
        let id1 = Tracks.all[1].id
        var row0 = Array(repeating: false, count: 16)
        row0[0] = true
        var row1 = Array(repeating: false, count: 16)
        row1[8] = true
        let filled = Presets.filledRows(from: [id0: row0, id1: row1])
        XCTAssertTrue(filled[id0]?[0] == true)
        XCTAssertFalse(filled[id0]?[8] == true)
        XCTAssertTrue(filled[id1]?[8] == true)
        XCTAssertFalse(filled[id1]?[0] == true)
    }

    func test_filledRows_length32_from32Source() {
        let trackId = Tracks.all[0].id
        var source = Array(repeating: false, count: 32)
        source[20] = true
        let filled = Presets.filledRows(from: [trackId: source], length: 32)
        XCTAssertEqual(filled[trackId]?.count, 32)
        XCTAssertTrue(filled[trackId]?[20] == true)
    }

    // MARK: - Presets.all catalog

    func test_presetsAll_notEmpty() {
        XCTAssertFalse(Presets.all.isEmpty)
    }

    func test_presetsAll_uniqueIds() {
        let ids = Presets.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_presetsAll_validTempos() {
        for preset in Presets.all {
            XCTAssertGreaterThanOrEqual(preset.tempo, 40, "\(preset.id) has invalid tempo")
            XCTAssertLessThanOrEqual(preset.tempo, 220, "\(preset.id) has invalid tempo")
        }
    }

    func test_presetsAll_validSwing() {
        for preset in Presets.all {
            XCTAssertGreaterThanOrEqual(preset.swing, 0, "\(preset.id) has invalid swing")
            XCTAssertLessThanOrEqual(preset.swing, 0.6, "\(preset.id) has invalid swing")
        }
    }

    func test_presetsAll_patternLengthIsNilOr16Or32() {
        for preset in Presets.all {
            if let len = preset.patternLength {
                XCTAssertTrue(len == 16 || len == 32, "\(preset.id) has invalid patternLength \(len)")
            }
        }
    }

    func test_presetsAll_32stepRowsAre32Long() {
        for preset in Presets.all where preset.patternLength == 32 {
            for (trackId, row) in preset.rows {
                XCTAssertEqual(row.count, 32, "\(preset.id) track \(trackId) should be 32 steps")
            }
        }
    }

    func test_presetsAll_defaultLengthRowsAre16Long() {
        for preset in Presets.all where (preset.patternLength ?? 16) == 16 {
            for (trackId, row) in preset.rows {
                XCTAssertEqual(row.count, 16, "\(preset.id) track \(trackId) should be 16 steps")
            }
        }
    }

    func test_presetsAll_containsJungleChop() {
        XCTAssertNotNil(Presets.all.first { $0.id == "jungle-chop" })
    }

    func test_presetsAll_containsEmptyPattern() {
        XCTAssertNotNil(Presets.all.first { $0.id == "empty" })
    }

    func test_boomBapClassic_matchesScreenshotVolumes() {
        let preset = Presets.all.first { $0.id == "boom-bap-classic" }
        XCTAssertEqual(preset?.volumes?["kick"] ?? 0, 0.95, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["snare"] ?? 0, 0.90, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["hat"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["clap"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["bass"] ?? 0, 0.80, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["pluck"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["pad"] ?? 0, 0.18, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["perc"] ?? 0, 0.42, accuracy: 0.001)
    }

    func test_boomBapClassicTwoBar_matchesScreenshotVolumesOnBar2() {
        let preset = Presets.all.first { $0.id == "boom-bap-2" }
        XCTAssertEqual(preset?.bar2Volumes?["kick"] ?? 0, 0.95, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["snare"] ?? 0, 0.90, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["hat"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["clap"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["bass"] ?? 0, 0.80, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["pluck"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["pad"] ?? 0, 0.18, accuracy: 0.001)
        XCTAssertEqual(preset?.bar2Volumes?["perc"] ?? 0, 0.42, accuracy: 0.001)
    }

    func test_musicBoxFantasy_matchesScreenshotVolumes() {
        let preset = Presets.all.first { $0.id == "music-box-fantasy" }
        XCTAssertEqual(preset?.volumes?["kick"] ?? 0, 0.62, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["snare"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["hat"] ?? 0, 0.50, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["clap"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["bass"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["pluck"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["pad"] ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(preset?.volumes?["perc"] ?? 0, 1.00, accuracy: 0.001)
    }

    func test_presetsAll_2barVariantsHaveBasePresetId() {
        for preset in Presets.all where preset.patternLength == 32 && preset.id != "empty" {
            XCTAssertNotNil(preset.basePresetId, "\(preset.id) missing basePresetId")
        }
    }

    func test_twoBarVariantsFirstBarMatchesBasePreset() {
        for variant in Presets.all where variant.patternLength == 32 {
            guard let basePresetId = variant.basePresetId,
                  let base = Presets.all.first(where: { $0.id == basePresetId }) else {
                continue
            }

            for track in Tracks.all {
                let variantRow = Array((variant.rows[track.id] ?? Array(repeating: false, count: 32)).prefix(16))
                let baseRow = base.rows[track.id] ?? Array(repeating: false, count: 16)
                XCTAssertEqual(variantRow, baseRow, "\(variant.id) \(track.id) row bar 1 should match \(base.id)")

                let variantAccents = Array((variant.accents?[track.id] ?? Array(repeating: false, count: 32)).prefix(16))
                let baseAccents = base.accents?[track.id] ?? Array(repeating: false, count: 16)
                XCTAssertEqual(variantAccents, baseAccents, "\(variant.id) \(track.id) accents bar 1 should match \(base.id)")

                let variantPitches = Array((variant.pitches?[track.id] ?? Array(repeating: 0, count: 32)).prefix(16))
                let basePitches = base.pitches?[track.id] ?? Array(repeating: 0, count: 16)
                XCTAssertEqual(variantPitches, basePitches, "\(variant.id) \(track.id) pitches bar 1 should match \(base.id)")
            }

            for track in Tracks.all {
                let variantVolume = variant.volumes?[track.id] ?? 1.0
                let baseVolume = base.volumes?[track.id] ?? 1.0
                XCTAssertEqual(variantVolume, baseVolume, accuracy: 0.001, "\(variant.id) \(track.id) volume should match \(base.id)")

                let variantEffect = variant.effects?[track.id] ?? .default
                let baseEffect = base.effects?[track.id] ?? .default
                XCTAssertEqual(variantEffect, baseEffect, "\(variant.id) \(track.id) effect should match \(base.id)")
            }
        }
    }

    // MARK: - Pattern Codable

    func test_pattern_codable_roundTrip() throws {
        let preset = Presets.all[0]
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(Pattern.self, from: data)
        XCTAssertEqual(decoded.id, preset.id)
        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.tempo, preset.tempo)
        XCTAssertEqual(decoded.swing, preset.swing)
        XCTAssertEqual(decoded.kitId, preset.kitId)
    }

    func test_pattern_codable_withOptionalFields() throws {
        var p = Pattern(id: "x", name: "X", tempo: 100, swing: 0, rows: [:])
        p.volumes = ["kick": 0.9]
        p.mutes = ["snare": true]
        p.effects = ["hat": TrackEffects()]
        p.patternLength = 32
        p.bar2Volumes = ["kick": 0.5]
        p.bar2Effects = ["hat": TrackEffects()]
        p.basePresetId = "y"
        p.barLength = 2

        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Pattern.self, from: data)

        XCTAssertEqual(decoded.volumes?["kick"] ?? 0, Float(0.9), accuracy: Float(0.001))
        XCTAssertEqual(decoded.mutes?["snare"], true)
        XCTAssertEqual(decoded.patternLength, 32)
        XCTAssertEqual(decoded.bar2Volumes?["kick"] ?? 0, Float(0.5), accuracy: Float(0.001))
        XCTAssertEqual(decoded.basePresetId, "y")
        XCTAssertEqual(decoded.barLength, 2)
    }

    // MARK: - Preset pitch variation

    func test_pattern_codableRoundTripsPitches() throws {
        var p = Pattern(id: "x", name: "X", tempo: 100, swing: 0.1, rows: [:])
        p.pitches = ["bass": (0..<16).map { $0 == 3 ? 12 : 0 }]
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Pattern.self, from: data)
        XCTAssertEqual(decoded.pitches?["bass"]?[3], 12)
    }

    func test_pattern_decodesWithoutPitches() throws {
        // Pre-pitch saved payloads have no "pitches" key and must still decode.
        let json = #"{"id":"old","name":"Old","tempo":90,"swing":0.2,"rows":{}}"#
        let decoded = try JSONDecoder().decode(Pattern.self, from: Data(json.utf8))
        XCTAssertNil(decoded.pitches)
    }

    func test_presets_pitchesOnlyOnMelodicTracks() {
        for preset in Presets.all {
            for trackId in (preset.pitches ?? [:]).keys {
                let voice = Tracks.find(trackId)?.voice
                XCTAssertNotNil(voice, "\(preset.id): unknown track \(trackId)")
                XCTAssertTrue(voice.map(StepPitch.supportsPitch) == true,
                              "\(preset.id): pitch variation on non-melodic track \(trackId)")
            }
        }
    }

    func test_presets_pitchValuesAreRenderableOffsets() {
        for preset in Presets.all {
            for (trackId, row) in preset.pitches ?? [:] {
                guard let voice = Tracks.find(trackId)?.voice else { continue }
                let allowed = Set(StepPitch.renderedOffsets(for: voice))
                for (step, semitones) in row.enumerated() where semitones != 0 {
                    XCTAssertTrue(allowed.contains(semitones),
                                  "\(preset.id)/\(trackId) step \(step): offset \(semitones) has no rendered buffer")
                }
            }
        }
    }

    func test_presets_pitchRowsMatchPatternLengthAndActiveSteps() {
        for preset in Presets.all {
            let length = preset.patternLength ?? 16
            for (trackId, row) in preset.pitches ?? [:] {
                XCTAssertEqual(row.count, length, "\(preset.id)/\(trackId): pitch row length")
                let steps = preset.rows[trackId] ?? []
                for (step, semitones) in row.enumerated() where semitones != 0 {
                    XCTAssertTrue(steps.indices.contains(step) && steps[step],
                                  "\(preset.id)/\(trackId) step \(step): pitch on inactive step")
                }
            }
        }
    }

    func test_presets_somePitchVariationExists() {
        XCTAssertTrue(Presets.all.contains { !($0.pitches ?? [:]).isEmpty })
    }
}

import XCTest
@testable import Pulse

final class TrackEffectsTests: XCTestCase {

    // MARK: - Default values

    func test_default_isNoActiveEffects() {
        XCTAssertFalse(TrackEffects.default.hasAnyActive)
    }

    func test_default_pan0() {
        XCTAssertEqual(TrackEffects().pan, 0)
    }

    func test_default_pitch0() {
        XCTAssertEqual(TrackEffects().pitch, 0)
    }

    func test_default_filterCutoff100() {
        XCTAssertEqual(TrackEffects().filterCutoff, 100)
    }

    func test_default_humanize0() {
        XCTAssertEqual(TrackEffects().humanize, 0)
    }

    func test_default_reverbWet0() {
        XCTAssertEqual(TrackEffects().reverbWet, 0)
    }

    func test_default_delayWet0() {
        XCTAssertEqual(TrackEffects().delayWet, 0)
    }

    func test_default_delaySyncDivisionIsEighth() {
        XCTAssertEqual(TrackEffects().delaySyncDivision, .eighth)
    }

    func test_default_distortionWet0() {
        XCTAssertEqual(TrackEffects().distortionWet, 0)
    }

    // MARK: - hasAnyActive

    func test_hasAnyActive_falseForDefault() {
        XCTAssertFalse(TrackEffects().hasAnyActive)
    }

    func test_hasAnyActive_trueWithNonzeroPan() {
        var fx = TrackEffects()
        fx.pan = 0.1
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithNegativePan() {
        var fx = TrackEffects()
        fx.pan = -0.5
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithNonzeroPitch() {
        var fx = TrackEffects()
        fx.pitch = 2
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithFilterCutoffBelow100() {
        var fx = TrackEffects()
        fx.filterCutoff = 99.9
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_falseWithFilterCutoffAt100() {
        var fx = TrackEffects()
        fx.filterCutoff = 100
        XCTAssertFalse(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithHumanize() {
        var fx = TrackEffects()
        fx.humanize = 1
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithReverb() {
        var fx = TrackEffects()
        fx.reverbWet = 50
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithDelay() {
        var fx = TrackEffects()
        fx.delayWet = 30
        XCTAssertTrue(fx.hasAnyActive)
    }

    func test_hasAnyActive_trueWithDistortion() {
        var fx = TrackEffects()
        fx.distortionWet = 20
        XCTAssertTrue(fx.hasAnyActive)
    }

    // MARK: - filterFrequency

    func test_filterFrequency_at0_is200Hz() {
        let freq = TrackEffects.filterFrequency(from: 0)
        XCTAssertEqual(freq, 200.0, accuracy: 1.0)
    }

    func test_filterFrequency_at100_is20kHz() {
        let freq = TrackEffects.filterFrequency(from: 100)
        XCTAssertEqual(freq, 20000.0, accuracy: 10.0)
    }

    func test_filterFrequency_at50_is2kHz() {
        // 200 * 100^0.5 = 200 * 10 = 2000 Hz
        let freq = TrackEffects.filterFrequency(from: 50)
        XCTAssertEqual(freq, 2000.0, accuracy: 5.0)
    }

    func test_filterFrequency_monotonicIncreasing() {
        var prev: Float = 0
        for i in stride(from: 0, through: 100, by: 10) {
            let freq = TrackEffects.filterFrequency(from: Float(i))
            XCTAssertGreaterThanOrEqual(freq, prev)
            prev = freq
        }
    }

    func test_filterFrequency_alwaysPositive() {
        for i in 0...100 {
            let freq = TrackEffects.filterFrequency(from: Float(i))
            XCTAssertGreaterThan(freq, 0)
        }
    }

    // MARK: - DelaySyncDivision

    func test_delaySyncDivision_displayName_sixteenth() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.sixteenth.displayName, "1/16")
    }

    func test_delaySyncDivision_displayName_eighth() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.eighth.displayName, "1/8")
    }

    func test_delaySyncDivision_displayName_quarter() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.quarter.displayName, "1/4")
    }

    func test_delaySyncDivision_multiplier_sixteenth() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.sixteenth.quarterNoteMultiplier, 0.25, accuracy: 0.001)
    }

    func test_delaySyncDivision_multiplier_eighth() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.eighth.quarterNoteMultiplier, 0.5, accuracy: 0.001)
    }

    func test_delaySyncDivision_multiplier_quarter() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.quarter.quarterNoteMultiplier, 1.0, accuracy: 0.001)
    }

    func test_delaySyncDivision_allCasesCount() {
        XCTAssertEqual(TrackEffects.DelaySyncDivision.allCases.count, 3)
    }

    func test_delaySyncDivision_rawValueRoundTrip() {
        for div in TrackEffects.DelaySyncDivision.allCases {
            XCTAssertEqual(TrackEffects.DelaySyncDivision(rawValue: div.rawValue), div)
        }
    }

    // MARK: - Codable

    func test_codable_roundTrip() throws {
        var fx = TrackEffects()
        fx.pan = 0.5
        fx.pitch = -3
        fx.filterCutoff = 75
        fx.humanize = 20
        fx.reverbWet = 40
        fx.delayWet = 60
        fx.delaySyncDivision = .quarter
        fx.distortionWet = 10

        let data = try JSONEncoder().encode(fx)
        let decoded = try JSONDecoder().decode(TrackEffects.self, from: data)

        XCTAssertEqual(decoded.pan, fx.pan, accuracy: 0.001)
        XCTAssertEqual(decoded.pitch, fx.pitch, accuracy: 0.001)
        XCTAssertEqual(decoded.filterCutoff, fx.filterCutoff, accuracy: 0.001)
        XCTAssertEqual(decoded.humanize, fx.humanize, accuracy: 0.001)
        XCTAssertEqual(decoded.reverbWet, fx.reverbWet, accuracy: 0.001)
        XCTAssertEqual(decoded.delayWet, fx.delayWet, accuracy: 0.001)
        XCTAssertEqual(decoded.delaySyncDivision, fx.delaySyncDivision)
        XCTAssertEqual(decoded.distortionWet, fx.distortionWet, accuracy: 0.001)
    }

    func test_codable_defaultRoundTrip() throws {
        let fx = TrackEffects.default
        let data = try JSONEncoder().encode(fx)
        let decoded = try JSONDecoder().decode(TrackEffects.self, from: data)
        XCTAssertEqual(decoded, fx)
    }

    // MARK: - Equatable

    func test_equatable_sameDefaultValues() {
        XCTAssertEqual(TrackEffects(), TrackEffects())
    }

    func test_equatable_differentReverb() {
        var fx1 = TrackEffects()
        fx1.reverbWet = 50
        XCTAssertNotEqual(fx1, TrackEffects())
    }

    func test_equatable_differentDivision() {
        var fx1 = TrackEffects()
        fx1.delaySyncDivision = .quarter
        var fx2 = TrackEffects()
        fx2.delaySyncDivision = .sixteenth
        XCTAssertNotEqual(fx1, fx2)
    }

    func test_equatable_symmetry() {
        var fx1 = TrackEffects()
        fx1.pan = 0.3
        var fx2 = TrackEffects()
        fx2.pan = 0.3
        XCTAssertEqual(fx1, fx2)
        XCTAssertEqual(fx2, fx1)
    }
}

import XCTest
@testable import GlassBeats

final class SessionStateTests: XCTestCase {

    private func makeSession(
        patternName: String = "Test",
        tempo: Double = 120,
        swing: Double = 0.2,
        masterGain: Float = 0.8,
        kitId: String? = "studio",
        patternId: String? = "test-id",
        patternLength: Int? = 16,
        enabledBars: [Bool]? = [true]
    ) -> SessionState {
        SessionState(
            patternName: patternName,
            tempo: tempo,
            swing: swing,
            masterGain: masterGain,
            rows: [:],
            volumes: [:],
            mutes: [:],
            kitId: kitId,
            patternId: patternId,
            effects: nil,
            patternLength: patternLength,
            enabledBars: enabledBars,
            bar2Volumes: nil,
            bar2Effects: nil
        )
    }

    // MARK: - Codable

    func test_codable_patternName() throws {
        let s = makeSession(patternName: "My Beat")
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.patternName, "My Beat")
    }

    func test_codable_tempo() throws {
        let s = makeSession(tempo: 145)
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.tempo, 145)
    }

    func test_codable_swing() throws {
        let s = makeSession(swing: 0.33)
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.swing, 0.33, accuracy: 0.001)
    }

    func test_codable_masterGain() throws {
        let s = makeSession(masterGain: 0.65)
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.masterGain, 0.65, accuracy: 0.001)
    }

    func test_codable_kitId() throws {
        let s = makeSession(kitId: "jungle")
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.kitId, "jungle")
    }

    func test_codable_kitId_nil() throws {
        let s = makeSession(kitId: nil)
        let decoded = try roundTrip(s)
        XCTAssertNil(decoded.kitId)
    }

    func test_codable_patternId() throws {
        let s = makeSession(patternId: "jungle-chop")
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.patternId, "jungle-chop")
    }

    func test_codable_patternId_nil() throws {
        let s = makeSession(patternId: nil)
        let decoded = try roundTrip(s)
        XCTAssertNil(decoded.patternId)
    }

    func test_codable_patternLength() throws {
        let s = makeSession(patternLength: 32)
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.patternLength, 32)
    }

    func test_codable_patternLength_nil() throws {
        let s = makeSession(patternLength: nil)
        let decoded = try roundTrip(s)
        XCTAssertNil(decoded.patternLength)
    }

    func test_codable_enabledBars() throws {
        let s = makeSession(enabledBars: [true, false])
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.enabledBars, [true, false])
    }

    func test_codable_enabledBars_nil() throws {
        let s = makeSession(enabledBars: nil)
        let decoded = try roundTrip(s)
        XCTAssertNil(decoded.enabledBars)
    }

    func test_codable_withRows() throws {
        var s = makeSession()
        s.rows = ["kick": Array(repeating: false, count: 16)]
        s.rows["kick"]![0] = true
        let decoded = try roundTrip(s)
        XCTAssertTrue(decoded.rows["kick"]?[0] == true)
    }

    func test_codable_withVolumes() throws {
        var s = makeSession()
        s.volumes = ["kick": 0.75]
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.volumes["kick"] ?? 0, Float(0.75), accuracy: Float(0.001))
    }

    func test_codable_withMutes() throws {
        var s = makeSession()
        s.mutes = ["snare": true]
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.mutes["snare"], true)
    }

    func test_codable_withEffects() throws {
        var s = makeSession()
        var fx = TrackEffects()
        fx.reverbWet = 55
        s.effects = ["hat": fx]
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.effects?["hat"]?.reverbWet ?? 0, Float(55), accuracy: Float(0.001))
    }

    func test_codable_withBar2Volumes() throws {
        var s = makeSession()
        s.bar2Volumes = ["bass": 0.6]
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.bar2Volumes?["bass"] ?? 0, Float(0.6), accuracy: Float(0.001))
    }

    func test_codable_withBar2Effects() throws {
        var s = makeSession()
        var fx = TrackEffects()
        fx.distortionWet = 25
        s.bar2Effects = ["kick": fx]
        let decoded = try roundTrip(s)
        XCTAssertEqual(decoded.bar2Effects?["kick"]?.distortionWet ?? 0, Float(25), accuracy: Float(0.001))
    }

    // MARK: - Store round-trip via sessionState/loadSession

    func test_storeSessionRoundTrip_allFields() {
        let original = Store()
        original.setTempo(155)
        original.setSwing(0.28)
        original.setMasterGain(0.72)
        original.setPatternName("Full Test")
        original.setKit("808")
        original.setCurrentPatternId("custom-abc")
        original.setPatternLength(32)
        original.toggleStep(trackId: "kick", step: 0)
        original.toggleMute(trackId: "snare")
        original.setVolume(trackId: "bass", value: 0.65)

        let session = original.sessionState()
        let restored = Store()
        restored.loadSession(session)

        XCTAssertEqual(restored.tempo, 155)
        XCTAssertEqual(restored.swing, 0.28, accuracy: 0.001)
        XCTAssertEqual(restored.masterGain, 0.72, accuracy: 0.001)
        XCTAssertEqual(restored.patternName, "Full Test")
        XCTAssertEqual(restored.currentKitId, "808")
        XCTAssertEqual(restored.currentPatternId, "custom-abc")
        XCTAssertEqual(restored.patternLength, 32)
        XCTAssertTrue(restored.rows["kick"]?[0] == true)
        XCTAssertTrue(restored.mutes["snare"] == true)
        XCTAssertEqual(restored.volumes["bass"] ?? 0, Float(0.65), accuracy: Float(0.001))
    }

    // MARK: - Helpers

    private func roundTrip(_ session: SessionState) throws -> SessionState {
        let data = try JSONEncoder().encode(session)
        return try JSONDecoder().decode(SessionState.self, from: data)
    }
}

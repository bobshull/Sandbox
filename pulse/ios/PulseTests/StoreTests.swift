import XCTest
import Combine
@testable import Pulse

final class StoreTests: XCTestCase {
    var store: Store!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        store = Store()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_init_tempoMatchesAppSettings() {
        XCTAssertEqual(store.tempo, AppSettings.defaultTempo)
    }

    func test_init_swingIs018() {
        XCTAssertEqual(store.swing, 0.18, accuracy: 0.001)
    }

    func test_init_masterGainIs085() {
        XCTAssertEqual(store.masterGain, 0.85, accuracy: 0.001)
    }

    func test_init_allTracksHaveRows() {
        for track in Tracks.all {
            XCTAssertNotNil(store.rows[track.id])
        }
    }

    func test_init_rowsAre16Steps() {
        for track in Tracks.all {
            XCTAssertEqual(store.rows[track.id]?.count, 16)
        }
    }

    func test_init_allStepsOff() {
        for track in Tracks.all {
            XCTAssertTrue(store.rows[track.id]?.allSatisfy { !$0 } == true)
        }
    }

    func test_init_allMutesFalse() {
        for track in Tracks.all {
            XCTAssertEqual(store.mutes[track.id], false)
        }
    }

    func test_init_allVolumesOne() {
        for track in Tracks.all {
            XCTAssertEqual(store.volumes[track.id] ?? 0, Float(1.0), accuracy: Float(0.001))
        }
    }

    func test_init_notDirty() {
        XCTAssertFalse(store.isDirty)
    }

    func test_init_cannotUndo() {
        XCTAssertFalse(store.canUndo)
    }

    func test_init_patternLength16() {
        XCTAssertEqual(store.patternLength, 16)
    }

    func test_init_enabledBarsOneBar() {
        XCTAssertEqual(store.enabledBars, [true])
    }

    func test_init_sequenceStart0() {
        XCTAssertEqual(store.sequenceStart, 0)
    }

    func test_init_sequenceLength16() {
        XCTAssertEqual(store.sequenceLength, 16)
    }

    func test_init_activeStepIsNegative1() {
        XCTAssertEqual(store.activeStep, -1)
    }

    func test_init_patternNameIsUntitled() {
        XCTAssertEqual(store.patternName, "Untitled")
    }

    func test_init_kitIdIsStudio() {
        XCTAssertEqual(store.currentKitId, "studio")
    }

    // MARK: - setTempo

    func test_setTempo_normalValue() {
        store.setTempo(120)
        XCTAssertEqual(store.tempo, 120)
        XCTAssertTrue(store.isDirty)
    }

    func test_setTempo_clampsToMin() {
        store.setTempo(10)
        XCTAssertEqual(store.tempo, 40)
    }

    func test_setTempo_clampsToMax() {
        store.setTempo(300)
        XCTAssertEqual(store.tempo, 220)
    }

    func test_setTempo_exactMin() {
        store.setTempo(40)
        XCTAssertEqual(store.tempo, 40)
    }

    func test_setTempo_exactMax() {
        store.setTempo(220)
        XCTAssertEqual(store.tempo, 220)
    }

    func test_setTempo_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setTempo(100)
        XCTAssertTrue(received.contains(.tempo))
    }

    // MARK: - setSwing

    func test_setSwing_normalValue() {
        store.setSwing(0.3)
        XCTAssertEqual(store.swing, 0.3, accuracy: 0.001)
        XCTAssertTrue(store.isDirty)
    }

    func test_setSwing_clampsToMin() {
        store.setSwing(-0.5)
        XCTAssertEqual(store.swing, 0.0, accuracy: 0.001)
    }

    func test_setSwing_clampsToMax() {
        store.setSwing(1.0)
        XCTAssertEqual(store.swing, 0.6, accuracy: 0.001)
    }

    func test_setSwing_exactMin() {
        store.setSwing(0.0)
        XCTAssertEqual(store.swing, 0.0, accuracy: 0.001)
    }

    func test_setSwing_exactMax() {
        store.setSwing(0.6)
        XCTAssertEqual(store.swing, 0.6, accuracy: 0.001)
    }

    func test_setSwing_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setSwing(0.2)
        XCTAssertTrue(received.contains(.swing))
    }

    // MARK: - setMasterGain

    func test_setMasterGain_normalValue() {
        store.setMasterGain(0.5)
        XCTAssertEqual(store.masterGain, 0.5, accuracy: 0.001)
        XCTAssertTrue(store.isDirty)
    }

    func test_setMasterGain_clampsToMin() {
        store.setMasterGain(-0.5)
        XCTAssertEqual(store.masterGain, 0.0, accuracy: 0.001)
    }

    func test_setMasterGain_clampsToMax() {
        store.setMasterGain(1.5)
        XCTAssertEqual(store.masterGain, 1.0, accuracy: 0.001)
    }

    func test_setMasterGain_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setMasterGain(0.5)
        XCTAssertTrue(received.contains(.master))
    }

    // MARK: - toggleStep

    func test_toggleStep_turnsStepOn() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0)
        XCTAssertTrue(store.rows[trackId]?[0] == true)
    }

    func test_toggleStep_turnsStepOff() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0)
        store.toggleStep(trackId: trackId, step: 0)
        XCTAssertTrue(store.rows[trackId]?[0] == false)
    }

    func test_toggleStep_marksDirty() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        XCTAssertTrue(store.isDirty)
    }

    func test_toggleStep_pushesUndo() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        XCTAssertTrue(store.canUndo)
    }

    func test_toggleStep_invalidStep_noEffect() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 99)
        XCTAssertFalse(store.canUndo)
    }

    func test_toggleStep_invalidTrack_noEffect() {
        store.toggleStep(trackId: "nonexistent", step: 0)
        XCTAssertFalse(store.canUndo)
    }

    func test_toggleStep_sendsPatternChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        XCTAssertTrue(received.contains(.pattern))
    }

    func test_toggleStep_updatesSnapshot() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0)
        XCTAssertTrue(store.audioSnapshot().rows[trackId]?[0] == true)
    }

    // MARK: - toggleMute

    func test_toggleMute_mutesTrack() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId)
        XCTAssertTrue(store.mutes[trackId] == true)
    }

    func test_toggleMute_unmutesTrack() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId)
        store.toggleMute(trackId: trackId)
        XCTAssertFalse(store.mutes[trackId] == true)
    }

    func test_toggleMute_pushesUndo() {
        store.toggleMute(trackId: Tracks.all[0].id)
        XCTAssertTrue(store.canUndo)
    }

    func test_toggleMute_marksDirty() {
        store.toggleMute(trackId: Tracks.all[0].id)
        XCTAssertTrue(store.isDirty)
    }

    func test_toggleMute_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.toggleMute(trackId: Tracks.all[0].id)
        XCTAssertTrue(received.contains(.mutes))
    }

    func test_toggleMute_updatesSnapshot() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId)
        XCTAssertTrue(store.audioSnapshot().mutes[trackId] == true)
    }

    // MARK: - setVolume

    func test_setVolume_normalValue() {
        let trackId = Tracks.all[0].id
        store.setVolume(trackId: trackId, value: 0.7)
        XCTAssertEqual(store.volumes[trackId] ?? 0, Float(0.7), accuracy: Float(0.001))
    }

    func test_setVolume_clampsToMin() {
        let trackId = Tracks.all[0].id
        store.setVolume(trackId: trackId, value: -0.5)
        XCTAssertEqual(store.volumes[trackId] ?? 1, Float(0.0), accuracy: Float(0.001))
    }

    func test_setVolume_clampsToMax() {
        let trackId = Tracks.all[0].id
        store.setVolume(trackId: trackId, value: 1.5)
        XCTAssertEqual(store.volumes[trackId] ?? 0, Float(1.0), accuracy: Float(0.001))
    }

    func test_setVolume_marksDirty() {
        store.setVolume(trackId: Tracks.all[0].id, value: 0.5)
        XCTAssertTrue(store.isDirty)
    }

    func test_setVolume_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setVolume(trackId: Tracks.all[0].id, value: 0.5)
        XCTAssertTrue(received.contains(.volumes))
    }

    func test_setVolume_bar1() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.setVolume(trackId: trackId, value: 0.5, bar: 1)
        XCTAssertEqual(store.volumes(for: 1)[trackId] ?? 0, Float(0.5), accuracy: Float(0.001))
    }

    func test_setVolume_bar0AndBar1Independent() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.setVolume(trackId: trackId, value: 0.3, bar: 0)
        store.setVolume(trackId: trackId, value: 0.7, bar: 1)
        XCTAssertEqual(store.volumes(for: 0)[trackId] ?? 0, Float(0.3), accuracy: Float(0.001))
        XCTAssertEqual(store.volumes(for: 1)[trackId] ?? 0, Float(0.7), accuracy: Float(0.001))
    }

    // MARK: - setTrackEffects

    func test_setTrackEffects_bar0() {
        let trackId = Tracks.all[0].id
        var fx = TrackEffects()
        fx.reverbWet = 50
        store.setTrackEffects(trackId: trackId, fx)
        XCTAssertEqual(store.effects[trackId]?.reverbWet ?? 0, Float(50), accuracy: Float(0.001))
    }

    func test_setTrackEffects_bar1() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        var fx = TrackEffects()
        fx.delayWet = 30
        store.setTrackEffects(trackId: trackId, fx, bar: 1)
        XCTAssertEqual(store.effects(for: 1)[trackId]?.delayWet ?? 0, Float(30), accuracy: Float(0.001))
    }

    func test_setTrackEffects_marksDirty() {
        store.setTrackEffects(trackId: Tracks.all[0].id, TrackEffects())
        XCTAssertTrue(store.isDirty)
    }

    func test_setTrackEffects_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setTrackEffects(trackId: Tracks.all[0].id, TrackEffects())
        XCTAssertTrue(received.contains(.effects))
    }

    // MARK: - setActiveStep

    func test_setActiveStep() {
        store.setActiveStep(5)
        XCTAssertEqual(store.activeStep, 5)
    }

    func test_setActiveStep_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setActiveStep(3)
        XCTAssertTrue(received.contains(.step))
    }

    func test_setActiveStep_negative1() {
        store.setActiveStep(5)
        store.setActiveStep(-1)
        XCTAssertEqual(store.activeStep, -1)
    }

    // MARK: - setPatternName

    func test_setPatternName() {
        store.setPatternName("My Beat")
        XCTAssertEqual(store.patternName, "My Beat")
    }

    func test_setPatternName_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setPatternName("Test")
        XCTAssertTrue(received.contains(.name))
    }

    // MARK: - setCurrentPatternId

    func test_setCurrentPatternId() {
        store.setCurrentPatternId("my-custom-id")
        XCTAssertEqual(store.currentPatternId, "my-custom-id")
    }

    // MARK: - setKit

    func test_setKit() {
        store.setKit("jungle")
        XCTAssertEqual(store.currentKitId, "jungle")
        XCTAssertTrue(store.isDirty)
    }

    func test_setKit_pushesUndo() {
        store.setKit("jungle")
        XCTAssertTrue(store.canUndo)
    }

    func test_setKit_sendsChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setKit("808")
        XCTAssertTrue(received.contains(.kit))
    }

    // MARK: - setPatternLength

    func test_setPatternLength_to32() {
        store.setPatternLength(32)
        XCTAssertEqual(store.patternLength, 32)
        XCTAssertEqual(store.enabledBars, [true, true])
    }

    func test_setPatternLength_to32_expandsRows() {
        store.setPatternLength(32)
        for track in Tracks.all {
            XCTAssertEqual(store.rows[track.id]?.count, 32)
        }
    }

    func test_setPatternLength_to32_bar1IsBlank() {
        store.setPatternLength(32)
        for track in Tracks.all {
            let bar2 = Array(store.rows[track.id]?.suffix(16) ?? [])
            XCTAssertTrue(bar2.allSatisfy { !$0 })
        }
    }

    func test_setPatternLength_to16_from32() {
        store.setPatternLength(32)
        store.setPatternLength(16)
        XCTAssertEqual(store.patternLength, 16)
        XCTAssertEqual(store.enabledBars, [true])
    }

    func test_setPatternLength_to32_preservesBar1Steps() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 3)
        store.setPatternLength(32)
        XCTAssertTrue(store.rows[trackId]?[3] == true)
    }

    func test_setPatternLength_sameLength_noOp() {
        store.setPatternLength(16)
        XCTAssertFalse(store.canUndo)
    }

    func test_setPatternLength_invalidValue_noOp() {
        store.setPatternLength(8)
        XCTAssertEqual(store.patternLength, 16)
    }

    func test_setPatternLength_to32_pushesUndo() {
        store.setPatternLength(32)
        XCTAssertTrue(store.canUndo)
    }

    func test_setPatternLength_to32_marksDirty() {
        store.setPatternLength(32)
        XCTAssertTrue(store.isDirty)
    }

    func test_setPatternLength_to32_updatesSnapshot() {
        store.setPatternLength(32)
        XCTAssertEqual(store.audioSnapshot().patternLength, 32)
    }

    func test_setPatternLength_to32_sendsChanges() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.setPatternLength(32)
        XCTAssertTrue(received.contains(.patternLength))
        XCTAssertTrue(received.contains(.pattern))
    }

    func test_setPatternLength_to32_doesNotExpandAlready32Rows() {
        // Set to 32 first, add a bar2 step, then switch to 16 and back to 32
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.toggleStep(trackId: trackId, step: 16) // set bar2 step
        store.setPatternLength(16)
        store.setPatternLength(32)
        // Bar2 step should still be set (preserved 32-step rows)
        XCTAssertTrue(store.rows[trackId]?[16] == true)
    }

    // MARK: - sequenceStart / sequenceLength

    func test_sequenceStart_16step_is0() {
        XCTAssertEqual(store.sequenceStart, 0)
    }

    func test_sequenceStart_32step_bothBarsEnabled_is0() {
        store.setPatternLength(32)
        XCTAssertEqual(store.sequenceStart, 0)
    }

    func test_sequenceStart_32step_onlyBar2Enabled_is16() {
        store.setPatternLength(32)
        store.toggleBar(0) // disable bar 1, bar 2 is still on
        XCTAssertEqual(store.sequenceStart, 16)
    }

    func test_sequenceLength_16step_is16() {
        XCTAssertEqual(store.sequenceLength, 16)
    }

    func test_sequenceLength_32step_bothBars_is32() {
        store.setPatternLength(32)
        XCTAssertEqual(store.sequenceLength, 32)
    }

    func test_sequenceLength_32step_oneBarEnabled_is16() {
        store.setPatternLength(32)
        store.toggleBar(1) // disable bar 2
        XCTAssertEqual(store.sequenceLength, 16)
    }

    // MARK: - toggleBar

    func test_toggleBar_disablesBar2() {
        store.setPatternLength(32)
        store.toggleBar(1)
        XCTAssertEqual(store.enabledBars, [true, false])
    }

    func test_toggleBar_reEnablesBar2() {
        store.setPatternLength(32)
        store.toggleBar(1)
        store.toggleBar(1)
        XCTAssertEqual(store.enabledBars, [true, true])
    }

    func test_toggleBar_cannotDisableOnlyActiveBar() {
        store.setPatternLength(32)
        store.toggleBar(1) // disable bar 2
        store.toggleBar(0) // try to disable bar 1 (only active)
        XCTAssertEqual(store.enabledBars, [true, false]) // bar 1 still enabled
    }

    func test_toggleBar_noOpIn16StepMode() {
        store.toggleBar(0) // 16-step mode, should be no-op
        XCTAssertEqual(store.enabledBars, [true])
    }

    func test_toggleBar_marksDirty() {
        store.setPatternLength(32)
        store.toggleBar(1)
        XCTAssertTrue(store.isDirty)
    }

    func test_toggleBar_updatesSnapshot() {
        store.setPatternLength(32)
        store.toggleBar(1)
        XCTAssertEqual(store.audioSnapshot().sequenceLength, 16)
    }

    // MARK: - expandToTwoBarsDuplicate

    func test_expandToTwoBarsDuplicate_doublesLength() {
        store.expandToTwoBarsDuplicate()
        XCTAssertEqual(store.patternLength, 32)
    }

    func test_expandToTwoBarsDuplicate_duplicatesSteps() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 3)
        store.expandToTwoBarsDuplicate()
        XCTAssertTrue(store.rows[trackId]?[3] == true)
        XCTAssertTrue(store.rows[trackId]?[19] == true) // 3 + 16
    }

    func test_expandToTwoBarsDuplicate_noOpWhenAlready32Step() {
        store.setPatternLength(32)
        store.toggleStep(trackId: Tracks.all[0].id, step: 16)
        store.expandToTwoBarsDuplicate() // should be no-op
        XCTAssertTrue(store.rows[Tracks.all[0].id]?[16] == true)
    }

    func test_expandToTwoBarsDuplicate_pushesUndo() {
        store.expandToTwoBarsDuplicate()
        XCTAssertTrue(store.canUndo)
    }

    func test_expandToTwoBarsDuplicate_copiesBar0VolumesToBar1() {
        let trackId = Tracks.all[0].id
        store.setVolume(trackId: trackId, value: 0.6)
        store.expandToTwoBarsDuplicate()
        XCTAssertEqual(store.volumes(for: 1)[trackId] ?? 0, Float(0.6), accuracy: Float(0.001))
    }

    // MARK: - duplicateBar1

    func test_duplicateBar1_copiesBar1ToBar2() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.toggleStep(trackId: trackId, step: 2)
        // Clear bar2 by setting all to false initially (they should be)
        store.duplicateBar1()
        XCTAssertTrue(store.rows[trackId]?[2] == true)
        XCTAssertTrue(store.rows[trackId]?[18] == true) // 2 + 16
    }

    func test_duplicateBar1_noOpIn16StepMode() {
        store.duplicateBar1()
        XCTAssertFalse(store.canUndo)
    }

    func test_duplicateBar1_pushesUndo() {
        store.setPatternLength(32)
        store.duplicateBar1()
        XCTAssertTrue(store.canUndo)
    }

    func test_duplicateBar1_copiesBar0VolumesToBar1() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.setVolume(trackId: trackId, value: 0.4, bar: 0)
        store.duplicateBar1()
        XCTAssertEqual(store.volumes(for: 1)[trackId] ?? 0, Float(0.4), accuracy: Float(0.001))
    }

    // MARK: - clearPattern

    func test_clearPattern_clearsAllSteps() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0)
        store.clearPattern()
        XCTAssertTrue(store.rows[trackId]?.allSatisfy { !$0 } == true)
    }

    func test_clearPattern_pushesUndo() {
        store.clearPattern()
        XCTAssertTrue(store.canUndo)
    }

    func test_clearPattern_marksDirty() {
        store.clearPattern()
        XCTAssertTrue(store.isDirty)
    }

    func test_clearPattern_preservesLength() {
        store.setPatternLength(32)
        store.clearPattern()
        XCTAssertEqual(store.patternLength, 32)
        for track in Tracks.all {
            XCTAssertEqual(store.rows[track.id]?.count, 32)
        }
    }

    // MARK: - hasBar2Content / hasPreservedBar2

    func test_hasBar2Content_falseWhenNoBar2Steps() {
        store.setPatternLength(32)
        XCTAssertFalse(store.hasBar2Content)
    }

    func test_hasBar2Content_trueWhenBar2HasStep() {
        let trackId = Tracks.all[0].id
        store.setPatternLength(32)
        store.toggleStep(trackId: trackId, step: 16)
        XCTAssertTrue(store.hasBar2Content)
    }

    func test_hasBar2Content_falseIn16StepMode() {
        XCTAssertFalse(store.hasBar2Content)
    }

    func test_hasPreservedBar2_falseIn16Step() {
        XCTAssertFalse(store.hasPreservedBar2)
    }

    func test_hasPreservedBar2_trueAfterExpandingTo32() {
        store.setPatternLength(32)
        XCTAssertTrue(store.hasPreservedBar2)
    }

    func test_hasPreservedBar2_trueAfterExpandingThenBack() {
        store.setPatternLength(32)
        store.setPatternLength(16)
        XCTAssertTrue(store.hasPreservedBar2)
    }

    // MARK: - isCurrentPatternPreset / isCurrentPatternUserSaved

    func test_isCurrentPatternPreset_falseForEmptyId() {
        XCTAssertFalse(store.isCurrentPatternPreset)
    }

    func test_isCurrentPatternPreset_trueForPresetId() {
        store.setCurrentPatternId("jungle-chop")
        XCTAssertTrue(store.isCurrentPatternPreset)
    }

    func test_isCurrentPatternUserSaved_falseForEmptyId() {
        XCTAssertFalse(store.isCurrentPatternUserSaved)
    }

    func test_isCurrentPatternUserSaved_falseForPreset() {
        store.setCurrentPatternId("jungle-chop")
        XCTAssertFalse(store.isCurrentPatternUserSaved)
    }

    func test_isCurrentPatternUserSaved_trueForCustomId() {
        store.setCurrentPatternId("custom-uuid-123")
        XCTAssertTrue(store.isCurrentPatternUserSaved)
    }

    // MARK: - Undo

    func test_undo_restoresStep() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0) // on → pushes [off-state]
        store.toggleStep(trackId: trackId, step: 0) // off → pushes [on-state]
        store.undo()
        XCTAssertTrue(store.rows[trackId]?[0] == true) // restored to on
    }

    func test_undo_restoresMute() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId) // muted → pushes [unmuted-state]
        store.undo()
        XCTAssertFalse(store.mutes[trackId] == true)
    }

    func test_undo_restoresTempo() {
        // pushUndo captures current state; if we change tempo then trigger an undo-tracked action
        store.setTempo(200)
        store.toggleStep(trackId: Tracks.all[0].id, step: 0) // pushes state with tempo=200
        store.setTempo(80)
        store.undo()
        XCTAssertEqual(store.tempo, 200)
    }

    func test_undo_restoresKit() {
        store.setKit("jungle")  // pushes state with kit=studio
        store.undo()
        XCTAssertEqual(store.currentKitId, "studio")
    }

    func test_undo_marksAsDirty() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        store.markClean()
        store.undo()
        XCTAssertTrue(store.isDirty)
    }

    func test_undo_emptyStack_noEffect() {
        let tempo = store.tempo
        store.undo()
        XCTAssertEqual(store.tempo, tempo)
    }

    func test_undo_stackLimitedTo50() {
        for i in 0..<51 {
            store.toggleStep(trackId: Tracks.all[0].id, step: i % 16)
        }
        // Undo 50 times — all succeed
        for _ in 0..<50 {
            store.undo()
        }
        // 51st should be a no-op
        XCTAssertFalse(store.canUndo)
    }

    func test_undo_sendsUndoChange() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.undo()
        XCTAssertTrue(received.contains(.undo))
        XCTAssertTrue(received.contains(.load))
    }

    func test_markClean() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        store.markClean()
        XCTAssertFalse(store.isDirty)
    }

    // MARK: - loadPattern

    func test_loadPattern_setsName() {
        let preset = Presets.all[0]
        store.loadPattern(preset)
        XCTAssertEqual(store.patternName, preset.name)
    }

    func test_loadPattern_setsTempo() {
        let preset = Presets.all[0]
        store.loadPattern(preset)
        XCTAssertEqual(store.tempo, preset.tempo)
    }

    func test_loadPattern_setsSwing() {
        let preset = Presets.all[0]
        store.loadPattern(preset)
        XCTAssertEqual(store.swing, preset.swing, accuracy: 0.001)
    }

    func test_loadPattern_setsPatternId() {
        let preset = Presets.all[0]
        store.loadPattern(preset)
        XCTAssertEqual(store.currentPatternId, preset.id)
    }

    func test_loadPattern_clearsUndoStack() {
        store.toggleStep(trackId: Tracks.all[0].id, step: 0)
        store.loadPattern(Presets.all[0])
        XCTAssertFalse(store.canUndo)
    }

    func test_loadPattern_marksClean() {
        store.loadPattern(Presets.all[0])
        XCTAssertFalse(store.isDirty)
    }

    func test_loadPattern_loads32StepPattern() {
        let preset32 = Presets.all.first { $0.patternLength == 32 }!
        store.loadPattern(preset32)
        XCTAssertEqual(store.patternLength, 32)
    }

    func test_loadPattern_setsKitId() {
        let preset = Presets.all.first { $0.kitId != nil }!
        store.loadPattern(preset)
        XCTAssertEqual(store.currentKitId, preset.kitId)
    }

    func test_loadPattern_defaultsKitToStudio() {
        let noKitPattern = Pattern(id: "x", name: "X", tempo: 90, swing: 0, rows: [:])
        store.loadPattern(noKitPattern)
        XCTAssertEqual(store.currentKitId, "studio")
    }

    func test_loadPattern_sendsLoadChange() {
        var received: [StateSection] = []
        store.changes.sink { received.append($0) }.store(in: &cancellables)
        store.loadPattern(Presets.all[0])
        XCTAssertTrue(received.contains(.load))
    }

    // MARK: - loadPattern (empty preset)

    func test_loadPattern_emptyPreset_usesDefaultTempo() {
        AppSettings.defaultTempo = 128
        defer { UserDefaults.standard.removeObject(forKey: "pulse.defaultTempo") }
        let empty = Presets.all.first { $0.id == "empty" }!
        store.loadPattern(empty)
        XCTAssertEqual(store.tempo, 128)
    }

    func test_loadPattern_emptyPreset_defaultTempoWhenNeverSet() {
        UserDefaults.standard.removeObject(forKey: "pulse.defaultTempo")
        let empty = Presets.all.first { $0.id == "empty" }!
        store.loadPattern(empty)
        XCTAssertEqual(store.tempo, 96)  // AppSettings fallback
    }

    func test_loadPattern_emptyPreset_ignoresHardcodedTempo() {
        // Hardcoded value in Presets.all is 96; setting default to something else must win.
        AppSettings.defaultTempo = 140
        defer { UserDefaults.standard.removeObject(forKey: "pulse.defaultTempo") }
        let empty = Presets.all.first { $0.id == "empty" }!
        XCTAssertEqual(empty.tempo, 96, "test precondition: empty preset still has 96 baked in")
        store.loadPattern(empty)
        XCTAssertEqual(store.tempo, 140)
    }

    func test_loadPattern_nonEmptyPreset_usesPatternTempo() {
        // A non-empty preset must NOT be overridden by AppSettings.defaultTempo.
        AppSettings.defaultTempo = 200
        defer { UserDefaults.standard.removeObject(forKey: "pulse.defaultTempo") }
        let preset = Presets.all.first { $0.id != "empty" }!
        store.loadPattern(preset)
        XCTAssertEqual(store.tempo, preset.tempo)
    }

    func test_loadPattern_customPattern_usesPatternTempo() {
        // A user-saved pattern with a specific tempo must load that tempo regardless of default.
        AppSettings.defaultTempo = 200
        defer { UserDefaults.standard.removeObject(forKey: "pulse.defaultTempo") }
        let custom = Pattern(id: "custom-uuid-abc", name: "My Beat", tempo: 110, swing: 0, rows: [:])
        store.loadPattern(custom)
        XCTAssertEqual(store.tempo, 110)
    }

    // MARK: - exportPattern

    func test_exportPattern_hasCurrentName() {
        store.setPatternName("Test Export")
        let exported = store.exportPattern()
        XCTAssertEqual(exported.name, "Test Export")
    }

    func test_exportPattern_hasTempo() {
        store.setTempo(140)
        let exported = store.exportPattern()
        XCTAssertEqual(exported.tempo, 140)
    }

    func test_exportPattern_hasSwing() {
        store.setSwing(0.35)
        let exported = store.exportPattern()
        XCTAssertEqual(exported.swing, 0.35, accuracy: 0.001)
    }

    func test_exportPattern_16stepRowsAre16Long() {
        let exported = store.exportPattern()
        for (_, row) in exported.rows {
            XCTAssertEqual(row.count, 16)
        }
    }

    func test_exportPattern_32stepRowsAre32Long() {
        store.setPatternLength(32)
        let exported = store.exportPattern()
        for (_, row) in exported.rows {
            XCTAssertEqual(row.count, 32)
        }
    }

    func test_exportPattern_hasNewUniqueId() {
        store.setCurrentPatternId("old-id")
        let e1 = store.exportPattern()
        let e2 = store.exportPattern()
        XCTAssertNotEqual(e1.id, "old-id")
        XCTAssertNotEqual(e1.id, e2.id)
    }

    func test_exportPattern_hasCurrentKit() {
        store.setKit("808")
        let exported = store.exportPattern()
        XCTAssertEqual(exported.kitId, "808")
    }

    func test_exportPattern_includesMutes() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId)
        let exported = store.exportPattern()
        XCTAssertTrue(exported.mutes?[trackId] == true)
    }

    // MARK: - sessionState / loadSession

    func test_sessionState_roundTrip() {
        store.setTempo(130)
        store.setSwing(0.25)
        store.setMasterGain(0.6)
        store.setPatternName("Round Trip")
        let session = store.sessionState()
        let store2 = Store()
        store2.loadSession(session)
        XCTAssertEqual(store2.tempo, 130)
        XCTAssertEqual(store2.swing, 0.25, accuracy: 0.001)
        XCTAssertEqual(store2.masterGain, Float(0.6), accuracy: Float(0.001))
        XCTAssertEqual(store2.patternName, "Round Trip")
    }

    func test_loadSession_notDirty() {
        let session = store.sessionState()
        store.setTempo(200)
        store.loadSession(session)
        XCTAssertFalse(store.isDirty)
    }

    func test_loadSession_restoresPatternLength() {
        store.setPatternLength(32)
        let session = store.sessionState()
        let store2 = Store()
        store2.loadSession(session)
        XCTAssertEqual(store2.patternLength, 32)
    }

    func test_loadSession_restoresKit() {
        store.setKit("jungle")
        let session = store.sessionState()
        let store2 = Store()
        store2.loadSession(session)
        XCTAssertEqual(store2.currentKitId, "jungle")
    }

    func test_loadSession_withNilOptionalsUsesDefaults() {
        let minimal = SessionState(
            patternName: "Min",
            tempo: 100,
            swing: 0.1,
            masterGain: 0.5,
            rows: [:],
            volumes: [:],
            mutes: [:],
            kitId: nil,
            patternId: nil,
            effects: nil,
            patternLength: nil,
            enabledBars: nil,
            bar2Volumes: nil,
            bar2Effects: nil
        )
        store.loadSession(minimal)
        XCTAssertEqual(store.currentKitId, "studio")
        XCTAssertEqual(store.patternLength, 16)
        for track in Tracks.all {
            XCTAssertEqual(store.volumes[track.id] ?? -1, Float(1.0), accuracy: Float(0.001))
            XCTAssertEqual(store.mutes[track.id], false)
            XCTAssertEqual(store.effects[track.id], TrackEffects.default)
            XCTAssertEqual(store.effects(for: 1)[track.id], TrackEffects.default)
        }
    }

    func test_loadSession_with32StepAndNilEnabledBarsUsesDefault() {
        let session = SessionState(
            patternName: "Two",
            tempo: 120,
            swing: 0,
            masterGain: 1,
            rows: [:],
            volumes: [:],
            mutes: [:],
            kitId: "studio",
            patternId: nil,
            effects: nil,
            patternLength: 32,
            enabledBars: nil,  // should default to [true, true] for 32-step
            bar2Volumes: nil,
            bar2Effects: nil
        )
        store.loadSession(session)
        XCTAssertEqual(store.patternLength, 32)
        XCTAssertEqual(store.enabledBars, [true, true])
    }

    func test_sessionState_16stepRowsCappedAt16() {
        store.setPatternLength(32)
        store.setPatternLength(16)
        let session = store.sessionState()
        for (_, row) in session.rows {
            XCTAssertEqual(row.count, 16)
        }
    }

    // MARK: - audioSnapshot

    func test_audioSnapshot_consistentWithState() {
        let trackId = Tracks.all[0].id
        store.toggleStep(trackId: trackId, step: 0)
        let snap = store.audioSnapshot()
        XCTAssertTrue(snap.rows[trackId]?[0] == true)
    }

    func test_audioSnapshot_patternLength() {
        store.setPatternLength(32)
        let snap = store.audioSnapshot()
        XCTAssertEqual(snap.patternLength, 32)
    }

    func test_audioSnapshot_sequenceStart() {
        store.setPatternLength(32)
        store.toggleBar(0) // only bar 2 active → start = 16
        let snap = store.audioSnapshot()
        XCTAssertEqual(snap.sequenceStart, 16)
    }

    func test_audioSnapshot_sequenceLength_32stepBothBars() {
        store.setPatternLength(32)
        let snap = store.audioSnapshot()
        XCTAssertEqual(snap.sequenceLength, 32)
    }

    func test_audioSnapshot_mutes() {
        let trackId = Tracks.all[0].id
        store.toggleMute(trackId: trackId)
        XCTAssertTrue(store.audioSnapshot().mutes[trackId] == true)
    }

    // MARK: - volumes(for:) / effects(for:)

    func test_volumesFor0_matchesVolumes() {
        let trackId = Tracks.all[0].id
        store.setVolume(trackId: trackId, value: 0.42)
        XCTAssertEqual(store.volumes(for: 0)[trackId], store.volumes[trackId])
    }

    func test_effectsFor0_matchesEffects() {
        let trackId = Tracks.all[0].id
        var fx = TrackEffects()
        fx.reverbWet = 77
        store.setTrackEffects(trackId: trackId, fx)
        XCTAssertEqual(store.effects(for: 0)[trackId]?.reverbWet, store.effects[trackId]?.reverbWet)
    }
}

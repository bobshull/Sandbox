import XCTest
import AVFoundation
@testable import Pulse

final class ExportPlanTests: XCTestCase {

    // 48kHz keeps the math integral: tempo 120 → 0.125s/step → 6000 frames/step.
    private let sr: Double = 48_000
    private let framesPerStep: AVAudioFramePosition = 6_000

    private func emptyRows(length: Int = 16) -> [String: [Bool]] {
        var rows: [String: [Bool]] = [:]
        for t in Tracks.all { rows[t.id] = Array(repeating: false, count: length) }
        return rows
    }

    private func makeSnapshot(tempo: Double = 120,
                              swing: Double = 0,
                              rows: [String: [Bool]],
                              mutes: [String: Bool] = [:],
                              barEffects: [[String: TrackEffects]] = [[:], [:]],
                              patternLength: Int = 16,
                              sequenceStart: Int = 0,
                              sequenceLength: Int = 16,
                              accents: [String: [Bool]] = [:],
                              grooveSeed: UInt64 = 42) -> Store.AudioSnapshot {
        Store.AudioSnapshot(tempo: tempo, swing: swing, masterGain: 1,
                            rows: rows, mutes: mutes,
                            barVolumes: [[:], [:]], barEffects: barEffects,
                            patternLength: patternLength,
                            sequenceStart: sequenceStart, sequenceLength: sequenceLength,
                            accents: accents, grooveSeed: grooveSeed)
    }

    private func makeBuffer(_ values: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(values.count))!
        buf.frameLength = AVAudioFrameCount(values.count)
        for ch in 0..<2 {
            for i in 0..<values.count { buf.floatChannelData![ch][i] = values[i] }
        }
        return buf
    }

    private func ramp(_ n: Int) -> AVAudioPCMBuffer { makeBuffer((0..<n).map(Float.init)) }
    private func constant(_ v: Float, _ n: Int) -> AVAudioPCMBuffer { makeBuffer(Array(repeating: v, count: n)) }
    private var stereoFormat: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)! }

    // MARK: - Plan duration

    func test_plan_16stepDuration() {
        let plan = ExportPlanBuilder.build(snapshot: makeSnapshot(rows: emptyRows()), reps: 1, sampleRate: sr)
        XCTAssertEqual(plan.totalFrames, 16 * framesPerStep)
    }

    func test_plan_loopCountScalesDuration() {
        let snap = makeSnapshot(rows: emptyRows())
        let one = ExportPlanBuilder.build(snapshot: snap, reps: 1, sampleRate: sr)
        let eight = ExportPlanBuilder.build(snapshot: snap, reps: 8, sampleRate: sr)
        XCTAssertEqual(eight.totalFrames, 8 * one.totalFrames)
    }

    func test_plan_32stepDuration() {
        let snap = makeSnapshot(rows: emptyRows(length: 32), patternLength: 32,
                                sequenceStart: 0, sequenceLength: 32)
        let plan = ExportPlanBuilder.build(snapshot: snap, reps: 1, sampleRate: sr)
        XCTAssertEqual(plan.totalFrames, 32 * framesPerStep)
    }

    func test_plan_swingPreservesTotalDurationAndDelaysOffbeats() {
        var rows = emptyRows()
        rows["hat"] = (0..<16).map { _ in true }
        let plan = ExportPlanBuilder.build(snapshot: makeSnapshot(swing: 0.2, rows: rows),
                                           reps: 1, sampleRate: sr)
        // Swing borrows from the following downbeat, so the pattern length is unchanged.
        XCTAssertEqual(plan.totalFrames, 16 * framesPerStep)
        let frames = plan.events["hat"]!.map(\.frame)
        // Downbeats stay on the unswung grid; offbeats land late by swing × step.
        XCTAssertEqual(frames[0], 0)
        XCTAssertEqual(frames[1], AVAudioFramePosition(1.2 * Double(framesPerStep)))
        XCTAssertEqual(frames[2], 2 * framesPerStep)
        XCTAssertEqual(frames[3], AVAudioFramePosition(3.2 * Double(framesPerStep)))
    }

    // MARK: - Plan events

    func test_plan_mutedTrackHasNoEvents() {
        var rows = emptyRows()
        rows["kick"] = (0..<16).map { _ in true }
        let snap = makeSnapshot(rows: rows, mutes: ["kick": true])
        let plan = ExportPlanBuilder.build(snapshot: snap, reps: 1, sampleRate: sr)
        XCTAssertNil(plan.events["kick"])
    }

    func test_plan_flagsAccentedSteps() {
        var rows = emptyRows()
        rows["snare"]![4] = true
        rows["snare"]![12] = true
        var accents = [String: [Bool]]()
        accents["snare"] = (0..<16).map { $0 == 12 }
        let plan = ExportPlanBuilder.build(snapshot: makeSnapshot(rows: rows, accents: accents),
                                           reps: 1, sampleRate: sr)
        let events = plan.events["snare"]!
        XCTAssertEqual(events.map(\.isAccented), [false, true])
    }

    func test_plan_humanizeIsDeterministicAndNonzero() {
        var rows = emptyRows()
        rows["hat"] = (0..<16).map { _ in true }
        var fx = TrackEffects(); fx.humanize = 80
        let snap = makeSnapshot(rows: rows, barEffects: [["hat": fx], ["hat": fx]])
        let a = ExportPlanBuilder.build(snapshot: snap, reps: 2, sampleRate: sr)
        let b = ExportPlanBuilder.build(snapshot: snap, reps: 2, sampleRate: sr)
        XCTAssertEqual(a.events["hat"], b.events["hat"])
        XCTAssertEqual(a.totalFrames, b.totalFrames)

        let straight = ExportPlanBuilder.build(snapshot: makeSnapshot(rows: rows),
                                               reps: 2, sampleRate: sr)
        XCTAssertNotEqual(a.events["hat"], straight.events["hat"])
    }

    func test_plan_humanizeRepeatsPerLoop() {
        // Jitter keys off the pattern step, so every loop repetition lands identically.
        // (Step 8, not 0, so negative jitter can't clamp against frame 0.)
        var rows = emptyRows()
        rows["hat"]![8] = true
        var fx = TrackEffects(); fx.humanize = 60
        let snap = makeSnapshot(rows: rows, barEffects: [["hat": fx], ["hat": fx]])
        let plan = ExportPlanBuilder.build(snapshot: snap, reps: 2, sampleRate: sr)
        let events = plan.events["hat"]!
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].frame - events[0].frame, 16 * framesPerStep)
    }

    func test_plan_bar2OnlyLoop() {
        var rows = emptyRows(length: 32)
        rows["snare"]![20] = true
        let snap = makeSnapshot(rows: rows, patternLength: 32,
                                sequenceStart: 16, sequenceLength: 16)
        let plan = ExportPlanBuilder.build(snapshot: snap, reps: 1, sampleRate: sr)
        XCTAssertEqual(plan.totalFrames, 16 * framesPerStep)
        // Step 20 is the 5th step of the bar-2 loop → 4 steps from the start.
        XCTAssertEqual(plan.events["snare"]!.map(\.frame), [4 * framesPerStep])
        XCTAssertEqual(plan.barBoundaries.map(\.bar), [1])
    }

    func test_plan_32stepBarBoundaries() {
        let snap = makeSnapshot(rows: emptyRows(length: 32), patternLength: 32,
                                sequenceStart: 0, sequenceLength: 32)
        let plan = ExportPlanBuilder.build(snapshot: snap, reps: 2, sampleRate: sr)
        XCTAssertEqual(plan.barBoundaries.map(\.bar), [0, 1, 0, 1])
        XCTAssertEqual(plan.barBoundaries.map(\.frame),
                       [0, 16 * framesPerStep, 32 * framesPerStep, 48 * framesPerStep])
    }

    // MARK: - OfflineTrackRenderer

    func test_render_overlappingHitIsCutByNextHit() {
        // "Dense pad": source longer than the gap. Live .interrupts cuts the tail.
        let src = ramp(1000)
        let events = [ExportStepEvent(frame: 0, isAccented: false),
                      ExportStepEvent(frame: 400, isAccented: false)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: src,
                                                 accentBuffer: nil, totalFrames: 10_000,
                                                 format: stereoFormat)!
        XCTAssertEqual(render.startFrame, 0)
        XCTAssertEqual(Int(render.buffer.frameLength), 1400)
        let ch = render.buffer.floatChannelData![0]
        XCTAssertEqual(ch[399], 399)   // first hit plays up to the cut
        XCTAssertEqual(ch[400], 0)     // second hit restarts the source exactly here
        XCTAssertEqual(ch[401], 1)
        XCTAssertEqual(ch[1399], 999)  // second hit's full tail survives
    }

    func test_render_fastRepeatedHits_everyHitStartsOnTime() {
        // "Fast hats": every hit truncated to the gap, starts exactly on its frame.
        let src = ramp(1000)
        let events = (0..<8).map { ExportStepEvent(frame: AVAudioFramePosition($0 * 300), isAccented: false) }
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: src,
                                                 accentBuffer: nil, totalFrames: 10_000,
                                                 format: stereoFormat)!
        let ch = render.buffer.floatChannelData![0]
        for hit in 0..<8 {
            XCTAssertEqual(ch[hit * 300], 0, "hit \(hit) must restart the source at its own frame")
            if hit > 0 {
                XCTAssertEqual(ch[hit * 300 - 1], 299, "hit \(hit - 1) must run right up to the cut")
            }
        }
    }

    func test_render_nonOverlappingHitsKeepFullTailsAndSilenceBetween() {
        let src = ramp(1000)
        let events = [ExportStepEvent(frame: 0, isAccented: false),
                      ExportStepEvent(frame: 2000, isAccented: false)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: src,
                                                 accentBuffer: nil, totalFrames: 10_000,
                                                 format: stereoFormat)!
        let ch = render.buffer.floatChannelData![0]
        XCTAssertEqual(ch[999], 999)
        XCTAssertEqual(ch[1000], 0)    // gap is silent
        XCTAssertEqual(ch[1999], 0)
        XCTAssertEqual(ch[2000], 0)    // second hit starts (ramp begins at 0)
        XCTAssertEqual(ch[2001], 1)
        XCTAssertEqual(Int(render.buffer.frameLength), 3000)
    }

    func test_render_accentedHitUsesAccentBuffer() {
        let normal = constant(1, 500)
        let accent = constant(2, 500)
        let events = [ExportStepEvent(frame: 0, isAccented: false),
                      ExportStepEvent(frame: 600, isAccented: true)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: normal,
                                                 accentBuffer: accent, totalFrames: 10_000,
                                                 format: stereoFormat)!
        let ch = render.buffer.floatChannelData![0]
        XCTAssertEqual(ch[0], 1)
        XCTAssertEqual(ch[600], 2)
        XCTAssertEqual(ch[1099], 2)
    }

    func test_render_hitClippedAtExportEnd() {
        let src = ramp(1000)
        let events = [ExportStepEvent(frame: 9_500, isAccented: false)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: src,
                                                 accentBuffer: nil, totalFrames: 10_000,
                                                 format: stereoFormat)!
        XCTAssertEqual(render.startFrame, 9_500)
        XCTAssertEqual(Int(render.buffer.frameLength), 500)
    }

    func test_render_bufferStartsAtFirstHit() {
        let src = ramp(1000)
        let events = [ExportStepEvent(frame: 5_000, isAccented: false)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: src,
                                                 accentBuffer: nil, totalFrames: 100_000,
                                                 format: stereoFormat)!
        XCTAssertEqual(render.startFrame, 5_000)
        XCTAssertEqual(Int(render.buffer.frameLength), 1000)
        XCTAssertEqual(render.buffer.floatChannelData![0][999], 999)
    }

    func test_render_simultaneousHits_lastWins() {
        let normal = constant(1, 500)
        let accent = constant(2, 500)
        let events = [ExportStepEvent(frame: 100, isAccented: false),
                      ExportStepEvent(frame: 100, isAccented: true)]
        let render = OfflineTrackRenderer.render(events: events, normalBuffer: normal,
                                                 accentBuffer: accent, totalFrames: 10_000,
                                                 format: stereoFormat)!
        XCTAssertEqual(render.buffer.floatChannelData![0][0], 2)
    }

    func test_render_emptyEventsReturnsNil() {
        XCTAssertNil(OfflineTrackRenderer.render(events: [], normalBuffer: ramp(10),
                                                 accentBuffer: nil, totalFrames: 100,
                                                 format: stereoFormat))
    }

    // MARK: - End-to-end determinism (plan + render)

    func test_planAndRender_repeatedRunsAreIdentical() {
        var rows = emptyRows()
        rows["pad"] = (0..<16).map { $0 % 2 == 0 }
        var fx = TrackEffects(); fx.humanize = 50
        let snap = makeSnapshot(swing: 0.15, rows: rows, barEffects: [["pad": fx], ["pad": fx]])
        let src = ramp(20_000)   // longer than a step → exercises truncation

        func renderOnce() -> [Float] {
            let plan = ExportPlanBuilder.build(snapshot: snap, reps: 2, sampleRate: sr)
            let render = OfflineTrackRenderer.render(events: plan.events["pad"]!,
                                                     normalBuffer: src, accentBuffer: nil,
                                                     totalFrames: plan.totalFrames,
                                                     format: stereoFormat)!
            let ch = render.buffer.floatChannelData![0]
            return (0..<Int(render.buffer.frameLength)).map { ch[$0] }
        }
        XCTAssertEqual(renderOnce(), renderOnce())
    }
}

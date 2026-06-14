import AVFoundation
import Foundation

// MARK: - GrooveTiming

/// Groove-timing math shared by live scheduling and offline export, so the two
/// paths cannot drift apart.
enum GrooveTiming {

    /// Deterministic per-hit timing jitter for humanize. Same seed + track + step
    /// always yields the same offset, so playback and export agree and repeated
    /// exports of an unchanged mix are identical.
    static func deterministicJitter(trackId: String,
                                    step: Int,
                                    seed: UInt64,
                                    amount: Double,
                                    stepDuration: Double) -> Double {
        guard amount > 0 else { return 0 }
        var value = seed
        value ^= UInt64(step &* 0x9E37)
        for byte in trackId.utf8 {
            value ^= UInt64(byte)
            value &*= 0x100000001B3
        }
        value &+= 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31

        let unit = Double(value) / Double(UInt64.max)
        return ((unit * 2.0) - 1.0) * amount / 100.0 * stepDuration * 0.3
    }
}

// MARK: - ExportPlan

/// A single hit in an offline export, placed at an exact output frame.
struct ExportStepEvent: Equatable {
    let frame: AVAudioFramePosition
    let isAccented: Bool
    /// Per-step semitone offset; 0 = track's base pitch.
    var pitch: Int = 0
}

/// Frame-accurate timing plan for one offline export, derived from a
/// `Store.AudioSnapshot` — the same source of truth the live scheduler reads.
struct ExportPlan {
    let totalFrames: AVAudioFramePosition
    /// Per-track hit events, sorted by frame. Muted or empty tracks have no entry.
    let events: [String: [ExportStepEvent]]
    /// Bar-settings switch points, sorted by frame.
    let barBoundaries: [(frame: AVAudioFramePosition, bar: Int)]
}

enum ExportPlanBuilder {

    /// Mirrors the live scheduler: 16th-note grid from tempo, swing applied as
    /// (1±swing) on offbeat/downbeat transitions, humanize jitter seeded from the
    /// groove seed, accents flagged per hit, muted tracks skipped.
    static func build(snapshot: Store.AudioSnapshot,
                      reps: Int,
                      sampleRate: Double) -> ExportPlan {
        let stepDur  = 60.0 / snapshot.tempo / 4.0
        let seqStart = snapshot.sequenceStart
        let seqLen   = snapshot.sequenceLength
        let totalSteps = reps * seqLen

        var stepFrames = [AVAudioFramePosition](repeating: 0, count: totalSteps)
        var time = 0.0
        for i in 0..<totalSteps {
            stepFrames[i] = AVAudioFramePosition((time * sampleRate).rounded())
            let nextStep = seqStart + ((i + 1) % seqLen)
            let nextIsOffbeat = nextStep % 2 == 1
            time += stepDur * (nextIsOffbeat ? 1.0 + snapshot.swing : 1.0 - snapshot.swing)
        }
        let totalFrames = AVAudioFramePosition((time * sampleRate).rounded())

        var boundaries: [(frame: AVAudioFramePosition, bar: Int)] = []
        for i in 0..<totalSteps {
            let patStep = seqStart + (i % seqLen)
            if patStep % 16 == 0 {
                boundaries.append((stepFrames[i], patStep / 16))
            }
        }
        boundaries.sort { $0.frame < $1.frame }

        var events: [String: [ExportStepEvent]] = [:]
        for track in Tracks.all {
            guard snapshot.mutes[track.id] != true,
                  let row = snapshot.rows[track.id] else { continue }
            var trackEvents: [ExportStepEvent] = []
            for i in 0..<totalSteps {
                let patStep = seqStart + (i % seqLen)
                guard row.indices.contains(patStep), row[patStep] else { continue }
                let barIndex = patStep / 16
                let safeBar = min(max(barIndex, 0), snapshot.barEffects.count - 1)
                let humanize = Double(snapshot.barEffects[safeBar][track.id]?.humanize ?? 0)
                let jitter = GrooveTiming.deterministicJitter(trackId: track.id,
                                                              step: patStep,
                                                              seed: snapshot.grooveSeed,
                                                              amount: humanize,
                                                              stepDuration: stepDur)
                let jittered = stepFrames[i] + AVAudioFramePosition((jitter * sampleRate).rounded())
                let frame = min(max(jittered, 0), max(totalFrames - 1, 0))
                let isAccented = snapshot.accents[track.id]?.indices.contains(patStep) == true
                              && (snapshot.accents[track.id]?[patStep] ?? false)
                let pitchRow = snapshot.pitches[track.id]
                let pitch = pitchRow?.indices.contains(patStep) == true ? pitchRow![patStep] : 0
                trackEvents.append(ExportStepEvent(frame: frame, isAccented: isAccented, pitch: pitch))
            }
            guard !trackEvents.isEmpty else { continue }
            // High humanize can reorder neighboring hits; render in frame order so
            // truncation below is deterministic.
            trackEvents.sort { $0.frame < $1.frame }
            events[track.id] = trackEvents
        }

        return ExportPlan(totalFrames: totalFrames, events: events, barBoundaries: boundaries)
    }
}

// MARK: - OfflineTrackRenderer

/// Pre-mixes one track's hits into a single buffer, reproducing the live
/// scheduler's `.interrupts` semantics: a later hit on the same track cuts off
/// the previous hit's tail at the frame it starts. The result is scheduled once
/// per track, so export timing never depends on AVAudioPlayerNode queueing.
enum OfflineTrackRenderer {

    struct TrackRender {
        let buffer: AVAudioPCMBuffer
        /// Output frame at which the buffer should be scheduled. Buffers start at
        /// the track's first hit rather than frame 0 to keep memory proportional
        /// to actual content.
        let startFrame: AVAudioFramePosition
    }

    /// Buffer dictionaries are keyed by per-step semitone offset; key 0 is the
    /// track's base pitch and must be present. Unrendered offsets fall back to 0.
    static func render(events: [ExportStepEvent],
                       normalBuffers: [Int: AVAudioPCMBuffer],
                       accentBuffers: [Int: AVAudioPCMBuffer]?,
                       totalFrames: AVAudioFramePosition,
                       format: AVAudioFormat) -> TrackRender? {
        guard !events.isEmpty, totalFrames > 0,
              let baseBuffer = normalBuffers[0] else { return nil }

        func source(for event: ExportStepEvent) -> AVAudioPCMBuffer {
            let normal = normalBuffers[event.pitch] ?? baseBuffer
            guard event.isAccented else { return normal }
            return accentBuffers?[event.pitch] ?? accentBuffers?[0] ?? normal
        }
        /// End of the audible portion of event `i`: full source length, cut at the
        /// next hit on the track (interrupt semantics) and at the export end.
        func audibleEnd(_ i: Int) -> AVAudioFramePosition {
            let event = events[i]
            let srcLen = AVAudioFramePosition(source(for: event).frameLength)
            let cutoff = i + 1 < events.count ? events[i + 1].frame : .max
            return min(event.frame + srcLen, min(cutoff, totalFrames))
        }

        let startFrame = events[0].frame
        var endFrame = startFrame
        for i in events.indices { endFrame = max(endFrame, audibleEnd(i)) }

        let length = endFrame - startFrame
        guard length > 0,
              length <= AVAudioFramePosition(AVAudioFrameCount.max),
              let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(length)),
              let outChannels = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(length)
        for ch in 0..<Int(format.channelCount) {
            outChannels[ch].update(repeating: 0, count: Int(length))
        }

        for i in events.indices {
            let event = events[i]
            let src = source(for: event)
            guard let srcChannels = src.floatChannelData else { continue }
            let copyLen = Int(audibleEnd(i) - event.frame)
            guard copyLen > 0 else { continue }   // zero-length = replaced by a simultaneous hit
            let dstOffset = Int(event.frame - startFrame)
            let srcChannelCount = Int(src.format.channelCount)
            for ch in 0..<Int(format.channelCount) {
                let srcPtr = srcChannels[min(ch, srcChannelCount - 1)]
                outChannels[ch].advanced(by: dstOffset).update(from: srcPtr, count: copyLen)
            }
        }

        return TrackRender(buffer: out, startFrame: startFrame)
    }
}

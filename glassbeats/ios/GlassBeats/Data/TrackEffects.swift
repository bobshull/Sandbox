import AVFoundation

struct TrackEffects: Codable, Equatable {

    var pan: Float = 0                  // -1 (L) to 1 (R)
    var pitch: Float = 0                // -12 to +12 semitones
    var filterCutoff: Float = 100       // 0–100, 100 = wide open (~20kHz)
    var humanize: Float = 0             // 0–100; per-hit timing jitter

    var reverbWet: Float = 0            // 0–100, 0 = off

    var delayWet: Float = 0             // 0–100, 0 = off
    var delaySyncDivision: DelaySyncDivision = .eighth

    var distortionWet: Float = 0        // 0–100, 0 = off

    enum DelaySyncDivision: String, Codable, CaseIterable {
        case sixteenth, eighth, quarter

        var displayName: String {
            switch self {
            case .sixteenth: return "1/16"
            case .eighth:    return "1/8"
            case .quarter:   return "1/4"
            }
        }

        var quarterNoteMultiplier: Double {
            switch self {
            case .sixteenth: return 0.25
            case .eighth:    return 0.5
            case .quarter:   return 1.0
            }
        }
    }

    static let `default` = TrackEffects()

    var hasAnyActive: Bool {
        pan != 0 || pitch != 0 || filterCutoff < 100 || humanize > 0 ||
        reverbWet > 0 || delayWet > 0 || distortionWet > 0
    }

    /// Maps 0–100 fader value to a log-scale filter frequency (200Hz–20kHz).
    static func filterFrequency(from cutoff: Float) -> Float {
        Float(200.0 * pow(100.0, Double(cutoff) / 100.0))
    }
}

import AVFoundation

struct TrackEffects: Codable, Equatable {

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

    var hasAnyActive: Bool { reverbWet > 0 || delayWet > 0 || distortionWet > 0 }
}

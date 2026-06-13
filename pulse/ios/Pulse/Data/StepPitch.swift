import Foundation

/// Per-step pitch variation for melodic voices, stored as semitone offsets
/// relative to the track-level pitch. 0 is always the default (Root/Mid);
/// drum voices have no options and always read as 0.
enum StepPitch {

    struct Option: Equatable {
        let label: String
        let semitones: Int
    }

    /// Selectable options per voice, in display order. nil for drum voices.
    static func options(for voice: VoiceKind) -> [Option]? {
        switch voice {
        case .bass:
            return [Option(label: "Root", semitones: 0),
                    Option(label: "Fifth", semitones: 7),
                    Option(label: "Octave", semitones: 12)]
        case .pluck, .pad:
            return [Option(label: "Low", semitones: -7),
                    Option(label: "Mid", semitones: 0),
                    Option(label: "High", semitones: 7)]
        case .kick, .snare, .hat, .clap, .perc:
            return nil
        }
    }

    static func supportsPitch(_ voice: VoiceKind) -> Bool {
        options(for: voice) != nil
    }

    /// Semitone offsets that need a rendered voice buffer. Always includes 0.
    static func renderedOffsets(for voice: VoiceKind) -> [Int] {
        options(for: voice)?.map(\.semitones) ?? [0]
    }

    static func label(for voice: VoiceKind, semitones: Int) -> String? {
        options(for: voice)?.first { $0.semitones == semitones }?.label
    }
}

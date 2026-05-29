import Foundation

enum VoiceKind: String, Codable, CaseIterable {
    case kick, snare, hat, clap, bass, pluck, pad, perc
}

struct Track {
    let id: String
    let name: String
    let voice: VoiceKind
}

enum Tracks {
    static let stepCount = 16

    static let all: [Track] = [
        Track(id: "kick",  name: "Kick",  voice: .kick),
        Track(id: "snare", name: "Snare", voice: .snare),
        Track(id: "hat",   name: "Hat",   voice: .hat),
        Track(id: "clap",  name: "Clap",  voice: .clap),
        Track(id: "bass",  name: "Bass",  voice: .bass),
        Track(id: "pluck", name: "Pluck", voice: .pluck),
        Track(id: "pad",   name: "Pad",   voice: .pad),
        Track(id: "perc",  name: "Perc",  voice: .perc),
    ]

    static func find(_ id: String) -> Track? { all.first { $0.id == id } }
}

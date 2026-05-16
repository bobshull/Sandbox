import UIKit

enum VoiceKind: String, Codable, CaseIterable {
    case kick, snare, hat, clap, bass, pluck, pad, perc
}

struct Track {
    let id: String
    let name: String
    let voice: VoiceKind
    let color: UIColor
    let accent: UIColor
}

enum Tracks {
    static let stepCount = 16

    static let all: [Track] = [
        Track(id: "kick",  name: "Kick",  voice: .kick,  color: hex("#ff7a59"), accent: hex("#ff5a3a")),
        Track(id: "snare", name: "Snare", voice: .snare, color: hex("#ffd166"), accent: hex("#f6b73c")),
        Track(id: "hat",   name: "Hat",   voice: .hat,   color: hex("#9bf6ff"), accent: hex("#5fd5e0")),
        Track(id: "clap",  name: "Clap",  voice: .clap,  color: hex("#caffbf"), accent: hex("#86e07a")),
        Track(id: "bass",  name: "Bass",  voice: .bass,  color: hex("#bdb2ff"), accent: hex("#8e7dff")),
        Track(id: "pluck", name: "Pluck", voice: .pluck, color: hex("#ffc6ff"), accent: hex("#e98cff")),
        Track(id: "pad",   name: "Pad",   voice: .pad,   color: hex("#a0c4ff"), accent: hex("#6c98ec")),
        Track(id: "perc",  name: "Perc",  voice: .perc,  color: hex("#fdffb6"), accent: hex("#ddd86a")),
    ]

    static func find(_ id: String) -> Track? { all.first { $0.id == id } }
}

private func hex(_ value: String) -> UIColor {
    var s = value
    if s.hasPrefix("#") { s.removeFirst() }
    var rgb: UInt64 = 0
    Scanner(string: s).scanHexInt64(&rgb)
    let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
    let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
    let b = CGFloat(rgb & 0x0000FF) / 255
    return UIColor(red: r, green: g, blue: b, alpha: 1)
}

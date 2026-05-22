import UIKit

struct ColorTheme {
    let id: String
    let name: String
    private let colors: [String: (UIColor, UIColor)]

    func color(for trackId: String) -> UIColor  { colors[trackId]?.0 ?? Theme.accent }
    func accent(for trackId: String) -> UIColor { colors[trackId]?.1 ?? Theme.accent }

    static var current: ColorTheme {
        all.first { $0.id == AppSettings.colorThemeId } ?? neon
    }

    static let all: [ColorTheme] = [neon, pastel, dusk, aurora]

    // ── Neon (original) ────────────────────────────────────────────────────
    static let neon = ColorTheme(id: "neon", name: "Neon", colors: [
        "kick":  (hex("ff7a59"), hex("ff5a3a")),
        "snare": (hex("ffd166"), hex("f6b73c")),
        "hat":   (hex("9bf6ff"), hex("5fd5e0")),
        "clap":  (hex("caffbf"), hex("86e07a")),
        "bass":  (hex("bdb2ff"), hex("8e7dff")),
        "pluck": (hex("ffc6ff"), hex("e98cff")),
        "pad":   (hex("a0c4ff"), hex("6c98ec")),
        "perc":  (hex("fdffb6"), hex("ddd86a")),
    ])

    // ── Pastel ─────────────────────────────────────────────────────────────
    static let pastel = ColorTheme(id: "pastel", name: "Pastel", colors: [
        "kick":  (hex("ffb3a0"), hex("ff8f78")),
        "snare": (hex("ffe4a0"), hex("ffd166")),
        "hat":   (hex("b3f0ff"), hex("7ddff0")),
        "clap":  (hex("c8ffbe"), hex("96e88a")),
        "bass":  (hex("d9d4ff"), hex("b0a8ff")),
        "pluck": (hex("ffd6ff"), hex("f0aaff")),
        "pad":   (hex("c4dcff"), hex("93b8f5")),
        "perc":  (hex("feffd6"), hex("e8e97a")),
    ])

    // ── Dusk ───────────────────────────────────────────────────────────────
    static let dusk = ColorTheme(id: "dusk", name: "Dusk", colors: [
        "kick":  (hex("e05c78"), hex("c43a58")),
        "snare": (hex("d4aa6a"), hex("b88a3a")),
        "hat":   (hex("7ab8d8"), hex("4e92b8")),
        "clap":  (hex("8abca0"), hex("649e7e")),
        "bass":  (hex("9080c8"), hex("6a5ea8")),
        "pluck": (hex("c08898"), hex("a06878")),
        "pad":   (hex("7898c8"), hex("5070a8")),
        "perc":  (hex("b8a860"), hex("988040")),
    ])

    // ── Aurora ─────────────────────────────────────────────────────────────
    static let aurora = ColorTheme(id: "aurora", name: "Aurora", colors: [
        "kick":  (hex("4488ff"), hex("2266ee")),
        "snare": (hex("30d8c8"), hex("18b0a0")),
        "hat":   (hex("88ccff"), hex("60a8f0")),
        "clap":  (hex("40d080"), hex("28b060")),
        "bass":  (hex("a060f0"), hex("7840d8")),
        "pluck": (hex("d080ff"), hex("a858e8")),
        "pad":   (hex("60d8e8"), hex("40b8c8")),
        "perc":  (hex("b0a0ff"), hex("8878ee")),
    ])
}

private func hex(_ h: String) -> UIColor {
    var s = h.trimmingCharacters(in: .init(charactersIn: "#"))
    if s.count == 6 { s += "ff" }
    guard s.count == 8, let v = UInt64(s, radix: 16) else { return .white }
    return UIColor(
        red:   CGFloat((v >> 24) & 0xff) / 255,
        green: CGFloat((v >> 16) & 0xff) / 255,
        blue:  CGFloat((v >>  8) & 0xff) / 255,
        alpha: CGFloat( v        & 0xff) / 255
    )
}

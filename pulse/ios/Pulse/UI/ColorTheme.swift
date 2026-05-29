import UIKit

struct ColorTheme {
    let id: String
    let name: String
    private let colors: [String: (UIColor, UIColor)]

    func color(for trackId: String) -> UIColor  { colors[trackId]?.0 ?? Theme.accent }
    func accent(for trackId: String) -> UIColor { colors[trackId]?.1 ?? Theme.accent }

    /// Track ids that this theme defines a colour pair for. Exposed for tests.
    var definedTrackIds: Set<String> { Set(colors.keys) }

    /// The primary UI accent colour for this theme — used by transport, bar buttons, toast, etc.
    var primaryColor: UIColor { color(for: "kick") }

    static var current: ColorTheme {
        all.first { $0.id == AppSettings.colorThemeId } ?? mangoTango
    }

    /// Theme tiles ordered by primary tile color similarity.
    static let all: [ColorTheme] = sortByPrimaryColorSimilarity([
        candyNoir,
        cherryBomb,
        bubblegumHaze,
        mangoTango,
        lemonDrop,
        goldfinger,
        pickleJuice,
        electricLime,
        emeraldCity,
        mintCondition,
        poolParty,
        silverLining,
        aurora,
        blueLagoon,
        ultraviolet,
        plumCrazy,
    ])

    private static func sortByPrimaryColorSimilarity(_ themes: [ColorTheme]) -> [ColorTheme] {
        themes.sorted { lhs, rhs in
            let left = lhs.primaryColorSortKey
            let right = rhs.primaryColorSortKey

            if left.isNeutral != right.isNeutral { return !left.isNeutral }
            if left.hue != right.hue { return left.hue < right.hue }
            if left.saturation != right.saturation { return left.saturation > right.saturation }
            if left.brightness != right.brightness { return left.brightness > right.brightness }
            return lhs.id < rhs.id
        }
    }

    private var primaryColorSortKey: (isNeutral: Bool, hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        primaryColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let redStart: CGFloat = 0.94
        let shiftedHue = hue >= redStart ? hue - redStart : hue + (1 - redStart)
        return (saturation < 0.25, shiftedHue, saturation, brightness)
    }

    // MARK: - New replacement themes

    // ── Cherry Bomb ────────────────────────────────────────────────────────
    static let cherryBomb = ColorTheme(id: "cherryBomb", name: "Cherry Bomb", colors: [
        "kick":  (hex("e11d48"), hex("aa1435")),   // cherry red
        "snare": (hex("22c55e"), hex("16883f")),   // circuit green
        "hat":   (hex("38bdf8"), hex("2589b8")),   // bright cyan
        "clap":  (hex("facc15"), hex("b9970e")),   // signal yellow
        "bass":  (hex("7f1d1d"), hex("531212")),   // dark cherry
        "pluck": (hex("a855f7"), hex("7a35bd")),   // electric violet
        "pad":   (hex("2563eb"), hex("1b49ad")),   // saturated blue
        "perc":  (hex("f472b6"), hex("bd4d89")),   // hot pink
    ])

    // ── Electric Lime ──────────────────────────────────────────────────────
    static let electricLime = ColorTheme(id: "electricLime", name: "Electric Lime", colors: [
        "kick":  (hex("84cc16"), hex("5f9710")),   // electric lime
        "snare": (hex("9333ea"), hex("6923a9")),   // purple complement
        "hat":   (hex("bef264"), hex("8fbd47")),   // lime glow
        "clap":  (hex("ef4444"), hex("b52d2d")),   // red pop
        "bass":  (hex("365314"), hex("24370d")),   // deep green
        "pluck": (hex("06b6d4"), hex("07869c")),   // cyan bite
        "pad":   (hex("64748b"), hex("475569")),   // cool slate
        "perc":  (hex("f9a8d4"), hex("c878a4")),   // soft pink
    ])

    // ── Emerald City ───────────────────────────────────────────────────────
    static let emeraldCity = ColorTheme(id: "emeraldCity", name: "Emerald City", colors: [
        "kick":  (hex("16a34a"), hex("0f7333")),   // jade green
        "snare": (hex("dc2626"), hex("9f1b1b")),   // temple red
        "hat":   (hex("f5d76e"), hex("bea74f")),   // muted gold
        "clap":  (hex("0891b2"), hex("066b85")),   // blue teal
        "bass":  (hex("14532d"), hex("0c351c")),   // deep jade
        "pluck": (hex("c084fc"), hex("925ec6")),   // orchid contrast
        "pad":   (hex("22c55e"), hex("178d42")),   // bright leaf
        "perc":  (hex("fb7185"), hex("c95062")),   // rose accent
    ])

    // ── Pool Party ─────────────────────────────────────────────────────────
    static let poolParty = ColorTheme(id: "poolParty", name: "Pool Party", colors: [
        "kick":  (hex("0e7490"), hex("09576d")),   // ocean teal
        "snare": (hex("e879f9"), hex("b454c3")),   // anemone violet
        "hat":   (hex("67e8f9"), hex("43b8c7")),   // bright surf
        "clap":  (hex("fbbf24"), hex("c89117")),   // beacon gold
        "bass":  (hex("164e63"), hex("0d3442")),   // deep water
        "pluck": (hex("38bdf8"), hex("268dbb")),   // blue glint
        "pad":   (hex("2dd4bf"), hex("1fa094")),   // sea glass
        "perc":  (hex("a3e635"), hex("7bad24")),   // reef lime
    ])

    // ── Blue Lagoon ────────────────────────────────────────────────────────
    static let blueLagoon = ColorTheme(id: "blueLagoon", name: "Blue Lagoon", colors: [
        "kick":  (hex("2563eb"), hex("1d4fb8")),   // cobalt
        "snare": (hex("f59e0b"), hex("bd7608")),   // gold contrast
        "hat":   (hex("7dd3fc"), hex("55a4cb")),   // sky blue
        "clap":  (hex("fb7185"), hex("c94d60")),   // rose punch
        "bass":  (hex("1e3a8a"), hex("13265d")),   // deep cobalt
        "pluck": (hex("c084fc"), hex("925ec6")),   // violet shimmer
        "pad":   (hex("22d3ee"), hex("18a1b6")),   // cyan pulse
        "perc":  (hex("fde047"), hex("c2a92e")),   // bright yellow
    ])

    // ── Plum Crazy ─────────────────────────────────────────────────────────
    static let plumCrazy = ColorTheme(id: "plumCrazy", name: "Plum Crazy", colors: [
        "kick":  (hex("a21caf"), hex("78127f")),   // electric plum
        "snare": (hex("84cc16"), hex("60960f")),   // lime complement
        "hat":   (hex("f0abfc"), hex("bd7ac9")),   // lilac flash
        "clap":  (hex("14b8a6"), hex("0f887b")),   // teal voltage
        "bass":  (hex("581c87"), hex("3a105d")),   // deep plum
        "pluck": (hex("f43f5e"), hex("b92d45")),   // rose spark
        "pad":   (hex("c084fc"), hex("925ec6")),   // violet haze
        "perc":  (hex("facc15"), hex("bd970e")),   // electric gold
    ])

    // ── Lemon Drop ─────────────────────────────────────────────────────────
    static let lemonDrop = ColorTheme(id: "lemonDrop", name: "Lemon Drop", colors: [
        "kick":  (hex("facc15"), hex("bd970e")),   // signal yellow
        "snare": (hex("f97316"), hex("be530f")),   // hot orange
        "hat":   (hex("fde047"), hex("c2a92e")),   // bright sun
        "clap":  (hex("ec4899"), hex("b83475")),   // punch pink
        "bass":  (hex("b45309"), hex("813b06")),   // amber shadow
        "pluck": (hex("a3e635"), hex("79ad24")),   // acid lime
        "pad":   (hex("fb7185"), hex("c94d60")),   // neon rose
        "perc":  (hex("22d3ee"), hex("18a1b6")),   // cyan spark
    ])

    // ── Silver Lining ──────────────────────────────────────────────────────
    static let silverLining = ColorTheme(id: "silverLining", name: "Silver Lining", colors: [
        "kick":  (hex("6f7d86"), hex("4f5d65")),   // lighter gunmetal
        "snare": (hex("d6a15f"), hex("a77843")),   // brushed brass
        "hat":   (hex("9fc5d3"), hex("7497a4")),   // pale steel blue
        "clap":  (hex("b7cf7a"), hex("899f57")),   // muted lime
        "bass":  (hex("43515a"), hex("303c43")),   // lifted graphite
        "pluck": (hex("b08adf"), hex("8362ad")),   // muted violet
        "pad":   (hex("7fa6b8"), hex("5d7d8d")),   // blue gray
        "perc":  (hex("e4c56f"), hex("ad934d")),   // soft brass
    ])

    // MARK: - Kept themes from the original file. Do not alter these palettes.

    // ── Mango Tango ────────────────────────────────────────────────────────
    static let mangoTango = ColorTheme(id: "mangoTango", name: "Mango Tango", colors: [
        "kick":  (hex("ff6b4a"), hex("d94a2e")),   // coral flame
        "snare": (hex("ffd166"), hex("dca842")),   // warm yellow
        "hat":   (hex("4ddfff"), hex("22aeca")),   // electric cyan
        "clap":  (hex("91f27a"), hex("63c653")),   // neon leaf
        "bass":  (hex("9b7cff"), hex("7254d8")),   // violet
        "pluck": (hex("ff88d2"), hex("d95fae")),   // synth pink
        "pad":   (hex("5fa8ff"), hex("3d7dd4")),   // sky blue
        "perc":  (hex("f5f06a"), hex("c9c344")),   // acid yellow
    ])

    // ── Pickle Juice ───────────────────────────────────────────────────────
    static let pickleJuice = ColorTheme(id: "pickleJuice", name: "Pickle Juice", colors: [
        "kick":  (hex("6f7f32"), hex("4f5f20")),   // olive
        "snare": (hex("b05a38"), hex("854029")),   // rust complement
        "hat":   (hex("c7b84f"), hex("9b8e36")),   // brass khaki
        "clap":  (hex("7e4b7a"), hex("5d355a")),   // muted purple
        "bass":  (hex("34451f"), hex("202d12")),   // deep olive
        "pluck": (hex("2d9a8c"), hex("1f756b")),   // blue teal contrast
        "pad":   (hex("93a86b"), hex("6f824d")),   // sage
        "perc":  (hex("c08345"), hex("93602f")),   // leather brown
    ])

    // ── Bubblegum Haze ─────────────────────────────────────────────────────
    static let bubblegumHaze = ColorTheme(id: "bubblegumHaze", name: "Bubblegum Haze", colors: [
        "kick":  (hex("d86f83"), hex("ad4e61")),   // dusty rose
        "snare": (hex("d6a45f"), hex("a97a3f")),   // antique gold
        "hat":   (hex("72add0"), hex("4f84a4")),   // dusk blue
        "clap":  (hex("81bd9a"), hex("5f9274")),   // sage green
        "bass":  (hex("6858a6"), hex("463b7f")),   // muted violet
        "pluck": (hex("c58aa2"), hex("99657a")),   // mauve
        "pad":   (hex("7894c9"), hex("566fa2")),   // blue lavender
        "perc":  (hex("c7bb68"), hex("9a8e48")),   // khaki gold
    ])

    // ── Aurora ─────────────────────────────────────────────────────────────
    static let aurora = ColorTheme(id: "aurora", name: "Aurora", colors: [
        "kick":  (hex("3aa8ff"), hex("1d78d0")),   // aurora blue
        "snare": (hex("39d6b3"), hex("20a88a")),   // mint teal
        "hat":   (hex("9fdcff"), hex("70b5df")),   // ice blue
        "clap":  (hex("8be56d"), hex("61bb4a")),   // polar green
        "bass":  (hex("4e5bd5"), hex("333ca8")),   // northern indigo
        "pluck": (hex("b985ff"), hex("8d5fd8")),   // violet glow
        "pad":   (hex("5de0d0"), hex("38afa2")),   // luminous aqua
        "perc":  (hex("c8f27a"), hex("9fc551")),   // soft lime
    ])

    // ── Ultraviolet ────────────────────────────────────────────────────────
    static let ultraviolet = ColorTheme(id: "ultraviolet", name: "Ultraviolet", colors: [
        "kick":  (hex("7b3ff2"), hex("5828bd")),   // ultraviolet
        "snare": (hex("f0c84b"), hex("bc9a32")),   // gold complement
        "hat":   (hex("b58cff"), hex("8d63d4")),   // lavender
        "clap":  (hex("37c6b0"), hex("269888")),   // teal
        "bass":  (hex("3a1f75"), hex("24124f")),   // deep purple
        "pluck": (hex("d96fd3"), hex("aa4aa5")),   // orchid
        "pad":   (hex("5d6fe8"), hex("3f4eb8")),   // blue violet
        "perc":  (hex("e59f45"), hex("b6762d")),   // amber
    ])

    // ── Candy Noir ─────────────────────────────────────────────────────────
    static let candyNoir = ColorTheme(id: "candyNoir", name: "Candy Noir", colors: [
        "kick":  (hex("d93f8c"), hex("aa2d6c")),   // magenta
        "snare": (hex("37c987"), hex("279965")),   // mint green complement
        "hat":   (hex("f0b95a"), hex("c7903f")),   // warm gold
        "clap":  (hex("48b8d0"), hex("328ca0")),   // cyan blue
        "bass":  (hex("6d214f"), hex("451332")),   // deep plum
        "pluck": (hex("ef7ab8"), hex("bd5690")),   // pink pop
        "pad":   (hex("7b6ee6"), hex("584cc0")),   // blue violet
        "perc":  (hex("d9824f"), hex("a96037")),   // copper orange
    ])

    // ── Goldfinger ─────────────────────────────────────────────────────────
    static let goldfinger = ColorTheme(id: "goldfinger", name: "Goldfinger", colors: [
        "kick":  (hex("c89010"), hex("9e6e0c")),   // ochre mustard
        "snare": (hex("904028"), hex("6e2e1c")),   // brick
        "hat":   (hex("c87870"), hex("9e5c56")),   // dusty rose
        "clap":  (hex("208878"), hex("16685c")),   // teal
        "bass":  (hex("605040"), hex("483c30")),   // warm taupe
        "pluck": (hex("9858b8"), hex("74408e")),   // violet
        "pad":   (hex("489870"), hex("347858")),   // sage
        "perc":  (hex("e8d0b8"), hex("c0a890")),   // warm ivory
    ])

    // ── Mint Condition ─────────────────────────────────────────────────────
    static let mintCondition = ColorTheme(id: "mintCondition", name: "Mint Condition", colors: [
        "kick":  (hex("56d6a9"), hex("37a982")),   // mint
        "snare": (hex("f08a72"), hex("bf6655")),   // peach coral complement
        "hat":   (hex("c9e89c"), hex("9abb70")),   // pale green
        "clap":  (hex("a98be8"), hex("8065bf")),   // lavender
        "bass":  (hex("1f6658"), hex("124238")),   // deep mint teal
        "pluck": (hex("55a9e8"), hex("377fb4")),   // circuit blue
        "pad":   (hex("8fbf9f"), hex("6a9478")),   // sage mint
        "perc":  (hex("e6c76f"), hex("b99c4d")),   // soft gold
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

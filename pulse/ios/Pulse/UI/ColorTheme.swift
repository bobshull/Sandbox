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
        all.first { $0.id == AppSettings.colorThemeId } ?? neon
    }

    static let all: [ColorTheme] = [
        neon, olive, dusk, aurora, crimson, lemon, acid, teal,
        violet, magenta, midnight, forest, tangerine, mint, steel, lavender,
    ]

    // ── Neon Night ─────────────────────────────────────────────────────────
    static let neon = ColorTheme(id: "neon", name: "Neon Night", colors: [
        "kick":  (hex("ff6b4a"), hex("d94a2e")),   // coral flame
        "snare": (hex("ffd166"), hex("dca842")),   // warm yellow
        "hat":   (hex("4ddfff"), hex("22aeca")),   // electric cyan
        "clap":  (hex("91f27a"), hex("63c653")),   // neon leaf
        "bass":  (hex("9b7cff"), hex("7254d8")),   // violet
        "pluck": (hex("ff88d2"), hex("d95fae")),   // synth pink
        "pad":   (hex("5fa8ff"), hex("3d7dd4")),   // sky blue
        "perc":  (hex("f5f06a"), hex("c9c344")),   // acid yellow
    ])

    // ── Olive Grove ────────────────────────────────────────────────────────
    static let olive = ColorTheme(id: "olive", name: "Olive Grove", colors: [
        "kick":  (hex("6f7f32"), hex("4f5f20")),   // olive
        "snare": (hex("b05a38"), hex("854029")),   // rust complement
        "hat":   (hex("c7b84f"), hex("9b8e36")),   // brass khaki
        "clap":  (hex("7e4b7a"), hex("5d355a")),   // muted purple
        "bass":  (hex("34451f"), hex("202d12")),   // deep olive
        "pluck": (hex("2d9a8c"), hex("1f756b")),   // blue teal contrast
        "pad":   (hex("93a86b"), hex("6f824d")),   // sage
        "perc":  (hex("c08345"), hex("93602f")),   // leather brown
    ])

    // ── Pastel Dusk ────────────────────────────────────────────────────────
    static let dusk = ColorTheme(id: "dusk", name: "Pastel Dusk", colors: [
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

    // ── Blood Orange ───────────────────────────────────────────────────────
    static let crimson = ColorTheme(id: "crimson", name: "Blood Orange", colors: [
        "kick":  (hex("c21f32"), hex("921524")),   // blood red
        "snare": (hex("30a66f"), hex("227d52")),   // emerald complement
        "hat":   (hex("ff8a5b"), hex("cf653e")),   // blood orange
        "clap":  (hex("26b3a3"), hex("1a867a")),   // teal contrast
        "bass":  (hex("5c111c"), hex("390911")),   // dark wine
        "pluck": (hex("e05261"), hex("ad3845")),   // cherry red
        "pad":   (hex("8f3545"), hex("682531")),   // raspberry shadow
        "perc":  (hex("e0a048"), hex("ad7830")),   // copper gold
    ])

    // ── Citrus Pop ─────────────────────────────────────────────────────────
    static let lemon = ColorTheme(id: "lemon", name: "Citrus Pop", colors: [
        "kick":  (hex("f7d447"), hex("c9a82f")),   // lemon
        "snare": (hex("267fc7"), hex("1b5f96")),   // blue complement
        "hat":   (hex("b9e34f"), hex("8eb53a")),   // lime
        "clap":  (hex("ff6f61"), hex("cc4f45")),   // grapefruit
        "bass":  (hex("66761f"), hex("465315")),   // bitter rind
        "pluck": (hex("f47b2f"), hex("c45620")),   // orange
        "pad":   (hex("55c6c8"), hex("36999b")),   // aqua soda
        "perc":  (hex("d96bb0"), hex("aa4c88")),   // berry candy
    ])

    // ── Acid Bloom ─────────────────────────────────────────────────────────
    static let acid = ColorTheme(id: "acid", name: "Acid Bloom", colors: [
        "kick":  (hex("c6f432"), hex("9dc724")),   // acid chartreuse
        "snare": (hex("8b45d9"), hex("6531a8")),   // purple complement
        "hat":   (hex("f2e94e"), hex("c4ba34")),   // electric yellow
        "clap":  (hex("ff4f7d"), hex("cc365b")),   // hot coral
        "bass":  (hex("43520f"), hex("2b3608")),   // dark acid green
        "pluck": (hex("23d9c0"), hex("17a894")),   // toxic mint
        "pad":   (hex("4fdb55"), hex("36ad3b")),   // laser green
        "perc":  (hex("ff9f35"), hex("cf7523")),   // orange pop
    ])

    // ── Ocean Glass ────────────────────────────────────────────────────────
    static let teal = ColorTheme(id: "teal", name: "Ocean Glass", colors: [
        "kick":  (hex("16a6a6"), hex("0d7d80")),   // teal
        "snare": (hex("f26f5e"), hex("c84f43")),   // coral complement
        "hat":   (hex("8fd6e8"), hex("62abc0")),   // pale aqua
        "clap":  (hex("f2c36b"), hex("c99843")),   // beach gold
        "bass":  (hex("164f63"), hex("0b3442")),   // deep sea
        "pluck": (hex("5d8fc9"), hex("3d69a0")),   // ocean blue
        "pad":   (hex("46c2b8"), hex("2a958f")),   // seafoam
        "perc":  (hex("d99a72"), hex("ae7150")),   // shell clay
    ])

    // ── Ultraviolet ────────────────────────────────────────────────────────
    static let violet = ColorTheme(id: "violet", name: "Ultraviolet", colors: [
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
    static let magenta = ColorTheme(id: "magenta", name: "Candy Noir", colors: [
        "kick":  (hex("d93f8c"), hex("aa2d6c")),   // magenta
        "snare": (hex("37c987"), hex("279965")),   // mint green complement
        "hat":   (hex("f0b95a"), hex("c7903f")),   // warm gold
        "clap":  (hex("48b8d0"), hex("328ca0")),   // cyan blue
        "bass":  (hex("6d214f"), hex("451332")),   // deep plum
        "pluck": (hex("ef7ab8"), hex("bd5690")),   // pink pop
        "pad":   (hex("7b6ee6"), hex("584cc0")),   // blue violet
        "perc":  (hex("d9824f"), hex("a96037")),   // copper orange
    ])

    // ── Midnight City ──────────────────────────────────────────────────────
    static let midnight = ColorTheme(id: "midnight", name: "Midnight City", colors: [
        "kick":  (hex("25318f"), hex("161f68")),   // royal midnight
        "snare": (hex("f2a23a"), hex("bd7926")),   // streetlight amber
        "hat":   (hex("7aa7ff"), hex("527bd4")),   // moon blue
        "clap":  (hex("d86f76"), hex("ad4f57")),   // muted neon red
        "bass":  (hex("10183a"), hex("080e24")),   // deep navy
        "pluck": (hex("c79bff"), hex("956cd7")),   // city violet
        "pad":   (hex("4d6fb8"), hex("334d90")),   // dusk blue
        "perc":  (hex("f0c66b"), hex("bd9846")),   // warm gold
    ])

    // ── Forest Floor ───────────────────────────────────────────────────────
    static let forest = ColorTheme(id: "forest", name: "Forest Floor", colors: [
        "kick":  (hex("3f8f4e"), hex("2d6b3a")),   // moss green
        "snare": (hex("9b6a45"), hex("70472e")),   // bark brown
        "hat":   (hex("b9c46a"), hex("8f9a47")),   // lichen yellow
        "clap":  (hex("8a4f63"), hex("663747")),   // wild berry
        "bass":  (hex("1f4a2c"), hex("122f1b")),   // deep pine
        "pluck": (hex("48a7a0"), hex("357d78")),   // creek teal
        "pad":   (hex("6d8a58"), hex("4d683d")),   // moss gray-green
        "perc":  (hex("c48f57"), hex("94683d")),   // mushroom tan
    ])

    // ── Golden Hour ────────────────────────────────────────────────────────
    static let tangerine = ColorTheme(id: "golden", name: "Golden Hour", colors: [
        "kick":  (hex("c4556a"), hex("963f52")),   // deep rose
        "snare": (hex("d4a843"), hex("a47e30")),   // warm gold
        "hat":   (hex("e8a0b0"), hex("bb778a")),   // blush
        "clap":  (hex("d96a3a"), hex("a84e28")),   // ember orange
        "bass":  (hex("4a1a2c"), hex("2e0f1b")),   // deep wine
        "pluck": (hex("c97840"), hex("9a582e")),   // amber
        "pad":   (hex("a03a50"), hex("782a3c")),   // burgundy rose
        "perc":  (hex("d4a882"), hex("a4785a")),   // champagne tan
    ])

    // ── Mint Circuit ───────────────────────────────────────────────────────
    static let mint = ColorTheme(id: "mint", name: "Mint Circuit", colors: [
        "kick":  (hex("56d6a9"), hex("37a982")),   // mint
        "snare": (hex("f08a72"), hex("bf6655")),   // peach coral complement
        "hat":   (hex("c9e89c"), hex("9abb70")),   // pale green
        "clap":  (hex("a98be8"), hex("8065bf")),   // lavender
        "bass":  (hex("1f6658"), hex("124238")),   // deep mint teal
        "pluck": (hex("55a9e8"), hex("377fb4")),   // circuit blue
        "pad":   (hex("8fbf9f"), hex("6a9478")),   // sage mint
        "perc":  (hex("e6c76f"), hex("b99c4d")),   // soft gold
    ])

    // ── Slate & Copper ─────────────────────────────────────────────────────
    static let steel = ColorTheme(id: "steel", name: "Slate & Copper", colors: [
        "kick":  (hex("52656f"), hex("35464f")),   // slate
        "snare": (hex("c98243"), hex("99602f")),   // copper
        "hat":   (hex("91a2aa"), hex("6b7b83")),   // light steel
        "clap":  (hex("d9a066"), hex("a9784a")),   // brushed brass
        "bass":  (hex("26343a"), hex("141f23")),   // dark graphite
        "pluck": (hex("5f9fb0"), hex("437886")),   // oxidized blue
        "pad":   (hex("6f8790"), hex("506871")),   // blue steel
        "perc":  (hex("e0b36f"), hex("ad874f")),   // warm metal
    ])

    // ── Lavender Cream ─────────────────────────────────────────────────────
    static let lavender = ColorTheme(id: "lavender", name: "Lavender Cream", colors: [
        "kick":  (hex("a98be8"), hex("8065bf")),   // lavender
        "snare": (hex("e6c76f"), hex("b99c4d")),   // cream gold complement
        "hat":   (hex("c9b5f2"), hex("9d82d4")),   // lilac
        "clap":  (hex("8fbf9f"), hex("6a9478")),   // sage
        "bass":  (hex("5a3f88"), hex("3b2860")),   // deep lavender
        "pluck": (hex("d99ec6"), hex("aa75a0")),   // mauve pink
        "pad":   (hex("8b9ed8"), hex("6679b0")),   // soft periwinkle
        "perc":  (hex("f0d79a"), hex("bea76f")),   // vanilla
    ])

    // Compatibility aliases for older references that existed in the original file
    // but were not included in ColorTheme.all.
    static let synthwave = forest
    static let lava = crimson
    static let sand = ColorTheme(id: "sand", name: "Desert Bloom", colors: [
        "kick":  (hex("d0a15f"), hex("a1763f")),   // sand
        "snare": (hex("bd6a4a"), hex("8f4b34")),   // terracotta
        "hat":   (hex("e8c66f"), hex("b99a4c")),   // desert sun
        "clap":  (hex("a35f7a"), hex("794558")),   // desert flower
        "bass":  (hex("5b4331"), hex("38291e")),   // dry earth
        "pluck": (hex("6f9a72"), hex("527653")),   // cactus green
        "pad":   (hex("c5885b"), hex("976340")),   // clay
        "perc":  (hex("3f9fa8"), hex("2b777d")),   // turquoise
    ])
    static let cherry = magenta
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

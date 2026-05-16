import Foundation

struct Pattern: Codable {
    var id: String
    var name: String
    var tempo: Double
    var swing: Double
    var rows: [String: [Bool]]   // trackId -> 16 booleans
}

enum Presets {
    private static func row(_ positions: Int...) -> [Bool] {
        var r = Array(repeating: false, count: Tracks.stepCount)
        for p in positions where (0..<Tracks.stepCount).contains(p) { r[p] = true }
        return r
    }

    static let all: [Pattern] = [

        // ── Chill / Lo-Fi ─────────────────────────────────────────────────
        Pattern(id: "lofi-shuffle", name: "Lo-Fi Shuffle", tempo: 76, swing: 0.32, rows: [
            "kick":  row(0, 8),
            "snare": row(4, 12),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(12),
            "pluck": row(0, 6, 10),
            "pad":   row(0),
        ]),
        Pattern(id: "dusty-lofi", name: "Dusty Lo-Fi", tempo: 82, swing: 0.36, rows: [
            "kick":  row(0, 7, 11),
            "snare": row(4, 12),
            "hat":   row(0, 3, 6, 10, 14),
            "pad":   row(0, 8),
            "pluck": row(3, 9, 13),
        ]),
        Pattern(id: "rainy-window", name: "Rainy Window", tempo: 68, swing: 0.40, rows: [
            "kick":  row(0, 6),
            "snare": row(4, 13),
            "hat":   row(2, 8, 14),
            "pad":   row(0),
            "pluck": row(5, 11),
        ]),
        Pattern(id: "chillhop", name: "Chillhop", tempo: 92, swing: 0.18, rows: [
            "kick":  row(0, 8),
            "snare": row(4, 12),
            "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
            "clap":  row(6, 14),
            "pluck": row(0, 3, 8, 11),
            "pad":   row(0, 8),
        ]),
        Pattern(id: "tape-deck", name: "Tape Deck", tempo: 86, swing: 0.26, rows: [
            "kick":  row(0, 5, 10),
            "snare": row(4, 12),
            "hat":   row(1, 3, 5, 7, 9, 11, 13, 15),
            "bass":  row(0, 8),
            "perc":  row(6, 14),
        ]),

        // ── Hip-Hop ───────────────────────────────────────────────────────
        Pattern(id: "boom-bap", name: "Boom Bap", tempo: 88, swing: 0.22, rows: [
            "kick":  row(0, 6, 10),
            "snare": row(4, 12),
            "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
            "bass":  row(0, 10),
            "perc":  row(7, 15),
        ]),
        Pattern(id: "late-night", name: "Late Night", tempo: 74, swing: 0.20, rows: [
            "kick":  row(0, 9),
            "snare": row(8),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(8),
            "bass":  row(0, 6),
            "pad":   row(0),
        ]),
        Pattern(id: "half-time", name: "Half Time", tempo: 70, swing: 0.15, rows: [
            "kick":  row(0, 7),
            "snare": row(8),
            "hat":   row(0, 4, 8, 12),
            "clap":  row(8),
            "pad":   row(0),
            "pluck": row(2, 9, 13),
        ]),

        // ── Electronic ────────────────────────────────────────────────────
        Pattern(id: "house-pulse", name: "House Pulse", tempo: 122, swing: 0.05, rows: [
            "kick":  row(0, 4, 8, 12),
            "clap":  row(4, 12),
            "hat":   row(2, 6, 10, 14),
            "bass":  row(0, 3, 8, 11),
            "perc":  row(7, 15),
        ]),
        Pattern(id: "spacey", name: "Spacey", tempo: 112, swing: 0.08, rows: [
            "kick":  row(0, 12),
            "clap":  row(8),
            "hat":   row(4, 12),
            "pad":   row(0, 8),
            "pluck": row(3, 7, 11, 15),
            "perc":  row(6),
        ]),
        Pattern(id: "breakbeat", name: "Breakbeat", tempo: 138, swing: 0.10, rows: [
            "kick":  row(0, 6, 10),
            "snare": row(4, 12, 14),
            "hat":   row(0, 2, 3, 5, 7, 8, 10, 11, 13, 15),
            "bass":  row(0, 8),
        ]),

        // ── Minimal ───────────────────────────────────────────────────────
        Pattern(id: "minimal", name: "Minimal", tempo: 98, swing: 0.05, rows: [
            "kick":  row(0, 8),
            "hat":   row(4, 12),
            "snare": row(12),
            "bass":  row(0),
        ]),
        Pattern(id: "empty", name: "Empty", tempo: 96, swing: 0.0, rows: [:]),
    ]

    static func emptyRows() -> [String: [Bool]] {
        var dict: [String: [Bool]] = [:]
        for t in Tracks.all {
            dict[t.id] = Array(repeating: false, count: Tracks.stepCount)
        }
        return dict
    }

    static func filledRows(from rows: [String: [Bool]]) -> [String: [Bool]] {
        var out = emptyRows()
        for (k, v) in rows where out[k] != nil && v.count == Tracks.stepCount {
            out[k] = v
        }
        return out
    }
}

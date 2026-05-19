import Foundation

struct Pattern: Codable {
    var id: String
    var name: String
    var tempo: Double
    var swing: Double
    var rows: [String: [Bool]]   // trackId -> 16 or 32 booleans
    var volumes: [String: Float]?        // bar 0
    var mutes: [String: Bool]?
    var effects: [String: TrackEffects]? // bar 0
    var kitId: String?
    var patternLength: Int?              // nil decodes as 16 (backward compat)
    var bar2Volumes: [String: Float]?    // nil → copy bar 0 on load
    var bar2Effects: [String: TrackEffects]? // nil → copy bar 0 on load
}

enum Presets {
    private static func row(_ positions: Int...) -> [Bool] {
        var r = Array(repeating: false, count: Tracks.stepCount)
        for p in positions where (0..<Tracks.stepCount).contains(p) { r[p] = true }
        return r
    }

    private static func row2(_ positions: Int...) -> [Bool] {
        var r = Array(repeating: false, count: 32)
        for p in positions where (0..<32).contains(p) { r[p] = true }
        return r
    }

    static let all: [Pattern] = [

        // ── Electronic ────────────────────────────────────────────────────

        // User mix. Dense perc run + pluck build into beat 3.
        Pattern(id: "floor-filler", name: "Floor Filler", tempo: 122, swing: 0.05, rows: [
            "kick":  row(0, 4, 8, 12),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(4, 12),
            "bass":  row(0, 3, 8, 11),
            "pluck": row(4, 5, 6, 7, 8),
            "perc":  row(2, 3, 4, 5, 6, 7, 8, 9, 15),
        ]),

        // Half-time snare on beat 3 (step 8) is the genre's defining hit.
        // Kick doubles on 0+3 ("DUN-dun" attack) then hits and-of-3 and and-of-4.
        // Bass overlaps at 140 BPM (0.35s decay > one 16th = 0.107s) — the
        // consecutive hits on 0+1 and 8+9 create the wub texture naturally.
        Pattern(id: "dubstep", name: "Dubstep", tempo: 140, swing: 0.0, rows: [
            "kick":  row(0, 3, 10, 14),
            "snare": row(8),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(8),
            "bass":  row(0, 1, 6, 8, 9, 12, 14),
            "perc":  row(4, 12),
        ]),

        // Textbook Chicago house. Bass uses standard syncopated house rhythm
        // (root + "and" anticipation pairs: 0, 3, 8, 11).
        Pattern(id: "house-pulse", name: "House Pulse", tempo: 122, swing: 0.05, rows: [
            "kick":  row(0, 4, 8, 12),
            "clap":  row(4, 12),
            "hat":   row(2, 6, 10, 14),
            "bass":  row(0, 3, 8, 11),
            "perc":  row(7, 15),
        ]),

        // Amen break energy. Snare stutters on 4, a-of-3 (11), 4, and-of-4 (14).
        Pattern(id: "breakbeat", name: "Breakbeat", tempo: 138, swing: 0.10, rows: [
            "kick":  row(0, 6, 10),
            "snare": row(4, 11, 12, 14),
            "hat":   row(0, 2, 3, 5, 7, 8, 10, 11, 13, 15),
            "bass":  row(0, 8),
        ]),

        // ── Hip-Hop ───────────────────────────────────────────────────────

        // SP-1200 style. Kick on and-of-2 (6) and and-of-3 (10) is the knock.
        // Single clap on beat 2 for the NY accent.
        Pattern(id: "boom-bap", name: "Boom Bap", tempo: 88, swing: 0.22, rows: [
            "kick":  row(0, 6, 10),
            "snare": row(4, 12),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(4),
            "bass":  row(0, 10),
            "perc":  row(7, 15),
        ]),

        // Snare ONLY on beat 3 — active kick compensates for the missing backbeat.
        Pattern(id: "half-time", name: "Half Time", tempo: 70, swing: 0.15, rows: [
            "kick":  row(0, 4, 6, 12),
            "snare": row(8),
            "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
            "clap":  row(8),
            "bass":  row(0, 8),
            "pluck": row(3, 11),
        ]),

        // ── Chill / Lo-Fi ─────────────────────────────────────────────────

        // Pluck on e-of-1 and e-of-3 (steps 1, 9) — with 0.32 swing those
        // float back as lazy triplet afterbeats. That IS the lo-fi feel.
        Pattern(id: "lofi-shuffle", name: "Lo-Fi Shuffle", tempo: 76, swing: 0.32, rows: [
            "kick":  row(0, 8),
            "snare": row(4, 12),
            "hat":   row(2, 6, 10, 14),
            "clap":  row(4),
            "pluck": row(1, 9),
            "bass":  row(0, 8),
        ]),

        // Upbeat study-beats. Bass uses tresillo-influenced anticipation pairs.
        Pattern(id: "chillhop", name: "Chillhop", tempo: 92, swing: 0.18, rows: [
            "kick":  row(0, 8),
            "snare": row(4, 12),
            "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
            "clap":  row(4, 12),
            "bass":  row(0, 3, 8, 11),
            "pluck": row(2, 10),
        ]),

        // All odd-step hats pushed back by 0.26 swing = vintage tape shuffle.
        Pattern(id: "tape-deck", name: "Tape Deck", tempo: 86, swing: 0.26, rows: [
            "kick":  row(0, 8, 11),
            "snare": row(4, 12),
            "hat":   row(1, 3, 5, 7, 9, 11, 13, 15),
            "bass":  row(0, 6, 9),
            "perc":  row(2, 10),
        ]),

        // ── Minimal ───────────────────────────────────────────────────────

        // Two hats, four kicks. The space between them is the point.
        Pattern(id: "minimal", name: "Minimal", tempo: 98, swing: 0.05, rows: [
            "kick":  row(0, 4, 8, 12),
            "clap":  row(4, 12),
            "hat":   row(6, 14),
            "bass":  row(0, 8),
        ]),

        Pattern(id: "empty", name: "Empty", tempo: 96, swing: 0.0, rows: [:]),
    ]

    static func emptyRows(length: Int = Tracks.stepCount) -> [String: [Bool]] {
        var dict: [String: [Bool]] = [:]
        for t in Tracks.all {
            dict[t.id] = Array(repeating: false, count: length)
        }
        return dict
    }

    static func filledRows(from rows: [String: [Bool]], length: Int = Tracks.stepCount) -> [String: [Bool]] {
        var out = emptyRows(length: length)
        for (k, v) in rows where out[k] != nil && v.count == length {
            out[k] = v
        }
        return out
    }
}

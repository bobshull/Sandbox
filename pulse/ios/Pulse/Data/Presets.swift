import Foundation

struct Pattern: Codable {
    var id: String
    var name: String
    var tempo: Double
    var swing: Double
    var rows: [String: [Bool]]
    var volumes: [String: Float]?
    var mutes: [String: Bool]?
    var effects: [String: TrackEffects]?
    var kitId: String?
    var patternLength: Int?
    var bar2Volumes: [String: Float]?
    var bar2Effects: [String: TrackEffects]?
    var basePresetId: String?
    var barLength: Int?
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

    private static func fx(rvb: Float = 0, dly: Float = 0,
                            div: TrackEffects.DelaySyncDivision = .eighth,
                            dst: Float = 0) -> TrackEffects {
        TrackEffects(reverbWet: rvb, delayWet: dly, delaySyncDivision: div, distortionWet: dst)
    }

    static let all: [Pattern] = [

        // ── Jungle Chop — user's hand-crafted beat, exact replica ────────────
        Pattern(
            id: "jungle-chop", name: "Jungle Chop", tempo: 92, swing: 0.18,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "clap":  row(4, 12),
                "bass":  row(0, 3, 8, 11),
                "pluck": row(2, 10),
                "perc":  row(0, 8, 12),
            ],
            volumes: ["pluck": 0.55],
            effects: [
                "hat":   fx(rvb: 66, dly: 32, div: .quarter,   dst: 92),
                "bass":  fx(rvb: 43, dly: 12, div: .sixteenth, dst: 60),
                "pluck": fx(rvb: 31, dly: 70, div: .sixteenth, dst: 69),
                "perc":  fx(rvb: 75, dly: 57, div: .sixteenth, dst: 83),
            ],
            kitId: "jungle"
        ),

        // ── 808 Groove — slow soul, sub bass room to breathe ────────────────
        Pattern(
            id: "808-memphis", name: "808 Groove", tempo: 85, swing: 0.22,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "clap":  row(4),
                "bass":  row(0, 6, 10),
                "pluck": row(3, 11),
            ],
            volumes: ["kick": 0.92, "snare": 0.80, "bass": 0.88, "hat": 0.58, "clap": 0.70, "pluck": 0.68],
            effects: [
                "kick":  fx(rvb: 28, dst: 15),
                "snare": fx(rvb: 42),
                "hat":   fx(rvb: 20),
                "clap":  fx(rvb: 38),
                "bass":  fx(rvb: 32, dst: 30),
                "pluck": fx(rvb: 48, dly: 20, div: .eighth),
            ],
            kitId: "808"
        ),

        // ── Rainy Lo-Fi — head-nod groove, late-night lazy ──────────────────
        Pattern(
            id: "rainy-lofi", name: "Rainy Lo-Fi", tempo: 75, swing: 0.32,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4, 13),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "bass":  row(0, 6, 10),
                "pluck": row(3, 9, 14),
                "perc":  row(5, 11),
            ],
            volumes: ["kick": 0.78, "snare": 0.68, "hat": 0.55, "bass": 0.82, "pluck": 0.72],
            effects: [
                "kick":  fx(rvb: 52),
                "snare": fx(rvb: 58),
                "hat":   fx(rvb: 62),
                "bass":  fx(rvb: 45, dly: 18, div: .eighth),
                "pluck": fx(rvb: 70, dly: 28, div: .eighth),
                "perc":  fx(rvb: 55),
            ],
            kitId: "rainy-night"
        ),

        // ── Music Box Fantasy — melody-first, not a drum pattern ────────────
        Pattern(
            id: "music-box-fantasy", name: "Music Box Fantasy", tempo: 82, swing: 0.10,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(2, 10),
                "hat":   row(0, 8),
                "bass":  row(0, 3, 6, 9, 12),
                "pluck": row(1, 5, 8, 11, 14),
                "perc":  row(4, 12),
            ],
            volumes: ["hat": 0.50, "kick": 0.62],
            effects: [
                "kick":  fx(rvb: 62),
                "snare": fx(rvb: 78, dly: 28, div: .eighth),
                "hat":   fx(rvb: 45),
                "bass":  fx(rvb: 68, dly: 35, div: .eighth),
                "pluck": fx(rvb: 82, dly: 50, div: .eighth),
                "perc":  fx(rvb: 72),
            ],
            kitId: "music-box"
        ),

        // ── Space Drift — dark techno, room to breathe ──────────────────────
        Pattern(
            id: "space-drift", name: "Space Drift", tempo: 120, swing: 0.02,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(4, 12),
                "hat":   row(2, 6, 10, 14),
                "bass":  row(0, 6, 10),
                "perc":  row(7, 15),
            ],
            volumes: ["kick": 0.88, "bass": 0.82, "hat": 0.58, "perc": 0.75],
            effects: [
                "kick":  fx(rvb: 42),
                "snare": fx(rvb: 62),
                "hat":   fx(rvb: 50),
                "bass":  fx(rvb: 35),
                "perc":  fx(rvb: 72, dst: 18),
            ],
            kitId: "space"
        ),

        // ── Arcade Rush — 8-bit boss battle ──────────────────────────────────
        Pattern(
            id: "arcade-rush", name: "Arcade Rush", tempo: 150, swing: 0.0,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "clap":  row(2, 10),
                "bass":  row(0, 3, 8, 11),
                "pluck": row(0, 3, 6, 10, 13),
                "perc":  row(1, 5, 9, 13),
            ],
            volumes: ["hat": 0.55, "clap": 0.78, "pluck": 0.72],
            effects: [
                "kick":  fx(dst: 32),
                "snare": fx(dst: 28),
                "hat":   fx(dst: 15),
                "clap":  fx(dst: 24),
                "bass":  fx(dst: 20),
                "pluck": fx(dly: 18, div: .sixteenth, dst: 35),
                "perc":  fx(dst: 18),
            ],
            kitId: "arcade"
        ),

        // ── Dusty Breaks — vintage amen-break energy ─────────────────────────
        Pattern(
            id: "dusty-breaks", name: "Dusty Breaks", tempo: 95, swing: 0.22,
            rows: [
                "kick":  row(0, 6, 10),
                "snare": row(4, 11, 12, 14),
                "hat":   row(0, 2, 3, 5, 7, 8, 10, 11, 13, 15),
                "bass":  row(0, 8),
                "pluck": row(2, 12),
                "perc":  row(5, 13),
            ],
            volumes: ["kick": 0.90, "snare": 0.85],
            effects: [
                "snare": fx(rvb: 40, dst: 18),
                "hat":   fx(dst: 22),
                "bass":  fx(rvb: 22),
                "pluck": fx(rvb: 35, dly: 20, div: .eighth),
            ],
            kitId: "dusty-tape"
        ),

        // ── Marimba Groove — afrobeat cross-rhythms ──────────────────────────
        Pattern(
            id: "marimba-groove", name: "Marimba Groove", tempo: 105, swing: 0.15,
            rows: [
                "kick":  row(0, 3, 8, 11),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "bass":  row(0, 2, 5, 8, 10, 13),
                "pluck": row(1, 4, 9, 13),
                "perc":  row(3, 7, 11, 15),
            ],
            volumes: ["bass": 0.80, "pluck": 0.75, "perc": 0.70],
            effects: [
                "snare": fx(rvb: 22),
                "bass":  fx(rvb: 28),
                "pluck": fx(rvb: 32, dly: 18, div: .eighth),
                "perc":  fx(rvb: 35, dly: 22, div: .eighth),
            ],
            kitId: "marimba"
        ),

        // ── Boom Bap Classic — SP-1200 knock ─────────────────────────────────
        Pattern(
            id: "boom-bap-classic", name: "Boom Bap Classic", tempo: 88, swing: 0.22,
            rows: [
                "kick":  row(0, 6, 10),
                "snare": row(4, 12),
                "hat":   row(2, 6, 10, 14),
                "clap":  row(4),
                "bass":  row(0, 10),
                "pluck": row(3, 11),
                "perc":  row(7, 15),
            ],
            volumes: ["kick": 0.95, "snare": 0.90, "bass": 0.80],
            effects: [
                "kick":  fx(rvb: 15),
                "snare": fx(rvb: 32),
                "pluck": fx(rvb: 28, dly: 20, div: .eighth),
            ],
            kitId: "boom-bap"
        ),

        // ── Jazz Brush — real jazz shuffle ───────────────────────────────────
        Pattern(
            id: "jazz-brush", name: "Jazz Brush", tempo: 92, swing: 0.30,
            rows: [
                "kick":  row(0, 3, 10),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "clap":  row(4),
                "bass":  row(0, 4, 6, 8, 12),
                "pluck": row(2, 10),
            ],
            volumes: ["kick": 0.72, "bass": 0.68, "hat": 0.68, "pluck": 0.80],
            effects: [
                "kick":  fx(rvb: 18),
                "snare": fx(rvb: 45),
                "hat":   fx(rvb: 35),
                "bass":  fx(rvb: 22),
                "pluck": fx(rvb: 40, dly: 18, div: .eighth),
            ],
            kitId: "jazz"
        ),

        // ── Jungle Chop 2-bar — bar 2 strips grit for space ─────────────────
        Pattern(
            id: "jungle-chop-2", name: "Jungle Chop", tempo: 92, swing: 0.18,
            rows: [
                "kick":  row2(0, 4, 8, 12,        16, 20, 24, 28),
                "snare": row2(4, 12,              20, 28),
                "hat":   row2(0,2,4,6,8,10,12,14, 16,18,20,22,24,26,28,30),
                "clap":  row2(4, 12,              20, 28),
                "bass":  row2(0, 3, 8, 11,        16, 19, 24, 27),
                "pluck": row2(2, 10,              18, 26),
                "perc":  row2(0, 8, 12,           16, 24, 28),
            ],
            volumes: ["pluck": 0.55],
            effects: [
                "hat":   fx(rvb: 66, dly: 32, div: .quarter,   dst: 92),
                "bass":  fx(rvb: 43, dly: 12, div: .sixteenth, dst: 60),
                "pluck": fx(rvb: 31, dly: 70, div: .sixteenth, dst: 69),
                "perc":  fx(rvb: 75, dly: 57, div: .sixteenth, dst: 83),
            ],
            kitId: "jungle",
            patternLength: 32,
            bar2Volumes: ["pluck": 0.10],
            bar2Effects: [
                "hat":   fx(rvb: 88, dly: 15, div: .quarter,   dst: 20),
                "bass":  fx(rvb: 70, dly: 0,  div: .sixteenth, dst: 15),
                "pluck": fx(rvb: 85, dly: 45, div: .eighth,    dst: 10),
                "perc":  fx(rvb: 90, dly: 25, div: .eighth,    dst: 18),
            ],
            basePresetId: "jungle-chop", barLength: 2
        ),

        // ── Boom Bap 2-bar — bar 2 turnaround fill ───────────────────────────
        Pattern(
            id: "boom-bap-2", name: "Boom Bap Classic", tempo: 88, swing: 0.22,
            rows: [
                "kick":  row2(0, 6, 10,       16, 22, 28, 30),
                "snare": row2(4, 12,           20, 28, 30),
                "hat":   row2(2, 6, 10, 14,    18, 22, 26, 30),
                "clap":  row2(4,               20),
                "bass":  row2(0, 10,           16, 26, 30),
                "pluck": row2(3, 11,           19, 27),
                "perc":  row2(7,               23),
            ],
            volumes: ["kick": 0.95, "snare": 0.90, "bass": 0.80],
            effects: [
                "kick":  fx(rvb: 15),
                "snare": fx(rvb: 32),
                "pluck": fx(rvb: 28, dly: 20, div: .eighth),
            ],
            kitId: "boom-bap",
            patternLength: 32,
            basePresetId: "boom-bap-classic", barLength: 2
        ),

        // ── 808 Groove 2-bar — bar 2 synco push ──────────────────────────────
        Pattern(
            id: "808-groove-2", name: "808 Groove", tempo: 85, swing: 0.22,
            rows: [
                "kick":  row2(0, 10,              16, 26, 28),
                "snare": row2(4, 12,              20, 28),
                "hat":   row2(0,2,4,6,8,10,12,14, 16,18,20,22,24,26,28,30),
                "clap":  row2(4,                  20),
                "bass":  row2(0, 6, 10,           16, 22, 28, 30),
                "pluck": row2(3, 11,              19, 23, 29),
            ],
            volumes: ["kick": 0.92, "snare": 0.80, "bass": 0.88, "hat": 0.58, "clap": 0.70, "pluck": 0.68],
            effects: [
                "kick":  fx(rvb: 28, dst: 15),
                "snare": fx(rvb: 42),
                "hat":   fx(rvb: 20),
                "clap":  fx(rvb: 38),
                "bass":  fx(rvb: 32, dst: 30),
                "pluck": fx(rvb: 48, dly: 20, div: .eighth),
            ],
            kitId: "808",
            patternLength: 32,
            basePresetId: "808-memphis", barLength: 2
        ),

        // ── Rainy Lo-Fi 2-bar — bar 2 drift and dissolve ─────────────────────
        Pattern(
            id: "rainy-lofi-2", name: "Rainy Lo-Fi", tempo: 75, swing: 0.32,
            rows: [
                "kick":  row2(0, 10,              16, 28),
                "snare": row2(4, 13,              20, 29),
                "hat":   row2(0,2,4,6,8,10,12,14, 16,18,20,22,24,26,28,30),
                "bass":  row2(0, 6, 10,           16, 24, 30),
                "pluck": row2(3, 9, 14,           21, 27, 30),
                "perc":  row2(5, 11,              19, 27),
            ],
            volumes: ["kick": 0.78, "snare": 0.68, "hat": 0.55, "bass": 0.82, "pluck": 0.72],
            effects: [
                "kick":  fx(rvb: 52),
                "snare": fx(rvb: 58),
                "hat":   fx(rvb: 62),
                "bass":  fx(rvb: 45, dly: 18, div: .eighth),
                "pluck": fx(rvb: 70, dly: 28, div: .eighth),
                "perc":  fx(rvb: 55),
            ],
            kitId: "rainy-night",
            patternLength: 32,
            basePresetId: "rainy-lofi", barLength: 2
        ),

        // ── Dusty Breaks 2-bar — bar 2 break fill ────────────────────────────
        Pattern(
            id: "dusty-breaks-2", name: "Dusty Breaks", tempo: 95, swing: 0.22,
            rows: [
                "kick":  row2(0, 6, 10,               16, 24, 28, 30),
                "snare": row2(4, 11, 12, 14,           20, 26, 27, 28, 30),
                "hat":   row2(0,2,3,5,7,8,10,11,13,15, 16,18,19,21,23,24,26,27,29,31),
                "bass":  row2(0, 8,                   16, 24),
                "pluck": row2(2, 12,                  18, 28),
                "perc":  row2(5, 13,                  21, 29),
            ],
            volumes: ["kick": 0.90, "snare": 0.85],
            effects: [
                "snare": fx(rvb: 40, dst: 18),
                "hat":   fx(dst: 22),
                "bass":  fx(rvb: 22),
                "pluck": fx(rvb: 35, dly: 20, div: .eighth),
            ],
            kitId: "dusty-tape",
            patternLength: 32,
            basePresetId: "dusty-breaks", barLength: 2
        ),

        // ── Jazz Brush 2-bar — bar 2 open blowing ────────────────────────────
        Pattern(
            id: "jazz-brush-2", name: "Jazz Brush", tempo: 92, swing: 0.30,
            rows: [
                "kick":  row2(0, 3, 10,           17, 26),
                "snare": row2(4, 12,              22, 28, 30),
                "hat":   row2(0,2,4,6,8,10,12,14, 16,18,20,22,24,26,28,30),
                "clap":  row2(4,                  20),
                "bass":  row2(0, 4, 6, 8, 12,     16, 20, 22, 26, 28),
                "pluck": row2(2, 10,              18, 24, 30),
            ],
            volumes: ["kick": 0.72, "bass": 0.68, "hat": 0.68, "pluck": 0.80],
            effects: [
                "kick":  fx(rvb: 18),
                "snare": fx(rvb: 45),
                "hat":   fx(rvb: 35),
                "bass":  fx(rvb: 22),
                "pluck": fx(rvb: 40, dly: 18, div: .eighth),
            ],
            kitId: "jazz",
            patternLength: 32,
            basePresetId: "jazz-brush", barLength: 2
        ),

        // ── Music Box Fantasy 2-bar — bar 2 harmonic shift ───────────────────
        Pattern(
            id: "music-box-2", name: "Music Box Fantasy", tempo: 82, swing: 0.10,
            rows: [
                "kick":  row2(0, 4, 8, 12,      16, 20, 24, 28),
                "snare": row2(2, 10,             18, 26),
                "hat":   row2(0, 8,              17, 25),
                "bass":  row2(0, 3, 6, 9, 12,   17, 21, 25, 29),
                "pluck": row2(1, 5, 8, 11, 14,  16, 19, 23, 26, 30),
                "perc":  row2(4, 12,             20, 28),
            ],
            volumes: ["hat": 0.50, "kick": 0.62],
            effects: [
                "kick":  fx(rvb: 62),
                "snare": fx(rvb: 78, dly: 28, div: .eighth),
                "hat":   fx(rvb: 45),
                "bass":  fx(rvb: 68, dly: 35, div: .eighth),
                "pluck": fx(rvb: 82, dly: 50, div: .eighth),
                "perc":  fx(rvb: 72),
            ],
            kitId: "music-box",
            patternLength: 32,
            basePresetId: "music-box-fantasy", barLength: 2
        ),

        // ── Space Drift 2-bar — bar 2 build ──────────────────────────────────
        Pattern(
            id: "space-drift-2", name: "Space Drift", tempo: 120, swing: 0.02,
            rows: [
                "kick":  row2(0, 4, 8, 12,   16, 20, 24, 28),
                "snare": row2(4, 12,          20, 28),
                "hat":   row2(2, 6, 10, 14,  18, 22, 26, 30),
                "bass":  row2(0, 6, 10,      17, 22, 26, 30),
                "perc":  row2(7, 15,         19, 23, 29),
            ],
            volumes: ["kick": 0.88, "bass": 0.82, "hat": 0.58, "perc": 0.75],
            effects: [
                "kick":  fx(rvb: 42),
                "snare": fx(rvb: 62),
                "hat":   fx(rvb: 50),
                "bass":  fx(rvb: 35),
                "perc":  fx(rvb: 72, dst: 18),
            ],
            kitId: "space",
            patternLength: 32,
            basePresetId: "space-drift", barLength: 2
        ),

        // ── Arcade Rush 2-bar — bar 2 phase shift ────────────────────────────
        Pattern(
            id: "arcade-rush-2", name: "Arcade Rush", tempo: 150, swing: 0.0,
            rows: [
                "kick":  row2(0, 4, 8, 12,         16, 20, 24, 28),
                "snare": row2(4, 12,               20, 26, 28),
                "hat":   row2(0,2,4,6,8,10,12,14,  16,18,20,22,24,26,28,30),
                "clap":  row2(2, 10,               18, 26),
                "bass":  row2(0, 3, 8, 11,         17, 20, 24, 27, 30),
                "pluck": row2(0, 3, 6, 10, 13,     16, 19, 22, 27, 30),
                "perc":  row2(1, 5, 9, 13,         17, 21, 25, 31),
            ],
            volumes: ["hat": 0.55, "clap": 0.78, "pluck": 0.72],
            effects: [
                "kick":  fx(dst: 32),
                "snare": fx(dst: 28),
                "hat":   fx(dst: 15),
                "clap":  fx(dst: 24),
                "bass":  fx(dst: 20),
                "pluck": fx(dly: 18, div: .sixteenth, dst: 35),
                "perc":  fx(dst: 18),
            ],
            kitId: "arcade",
            patternLength: 32,
            basePresetId: "arcade-rush", barLength: 2
        ),

        // ── Marimba Groove 2-bar — bar 2 inverted cross-rhythm ───────────────
        Pattern(
            id: "marimba-groove-2", name: "Marimba Groove", tempo: 105, swing: 0.15,
            rows: [
                "kick":  row2(0, 3, 8, 11,       16, 19, 24, 27),
                "snare": row2(4, 12,             20, 28),
                "hat":   row2(0,2,4,6,8,10,12,14, 16,18,20,22,24,26,28,30),
                "bass":  row2(0, 2, 5, 8, 10, 13, 17, 20, 23, 26, 29),
                "pluck": row2(1, 4, 9, 13,       18, 22, 25, 29),
                "perc":  row2(3, 7, 11, 15,      18, 22, 26, 30),
            ],
            volumes: ["bass": 0.80, "pluck": 0.75, "perc": 0.70],
            effects: [
                "snare": fx(rvb: 22),
                "bass":  fx(rvb: 28),
                "pluck": fx(rvb: 32, dly: 18, div: .eighth),
                "perc":  fx(rvb: 35, dly: 22, div: .eighth),
            ],
            kitId: "marimba",
            patternLength: 32,
            basePresetId: "marimba-groove", barLength: 2
        ),

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
        for (k, v) in rows where out[k] != nil {
            if v.count == length {
                out[k] = v
            } else if v.count > length {
                out[k] = Array(v.prefix(length))
            }
        }
        return out
    }
}

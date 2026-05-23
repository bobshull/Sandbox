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
    var accents: [String: [Bool]]?
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
                            dst: Float = 0,
                            pan: Float = 0, pitch: Float = 0) -> TrackEffects {
        TrackEffects(pan: pan, pitch: pitch, reverbWet: rvb, delayWet: dly,
                     delaySyncDivision: div, distortionWet: dst)
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

        // ── Concrete Jungle — NYC boom bap, punchy downbeat knock ────────────
        Pattern(
            id: "concrete-jungle", name: "Concrete Jungle", tempo: 87, swing: 0.25,
            rows: [
                "kick":  row(0, 6, 10),
                "snare": row(4, 12),
                "hat":   row(2, 6, 10, 14),
                "clap":  row(4),
                "bass":  row(0, 5, 8, 11),
                "pluck": row(2, 9, 15),
                "perc":  row(7, 13),
            ],
            volumes: ["kick": 0.92, "snare": 0.88, "hat": 0.65, "clap": 0.75, "bass": 0.85, "pluck": 0.72, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 18, dst: 20),
                "snare": fx(rvb: 35),
                "hat":   fx(rvb: 22, pan: -0.20),
                "clap":  fx(rvb: 30, pan:  0.15),
                "bass":  fx(rvb: 12),
                "pluck": fx(rvb: 32, dly: 22, pan:  0.30),
                "perc":  fx(rvb: 28, pan: -0.30),
            ],
            kitId: "boom-bap",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "hat":   row(2, 10),
            ]
        ),

        // ── Concrete Jungle 2-bar — bar 2 snare fill turnaround ──────────────
        Pattern(
            id: "concrete-jungle-2", name: "Concrete Jungle", tempo: 87, swing: 0.25,
            rows: [
                "kick":  row2(0, 6, 10,        16, 22, 26, 30, 31),
                "snare": row2(4, 12,            20, 27, 28),
                "hat":   row2(2, 6, 10, 14,     18, 22, 26, 30),
                "clap":  row2(4,                20),
                "bass":  row2(0, 5, 8, 11,      16, 21, 24, 27),
                "pluck": row2(2, 9, 15,         18, 25, 31),
                "perc":  row2(7, 13,            23),
            ],
            volumes: ["kick": 0.92, "snare": 0.88, "hat": 0.65, "clap": 0.75, "bass": 0.85, "pluck": 0.72, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 18, dst: 20),
                "snare": fx(rvb: 35),
                "hat":   fx(rvb: 22, pan: -0.20),
                "clap":  fx(rvb: 30, pan:  0.15),
                "bass":  fx(rvb: 12),
                "pluck": fx(rvb: 32, dly: 22, pan:  0.30),
                "perc":  fx(rvb: 28, pan: -0.30),
            ],
            kitId: "boom-bap",
            patternLength: 32,
            basePresetId: "concrete-jungle", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(4, 20),
                "hat":   row2(2, 10, 18, 26),
            ]
        ),

        // ── Soul Choppa — dusty soul chops, chopped-sample stabs ─────────────
        Pattern(
            id: "soul-choppa", name: "Soul Choppa", tempo: 90, swing: 0.28,
            rows: [
                "kick":  row(0, 8, 11),
                "snare": row(4, 14),
                "hat":   row(2, 4, 6, 8, 10, 12, 14),
                "clap":  row(12),
                "bass":  row(0, 3, 6, 9, 12),
                "pluck": row(1, 7, 11, 15),
                "pad":   row(0, 8),
                "perc":  row(5, 13),
            ],
            volumes: ["kick": 0.90, "snare": 0.85, "hat": 0.60, "clap": 0.70, "bass": 0.85, "pluck": 0.68, "pad": 0.45, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 20, dst: 22),
                "snare": fx(rvb: 40, pan:  0.10),
                "hat":   fx(dst: 30, pan: -0.15),
                "clap":  fx(rvb: 38, pan:  0.20),
                "bass":  fx(dst: 18),
                "pluck": fx(rvb: 28, dly: 20, div: .sixteenth, pan:  0.35),
                "pad":   fx(rvb: 60, dly: 18, div: .quarter,   pan: -0.20),
                "perc":  fx(rvb: 22, pan: -0.25),
            ],
            kitId: "dusty-tape",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "hat":   row(4, 12),
                "pluck": row(1, 11),
            ]
        ),

        // ── Soul Choppa 2-bar — bar 2 off-beat kick variation ────────────────
        Pattern(
            id: "soul-choppa-2", name: "Soul Choppa", tempo: 90, swing: 0.28,
            rows: [
                "kick":  row2(0, 8, 11,              16, 20, 26, 28),
                "snare": row2(4, 14,                 20, 28, 30),
                "hat":   row2(2,4,6,8,10,12,14,      18,20,22,24,26,28,30),
                "clap":  row2(12,                    28),
                "bass":  row2(0, 3, 6, 9, 12,        16, 19, 22, 25, 28),
                "pluck": row2(1, 7, 11, 15,          17, 23, 27, 31),
                "pad":   row2(0, 8,                  16, 24),
                "perc":  row2(5, 13,                 21, 29),
            ],
            volumes: ["kick": 0.90, "snare": 0.85, "hat": 0.60, "clap": 0.70, "bass": 0.85, "pluck": 0.68, "pad": 0.45, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 20, dst: 22),
                "snare": fx(rvb: 40, pan:  0.10),
                "hat":   fx(dst: 30, pan: -0.15),
                "clap":  fx(rvb: 38, pan:  0.20),
                "bass":  fx(dst: 18),
                "pluck": fx(rvb: 28, dly: 20, div: .sixteenth, pan:  0.35),
                "pad":   fx(rvb: 60, dly: 18, div: .quarter,   pan: -0.20),
                "perc":  fx(rvb: 22, pan: -0.25),
            ],
            kitId: "dusty-tape",
            patternLength: 32,
            basePresetId: "soul-choppa", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(4, 20),
                "hat":   row2(4, 12, 20, 28),
                "pluck": row2(1, 11, 17, 27),
            ]
        ),

        // ── Late Night 808 — slow southern sub, heavy drag, doubled backbeat ──
        Pattern(
            id: "late-night-808", name: "Late Night 808", tempo: 76, swing: 0.18,
            rows: [
                "kick":  row(0, 6, 12),
                "snare": row(4, 12),
                "hat":   row(2, 4, 8, 10, 14),
                "clap":  row(4, 12),
                "bass":  row(0, 5, 8, 11),
                "pluck": row(3, 13),
            ],
            volumes: ["kick": 0.98, "snare": 0.80, "hat": 0.48, "clap": 0.68, "bass": 0.95, "pluck": 0.62],
            effects: [
                "kick":  fx(rvb: 18, dst: 22),
                "snare": fx(rvb: 42, pan:  0.10),
                "hat":   fx(rvb: 12, pan: -0.12),
                "clap":  fx(rvb: 52, pan:  0.18),
                "bass":  fx(rvb: 22, dst: 30),
                "pluck": fx(rvb: 55, dly: 25, pan:  0.35),
            ],
            kitId: "808",
            accents: [
                "kick":  row(0),
                "bass":  row(0, 8),
            ]
        ),

        // ── Late Night 808 2-bar — bar 2 kicks push, bass crawls different ────
        Pattern(
            id: "late-night-808-2", name: "Late Night 808", tempo: 76, swing: 0.18,
            rows: [
                "kick":  row2(0, 6, 12,               16, 22, 28, 31),
                "snare": row2(4, 12,                  20, 28),
                "hat":   row2(2, 4, 8, 10, 14,        18, 20, 24, 26, 30),
                "clap":  row2(4, 12,                  20, 28),
                "bass":  row2(0, 5, 8, 11,            16, 21, 24, 27),
                "pluck": row2(3, 13,                  19, 29),
            ],
            volumes: ["kick": 0.98, "snare": 0.80, "hat": 0.48, "clap": 0.68, "bass": 0.95, "pluck": 0.62],
            effects: [
                "kick":  fx(rvb: 18, dst: 22),
                "snare": fx(rvb: 42, pan:  0.10),
                "hat":   fx(rvb: 12, pan: -0.12),
                "clap":  fx(rvb: 52, pan:  0.18),
                "bass":  fx(rvb: 22, dst: 30),
                "pluck": fx(rvb: 55, dly: 25, pan:  0.35),
            ],
            kitId: "808",
            patternLength: 32,
            basePresetId: "late-night-808", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "bass":  row2(0, 8, 16, 24),
            ]
        ),

        // ── Coffee Shop — warm lo-fi head-nod, late afternoon easy ───────────
        Pattern(
            id: "coffee-shop", name: "Coffee Shop", tempo: 80, swing: 0.38,
            rows: [
                "kick":  row(0, 8),
                "snare": row(4, 13),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "bass":  row(0, 5, 9),
                "pluck": row(2, 6, 10, 14),
                "pad":   row(0, 8),
                "perc":  row(5, 13),
            ],
            volumes: ["kick": 0.75, "snare": 0.65, "hat": 0.52, "bass": 0.80, "pluck": 0.70, "pad": 0.40, "perc": 0.48],
            effects: [
                "kick":  fx(rvb: 52, dst: 12),
                "snare": fx(rvb: 62, pan:  0.10),
                "hat":   fx(rvb: 55, dst:  8, pan: -0.12),
                "bass":  fx(rvb: 42, dst: 10),
                "pluck": fx(rvb: 68, dly: 30, pan:  0.25),
                "pad":   fx(rvb: 75, dly: 15, div: .quarter, pan: -0.15),
                "perc":  fx(rvb: 50, pan: -0.28),
            ],
            kitId: "rainy-night",
            accents: [
                "hat":   row(2, 10),
                "pluck": row(2),
                "bass":  row(0),
            ]
        ),

        // ── Coffee Shop 2-bar — bar 2 shifts bass walk, sparser kick ─────────
        Pattern(
            id: "coffee-shop-2", name: "Coffee Shop", tempo: 80, swing: 0.38,
            rows: [
                "kick":  row2(0, 8,                   16, 26),
                "snare": row2(4, 13,                  20, 29),
                "hat":   row2(0,2,4,6,8,10,12,14,     16,18,20,22,24,26,28,30),
                "bass":  row2(0, 5, 9,                16, 21, 25),
                "pluck": row2(2, 6, 10, 14,           18, 22, 26, 30),
                "pad":   row2(0, 8,                   16, 24),
                "perc":  row2(5, 13,                  19, 29),
            ],
            volumes: ["kick": 0.75, "snare": 0.65, "hat": 0.52, "bass": 0.80, "pluck": 0.70, "pad": 0.40, "perc": 0.48],
            effects: [
                "kick":  fx(rvb: 52, dst: 12),
                "snare": fx(rvb: 62, pan:  0.10),
                "hat":   fx(rvb: 55, dst:  8, pan: -0.12),
                "bass":  fx(rvb: 42, dst: 10),
                "pluck": fx(rvb: 68, dly: 30, pan:  0.25),
                "pad":   fx(rvb: 75, dly: 15, div: .quarter, pan: -0.15),
                "perc":  fx(rvb: 50, pan: -0.28),
            ],
            kitId: "rainy-night",
            patternLength: 32,
            basePresetId: "coffee-shop", barLength: 2,
            accents: [
                "hat":   row2(2, 10, 18, 26),
                "pluck": row2(2, 18),
                "bass":  row2(0, 16),
            ]
        ),

        // ── Bedroom Sessions — ultra-slow dusty tape, minimal, ceiling-staring
        Pattern(
            id: "bedroom-sessions", name: "Bedroom Sessions", tempo: 73, swing: 0.42,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4, 13),
                "hat":   row(2, 6, 10, 14),
                "bass":  row(0, 6, 10),
                "pluck": row(3, 11, 15),
                "pad":   row(0),
                "perc":  row(7),
            ],
            volumes: ["kick": 0.78, "snare": 0.62, "hat": 0.48, "bass": 0.82, "pluck": 0.65, "pad": 0.38, "perc": 0.45],
            effects: [
                "kick":  fx(rvb: 58, dst: 20),
                "snare": fx(rvb: 65, pan:  0.08),
                "hat":   fx(rvb: 60, dst: 12, pan: -0.22),
                "bass":  fx(rvb: 45, dst: 15),
                "pluck": fx(rvb: 72, dly: 35, pan:  0.32),
                "pad":   fx(rvb: 80, dly: 20, div: .quarter, pan:  0.10),
                "perc":  fx(rvb: 58, pan: -0.38),
            ],
            kitId: "dusty-tape",
            accents: [
                "kick":  row(0),
                "hat":   row(6, 14),
                "pluck": row(3, 11),
            ]
        ),

        // ── Rainy Window — music-box lullaby pulse, sparse and tinkling ──────
        Pattern(
            id: "rainy-window", name: "Rainy Window", tempo: 76, swing: 0.35,
            rows: [
                "kick":  row(0, 8),
                "snare": row(4, 12),
                "hat":   row(0, 4, 8, 12),
                "bass":  row(0, 2, 5, 8, 11, 14),
                "pluck": row(1, 3, 7, 9, 13),
                "pad":   row(0, 8),
                "perc":  row(3, 7, 11, 15),
            ],
            volumes: ["kick": 0.60, "snare": 0.55, "hat": 0.42, "bass": 0.72, "pluck": 0.78, "pad": 0.45, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 68),
                "snare": fx(rvb: 72, pan:  0.12),
                "hat":   fx(rvb: 60, pan: -0.10),
                "bass":  fx(rvb: 65, dly: 22),
                "pluck": fx(rvb: 80, dly: 40, pan:  0.28),
                "pad":   fx(rvb: 82, dly: 18, div: .quarter, pan: -0.18),
                "perc":  fx(rvb: 75, dly: 28, pan: -0.32),
            ],
            kitId: "music-box",
            accents: [
                "pluck": row(1, 9),
                "perc":  row(3, 11),
            ]
        ),

        // ── Rainy Window 2-bar — bar 2 shifts melody slightly ────────────────
        Pattern(
            id: "rainy-window-2", name: "Rainy Window", tempo: 76, swing: 0.35,
            rows: [
                "kick":  row2(0, 8,                   16, 24),
                "snare": row2(4, 12,                  20, 28),
                "hat":   row2(0, 4, 8, 12,            16, 20, 24, 28),
                "bass":  row2(0, 2, 5, 8, 11, 14,     16, 18, 21, 24, 27, 30),
                "pluck": row2(1, 3, 7, 9, 13,         17, 19, 23, 25, 29),
                "pad":   row2(0, 8,                   16, 24),
                "perc":  row2(3, 7, 11, 15,           18, 22, 27, 31),
            ],
            volumes: ["kick": 0.60, "snare": 0.55, "hat": 0.42, "bass": 0.72, "pluck": 0.78, "pad": 0.45, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 68),
                "snare": fx(rvb: 72, pan:  0.12),
                "hat":   fx(rvb: 60, pan: -0.10),
                "bass":  fx(rvb: 65, dly: 22),
                "pluck": fx(rvb: 80, dly: 40, pan:  0.28),
                "pad":   fx(rvb: 82, dly: 18, div: .quarter, pan: -0.18),
                "perc":  fx(rvb: 75, dly: 28, pan: -0.32),
            ],
            kitId: "music-box",
            patternLength: 32,
            basePresetId: "rainy-window", barLength: 2,
            accents: [
                "pluck": row2(1, 9, 17, 25),
                "perc":  row2(3, 11, 18, 27),
            ]
        ),

        // ── 3AM Vibes — sparse jazz lo-fi, heavy swing, walking bass ─────────
        Pattern(
            id: "3am-vibes", name: "3AM Vibes", tempo: 82, swing: 0.44,
            rows: [
                "kick":  row(0, 9, 14),
                "snare": row(4, 12),
                "hat":   row(2, 6, 8, 12),
                "clap":  row(4),
                "bass":  row(0, 3, 6, 9, 13),
                "pluck": row(2, 8, 13),
                "pad":   row(0, 8),
                "perc":  row(5, 11),
            ],
            volumes: ["kick": 0.68, "snare": 0.65, "hat": 0.55, "clap": 0.45, "bass": 0.78, "pluck": 0.72, "pad": 0.40, "perc": 0.48],
            effects: [
                "kick":  fx(rvb: 42),
                "snare": fx(rvb: 52, pan:  0.12),
                "hat":   fx(rvb: 48, pan:  0.10),
                "clap":  fx(rvb: 55, pan:  0.20),
                "bass":  fx(rvb: 32, dly: 12),
                "pluck": fx(rvb: 60, dly: 25, pan: -0.22),
                "pad":   fx(rvb: 75, dly: 18, div: .quarter, pan:  0.18),
                "perc":  fx(rvb: 50, pan: -0.28),
            ],
            kitId: "jazz",
            accents: [
                "hat":   row(2, 8),
                "bass":  row(0, 9),
                "pluck": row(2, 13),
            ]
        ),

        // ── 3AM Vibes 2-bar — bar 2 bass extends, snare pushes the pocket ────
        Pattern(
            id: "3am-vibes-2", name: "3AM Vibes", tempo: 82, swing: 0.44,
            rows: [
                "kick":  row2(0, 9, 14,               16, 25, 28, 30),
                "snare": row2(4, 12,                  20, 28, 31),
                "hat":   row2(2, 6, 8, 12,            18, 22, 24, 28),
                "clap":  row2(4,                      20),
                "bass":  row2(0, 3, 6, 9, 13,         16, 19, 22, 25, 29),
                "pluck": row2(2, 8, 13,               18, 24, 29),
                "pad":   row2(0, 8,                   16, 24),
                "perc":  row2(5, 11,                  21, 27),
            ],
            volumes: ["kick": 0.68, "snare": 0.65, "hat": 0.55, "clap": 0.45, "bass": 0.78, "pluck": 0.72, "pad": 0.40, "perc": 0.48],
            effects: [
                "kick":  fx(rvb: 42),
                "snare": fx(rvb: 52, pan:  0.12),
                "hat":   fx(rvb: 48, pan:  0.10),
                "clap":  fx(rvb: 55, pan:  0.20),
                "bass":  fx(rvb: 32, dly: 12),
                "pluck": fx(rvb: 60, dly: 25, pan: -0.22),
                "pad":   fx(rvb: 75, dly: 18, div: .quarter, pan:  0.18),
                "perc":  fx(rvb: 50, pan: -0.28),
            ],
            kitId: "jazz",
            patternLength: 32,
            basePresetId: "3am-vibes", barLength: 2,
            accents: [
                "hat":   row2(2, 8, 18, 24),
                "bass":  row2(0, 9, 16, 25),
                "pluck": row2(2, 13, 18, 29),
            ]
        ),

        // ── Glass Garden — sparse glass percussion, wide stereo shimmer ──────
        Pattern(
            id: "glass-garden", name: "Glass Garden", tempo: 72, swing: 0.08,
            rows: [
                "kick":  row(0, 8),
                "hat":   row(2, 6, 10, 14),
                "bass":  row(0, 4, 9),
                "pluck": row(0, 3, 7, 12),
                "pad":   row(0, 8),
                "perc":  row(1, 5, 9, 13),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.72, "pad": 0.55, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 75),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 72, dly: 18, pan: -0.10, pitch: -5),
                "pluck": fx(rvb: 85, dly: 45, pan:  0.40),
                "pad":   fx(rvb: 88, dly: 25, div: .quarter, pan: -0.30),
                "perc":  fx(rvb: 78, dly: 30, pan: -0.45, pitch:  5),
            ],
            kitId: "glass",
            accents: [
                "pluck": row(0, 7),
                "perc":  row(1, 9),
            ]
        ),

        // ── Glass Garden 2-bar — bar 2 melody evolves, bass reharmonizes ─────
        Pattern(
            id: "glass-garden-2", name: "Glass Garden", tempo: 72, swing: 0.08,
            rows: [
                "kick":  row2(0, 8,                  16, 24),
                "hat":   row2(2, 6, 10, 14,          18, 22, 26, 30),
                "bass":  row2(0, 4, 9,               16, 20, 25, 28),
                "pluck": row2(0, 3, 7, 12,           17, 19, 23, 27, 31),
                "pad":   row2(0, 8,                  16, 24),
                "perc":  row2(1, 5, 9, 13,           17, 21, 25, 29),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.72, "pad": 0.55, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 75),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 72, dly: 18, pan: -0.10, pitch: -5),
                "pluck": fx(rvb: 85, dly: 45, pan:  0.40),
                "pad":   fx(rvb: 88, dly: 25, div: .quarter, pan: -0.30),
                "perc":  fx(rvb: 78, dly: 30, pan: -0.45, pitch:  5),
            ],
            kitId: "glass",
            patternLength: 32,
            basePresetId: "glass-garden", barLength: 2,
            accents: [
                "pluck": row2(0, 7, 17, 27),
                "perc":  row2(1, 9, 17, 25),
            ]
        ),

        // ── Drifting Smoke — ultra-sparse space drone, max space between hits ─
        Pattern(
            id: "drifting-smoke", name: "Drifting Smoke", tempo: 65, swing: 0.05,
            rows: [
                "kick":  row(0, 12),
                "snare": row(4),
                "hat":   row(8),
                "bass":  row(0, 7),
                "pluck": row(3, 11),
                "pad":   row(0),
                "perc":  row(5, 13),
            ],
            volumes: ["kick": 0.70, "snare": 0.55, "hat": 0.40, "bass": 0.72, "pluck": 0.62, "pad": 0.60, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 65, dst: 15),
                "snare": fx(rvb: 80, pan:  0.10),
                "hat":   fx(rvb: 78, pan:  0.30),
                "bass":  fx(rvb: 58, dly: 22, div: .quarter, pitch: -7),
                "pluck": fx(rvb: 90, dly: 55, pan:  0.38, pitch:  3),
                "pad":   fx(rvb: 92, dly: 30, div: .quarter, pan: -0.25),
                "perc":  fx(rvb: 85, dst: 12, pan: -0.40),
            ],
            kitId: "space",
            accents: [
                "kick":  row(0),
                "pad":   row(0),
                "pluck": row(3),
            ]
        ),

        // ── Drifting Smoke 2-bar — identical bar 2 for seamless loop ─────────
        Pattern(
            id: "drifting-smoke-2", name: "Drifting Smoke", tempo: 65, swing: 0.05,
            rows: [
                "kick":  row2(0, 12,           16, 28),
                "snare": row2(4,               20),
                "hat":   row2(8,               24),
                "bass":  row2(0, 7,            16, 23),
                "pluck": row2(3, 11,           19, 27),
                "pad":   row2(0,               16),
                "perc":  row2(5, 13,           21, 31),
            ],
            volumes: ["kick": 0.70, "snare": 0.55, "hat": 0.40, "bass": 0.72, "pluck": 0.62, "pad": 0.60, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 65, dst: 15),
                "snare": fx(rvb: 80, pan:  0.10),
                "hat":   fx(rvb: 78, pan:  0.30),
                "bass":  fx(rvb: 58, dly: 22, div: .quarter, pitch: -7),
                "pluck": fx(rvb: 90, dly: 55, pan:  0.38, pitch:  3),
                "pad":   fx(rvb: 92, dly: 30, div: .quarter, pan: -0.25),
                "perc":  fx(rvb: 85, dst: 12, pan: -0.40),
            ],
            kitId: "space",
            patternLength: 32,
            basePresetId: "drifting-smoke", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "pad":   row2(0, 16),
                "pluck": row2(3, 19),
            ]
        ),

        // ── Wind Through Chimes — no drums, pure chime-and-pad atmosphere ────
        Pattern(
            id: "wind-through-chimes", name: "Wind Through Chimes", tempo: 90, swing: 0.12,
            rows: [
                "hat":   row(0, 4, 8, 12),
                "bass":  row(0, 3, 6, 10),
                "pluck": row(0, 2, 5, 9, 12, 15),
                "pad":   row(0, 8),
                "perc":  row(1, 4, 7, 11, 14),
            ],
            volumes: ["hat": 0.42, "bass": 0.60, "pluck": 0.75, "pad": 0.52, "perc": 0.65],
            effects: [
                "hat":   fx(rvb: 82, pan:  0.28),
                "bass":  fx(rvb: 68, dly: 20, pan: -0.08, pitch: -3),
                "pluck": fx(rvb: 88, dly: 38, pan:  0.40, pitch:  2),
                "pad":   fx(rvb: 90, dly: 22, div: .quarter, pan: -0.30),
                "perc":  fx(rvb: 85, dly: 28, pan: -0.45, pitch:  5),
            ],
            kitId: "wind-chimes",
            accents: [
                "pluck": row(0, 9),
                "perc":  row(4, 14),
            ]
        ),

        // ── Wind Through Chimes 2-bar — bar 2 melodic variation ──────────────
        Pattern(
            id: "wind-through-chimes-2", name: "Wind Through Chimes", tempo: 90, swing: 0.12,
            rows: [
                "hat":   row2(0, 4, 8, 12,            16, 20, 24, 28),
                "bass":  row2(0, 3, 6, 10,            16, 19, 22, 26, 29),
                "pluck": row2(0, 2, 5, 9, 12, 15,     16, 18, 21, 25, 28, 31),
                "pad":   row2(0, 8,                   16, 24),
                "perc":  row2(1, 4, 7, 11, 14,        17, 20, 23, 27, 30),
            ],
            volumes: ["hat": 0.42, "bass": 0.60, "pluck": 0.75, "pad": 0.52, "perc": 0.65],
            effects: [
                "hat":   fx(rvb: 82, pan:  0.28),
                "bass":  fx(rvb: 68, dly: 20, pan: -0.08, pitch: -3),
                "pluck": fx(rvb: 88, dly: 38, pan:  0.40, pitch:  2),
                "pad":   fx(rvb: 90, dly: 22, div: .quarter, pan: -0.30),
                "perc":  fx(rvb: 85, dly: 28, pan: -0.45, pitch:  5),
            ],
            kitId: "wind-chimes",
            patternLength: 32,
            basePresetId: "wind-through-chimes", barLength: 2,
            accents: [
                "pluck": row2(0, 9, 16, 25),
                "perc":  row2(4, 14, 20, 30),
            ]
        ),

        // ── Toy Piano — bouncy and playful, upbeat toy-kit groove ────────────
        Pattern(
            id: "toy-piano-groove", name: "Toy Piano", tempo: 84, swing: 0.10,
            rows: [
                "kick":  row(0, 8),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "bass":  row(0, 4, 7, 11),
                "pluck": row(0, 2, 5, 9, 12),
                "pad":   row(0, 8),
                "perc":  row(3, 7, 11, 15),
            ],
            volumes: ["kick": 0.78, "snare": 0.72, "hat": 0.55, "bass": 0.75, "pluck": 0.82, "pad": 0.38, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 45, dst:  8),
                "snare": fx(rvb: 40, pan:  0.12),
                "hat":   fx(rvb: 35, pan: -0.15),
                "bass":  fx(rvb: 38, dly: 10),
                "pluck": fx(rvb: 52, dly: 22, pan:  0.28),
                "pad":   fx(rvb: 65, dly: 20, div: .quarter, pan: -0.18),
                "perc":  fx(rvb: 60, dly: 18, pan: -0.32, pitch:  3),
            ],
            kitId: "toy-piano",
            accents: [
                "kick":  row(0),
                "hat":   row(0, 8),
                "pluck": row(0, 9),
            ]
        ),

        // ── Toy Piano 2-bar — bar 2 shifts melody, snare fill at end ─────────
        Pattern(
            id: "toy-piano-groove-2", name: "Toy Piano", tempo: 84, swing: 0.10,
            rows: [
                "kick":  row2(0, 8,                        16, 24),
                "snare": row2(4, 12,                       20, 28, 30),
                "hat":   row2(0,2,4,6,8,10,12,14,          16,18,20,22,24,26,28,30),
                "bass":  row2(0, 4, 7, 11,                 16, 20, 23, 27),
                "pluck": row2(0, 2, 5, 9, 12,              17, 21, 24, 28, 31),
                "pad":   row2(0, 8,                        16, 24),
                "perc":  row2(3, 7, 11, 15,                19, 23, 27, 31),
            ],
            volumes: ["kick": 0.78, "snare": 0.72, "hat": 0.55, "bass": 0.75, "pluck": 0.82, "pad": 0.38, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 45, dst:  8),
                "snare": fx(rvb: 40, pan:  0.12),
                "hat":   fx(rvb: 35, pan: -0.15),
                "bass":  fx(rvb: 38, dly: 10),
                "pluck": fx(rvb: 52, dly: 22, pan:  0.28),
                "pad":   fx(rvb: 65, dly: 20, div: .quarter, pan: -0.18),
                "perc":  fx(rvb: 60, dly: 18, pan: -0.32, pitch:  3),
            ],
            kitId: "toy-piano",
            patternLength: 32,
            basePresetId: "toy-piano-groove", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "hat":   row2(0, 8, 16, 24),
                "pluck": row2(0, 9, 17, 28),
            ]
        ),

        // ── Toy Dream — slow toy piano lullaby, fragile and dreamy ─────────────
        Pattern(
            id: "toy-dream", name: "Toy Dream", tempo: 66, swing: 0.12,
            rows: [
                "kick":  row(0, 11),
                "hat":   row(2, 8, 14),
                "bass":  row(0, 5, 9, 13),
                "pluck": row(0, 3, 7, 11, 14),
                "pad":   row(0, 8),
                "perc":  row(4, 10),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.82, "pad": 0.45, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 70),
                "hat":   fx(rvb: 68, pan:  0.25),
                "bass":  fx(rvb: 58, dly: 15, pitch: -2),
                "pluck": fx(rvb: 75, dly: 28, pan:  0.32),
                "pad":   fx(rvb: 88, dly: 22, div: .quarter, pan: -0.22, pitch: -4),
                "perc":  fx(rvb: 72, dly: 20, pan: -0.38, pitch:  4),
            ],
            kitId: "toy-piano",
            accents: [
                "pluck": row(0, 7, 14),
                "perc":  row(4),
            ]
        ),

        // ── Toy Dream 2-bar — bar 2 melody wanders, perc breathes ────────────
        Pattern(
            id: "toy-dream-2", name: "Toy Dream", tempo: 66, swing: 0.12,
            rows: [
                "kick":  row2(0, 11,                  16, 27),
                "hat":   row2(2, 8, 14,               18, 24, 30),
                "bass":  row2(0, 5, 9, 13,            16, 21, 25, 29),
                "pluck": row2(0, 3, 7, 11, 14,        17, 20, 24, 28, 31),
                "pad":   row2(0, 8,                   16, 24),
                "perc":  row2(4, 10,                  20, 26),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.82, "pad": 0.45, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 70),
                "hat":   fx(rvb: 68, pan:  0.25),
                "bass":  fx(rvb: 58, dly: 15, pitch: -2),
                "pluck": fx(rvb: 75, dly: 28, pan:  0.32),
                "pad":   fx(rvb: 88, dly: 22, div: .quarter, pan: -0.22, pitch: -4),
                "perc":  fx(rvb: 72, dly: 20, pan: -0.38, pitch:  4),
            ],
            kitId: "toy-piano",
            patternLength: 32,
            basePresetId: "toy-dream", barLength: 2,
            accents: [
                "pluck": row2(0, 7, 14, 17, 24, 31),
                "perc":  row2(4, 20),
            ]
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

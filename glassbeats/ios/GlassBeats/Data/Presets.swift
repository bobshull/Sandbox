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
    var grooveSeed: UInt64? = nil
    // Per-step semitone offsets for melodic tracks; nil/missing → all defaults (0)
    var pitches: [String: [Int]]? = nil
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

    /// Per-step semitone offsets at the given step positions; everything else 0.
    private static func pitchRow(_ assignments: [Int: Int], length: Int = Tracks.stepCount) -> [Int] {
        var r = Array(repeating: 0, count: length)
        for (step, semitones) in assignments where r.indices.contains(step) { r[step] = semitones }
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
            kitId: "jungle",
            accents: [
                "kick":  row(0),
                "snare": row(12),
                "bass":  row(0),
            ],
            pitches: [
                "bass":  pitchRow([3: 12, 11: 7]),
                "pluck": pitchRow([10: 7]),
            ]
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
            kitId: "808",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "bass":  row(0),
            ],
            pitches: [
                "bass":  pitchRow([10: 7]),
                "pluck": pitchRow([3: -7]),
            ]
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
            kitId: "rainy-night",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "pluck": row(3),
            ],
            pitches: [
                "bass":  pitchRow([6: 7]),
                "pluck": pitchRow([3: -7, 14: 7]),
            ]
        ),

        // ── Music Box Fantasy — melody-first, not a drum pattern ────────────
        Pattern(
            id: "music-box-fantasy", name: "Music Box Fantasy", tempo: 82, swing: 0.10,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(2, 10),
                "hat":   row(0, 8),
                "bass":  row(0, 3, 6, 9, 12),
                "pluck": row(1, 5, 8, 11),
                "perc":  row(4, 12),
            ],
            volumes: ["kick": 0.62, "snare": 1.00, "hat": 0.50, "clap": 1.00, "bass": 1.00, "pluck": 1.00, "pad": 1.00, "perc": 1.00],
            effects: [
                "kick":  fx(rvb: 62),
                "snare": fx(rvb: 78, dly: 28, div: .eighth),
                "hat":   fx(rvb: 45),
                "bass":  fx(rvb: 68, dly: 35, div: .eighth),
                "pluck": fx(rvb: 82, dly: 50, div: .eighth),
                "perc":  fx(rvb: 72),
            ],
            kitId: "music-box",
            patternLength: 16,
            barLength: 1
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
            kitId: "space",
            accents: [
                "kick": row(0, 8),
                "perc": row(7),
            ],
            pitches: [
                "bass": pitchRow([6: 12]),
            ]
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
            kitId: "arcade",
            accents: [
                "kick":  row(0, 8),
                "snare": row(4, 12),
                "pluck": row(0),
            ],
            pitches: [
                "bass":  pitchRow([3: 12, 11: 12]),
                "pluck": pitchRow([3: 7, 10: -7, 13: 7]),
            ]
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
            kitId: "dusty-tape",
            accents: [
                "kick":  row(0),
                "snare": row(4, 12),
            ],
            pitches: [
                "bass":  pitchRow([8: 7]),
                "pluck": pitchRow([12: -7]),
            ]
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
            kitId: "marimba",
            accents: [
                "kick": row(0),
                "perc": row(3, 11),
            ],
            pitches: [
                "bass":  pitchRow([5: 7, 13: 7]),
                "pluck": pitchRow([4: 7, 13: -7]),
            ]
        ),

        // ── Boom Bap Classic — SP-1200 knock ─────────────────────────────────
        Pattern(
            id: "boom-bap-classic", name: "Boom Bap Classic", tempo: 88, swing: 0.22,
            rows: [
                "kick":  row(0, 4, 8, 12),
                "snare": row(4, 12),
                "hat":   row(2, 6, 10, 14),
                "clap":  row(4, 12),
                "bass":  row(0, 10),
                "pluck": row(4, 12),
                "pad":   row(0, 3, 8, 12),
                "perc":  row(0, 4, 8, 12),
            ],
            volumes: ["kick": 0.95, "snare": 0.90, "hat": 1.00, "clap": 1.00, "bass": 0.80, "pluck": 1.00, "pad": 0.18, "perc": 0.42],
            effects: [
                "kick":  fx(rvb: 15),
                "snare": fx(rvb: 32),
                "pluck": fx(rvb: 28, dly: 20, div: .eighth),
            ],
            kitId: "boom-bap",
            patternLength: 16,
            barLength: 1,
            accents: [
                "kick":  row(0, 8),
                "clap":  row(12),
                "perc":  row(4, 12),
            ],
            pitches: [
                "bass":  pitchRow([10: 7]),
                "pluck": pitchRow([4: 7, 12: -7]),
                "pad":   pitchRow([0: 7, 3: 7, 8: 7, 12: -7]),
            ]
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
            kitId: "jazz",
            accents: [
                "snare": row(4),
                "bass":  row(0),
            ],
            pitches: [
                "bass":  pitchRow([6: 7, 12: 12]),
                "pluck": pitchRow([10: 7]),
            ]
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
            basePresetId: "jungle-chop", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(12, 28),
                "bass":  row2(0, 16),
            ],
            pitches: [
                "bass":  pitchRow([3: 12, 11: 7, 19: 7, 27: 12], length: 32),
                "pluck": pitchRow([10: 7, 26: -7], length: 32),
            ]
        ),

        // ── Boom Bap 2-bar — bar 2 turnaround fill ───────────────────────────
        Pattern(
            id: "boom-bap-2", name: "Boom Bap Classic", tempo: 88, swing: 0.22,
            rows: [
                "kick":  row2(0, 4, 8, 12,    16, 19, 24, 30),
                "snare": row2(4, 12,           20, 28, 31),
                "hat":   row2(2, 6, 10, 14,    17, 18, 22, 25, 26, 30),
                "clap":  row2(4, 12,           20, 28),
                "bass":  row2(0, 10,           16, 23, 27, 30),
                "pluck": row2(4, 12,           18, 24, 29),
                "pad":   row2(0, 3, 8, 12,     16, 21, 24, 30),
                "perc":  row2(0, 4, 8, 12,     18, 23, 27, 31),
            ],
            volumes: ["kick": 0.95, "snare": 0.90, "hat": 1.00, "clap": 1.00, "bass": 0.80, "pluck": 1.00, "pad": 0.18, "perc": 0.42],
            effects: [
                "kick":  fx(rvb: 15),
                "snare": fx(rvb: 32),
                "pluck": fx(rvb: 28, dly: 20, div: .eighth),
            ],
            kitId: "boom-bap",
            patternLength: 32,
            bar2Volumes: ["kick": 0.95, "snare": 0.90, "hat": 1.00, "clap": 1.00, "bass": 0.80, "pluck": 1.00, "pad": 0.18, "perc": 0.42],
            basePresetId: "boom-bap-classic", barLength: 2,
            accents: [
                "kick":  row2(0, 8, 16, 24),
                "snare": row2(20, 28, 31),
                "clap":  row2(12),
                "perc":  row2(4, 12, 23, 31),
            ],
            pitches: [
                "bass":  pitchRow([10: 7, 23: 7, 27: 7, 30: 12], length: 32),
                "pluck": pitchRow([4: 7, 12: -7, 18: 7, 24: 7, 29: -7], length: 32),
                "pad":   pitchRow([0: 7, 3: 7, 8: 7, 12: -7, 16: 7, 21: 7, 24: 7, 30: -7], length: 32),
            ]
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
            basePresetId: "808-memphis", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(4, 20),
                "bass":  row2(0, 16),
            ],
            pitches: [
                "bass":  pitchRow([10: 7, 30: 7], length: 32),
                "pluck": pitchRow([3: -7, 23: 7], length: 32),
            ]
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
            basePresetId: "rainy-lofi", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(4, 20),
                "pluck": row2(3, 21),
            ],
            pitches: [
                "bass":  pitchRow([6: 7, 24: 7], length: 32),
                "pluck": pitchRow([3: -7, 14: 7, 27: 7, 30: -7], length: 32),
            ]
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
            basePresetId: "dusty-breaks", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "snare": row2(4, 12, 20, 28),
            ],
            pitches: [
                "bass":  pitchRow([8: 7, 24: 7], length: 32),
                "pluck": pitchRow([12: -7, 28: -7], length: 32),
            ]
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
            basePresetId: "jazz-brush", barLength: 2,
            accents: [
                "snare": row2(4, 22),
                "bass":  row2(0, 16),
            ],
            pitches: [
                "bass":  pitchRow([6: 7, 12: 12, 22: 7, 28: 12], length: 32),
                "pluck": pitchRow([10: 7, 24: 7, 30: -7], length: 32),
            ]
        ),

        // ── Music Box Fantasy 2-bar — bar 2 harmonic shift ───────────────────
        Pattern(
            id: "music-box-2", name: "Music Box Fantasy", tempo: 82, swing: 0.10,
            rows: [
                "kick":  row2(0, 4, 8, 12,      16, 20, 24, 28),
                "snare": row2(2, 10,             18, 26),
                "hat":   row2(0, 8,              17, 25),
                "bass":  row2(0, 3, 6, 9, 12,   17, 21, 25, 29),
                "pluck": row2(1, 5, 8, 11,      16, 19, 23, 26, 30),
                "perc":  row2(4, 12,             20, 28),
            ],
            volumes: ["kick": 0.62, "snare": 1.00, "hat": 0.50, "clap": 1.00, "bass": 1.00, "pluck": 1.00, "pad": 1.00, "perc": 1.00],
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
            bar2Volumes: ["kick": 0.62, "snare": 1.00, "hat": 0.50, "clap": 1.00, "bass": 1.00, "pluck": 1.00, "pad": 1.00, "perc": 1.00],
            basePresetId: "music-box-fantasy", barLength: 2,
            accents: [
                "bass":  row2(17),
                "pluck": row2(16, 26),
            ],
            pitches: [
                "bass":  pitchRow([21: 7, 29: 12], length: 32),
                "pluck": pitchRow([19: 7, 26: -7, 30: 7], length: 32),
            ]
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
            basePresetId: "space-drift", barLength: 2,
            accents: [
                "kick": row2(0, 8, 16, 24),
                "perc": row2(7, 19),
            ],
            pitches: [
                "bass": pitchRow([6: 12, 22: 12, 30: 7], length: 32),
            ]
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
            basePresetId: "arcade-rush", barLength: 2,
            accents: [
                "kick":  row2(0, 8, 16, 24),
                "snare": row2(4, 12, 20, 28),
                "pluck": row2(0, 16),
            ],
            pitches: [
                "bass":  pitchRow([3: 12, 11: 12, 20: 12, 30: 12], length: 32),
                "pluck": pitchRow([3: 7, 10: -7, 13: 7, 19: 7, 27: -7, 30: 7], length: 32),
            ]
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
            basePresetId: "marimba-groove", barLength: 2,
            accents: [
                "kick": row2(0, 16),
                "perc": row2(3, 11, 18, 26),
            ],
            pitches: [
                "bass":  pitchRow([5: 7, 13: 7, 23: 7, 29: 7], length: 32),
                "pluck": pitchRow([4: 7, 13: -7, 22: -7, 29: 7], length: 32),
            ]
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
            ],
            pitches: [
                "bass":  pitchRow([11: 7]),
                "pluck": pitchRow([9: -7, 15: 7]),
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
            ],
            pitches: [
                "bass":  pitchRow([11: 7, 27: 7], length: 32),
                "pluck": pitchRow([9: -7, 15: 7, 25: -7, 31: 7], length: 32),
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
                "perc":  row(5, 13),
            ],
            volumes: ["kick": 0.90, "snare": 0.85, "hat": 0.60, "clap": 0.70, "bass": 0.85, "pluck": 0.68, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 20, dst: 22),
                "snare": fx(rvb: 40, pan:  0.10),
                "hat":   fx(dst: 30, pan: -0.15),
                "clap":  fx(rvb: 38, pan:  0.20),
                "bass":  fx(dst: 18),
                "pluck": fx(rvb: 28, dly: 20, div: .sixteenth, pan:  0.35),
                "perc":  fx(rvb: 22, pan: -0.25),
            ],
            kitId: "dusty-tape",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "hat":   row(4, 12),
                "pluck": row(1, 11),
            ],
            pitches: [
                "bass":  pitchRow([6: 7]),
                "pluck": pitchRow([7: -7, 15: 7]),
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
                "perc":  row2(5, 13,                 21, 29),
            ],
            volumes: ["kick": 0.90, "snare": 0.85, "hat": 0.60, "clap": 0.70, "bass": 0.85, "pluck": 0.68, "perc": 0.55],
            effects: [
                "kick":  fx(rvb: 20, dst: 22),
                "snare": fx(rvb: 40, pan:  0.10),
                "hat":   fx(dst: 30, pan: -0.15),
                "clap":  fx(rvb: 38, pan:  0.20),
                "bass":  fx(dst: 18),
                "pluck": fx(rvb: 28, dly: 20, div: .sixteenth, pan:  0.35),
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
            ],
            pitches: [
                "bass":  pitchRow([6: 7, 22: 7], length: 32),
                "pluck": pitchRow([7: -7, 15: 7, 23: -7, 31: 7], length: 32),
            ]
        ),

        // ── Coffee Shop — lazy lo-fi, kick on 1+and-of-3, pluck drags on upbeats
        Pattern(
            id: "coffee-shop", name: "Coffee Shop", tempo: 80, swing: 0.38,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4, 12),
                "hat":   row(0, 2, 4, 6, 8, 10, 12, 14),
                "bass":  row(0, 5, 9),
                "pluck": row(2, 7, 11),
            ],
            volumes: ["kick": 0.72, "snare": 0.60, "hat": 0.48, "bass": 0.80, "pluck": 0.72],
            effects: [
                "kick":  fx(rvb: 55, dst: 12),
                "snare": fx(rvb: 65, pan:  0.08),
                "hat":   fx(rvb: 60, dst:  8, pan: -0.12),
                "bass":  fx(rvb: 50, dst: 10),
                "pluck": fx(rvb: 72, dly: 30, pan:  0.25),
            ],
            kitId: "rainy-night",
            accents: [
                "kick":  row(0),
                "hat":   row(0, 8),
                "pluck": row(2),
            ],
            pitches: [
                "bass":  pitchRow([5: 7]),
                "pluck": pitchRow([7: -7, 11: 7]),
            ]
        ),

        // ── Coffee Shop 2-bar — bar 2 bass adds a passing note, kick holds ─────
        Pattern(
            id: "coffee-shop-2", name: "Coffee Shop", tempo: 80, swing: 0.38,
            rows: [
                "kick":  row2(0, 10,                  16, 26),
                "snare": row2(4, 12,                  20, 28),
                "hat":   row2(0,2,4,6,8,10,12,14,     16,18,20,22,24,26,28,30),
                "bass":  row2(0, 5, 9,                16, 21, 25, 28),
                "pluck": row2(2, 7, 11,               18, 23, 27),
            ],
            volumes: ["kick": 0.72, "snare": 0.60, "hat": 0.48, "bass": 0.80, "pluck": 0.72],
            effects: [
                "kick":  fx(rvb: 55, dst: 12),
                "snare": fx(rvb: 65, pan:  0.08),
                "hat":   fx(rvb: 60, dst:  8, pan: -0.12),
                "bass":  fx(rvb: 50, dst: 10),
                "pluck": fx(rvb: 72, dly: 30, pan:  0.25),
            ],
            kitId: "rainy-night",
            patternLength: 32,
            basePresetId: "coffee-shop", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "hat":   row2(0, 8, 16, 24),
                "pluck": row2(2, 18),
            ],
            pitches: [
                "bass":  pitchRow([5: 7, 25: 7], length: 32),
                "pluck": pitchRow([7: -7, 11: 7, 23: -7, 27: 7], length: 32),
            ]
        ),

        // ── Bedroom Sessions — on-beat hat ticks straight while bass drags ────────
        Pattern(
            id: "bedroom-sessions", name: "Bedroom Sessions", tempo: 73, swing: 0.42,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4, 13),
                "hat":   row(0, 4, 8, 12),
                "bass":  row(0, 6, 10),
                "pluck": row(3, 9, 15),
            ],
            volumes: ["kick": 0.82, "snare": 0.60, "hat": 0.44, "bass": 0.84, "pluck": 0.72],
            effects: [
                "kick":  fx(rvb: 58, dst: 20),
                "snare": fx(rvb: 70, pan:  0.08),
                "hat":   fx(rvb: 58, dst: 10, pan: -0.18),
                "bass":  fx(rvb: 50, dst: 15),
                "pluck": fx(rvb: 78, dly: 40, pan:  0.30),
            ],
            kitId: "dusty-tape",
            accents: [
                "kick":  row(0),
                "snare": row(4),
                "pluck": row(3),
            ],
            pitches: [
                "bass":  pitchRow([6: 7]),
                "pluck": pitchRow([9: 7, 15: -7]),
            ]
        ),

        // ── Rainy Window — music-box lullaby rhythm, sparse and tinkling ──────
        Pattern(
            id: "rainy-window", name: "Rainy Window", tempo: 76, swing: 0.35,
            rows: [
                "kick":  row(0, 9),
                "snare": row(4, 12),
                "hat":   row(2, 7, 13),
                "bass":  row(0, 4, 9, 14),
                "pluck": row(1, 6, 10, 14),
                "perc":  row(3, 8, 13),
            ],
            volumes: ["kick": 0.52, "snare": 0.45, "hat": 0.36, "bass": 0.68, "pluck": 0.82, "perc": 0.62],
            effects: [
                "kick":  fx(rvb: 72),
                "snare": fx(rvb: 76, pan:  0.12),
                "hat":   fx(rvb: 65, pan: -0.10),
                "bass":  fx(rvb: 68, dly: 24, pan: -0.08),
                "pluck": fx(rvb: 85, dly: 42, pan:  0.32),
                "perc":  fx(rvb: 78, dly: 28, pan: -0.38),
            ],
            kitId: "music-box",
            accents: [
                "pluck": row(1, 10),
                "perc":  row(3, 8),
            ],
            pitches: [
                "bass":  pitchRow([9: 7]),
                "pluck": pitchRow([6: 7, 14: -7]),
            ]
        ),

        // ── Rainy Window 2-bar — bar 2 shifts melody slightly ────────────────
        Pattern(
            id: "rainy-window-2", name: "Rainy Window", tempo: 76, swing: 0.35,
            rows: [
                "kick":  row2(0, 9,                   16, 25),
                "snare": row2(4, 12,                  20, 28),
                "hat":   row2(2, 7, 13,               18, 23, 29),
                "bass":  row2(0, 4, 9, 14,            16, 20, 25, 30),
                "pluck": row2(1, 6, 10, 14,           17, 22, 26, 31),
                "perc":  row2(3, 8, 13,               19, 24, 29),
            ],
            volumes: ["kick": 0.52, "snare": 0.45, "hat": 0.36, "bass": 0.68, "pluck": 0.82, "perc": 0.62],
            effects: [
                "kick":  fx(rvb: 72),
                "snare": fx(rvb: 76, pan:  0.12),
                "hat":   fx(rvb: 65, pan: -0.10),
                "bass":  fx(rvb: 68, dly: 24, pan: -0.08),
                "pluck": fx(rvb: 85, dly: 42, pan:  0.32),
                "perc":  fx(rvb: 78, dly: 28, pan: -0.38),
            ],
            kitId: "music-box",
            patternLength: 32,
            basePresetId: "rainy-window", barLength: 2,
            accents: [
                "pluck": row2(1, 10, 17, 26),
                "perc":  row2(3, 8, 19, 24),
            ],
            pitches: [
                "bass":  pitchRow([9: 7, 25: 7], length: 32),
                "pluck": pitchRow([6: 7, 14: -7, 22: 7, 31: -7], length: 32),
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
                "perc":  row(1, 5, 9, 13),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.72, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 75),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 72, dly: 18, pan: -0.10, pitch: -5),
                "pluck": fx(rvb: 85, dly: 45, pan:  0.40),
                "perc":  fx(rvb: 78, dly: 30, pan: -0.45, pitch:  5),
            ],
            kitId: "glass",
            accents: [
                "pluck": row(0, 7),
                "perc":  row(1, 9),
            ],
            pitches: [
                "bass":  pitchRow([9: 7]),
                "pluck": pitchRow([3: 7, 12: -7]),
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
                "perc":  row2(1, 5, 9, 13,           17, 21, 25, 29),
            ],
            volumes: ["kick": 0.50, "hat": 0.38, "bass": 0.65, "pluck": 0.72, "perc": 0.60],
            effects: [
                "kick":  fx(rvb: 75),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 72, dly: 18, pan: -0.10, pitch: -5),
                "pluck": fx(rvb: 85, dly: 45, pan:  0.40),
                "perc":  fx(rvb: 78, dly: 30, pan: -0.45, pitch:  5),
            ],
            kitId: "glass",
            patternLength: 32,
            basePresetId: "glass-garden", barLength: 2,
            accents: [
                "pluck": row2(0, 7, 17, 27),
                "perc":  row2(1, 9, 17, 25),
            ],
            pitches: [
                "bass":  pitchRow([9: 7, 25: 7], length: 32),
                "pluck": pitchRow([3: 7, 12: -7, 23: 7, 31: -7], length: 32),
            ]
        ),

        // ── Drifting Smoke — ultra-sparse space drone, max space between hits ─
        Pattern(
            id: "drifting-smoke", name: "Drifting Smoke", tempo: 65, swing: 0.05,
            rows: [
                "kick":  row(0, 10),
                "snare": row(4),
                "hat":   row(7, 15),
                "bass":  row(0, 6, 13),
                "pluck": row(3, 8),
                "perc":  row(5, 12),
            ],
            volumes: ["kick": 0.68, "snare": 0.50, "hat": 0.36, "bass": 0.75, "pluck": 0.60, "perc": 0.52],
            effects: [
                "kick":  fx(rvb: 68, dst: 18),
                "snare": fx(rvb: 85, pan:  0.12),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 62, dly: 28, div: .quarter, pitch: -7),
                "pluck": fx(rvb: 92, dly: 58, pan:  0.40, pitch:  3),
                "perc":  fx(rvb: 88, dst: 15, pan: -0.42),
            ],
            kitId: "space",
            accents: [
                "kick":  row(0),
                "pluck": row(3),
            ],
            pitches: [
                "bass":  pitchRow([13: 7]),
                "pluck": pitchRow([8: -7]),
            ]
        ),

        // ── Drifting Smoke 2-bar — bar 2 shifts for variation ────────────────
        Pattern(
            id: "drifting-smoke-2", name: "Drifting Smoke", tempo: 65, swing: 0.05,
            rows: [
                "kick":  row2(0, 10,           17, 26),
                "snare": row2(4,               22),
                "hat":   row2(7, 15,           23, 30),
                "bass":  row2(0, 6, 13,        16, 24, 29),
                "pluck": row2(3, 8,            19, 28),
                "perc":  row2(5, 12,           20, 31),
            ],
            volumes: ["kick": 0.68, "snare": 0.50, "hat": 0.36, "bass": 0.75, "pluck": 0.60, "perc": 0.52],
            effects: [
                "kick":  fx(rvb: 68, dst: 18),
                "snare": fx(rvb: 85, pan:  0.12),
                "hat":   fx(rvb: 82, pan:  0.35),
                "bass":  fx(rvb: 62, dly: 28, div: .quarter, pitch: -7),
                "pluck": fx(rvb: 92, dly: 58, pan:  0.40, pitch:  3),
                "perc":  fx(rvb: 88, dst: 15, pan: -0.42),
            ],
            kitId: "space",
            patternLength: 32,
            basePresetId: "drifting-smoke", barLength: 2,
            accents: [
                "kick":  row2(0, 17),
                "pluck": row2(3, 19),
            ],
            pitches: [
                "bass":  pitchRow([13: 7, 29: 7], length: 32),
                "pluck": pitchRow([8: -7, 28: -7], length: 32),
            ]
        ),

        // ── Wind Through Chimes — sparse gusts, irregular, nothing repeats evenly
        Pattern(
            id: "wind-through-chimes", name: "Wind Through Chimes", tempo: 90, swing: 0.12,
            rows: [
                "hat":   row(1, 4, 11),
                "bass":  row(0, 8, 13),
                "pluck": row(0, 3, 7, 12),
                "perc":  row(5, 9, 15),
            ],
            volumes: ["hat": 0.38, "bass": 0.58, "pluck": 0.78, "perc": 0.65],
            effects: [
                "hat":   fx(rvb: 88, pan:  0.30),
                "bass":  fx(rvb: 75, dly: 20, pan: -0.10, pitch: -3),
                "pluck": fx(rvb: 92, dly: 45, pan:  0.42, pitch:  2),
                "perc":  fx(rvb: 90, dly: 32, pan: -0.48, pitch:  5),
            ],
            kitId: "wind-chimes",
            accents: [
                "pluck": row(0, 7),
                "perc":  row(5),
            ],
            pitches: [
                "bass":  pitchRow([13: 7]),
                "pluck": pitchRow([3: 7, 12: -7]),
            ]
        ),

        // ── Wind Through Chimes 2-bar — bar 2 gust comes from different angle ──
        Pattern(
            id: "wind-through-chimes-2", name: "Wind Through Chimes", tempo: 90, swing: 0.12,
            rows: [
                "hat":   row2(1, 4, 11,               17, 22, 28),
                "bass":  row2(0, 8, 13,               16, 24, 29),
                "pluck": row2(0, 3, 7, 12,            18, 21, 25, 30),
                "perc":  row2(5, 9, 15,               20, 26, 31),
            ],
            volumes: ["hat": 0.38, "bass": 0.58, "pluck": 0.78, "perc": 0.65],
            effects: [
                "hat":   fx(rvb: 88, pan:  0.30),
                "bass":  fx(rvb: 75, dly: 20, pan: -0.10, pitch: -3),
                "pluck": fx(rvb: 92, dly: 45, pan:  0.42, pitch:  2),
                "perc":  fx(rvb: 90, dly: 32, pan: -0.48, pitch:  5),
            ],
            kitId: "wind-chimes",
            patternLength: 32,
            basePresetId: "wind-through-chimes", barLength: 2,
            accents: [
                "pluck": row2(0, 7, 18, 25),
                "perc":  row2(5, 20),
            ],
            pitches: [
                "bass":  pitchRow([13: 7, 29: 7], length: 32),
                "pluck": pitchRow([3: 7, 12: -7, 21: 7, 30: -7], length: 32),
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
                "perc":  row(3, 7, 11, 15),
            ],
            volumes: ["kick": 0.78, "snare": 0.72, "hat": 0.55, "bass": 0.75, "pluck": 0.82, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 45, dst:  8),
                "snare": fx(rvb: 40, pan:  0.12),
                "hat":   fx(rvb: 35, pan: -0.15),
                "bass":  fx(rvb: 38, dly: 10),
                "pluck": fx(rvb: 52, dly: 22, pan:  0.28),
                "perc":  fx(rvb: 60, dly: 18, pan: -0.32, pitch:  3),
            ],
            kitId: "toy-piano",
            accents: [
                "kick":  row(0),
                "hat":   row(0, 8),
                "pluck": row(0, 9),
            ],
            pitches: [
                "bass":  pitchRow([7: 7]),
                "pluck": pitchRow([2: 7, 9: -7]),
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
                "perc":  row2(3, 7, 11, 15,                19, 23, 27, 31),
            ],
            volumes: ["kick": 0.78, "snare": 0.72, "hat": 0.55, "bass": 0.75, "pluck": 0.82, "perc": 0.65],
            effects: [
                "kick":  fx(rvb: 45, dst:  8),
                "snare": fx(rvb: 40, pan:  0.12),
                "hat":   fx(rvb: 35, pan: -0.15),
                "bass":  fx(rvb: 38, dly: 10),
                "pluck": fx(rvb: 52, dly: 22, pan:  0.28),
                "perc":  fx(rvb: 60, dly: 18, pan: -0.32, pitch:  3),
            ],
            kitId: "toy-piano",
            patternLength: 32,
            basePresetId: "toy-piano-groove", barLength: 2,
            accents: [
                "kick":  row2(0, 16),
                "hat":   row2(0, 8, 16, 24),
                "pluck": row2(0, 9, 17, 28),
            ],
            pitches: [
                "bass":  pitchRow([7: 7, 23: 7], length: 32),
                "pluck": pitchRow([2: 7, 9: -7, 21: 7, 28: -7], length: 32),
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

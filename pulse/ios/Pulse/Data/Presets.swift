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
        // 85 BPM + 0.22 swing = laid-back shuffle. The 0.8s kick sweep fills
        // the half-bar naturally; no need to stack hits. Single clap on beat 2.
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
        // Rainy Night kit is muffled (kick 150Hz, hat 4kHz, bass 100Hz).
        // Heavy swing + off-beat kicks gives the drowsy lo-fi head-nod.
        // Bass line hits 0,6,10 for drive. Pluck sparse for melodic color.
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
        // Every voice is a pitched tine: bass=G4, pluck=C6 (w/ real 2.756× overtone),
        // snare=E6, pad=E5. Together G4+E5+C6+E6 = C major voicing across 4 octaves.
        // Hat = 2 mechanism ticks per bar only. Let the melody carry it.
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
        // Reverb only — delays were creating ghost-note chaos. The space kit's
        // long decays (kick 0.55s, bass 0.7s) fill the space on their own.
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
        // Pluck sweeps 880→440 Hz on each hit — the irregular pattern (0,3,6,10,13)
        // makes it feel like a melodic hook, not just noise. Hats stay on 8th notes
        // so the other voices have room to breathe.
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

        // ── Glass Ritual — sub rumble and noise, no bells ────────────────────
        // Snare = C6 pure sine, pluck = E6 pure sine. Either one with high reverb
        // = doorbell. Dropped both. Build from kick (low sine ping), hat (noise),
        // bass (65Hz sub), perc — the voices that don't sound like a front door.
        Pattern(
            id: "glass-ritual", name: "Glass Ritual", tempo: 76, swing: 0.12,
            rows: [
                "kick":  row(0, 9, 13),
                "hat":   row(3, 11),
                "bass":  row(0, 7, 12),
                "perc":  row(2, 10),
            ],
            volumes: ["kick": 0.60, "hat": 0.50, "bass": 0.72, "perc": 0.62],
            effects: [
                "kick":  fx(rvb: 88),
                "hat":   fx(rvb: 72),
                "bass":  fx(rvb: 85),
                "perc":  fx(rvb: 80),
            ],
            kitId: "glass"
        ),

        // ── Dusty Breaks — vintage amen-break energy ─────────────────────────
        // Snare stutters on 4, a-of-3 (11), downbeat 3 (12), and-of-4 (14).
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
        // Kick and bass on clave-influenced positions (0,3,8,11 vs 0,2,5,8,10,13).
        // Perc on every 4th offbeat (3,7,11,15) locks the cross-rhythm.
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

        // ── Wind Garden — one chime, one pluck, breathe ──────────────────────
        // Wind-chimes hat: 4 partials, 0.3s decay. At 78 BPM a step is 0.19s —
        // even 2 hits overlap. One hat hit, one pluck hit, no perc. The kick and
        // bass carry the rhythm; the chime is a single accent, not a texture.
        Pattern(
            id: "wind-garden", name: "Wind Garden", tempo: 78, swing: 0.20,
            rows: [
                "kick":  row(0, 8),
                "snare": row(4, 12),
                "hat":   row(3),
                "bass":  row(0, 5, 10),
                "pluck": row(9),
            ],
            volumes: ["kick": 0.60, "snare": 0.62, "hat": 0.62, "pluck": 0.68],
            effects: [
                "kick":  fx(rvb: 62),
                "snare": fx(rvb: 70),
                "hat":   fx(rvb: 85),
                "bass":  fx(rvb: 58, dly: 20, div: .eighth),
                "pluck": fx(rvb: 90, dly: 35, div: .eighth),
            ],
            kitId: "wind-chimes"
        ),

        // ── Boom Bap Classic — SP-1200 knock ─────────────────────────────────
        // Kick on and-of-2 (6) and and-of-3 (10) is the genre's defining knock.
        // Single clap on beat 2 for the NY accent.
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
        // Hat on all 8th notes + 0.30 swing = triplet shuffle = jazz ride feel.
        // Bass on quarter notes (0,4,8,12) + one passing note (6) = walking bass.
        // Kick comps (0,3,10), single clap on beat 2, pluck chords on the "ands".
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

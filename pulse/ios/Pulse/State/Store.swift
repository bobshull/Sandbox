import Foundation
import Combine

enum StateSection {
    case tempo, swing, master, pattern, mutes, volumes, step, name, load, kit, undo, effects, patternLength, accent
}

final class Store {
    // Settings
    private(set) var tempo: Double = AppSettings.defaultTempo
    private(set) var swing: Double = 0.18
    private(set) var masterGain: Float = 0.85

    // Pattern + per-track state
    private(set) var rows: [String: [Bool]] = Presets.emptyRows()
    private(set) var mutes: [String: Bool] = [:]
    // Per-bar volumes and effects (index 0 = Bar 1, index 1 = Bar 2)
    private(set) var barVolumes: [[String: Float]] = [[:], [:]]
    private(set) var barEffects: [[String: TrackEffects]] = [[:], [:]]
    private(set) var accents: [String: [Bool]] = [:]

    var volumes: [String: Float] { barVolumes[0] }
    var effects: [String: TrackEffects] { barEffects[0] }
    func volumes(for bar: Int) -> [String: Float] { bar == 1 ? barVolumes[1] : barVolumes[0] }
    func effects(for bar: Int) -> [String: TrackEffects] { bar == 1 ? barEffects[1] : barEffects[0] }
    private func isValidBar(_ bar: Int) -> Bool { barVolumes.indices.contains(bar) && barEffects.indices.contains(bar) }
    private func normalizedFlags(_ source: [Bool]?, length: Int) -> [Bool] {
        var out = Array((source ?? []).prefix(length))
        if out.count < length {
            out += Array(repeating: false, count: length - out.count)
        }
        return out
    }

    // Transport
    private(set) var activeStep: Int = -1
    private(set) var patternName: String = "Untitled"
    private(set) var currentKitId: String = "studio"
    private(set) var currentPatternId: String = ""

    // Pattern length (16 or 32 steps)
    private(set) var patternLength: Int = 16

    // Which bars are active in the playback loop (index 0 = Bar 1, 1 = Bar 2).
    // Only meaningful in 32-step mode; always [true] in 16-step mode.
    private(set) var enabledBars: [Bool] = [true]

    // Derived: first step and length of the currently active sequence.
    var sequenceStart: Int {
        guard patternLength == 32 else { return 0 }
        return (enabledBars.first == true) ? 0 : 16
    }
    var sequenceLength: Int {
        guard patternLength == 32 else { return 16 }
        let count = enabledBars.filter { $0 }.count
        return max(count, 1) * 16   // at least one bar always plays
    }

    var hasBar2Content: Bool {
        rows.values.contains { arr in
            arr.count == 32 && arr[16...].contains(true)
        }
    }

    // True when 32-step rows are in memory (Bar 2 preserved from a previous 2-bar session).
    var hasPreservedBar2: Bool {
        rows.values.contains { $0.count == 32 }
    }

    var isCurrentPatternPreset: Bool {
        Presets.all.contains(where: { $0.id == currentPatternId })
    }
    var isCurrentPatternUserSaved: Bool {
        !currentPatternId.isEmpty && !isCurrentPatternPreset
    }

    // Undo / dirty
    private(set) var isDirty = false
    private var undoStack: [SessionState] = []
    var canUndo: Bool { !undoStack.isEmpty }

    let changes = PassthroughSubject<StateSection, Never>()

    struct AudioSnapshot {
        let tempo: Double
        let swing: Double
        let masterGain: Float
        let rows: [String: [Bool]]
        let mutes: [String: Bool]
        let barVolumes: [[String: Float]]
        let barEffects: [[String: TrackEffects]]
        let patternLength: Int
        let sequenceStart: Int
        let sequenceLength: Int
        let accents: [String: [Bool]]
    }
    private let snapshotLock = NSLock()
    private var snapshot = AudioSnapshot(tempo: AppSettings.defaultTempo, swing: 0.18, masterGain: 0.85,
                                         rows: [:], mutes: [:], barVolumes: [[:], [:]],
                                         barEffects: [[:], [:]], patternLength: 16,
                                         sequenceStart: 0, sequenceLength: 16, accents: [:])

    func audioSnapshot() -> AudioSnapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return snapshot
    }

    private func refreshSnapshot() {
        snapshotLock.lock()
        snapshot = AudioSnapshot(tempo: tempo, swing: swing, masterGain: masterGain,
                                 rows: rows, mutes: mutes,
                                 barVolumes: barVolumes, barEffects: barEffects,
                                 patternLength: patternLength,
                                 sequenceStart: sequenceStart, sequenceLength: sequenceLength,
                                 accents: accents)
        snapshotLock.unlock()
    }

    init() {
        for t in Tracks.all {
            mutes[t.id] = false
            barVolumes[0][t.id] = 1.0
            barVolumes[1][t.id] = 1.0
            barEffects[0][t.id] = .default
            barEffects[1][t.id] = .default
            accents[t.id] = Array(repeating: false, count: 16)
        }
        refreshSnapshot()
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(sessionState())
        if undoStack.count > 50 { undoStack.removeFirst() }
        changes.send(.undo)
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        patternName = snap.patternName
        tempo = snap.tempo
        swing = snap.swing
        masterGain = snap.masterGain
        let prevLength = snap.patternLength ?? 16
        let prevBars = snap.enabledBars ?? (prevLength == 32 ? [true, true] : [true])
        if prevLength != patternLength || prevBars != enabledBars {
            patternLength = prevLength
            enabledBars = prevBars
            changes.send(.patternLength)
        }
        rows = Presets.filledRows(from: snap.rows, length: patternLength)
        for t in Tracks.all {
            barVolumes[0][t.id] = snap.volumes[t.id] ?? 1.0
            barVolumes[1][t.id] = snap.bar2Volumes?[t.id] ?? 1.0
            mutes[t.id] = snap.mutes[t.id] ?? false
            barEffects[0][t.id] = snap.effects?[t.id] ?? .default
            barEffects[1][t.id] = snap.bar2Effects?[t.id] ?? .default
            accents[t.id] = normalizedFlags(snap.accents?[t.id], length: patternLength)
        }
        currentKitId = snap.kitId ?? "studio"
        refreshSnapshot()
        isDirty = true
        changes.send(.load)
        changes.send(.undo)
    }

    func markClean() {
        isDirty = false
    }

    // MARK: - Mutations

    func setTempo(_ value: Double) {
        tempo = min(max(value, 40), 220)
        refreshSnapshot()
        isDirty = true
        changes.send(.tempo)
    }

    func setSwing(_ value: Double) {
        swing = min(max(value, 0), 0.6)
        refreshSnapshot()
        isDirty = true
        changes.send(.swing)
    }

    func setMasterGain(_ value: Float) {
        masterGain = min(max(value, 0), 1)
        refreshSnapshot()
        isDirty = true
        changes.send(.master)
    }

    func toggleStep(trackId: String, step: Int) {
        guard var arr = rows[trackId], (0..<arr.count).contains(step) else { return }
        pushUndo()
        arr[step].toggle()
        rows[trackId] = arr
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
    }

    func toggleMute(trackId: String) {
        pushUndo()
        mutes[trackId, default: false].toggle()
        refreshSnapshot()
        isDirty = true
        changes.send(.mutes)
    }

    func setVolume(trackId: String, value: Float, bar: Int = 0) {
        guard isValidBar(bar) else { return }
        barVolumes[bar][trackId] = min(max(value, 0), 1)
        refreshSnapshot()
        isDirty = true
        changes.send(.volumes)
    }

    func setTrackEffects(trackId: String, _ fx: TrackEffects, bar: Int = 0) {
        guard isValidBar(bar) else { return }
        barEffects[bar][trackId] = fx
        refreshSnapshot()
        isDirty = true
        changes.send(.effects)
    }

    func setActiveStep(_ step: Int) {
        activeStep = step
        changes.send(.step)
    }

    func setPatternName(_ name: String) {
        patternName = name
        changes.send(.name)
    }

    func setCurrentPatternId(_ id: String) {
        currentPatternId = id
    }

    func setKit(_ id: String) {
        pushUndo()
        currentKitId = id
        isDirty = true
        changes.send(.kit)
    }

    func setPatternLength(_ length: Int) {
        guard length == 16 || length == 32, length != patternLength else { return }
        pushUndo()
        patternLength = length
        if length == 32 {
            enabledBars = [true, true]
            for t in Tracks.all {
                let current = rows[t.id] ?? Array(repeating: false, count: 16)
                if current.count < 32 {
                    rows[t.id] = Array(current.prefix(16)) + Array(repeating: false, count: 16)
                }
                let curAccents = accents[t.id] ?? Array(repeating: false, count: 16)
                if curAccents.count < 32 {
                    accents[t.id] = Array(curAccents.prefix(16)) + Array(repeating: false, count: 16)
                }
            }
        } else {
            enabledBars = [true]
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.patternLength)
        changes.send(.pattern)
    }

    func expandToTwoBarsDuplicate() {
        guard patternLength == 16 else { return }
        pushUndo()
        patternLength = 32
        enabledBars = [true, true]
        for t in Tracks.all {
            let bar1 = Array((rows[t.id] ?? Array(repeating: false, count: 16)).prefix(16))
            rows[t.id] = bar1 + bar1
            barVolumes[1][t.id] = barVolumes[0][t.id]
            barEffects[1][t.id] = barEffects[0][t.id]
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.patternLength)
        changes.send(.pattern)
        changes.send(.volumes)
        changes.send(.effects)
    }

    func toggleBar(_ index: Int) {
        guard patternLength == 32, enabledBars.indices.contains(index) else { return }
        // Don't allow disabling the only remaining active bar
        let wouldDisable = enabledBars[index]
        if wouldDisable && enabledBars.filter({ $0 }).count == 1 { return }
        enabledBars[index].toggle()
        refreshSnapshot()
        isDirty = true
        changes.send(.patternLength)   // reuses existing section; SequencerView listens to it
    }

    func duplicateBar1() {
        guard patternLength == 32 else { return }
        pushUndo()
        for t in Tracks.all {
            guard var arr = rows[t.id], arr.count == 32 else { continue }
            let bar1 = Array(arr.prefix(16))
            arr.replaceSubrange(16..., with: bar1)
            rows[t.id] = arr
            barVolumes[1][t.id] = barVolumes[0][t.id]
            barEffects[1][t.id] = barEffects[0][t.id]
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.volumes)
        changes.send(.effects)
    }

    func clearPattern() {
        pushUndo()
        rows = Presets.emptyRows(length: patternLength)
        for t in Tracks.all { accents[t.id] = Array(repeating: false, count: patternLength) }
        currentPatternId = ""
        patternName = "Untitled"
        refreshSnapshot()
        isDirty = false
        changes.send(.pattern)
        changes.send(.accent)
        changes.send(.name)
    }

    func loadPattern(_ pattern: Pattern) {
        undoStack.removeAll()
        patternName = pattern.name
        currentPatternId = pattern.id
        tempo = pattern.id == "empty" ? AppSettings.defaultTempo : pattern.tempo
        swing = pattern.swing
        patternLength = pattern.patternLength ?? 16
        enabledBars = patternLength == 32 ? [true, true] : [true]
        rows = Presets.filledRows(from: pattern.rows, length: patternLength)
        for t in Tracks.all {
            barVolumes[0][t.id] = pattern.volumes?[t.id] ?? 1.0
            barVolumes[1][t.id] = pattern.bar2Volumes?[t.id] ?? 1.0
            mutes[t.id] = pattern.mutes?[t.id] ?? false
            barEffects[0][t.id] = pattern.effects?[t.id] ?? .default
            barEffects[1][t.id] = pattern.bar2Effects?[t.id] ?? .default
        }
        currentKitId = pattern.kitId ?? "studio"
        for t in Tracks.all {
            accents[t.id] = normalizedFlags(pattern.accents?[t.id], length: patternLength)
        }
        refreshSnapshot()
        isDirty = false
        changes.send(.kit)
        changes.send(.undo)
        changes.send(.patternLength)
        changes.send(.load)
    }

    func exportPattern() -> Pattern {
        let exportRows = patternLength == 16
            ? rows.mapValues { Array($0.prefix(16)) }
            : rows
        let exportAccents = patternLength == 16
            ? accents.mapValues { Array($0.prefix(16)) }
            : accents
        return Pattern(id: UUID().uuidString, name: patternName, tempo: tempo, swing: swing,
                rows: exportRows, volumes: barVolumes[0], mutes: mutes, effects: barEffects[0],
                kitId: currentKitId, patternLength: patternLength,
                bar2Volumes: barVolumes[1], bar2Effects: barEffects[1],
                accents: exportAccents)
    }

    func sessionState() -> SessionState {
        let snapRows = patternLength == 16
            ? rows.mapValues { Array($0.prefix(16)) }
            : rows
        let snapAccents = patternLength == 16
            ? accents.mapValues { Array($0.prefix(16)) }
            : accents
        return SessionState(
            patternName: patternName,
            tempo: tempo,
            swing: swing,
            masterGain: masterGain,
            rows: snapRows,
            volumes: barVolumes[0],
            mutes: mutes,
            kitId: currentKitId,
            patternId: currentPatternId,
            effects: barEffects[0],
            patternLength: patternLength,
            enabledBars: enabledBars,
            bar2Volumes: barVolumes[1],
            bar2Effects: barEffects[1],
            accents: snapAccents
        )
    }

    func loadSession(_ session: SessionState) {
        patternName = session.patternName
        currentPatternId = session.patternId ?? ""
        tempo = session.tempo
        swing = session.swing
        masterGain = session.masterGain
        patternLength = session.patternLength ?? 16
        enabledBars = session.enabledBars ?? (patternLength == 32 ? [true, true] : [true])
        rows = Presets.filledRows(from: session.rows, length: patternLength)
        for t in Tracks.all {
            barVolumes[0][t.id] = session.volumes[t.id] ?? 1.0
            barVolumes[1][t.id] = session.bar2Volumes?[t.id] ?? 1.0
            mutes[t.id] = session.mutes[t.id] ?? false
            barEffects[0][t.id] = session.effects?[t.id] ?? .default
            barEffects[1][t.id] = session.bar2Effects?[t.id] ?? .default
        }
        currentKitId = session.kitId ?? "studio"
        for t in Tracks.all {
            accents[t.id] = normalizedFlags(session.accents?[t.id], length: patternLength)
        }
        refreshSnapshot()
        isDirty = false
        changes.send(.patternLength)
        changes.send(.load)
    }

    // MARK: - Accent

    func toggleAccent(trackId: String, step: Int) {
        guard var arr = accents[trackId], arr.indices.contains(step) else { return }
        pushUndo()
        arr[step].toggle()
        accents[trackId] = arr
        isDirty = true
        refreshSnapshot()
        changes.send(.accent)
    }

    // MARK: - Track Actions

    func clearTrack(trackId: String) {
        pushUndo()
        rows[trackId] = Array(repeating: false, count: patternLength)
        accents[trackId] = Array(repeating: false, count: patternLength)
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    /// Positive delta = shift right, negative = shift left. Wraps within patternLength.
    func shiftTrack(trackId: String, by delta: Int) {
        guard var arr = rows[trackId], !arr.isEmpty else { return }
        pushUndo()
        let len = arr.count
        let d = ((delta % len) + len) % len
        arr = Array(arr[d...]) + Array(arr[..<d])
        rows[trackId] = arr
        if var accArr = accents[trackId], accArr.count == len {
            accArr = Array(accArr[d...]) + Array(accArr[..<d])
            accents[trackId] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
    }

    func randomizeTrack(_ trackId: String) {
        guard let track = Tracks.find(trackId) else { return }
        pushUndo()
        rows[trackId] = generateTrackSteps(voice: track.voice, length: patternLength)
        accents[trackId] = Array(repeating: false, count: patternLength)
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    // MARK: - Bar Actions

    func clearBar(_ barIndex: Int) {
        pushUndo()
        let start = barIndex == 0 ? 0 : 16
        for trackId in rows.keys {
            guard var arr = rows[trackId], arr.count > start else { continue }
            let end = min(start + 16, arr.count)
            for i in start..<end { arr[i] = false }
            rows[trackId] = arr
            if var accArr = accents[trackId], accArr.count > start {
                for i in start..<min(start + 16, accArr.count) { accArr[i] = false }
                accents[trackId] = accArr
            }
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    func randomizeBar(_ barIndex: Int) {
        pushUndo()
        let start = barIndex == 0 ? 0 : 16
        for track in Tracks.all {
            guard var arr = rows[track.id], arr.count > start else { continue }
            let barSteps = randomBarSteps(voice: track.voice)
            let end = min(start + 16, arr.count)
            for i in start..<end { arr[i] = barSteps[i - start] }
            rows[track.id] = arr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
    }

    func humanizeBar(_ barIndex: Int) {
        pushUndo()
        let start = barIndex == 0 ? 0 : 16
        for trackId in rows.keys {
            guard var arr = rows[trackId], arr.count > start else { continue }
            var accArr = accents[trackId] ?? Array(repeating: false, count: arr.count)
            let end = min(start + 16, arr.count)
            for i in start..<end {
                if arr[i] {
                    if Double.random(in: 0...1) < 0.25 { accArr[i].toggle() }
                    if Double.random(in: 0...1) < 0.07 { arr[i] = false; accArr[i] = false }
                } else if i % 4 == 2, Double.random(in: 0...1) < 0.05 {
                    arr[i] = true
                }
            }
            rows[trackId] = arr
            accents[trackId] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    // MARK: - Groove Actions

    func humanizeGroove() {
        pushUndo()
        for trackId in rows.keys {
            guard var arr = rows[trackId] else { continue }
            var accArr = accents[trackId] ?? Array(repeating: false, count: arr.count)
            for i in arr.indices {
                if arr[i] {
                    if Double.random(in: 0...1) < 0.30 { accArr[i].toggle() }
                    if Double.random(in: 0...1) < 0.06 { arr[i] = false; accArr[i] = false }
                } else if i % 4 == 2, Double.random(in: 0...1) < 0.04 {
                    arr[i] = true
                }
            }
            rows[trackId] = arr
            accents[trackId] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    func randomizeGroove() {
        pushUndo()
        for track in Tracks.all {
            rows[track.id] = generateTrackSteps(voice: track.voice, length: patternLength)
            accents[track.id] = Array(repeating: false, count: patternLength)
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    // MARK: - Private helpers

    private func generateTrackSteps(voice: VoiceKind, length: Int) -> [Bool] {
        var result = Array(repeating: false, count: length)
        let bar1 = randomBarSteps(voice: voice)
        for i in 0..<min(16, length) { result[i] = bar1[i] }
        if length == 32 {
            let bar2 = randomBarSteps(voice: voice)
            for i in 0..<16 { result[16 + i] = bar2[i] }
        }
        return result
    }

    private func randomBarSteps(voice: VoiceKind) -> [Bool] {
        var r = Array(repeating: false, count: 16)
        switch voice {
        case .kick:
            for b in [0, 8] { if Double.random(in: 0...1) < 0.85 { r[b] = true } }
            for b in [2, 4, 6, 10, 12, 14] { if Double.random(in: 0...1) < 0.25 { r[b] = true } }
        case .snare:
            for b in [4, 12] { if Double.random(in: 0...1) < 0.90 { r[b] = true } }
            for b in [2, 6, 10, 14] { if Double.random(in: 0...1) < 0.15 { r[b] = true } }
        case .hat:
            let stride = Bool.random() ? 2 : 1
            for i in Swift.stride(from: 0, to: 16, by: stride) { r[i] = Double.random(in: 0...1) < 0.80 }
        case .clap:
            for b in [4, 12] { if Double.random(in: 0...1) < 0.75 { r[b] = true } }
            for b in [6, 14] { if Double.random(in: 0...1) < 0.20 { r[b] = true } }
        case .bass:
            for b in [0, 8] { if Double.random(in: 0...1) < 0.70 { r[b] = true } }
            for b in [3, 5, 10, 13] { if Double.random(in: 0...1) < 0.30 { r[b] = true } }
        case .pluck:
            for b in [2, 5, 7, 9, 11, 13, 14, 15] { if Double.random(in: 0...1) < 0.30 { r[b] = true } }
        case .pad:
            for b in [0, 4, 8, 12] { if Double.random(in: 0...1) < 0.35 { r[b] = true } }
        case .perc:
            for b in [1, 3, 5, 7, 9, 11, 13, 15] { if Double.random(in: 0...1) < 0.30 { r[b] = true } }
        }
        return r
    }
}

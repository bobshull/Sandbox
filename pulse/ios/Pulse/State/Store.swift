import Foundation
import Combine

enum StateSection {
    case tempo, swing, master, pattern, mutes, volumes, step, name, load, kit, undo, effects, patternLength
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

    var volumes: [String: Float] { barVolumes[0] }
    var effects: [String: TrackEffects] { barEffects[0] }
    func volumes(for bar: Int) -> [String: Float] { bar == 1 ? barVolumes[1] : barVolumes[0] }
    func effects(for bar: Int) -> [String: TrackEffects] { bar == 1 ? barEffects[1] : barEffects[0] }

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
        let rows: [String: [Bool]]
        let mutes: [String: Bool]
        let patternLength: Int
        let sequenceStart: Int
        let sequenceLength: Int
    }
    private let snapshotLock = NSLock()
    private var snapshot = AudioSnapshot(rows: [:], mutes: [:], patternLength: 16, sequenceStart: 0, sequenceLength: 16)

    func audioSnapshot() -> AudioSnapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return snapshot
    }

    private func refreshSnapshot() {
        snapshotLock.lock()
        snapshot = AudioSnapshot(rows: rows, mutes: mutes, patternLength: patternLength,
                                 sequenceStart: sequenceStart, sequenceLength: sequenceLength)
        snapshotLock.unlock()
    }

    init() {
        for t in Tracks.all {
            mutes[t.id] = false
            barVolumes[0][t.id] = 1.0
            barVolumes[1][t.id] = 1.0
            barEffects[0][t.id] = .default
            barEffects[1][t.id] = .default
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
        isDirty = true
        changes.send(.tempo)
    }

    func setSwing(_ value: Double) {
        swing = min(max(value, 0), 0.6)
        isDirty = true
        changes.send(.swing)
    }

    func setMasterGain(_ value: Float) {
        masterGain = min(max(value, 0), 1)
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
        barVolumes[bar][trackId] = min(max(value, 0), 1)
        isDirty = true
        changes.send(.volumes)
    }

    func setTrackEffects(trackId: String, _ fx: TrackEffects, bar: Int = 0) {
        barEffects[bar][trackId] = fx
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
                    // Pad with blank Bar 2 only when not already 32 steps
                    rows[t.id] = Array(current.prefix(16)) + Array(repeating: false, count: 16)
                }
                // If rows are already 32 steps, keep them (restores preserved Bar 2)
            }
        } else {
            // Switching to 1 bar: keep rows as-is so Bar 2 is preserved in memory.
            // The audio engine and sequencer respect patternLength, so Bar 2 is
            // silently skipped. Switching back to 2 bars restores it automatically.
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
        guard patternLength == 32, index < 2 else { return }
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
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
    }

    func loadPattern(_ pattern: Pattern) {
        undoStack.removeAll()
        patternName = pattern.name
        currentPatternId = pattern.id
        tempo = pattern.tempo
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
        return Pattern(id: UUID().uuidString, name: patternName, tempo: tempo, swing: swing,
                rows: exportRows, volumes: barVolumes[0], mutes: mutes, effects: barEffects[0],
                kitId: currentKitId, patternLength: patternLength,
                bar2Volumes: barVolumes[1], bar2Effects: barEffects[1])
    }

    func sessionState() -> SessionState {
        let snapRows = patternLength == 16
            ? rows.mapValues { Array($0.prefix(16)) }
            : rows
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
            bar2Effects: barEffects[1]
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
        refreshSnapshot()
        isDirty = false
        changes.send(.patternLength)
        changes.send(.load)
    }
}

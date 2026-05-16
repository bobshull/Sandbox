import Foundation
import Combine

enum StateSection {
    case tempo, swing, master, pattern, mutes, volumes, step, name, load, kit, undo, effects
}

final class Store {
    // Settings
    private(set) var tempo: Double = 96
    private(set) var swing: Double = 0.18
    private(set) var masterGain: Float = 0.85

    // Pattern + per-track state
    private(set) var rows: [String: [Bool]] = Presets.emptyRows()
    private(set) var mutes: [String: Bool] = [:]
    private(set) var volumes: [String: Float] = [:]
    private(set) var effects: [String: TrackEffects] = [:]

    // Transport
    private(set) var activeStep: Int = -1
    private(set) var patternName: String = "Untitled"
    private(set) var currentKitId: String = "studio"
    private(set) var currentPatternId: String = ""

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
    }
    private let snapshotLock = NSLock()
    private var snapshot = AudioSnapshot(rows: [:], mutes: [:])

    func audioSnapshot() -> AudioSnapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return snapshot
    }

    private func refreshSnapshot() {
        snapshotLock.lock()
        snapshot = AudioSnapshot(rows: rows, mutes: mutes)
        snapshotLock.unlock()
    }

    init() {
        for t in Tracks.all {
            mutes[t.id] = false
            volumes[t.id] = 1.0
            effects[t.id] = .default
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
        rows = Presets.filledRows(from: snap.rows)
        for t in Tracks.all {
            volumes[t.id] = snap.volumes[t.id] ?? 1.0
            mutes[t.id] = snap.mutes[t.id] ?? false
            effects[t.id] = snap.effects?[t.id] ?? .default
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

    func setVolume(trackId: String, value: Float) {
        volumes[trackId] = min(max(value, 0), 1)
        isDirty = true
        changes.send(.volumes)
    }

    func setTrackEffects(trackId: String, _ fx: TrackEffects) {
        effects[trackId] = fx
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

    func clearPattern() {
        pushUndo()
        rows = Presets.emptyRows()
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
        rows = Presets.filledRows(from: pattern.rows)
        for t in Tracks.all {
            volumes[t.id] = pattern.volumes?[t.id] ?? 1.0
            mutes[t.id] = pattern.mutes?[t.id] ?? false
            effects[t.id] = pattern.effects?[t.id] ?? .default
        }
        currentKitId = pattern.kitId ?? "studio"
        refreshSnapshot()
        isDirty = false
        changes.send(.kit)
        changes.send(.undo)
        changes.send(.load)
    }

    func exportPattern() -> Pattern {
        Pattern(id: UUID().uuidString, name: patternName, tempo: tempo, swing: swing,
                rows: rows, volumes: volumes, mutes: mutes, effects: effects, kitId: currentKitId)
    }

    func sessionState() -> SessionState {
        SessionState(
            patternName: patternName,
            tempo: tempo,
            swing: swing,
            masterGain: masterGain,
            rows: rows,
            volumes: volumes,
            mutes: mutes,
            kitId: currentKitId,
            patternId: currentPatternId,
            effects: effects
        )
    }

    func loadSession(_ session: SessionState) {
        patternName = session.patternName
        currentPatternId = session.patternId ?? ""
        tempo = session.tempo
        swing = session.swing
        masterGain = session.masterGain
        rows = Presets.filledRows(from: session.rows)
        for t in Tracks.all {
            volumes[t.id] = session.volumes[t.id] ?? 1.0
            mutes[t.id] = session.mutes[t.id] ?? false
            effects[t.id] = session.effects?[t.id] ?? .default
        }
        currentKitId = session.kitId ?? "studio"
        refreshSnapshot()
        isDirty = false
        changes.send(.load)
    }
}

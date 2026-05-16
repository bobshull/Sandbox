import Foundation
import Combine

enum StateSection {
    case tempo, swing, master, pattern, mutes, volumes, step, name, load, kit, undo
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

    // Transport
    private(set) var activeStep: Int = -1
    private(set) var patternName: String = "Untitled"
    private(set) var currentKitId: String = "studio"

    // Undo / dirty
    private(set) var isDirty = false
    private var undoStack: [SessionState] = []
    var canUndo: Bool { !undoStack.isEmpty }

    let changes = PassthroughSubject<StateSection, Never>()

    /// Audio scheduler reads pattern + mute state from a non-main thread.
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
            volumes[t.id] = 0.8
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
            volumes[t.id] = snap.volumes[t.id] ?? 0.8
            mutes[t.id] = snap.mutes[t.id] ?? false
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

    func setActiveStep(_ step: Int) {
        activeStep = step
        changes.send(.step)
    }

    func setPatternName(_ name: String) {
        patternName = name
        changes.send(.name)
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
        pushUndo()
        patternName = pattern.name
        tempo = pattern.tempo
        swing = pattern.swing
        rows = Presets.filledRows(from: pattern.rows)
        refreshSnapshot()
        isDirty = false
        changes.send(.load)
    }

    func exportPattern() -> Pattern {
        Pattern(id: UUID().uuidString, name: patternName, tempo: tempo, swing: swing, rows: rows)
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
            kitId: currentKitId
        )
    }

    func loadSession(_ session: SessionState) {
        patternName = session.patternName
        tempo = session.tempo
        swing = session.swing
        masterGain = session.masterGain
        rows = Presets.filledRows(from: session.rows)
        for t in Tracks.all {
            volumes[t.id] = session.volumes[t.id] ?? 0.8
            mutes[t.id] = session.mutes[t.id] ?? false
        }
        currentKitId = session.kitId ?? "studio"
        refreshSnapshot()
        isDirty = false
        changes.send(.load)
    }
}

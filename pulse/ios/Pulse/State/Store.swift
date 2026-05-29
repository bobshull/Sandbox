import Foundation
import Combine

enum StateSection {
    case tempo, swing, master, pattern, mutes, volumes, step, name, load, kit, undo, effects, patternLength, accent
}

enum RandomizeIntensity: CaseIterable {
    case light, medium, wild

    var title: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .wild: return "Wild"
        }
    }

    fileprivate var density: Double {
        switch self {
        case .light: return 0.65
        case .medium: return 1.0
        case .wild: return 1.45
        }
    }
}

enum AccentPattern: CaseIterable {
    case downbeat, upbeat

    var title: String {
        switch self {
        case .downbeat: return "Downbeats"
        case .upbeat: return "Upbeats"
        }
    }

    fileprivate func contains(localStep: Int) -> Bool {
        switch self {
        case .downbeat: return [0, 4, 8, 12].contains(localStep)
        case .upbeat: return [2, 6, 10, 14].contains(localStep)
        }
    }
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
    private(set) var grooveSeed: UInt64 = UInt64.random(in: 1...UInt64.max)

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
        let grooveSeed: UInt64
    }
    private let snapshotLock = NSLock()
    private var snapshot = AudioSnapshot(tempo: AppSettings.defaultTempo, swing: 0.18, masterGain: 0.85,
                                         rows: [:], mutes: [:], barVolumes: [[:], [:]],
                                         barEffects: [[:], [:]], patternLength: 16,
                                         sequenceStart: 0, sequenceLength: 16, accents: [:],
                                         grooveSeed: 1)

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
                                 accents: accents, grooveSeed: grooveSeed)
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

    private func refreshGrooveSeed() {
        grooveSeed = UInt64.random(in: 1...UInt64.max)
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        patternName = snap.patternName
        tempo = snap.tempo
        swing = snap.swing
        masterGain = snap.masterGain
        let prevLength = snap.patternLength ?? 16
        let prevBars = snap.enabledBars ?? (prevLength == 32 ? [true, true] : [true])
        grooveSeed = snap.grooveSeed ?? UInt64.random(in: 1...UInt64.max)
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
        refreshGrooveSeed()
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
        refreshGrooveSeed()
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
        refreshGrooveSeed()
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
        refreshGrooveSeed()
        refreshSnapshot()
        isDirty = true
        changes.send(.patternLength)   // reuses existing section; SequencerView listens to it
    }

    func duplicateBar1() {
        guard patternLength == 32 else { return }
        pushUndo()
        refreshGrooveSeed()
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

    func generateBar2Variation() {
        if patternLength == 16 {
            pushUndo()
            patternLength = 32
            enabledBars = [true, true]
            for t in Tracks.all {
                let bar1 = Array((rows[t.id] ?? Array(repeating: false, count: 16)).prefix(16))
                rows[t.id] = bar1 + bar1
                let bar1Accents = Array(normalizedFlags(accents[t.id], length: 16).prefix(16))
                accents[t.id] = bar1Accents + bar1Accents
                barVolumes[1][t.id] = barVolumes[0][t.id]
                barEffects[1][t.id] = barEffects[0][t.id]
            }
        } else {
            pushUndo()
            for t in Tracks.all {
                guard var arr = rows[t.id], arr.count == 32 else { continue }
                let bar1 = Array(arr.prefix(16))
                arr.replaceSubrange(16..., with: bar1)
                rows[t.id] = arr

                var accArr = normalizedFlags(accents[t.id], length: 32)
                let bar1Accents = Array(accArr.prefix(16))
                accArr.replaceSubrange(16..., with: bar1Accents)
                accents[t.id] = accArr

                barVolumes[1][t.id] = barVolumes[0][t.id]
                barEffects[1][t.id] = barEffects[0][t.id]
            }
        }

        refreshGrooveSeed()
        for track in Tracks.all {
            guard var arr = rows[track.id], arr.count == 32 else { continue }
            var accArr = normalizedFlags(accents[track.id], length: 32)
            for step in 16..<32 {
                mutateStep(voice: track.voice, absoluteStep: step, steps: &arr, accents: &accArr)
            }
            rows[track.id] = arr
            accents[track.id] = accArr
        }

        refreshSnapshot()
        isDirty = true
        changes.send(.patternLength)
        changes.send(.pattern)
        changes.send(.accent)
        changes.send(.volumes)
        changes.send(.effects)
    }

    func clearPattern() {
        pushUndo()
        refreshGrooveSeed()
        rows = Presets.emptyRows(length: patternLength)
        for t in Tracks.all { accents[t.id] = Array(repeating: false, count: patternLength) }
        currentPatternId = ""
        patternName = "Untitled"
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
        changes.send(.name)
    }

    func loadPattern(_ pattern: Pattern) {
        undoStack.removeAll()
        patternName = pattern.id == "empty" ? "Untitled" : pattern.name
        currentPatternId = pattern.id
        tempo = pattern.id == "empty" ? AppSettings.defaultTempo : pattern.tempo
        swing = pattern.swing
        grooveSeed = pattern.grooveSeed ?? UInt64.random(in: 1...UInt64.max)
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
                accents: exportAccents, grooveSeed: grooveSeed)
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
            accents: snapAccents,
            grooveSeed: grooveSeed
        )
    }

    func loadSession(_ session: SessionState) {
        patternName = session.patternName
        currentPatternId = session.patternId ?? ""
        tempo = session.tempo
        swing = session.swing
        masterGain = session.masterGain
        grooveSeed = session.grooveSeed ?? UInt64.random(in: 1...UInt64.max)
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
        refreshGrooveSeed()
        arr[step].toggle()
        accents[trackId] = arr
        isDirty = true
        refreshSnapshot()
        changes.send(.accent)
    }

    func accentTrack(trackId: String, pattern: AccentPattern) {
        guard let steps = rows[trackId] else { return }
        pushUndo()
        refreshGrooveSeed()
        var accArr = normalizedFlags(accents[trackId], length: steps.count)
        applyAccents(pattern: pattern, steps: steps, range: steps.indices, accents: &accArr)
        accents[trackId] = accArr
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    func clearTrackAccents(trackId: String) {
        guard accents[trackId] != nil else { return }
        pushUndo()
        refreshGrooveSeed()
        accents[trackId] = Array(repeating: false, count: patternLength)
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    // MARK: - Track Actions

    func clearTrack(trackId: String) {
        pushUndo()
        refreshGrooveSeed()
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
        refreshGrooveSeed()
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

    func randomizeTrack(_ trackId: String, intensity: RandomizeIntensity = .medium) {
        guard let track = Tracks.find(trackId) else { return }
        pushUndo()
        refreshGrooveSeed()
        rows[trackId] = generateTrackSteps(voice: track.voice, length: patternLength, intensity: intensity)
        accents[trackId] = Array(repeating: false, count: patternLength)
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    // MARK: - Bar Actions

    func clearBar(_ barIndex: Int) {
        pushUndo()
        refreshGrooveSeed()
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

    func accentBar(_ barIndex: Int, pattern: AccentPattern) {
        pushUndo()
        refreshGrooveSeed()
        let start = barIndex == 0 ? 0 : 16
        for track in Tracks.all {
            guard let steps = rows[track.id], steps.count > start else { continue }
            var accArr = normalizedFlags(accents[track.id], length: steps.count)
            applyAccents(pattern: pattern,
                         steps: steps,
                         range: start..<min(start + 16, steps.count),
                         accents: &accArr)
            accents[track.id] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    func clearBarAccents(_ barIndex: Int) {
        pushUndo()
        refreshGrooveSeed()
        let start = barIndex == 0 ? 0 : 16
        for trackId in accents.keys {
            guard var accArr = accents[trackId], accArr.count > start else { continue }
            for i in start..<min(start + 16, accArr.count) { accArr[i] = false }
            accents[trackId] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    func randomizeBar(_ barIndex: Int, intensity: RandomizeIntensity = .medium) {
        pushUndo()
        refreshGrooveSeed()
        let start = barIndex == 0 ? 0 : 16
        for track in Tracks.all {
            guard var arr = rows[track.id], arr.count > start else { continue }
            var accArr = normalizedFlags(accents[track.id], length: arr.count)
            let barSteps = randomBarSteps(voice: track.voice, intensity: intensity)
            let end = min(start + 16, arr.count)
            for i in start..<end {
                arr[i] = barSteps[i - start]
                accArr[i] = false
            }
            rows[track.id] = arr
            accents[track.id] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    func humanizeBar(_ barIndex: Int) {
        pushUndo()
        refreshGrooveSeed()
        let start = barIndex == 0 ? 0 : 16
        for track in Tracks.all {
            guard var arr = rows[track.id], arr.count > start else { continue }
            var accArr = normalizedFlags(accents[track.id], length: arr.count)
            let end = min(start + 16, arr.count)
            for step in start..<end {
                mutateStep(voice: track.voice, absoluteStep: step, steps: &arr, accents: &accArr)
            }
            rows[track.id] = arr
            accents[track.id] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    // MARK: - Groove Actions

    func humanizeGroove() {
        pushUndo()
        refreshGrooveSeed()
        for track in Tracks.all {
            guard var arr = rows[track.id] else { continue }
            var accArr = normalizedFlags(accents[track.id], length: arr.count)
            for step in arr.indices {
                mutateStep(voice: track.voice, absoluteStep: step, steps: &arr, accents: &accArr)
            }
            rows[track.id] = arr
            accents[track.id] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    func randomizeGroove(intensity: RandomizeIntensity = .medium) {
        pushUndo()
        refreshGrooveSeed()
        for track in Tracks.all {
            rows[track.id] = generateTrackSteps(voice: track.voice, length: patternLength, intensity: intensity)
            accents[track.id] = Array(repeating: false, count: patternLength)
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.pattern)
        changes.send(.accent)
    }

    func accentGroove(pattern: AccentPattern) {
        pushUndo()
        refreshGrooveSeed()
        for track in Tracks.all {
            guard let steps = rows[track.id] else { continue }
            var accArr = normalizedFlags(accents[track.id], length: steps.count)
            applyAccents(pattern: pattern, steps: steps, range: steps.indices, accents: &accArr)
            accents[track.id] = accArr
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    func clearGrooveAccents() {
        pushUndo()
        refreshGrooveSeed()
        for track in Tracks.all {
            accents[track.id] = Array(repeating: false, count: patternLength)
        }
        refreshSnapshot()
        isDirty = true
        changes.send(.accent)
    }

    // MARK: - Private helpers

    private func generateTrackSteps(voice: VoiceKind, length: Int, intensity: RandomizeIntensity) -> [Bool] {
        var result = Array(repeating: false, count: length)
        let bar1 = randomBarSteps(voice: voice, intensity: intensity)
        for i in 0..<min(16, length) { result[i] = bar1[i] }
        if length == 32 {
            let bar2 = randomBarSteps(voice: voice, intensity: intensity)
            for i in 0..<16 { result[16 + i] = bar2[i] }
        }
        return result
    }

    private func roll(_ probability: Double, intensity: RandomizeIntensity, anchor: Bool = false) -> Bool {
        let scaled = min(max(probability * (anchor ? max(0.85, intensity.density) : intensity.density), 0), 0.98)
        return Double.random(in: 0...1) < scaled
    }

    private func randomBarSteps(voice: VoiceKind, intensity: RandomizeIntensity) -> [Bool] {
        var r = Array(repeating: false, count: 16)
        switch voice {
        case .kick:
            for b in [0, 8] { if roll(0.85, intensity: intensity, anchor: true) { r[b] = true } }
            for b in [2, 4, 6, 10, 12, 14] { if roll(0.25, intensity: intensity) { r[b] = true } }
        case .snare:
            for b in [4, 12] { if roll(0.90, intensity: intensity, anchor: true) { r[b] = true } }
            for b in [2, 6, 10, 14] { if roll(0.15, intensity: intensity) { r[b] = true } }
        case .hat:
            let stride = intensity == .light ? 2 : (Bool.random() ? 2 : 1)
            for i in Swift.stride(from: 0, to: 16, by: stride) { r[i] = roll(0.80, intensity: intensity) }
        case .clap:
            for b in [4, 12] { if roll(0.75, intensity: intensity, anchor: true) { r[b] = true } }
            for b in [6, 14] { if roll(0.20, intensity: intensity) { r[b] = true } }
        case .bass:
            for b in [0, 8] { if roll(0.70, intensity: intensity, anchor: true) { r[b] = true } }
            for b in [3, 5, 10, 13] { if roll(0.30, intensity: intensity) { r[b] = true } }
        case .pluck:
            for b in [2, 5, 7, 9, 11, 13, 14, 15] { if roll(0.30, intensity: intensity) { r[b] = true } }
        case .pad:
            for b in [0, 4, 8, 12] { if roll(0.35, intensity: intensity, anchor: true) { r[b] = true } }
        case .perc:
            for b in [1, 3, 5, 7, 9, 11, 13, 15] { if roll(0.30, intensity: intensity) { r[b] = true } }
        }
        return r
    }

    private func mutateStep(voice: VoiceKind,
                            absoluteStep: Int,
                            steps: inout [Bool],
                            accents: inout [Bool]) {
        let localStep = absoluteStep % 16
        let isAnchor: Bool
        let accentChance: Double
        let removeChance: Double
        let addChance: Double

        switch voice {
        case .kick:
            isAnchor = localStep == 0 || localStep == 8
            accentChance = 0.18
            removeChance = isAnchor ? 0.01 : 0.035
            addChance = [2, 6, 10, 14].contains(localStep) ? 0.045 : 0.012
        case .snare, .clap:
            isAnchor = localStep == 4 || localStep == 12
            accentChance = 0.22
            removeChance = isAnchor ? 0.01 : 0.04
            addChance = [2, 6, 10, 14].contains(localStep) ? 0.035 : 0.01
        case .hat, .perc:
            isAnchor = false
            accentChance = 0.32
            removeChance = 0.08
            addChance = localStep % 2 == 1 ? 0.055 : 0.035
        case .bass:
            isAnchor = localStep == 0 || localStep == 8
            accentChance = 0.16
            removeChance = isAnchor ? 0.015 : 0.04
            addChance = [3, 5, 10, 13].contains(localStep) ? 0.035 : 0.008
        case .pluck:
            isAnchor = false
            accentChance = 0.24
            removeChance = 0.055
            addChance = [2, 5, 7, 9, 11, 14].contains(localStep) ? 0.045 : 0.012
        case .pad:
            isAnchor = localStep % 4 == 0
            accentChance = 0.10
            removeChance = isAnchor ? 0.015 : 0.025
            addChance = localStep % 4 == 0 ? 0.025 : 0.004
        }

        if steps[absoluteStep] {
            if Double.random(in: 0...1) < accentChance { accents[absoluteStep].toggle() }
            if Double.random(in: 0...1) < removeChance {
                steps[absoluteStep] = false
                accents[absoluteStep] = false
            }
        } else if Double.random(in: 0...1) < addChance {
            steps[absoluteStep] = true
            accents[absoluteStep] = Double.random(in: 0...1) < accentChance
        }
    }

    private func applyAccents(pattern: AccentPattern,
                              steps: [Bool],
                              range: Range<Int>,
                              accents: inout [Bool]) {
        for step in range where steps.indices.contains(step) && accents.indices.contains(step) {
            accents[step] = steps[step] && pattern.contains(localStep: step % 16)
        }
    }
}

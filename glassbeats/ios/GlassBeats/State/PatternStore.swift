import Foundation

struct SessionState: Codable {
    var patternName: String
    var tempo: Double
    var swing: Double
    var masterGain: Float
    var rows: [String: [Bool]]
    var volumes: [String: Float]       // bar 0 (backward compat)
    var mutes: [String: Bool]
    var kitId: String?
    var patternId: String?
    var effects: [String: TrackEffects]?   // bar 0 (backward compat)
    var patternLength: Int?
    var enabledBars: [Bool]?
    var bar2Volumes: [String: Float]?      // nil → copy bar 0
    var bar2Effects: [String: TrackEffects]?  // nil → copy bar 0
    var accents: [String: [Bool]]? = nil
    var grooveSeed: UInt64? = nil
    var pitches: [String: [Int]]? = nil   // nil → all defaults (0)
}

enum PatternStore {
    enum CloudStatus {
        case unavailable
        case disabled
        case notSynced
        case synced
        case syncFailed
    }

    private static var local = UserDefaults.standard
    private static var cloudObserver: NSObjectProtocol?
    private static var lastCloudSyncSucceeded: Bool?
    private static var uploadedSavedMixes = false
    private static var receivedExternalCloudChange = false

    private static let patternsKey = "glassbeats.userPatterns.v1"
    private static let sessionKey = "glassbeats.session.v1"
    private static let syncKey = "glassbeats.iCloudSyncEnabled"
    // Written alongside saved mixes in both stores so reads can prefer the
    // newest source instead of letting a stale cloud copy shadow local edits.
    // Session state is local-only; saved mixes are the durable synced content.
    private static let patternsStampKey = "glassbeats.userPatterns.v1.savedAt"
    private static let sessionStampKey = "glassbeats.session.v1.savedAt"
    private static var cloud: NSUbiquitousKeyValueStore { .default }
    private static var canUseCloud: Bool {
        iCloudSyncEnabled && FileManager.default.ubiquityIdentityToken != nil
    }

    static var cloudStatus: CloudStatus {
        guard FileManager.default.ubiquityIdentityToken != nil else { return .unavailable }
        guard iCloudSyncEnabled else { return .disabled }
        if lastCloudSyncSucceeded == false { return .syncFailed }
        return (uploadedSavedMixes || receivedExternalCloudChange || savedMixesAreSyncedWithCloud()) ? .synced : .notSynced
    }

    static func useLocalStore(_ store: UserDefaults) {
        local = store
    }

    @discardableResult
    static func startCloudSync() -> Bool {
        guard canUseCloud else {
            lastCloudSyncSucceeded = nil
            return false
        }
        if cloudObserver == nil {
            cloudObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                                   object: cloud, queue: .main) { _ in
                receivedExternalCloudChange = true
                NotificationCenter.default.post(name: .patternStoreDidChange, object: nil)
            }
        }
        let didSync = cloud.synchronize()
        lastCloudSyncSucceeded = didSync
        if didSync { reconcileSavedMixesWithCloud() }
        return didSync
    }

    static var iCloudSyncEnabled: Bool {
        get { local.object(forKey: syncKey) == nil ? true : local.bool(forKey: syncKey) }
        set {
            local.set(newValue, forKey: syncKey)
            if newValue { startCloudSync() }
        }
    }

    /// Picks whichever copy of a payload was written most recently. Old installs
    /// without stamps read as 0; ties prefer local.
    private static func newestData(forKey key: String, stampKey: String) -> Data? {
        let localData = local.data(forKey: key)
        guard canUseCloud, let cloudData = cloud.data(forKey: key) else { return localData }
        guard localData != nil else { return cloudData }
        return cloud.double(forKey: stampKey) > local.double(forKey: stampKey) ? cloudData : localData
    }

    private static func savedMixesAreSyncedWithCloud() -> Bool {
        guard canUseCloud, let cloudData = cloud.data(forKey: patternsKey) else { return false }
        guard let localData = local.data(forKey: patternsKey) else { return true }
        return cloudData == localData && cloud.double(forKey: patternsStampKey) >= local.double(forKey: patternsStampKey)
    }

    private static func reconcileSavedMixesWithCloud() {
        guard canUseCloud else { return }

        let localData = local.data(forKey: patternsKey)
        let cloudData = cloud.data(forKey: patternsKey)
        let cloudStamp = cloud.double(forKey: patternsStampKey)
        let localStamp = local.double(forKey: patternsStampKey)

        if let localData, (cloudData == nil || localStamp > cloudStamp) {
            cloud.set(localData, forKey: patternsKey)
            cloud.set(localStamp, forKey: patternsStampKey)
            lastCloudSyncSucceeded = cloud.synchronize()
            uploadedSavedMixes = lastCloudSyncSucceeded == true
            return
        }

        guard let cloudData, localData == nil || cloudStamp > localStamp else { return }
        local.set(cloudData, forKey: patternsKey)
        local.set(cloudStamp, forKey: patternsStampKey)
        receivedExternalCloudChange = true
        NotificationCenter.default.post(name: .patternStoreDidChange, object: nil)
    }

    // MARK: - User Patterns

    static func userPatterns() -> [Pattern] {
        guard let data = newestData(forKey: patternsKey, stampKey: patternsStampKey) else { return [] }
        do {
            return try JSONDecoder().decode([Pattern].self, from: data)
        } catch {
            print("[PatternStore] decode failed: \(error)")
            return []
        }
    }

    /// Updates an existing pattern by id, or inserts a new one. A new pattern
    /// never replaces a different pattern just because the names collide —
    /// use `uniqueName(_:)` when creating to keep display names unambiguous.
    @discardableResult
    static func save(_ pattern: Pattern) -> Bool {
        var list = userPatterns()
        if let idx = list.firstIndex(where: { $0.id == pattern.id }) {
            list[idx] = pattern
        } else {
            list.insert(pattern, at: 0)
        }
        if list.count > 50 { list = Array(list.prefix(50)) }
        return persistPatterns(list)
    }

    /// Returns `name`, or "name 2"/"name 3"… if a different saved pattern
    /// already uses it (case-insensitive).
    static func uniqueName(_ name: String) -> String {
        let taken = Set(userPatterns().map { $0.name.lowercased() })
        guard taken.contains(name.lowercased()) else { return name }
        var n = 2
        while taken.contains("\(name) \(n)".lowercased()) { n += 1 }
        return "\(name) \(n)"
    }

    @discardableResult
    static func delete(id: String) -> Bool {
        let list = userPatterns().filter { $0.id != id }
        return persistPatterns(list)
    }

    private static func persistPatterns(_ list: [Pattern]) -> Bool {
        do {
            let data = try JSONEncoder().encode(list)
            let stamp = Date().timeIntervalSince1970
            local.set(data, forKey: patternsKey)
            local.set(stamp, forKey: patternsStampKey)
            if canUseCloud {
                cloud.set(data, forKey: patternsKey)
                cloud.set(stamp, forKey: patternsStampKey)
                lastCloudSyncSucceeded = cloud.synchronize()
                uploadedSavedMixes = lastCloudSyncSucceeded == true
            }
            NotificationCenter.default.post(name: .patternStoreDidChange, object: nil)
            return true
        } catch {
            print("[PatternStore] encode failed: \(error)")
            return false
        }
    }

    // MARK: - Session

    static func saveSession(_ state: SessionState) {
        do {
            let data = try JSONEncoder().encode(state)
            let stamp = Date().timeIntervalSince1970
            local.set(data, forKey: sessionKey)
            local.set(stamp, forKey: sessionStampKey)
            NotificationCenter.default.post(name: .patternStoreDidChange, object: nil)
        } catch {
            print("[PatternStore] session encode failed: \(error)")
        }
    }

    static func loadSession() -> SessionState? {
        guard let data = local.data(forKey: sessionKey) else { return nil }
        do {
            return try JSONDecoder().decode(SessionState.self, from: data)
        } catch {
            print("[PatternStore] session decode failed: \(error)")
            return nil
        }
    }
}

// MARK: - SessionSaver

/// Debounces session saves during normal editing, with a synchronous `flush()`
/// for app-lifecycle moments (resign active / background) so edits made inside
/// the debounce window are never lost to suspension.
final class SessionSaver {
    private let delay: TimeInterval
    private let save: () -> Void
    private var pending: DispatchWorkItem?

    init(delay: TimeInterval = 0.5, save: @escaping () -> Void) {
        self.delay = delay
        self.save = save
    }

    /// Coalesces rapid edits into one save `delay` seconds after the last call.
    func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.save()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Runs a pending save immediately. No-op when nothing is pending.
    func flush() {
        guard let work = pending else { return }
        work.cancel()
        pending = nil
        save()
    }
}

extension Notification.Name {
    static let patternStoreDidChange = Notification.Name("glassbeats.patternStoreDidChange")
}

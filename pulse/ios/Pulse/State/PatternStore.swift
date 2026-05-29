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
}

enum PatternStore {
    private static let cloud = NSUbiquitousKeyValueStore.default
    private static var local = UserDefaults.standard

    private static let patternsKey = "pulse.userPatterns.v1"
    private static let sessionKey = "pulse.session.v1"
    private static let syncKey = "pulse.iCloudSyncEnabled"

    static func useLocalStore(_ store: UserDefaults) {
        local = store
    }

    static func startCloudSync() {
        _ = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                   object: cloud, queue: .main) { _ in
            NotificationCenter.default.post(name: .patternStoreDidChange, object: nil)
        }
        cloud.synchronize()
    }

    static var iCloudSyncEnabled: Bool {
        get { local.object(forKey: syncKey) == nil ? true : local.bool(forKey: syncKey) }
        set { local.set(newValue, forKey: syncKey) }
    }

    // MARK: - User Patterns

    static func userPatterns() -> [Pattern] {
        let data = (iCloudSyncEnabled ? cloud.data(forKey: patternsKey) : nil)
            ?? local.data(forKey: patternsKey)
        guard let data else { return [] }
        do {
            return try JSONDecoder().decode([Pattern].self, from: data)
        } catch {
            print("[PatternStore] decode failed: \(error)")
            return []
        }
    }

    @discardableResult
    static func save(_ pattern: Pattern) -> Bool {
        var list = userPatterns()
        if let idx = list.firstIndex(where: { $0.id == pattern.id || $0.name == pattern.name }) {
            list[idx] = pattern
        } else {
            list.insert(pattern, at: 0)
        }
        if list.count > 50 { list = Array(list.prefix(50)) }
        return persistPatterns(list)
    }

    @discardableResult
    static func delete(id: String) -> Bool {
        let list = userPatterns().filter { $0.id != id }
        return persistPatterns(list)
    }

    private static func persistPatterns(_ list: [Pattern]) -> Bool {
        do {
            let data = try JSONEncoder().encode(list)
            local.set(data, forKey: patternsKey)
            if iCloudSyncEnabled {
                cloud.set(data, forKey: patternsKey)
                cloud.synchronize()
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
            local.set(data, forKey: sessionKey)
            if iCloudSyncEnabled {
                cloud.set(data, forKey: sessionKey)
                cloud.synchronize()
            }
        } catch {
            print("[PatternStore] session encode failed: \(error)")
        }
    }

    static func loadSession() -> SessionState? {
        let data = (iCloudSyncEnabled ? cloud.data(forKey: sessionKey) : nil)
            ?? local.data(forKey: sessionKey)
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(SessionState.self, from: data)
        } catch {
            print("[PatternStore] session decode failed: \(error)")
            return nil
        }
    }
}

extension Notification.Name {
    static let patternStoreDidChange = Notification.Name("pulse.patternStoreDidChange")
}

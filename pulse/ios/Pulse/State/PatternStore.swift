import Foundation

struct SessionState: Codable {
    var patternName: String
    var tempo: Double
    var swing: Double
    var masterGain: Float
    var rows: [String: [Bool]]
    var volumes: [String: Float]
    var mutes: [String: Bool]
    var kitId: String?
    var patternId: String?
    var effects: [String: TrackEffects]?
}

enum PatternStore {
    private static let cloud = NSUbiquitousKeyValueStore.default
    private static let local = UserDefaults.standard

    private static let patternsKey = "pulse.userPatterns.v1"
    private static let sessionKey = "pulse.session.v1"

    // MARK: - User Patterns

    static func userPatterns() -> [Pattern] {
        let data = cloud.data(forKey: patternsKey) ?? local.data(forKey: patternsKey)
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
            cloud.set(data, forKey: patternsKey)
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
            cloud.set(data, forKey: sessionKey)
        } catch {
            print("[PatternStore] session encode failed: \(error)")
        }
    }

    static func loadSession() -> SessionState? {
        let data = cloud.data(forKey: sessionKey) ?? local.data(forKey: sessionKey)
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(SessionState.self, from: data)
        } catch {
            print("[PatternStore] session decode failed: \(error)")
            return nil
        }
    }
}

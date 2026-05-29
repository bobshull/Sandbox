import XCTest
@testable import Pulse

final class PatternStoreTests: XCTestCase {

    private let patternsKey = "pulse.userPatterns.v1"
    private let sessionKey = "pulse.session.v1"
    private let syncKey = "pulse.iCloudSyncEnabled"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "Pulse.PatternStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        PatternStore.useLocalStore(defaults)
        // Disable iCloud sync so tests only touch UserDefaults, not NSUbiquitousKeyValueStore
        PatternStore.iCloudSyncEnabled = false
        defaults.removeObject(forKey: patternsKey)
        defaults.removeObject(forKey: sessionKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: patternsKey)
        defaults.removeObject(forKey: sessionKey)
        // Restore default (true)
        defaults.removeObject(forKey: syncKey)
        PatternStore.useLocalStore(.standard)
        defaults = nil
        super.tearDown()
    }

    private func makePattern(id: String = UUID().uuidString, name: String = "Test Beat") -> Pattern {
        Pattern(id: id, name: name, tempo: 120, swing: 0.1, rows: [:])
    }

    // MARK: - userPatterns

    func test_userPatterns_emptyWhenNothingSaved() {
        XCTAssertTrue(PatternStore.userPatterns().isEmpty)
    }

    // MARK: - save

    func test_save_storesOnePattern() {
        PatternStore.save(makePattern())
        XCTAssertEqual(PatternStore.userPatterns().count, 1)
    }

    func test_save_returnsTrue() {
        XCTAssertTrue(PatternStore.save(makePattern()))
    }

    func test_save_multiplePatterns() {
        PatternStore.save(makePattern(id: "a", name: "Pattern A"))
        PatternStore.save(makePattern(id: "b", name: "Pattern B"))
        PatternStore.save(makePattern(id: "c", name: "Pattern C"))
        XCTAssertEqual(PatternStore.userPatterns().count, 3)
    }

    func test_save_insertsAtFront() {
        PatternStore.save(makePattern(id: "first-id", name: "First Pattern"))
        PatternStore.save(makePattern(id: "second-id", name: "Second Pattern"))
        XCTAssertEqual(PatternStore.userPatterns().first?.id, "second-id")
    }

    func test_save_updatesExistingById() {
        let id = UUID().uuidString
        PatternStore.save(makePattern(id: id, name: "Original"))
        PatternStore.save(makePattern(id: id, name: "Updated"))
        let list = PatternStore.userPatterns()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.name, "Updated")
    }

    func test_save_updatesExistingByName() {
        PatternStore.save(makePattern(id: "id1", name: "Same Name"))
        PatternStore.save(makePattern(id: "id2", name: "Same Name"))
        XCTAssertEqual(PatternStore.userPatterns().count, 1)
    }

    func test_save_limitsTo50Patterns() {
        for i in 0..<55 {
            PatternStore.save(makePattern(id: "id-\(i)", name: "Pattern \(i)"))
        }
        XCTAssertEqual(PatternStore.userPatterns().count, 50)
    }

    func test_save_preservesPatternData() {
        var p = makePattern(id: "test-id", name: "My Pattern")
        p.tempo = 140
        p.swing = 0.22
        p.kitId = "jungle"
        PatternStore.save(p)
        let loaded = PatternStore.userPatterns().first
        XCTAssertEqual(loaded?.id, "test-id")
        XCTAssertEqual(loaded?.name, "My Pattern")
        XCTAssertEqual(loaded?.tempo, 140)
        XCTAssertEqual(loaded?.swing ?? 0, 0.22, accuracy: 0.001)
        XCTAssertEqual(loaded?.kitId, "jungle")
    }

    // MARK: - delete

    func test_delete_removesPattern() {
        let id = UUID().uuidString
        PatternStore.save(makePattern(id: id))
        PatternStore.delete(id: id)
        XCTAssertTrue(PatternStore.userPatterns().isEmpty)
    }

    func test_delete_returnsTrue() {
        XCTAssertTrue(PatternStore.delete(id: "nonexistent"))
    }

    func test_delete_leavesOtherPatterns() {
        PatternStore.save(makePattern(id: "keep", name: "Keep Me"))
        PatternStore.save(makePattern(id: "remove", name: "Remove Me"))
        PatternStore.delete(id: "remove")
        let list = PatternStore.userPatterns()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, "keep")
    }

    func test_delete_nonexistentId_noEffect() {
        PatternStore.save(makePattern(id: "real", name: "Real One"))
        PatternStore.delete(id: "fake")
        XCTAssertEqual(PatternStore.userPatterns().count, 1)
    }

    func test_delete_all() {
        PatternStore.save(makePattern(id: "a", name: "Alpha"))
        PatternStore.save(makePattern(id: "b", name: "Beta"))
        PatternStore.delete(id: "a")
        PatternStore.delete(id: "b")
        XCTAssertTrue(PatternStore.userPatterns().isEmpty)
    }

    // MARK: - saveSession / loadSession

    func test_loadSession_returnsNilWhenNothingSaved() {
        XCTAssertNil(PatternStore.loadSession())
    }

    func test_saveLoadSession_tempo() {
        let store = Store()
        store.setTempo(140)
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.tempo, 140)
    }

    func test_saveLoadSession_swing() {
        let store = Store()
        store.setSwing(0.22)
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.swing ?? 0, 0.22, accuracy: 0.001)
    }

    func test_saveLoadSession_masterGain() {
        let store = Store()
        store.setMasterGain(0.7)
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.masterGain ?? 0, Float(0.7), accuracy: Float(0.001))
    }

    func test_saveLoadSession_patternName() {
        let store = Store()
        store.setPatternName("Session Test")
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.patternName, "Session Test")
    }

    func test_saveLoadSession_kitId() {
        let store = Store()
        store.setKit("arcade")
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.kitId, "arcade")
    }

    func test_saveLoadSession_patternLength() {
        let store = Store()
        store.setPatternLength(32)
        PatternStore.saveSession(store.sessionState())
        XCTAssertEqual(PatternStore.loadSession()?.patternLength, 32)
    }

    func test_saveSession_overwritesPrevious() {
        let s1 = Store()
        s1.setPatternName("First")
        PatternStore.saveSession(s1.sessionState())

        let s2 = Store()
        s2.setPatternName("Second")
        PatternStore.saveSession(s2.sessionState())

        XCTAssertEqual(PatternStore.loadSession()?.patternName, "Second")
    }

    // MARK: - Error handling (corrupt data)

    func test_userPatterns_corruptData_returnsEmpty() {
        defaults.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: patternsKey)
        XCTAssertTrue(PatternStore.userPatterns().isEmpty)
    }

    func test_loadSession_corruptData_returnsNil() {
        defaults.set(Data([0xFF, 0xFE]), forKey: sessionKey)
        XCTAssertNil(PatternStore.loadSession())
    }

    // MARK: - iCloudSyncEnabled

    func test_iCloudSyncEnabled_defaultsToTrue() {
        defaults.removeObject(forKey: syncKey)
        XCTAssertTrue(PatternStore.iCloudSyncEnabled)
    }

    func test_iCloudSyncEnabled_setFalse() {
        PatternStore.iCloudSyncEnabled = false
        XCTAssertFalse(PatternStore.iCloudSyncEnabled)
    }

    func test_iCloudSyncEnabled_setTrue() {
        PatternStore.iCloudSyncEnabled = false
        PatternStore.iCloudSyncEnabled = true
        XCTAssertTrue(PatternStore.iCloudSyncEnabled)
    }
}

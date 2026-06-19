import XCTest
@testable import AggregatorApp

final class ThreadSeenStoreTests: XCTestCase {

    private func makeSuite() -> UserDefaults {
        let suiteName = "ThreadSeenStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func threadJSON(id: Int, hasUpdates: Bool, lastUpdated: String) -> Data {
        let json = """
        {
            "id": \(id),
            "representative_title": "Thread \(id)",
            "rolling_summary": null,
            "known_facts": [],
            "status": "active",
            "novelty_label": null,
            "first_seen": "2026-06-01T00:00:00+00:00",
            "last_updated": "\(lastUpdated)",
            "source_count": 1,
            "member_count": 1,
            "image_url": null,
            "has_updates": \(hasUpdates ? "true" : "false"),
            "dismissed": false,
            "top_grade": null
        }
        """
        return Data(json.utf8)
    }

    // MARK: - hasUnseenUpdate

    func testUnseenWhenNeverOpened() throws {
        let store = ThreadSeenStore(defaults: makeSuite())
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 1, hasUpdates: true, lastUpdated: "2026-06-19T10:00:00+00:00"))
        XCTAssertTrue(store.hasUnseenUpdate(thread))
    }

    func testSeenAfterMarkSeenWithMatchingLastUpdated() throws {
        let defaults = makeSuite()
        let store = ThreadSeenStore(defaults: defaults)
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 2, hasUpdates: true, lastUpdated: "2026-06-19T10:00:00+00:00"))
        store.markSeen(id: thread.id, lastUpdated: thread.lastUpdated)
        XCTAssertFalse(store.hasUnseenUpdate(thread))
    }

    func testUnseenAgainWhenLastUpdatedChanges() throws {
        let defaults = makeSuite()
        let store = ThreadSeenStore(defaults: defaults)
        store.markSeen(id: 3, lastUpdated: "2026-06-19T10:00:00+00:00")
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 3, hasUpdates: true, lastUpdated: "2026-06-20T12:00:00+00:00"))
        XCTAssertTrue(store.hasUnseenUpdate(thread))
    }

    func testReturnsFalseWhenHasUpdatesFalse() throws {
        let store = ThreadSeenStore(defaults: makeSuite())
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 4, hasUpdates: false, lastUpdated: "2026-06-19T10:00:00+00:00"))
        XCTAssertFalse(store.hasUnseenUpdate(thread))
    }

    func testReturnsFalseWhenHasUpdatesFalseEvenWhenNotSeen() throws {
        let store = ThreadSeenStore(defaults: makeSuite())
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 5, hasUpdates: false, lastUpdated: "2026-06-19T10:00:00+00:00"))
        XCTAssertFalse(store.hasUnseenUpdate(thread))
    }

    func testReturnsTrueWhenLastUpdatedDiffers() throws {
        let defaults = makeSuite()
        let store = ThreadSeenStore(defaults: defaults)
        store.markSeen(id: 6, lastUpdated: "2026-06-18T08:00:00+00:00")
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 6, hasUpdates: true, lastUpdated: "2026-06-19T10:00:00+00:00"))
        XCTAssertTrue(store.hasUnseenUpdate(thread))
    }

    // MARK: - UserDefaults persistence

    func testMarkSeenRoundTripsThroughUserDefaults() throws {
        let defaults = makeSuite()
        let store1 = ThreadSeenStore(defaults: defaults)
        store1.markSeen(id: 7, lastUpdated: "2026-06-19T10:00:00+00:00")

        let store2 = ThreadSeenStore(defaults: defaults)
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 7, hasUpdates: true, lastUpdated: "2026-06-19T10:00:00+00:00"))
        XCTAssertFalse(store2.hasUnseenUpdate(thread), "Second store instance should see persisted seen state")
    }

    func testNonNumericKeyInStoredJSONIsSkipped() throws {
        let defaults = makeSuite()
        let poisoned: [String: String] = ["notANumber": "2026-06-19T10:00:00+00:00", "8": "2026-06-19T11:00:00+00:00"]
        let data = try JSONEncoder().encode(poisoned)
        defaults.set(data, forKey: "aggregator.threadsSeen")

        let store = ThreadSeenStore(defaults: defaults)
        let thread = try JSONDecoder().decode(Thread.self, from: threadJSON(id: 8, hasUpdates: true, lastUpdated: "2026-06-19T11:00:00+00:00"))
        XCTAssertFalse(store.hasUnseenUpdate(thread), "Valid key should be loaded; non-numeric key should be skipped without crash")
    }
}

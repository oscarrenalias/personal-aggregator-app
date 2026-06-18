import XCTest
@testable import AggregatorApp

final class AggregatorAppTests: XCTestCase {
    func testCredentialsStoreDefaults() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var storage: [String: String] = [:]
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { storage[$0] },
            keychainWrite: { storage[$0] = $1 }
        )
        XCTAssertEqual(store.baseURL, "https://aggregator-api.renaliaslabs.net/api/v1")
        XCTAssertEqual(store.clientId, "")
        XCTAssertEqual(store.clientSecret, "")
        XCTAssertFalse(store.isConfigured)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCredentialsStoreIsConfigured() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var storage: [String: String] = [:]
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { storage[$0] },
            keychainWrite: { storage[$0] = $1 }
        )
        store.baseURL = "https://example.com"
        store.clientId = "my-client-id"
        store.clientSecret = "my-client-secret"
        XCTAssertTrue(store.isConfigured)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSourceDecodingFromJSON() throws {
        let json = #"{"id":1,"name":"Test Feed","feed_url":"https://example.com/feed.xml"}"#
        let data = Data(json.utf8)
        let source = try JSONDecoder().decode(Source.self, from: data)
        XCTAssertEqual(source.id, 1)
        XCTAssertEqual(source.name, "Test Feed")
        XCTAssertEqual(source.feedURL, "https://example.com/feed.xml")
    }
}

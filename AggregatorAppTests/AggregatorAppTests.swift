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

    // MARK: - CredentialsStore mutation (SettingsIPadView binding coverage)

    func testCredentialsStoreBaseURLPersistsToDefaults() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { _ in nil },
            keychainWrite: { _, _ in }
        )
        store.baseURL = "https://custom.example.com/api/v1"
        XCTAssertEqual(defaults.string(forKey: "aggregator.baseURL"), "https://custom.example.com/api/v1")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCredentialsStoreClientIdWritesToKeychain() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var written: [String: String] = [:]
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { _ in nil },
            keychainWrite: { written[$0] = $1 }
        )
        store.clientId = "abc123.access"
        XCTAssertEqual(written["aggregator.clientId"], "abc123.access")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCredentialsStoreClientSecretWritesToKeychain() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var written: [String: String] = [:]
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { _ in nil },
            keychainWrite: { written[$0] = $1 }
        )
        store.clientSecret = "super-secret-value"
        XCTAssertEqual(written["aggregator.clientSecret"], "super-secret-value")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCredentialsStoreIsNotConfiguredWhenAnyFieldEmpty() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { _ in nil },
            keychainWrite: { _, _ in }
        )
        store.baseURL = "https://example.com"
        store.clientId = "id"
        // clientSecret still empty
        XCTAssertFalse(store.isConfigured)
        store.clientSecret = "secret"
        XCTAssertTrue(store.isConfigured)
        store.baseURL = ""
        XCTAssertFalse(store.isConfigured)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCredentialsStoreInitReadsExistingKeychainValues() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { key in
                key == "aggregator.clientId" ? "stored-id" : "stored-secret"
            },
            keychainWrite: { _, _ in }
        )
        XCTAssertEqual(store.clientId, "stored-id")
        XCTAssertEqual(store.clientSecret, "stored-secret")
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

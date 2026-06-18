import Foundation
import Observation

/// Stores and observes app credentials.
///
/// Storage split:
/// - `baseURL` — UserDefaults key `aggregator.baseURL`; defaults to the production API URL on first launch.
/// - `clientId` / `clientSecret` — Keychain keys `aggregator.clientId` / `aggregator.clientSecret`; default to `""`.
///
/// For unit tests, inject a `.ephemeral` suite and stub closures to avoid touching real storage:
/// ```swift
/// CredentialsStore(defaults: testDefaults, keychainRead: { _ in nil }, keychainWrite: { _, _ in })
/// ```
@Observable
final class CredentialsStore {
    private let keychainRead: (String) -> String?
    private let keychainWrite: (String, String) -> Void
    private let defaults: UserDefaults

    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: "aggregator.baseURL") }
    }
    var clientId: String {
        didSet { keychainWrite("aggregator.clientId", clientId) }
    }
    var clientSecret: String {
        didSet { keychainWrite("aggregator.clientSecret", clientSecret) }
    }

    var isConfigured: Bool {
        !baseURL.isEmpty && !clientId.isEmpty && !clientSecret.isEmpty
    }

    init(
        defaults: UserDefaults = .standard,
        keychainRead: @escaping (String) -> String? = KeychainHelper.read,
        keychainWrite: @escaping (String, String) -> Void = KeychainHelper.write
    ) {
        self.defaults = defaults
        self.keychainRead = keychainRead
        self.keychainWrite = keychainWrite
        let storedURL = defaults.string(forKey: "aggregator.baseURL")
            ?? "https://aggregator-api.renaliaslabs.net/api/v1"
        self.baseURL = storedURL
        self.clientId = keychainRead("aggregator.clientId") ?? ""
        self.clientSecret = keychainRead("aggregator.clientSecret") ?? ""
    }
}

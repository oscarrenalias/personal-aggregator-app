import Foundation
import Observation

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

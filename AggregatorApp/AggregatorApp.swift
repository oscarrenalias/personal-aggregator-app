import SwiftUI

@main
struct AggregatorApp: App {
    @State private var credentialsStore: CredentialsStore
    @State private var seenStore = ThreadSeenStore()
    @State private var listPreferences = ListPreferences()
    @State private var readStore = ArticleReadStore()

    init() {
        // Migration must run before CredentialsStore reads from the keychain.
        KeychainHelper.migrateToSharedGroupIfNeeded(keys: [
            "aggregator.clientId",
            "aggregator.clientSecret"
        ])
        _credentialsStore = State(initialValue: CredentialsStore())
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(credentialsStore)
                .environment(seenStore)
                .environment(listPreferences)
                .environment(readStore)
        }
    }
}

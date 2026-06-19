import SwiftUI

@main
struct AggregatorApp: App {
    @State private var credentialsStore = CredentialsStore()
    @State private var seenStore = ThreadSeenStore()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(credentialsStore)
                .environment(seenStore)
        }
    }
}

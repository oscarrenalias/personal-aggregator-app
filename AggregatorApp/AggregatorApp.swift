import SwiftUI

@main
struct AggregatorApp: App {
    @State private var credentialsStore = CredentialsStore()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(credentialsStore)
        }
    }
}

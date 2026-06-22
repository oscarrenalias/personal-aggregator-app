import SwiftUI

enum DeepLink: Hashable {
    case article(Int)
    case thread(Int)
}

@Observable
final class DeepLinkRouter {
    var pendingLink: DeepLink?

    func handle(_ url: URL) {
        guard url.scheme == "aggregator",
              let host = url.host(percentEncoded: false),
              let idString = url.pathComponents.dropFirst().first,
              let id = Int(idString) else { return }
        switch host {
        case "article": pendingLink = .article(id)
        case "thread":  pendingLink = .thread(id)
        default:        break
        }
    }
}

@main
struct AggregatorApp: App {
    @State private var credentialsStore: CredentialsStore
    @State private var seenStore = ThreadSeenStore()
    @State private var listPreferences = ListPreferences()
    @State private var readStore = ArticleReadStore()
    @State private var deepLinkRouter = DeepLinkRouter()

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
                .environment(deepLinkRouter)
                .onOpenURL { url in
                    deepLinkRouter.handle(url)
                }
        }
    }
}

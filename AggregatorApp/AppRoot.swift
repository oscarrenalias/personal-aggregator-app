import SwiftUI

struct AppRoot: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.horizontalSizeClass) var hSizeClass
    @State private var selectedTab = "threads"

    var body: some View {
        if hSizeClass == .regular {
            AppRootIPad()
        } else {
        TabView(selection: $selectedTab) {
            Tab("Threads", systemImage: "rectangle.stack", value: "threads") {
                ThreadsView()
            }
            Tab("Sources", systemImage: "antenna.radiowaves.left.and.right", value: "sources") {
                SourcesView()
            }
            Tab("Today", systemImage: "calendar", value: "today") {
                TodayView()
            }
            Tab("Podcasts", systemImage: "headphones", value: "podcasts") {
                PodcastsView()
            }
            Tab("Settings", systemImage: "gearshape", value: "settings") {
                SettingsView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: "search", role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.pendingLink) { _, link in
            guard link != nil else { return }
            selectedTab = "threads"
        }
        }
    }
}

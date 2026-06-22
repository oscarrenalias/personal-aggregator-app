import SwiftUI

struct AppRoot: View {
    @Environment(DeepLinkRouter.self) private var router
    @State private var selectedTab = "threads"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Threads", systemImage: "rectangle.stack", value: "threads") {
                ThreadsView()
            }
            Tab("Sources", systemImage: "antenna.radiowaves.left.and.right", value: "sources") {
                SourcesView()
            }
            Tab("Today", systemImage: "sparkles", value: "today") {
                TodayView()
            }
            Tab("Settings", systemImage: "gearshape", value: "settings") {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.pendingLink) { _, link in
            guard link != nil else { return }
            selectedTab = "threads"
        }
    }
}

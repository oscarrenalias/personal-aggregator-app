import SwiftUI
import UIKit

struct AppRootIPad: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } content: {
            sectionContent
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            Text("Select an item")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            updateColumnVisibility()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateColumnVisibility()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch navigationModel.selectedSection {
        case .threads:
            ThreadsIPadView()
        case .today:
            TodayIPadView()
        case .podcasts:
            PodcastsIPadView()
        case .sources:
            SourcesIPadView()
        case .search:
            SearchIPadView()
        case .settings:
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("Settings panel coming soon.")
            )
        }
    }

    private func updateColumnVisibility() {
        let bounds = UIScreen.main.bounds
        let isPortrait = bounds.width < bounds.height
        columnVisibility = isPortrait ? .doubleColumn : .all
    }
}

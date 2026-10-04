import SwiftUI
import UIKit

struct AppRootIPad: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Text("Sidebar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Menu")
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } content: {
            Text("Section List")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Content")
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            Text("Detail")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Detail")
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

    private func updateColumnVisibility() {
        let bounds = UIScreen.main.bounds
        let isPortrait = bounds.width < bounds.height
        columnVisibility = isPortrait ? .doubleColumn : .all
    }
}

import SwiftUI

struct AppRoot: View {
    var body: some View {
        TabView {
            Tab("Threads", systemImage: "rectangle.stack") {
                ThreadsView()
            }
            Tab("Sources", systemImage: "antenna.radiowaves.left.and.right") {
                SourcesView()
            }
            Tab("Today", systemImage: "sparkles") {
                TodayView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

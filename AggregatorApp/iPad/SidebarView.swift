import SwiftUI

private extension AppSection {
    var label: String {
        switch self {
        case .threads:  "Threads"
        case .sources:  "Sources"
        case .today:    "Today"
        case .podcasts: "Podcasts"
        case .search:   "Search"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .threads:  "rectangle.stack"
        case .sources:  "antenna.radiowaves.left.and.right"
        case .today:    "calendar"
        case .podcasts: "headphones"
        case .search:   "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel

    var body: some View {
        @Bindable var nav = navigationModel
        let selection = Binding<AppSection?>(
            get: { nav.selectedSection },
            set: { nav.selectedSection = $0 ?? .threads }
        )
        List(AppSection.allCases, selection: selection) { section in
            Label(section.label, systemImage: section.systemImage)
                .tag(section)
                .accessibilityLabel(section.label)
        }
        .navigationTitle("Menu")
    }
}

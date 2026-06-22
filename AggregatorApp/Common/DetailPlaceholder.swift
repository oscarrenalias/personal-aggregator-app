import SwiftUI

/// Placeholder shown in the detail column of a two-pane (`NavigationSplitView`)
/// layout when nothing is selected yet. Only appears at regular width
/// (iPad/Mac); the compact iPhone layout pushes detail views instead.
struct DetailPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Nothing Selected",
            systemImage: "sidebar.right",
            description: Text("Choose an item from the list to read it here.")
        )
    }
}

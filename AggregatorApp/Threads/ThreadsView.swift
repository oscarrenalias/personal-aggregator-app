import SwiftUI

struct ThreadsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Threads",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Coming soon")
            )
            .navigationTitle("Threads")
        }
    }
}

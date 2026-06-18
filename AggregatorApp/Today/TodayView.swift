import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Today",
                systemImage: "sparkles",
                description: Text("Coming soon")
            )
            .navigationTitle("Today")
        }
    }
}

import SwiftUI
import WidgetKit

// MARK: - Default background

/// Dark-navy radar background rendered when an entry carries no hero image URL.
/// Used as the containerBackground fallback in both small and medium widget layouts.
struct RadarDefaultBackground: View {
    var body: some View {
        Image("RadarDefault")
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Widget layout views
// SmallWidgetView, MediumWidgetView, and state views are added by downstream beads.

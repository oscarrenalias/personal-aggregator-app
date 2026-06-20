import SwiftUI

struct SourceActivityDot: View {
    let source: Source

    var body: some View {
        if source.hasPriority {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel("Important updates")
        } else if source.hasNew {
            Circle()
                .fill(Color.secondary)
                .frame(width: 8, height: 8)
                .accessibilityLabel("New updates")
        } else {
            EmptyView()
        }
    }
}

#Preview("Priority") {
    SourceActivityDot(source: Source(id: 1, name: "Test", feedURL: "https://example.com", hasNew: true, hasPriority: true))
        .padding()
}

#Preview("New only") {
    SourceActivityDot(source: Source(id: 2, name: "Test", feedURL: "https://example.com", hasNew: true, hasPriority: false))
        .padding()
}

#Preview("Neither") {
    SourceActivityDot(source: Source(id: 3, name: "Test", feedURL: "https://example.com", hasNew: false, hasPriority: false))
        .padding()
}

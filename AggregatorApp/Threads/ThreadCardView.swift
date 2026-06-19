import SwiftUI

struct ThreadCardView: View {
    let thread: Thread

    @Environment(ThreadSeenStore.self) private var seenStore

    private var metaCaption: String {
        let sources = thread.sourceCount == 1 ? "1 source" : "\(thread.sourceCount) sources"
        let articles = thread.memberCount == 1 ? "1 article" : "\(thread.memberCount) articles"
        let date = DateDisplay.relative(thread.lastUpdated)
        return "\(sources) · \(articles) · \(date)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Meta line
                HStack(spacing: 4) {
                    if seenStore.hasUnseenUpdate(thread) {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Has updates")
                    }
                    Text(metaCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Text(thread.representativeTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = thread.rollingSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageURLString = thread.imageURL, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.secondary.opacity(0.2)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .listRowBackground(Color.clear)
    }
}

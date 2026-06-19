import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title ?? "")
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(article.isRead ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let score = article.importanceScore {
                    importancePill(score: score)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
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
                .accessibilityHidden(true)
            }
        }
        .listRowBackground(Color.clear)
    }

    private var caption: String {
        var parts: [String] = []
        if let name = article.sourceName { parts.append(name) }
        let date = DateDisplay.relative(article.feedPublishedAt)
        if !date.isEmpty { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func importancePill(score: Int) -> some View {
        Text(score >= 80 ? "High importance" : score >= 50 ? "Medium importance" : "Low importance")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(score >= 80 ? Color.red : score >= 50 ? Color.orange : Color.secondary)
            .clipShape(Capsule())
            .accessibilityLabel("Importance score: \(score)")
    }
}

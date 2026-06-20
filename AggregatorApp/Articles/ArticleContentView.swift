import SwiftUI

/// Pure, stateless article content: hero, title, byline, importance badge,
/// chips, AI summary, and body.
///
/// It performs no networking and holds no state, so it renders instantly from an
/// already-loaded `Article`. Both the standalone reader (`ArticleDetailView`)
/// and the paged reader (`ArticlePagerView`) embed it and own their own chrome
/// (toolbar, read/save sync, Safari). Keeping pages stateless is what makes
/// swiping in the pager smooth — each page paints immediately with no fetch.
struct ArticleContentView: View {
    let article: Article
    /// Invoked by the "Open original" fallback shown when there is no reader text.
    var onOpenOriginal: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // (1) Hero image — renders when imageURL is present.
                // The size is dictated by a fixed-size container and the image is
                // a clipped overlay, so `scaledToFill` cannot overflow and force
                // the content column wider than the screen (which would crop text).
                if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                    // Rectangle (not Color) for the base: Color ignores the safe
                    // area and would push the hero up under the nav bar.
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .overlay {
                            AsyncImage(url: imageURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                }
                            }
                        }
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 14) {
                    // (2) Title
                    if let title = article.title {
                        Text(title)
                            .font(.title2.bold())
                    }

                    // (3) Byline — missing pieces omitted gracefully
                    let bylineText = byline(for: article)
                    if !bylineText.isEmpty {
                        Text(bylineText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // (4) Importance badge
                    if let score = article.importanceScore {
                        importanceBadge(score: score, reason: article.importanceReason)
                    }

                    // (5) Topic/category chips in wrapping layout
                    let chips = (article.topics + article.categories).filter { !$0.isEmpty }
                    if !chips.isEmpty {
                        ChipFlowLayout(items: chips)
                    }

                    // (6) Summary as glass callout block
                    if let summary = article.summary, !summary.isEmpty {
                        ParagraphText(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // (7) Full article text or unavailable fallback with Open original.
                    // SelectableText (UITextView) gives word/range selection + the
                    // system Look Up / Define / Translate menu, unlike SwiftUI Text.
                    if let cleanText = article.cleanText, !cleanText.isEmpty {
                        SelectableText(cleanText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No reader text",
                                systemImage: "doc.text",
                                description: Text("The full article text is not available.")
                            )
                            if article.url != nil, let onOpenOriginal {
                                Button("Open original") { onOpenOriginal() }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(.horizontal, ReaderLayout.hPadding)
                .padding(.vertical)
            }
        }
    }

    @ViewBuilder
    private func importanceBadge(score: Int, reason: String?) -> some View {
        Text(score >= 80 ? "High importance" : score >= 50 ? "Medium importance" : "Low importance")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(score >= 80 ? Color.red : score >= 50 ? Color.orange : Color.secondary)
            .clipShape(Capsule())
            .accessibilityLabel(reason.map { "Importance \(score): \($0)" } ?? "Importance score: \(score)")
    }

    private func byline(for article: Article) -> String {
        var parts: [String] = []
        if let author = article.author { parts.append(author) }
        if let name = article.sourceName { parts.append(name) }
        let date = DateDisplay.relative(article.feedPublishedAt)
        if !date.isEmpty { parts.append(date) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Chip flow layout

private struct ChipFlowLayout: View {
    let items: [String]

    var body: some View {
        ChipFlow(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
            }
        }
    }
}

private struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var height: CGFloat = 0
        var rowX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > maxWidth, rowX > 0 {
                height += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

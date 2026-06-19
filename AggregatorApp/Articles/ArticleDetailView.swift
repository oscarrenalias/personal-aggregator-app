import SwiftUI

struct ArticleDetailView: View {
    let articleId: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var article: Article? = nil
    @State private var loadError: Error? = nil
    @State private var isRead = false
    @State private var isSaved = false
    @State private var showSafari = false

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        Group {
            if let error = loadError {
                errorView(error)
            } else if let article {
                articleContent(article)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(article?.title ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await toggleSaved() }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Unsave article" : "Save article")

                Button {
                    Task { await toggleRead() }
                } label: {
                    Image(systemName: isRead ? "circle.fill" : "circle")
                }
                .accessibilityLabel(isRead ? "Mark as unread" : "Mark as read")

                Button {
                    showSafari = true
                } label: {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Open original in browser")
                .disabled(article?.url == nil)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let urlString = article?.url, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
        .task {
            await loadArticle()
        }
    }

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadArticle() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func articleContent(_ article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // (1) Hero image — code path is live, activates when imageURL becomes non-nil
                if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.secondary.opacity(0.15)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
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
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // (7) Full article text or unavailable fallback with Open original
                    if let cleanText = article.cleanText, !cleanText.isEmpty {
                        Text(cleanText)
                            .font(.body)
                    } else {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No reader text",
                                systemImage: "doc.text",
                                description: Text("The full article text is not available.")
                            )
                            if article.url != nil {
                                Button("Open original") {
                                    showSafari = true
                                }
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

    private func loadArticle() async {
        article = nil
        loadError = nil
        do {
            let fetched = try await apiClient.getArticle(id: articleId)
            article = fetched
            isRead = fetched.isRead
            isSaved = fetched.isSaved
            // Auto-mark read on first view; swallow the error so it doesn't block display
            if !fetched.isRead {
                try? await apiClient.markArticleRead(id: articleId)
                isRead = true
            }
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
    }

    private func toggleRead() async {
        let previous = isRead
        isRead = !previous  // optimistic
        do {
            if previous {
                try await apiClient.markArticleUnread(id: articleId)
            } else {
                try await apiClient.markArticleRead(id: articleId)
            }
        } catch {
            isRead = previous  // revert on failure
        }
    }

    private func toggleSaved() async {
        let previous = isSaved
        isSaved = !previous  // optimistic
        do {
            if previous {
                try await apiClient.unsaveArticle(id: articleId)
            } else {
                try await apiClient.saveArticle(id: articleId)
            }
        } catch {
            isSaved = previous  // revert on failure
        }
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

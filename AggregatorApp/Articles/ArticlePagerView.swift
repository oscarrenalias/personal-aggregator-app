import SwiftUI

/// Horizontally paged reader over an already-loaded slice of articles.
///
/// Each page is a stateless `ArticleContentView` rendered from preloaded data
/// (no per-page network fetch), so swiping is smooth. A single toolbar lives on
/// the pager (not per page), reflecting the currently-selected article — this
/// avoids the duplicate toolbar that appears when each paged view contributes
/// its own. Read state syncs through the shared `ArticleReadStore`; the visible
/// article is auto-marked read on the backend when it becomes selected.
struct ArticlePagerView: View {
    let articles: [Article]
    let startIndex: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ArticleReadStore.self) private var readStore
    @State private var selectedIndex: Int
    @State private var savedOverrides: [Int: Bool] = [:]
    @State private var safariURL: URL?
    @State private var showSafari = false
    @State private var autoMarked: Set<Int> = []

    init(articles: [Article], startIndex: Int) {
        self.articles = articles
        self.startIndex = startIndex
        self._selectedIndex = State(initialValue: startIndex)
    }

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    /// Currently-visible article. `articles` is always non-empty here (the pager
    /// is only pushed from a tapped list row); the index is clamped defensively.
    private var current: Article {
        let i = min(max(selectedIndex, 0), articles.count - 1)
        return articles[i]
    }

    // ShareLink requires a non-optional URL; this placeholder is only used when the button is disabled.
    private var currentShareURL: URL {
        guard let s = current.url, let url = URL(string: s) else { return URL(string: "https://example.com")! }
        return url
    }

    private func isRead(_ a: Article) -> Bool { readStore.isRead(id: a.id, fetched: a.isRead) }
    private func isSaved(_ a: Article) -> Bool { savedOverrides[a.id] ?? a.isSaved }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                ArticleContentView(article: article, onOpenOriginal: { openOriginal(article) })
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(current.title ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await toggleSaved(current) }
                } label: {
                    Image(systemName: isSaved(current) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved(current) ? "Unsave article" : "Save article")

                Button {
                    Task { await toggleRead(current) }
                } label: {
                    Image(systemName: isRead(current) ? "checkmark.circle.fill" : "circle")
                }
                .accessibilityLabel(isRead(current) ? "Mark as unread" : "Mark as read")

                ShareLink(item: currentShareURL, subject: Text(current.title ?? ""))
                    .disabled(current.url == nil)

                Button {
                    openOriginal(current)
                } label: {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Open original in browser")
                .disabled(current.url == nil)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
        .task { await autoMarkRead(current) }
        .onChange(of: selectedIndex) { _, _ in
            Task { await autoMarkRead(current) }
        }
    }

    private func openOriginal(_ a: Article) {
        guard let urlString = a.url, let url = URL(string: urlString) else { return }
        safariURL = url
        showSafari = true
    }

    /// Marks the visible article read on the backend, once, on selection. Only
    /// reflects "read" when the write succeeds so the UI matches the server.
    private func autoMarkRead(_ a: Article) async {
        guard !autoMarked.contains(a.id) else { return }
        guard !readStore.isRead(id: a.id, fetched: a.isRead) else { autoMarked.insert(a.id); return }
        autoMarked.insert(a.id)
        do {
            try await apiClient.markArticleRead(id: a.id)
            readStore.markRead(a.id)
        } catch {
            autoMarked.remove(a.id)
        }
    }

    private func toggleRead(_ a: Article) async {
        let previous = readStore.isRead(id: a.id, fetched: a.isRead)
        if previous { readStore.markUnread(a.id) } else { readStore.markRead(a.id) }
        do {
            if previous {
                try await apiClient.markArticleUnread(id: a.id)
            } else {
                try await apiClient.markArticleRead(id: a.id)
            }
        } catch {
            if previous { readStore.markRead(a.id) } else { readStore.markUnread(a.id) }
        }
    }

    private func toggleSaved(_ a: Article) async {
        let previous = isSaved(a)
        savedOverrides[a.id] = !previous  // optimistic
        do {
            if previous {
                try await apiClient.unsaveArticle(id: a.id)
            } else {
                try await apiClient.saveArticle(id: a.id)
            }
        } catch {
            savedOverrides[a.id] = previous  // revert on failure
        }
    }
}

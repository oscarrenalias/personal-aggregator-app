import SwiftUI
import UIKit

/// Horizontally paged reader over an already-loaded slice of articles.
///
/// Each page is a stateless `ArticleContentView` rendered from preloaded data
/// (no per-page network fetch), so swiping is smooth. A single toolbar lives on
/// the pager (not per page), reflecting the currently-selected article — this
/// avoids the duplicate toolbar that appears when each paged view contributes
/// its own. Read state syncs through the shared `ArticleReadStore`; the visible
/// article is auto-marked read on the backend when it becomes selected.
///
/// Paging uses a horizontal `ScrollView` with `.scrollTargetBehavior(.paging)`
/// rather than a `.page`-style `TabView`: the TabView (a `UIPageViewController`)
/// insets its pages below the status bar, which left a strip above the hero. A
/// plain ScrollView lets each page's hero bleed to the very top like the
/// standalone reader does.
struct ArticlePagerView: View {
    let articles: [Article]
    let startIndex: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ArticleReadStore.self) private var readStore
    // Bound to the scroll position; identifies the currently-centered page.
    @State private var currentID: Int?
    @State private var savedOverrides: [Int: Bool] = [:]
    // Single item-driven Safari sheet for "open original" / "open comments".
    @State private var safariURL: SafariURL?
    @State private var autoMarked: Set<Int> = []

    init(articles: [Article], startIndex: Int) {
        self.articles = articles
        self.startIndex = startIndex
        self._currentID = State(initialValue: startIndex)
    }

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    /// Currently-visible article. `articles` is always non-empty here (the pager
    /// is only pushed from a tapped list row); the index is clamped defensively.
    private var current: Article {
        let i = min(max(currentID ?? startIndex, 0), articles.count - 1)
        return articles[i]
    }

    // ShareLink requires a non-optional URL; this placeholder is only used when the button is disabled.
    private var currentShareURL: URL {
        guard let s = current.url, let url = URL(string: s) else { return URL(string: "https://example.com")! }
        return url
    }

    private func isRead(_ a: Article) -> Bool { readStore.isRead(id: a.id, fetched: a.isRead) }
    private func isSaved(_ a: Article) -> Bool { savedOverrides[a.id] ?? a.isSaved }

    /// Bleed under the bars only when the page has a hero image; otherwise the
    /// title would be hidden behind the floating toolbar. Mirrors the standalone
    /// reader (`ArticleDetailView`) — letting the system inset hero-less content
    /// below the bar instead of fighting it with a hand-computed spacer.
    private func bleedRegions(_ a: Article) -> SafeAreaRegions {
        (a.imageURL.flatMap { URL(string: $0) } != nil) ? .all : []
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                    ArticleContentView(
                        article: article,
                        onOpenOriginal: { openOriginal(article) }
                    )
                    .ignoresSafeArea(bleedRegions(article), edges: .top)
                    // Size only the paging axis. Forcing `.vertical` too pins each
                    // page to the scroll view's full (bleeding) height, which
                    // collapses the page's top safe-area inset and clips the title.
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        // No navigationTitle: the title is shown once, below the hero in the
        // content, rather than duplicated as an inline title over the image.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
        }
        .task { await autoMarkRead(current) }
        .onChange(of: currentID) { _, _ in
            Task { await autoMarkRead(current) }
        }
    }

    // Toolbar extracted into its own ToolbarContentBuilder member so the body
    // expression stays small (keeps the type-checker fast and avoids the
    // pathological compile/runtime behaviour seen with large inline toolbars).
    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
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

            // Shown only when the article has a comments URL (backend comments_url).
            if current.commentsURL != nil {
                Button {
                    openComments(current)
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Open comments")
            }
        }
    }

    private func openOriginal(_ a: Article) {
        safariURL = SafariURL(a.url)
    }

    private func openComments(_ a: Article) {
        safariURL = SafariURL(a.commentsURL)
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

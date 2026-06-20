import SwiftUI

struct ArticleDetailView: View {
    let articleId: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ArticleReadStore.self) private var readStore
    @State private var article: Article? = nil
    @State private var loadError: Error? = nil
    @State private var isRead = false
    @State private var isSaved = false
    @State private var showSafari = false
    @State private var showCommentsSafari = false

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    private var shareURL: URL {
        guard let a = article, let urlString = a.url, let url = URL(string: urlString) else {
            return URL(string: "about:blank")!
        }
        return url
    }

    var body: some View {
        Group {
            if let error = loadError {
                errorView(error)
            } else if let article {
                ArticleContentView(article: article, onOpenOriginal: { showSafari = true })
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(article?.title ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
        .sheet(isPresented: $showSafari) {
            if let urlString = article?.url, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showCommentsSafari) {
            if let urlString = article?.commentsURL, let url = URL(string: urlString) {
                SafariView(url: url)
            }
        }
        .task {
            await loadArticle()
        }
    }

    // Toolbar extracted into its own ToolbarContentBuilder member so the body
    // expression stays small (keeps the type-checker fast and avoids the
    // pathological compile/runtime behaviour seen with large inline toolbars).
    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
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
                Image(systemName: effectiveIsRead ? "checkmark.circle.fill" : "circle")
            }
            .accessibilityLabel(effectiveIsRead ? "Mark as unread" : "Mark as read")

            Button {
                showSafari = true
            } label: {
                Image(systemName: "safari")
            }
            .accessibilityLabel("Open original in browser")
            .disabled(article?.url == nil)

            ShareLink(item: shareURL, subject: Text(article?.title ?? "")) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share article")
            .disabled(article?.url == nil)

            // Shown only when the article has a comments URL (backend comments_url).
            if article?.commentsURL != nil {
                Button {
                    showCommentsSafari = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Open comments")
            }
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

    private func loadArticle() async {
        article = nil
        loadError = nil
        do {
            let fetched = try await apiClient.getArticle(id: articleId)
            article = fetched
            isRead = readStore.isRead(id: articleId, fetched: fetched.isRead)
            isSaved = fetched.isSaved
            // Auto-mark read on first view. Only reflect "read" if the backend
            // write succeeds, so the UI never claims a state the server lacks.
            if !isRead {
                do {
                    try await apiClient.markArticleRead(id: articleId)
                    isRead = true
                    readStore.markRead(articleId)
                } catch {
                    // Leave unread on failure; the dot stays so state matches the server.
                }
            }
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
    }

    /// Read state derived from the observable store (preferred) falling back to
    /// the fetched value. Reading the store here keeps the toolbar indicator
    /// reactive even when hosted in the paged reader, where local @State changes
    /// don't reliably re-render the lifted navigation-bar toolbar.
    private var effectiveIsRead: Bool {
        readStore.isRead(id: articleId, fetched: article?.isRead ?? isRead)
    }

    private func toggleRead() async {
        let previous = effectiveIsRead
        // Optimistically reflect the new state in the store so the toolbar updates.
        if previous { readStore.markUnread(articleId) } else { readStore.markRead(articleId) }
        isRead = !previous
        do {
            if previous {
                try await apiClient.markArticleUnread(id: articleId)
            } else {
                try await apiClient.markArticleRead(id: articleId)
            }
        } catch {
            // Revert both store and local state on failure.
            if previous { readStore.markRead(articleId) } else { readStore.markUnread(articleId) }
            isRead = previous
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

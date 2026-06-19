import SwiftUI

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct ArticleListView: View {
    let feed: ArticleFeed

    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var articles: [Article] = []
    @State private var nextCursor: String? = nil
    @State private var sort: ArticleSort = .importance
    @State private var unreadOnly: Bool = false
    @State private var phase: LoadPhase = .loading
    @State private var isLoadingMore: Bool = false

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let error):
                VStack(spacing: 16) {
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadFirstPage() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                if articles.isEmpty {
                    ContentUnavailableView(
                        "No articles",
                        systemImage: "newspaper",
                        description: Text("No articles found for this feed.")
                    )
                } else {
                    articleList
                }
            }
        }
        .navigationTitle(feed.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("By Importance").tag(ArticleSort.importance)
                        Text("Recent").tag(ArticleSort.recent)
                    }
                    if feed.allowsUnreadFilter {
                        Toggle("Unread Only", isOn: $unreadOnly)
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            await loadFirstPage()
        }
        .onChange(of: sort) {
            Task { await loadFirstPage() }
        }
        .onChange(of: unreadOnly) {
            Task { await loadFirstPage() }
        }
    }

    private var articleList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: index) {
                        ArticleRowView(article: article)
                    }
                    .listRowBackground(Color.clear)
                    .onAppear {
                        if index == articles.count - 1 {
                            Task { await loadNextPage() }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Int.self) { index in
            ArticlePagerView(articles: articles, startIndex: index)
        }
        .refreshable {
            await loadFirstPage(showSpinner: false)
        }
    }

    private func loadFirstPage(showSpinner: Bool = true) async {
        if showSpinner {
            phase = .loading
            articles = []
        }
        nextCursor = nil
        do {
            let response = try await apiClient.getArticles(
                feed: feed,
                sort: sort,
                unreadOnly: unreadOnly,
                limit: 15,
                cursor: nil
            )
            articles = response.items
            nextCursor = response.nextCursor
            phase = .loaded
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }

    private func loadNextPage() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await apiClient.getArticles(
                feed: feed,
                sort: sort,
                unreadOnly: unreadOnly,
                limit: 15,
                cursor: cursor
            )
            articles.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            // Silent failure on next-page errors; user can scroll back to trigger another attempt
        }
    }
}

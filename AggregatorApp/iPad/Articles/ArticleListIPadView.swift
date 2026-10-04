import SwiftUI

/// Article list for the iPad content column.
/// In landscape: tapping a row sets navigationModel.selectedArticle so the detail column reacts.
/// In portrait: wraps the list in a NavigationStack and uses NavigationLink to push ArticleDetailView.
struct ArticleListIPadView: View {
    let feed: ArticleFeed

    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ListPreferences.self) private var listPreferences

    @State private var articles: [Article] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isLoadingMore = false
    @State private var isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    private enum LoadPhase { case loading, loaded, error(Error) }

    var body: some View {
        Group {
            if isPortrait {
                NavigationStack {
                    listContent
                        .navigationTitle(feed.title)
                }
            } else {
                listContent
                    .navigationTitle(feed.title)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                @Bindable var prefs = listPreferences
                Menu {
                    Picker("Sort", selection: $prefs.articlesSort) {
                        Text("By Importance").tag(ArticleSort.importance)
                        Text("Recent").tag(ArticleSort.recent)
                    }
                    if feed.allowsUnreadFilter {
                        Toggle("Unread Only", isOn: $prefs.articlesUnreadOnly)
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await loadFirstPage() }
        .onChange(of: feed) { Task { await loadFirstPage() } }
        .onChange(of: listPreferences.articlesSort) { Task { await loadFirstPage() } }
        .onChange(of: listPreferences.articlesUnreadOnly) { Task { await loadFirstPage() } }
    }

    @ViewBuilder
    private var listContent: some View {
        switch phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let error):
            VStack(spacing: 16) {
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await loadFirstPage() } }
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

    private var articleList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    articleRow(article: article, index: index)
                        .listRowBackground(
                            navigationModel.selectedArticle?.id == article.id && !isPortrait
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .onAppear {
                            if index == articles.count - 1 {
                                Task { await loadNextPage() }
                            }
                        }
                }
                if isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func articleRow(article: Article, index: Int) -> some View {
        if isPortrait {
            NavigationLink {
                ArticleDetailView(articleId: article.id)
            } label: {
                ArticleRowView(article: article)
            }
            .accessibilityLabel(article.title ?? "Article")
        } else {
            Button {
                navigationModel.selectedArticle = article
            } label: {
                ArticleRowView(article: article)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(article.title ?? "Article")
        }
    }

    private func loadFirstPage() async {
        phase = .loading
        articles = []
        nextCursor = nil
        do {
            let response = try await apiClient.getArticles(
                feed: feed,
                sort: listPreferences.articlesSort,
                unreadOnly: listPreferences.articlesUnreadOnly
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
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await apiClient.getArticles(
                feed: feed,
                sort: listPreferences.articlesSort,
                unreadOnly: listPreferences.articlesUnreadOnly,
                cursor: cursor
            )
            articles.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            if isCancellation(error) { return }
        }
    }
}

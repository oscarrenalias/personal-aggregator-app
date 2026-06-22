import SwiftUI

struct SourcesView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(\.horizontalSizeClass) private var hSizeClass
    // nil = not yet fetched (loading); [] = loaded empty; non-empty = loaded
    @State private var sources: [Source]? = nil
    @State private var loadError: Error? = nil
    @State private var categories: [Category] = []
    @State private var categoriesError: Error? = nil
    @State private var selectedFeed: ArticleFeed?      // regular-only detail selection

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        Group {
            if hSizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
        }
        .task {
            if credentialsStore.isConfigured {
                await loadAll()
            }
        }
    }

    // MARK: - Compact (iPhone): unchanged push navigation

    private var compactBody: some View {
        NavigationStack {
            stateContent { compactSourceList }
                .navigationTitle("Sources")
        }
    }

    // MARK: - Regular (iPad/Mac): two-pane master-detail

    private var regularBody: some View {
        NavigationSplitView {
            stateContent { sidebarSourceList }
                .navigationTitle("Sources")
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            NavigationStack {
                if let feed = selectedFeed {
                    // `.id(feed)` gives each feed a fresh identity so ArticleListView's
                    // LoadOnceGate/.task reloads when the selection changes.
                    ArticleListView(feed: feed).id(feed)
                } else {
                    DetailPlaceholder()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Shared state handling

    @ViewBuilder
    private func stateContent<L: View>(@ViewBuilder list: () -> L) -> some View {
        if !credentialsStore.isConfigured {
            ContentUnavailableView(
                "Not configured",
                systemImage: "gearshape",
                description: Text("Enter your server credentials in Settings.")
            )
        } else if let error = loadError {
            VStack(spacing: 16) {
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadAll() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sources != nil {
            list()
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Lists

    /// Compact list: rows push the article list via destination-based links.
    private var compactSourceList: some View {
        GlassEffectContainer {
            List {
                Section("Feeds") {
                    ForEach([ArticleFeed.important, .unread, .saved], id: \.id) { feed in
                        NavigationLink(destination: ArticleListView(feed: feed)) {
                            feedLabel(feed)
                        }
                        .accessibilityLabel("\(feed.title) articles")
                        .listRowBackground(Color.clear)
                    }
                }
                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            NavigationLink(destination: ArticleListView(feed: .category(name: category.name))) {
                                categoryLabel(category)
                            }
                            .accessibilityLabel(category.name)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                let loaded = sources ?? []
                if !loaded.isEmpty {
                    Section("Sources") {
                        ForEach(loaded) { source in
                            NavigationLink(destination: ArticleListView(feed: .source(id: source.id, name: source.name))) {
                                sourceLabel(source)
                            }
                            .accessibilityLabel(sourceAccessibility(source))
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .refreshable {
                await loadAll()
            }
        }
    }

    /// Regular sidebar: selection drives the detail column.
    private var sidebarSourceList: some View {
        GlassEffectContainer {
            List(selection: $selectedFeed) {
                Section("Feeds") {
                    ForEach([ArticleFeed.important, .unread, .saved], id: \.id) { feed in
                        feedLabel(feed)
                            .tag(feed)
                            .accessibilityLabel("\(feed.title) articles")
                            .listRowBackground(Color.clear)
                    }
                }
                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            categoryLabel(category)
                                .tag(ArticleFeed.category(name: category.name))
                                .accessibilityLabel(category.name)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                let loaded = sources ?? []
                if !loaded.isEmpty {
                    Section("Sources") {
                        ForEach(loaded) { source in
                            sourceLabel(source)
                                .tag(ArticleFeed.source(id: source.id, name: source.name))
                                .accessibilityLabel(sourceAccessibility(source))
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .refreshable {
                await loadAll()
            }
        }
    }

    // MARK: - Shared row labels

    private func feedLabel(_ feed: ArticleFeed) -> some View {
        Label(feed.title, systemImage: feed.systemImage ?? "tray")
    }

    private func categoryLabel(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(category.name, systemImage: "tag")
                .font(.body)
            if let phrase = category.freshnessPhrase() {
                Text(phrase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sourceLabel(_ source: Source) -> some View {
        HStack {
            SourceFaviconView(feedURL: source.feedURL)
            Text(source.name)
                .font(.body)
            Spacer()
            SourceActivityDot(source: source)
        }
    }

    private func sourceAccessibility(_ source: Source) -> String {
        source.hasPriority ? "\(source.name), important updates" :
        source.hasNew ? "\(source.name), new updates" :
        source.name
    }

    // MARK: - Data

    private func loadAll() async {
        sources = nil
        loadError = nil
        categoriesError = nil
        categories = []

        async let fetchSources = apiClient.getSources()
        async let fetchCategories = apiClient.getCategories()

        // Await categories first (non-fatal: failure shows no Categories section)
        do {
            categories = try await fetchCategories
        } catch {
            if isCancellation(error) { return }
            categoriesError = error
        }

        // Await sources (fatal: failure shows full-tab error view)
        do {
            sources = try await fetchSources
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
    }
}

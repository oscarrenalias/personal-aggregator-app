import SwiftUI

struct SourcesView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    // nil = not yet fetched (loading); [] = loaded empty; non-empty = loaded
    @State private var sources: [Source]? = nil
    @State private var loadError: Error? = nil
    @State private var categories: [Category] = []
    @State private var categoriesError: Error? = nil

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        NavigationStack {
            Group {
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
                } else if let loaded = sources {
                    GlassEffectContainer {
                        List {
                            Section("Feeds") {
                                NavigationLink(destination: ArticleListView(feed: .important)) {
                                    Label("Important", systemImage: "exclamationmark.circle")
                                }
                                .accessibilityLabel("Important articles")
                                .listRowBackground(Color.clear)
                                NavigationLink(destination: ArticleListView(feed: .unread)) {
                                    Label("Unread", systemImage: "envelope.badge")
                                }
                                .accessibilityLabel("Unread articles")
                                .listRowBackground(Color.clear)
                                NavigationLink(destination: ArticleListView(feed: .saved)) {
                                    Label("Saved", systemImage: "bookmark")
                                }
                                .accessibilityLabel("Saved articles")
                                .listRowBackground(Color.clear)
                            }
                            if !categories.isEmpty {
                                Section("Categories") {
                                    ForEach(categories) { category in
                                        NavigationLink(destination: ArticleListView(feed: .category(name: category.name))) {
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
                                        .accessibilityLabel(category.name)
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                            if !loaded.isEmpty {
                                Section("Sources") {
                                    ForEach(loaded) { source in
                                        NavigationLink(destination: ArticleListView(feed: .source(id: source.id, name: source.name))) {
                                            HStack {
                                                SourceFaviconView(feedURL: source.feedURL)
                                                Text(source.name)
                                                    .font(.body)
                                                Spacer()
                                                SourceActivityDot(source: source)
                                            }
                                        }
                                        .accessibilityLabel(
                                            source.hasPriority ? "\(source.name), important updates" :
                                            source.hasNew ? "\(source.name), new updates" :
                                            source.name
                                        )
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await loadAll()
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Sources")
        }
        .task {
            if credentialsStore.isConfigured {
                await loadAll()
            }
        }
    }

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

import SwiftUI

struct SourcesView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    // nil = not yet fetched (loading); [] = loaded empty; non-empty = loaded
    @State private var sources: [Source]? = nil
    @State private var loadError: Error? = nil

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
                            Task { await loadSources() }
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
                            }
                            if !loaded.isEmpty {
                                Section("Sources") {
                                    ForEach(loaded) { source in
                                        NavigationLink(destination: ArticleListView(feed: .source(id: source.id, name: source.name))) {
                                            Text(source.name)
                                                .font(.body)
                                        }
                                        .accessibilityLabel(source.name)
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                        }
                        .refreshable {
                            await loadSources()
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
                await loadSources()
            }
        }
    }

    private func loadSources() async {
        sources = nil
        loadError = nil
        do {
            sources = try await apiClient.getSources()
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
    }
}

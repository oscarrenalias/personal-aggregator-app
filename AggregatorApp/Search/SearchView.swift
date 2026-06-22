import SwiftUI

private enum LoadPhase {
    case idle
    case loading
    case loaded
    case error(Error)
}

struct SearchView: View {
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var query = ""
    @State private var articles: [Article] = []
    @State private var nextCursor: String? = nil
    @State private var loadPhase: LoadPhase = .idle
    @State private var committedQuery = ""

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !credentialsStore.isConfigured {
                    ContentUnavailableView(
                        "Not Configured",
                        systemImage: "gearshape",
                        description: Text("Enter your server credentials in Settings.")
                    )
                } else {
                    switch loadPhase {
                    case .idle:
                        ContentUnavailableView(
                            "Search Articles",
                            systemImage: "magnifyingglass",
                            description: Text("Type to search for articles.")
                        )
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        if articles.isEmpty {
                            ContentUnavailableView.search(text: committedQuery)
                        } else {
                            resultsList
                        }
                    case .error(let error):
                        VStack(spacing: 16) {
                            Text(error.localizedDescription)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await runSearch(q: committedQuery) }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            committedQuery = trimmed
            Task { await runSearch(q: trimmed) }
        }
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                articles = []
                nextCursor = nil
                loadPhase = .idle
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            committedQuery = trimmed
            await runSearch(q: trimmed)
        }
    }

    private var resultsList: some View {
        GlassEffectContainer {
            List {
                // Article rows and pagination added in the next bead
            }
        }
    }

    private func runSearch(q: String) async {
        loadPhase = .loading
        articles = []
        nextCursor = nil
        do {
            let response = try await apiClient.searchArticles(q: q)
            articles = response.items
            nextCursor = response.nextCursor
            loadPhase = .loaded
        } catch {
            if isCancellation(error) { return }
            loadPhase = .error(error)
        }
    }
}

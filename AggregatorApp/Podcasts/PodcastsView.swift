import SwiftUI

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct PodcastsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var episodes: [PodcastEpisode] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage: Bool = false
    @State private var loadGate = LoadOnceGate()

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        NavigationStack {
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
                    if !credentialsStore.isConfigured {
                        ContentUnavailableView(
                            "Not configured",
                            systemImage: "gearshape",
                            description: Text("Enter your server credentials in Settings.")
                        )
                    } else if episodes.isEmpty {
                        ContentUnavailableView(
                            "No episodes",
                            systemImage: "headphones"
                        )
                    } else {
                        episodeList
                    }
                }
            }
            .navigationTitle("Podcasts")
        }
        .task {
            guard loadGate.shouldLoad() else { return }
            guard credentialsStore.isConfigured else {
                phase = .loaded
                return
            }
            await loadFirstPage()
        }
    }

    private var episodeList: some View {
        GlassEffectContainer {
            List {
                ForEach(episodes) { episode in
                    NavigationLink {
                        PodcastPlayerView(episode: episode, credentialsStore: credentialsStore)
                    } label: {
                        PodcastEpisodeRowView(episode: episode)
                    }
                    .listRowBackground(Color.clear)
                    .onAppear {
                        if episode.id == episodes.last?.id {
                            Task { await loadNextPage() }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .refreshable {
            await loadFirstPage(showSpinner: false)
        }
    }

    private func loadFirstPage(showSpinner: Bool = true) async {
        if showSpinner {
            phase = .loading
            episodes = []
        }
        nextCursor = nil
        do {
            let response = try await apiClient.getPodcasts(cursor: nil, limit: 20)
            episodes = response.items
            nextCursor = response.nextCursor
            phase = .loaded
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }

    private func loadNextPage() async {
        guard !isFetchingNextPage, let cursor = nextCursor else { return }
        isFetchingNextPage = true
        defer { isFetchingNextPage = false }
        do {
            let response = try await apiClient.getPodcasts(cursor: cursor, limit: 20)
            episodes.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            // silent: user can scroll back and retry
        }
    }
}

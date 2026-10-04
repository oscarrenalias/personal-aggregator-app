import SwiftUI
import UIKit

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct PodcastsIPadView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var episodes: [PodcastEpisode] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage = false
    @State private var loadGate = LoadOnceGate()
    @State private var isPortrait = false
    @State private var portraitPath = NavigationPath()

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    var body: some View {
        Group {
            if isPortrait {
                NavigationStack(path: $portraitPath) {
                    listBody
                        .navigationTitle("Podcasts")
                        .navigationDestination(for: Int.self) { episodeId in
                            if let episode = episodes.first(where: { $0.id == episodeId }) {
                                PodcastPlayerView(episode: episode)
                            }
                        }
                }
            } else {
                listBody
                    .navigationTitle("Podcasts")
            }
        }
        .onAppear { updateOrientation() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateOrientation()
        }
        .task {
            guard loadGate.shouldLoad() else { return }
            guard credentialsStore.isConfigured else { phase = .loaded; return }
            await loadFirstPage()
        }
    }

    @ViewBuilder
    private var listBody: some View {
        if !credentialsStore.isConfigured {
            ContentUnavailableView(
                "Not configured",
                systemImage: "gearshape",
                description: Text("Enter your server credentials in Settings.")
            )
        } else {
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
                if episodes.isEmpty {
                    ContentUnavailableView("No episodes", systemImage: "headphones")
                } else {
                    episodeList
                }
            }
        }
    }

    private var episodeList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                    episodeRow(episode: episode, index: index)
                        .onAppear {
                            if index == episodes.count - 1 {
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

    @ViewBuilder
    private func episodeRow(episode: PodcastEpisode, index: Int) -> some View {
        if isPortrait {
            NavigationLink(value: episode.id) {
                PodcastEpisodeRowView(episode: episode)
            }
            .listRowBackground(Color.clear)
        } else {
            Button {
                navigationModel.selectedEpisode = episode
            } label: {
                PodcastEpisodeRowView(episode: episode)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                navigationModel.selectedEpisode?.id == episode.id
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .accessibilityLabel("Episode \(DateDisplay.mediumDate(episode.date))")
        }
    }

    private func updateOrientation() {
        isPortrait = iPadIsPortrait()
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

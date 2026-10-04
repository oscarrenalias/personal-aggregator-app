import SwiftUI
import UIKit

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
    case empty
}

struct TodayIPadView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var briefs: [Brief] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage = false
    @State private var isFallback = false
    @State private var loadGate = LoadOnceGate()
    @State private var isPortrait = iPadIsPortrait()

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    var body: some View {
        Group {
            if isPortrait {
                NavigationStack {
                    briefListPane(isPortrait: true)
                        .navigationTitle("Today")
                }
            } else {
                briefListPane(isPortrait: false)
                    .navigationTitle("Today")
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            isPortrait = iPadIsPortrait()
        }
        .task {
            guard loadGate.shouldLoad() else { return }
            guard credentialsStore.isConfigured else { phase = .loaded; return }
            await loadFirstPage()
        }
    }

    // MARK: - Shared list pane

    @ViewBuilder
    private func briefListPane(isPortrait: Bool) -> some View {
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

            case .empty:
                ContentUnavailableView(
                    "No briefs yet",
                    systemImage: "sparkles",
                    description: Text("Today's brief hasn't been generated yet.")
                )

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
                if briefs.isEmpty {
                    ContentUnavailableView(
                        "No briefs yet",
                        systemImage: "sparkles",
                        description: Text("Today's brief hasn't been generated yet.")
                    )
                } else {
                    GlassEffectContainer {
                        List {
                            ForEach(briefs) { brief in
                                if isPortrait {
                                    NavigationLink {
                                        BriefDetailView(brief: brief)
                                    } label: {
                                        BriefCardView(brief: brief, isLatest: brief.id == briefs.first?.id)
                                    }
                                    .listRowBackground(Color.clear)
                                    .onAppear { loadMoreIfNeeded(brief: brief) }
                                } else {
                                    Button {
                                        navigationModel.selectedBrief = brief
                                    } label: {
                                        BriefCardView(brief: brief, isLatest: brief.id == briefs.first?.id)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(
                                        navigationModel.selectedBrief?.id == brief.id
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                                    .accessibilityLabel(brief.headline ?? "Daily Brief")
                                    .onAppear { loadMoreIfNeeded(brief: brief) }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .refreshable { await loadFirstPage(showSpinner: false) }
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadMoreIfNeeded(brief: Brief) {
        if !isFallback, brief.id == briefs.last?.id {
            Task { await loadNextPage() }
        }
    }

    private func loadFirstPage(showSpinner: Bool = true) async {
        if showSpinner {
            phase = .loading
            briefs = []
        }
        nextCursor = nil
        isFallback = false
        do {
            let response = try await apiClient.getBriefs(cursor: nil, limit: 20)
            briefs = response.items
            nextCursor = response.nextCursor
            phase = briefs.isEmpty ? .empty : .loaded
        } catch APIError.http(status: 404) {
            await loadTodayBriefFallback()
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
            let response = try await apiClient.getBriefs(cursor: cursor, limit: 20)
            briefs.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            // silent: existing rows remain visible
        }
    }

    private func loadTodayBriefFallback() async {
        do {
            let brief = try await apiClient.getTodayBrief()
            briefs = [brief]
            nextCursor = nil
            isFallback = true
            phase = .loaded
        } catch APIError.http(status: 404) {
            phase = .empty
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }
}

import SwiftUI

struct TodayView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var briefs: [Brief] = []
    @State private var nextCursor: String? = nil
    @State private var phase: Phase = .loading
    @State private var isLoadingMore: Bool = false
    @State private var isFallback: Bool = false

    private enum Phase {
        case loading
        case loaded
        case error(Error)
        case empty
    }

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
                                Task { await loadBriefs() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        GlassEffectContainer {
                            List {
                                ForEach(briefs) { brief in
                                    NavigationLink(destination: BriefDetailView(brief: brief)) {
                                        BriefCardView(brief: brief, isLatest: brief.id == briefs.first?.id)
                                    }
                                    .listRowBackground(Color.clear)
                                    .onAppear {
                                        if !isFallback && brief.id == briefs.last?.id {
                                            Task { await loadMoreBriefs() }
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                        .refreshable {
                            await refreshBriefs()
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
        .task {
            if credentialsStore.isConfigured {
                await loadBriefs()
            }
        }
    }

    private func loadBriefs() async {
        phase = .loading
        isFallback = false
        do {
            let response = try await apiClient.getBriefs(limit: 20)
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

    private func refreshBriefs() async {
        isFallback = false
        nextCursor = nil
        do {
            let response = try await apiClient.getBriefs(limit: 20)
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

    private func loadMoreBriefs() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await apiClient.getBriefs(cursor: cursor, limit: 20)
            briefs.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            if isCancellation(error) { return }
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

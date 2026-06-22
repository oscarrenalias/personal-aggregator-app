import SwiftUI

struct TodayView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var briefs: [Brief] = []
    @State private var nextCursor: String? = nil
    @State private var phase: Phase = .loading
    @State private var isLoadingMore: Bool = false
    @State private var isFallback: Bool = false
    @State private var selectedBriefID: Brief.ID?      // regular-only detail selection

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
        Group {
            if hSizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
        }
        .task {
            if credentialsStore.isConfigured {
                await loadBriefs()
            }
        }
    }

    // MARK: - Compact (iPhone): unchanged push navigation

    private var compactBody: some View {
        NavigationStack {
            stateContent { compactBriefList }
                .navigationTitle("Today")
        }
    }

    // MARK: - Regular (iPad/Mac): two-pane master-detail

    private var regularBody: some View {
        NavigationSplitView {
            stateContent { sidebarBriefList }
                .navigationTitle("Today")
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            NavigationStack {
                if let id = selectedBriefID, let brief = briefs.first(where: { $0.id == id }) {
                    BriefDetailView(brief: brief, onRefresh: { await refreshBriefs() })
                        .id(brief.id)
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
                list()
            }
        }
    }

    // MARK: - Lists

    /// Compact list: rows push the brief detail via destination-based links.
    private var compactBriefList: some View {
        List {
            ForEach(briefs) { brief in
                NavigationLink(destination: BriefDetailView(brief: brief)) {
                    BriefCardView(brief: brief, isLatest: brief.id == briefs.first?.id)
                }
                .onAppear {
                    if !isFallback && brief.id == briefs.last?.id {
                        Task { await loadMoreBriefs() }
                    }
                }
            }
        }
        .refreshable {
            await refreshBriefs()
        }
    }

    /// Regular sidebar: selection drives the detail column.
    private var sidebarBriefList: some View {
        List(selection: $selectedBriefID) {
            ForEach(briefs) { brief in
                BriefCardView(brief: brief, isLatest: brief.id == briefs.first?.id)
                    .tag(brief.id)
                    .onAppear {
                        if !isFallback && brief.id == briefs.last?.id {
                            Task { await loadMoreBriefs() }
                        }
                    }
            }
        }
        .refreshable {
            await refreshBriefs()
        }
    }

    // MARK: - Data

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

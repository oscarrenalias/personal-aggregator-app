import SwiftUI

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

/// Identifies what the detail column shows in the regular-width (iPad/Mac) split
/// layout. A thread is chosen from the list; an article only arrives via deep link
/// (`aggregator://article/{id}`), which `AppRoot` routes through the Threads tab.
private enum ThreadDetail: Hashable {
    case thread(Int)
    case article(Int)
}

struct ThreadsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ListPreferences.self) private var listPreferences
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var threads: [Thread] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage: Bool = false
    @State private var loadGate = LoadOnceGate()
    @State private var path = NavigationPath()          // compact-only navigation
    @State private var selection: ThreadDetail?         // regular-only detail selection

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
            guard credentialsStore.isConfigured, loadGate.shouldLoad() else { return }
            await loadFirstPage()
        }
        .onChange(of: listPreferences.threadsSort) {
            Task { await loadFirstPage() }
        }
        .onChange(of: listPreferences.threadsShowDismissed) {
            Task { await loadFirstPage() }
        }
        .onAppear { handlePendingLink() }
        .onChange(of: deepLinkRouter.pendingLink) { _, _ in handlePendingLink() }
    }

    // MARK: - Compact (iPhone): unchanged push-navigation + swipe pager

    private var compactBody: some View {
        NavigationStack(path: $path) {
            stateContent { threadList }
                .navigationTitle("Threads")
                .toolbar { filterToolbar }
                .navigationDestination(for: Int.self) { index in
                    ThreadPagerView(threads: threads, startIndex: index)
                }
                .navigationDestination(for: DeepLink.self) { link in
                    switch link {
                    case .thread(let id): ThreadDetailView(threadId: id)
                    case .article(let id): ArticleDetailView(articleId: id)
                    }
                }
        }
    }

    // MARK: - Regular (iPad/Mac): two-pane master-detail

    private var regularBody: some View {
        NavigationSplitView {
            stateContent { sidebarList }
                .navigationTitle("Threads")
                .toolbar { filterToolbar }
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            NavigationStack { detailContent }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .thread(let id):
            ThreadDetailView(threadId: id).id(ThreadDetail.thread(id))
        case .article(let id):
            ArticleDetailView(articleId: id).id(ThreadDetail.article(id))
        case nil:
            DetailPlaceholder()
        }
    }

    // MARK: - Shared content

    /// Renders the not-configured / loading / error / empty states identically for
    /// both layouts; defers to `list` only when threads are loaded and non-empty.
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
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No threads",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                } else {
                    list()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        @Bindable var prefs = listPreferences
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $prefs.threadsSort) {
                    Text("By Importance").tag(ThreadSort.importance)
                    Text("Recent").tag(ThreadSort.recent)
                }
                Toggle("Show Dismissed", isOn: $prefs.threadsShowDismissed)
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    /// Compact list: tapping a row pushes the swipe pager via value-based link.
    private var threadList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    NavigationLink(value: index) {
                        ThreadCardView(thread: thread)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        rowSwipeActions(index: index)
                    }
                    .onAppear {
                        if index == threads.count - 1 {
                            Task { await loadNextPage() }
                        }
                    }
                }
            }
        }
        .refreshable {
            await loadFirstPage(showSpinner: false)
        }
    }

    /// Regular sidebar: selection drives the detail column.
    private var sidebarList: some View {
        GlassEffectContainer {
            List(selection: $selection) {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    ThreadCardView(thread: thread)
                        .tag(ThreadDetail.thread(thread.id))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            rowSwipeActions(index: index)
                        }
                        .onAppear {
                            if index == threads.count - 1 {
                                Task { await loadNextPage() }
                            }
                        }
                }
            }
        }
        .refreshable {
            await loadFirstPage(showSpinner: false)
        }
    }

    @ViewBuilder
    private func rowSwipeActions(index: Int) -> some View {
        if listPreferences.threadsShowDismissed {
            Button("Restore") {
                Task { await restoreThread(at: index) }
            }
            .tint(.accentColor)
        } else {
            Button("Dismiss", role: .destructive) {
                Task { await dismissThread(at: index) }
            }
        }
    }

    // MARK: - Deep links

    private func handlePendingLink() {
        guard let link = deepLinkRouter.pendingLink else { return }
        if hSizeClass == .compact {
            path.append(link)
        } else {
            switch link {
            case .thread(let id): selection = .thread(id)
            case .article(let id): selection = .article(id)
            }
        }
        deepLinkRouter.pendingLink = nil
    }

    // MARK: - Data

    private func loadFirstPage(showSpinner: Bool = true) async {
        if showSpinner {
            phase = .loading
            threads = []
        }
        nextCursor = nil
        do {
            let response = try await apiClient.getThreads(sort: listPreferences.threadsSort, showDismissed: listPreferences.threadsShowDismissed, cursor: nil)
            threads = response.items
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
            let response = try await apiClient.getThreads(sort: listPreferences.threadsSort, showDismissed: listPreferences.threadsShowDismissed, cursor: cursor)
            threads.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            // Silent failure on next-page errors; user can scroll back to retry
        }
    }

    private func dismissThread(at index: Int) async {
        guard index < threads.count else { return }
        let thread = threads[index]
        if selection == .thread(thread.id) { selection = nil }
        threads.remove(at: index)
        do {
            try await apiClient.dismissThread(id: thread.id)
        } catch {
            threads.insert(thread, at: min(index, threads.count))
        }
    }

    private func restoreThread(at index: Int) async {
        guard index < threads.count else { return }
        let thread = threads[index]
        if selection == .thread(thread.id) { selection = nil }
        threads.remove(at: index)
        do {
            try await apiClient.restoreThread(id: thread.id)
        } catch {
            threads.insert(thread, at: min(index, threads.count))
        }
    }
}

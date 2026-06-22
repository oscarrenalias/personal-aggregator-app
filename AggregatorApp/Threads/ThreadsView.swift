import SwiftUI

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct ThreadsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ListPreferences.self) private var listPreferences
    @Environment(DeepLinkRouter.self) private var deepLinkRouter

    @State private var threads: [Thread] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage: Bool = false
    @State private var loadGate = LoadOnceGate()
    @State private var path = NavigationPath()

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        @Bindable var prefs = listPreferences
        NavigationStack(path: $path) {
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
                            threadList
                        }
                    }
                }
            }
            .navigationTitle("Threads")
            .toolbar {
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
        .onAppear {
            if let link = deepLinkRouter.pendingLink {
                path.append(link)
                deepLinkRouter.pendingLink = nil
            }
        }
        .onChange(of: deepLinkRouter.pendingLink) { _, newLink in
            guard let link = newLink else { return }
            path.append(link)
            deepLinkRouter.pendingLink = nil
        }
    }

    private var threadList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    NavigationLink(value: index) {
                        ThreadCardView(thread: thread)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
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
        threads.remove(at: index)
        do {
            try await apiClient.restoreThread(id: thread.id)
        } catch {
            threads.insert(thread, at: min(index, threads.count))
        }
    }
}

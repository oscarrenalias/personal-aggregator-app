import SwiftUI
import UIKit

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct ThreadsIPadView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ListPreferences.self) private var listPreferences
    @Environment(ThreadSeenStore.self) private var seenStore

    @State private var threads: [Thread] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage = false
    @State private var loadGate = LoadOnceGate()
    @State private var isPortrait = false
    @State private var portraitPath = NavigationPath()

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        Group {
            if isPortrait {
                NavigationStack(path: $portraitPath) {
                    listBody
                        .navigationTitle("Threads")
                        .toolbar { filterToolbar }
                        .navigationDestination(for: Int.self) { threadId in
                            ThreadDetailView(threadId: threadId)
                        }
                }
            } else {
                listBody
                    .navigationTitle("Threads")
                    .toolbar { filterToolbar }
            }
        }
        .onAppear { updateOrientation() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateOrientation()
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
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: Binding(
                    get: { listPreferences.threadsSort },
                    set: { listPreferences.threadsSort = $0 }
                )) {
                    Text("By Importance").tag(ThreadSort.importance)
                    Text("Recent").tag(ThreadSort.recent)
                }
                Toggle("Show Dismissed", isOn: Binding(
                    get: { listPreferences.threadsShowDismissed },
                    set: { listPreferences.threadsShowDismissed = $0 }
                ))
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
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

    private var threadList: some View {
        GlassEffectContainer {
            List {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    threadRow(thread: thread, index: index)
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
            .listStyle(.plain)
        }
        .refreshable {
            await loadFirstPage(showSpinner: false)
        }
    }

    @ViewBuilder
    private func threadRow(thread: Thread, index: Int) -> some View {
        if isPortrait {
            NavigationLink(value: thread.id) {
                ThreadCardView(thread: thread)
            }
            .listRowBackground(Color.clear)
        } else {
            Button {
                navigationModel.selectedThread = thread
            } label: {
                ThreadCardView(thread: thread)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                navigationModel.selectedThread?.id == thread.id
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .accessibilityLabel(thread.representativeTitle)
        }
    }

    private func updateOrientation() {
        isPortrait = iPadIsPortrait()
    }

    private func loadFirstPage(showSpinner: Bool = true) async {
        if showSpinner {
            phase = .loading
            threads = []
        }
        nextCursor = nil
        do {
            let response = try await apiClient.getThreads(
                sort: listPreferences.threadsSort,
                showDismissed: listPreferences.threadsShowDismissed,
                cursor: nil
            )
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
            let response = try await apiClient.getThreads(
                sort: listPreferences.threadsSort,
                showDismissed: listPreferences.threadsShowDismissed,
                cursor: cursor
            )
            threads.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch {
            // Silent failure on pagination; existing rows remain visible
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

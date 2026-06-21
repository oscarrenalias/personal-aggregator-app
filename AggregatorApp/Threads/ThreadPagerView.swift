import SwiftUI

/// Horizontally paged reader over an already-loaded slice of threads.
///
/// Each page is a `ThreadDetailView`. A single toolbar lives on the pager (not
/// per page), reflecting the currently-selected thread — this avoids the
/// duplicate toolbar that appears when each paged view contributes its own, and
/// its presence gives the inline nav bar the translucent floating Liquid Glass
/// treatment so the hero scrolls under it.
///
/// Paging uses a horizontal `ScrollView` with `.scrollTargetBehavior(.paging)`
/// rather than a `.page`-style `TabView`: the TabView (a `UIPageViewController`)
/// insets its pages below the status bar, which left a strip above the hero. A
/// plain ScrollView lets each page's hero bleed to the very top.
struct ThreadPagerView: View {
    let threads: [Thread]
    let startIndex: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    // Bound to the scroll position; identifies the currently-centered page.
    @State private var currentID: Int?
    // Optimistic per-thread override for the dismissed flag toggled from the toolbar.
    @State private var dismissOverrides: [Int: Bool] = [:]

    init(threads: [Thread], startIndex: Int) {
        self.threads = threads
        self.startIndex = startIndex
        self._currentID = State(initialValue: startIndex)
    }

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    /// Currently-visible thread. `threads` is always non-empty here (the pager is
    /// only pushed from a tapped list row); the index is clamped defensively.
    private var current: Thread {
        let i = min(max(currentID ?? startIndex, 0), threads.count - 1)
        return threads[i]
    }

    private func isDismissed(_ t: Thread) -> Bool { dismissOverrides[t.id] ?? t.dismissed }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(threads.enumerated()), id: \.offset) { index, thread in
                    ThreadDetailView(threadId: thread.id)
                        // Size only the paging axis; forcing `.vertical` pins pages
                        // to the full bleeding height and clips hero-less titles.
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        // Each page bleeds heroes under the bars itself (post-load); hero-less
        // pages keep the system's inset so the title clears the floating toolbar.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { pagerToolbar }
    }

    @ToolbarContentBuilder
    private var pagerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await toggleDismissed(current) }
            } label: {
                Image(systemName: isDismissed(current) ? "arrow.uturn.backward" : "archivebox")
            }
            .accessibilityLabel(isDismissed(current) ? "Restore thread" : "Dismiss thread")
        }
    }

    private func toggleDismissed(_ t: Thread) async {
        let previous = isDismissed(t)
        dismissOverrides[t.id] = !previous  // optimistic
        do {
            if previous {
                try await apiClient.restoreThread(id: t.id)
            } else {
                try await apiClient.dismissThread(id: t.id)
            }
        } catch {
            dismissOverrides[t.id] = previous  // revert on failure
        }
    }
}

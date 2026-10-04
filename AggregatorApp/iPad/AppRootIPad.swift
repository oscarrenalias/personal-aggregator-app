import SwiftUI
import UIKit

struct AppRootIPad: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(DeepLinkRouter.self) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPortrait = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            detailColumn
        }
        // In iOS 26, the nav bars of all visible columns merge into a single
        // Liquid Glass panel spanning the full width of the split view. Hiding
        // the background here removes that merged band; toolbar items in each
        // column still render as floating glass pills (iOS 26 standard behaviour).
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { updateOrientation() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in updateOrientation() }
        .onChange(of: router.pendingLink) { _, link in
            guard let link else { return }
            switch link {
            case .thread:
                navigationModel.selectedSidebarItem = .threads
            case .article:
                break
            }
            router.pendingLink = nil
        }
    }

    // MARK: - Content column (landscape only — hidden in portrait)

    @ViewBuilder
    private var contentColumn: some View {
        switch navigationModel.selectedSidebarItem {
        case .threads:
            ThreadsIPadView()
        case .today:
            TodayIPadView()
        case .podcasts:
            PodcastsIPadView()
        case .feed(let f):
            ArticleListIPadView(feed: f)
                .id(f.id)
        }
    }

    // MARK: - Detail column

    @ViewBuilder
    private var detailColumn: some View {
        if isPortrait {
            // Portrait: content column is hidden; detail column acts as the primary view
            // and owns its own NavigationStack for push navigation.
            portraitDetailColumn
        } else {
            landscapeDetailColumn
        }
    }

    @ViewBuilder
    private var landscapeDetailColumn: some View {
        if let thread = navigationModel.selectedThread {
            NavigationStack {
                ThreadDetailView(threadId: thread.id)
            }
            // Suppress the NavigationSplitView's outer detail-column glass nav bar;
            // the inner NavigationStack provides its own bar that adapts correctly
            // to hero-bleed content (iOS 26 Liquid Glass floating-pill behaviour).
            .toolbarBackground(.hidden, for: .navigationBar)
            .id(thread.id)
        } else if let brief = navigationModel.selectedBrief {
            NavigationStack {
                BriefDetailView(brief: brief)
                    .navigationTitle(brief.headline ?? "Daily Brief")
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .id(brief.id)
        } else if let episode = navigationModel.selectedEpisode {
            NavigationStack {
                PodcastPlayerView(episode: episode)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .id(episode.id)
        } else if let article = navigationModel.selectedArticle {
            NavigationStack {
                ArticleDetailView(articleId: article.id)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .id(article.id)
        } else {
            landscapePlaceholder
        }
    }

    @ViewBuilder
    private var landscapePlaceholder: some View {
        switch navigationModel.selectedSidebarItem {
        case .threads:
            ContentUnavailableView("Select a thread", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("Choose a thread from the list."))
        case .today:
            ContentUnavailableView("Select a brief", systemImage: "calendar",
                                   description: Text("Choose a brief from the list."))
        case .podcasts:
            ContentUnavailableView("Select an episode", systemImage: "headphones",
                                   description: Text("Choose an episode to play."))
        case .feed:
            ContentUnavailableView("Select an article", systemImage: "newspaper",
                                   description: Text("Choose an article from the list."))
        }
    }

    @ViewBuilder
    private var portraitDetailColumn: some View {
        // In portrait, the content column is hidden, so the detail column shows
        // the full section view (with its own NavigationStack for push navigation).
        switch navigationModel.selectedSidebarItem {
        case .threads:
            ThreadsIPadView()
        case .today:
            TodayIPadView()
        case .podcasts:
            PodcastsIPadView()
        case .feed(let f):
            NavigationStack {
                ArticleListView(feed: f)
            }
            .id(f.id)
        }
    }

    private func updateOrientation() {
        isPortrait = iPadIsPortrait()
        columnVisibility = isPortrait ? .doubleColumn : .all
    }
}

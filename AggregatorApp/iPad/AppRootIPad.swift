import SwiftUI
import UIKit

struct AppRootIPad: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(DeepLinkRouter.self) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var capturedDeepLink: DeepLink?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } content: {
            sectionContent
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            detailContent
        }
        .onAppear {
            updateColumnVisibility()
            consumePendingLink()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateColumnVisibility()
        }
        .onChange(of: router.pendingLink) { _, link in
            guard link != nil else { return }
            consumePendingLink()
        }
        .onChange(of: navigationModel.selectedThread?.id) { capturedDeepLink = nil }
        .onChange(of: navigationModel.selectedArticle?.id) { capturedDeepLink = nil }
        .onChange(of: navigationModel.selectedBrief?.id) { capturedDeepLink = nil }
        .onChange(of: navigationModel.selectedFeed) { capturedDeepLink = nil }
        .onChange(of: navigationModel.selectedEpisode?.id) { capturedDeepLink = nil }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let link = capturedDeepLink {
            switch link {
            case .thread(let id):
                NavigationStack {
                    ThreadDetailView(threadId: id)
                }
                .id(id)
            case .article(let id):
                NavigationStack {
                    ArticleDetailView(articleId: id)
                }
                .id(id)
            }
        } else {
            sectionDetailContent
        }
    }

    private func consumePendingLink() {
        guard let link = router.pendingLink else { return }
        capturedDeepLink = link
        router.pendingLink = nil
    }

    @ViewBuilder
    private var sectionDetailContent: some View {
        switch navigationModel.selectedSection {
        case .threads:
            if let thread = navigationModel.selectedThread {
                NavigationStack {
                    ThreadDetailView(threadId: thread.id)
                }
            } else {
                ContentUnavailableView(
                    "Select a thread",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a thread from the list to read.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .today:
            if let brief = navigationModel.selectedBrief {
                NavigationStack {
                    BriefDetailView(brief: brief)
                        .navigationTitle(brief.headline ?? "Daily Brief")
                }
            } else {
                ContentUnavailableView(
                    "Select a brief",
                    systemImage: "calendar",
                    description: Text("Choose a brief from the list to read.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .podcasts:
            if let episode = navigationModel.selectedEpisode {
                NavigationStack {
                    PodcastPlayerView(episode: episode)
                }
            } else {
                ContentUnavailableView(
                    "Select an episode",
                    systemImage: "headphones",
                    description: Text("Choose an episode from the list to play.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .sources:
            if let feed = navigationModel.selectedFeed {
                NavigationStack {
                    ArticleListView(feed: feed)
                }
            } else {
                ContentUnavailableView(
                    "Select a source",
                    systemImage: "newspaper",
                    description: Text("Choose a source or feed to browse articles.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .search:
            if let article = navigationModel.selectedArticle {
                NavigationStack {
                    ArticleDetailView(articleId: article.id)
                }
            } else {
                ContentUnavailableView(
                    "Search results",
                    systemImage: "magnifyingglass",
                    description: Text("Select an article from search results to read it.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .settings:
            SettingsIPadView()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch navigationModel.selectedSection {
        case .threads:
            ThreadsIPadView()
        case .today:
            TodayIPadView()
        case .podcasts:
            PodcastsIPadView()
        case .sources:
            SourcesIPadView()
        case .search:
            SearchIPadView()
        case .settings:
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("Choose a category from the list.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func updateColumnVisibility() {
        let bounds = UIScreen.main.bounds
        let isPortrait = bounds.width < bounds.height
        columnVisibility = isPortrait ? .doubleColumn : .all
    }
}

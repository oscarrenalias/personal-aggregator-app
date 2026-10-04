import SwiftUI

enum SidebarItem: Hashable, Identifiable {
    case threads
    case today
    case podcasts
    case feed(ArticleFeed)

    var id: String {
        switch self {
        case .threads: return "threads"
        case .today: return "today"
        case .podcasts: return "podcasts"
        case .feed(let f): return "feed-\(f.id)"
        }
    }
}

@Observable
final class iPadNavigationModel {
    var selectedSidebarItem: SidebarItem = .threads
    var selectedThread: Thread?
    var selectedArticle: Article?
    var selectedEpisode: PodcastEpisode?
    var selectedBrief: Brief?

    /// Push stack for the landscape detail column. Owned here (rather than left
    /// implicit inside the NavigationStack) so a selection change can pop it back
    /// to root — replacing a NavigationStack that has a pushed view does not
    /// reliably tear the pushed view down.
    var detailPath = NavigationPath()

    func clearSelection() {
        selectedThread = nil
        selectedArticle = nil
        selectedEpisode = nil
        selectedBrief = nil
        detailPath = NavigationPath()
    }
}

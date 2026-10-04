import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case threads
    case sources
    case today
    case podcasts
    case search
    case settings

    var id: String { rawValue }
}

@Observable
final class iPadNavigationModel {
    var selectedSection: AppSection = .threads
    var selectedThread: Thread?
    var selectedArticle: Article?
    var selectedSource: Source?
    var selectedEpisode: PodcastEpisode?
    var selectedFeed: ArticleFeed?
    var selectedBrief: Brief?
}

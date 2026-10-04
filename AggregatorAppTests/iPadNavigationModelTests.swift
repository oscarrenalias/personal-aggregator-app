import SwiftUI
import XCTest
@testable import AggregatorApp

final class iPadNavigationModelTests: XCTestCase {

    // MARK: - SidebarItem

    func testDefaultSelectedSidebarItemIsThreads() {
        let model = iPadNavigationModel()
        XCTAssertEqual(model.selectedSidebarItem, .threads)
    }

    func testSidebarItemIdsAreUnique() {
        let items: [SidebarItem] = [
            .threads, .today, .podcasts,
            .feed(.important), .feed(.unread), .feed(.saved),
            .feed(.source(id: 5, name: "Tech News")),
            .feed(.category(name: "Science")),
        ]
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }

    func testSidebarItemIdsAreStable() {
        XCTAssertEqual(SidebarItem.threads.id, "threads")
        XCTAssertEqual(SidebarItem.today.id, "today")
        XCTAssertEqual(SidebarItem.podcasts.id, "podcasts")
        XCTAssertEqual(SidebarItem.feed(.important).id, "feed-important")
        XCTAssertEqual(SidebarItem.feed(.source(id: 5, name: "Tech News")).id, "feed-source-5")
    }

    func testSelectedSidebarItemCanBeSet() {
        let model = iPadNavigationModel()
        for item in [SidebarItem.today, .podcasts, .feed(.saved), .threads] {
            model.selectedSidebarItem = item
            XCTAssertEqual(model.selectedSidebarItem, item)
        }
    }

    // MARK: - Detail column selection state

    func testInitialSelectionsAreNil() {
        let model = iPadNavigationModel()
        XCTAssertNil(model.selectedThread)
        XCTAssertNil(model.selectedArticle)
        XCTAssertNil(model.selectedEpisode)
        XCTAssertNil(model.selectedBrief)
        XCTAssertTrue(model.detailPath.isEmpty)
    }

    func testSelectedBriefCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        model.selectedBrief = try makeBrief(id: 42, headline: "Test Brief")
        XCTAssertEqual(model.selectedBrief?.id, 42)
        model.selectedBrief = nil
        XCTAssertNil(model.selectedBrief)
    }

    func testSelectedEpisodeCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        model.selectedEpisode = try makePodcastEpisode(id: 7)
        XCTAssertEqual(model.selectedEpisode?.id, 7)
        model.selectedEpisode = nil
        XCTAssertNil(model.selectedEpisode)
    }

    func testSelectedThreadCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        model.selectedThread = try JSONDecoder().decode(Thread.self, from: Data(threadJSON(id: 10).utf8))
        XCTAssertEqual(model.selectedThread?.id, 10)
        model.selectedThread = nil
        XCTAssertNil(model.selectedThread)
    }

    func testSelectedArticleCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        model.selectedArticle = try makeArticle(id: 99)
        XCTAssertEqual(model.selectedArticle?.id, 99)
        model.selectedArticle = nil
        XCTAssertNil(model.selectedArticle)
    }

    func testSelectionsAreIndependent() throws {
        let model = iPadNavigationModel()
        model.selectedThread = try JSONDecoder().decode(Thread.self, from: Data(threadJSON(id: 1).utf8))
        model.selectedBrief = try makeBrief(id: 2, headline: "Brief")
        model.selectedEpisode = try makePodcastEpisode(id: 3)

        model.selectedThread = nil
        XCTAssertNil(model.selectedThread)
        XCTAssertEqual(model.selectedBrief?.id, 2, "Clearing one selection must not affect siblings")
        XCTAssertEqual(model.selectedEpisode?.id, 3)
    }

    // MARK: - clearSelection

    func testClearSelectionClearsEverySelection() throws {
        let model = iPadNavigationModel()
        model.selectedThread = try JSONDecoder().decode(Thread.self, from: Data(threadJSON(id: 1).utf8))
        model.selectedArticle = try makeArticle(id: 2)
        model.selectedBrief = try makeBrief(id: 3, headline: "B")
        model.selectedEpisode = try makePodcastEpisode(id: 4)

        model.clearSelection()

        XCTAssertNil(model.selectedThread)
        XCTAssertNil(model.selectedArticle)
        XCTAssertNil(model.selectedBrief)
        XCTAssertNil(model.selectedEpisode)
    }

    func testClearSelectionLeavesSidebarItemUntouched() {
        let model = iPadNavigationModel()
        model.selectedSidebarItem = .feed(.saved)
        model.clearSelection()
        XCTAssertEqual(model.selectedSidebarItem, .feed(.saved),
                       "clearSelection clears the detail column, not the sidebar choice")
    }

    /// The detail column is one stable NavigationStack; an article opened from
    /// inside a thread is a push on that stack. Switching selection must pop it,
    /// otherwise the stale pushed view stays on screen.
    func testClearSelectionResetsDetailPath() throws {
        let model = iPadNavigationModel()
        model.detailPath.append(ThreadArticleRef(articleId: 123))
        model.detailPath.append(ThreadArticleRef(articleId: 456))
        XCTAssertEqual(model.detailPath.count, 2)

        model.clearSelection()

        XCTAssertTrue(model.detailPath.isEmpty, "Selection change must pop the detail stack to root")
    }

    func testThreadArticleRefEquality() {
        XCTAssertEqual(ThreadArticleRef(articleId: 1), ThreadArticleRef(articleId: 1))
        XCTAssertNotEqual(ThreadArticleRef(articleId: 1), ThreadArticleRef(articleId: 2))
    }

    // MARK: - Helpers

    private func makeBrief(id: Int, headline: String) throws -> Brief {
        let json = """
        {"id":\(id),"headline":"\(headline)","intro":null,"generated_at":null,
         "period_start":"2026-01-01T00:00:00+00:00","period_end":"2026-01-02T00:00:00+00:00",
         "model":null,"topics":[]}
        """
        return try JSONDecoder().decode(Brief.self, from: Data(json.utf8))
    }

    private func makePodcastEpisode(id: Int) throws -> PodcastEpisode {
        let json = """
        {"id":\(id),"date":"2026-01-01","episode_theme":null,"status":"ready",
         "duration_seconds":1800,"audio_url":"https://example.com/ep.mp3",
         "segment_count":3,"llm_model":null,"tts_model":null,"tts_voice":null,
         "generated_at":null,"created_at":"2026-01-01T00:00:00+00:00"}
        """
        return try JSONDecoder().decode(PodcastEpisode.self, from: Data(json.utf8))
    }

    // Returns JSON rather than a decoded value: a `-> Thread` annotation is
    // ambiguous against Foundation.Thread, and the module can't be used to
    // qualify it because the app's `AggregatorApp` App struct shadows the name.
    // Decoding inline at the call site resolves it.
    private func threadJSON(id: Int) -> String {
        """
        {"id":\(id),"representative_title":"Thread \(id)","rolling_summary":null,
         "known_facts":[],"status":"active","novelty_label":null,
         "first_seen":"2026-01-01T00:00:00+00:00","last_updated":"2026-01-01T00:00:00+00:00",
         "source_count":1,"member_count":1,"image_url":null,"has_updates":false,
         "dismissed":false,"top_grade":null,"last_viewed_at":null,"deltas":[]}
        """
    }

    private func makeArticle(id: Int) throws -> Article {
        let json = """
        {"id":\(id),"title":"Article \(id)","url":"https://example.com","source_id":1,
         "source_name":"Source","feed_published_at":null,"summary":null,"clean_text":null,
         "importance_score":null,"importance_reason":null,"topics":[],"categories":[],
         "is_read":false,"is_saved":false,"author":null,"word_count":null,
         "language":null,"image_url":null,"comments_url":null}
        """
        return try JSONDecoder().decode(Article.self, from: Data(json.utf8))
    }
}

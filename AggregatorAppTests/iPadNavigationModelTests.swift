import XCTest
@testable import AggregatorApp

final class iPadNavigationModelTests: XCTestCase {

    func testDefaultSelectedSectionIsThreads() {
        let model = iPadNavigationModel()
        XCTAssertEqual(model.selectedSection, .threads)
    }

    func testAllAppSectionsHaveUniqueIds() {
        let ids = AppSection.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, AppSection.allCases.count)
    }

    func testAppSectionIdMatchesRawValue() {
        for section in AppSection.allCases {
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func testSelectedSectionCanBeSetToAllCases() {
        let model = iPadNavigationModel()
        for section in AppSection.allCases {
            model.selectedSection = section
            XCTAssertEqual(model.selectedSection, section)
        }
    }

    func testInitialOptionalSelectionsAreNil() {
        let model = iPadNavigationModel()
        XCTAssertNil(model.selectedThread)
        XCTAssertNil(model.selectedArticle)
        XCTAssertNil(model.selectedSource)
        XCTAssertNil(model.selectedEpisode)
        XCTAssertNil(model.selectedFeed)
        XCTAssertNil(model.selectedBrief)
    }

    func testAllAppSectionsCovered() {
        XCTAssertEqual(AppSection.allCases.count, 6,
            "AppSection must have exactly 6 cases: threads, sources, today, podcasts, search, settings")
        XCTAssertTrue(AppSection.allCases.contains(.threads))
        XCTAssertTrue(AppSection.allCases.contains(.sources))
        XCTAssertTrue(AppSection.allCases.contains(.today))
        XCTAssertTrue(AppSection.allCases.contains(.podcasts))
        XCTAssertTrue(AppSection.allCases.contains(.search))
        XCTAssertTrue(AppSection.allCases.contains(.settings))
    }

    // MARK: - Detail column routing state (B-80cd72ae-subtask-subtask-2)

    func testSelectedBriefCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        let brief = try makeBrief(id: 42, headline: "Test Brief")
        model.selectedBrief = brief
        XCTAssertEqual(model.selectedBrief?.id, 42)
        model.selectedBrief = nil
        XCTAssertNil(model.selectedBrief)
    }

    func testSelectedFeedCanBeSetAndCleared() {
        let model = iPadNavigationModel()
        model.selectedFeed = .source(id: 5, name: "Tech News")
        XCTAssertEqual(model.selectedFeed?.id, "source-5")
        model.selectedFeed = .important
        XCTAssertEqual(model.selectedFeed?.id, "important")
        model.selectedFeed = nil
        XCTAssertNil(model.selectedFeed)
    }

    func testSelectedEpisodeCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        let episode = try makePodcastEpisode(id: 7)
        model.selectedEpisode = episode
        XCTAssertEqual(model.selectedEpisode?.id, 7)
        model.selectedEpisode = nil
        XCTAssertNil(model.selectedEpisode)
    }

    func testSelectedThreadCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        let thread = try JSONDecoder().decode(Thread.self, from: Data(threadJSON(id: 10).utf8))
        model.selectedThread = thread
        XCTAssertEqual(model.selectedThread?.id, 10)
        model.selectedThread = nil
        XCTAssertNil(model.selectedThread)
    }

    func testSelectedArticleCanBeSetAndCleared() throws {
        let model = iPadNavigationModel()
        let article = try makeArticle(id: 99)
        model.selectedArticle = article
        XCTAssertEqual(model.selectedArticle?.id, 99)
        model.selectedArticle = nil
        XCTAssertNil(model.selectedArticle)
    }

    func testSelectionsAreIndependent() throws {
        let model = iPadNavigationModel()
        let thread = try JSONDecoder().decode(Thread.self, from: Data(threadJSON(id: 1).utf8))
        let brief = try makeBrief(id: 2, headline: "Brief")
        let episode = try makePodcastEpisode(id: 3)
        model.selectedThread = thread
        model.selectedBrief = brief
        model.selectedEpisode = episode
        model.selectedFeed = .unread
        XCTAssertEqual(model.selectedThread?.id, 1)
        XCTAssertEqual(model.selectedBrief?.id, 2)
        XCTAssertEqual(model.selectedEpisode?.id, 3)
        XCTAssertEqual(model.selectedFeed?.id, "unread")
        // Clearing one must not affect others
        model.selectedThread = nil
        XCTAssertNil(model.selectedThread)
        XCTAssertEqual(model.selectedBrief?.id, 2)
        XCTAssertEqual(model.selectedEpisode?.id, 3)
    }

    func testSectionSwitchDoesNotAutoclearSelections() throws {
        let model = iPadNavigationModel()
        let brief = try makeBrief(id: 5, headline: "B")
        model.selectedSection = .today
        model.selectedBrief = brief
        model.selectedSection = .threads
        // Switching sections in the model alone does not clear sibling selections;
        // AppRootIPad clears capturedDeepLink on selection changes, not the model.
        XCTAssertEqual(model.selectedBrief?.id, 5,
            "Navigation model itself does not clear selections on section switch — AppRootIPad manages deep link capture independently")
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

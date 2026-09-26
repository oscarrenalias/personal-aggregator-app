import XCTest
@testable import AggregatorApp

final class PodcastTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - PodcastEpisode decoding

    private let fullEpisodeJSON = """
    {
        "id": 42,
        "date": "2024-01-15",
        "episode_theme": "AI and the Future",
        "status": "ready",
        "duration_seconds": 1234,
        "audio_url": "https://example.com/episodes/42.mp3",
        "segment_count": 5,
        "llm_model": "gpt-4o",
        "tts_model": "tts-1-hd",
        "tts_voice": "alloy",
        "generated_at": "2024-01-15T08:00:00+00:00",
        "created_at": "2024-01-15T07:00:00+00:00"
    }
    """

    func testPodcastEpisodeDecodesAllRequiredFields() throws {
        let episode = try decoder.decode(PodcastEpisode.self, from: Data(fullEpisodeJSON.utf8))
        XCTAssertEqual(episode.id, 42)
        XCTAssertEqual(episode.date, "2024-01-15")
        XCTAssertEqual(episode.status, "ready")
        XCTAssertEqual(episode.audioUrl, "https://example.com/episodes/42.mp3")
        XCTAssertEqual(episode.segmentCount, 5)
        XCTAssertEqual(episode.createdAt, "2024-01-15T07:00:00+00:00")
    }

    func testPodcastEpisodeDecodesAllOptionalFieldsWhenPresent() throws {
        let episode = try decoder.decode(PodcastEpisode.self, from: Data(fullEpisodeJSON.utf8))
        XCTAssertEqual(episode.episodeTheme, "AI and the Future")
        XCTAssertEqual(episode.durationSeconds, 1234)
        XCTAssertEqual(episode.llmModel, "gpt-4o")
        XCTAssertEqual(episode.ttsModel, "tts-1-hd")
        XCTAssertEqual(episode.ttsVoice, "alloy")
        XCTAssertEqual(episode.generatedAt, "2024-01-15T08:00:00+00:00")
    }

    func testPodcastEpisodeOptionalFieldsNilWhenAbsent() throws {
        let json = """
        {
            "id": 1,
            "date": "2024-01-15",
            "status": "ready",
            "audio_url": "https://example.com/1.mp3",
            "segment_count": 3,
            "created_at": "2024-01-15T07:00:00+00:00"
        }
        """
        let episode = try decoder.decode(PodcastEpisode.self, from: Data(json.utf8))
        XCTAssertNil(episode.episodeTheme)
        XCTAssertNil(episode.durationSeconds)
        XCTAssertNil(episode.llmModel)
        XCTAssertNil(episode.ttsModel)
        XCTAssertNil(episode.ttsVoice)
        XCTAssertNil(episode.generatedAt)
    }

    func testPodcastEpisodeFailsWhenRequiredFieldMissing_id() {
        let json = """
        {
            "date": "2024-01-15",
            "status": "ready",
            "audio_url": "https://example.com/1.mp3",
            "segment_count": 3,
            "created_at": "2024-01-15T07:00:00+00:00"
        }
        """
        XCTAssertThrowsError(try decoder.decode(PodcastEpisode.self, from: Data(json.utf8)))
    }

    func testPodcastEpisodeFailsWhenRequiredFieldMissing_audioUrl() {
        let json = """
        {
            "id": 1,
            "date": "2024-01-15",
            "status": "ready",
            "segment_count": 3,
            "created_at": "2024-01-15T07:00:00+00:00"
        }
        """
        XCTAssertThrowsError(try decoder.decode(PodcastEpisode.self, from: Data(json.utf8)))
    }

    func testPodcastEpisodeFailsWhenRequiredFieldMissing_createdAt() {
        let json = """
        {
            "id": 1,
            "date": "2024-01-15",
            "status": "ready",
            "audio_url": "https://example.com/1.mp3",
            "segment_count": 3
        }
        """
        XCTAssertThrowsError(try decoder.decode(PodcastEpisode.self, from: Data(json.utf8)))
    }

    func testPaginatedPodcastEpisodeDecodes() throws {
        let json = """
        {
            "items": [
                {
                    "id": 1,
                    "date": "2024-01-15",
                    "status": "ready",
                    "audio_url": "https://example.com/1.mp3",
                    "segment_count": 3,
                    "created_at": "2024-01-15T07:00:00+00:00"
                }
            ],
            "next_cursor": "eyJpZCI6IDF9"
        }
        """
        let response = try decoder.decode(PaginatedResponse<PodcastEpisode>.self, from: Data(json.utf8))
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.nextCursor, "eyJpZCI6IDF9")
        XCTAssertEqual(response.items[0].id, 1)
    }

    func testPaginatedPodcastEpisodeNullCursor() throws {
        let json = """
        {
            "items": [],
            "next_cursor": null
        }
        """
        let response = try decoder.decode(PaginatedResponse<PodcastEpisode>.self, from: Data(json.utf8))
        XCTAssertTrue(response.items.isEmpty)
        XCTAssertNil(response.nextCursor)
    }

    // MARK: - DateDisplay with date-only strings (podcast episode.date format)

    func testMonthDayWithDateOnlyString() {
        let result = DateDisplay.monthDay("2024-01-15")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.month, "JAN")
        XCTAssertEqual(result?.day, "15")
    }

    func testMonthDayDecemberBoundary() {
        let result = DateDisplay.monthDay("2024-12-31")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.month, "DEC")
        XCTAssertEqual(result?.day, "31")
    }

    func testMonthDayJanuaryFirst() {
        let result = DateDisplay.monthDay("2024-01-01")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.month, "JAN")
        XCTAssertEqual(result?.day, "1")
    }

    func testMediumDateWithDateOnlyString() {
        let result = DateDisplay.mediumDate("2024-01-15")
        XCTAssertFalse(result.isEmpty, "mediumDate must return a non-empty string for a valid date-only string")
    }

    func testRelativeWithDateOnlyString() {
        // Use a known reference date well after 2024-01-15 so relative is deterministic
        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime]
        let now = isoParser.date(from: "2024-02-15T12:00:00+00:00")!
        let result = DateDisplay.relative("2024-01-15", now: now)
        XCTAssertFalse(result.isEmpty, "relative must return a non-empty string for a valid date-only string")
    }

    func testMonthDayNilInputReturnsNil() {
        XCTAssertNil(DateDisplay.monthDay(nil))
    }

    func testMonthDayMalformedReturnsNil() {
        XCTAssertNil(DateDisplay.monthDay("not-a-date"))
        XCTAssertNil(DateDisplay.monthDay("2024-13-01"))
    }

    func testMediumDateNilReturnsEmpty() {
        XCTAssertEqual(DateDisplay.mediumDate(nil), "")
    }

    func testMediumDateMalformedReturnsEmpty() {
        XCTAssertEqual(DateDisplay.mediumDate("not-a-date"), "")
    }

    // Regression: full ISO-8601 strings still parse after date-only fallback was added
    func testMonthDayWithFullISO8601WithFractionalSeconds() {
        let result = DateDisplay.monthDay("2024-01-15T10:30:00.500000+00:00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.month, "JAN")
    }

    func testMonthDayWithFullISO8601WithoutFractionalSeconds() {
        let result = DateDisplay.monthDay("2024-06-23T10:30:00+00:00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.month, "JUN")
    }

    // MARK: - APIClient podcast URL construction

    func testGetPodcastsURLNoCursorItemWhenNil() {
        let query = podcastsQuery(cursor: nil, limit: 20)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/podcasts", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "limit" })?.value, "20")
        XCTAssertNil(items.first(where: { $0.name == "cursor" }), "cursor must be absent when nil")
    }

    func testGetPodcastsURLWithCursorAppendsVerbatim() {
        let query = podcastsQuery(cursor: "abc==", limit: 10)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/podcasts", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "cursor" })?.value, "abc==")
        XCTAssertTrue(url.absoluteString.contains("cursor=abc%3D%3D"), "cursor 'abc==' must appear percent-encoded in URL")
    }

    func testGetPodcastEpisodeURLBuildsCorrectPath() {
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/podcasts/42")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.hasSuffix("/podcasts/42") ?? false)
    }

    func testGetLatestPodcastEpisodeURLBuildsCorrectPath() {
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/podcasts/latest")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.hasSuffix("/podcasts/latest") ?? false)
    }

    // MARK: - Private helpers

    private func podcastsQuery(cursor: String?, limit: Int) -> [URLQueryItem] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return query
    }
}

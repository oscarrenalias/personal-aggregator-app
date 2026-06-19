import XCTest
@testable import AggregatorApp

final class ThreadsModelTests: XCTestCase {

    // MARK: - PaginatedResponse

    func testPaginatedResponseDecodesTwoItemsWithCursor() throws {
        let json = """
        {
            "items": [
                {"id": 1, "name": "Feed A", "feed_url": "https://a.com/feed"},
                {"id": 2, "name": "Feed B", "feed_url": "https://b.com/feed"}
            ],
            "next_cursor": "dGVzdA=="
        }
        """
        let result = try JSONDecoder().decode(PaginatedResponse<Source>.self, from: Data(json.utf8))
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.nextCursor, "dGVzdA==")
    }

    func testPaginatedResponseDecodesNullCursorAsNil() throws {
        let json = """
        {
            "items": [],
            "next_cursor": null
        }
        """
        let result = try JSONDecoder().decode(PaginatedResponse<Source>.self, from: Data(json.utf8))
        XCTAssertNil(result.nextCursor)
    }

    // MARK: - Thread

    func testThreadDecoding() throws {
        let json = """
        {
            "id": 42,
            "representative_title": "AI Advances in 2026",
            "rolling_summary": null,
            "known_facts": [],
            "status": "active",
            "novelty_label": null,
            "first_seen": "2026-06-17T04:41:10.929002+00:00",
            "last_updated": "2026-06-19T10:00:00+00:00",
            "source_count": 5,
            "member_count": 12,
            "image_url": "https://example.com/img.jpg",
            "has_updates": true,
            "dismissed": false,
            "top_grade": null
        }
        """
        let thread = try JSONDecoder().decode(Thread.self, from: Data(json.utf8))
        XCTAssertEqual(thread.representativeTitle, "AI Advances in 2026")
        XCTAssertEqual(thread.sourceCount, 5)
        XCTAssertEqual(thread.memberCount, 12)
        XCTAssertTrue(thread.hasUpdates)
        XCTAssertFalse(thread.dismissed)
        XCTAssertEqual(thread.imageURL, "https://example.com/img.jpg")
        XCTAssertEqual(thread.knownFacts, [])
    }

    // MARK: - ThreadMember

    func testThreadMemberDecoding() throws {
        let json = """
        {
            "id": 101,
            "thread_id": 42,
            "article_id": 999,
            "clean_title": "The Rise of AI",
            "url": "https://example.com/article",
            "source_name": "TechCrunch",
            "published_at": "2026-06-18T09:00:00+00:00",
            "classification_label": "primary",
            "suppressed": false
        }
        """
        let member = try JSONDecoder().decode(ThreadMember.self, from: Data(json.utf8))
        XCTAssertEqual(member.articleId, 999)
        XCTAssertEqual(member.cleanTitle, "The Rise of AI")
        XCTAssertEqual(member.sourceName, "TechCrunch")
        XCTAssertFalse(member.suppressed)
    }

    // MARK: - Article

    func testArticleDecoding() throws {
        let json = """
        {
            "id": 55,
            "title": "Test Article",
            "url": "https://example.com/test",
            "source_id": 7,
            "source_name": "Example News",
            "feed_published_at": "2026-06-18T08:00:00+00:00",
            "summary": null,
            "clean_text": null,
            "importance_score": null,
            "importance_reason": null,
            "topics": ["technology", "AI"],
            "categories": [],
            "is_read": true,
            "is_saved": false,
            "author": null,
            "word_count": null,
            "language": null
        }
        """
        let article = try JSONDecoder().decode(Article.self, from: Data(json.utf8))
        XCTAssertTrue(article.isRead)
        XCTAssertFalse(article.isSaved)
        XCTAssertEqual(article.topics, ["technology", "AI"])
        XCTAssertNil(article.language)
        XCTAssertNil(article.imageURL)
    }

    // MARK: - APIClient.makeURL

    func testMakeURLBuildsThreadsURLWithPercentEncodedCursor() {
        let base = "https://aggregator-api.renaliaslabs.net/api/v1"
        let query = [
            URLQueryItem(name: "sort", value: "recent"),
            URLQueryItem(name: "show_dismissed", value: "true"),
            URLQueryItem(name: "cursor", value: "ABC==")
        ]
        let url = APIClient.makeURL(baseURL: base, path: "/threads", query: query)
        XCTAssertNotNil(url)
        let s = url!.absoluteString
        XCTAssertTrue(s.hasPrefix("https://aggregator-api.renaliaslabs.net/api/v1/threads?"))
        XCTAssertTrue(s.contains("sort=recent"))
        XCTAssertTrue(s.contains("show_dismissed=true"))
        // URLComponents percent-encodes '=' within a value as '%3D'
        XCTAssertTrue(s.contains("cursor=ABC%3D%3D"), "cursor value must be percent-encoded")
        XCTAssertFalse(s.contains("cursor=ABC=="), "raw = signs must not appear unencoded in cursor value")
    }

    func testMakeURLOmitsCursorParamWhenNil() {
        let base = "https://aggregator-api.renaliaslabs.net/api/v1"
        let query = [
            URLQueryItem(name: "sort", value: "recent"),
            URLQueryItem(name: "show_dismissed", value: "true")
        ]
        let url = APIClient.makeURL(baseURL: base, path: "/threads", query: query)
        XCTAssertNotNil(url)
        XCTAssertFalse(url!.absoluteString.contains("cursor"))
    }

    // MARK: - DateDisplay

    func testDateDisplayRelativeTwoHoursAgo() {
        // Pin "now" to a fixed reference so the test is deterministic
        let now = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01T00:00:00Z
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let isoString = formatter.string(from: twoHoursAgo)
        XCTAssertEqual(DateDisplay.relative(isoString, now: now), "2h ago")
    }

    func testDateDisplayRelativeNilInputReturnsEmpty() {
        XCTAssertEqual(DateDisplay.relative(nil), "")
    }

    func testDateDisplayRelativeGarbageInputReturnsEmpty() {
        XCTAssertEqual(DateDisplay.relative("not-a-valid-date"), "")
    }
}

import XCTest
@testable import AggregatorApp

final class BriefModelTests: XCTestCase {

    // MARK: - Brief decoding

    func testBriefDecodesTopicsAndFields() throws {
        let json = """
        {
            "id": 1,
            "headline": "Today's Highlights",
            "intro": "Here is what happened today.",
            "generated_at": "2026-06-19T06:00:00+00:00",
            "period_start": "2026-06-18T00:00:00+00:00",
            "period_end": "2026-06-19T00:00:00+00:00",
            "model": "gpt-4o",
            "topics": [
                {
                    "position": 1,
                    "headline": "AI Advances",
                    "what_happened": "Several models were released.",
                    "why_it_matters": "Pace of progress is accelerating.",
                    "historical_context": null,
                    "refs": []
                },
                {
                    "position": 2,
                    "headline": "Climate Update",
                    "what_happened": "New report published.",
                    "why_it_matters": "Affects policy decisions.",
                    "historical_context": "Long running trend since 1990s.",
                    "refs": []
                }
            ]
        }
        """
        let brief = try JSONDecoder().decode(Brief.self, from: Data(json.utf8))
        XCTAssertEqual(brief.headline, "Today's Highlights")
        XCTAssertEqual(brief.intro, "Here is what happened today.")
        XCTAssertEqual(brief.periodStart, "2026-06-18T00:00:00+00:00")
        XCTAssertEqual(brief.periodEnd, "2026-06-19T00:00:00+00:00")
        XCTAssertEqual(brief.model, "gpt-4o")
        XCTAssertEqual(brief.topics.count, 2)

        let first = brief.topics[0]
        XCTAssertEqual(first.whatHappened, "Several models were released.")
        XCTAssertEqual(first.whyItMatters, "Pace of progress is accelerating.")
        XCTAssertNil(first.historicalContext)

        let second = brief.topics[1]
        XCTAssertEqual(second.historicalContext, "Long running trend since 1990s.")
    }

    // MARK: - BriefRef decoding

    func testBriefRefInternalDecoding() throws {
        let json = """
        {"url": null, "title": "X", "internal": true, "article_id": 42}
        """
        let ref = try JSONDecoder().decode(BriefRef.self, from: Data(json.utf8))
        XCTAssertTrue(ref.`internal`)
        XCTAssertEqual(ref.articleId, 42)
        XCTAssertNil(ref.url)
    }

    func testBriefRefExternalDecoding() throws {
        let json = """
        {"url": "https://e.com", "title": "Y", "internal": false, "article_id": null}
        """
        let ref = try JSONDecoder().decode(BriefRef.self, from: Data(json.utf8))
        XCTAssertFalse(ref.`internal`)
        XCTAssertEqual(ref.url, "https://e.com")
        XCTAssertNil(ref.articleId)
    }

    // MARK: - DateDisplay.mediumDate

    func testMediumDateFormatsKnownDate() {
        // Derive expected with the same formatter to avoid locale coupling
        let iso = "2026-06-19T00:00:00+00:00"
        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime]
        let date = isoParser.date(from: iso)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let expected = formatter.string(from: date)
        XCTAssertEqual(DateDisplay.mediumDate(iso), expected)
    }

    func testMediumDateWithFractionalSeconds() {
        let iso = "2026-06-17T04:41:10.929002+00:00"
        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoParser.date(from: iso)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let expected = formatter.string(from: date)
        XCTAssertEqual(DateDisplay.mediumDate(iso), expected)
    }

    func testMediumDateNilReturnsEmpty() {
        XCTAssertEqual(DateDisplay.mediumDate(nil), "")
    }

    func testMediumDateGarbageReturnsEmpty() {
        XCTAssertEqual(DateDisplay.mediumDate("not-a-date"), "")
    }

    // MARK: - DateDisplay.monthDay (calendar badge)

    func testMonthDayReturnsUppercaseMonthAndDay() {
        // Derive expected with the same formatters/locale/timezone as the implementation.
        let iso = "2026-06-19T12:00:00+00:00"
        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime]
        let date = isoParser.date(from: iso)!
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let result = DateDisplay.monthDay(iso)
        XCTAssertEqual(result?.month, monthFormatter.string(from: date).uppercased())
        XCTAssertEqual(result?.day, dayFormatter.string(from: date))
    }

    func testMonthDayNilAndGarbageReturnNil() {
        XCTAssertNil(DateDisplay.monthDay(nil))
        XCTAssertNil(DateDisplay.monthDay("not-a-date"))
    }

    // MARK: - getBriefs URL construction via APIClient.makeURL

    func testGetBriefsURLWithCursor() {
        let query = briefsQuery(cursor: "C==", limit: 20)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/briefs", query: query)

        XCTAssertNotNil(url)
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertEqual(items.first(where: { $0.name == "limit" })?.value, "20")
        // URLComponents decodes the stored value; verify raw percent-encoding in the URL string
        XCTAssertEqual(items.first(where: { $0.name == "cursor" })?.value, "C==")
        XCTAssertTrue(url.absoluteString.contains("cursor=C%3D%3D"), "cursor 'C==' must appear percent-encoded as 'C%3D%3D' in URL")
    }

    func testGetBriefsURLNoCursorItemWhenCursorIsNil() {
        let query = briefsQuery(cursor: nil, limit: 20)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/briefs", query: query)

        XCTAssertNotNil(url)
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertEqual(items.first(where: { $0.name == "limit" })?.value, "20")
        XCTAssertNil(items.first(where: { $0.name == "cursor" }), "cursor query item must be absent when cursor is nil")
    }

    // MARK: - PaginatedResponse<Brief> decoding

    func testPaginatedBriefDecodesEnvelopeWithTwoItems() throws {
        let json = """
        {
            "items": [
                {
                    "id": 10,
                    "headline": "Brief One",
                    "intro": "Intro one.",
                    "generated_at": "2026-06-19T06:00:00+00:00",
                    "period_start": "2026-06-18T00:00:00+00:00",
                    "period_end": "2026-06-19T00:00:00+00:00",
                    "model": "gpt-4o",
                    "topics": [
                        {
                            "position": 1,
                            "headline": "Topic A",
                            "what_happened": "Something happened.",
                            "why_it_matters": "It matters because.",
                            "historical_context": null,
                            "refs": []
                        }
                    ]
                },
                {
                    "id": 11,
                    "headline": "Brief Two",
                    "intro": null,
                    "generated_at": null,
                    "period_start": "2026-06-17T00:00:00+00:00",
                    "period_end": "2026-06-18T00:00:00+00:00",
                    "model": null,
                    "topics": []
                }
            ],
            "next_cursor": "abc123=="
        }
        """
        let response = try JSONDecoder().decode(PaginatedResponse<Brief>.self, from: Data(json.utf8))

        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.nextCursor, "abc123==")

        let first = response.items[0]
        XCTAssertEqual(first.id, 10)
        XCTAssertEqual(first.headline, "Brief One")
        XCTAssertEqual(first.topics.count, 1)
        XCTAssertEqual(first.topics[0].whatHappened, "Something happened.")

        let second = response.items[1]
        XCTAssertEqual(second.id, 11)
        XCTAssertNil(second.intro)
        XCTAssertEqual(second.topics.count, 0)
    }

    // MARK: - Private helpers

    /// Mirrors the query-building logic inside APIClient.getBriefs for URL composition tests.
    private func briefsQuery(cursor: String?, limit: Int) -> [URLQueryItem] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return query
    }
}

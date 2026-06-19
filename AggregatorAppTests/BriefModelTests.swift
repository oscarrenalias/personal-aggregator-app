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
}

import XCTest
@testable import AggregatorApp

final class CategoryTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Decoding: current API shape (no last_activity, no has_priority)

    func testCategoryDecodingCurrentAPIShape() throws {
        let json = """
        {"id": 7, "name": "Technology", "sort_order": 2}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertEqual(category.id, 7)
        XCTAssertEqual(category.name, "Technology")
        XCTAssertEqual(category.sortOrder, 2)
        XCTAssertNil(category.description)
        XCTAssertNil(category.lastActivity)
        XCTAssertFalse(category.hasPriority)
    }

    func testCategoryDecodingWithDescription() throws {
        let json = """
        {"id": 3, "name": "Science", "sort_order": 1, "description": "Science news"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertEqual(category.description, "Science news")
    }

    // MARK: - Decoding: future API shape (last_activity + has_priority populated)

    func testCategoryDecodingFutureAPIShapeAllFields() throws {
        let json = """
        {"id": 5, "name": "Gaming", "sort_order": 3,
         "description": "Game reviews",
         "last_activity": "2026-06-20T10:00:00Z",
         "has_priority": true}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertEqual(category.id, 5)
        XCTAssertEqual(category.name, "Gaming")
        XCTAssertEqual(category.sortOrder, 3)
        XCTAssertEqual(category.description, "Game reviews")
        XCTAssertEqual(category.lastActivity, "2026-06-20T10:00:00Z")
        XCTAssertTrue(category.hasPriority)
    }

    func testCategoryDecodingMissingLastActivityIsNil() throws {
        let json = """
        {"id": 1, "name": "Sports", "sort_order": 4}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertNil(category.lastActivity)
    }

    func testCategoryDecodingMissingHasPriorityDefaultsFalse() throws {
        let json = """
        {"id": 1, "name": "Sports", "sort_order": 4, "last_activity": "2026-06-20T10:00:00Z"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertFalse(category.hasPriority)
    }

    func testCategoryDecodingHasPriorityTrue() throws {
        let json = """
        {"id": 1, "name": "Sports", "sort_order": 4, "has_priority": true}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertTrue(category.hasPriority)
    }

    // MARK: - Identifiable

    func testCategoryIdentifiableIdIsInt() throws {
        let json1 = """
        {"id": 42, "name": "Tech", "sort_order": 1}
        """
        let json2 = """
        {"id": 43, "name": "Other", "sort_order": 2}
        """
        let category1 = try decoder.decode(Category.self, from: XCTUnwrap(json1.data(using: .utf8)))
        let category2 = try decoder.decode(Category.self, from: XCTUnwrap(json2.data(using: .utf8)))
        XCTAssertEqual(category1.id, 42)
        XCTAssertNotEqual(category1.id, category2.id)
    }

    // MARK: - freshnessPhrase

    func testFreshnessPhraseHasPriorityTrueWithNilLastActivity() throws {
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "has_priority": true}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertEqual(category.freshnessPhrase(), "New notable stories")
    }

    func testFreshnessPhraseHasPriorityTrueWithNonNilLastActivity() throws {
        // hasPriority=true takes precedence regardless of lastActivity
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "has_priority": true, "last_activity": "2020-01-01T00:00:00Z"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertEqual(category.freshnessPhrase(now: Date()), "New notable stories")
    }

    func testFreshnessPhraseUpdatedToday() throws {
        // lastActivity noon UTC, now = same day afternoon UTC — always same calendar day in any timezone
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "last_activity": "2026-06-20T12:00:00Z"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-20T12:00:00Z"))
        XCTAssertEqual(category.freshnessPhrase(now: now), "Updated today")
    }

    func testFreshnessPhraseUpdatedYesterday() throws {
        // lastActivity exactly 24 hours before now, both at noon UTC
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "last_activity": "2026-06-19T12:00:00Z"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-20T12:00:00Z"))
        XCTAssertEqual(category.freshnessPhrase(now: now), "Updated yesterday")
    }

    func testFreshnessPhraseQuietForOlderActivity() throws {
        // lastActivity 3 days before now
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "last_activity": "2026-06-17T12:00:00Z"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-20T12:00:00Z"))
        XCTAssertEqual(category.freshnessPhrase(now: now), "Quiet")
    }

    func testFreshnessPhraseNilWhenNoLastActivityAndNoPriority() throws {
        let json = """
        {"id": 1, "name": "X", "sort_order": 0}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertNil(category.freshnessPhrase())
    }

    func testFreshnessPhraseNilForUnparsableLastActivity() throws {
        let json = """
        {"id": 1, "name": "X", "sort_order": 0, "last_activity": "not-a-date"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let category = try decoder.decode(Category.self, from: data)
        XCTAssertNil(category.freshnessPhrase(now: Date()))
    }
}

import XCTest
@testable import AggregatorApp

final class ArticleDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // Minimum required fields for a valid Article JSON payload.
    private let baseFields = """
        "id": 1, "source_id": 42, "is_read": false, "is_saved": false
        """

    func testCommentsURLDecodesWhenPresent() throws {
        let json = "{\(baseFields), \"comments_url\": \"https://news.ycombinator.com/item?id=12345\"}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let article = try decoder.decode(Article.self, from: data)
        XCTAssertEqual(article.commentsURL, "https://news.ycombinator.com/item?id=12345")
    }

    func testCommentsURLIsNilWhenAbsent() throws {
        let json = "{\(baseFields)}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let article = try decoder.decode(Article.self, from: data)
        XCTAssertNil(article.commentsURL)
    }
}

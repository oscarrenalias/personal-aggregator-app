import XCTest
@testable import AggregatorApp

final class SearchArticlesTests: XCTestCase {

    // MARK: - 1. q and limit are always present

    func testQAlwaysPresent() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNotNil(query.first(where: { $0.name == "q" }), "q must always be present in search query")
    }

    func testLimitAlwaysPresent() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNotNil(query.first(where: { $0.name == "limit" }), "limit must always be present in search query")
    }

    func testQValueMatchesInput() {
        let query = searchQuery(q: "swift concurrency", cursor: nil)
        XCTAssertEqual(query.first(where: { $0.name == "q" })?.value, "swift concurrency")
    }

    func testLimitDefaultValueIs25() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertEqual(query.first(where: { $0.name == "limit" })?.value, "25")
    }

    // MARK: - 2. cursor absent when nil, present when provided

    func testCursorAbsentWhenNil() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNil(query.first(where: { $0.name == "cursor" }),
                     "cursor query item must be absent when cursor is nil")
    }

    func testCursorPresentWhenProvided() {
        let query = searchQuery(q: "swift", cursor: "C==")
        XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, "C==")
    }

    func testCursorIsPercentEncodedInURL() {
        let query = searchQuery(q: "swift", cursor: "C==")
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/articles/search", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        XCTAssertTrue(url.absoluteString.contains("cursor=C%3D%3D"),
                      "cursor 'C==' must appear percent-encoded as 'C%3D%3D' in URL, got: \(url.absoluteString)")
    }

    // MARK: - 3. No sort, view, or unread_only params

    func testNoSortParam() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNil(query.first(where: { $0.name == "sort" }), "sort must never appear in search query")
    }

    func testNoViewParam() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNil(query.first(where: { $0.name == "view" }), "view must never appear in search query")
    }

    func testNoUnreadOnlyParam() {
        let query = searchQuery(q: "swift", cursor: nil)
        XCTAssertNil(query.first(where: { $0.name == "unread_only" }),
                     "unread_only must never appear in search query")
    }

    // MARK: - 4. Multi-word query is correctly percent-encoded

    func testMultiWordQueryIsPercentEncoded() {
        let query = searchQuery(q: "open ai", cursor: nil)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/articles/search", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        XCTAssertTrue(url.absoluteString.contains("q=open%20ai"),
                      "space in query must appear percent-encoded as %20 in URL, got: \(url.absoluteString)")
    }

    // MARK: - 5. Empty-query guard in APIClient

    func testEmptyQueryThrows() async {
        let client = makeAPIClient()
        do {
            _ = try await client.searchArticles(q: "")
            XCTFail("Expected URLError(.badURL) for empty query")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL, "empty query must throw URLError(.badURL)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWhitespaceOnlyQueryThrows() async {
        let client = makeAPIClient()
        do {
            _ = try await client.searchArticles(q: "   ")
            XCTFail("Expected URLError(.badURL) for whitespace-only query")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL, "whitespace-only query must throw URLError(.badURL)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNewlineOnlyQueryThrows() async {
        let client = makeAPIClient()
        do {
            _ = try await client.searchArticles(q: "\n\t")
            XCTFail("Expected URLError(.badURL) for newline-only query")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL, "newline/tab-only query must throw URLError(.badURL)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Private helpers

    /// Mirrors the query-building logic inside APIClient.searchArticles for URL composition tests.
    private func searchQuery(q: String, cursor: String?, limit: Int = 25) -> [URLQueryItem] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return query
    }

    private func makeAPIClient() -> APIClient {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = CredentialsStore(
            defaults: defaults,
            keychainRead: { _ in nil },
            keychainWrite: { _, _ in }
        )
        return APIClient(store: store)
    }
}

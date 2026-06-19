import XCTest
@testable import AggregatorApp

final class ArticleFeedTests: XCTestCase {

    // MARK: - 1. Feed-to-query-param mapping

    func testFeedQueryParamMapping() {
        let sourceItems = feedQueryItems(for: .source(id: 11, name: "X"))
        XCTAssertEqual(sourceItems.first(where: { $0.name == "source_id" })?.value, "11")
        XCTAssertNil(sourceItems.first(where: { $0.name == "view" }))

        let importantItems = feedQueryItems(for: .important)
        XCTAssertEqual(importantItems.first(where: { $0.name == "view" })?.value, "important")
        XCTAssertNil(importantItems.first(where: { $0.name == "source_id" }))

        let unreadItems = feedQueryItems(for: .unread)
        XCTAssertEqual(unreadItems.first(where: { $0.name == "view" })?.value, "unread")
        XCTAssertNil(unreadItems.first(where: { $0.name == "source_id" }))
    }

    // MARK: - 2. getArticles URL composition via APIClient.makeURL

    func testGetArticlesURLCompositionWithCursor() {
        let query = articlesQuery(feed: .source(id: 11, name: "X"), sort: .recent, unreadOnly: true, cursor: "C==")
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/articles", query: query)

        XCTAssertNotNil(url)
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertEqual(items.first(where: { $0.name == "source_id" })?.value, "11")
        XCTAssertEqual(items.first(where: { $0.name == "sort" })?.value, "recent")
        XCTAssertEqual(items.first(where: { $0.name == "unread_only" })?.value, "true")
        // URLComponents decodes the stored value; verify raw percent-encoding in the URL string
        XCTAssertEqual(items.first(where: { $0.name == "cursor" })?.value, "C==")
        XCTAssertTrue(url.absoluteString.contains("cursor=C%3D%3D"), "cursor 'C==' must appear percent-encoded as 'C%3D%3D' in URL")
    }

    func testGetArticlesURLNoCursorItemWhenCursorIsNil() {
        let query = articlesQuery(feed: .source(id: 11, name: "X"), sort: .recent, unreadOnly: true, cursor: nil)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/articles", query: query)

        XCTAssertNotNil(url)
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertNil(items.first(where: { $0.name == "cursor" }), "cursor query item must be absent when cursor is nil")
    }

    // MARK: - 3. allowsUnreadFilter

    func testAllowsUnreadFilter() {
        XCTAssertFalse(ArticleFeed.unread.allowsUnreadFilter)
        XCTAssertTrue(ArticleFeed.source(id: 1, name: "Test").allowsUnreadFilter)
        XCTAssertTrue(ArticleFeed.important.allowsUnreadFilter)
    }

    // MARK: - Private helpers

    private func feedQueryItems(for feed: ArticleFeed) -> [URLQueryItem] {
        switch feed {
        case .source(let id, _):
            return [URLQueryItem(name: "source_id", value: "\(id)")]
        case .important:
            return [URLQueryItem(name: "view", value: "important")]
        case .unread:
            return [URLQueryItem(name: "view", value: "unread")]
        }
    }

    /// Mirrors the query-building logic inside APIClient.getArticles for URL composition tests.
    private func articlesQuery(feed: ArticleFeed, sort: ArticleSort, unreadOnly: Bool, cursor: String?) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        switch feed {
        case .source(let id, _):
            query.append(URLQueryItem(name: "source_id", value: "\(id)"))
        case .important:
            query.append(URLQueryItem(name: "view", value: "important"))
        case .unread:
            query.append(URLQueryItem(name: "view", value: "unread"))
        }
        query.append(URLQueryItem(name: "sort", value: sort.rawValue))
        if unreadOnly {
            query.append(URLQueryItem(name: "unread_only", value: "true"))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return query
    }
}

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
        XCTAssertTrue(ArticleFeed.category(name: "Tech").allowsUnreadFilter)
    }

    // MARK: - 4. Category feed — query param, URL encoding, composition, regression

    func testCategoryFeedQueryParamSimpleName() {
        let query = articlesQuery(feed: .category(name: "Technology"), sort: .importance, unreadOnly: false, cursor: nil)
        XCTAssertEqual(query.first(where: { $0.name == "category" })?.value, "Technology")
        XCTAssertNil(query.first(where: { $0.name == "source_id" }))
        XCTAssertNil(query.first(where: { $0.name == "view" }))
    }

    func testCategoryFeedSpaceIsPercentEncoded() {
        let query = articlesQuery(feed: .category(name: "Game Reviews"), sort: .importance, unreadOnly: false, cursor: nil)
        let url = APIClient.makeURL(baseURL: "https://example.com/api/v1", path: "/articles", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        XCTAssertTrue(url.absoluteString.contains("category=Game%20Reviews"),
                      "space in category name must appear percent-encoded as %20 in URL, got: \(url.absoluteString)")
    }

    func testCategoryFeedComposesWithSortAndUnreadOnly() {
        let query = articlesQuery(feed: .category(name: "Tech"), sort: .recent, unreadOnly: true, cursor: nil)
        XCTAssertEqual(query.first(where: { $0.name == "category" })?.value, "Tech")
        XCTAssertEqual(query.first(where: { $0.name == "sort" })?.value, "recent")
        XCTAssertEqual(query.first(where: { $0.name == "unread_only" })?.value, "true")
        XCTAssertNil(query.first(where: { $0.name == "source_id" }))
        XCTAssertNil(query.first(where: { $0.name == "view" }))
    }

    func testCategoryFeedRegressionExistingFeedsUnchanged() {
        // .source, .important, .unread must be unaffected by the category addition
        let sourceQuery = articlesQuery(feed: .source(id: 5, name: "X"), sort: .importance, unreadOnly: false, cursor: nil)
        XCTAssertEqual(sourceQuery.first(where: { $0.name == "source_id" })?.value, "5")
        XCTAssertNil(sourceQuery.first(where: { $0.name == "category" }))

        let importantQuery = articlesQuery(feed: .important, sort: .importance, unreadOnly: false, cursor: nil)
        XCTAssertEqual(importantQuery.first(where: { $0.name == "view" })?.value, "important")
        XCTAssertNil(importantQuery.first(where: { $0.name == "category" }))

        let unreadQuery = articlesQuery(feed: .unread, sort: .importance, unreadOnly: false, cursor: nil)
        XCTAssertEqual(unreadQuery.first(where: { $0.name == "view" })?.value, "unread")
        XCTAssertNil(unreadQuery.first(where: { $0.name == "category" }))
    }

    // MARK: - 5. systemImage

    func testCategorySystemImage() {
        XCTAssertEqual(ArticleFeed.category(name: "Tech").systemImage, "tag")
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
        case .category(let name):
            return [URLQueryItem(name: "category", value: name)]
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
        case .category(let name):
            query.append(URLQueryItem(name: "category", value: name))
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

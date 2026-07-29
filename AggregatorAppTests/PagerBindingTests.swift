import XCTest
import SwiftUI
@testable import AggregatorApp

/// Regression tests for the pager @Binding fix.
///
/// Before the fix, ArticlePagerView and ThreadPagerView held `let` snapshots of
/// the article/thread arrays captured at navigation time. When loadNextPage()
/// appended items to the list's @State, the pager's copy was stale. These tests
/// verify the @Binding property reads through to the live backing array.
final class PagerBindingTests: XCTestCase {

    // MARK: - JSON fixtures

    private func articleJSON(id: Int) -> Data {
        Data("""
        {"id":\(id),"title":"Article \(id)","url":"https://example.com/\(id)",\
        "source_id":1,"is_read":false,"is_saved":false,"topics":[],"categories":[]}
        """.utf8)
    }

    private func threadJSON(id: Int) -> Data {
        // Use JSONDecoder().decode(Thread.self,...) callers — Thread is unambiguous there
        // because Foundation.Thread (NSThread) is not Decodable.
        Data("""
        {"id":\(id),"representative_title":"Thread \(id)","known_facts":[],\
        "status":"active","first_seen":"2026-01-01T00:00:00Z",\
        "last_updated":"2026-01-01T00:00:00Z","source_count":1,"member_count":1,\
        "has_updates":false,"dismissed":false}
        """.utf8)
    }

    // MARK: - ArticlePagerView

    func testArticlePagerSeesAppendedArticlesViaBinding() throws {
        var articlesArray = try [articleJSON(id: 1), articleJSON(id: 2)].map {
            try JSONDecoder().decode(Article.self, from: $0)
        }
        let binding = Binding(get: { articlesArray }, set: { articlesArray = $0 })
        let pager = ArticlePagerView(articles: binding, startIndex: 0)

        XCTAssertEqual(pager.articles.count, 2)

        // Simulate loadNextPage() appending after the pager was created
        articlesArray.append(try JSONDecoder().decode(Article.self, from: articleJSON(id: 3)))

        // Must see the appended article through the live binding
        XCTAssertEqual(pager.articles.count, 3,
            "ArticlePagerView must see articles appended after creation via @Binding")
    }

    func testArticlePagerInitialCountMatchesBoundArray() throws {
        var articlesArray = try [articleJSON(id: 10), articleJSON(id: 20), articleJSON(id: 30)].map {
            try JSONDecoder().decode(Article.self, from: $0)
        }
        let binding = Binding(get: { articlesArray }, set: { articlesArray = $0 })
        let pager = ArticlePagerView(articles: binding, startIndex: 1)

        XCTAssertEqual(pager.articles.count, 3)
    }

    // MARK: - ThreadPagerView
    // Note: Thread.self in decode(_:from:) is unambiguous — Foundation.Thread is not Decodable.

    func testThreadPagerSeesAppendedThreadsViaBinding() throws {
        var threadsArray = try [threadJSON(id: 1), threadJSON(id: 2)].map {
            try JSONDecoder().decode(Thread.self, from: $0)
        }
        let binding = Binding(get: { threadsArray }, set: { threadsArray = $0 })
        let pager = ThreadPagerView(threads: binding, startIndex: 0)

        XCTAssertEqual(pager.threads.count, 2)

        // Simulate loadNextPage() appending after the pager was created
        threadsArray.append(try JSONDecoder().decode(Thread.self, from: threadJSON(id: 3)))

        // Must see the appended thread through the live binding
        XCTAssertEqual(pager.threads.count, 3,
            "ThreadPagerView must see threads appended after creation via @Binding")
    }

    func testThreadPagerInitialCountMatchesBoundArray() throws {
        var threadsArray = try [threadJSON(id: 10), threadJSON(id: 20)].map {
            try JSONDecoder().decode(Thread.self, from: $0)
        }
        let binding = Binding(get: { threadsArray }, set: { threadsArray = $0 })
        let pager = ThreadPagerView(threads: binding, startIndex: 0)

        XCTAssertEqual(pager.threads.count, 2)
    }
}

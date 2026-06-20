import XCTest
@testable import AggregatorApp

final class SourceDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // JSON that only contains fields present in the current API shape.
    private func minimalJSON(id: Int = 1, name: String = "BBC", feedURL: String = "https://feeds.bbci.co.uk/news/rss.xml") -> Data {
        let json = "{\"id\":\(id),\"name\":\"\(name)\",\"feed_url\":\"\(feedURL)\"}"
        return json.data(using: .utf8)!
    }

    func testMinimalJSONProducesHasNewFalse() throws {
        let source = try decoder.decode(Source.self, from: minimalJSON())
        XCTAssertFalse(source.hasNew)
    }

    func testMinimalJSONProducesHasPriorityFalse() throws {
        let source = try decoder.decode(Source.self, from: minimalJSON())
        XCTAssertFalse(source.hasPriority)
    }

    func testMinimalJSONDecodesRequiredFields() throws {
        let source = try decoder.decode(Source.self, from: minimalJSON())
        XCTAssertEqual(source.id, 1)
        XCTAssertEqual(source.name, "BBC")
        XCTAssertEqual(source.feedURL, "https://feeds.bbci.co.uk/news/rss.xml")
    }

    func testHasNewTrueDecodesCorrectly() throws {
        let json = "{\"id\":2,\"name\":\"Reuters\",\"feed_url\":\"https://feeds.reuters.com/rss.xml\",\"has_new\":true,\"has_priority\":false}"
        let source = try decoder.decode(Source.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(source.hasNew)
        XCTAssertFalse(source.hasPriority)
    }

    func testHasPriorityTrueDecodesCorrectly() throws {
        let json = "{\"id\":3,\"name\":\"AP\",\"feed_url\":\"https://feeds.ap.org/rss.xml\",\"has_new\":false,\"has_priority\":true}"
        let source = try decoder.decode(Source.self, from: json.data(using: .utf8)!)
        XCTAssertFalse(source.hasNew)
        XCTAssertTrue(source.hasPriority)
    }

    func testBothFlagsTrue() throws {
        let json = "{\"id\":4,\"name\":\"NPR\",\"feed_url\":\"https://feeds.npr.org/rss.xml\",\"has_new\":true,\"has_priority\":true}"
        let source = try decoder.decode(Source.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(source.hasNew)
        XCTAssertTrue(source.hasPriority)
    }
}

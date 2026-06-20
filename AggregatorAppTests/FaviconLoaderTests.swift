import XCTest
@testable import AggregatorApp

final class FaviconLoaderTests: XCTestCase {

    func testIconURLForHTTPSFeedURL() {
        let url = FaviconLoader.iconURL(forFeedURL: "https://feeds.bbci.co.uk/news/rss.xml")
        XCTAssertEqual(url?.absoluteString, "https://icons.duckduckgo.com/ip3/feeds.bbci.co.uk.ico")
    }

    func testIconURLForHTTPFeedURL() {
        let url = FaviconLoader.iconURL(forFeedURL: "http://feeds.example.com/rss")
        XCTAssertEqual(url?.absoluteString, "https://icons.duckduckgo.com/ip3/feeds.example.com.ico")
    }

    func testIconURLForEmptyStringReturnsNil() {
        XCTAssertNil(FaviconLoader.iconURL(forFeedURL: ""))
    }

    func testIconURLForNonURLStringReturnsNil() {
        XCTAssertNil(FaviconLoader.iconURL(forFeedURL: "not a url at all"))
    }

    func testIconURLForURLWithNoHostReturnsNil() {
        // A string that parses as a URL but has no host component.
        XCTAssertNil(FaviconLoader.iconURL(forFeedURL: "file:///local/path"))
    }
}

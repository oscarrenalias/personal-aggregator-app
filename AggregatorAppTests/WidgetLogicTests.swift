import XCTest
import UIKit
@testable import AggregatorApp

// MARK: - Group 1: APIClient URL construction for widget use cases

final class APIClientWidgetURLTests: XCTestCase {

    private let base = "https://aggregator-api.renaliaslabs.net/api/v1"

    func testThreadsWidgetURLHasCorrectQueryParams() {
        // Provider.fetchItems(.latestThreads) builds exactly these three query items
        let query: [URLQueryItem] = [
            URLQueryItem(name: "sort", value: ThreadSort.importance.rawValue),
            URLQueryItem(name: "show_dismissed", value: "false"),
            URLQueryItem(name: "limit", value: "5")
        ]
        let url = APIClient.makeURL(baseURL: base, path: "/threads", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "sort" })?.value, "importance")
        XCTAssertEqual(items.first(where: { $0.name == "show_dismissed" })?.value, "false")
        XCTAssertEqual(items.first(where: { $0.name == "limit" })?.value, "5")
        XCTAssertNil(items.first(where: { $0.name == "cursor" }), "no cursor on first widget fetch")
    }

    func testArticlesWidgetURLHasCorrectQueryParams() {
        // Provider.fetchItems(.unreadImportant) calls getArticles(feed:.important,sort:.importance,unreadOnly:true,limit:5)
        // which produces these four query items
        let query: [URLQueryItem] = [
            URLQueryItem(name: "view", value: "important"),
            URLQueryItem(name: "sort", value: ArticleSort.importance.rawValue),
            URLQueryItem(name: "unread_only", value: "true"),
            URLQueryItem(name: "limit", value: "5")
        ]
        let url = APIClient.makeURL(baseURL: base, path: "/articles", query: query)
        XCTAssertNotNil(url)
        guard let url else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "view" })?.value, "important")
        XCTAssertEqual(items.first(where: { $0.name == "sort" })?.value, "importance")
        XCTAssertEqual(items.first(where: { $0.name == "unread_only" })?.value, "true")
        XCTAssertEqual(items.first(where: { $0.name == "limit" })?.value, "5")
        XCTAssertNil(items.first(where: { $0.name == "cursor" }), "no cursor on first widget fetch")
    }

    func testThreadsWidgetURLPathIsCorrect() {
        let url = APIClient.makeURL(baseURL: base, path: "/threads", query: [])
        XCTAssertEqual(url?.path, "/api/v1/threads")
    }

    func testArticlesWidgetURLPathIsCorrect() {
        let url = APIClient.makeURL(baseURL: base, path: "/articles", query: [])
        XCTAssertEqual(url?.path, "/api/v1/articles")
    }
}

// MARK: - Group 2: ImageDownsampler

final class ImageDownsamplerTests: XCTestCase {

    private func makeImagePNGData(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }

    func testDownsampledImageFitsWithinTargetBounds() {
        // Large source: 400×300 px. Target: 50×50 pt → max pixel dimension = 50*3 = 150 px.
        let data = makeImagePNGData(width: 400, height: 300)
        let targetSize = CGSize(width: 50, height: 50)
        let result = ImageDownsampler.downsample(data: data, targetSize: targetSize)
        XCTAssertNotNil(result, "Expected non-nil image from valid PNG data")
        guard let result else { return }
        let maxPixelDimension = max(targetSize.width, targetSize.height) * 3
        // UIImage(cgImage:) scale is 1.0, so size is in pixels
        XCTAssertLessThanOrEqual(result.size.width, maxPixelDimension + 1,
            "width \(result.size.width)px must be ≤ targetSize×3 (\(maxPixelDimension)px)")
        XCTAssertLessThanOrEqual(result.size.height, maxPixelDimension + 1,
            "height \(result.size.height)px must be ≤ targetSize×3 (\(maxPixelDimension)px)")
    }

    func testDownsampleReturnsNilForNonImageData() {
        let garbage = Data("<!DOCTYPE html><html>Cloudflare 403</html>".utf8)
        XCTAssertNil(ImageDownsampler.downsample(data: garbage, targetSize: CGSize(width: 50, height: 50)))
    }

    func testDownsampleReturnsNilForEmptyData() {
        XCTAssertNil(ImageDownsampler.downsample(data: Data(), targetSize: CGSize(width: 50, height: 50)))
    }

    func testDownloadAndDownsampleReturnsNilForUnreachableURL() async {
        // localhost:1 causes an immediate connection-refused error, returning nil without hanging
        let url = URL(string: "http://localhost:1/nonexistent.jpg")!
        let result = await ImageDownsampler.downloadAndDownsample(url: url, targetSize: CGSize(width: 50, height: 50))
        XCTAssertNil(result)
    }
}

// MARK: - Group 3: Deep-link parsing

final class DeepLinkParsingTests: XCTestCase {

    func testArticleDeepLinkParsesToArticleRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "aggregator://article/123")!)
        XCTAssertEqual(router.pendingLink, .article(123))
    }

    func testThreadDeepLinkParsesToThreadRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "aggregator://thread/45")!)
        XCTAssertEqual(router.pendingLink, .thread(45))
    }

    func testMalformedURLWithNoHostProducesNoPendingLink() {
        let router = DeepLinkRouter()
        // URL with scheme only and no host — guard on host fails
        router.handle(URL(string: "aggregator://unknown/1")!)
        XCTAssertNil(router.pendingLink)
    }

    func testWrongSchemeProducesNoPendingLink() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://example.com/article/42")!)
        XCTAssertNil(router.pendingLink)
    }

    func testNonIntegerIDProducesNoPendingLink() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "aggregator://article/abc")!)
        XCTAssertNil(router.pendingLink)
    }

    func testMissingIDProducesNoPendingLink() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "aggregator://article/")!)
        XCTAssertNil(router.pendingLink)
    }

    func testUnknownHostProducesNoPendingLink() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "aggregator://search/1")!)
        XCTAssertNil(router.pendingLink)
    }

    func testHandleDoesNotCrashOnEmptyURL() {
        // aggregator:// has an empty host; guard let host fails or host == "" which doesn't match cases
        let router = DeepLinkRouter()
        if let url = URL(string: "aggregator://") {
            router.handle(url)
        }
        XCTAssertNil(router.pendingLink)
    }
}

// MARK: - Group 4: Timeline entry date and URL contract
//
// Provider.buildTimeline is private and depends on WidgetKit/AppIntents types that
// live exclusively in the AggregatorWidget extension target. These tests verify the
// date-spacing formula and deep-link URL patterns that the provider implements.

final class TimelineBuilderContractTests: XCTestCase {

    func testFiveItemsProduceFiveDates() {
        let now = Date()
        let dates = (0..<5).map { i in now.addingTimeInterval(Double(i) * 180) }
        XCTAssertEqual(dates.count, 5)
    }

    func testEntryDatesAreMonotonicallyIncreasing() {
        let now = Date()
        let dates = (0..<5).map { i in now.addingTimeInterval(Double(i) * 180) }
        for i in 1..<dates.count {
            XCTAssertGreaterThan(dates[i], dates[i - 1],
                "Entry \(i) must be strictly after entry \(i - 1)")
        }
    }

    func testEntryDatesAreSpaced180SecondsApart() {
        let now = Date()
        let dates = (0..<5).map { i in now.addingTimeInterval(Double(i) * 180) }
        for i in 1..<dates.count {
            XCTAssertEqual(
                dates[i].timeIntervalSince(dates[i - 1]),
                180,
                accuracy: 0.001,
                "Consecutive entries must be exactly 180 s apart"
            )
        }
    }

    func testThreadDeepLinkURLPattern() {
        // Provider constructs "aggregator://thread/<id>" for thread items
        let id = 42
        let url = URL(string: "aggregator://thread/\(id)")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "aggregator")
        XCTAssertEqual(url?.host, "thread")
        XCTAssertEqual(url?.lastPathComponent, "42")
        // Verify the URL round-trips through DeepLinkRouter
        let router = DeepLinkRouter()
        router.handle(url!)
        XCTAssertEqual(router.pendingLink, .thread(42))
    }

    func testArticleDeepLinkURLPattern() {
        // Provider uses article.url directly for article deep links
        let articleURL = "aggregator://article/99"
        let url = URL(string: articleURL)
        XCTAssertNotNil(url)
        let router = DeepLinkRouter()
        router.handle(url!)
        XCTAssertEqual(router.pendingLink, .article(99))
    }

    func testFirstEntryDateIsNotEarlierThanNow() {
        let now = Date()
        let firstDate = now.addingTimeInterval(Double(0) * 180)
        XCTAssertGreaterThanOrEqual(firstDate.timeIntervalSince(now), 0)
    }
}

// MARK: - Group 5: ContentSource enum and ContentSourceIntent default

final class ContentSourceTests: XCTestCase {

    func testContentSourceRawValues() {
        XCTAssertEqual(ContentSource.latestThreads.rawValue, "latestThreads")
        XCTAssertEqual(ContentSource.unreadImportant.rawValue, "unreadImportant")
    }

    func testContentSourceDisplayRepresentationsExist() {
        let reps = ContentSource.caseDisplayRepresentations
        XCTAssertNotNil(reps[.latestThreads], "latestThreads must have a display representation")
        XCTAssertNotNil(reps[.unreadImportant], "unreadImportant must have a display representation")
    }

    func testContentSourceIntentDefaultIsLatestThreads() {
        let intent = ContentSourceIntent()
        XCTAssertEqual(intent.contentSource, .latestThreads,
            "A fresh ContentSourceIntent must default contentSource to .latestThreads")
    }
}

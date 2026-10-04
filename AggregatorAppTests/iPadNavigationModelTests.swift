import XCTest
@testable import AggregatorApp

final class iPadNavigationModelTests: XCTestCase {

    func testDefaultSelectedSectionIsThreads() {
        let model = iPadNavigationModel()
        XCTAssertEqual(model.selectedSection, .threads)
    }

    func testAllAppSectionsHaveUniqueIds() {
        let ids = AppSection.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, AppSection.allCases.count)
    }

    func testAppSectionIdMatchesRawValue() {
        for section in AppSection.allCases {
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func testSelectedSectionCanBeSetToAllCases() {
        let model = iPadNavigationModel()
        for section in AppSection.allCases {
            model.selectedSection = section
            XCTAssertEqual(model.selectedSection, section)
        }
    }

    func testInitialOptionalSelectionsAreNil() {
        let model = iPadNavigationModel()
        XCTAssertNil(model.selectedThread)
        XCTAssertNil(model.selectedArticle)
        XCTAssertNil(model.selectedSource)
        XCTAssertNil(model.selectedEpisode)
        XCTAssertNil(model.selectedFeed)
        XCTAssertNil(model.selectedBrief)
    }

    func testAllAppSectionsCovered() {
        XCTAssertEqual(AppSection.allCases.count, 6,
            "AppSection must have exactly 6 cases: threads, sources, today, podcasts, search, settings")
        XCTAssertTrue(AppSection.allCases.contains(.threads))
        XCTAssertTrue(AppSection.allCases.contains(.sources))
        XCTAssertTrue(AppSection.allCases.contains(.today))
        XCTAssertTrue(AppSection.allCases.contains(.podcasts))
        XCTAssertTrue(AppSection.allCases.contains(.search))
        XCTAssertTrue(AppSection.allCases.contains(.settings))
    }
}

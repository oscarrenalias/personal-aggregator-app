import XCTest
@testable import AggregatorApp

final class ListPreferencesTests: XCTestCase {

    private func makeSuite() -> UserDefaults {
        let suiteName = "ListPreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testDefaultValues() {
        let prefs = ListPreferences(defaults: makeSuite())
        XCTAssertEqual(prefs.threadsSort, .importance)
        XCTAssertFalse(prefs.threadsShowDismissed)
    }

    func testValuesPersistedAndRestoredAcrossInstances() {
        let defaults = makeSuite()

        let prefs1 = ListPreferences(defaults: defaults)
        prefs1.threadsSort = .recent
        prefs1.threadsShowDismissed = true

        let prefs2 = ListPreferences(defaults: defaults)
        XCTAssertEqual(prefs2.threadsSort, .recent, "threadsSort should survive a new instance reading the same suite")
        XCTAssertTrue(prefs2.threadsShowDismissed, "threadsShowDismissed should survive a new instance reading the same suite")
    }
}

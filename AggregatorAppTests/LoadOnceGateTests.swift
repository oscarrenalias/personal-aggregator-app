import XCTest
@testable import AggregatorApp

/// Regression tests for the load-once gate that prevents ArticleListView and
/// ThreadsView from reloading when the user returns from a detail view.
final class LoadOnceGateTests: XCTestCase {

    func testFirstCallReturnsTrue() {
        var gate = LoadOnceGate()
        XCTAssertTrue(gate.shouldLoad(), "first call must return true so the initial load runs")
        XCTAssertTrue(gate.hasLoaded)
    }

    func testSubsequentCallsReturnFalse() {
        var gate = LoadOnceGate()
        _ = gate.shouldLoad()
        XCTAssertFalse(gate.shouldLoad(), "second call must be a no-op — view reappeared after popping detail")
        XCTAssertFalse(gate.shouldLoad(), "third call must also be a no-op")
    }

    func testGatePermitsExactlyOneLoad() {
        var gate = LoadOnceGate()
        var loadCount = 0
        for _ in 0..<5 {
            if gate.shouldLoad() { loadCount += 1 }
        }
        XCTAssertEqual(loadCount, 1, "gate must allow exactly one load regardless of how many times the view reappears")
    }
}

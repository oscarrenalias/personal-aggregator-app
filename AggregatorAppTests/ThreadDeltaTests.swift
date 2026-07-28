import XCTest
@testable import AggregatorApp

final class ThreadDeltaTests: XCTestCase {

    private let decoder = JSONDecoder()

    // A minimal Thread JSON payload without deltas or last_viewed_at.
    private func baseThreadJSON(extras: String = "") -> String {
        """
        {
            "id": 1,
            "representative_title": "Test Thread",
            "rolling_summary": null,
            "known_facts": [],
            "status": "active",
            "novelty_label": null,
            "first_seen": "2026-07-01T00:00:00+00:00",
            "last_updated": "2026-07-28T00:00:00+00:00",
            "source_count": 2,
            "member_count": 3,
            "image_url": null,
            "has_updates": false,
            "dismissed": false,
            "top_grade": null\(extras.isEmpty ? "" : ", \(extras)")
        }
        """
    }

    // MARK: - Thread decoding: absent deltas and last_viewed_at

    func testThreadDecodesWithNoDeltasOrLastViewedAt() throws {
        let thread = try decoder.decode(Thread.self, from: Data(baseThreadJSON().utf8))
        XCTAssertTrue(thread.deltas.isEmpty, "deltas must default to [] when key is absent")
        XCTAssertNil(thread.lastViewedAt, "lastViewedAt must be nil when key is absent")
    }

    // MARK: - Thread decoding: last_viewed_at present

    func testThreadDecodesWithLastViewedAt() throws {
        let json = baseThreadJSON(extras: "\"last_viewed_at\": \"2026-07-27T12:00:00+00:00\"")
        let thread = try decoder.decode(Thread.self, from: Data(json.utf8))
        XCTAssertEqual(thread.lastViewedAt, "2026-07-27T12:00:00+00:00")
    }

    // MARK: - Thread decoding: deltas populated

    func testThreadDecodesWithDeltasArray() throws {
        let json = baseThreadJSON(extras: """
            "deltas": [
                {
                    "timestamp": "2026-07-28T08:00:00+00:00",
                    "article_id": 99,
                    "label": "same_thread_new_fact",
                    "new_facts": ["Fact A", "Fact B"],
                    "reason": "Clarifies prior reporting",
                    "absorbed_id": 55,
                    "type": "update"
                }
            ]
            """)
        let thread = try decoder.decode(Thread.self, from: Data(json.utf8))
        XCTAssertEqual(thread.deltas.count, 1)
        let d = thread.deltas[0]
        XCTAssertEqual(d.timestamp, "2026-07-28T08:00:00+00:00")
        XCTAssertEqual(d.articleId, 99)
        XCTAssertEqual(d.label, "same_thread_new_fact")
        XCTAssertEqual(d.newFacts, ["Fact A", "Fact B"])
        XCTAssertEqual(d.reason, "Clarifies prior reporting")
        XCTAssertEqual(d.absorbedId, 55)
        XCTAssertEqual(d.type, "update")
    }

    // MARK: - Thread encoding: deltas and lastViewedAt appear in output

    func testThreadEncodeIncludesDeltasAndLastViewedAt() throws {
        // Decode a thread with both fields populated, then re-encode and verify keys survive.
        let json = baseThreadJSON(extras: """
            "last_viewed_at": "2026-07-27T12:00:00+00:00",
            "deltas": [
                {
                    "timestamp": "2026-07-28T08:00:00+00:00",
                    "article_id": 1,
                    "label": "same_thread_new_fact",
                    "new_facts": ["New info"],
                    "reason": null,
                    "absorbed_id": null,
                    "type": "update"
                }
            ]
            """)
        let thread = try decoder.decode(Thread.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(thread)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(obj["last_viewed_at"], "last_viewed_at must be present when non-nil")
        XCTAssertEqual((obj["deltas"] as? [[String: Any]])?.count, 1, "deltas array must appear in output")
    }

    // MARK: - ThreadDelta decoding: all optional fields absent

    func testThreadDeltaDecodesWithOnlyRequiredFields() throws {
        let json = """
        {
            "timestamp": "2026-07-28T09:00:00+00:00",
            "new_facts": []
        }
        """
        let delta = try decoder.decode(ThreadDelta.self, from: Data(json.utf8))
        XCTAssertEqual(delta.timestamp, "2026-07-28T09:00:00+00:00")
        XCTAssertEqual(delta.newFacts, [])
        XCTAssertNil(delta.articleId)
        XCTAssertNil(delta.label)
        XCTAssertNil(delta.reason)
        XCTAssertNil(delta.absorbedId)
        XCTAssertNil(delta.type)
    }

    // MARK: - filterNewDeltas: nil cutoff returns all content-bearing deltas

    func testFilterNewDeltasNilCutoffReturnsAllQualifyingDeltas() {
        let deltas = [
            makeDelta(ts: "2026-07-26T00:00:00Z", label: "same_thread_new_fact", facts: ["F1"]),
            makeDelta(ts: "2026-07-27T00:00:00Z", label: nil, facts: [], reason: "Some reason"),
            makeDelta(ts: "2026-07-28T00:00:00Z", label: nil, facts: [], reason: nil),
        ]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: nil)
        // Third delta has no label, no facts, no reason — excluded
        XCTAssertEqual(result.count, 2)
    }

    func testFilterNewDeltasCutoffExcludesOlderDeltas() {
        let cutoff = "2026-07-27T00:00:00Z"
        let deltas = [
            makeDelta(ts: "2026-07-26T00:00:00Z", label: "same_thread_new_fact", facts: ["F1"]),
            makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_angle", facts: ["F2"]),
        ]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: cutoff)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].timestamp, "2026-07-28T00:00:00Z")
    }

    func testFilterNewDeltasAllOlderThanCutoffReturnsEmpty() {
        let cutoff = "2026-07-29T00:00:00Z"
        let deltas = [
            makeDelta(ts: "2026-07-26T00:00:00Z", label: "same_thread_new_fact", facts: ["F1"]),
            makeDelta(ts: "2026-07-27T00:00:00Z", label: "same_thread_new_fact", facts: ["F2"]),
        ]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: cutoff)
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterNewDeltasEmptyInputReturnsEmpty() {
        let result = ThreadDetailView.filterNewDeltas(in: [], since: nil)
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterNewDeltasExcludesDeltasWithNoContentEvenWhenNew() {
        let cutoff = "2026-07-26T00:00:00Z"
        let deltas = [
            makeDelta(ts: "2026-07-28T00:00:00Z", label: nil, facts: [], reason: nil),
            makeDelta(ts: "2026-07-28T00:00:00Z", label: nil, facts: [], reason: ""),
        ]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: cutoff)
        XCTAssertTrue(result.isEmpty, "deltas with no label, no facts, and empty reason must be excluded")
    }

    func testFilterNewDeltasIncludesDeltaWithLabelOnly() {
        let deltas = [makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: [])]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: nil)
        XCTAssertEqual(result.count, 1)
    }

    func testFilterNewDeltasIncludesDeltaWithReasonOnly() {
        let deltas = [makeDelta(ts: "2026-07-28T00:00:00Z", label: nil, facts: [], reason: "Important context")]
        let result = ThreadDetailView.filterNewDeltas(in: deltas, since: nil)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Helpers

    private func makeDelta(
        ts: String,
        label: String?,
        facts: [String],
        reason: String? = nil
    ) -> ThreadDelta {
        ThreadDelta(
            timestamp: ts,
            articleId: nil,
            label: label,
            newFacts: facts,
            reason: reason,
            absorbedId: nil,
            type: nil
        )
    }
}

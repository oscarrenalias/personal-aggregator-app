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

    // MARK: - factsCoveredByDeltas

    func testFactsCoveredByDeltasUnionsAllNewFacts() {
        let deltas = [
            makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: ["Fact A", "Fact B"]),
            makeDelta(ts: "2026-07-29T00:00:00Z", label: "same_thread_new_fact", facts: ["Fact C"]),
        ]
        let covered = ThreadDetailView.factsCoveredByDeltas(deltas)
        XCTAssertEqual(covered, Set(["Fact A", "Fact B", "Fact C"]))
    }

    func testFactsCoveredByDeltasEmptyDeltasReturnsEmpty() {
        let covered = ThreadDetailView.factsCoveredByDeltas([])
        XCTAssertTrue(covered.isEmpty)
    }

    // MARK: - knownFacts suppression (regression: duplication between knownFacts and delta bullets)

    func testKnownFactsCardHiddenWhenAllFactsCoveredByDeltas() {
        // Bug: knownFacts card rendered even when every fact already appears as a delta bullet.
        let knownFacts = ["Fact A", "Fact B"]
        let deltas = [
            makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: ["Fact A", "Fact B"])
        ]
        let qualifying = ThreadDetailView.filterNewDeltas(in: deltas, since: nil)
        let covered = ThreadDetailView.factsCoveredByDeltas(qualifying)
        let residual = knownFacts.filter { !covered.contains($0) }
        XCTAssertTrue(residual.isEmpty, "knownFacts card must be suppressed when all facts appear in delta bullets")
    }

    func testKnownFactsCardShownWhenSomeFactsNotCovered() {
        let knownFacts = ["Fact A", "Fact B", "Fact C"]
        let deltas = [
            makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: ["Fact A"])
        ]
        let qualifying = ThreadDetailView.filterNewDeltas(in: deltas, since: nil)
        let covered = ThreadDetailView.factsCoveredByDeltas(qualifying)
        let residual = knownFacts.filter { !covered.contains($0) }
        XCTAssertFalse(residual.isEmpty, "knownFacts card must appear when at least one fact is not covered")
        XCTAssertEqual(Set(residual), Set(["Fact B", "Fact C"]),
                       "only uncovered facts should be shown in the knownFacts card")
    }

    func testKnownFactsCardShownWhenNoDeltasExist() {
        let knownFacts = ["Fact A", "Fact B"]
        let covered = ThreadDetailView.factsCoveredByDeltas([])
        let residual = knownFacts.filter { !covered.contains($0) }
        XCTAssertEqual(residual, knownFacts, "all knownFacts should appear when there are no deltas")
    }

    // MARK: - delta(for:in:) (regression: delta bullets disconnected from article rows)

    func testDeltaLookupMatchesMemberByArticleId() {
        let member = ThreadMember(
            id: 1, threadId: 10, articleId: 99,
            cleanTitle: "Test Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        let matchingDelta = ThreadDelta(
            timestamp: "2026-07-28T00:00:00Z", articleId: 99,
            label: "same_thread_new_fact", newFacts: ["New fact"],
            reason: nil, absorbedId: nil, type: nil
        )
        let otherDelta = ThreadDelta(
            timestamp: "2026-07-28T00:00:00Z", articleId: 200,
            label: "same_thread_new_fact", newFacts: ["Other fact"],
            reason: nil, absorbedId: nil, type: nil
        )
        let result = ThreadDetailView.delta(for: member, in: [matchingDelta, otherDelta])
        XCTAssertNotNil(result, "delta must match member with articleId 99")
        XCTAssertEqual(result?.newFacts, ["New fact"])
    }

    func testDeltaLookupReturnsNilForUnmatchedMember() {
        let member = ThreadMember(
            id: 2, threadId: 10, articleId: 999,
            cleanTitle: "Other Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        let delta = ThreadDelta(
            timestamp: "2026-07-28T00:00:00Z", articleId: 42,
            label: "same_thread_new_fact", newFacts: ["Some fact"],
            reason: nil, absorbedId: nil, type: nil
        )
        let result = ThreadDetailView.delta(for: member, in: [delta])
        XCTAssertNil(result, "delta must not match when articleId differs")
    }

    func testDeltaLookupIgnoresUnlinkedDeltas() {
        let member = ThreadMember(
            id: 3, threadId: 10, articleId: 77,
            cleanTitle: "Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        // Delta with articleId == nil should not match any member
        let unlinkedDelta = ThreadDelta(
            timestamp: "2026-07-28T00:00:00Z", articleId: nil,
            label: "same_thread_new_fact", newFacts: ["Unlinked fact"],
            reason: nil, absorbedId: nil, type: nil
        )
        let result = ThreadDetailView.delta(for: member, in: [unlinkedDelta])
        XCTAssertNil(result, "unlinked delta (articleId nil) must not match any member")
    }

    // MARK: - Section header logic via static helpers

    func testSectionHeaderIsArticlesWhenNoQualifyingDeltasMatchMembers() {
        let member = ThreadMember(
            id: 1, threadId: 10, articleId: 99,
            cleanTitle: "Test Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        // Delta predates the cutoff — excluded from qualifying
        let cutoff = "2026-07-28T00:00:00Z"
        let oldDelta = makeDelta(ts: "2026-07-27T00:00:00Z", label: "same_thread_new_fact", facts: ["Fact"], articleId: 99)

        let qualifying = ThreadDetailView.filterNewDeltas(in: [oldDelta], since: cutoff)
        let hasNewDeltaArticles = [member].contains { ThreadDetailView.delta(for: $0, in: qualifying) != nil }
        XCTAssertFalse(hasNewDeltaArticles, "section header must be 'Articles' when no qualifying deltas match any member")
    }

    func testSectionHeaderIsNewSinceLastVisitWhenQualifyingDeltaMatchesMember() {
        let member = ThreadMember(
            id: 1, threadId: 10, articleId: 99,
            cleanTitle: "Test Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        let cutoff = "2026-07-27T00:00:00Z"
        let newDelta = makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: ["New fact"], articleId: 99)

        let qualifying = ThreadDetailView.filterNewDeltas(in: [newDelta], since: cutoff)
        let hasNewDeltaArticles = [member].contains { ThreadDetailView.delta(for: $0, in: qualifying) != nil }
        XCTAssertTrue(hasNewDeltaArticles, "section header must be 'New since last visit' when a qualifying delta matches an active member")
    }

    // MARK: - Unlinked deltas in "Other updates"

    func testUnlinkedDeltaWithNonEmptyFactsAppearsInOtherUpdates() {
        let unlinked = makeDelta(ts: "2026-07-28T00:00:00Z", label: nil, facts: ["Unlinked fact"], articleId: nil)
        let qualifying = ThreadDetailView.filterNewDeltas(in: [unlinked], since: nil)
        let unlinkedDeltas = qualifying.filter { $0.articleId == nil && !$0.newFacts.isEmpty }
        XCTAssertEqual(unlinkedDeltas.count, 1, "unlinked delta with non-empty facts must appear in Other Updates")
        XCTAssertEqual(unlinkedDeltas[0].newFacts, ["Unlinked fact"])
    }

    func testUnlinkedDeltaWithEmptyFactsExcludedFromOtherUpdates() {
        // Qualifies via label but has no facts and no articleId — must NOT appear in unlinkedDeltas
        let unlinked = makeDelta(ts: "2026-07-28T00:00:00Z", label: "same_thread_new_fact", facts: [], articleId: nil)
        let qualifying = ThreadDetailView.filterNewDeltas(in: [unlinked], since: nil)
        let unlinkedDeltas = qualifying.filter { $0.articleId == nil && !$0.newFacts.isEmpty }
        XCTAssertTrue(unlinkedDeltas.isEmpty, "unlinked delta with empty facts must not appear in Other Updates even when it qualifies via label")
    }

    // MARK: - Regression: article rows use allDeltas (not qualifyingDeltas)

    func testOlderDeltaExcludedFromQualifyingButMatchesInAllDeltasContext() {
        // Regression: old behaviour used qualifyingDeltas for article rows, hiding pre-cutoff facts.
        // New behaviour: article rows use allDeltas (content filter only, no timestamp filter).
        let cutoff = "2026-07-28T00:00:00Z"
        let member = ThreadMember(
            id: 1, threadId: 10, articleId: 99,
            cleanTitle: "Test Article", url: nil, sourceName: nil,
            publishedAt: nil, classificationLabel: nil, suppressed: false
        )
        let oldDelta = makeDelta(ts: "2026-07-27T00:00:00Z", label: "same_thread_new_fact", facts: ["Old fact"], articleId: 99)

        // qualifyingDeltas path (timestamp + content filter) — old delta excluded
        let qualifying = ThreadDetailView.filterNewDeltas(in: [oldDelta], since: cutoff)
        XCTAssertTrue(qualifying.isEmpty, "old delta must be absent from qualifyingDeltas")

        // allDeltas path (content filter only, mirrors the private allDeltas() implementation)
        let allContent = [oldDelta].filter { d in
            d.label != nil || !d.newFacts.isEmpty || (d.reason.map { !$0.isEmpty } ?? false)
        }
        let matched = ThreadDetailView.delta(for: member, in: allContent)
        XCTAssertNotNil(matched, "old delta must match in allDeltas context for article row display")
        XCTAssertEqual(matched?.newFacts, ["Old fact"])
    }

    // MARK: - Helpers

    private func makeDelta(
        ts: String,
        label: String?,
        facts: [String],
        reason: String? = nil,
        articleId: Int? = nil
    ) -> ThreadDelta {
        ThreadDelta(
            timestamp: ts,
            articleId: articleId,
            label: label,
            newFacts: facts,
            reason: reason,
            absorbedId: nil,
            type: nil
        )
    }
}

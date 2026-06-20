---
name: "Today tab: daily brief with topics and article references"
id: spec-f03dbf5c
description: "Today tab renders GET /brief/today: headline, intro, and topics (what happened / why it matters / background) with tappable internal (reader) and external (Safari) references."
dependencies: null
priority: medium
complexity: null
status: done
tags:
- today
- brief
- reader
- navigation
scope:
  in: null
  out: null
feature_root_id: B-5ccdd6d1
---
# Today tab: daily brief with topics and article references

## Objective

Turn the Today tab from a stub into the daily brief reader: fetch today's
AI-generated brief and render its headline, intro, and topics (what happened /
why it matters / background), each with tappable references that open in the
existing article reader (internal) or the in-app Safari view (external).

## Context

- Builds on the merged reader stack: reuse `ArticleDetailView` (internal refs),
  `SafariView` (external refs), `ParagraphText` (multi-paragraph body),
  `DateDisplay`, and `APIClient`. All environment stores are injected at app root.
- Backend: `GET /brief/today` → `BriefResponse`. There is **no** historical
  briefs list endpoint and **no** JSON generate/refresh endpoint, so this tab
  shows only today's brief and cannot trigger generation.

### Verified API shape (from the live backend)

`GET /brief/today` → `BriefResponse`:
- `id: Int`, `headline: String?`, `intro: String?`, `generated_at: String?`,
  `period_start: String`, `period_end: String`, `model: String?`,
  `topics: [BriefTopicResponse]`.

`BriefTopicResponse`:
- `position: Int`, `headline: String`, `what_happened: String`,
  `why_it_matters: String`, `historical_context: String?`, `refs: [ref]`.

Each `ref` (loosely typed as an array in OpenAPI; real shape is an object):
- `title: String?`, `url: String?`, `internal: Bool`, `article_id: Int?`.
  Example: `{"url": null, "title": "GLM-5.2 …", "internal": true, "article_id": 49799}`.
- `internal == true` (with `article_id`) → an aggregator article → open in the
  reader. Otherwise (`url` present) → external link → open in Safari view.

Timestamps are ISO-8601 with fractional seconds + offset (same as elsewhere).

## Changes

### 1. Models

Add `AggregatorApp/Models/Brief.swift` (all `Decodable`; decode snake_case via
CodingKeys; decode loosely-typed/optional fields defensively):

```swift
struct Brief: Decodable, Identifiable {
    let id: Int
    let headline: String?
    let intro: String?
    let generatedAt: String?     // generated_at
    let periodStart: String      // period_start
    let periodEnd: String        // period_end
    let model: String?
    let topics: [BriefTopic]
}

struct BriefTopic: Decodable, Identifiable {
    var id: Int { position }
    let position: Int
    let headline: String
    let whatHappened: String      // what_happened
    let whyItMatters: String      // why_it_matters
    let historicalContext: String? // historical_context
    let refs: [BriefRef]
}

struct BriefRef: Decodable, Identifiable, Hashable {
    let title: String?
    let url: String?
    let `internal`: Bool
    let articleId: Int?           // article_id
    var id: String { "\(articleId.map(String.init) ?? url ?? title ?? UUID().uuidString)" }
}
```

Decode `refs` with `decodeIfPresent`, defaulting to `[]`; default `internal` to
`false` and `articleId` to `nil` when absent.

### 2. APIClient — brief endpoint

Add to `APIClient.swift`:

```swift
func getTodayBrief() async throws -> Brief {
    try await get("/brief/today")
}
```

Note: if no brief exists the backend may return a non-2xx (e.g. 404). `get`
already throws `APIError.http(status:)` for non-2xx — `TodayView` treats a 404
as the "no brief yet" empty state (see below) rather than a hard error.

### 3. TodayView — the brief reader (replace the stub)

`AggregatorApp/Today/TodayView.swift`. Wrap content in its own `NavigationStack`
(consistent with the other tabs) so refs can push the reader.

- State: `brief: Brief?`, a `phase` enum (loading / loaded / error / empty), and
  `safariURL: URL?` for external refs.
- When `!credentialsStore.isConfigured`: show the "Not configured"
  `ContentUnavailableView` pointing to Settings (same pattern as `SourcesView`).
- On appear (`.task`): fetch `getTodayBrief()`.
  - Success → `.loaded`.
  - `APIError.http(404)` (or an empty/no-brief response) → `.empty`.
  - Cancellation → ignore (use the existing `isCancellation` helper).
  - Other errors → `.error`.
- **Empty state**: `ContentUnavailableView("No brief yet", systemImage: "sparkles", description: Text("Today's brief hasn't been generated yet. Pull to refresh."))`.
- **Loading**: centered `ProgressView`. **Error**: message + Retry button.
- **Loaded** content in a `ScrollView` (use `ReaderLayout.hPadding` for horizontal insets, full-bleed nothing here):
  - Header: `headline` (`.title2`/`.bold`; fall back to "Daily Brief" if nil);
    a caption line with the brief date (from `periodStart`, rendered as an
    absolute date — see §5) and `model` when present (`.caption`, `.secondary`).
  - `intro` as body text (`ParagraphText`) when present.
  - Topics in `position` order, each rendered by `BriefTopicView` (§4).
- **Pull-to-refresh** (`.refreshable`) re-fetches today's brief.
- `.navigationTitle("Today")`.
- A `.sheet(item:)`/`.sheet(isPresented:)` presenting `SafariView(url:)` for the
  selected external ref `safariURL`.

### 4. BriefTopicView

`AggregatorApp/Today/BriefTopicView.swift`, initialised with `topic: BriefTopic`
and a closure `onExternalRef: (URL) -> Void` (to raise the Safari sheet in the
parent). A glass-card section (`.glassEffect` rounded container, consistent with
the reader's summary callout):

- `headline` (`.headline`).
- Section "What happened" — small `.subheadline`/`.bold` label + `ParagraphText(topic.whatHappened)`.
- Section "Why it matters" — same treatment with `topic.whyItMatters`.
- Section "Background" — only when `historicalContext` is non-nil/non-empty.
- **"Read" references** (when `refs` non-empty): a labelled list of refs. For each:
  - `internal == true` && `articleId != nil` → a `NavigationLink` whose
    destination is `ArticleDetailView(articleId: ref.articleId!)` (destination-based
    link, matching the Sources flow — do NOT use value-based
    `navigationDestination`), labelled with `ref.title ?? "Untitled"`.
  - else if `url` is a valid URL → a `Button` calling `onExternalRef(url)` to open
    the in-app Safari view, labelled with `ref.title ?? ref.url`.
  - else → plain `Text(ref.title ?? "")` (non-interactive).
  - Use a leading SF Symbol (e.g. `doc.text` internal, `safari` external) and
    accessibility labels.

### 5. Brief date formatting

The brief header needs an absolute date (e.g. "19 Jun 2026"), not a relative
"x ago". Add a small helper to `DateDisplay` (or alongside it):
`static func mediumDate(_ iso: String?) -> String` — parse the ISO-8601 string
and format with a medium date style; return `""` for nil/unparseable. Keep it
deterministic/testable.

### 6. Unit tests

Add `AggregatorAppTests/BriefModelTests.swift` (no network):

1. **Brief decoding** — decode a realistic `BriefResponse` JSON snippet (headline,
   intro, period_start/end, model, two topics); assert `topics.count == 2`,
   topic `whatHappened`/`whyItMatters` map correctly, and a nil
   `historical_context` decodes to `nil`.
2. **BriefRef decoding** — decode an internal ref
   `{"url":null,"title":"X","internal":true,"article_id":42}`: assert
   `internal == true`, `articleId == 42`, `url == nil`. Decode an external ref
   `{"url":"https://e.com","title":"Y","internal":false,"article_id":null}`:
   assert `internal == false`, `url == "https://e.com"`, `articleId == nil`.
3. **DateDisplay.mediumDate** — a known ISO string formats to the expected medium
   date; nil/garbage returns `""`.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Models/Brief.swift` | New `Brief` / `BriefTopic` / `BriefRef` models |
| `AggregatorApp/Common/APIClient.swift` | Add `getTodayBrief()` |
| `AggregatorApp/Common/DateDisplay.swift` | Add `mediumDate(_:)` |
| `AggregatorApp/Today/TodayView.swift` | Replace stub with the brief reader |
| `AggregatorApp/Today/BriefTopicView.swift` | New topic section view |
| `AggregatorAppTests/BriefModelTests.swift` | New unit tests |

After implementation run `xcodegen generate` (new files), then:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [ ] `xcodegen generate` succeeds; `xcodebuild test` exits 0 incl. new brief tests
- [ ] Today tab shows today's brief: headline, date + model, intro, and topics in order
- [ ] Each topic shows "What happened", "Why it matters", and "Background" (only when present)
- [ ] Topic references render as a "Read" list; internal refs open the article reader on tap, external refs open the in-app Safari view
- [ ] Internal ref navigation opens the reader on the first tap (destination-based links)
- [ ] With no brief available, the tab shows a "No brief yet" empty state (no hard error); pull-to-refresh re-fetches
- [ ] With no credentials, the tab shows the "Not configured" state
- [ ] Loading and error states handled; cancelled fetches do not show an error
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **No historical briefs / no generation trigger**: the JSON API only exposes
  `GET /brief/today` (no briefs list, no refresh/generate endpoint), so the tab
  shows only today's brief and cannot trigger generation. If a briefs-list or
  generate endpoint is added later, a history view / "Generate" button can follow.
- **Topic images**: `BriefTopicResponse` exposes no image field (the web client's
  topic image is an ORM-only field), so topics render without images. Future
  enhancement if the API adds one (mirrors the article `image_url` precedent).

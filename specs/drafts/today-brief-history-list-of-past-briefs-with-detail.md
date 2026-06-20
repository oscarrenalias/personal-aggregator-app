---
name: "Today brief history: list of past briefs with detail"
id: spec-9f85467c
description: Today tab becomes a paginated list of past briefs (newest first) opening a reusable brief detail; degrades to today-only until the backend adds GET /briefs.
dependencies: null
priority: medium
complexity: null
status: draft
tags:
- today
- brief
- history
- pagination
- navigation
scope:
  in: null
  out: null
feature_root_id: null
---
# Today brief history: list of past briefs with detail

## Objective

Make the Today tab show a browsable history of daily briefs, not just today's.
The tab becomes a list of brief cards (date · headline · topic count), newest
first; tapping a card opens the full brief in a detail screen. Today's brief is
the top card.

## Context

- Builds on the merged Today feature (`spec-f03dbf5c`): reuse the `Brief` /
  `BriefTopic` / `BriefRef` models, `BriefTopicView`, `DateDisplay`,
  `PaginatedResponse`, `ParagraphText`, and `ArticleDetailView`/`SafariView` for
  topic refs.
- The current `TodayView` renders a single brief from `GET /brief/today`. This
  spec **refactors** that brief rendering into a reusable detail view and turns
  `TodayView` into the list.

### Backend dependency

The JSON API currently exposes only `GET /brief/today`; there is no history
endpoint (the DB holds past briefs — the web client lists the last 30 by
querying the DB directly). A backend endpoint to list briefs is being added
separately (request handed off):

- `GET /briefs?limit=&cursor=` → `PaginatedResponse[BriefResponse]`, newest
  first, each item a full `BriefResponse` (with topics) so the detail needs no
  second fetch.

**Graceful degradation (important):** build the iOS side so it does NOT regress
while the endpoint is absent. `TodayView` tries `GET /briefs`; if it is
unavailable (e.g. HTTP 404), it **falls back** to a single-item list containing
`GET /brief/today`. So today the tab shows just today's brief (as now), and it
automatically gains full history the moment `/briefs` ships — no further app
change.

## Changes

### 1. APIClient — briefs list

Add to `APIClient.swift`:
```swift
func getBriefs(cursor: String? = nil, limit: Int = 30) async throws -> PaginatedResponse<Brief>
```
Builds `GET /briefs` with `limit` and optional `cursor`. Keep the existing
`getTodayBrief()` for the fallback.

### 2. BriefDetailView — extract the current brief reader

New `AggregatorApp/Today/BriefDetailView.swift`, initialised with `brief: Brief`.
Move the current `TodayView` brief-rendering here (header: headline + date/model;
intro; topics via `BriefTopicView`; the external-ref Safari sheet). It is a pure
presentation view over a provided `Brief` (no fetch), so the list can pass the
already-loaded brief and the detail paints instantly.

### 3. TodayView — the briefs list (refactor)

`AggregatorApp/Today/TodayView.swift`. Own a `NavigationStack`.
- State: `briefs: [Brief]`, `nextCursor: String?`, a `phase`
  (loading/loaded/error/empty), `isLoadingMore`.
- Not-configured: the existing "Not configured" `ContentUnavailableView`.
- Load (`.task`, load-once — do not reload on reappearance, matching the list
  scroll-preservation fix): fetch `getBriefs()`.
  - Success → `briefs = items`, `nextCursor`.
  - **Fallback**: if `/briefs` is unavailable (`APIError.http(404)`), fetch
    `getTodayBrief()` and present it as a single-item list (`briefs = [today]`,
    `nextCursor = nil`). If that also yields no brief → `.empty`.
  - Cancellation → ignore (`isCancellation`). Other errors → `.error`.
- **Empty**: `ContentUnavailableView("No briefs yet", systemImage: "sparkles", …)`.
- **Loaded**: a `List` of `BriefCardView` rows, each a **destination-based**
  `NavigationLink` to `BriefDetailView(brief: brief)` (destination-based to avoid
  the first-tap navigation bug). Newest first (the API returns newest-first;
  do not re-sort).
- **Infinite scroll**: when the last row appears and `nextCursor != nil`, load
  the next page (only when `/briefs` is available; the fallback has no pages).
- **Pull-to-refresh**: reload the first page.
- `.navigationTitle("Today")`.

### 4. BriefCardView

New `AggregatorApp/Today/BriefCardView.swift`, a glass list row for a `Brief`:
- Date line (`.caption`, `.secondary`): `DateDisplay.mediumDate(brief.periodStart)`;
  for the most-recent/today's brief, prefix "Today · " (compute by comparing the
  brief's period to the current day, or simply label the first row "Today").
- Topic count: "{n} topic(s)" with correct pluralisation.
- `headline` (`.headline`, up to 2 lines; fall back to "Daily Brief").
- Glass row treatment (`.listRowBackground(Color.clear)`), consistent with other lists.

### 5. Unit tests

`AggregatorAppTests`:
- **getBriefs URL** via `APIClient.makeURL`: `GET /briefs` with `limit` and a
  percent-encoded `cursor`, and no cursor when nil.
- **PaginatedResponse[Brief] decoding**: decode an envelope with two brief items
  + a `next_cursor`; assert count and that the first brief's topics decode.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Common/APIClient.swift` | Add `getBriefs(cursor:limit:)` |
| `AggregatorApp/Today/BriefDetailView.swift` | New — extracted single-brief reader (from TodayView) |
| `AggregatorApp/Today/BriefCardView.swift` | New — brief list row |
| `AggregatorApp/Today/TodayView.swift` | Refactor into the briefs list with `/briefs` + `/brief/today` fallback |
| `AggregatorAppTests/...` | getBriefs URL + paginated brief decoding tests |

Run the test gate (`bash scripts/run-tests.sh`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 incl. new brief-list tests
- [ ] Today tab shows a list of brief cards (date · topic count · headline), newest first; the top one labelled/identifiable as today's
- [ ] Tapping a card opens the full brief detail (headline, intro, topics, refs) — opens on the first tap
- [ ] When `/briefs` is unavailable, the tab still shows today's brief as a single-item list (no regression, no hard error)
- [ ] When `/briefs` is available, scrolling loads older briefs (pagination) and pull-to-refresh reloads
- [ ] Returning from a brief detail preserves the list scroll position (load-once, not on reappearance)
- [ ] Not-configured / loading / empty / error states handled; cancelled fetches don't show an error
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **History UX**: resolved — list → detail (master/detail), newest first.
- **Backend dependency**: `GET /briefs` paginated (full BriefResponse items),
  being added separately. iOS degrades to today-only until it ships, then gains
  history automatically.
- **Generation/refresh**: still no JSON endpoint to generate a brief; out of scope.

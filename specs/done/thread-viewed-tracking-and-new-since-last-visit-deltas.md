---
name: Thread viewed tracking and new-since-last-visit deltas
id: spec-4117bca1
description: "Call POST /threads/{id}/viewed on thread open, decode last_viewed_at and typed ThreadDelta, render New since last visit section in ThreadDetailView"
dependencies: null
priority: high
complexity: low
status: done
tags:
- threads
- backend-sync
scope:
  in: "Thread model, ThreadDetailView, APIClient, docs/openapi.json, docs/API.md"
  out: "ThreadSeenStore retirement, widget changes, ThreadsView unread dot logic"
feature_root_id: null
---
# Thread viewed tracking and new-since-last-visit deltas

## Objective

Wire up the `POST /threads/{id}/viewed` endpoint that shipped in backend v0.1.54, decode the new `last_viewed_at` field and typed `ThreadDelta` schema, and render a "New since last visit" section in `ThreadDetailView`.

## Background

The backend now:
- Trims `rolling_summary` to a safe length server-side (no iOS change needed).
- Exposes `POST /threads/{thread_id}/viewed` — stamps a server-side "last viewed" timestamp for the thread. Returns the updated `ThreadResponse`.
- Adds `last_viewed_at: string | null` to `ThreadResponse` — ISO-8601 timestamp of the previous visit (i.e. the value *before* the current `/viewed` call stamps the new time).
- Promotes `deltas` from an untyped array to `[ThreadDelta]` with schema: `timestamp` (required, ISO-8601), `article_id?`, `label?`, `new_facts?: [String]`, `reason?`, `absorbed_id?`, `type?`.

## Changes

### 1. `docs/openapi.json` — update snapshot

Replace the committed file with the upstream v0.1.54 snapshot from `https://raw.githubusercontent.com/oscarrenalias/personal-aggregator/main/docs/openapi.json`. The key additions vs the current file:
- `POST /threads/{thread_id}/viewed` path
- `ThreadDelta` component schema
- `last_viewed_at` field on `ThreadResponse`
- `deltas` on `ThreadResponse` typed as `[ThreadDelta]`

### 2. `docs/API.md` — document new endpoint and field

Add `POST /threads/{id}/viewed` to the Writes table and add a note about `last_viewed_at` under the Threads section.

### 3. `AggregatorApp/Models/Thread.swift` — add `lastViewedAt` and typed `deltas`

Add a new `ThreadDelta` struct (same file or a new `ThreadDelta.swift`):

```swift
struct ThreadDelta: Codable {
    let timestamp: String
    let articleId: Int?
    let label: String?
    let newFacts: [String]?
    let reason: String?
    let absorbedId: Int?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case articleId   = "article_id"
        case label
        case newFacts    = "new_facts"
        case reason
        case absorbedId  = "absorbed_id"
        case type
    }
}
```

Add to `Thread`:
- `let lastViewedAt: String?` decoded with `decodeIfPresent`
- `let deltas: [ThreadDelta]` decoded with `decodeIfPresent` defaulting to `[]`

Update both `encode(to:)` and `init(from:)` to handle the new fields.

### 4. `AggregatorApp/Common/APIClient.swift` — add `postViewedThread`

```swift
/// Stamps the current time as the "last viewed" marker for the thread.
/// Returns the updated thread (with the previous last_viewed_at value).
@discardableResult
func postViewedThread(id: Int) async throws -> Thread {
    return try await post("/threads/\(id)/viewed")
}
```

Reuse the existing `post(_:)` helper that already handles CF-Access headers.

### 5. `AggregatorApp/Threads/ThreadDetailView.swift` — post viewed + render deltas

**Load sequence change in `loadInitial()`:**

```
1. GET /threads/{id}          → thread (with previous last_viewed_at)
2. GET /threads/{id}/members  → members (concurrent with step 1)
3. POST /threads/{id}/viewed  → fire-and-forget after steps 1+2 succeed
4. seenStore.markSeen(...)    → unchanged, keep for list-level dot
```

Capture `thread.lastViewedAt` (the *previous* visit timestamp) before posting `/viewed`. This value drives the "New since last visit" filter.

**New "New since last visit" section:**

Add a `newDeltasSection` builder in `ThreadDetailView`. Show it between the header section and known facts when there are deltas newer than `previousLastViewedAt`:

```
previousLastViewedAt == nil   → show all deltas (first visit)
previousLastViewedAt != nil   → show deltas where delta.timestamp > previousLastViewedAt
no qualifying deltas           → section hidden
```

Each delta row shows:
- `label` (if non-nil): displayed using the existing `classificationDisplayLabel(_:)` / `classificationBadgeColor(_:)` helpers already in the file
- `newFacts` (if non-empty): bullet list, same style as the known-facts section
- `reason` (if non-nil and `newFacts` is empty): shown as body text
- If none of the above: skip the delta row entirely

Section header: `"New since last visit"` in `.headline`. Wrap the section in a glass card (`glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))`) matching the known-facts section style.

**`loadInitial` error handling:** if `postViewedThread` throws, swallow the error — the view must still display the thread content normally.

## Files to Modify

| File | Change |
|---|---|
| `docs/openapi.json` | Replace with upstream v0.1.54 snapshot |
| `docs/API.md` | Add `POST /threads/{id}/viewed` to Writes table; note `last_viewed_at` |
| `AggregatorApp/Models/Thread.swift` | Add `ThreadDelta` struct; add `lastViewedAt` and `deltas` to `Thread` |
| `AggregatorApp/Common/APIClient.swift` | Add `postViewedThread(id:)` |
| `AggregatorApp/Threads/ThreadDetailView.swift` | Post viewed on load; add "New since last visit" delta section |

## Acceptance Criteria

- [ ] `docs/openapi.json` contains `POST /threads/{thread_id}/viewed`, `ThreadDelta` schema, and `last_viewed_at` on `ThreadResponse`.
- [ ] `Thread` model decodes `last_viewed_at` and `deltas: [ThreadDelta]` without crashing when either field is absent (existing threads in the wild may not have them).
- [ ] Opening a thread detail calls `POST /threads/{id}/viewed` exactly once per view load; failure does not prevent the thread from rendering.
- [ ] "New since last visit" section appears in `ThreadDetailView` when there are qualifying deltas (newer than `previousLastViewedAt`).
- [ ] Section is hidden when there are no qualifying deltas.
- [ ] On first visit (`previousLastViewedAt == nil`), all deltas are shown.
- [ ] `xcodebuild test` passes with no new failures.

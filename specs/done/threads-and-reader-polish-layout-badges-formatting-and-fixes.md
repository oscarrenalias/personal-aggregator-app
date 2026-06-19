---
name: "Threads and reader polish: layout, badges, formatting, and fixes"
id: spec-19056cf7
description: "Six client-side polish fixes for the threads/reader: consistent margins, cancellation-error fix, web-accurate badge colors, Threads tab icon, article paragraph typography, and local has-updates dot clearing."
dependencies: null
priority: high
complexity: null
status: done
tags:
- polish
- ui
- bugfix
- threads
- reader
scope:
  in: null
  out: null
feature_root_id: B-2ca6fdbe
---
# Threads and reader polish: layout, badges, formatting, and fixes

## Objective

Post-release polish for the threads reading experience (spec-37d1bbcf), based on
user testing. Six focused changes: consistent reader margins, a back-navigation
bug fix, web-accurate classification-badge colors, the Threads tab icon, article
body typography, and local clearing of the "has updates" dot. All client-side;
no backend changes.

## Context

- Builds directly on spec-37d1bbcf (merged). Files referenced below already exist.
- Reference web client (visual parity):
  `/Users/oscar.renalias/Projects/personal-aggregator/packages/aggregator-web`
  (`static/styles.css`, `templates/_thread_detail.html`).
- Follow the Liquid Glass / semantic-color conventions in CLAUDE.md. The
  classification badges are the one place distinct hues are required — use
  SwiftUI system colors (`.indigo`, `.teal`, `.purple`, `.orange`), not hex.

## Changes

### 1. Consistent reader margins (thread detail ⟷ article reader)

`ThreadDetailView.swift` and `ArticleDetailView.swift` both use a bare
`.padding()` (~16pt) on their content `VStack`, but the article reader reads as
narrower/denser (compounded by the line-spacing issue in §6). Standardise both:

- Use the **same horizontal content padding** in both views — `.padding(.horizontal, 20)`
  (plus the existing vertical padding). Define it once (e.g. a shared constant
  like `enum ReaderLayout { static let hPadding: CGFloat = 20 }`) and use it in
  both files so they can't drift again.
- **Hero images stay full-bleed** (full width, no horizontal padding) in both
  views — only the text content gets the margin.
- After the change, the title, summary, body, known-facts, and member rows in
  both screens share the same leading margin.

### 2. Fix spurious "cancelled / Retry" on back-navigation

Navigating back from the article reader to a thread briefly shows the thread
detail's error state with the message "cancelled" and a Retry button. Cause: the
thread detail's in-flight fetch task is cancelled by SwiftUI during the
navigation transition, and the `catch` treats that cancellation as a real error.

- In the fetch/`catch` logic of `ThreadDetailView` (and any other view with the
  same pattern — check `ThreadsView`, `ArticleDetailView`, `SourcesView`), treat
  cancellation as benign: if the thrown error is `CancellationError`, or a
  `URLError` with `.code == .cancelled`, do **not** transition to the error
  state. Leave existing content/loading as-is and return.
- A small helper is acceptable, e.g.
  `func isCancellation(_ error: Error) -> Bool` checking both cases, used wherever
  a fetch `catch` sets an error phase.
- Verify: opening a thread, tapping an article, then tapping back shows the
  thread detail intact (no "cancelled / Retry").

### 3. Web-accurate classification-badge colors

`ThreadDetailView.classificationBadgeColor(_:)` currently maps
`same_thread_new_fact` **and** `same_thread_new_angle` to the same `.green`, and
uses `.blue` for new threads. Re-map to match the web palette
(`static/styles.css` `.classification-*` rules) and split New Angle out:

| Raw label(s) | Display | Color |
|---|---|---|
| `new_thread`, `related_new_thread` | New Thread / Related | `.indigo` |
| `same_thread_new_fact` | New Fact | `.teal` |
| `same_thread_new_angle` | New Angle | `.purple` |
| `correction_or_clarification` | Correction | `.orange` |
| `same_thread_duplicate`, `same_thread_background_only`, `irrelevant_or_low_value`, default | Duplicate / Background / Low Value | `.secondary` |

Also adopt the web's **tinted** badge style instead of the current solid-fill +
white text: capsule background `color.opacity(0.15)`, foreground `color`, and a
thin `color.opacity(0.25)` border (`.overlay(Capsule().strokeBorder(...))`).
Keep the existing font/size/padding and the accessibility label.

### 4. Clear the "has updates" dot locally when a thread is opened

The blue dot (`ThreadCardView`, shown when `thread.hasUpdates`) must disappear
once the user opens the thread. `GET /threads/{id}` is intentionally passive and
there is no "seen" write endpoint, so track this **locally** (this matches how
the web UI behaves).

- New `AggregatorApp/Threads/ThreadSeenStore.swift`: an `@Observable final class`
  persisting a map of `threadId -> lastUpdated` (the `last_updated` string seen at
  open time) in `UserDefaults` (key e.g. `aggregator.threadsSeen`, JSON-encoded
  `[Int: String]`). Inject it into the environment from `AggregatorApp.swift`
  alongside `CredentialsStore`.
- API:
  - `func markSeen(id: Int, lastUpdated: String)` — store/overwrite.
  - `func hasUnseenUpdate(_ thread: Thread) -> Bool` — returns
    `thread.hasUpdates && seen[thread.id] != thread.lastUpdated`. (So the dot
    clears on open and reappears if the thread later updates to a new
    `last_updated`.)
- `ThreadCardView` shows the dot based on `seenStore.hasUnseenUpdate(thread)`
  rather than `thread.hasUpdates` directly. It reads the store from the
  environment so returning to the list re-evaluates and the dot is gone.
- Mark seen when the thread is opened: in `ThreadDetailView`, after the thread
  loads, call `seenStore.markSeen(id: thread.id, lastUpdated: thread.lastUpdated)`.
- Add a unit test for `ThreadSeenStore` using an injected in-memory/UUID-suite
  `UserDefaults` (no real defaults): unseen when never opened; seen after
  `markSeen` with the same `lastUpdated`; unseen again when `lastUpdated` changes.

### 5. Threads tab icon

In `AppRoot.swift`, change the Threads tab's `systemImage` from
`bubble.left.and.bubble.right` to **`rectangle.stack`** (better represents
clustered stories than the chat-bubble metaphor). Other tabs unchanged.

### 6. Article body typography

`ArticleDetailView` renders the body as a single `Text(cleanText).font(.body)`,
so paragraphs (newline-separated in `clean_text`) collapse into a dense block.

- Split `cleanText` into paragraphs on blank lines / newlines (trim, drop empty
  entries) and render each as its own `Text` inside a
  `VStack(alignment: .leading, spacing: 14)`.
- Apply `.lineSpacing(5)` (intra-paragraph) and `.font(.body)` to each paragraph
  for comfortable reading.
- Apply the same paragraph treatment to the AI `summary` callout if it contains
  multiple paragraphs (the web runs both through its `paragraphs` filter); a
  single-paragraph summary is unaffected.
- A small reusable helper (e.g. `ParagraphText(_ text: String)`) is encouraged so
  body and summary share the logic.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/AppRoot.swift` | §5 tab icon → `rectangle.stack` |
| `AggregatorApp/Threads/ThreadDetailView.swift` | §1 padding, §2 cancellation handling, §3 badge colors+style, §4 markSeen on load |
| `AggregatorApp/Articles/ArticleDetailView.swift` | §1 padding, §2 cancellation handling, §6 paragraph typography |
| `AggregatorApp/Threads/ThreadsView.swift` | §2 cancellation handling (if applicable) |
| `AggregatorApp/Sources/SourcesView.swift` | §2 cancellation handling (if applicable) |
| `AggregatorApp/Threads/ThreadCardView.swift` | §4 dot driven by `ThreadSeenStore` |
| `AggregatorApp/Threads/ThreadSeenStore.swift` | §4 new observable local-seen store |
| `AggregatorApp/AggregatorApp.swift` | §4 inject `ThreadSeenStore` into environment |
| `AggregatorApp/Common/ReaderLayout.swift` (or inline) | §1 shared horizontal-padding constant |
| `AggregatorAppTests/ThreadSeenStoreTests.swift` | §4 unit tests |

After implementation run `xcodegen generate`, then:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [ ] `xcodegen generate` succeeds; `xcodebuild test` exits 0 (incl. new ThreadSeenStore tests)
- [ ] Thread detail and article reader have identical horizontal text margins; hero images remain full-bleed in both
- [ ] Navigating article → back to thread no longer shows a "cancelled / Retry" error state
- [ ] Classification badges: New Thread/Related = indigo, New Fact = teal, New Angle = purple, Correction = orange, Duplicate/Background/Low Value = gray; tinted-fill + border style
- [ ] New Angle and New Fact are visibly different colors
- [ ] Threads tab icon is `rectangle.stack`
- [ ] Article body shows clear spacing between paragraphs and comfortable line spacing
- [ ] Opening a thread clears its "has updates" dot; the dot stays cleared on return to the list and across app restarts (persisted); it reappears only if the thread's `last_updated` changes
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Item #4 approach**: resolved — **local-only tracking** (UserDefaults), matching
  the web UI's behavior. No backend "seen" endpoint.

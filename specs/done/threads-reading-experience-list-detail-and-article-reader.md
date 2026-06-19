---
name: "Threads reading experience: list, detail, and article reader"
id: spec-37d1bbcf
description: "Threads tab list with pagination/sort/dismiss, thread detail (summary + members), and a reusable article reader with read/save actions."
dependencies: null
priority: high
complexity: null
status: done
tags:
- threads
- articles
- reader
- networking
- pagination
- webview
- hero-images
scope:
  in: null
  out: null
feature_root_id: B-82362f7d
---
# Threads reading experience: list, detail, and article reader

## Objective

Turn the Threads tab from a stub into a working Feedly-style reading flow:
browse story threads, open a thread to see its summary and member articles, and
tap an article to read its full text. Build the article reader as a standalone,
reusable view so later specs (Articles browse, Search) can reuse it.

The flow: **Threads list → Thread detail (summary + members) → Article reader**.

## Context

- Builds on the skeleton from spec-3da083df (`APIClient`, `CredentialsStore`,
  tab shell, `SourcesView` as the reference pattern for state handling).
- Backend contract: `docs/API.md`, `docs/openapi.json`. Base URL and the two
  CF Access headers are already handled by `APIClient`.
- All list endpoints use the pagination envelope
  `{ "items": [...], "next_cursor": string | null }`. `next_cursor` is opaque —
  pass it verbatim as the `cursor` query param; never parse or construct it.
- `GET` endpoints are passive (do not change server state). State changes use the
  explicit `POST` write endpoints.

### Verified API field shapes (from the live backend)

- `GET /threads?sort=importance|recent&show_dismissed=<bool>&limit=<int>&cursor=<str>`
  → `PaginatedResponse[ThreadResponse]`. Many scalar score fields are `null`.
  `source_list` is an array of integer source IDs. `known_facts`, `deltas` are
  arrays (often empty). `image_url` may be `null`. `representative_title`,
  `status`, `first_seen`, `last_updated`, `source_count`, `member_count`,
  `has_updates`, `dismissed` are reliably present.
- `GET /threads/{id}` → single `ThreadResponse` (passive; does NOT clear the
  web UI's unread markers — intentional).
- `GET /threads/{id}/members` → `PaginatedResponse[ThreadMemberResponse]`. Members
  carry `article_id`, `clean_title`, `url`, `source_name`, `published_at`,
  `classification_label`, and `suppressed` (true = duplicate). `new_facts` is an
  array (often empty).
- `GET /articles/{id}` → `ArticleResponse`. `clean_text` may be empty string;
  `word_count` may be 0; `topics` is an array of strings; `categories` an array;
  `is_read`/`is_saved` are booleans; `summary` is an AI summary; `excerpt` is
  raw HTML and is NOT rendered in this spec.
- Timestamps are ISO-8601 with fractional seconds and a UTC offset, e.g.
  `"2026-06-17T04:41:10.929002+00:00"`.
- Writes (no body, return the updated resource which may be ignored):
  `POST /threads/{id}/dismiss`, `/restore`, `POST /articles/{id}/read`,
  `/unread`, `/save`, `/unsave`.

### Visual parity with the web reader

The reference web client lives at
`/Users/oscar.renalias/Projects/personal-aggregator/packages/aggregator-web`
(Jinja templates `_thread_card.html`, `_thread_detail.html`,
`_article_detail.html`). This spec mirrors its **content hierarchy**, adapted to
native iOS idioms (no custom CSS — SwiftUI controls, semantic colors, Liquid
Glass). Concretely, the web client informs:

- **Importance badge** on articles: the score (0–100) shown as a small pill,
  colored by tier — `>= 80` high, `>= 50` medium, else low. Map to semantic
  iOS colors: high → `.red`, medium → `.orange`, low → `.secondary`.
- **Topic / category chips** on the article reader.
- **Classification-label badges** on thread members. Label → display text:
  `new_thread`→"New Thread", `same_thread_new_fact`→"New Fact",
  `same_thread_new_angle`→"New Angle", `same_thread_duplicate`→"Duplicate",
  `same_thread_background_only`→"Background",
  `correction_or_clarification`→"Correction", `related_new_thread`→"Related",
  `irrelevant_or_low_value`→"Low Value". Unknown labels fall back to the raw
  string.
- **Suppressed members** rendered as a separate "Also covered by" list of source
  names (not full rows), below the active members.

**Explicitly NOT mirrored in this spec** (future enhancements):
- The web "What changed" section driven by `deltas`. `deltas` is a
  heterogeneous array of objects (e.g. `{"type":"merge","absorbed_id":…}` with
  no facts) and is brittle to model in Swift; skip it. Decode `deltas` is not
  required — do not add it to the `Thread` model.
- Thread `tier` badge: the live backend returns `tier: null` for all threads, so
  it is not worth building. If `tier` is present, you MAY show a small badge, but
  it is optional and untested.
- Cross-article prev/next navigation within the reader (the web reader-nav row).
- `known_facts` IS populated and IS a plain `[String]` — render it (see below).

## Changes

### 1. APIClient — pagination, query params, status checking, new endpoints

Extend `AggregatorApp/Common/APIClient.swift`:

- Add query-parameter support. Build request URLs with `URLComponents` from
  `store.baseURL + path` plus a `[URLQueryItem]`. Extract URL construction into a
  testable pure function so unit tests can verify it without the network:

  ```swift
  static func makeURL(baseURL: String, path: String, query: [URLQueryItem]) -> URL?
  ```

- Add HTTP status handling. After `URLSession` returns, inspect the
  `HTTPURLResponse` status code:
  - `200...299` → decode/return as today
  - `403` with a non-JSON (HTML) body → throw `APIError.cloudflareRejected`
  - other non-2xx → throw `APIError.http(status:)`
  Define `enum APIError: Error` with those cases plus `LocalizedError`
  conformance for user-facing messages.

- New typed methods:

  ```swift
  func getThreads(sort: ThreadSort, showDismissed: Bool, cursor: String?) async throws -> PaginatedResponse<Thread>
  func getThread(id: Int) async throws -> Thread
  func getThreadMembers(id: Int, cursor: String?) async throws -> PaginatedResponse<ThreadMember>
  func getArticle(id: Int) async throws -> Article

  func dismissThread(id: Int) async throws   // POST /threads/{id}/dismiss
  func restoreThread(id: Int) async throws   // POST /threads/{id}/restore
  func markArticleRead(id: Int) async throws
  func markArticleUnread(id: Int) async throws
  func saveArticle(id: Int) async throws
  func unsaveArticle(id: Int) async throws
  ```

  Existing `getSources()` / `healthCheck()` stay unchanged.

`ThreadSort` is an `enum ThreadSort: String { case importance, recent }`.

### 2. Models

Add to `AggregatorApp/Models/`. All `Decodable`; list models also `Identifiable`.
Decode loosely-typed arrays (`known_facts`, `topics`, `categories`) **defensively**
— a decode failure on these must degrade to `nil`/`[]`, never throw and break the
whole object (use `decodeIfPresent` with `try?` fallback). Timestamps are stored
as `String`; rendering is handled by a date helper (below).

**`PaginatedResponse.swift`**
```swift
struct PaginatedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
```

**`Thread.swift`** — fields the UI uses (map snake_case via CodingKeys):
`id: Int`, `representativeTitle: String`, `rollingSummary: String?`,
`knownFacts: [String]`, `status: String`, `noveltyLabel: String?`,
`firstSeen: String`, `lastUpdated: String`, `sourceCount: Int`,
`memberCount: Int`, `imageURL: String?`, `hasUpdates: Bool`,
`dismissed: Bool`, `topGrade: Int?`.

**`ThreadMember.swift`**: `id: Int`, `threadId: Int`, `articleId: Int`,
`cleanTitle: String?`, `url: String?`, `sourceName: String?`,
`publishedAt: String?`, `classificationLabel: String?`, `suppressed: Bool`.

**`Article.swift`**: `id: Int`, `title: String?`, `url: String?`,
`sourceId: Int`, `sourceName: String?`, `feedPublishedAt: String?`,
`summary: String?`, `cleanText: String?`, `importanceScore: Int?`,
`importanceReason: String?`, `topics: [String]`, `categories: [String]`,
`isRead: Bool`, `isSaved: Bool`, `author: String?`, `wordCount: Int?`,
`language: String?`, `imageURL: String?` (decoded from `image_url` with
`decodeIfPresent` — absent in the current API, present-proofed for a future
backend field; defaults to `nil`).

**`DateDisplay.swift`** (helper, not a model): a small enum/struct with
`static func relative(_ iso: String?) -> String` that parses the ISO-8601 string
(with fractional seconds) and returns a short relative string (e.g. "2h ago",
"Jun 17"). Return `""` for `nil`/unparseable input. Must be deterministic enough
to unit-test with a fixed reference date (inject "now" as a parameter with a
default of `Date()`).

### 3. ThreadsView — the list (replace the stub)

`AggregatorApp/Threads/ThreadsView.swift`. Follow `SourcesView`'s state pattern
(loading / error / empty / not-configured) and the Liquid Glass conventions in
CLAUDE.md.

- State: `threads: [Thread]`, `nextCursor: String?`, `sort: ThreadSort`
  (default `.importance`), `showDismissed: Bool` (default `false`), plus a
  `phase` enum for loading/loaded/error.
- When `!credentialsStore.isConfigured`: show the "Not configured"
  `ContentUnavailableView` pointing to Settings (same as `SourcesView`).
- On appear / on sort or showDismissed change: fetch the first page
  (cursor `nil`), replacing the list.
- **Infinite scroll**: when the last row appears and `nextCursor != nil`, fetch
  the next page and append. Guard against duplicate concurrent page loads.
- **Pull to refresh** via `.refreshable` — reloads the first page.
- **Sort control**: a toolbar `Menu` (Liquid Glass) or `Picker` letting the user
  switch importance/recent. A toolbar toggle or menu item flips `showDismissed`.
- Tapping a row navigates (via `.navigationDestination`) to a **paged** detail
  container, `ThreadPagerView(threads: threads, startIndex: <tapped index>)`,
  NOT directly to `ThreadDetailView`. This enables swipe-between-threads
  (see §5a). Rows are `ThreadCardView`.
- **Swipe actions**: when not showing dismissed → trailing "Dismiss" (calls
  `dismissThread`, removes the row optimistically). When showing dismissed →
  "Restore" (calls `restoreThread`). On failure, reinsert the row and surface
  the error.
- `.navigationTitle("Threads")`.

### 4. ThreadCardView

`AggregatorApp/Threads/ThreadCardView.swift`. A **magazine-style** row: text on
the left, a small thumbnail on the right.

- Layout: an `HStack(alignment: .top)` with:
  - **Left column** (`VStack(alignment: .leading)`, takes remaining width):
    1. Meta line (`.caption`, `.secondary`): an update dot when `hasUpdates`
       (small filled glyph, e.g. `circlebadge.fill`, in `.tint`, with
       accessibility label "Has updates" — never color alone), then
       "{sourceCount} source(s) · {memberCount} article(s) · {relative(lastUpdated)}"
       with correct singular/plural.
    2. `representativeTitle` as `.headline`, up to 2 lines.
    3. `rollingSummary` as `.subheadline`/`.secondary`, up to 3 lines (omit if nil).
  - **Right thumbnail**: when `imageURL` is present, an `AsyncImage` ~80×80,
    `.scaledToFill()`, clipped to a rounded rect, with a placeholder; remove
    gracefully on load failure. When `imageURL` is nil, the thumbnail is omitted
    and the text fills the full row width (no empty gap).
- Rows use the established glass treatment (`.listRowBackground(Color.clear)` and
  a `GlassEffectContainer` around the list, as in `SourcesView`).

### 5a. ThreadPagerView — swipe between threads

`AggregatorApp/Threads/ThreadPagerView.swift`. Initialised with the ordered
`threads: [Thread]` (the list as currently loaded) and `startIndex: Int`.

- Renders a horizontally paged `TabView(selection:)` with
  `.tabViewStyle(.page(indexDisplayMode: .never))`. Each page is a
  `ThreadDetailView(threadId: threads[i].id)`, tagged by index.
- **Swiping left/right moves to the next/previous thread** in the list — this is
  the user-requested behavior. The selection starts at `startIndex`.
- If the user pages to the last loaded thread, paging simply stops (loading more
  pages from here is a future enhancement — note in the bead handoff).
- `.navigationBarTitleDisplayMode(.inline)`. Each `ThreadDetailView` sets its own
  inline title, so the nav bar reflects the currently-visible thread.
- Tapping a member article inside a page pushes `ArticleDetailView` onto the same
  `NavigationStack` (paging is horizontal; drill-down is a push — they compose).

### 5. ThreadDetailView

`AggregatorApp/Threads/ThreadDetailView.swift`. Initialised with `threadId: Int`.

- On appear, concurrently fetch `getThread(id:)` and the first page of
  `getThreadMembers(id:)`. Handle loading / error states.
- **Hero image**: when `thread.imageURL` is present, render it full-width at the
  top via `AsyncImage` (aspect-fill, clipped, a sensible max height ~220pt, with
  a placeholder; remove gracefully on load failure — never block layout). Mirrors
  the web `detail-hero`.
- Header section:
  - `representativeTitle` as `.title3`/`.bold`.
  - Metadata caption: "Updated {relative(lastUpdated)} · {sourceCount} sources".
  - `rollingSummary` body text (if present).
  - `knownFacts` (if non-empty): a "Known facts" subsection rendering each fact
    as a bulleted row.
- Members section ("Articles", active member count in the header). Split members
  into **active** (`suppressed == false`) and **suppressed** (`true`):
  - **Active members**, ordered by `publishedAt` descending. Each row shows:
    - a small classification-label badge (mapping in the Visual-parity section;
      omit when `classificationLabel` is nil),
    - `cleanTitle` (or "(untitled)"),
    - caption "{sourceName} · {relative(publishedAt)}".
    Each active row is a `NavigationLink` to
    `ArticleDetailView(articleId: member.articleId)`.
  - **Suppressed members** render below under an "Also covered by" subheading as a
    compact list of `sourceName` links (not full rows), each navigating to its
    article reader. This mirrors the web client and keeps recurring duplicates
    from dominating the view.
  - Paginate members with the same infinite-scroll approach if `nextCursor != nil`.
- `.navigationTitle(thread.representativeTitle)` with `.navigationBarTitleDisplayMode(.inline)`.

### 6. ArticleDetailView — the reusable reader

`AggregatorApp/Articles/ArticleDetailView.swift` (new `Articles/` directory).
Initialised with `articleId: Int`.

- On appear: fetch `getArticle(id:)`. Handle loading / error.
- **Auto mark-read**: after a successful load, if `!article.isRead`, call
  `markArticleRead(id:)` and update local state. (See Pending Decisions.)
- Content (in a `ScrollView`):
  - **Hero image**: when `article.imageURL` is present, render it full-width at
    the top (same `AsyncImage` treatment as the thread hero). NOTE: the current
    `ArticleResponse` from the backend does NOT include an image field, so this
    renders only once the API exposes one (the model decodes `image_url`
    defensively — see §2 and Pending Decisions). Build the code path now so it
    activates automatically when the backend adds the field.
  - Title (`.title2`/`.bold`).
  - Byline caption: "{sourceName} · {author} · {relative(feedPublishedAt)}"
    (omit missing pieces gracefully).
  - **Importance badge**: when `importanceScore != nil`, a small pill showing the
    score, colored by tier (`>= 80` `.red`, `>= 50` `.orange`, else `.secondary`).
    Its accessibility label includes `importanceReason` when present.
  - **Chips**: `topics` (and `categories` if present) rendered as wrapping chips
    (`.caption`, `.regularMaterial`/bordered). Non-interactive in this spec.
  - `summary` rendered as a visually distinct callout (e.g. a `.glassEffect()`
    rounded block or quote styling) labelled implicitly as the AI summary.
  - `cleanText` as the body (`.body`). If `cleanText` is nil/empty, show a
    `ContentUnavailableView`-style message "No reader text" plus a prominent
    "Open original" button.
- **Toolbar actions** (trailing):
  - Save/unsave toggle — `bookmark` / `bookmark.fill`, calls `saveArticle` /
    `unsaveArticle`, optimistic update.
  - Read/unread toggle — `circle` / `circle.fill`, reflects/sets `isRead` via
    `markArticleRead` / `markArticleUnread`.
  - **Open original** — `safari` icon. Presents the article `url` in an
    **in-app Safari view** (`SafariView`, §6a) via `.sheet`/`.fullScreenCover`,
    NOT the external Safari app and NOT a plain `openURL`. `SFSafariViewController`
    natively provides Reader mode, share, and an "Open in Safari" affordance in
    its own toolbar, satisfying the in-app-browser + open-in-Safari requirement.
    Disabled when `url` is nil.
  - All icon-only buttons need `.accessibilityLabel`.

### 6a. SafariView — in-app browser wrapper

`AggregatorApp/Common/SafariView.swift`. A thin
`UIViewControllerRepresentable` wrapping `SFSafariViewController` (from
`SafariServices`):

```swift
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
```

Presented from `ArticleDetailView` to show the original article inside the app.
No custom chrome — `SFSafariViewController`'s built-in toolbar already includes
the "Open in Safari" button the user asked for.

### 7. Unit tests

Add to `AggregatorAppTests/`. No network calls.

1. **PaginatedResponse decoding** — decode a JSON envelope with two items and a
   non-null `next_cursor`; assert `items.count == 2` and `nextCursor` matches.
   Decode a second envelope with `"next_cursor": null`; assert `nextCursor == nil`.
2. **Thread decoding** — decode a real `ThreadResponse` JSON snippet (use the
   shape in this spec, including `null` score fields and empty `known_facts`);
   assert `representativeTitle`, `sourceCount`, `memberCount`, `hasUpdates`,
   `dismissed`, and `imageURL` decode correctly, and `knownFacts == []`.
3. **ThreadMember decoding** — assert `articleId`, `cleanTitle`, `sourceName`,
   `suppressed` decode correctly.
4. **Article decoding** — decode an `ArticleResponse` snippet; assert `isRead`,
   `isSaved`, `topics` (array of strings), and a nil `language` decode correctly,
   and that `imageURL == nil` when `image_url` is absent (current API shape).
5. **APIClient.makeURL** — assert it builds the correct absolute URL for
   `getThreads(sort: .recent, showDismissed: true, cursor: "ABC==")`, including
   percent-encoding of the cursor, and omits the cursor param when nil.
6. **DateDisplay.relative** — with a fixed injected "now", assert an ISO string
   ~2 hours earlier renders as a short relative string, and that `nil`/garbage
   input returns `""`.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Common/APIClient.swift` | Add query params, `makeURL`, `APIError`, status checking, thread/article/write methods, `ThreadSort` |
| `AggregatorApp/Models/PaginatedResponse.swift` | New generic envelope |
| `AggregatorApp/Models/Thread.swift` | New model |
| `AggregatorApp/Models/ThreadMember.swift` | New model |
| `AggregatorApp/Models/Article.swift` | New model |
| `AggregatorApp/Common/DateDisplay.swift` | New ISO-8601 → relative-string helper |
| `AggregatorApp/Common/SafariView.swift` | New `SFSafariViewController` wrapper for the in-app browser |
| `AggregatorApp/Threads/ThreadsView.swift` | Replace stub with the list |
| `AggregatorApp/Threads/ThreadCardView.swift` | New card row |
| `AggregatorApp/Threads/ThreadPagerView.swift` | New paged container — swipe between threads |
| `AggregatorApp/Threads/ThreadDetailView.swift` | New detail view (with hero image) |
| `AggregatorApp/Articles/ArticleDetailView.swift` | New reusable reader (hero, importance badge, chips, in-app Safari) |
| `AggregatorAppTests/ThreadsModelTests.swift` | Decoding + makeURL + DateDisplay tests |

After implementation run `xcodegen generate` (new files/dirs), then:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [ ] `xcodegen generate` succeeds; `xcodebuild test` exits 0 with all new tests passing
- [ ] Threads tab lists threads from `GET /threads`, default sort importance
- [ ] Switching sort to "recent" reloads the list in recency order
- [ ] Scrolling to the bottom loads the next page via `next_cursor` (no duplicate rows)
- [ ] Pull-to-refresh reloads the first page
- [ ] Swiping a thread dismisses it (removed from the default list); enabling "show dismissed" lists it with a Restore action that works
- [ ] Tapping a thread opens the detail view showing the hero image (when present), rolling summary, known facts (when present), and the member article list
- [ ] Thread detail shows active members with classification-label badges and suppressed members under "Also covered by"
- [ ] Swiping left/right in the thread detail moves to the next/previous thread in the list
- [ ] Tapping a member article opens the reader showing title, byline, importance badge, topic chips, AI summary, and full `clean_text`
- [ ] Opening an unread article marks it read on the server; the read/unread toolbar toggle reflects and can change state
- [ ] Save/unsave toggle persists to the server
- [ ] "Open original" opens the article URL in an in-app Safari view that itself offers an "Open in Safari" action
- [ ] Thread detail renders a hero image when `thread.image_url` is present; the article reader's hero path is implemented and activates if/when the API provides an article image
- [ ] With no credentials, the Threads tab shows the "Not configured" state (no crash, no spinner hang)
- [ ] All network-touching screens handle loading, empty, and error states; icon-only buttons have accessibility labels
- [ ] No hardcoded hex colors; Liquid Glass treatment consistent with `SourcesView`

## Pending Decisions

- **Auto mark-read on open**: this spec marks an article read automatically when
  the reader opens (Feedly behavior), with a toolbar toggle to undo. If you'd
  rather require an explicit "mark read" tap, say so and the auto-call is removed.
  *Resolution: auto mark-read on open.*
- **Suppressed members**: shown under an "Also covered by" list rather than hidden,
  so threads whose members are all duplicates (e.g. recurring live-threads)
  aren't empty. *Resolution: show as "Also covered by".*
- **Article hero image / API gap**: the backend `ArticleResponse` exposes no
  image field, so the article reader's hero will not render until the API adds
  one (e.g. `image_url`). The model and view paths are built defensively so the
  feature activates automatically when the field appears. *Recommended backend
  follow-up: expose the article's `header_image_url` as `image_url` in
  `ArticleResponse`.* Thread hero images work today via `thread.image_url`.
- **`excerpt` (raw HTML)**: not rendered in this spec — `summary` + `clean_text`
  cover the reader. Rendering HTML excerpts is out of scope.

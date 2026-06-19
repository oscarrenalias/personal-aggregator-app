---
name: "Sources reading experience: article lists, virtual feeds, and reader navigation"
id: spec-7bb21007
description: "Sources tab article browsing: real sources + Important/Unread virtual feeds, sort/filter, progressive loading, pull-to-refresh, and swipe-between-articles reader."
dependencies: null
priority: high
complexity: null
status: done
tags:
- sources
- articles
- reader
- pagination
- virtual-feeds
- navigation
scope:
  in: null
  out: null
feature_root_id: B-9948fed6
---
# Sources reading experience: article lists, virtual feeds, and reader navigation

## Objective

Build the full Sources tab reading flow: list feeds (real sources plus the
cross-source "Important" and "Unread" virtual feeds), open a feed to browse its
articles with sorting and read/unread filtering, and read any article in the
existing article reader with swipe navigation to the next/previous article.

Flow: **Sources tab (feeds) → article list (sorted/filtered) → article reader
(swipe between articles)**.

## Context

- Builds on spec-37d1bbcf (reader, models, APIClient) and **spec-19056cf7**
  (polish): this spec reuses the `isCancellation` helper, the `ReaderLayout`
  horizontal-padding constant, and the existing `ArticleDetailView`. **Depends on
  spec-19056cf7 being merged first** (shared files: `SourcesView`,
  `ArticleDetailView`, `APIClient`).
- Backend contract: `docs/API.md`, `docs/openapi.json`.
- The existing `Article` model and `PaginatedResponse` are reused as-is.

### Verified API behavior (from the live backend)

- `GET /articles` query params: `view`, `sort`, `category`, `source_id`,
  `unread_only`, `limit`, `cursor`.
- `sort` accepts `importance` (default; importance_score desc, then published
  desc) and `recent` (most-recently-published first) — **now live** in the
  backend, mirroring `GET /threads`. Verified: `sort=recent` returns different,
  newer articles than `sort=importance`.
- `view=important` and `view=unread` work **cross-source** and **combine** with
  `source_id` and `unread_only` (e.g. `?source_id=11&view=important`,
  `?source_id=11&unread_only=true`).
- Small `limit` works (e.g. `limit=4`) → progressive loading is feasible.

## Changes

### 1. ArticleFeed — a unified feed descriptor

New `AggregatorApp/Articles/ArticleFeed.swift`:

```swift
enum ArticleFeed: Hashable, Identifiable {
    case source(id: Int, name: String)
    case important
    case unread

    var id: String { ... }            // stable: "source-<id>", "important", "unread"
    var title: String { ... }         // source name, "Important", "Unread"
    var systemImage: String? { ... }  // virtual feeds: "exclamationmark.circle" / "envelope.badge"; source: nil
    var allowsUnreadFilter: Bool { ... } // false for .unread (already unread), true otherwise
}
```

Maps to base query params:
- `.source(id, _)` → `source_id=<id>`
- `.important` → `view=important`
- `.unread` → `view=unread`

### 2. APIClient — article-list endpoint

Add to `APIClient.swift`:

```swift
enum ArticleSort: String { case importance, recent }

func getArticles(feed: ArticleFeed,
                 sort: ArticleSort,
                 unreadOnly: Bool,
                 limit: Int = 25,
                 cursor: String? = nil) async throws -> PaginatedResponse<Article>
```

Builds query items: the feed's base param (`source_id` or `view`), `sort` (always
sent), `unread_only=true` only when `unreadOnly` is true, `limit`, and `cursor`
when non-nil. Uses the existing generic `get` + `makeURL`. For `.unread`, treat
`unreadOnly` as already implied (don't double-send, harmless if you do).

### 3. SourcesView — feeds list (extend the existing tab)

`AggregatorApp/Sources/SourcesView.swift`. Keep the existing
loading/empty/error/not-configured states and Liquid Glass treatment. Restructure
the loaded state into a `List` with two sections:

- **Section "Feeds"** (virtual, always shown when configured):
  - "Important" → `NavigationLink` to `ArticleListView(feed: .important)`,
    icon `exclamationmark.circle`.
  - "Unread" → `NavigationLink` to `ArticleListView(feed: .unread)`,
    icon `envelope.badge`.
- **Section "Sources"**: the real sources from `GET /sources`, each a
  `NavigationLink` to `ArticleListView(feed: .source(id: s.id, name: s.name))`,
  showing `s.name` and `s.feedURL` caption as today.
- **Pull-to-refresh** (`.refreshable`) reloads the sources list (`GET /sources`).
- Title stays "Sources".

### 4. ArticleListView — the article browser

New `AggregatorApp/Articles/ArticleListView.swift`, initialised with
`feed: ArticleFeed`.

- State: `articles: [Article]`, `nextCursor: String?`, `sort: ArticleSort`
  (default `.importance`), `unreadOnly: Bool` (default `false`; for `.unread`
  feed effectively always unread), a `phase` (loading/loaded/error), and an
  `isLoadingMore` flag.
- **Initial load** uses a small first page (`limit: 15`) so content paints fast.
  Show a centered `ProgressView` while the first page is in flight — the view
  must never appear frozen.
- Render rows as soon as the first page arrives; then **infinite-scroll**: when
  the last row appears and `nextCursor != nil` and not already loading, fetch the
  next page (`limit: 25`) and append. Show a **footer `ProgressView`** while
  loading more. Guard against duplicate concurrent page loads.
- **Pull-to-refresh** (`.refreshable`) reloads the first page for the current
  feed/sort/filter.
- **Sort control**: a toolbar `Menu` (or `Picker`) toggling Importance / Recent;
  changing it reloads from the first page.
- **Read/unread filter**: a toolbar control toggling All / Unread only (drives
  `unreadOnly`), shown only when `feed.allowsUnreadFilter`; changing it reloads.
- Empty state: `ContentUnavailableView` ("No articles" / appropriate message).
- Error state: message + Retry (but treat `isCancellation` as benign — do not show
  the error state for a cancelled fetch, per spec-19056cf7).
- Rows: `ArticleRowView`, each a `NavigationLink` to
  `ArticlePagerView(articles: articles, startIndex: <tapped index>)`.
- `.navigationTitle(feed.title)`.
- **In-view header**: show the current feed's name at the top of the content
  (above the rows), not only in the nav bar. Use a list header / leading-aligned
  header row with `feed.title` as `.title3`/`.bold` (and `feed.systemImage` when
  set, e.g. for Important/Unread). For a source feed this makes it obvious which
  source is being read even when the nav-bar title is collapsed/inline; for the
  virtual feeds it labels them clearly. Optionally include a subtle count/sort
  caption beneath it. The header scrolls with the list (it is content, not a
  pinned bar).

### 5. ArticleRowView — magazine-style article row

New `AggregatorApp/Articles/ArticleRowView.swift`. Consistent with
`ThreadCardView`:

- `HStack(alignment: .top)`:
  - Left `VStack(alignment: .leading)`: title (`.headline`, 2 lines); caption
    (`.caption`, `.secondary`): "{sourceName} · {relative(feedPublishedAt)}" plus
    a small importance badge (reuse the score-pill style/colors from
    `ArticleDetailView`: `>= 80` `.red`, `>= 50` `.orange`, else `.secondary`).
  - Right: `AsyncImage` thumbnail ~80×80 (rounded, clipped, placeholder) when
    `article.imageURL` is present; omitted otherwise (text fills width).
- **Read state**: when `article.isRead`, render the title in `.secondary` (dimmed)
  to distinguish read from unread; unread titles use `.primary`.
- Glass row treatment (`.listRowBackground(Color.clear)` + container) as elsewhere.

### 6. ArticlePagerView — swipe between articles

New `AggregatorApp/Articles/ArticlePagerView.swift`, initialised with
`articles: [Article]` and `startIndex: Int`. Mirrors `ThreadPagerView`:

- Horizontally paged `TabView(selection:)` with
  `.tabViewStyle(.page(indexDisplayMode: .never))`; each page is
  `ArticleDetailView(articleId: articles[i].id)`, tagged by index.
- **Swiping left/right moves to the next/previous article** in the list; selection
  starts at `startIndex`.
- Paging past the last loaded article simply stops (loading further pages from the
  pager is a future enhancement — note in the handoff).
- `.navigationBarTitleDisplayMode(.inline)`.

`ArticleDetailView` is reused unchanged — it already provides the in-app Safari
view ("Open original"), read/unread and save/unsave actions, hero image,
importance badge, chips, and (from spec-19056cf7) paragraph typography and
consistent margins.

### 7. Unit tests

New `AggregatorAppTests/ArticleFeedTests.swift` (no network):

1. **Feed → params**: `.source(id: 11, name: "X")` yields `source_id=11`;
   `.important` yields `view=important`; `.unread` yields `view=unread`.
2. **getArticles URL** via `APIClient.makeURL`: assert the composed query for
   `getArticles(feed: .source(id: 11), sort: .recent, unreadOnly: true, cursor: "C==")`
   contains `source_id=11`, `sort=recent`, `unread_only=true`, percent-encoded
   `cursor=C%3D%3D`, and omits `cursor` when nil.
3. **allowsUnreadFilter**: `false` for `.unread`, `true` for `.source` and
   `.important`.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Articles/ArticleFeed.swift` | New feed descriptor enum + query mapping |
| `AggregatorApp/Common/APIClient.swift` | Add `ArticleSort` + `getArticles(...)` |
| `AggregatorApp/Sources/SourcesView.swift` | Feeds section (Important/Unread) + sources navigate to `ArticleListView`; pull-to-refresh sources |
| `AggregatorApp/Articles/ArticleListView.swift` | New article browser (sort, filter, pagination, progressive load, refresh) |
| `AggregatorApp/Articles/ArticleRowView.swift` | New magazine-style article row |
| `AggregatorApp/Articles/ArticlePagerView.swift` | New swipe-between-articles container |
| `AggregatorAppTests/ArticleFeedTests.swift` | New unit tests |

After implementation run `xcodegen generate`, then:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [x] `xcodegen generate` succeeds; `xcodebuild test` exits 0 (incl. new ArticleFeed tests)
- [x] Sources tab shows a "Feeds" section (Important, Unread) above the real sources
- [x] Tapping Important lists important articles across all sources; Unread lists unread across all sources
- [x] Tapping a source lists that source's articles
- [x] The article list shows the current source/feed name as an in-view header at the top of the content (in addition to the nav-bar title)
- [x] Sort toggle offers Importance and Recent, both effective via the live `sort` param; the chosen sort and read/unread filter persist across launches (shared `ListPreferences` store)
- [x] Read/unread filter (All / Unread only) works for source and Important feeds; hidden for the Unread feed
- [x] Article list never appears frozen: a spinner shows during the initial load, content paints from a small first page, and a footer spinner shows while paginating
- [x] Scrolling to the bottom loads more via `next_cursor` without duplicate rows
- [x] Pull-to-refresh on the Sources list refreshes the sources; pull-to-refresh inside a feed refreshes that feed
- [x] Tapping an article opens the reader; swiping left/right moves to the next/previous article in the list
- [x] The reader's "Open original" opens the in-app Safari view (existing behavior)
- [x] Read articles are visually de-emphasised in the list vs unread
- [x] Cancelled fetches (navigation transitions) do not show an error state
- [x] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Recency sort backend dependency**: resolved — the backend now supports
  `sort=importance|recent` on `GET /articles` (mirroring `/threads`). Both sorts
  are fully effective; no further dependency.
- **"Read only" filter**: the API supports "unread only" (`unread_only=true`) but
  has no "read only" filter, so the toggle is All / Unread only (not a 3-way).
- **Preference persistence**: the article-list sort and read/unread filter must
  persist across launches via the shared `ListPreferences` store (introduced by
  the Threads-sort-persistence defect). Reuse that store; add `articlesSort` /
  `articlesUnreadOnly` keys to it rather than creating a parallel store.
- **Sequencing**: build after spec-19056cf7 (polish) and the list-preference
  persistence defect — reuses the `isCancellation` helper, `ReaderLayout`
  constant, and `ListPreferences` store.

## Implementation Notes

### ArticlePagerView: pagination is bounded to the loaded slice

`ArticlePagerView` receives the `articles` array that `ArticleListView` has
already loaded. Swiping past the last article in that array simply stops — no
additional pages are fetched from within the pager. If the user reaches the
end of the currently loaded page, they need to return to the list and scroll
down to trigger the next page load before tapping into the pager again. This
is a known limitation; loading further pages on-demand from within the pager
is a future enhancement.

### ListPreferences: UserDefaults key names for article preferences

Two new keys were added to `ListPreferences` alongside the existing Threads
keys:

| Property | UserDefaults key | Default |
|---|---|---|
| `articlesSort` | `aggregator.articlesSort` | `.importance` |
| `articlesUnreadOnly` | `aggregator.articlesUnreadOnly` | `false` |

Both follow the same `aggregator.` prefix convention as the existing Threads
keys (`aggregator.threadsSort`, `aggregator.threadsShowDismissed`). Pass a
custom `UserDefaults` suite (e.g. `UserDefaults(suiteName: "test-…")`) to
`ListPreferences(defaults:)` in tests to avoid touching the real defaults.

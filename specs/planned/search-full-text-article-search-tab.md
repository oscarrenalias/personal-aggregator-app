---
name: "Search: full-text article search tab"
id: spec-9ada6cc7
description: "Add full-text article search as a dedicated iOS 26 Tab(role: .search): debounced searchable results list hitting GET /articles/search, reusing ArticleRowView -> ArticlePagerView. New APIClient.searchArticles + SearchView; no sort (endpoint has none)."
dependencies: null
priority: medium
complexity: null
status: planned
tags:
- articles
- search
- navigation
- tabs
scope:
  in: null
  out: null
feature_root_id: B-cc58d0d7
---
# Search: full-text article search tab

## Objective

Add full-text article search — a capability listed in the project scope
(`CLAUDE.md`: "article list, threads view, daily brief, **search**, sources/
categories") that was never implemented. Surface it as a dedicated **Search tab**
using the iOS 26 `Tab(role: .search)` treatment (detached, trailing edge of the
Liquid Glass tab bar). The tab presents a live, debounced search field; results
reuse the existing article row → reader → pager stack. No new model, no backend
work — the endpoint already exists.

## Context

- The backend exposes `GET /articles/search` but the app has **no** search: no
  `.searchable`, no Search tab, no `APIClient` method. This spec adds only the
  search surface; everything downstream (reading, mark-read, save) already works.
- Mirrors the existing feed pattern: a search results list is just a paginated
  `[Article]` rendered with `ArticleRowView`, navigating into
  `ArticlePagerView(articles:startIndex:)` — identical to `ArticleListView`
  (`AggregatorApp/Articles/ArticleListView.swift`). The difference from a feed:
  the query is user-typed and there is **no sort/unread filter** (the endpoint
  takes no `sort`), so search has its own lightweight view rather than reusing
  `ArticleListView` (which carries the sort/unread toolbar + `ListPreferences`).

### Verified API behavior

From `docs/API.md:83` and `docs/openapi.json:226`:

- `GET /articles/search` parameters: **`q` (required, string)**, `category`
  (optional), `source_id` (optional int), `limit` (optional int, default 50),
  `cursor` (optional string). **No `sort`, no `view`, no `unread_only`.**
- Response: `PaginatedResponse_ArticleResponse_` — the same
  `{ items: [...], next_cursor }` shape `getArticles` already decodes into
  `PaginatedResponse<Article>`.
- A missing/empty `q` yields `422` (validation error); the client must not call
  the endpoint with an empty query.
- Results arrive in backend relevance order; the app must not re-sort or expose a
  sort control.

## Changes

### 1. APIClient — `searchArticles`

Add to `AggregatorApp/Common/APIClient.swift` (near `getArticles`, line 153),
returning the existing `PaginatedResponse<Article>`:

```swift
/// Full-text article search. `q` is required; an empty/whitespace query must
/// not reach here (the endpoint returns 422). No sort param — results come back
/// in backend relevance order. Cursor-paginated like the other list endpoints.
/// Page size is 25 (smaller than the endpoint's 50 default) to keep first-page
/// latency low for live-typed queries, matching `ArticleListView`'s small pages.
func searchArticles(q: String, limit: Int = 25, cursor: String? = nil) async throws -> PaginatedResponse<Article> {
    var query: [URLQueryItem] = [URLQueryItem(name: "q", value: q)]
    query.append(URLQueryItem(name: "limit", value: "\(limit)"))
    if let cursor {
        query.append(URLQueryItem(name: "cursor", value: cursor))
    }
    return try await get("/articles/search", query: query)
}
```

(`category`/`source_id` are intentionally omitted — see Pending Decisions.)

### 2. SearchView — new file `AggregatorApp/Search/SearchView.swift`

Modeled on `ArticleListView` but with a typed query and **no sort/unread
toolbar**. Structure:

- `@State private var query = ""`, plus `articles`, `nextCursor`, a load phase,
  and `isLoadingMore` (same shape as `ArticleListView`).
- Root: `NavigationStack { content }.navigationTitle("Search")` with
  `.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))`
  so the field is always visible. (Verify the exact `.searchable` placement plays
  well with the `role: .search` tab at implementation — see Pending Decisions.)
- **Debounced live search** via `.task(id: query)`: trim the query; if empty,
  clear results and show the idle state; otherwise `try await Task.sleep` ~300 ms
  (cancellation from the next keystroke supersedes it), then call
  `searchArticles(q:)`. Treat `CancellationError` as a no-op (reuse `isCancellation`).
- Also trigger an immediate search on `.onSubmit(of: .search)`.
- **Pagination**: on the last row's `.onAppear`, fetch the next page with the
  **current committed query** + `nextCursor` (store the query that produced the
  current results so paging doesn't mix queries).
- Rows: reuse `ArticleRowView(article:)` inside `NavigationLink { ArticlePagerView(articles: articles, startIndex: index) }`
  (destination-based, matching `ArticleListView:119`), wrapped in
  `GlassEffectContainer`.
- **States (all required):**
  - **Idle** (empty query): `ContentUnavailableView("Search Articles", systemImage: "magnifyingglass", description: …)`.
  - **Loading**: `ProgressView`.
  - **Empty** (query, zero results): `ContentUnavailableView.search(text: query)`.
  - **Error**: message + Retry (re-runs the current query).
  - **Loaded**: the results `List`.
- Not-configured: show the same "Not configured" `ContentUnavailableView` used by
  the other tabs when `!credentialsStore.isConfigured`.

### 3. AppRoot — Search tab

In `AggregatorApp/AppRoot.swift`, add a tab with the search role (placed before
or after Settings — the role detaches it regardless):

```swift
Tab("Search", systemImage: "magnifyingglass", value: "search", role: .search) {
    SearchView()
}
```

Settings remains a tab (resolved decision). `selectedTab` stays a `String`.

### 4. project.yml / xcodegen

`SearchView.swift` is a new file under the existing `AggregatorApp` source glob —
no `project.yml` edit needed, but **run `xcodegen generate`** before building so
the file is in the target. (New `Search/` group is created automatically.)

### 5. Unit tests

`AggregatorAppTests` (match the existing `APIClient`/feed query-construction
tests):
- `searchArticles` emits `q=<query>` and `limit`, and `cursor` only when provided.
- The query string is correctly percent-encoded for multi-word / special-char
  queries (e.g. `q=open ai` → `q=open%20ai`).
- **No `sort`, `view`, or `unread_only`** params are emitted.
- **Empty-query short-circuit**: a trimmed-empty / whitespace-only query does not
  invoke the network (no `searchArticles` request is constructed) — mirrors the
  acceptance criterion and avoids the 422 round-trip. Test at whatever layer the
  guard lives (the view's debounce task, or a small extracted guard helper).

## Files to Modify

| File | Change |
|---|---|
| `AggregatorApp/Common/APIClient.swift` | Add `searchArticles(q:limit:cursor:)` → `PaginatedResponse<Article>` |
| `AggregatorApp/Search/SearchView.swift` | **New** — debounced searchable results list; Idle/Loading/Empty/Error/Loaded |
| `AggregatorApp/AppRoot.swift` | Add `Tab(role: .search)` hosting `SearchView` |
| `AggregatorAppTests/...` | `searchArticles` query-construction tests |

Run `xcodegen generate`, then the test gate
(`xcodebuild test -scheme AggregatorApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 including the new `searchArticles` tests
- [ ] A detached **Search** tab appears at the trailing edge of the tab bar
      (`role: .search`); the other tabs (Threads/Sources/Today/Settings) are unchanged
- [ ] Typing in the field performs a live, debounced search (no request per
      keystroke); submitting runs it immediately
- [ ] An empty/whitespace query never hits the network and shows the **Idle** prompt
- [ ] Results render with `ArticleRowView`; tapping one opens `ArticlePagerView`
      and articles mark-read / save via the existing toolbar actions
- [ ] Results paginate via cursor using the committed query (paging never mixes queries)
- [ ] **Empty** (no matches), **Loading**, and **Error** (with Retry) states are
      all handled, plus the **Not configured** state
- [ ] No sort/unread control is shown; results stay in backend relevance order
- [ ] No hardcoded hex colors; standard controls, SF Symbols, Liquid Glass
      conventions preserved (`GlassEffectContainer` around the list)

## Pending Decisions

- **Entry point**: resolved — dedicated `Tab(role: .search)`; Settings stays a tab.
  (Considered and rejected: 5th plain tab, relocating Settings to a toolbar gear.)
- **Live vs submit-only**: resolved — live debounced search (~300 ms) *and*
  on-submit. Debounce interval is a tuning detail for implementation.
- **`category` / `source_id` scoping**: out of scope for v1. The endpoint supports
  narrowing search to a category or source; a later enhancement could add a scope
  picker. v1 searches everything via `q` only.
- **Search history / recent searches / suggestions**: out of scope.
- **`.searchable` placement vs `role: .search`**: the exact composition of an
  always-visible `.searchable` field inside a search-role tab is a new iOS 26 API
  interaction — verify on a real run at implementation and adjust placement
  (`.navigationBarDrawer` vs `.automatic`) to match the native detached-search feel.
- **Deep linking to a search query**: out of scope (no `aggregator://search` route).

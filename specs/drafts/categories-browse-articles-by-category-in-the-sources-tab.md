---
name: "Categories: browse articles by category in the Sources tab"
id: spec-ac336102
description: "Add a Categories section to the Sources tab (GET /categories, ordered) opening category-filtered article lists; reuses the article list/reader/pager via a new ArticleFeed.category case."
dependencies: null
priority: medium
complexity: null
status: draft
tags:
- categories
- sources
- articles
- browsing
scope:
  in: null
  out: null
feature_root_id: null
---
# Categories: browse articles by category in the Sources tab

## Objective

Let the user browse articles by category. Add a "Categories" section to the
Sources tab listing the backend's categories (ordered by `sort_order`); tapping
a category opens the existing article list filtered to that category. A category
is just another article feed, so this reuses the whole article list → reader →
pager stack.

## Context

- Builds on the merged Sources feature (`spec-7bb21007`): reuse `ArticleFeed`,
  `ArticleListView`, `ArticleRowView`, `ArticlePagerView`, `APIClient`,
  `ListPreferences`. The Sources tab already has a "Feeds" section
  (Important/Unread) plus the sources list.
- The reader's article cards already display category chips (read-only); this
  spec adds category *browsing*, not chip interaction (chips stay non-interactive).

### Verified API behavior

- `GET /categories` → array of `CategoryResponse`: `id: Int`, `name: String`,
  `description: String?`, `sort_order: Int`. Returned ordered by `sort_order`
  (verified: 6 categories, e.g. "AI", "Cloud & Architecture", "Gaming").
- `GET /articles?category=<name>&sort=&unread_only=&limit=&cursor=` filters
  articles to that category and composes with sort and the unread filter
  (verified: `category=Game Reviews` returns matching articles). `category` is
  matched by **name** (not id).

### Category freshness subtitle — backend dependency

The web sidebar shows a freshness line under each category, computed server-side
from two per-category fields (`has_priority`, `last_activity`):

```
has_priority                          → "New notable stories"
last_activity is today                → "Updated today"
last_activity is yesterday            → "Updated yesterday"
otherwise                             → "Quiet"
```

The JSON API's `CategoryResponse` does **not** currently expose `has_priority`
or `last_activity`. A backend change to add them is requested separately. Per the
`image_url`/`comments_url` precedent, build the iOS subtitle **now** but dormant:
decode the fields defensively (absent → no subtitle) so the category rows simply
show the name today, and gain the freshness line automatically when the backend
ships the fields.

## Changes

### 1. Category model

New `AggregatorApp/Models/Category.swift`:
```swift
struct Category: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let sortOrder: Int
    // Freshness fields — absent in the current API; decoded defensively so the
    // subtitle activates when the backend adds them (see freshness subtitle above).
    let lastActivity: String?   // last_activity (ISO-8601), decodeIfPresent → nil
    let hasPriority: Bool       // has_priority, decodeIfPresent → false

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case sortOrder = "sort_order"
        case lastActivity = "last_activity"
        case hasPriority = "has_priority"
    }
}
```
Decode `lastActivity` with `decodeIfPresent` (→ nil) and `hasPriority` with
`decodeIfPresent ?? false`, so the current API (without these fields) decodes fine.

### 1a. Freshness phrase helper

Add a pure, testable helper (e.g. `Category.freshnessPhrase(now:)` or a function
in `DateDisplay`) mirroring the web macro, returning an optional String:
- `hasPriority == true` → "New notable stories"
- else parse `lastActivity`: same calendar day as `now` → "Updated today";
  previous day → "Updated yesterday"; older → "Quiet"
- `lastActivity == nil` && `!hasPriority` → return `nil` (no subtitle; current API)
Inject `now` (default `Date()`) for deterministic testing.

### 2. ArticleFeed — category case

Add a case to `AggregatorApp/Articles/ArticleFeed.swift`:
- `case category(name: String)`
- `id`: `"category-<name>"`
- `title`: the category name
- `systemImage`: `"tag"` (a category glyph; virtual feeds already set icons)
- `allowsUnreadFilter`: `true` (unread filtering is valid within a category)
- Query mapping: `category=<name>` (URL-encoded by the existing `makeURL`/
  `URLQueryItem` path). The base param is `category`, distinct from `source_id`
  and `view`.

`APIClient.getArticles(feed:...)` already builds the query from the feed's base
param — extend its feed→param mapping to emit `category` for `.category`.

### 3. APIClient — categories endpoint

Add `func getCategories() async throws -> [Category]` → `GET /categories`
(non-paginated array, like `getSources()`).

### 4. SourcesView — Categories section

`AggregatorApp/Sources/SourcesView.swift`:
- Also fetch `getCategories()` (concurrently with `getSources()`), stored in
  state. Reuse the existing load-once / refresh pattern (and the scroll-
  preservation behaviour — load once, pull-to-refresh reloads both lists).
- Insert a **"Categories"** `Section` between the "Feeds" section and the
  "Sources" section, listing categories in returned order. Each row is a
  `NavigationLink` (destination-based, matching the rest of the tab) to
  `ArticleListView(feed: .category(name: category.name))`. Each row shows the
  category name and, **when `freshnessPhrase(now:)` is non-nil**, the freshness
  line as a `.caption`/`.secondary` subtitle beneath it (no subtitle on the
  current API). Show the section only when categories is non-empty.
- Pull-to-refresh refreshes sources and categories.
- Loading/empty/error/not-configured states unchanged (categories load failure
  should not blank the whole tab — if categories fail but sources succeed, still
  show sources; treat a categories error as "no categories section").

### 5. Unit tests

`AggregatorAppTests`:
- **Category decoding**: decode `{"id":4,"name":"AI","description":"…","sort_order":40}`
  (current API shape): assert `name`, `sortOrder` (from `sort_order`), a nil
  description case, `lastActivity == nil`, and `hasPriority == false`. Also decode
  a future-shape object including `last_activity` + `has_priority` and assert they
  populate.
- **Freshness phrase** with an injected fixed `now`: `hasPriority` → "New notable
  stories"; a `last_activity` on `now`'s day → "Updated today"; previous day →
  "Updated yesterday"; older → "Quiet"; nil activity + not priority → nil.
- **ArticleFeed.category → params** via `APIClient.makeURL`/getArticles: assert
  `.category(name: "Game Reviews")` produces `category=Game%20Reviews` (encoded),
  composes with `sort` and `unread_only`, and `allowsUnreadFilter == true`.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Models/Category.swift` | New `Category` model |
| `AggregatorApp/Articles/ArticleFeed.swift` | Add `.category(name:)` case + `category` query mapping |
| `AggregatorApp/Common/APIClient.swift` | Add `getCategories()`; emit `category` param for `.category` feed |
| `AggregatorApp/Sources/SourcesView.swift` | Fetch categories; add "Categories" section navigating to filtered article lists |
| `AggregatorAppTests/...` | Category decoding + ArticleFeed.category param tests |

Run the test gate (`bash scripts/run-tests.sh`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 incl. new category tests
- [ ] Sources tab shows a "Categories" section (ordered by `sort_order`) between Feeds and Sources
- [ ] Category rows show a freshness subtitle when the API provides `last_activity`/`has_priority` ("New notable stories" / "Updated today" / "Updated yesterday" / "Quiet"); on the current API (fields absent) rows show just the name, no subtitle, no error
- [ ] Tapping a category opens the article list filtered to that category, on the first tap
- [ ] Category article lists support the existing sort (importance/recent) and All/Unread filter, and persist those via `ListPreferences`
- [ ] Pull-to-refresh on the Sources tab refreshes both sources and categories
- [ ] If categories fail to load but sources succeed (or vice versa), the tab still shows what it has (no full-tab blank/error)
- [ ] Not-configured state unchanged; returning from a category list preserves scroll (load-once)
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Placement**: resolved — a "Categories" section inside the Sources tab
  (between Feeds and Sources), per the chosen UX.
- **Freshness subtitle**: resolved — build it now, dormant. Needs the backend to
  add `last_activity` (ISO-8601) and `has_priority` (bool) to `CategoryResponse`
  (request handed off separately). The web computes these server-side; the iOS
  phrase logic mirrors the web macro and activates when the fields appear.
- **Category chips in the reader**: remain non-interactive in this spec (making
  them tappable to open a category feed is a possible later enhancement).
- **Filtering key**: the API filters by category **name**; `ArticleFeed.category`
  carries the name accordingly.

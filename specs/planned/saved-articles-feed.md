---
name: Saved articles feed
id: spec-c142424c
description: Add a Saved entry to the Sources tab Feeds section (GET /articles?view=saved) opening a saved-articles list; reuses the article list/reader/pager via a new ArticleFeed.saved case. Unread filter disabled.
dependencies: null
priority: medium
complexity: null
status: planned
tags:
- articles
- saved
- sources
- browsing
scope:
  in: null
  out: null
feature_root_id: B-c2456509
---
# Saved articles feed

## Objective

Let the user browse the articles they've saved. Add a **"Saved"** entry to the
existing "Feeds" section of the Sources tab (alongside Important and Unread);
tapping it opens the existing article list filtered to saved articles via
`GET /articles?view=saved`. Saved is just another article feed, so this reuses
the whole article list → reader → pager stack with no new screens.

## Context

- Directly mirrors the merged Categories feature (`spec-ac336102`) and the
  Important/Unread feeds: a new `ArticleFeed` case plus a query mapping, surfaced
  as a `NavigationLink` in `SourcesView`. No new model, no new view.
- Save/unsave already exist end-to-end: `APIClient.saveArticle(id:)` /
  `unsaveArticle(id:)` (`AggregatorApp/Common/APIClient.swift:220`), the bookmark
  toggle in `ArticlePagerView`/`ArticleDetailView`, and `Article.isSaved`
  (`AggregatorApp/Models/Article.swift:17`). This spec adds only the *browse*
  surface for saved articles.

### Verified API behavior

- `view` enum on `GET /articles` includes `saved` (`docs/API.md:112`).
- `GET /articles?view=saved&sort=&limit=&cursor=` returns the saved articles as a
  standard cursor-paginated `{ items, next_cursor }` list, composing with `sort`
  exactly like the other views (`view=important` / `view=unread`).

## Changes

### 1. ArticleFeed — saved case

Add a case to `AggregatorApp/Articles/ArticleFeed.swift` (compiler will flag the
four switches to fill in):
- `case saved`
- `id`: `"saved"`
- `title`: `"Saved"`
- `systemImage`: `"bookmark"` (matches the save toolbar glyph; `bookmark.fill` is
  the saved/active state used in the reader toolbar)
- `allowsUnreadFilter`: **`false`** — join `.unread` in the existing
  `case .unread: return false` arm. Saved always shows everything you've saved
  regardless of read state (resolved decision).

### 2. APIClient — query mapping

In `APIClient.getArticles(feed:...)` (`AggregatorApp/Common/APIClient.swift:152`),
add `case .saved: query.append(URLQueryItem(name: "view", value: "saved"))`, and
update the method's doc comment (lines ~146–147) to list `.saved` → `view=saved`.

### 3. SourcesView — Saved feed row

In `AggregatorApp/Sources/SourcesView.swift`, add a third `NavigationLink` to the
existing **"Feeds"** `Section` (after the Unread link, ~line 47):
```swift
NavigationLink(destination: ArticleListView(feed: .saved)) {
    Label("Saved", systemImage: "bookmark")
}
.accessibilityLabel("Saved articles")
.listRowBackground(Color.clear)
```
No other `SourcesView` changes — no extra fetch (saved articles load lazily in
`ArticleListView`, like Important/Unread).

### 4. Unit tests

`AggregatorAppTests`:
- **ArticleFeed.saved → params**: assert `.saved` produces `view=saved` (via the
  same `APIClient`/`getArticles` query path the Important/Unread tests use),
  composes with `sort`, and that `allowsUnreadFilter == false`.
- **ArticleFeed.saved identity**: assert `id == "saved"`, `title == "Saved"`,
  `systemImage == "bookmark"`.

## Files to Modify

| File | Change |
|---|---|
| `AggregatorApp/Articles/ArticleFeed.swift` | Add `.saved` case (id/title/systemImage; `allowsUnreadFilter == false`) |
| `AggregatorApp/Common/APIClient.swift` | Emit `view=saved` for `.saved`; update doc comment |
| `AggregatorApp/Sources/SourcesView.swift` | Add "Saved" `NavigationLink` to the Feeds section |
| `AggregatorAppTests/...` | `ArticleFeed.saved` param + identity tests |

Run the test gate (`xcodebuild test ... -scheme AggregatorApp`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 incl. the new saved-feed tests
- [ ] Sources tab "Feeds" section shows Important, Unread, **Saved** (bookmark icon), in that order
- [ ] Tapping Saved opens the article list of saved articles on the first tap, with the title "Saved"
- [ ] The Saved list paginates (cursor) and supports the sort (importance/recent) control like other feeds
- [ ] The "Unread Only" filter is **not** offered in the Saved feed (`allowsUnreadFilter == false`)
- [ ] Saved list handles Empty (no saved articles), Loading, and Error states
- [ ] Articles opened from the Saved list still save/unsave and mark read via the existing toolbar actions
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Placement**: resolved — a "Saved" row inside the Sources tab's existing
  "Feeds" section, after Unread.
- **Unread Only filter**: resolved — **disabled** in the Saved feed
  (`allowsUnreadFilter == false`), like the Unread feed. Saved shows all saved
  articles regardless of read state.
- **Icon**: resolved — `bookmark` (the save action's glyph).
- **Live removal on unsave**: out of scope. Unsaving an article from within the
  Saved list will not drop it from the list until a refresh/reload — consistent
  with how read-state changes behave in the existing lists. A later enhancement
  could remove the row optimistically.
- **Sort default**: inherits the feed-wide default and the user's persisted
  `ListPreferences` sort; no saved-specific sort behavior.

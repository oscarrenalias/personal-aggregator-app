---
name: "Source rows: favicons and activity dots"
id: spec-bfb50962
description: "Source-list rows show cached favicons (DuckDuckGo, from feed_url) and an activity dot (blue=important, gray=new) dormant until SourceResponse exposes has_new/has_priority."
dependencies: null
priority: medium
complexity: null
status: done
tags:
- sources
- favicons
- activity-dots
- caching
scope:
  in: null
  out: null
feature_root_id: B-059d7a6e
---
# Source rows: favicons and activity dots

## Objective

Enrich the source rows in the Sources tab with:
1. **Favicons** — each source shows its site favicon (when available), derived
   from the feed URL and cached on-device so it isn't re-fetched every time.
2. **Activity dots** — a blue dot when the source has important news, a gray dot
   when it has new (non-important) updates, mirroring the web sidebar.

## Context

- Builds on the merged Categories/Sources work. Source rows live in
  `AggregatorApp/Sources/SourcesView.swift`; the `Source` model is
  `AggregatorApp/Models/Source.swift` (`id, name, feedURL`).
- Mirrors the web `_sidebar.html` `activity_dot(has_new, has_priority)` macro:
  `has_priority` → blue (accent) dot; else `has_new` → gray (muted) dot; else
  nothing. (CSS: `.sidebar-dot` muted, `.sidebar-dot.is-priority` accent.)
- The web does NOT show source favicons — that part is iOS-only.

### Backend dependency (activity dots only)

`SourceResponse` exposes only `id, name, feed_url`. The dots need `has_new` and
`has_priority` per source, which the backend is adding separately (request handed
off). Per the established pattern, build the iOS side **dormant**: decode the
fields defensively (absent → `false`), so rows show no dot today and gain the
dots automatically when the fields ship. **Favicons have no backend dependency.**

## Changes

### 1. Source model — activity flags

In `AggregatorApp/Models/Source.swift` add:
- `hasNew: Bool` (from `has_new`, `decodeIfPresent ?? false`)
- `hasPriority: Bool` (from `has_priority`, `decodeIfPresent ?? false`)

Keep existing `id, name, feedURL`. The current API (without these) must still
decode (defaults to `false`).

### 2. Favicon loading + cache

New `AggregatorApp/Common/FaviconLoader.swift` — a shared, cached favicon loader:
- Derive the host from a source's `feedURL` via `URLComponents`. Build the icon
  URL `https://icons.duckduckgo.com/ip3/<host>.ico`.
- Two-level cache: an in-memory `NSCache<NSString, UIImage>` keyed by host, and an
  on-disk cache in the Caches directory (e.g. `favicons/<sha or sanitized host>.png`).
  Lookup order: memory → disk → network (DuckDuckGo). On network success, store to
  disk + memory. Return `nil` on any failure (no icon shown).
- Expose `func icon(forFeedURL: String) async -> UIImage?` (or `Image?`). Make it
  an `actor` or use a serial queue so concurrent row loads dedupe/are safe.
- Implemented with `URLSession.shared`; failures are swallowed (best-effort).

New `AggregatorApp/Common/SourceFaviconView.swift` — a small SwiftUI view:
- `SourceFaviconView(feedURL: String)`, fixed ~20×20pt, rounded.
- On appear, `Task { image = await FaviconLoader.shared.icon(forFeedURL:) }`,
  store in `@State image: UIImage?`. Show the image when present; otherwise a
  neutral placeholder (e.g. SF Symbol `globe` in `.secondary`) — never blank/jumpy.
- Because the loader caches, re-appearing rows don't re-fetch.

### 3. Activity dot

New small view/helper for the dot (e.g. `SourceActivityDot(source:)` or an inline
`@ViewBuilder`): an 8pt filled `Circle`, shown only when `hasPriority || hasNew`:
- `hasPriority` → `.tint` (accent/blue), accessibility label "Important updates"
- else `hasNew` → `.secondary` (gray), accessibility label "New updates"
- else → nothing.
Do not rely on color alone for meaning — the accessibility labels distinguish them.

### 4. SourcesView — source row layout

Update the "Sources" section rows in `SourcesView.swift`. Each source
`NavigationLink` label becomes:
`HStack { SourceFaviconView(feedURL:) ; Text(source.name) ; Spacer() ; dot }`
- Favicon leading, name next, the activity dot trailing (matching the web's
  name-then-dot order).
- Keep `.listRowBackground(Color.clear)` and the accessibility label (include the
  dot meaning, e.g. "BBC News, important updates").
- The Feeds and Categories sections are unchanged (favicons/dots are for real
  sources, which have a `feedURL`).

### 5. Unit tests

`AggregatorAppTests`:
- **Source decoding**: current shape `{"id":1,"name":"X","feed_url":"https://e.com/rss"}`
  → `hasNew == false`, `hasPriority == false`; future shape with `has_new`/
  `has_priority` populates them.
- **Favicon host derivation**: a pure helper mapping a feed URL to the icon URL,
  e.g. `https://feeds.bbci.co.uk/news/rss.xml` → host `feeds.bbci.co.uk` →
  `https://icons.duckduckgo.com/ip3/feeds.bbci.co.uk.ico`; invalid URL → nil.
  (Extract the URL-building into a testable static function.)

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Models/Source.swift` | Add `hasNew` / `hasPriority` (defensive decode) |
| `AggregatorApp/Common/FaviconLoader.swift` | New cached favicon loader (memory + disk) |
| `AggregatorApp/Common/SourceFaviconView.swift` | New favicon view with placeholder |
| `AggregatorApp/Sources/SourcesView.swift` | Source rows: favicon + name + activity dot |
| `AggregatorAppTests/...` | Source decoding + favicon URL tests |

Run the test gate (`bash scripts/run-tests.sh`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 incl. new tests
- [ ] Each source row shows its favicon when available (leading), with a neutral placeholder otherwise; layout never jumps
- [ ] Favicons are cached on disk — scrolling/leaving and returning does not re-fetch them (verify no repeated network for the same host)
- [ ] Source rows show a blue dot when `has_priority`, a gray dot when `has_new` (not priority), and no dot otherwise; on the current API (fields absent) no dots appear and no error
- [ ] Dots have distinct accessibility labels (not color-only)
- [ ] Feeds and Categories sections unchanged; not-configured/loading/error states unchanged
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Favicon source**: resolved — client-side via DuckDuckGo's
  `icons.duckduckgo.com/ip3/<host>.ico` derived from `feed_url`, cached on disk.
  (Trade-off accepted: source hostnames go to that service; a feed subdomain may
  not always yield the site's exact logo.)
- **Activity dots backend dependency**: resolved — backend to add `has_new` +
  `has_priority` to `SourceResponse`; iOS dormant until then.
- **Scope**: favicons/dots are on the real-source rows in the Sources **list**
  only (not Feeds/Categories rows). **Do NOT** show favicons in the source detail
  (the `ArticleListView` opened on tap — no favicon in its header or article rows),
  nor in the article reader. List rows only.

---
name: "Reader enhancements: share sheet, selectable text, and comments link"
id: spec-f1e7a6a5
description: "Reader toolbar share sheet (title+URL), selectable body/summary text, and a comments-link action (dormant until backend exposes comments_url)."
dependencies: null
priority: medium
complexity: null
status: done
tags:
- reader
- share
- text-selection
- comments
- toolbar
scope:
  in: null
  out: null
feature_root_id: B-5bd93857
---
# Reader enhancements: share sheet, selectable text, and comments link

## Objective

Three reader improvements from user testing:
1. **Share sheet** — share the current article (title + URL) via the native iOS
   share sheet from the reader toolbar.
2. **Selectable text** — allow selecting/copying the article body and summary.
3. **Comments link** — when an article has a separate discussion/comments URL
   (e.g. Hacker News), offer a "comments" action that opens it in the in-app
   Safari view, alongside the existing "open original".

## Context

- Builds on the merged reader: `ArticleContentView` (pure content),
  `ArticleDetailView` (standalone reader toolbar), `ArticlePagerView` (paged
  reader with its own single toolbar), `SafariView`, `Article` model, `APIClient`.
- **Both** `ArticleDetailView` and `ArticlePagerView` own toolbars (the pager has
  a single toolbar reflecting the selected article). New toolbar actions must be
  added to **both** so the behaviour is consistent whether an article is opened
  standalone (Threads/Today refs) or in the paged reader (Sources).

### Comments link — backend dependency

The API's `ArticleResponse` currently exposes `url` (source link) but **not** a
comments link. The backend DB has `comments_url` (the web client renders an HN
comments icon from it); a backend change to surface it as `comments_url` in
`ArticleResponse` is being made separately (request handed off). Per the
`image_url` precedent, build the iOS side **now** so it activates automatically
when the field ships:
- `Article` decodes `comments_url` defensively (absent today → `nil`).
- The comments toolbar action is shown only when `commentsURL` is present, so it
  stays hidden until the backend provides it.

## Changes

### 1. Article model — comments URL

In `AggregatorApp/Models/Article.swift` add:
`commentsURL: String?` decoded from `comments_url` via `decodeIfPresent`
(defaults to `nil`; absent in the current API). Mirrors the existing `imageURL`
/ `image_url` field.

### 2. Selectable text (defect #4)

Make the reader body and summary selectable for copy/paste:
- In `AggregatorApp/Common/ParagraphText.swift`, add `.textSelection(.enabled)`
  to the rendered `Text`. This covers both the body and the AI summary (both use
  `ParagraphText`). The title may also get `.textSelection(.enabled)` in
  `ArticleContentView` if trivial.
- Verify selection works inside the vertically-scrolling reader and, in the
  pager, does not break horizontal swiping (text selection uses a long-press, so
  it should not conflict with the page swipe gesture — confirm in testing).

### 3. Share sheet

Add a native share action to the reader toolbars using SwiftUI `ShareLink`:
- Share **title + URL**. Preferred form:
  `ShareLink(item: url, subject: Text(title), message: nil)` with the article
  title as the subject, or share a composed item so the title accompanies the
  link. If `url` is nil, omit/disable the share control.
- Add to the toolbar in **both** `ArticleDetailView` and `ArticlePagerView`
  (for the pager, share the currently-selected article). Place it in the
  trailing toolbar group with the existing save/read/safari actions; use the
  standard `square.and.arrow.up` symbol (ShareLink provides this by default).
- Keep the toolbar a single unconditional `ToolbarItemGroup` (do not introduce
  conditional toolbar content — that previously caused a type-check hang).

### 4. Comments link

Add a comments action to the reader toolbars, shown only when the current
article has a non-empty `commentsURL`:
- Opens `commentsURL` in the in-app `SafariView` (same mechanism as "open
  original"), distinct from the source `url`.
- Symbol: `bubble.left.and.bubble.right` (or `text.bubble`); accessibility label
  "Open comments".
- Add to **both** `ArticleDetailView` and `ArticlePagerView` toolbars.
- Because it must be conditional on `commentsURL != nil` but conditional toolbar
  content is risky, prefer keeping the button always present but **disabled**
  (`.disabled(commentsURL == nil)`) — same pattern the safari button already uses
  with `url == nil`. (Avoids `if` inside `.toolbar`.) Today it will always be
  disabled until the backend ships `comments_url`.

### 5. Unit tests

`AggregatorAppTests`: extend the Article decoding test to assert `commentsURL`
decodes from `comments_url` when present and is `nil` when absent.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Models/Article.swift` | Add `commentsURL` (`comments_url`, decodeIfPresent) |
| `AggregatorApp/Common/ParagraphText.swift` | `.textSelection(.enabled)` on the body/summary text |
| `AggregatorApp/Articles/ArticleContentView.swift` | (optional) selectable title |
| `AggregatorApp/Articles/ArticleDetailView.swift` | Toolbar: ShareLink (title+URL) + comments button (disabled when nil) |
| `AggregatorApp/Articles/ArticlePagerView.swift` | Same toolbar additions for the selected article |
| `AggregatorAppTests/...` | Extend Article decoding test for `commentsURL` |

After implementation run `xcodegen generate` (no new files expected, but safe),
then the test gate (`bash scripts/run-tests.sh`).

## Acceptance Criteria

- [ ] `xcodebuild test` exits 0 (incl. updated Article decoding test)
- [ ] Reader toolbar has a Share action; tapping it presents the iOS share sheet with the article title + URL
- [ ] Share works in both the standalone reader (Threads/Today) and the paged reader (Sources), sharing the currently-visible article
- [ ] Article body and summary text can be selected and copied
- [ ] Text selection does not break vertical scrolling or horizontal page swiping
- [ ] A comments action is present in the reader toolbar, disabled when the article has no comments URL; when `comments_url` is provided by the API it becomes enabled and opens the comments page in the in-app Safari view
- [ ] No conditional content inside `.toolbar` (buttons use `.disabled`, not `if`)
- [ ] No hardcoded hex colors; Liquid Glass conventions preserved

## Pending Decisions

- **Comments backend dependency**: resolved — build the iOS side now (dormant);
  backend to add `comments_url` to `ArticleResponse` separately. The comments
  toolbar button stays disabled until the field is present.
- **Share contents**: resolved — share title + URL.

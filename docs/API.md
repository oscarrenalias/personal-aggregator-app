# Personal Aggregator — JSON API reference

Self-contained reference for building a **client** against the aggregator's JSON
API (mobile/iOS app, the terminal `aggregator-tui`, scripts). The API is a
read-mostly REST surface mounted at **`/api/v1`** inside the `web` service.

> For deeper architecture (services, state machine, clustering) see
> [`../CLAUDE.md`](../CLAUDE.md). This file is the client-facing contract.

## Base URL

```
https://<host>/api/v1
```

- **Self-hosted behind Cloudflare Access** (recommended public access): e.g.
  `https://aggregator-api.renaliaslabs.net/api/v1`.
- **Local / LAN**: `http://<host>:8000/api/v1` (default `http://localhost:8000/api/v1`).

## Authentication

The API itself is **unauthenticated** — it relies on the network perimeter.
For public access it is published behind **Cloudflare Access** with a
**service-token (Service Auth) policy**. Clients send the token on **every**
request as two headers:

```
CF-Access-Client-Id:     <client-id>.access
CF-Access-Client-Secret: <client-secret>
```

Cloudflare validates them at the edge; requests without valid headers get an
HTTP `403` and an HTML Cloudflare Access error page (not JSON). Create the token
in the Zero Trust dashboard under **Access → Service Auth → Service Tokens**, and
attach it to the API application via a policy whose **Action is "Service Auth"**.

Store the secret securely (iOS **Keychain**, never in source or `Info.plist`).
A single shared service token suits a personal, single-user app; for per-user
identity use Cloudflare Access OIDC via `ASWebAuthenticationSession` instead.

### iOS (URLSession) sketch

```swift
var req = URLRequest(url: URL(string: "\(baseURL)/articles?limit=20")!)
req.setValue(clientId,     forHTTPHeaderField: "CF-Access-Client-Id")
req.setValue(clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
let (data, resp) = try await URLSession.shared.data(for: req)
```

Prefer generating a typed client with
[`swift-openapi-generator`](https://github.com/apple/swift-openapi-generator)
from [`openapi.json`](./openapi.json), and inject the two headers via a transport
middleware so every request carries them.

## Response conventions

- **Pagination envelope.** Every list endpoint returns
  `{ "items": [...], "next_cursor": "<opaque-string>" | null }`.
  - `next_cursor` is an **opaque** base64 string. Pass it **verbatim** as the
    `cursor` query param to fetch the next page. `null` means no more pages.
    Never parse, construct, or compare cursors.
- **Passive reads.** `GET` endpoints never mutate state. In particular,
  `GET /threads/{id}` does **not** stamp "last viewed" / clear the unread
  indicator — that is intentional, so a client polling the API doesn't reset the
  web UI's update markers. Use the explicit write endpoints to change state.
- **Errors.** Application errors are FastAPI-style JSON: `{ "detail": "..." }`
  with the appropriate 4xx/5xx status (`404` unknown id, `422` bad params).
  A `403` with an **HTML** body is the Cloudflare Access layer, not the API —
  it means the token headers are missing/invalid.
- **Content type.** `application/json` for all API responses.
- **Version.** `info.version` in the OpenAPI doc is the package version, not the
  deployed release. For the running version call `GET /healthz`
  (`{ "version": "v0.1.43", "db": "ok" }`).

## Endpoints

### Reads

| Method & path | Purpose | Key query params |
|---|---|---|
| `GET /healthz` | Liveness + running version | — |
| `GET /articles` | List articles | `view`, `sort` (`importance`\|`recent`, default `importance`), `category`, `source_id`, `unread_only`, `limit`, `cursor` |
| `GET /articles/search` | Full-text search | `q` (required), `category`, `source_id`, `limit`, `cursor` |
| `GET /articles/{id}` | Single article | — |
| `GET /threads` | List story threads | `sort`, `show_dismissed`, `limit`, `cursor` |
| `GET /threads/{id}` | Single thread (passive) | — |
| `GET /threads/{id}/members` | Articles in a thread | — |
| `GET /brief/today` | Today's generated brief | — |
| `GET /briefs` | Paginated list of generated briefs (newest first) | `limit`, `cursor` |
| `GET /sources` | All feed sources | — |
| `GET /categories` | All categories | — |
| `GET /interest-profile` | Current interest-profile text | — |

### Writes

| Method & path | Purpose |
|---|---|
| `POST /articles/{id}/read` | Mark article read |
| `POST /articles/{id}/unread` | Mark article unread |
| `POST /articles/{id}/save` | Save article |
| `POST /articles/{id}/unsave` | Unsave article |
| `POST /threads/{id}/dismiss` | Dismiss thread |
| `POST /threads/{id}/restore` | Restore dismissed thread |

Write endpoints take no body; the resource is identified by the path. They are
**unauthenticated at the app layer** — they are protected only by the perimeter
(Cloudflare Access / Tailscale / localhost). Do not expose them publicly without
that perimeter.

### Enumerations

- **`view`** (on `GET /articles`): `all` · `unread` · `important` · `saved` ·
  `today` · `uncategorized`.
- **`sort`** (on `GET /articles` and `GET /threads`): `importance` (default) · `recent`.
  For articles, `recent` orders by `feed_published_at DESC` independent of importance score.
- **`unread_only`**, **`show_dismissed`**: boolean (`true`/`false`).
- **`limit`**: page size (server default ~50).

The exact field-level schemas for every response object live in
[`openapi.json`](./openapi.json) — treat that as the source of truth.

## Examples

All examples assume the two CF-Access headers are set (omitted for brevity).

```bash
BASE=https://aggregator-api.renaliaslabs.net/api/v1
H=(-H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET")

# Health + running version
curl -sS "${H[@]}" "$BASE/healthz"

# First page of unread articles
curl -sS "${H[@]}" "$BASE/articles?view=unread&limit=20"

# Next page (pass next_cursor verbatim)
curl -sS "${H[@]}" "$BASE/articles?view=unread&limit=20&cursor=<next_cursor>"

# Articles from one source
curl -sS "${H[@]}" "$BASE/articles?source_id=5&limit=20"

# Full-text search
curl -sS "${H[@]}" "$BASE/articles/search?q=anthropic&limit=10"

# Threads, most recent first
curl -sS "${H[@]}" "$BASE/threads?sort=recent&limit=10"

# A thread and its members
curl -sS "${H[@]}" "$BASE/threads/42"
curl -sS "${H[@]}" "$BASE/threads/42/members"

# Paginated list of briefs (newest first)
curl -sS "${H[@]}" "$BASE/briefs?limit=20"

# Next page of briefs
curl -sS "${H[@]}" "$BASE/briefs?limit=20&cursor=<next_cursor>"

# Today's brief (single-object endpoint, returns 404 if not yet generated)
curl -sS "${H[@]}" "$BASE/brief/today"

# Mark an article read / save it
curl -sS -X POST "${H[@]}" "$BASE/articles/14522/read"
curl -sS -X POST "${H[@]}" "$BASE/articles/14522/save"
```

## iOS client: Today tab

The **Today** tab displays a scrollable list of generated briefs using three
components that map onto the two brief endpoints:

| Component | File | Role |
|---|---|---|
| `TodayView` | `AggregatorApp/Today/TodayView.swift` | Root view; owns loading state, list, pagination |
| `BriefCardView` | `AggregatorApp/Today/BriefCardView.swift` | List row: date label, headline, topic count |
| `BriefDetailView` | `AggregatorApp/Today/BriefDetailView.swift` | Full brief: intro, ordered topics, source links via `SafariView` |

### Load sequence and graceful degradation

`TodayView` calls `APIClient.getBriefs(limit:cursor:)` (`GET /briefs`) on
appear and on pull-to-refresh. If the backend returns **404** (endpoint not
yet deployed), it automatically falls back to `APIClient.getTodayBrief()`
(`GET /brief/today`) and marks itself as `isFallback = true`. In fallback
mode the list contains only the current day's brief and infinite-scroll is
disabled (no cursor, no further pages).

Once the backend ships `GET /briefs`, full history appears automatically
without any app change — the app always attempts the paginated endpoint first.

```
getTodayBrief()  ← fallback, single brief, no pagination
     ↑ 404
getBriefs()      ← primary, newest-first, cursor-paginated
```

### `BriefCardView`

Renders a brief as a list row:

- **Date label** (`caption`): `"Today · <medium date>"` for the most-recent
  brief, bare `<medium date>` for older ones. Determined by comparing
  `brief.id` against the first item in the list.
- **Headline** (`headline`): `brief.headline ?? "Daily Brief"`.
- **Topic count** (`caption`): e.g. `"3 topics"`.

### `BriefDetailView`

Renders full brief content in a `ScrollView`:

- Headline (`title2 bold`), date + model caption, optional intro paragraph.
- Topics sorted by `position` ascending, each rendered by `BriefTopicView`.
- Source links open in `SafariView` (in-app sheet).
- Accepts an optional `onRefresh` closure wired to the list's pull-to-refresh
  in parent views.

### `getBriefs` — `APIClient` method

```swift
func getBriefs(cursor: String? = nil, limit: Int) async throws -> PaginatedResponse<Brief>
```

Calls `GET /briefs` with `limit` and, when non-nil, a percent-encoded
`cursor` query parameter. Returns the standard paginated envelope
(`PaginatedResponse<Brief>`). Throws `APIError.http(status: 404)` when the
endpoint does not exist on the backend; callers are expected to catch that
and fall back to `getTodayBrief()`.

## iOS client: Sources tab

The **Sources** tab (`AggregatorApp/Sources/SourcesView.swift`) presents a
three-section list: **Feeds**, **Categories**, and **Sources**. All three
sections navigate into `ArticleListView` via an `ArticleFeed` value.

### `ArticleFeed` enum

`ArticleFeed` (`AggregatorApp/Articles/ArticleFeed.swift`) is the discriminated
union that drives both navigation and query-parameter construction in
`getArticles`:

| Case | Query parameter sent |
|---|---|
| `.source(id:name:)` | `source_id=<id>` |
| `.important` | `view=important` |
| `.unread` | `view=unread` |
| `.category(name:)` | `category=<name>` |

The `category` parameter matches articles by category **name** (not id),
consistent with `GET /articles?category=<name>`. The value is percent-encoded
automatically by `URLComponents`/`URLQueryItem`. `allowsUnreadFilter` returns
`true` for `.category`, so category feeds compose with the unread filter and
sort order.

### Categories section

`SourcesView` fetches `GET /categories` concurrently with `GET /sources` on
appear and on pull-to-refresh. The **"Categories"** section appears between
"Feeds" and "Sources" when the categories array is non-empty. Each row is a
`NavigationLink` to `ArticleListView(feed: .category(name:))` and shows the
category name plus an optional freshness subtitle.

### Freshness subtitle — dormant until backend ships fields

Each category row optionally shows a freshness phrase beneath the name
(`Category.freshnessPhrase(now:)`). The logic mirrors the web sidebar:

| Backend field | Value | Phrase shown |
|---|---|---|
| `has_priority` | `true` | "New notable stories" |
| `last_activity` | today | "Updated today" |
| `last_activity` | yesterday | "Updated yesterday" |
| `last_activity` | older | "Quiet" |
| both absent | — | *(no subtitle)* |

**Current state (dormant):** `GET /categories` does not yet include
`last_activity` or `has_priority`. The `Category` model decodes both with
`decodeIfPresent`, so they arrive as `nil`/`false` on the current API — rows
display just the category name with no subtitle and no error.

**Activation path:** the backend must add `last_activity` (ISO-8601 string) and
`has_priority` (bool) to the `CategoryResponse` schema. When those fields
appear, the iOS decoder picks them up and `freshnessPhrase()` returns the
appropriate phrase automatically with no app change required.

### Load-isolation behaviour

Categories and sources load concurrently. Their error semantics differ
intentionally:

```
GET /sources      ← fatal: failure triggers the full-tab error view + Retry
GET /categories   ← non-fatal: failure hides the Categories section only
```

A flaky or absent `/categories` endpoint never blanks the whole tab. If
categories fail but sources succeed, the tab renders "Feeds" and "Sources"
sections normally. A sources failure replaces the entire tab content with an
error view.

### `getCategories` — `APIClient` method

```swift
func getCategories() async throws -> [Category]
```

Calls `GET /categories` and decodes the response as `[Category]`. Non-paginated
(the backend returns a flat array ordered by `sort_order`). Throws
`APIError.cloudflareRejected` or `APIError.http` on failure; `SourcesView`
treats any error as "show no Categories section."

### Source favicons — `FaviconLoader`

Each source row in the **Sources** section shows a 20×20 favicon resolved by
`FaviconLoader` (`AggregatorApp/Common/FaviconLoader.swift`), a Swift `actor`
with three-level caching:

```
NSCache (in-memory) → Caches/favicons/<host>.png (on-disk) → network
```

**Icon derivation.** `FaviconLoader.iconURL(forFeedURL:)` extracts the `host`
component of `Source.feedURL` and queries
`https://icons.duckduckgo.com/ip3/<host>.ico`. Each source's hostname is sent
to DuckDuckGo's public icon service on first load.

**Failure behaviour.** All errors — network failures, non-200 responses, bad
image data — are swallowed. `SourceFaviconView` falls back to the `globe` SF
Symbol when `FaviconLoader` returns `nil`.

**Concurrent deduplication.** In-flight tasks are keyed by host. Multiple
`SourceFaviconView` instances requesting the same host trigger exactly one
network request; subsequent callers await the same `Task`.

### Source activity dots — dormant until backend ships fields

`SourceActivityDot` (`AggregatorApp/Sources/SourceActivityDot.swift`) renders
an 8×8 dot to the trailing edge of each source name in the Sources list:

| `Source` field | Value | Dot |
|---|---|---|
| `has_priority` | `true` | accent-colour filled circle |
| `has_new` | `true` (and `has_priority` false) | secondary-colour filled circle |
| both false | — | *(no dot)* |

**Scope.** Activity dots appear on **source list rows only** — they are not
shown on article rows, article detail views, or any source-detail header.

**Dormancy pattern.** `GET /sources` does not yet include `has_new` or
`has_priority`. `Source` decodes both fields with `decodeIfPresent` and
defaults them to `false`, so rows show no dot and no error on the current API.
This mirrors the dormancy pattern used for `Category.has_priority` and
`last_activity` (see Freshness subtitle — dormant until backend ships fields).

**Activation path.** When the backend adds `has_new` (bool) and `has_priority`
(bool) to the `SourceResponse` schema, the iOS decoder picks them up and dots
appear automatically — no app change required.

## The OpenAPI spec

- **In this repo:** [`docs/openapi.json`](./openapi.json) — a committed snapshot,
  regenerated and attached to every GitHub release as `openapi.json` so a client
  repo can pin the contract to a release tag.
- **Live:** `GET /api/v1/openapi.json` (and Swagger UI at `/api/v1/docs`),
  reachable through Cloudflare Access with the token headers.
- **Regenerate locally:**
  ```bash
  uv run --package aggregator-api python -c \
    "import json; from aggregator_api.app import app; \
     open('docs/openapi.json','w').write(json.dumps(app.openapi(), indent=2))"
  ```

# Personal Aggregator App — Claude operating notes

iOS SwiftUI news reader app for the personal aggregator backend. Personal-use
scope, iPhone-only (`TARGETED_DEVICE_FAMILY = "1"`). Feedly-style UX: article
list, threads view, daily brief, search, sources/categories.

Backend: FastAPI service at `https://aggregator-api.renaliaslabs.net/api/v1`.
Full API contract: `docs/API.md` and `docs/openapi.json` in
[oscarrenalias/personal-aggregator](https://github.com/oscarrenalias/personal-aggregator).

## Project shape

- `AggregatorApp/` — iOS app target. SwiftUI, iOS 26+.
- `AggregatorAppTests/` — Unit test target (XCTest).
- `specs/` — spec-driven development workflow. Three lifecycle folders
  (`drafts/`, `planned/`, `done/`). Managed exclusively via the
  `skill-spec-management` skill at `.claude/skills/skill-spec-management/spec.py`
  — never `mv` spec files between folders or hand-edit frontmatter.
- `.takt/` — takt orchestration state (beads, worktrees, telemetry).

The Xcode project is **generated** by `xcodegen` from `project.yml` and
is gitignored. Run `xcodegen generate` after any change that adds or
removes source files.

## Build & test

```bash
xcodegen generate
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Same `test_command` is configured in `.takt/config.yaml` and runs as
takt's merge gate.

## Authentication

Every request to the backend requires two Cloudflare Access headers:

```
CF-Access-Client-Id:     <client-id>.access
CF-Access-Client-Secret: <client-secret>
```

Store both values in the iOS **Keychain** — never in source, `Info.plist`,
or `UserDefaults`. A 403 with an HTML body is a Cloudflare rejection, not
an API error.

## Operational rules

- **Run `xcodegen generate` after every `takt merge` to `main`.** Beads
  inside a takt run regenerate the project inside their worktree; main's
  generated `AggregatorApp.xcodeproj` does not pick up new files until
  xcodegen is rerun at the repo root. Without this, the next build fails
  with "cannot find X in scope" for newly added files.
- **Never push to `origin` without explicit user authorization.** Merge
  authorization (e.g. "merge it when done") covers the local merge only;
  the push is a separate per-action ask.
- **Never skip git hooks** (`--no-verify`, `--no-gpg-sign`) unless the
  user explicitly asks. If a pre-commit hook fails, fix the underlying
  issue and create a new commit (don't `--amend` a failed-hook commit).
- **Spec lifecycle via spec.py only.** `python3 .claude/skills/skill-spec-management/spec.py
  {create,list,show,set status,set feature-root,...}`. The skill enforces
  filesystem layout matching the `status` frontmatter field.

## UI conventions

- Standard SwiftUI controls only — no custom controls without explicit
  spec approval.
- SF Symbols for all icons; use the most semantically appropriate symbol.
- Semantic colors only (`.primary`, `.secondary`, `.accentColor`, system
  materials). Never hardcode hex values.
- System font styles only (`.body`, `.headline`, `.title3`, etc.). Respect
  Dynamic Type.
- Every primary tab wrapped in its own `NavigationStack` with a
  `.navigationTitle(...)` matching the tab label.
- Every screen that shows data must explicitly handle **Empty**, **Loading**,
  and **Error** states — these are part of the spec, not extras.
- Use `List` for collections. `LazyVStack`/`LazyVGrid` only for non-list
  scrolling layouts.
- Every interactive element needs an accessibility label. Tap targets ≥ 44×44 pt.
- iOS 26 deployment target. Use Liquid Glass UI (`Tab {}` syntax, `.glassEffect()`,
  `GlassEffectContainer`) — these are iOS 26-only APIs and that is intentional.
  Do not use APIs newer than iOS 26 without raising with the user first.

## Widget extension (AggregatorWidget)

The widget is a WidgetKit app extension with bundle identifier
`net.renalias.AggregatorApp.AggregatorWidget`.

### Shared identifiers

Both the app target and the widget extension declare identical entitlements so
they can share data:

| Capability | Identifier |
|---|---|
| App Group | `group.net.renalias.AggregatorApp` |
| Keychain Access Group | `$(AppIdentifierPrefix)net.renalias.AggregatorApp.shared` |

`$(AppIdentifierPrefix)` expands at build time to the Apple Development Team ID
(`QEZ63CXN26`) followed by a period. The resolved value is
`QEZ63CXN26.net.renalias.AggregatorApp.shared`. Both targets must use the same
string for Keychain sharing to work.

### project.yml and xcodegen

`AggregatorWidget` is defined as a separate `app-extension` target in
`project.yml`. It shares several source files from `AggregatorApp/Common/` and
`AggregatorApp/Models/` via explicit `sources` entries. Any change to
`project.yml` that touches the widget target (adding/removing sources,
entitlements, build settings) **requires `xcodegen generate` afterward** — the
same rule as any other target change. Do not add `INFOPLIST_FILE` back to the
widget target settings; `GENERATE_INFOPLIST_FILE: YES` replaced it to fix an
`AppIntentsSSUTraining` build failure.

### Widget data refresh model

`AggregatorRadarProvider` (in `AggregatorWidget/Provider.swift`) implements
`AppIntentTimelineProvider`:

- **Timeline entries**: up to 5 entries per fetch, spaced 3 minutes (180 s)
  apart — one content item (thread or article) per entry.
- **Refresh interval**: 30 minutes (`1800` s). After the last entry's date
  passes, WidgetKit calls `timeline(for:in:)` again with the `.after` policy.
- **Offline fallback**: on network failure the provider reads `LastGoodCache`
  from the App Group container (`widget_last_good_entries.json`) and builds an
  `.offline` timeline with the same 3-minute rotation and 30-minute reload
  policy.
- **Image cache**: hero images are stored in the App Group container under
  `WidgetImageCache/`. Files are keyed by `<itemId>_<w>x<h>.cache` and pruned
  on every successful timeline build to remove stale entries.
- **WidgetCenter reloads**: the main app can call
  `WidgetCenter.shared.reloadAllTimelines()` to force an immediate refresh (for
  example, after credentials are saved in Settings). The widget does not
  self-initiate out-of-band reloads beyond the `.after` policy.

### Widget configuration

The widget exposes one user-configurable parameter via `ContentSourceIntent`:

| Option | Value |
|---|---|
| Latest Threads | `ContentSource.latestThreads` — top-5 threads sorted by importance |
| Unread Important | `ContentSource.unreadImportant` — top-5 unread articles from the important feed |

### aggregator:// URL scheme

The main app registers the `aggregator` custom URL scheme
(`CFBundleURLSchemes: [aggregator]` in `Info.plist` / `project.yml`).
`DeepLinkRouter` in `AggregatorApp.swift` handles incoming URLs.

Supported paths:

| URL | Action |
|---|---|
| `aggregator://thread/{id}` | Navigate to the Threads tab and open thread `{id}` |
| `aggregator://article/{id}` | Navigate to the article detail for article `{id}` |

`{id}` is always an integer. The widget sets `deepLinkURL` on each
`WidgetEntry` so tapping the widget opens the correct item in the app.

## Networking conventions

- Inject `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers via a
  `URLSession` middleware / transport layer so every request carries them
  automatically.
- All list endpoints are cursor-paginated: `{ items: [...], next_cursor: string | null }`.
  Pass `next_cursor` verbatim as the `cursor` query param. Never parse or
  construct cursor values.
- `GET` endpoints are passive — reading an article or thread does **not**
  mark it as read. Use the explicit `POST /articles/{id}/read` write endpoint.

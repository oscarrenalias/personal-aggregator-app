# Personal Aggregator App — Claude operating notes

iOS SwiftUI news reader app for the personal aggregator backend. Personal-use
scope, iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). Feedly-style UX:
article list, threads view, daily brief, search, sources/categories.

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

## iPad layout

The app supports iPad via a three-column `NavigationSplitView`. iPhone and iPad
code paths are branch-guarded at `AppRoot.swift` using
`@Environment(\.horizontalSizeClass)`: `.regular` (iPad in landscape or
full-width split view) → `AppRootIPad`; `.compact` (iPhone, or iPad in a
narrow Split View slot) → the tab-based `TabView` UI.

### Folder structure

All iPad-specific views live under `AggregatorApp/iPad/`:

```
AggregatorApp/iPad/
├── AppRootIPad.swift           — root NavigationSplitView (sidebar + content + detail)
├── SidebarView.swift           — sidebar List driven by AppSection
├── NavigationModel.swift       — AppSection enum + iPadNavigationModel
├── Threads/ThreadsIPadView.swift
├── Today/TodayIPadView.swift
├── Podcasts/PodcastsIPadView.swift
├── Sources/SourcesIPadView.swift
├── Search/SearchIPadView.swift
└── Settings/SettingsIPadView.swift
```

### NavigationModel and AppSection

`AppSection` is a `String`-backed enum with cases `.threads`, `.sources`,
`.today`, `.podcasts`, `.search`, `.settings`.

`iPadNavigationModel` is `@Observable` and holds:

- `selectedSection: AppSection` — which section is active in the sidebar.
- One optional selected-item property per section: `selectedThread`,
  `selectedArticle`, `selectedSource`, `selectedEpisode`, `selectedFeed`,
  `selectedBrief`.

The model is instantiated at app startup in `AggregatorApp.swift` and injected
via `.environment(iPadNavModel)`. All iPad views read it via
`@Environment(iPadNavigationModel.self)`.

`DeepLinkRouter.handle(_:iPadNavModel:)` receives the model so deep links can
navigate the sidebar to the correct section as well as set a `pendingLink`.

### Orientation detection

`AppRootIPad` detects orientation by comparing `UIScreen.main.bounds.width` and
`.height` — **not** `verticalSizeClass`. `verticalSizeClass` is unreliable on
iPad because both orientations typically report `.regular`. The bounds ratio is
checked in `updateColumnVisibility()`, called on `.onAppear` and on every
`UIDevice.orientationDidChangeNotification`:

- Portrait (`width < height`) → `.doubleColumn` (sidebar hidden; content +
  detail visible)
- Landscape → `.all` (sidebar + content + detail all visible)

### Column width conventions

| Column  | min    | ideal  | max    |
|---------|--------|--------|--------|
| Sidebar | 200 pt | 220 pt | 260 pt |
| Content | 280 pt | 320 pt | 380 pt |
| Detail  | flexible (fills remaining width) | | |

### Detail column content and deep link capture

`AppRootIPad` routes each section's selected item to the detail column via
`sectionDetailContent`. When nothing is selected, a `ContentUnavailableView`
placeholder is shown:

| Section  | Selected item → detail column      | No selection placeholder            |
|----------|------------------------------------|-------------------------------------|
| Threads  | `ThreadDetailView(threadId:)`      | "Select a thread"                   |
| Today    | `BriefDetailView(brief:)`          | "Select a brief"                    |
| Podcasts | `PodcastPlayerView(episode:)`      | "Select an episode"                 |
| Sources  | `ArticleListView(feed:)`           | "Select a source"                   |
| Search   | `ArticleDetailView(articleId:)`    | "Search results"                    |
| Settings | —                                  | "Settings panel coming soon"        |

**Deep link capture**: when `router.pendingLink` arrives, `AppRootIPad` captures
it into a local `capturedDeepLink` state that takes priority over
`sectionDetailContent` in the detail column. `capturedDeepLink` clears when any
navigation model item property changes (the user makes a new selection). This
ensures a tapped widget deep link opens the correct detail regardless of the
current sidebar state.

**`SettingsIPadView` internal layout**: rather than routing Settings detail
through the `AppRootIPad` detail column, `SettingsIPadView` manages its own
orientation-aware split layout inside the content column:

- **Landscape**: `HStack` with a fixed 260 pt `GlassEffectContainer` section
  list pane + a detail pane (`NavigationStack`) that renders
  `CredentialsSettingsView` or `AboutSettingsView`.
- **Portrait**: full-width `NavigationStack` with
  `navigationDestination`-based push navigation.

The `AppRootIPad` detail column shows a static placeholder for Settings; all
Settings UI is self-contained within `SettingsIPadView` in the content column.

### TARGETED_DEVICE_FAMILY

`project.yml` sets `TARGETED_DEVICE_FAMILY: "1,2"` for the main app target
(iPhone + iPad). The widget target stays at `"1"` (iPhone only, unchanged).
After any change to `project.yml` — including adding new iPad source files —
run `xcodegen generate` to regenerate `AggregatorApp.xcodeproj`.

### Testing the iPad layout on a simulator

```bash
xcodegen generate
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=latest' -quiet
```

To exercise orientation interactively, run the app on an iPad simulator in
Xcode and use **Device → Rotate Left / Rotate Right** (⌘← / ⌘→).

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
  policy. Each `CachedEntryData` entry includes the full `WidgetContentItem`
  (thread or article), so offline entries render the item's title, source, and
  date rather than a generic placeholder. `Article` and `Thread` implement
  explicit `encode(to:)` and `init(from:)` to support this cache
  serialisation.
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

## Podcasts tab

The app has a **Podcasts** tab (4th position, `headphones` SF Symbol, value `"podcasts"`) wired up in `AppRoot.swift`. It presents `PodcastsView`, which lists episodes from the `/podcasts` endpoint; tapping an episode opens `PodcastPlayerView`.

### Audio streaming and CF-Access headers

The Cloudflare Access domain covers audio stream URLs as well as API endpoints. `AudioPlayerViewModel` injects the CF-Access credentials into the AVFoundation layer using `AVURLAssetHTTPHeaderFieldsKey`:

```swift
let asset = AVURLAsset(url: url, options: [AVURLAssetHTTPHeaderFieldsKey: headers])
```

This ensures every byte-range request AVPlayer makes to the audio URL carries the `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers. The credentials are read from `CredentialsStore` (Keychain-backed) at player initialisation — the same credentials used for API calls.

### Background audio and system transport controls

`AudioPlayerViewModel` configures `AVAudioSession` with the `.playback` category on init so audio continues when the app is backgrounded. `Info.plist` declares `UIBackgroundModes: [audio]` to enable this capability.

Now Playing metadata and lock-screen / Control Center transport controls are wired through `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`:

- **`setupNowPlaying(episode:)`** — populates `MPNowPlayingInfoCenter.default().nowPlayingInfo` with the episode title (`"Daily Podcast"`) and artist (the episode date formatted by `DateDisplay.mediumDate`).
- **`updateNowPlayingPlaybackState()`** — called on every periodic time tick, seek, and play/pause toggle; keeps `MPNowPlayingInfoPropertyElapsedPlaybackTime`, `MPNowPlayingInfoPropertyPlaybackRate`, and `MPMediaItemPropertyPlaybackDuration` in sync.
- **`setupRemoteCommands()`** — registers handlers on `MPRemoteCommandCenter` for `togglePlayPauseCommand`, `playCommand`, `pauseCommand`, and `changePlaybackPositionCommand` (scrub bar).
- **Cleanup** — `deinit` removes all `MPRemoteCommandCenter` targets and clears `nowPlayingInfo` to avoid stale lock-screen state after the player is dismissed.

### Podcasts v1 out-of-scope items

The following items are intentionally deferred to a future iteration:

- **Offline episode caching** — episodes are not downloaded for offline playback.
- **Episode script / transcript view** — the API returns a `script` field but it is not rendered in v1.

## Networking conventions

- Inject `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers via a
  `URLSession` middleware / transport layer so every request carries them
  automatically. For audio streams, inject the same headers via
  `AVURLAssetHTTPHeaderFieldsKey` (see Podcasts tab section above).
- All list endpoints are cursor-paginated: `{ items: [...], next_cursor: string | null }`.
  Pass `next_cursor` verbatim as the `cursor` query param. Never parse or
  construct cursor values.
- `GET` endpoints are passive — reading an article or thread does **not**
  mark it as read. Use the explicit `POST /articles/{id}/read` write endpoint.

## DateDisplay.parseISO8601

`DateDisplay.parseISO8601` attempts three passes in order:

1. **Fractional-second ISO-8601** (`withInternetDateTime | withFractionalSeconds`) — handles timestamps like `2026-06-17T04:41:10.929002+00:00`.
2. **Whole-second ISO-8601** (`withInternetDateTime`) — handles `2026-06-17T04:41:10+00:00`.
3. **Date-only** (`yyyy-MM-dd`, `en_US_POSIX` locale) — handles podcast episode date strings like `2024-01-15` that contain no time component.

All three callers (`relative`, `mediumDate`, `monthDay`) share this single parser, so podcast episode dates render correctly in all display contexts.

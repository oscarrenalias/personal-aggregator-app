---
name: "Podcasts tab: browse and play daily podcast episodes"
id: spec-9b2d2357
description: "New Podcasts tab: cursor-paginated episode list with calendar badges, plus an AVPlayer-based audio player with scrubbing and 1×/1.5×/2× speed control. CF-Access headers injected into AVURLAsset for authenticated audio streaming."
dependencies: null
priority: medium
complexity: medium
status: planned
tags:
- podcasts
- audio
- avfoundation
- tab
scope:
  in: null
  out: null
feature_root_id: null
---
# Podcasts tab: browse and play daily podcast episodes

## Objective

Add a Podcasts tab to the app that lets the user browse daily auto-generated
podcast episodes and play them with a native-feeling audio player (play/pause,
scrubbing, 1×/1.5×/2× speed). Episodes have no cover art, so a calendar badge
(matching the Today tab) is used instead. The `episode_theme` field is null
today but will hold a content summary in the near future — the UI is built to
display it when present.

## Context

- New tab, no existing code to migrate.
- Backend: `GET /podcasts` (cursor-paginated list) and `GET /podcasts/{id}`
  (single episode). The episode model carries an `audio_url` direct URL to the
  audio file.
- The backend is behind Cloudflare Access — CF-Access headers must be injected
  on every request including the audio stream, via `AVURLAsset` options.
- Reuse: `APIClient`, `PaginatedResponse<T>`, `DateDisplay`, `LoadOnceGate`,
  `GlassEffectContainer`, `ParagraphText`, `CredentialsStore`.
- Calendar badge: copy the `calendarBadge` ViewBuilder pattern from
  `BriefCardView` verbatim, sourcing from `episode.date`.
- `DateDisplay.parseISO8601` currently handles full ISO-8601 datetimes only.
  `episode.date` is a date-only string (`"2024-01-15"`); a fallback parser must
  be added so `monthDay`, `mediumDate`, and `relative` all work.
- xcodegen: `AggregatorApp` target uses `sources: - path: AggregatorApp`
  recursively, so new files under `AggregatorApp/Podcasts/` and
  `AggregatorApp/Models/PodcastEpisode.swift` are auto-included. Run
  `xcodegen generate` after adding files.

### Verified API shape

`GET /podcasts?limit=20&cursor=<cursor>` → `PaginatedResponse[PodcastEpisodeResponse]`:
- Paginated, same cursor pattern as threads/articles: pass `next_cursor`
  verbatim as the `cursor` query param. Never parse or construct cursor values.

`GET /podcasts/{id}` → `PodcastEpisodeResponse`:
```json
{
  "id": 42,
  "date": "2024-01-15",
  "episode_theme": null,
  "status": "completed",
  "duration_seconds": 1234,
  "audio_url": "https://...",
  "segment_count": 8,
  "llm_model": "gpt-4o",
  "tts_model": "tts-1",
  "tts_voice": "alloy",
  "generated_at": "2024-01-15T06:00:00Z",
  "created_at": "2024-01-15T05:55:00Z"
}
```

`episode_theme`: null now; will contain a content summary string in the future.
`duration_seconds`: nullable — AVPlayer reports real duration on `.readyToPlay`.
`audio_url`: string URL; requires CF-Access headers (same Cloudflare domain).

## Changes

### 1. DateDisplay fallback — `AggregatorApp/Common/DateDisplay.swift`

Add a date-only fallback in the private `parseISO8601` method (after the two
existing `ISO8601DateFormatter` attempts):

```swift
let dateOnly = DateFormatter()
dateOnly.dateFormat = "yyyy-MM-dd"
dateOnly.locale = Locale(identifier: "en_US_POSIX")
if let date = dateOnly.date(from: iso) { return date }
return nil
```

Existing callers (full datetimes like `"2026-06-17T04:41:10.929002+00:00"`)
hit the first two passes and are unaffected. After this change,
`DateDisplay.monthDay("2024-01-15")` returns `("JAN", "15")`.

### 2. Model — `AggregatorApp/Models/PodcastEpisode.swift`

New file. Follow the same `Codable, Identifiable` pattern as `Brief.swift`:
explicit `CodingKeys` for snake_case, `decodeIfPresent` for all optional
fields, ISO-8601 date strings (never `Date`).

```swift
struct PodcastEpisode: Codable, Identifiable {
    let id: Int
    let date: String            // date-only: "2024-01-15"
    let episodeTheme: String?   // null now; content summary in the future
    let status: String
    let durationSeconds: Int?
    let audioUrl: String
    let segmentCount: Int
    let llmModel: String?
    let ttsModel: String?
    let ttsVoice: String?
    let generatedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, status
        case episodeTheme    = "episode_theme"
        case durationSeconds = "duration_seconds"
        case audioUrl        = "audio_url"
        case segmentCount    = "segment_count"
        case llmModel        = "llm_model"
        case ttsModel        = "tts_model"
        case ttsVoice        = "tts_voice"
        case generatedAt     = "generated_at"
        case createdAt       = "created_at"
    }
}
```

Use explicit `init(from decoder: Decoder)` (matching the pattern in
`Brief.swift`) so all optional fields use `decodeIfPresent`.

### 3. APIClient — `AggregatorApp/Common/APIClient.swift`

Add three methods after `getBriefs`:

```swift
func getPodcasts(cursor: String? = nil, limit: Int = 20) async throws -> PaginatedResponse<PodcastEpisode> {
    var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
    return try await get("/podcasts", query: query)
}

func getPodcastEpisode(id: Int) async throws -> PodcastEpisode {
    return try await get("/podcasts/\(id)")
}

func getLatestPodcastEpisode() async throws -> PodcastEpisode {
    return try await get("/podcasts/latest")
}
```

CF-Access headers are injected automatically by the existing `get(_:query:)`.

### 4. AudioPlayerViewModel — `AggregatorApp/Podcasts/AudioPlayerViewModel.swift`

`@Observable final class`. Manages all `AVFoundation` state so the view stays
declarative. Credentials passed explicitly (not via `@Environment`) because
`@State` initialisation happens before the environment is available.

**Init**: `init(episode: PodcastEpisode, store: CredentialsStore)`

Implementation steps:
1. Configure `AVAudioSession.sharedInstance()` with `.playback` category and
   activate it — enables audio over the silent switch and background playback.
2. Build CF-Access headers:
   `["CF-Access-Client-Id": store.clientId, "CF-Access-Client-Secret": store.clientSecret]`
3. Guard `URL(string: episode.audioUrl)` — if nil, set `playerError = true`
   and return early; the view shows an error state.
4. `AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])`
5. `AVPlayerItem(asset:)` → `AVPlayer(playerItem:)`
6. Set `player.defaultRate = playbackSpeed`
7. KVO on `item.status` → when `.readyToPlay`, capture real duration from
   `CMTimeGetSeconds(item.duration)` on the main queue.
8. Periodic time observer (0.5 s interval, `queue: .main`) → update
   `currentTime` unless `isSeeking`.
9. `AVPlayerItem.didPlayToEndTimeNotification` observer → set `isPlaying = false`,
   seek to `.zero`, reset `currentTime = 0`.

**Observable properties** (all `private(set)` except `isSeeking` and
`playbackSpeed`):
- `isPlaying: Bool = false`
- `currentTime: Double = 0`
- `duration: Double = 0`
- `playbackSpeed: Float = 1.0`
- `isSeeking: Bool = false`
- `playerError: Bool = false`

**Public methods**:
- `func togglePlayPause()` — call `player?.pause()` or `player?.play()`;
  toggle `isPlaying`
- `func seek(to seconds: Double)` — `player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))`; set `isSeeking = false`; set `currentTime = seconds`
- `func setSpeed(_ speed: Float)` — set `playbackSpeed = speed`;
  `player?.defaultRate = speed`; if `isPlaying`, also `player?.rate = speed`

**`deinit`**: remove time observer, invalidate KVO observation, remove
notification observer.

### 5. PodcastEpisodeRowView — `AggregatorApp/Podcasts/PodcastEpisodeRowView.swift`

Mirrors `BriefCardView` layout: leading content VStack + trailing calendar badge.

Calendar badge: copy the `calendarBadge` ViewBuilder from `BriefCardView`
exactly (month abbrev in `.red`, large day number, `RoundedRectangle` background),
sourcing from `DateDisplay.monthDay(episode.date)`.

Layout:
- Meta line: `DateDisplay.mediumDate(episode.date)` · duration formatted as
  `M:SS` (when `durationSeconds != nil`) · `"\(segmentCount) segment(s)"` —
  `.font(.caption).foregroundStyle(.secondary)`
- Title: `"Daily Podcast"` — `.font(.headline).lineLimit(2)` — episodes are
  identified by date, not by a headline
- Theme line (only when `episode.episodeTheme != nil`):
  `.font(.subheadline).foregroundStyle(.secondary).lineLimit(2)` — content
  summary preview
- `.listRowBackground(Color.clear)`
- Accessibility label combining "Daily Podcast", date, and duration

### 6. PodcastPlayerView — `AggregatorApp/Podcasts/PodcastPlayerView.swift`

Receives `episode: PodcastEpisode` and `credentialsStore: CredentialsStore`.
Initialises `AudioPlayerViewModel` as `@State` using `State(wrappedValue:)` in
the custom `init` so the player is ready on first render.

```swift
import SwiftUI
import AVFoundation

struct PodcastPlayerView: View {
    let episode: PodcastEpisode
    @State private var viewModel: AudioPlayerViewModel

    init(episode: PodcastEpisode, credentialsStore: CredentialsStore) {
        _viewModel = State(wrappedValue: AudioPlayerViewModel(episode: episode, store: credentialsStore))
    }
    ...
}
```

If `viewModel.playerError` is true, show:
`ContentUnavailableView("Cannot play episode", systemImage: "exclamationmark.triangle")`

Otherwise, `ScrollView > VStack(spacing: 24)`, horizontal padding via
`ReaderLayout.hPadding`:

1. **Calendar badge** — centred, sourced from `episode.date`. Use the same
   `calendarBadge` ViewBuilder pattern; wrap in a `.frame(maxWidth: .infinity)`
   so it centres horizontally.
2. **Title**: `Text("Daily Podcast")` — `.font(.title2.bold()).multilineTextAlignment(.center)`
3. **Date/meta**: `DateDisplay.mediumDate(episode.date)` · segment count —
   `.font(.caption).foregroundStyle(.secondary)`
4. **Episode theme** (only when `episode.episodeTheme != nil`): full text via
   `ParagraphText(episode.episodeTheme!)` — this is where the content summary
   will appear once the backend starts populating the field. Do not show if nil.
5. **Scrubber**:
   ```swift
   Slider(
       value: Binding(
           get: { viewModel.currentTime },
           set: { viewModel.currentTime = $0; viewModel.isSeeking = true }
       ),
       in: 0...max(viewModel.duration, 1)
   )
   .onEditingChanged { editing in
       if !editing { viewModel.seek(to: viewModel.currentTime) }
       else { viewModel.isSeeking = true }
   }
   ```
   Setting `viewModel.currentTime` in the `set` closure is safe because
   `isSeeking = true` prevents the periodic timer from overriding it while
   the user drags. On release the slider calls `seek(to:)` which resets
   `isSeeking = false`.
6. **Time labels** HStack (spaceBetween): `Text(formatTime(viewModel.currentTime))` left,
   `Text(formatTime(viewModel.duration))` right — `.font(.caption).foregroundStyle(.secondary)`
7. **Play/pause button** (centred):
   ```swift
   Button { viewModel.togglePlayPause() } label: {
       Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
           .font(.system(size: 64))
   }
   .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
   ```
8. **Speed picker**:
   ```swift
   Picker("Speed", selection: Binding(
       get: { viewModel.playbackSpeed },
       set: { viewModel.setSpeed($0) }
   )) {
       Text("1×").tag(Float(1.0))
       Text("1.5×").tag(Float(1.5))
       Text("2×").tag(Float(2.0))
   }
   .pickerStyle(.segmented)
   ```

Private helper (file-scope):
```swift
private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}
```

`.navigationTitle("Episode").navigationBarTitleDisplayMode(.inline)`

### 7. PodcastsView — `AggregatorApp/Podcasts/PodcastsView.swift`

Mirrors `ThreadsView` / `TodayView` closely.

```swift
private enum LoadPhase { case loading, loaded, error(Error) }

struct PodcastsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var episodes: [PodcastEpisode] = []
    @State private var nextCursor: String? = nil
    @State private var phase: LoadPhase = .loading
    @State private var isFetchingNextPage: Bool = false
    @State private var loadGate = LoadOnceGate()

    private var apiClient: APIClient { APIClient(store: credentialsStore) }
    ...
}
```

`body`: `NavigationStack` wrapping a `Group` switching on `phase`:
- `.loading` → `ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)`
- `.error(let e)` → error VStack with message + "Retry" button calling
  `Task { await loadFirstPage() }`
- `.loaded`:
  - If `!credentialsStore.isConfigured` →
    `ContentUnavailableView("Not configured", systemImage: "gearshape", description: Text("Enter your server credentials in Settings."))`
  - If `episodes.isEmpty` →
    `ContentUnavailableView("No episodes", systemImage: "headphones")`
  - Else → `GlassEffectContainer { List { ForEach ... } .listStyle(.plain) }` with
    `.refreshable { await loadFirstPage(showSpinner: false) }`

Each `ForEach` row:
```swift
NavigationLink {
    PodcastPlayerView(episode: ep, credentialsStore: credentialsStore)
} label: {
    PodcastEpisodeRowView(episode: ep)
}
.listRowBackground(Color.clear)
.onAppear {
    if ep.id == episodes.last?.id { Task { await loadNextPage() } }
}
```

`loadFirstPage(showSpinner: Bool = true)`:
- Optionally set `phase = .loading`; reset cursor and episodes array
- Call `apiClient.getPodcasts(limit: 20)`; on success update `episodes`,
  `nextCursor`, `phase = .loaded`
- On cancellation: ignore (use `isCancellation` helper)
- On other error: `phase = .error(e)`

`loadNextPage()`:
- Guard `!isFetchingNextPage && nextCursor != nil`
- Append results; update `nextCursor`; silent failure on next-page errors

`.task { guard credentialsStore.isConfigured, loadGate.shouldLoad() else { return }; await loadFirstPage() }`

`.navigationTitle("Podcasts")`

### 8. AppRoot tab — `AggregatorApp/AppRoot.swift`

Add one `Tab` between `"today"` and `"settings"`:

```swift
Tab("Podcasts", systemImage: "headphones", value: "podcasts") {
    PodcastsView()
}
```

No additional environment objects needed — `CredentialsStore` is already
injected at the app root and flows down via `@Environment`.

## Files to Create / Modify

| File | Change |
|---|---|
| `AggregatorApp/Common/DateDisplay.swift` | Add date-only fallback in `parseISO8601` |
| `AggregatorApp/Models/PodcastEpisode.swift` | New model |
| `AggregatorApp/Common/APIClient.swift` | Add `getPodcasts`, `getPodcastEpisode`, `getLatestPodcastEpisode` |
| `AggregatorApp/Podcasts/AudioPlayerViewModel.swift` | New `@Observable` AVPlayer wrapper |
| `AggregatorApp/Podcasts/PodcastEpisodeRowView.swift` | New list row view |
| `AggregatorApp/Podcasts/PodcastPlayerView.swift` | New player detail view |
| `AggregatorApp/Podcasts/PodcastsView.swift` | New list view |
| `AggregatorApp/AppRoot.swift` | Add Podcasts tab |

After adding files, run `xcodegen generate`, then:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [ ] `xcodegen generate` succeeds; `xcodebuild test` exits 0
- [ ] "Podcasts" tab with `headphones` icon appears in the Liquid Glass tab bar
- [ ] With no credentials configured, the Podcasts tab shows the "Not configured" state
- [ ] Episode list renders with calendar badge, meta line (date · duration · segments), and "Daily Podcast" title
- [ ] `episode_theme` shown as subtitle in the row and as body text in the player when non-null; absent when null (no empty space)
- [ ] Tapping a row pushes `PodcastPlayerView`; back returns to list at same position
- [ ] Play/pause button starts and stops audio; progress advances in real time
- [ ] Scrubbing: dragging the slider does not fight the periodic timer; releasing seeks to the correct position
- [ ] Speed: 1×/1.5×/2× segmented picker changes rate immediately when playing; respects speed on resume after pause
- [ ] End-of-episode: player resets to 0:00 and shows play button
- [ ] Pagination: scrolling to the last row triggers the next page; no double-fire
- [ ] Pull-to-refresh reloads page 1 without a spinner flash
- [ ] CF-Access headers present on both `/podcasts` list requests and the audio URL
- [ ] No hardcoded hex colors; semantic colors and system fonts throughout
- [ ] No AVFoundation-related crashes on devices/simulators with iOS 26

## Pending Decisions

- **`episode_theme` as title**: resolved — `episode_theme` is a content summary,
  not an episode title. Episode title is always "Daily Podcast"; the theme is
  shown as body/description text.
- **Audio URL auth**: resolved — always inject CF-Access headers via
  `AVURLAssetHTTPHeaderFieldsKey`, even if the URL proves to be a CDN URL.
  Safe default with no downside.
- **Unit tests**: no new unit tests are specified for this spec. The acceptance
  criteria are verified via Simulator build+run. If model decoding tests are
  desired, add `PodcastEpisodeModelTests.swift` analogous to existing model
  test files.
- **Out of scope (v1)**: background audio session management beyond
  `.playback` category (e.g. Now Playing info, remote controls via
  `MPNowPlayingInfoCenter`); offline episode caching; episode script view.

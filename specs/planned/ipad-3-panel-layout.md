---
name: iPad 3-Panel Layout
id: spec-ba28ac41
description: "Add iPadOS support with a fully separate 3-panel NavigationSplitView layout, leaving iPhone views untouched."
dependencies: null
priority: medium
complexity: high
status: planned
tags:
- ipad
- navigation
- layout
scope:
  in: "|"
  out: "|"
feature_root_id: B-6ca3d410
---
# iPad 3-Panel Layout

## Objective

Add iPadOS support to the app. The iPhone layout (all existing views) is left completely untouched. A separate `AggregatorApp/iPad/` folder contains parallel iPad-specific views built on `NavigationSplitView`. Shared non-UI code (models, networking, ViewModels where already extracted) is reused as-is.

## Problems to Fix

The app is currently iPhone-only (`TARGETED_DEVICE_FAMILY = "1"`). No iPad layout exists.

## Architecture

### Folder structure

```
AggregatorApp/
  AppRoot.swift                    ← add one horizontalSizeClass branch (minimal edit)
  iPad/                            ← new, all additive
    AppRootIPad.swift              ← NavigationSplitView root + columnVisibility logic
    SidebarView.swift              ← section selector (replaces tab bar on iPad)
    Threads/ThreadsIPadView.swift
    Sources/SourcesIPadView.swift
    Today/TodayIPadView.swift
    Podcasts/PodcastsIPadView.swift
    Search/SearchIPadView.swift
    Settings/SettingsIPadView.swift
```

Existing view files in `Threads/`, `Sources/`, `Today/`, `Podcasts/`, `Search/`, `Settings/` are **not modified**.

### Shared non-UI code (reused directly)

- `Models/` — all model types, unchanged
- `Common/` — networking, `CredentialsStore`, `DateDisplay`, etc., unchanged
- ViewModels — reused via `@StateObject` in iPad views **if** they contain no `NavigationPath`/`NavigationStack`-specific state (see Task 1)
- Row/card component views (e.g. `ThreadRowView`, `ArticleRowView`) — reused if they exist as separate files with no navigation logic embedded

### Navigation model

A new `NavigationModel.swift` (in `iPad/`) holds:

```swift
@Observable final class iPadNavigationModel {
    var selectedSection: AppSection = .threads
    var selectedThread: Thread?
    var selectedArticle: Article?
    var selectedSource: Source?
    var selectedEpisode: Episode?
}
```

`AppSection` is an enum matching the 6 tabs: `.threads`, `.sources`, `.today`, `.podcasts`, `.search`, `.settings`.

### Orientation / column visibility

```swift
// in AppRootIPad
@State private var columnVisibility: NavigationSplitViewVisibility = .all
@Environment(\.verticalSizeClass) var vSizeClass

.onChange(of: vSizeClass) { _, new in
    columnVisibility = orientationIsPortrait ? .doubleColumn : .all
}
```

Portrait detection: use the screen's bounds ratio (`UIScreen.main.bounds.width < UIScreen.main.bounds.height`) or `UIDevice.current.orientation` observed via `UIDevice.orientationDidChangeNotification`. `verticalSizeClass` alone is unreliable on iPad (always `.regular`); use screen bounds ratio as the primary signal.

### Column widths (landscape)

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView(...)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
} content: {
    ItemListView(...)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
} detail: {
    DetailView(...)   // flexible, takes remainder (~55% on 11" landscape)
}
```

### Portrait behaviour (2-column)

When portrait is detected, `columnVisibility` is set to `.doubleColumn`. The content (supplementary) column is hidden. The detail column starts by rendering the section's item list; tapping an item pushes the detail view within the detail column's implicit `NavigationStack`.

Each iPad feature view must handle both states:
- **Landscape**: list selection drives `iPadNavigationModel.selectedXxx`; detail column reacts
- **Portrait**: list is rendered inside the detail column; item tap pushes detail view

### AppRoot changes (minimal)

```swift
// AppRoot.swift — only addition
@Environment(\.horizontalSizeClass) var hSizeClass

// inside body:
if hSizeClass == .regular {
    AppRootIPad()
} else {
    // existing TabView content, unchanged
}
```

### Deep link routing

`DeepLinkRouter` in `AggregatorApp.swift` currently calls `selectedTab = "threads"`. On iPad it must instead set `iPadNavigationModel.selectedSection = .threads` and `iPadNavigationModel.selectedThread = ...`. The router needs to detect which root is active and dispatch accordingly. `iPadNavigationModel` should be injected as an `@Environment` object at the app level so `DeepLinkRouter` can reach it.

## Tasks

### Task 1 — ViewModel audit (prerequisite)

Before writing any iPad views, read each feature folder's Swift files and answer:

1. Does a `ViewModel`/`ObservableObject`/`@Observable` class exist separate from the view?
2. Does it hold any `NavigationPath` or `NavigationStack`-specific state?
3. Are there row/card component views (e.g. `ThreadRowView`) defined as separate structs?

Produce a short table: feature → ViewModel reusable? → row components reusable?

### Task 2 — project.yml + AppRoot branch

- Change `TARGETED_DEVICE_FAMILY` to `"1,2"` in `project.yml`
- Add `AggregatorApp/iPad/` sources block to the `AggregatorApp` target
- Add the `horizontalSizeClass` branch to `AppRoot.swift`
- Run `xcodegen generate` and confirm the project builds

### Task 3 — NavigationModel + AppRootIPad + SidebarView

- Create `AggregatorApp/iPad/NavigationModel.swift`
- Create `AggregatorApp/iPad/AppRootIPad.swift` with `NavigationSplitView`, `columnVisibility` logic, and orientation detection
- Create `AggregatorApp/iPad/SidebarView.swift` — a `List` of `AppSection` cases with SF Symbol labels matching the existing tab icons
- Inject `iPadNavigationModel` into the environment at app root

### Task 4 — ThreadsIPadView

3-column landscape: sidebar selects section → content column shows thread list (driven by `selectedThread` binding) → detail column shows `ThreadDetailView` / `ArticleDetailView`.

Portrait: detail column renders thread list; tap pushes thread detail.

### Task 5 — SourcesIPadView

3-column landscape: source list in content column; article list or source detail in detail column.

Portrait: source list in detail column; tap pushes source detail / article list.

### Task 6 — TodayIPadView

3-column landscape: brief section list in content column; `BriefDetailView` / `ArticleDetailView` in detail column.

Portrait: brief section list in detail column; tap pushes detail.

### Task 7 — PodcastsIPadView

2-column layout (sidebar + episode list / player). No supplementary column needed — episode list in content column, player in detail column. Portrait collapses to episode list in detail column; tap pushes player.

### Task 8 — SearchIPadView + SettingsIPadView

Search: search bar + results list in content column; article detail in detail column.

Settings: `SettingsIPadView` is self-contained in the content column. It manages
its own orientation-aware split layout — in landscape an `HStack` with a 260 pt
`GlassEffectContainer` section list + a `NavigationStack` detail pane
(`CredentialsSettingsView` / `AboutSettingsView`); in portrait a full-width
`NavigationStack` with `navigationDestination`-based push navigation. The
`AppRootIPad` detail column shows a static placeholder for Settings and is not
used by this section.

### Task 9 — Deep link routing

Update `DeepLinkRouter` to detect active navigation model and dispatch to `iPadNavigationModel` on iPad or existing `selectedTab` logic on iPhone.

### Task 10 — QA pass

- Rotate device/simulator between portrait and landscape; confirm column visibility transitions correctly
- Tap a widget deep link; confirm correct section and item open on iPad
- Confirm all 6 sections render and navigate correctly in both orientations
- Confirm iPhone layout is completely unchanged

## Files to Modify

| File | Change |
|---|---|
| `project.yml` | `TARGETED_DEVICE_FAMILY: "1,2"`, add `AggregatorApp/iPad/` sources |
| `AggregatorApp/AppRoot.swift` | Add `horizontalSizeClass` branch |
| `AggregatorApp/AggregatorApp.swift` | Update `DeepLinkRouter` for iPad navigation model |

All other changes are new files under `AggregatorApp/iPad/`.

## Acceptance Criteria

- App installs and launches on an iPad simulator without crashing
- Landscape shows all 3 columns; portrait shows 2 columns; rotating live transitions correctly
- All 6 sections are reachable via the sidebar on iPad
- Tapping any item in the content column opens its detail in the detail column (landscape) or pushes it (portrait)
- `aggregator://thread/{id}` and `aggregator://article/{id}` deep links open the correct item on iPad
- All existing iPhone tests pass without modification
- iPhone layout is pixel-identical to before this change


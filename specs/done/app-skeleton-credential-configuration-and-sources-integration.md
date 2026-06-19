---
name: "App skeleton, credential configuration, and sources integration"
id: spec-3da083df
description: "Four-tab Liquid Glass shell (Threads/Sources/Today/Settings), Keychain-backed CF Access credentials, working Sources list, and iOS 26 UI conventions."
dependencies: null
priority: high
complexity: medium
status: done
tags:
- skeleton
- settings
- networking
- sources
scope:
  in: "App entry point, tab shell (Threads/Sources/Today stubs + Settings), credential/endpoint storage, API client, Sources list tab, xcodegen project generation, unit test target, iOS 26 Liquid Glass UI"
  out: "Article list, threads view, daily brief content, search, read/unread state, pagination"
feature_root_id: B-6f152256
---
# App skeleton, credential configuration, and sources integration

## Objective

Create a runnable iOS app from a clean repository: generate the Xcode project,
stand up a four-tab Liquid Glass shell, implement a Settings screen where the
user can enter their Cloudflare Access credentials and backend URL, a dedicated
Sources tab listing all configured feeds, and stub views for the two remaining
tabs (Threads, Today).

## Context

- Backend base URL: `https://aggregator-api.renaliaslabs.net/api/v1`
- Authentication: two CF Access headers on every request —
  `CF-Access-Client-Id` and `CF-Access-Client-Secret`
- OpenAPI contract: `docs/openapi.json` in oscarrenalias/personal-aggregator
- `project.yml` (iOS 26, `TARGETED_DEVICE_FAMILY = "1"`) and `.takt/config.yaml`
  are already committed; the Xcode project must be regenerated with
  `xcodegen generate` before building

## Liquid Glass conventions

This app targets iOS 26. All UI must follow the Liquid Glass design language:

- **Tab bar**: Use the new `Tab { }` initialiser (iOS 26). The system renders
  the tab bar automatically as a floating glass pill — no extra modifiers needed.
- **`.glassEffect()`**: Apply to card-style containers, header backgrounds, and
  any custom surface that should read as glass. Do not use opaque backgrounds
  that fight the glass layer.
- **`GlassEffectContainer`**: Wrap multiple adjacent glass-effect views so they
  share a single unified backing surface.
- **Navigation bars**: Rendered with glass material automatically in iOS 26 when
  inside a `NavigationStack`. Do not set a custom background.
- **`Form` / `List`**: Use `.listStyle(.insetGrouped)` (the default for `Form`);
  iOS 26 renders inset-grouped lists with glass insets automatically.
- **Colors**: Semantic only — `.primary`, `.secondary`, `.tint`,
  `Color(.systemGroupedBackground)`. Never hardcode hex values.
- **Materials**: When a surface needs a background, use `.regularMaterial`,
  `.thickMaterial`, or `.ultraThinMaterial` — these participate in the Liquid
  Glass layering model.

## Changes

### 1. Source directory scaffolding

Create the directory structure (files listed below; `xcodegen generate` then
produces `AggregatorApp.xcodeproj`):

```
AggregatorApp/
  AggregatorApp.swift
  AppRoot.swift
  Assets.xcassets/
    Contents.json
    AppIcon.appiconset/Contents.json
  Common/
    APIClient.swift
    CredentialsStore.swift
    KeychainHelper.swift
  Models/
    Source.swift
    HealthResponse.swift
  Threads/
    ThreadsView.swift
  Sources/
    SourcesView.swift
  Today/
    TodayView.swift
  Settings/
    SettingsView.swift

AggregatorAppTests/
  AggregatorAppTests.swift
```

### 2. App entry point — `AggregatorApp.swift`

```swift
@main
struct AggregatorApp: App {
    @State private var credentialsStore = CredentialsStore()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(credentialsStore)
        }
    }
}
```

### 3. Tab shell — `AppRoot.swift`

`TabView` using the iOS 26 `Tab { }` initialiser. Tab order:

| # | Label | SF Symbol | View |
|---|-------|-----------|------|
| 0 | Threads | `bubble.left.and.bubble.right` | `ThreadsView` (stub) |
| 1 | Sources | `antenna.radiowaves.left.and.right` | `SourcesView` |
| 2 | Today | `sparkles` | `TodayView` (stub) |
| 3 | Settings | `gearshape` | `SettingsView` |

Default selected tab: Threads (tab 0).

Every tab owns its own `NavigationStack` with `.navigationTitle(…)` matching
the tab label. Stub tabs (Threads, Today) show a centered
`ContentUnavailableView` with the tab name as title and "Coming soon" as
subtitle — nothing more.

The tab bar inherits the Liquid Glass floating-pill treatment automatically from
the iOS 26 runtime; no `.tabViewStyle` override is needed unless the system
default is insufficient.

### 4. Credential storage — `CredentialsStore.swift` + `KeychainHelper.swift`

`CredentialsStore` is an `@Observable final class` that owns all connectivity
state. Inject it into the environment from `AggregatorApp`.

**Properties (all `String`, `""` when unset):**

| Property | Storage | Default |
|----------|---------|---------|
| `baseURL` | `UserDefaults` key `aggregator.baseURL` | `"https://aggregator-api.renaliaslabs.net/api/v1"` |
| `clientId` | Keychain, key `aggregator.clientId` | `""` |
| `clientSecret` | Keychain, key `aggregator.clientSecret` | `""` |

**Computed property:**
- `isConfigured: Bool` — `true` when all three are non-empty

`KeychainHelper` is a simple struct with two static methods:
- `static func read(key: String) -> String?`
- `static func write(key: String, value: String)` — uses `kSecClassGenericPassword`

`CredentialsStore` reads all values at init time. Property `didSet` observers
persist changes immediately (synchronous Keychain writes are fine at this scale).

### 5. API client — `APIClient.swift`

```swift
struct APIClient {
    let store: CredentialsStore

    func get<T: Decodable>(_ path: String) async throws -> T
    func post(_ path: String) async throws
}
```

- `get` builds `URLRequest` from `store.baseURL + path`, injects both CF
  Access headers, performs `URLSession.shared.data(for:)`, decodes with
  `JSONDecoder()`.
- `post` same but HTTP method `POST`, no body, response ignored.
- Throws `URLError` on network failure; `DecodingError` on bad JSON.
- No pagination in this spec — cursor support added in later specs.

Concrete methods:

```swift
func getSources() async throws -> [Source]
func healthCheck() async throws -> HealthResponse
```

### 6. Models — `Source.swift`, `HealthResponse.swift`

```swift
struct Source: Codable, Identifiable {
    let id: Int
    let name: String
    let feedURL: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case feedURL = "feed_url"
    }
}

struct HealthResponse: Codable {
    let version: String
    let db: String
}
```

### 7. Sources tab — `SourcesView.swift`

Fetches `GET /sources` on appear via `APIClient`. States:

- **Loading**: `ProgressView()` centred in the view
- **Empty**: `ContentUnavailableView("No sources", systemImage: "antenna.radiowaves.left.and.right")`
- **Error**: error message + "Retry" button centred in the view
- **Loaded**: `List` of sources; each row:
  - Primary text: `source.name` (`.body`)
  - Secondary text: `source.feedURL` (`.caption`, `.secondary` color)
  - List rows use `.listRowBackground(Color.clear)` so the glass inset
    material shows through

Wrap the list in a `GlassEffectContainer` so all rows share a single glass
backing surface. The `NavigationStack` title is "Sources".

When `credentialsStore.isConfigured` is `false`, show
`ContentUnavailableView("Not configured", systemImage: "gearshape", description: Text("Enter your server credentials in Settings."))`
instead of attempting a fetch.

### 8. Settings screen — `SettingsView.swift`

A standard `Form` (renders as inset-grouped list with Liquid Glass insets on
iOS 26) with two sections:

**Section "Server"**
- `TextField("Base URL", text: $credentialsStore.baseURL)` — `.keyboardType(.URL)`, `.autocorrectionDisabled()`
- Button "Test Connection" — calls `healthCheck()`; shows inline status below
  the button:
  - Success: `Label("Connected · v{version}", systemImage: "checkmark.circle.fill")` tinted `.green`
  - Failure: `Label("{error}", systemImage: "exclamationmark.triangle.fill")` tinted `.red`
  - In-flight: `ProgressView()` inline

**Section "Cloudflare Access"**
- `TextField("Client ID", text: $credentialsStore.clientId)` — `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`
- `SecureField("Client Secret", text: $credentialsStore.clientSecret)`

No "Save" button — fields persist on change via `CredentialsStore` property observers.

### 9. Unit tests — `AggregatorAppTests.swift`

Three tests, no network calls:

1. **`testCredentialsStoreDefaults`** — fresh `CredentialsStore` has
   `baseURL == "https://aggregator-api.renaliaslabs.net/api/v1"`,
   `clientId == ""`, `clientSecret == ""`, `isConfigured == false`.

2. **`testCredentialsStoreIsConfigured`** — set all three to non-empty strings;
   assert `isConfigured == true`.

3. **`testSourceDecodingFromJSON`** — decode
   `{"id":1,"name":"Test Feed","feed_url":"https://example.com/feed.xml"}`
   into `Source`; assert id, name, and feedURL match.

Tests must not write to the real Keychain or `UserDefaults`. Use a dedicated
test initialiser on `CredentialsStore` that accepts in-memory backing stores, or
dependency-inject the storage backends.

## Files to Create

| File | Purpose |
|------|---------|
| `AggregatorApp/AggregatorApp.swift` | `@main` App entry point |
| `AggregatorApp/AppRoot.swift` | `TabView` shell (Threads/Sources/Today/Settings) |
| `AggregatorApp/Assets.xcassets/…` | Minimal asset catalogue (AppIcon placeholder) |
| `AggregatorApp/Common/APIClient.swift` | HTTP client with CF header injection |
| `AggregatorApp/Common/CredentialsStore.swift` | `@Observable` credential + URL store |
| `AggregatorApp/Common/KeychainHelper.swift` | Keychain read/write wrapper |
| `AggregatorApp/Models/Source.swift` | `Source` model |
| `AggregatorApp/Models/HealthResponse.swift` | `HealthResponse` model |
| `AggregatorApp/Threads/ThreadsView.swift` | Stub tab view |
| `AggregatorApp/Sources/SourcesView.swift` | Live Sources list with Liquid Glass rows |
| `AggregatorApp/Today/TodayView.swift` | Stub tab view |
| `AggregatorApp/Settings/SettingsView.swift` | Credentials form (Server + CF Access) |
| `AggregatorAppTests/AggregatorAppTests.swift` | Unit tests |

After creating all files, run `xcodegen generate` to produce
`AggregatorApp.xcodeproj`, then verify:

```bash
xcodebuild test -project AggregatorApp.xcodeproj -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

## Acceptance Criteria

- [ ] `xcodegen generate` succeeds with no warnings about missing source paths
- [ ] `xcodebuild test` exits 0; all three unit tests pass
- [ ] App launches in the simulator showing a Liquid Glass floating tab bar with tabs: Threads, Sources, Today, Settings (in that order)
- [ ] Threads and Today tabs show their stub `ContentUnavailableView` with "Coming soon"
- [ ] Settings tab shows Base URL pre-filled to `https://aggregator-api.renaliaslabs.net/api/v1`
- [ ] Entering valid credentials and tapping "Test Connection" shows the success label with version
- [ ] Sources tab with no credentials shows the "Not configured" `ContentUnavailableView`
- [ ] Sources tab with valid credentials shows the list of sources with glass row backgrounds
- [ ] Modifying any field in Settings persists across app restarts (Keychain / UserDefaults)
- [ ] No credentials are stored in source files, `Info.plist`, or `UserDefaults` (Client ID/Secret use Keychain only)
- [ ] `CredentialsStore` unit tests run without touching the real Keychain

## Pending Decisions

- **App icon**: placeholder is fine for this spec; final icon is out of scope
- **Orientation**: portrait-only as set in `project.yml`

# MRTDeepLinkSDK

A lightweight iOS CocoaPod for deep linking, install attribution, and event analytics — built for the [DeepLinkHub](https://github.com/mindrootstech/MRTDeepLinkSDK) platform.

**Current version: `0.5.3`**

## What this SDK does

| Feature | Description |
|---------|-------------|
| **Deep linking** | Universal Links + custom URL schemes |
| **License gate** | API key validation — invalid key disables link handling |
| **Remote config** | Domains, schemes, and bundle ID from your admin server |
| **Deferred deep links** | Match pre-install link clicks on first launch (Branch-style) |
| **Unique install tracking** | Register installs with a stable `device_id` |
| **Keychain device ID** | `device_id` stored in iOS Keychain — may survive reinstall |
| **Event analytics** | `track()`, `identify()`, auto session events |
| **Offline event queue** | Failed events saved locally and flushed when online |
| **API retry** | All network calls retry up to 3× on network / 5xx errors |
| **Smart link builder** | Generate shareable HTTPS URLs from the app |
| **SwiftUI + UIKit** | `.handleMRTDeepLinks` modifier, SceneDelegate helpers |

## SDK lifecycle (what happens on launch)

```
App launch
    ↓
MRTDeepLink.shared.configure(apiKey:)
    ↓
License API validate  ──→  invalid? deep links disabled
    ↓ valid
Remote config loaded (domains, schemes)
    ↓
Analytics + session tracking start
    ↓
Unique install API  ──→  POST /api/sdk/unique-install  (once per install)
    ↓
Deferred install API  ──→  POST /api/sdk/install  (once per install, if no direct link)
    ↓
Matched?  →  onDeepLink(payload) with isDeferred: true
    ↓
App running  →  track() events sent to server (queued offline if network fails)
```

## Requirements

- iOS 15.0+
- Swift 5.0+
- CocoaPods

## Installation

Add to your app's `Podfile`:

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  # Local development
  pod 'MRTDeepLinkSDK', :path => '../MRTDeepLinkSDK'

  # From Git
  pod 'MRTDeepLinkSDK', :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => '0.5.3'
end
```

Then run:

```bash
pod install
```

> **Important:** Open `YourApp.xcworkspace`, not `.xcodeproj`.

---

## Quick Start

### 1. Configure at app launch

```swift
import MRTDeepLinkSDK

MRTDeepLink.shared.configure(
    apiKey: "mrt_live_your_unique_key",
    debugLogging: true   // set false in production
)

MRTDeepLink.shared.onLicenseStatusChange { status in
    switch status {
    case .valid:
        print("License active — deep linking enabled")
    case .invalid(let message):
        print("License invalid:", message)
    case .validating:
        print("Checking license…")
    case .idle:
        break
    }
}
```

The SDK automatically:
- Sends your app's **Bundle ID** to the admin server
- Validates the **API key** (`GET /api/sdk/validate`)
- Downloads **domains**, **URL scheme**, and **app settings** from the server
- Reports **unique install** and checks **deferred deep links** on first launch
- Starts **analytics** and **session tracking**

You do **not** need to manually set domains or schemes in the app.

| Property | Description |
|----------|-------------|
| `apiKey` | Unique key from the admin panel (required) |
| `debugLogging` | Print debug logs to Xcode console (default `false`) |
| `licenseServerURL` | Admin server URL (optional, has SDK default) |

### 2. Handle deep links

```swift
MRTDeepLink.shared.onDeepLink { payload in
  print("URL:", payload.url.absoluteString)
  print("Path:", payload.path)
  print("Params:", payload.queryParameters)
  print("Source:", payload.source)       // universalLink | customScheme | deferred
  print("Deferred:", payload.isDeferred) // true if matched pre-install click
}
```

### 3. SwiftUI integration

```swift
ContentView()
    .handleMRTDeepLinks { payload in
        // same handler as onDeepLink
    }
```

Wires up automatically:
- `.onOpenURL` for custom URL schemes
- `.onContinueUserActivity` for Universal Links
- Pending link delivery if handler registers after cold start

### 4. UIKit / AppDelegate

```swift
func application(_ app: UIApplication, open url: URL, options: ...) -> Bool {
    MRTDeepLink.shared.handle(url: url)
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity, ...) -> Bool {
    MRTDeepLink.shared.handle(userActivity: userActivity)
}
```

### 5. UIKit / SceneDelegate

```swift
import MRTDeepLinkSDK

func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    MRTDeepLinkSceneSupport.handle(connectionOptions: connectionOptions)
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    MRTDeepLinkSceneSupport.handle(urlContexts: URLContexts)
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    MRTDeepLinkSceneSupport.handle(userActivity: userActivity)
}
```

### 6. Universal Links setup

1. Xcode → **Signing & Capabilities** → **Associated Domains**
2. Add:
   ```
   applinks:links.yourdomain.com
   applinks:links.yourdomain.com?mode=developer
   ```
   (`?mode=developer` required for debug builds.)
3. Host AASA at `https://links.yourdomain.com/.well-known/apple-app-site-association`
4. Serve with `Content-Type: application/json` (no `.json` extension).

### 7. Custom URL scheme (Info.plist)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>
```

---

## Smart Links

Generate shareable HTTPS URLs from the app:

```swift
let config = MRTSmartLinkConfiguration(
    webDomain: "links.yourdomain.com",
    customURLScheme: "yourapp",
    iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id123456789")!
)

let shareURL = MRTSmartLinkBuilder.makeWebURL(
    path: "/product/42",
    queryItems: [URLQueryItem(name: "id", value: "abc")],
    configuration: config
)
// → https://links.yourdomain.com/product/42?id=abc
```

Create links from the **DeepLinkHub console** (`/links`) for short URLs, click tracking, and deferred attribution.

---

## Deferred Deep Links

On first launch, the SDK calls your server to match a pre-install link click:

```
POST {server}/api/sdk/install?bundleId={bundleId}
Authorization: Bearer {apiKey}
```

**Request body:**

```json
{
  "deviceId": "A5E3-BF88-1092",
  "platform": "ios",
  "os": "iOS",
  "osVersion": "17.4",
  "appVersion": "1.0.0 (1)",
  "userAgent": "Mozilla/5.0 (iPhone; ...) MRTDeepLinkSDK",
  "language": "en-US"
}
```

**Response (match found):**

```json
{
  "success": true,
  "data": {
    "installId": "...",
    "isAttributed": true,
    "matchConfidence": 0.85,
    "confidenceLevel": "high",
    "attribution": {
      "url": "https://links.yourdomain.com/product/42",
      "path": "/product/42",
      "queryParameters": { "id": "abc" }
    }
  }
}
```

When `isAttributed` is `true`, the SDK delivers an `MRTDeepLinkPayload` with `isDeferred: true` through `onDeepLink`.

**Rules:**
- Called once per install, after license is valid
- Skipped if a direct deep link was received in the same session
- Retried automatically on network failure (up to 3 attempts)

**Auto analytics events:**
- `deferred_link_matched` — attribution found
- `deferred_link_no_match` — no matching click

---

## Unique Install Tracking

Registers each device with a stable `device_id`:

```
POST {server}/api/sdk/unique-install?bundleId={bundleId}
Authorization: Bearer {apiKey}
```

**Request body:**

```json
{
  "device_id": "A5E3-BF88-1092",
  "platform": "ios",
  "os_version": "17.4"
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "installId": "6a38c404171682bbacd2ccd2",
    "isNew": true,
    "uniqueCounted": true,
    "message": "Unique app install registered successfully."
  }
}
```

### Keychain `device_id`

The `device_id` is stored in the **iOS Keychain** (not UserDefaults):
- May survive app reinstall on the same physical device
- Legacy UserDefaults IDs are migrated automatically on first read
- No extra permissions required
- Server dedupes on `(bundleId, device_id)` — `isNew: false` on duplicate

**Auto analytics event:** `unique_install_registered` (when `isNew: true`)

---

## Event Analytics

Configured automatically when you call `MRTDeepLink.shared.configure(...)`.

```swift
MRTAnalytics.shared.identify(userId: "user_98765")

MRTAnalytics.shared.track(
    eventName: "button_click",
    properties: [
        "buttonName": "Submit",
        "screen": "Home"
    ]
)
```

### Events API

```
POST {server}/api/sdk/events?bundleId={bundleId}
Authorization: Bearer {apiKey}
```

```json
{
  "eventName": "button_click",
  "anonymousId": "anon_abc123",
  "userId": "user_device_xyz",
  "loginUserId": "user_98765",
  "sessionId": "sess_abc123",
  "properties": { "buttonName": "Submit", "screen": "Home" }
}
```

| Field | Description |
|-------|-------------|
| `eventName` | Required event name |
| `anonymousId` | Auto-generated, stable per install (`anon_...`) |
| `userId` | Auto-generated device user ID (`user_...`) — not replaced by `identify()` |
| `loginUserId` | Set by `identify(userId:)` |
| `sessionId` | Active session ID, auto-attached |
| `properties` | Optional string key-value pairs |

### Auto session tracking

| Event | When |
|-------|------|
| `session_started` | App launch or return after 30+ min background |
| `session_ended` | App enters background (`durationSeconds` in properties) |

Resume within 30 minutes keeps the same `sessionId`.

### Offline event queue

If an event fails to send (network error, 5xx):
1. Event is saved locally (up to **100** events)
2. Queue is flushed when:
   - Analytics is configured
   - App returns to foreground
   - A later event sends successfully

Client errors (`401`, `403`, `400`) are **not** queued.

---

## Network Reliability

All SDK API calls use automatic retry:

| Setting | Value |
|---------|-------|
| Max attempts | 3 |
| Initial delay | 0.5 seconds |
| Backoff | Exponential (0.5s → 1s → 2s) |

**Retried on:** network errors, HTTP `408`, `429`, `5xx`  
**Not retried on:** `400`, `401`, `403`, `404`, `422`

Applies to: license validation, events, unique-install, deferred install.

---

## License API

```
GET {server}/api/sdk/validate?key={apiKey}&bundleId={bundleId}
Authorization: Bearer {apiKey}
```

```json
{
  "valid": true,
  "config": {
    "appIdentifier": "com.yourcompany.app",
    "universalLinkDomains": ["links.yourdomain.com"],
    "customURLSchemes": ["yourapp"]
  }
}
```

If `valid` is not `true`, deep link handling is disabled.

---

## API Reference

### `MRTDeepLink`

| Method / Property | Description |
|-------------------|-------------|
| `configure(apiKey:debugLogging:)` | Initialize SDK, validate license, start analytics |
| `validateLicense()` | Re-check license with server |
| `onLicenseStatusChange(_:)` | Observe license status |
| `isLicenseValid` | Whether license is active |
| `onDeepLink(_:)` | Register deep link handler |
| `handle(url:)` | Handle URL manually |
| `handle(userActivity:)` | Handle Universal Link |
| `consumePendingDeepLink()` | Get link received before handler was set |

### `MRTDeepLinkPayload`

| Property | Description |
|----------|-------------|
| `url` | Original URL |
| `path` | Normalized path (e.g. `/product/42`) |
| `pathComponents` | Path segments |
| `queryParameters` | Query string dictionary |
| `source` | `.universalLink`, `.customScheme`, `.deferred`, `.unknown` |
| `isDeferred` | `true` if from pre-install attribution match |
| `receivedAt` | Timestamp when link was received |

### `MRTAnalytics`

| Method / Property | Description |
|-------------------|-------------|
| `configure(...)` | Standalone analytics init |
| `track(eventName:properties:)` | Log an event |
| `identify(userId:)` | Set `loginUserId` (device `userId` unchanged) |
| `setAnonymousId(_:)` | Override anonymous ID |
| `resetUser()` | Clear linked login user |
| `currentUserId` | Stable device user ID |
| `currentAnonymousId` | Stable anonymous ID |
| `currentLoginUserId` | Linked login user |
| `currentSessionId` | Active session ID |

### SwiftUI

| Modifier | Description |
|----------|-------------|
| `handleMRTDeepLinks(_:)` | Auto-wire deep link handling on a view |

---

## Multi-app setup (same domain)

Use unique path prefixes per app in AASA:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      { "appID": "TEAM_ID.com.app.NotifyTest", "paths": ["/notifytest", "/notifytest/*"] },
      { "appID": "TEAM_ID.com.app.3DLive",    "paths": ["/3dlive", "/3dlive/*"] }
    ]
  }
}
```

**Do not** use `"paths": ["*"]` with multiple apps on the same domain.

---

## Changelog

| Version | Highlights |
|---------|------------|
| **0.5.3** | API retry (3× backoff), offline event queue (100 events) |
| **0.5.2** | Keychain-based `device_id` (survives reinstall) |
| **0.5.1** | Deferred deep links + unique install tracking |
| **0.5.0** | Install attribution API |
| **0.4.0** | Gated debug logging, session tracking, masked auth headers |
| **0.3.x** | Analytics, auth headers, stable userId / anonymousId |

---

## Troubleshooting

### Link opens Safari instead of app
- Tap from **Notes / Messages / WhatsApp** — not Safari address bar
- Reinstall app after adding Associated Domains
- Confirm AASA is live
- Wire **SceneDelegate** handlers for Storyboard apps

### Deferred link not received
- Uninstall app first (clean install test)
- Tap link **before** installing (from Notes/Messages)
- Install within match window (check server config)
- Check console: `Install reported — attributed: true`

### Unique install count wrong
- Server must dedupe on `(bundleId, device_id)`
- Keychain ID may change after factory reset

### Events missing
- Check offline queue — events flush on foreground
- Enable `debugLogging: true` to see retry / queue logs

### CocoaPods build errors
Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in Podfile `post_install`.

---

## Publishing

```bash
cd MRTDeepLinkSDK
pod lib lint MRTDeepLinkSDK.podspec --allow-warnings
git tag 0.5.3
git push origin main
git push origin 0.5.3
```

## License

MIT

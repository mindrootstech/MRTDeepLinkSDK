# CliqIt

iOS SDK for **deferred deep linking** — attributes a SmartLink web click to the first app open, then routes the user to the matched in-app path.

**Version:** `2.0.3` · **iOS 15+** · **Swift 5**

---

## Features

| Feature | Description |
|---------|-------------|
| Deferred match | `POST /api/v1/sdk/app/match` with native signals + WebView fingerprint |
| Verify | `POST /api/v1/sdk/verify` — API key + bundle identity on configure |
| Universal Links | Handles `https://<domain>/…` when the app is installed |
| Direct link lookup | `GET /api/v1/sdk/link/{slug}` → destination path |
| Custom URL scheme | Optional `yourapp://…` links |
| SwiftUI helper | `.handleCliqItLinkReceived { … }` |
| Smart link builder | Build shareable web / custom-scheme URLs |

This SDK is **deferred-only**. Analytics, license validation, and install APIs are not included.

---

## Installation

### CocoaPods (local / source)

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'CliqIt', :path => '../CliqIt'
end
```

```bash
# Prefer source when developing against this repo
CLIQIT_SDK_SOURCE=1 pod install
```

Open `YourApp.xcworkspace`, not `.xcodeproj`.

### CocoaPods (git — binary)

```ruby
pod 'CliqIt',
    :git => 'https://github.com/mindrootstech/CliqIt.git',
    :tag => '2.0.3'
```

### Swift Package Manager

```swift
.package(path: "../CliqIt")
```

---

## Domains

| Role | Host |
|------|------|
| API / match server | `api.theblockyapp.com` (fixed in SDK) |
| Universal Links / SmartLinks | **Your domain from the admin panel** (per app / tenant) |

SDK match calls always go to the API host. The link domain users tap is the one you create/configure in admin — not hardcoded in the SDK.

Only `*.theblockyapp.com` (and exact `theblockyapp.com`) https hosts are accepted for `handle(url:)` unless you pass a custom domain via internal config.

---

## App setup

### 1. Associated Domains

Use the **SmartLink / Universal Link domain shown in your admin panel**.

```
applinks:<your-admin-panel-domain>
```

### 2. Custom URL scheme (optional)

`Info.plist` → URL Types — only if you use custom-scheme links.

### 3. AASA on the link domain

`https://<your-admin-panel-domain>/.well-known/apple-app-site-association`

---

## Quick start

Register listeners **before** `configure` where possible — deferred match can finish very fast.

### SwiftUI

```swift
import CliqIt
import SwiftUI

@main
struct MyApp: App {
    init() {
        CliqItSDK.shared.onLinkReceived { payload in
            if let err = payload.errorMessage { print("error", err, payload.status) }
            else if payload.shouldNavigate { print(payload.path) }
        }

        CliqItSDK.shared.configure(apiKey: "pk_live_…")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handleCliqItLinkReceived { payload in
                    print(payload.path, payload.isDeferred)
                }
        }
    }
}
```

### UIKit (Swift) — SceneDelegate

```swift
import UIKit
import CliqIt

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    CliqItSDK.shared.onLinkReceived { payload in
        print(payload.status, payload.path, payload.isDeferred)
    }
    CliqItSDK.shared.configure(apiKey: "pk_live_…")
    return true
}

func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    CliqItSceneSupport.handle(connectionOptions: connectionOptions)
}
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    _ = CliqItSceneSupport.handle(userActivity: userActivity)
}
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    CliqItSceneSupport.handle(urlContexts: URLContexts)
}
```

```swift
_ = CliqItSDK.shared.handle(url: url)
_ = CliqItSDK.shared.handle(userActivity: userActivity)
```

---

## When each callback runs

| API | When it runs |
|-----|----------------|
| `onLinkReceived` | **Only public callback** — direct opens, deferred outcomes, and verify/lookup **errors**. |
| `configure(apiKey:)` | Call once at launch. Starts **verify** + **deferred match** in background. |
| `handle(url:)` | Pass Universal Links / custom schemes (slug lookup runs in background). |
| `onVerify` / `onDirectLinkLookup` / `onDeferredMatch` | **Deprecated** — use `onLinkReceived`. |

---

## Callback results (what you get)

### `onLinkReceived` → `CliqItPayload` (direct + deferred)

| Property | Type | Notes |
|----------|------|--------|
| `url` | `URL` | Original or synthetic URL |
| `path` | `String` | In-app path to open (empty when nothing to navigate) |
| `pathComponents` | `[String]` | Path segments |
| `queryParameters` | `[String: String]` | Query map |
| `source` | `CliqItSource` | `.universalLink` / `.customScheme` / `.deferred` / `.unknown` |
| `isDeferred` | `Bool` | `true` for deferred match outcomes |
| `status` | `CliqItLinkStatus` | `opened` \| `matched` \| `notMatched` \| `failed` \| `verifyFailed` \| `lookupFailed` \| `alreadyReported` |
| `matched` | `Bool?` | Deferred only; `nil` for direct `opened` |
| `destinationPath` | `String?` | Server destination when known |
| `slug` / `tier` / `confidence` / `score` | optional | Deferred attribution fields |
| `errorMessage` | `String?` | When status is a failure (`failed` / `verifyFailed` / `lookupFailed`) — RN/Flutter key: `error` |
| `shouldNavigate` | `Bool` | `path` non-empty and status is `opened`, `matched`, or `lookupFailed` |
| `receivedAt` | `Date` | Receive time |

Navigate when `payload.shouldNavigate` (or check `status` + `path`).

**Integrators only need `onLinkReceived`.** Verify, slug lookup, and deferred match run in the background; successes for verify are silent; failures and link/match outcomes arrive on this callback.

**React Native / Flutter:** wrap as `{ result, error }` — top-level `error` is set for failure statuses.

### `onVerify` → `CliqItVerifyOutcome`

| Case | Notes |
|------|--------|
| `.passed(CliqItVerifyResult)` | `ok: true` |
| `.mismatched(CliqItVerifyResult)` | Wrong key / bundle — see `checks` / `mismatchMessage` |
| `.error(…)` | Network / decode |

`CliqItVerifyResult`: `ok`, `appId`, `appName`, `checks` (`bundleId` → `{ actual, expected, match }`).

### `onDirectLinkLookup` → `Result<CliqItLinkDetails, …>`

Use `CliqItLinkField` keys, e.g. `details[.resolvedPath]` (`iosDestination ?? destination`).

| Field (`CliqItLinkField`) | Notes |
|---------------------------|--------|
| `.resolvedPath` | Navigation path for iOS |
| `.destination` / `.iosDestination` / `.androidDestination` | Raw destinations |
| `.slug` | Link slug |
| `.ogTitle` / `.ogDescription` / `.ogImage` / `.ogUrl` | Open Graph |
| `.webFallback` | Web fallback |
| `.showInterstitial` / `.isDeepLink` | Flags |
| `.appleTeamId` / `.iosBundleId` / `.androidPackageName` | App identity metadata |

---

## Lifecycle

```
App launch
    └─ configure(apiKey:)
         ├─ POST /api/v1/sdk/verify     → onVerify
         └─ POST /api/v1/sdk/app/match  → onLinkReceived(status: matched|notMatched|failed)

Universal Link / custom scheme
    └─ handle(url:)
         ├─ GET /api/v1/sdk/link/{slug} → onDirectLinkLookup (if slug)
         └─ onLinkReceived(status: opened)
```

Deferred match is persisted only after a **real match** (`matched == true`).

---

## Deferred match API

### Request

`POST {serverURL}/api/v1/sdk/app/match`  
Header: `x-api-key`

Body includes `platform`, `bundleId`, device signals, and WebView fingerprint fields (`canvasHash`, `webglHash`, `gpuRenderer`, `audioFingerprint`, `clockSkewMs`, …).

### Response

```json
{
  "matched": true,
  "tier": "probabilistic",
  "confidence": "high",
  "score": 96.27,
  "destinationPath": "/product/1",
  "slug": "summer-sale"
}
```

| `tier` | Meaning |
|--------|---------|
| `deterministic_session` | Session id from link |
| `probabilistic` | Fingerprint match |
| `button` / `manual` | Ambiguous / no match |

---

## Smart link builder

```swift
let config = CliqItSmartLinkConfiguration(
    webDomain: "theblockyapp.com",
    customURLScheme: "mrtdeeplink",
    iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id…")!
)
CliqItSmartLinkBuilder.makeWebURL(path: "/product/42", configuration: config)
CliqItSmartLinkBuilder.makeAppURL(path: "/product/42", scheme: "mrtdeeplink")
```

---

## Testing Universal Links

1. Install a build with correct Team ID + bundle id.
2. Do **not** paste the URL into Safari’s address bar.
3. Open from Notes / Messages, or long-press → **Open in …**.
4. Confirm AASA is reachable.

---

## Requirements

- iOS 15.0+
- Xcode 15+
- Associated Domains (admin panel domain)
- Valid SDK API key from SmartLink admin

## React Native

See [react-native-cliqit](https://github.com/mindrootstech/react-native-cliqit) (`v2.0.6+`) for the RN bridge + result tables.

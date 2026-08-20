# CliqIt

iOS SDK for **deferred deep linking** — attributes a SmartLink web click to the first app open, then routes the user to the matched in-app path.

**Version:** `2.0.2` · **iOS 15+** · **Swift 5**

---

## Features

| Feature | Description |
|---------|-------------|
| Deferred match | `POST /api/v1/sdk/app/match` with native signals + `/fp-probe` fingerprint |
| Universal Links | Handles `https://<domain>/…` when the app is installed |
| Custom URL scheme | Optional `yourapp://…` links |
| SwiftUI helper | `.handleCliqItDeepLinks { … }` |
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

### CocoaPods (git)

```ruby
pod 'CliqIt',
    :git => 'https://github.com/mindrootstech/CliqIt.git',
    :tag => '2.0.2'
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

---

## App setup

### 1. Associated Domains

Use the **SmartLink / Universal Link domain shown in your admin panel** (not a fixed MindRoots domain).

In Xcode → Signing & Capabilities → Associated Domains:

```
applinks:<your-admin-panel-domain>
```

Example if admin shows `devajaysorg.theblockyapp.com`:

```
applinks:devajaysorg.theblockyapp.com
```

Or in entitlements:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:YOUR_ADMIN_PANEL_DOMAIN</string>
</array>
```

### 2. Custom URL scheme (optional)

`Info.plist` → URL Types — only if you use custom-scheme links.

### 3. AASA on the link domain

Your admin / SmartLink host serves AASA at:

`https://<your-admin-panel-domain>/.well-known/apple-app-site-association`

It must include your Apple Team ID + app bundle id. Follow the domain and AASA values from the admin panel.
---

## Quick start

Works with **SwiftUI** and **UIKit (Swift)**. Always call `configure(apiKey:)` at launch.

### SwiftUI

```swift
import CliqIt
import SwiftUI

@main
struct MyApp: App {
    init() {
        CliqItSDK.shared.configure(apiKey: "pk_live_…")
        // Match API always hits https://api.theblockyapp.com (built into SDK)

        CliqItSDK.shared.onDeferredMatch { outcome in
            switch outcome {
            case .matched(let info):
                // Navigate using info.destinationPath / info.slug
                break
            case .notMatched, .failed:
                break
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handleCliqItDeepLinks { payload in
                    // Universal Link / custom scheme
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

// AppDelegate
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    CliqItSDK.shared.configure(apiKey: "pk_live_…")

    CliqItSDK.shared.onDeepLink { payload in
        // Navigate (deferred or direct)
        print(payload.path, payload.isDeferred)
    }

    CliqItSDK.shared.onDeferredMatch { outcome in
        switch outcome {
        case .matched(let info):
            print(info.destinationPath ?? "")
        case .notMatched, .failed:
            break
        }
    }
    return true
}

// SceneDelegate
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

### UIKit — manual handlers

```swift
_ = CliqItSDK.shared.handle(url: url)
_ = CliqItSDK.shared.handle(userActivity: userActivity)
```

---

## Lifecycle
```
App launch
    └─ configure(…)
         └─ first launch only → POST /api/v1/sdk/app/match
              ├─ matched + destinationPath → onDeepLink(isDeferred: true)
              └─ no match → organic launch

Universal Link / custom scheme open
    └─ handle(url:) / .handleCliqItDeepLinks
         └─ onDeepLink(payload)
```

Deferred match runs **once per install** (guarded by `UserDefaults`).

---

## Deferred match API

### Request

`POST {serverURL}/api/v1/sdk/app/match`

Auth header: `x-api-key: {apiKey}`

Body includes native signals (`osVersionMajor`, `deviceName`, `locale`, `timezone`, `screenBucket`, …) and optional `/fp-probe` fields (`canvasHash`, `gpuRenderer`, `audioFingerprint`, …). If a Universal Link carried `?session=` / `clickSessionId`, that UUID is sent as `clickSessionId`.
`deviceName` is the hardware model id (e.g. `iPhone15,2`).

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
| `deterministic_session` | Session id from Universal Link |
| `probabilistic` | Fingerprint match |
| `button` / `manual` | Ambiguous / no match (`matched: false`) |

### Inspect from the app

```swift
CliqItSDK.shared.onDeferredMatchDebug { result in
    switch result {
    case .success(let match):
        print(match.matched, match.tier ?? "-", match.destinationPath ?? "-")
    case .failure(let error):
        print(error.localizedDescription)
    }
}

// Manual re-run (e.g. debug UI)
CliqItSDK.shared.runDeferredMatchDebug(clickSessionId: "optional-uuid")
```

---

## Payload

```swift
public struct CliqItPayload {
    public let url: URL
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let source: CliqItSource   // .universalLink | .customScheme | .deferred
    public let isDeferred: Bool
}
```

---

## Smart link builder

```swift
let config = CliqItSmartLinkConfiguration(
    webDomain: "theblockyapp.com",
    customURLScheme: "mrtdeeplink",
    iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id…")!
)

// https://theblockyapp.com/product/42
CliqItSmartLinkBuilder.makeWebURL(path: "/product/42", configuration: config)

// mrtdeeplink://product/42
CliqItSmartLinkBuilder.makeAppURL(path: "/product/42", scheme: "mrtdeeplink")
```

---

## Testing Universal Links

1. Install a build signed with the correct Team ID + bundle id.
2. Do **not** paste the URL into Safari’s address bar (often stays in Safari).
3. Open the link from Notes / Messages, or long-press → **Open in …**.
4. Confirm AASA is reachable and Apple’s CDN has cached it.

---

## Requirements

- iOS 15.0+
- Xcode 15+
- Associated Domains capability (domain from your admin panel)
- Valid SDK API key from your SmartLink admin

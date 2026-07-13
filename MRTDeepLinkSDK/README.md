# MRTDeepLinkSDK

iOS SDK for **deferred deep linking** — attributes a SmartLink web click to the first app open, then routes the user to the matched in-app path.

**Version:** `0.6.0` · **iOS 15+** · **Swift 5**

---

## Features

| Feature | Description |
|---------|-------------|
| Deferred match | `POST /api/deferred/app/match` with native signals + `/fp-probe` fingerprint |
| Universal Links | Handles `https://<domain>/…` when the app is installed |
| Custom URL scheme | Optional `yourapp://…` links |
| SwiftUI helper | `.handleMRTDeepLinks { … }` |
| Smart link builder | Build shareable web / custom-scheme URLs |

This SDK is **deferred-only**. Analytics, license validation, and install APIs are not included.

---

## Installation

### CocoaPods (local / source)

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'MRTDeepLinkSDK', :path => '../MRTDeepLinkSDK'
end
```

```bash
# Prefer source when developing against this repo
MRT_SDK_SOURCE=1 pod install
```

Open `YourApp.xcworkspace`, not `.xcodeproj`.

### CocoaPods (git)

```ruby
pod 'MRTDeepLinkSDK', :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => '0.6.0'
```

### Swift Package Manager

```swift
.package(path: "../MRTDeepLinkSDK")
```

---

## Domains

| Role | Host |
|------|------|
| API / match server | `apismartlink.digitalplayground.quest` |
| Universal Links / SmartLinks | `appsmartlink.digitalplayground.quest` |

These must stay distinct: entitlements claim the **app** host; match calls go to the **API** host.

---

## App setup

### 1. Associated Domains

In Xcode → Signing & Capabilities → Associated Domains:

```
applinks:appsmartlink.digitalplayground.quest
```

Or in entitlements:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:appsmartlink.digitalplayground.quest</string>
</array>
```

### 2. Custom URL scheme (optional)

`Info.plist` → URL Types, e.g. `mrtdeeplink`.

### 3. AASA on the link domain

Hosted at:

`https://appsmartlink.digitalplayground.quest/.well-known/apple-app-site-association`

Example:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.testapp.mindroots",
        "paths": ["/r/*", "/l/*"]
      }
    ]
  }
}
```

`appID` = `{Apple Team ID}.{bundle id}`.

---

## Quick start

```swift
import MRTDeepLinkSDK
import SwiftUI

@main
struct MyApp: App {
    init() {
        MRTDeepLink.shared.configure(
            apiKey: "dlh_sdk_…",
            debugLogging: true,
            serverURL: URL(string: "https://apismartlink.digitalplayground.quest")!,
            universalLinkDomain: "appsmartlink.digitalplayground.quest",
            customURLScheme: "mrtdeeplink"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handleMRTDeepLinks { payload in
                    // Navigate using payload.path / pathComponents
                    print(payload.url, payload.isDeferred)
                }
        }
    }
}
```

### UIKit

```swift
// SceneDelegate / AppDelegate
_ = MRTDeepLink.shared.handle(url: url)
_ = MRTDeepLink.shared.handle(userActivity: userActivity)

// Or helpers:
MRTDeepLinkSceneSupport.handle(connecting: connectionOptions, in: scene)
MRTDeepLinkSceneSupport.handle(userActivity: userActivity)
```

---

## Lifecycle

```
App launch
    └─ configure(…)
         └─ first launch only → POST /api/deferred/app/match
              ├─ matched + destinationPath → onDeepLink(isDeferred: true)
              └─ no match → organic launch

Universal Link / custom scheme open
    └─ handle(url:) / .handleMRTDeepLinks
         └─ onDeepLink(payload)
```

Deferred match runs **once per install** (guarded by `UserDefaults`).

---

## Deferred match API

### Request

`POST {serverURL}/api/deferred/app/match`

Auth headers: `X-SDK-Key`, `Authorization: Bearer {apiKey}`

Body includes native signals (`osVersionMajor`, `locale`, `timezone`, `screenBucket`, …) and optional `/fp-probe` fields (`canvasHash`, `gpuRenderer`, `audioFingerprint`, …). If a Universal Link carried `?session=` / `clickSessionId`, that UUID is sent as `clickSessionId`.

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
MRTDeepLink.shared.onDeferredMatchDebug { result in
    switch result {
    case .success(let match):
        print(match.matched, match.tier ?? "-", match.destinationPath ?? "-")
    case .failure(let error):
        print(error.localizedDescription)
    }
}

// Manual re-run (e.g. debug UI)
MRTDeepLink.shared.runDeferredMatchDebug(clickSessionId: "optional-uuid")
```

---

## Payload

```swift
public struct MRTDeepLinkPayload {
    public let url: URL
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let source: MRTDeepLinkSource   // .universalLink | .customScheme | .deferred
    public let isDeferred: Bool
}
```

---

## Smart link builder

```swift
let config = MRTSmartLinkConfiguration(
    webDomain: "appsmartlink.digitalplayground.quest",
    customURLScheme: "mrtdeeplink",
    iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id…")!
)

// https://appsmartlink…/product/42
MRTSmartLinkBuilder.makeWebURL(path: "/product/42", configuration: config)

// mrtdeeplink://product/42
MRTSmartLinkBuilder.makeAppURL(path: "/product/42", scheme: "mrtdeeplink")
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
- Associated Domains capability
- Valid SDK API key from your SmartLink admin

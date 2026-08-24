# CliqIt — Flutter / consumer handoff

## Public iOS API (only this)

```swift
import CliqIt

// 1) Listen once
CliqItSDK.shared.onLinkReceived { payload in
  if let err = payload.errorMessage {
    // status: failed | verifyFailed | lookupFailed
    print(payload.status, err)
    return
  }
  if payload.shouldNavigate {
    // open payload.path
  }
}

// 2) Configure (starts verify + deferred match in background)
CliqItSDK.shared.configure(apiKey: "pk_live_…")

// 3) Forward URLs (Scene / openURL / continue user activity)
_ = CliqItSDK.shared.handle(url: url)
// or CliqItSceneSupport.handle(…)
```

SwiftUI:

```swift
ContentView()
  .handleCliqItLinkReceived { payload in /* … */ }
```

## Background (automatic)

| Work | Success | Failure → `onLinkReceived` |
|------|---------|----------------------------|
| `POST /verify` | silent | `status: verifyFailed` + `errorMessage` |
| `GET /link/{slug}` | `status: opened` (+ path) | `status: lookupFailed` + `errorMessage` |
| `POST /app/match` | `matched` / `notMatched` | `status: failed` + `errorMessage` |

## `CliqItPayload` fields

`url`, `path`, `pathComponents`, `queryParameters`, `source`, `isDeferred`,  
`status`, `matched`, `tier`, `confidence`, `score`, `slug`, `destinationPath`,  
`errorMessage`, `shouldNavigate`, `receivedAt`

**status:** `opened` | `matched` | `notMatched` | `failed` | `verifyFailed` | `lookupFailed` | `alreadyReported`

## Ship to Flutter

1. `CliqIt/Frameworks/CliqIt.xcframework` (binary)
2. `CliqIt/CliqIt.podspec` (or root `CliqIt.podspec`)
3. This note

Plugin should expose **one** Dart stream, e.g. `onLinkReceived`, mirroring native.  
Adopt UIScene: `FlutterSceneLifeCycleDelegate` + `CliqItSceneSupport`.

## Not public anymore

Removed: `onDeepLink`, `onDeferredMatch`, `onVerify`, `onDirectLinkLookup`, `handleCliqItDeepLinks`.

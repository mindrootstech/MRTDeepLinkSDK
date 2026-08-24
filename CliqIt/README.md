# CliqIt iOS SDK

Deferred deep linking — **one listener**: `onLinkReceived`.

## Install

```ruby
pod 'CliqIt', :git => 'https://github.com/mindrootstech/CliqIt.git', :tag => '2.0.3'
```

## Usage

```swift
import CliqIt

CliqItSDK.shared.onLinkReceived { payload in
    if let err = payload.errorMessage {
        print(payload.status, err)
        return
    }
    if payload.shouldNavigate {
        // navigate to payload.path
    }
}

CliqItSDK.shared.configure(apiKey: "pk_live_…")
```

SwiftUI: `.handleCliqItLinkReceived { … }`  
URLs: `handle(url:)` / `CliqItSceneSupport`.

Do **not** call any other SDK APIs from the app. Verify, slug lookup, and deferred match run inside the SDK.

See `FLUTTER_TEAM_HANDOFF.md` for the field table.

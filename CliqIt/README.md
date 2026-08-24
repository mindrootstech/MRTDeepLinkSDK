# CliqIt iOS SDK

Deferred deep linking — **one listener**: `onLinkReceived`.

## Install

```ruby
pod 'CliqIt', :git => 'https://github.com/mindrootstech/CliqIt.git', :tag => '2.0.3'
```

Or local XCFramework via the podspec in this folder.

## Usage

```swift
import CliqIt

CliqItSDK.shared.onLinkReceived { payload in
    if let err = payload.errorMessage {
        print(payload.status, err) // verifyFailed / lookupFailed / failed
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

Verify, slug lookup, and deferred match run in the **background**. Only navigation results and errors are delivered on `onLinkReceived`.

See `FLUTTER_TEAM_HANDOFF.md` for the full field table.

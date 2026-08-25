# CliqIt iOS SDK

Deferred deep linking — **one listener**: `onLinkReceived`.

Public consumer docs: [mindrootstech/CliqIt](https://github.com/mindrootstech/CliqIt) · tag **`2.0.4`**

## Install

```ruby
pod 'CliqIt', :git => 'https://github.com/mindrootstech/CliqIt.git', :tag => '2.0.4'
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
UIKit: `CliqItSceneSupport.handle(…)` + `handle(url:)`

Verify, slug lookup, and deferred match are internal — do not call other SDK APIs from the app.

See the [public README](https://github.com/mindrootstech/CliqIt/blob/main/README.md) for the full payload table and UIScene setup.

# CliqIt — Flutter iOS (source, not XCFramework)

Do **not** vendor `CliqIt.xcframework`. Copy the Swift **classes** into the plugin and compile them with `CliqitPlugin.swift`. Same public API as native.

## 1. Copy these files

From this zip / repo into the Flutter package:

| Give them | Put in Flutter plugin |
|-----------|------------------------|
| `CliqIt/Classes/*.swift` (all files) | `ios/Classes/CliqIt/` |
| `FlutterPlugin/CliqitPlugin.swift` | `ios/Classes/CliqitPlugin.swift` |
| `FlutterPlugin/cliqit.dart` | `lib/cliqit.dart` (or merge into existing Dart) |

Do **not** copy `Frameworks/`. Do **not** copy `SwiftUI/` (not needed for Flutter).

`ios/cliqit.podspec` must compile all of them:

```ruby
s.source_files = 'Classes/**/*.swift'
s.ios.deployment_target = '15.0'
s.swift_version = '5.0'
# no vendored_frameworks
# no pod 'CliqIt'
```

Remove any `s.vendored_frameworks = '…CliqIt.xcframework'` and any `s.dependency 'CliqIt'`.

## 2. Plugin API (same as native)

```swift
CliqItSDK.shared.onLinkReceived { payload in … }
CliqItSDK.shared.configure(apiKey: "pk_live_…")
_ = CliqItSDK.shared.handle(url: url)
CliqItSceneSupport.handle(…)  // UIScene
```

Do not call other SDK methods. Verify, slug lookup, deferred match run inside the classes.

Navigate only when `payload.shouldNavigate == true` (use `path`, not `url`). Restart after a consumed deferred match is silent.

## 3. Dart

One stream: `cliqit/onLinkReceived`. See `FlutterPlugin/cliqit.dart`.

```dart
CliqIt.onLinkReceived.listen((payload) {
  if (payload['shouldNavigate'] == true) {
    // navigate to payload['path']
  }
});
await CliqIt.configure(apiKey: 'pk_live_…');
```

## Payload

`url`, `path`, `pathComponents`, `query`, `source`, `isDeferred`, `status`, `matched`, `tier`, `confidence`, `score`, `slug`, `destinationPath`, `error`, `shouldNavigate`

**status:** `opened` | `matched` | `notMatched` | `failed` | `verifyFailed` | `lookupFailed`

## After copy

```bash
flutter clean
cd ios && pod install && cd ..
flutter run
```

Old plugin calls `onDeepLink` / `onDeferredMatch` / `onVerify` — those methods do not exist. Use `onLinkReceived` only.

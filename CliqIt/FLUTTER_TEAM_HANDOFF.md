# Flutter team — CliqIt handoff

## 1) Crash fix (required)

**Symptom:** after `✅ [CliqIt] configured` → `freed pointer was not the last allocation` → abort.

**Cause:** Swift `async let` in deferred match (Xcode 26 / Swift 6.x).

**Action:** Replace the XCFramework / pod binary with the new build from this repo (`CliqIt/Frameworks/CliqIt.xcframework` or the zip you receive).

The UIScene console line is a **warning**, not this crash.

## 2) UIScene plugin migration (required soon)

In `CliqitPlugin`:

1. Adopt `FlutterSceneLifeCycleDelegate`
2. Call `registrar.addSceneDelegate(instance)` (keep `addApplicationDelegate` if you still support old apps)
3. Forward scene URL / activity / cold-start to CliqIt:

```swift
public final class CliqitPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CliqitPlugin()
    // … existing channel setup …
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let options = connectionOptions {
      CliqItSceneSupport.handle(connectionOptions: options)
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    CliqItSceneSupport.handle(urlContexts: URLContexts)
    return true
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    CliqItSceneSupport.handle(userActivity: userActivity)
  }
}
```

Host Flutter app must also complete UIScene migration:  
https://docs.flutter.dev/release/breaking-changes/uiscenedelegate

## 3) What to ship from native

- Updated `CliqIt.xcframework` (crash fix)
- Optional: this handoff note

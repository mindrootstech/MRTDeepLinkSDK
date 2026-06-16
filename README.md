# MRTDeepLinkSDK

A lightweight iOS CocoaPod for deep linking — handles Universal Links and custom URL schemes, with SwiftUI helpers and Smart Link URL generation.

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
  # pod 'MRTDeepLinkSDK', :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => '0.2.4'
end
```

Then run:

```bash
pod install
```

> **Important:** Open `YourApp.xcworkspace`, not `.xcodeproj`.

## Quick Start

### 1. Configure at app launch (API key only)

```swift
import MRTDeepLinkSDK

MRTDeepLink.shared.configure(
    apiKey: "mrt_live_your_unique_key",
    debugLogging: true,
    testMode: false  // set true to skip license API during local testing
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
- Validates the **API key**
- Downloads **domains**, **URL scheme**, and **app settings** from the server

You do **not** need to manually set domains or schemes in the app.

| Property | Description |
|----------|-------------|
| `apiKey` | Unique key from the admin panel (required) |
| `debugLogging` | Print debug logs (optional, default `false`) |
| `testMode` | Skip license API validation (optional, default `false`) |
| `licenseServerURL` | Admin server URL (optional, has SDK default) |

### 2. SwiftUI integration

```swift
ContentView()
    .handleMRTDeepLinks { payload in
        print("Path:", payload.path)
        print("Params:", payload.queryParameters)
    }
```

The `handleMRTDeepLinks` modifier automatically wires up:
- `.onOpenURL` for custom URL schemes
- `.onContinueUserActivity` for Universal Links
- Pending link delivery if the handler is registered after a cold start

### 3. UIKit / AppDelegate

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    MRTDeepLink.shared.handle(url: url)
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    MRTDeepLink.shared.handle(userActivity: userActivity)
}
```

### 4. UIKit / SceneDelegate (Storyboard apps)

If your app uses `UIScene`, wire deep links in **SceneDelegate** (and keep AppDelegate handlers as a fallback):

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

Register your handler at launch:

```swift
MRTDeepLink.shared.onDeepLink { payload in
    print("Deep link:", payload.url.absoluteString)
}
```

### 5. Custom URL scheme (Info.plist, optional)

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

### 6. Universal Links

1. Xcode → **Signing & Capabilities** → **Associated Domains**
2. Add:
   ```
   applinks:links.yourdomain.com
   applinks:links.yourdomain.com?mode=developer
   ```
   (`?mode=developer` is required for debug builds during development.)
3. Host `apple-app-site-association` at:
   ```
   https://links.yourdomain.com/.well-known/apple-app-site-association
   ```
4. Serve with `Content-Type: application/json` (no `.json` extension).

## Smart Links (open app or redirect to App Store)

For shareable links that work across WhatsApp, SMS, email, and social platforms, use `MRTSmartLinkBuilder` to generate HTTPS URLs. When the user taps the link:

- **App installed** → opens the app via Universal Link or custom scheme
- **App not installed** → redirects to the App Store

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

Host an `apple-app-site-association` file on your domain for Universal Links to work.

## Example links

```
yourapp://product/123?id=abc
https://links.yourdomain.com/product/123?id=abc
```

## License API (admin backend)

The SDK validates the API key on launch by calling your admin server:

```
GET {licenseServerURL}/api/sdk/validate?key={apiKey}&bundleId={bundleId}
```

Response 200:
  {
    "valid": true,
    "message": "OK",
    "config": {
      "appIdentifier": "com.yourcompany.app",
      "universalLinkDomains": ["links.yourdomain.com"],
      "customURLSchemes": ["yourapp"]
    }
  }

Response 403/401:
  { "valid": false, "message": "Invalid or expired key" }
```

If `valid` is not `true`, deep link handling is disabled.

## API Reference

### `MRTDeepLink`

| Method | Description |
|--------|-------------|
| `configure(_:)` | Initialize the SDK and validate license |
| `validateLicense()` | Re-check license with admin server |
| `onLicenseStatusChange(_:)` | Observe license validation status |
| `isLicenseValid` | Whether the current license is active |
| `currentLicenseStatus` | Current license state |
| `onDeepLink(_:)` | Register a deep link callback |
| `handle(url:)` | Handle a URL manually (e.g. from AppDelegate) |
| `handle(userActivity:)` | Handle a Universal Link from `NSUserActivity` |
| `consumePendingDeepLink()` | Retrieve a link received before the handler was set |

### `MRTDeepLinkPayload`

| Property | Description |
|----------|-------------|
| `url` | Original URL |
| `path` | Normalized path (e.g. `/product/42`) |
| `pathComponents` | Path split into segments |
| `queryParameters` | Query string as a dictionary |
| `source` | `.universalLink`, `.customScheme`, or `.unknown` |

### SwiftUI

| Modifier | Description |
|----------|-------------|
| `handleMRTDeepLinks(_:)` | View modifier that handles incoming deep links |

## Multi-app setup (same domain)

Multiple apps can share one domain. Give each app a **unique path prefix** in AASA:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      { "appID": "TEAM_ID.com.shop.app", "paths": ["/shop", "/shop/*"] },
      { "appID": "TEAM_ID.com.food.app", "paths": ["/food", "/food/*"] }
    ]
  }
}
```

Share links with matching prefixes:

```
https://links.yourdomain.com/shop/product/42   → Shop app
https://links.yourdomain.com/food/menu/5       → Food app
```

**Do not** use `"paths": ["*"]` or `"paths": ["/*"]` for multiple apps on the same domain — iOS cannot reliably pick the right app.

Each app still needs a unique Bundle ID. Custom URL schemes are optional but useful for local testing.

## Publishing to CocoaPods

```bash
cd MRTDeepLinkSDK
pod lib lint MRTDeepLinkSDK.podspec --allow-warnings
git tag 0.1.0
git push origin 0.1.0
```

## Troubleshooting

### Link opens Safari instead of the app

- Tap the link from **Notes**, **Messages**, or **WhatsApp** — typing in Safari's address bar does not trigger Universal Links.
- Delete the app and reinstall after adding Associated Domains.
- Confirm AASA is live at `/.well-known/apple-app-site-association`.
- For UIKit Storyboard apps, ensure **SceneDelegate** handlers are wired (see above).

### Wrong app opens for the same domain

- Remove wildcard `"*"` / `"/*"` paths from AASA.
- Use unique path prefixes per app (`/shop/*`, `/food/*`).
- Delete all related apps, restart the device, reinstall.

### "Multiple commands produce Info.plist"

If using a custom `Info.plist` inside a synchronized folder, exclude it from Copy Bundle Resources in Xcode.

### CocoaPods sandbox / rsync errors

Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in your project and Podfile `post_install` hook.

## License

MIT

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
  # pod 'MRTDeepLinkSDK', :git => 'https://github.com/mindrootstech/MRTDeepLinkSDK.git', :tag => '0.4.0'
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
    debugLogging: true
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
Authorization: Bearer {apiKey}
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

## Event Analytics

Log in-app events to your platform. Configured automatically when you call `MRTDeepLink.shared.configure(...)`, or standalone:

```swift
MRTAnalytics.shared.configure(
    apiKey: "mrt_live_your_unique_key",
    debugLogging: true
)

MRTAnalytics.shared.identify(userId: "user_98765")

MRTAnalytics.shared.track(
    eventName: "button_click",
    properties: [
        "buttonName": "Submit",
        "screen": "Home"
    ]
)
```

### Events API

```
POST {licenseServerURL}/api/sdk/events?bundleId={bundleId}
Content-Type: application/json
Authorization: Bearer {apiKey}
```

Request body:

```json
{
  "eventName": "button_click",
  "anonymousId": "anon_12345",
  "userId": "user_abc_device_id",
  "loginUserId": "user_98765",
  "sessionId": "sess_abc123",
  "properties": {
    "buttonName": "Submit",
    "screen": "Home"
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `eventName` | Yes | Event name |
| `anonymousId` | Auto-generated | Stable device ID (`anon_...`) — same until app uninstall |
| `userId` | Auto-generated | Stable SDK user ID (`user_...`) — same until app uninstall |
| `loginUserId` | No | Logged-in user from `identify(userId:)` — does not replace `userId` |
| `sessionId` | Auto | Attached to every event while a session is active |
| `properties` | No | Custom string key-value attributes |

### Auto session tracking

The SDK automatically tracks app sessions:

| Event | When |
|-------|------|
| `session_started` | App launch or return after 30+ min in background |
| `session_ended` | App enters background (includes `durationSeconds`) |

Every `track()` call includes the active `sessionId`. Resume within 30 minutes keeps the same session.

Every `track()` call can log to the Xcode console when `debugLogging: true`.

### `MRTAnalytics`

| Method | Description |
|--------|-------------|
| `configure(...)` | Initialize analytics with API key |
| `identify(userId:)` | Link logged-in user as `loginUserId` (device `userId` stays the same) |
| `setAnonymousId(_:)` | Set a custom anonymous ID |
| `resetUser()` | Clear linked login user |
| `track(eventName:properties:)` | Log an event |
| `currentUserId` | Stable device user ID |
| `currentAnonymousId` | Stable anonymous ID |
| `currentLoginUserId` | Linked login user, if any |
| `currentSessionId` | Active session ID, if any |

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

Each app still needs a unique Bundle ID. Custom URL schemes are optional.

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

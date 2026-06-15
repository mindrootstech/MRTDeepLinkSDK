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

  # From Git (after publishing)
  # pod 'MRTDeepLinkSDK', :git => 'https://github.com/MindRoots/MRTDeepLinkSDK.git', :tag => '0.1.0'
end
```

Then run:

```bash
pod install
```

> **Important:** Open `YourApp.xcworkspace`, not `.xcodeproj`.

## Quick Start

### 1. Configure at app launch

```swift
import MRTDeepLinkSDK

MRTDeepLink.shared.configure(
    MRTDeepLinkConfiguration(
        appIdentifier: "com.yourcompany.app",
        apiKey: "mrt_live_your_unique_key",
        licenseServerURL: URL(string: "https://your-admin-server.com")!,
        universalLinkDomains: ["links.yourdomain.com"],
        customURLSchemes: ["yourapp"],
        debugLogging: true
    )
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

| Property | Description |
|----------|-------------|
| `appIdentifier` | Your iOS bundle identifier |
| `apiKey` | Unique key generated from the admin panel (paid service) |
| `licenseServerURL` | Your admin/backend base URL |
| `licenseValidationPath` | API path for key validation (default: `api/v1/license/validate`) |
| `universalLinkDomains` | Domains configured for Universal Links |
| `customURLSchemes` | Custom URL schemes registered in Info.plist |
| `debugLogging` | Print debug logs to the console |

Deep linking only works when the license is **valid**. Invalid or missing keys are rejected.

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

### 3. UIKit / AppDelegate (optional)

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    MRTDeepLink.shared.handle(url: url)
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    MRTDeepLink.shared.handle(userActivity: userActivity)
}
```

### 4. Custom URL scheme (Info.plist)

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

### 5. Universal Links

1. Xcode → **Signing & Capabilities** → **Associated Domains**
2. Add: `applinks:links.yourdomain.com`
3. Host an `apple-app-site-association` file on your server

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
POST {licenseServerURL}/api/v1/license/validate
Headers:
  X-MRT-API-Key: {apiKey}
  Content-Type: application/json
Body:
  { "bundleId": "com.yourcompany.app" }

Response 200:
  { "valid": true, "message": "OK" }

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

## Multi-app setup

Each app that installs this pod must use **unique identifiers**:

- Bundle ID (e.g. `com.shop.app`, `com.food.app`)
- Custom URL scheme (e.g. `shopapp://`, `foodapp://`)
- Universal Link domain or subdomain (e.g. `links.shop.com`, `links.food.com`)

The pod code is shared; each app passes its own configuration in `configure()`. Your server uses the domain or an app key in the URL to determine which app to open.

## Publishing to CocoaPods

```bash
cd MRTDeepLinkSDK
pod lib lint MRTDeepLinkSDK.podspec --allow-warnings
git tag 0.1.0
git push origin 0.1.0
```

## Troubleshooting

### "Multiple commands produce Info.plist"

If using a custom `Info.plist` inside a synchronized folder, exclude it from Copy Bundle Resources in Xcode.

### CocoaPods sandbox / rsync errors

Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in your project and Podfile `post_install` hook.

## License

MIT

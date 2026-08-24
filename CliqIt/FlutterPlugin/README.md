# Flutter iOS — compile CliqIt **source**, not the XCFramework

Copy every file in `CliqIt/Classes/` into `ios/Classes/CliqIt/`.
Replace `ios/Classes/CliqitPlugin.swift` with `FlutterPlugin/CliqitPlugin.swift`.

Podspec: `s.source_files = 'Classes/**/*.swift'` — no `vendored_frameworks`.

Dart: one stream `onLinkReceived`. Navigate only if `shouldNavigate == true` (use `path`).

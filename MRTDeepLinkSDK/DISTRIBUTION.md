# Closed-source distribution

`MRTDeepLinkSDK` ships as a **binary XCFramework**. Consumers who `pod install` do **not** receive Swift source files.

## What consumers see

| Included | Not included |
|----------|--------------|
| `Frameworks/MRTDeepLinkSDK.xcframework` | `MRTDeepLinkSDK/Classes/**/*.swift` |
| Public API (`.swiftinterface`) | Internal implementation source |
| `LICENSE`, `README`, `.podspec` | Build scripts / private notes |

Public method/type names still appear in the Swift module interface (required for linking). Logic, comments, and private helpers are not shipped as readable source.

## Build the binary (maintainers only)

```bash
./scripts/build_xcframework.sh
```

Output: `MRTDeepLinkSDK/Frameworks/MRTDeepLinkSDK.xcframework`

## Install modes

```bash
# Default — binary (closed source)
pod install

# Local SDK development — compile from source
MRT_SDK_SOURCE=1 pod install
```

## Release checklist

1. Keep source in a **private** repo.
2. Run `./scripts/build_xcframework.sh`.
3. Publish a release tag that contains:
   - `Frameworks/MRTDeepLinkSDK.xcframework`
   - `MRTDeepLinkSDK.podspec`
   - `LICENSE` / `README`
4. Do **not** publish the `MRTDeepLinkSDK/Classes` or `SwiftUI` folders in the public release zip/tag.
5. Bump `s.version` in the podspec for each release.

## Limits (honest)

- Binary ≠ unbreakable. Skilled reverse engineering of the binary is still possible.
- Do not put API secrets / license keys only in the client SDK.
- For stronger protection, keep sensitive matching / scoring on the **server**.

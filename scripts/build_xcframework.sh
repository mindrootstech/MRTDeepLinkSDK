#!/usr/bin/env bash
# Builds a closed-source XCFramework for CocoaPods distribution.
# Consumers get the binary only — no Swift source files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="$ROOT/CliqIt"
OUT_DIR="$SDK_DIR/Frameworks"
BUILD_DIR="$SDK_DIR/.build-xcframework"
FRAMEWORK_NAME="CliqIt"
PROJECT="$SDK_DIR/CliqIt.xcodeproj"
XCFRAMEWORK="$OUT_DIR/${FRAMEWORK_NAME}.xcframework"

if [[ ! -d "$PROJECT" ]]; then
  echo "error: missing $PROJECT — regenerate the framework Xcode project first" >&2
  exit 1
fi

echo "→ Cleaning previous build…"
rm -rf "$BUILD_DIR" "$XCFRAMEWORK"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

archive_platform() {
  local destination="$1"
  local archive_path="$2"

  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$FRAMEWORK_NAME" \
    -configuration Release \
    -destination "$destination" \
    -archivePath "$archive_path" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ONLY_ACTIVE_ARCH=NO \
    DEBUG_INFORMATION_FORMAT=dwarf \
    STRIP_INSTALLED_PRODUCT=YES \
    COPY_PHASE_STRIP=YES \
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO
}

echo "→ Archiving iOS device…"
archive_platform "generic/platform=iOS" "$BUILD_DIR/ios-device.xcarchive"

echo "→ Archiving iOS simulator…"
archive_platform "generic/platform=iOS Simulator" "$BUILD_DIR/ios-sim.xcarchive"

find_framework() {
  find "$1" -name "${FRAMEWORK_NAME}.framework" -type d | head -1
}

DEVICE_FW="$(find_framework "$BUILD_DIR/ios-device.xcarchive")"
SIM_FW="$(find_framework "$BUILD_DIR/ios-sim.xcarchive")"

if [[ -z "$DEVICE_FW" || -z "$SIM_FW" ]]; then
  echo "error: could not locate built frameworks" >&2
  find "$BUILD_DIR" -name "*.framework" -type d || true
  exit 1
fi

echo "→ Device: $DEVICE_FW"
echo "→ Sim:    $SIM_FW"

echo "→ Creating XCFramework…"
xcodebuild -create-xcframework \
  -framework "$DEVICE_FW" \
  -framework "$SIM_FW" \
  -output "$XCFRAMEWORK"

find "$XCFRAMEWORK" -name "*.dSYM" -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "✅ Closed-source XCFramework ready:"
echo "   $XCFRAMEWORK"
echo ""
echo "Next:"
echo "  1. Tag/release with Frameworks/CliqIt.xcframework (do NOT publish Sources)"
echo "  2. cd .. && pod install"
echo "  3. Local source edits: CLIQIT_SDK_SOURCE=1 pod install"

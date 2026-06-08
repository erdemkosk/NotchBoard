#!/usr/bin/env bash
# Builds NotchBoard and assembles a runnable .app bundle (no full Xcode needed).
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="NotchBoard"
BUNDLE_ID="com.notchboard.app"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/dist/$APP_NAME.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"

echo "==> Assembling bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Inject version (CI passes NB_VERSION, e.g. "0.1.42"). Falls back to VERSION file + dev build.
PLIST="$APP_DIR/Contents/Info.plist"
VERSION_BASE="$(cat "$ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')"
SHORT_VERSION="${NB_VERSION:-${VERSION_BASE:-0.1.0}}"
BUILD_NUMBER="${NB_BUILD:-0}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $SHORT_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$PLIST"
echo "==> Version $SHORT_VERSION (build $BUILD_NUMBER)"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || \
    echo "   (codesign skipped/failed; app will still run locally)"

echo "==> Done: $APP_DIR"
echo "    Launch with: open \"$APP_DIR\""

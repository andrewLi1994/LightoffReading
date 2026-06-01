#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LightoffReading"
BUNDLE_ID="${BUNDLE_ID:-com.local.LightoffReading}"
APP_VERSION="${APP_VERSION:-}"
UNIVERSAL_BUILD="${UNIVERSAL_BUILD:-1}"
APP_PATH="$ROOT/.build/release/$APP_NAME.app"
BINARY_PATH="$ROOT/.build/release/$APP_NAME"
ARM64_BINARY_PATH="$ROOT/.build/arm64-apple-macosx/release/$APP_NAME"
X86_64_BINARY_PATH="$ROOT/.build/x86_64-apple-macosx/release/$APP_NAME"
ICON_PATH="$ROOT/Assets/AppIcon.icns"

if [[ -z "$APP_VERSION" && "${GITHUB_REF_NAME:-}" == v* ]]; then
    APP_VERSION="${GITHUB_REF_NAME#v}"
fi

APP_VERSION="${APP_VERSION:-0.1.2}"

cd "$ROOT"

if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
    swift build -c release --arch arm64 >&2
    swift build -c release --arch x86_64 >&2
else
    swift build -c release >&2
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
    /usr/bin/lipo -create "$ARM64_BINARY_PATH" "$X86_64_BINARY_PATH" -output "$APP_PATH/Contents/MacOS/$APP_NAME"
else
    cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
fi

chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_PATH" ]]; then
    cp "$ICON_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true

echo "$APP_PATH"

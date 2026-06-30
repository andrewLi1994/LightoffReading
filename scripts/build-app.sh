#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LightoffReading"
BUNDLE_ID="${BUNDLE_ID:-com.local.LightoffReading}"
APP_VERSION="${APP_VERSION:-}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-}}"
APPCAST_URL="${APPCAST_URL:-https://github.com/andrewLi1994/LightoffReading/releases/download/appcast/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-shyBq2otD9XCpgTNoqvQw8RVOnpH/9objwJT7qwhtfk=}"
UNIVERSAL_BUILD="${UNIVERSAL_BUILD:-1}"
APP_PATH="$ROOT/.build/release/$APP_NAME.app"
BINARY_PATH="$ROOT/.build/release/$APP_NAME"
ARM64_BINARY_PATH="$ROOT/.build/arm64-apple-macosx/release/$APP_NAME"
X86_64_BINARY_PATH="$ROOT/.build/x86_64-apple-macosx/release/$APP_NAME"
ICON_PATH="$ROOT/Assets/AppIcon.icns"

if [[ -z "$APP_VERSION" && "${GITHUB_REF_NAME:-}" == v* ]]; then
    APP_VERSION="${GITHUB_REF_NAME#v}"
fi

if [[ -z "$APP_VERSION" ]] && command -v git >/dev/null 2>&1; then
    LATEST_TAG="$(git tag --sort=-version:refname | awk '/^v[0-9]/{ print; exit }')"
    if [[ -n "$LATEST_TAG" ]]; then
        APP_VERSION="${LATEST_TAG#v}"
    fi
fi

if [[ -z "$APP_VERSION" ]]; then
    echo "Could not determine app version. Set APP_VERSION or create a v* git tag." >&2
    exit 1
fi

if [[ -z "$APP_BUILD_NUMBER" ]] && command -v git >/dev/null 2>&1; then
    APP_BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || true)"
fi

if [[ ! "$APP_BUILD_NUMBER" =~ ^[0-9]+$ ]] || [[ "$APP_BUILD_NUMBER" == "0" ]]; then
    echo "Could not determine a positive integer app build number. Set APP_BUILD_NUMBER." >&2
    exit 1
fi

cd "$ROOT"

if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
    swift build -c release --arch arm64 >&2
    swift build -c release --arch x86_64 >&2
else
    swift build -c release >&2
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Frameworks"

if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
    /usr/bin/lipo -create "$ARM64_BINARY_PATH" "$X86_64_BINARY_PATH" -output "$APP_PATH/Contents/MacOS/$APP_NAME"
else
    cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
fi

chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_PATH" ]]; then
    cp "$ICON_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Could not locate Sparkle.framework after building." >&2
    exit 1
fi
/usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

if ! /usr/bin/otool -l "$APP_PATH/Contents/MacOS/$APP_NAME" | grep -Fq '@executable_path/../Frameworks'; then
    /usr/bin/install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP_PATH/Contents/MacOS/$APP_NAME"
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
    <string>$APP_BUILD_NUMBER</string>
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
    <key>SUFeedURL</key>
    <string>$APPCAST_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_ED_KEY</string>
    <key>SURequireSignedFeed</key>
    <true/>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true

echo "$APP_PATH"

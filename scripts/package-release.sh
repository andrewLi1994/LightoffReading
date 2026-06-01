#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LightoffReading"
DIST_DIR="$ROOT/dist"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "$APP_NAME release packages must be built on macOS." >&2
    exit 1
fi

cd "$ROOT"
APP_PATH="$(bash scripts/build-app.sh)"

if [[ -n "$SIGN_IDENTITY" ]]; then
    /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$SIGN_IDENTITY" \
        "$APP_PATH"
fi

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ -z "$SIGN_IDENTITY" ]]; then
        echo "NOTARY_PROFILE requires SIGN_IDENTITY to be set to a Developer ID Application certificate." >&2
        exit 1
    fi

    /usr/bin/xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$APP_PATH"

    rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
fi

/usr/bin/shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "Created $ZIP_PATH"
echo "Created $ZIP_PATH.sha256"

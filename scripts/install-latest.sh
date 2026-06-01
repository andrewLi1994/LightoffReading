#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LightoffReading"
REPO="${LIGHTOFF_READING_REPO:-andrewLi1994/LightoffReading}"
ASSET_NAME="${LIGHTOFF_READING_ASSET:-LightoffReading.zip}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DOWNLOAD_URL="${LIGHTOFF_READING_DOWNLOAD_URL:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "$APP_NAME only runs on macOS." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required." >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -z "$DOWNLOAD_URL" ]]; then
    DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$ASSET_NAME"
fi

ZIP_PATH="$TMP_DIR/$ASSET_NAME"
UNPACK_DIR="$TMP_DIR/unpack"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"

echo "Downloading $DOWNLOAD_URL"
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$ZIP_PATH"

mkdir -p "$UNPACK_DIR"
/usr/bin/ditto -x -k "$ZIP_PATH" "$UNPACK_DIR"

APP_SOURCE="$(find "$UNPACK_DIR" -maxdepth 3 -type d -name "$APP_NAME.app" -print -quit)"
if [[ -z "$APP_SOURCE" ]]; then
    echo "Could not find $APP_NAME.app inside $ASSET_NAME." >&2
    exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
fi

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 0.4

if [[ -w "$INSTALL_DIR" ]]; then
    rm -rf "$APP_PATH"
    /usr/bin/ditto "$APP_SOURCE" "$APP_PATH"
else
    echo "$INSTALL_DIR is not writable. macOS may ask for your password."
    sudo rm -rf "$APP_PATH"
    sudo /usr/bin/ditto "$APP_SOURCE" "$APP_PATH"
fi

if [[ "${LIGHTOFF_READING_REMOVE_QUARANTINE:-0}" == "1" ]] && command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
fi

if [[ "${LIGHTOFF_READING_SKIP_OPEN:-0}" != "1" ]]; then
    open "$APP_PATH"
fi

echo "Installed $APP_NAME to $APP_PATH"

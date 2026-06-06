#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LightoffReading"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT/.build/release/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "$APP_NAME only runs on macOS." >&2
    exit 1
fi

cd "$ROOT"
bash scripts/build-app.sh >/dev/null

mkdir -p "$INSTALL_DIR"
/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 0.4
rm -rf "$INSTALL_PATH"
cp -R "$APP_PATH" "$INSTALL_PATH"

if command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true
fi

open "$INSTALL_PATH"
echo "Installed $APP_NAME to $INSTALL_PATH"

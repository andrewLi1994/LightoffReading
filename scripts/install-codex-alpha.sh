#!/usr/bin/env bash
set -euo pipefail

REPO="${LIGHTOFF_READING_REPO:-andrewLi1994/LightoffReading}"
ALPHA_TAG="${LIGHTOFF_READING_ALPHA_TAG:-v0.2.0-codex-alpha.7}"
ASSET_NAME="${LIGHTOFF_READING_ASSET:-LightoffReading.zip}"
INSTALLER_REF="${LIGHTOFF_READING_INSTALLER_REF:-main}"
DOWNLOAD_URL="${LIGHTOFF_READING_DOWNLOAD_URL:-https://github.com/$REPO/releases/download/$ALPHA_TAG/$ASSET_NAME}"
INSTALLER_URL="https://raw.githubusercontent.com/$REPO/$INSTALLER_REF/scripts/install-latest.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "LightoffReading only runs on macOS." >&2
    exit 1
fi

echo "Installing LightoffReading Codex alpha from $DOWNLOAD_URL"
curl -fsSL "$INSTALLER_URL" | LIGHTOFF_READING_DOWNLOAD_URL="$DOWNLOAD_URL" bash

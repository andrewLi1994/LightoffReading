# LightoffReading

**Language:** [English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

<p align="center">
  <img src="Assets/AppIcon.png" alt="LightoffReading app icon" width="112">
</p>

A lightweight macOS menu bar app that dims the screen and keeps a soft reading spotlight near your cursor.

LightoffReading is built for reading long pages, PDFs, documentation, and dense text at night or in bright environments. It stays out of the way in the menu bar, gives you a floating control HUD, and lets you toggle the reading light with a global shortcut.

Requires macOS 13 or later. The public release is a universal macOS app for both Apple Silicon and Intel Macs.

## Install

### Fast Install With Terminal

```sh
curl -fsSL https://raw.githubusercontent.com/andrewLi1994/LightoffReading/main/scripts/install-latest.sh | bash
```

This downloads the latest release, copies the app to `/Applications`, and opens it.

### Install Without Terminal

1. Open the latest release:
   https://github.com/andrewLi1994/LightoffReading/releases/latest

2. Download `LightoffReading.zip`.

3. Unzip it, then move `LightoffReading.app` to your `/Applications` folder.

Open LightoffReading from `/Applications`. It will appear in the macOS menu bar.

If macOS blocks the app on first launch, open System Settings and approve it from the Privacy & Security section.

## What It Does

- Dims the screen while leaving a soft reading area visible.
- Keeps the reading area positioned near the mouse cursor.
- Supports horizontal strip, ellipse, and other spotlight shapes.
- Provides a compact floating HUD for quick toggling and shape changes.
- Provides an expanded HUD for width, height, edge softness, darkness, and offset controls.
- Supports a global shortcut, defaulting to `Control-Option-Command-/`.
- Stores settings locally using macOS preferences.

## Privacy

LightoffReading does not include analytics, telemetry, accounts, or background network reporting.

The app stores your shortcut and visual settings locally on your Mac. The install script uses GitHub only to download the latest release asset.

## Usage

After launch, LightoffReading appears in the macOS menu bar.

- Use `Control-Option-Command-/` to toggle the reading light.
- Use the floating HUD to turn the light on or change the shape.
- Use `Show Floating HUD` from the menu bar item to reopen controls.
- Use `Set Shortcut...` to record a different shortcut.

On first launch, the app shows a small one-time hint under the menu bar icon so users know where the controls live.

## Support

LightoffReading is open source. If it helps you, you can support the project through GitHub Sponsors:

https://github.com/sponsors/andrewLi1994

## Build

```sh
bash scripts/build-app.sh
```

The script creates:

```text
.build/release/LightoffReading.app
```

By default, the app bundle contains a universal binary. For a faster local native-only build:

```sh
UNIVERSAL_BUILD=0 bash scripts/build-app.sh
```

Versioning:

- `APP_VERSION` env var wins when set.
- In GitHub Actions tag builds, `v1.2.3` becomes app version `1.2.3`.
- Otherwise the build script uses the latest local `v*` git tag.
- If no version can be resolved, the build fails instead of inventing one.

## Run Locally

```sh
open .build/release/LightoffReading.app
```

## Install From Source

For contributors or users who want to build locally:

```sh
git clone https://github.com/andrewLi1994/LightoffReading.git
cd LightoffReading
bash scripts/install.sh
```

The script builds the app, copies it to `/Applications/LightoffReading.app`, removes local quarantine metadata when present, and opens it.

## Package A Release

Create the release asset:

```sh
bash scripts/package-release.sh
```

The script creates:

```text
dist/LightoffReading.zip
dist/LightoffReading.zip.sha256
```

After `v*` tags are pushed, GitHub Actions builds and publishes the release asset automatically.

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Signing And Notarization

`scripts/build-app.sh` creates an ad-hoc signed app for local use. For the smoothest public download experience outside the Mac App Store, package a Developer ID signed and notarized release.

Example:

```sh
BUNDLE_ID="com.yourname.LightoffReading" \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notarytool-profile-name" \
bash scripts/package-release.sh
```

If the app is not Developer ID signed and notarized, macOS Gatekeeper may require users to manually approve the app the first time they open it.

## License

LightoffReading is released under the MIT License.

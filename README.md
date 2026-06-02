# LightoffReading

A lightweight macOS menu bar app that dims the screen and keeps a soft reading spotlight above the mouse cursor.

The public release is a universal macOS app for both Apple Silicon and Intel Macs.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/andrewLi1994/LightoffReading/main/scripts/install-latest.sh | bash
```

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

## Run

```sh
open .build/release/LightoffReading.app
```

## Install Locally

```sh
bash scripts/install.sh
```

The script builds the app, copies it to `/Applications/LightoffReading.app`, removes local quarantine metadata when present, and opens it.

Use `Control-Option-Command-/` to toggle the reading light by default.

Use `Set Shortcut...` in the menu bar item to record a different shortcut.

The menu bar item also exposes controls for shape, width, height, edge softness, darkness, horizontal offset, and vertical cursor offset.

On first launch, the app shows a small one-time hint under the menu bar icon so users know where the controls live.

## One-Line Install From GitHub Releases

For regular users, the cleanest non-App-Store flow is:

1. Build `dist/LightoffReading.zip`.
2. Attach that zip to a GitHub Release.
3. Let users run a `curl` installer that downloads the latest release asset and copies the app to `/Applications`.

Create the release asset:

```sh
bash scripts/package-release.sh
```

Users can install the latest release with:

```sh
curl -fsSL https://raw.githubusercontent.com/andrewLi1994/LightoffReading/main/scripts/install-latest.sh | bash
```

After `v*` tags are pushed, GitHub Actions builds and publishes the release asset automatically.

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Support

LightoffReading is open source. If it helps you, you can support the project through GitHub Sponsors:

https://github.com/sponsors/andrewLi1994

## Developer Source Install

For contributors or users who want to build locally:

```sh
git clone https://github.com/andrewLi1994/LightoffReading.git
cd LightoffReading
bash scripts/install.sh
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

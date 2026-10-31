#!/bin/bash
# Build Voice Launcher and package it as a drag-to-Applications .dmg.
# Self-signed, not notarized: no Apple Developer account is needed, and users
# allow the first launch once (see docs/INSTALL.md), or install with Homebrew.
#
#   ./App/make-dmg.sh   → build/VoiceLauncher-<version>.dmg and its SHA-256
set -euo pipefail
cd "$(dirname "$0")/.."

App/build-app.sh

APP="build/Voice Launcher.app"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/VoiceLauncher-$VER.dmg"
STAGE="build/dmg-stage"

echo "Packaging $DMG ..."
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
/usr/bin/ditto "$APP" "$STAGE/Voice Launcher.app"
ln -s /Applications "$STAGE/Applications"   # drag target

hdiutil create -volname "Voice Launcher" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Built $DMG"
echo "SHA-256 (for the Homebrew cask):"
shasum -a 256 "$DMG"

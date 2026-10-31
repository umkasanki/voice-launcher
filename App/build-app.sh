#!/bin/bash
# Assemble "Voice Launcher.app" with the command line tools alone — no Xcode.
#
#   ./App/build-app.sh             release build into build/
#   ./App/build-app.sh --install   the same, then replace /Applications/Voice Launcher.app and launch it
#
# The release workflow and make-dmg.sh use it too.
#
# Launch the bundle (open, the Dock, login), never the bare binary: macOS
# attributes the microphone grant to the bundle.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Voice Launcher.app"
DEST="/Applications/Voice Launcher.app"
IDENTITY="Voice Launcher Local"
KC="$HOME/Library/Keychains/voicelauncher.keychain-db"

echo "[1/4] swift build -c release..."
swift build -c release --product VoiceLauncher

echo "[2/4] Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/VoiceLauncher "$APP/Contents/MacOS/VoiceLauncher"
cp App/Info.plist "$APP/Contents/Info.plist"
cp App/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Version from the nearest v* tag, so a local build reads like a release: v0.2.0
# four commits on gives "0.2.0 (4)". Without tags App/Info.plist stands as it is.
if DESC=$(git describe --tags --match 'v[0-9]*' 2>/dev/null); then
    TAG="${DESC%-*-g*}"
    AHEAD=0
    [ "$TAG" != "$DESC" ] && AHEAD="${DESC#"$TAG"-}" && AHEAD="${AHEAD%%-*}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TAG#v}" \
                            -c "Set :CFBundleVersion $AHEAD" "$APP/Contents/Info.plist"
    echo "      version ${TAG#v} ($AHEAD)"
fi

echo "[3/4] Code signing..."
if [ -f "$KC" ] && security find-identity "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
    security unlock-keychain -p voicelauncher "$KC" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" --keychain "$KC" --timestamp=none "$APP"
    if codesign --display --verbose=2 "$APP" 2>&1 | grep -q "Signature=adhoc"; then
        echo "      ERROR: asked for '$IDENTITY' and got an ad-hoc signature." >&2
        exit 1
    fi
    echo "      stable identity: $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "      NO stable identity: signed ad-hoc, so macOS will ask for the"
    echo "      microphone again after every build. Run ./App/setup-signing.sh once."
fi

echo "[4/4] Verifying..."
codesign --verify --strict --verbose=1 "$APP" 2>&1 | sed 's/^/      /'
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    echo "[install] replacing $DEST"
    osascript -e 'tell application id "com.umkasanki.VoiceLauncher" to quit' 2>/dev/null || true
    pkill -x VoiceLauncher 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
    # ditto keeps the signature intact; a broken one would cost the grants.
    /usr/bin/ditto "$APP" "$DEST"
    open "$DEST"
    echo "Installed and launched $DEST"
fi

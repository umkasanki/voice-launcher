#!/bin/bash
# One-time: create a stable, self-signed code-signing identity, so that the
# microphone and speech-recognition grants survive rebuilds.
#
# macOS remembers those grants against the application's designated
# requirement, which comes from its code signature. An ad-hoc signature has no
# stable identity: every build looks like a new application and asks again.
# A self-signed certificate keeps the requirement fixed. No Apple account needed.
#
# The identity lives in its own keychain with a throwaway password, so codesign
# can use it without a GUI prompt. Do not re-run casually: a new certificate is
# a new identity, and the grants would be asked for again.
#
#   ./App/setup-signing.sh
set -euo pipefail

KC="$HOME/Library/Keychains/voicelauncher.keychain-db"
KCPASS="voicelauncher"          # throwaway; guards a local self-signed cert only
IDENTITY="Voice Launcher Local"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "The identity already exists; nothing to do."
    exit 0
fi

echo "[1/5] Generating a self-signed code-signing certificate..."
cat > "$WORK/cert.conf" <<CONF
[req]
distinguished_name = req_dn
x509_extensions    = v3
prompt             = no
[req_dn]
CN = $IDENTITY
[v3]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CONF
# The system LibreSSL, not Homebrew's OpenSSL 3+: newer OpenSSL writes PKCS#12
# files with algorithms `security import` cannot read ("MAC verification failed").
OPENSSL=/usr/bin/openssl
$OPENSSL req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.conf" >/dev/null 2>&1
$OPENSSL pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/identity.p12" -passout pass:$KCPASS -name "$IDENTITY" >/dev/null 2>&1

echo "[2/5] Creating and unlocking the keychain..."
security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || echo "      (already existed)"
security unlock-keychain -p "$KCPASS" "$KC"
security set-keychain-settings "$KC"

echo "[3/5] Importing the identity..."
security import "$WORK/identity.p12" -k "$KC" -P "$KCPASS" -T /usr/bin/codesign 2>&1 | tail -1 || true

echo "[4/5] Letting codesign use the key without a prompt..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null

echo "[5/5] Adding the keychain to the search list..."
EXISTING=$(security list-keychains -d user | sed 's/[[:space:]]*"//; s/"$//')
echo "$EXISTING" | grep -q "voicelauncher.keychain" || \
    security list-keychains -d user -s "$KC" $EXISTING

security find-identity "$KC" | grep "$IDENTITY" || echo "  (not found — check the import above)"
echo "Next:  ./App/build-app.sh --install"

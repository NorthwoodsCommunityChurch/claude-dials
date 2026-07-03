#!/bin/bash
# Build Claude Dials (Release) and sign it with a STABLE identity.
#
# Why this script exists: xcodebuild signs ad-hoc (CODE_SIGN_IDENTITY "-"),
# whose fingerprint changes every build. The macOS Keychain binds "Always Allow"
# to a code signature, so an ad-hoc app re-prompts for Keychain access on every
# rebuild. Re-signing with a real certificate (identity = bundle id + team, NOT
# the per-build hash) makes the grant stick across all rebuilds and copies.
#
# Cert: the Apple Development cert already on this Mac. To find its SHA-1 hash:
#   security find-identity -v -p codesigning
set -euo pipefail
cd "$(dirname "$0")"

CERT="${CLAUDEDIALS_SIGN_CERT:-C7C47640D77786FC360C811388F289BB0B71143C}"  # Apple Development: larson.central@pm.me (N8VRQ57AR9)
APP="build/Build/Products/Release/Claude Dials.app"
SPK="$APP/Contents/Frameworks/Sparkle.framework"

echo "▸ Generating project…"
xcodegen generate >/dev/null

echo "▸ Building (Release)…"
xcodebuild -scheme ClaudeDials -configuration Release -derivedDataPath build build >/dev/null

echo "▸ Signing with stable identity ($CERT)…"
# Sparkle must be signed inside-out (nested components before the framework).
codesign --force -o runtime --sign "$CERT" "$SPK/Versions/B/XPCServices/Installer.xpc"
codesign --force -o runtime --sign "$CERT" "$SPK/Versions/B/XPCServices/Downloader.xpc"
codesign --force -o runtime --sign "$CERT" "$SPK/Versions/B/Updater.app"
codesign --force -o runtime --sign "$CERT" "$SPK/Versions/B/Autoupdate"
codesign --force          --sign "$CERT" "$SPK"
codesign --force -o runtime --sign "$CERT" "$APP"

codesign --verify --deep --strict "$APP"
echo "✓ Built and signed: $APP"
echo "  Identity: $(codesign -dvv "$APP" 2>&1 | grep '^Authority' | head -1 | sed 's/Authority=//')"

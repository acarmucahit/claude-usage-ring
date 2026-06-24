#!/bin/bash
# Build, code-sign (Developer ID), notarize, and staple a release .app + .zip.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your login keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + Developer ID Application).
#   2. A stored notarytool credential profile:
#        xcrun notarytool store-credentials notary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./release.sh
set -euo pipefail

APP="ClaudeUsageRing.app"
ZIP="ClaudeUsageRing.app.zip"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your 'Developer ID Application: Name (TEAMID)' identity}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"

echo "▸ Building (release)…"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/ClaudeUsageRing"

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH" "$APP/Contents/MacOS/ClaudeUsageRing"
cp Info.plist "$APP/Contents/Info.plist"

echo "▸ Code signing (hardened runtime)…"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "▸ Zipping…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▸ Re-zipping stapled app…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "✅ Notarized & stapled."
echo "   $ZIP"
shasum -a 256 "$ZIP"

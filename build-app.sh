#!/bin/bash
set -euo pipefail
APP="ClaudeUsageRing.app"
CONFIG="${1:-release}"

swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/ClaudeUsageRing"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH" "$APP/Contents/MacOS/ClaudeUsageRing"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so Keychain access prompts behave and the app launches.
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built $APP"
echo "Run: open \"$APP\"   (or ./$APP/Contents/MacOS/ClaudeUsageRing for console logs)"

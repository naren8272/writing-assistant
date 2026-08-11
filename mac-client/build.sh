#!/usr/bin/env bash
# Builds WritingAssistant.app without an Xcode project (Command Line Tools are enough).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/build/WritingAssistant.app"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

swiftc -O \
  -target "${ARCH}-apple-macos14.0" \
  -sdk "$SDK" \
  -framework SwiftUI -framework AppKit \
  -o "$APP/Contents/MacOS/WritingAssistant" \
  "$ROOT"/*.swift

codesign --force --sign - "$APP"

echo "built: $APP"

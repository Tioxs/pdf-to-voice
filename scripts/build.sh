#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/dist/PDF to Voice.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
MODULE_CACHE="${TMPDIR:-/tmp}/pdf-to-voice-module-cache"

mkdir -p "$MACOS_DIR" "$MODULE_CACHE"
cp "$ROOT_DIR/BuildSupport/Info.plist" "$CONTENTS_DIR/Info.plist"

xcrun swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macosx13.0 \
  -module-cache-path "$MODULE_CACHE" \
  -Xcc "-fmodules-cache-path=$MODULE_CACHE" \
  "$ROOT_DIR"/PDFToVoice/*.swift \
  -framework SwiftUI \
  -framework PDFKit \
  -framework AVFoundation \
  -o "$MACOS_DIR/PDFToVoice"

codesign --force --sign - \
  --entitlements "$ROOT_DIR/PDFToVoice/PDFToVoice.entitlements" \
  "$APP_DIR"

echo "$APP_DIR"

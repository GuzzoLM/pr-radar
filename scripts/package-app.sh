#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <binary> <version> <output-directory>"
    exit 1
fi

BINARY="$1"
VERSION="${2#v}"
OUTPUT_DIR="$3"
APP_NAME="PRadar"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

if [[ ! -f "$BINARY" ]]; then
    echo "Binary not found: ${BINARY}"
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod 755 "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.guzzolm.pradar</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing keeps the bundle internally consistent. A Developer ID signature
# and notarization can replace this step when signing credentials are available.
codesign --force --deep --sign - "$APP_BUNDLE"

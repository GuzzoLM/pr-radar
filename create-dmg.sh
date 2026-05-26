#!/bin/bash
set -e

APP_NAME="PRadar"
BUNDLE_NAME="PRadar"
DMG_NAME="PRadar.dmg"
BUILD_DIR=".build/release"
APP_DIR="/tmp/pradar-dmg"
APP_BUNDLE="${APP_DIR}/${APP_NAME}.app"

echo "Building ${BUNDLE_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${BUNDLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BUNDLE_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${BUNDLE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.guzzolm.pradar</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${APP_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"

rm -rf "${APP_DIR}"

echo ""
echo "✓ Created ${DMG_NAME}"
echo "  Share this file — recipients just open the DMG and drag to /Applications."
echo ""
echo "Prerequisites for recipients:"
echo "  • macOS 13+"
echo "  • gh CLI installed and authenticated (brew install gh && gh auth login)"

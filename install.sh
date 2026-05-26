#!/bin/bash
set -e

APP_NAME="PRadar"
DISPLAY_NAME="PRadar"
APP_DIR="/Applications/${APP_NAME}.app"
OLD_APP_DIR="/Applications/pr-monitor.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle at ${APP_DIR}..."
rm -rf "${OLD_APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PRadar</string>
    <key>CFBundleDisplayName</key>
    <string>PRadar</string>
    <key>CFBundleIdentifier</key>
    <string>com.guzzolm.pradar</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>PRadar</string>
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

echo "✓ Installed to ${APP_DIR}"
echo ""
echo "You can now:"
echo "  • Open it from Spotlight (Cmd+Space → 'PRadar')"
echo "  • Find it in /Applications"
echo "  • Add it to Login Items (System Settings → General → Login Items) to auto-start"

#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PRadar"
VERSION="${1:-$(git describe --tags --always)}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pradar-dmg.XXXXXX")"
DMG_NAME="PRadar-${VERSION#v}.dmg"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "Building ${APP_NAME} ${VERSION#v}..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "Creating app bundle..."
scripts/package-app.sh "${BIN_DIR}/${APP_NAME}" "$VERSION" "$STAGING_DIR"

echo "Creating ${DMG_NAME}..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

echo "Created ${DMG_NAME}"

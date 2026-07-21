#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building PRadar..."
swift build -c release

BINARY=".build/release/PRadar"

if [ ! -f "$BINARY" ]; then
    echo "Build failed - binary not found."
    exit 1
fi

echo ""
echo "Build successful!"
echo "Binary: $BINARY"
echo ""
echo "To run: $BINARY"
echo ""

read -p "Run now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting PRadar..."
    "$BINARY"
fi

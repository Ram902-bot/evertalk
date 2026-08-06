#!/bin/bash
# Deploy Evertalk to /Applications
# Note: Don't re-sign after initial setup to preserve Accessibility permission

set -e

APP_NAME="Evertalk"
BUILD_PATH="$HOME/Library/Developer/Xcode/DerivedData/Evertalk-*/Build/Products/Debug/Evertalk.app"
DEST="/Applications/Evertalk.app"

# Find the build
BUILD=$(ls -d $BUILD_PATH 2>/dev/null | head -1)

if [ -z "$BUILD" ]; then
    echo "Error: Build not found. Run 'xcodebuild -scheme Evertalk build' first."
    exit 1
fi

# Kill running app
pkill -f "Evertalk.app" 2>/dev/null || true
sleep 0.5

# Copy to Applications (preserves existing signature if unchanged)
rm -rf "$DEST"
cp -R "$BUILD" "$DEST"

echo "Deployed to $DEST"
echo "Note: If this is first install, grant Accessibility permission when prompted."

open "$DEST"

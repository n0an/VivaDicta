#!/bin/bash

# Upload dSYM files to Firebase Crashlytics
# Usage: ./upload-crashlytics-dsym.sh [device|simulator]
# Default: device

set -e

PLATFORM="${1:-device}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GOOGLE_SERVICE_PLIST="$PROJECT_DIR/VivaDicta/GoogleService-Info.plist"

echo "🔍 Finding DerivedData folder..."

# Find the most recent VivaDicta DerivedData folder
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "VivaDicta-*" -type d 2>/dev/null | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo "❌ Error: Could not find VivaDicta DerivedData folder"
    echo "   Make sure you've built the project in Xcode first"
    exit 1
fi

echo "📁 DerivedData: $DERIVED_DATA"

# Find upload-symbols tool
UPLOAD_SYMBOLS="$DERIVED_DATA/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"

if [ ! -f "$UPLOAD_SYMBOLS" ]; then
    echo "❌ Error: upload-symbols tool not found at:"
    echo "   $UPLOAD_SYMBOLS"
    echo "   Make sure Firebase Crashlytics SPM package is resolved"
    exit 1
fi

echo "🔧 Upload tool: $UPLOAD_SYMBOLS"

# Find dSYM based on platform
if [ "$PLATFORM" = "simulator" ]; then
    DSYM_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/VivaDicta.app.dSYM"
else
    DSYM_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/VivaDicta.app.dSYM"
fi

if [ ! -d "$DSYM_PATH" ]; then
    echo "❌ Error: dSYM not found at:"
    echo "   $DSYM_PATH"
    echo "   Make sure DEBUG_INFORMATION_FORMAT is set to 'DWARF with dSYM File'"
    echo "   and rebuild the project"
    exit 1
fi

echo "📦 dSYM: $DSYM_PATH"

# Verify GoogleService-Info.plist exists
if [ ! -f "$GOOGLE_SERVICE_PLIST" ]; then
    echo "❌ Error: GoogleService-Info.plist not found at:"
    echo "   $GOOGLE_SERVICE_PLIST"
    exit 1
fi

echo "🔑 GoogleService-Info.plist: $GOOGLE_SERVICE_PLIST"
echo ""
echo "🚀 Uploading dSYM to Crashlytics..."
echo ""

"$UPLOAD_SYMBOLS" -gsp "$GOOGLE_SERVICE_PLIST" -p ios "$DSYM_PATH"

echo ""
echo "✅ Upload complete!"

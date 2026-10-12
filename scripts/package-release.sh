#!/usr/bin/env bash
set -euo pipefail

# Borno Pulse macOS Build & Packaging Script
# Creates production-grade Universal DMG and ZIP installer packages.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg_staging"
APP_NAME="Borno Pulse"
VERSION="1.3.0"
DMG_NAME="Borno-Pulse-v${VERSION}.dmg"
DMG_LATEST="Borno-Pulse-macOS.dmg"
ZIP_NAME="Borno-Pulse-macOS.zip"

echo "=========================================="
echo "🚀 Building Borno Pulse v${VERSION} for macOS"
echo "=========================================="

# 1. Clean previous dist
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

# 2. Build Release Universal Binary via xcodebuild
echo "📦 Compiling Universal Release Binary (arm64 + x86_64)..."
xcodebuild -project "smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "generic/platform=macOS" \
           -configuration Release \
           build | grep -E "(BUILD SUCCEEDED|warning:|error:)" || true

# 3. Locate compiled application bundle
DERIVED_DATA_APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Borno Pulse.app" -type d -path "*/Build/Products/Release/Borno Pulse.app" 2>/dev/null | head -n 1)

if [ -z "$DERIVED_DATA_APP" ] || [ ! -d "$DERIVED_DATA_APP" ]; then
    DERIVED_DATA_APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "smart tool.app" -type d -path "*/Build/Products/Release/smart tool.app" 2>/dev/null | head -n 1)
fi

if [ -z "$DERIVED_DATA_APP" ] || [ ! -d "$DERIVED_DATA_APP" ]; then
    echo "❌ Error: Could not find compiled Borno Pulse.app in DerivedData."
    exit 1
fi

echo "✅ Located build at: $DERIVED_DATA_APP"

# 4. Copy to dist and rename to Borno Pulse.app
TARGET_APP="$DIST_DIR/${APP_NAME}.app"
cp -R "$DERIVED_DATA_APP" "$TARGET_APP"

# Re-sign with ad-hoc signature to reflect bundle rename
codesign --force --deep --sign - "$TARGET_APP" 2>/dev/null || true

# 5. Prepare DMG Staging
echo "💿 Creating DMG Installer Image..."
cp -R "$TARGET_APP" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Generate DMG using hdiutil
hdiutil create -volname "${APP_NAME}" \
               -srcfolder "$STAGING_DIR" \
               -ov -format UDZO \
               "$DIST_DIR/$DMG_NAME"

cp "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$DMG_LATEST"
mkdir -p "$PROJECT_DIR/releases"
cp "$DIST_DIR/$DMG_LATEST" "$PROJECT_DIR/releases/$DMG_LATEST"
rm -rf "$STAGING_DIR"

# 6. Create ZIP distribution
echo "🗜️  Creating ZIP distribution..."
ditto -c -k --keepParent "$TARGET_APP" "$DIST_DIR/$ZIP_NAME"

# 7. Checksums
echo "🔐 Generating SHA-256 Checksums..."
(
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_NAME" "$DMG_LATEST" "$ZIP_NAME" > "checksums-sha256.txt"
)

# 8. Optional Install flag
if [[ "${1:-}" == "--install" ]]; then
    echo "📲 Installing ${APP_NAME} to /Applications..."
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "$TARGET_APP" "/Applications/${APP_NAME}.app"
    xattr -cr "/Applications/${APP_NAME}.app"
    echo "🎉 Successfully installed to /Applications/${APP_NAME}.app"
fi

echo "=========================================="
echo "✅ Build & Packaging Complete!"
echo "Artifacts generated in: $DIST_DIR"
ls -lh "$DIST_DIR"
echo "=========================================="

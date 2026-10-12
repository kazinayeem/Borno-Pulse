#!/usr/bin/env bash
set -euo pipefail

# Borno Pulse — Automated Screenshot Capture Script
# Builds the application and executes the automated screenshot suite across
# Light and Dark modes for all 24 navigation sections, settings tabs, and the menu bar widget.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-"$REPO_ROOT/screenshots"}"

echo "=========================================================="
echo "  Borno Pulse — Automated Screenshot Capture"
echo "=========================================================="
echo "Repository Root: $REPO_ROOT"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# 1. Build the Application
echo "==> Building smart tool target..."
xcodebuild -project "$REPO_ROOT/smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "platform=macOS" \
           -configuration Debug \
           build > /dev/null 2>&1

# 2. Locate built executable
DERIVED_DATA_BUILD="$HOME/Library/Developer/Xcode/DerivedData"
APP_BIN=$(find "$DERIVED_DATA_BUILD" \( -name "Borno Pulse" -o -name "smart tool" \) -type f -perm +111 -path "*/Contents/MacOS/*" 2>/dev/null | head -n 1)

if [ -z "$APP_BIN" ] || [ ! -x "$APP_BIN" ]; then
    echo "❌ Error: Could not locate built Borno Pulse executable."
    exit 1
fi

echo "==> Running automated screenshot engine: $APP_BIN"
mkdir -p "$OUTPUT_DIR/light" "$OUTPUT_DIR/dark" "$OUTPUT_DIR/widget"

# Kill any existing instance to ensure clean single-process execution
pkill -f "Contents/MacOS/Borno Pulse" || true
pkill -f "Contents/MacOS/smart tool" || true
sleep 1

# 3. Run screenshot automation
"$APP_BIN" --capture-all-screenshots "$OUTPUT_DIR"

# 4. Verify outputs
echo ""
echo "==> Validating generated screenshot files..."
LIGHT_COUNT=$(find "$OUTPUT_DIR/light" -name "*.png" -size +1k | wc -l | tr -d ' ')
DARK_COUNT=$(find "$OUTPUT_DIR/dark" -name "*.png" -size +1k | wc -l | tr -d ' ')
WIDGET_COUNT=$(find "$OUTPUT_DIR/widget" -name "*.png" -size +1k | wc -l | tr -d ' ')

echo "Captured:"
echo "  • Light Mode: $LIGHT_COUNT files"
echo "  • Dark Mode:  $DARK_COUNT files"
echo "  • Widget:     $WIDGET_COUNT files"

if [ "$LIGHT_COUNT" -gt 0 ] && [ "$DARK_COUNT" -gt 0 ] && [ "$WIDGET_COUNT" -gt 0 ]; then
    echo "✅ Screenshot automation completed successfully!"
    exit 0
else
    echo "❌ Error: Missing screenshots. Verification failed."
    exit 1
fi

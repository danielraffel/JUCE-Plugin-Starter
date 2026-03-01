#!/bin/bash

# Build DiagnosticKit App
# This script builds the SwiftUI diagnostic app using Swift Package Manager

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find DiagnosticKit directory
DIAGNOSTIC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIAGNOSTIC_DIR"

# Build configuration — SPM expects lowercase "debug" or "release"
BUILD_CONFIG="${1:-release}"
BUILD_CONFIG_LOWER=$(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]' | sed 's/prod/release/')
case "$BUILD_CONFIG_LOWER" in
    debug) BUILD_CONFIG_SPM="debug" ;;
    *)     BUILD_CONFIG_SPM="release" ;;
esac

echo -e "${GREEN}Building DiagnosticKit...${NC}"
echo "Configuration: $BUILD_CONFIG_SPM"

# Check if .env exists
if [[ ! -f ".env" ]]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Run this from the main build.sh which generates the .env file"
    exit 1
fi

# Load configuration
set -a
source .env
set +a

# Create build directory
BUILD_DIR="$DIAGNOSTIC_DIR/build"
mkdir -p "$BUILD_DIR"

APP_NAME="${APP_NAME:-DiagnosticKit}"
APP_BUNDLE_NAME="${APP_NAME}.app"

echo ""
echo "Building Swift package..."

# Build with Swift Package Manager
swift build \
    --configuration "$BUILD_CONFIG_SPM" \
    --product DiagnosticKit \
    --build-path "$BUILD_DIR/.build"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Swift build failed${NC}"
    exit 1
fi

# Get built binary path
if [[ "$BUILD_CONFIG_SPM" == "debug" ]]; then
    BINARY_PATH="$BUILD_DIR/.build/debug/DiagnosticKit"
else
    BINARY_PATH="$BUILD_DIR/.build/release/DiagnosticKit"
fi

echo ""
echo "Creating application bundle..."

# Create app bundle structure
APP_PATH="$BUILD_DIR/$APP_BUNDLE_NAME"
rm -rf "$APP_PATH"

mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy binary
cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

# Copy .env into Resources
cp ".env" "$APP_PATH/Contents/Resources/"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_IDENTIFIER}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y)</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Copy entitlements
if [[ -f "DiagnosticKit.entitlements" ]]; then
    cp "DiagnosticKit.entitlements" "$APP_PATH/Contents/"
fi

echo -e "${GREEN}✅ Build complete${NC}"
echo "App bundle: $APP_PATH"
echo ""

# Validate app bundle
if [[ -d "$APP_PATH" ]] && [[ -x "$APP_PATH/Contents/MacOS/$APP_NAME" ]]; then
    echo -e "${GREEN}✅ App bundle is valid${NC}"
else
    echo -e "${RED}❌ App bundle validation failed${NC}"
    exit 1
fi

# Export path for build.sh
echo "$APP_PATH"

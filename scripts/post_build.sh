#!/bin/bash
set -e

# Get the component path from first argument
COMPONENT_PATH="$1"
if [ -z "$COMPONENT_PATH" ]; then
    echo "Error: No component path provided"
    exit 1
fi

echo "Component path: $COMPONENT_PATH"

# Find Info.plist inside the component bundle
INFO_PLIST="$COMPONENT_PATH/Contents/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Info.plist not found at $INFO_PLIST"
    exit 1
fi

# Generate version string based on timestamp (YYMMDDHHmm)
VERSION="1.0.$(date +%y%m%d%H%M)"

# Update both version strings
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"

echo "Updated version to $VERSION"

# Copy to Components folder
COMPONENTS_DIR="$HOME/Library/Audio/Plug-Ins/Components"
mkdir -p "$COMPONENTS_DIR"

# Copy and overwrite if exists
cp -R "$COMPONENT_PATH" "$COMPONENTS_DIR/"

echo "Copied to $COMPONENTS_DIR"
echo "Remember to 'Reset & Rescan' in Logic Pro's Plugin Manager"

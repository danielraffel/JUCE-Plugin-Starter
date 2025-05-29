#!/bin/bash

# Define the project path
PROJECT_DIR="/Users/danielraffel/Code/RealtimeComposerToolkit"
BUILD_DIR="$PROJECT_DIR/build"
XCODE_PROJECT="$BUILD_DIR/RealtimeComposerToolkit.xcodeproj"

# Navigate to project directory
cd "$PROJECT_DIR" || { echo "Directory not found: $PROJECT_DIR"; exit 1; }

# Remove and recreate build directory
rm -rf "$BUILD_DIR"
mkdir "$BUILD_DIR"
cd "$BUILD_DIR" || { echo "Failed to enter build directory."; exit 1; }

# Run cmake to generate Xcode project
/opt/homebrew/bin/cmake .. -G "Xcode" -DCMAKE_OSX_ARCHITECTURES='arm64;x86_64'

# Open the generated Xcode project
if [ -d "$XCODE_PROJECT" ]; then
  open "$XCODE_PROJECT"
else
  echo "Xcode project not found: $XCODE_PROJECT"
  exit 1
fi

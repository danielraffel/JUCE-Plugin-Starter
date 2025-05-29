#!/bin/bash

# Load environment variables from .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found. Please create one from .env.example"
  exit 1
fi

# Validate required env variables
if [ -z "$PROJECT_PATH" ] || [ -z "$PROJECT_NAME" ]; then
  echo "Missing required PROJECT_PATH or PROJECT_NAME in .env"
  exit 1
fi

# Set derived paths
BUILD_DIR="$PROJECT_PATH/build"
XCODE_PROJECT="$BUILD_DIR/${PROJECT_NAME}.xcodeproj"

# Navigate to project directory
cd "$PROJECT_PATH" || { echo "Directory not found: $PROJECT_PATH"; exit 1; }

# Clean and recreate build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || { echo "Failed to enter build directory."; exit 1; }

# Run cmake to generate Xcode project
/opt/homebrew/bin/cmake .. -G "Xcode" -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"

# Open the generated Xcode project
if [ -d "$XCODE_PROJECT" ]; then
  open "$XCODE_PROJECT"
else
  echo "Xcode project not found: $XCODE_PROJECT"
  exit 1
fi

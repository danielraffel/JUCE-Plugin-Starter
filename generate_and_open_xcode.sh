#!/bin/bash

# Load environment variables from .env safely
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo ".env file not found. Please create one from .env.example"
  exit 1
fi

# Validate required env variables
if [ -z "$PROJECT_PATH" ] || [ -z "$PROJECT_NAME" ]; then
  echo "Missing required PROJECT_PATH or PROJECT_NAME in .env"
  exit 1
fi

# Use current directory if PROJECT_PATH doesn't exist
if [ ! -d "$PROJECT_PATH" ]; then
  echo "Warning: PROJECT_PATH ($PROJECT_PATH) not found. Using current directory."
  PROJECT_PATH=$(pwd)
fi

# Set derived paths
BUILD_DIR="$PROJECT_PATH/build"
XCODE_PROJECT="$BUILD_DIR/${PROJECT_NAME}.xcodeproj"

# Navigate to project directory
cd "$PROJECT_PATH" || { echo "Directory not found: $PROJECT_PATH"; exit 1; }

# ORIGINAL BUILD LOGIC
# # Clean and recreate build directory
# rm -rf "$BUILD_DIR"
# mkdir -p "$BUILD_DIR"
# cd "$BUILD_DIR" || { echo "Failed to enter build directory."; exit 1; }

# # Run cmake to generate Xcode project
# CMAKE_ARGS="-G Xcode -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64"

# ENHANCED BUILD LOGIC
# Conditionally recreate the build directory
if [ "$SKIP_CMAKE_REGEN" != "1" ]; then
  echo "Regenerating build directory..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR" || { echo "Failed to enter build directory."; exit 1; }

  # Run cmake to generate Xcode project
  CMAKE_ARGS="-G Xcode -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64"

  if [ -n "$ENABLE_AI_FEATURES" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_AI_FEATURES=$ENABLE_AI_FEATURES"
  fi
  if [ -n "$USE_VISAGE_UI" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DUSE_VISAGE_UI=$USE_VISAGE_UI"
  fi
  if [ -n "$BUILD_UNIT_TESTS" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DBUILD_UNIT_TESTS=$BUILD_UNIT_TESTS"
  fi
  if [ -n "$USE_GPU_ACCELERATION" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DUSE_GPU_ACCELERATION=$USE_GPU_ACCELERATION"
  fi
  if [ -n "$ENABLE_ESSENTIA_FEATURES" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_ESSENTIA_FEATURES=$ENABLE_ESSENTIA_FEATURES"
  fi

  /opt/homebrew/bin/cmake .. $CMAKE_ARGS
else
  echo "Skipping CMake regeneration. Using existing build folder."
  cd "$BUILD_DIR" || { echo "Build directory does not exist. Run without SKIP_CMAKE_REGEN=1 first."; exit 1; }
fi

# # Open the generated Xcode project
# if [ -d "$XCODE_PROJECT" ]; then
#   open "$XCODE_PROJECT"
# else
#   echo "Xcode project not found: $XCODE_PROJECT"
#   exit 1
# fi

#!/bin/bash

# Check for build type argument (default to Debug)
BUILD_TYPE="Debug"
if [ "$1" = "release" ]; then
  BUILD_TYPE="Release"
  echo "🚀 Configuring for Release build..."
else
  echo "🔧 Configuring for Debug build..."
fi

# Load environment variables from .env safely
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo ".env file not found. Please create one from .env.example"
  exit 1
fi

# Auto-bump version based on recent commits (unless explicitly disabled)
if [ "$SKIP_VERSION_BUMP" != "1" ]; then
  echo "📦 Auto-bumping version based on recent commits..."
  python3 scripts/bump_version.py --auto
else
  echo "📦 Skipping version bump (SKIP_VERSION_BUMP=1)"
fi

# Load the (potentially updated) version information
eval $(python3 scripts/bump_version.py --export-only)
if [ -z "$PROJECT_VERSION" ]; then
  echo "⚠️  Warning: Could not load version information, using defaults"
  export PROJECT_VERSION="1.2.0"
  export PROJECT_VERSION_MAJOR="1"
  export PROJECT_VERSION_MINOR="2"
  export PROJECT_VERSION_PATCH="0"
  export AU_VERSION_INT="65792"
else
  # Export version variables so CMake can see them
  export PROJECT_VERSION
  export PROJECT_VERSION_MAJOR
  export PROJECT_VERSION_MINOR
  export PROJECT_VERSION_PATCH
  export AU_VERSION_INT
  export BUILD_NUMBER
fi
echo "✅ Building version $PROJECT_VERSION"

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

# Enhanced build logic
# Conditionally recreate the build directory
if [ "$SKIP_CMAKE_REGEN" != "1" ]; then
  echo "Regenerating build directory..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR" || { echo "Failed to enter build directory."; exit 1; }

  # Run cmake to generate Xcode project
  CMAKE_ARGS="-G Xcode -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64 -DCMAKE_BUILD_TYPE=$BUILD_TYPE"

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
  if [ -n "$ENABLE_SLICE_MODE" ]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_SLICE_MODE=$ENABLE_SLICE_MODE"
  fi

  # Pass version information as CMake variables
  VERSION_ARGS="-DPROJECT_VERSION=$PROJECT_VERSION"
  VERSION_ARGS="$VERSION_ARGS -DPROJECT_VERSION_MAJOR=$PROJECT_VERSION_MAJOR"
  VERSION_ARGS="$VERSION_ARGS -DPROJECT_VERSION_MINOR=$PROJECT_VERSION_MINOR"
  VERSION_ARGS="$VERSION_ARGS -DPROJECT_VERSION_PATCH=$PROJECT_VERSION_PATCH"
  VERSION_ARGS="$VERSION_ARGS -DAU_VERSION_INT=$AU_VERSION_INT"
  
  /opt/homebrew/bin/cmake .. $CMAKE_ARGS $VERSION_ARGS
else
  echo "Skipping CMake regeneration. Using existing build folder."
  
  # Check if build directory exists AND has the Xcode project
  if [ ! -d "$BUILD_DIR" ] || [ ! -d "$XCODE_PROJECT" ]; then
    echo "❌ Build directory missing or incomplete (no Xcode project found)"
    echo "   Run without SKIP_CMAKE_REGEN=1 to regenerate"
    exit 1
  fi
  
  # Check if version in CMake cache matches current version
  if [ -f "$BUILD_DIR/CMakeCache.txt" ]; then
    CMAKE_VERSION=$(grep "CMAKE_PROJECT_VERSION:STRING=" "$BUILD_DIR/CMakeCache.txt" 2>/dev/null | cut -d= -f2 || echo "unknown")
    if [ "$CMAKE_VERSION" != "$PROJECT_VERSION" ]; then
      echo "⚠️  Version mismatch in CMake: cached=$CMAKE_VERSION, current=$PROJECT_VERSION"
      echo "❌ Cannot skip regeneration with outdated version"
      echo "   Run without SKIP_CMAKE_REGEN=1 to update version"
      exit 1
    fi
  fi
  
  cd "$BUILD_DIR" || { echo "Build directory does not exist. Run without SKIP_CMAKE_REGEN=1 first."; exit 1; }
fi

# # Open the generated Xcode project
# if [ -d "$XCODE_PROJECT" ]; then
#   open "$XCODE_PROJECT"
# else
#   echo "Xcode project not found: $XCODE_PROJECT"
#   exit 1
# fi
#!/bin/bash

# ==============================================================
# JUCE Plugin Starter: Automated Dependency Setup Script
# ==============================================================
# This script checks for and installs essential tools required for JUCE plugin development.
# You can uncomment optional tools if needed.

set -e

echo "🚀 JUCE Plugin Starter: Automated Dependency Setup Script"
echo "This script will check for and install required tools for JUCE plugin development."
read -p "Would you like to continue? (Y/N): " confirm

# Convert to lowercase and check
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Setup cancelled. Exiting..."
  exit 0
fi

# -------------------------------
# 0. Check for Xcode Command Line Tools
# -------------------------------
if ! xcode-select -p &>/dev/null; then
  echo "🔧 Xcode Command Line Tools not found. Installing..."
  xcode-select --install
  echo "⚠️ Please complete the installation before rerunning this script."
  exit 1
else
  echo "✅ Xcode Command Line Tools are installed."
fi

# -------------------------------
# 1. Check for Homebrew
# -------------------------------
if ! command -v brew &>/dev/null; then
  echo "🍺 Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "✅ Homebrew is installed."
fi

# -------------------------------
# 2. Required Brew packages
# -------------------------------
check_brew_package() {
  local package=$1
  local install_cmd=$2
  if ! brew list | grep -q "^$package\$"; then
    echo "📦 Installing $package..."
    eval "$install_cmd"
  else
    echo "✅ $package is already installed."
  fi
}

check_brew_cask() {
  local cask=$1
  if ! brew list --cask | grep -q "^$cask\$"; then
    echo "🧩 Installing $cask (cask)..."
    brew install --cask "$cask"
  else
    echo "✅ $cask is already installed."
  fi
}

check_brew_package "cmake" "brew install cmake"
check_brew_cask "pluginval"

# -------------------------------
# 3. Enhanced JUCE Framework Validation
# -------------------------------
# Use environment variables if available, otherwise use defaults
JUCE_REPO=${JUCE_REPO:-"https://github.com/juce-framework/JUCE.git"}
JUCE_TAG=${JUCE_TAG:-"8.0.7"}

echo "🎵 JUCE Configuration:"
echo "   Repository: $JUCE_REPO"
echo "   Version/Tag: $JUCE_TAG"

# Validate JUCE version format
validate_juce_version() {
  local version=$1
  
  # Check if it's a valid semantic version (e.g., 8.0.7, 7.0.12)
  if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✅ Valid JUCE version format: $version"
    return 0
  fi
  
  # Check if it's 'main' or other branch names
  if [[ $version == "main" ]] || [[ $version == "develop" ]]; then
    echo "⚠️  Using development branch: $version (not recommended for production)"
    return 0
  fi
  
  # Check if it's a commit hash (40 characters)
  if [[ $version =~ ^[a-f0-9]{40}$ ]]; then
    echo "✅ Using commit hash: ${version:0:8}..."
    return 0
  fi
  
  echo "❌ Invalid JUCE version format: $version"
  echo "   Expected: semantic version (e.g., 8.0.7), 'main', or commit hash"
  return 1
}

# Validate the JUCE version
if ! validate_juce_version "$JUCE_TAG"; then
  echo "❌ Please check your JUCE_TAG in .env file"
  exit 1
fi

# Check JUCE version compatibility
check_juce_compatibility() {
  local version=$1
  
  # Extract major version if it's a semantic version
  if [[ $version =~ ^([0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
    local major_version=${BASH_REMATCH[1]}
    
    if [[ $major_version -lt 7 ]]; then
      echo "⚠️  JUCE version $version is quite old. Consider upgrading to 7.x or 8.x"
    elif [[ $major_version -eq 7 ]]; then
      echo "✅ JUCE 7.x detected - stable and well-supported"
    elif [[ $major_version -eq 8 ]]; then
      echo "✅ JUCE 8.x detected - latest stable version"
    else
      echo "⚠️  JUCE version $version is newer than expected. Compatibility not guaranteed."
    fi
  fi
}

check_juce_compatibility "$JUCE_TAG"

echo "🎵 JUCE will be fetched from $JUCE_REPO at tag $JUCE_TAG during the CMake build process."

# -------------------------------
# 4. Build Environment Validation
# -------------------------------
echo "🔍 Validating build environment..."

# Check CMake version
if command -v cmake &>/dev/null; then
  CMAKE_VERSION=$(cmake --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
  echo "✅ CMake version: $CMAKE_VERSION"
  
  # Check if CMake version is sufficient (3.15+)
  if [[ $(echo "$CMAKE_VERSION 3.15" | tr ' ' '\n' | sort -V | head -n1) == "3.15" ]]; then
    echo "✅ CMake version is sufficient (3.15+ required)"
  else
    echo "⚠️  CMake version $CMAKE_VERSION may be too old. 3.15+ recommended."
  fi
fi

# Check Xcode version
if command -v xcodebuild &>/dev/null; then
  XCODE_VERSION=$(xcodebuild -version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
  echo "✅ Xcode version: $XCODE_VERSION"
fi

# -------------------------------
# Optional Tools – Uncomment if needed
# -------------------------------

# Faust (optional): DSP prototyping compiler
# check_brew_package "faust" "brew install faust"

# GoogleTest (optional): C++ unit testing
# check_brew_package "googletest" "brew install googletest"

# Python 3 (optional)
# if ! command -v python3 &>/dev/null; then
#   echo "🐍 Python 3 not found. Installing..."
#   brew install python
# else
#   echo "✅ Python 3 is installed."
# fi

# pip3 (optional)
# if ! command -v pip3 &>/dev/null; then
#   echo "📦 pip3 not found. Attempting to fix via Python reinstall..."
#   brew reinstall python
# else
#   echo "✅ pip3 is installed."
# fi

# behave (optional): BDD testing framework
# if ! pip3 list | grep -q "^behave "; then
#   echo "🧪 Installing behave for BDD testing..."
#   pip3 install behave
# else
#   echo "✅ behave is already installed."
# fi

echo "🎉 JUCE Plugin Starter: Enhanced Dependency Setup Complete!"
echo "📋 Summary:"
echo "   ✅ Development tools installed"
echo "   ✅ JUCE configuration validated"
echo "   ✅ Build environment ready"
echo ""
echo "🚀 Next steps:"
# Line 206: Update the reference
echo "   2. Run scripts/generate_and_open_xcode.sh to build your project"

#!/usr/bin/env bash

# ===============================
# JUCE Plugin Starter Dependencies Script
# ===============================
# This script checks for and installs the essential tools required to begin JUCE plugin development.
# Includes setup for:
# - Xcode Command Line Tools
# - Homebrew
# - CMake, PluginVal, Faust, GoogleTest
# - Python 3, pip3, and Behave for BDD testing

set -e

echo "🚀 JUCE Plugin Starter Setup Dependencies Script"
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
# 2. Ensure required Brew packages are installed
# -------------------------------

# Function to check and install a brew package
check_brew_package() {
  local package=$1
  local install_cmd=$2
  if ! brew list --formula | grep -q "^$package\$"; then
    echo "📦 Installing $package..."
    eval "$install_cmd"
  else
    echo "✅ $package is already installed."
  fi
}

# Function to check and install a brew cask
check_brew_cask() {
  local cask=$1
  if ! brew list --cask | grep -q "^$cask\$"; then
    echo "🧩 Installing $cask (cask)..."
    brew install --cask "$cask"
  else
    echo "✅ $cask is already installed."
  fi
}

# CMake: Build system configuration
check_brew_package "cmake" "brew install cmake"

# PluginVal: Plugin validation & testing
check_brew_cask "pluginval"

# Faust (optional): DSP prototyping compiler
# check_brew_package "faust" "brew install faust"

# GoogleTest (optional): C++ unit testing
# check_brew_package "googletest" "brew install googletest"

# -------------------------------
# 3. Check for Python 3, pip3, behave
# -------------------------------

# Python 3
if ! command -v python3 &>/dev/null; then
  echo "🐍 Python 3 not found. Installing..."
  brew install python
else
  echo "✅ Python 3 is installed."
fi

# pip3
if ! command -v pip3 &>/dev/null; then
  echo "📦 pip3 not found. Attempting to fix via Python reinstall..."
  brew reinstall python
else
  echo "✅ pip3 is installed."
fi

# behave: Natural language test automation
if ! pip3 list | grep -q "^behave "; then
  echo "🧪 Installing behave for BDD testing..."
  pip3 install behave
else
  echo "✅ behave is already installed."
fi

echo "🎉 JUCE Plugin Starter Setup Dependencies Script is Complete!"
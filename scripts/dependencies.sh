#!/usr/bin/env bash

# ==============================================================
# JUCE Plugin Starter: Automated Dependency Setup Script
# ==============================================================
# Cross-platform script that checks for and installs essential tools
# required for JUCE plugin development.
# Supports: macOS (Homebrew), Windows (winget via Git Bash/MSYS2)

set -e

echo "JUCE Plugin Starter: Automated Dependency Setup Script"
echo "This script will check for and install required tools for JUCE plugin development."

# Detect platform
case "$(uname -s)" in
    Darwin)  PLATFORM="macOS" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows" ;;
    Linux)   PLATFORM="Linux" ;;
    *)       echo "Unsupported platform: $(uname -s)"; exit 1 ;;
esac

echo "Detected platform: $PLATFORM"

read -p "Would you like to continue? (Y/N): " confirm

# Convert to lowercase and check
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. Exiting..."
    exit 0
fi

# ==============================================================
# macOS Setup
# ==============================================================
if [[ "$PLATFORM" == "macOS" ]]; then

    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools not found. Installing..."
        xcode-select --install
        echo "Please complete the installation before rerunning this script."
        exit 1
    else
        echo "OK: Xcode Command Line Tools are installed."
    fi

    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "OK: Homebrew is installed."
    fi

    # Helper functions for brew
    check_brew_package() {
        local package=$1
        local install_cmd=$2
        if ! brew list --formula | grep -q "^$package\$"; then
            echo "Installing $package..."
            eval "$install_cmd"
        else
            echo "OK: $package is already installed."
        fi
    }

    check_brew_cask() {
        local cask=$1
        if ! brew list --cask | grep -q "^$cask\$"; then
            echo "Installing $cask (cask)..."
            brew install --cask "$cask"
        else
            echo "OK: $cask is already installed."
        fi
    }

    check_brew_package "cmake" "brew install cmake"
    check_brew_package "ninja" "brew install ninja"
    check_brew_package "gh" "brew install gh"
    check_brew_cask "pluginval"

# ==============================================================
# Windows Setup (Git Bash / MSYS2)
# ==============================================================
elif [[ "$PLATFORM" == "Windows" ]]; then

    # Check for winget
    if ! command -v winget &>/dev/null; then
        echo "ERROR: winget not found. Please install the App Installer from the Microsoft Store."
        echo "https://www.microsoft.com/p/app-installer/9nblggh4nns1"
        exit 1
    else
        echo "OK: winget is available."
    fi

    # Helper function for winget
    check_winget_package() {
        local id=$1
        local name=$2
        local check_cmd=$3

        if eval "$check_cmd" &>/dev/null; then
            echo "OK: $name is already installed."
        else
            echo "Installing $name..."
            winget install --id "$id" -e --accept-package-agreements --accept-source-agreements
        fi
    }

    check_winget_package "Git.Git" "Git" "command -v git"
    check_winget_package "Kitware.CMake" "CMake" "command -v cmake"
    check_winget_package "Ninja-build.Ninja" "Ninja" "command -v ninja"

    # Check for Visual Studio / Build Tools with MSVC
    VS_FOUND=false
    for vs_path in \
        "/c/Program Files/Microsoft Visual Studio/2022/Community" \
        "/c/Program Files/Microsoft Visual Studio/2022/BuildTools" \
        "/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools"; do
        if [[ -d "$vs_path/VC/Tools/MSVC" ]]; then
            VS_FOUND=true
            echo "OK: Visual Studio C++ tools found at $vs_path"
            break
        fi
    done

    if [[ "$VS_FOUND" == "false" ]]; then
        echo "Visual Studio C++ tools not found. Installing Build Tools..."
        echo "This may take several minutes..."
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e \
            --accept-package-agreements --accept-source-agreements \
            --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
    fi

    echo ""
    echo "NOTE: After installing new tools, you may need to:"
    echo "  1. Open a new terminal (to refresh PATH)"
    echo "  2. Load the VS dev environment before building:"
    echo '     Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"'
    echo '     Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Community" -SkipAutomaticLocation'

# ==============================================================
# Linux Setup (apt for Ubuntu/Debian)
# ==============================================================
elif [[ "$PLATFORM" == "Linux" ]]; then

    # Check for apt
    if ! command -v apt-get &>/dev/null; then
        echo "ERROR: apt-get not found. This script supports Ubuntu/Debian-based distributions."
        echo "For other distributions, install these packages manually:"
        echo "  cmake ninja-build clang git"
        echo "  ALSA dev, X11 dev, Xinerama dev, Xext dev, FreeType dev"
        echo "  WebKit2GTK 4.1 dev, GLU dev, Xcursor dev, Xrandr dev"
        exit 1
    else
        echo "OK: apt-get is available."
    fi

    # JUCE Linux dependencies
    # Reference: https://forum.juce.com/t/list-of-juce-dependencies-under-linux/15121/44
    LINUX_PACKAGES=(
        # Build tools
        cmake
        ninja-build
        clang
        git
        pkg-config
        # JUCE audio
        libasound2-dev
        # JUCE GUI / X11
        libx11-dev
        libxinerama-dev
        libxext-dev
        libxrandr-dev
        libxcursor-dev
        # JUCE fonts
        libfreetype6-dev
        # JUCE web browser component (required even if disabled — header dependency)
        libwebkit2gtk-4.1-dev
        # JUCE OpenGL
        libglu1-mesa-dev
        # curl (JUCE networking, even if we disable it — some modules reference it)
        libcurl4-openssl-dev
    )

    echo "Installing JUCE development dependencies via apt..."
    echo "This may require sudo access."

    sudo apt-get update
    sudo apt-get install -y "${LINUX_PACKAGES[@]}"

    echo ""
    echo "Installed packages: ${LINUX_PACKAGES[*]}"
fi

# ==============================================================
# Optional Tools (all platforms) – Uncomment if needed
# ==============================================================

# Faust (optional): DSP prototyping compiler (macOS only via brew)
# [[ "$PLATFORM" == "macOS" ]] && check_brew_package "faust" "brew install faust"

echo ""
echo "JUCE Plugin Starter: Automated Dependency Setup Complete!"

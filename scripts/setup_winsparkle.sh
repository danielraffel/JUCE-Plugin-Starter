#!/bin/bash
# setup_winsparkle.sh — Download WinSparkle for Windows auto-update support
# Pinned to WinSparkle 0.9.2 (known working, EdDSA support)
#
# Usage:
#   ./scripts/setup_winsparkle.sh              # Download WinSparkle
#   WINSPARKLE_VERSION=0.9.2 ./scripts/setup_winsparkle.sh  # Override version
#
# Downloads and extracts to external/WinSparkle/:
#   external/WinSparkle/include/     — Headers (winsparkle.h, winsparkle-version.h)
#   external/WinSparkle/x64/         — x64 DLL + lib
#   external/WinSparkle/arm64/       — ARM64 DLL + lib
#   external/WinSparkle/bin/         — CLI tools (winsparkle-tool.exe)
#   external/WinSparkle/COPYING      — License

set -euo pipefail

WINSPARKLE_VERSION="${WINSPARKLE_VERSION:-0.9.2}"

# Find project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTERNAL_DIR="$PROJECT_ROOT/external"
WINSPARKLE_DIR="$EXTERNAL_DIR/WinSparkle"

echo "=== Setting up WinSparkle $WINSPARKLE_VERSION ==="

# Check if already present
if [[ -d "$WINSPARKLE_DIR/include" && -f "$WINSPARKLE_DIR/include/winsparkle.h" ]]; then
    echo "WinSparkle already present at $WINSPARKLE_DIR"
    echo "To re-download, remove external/WinSparkle and run again."
    exit 0
fi

WINSPARKLE_URL="https://github.com/vslavik/winsparkle/releases/download/v${WINSPARKLE_VERSION}/WinSparkle-${WINSPARKLE_VERSION}.zip"

echo "Downloading WinSparkle $WINSPARKLE_VERSION..."

# Create temp directory with cleanup trap
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Download
ARCHIVE="$TEMP_DIR/WinSparkle.zip"
if command -v curl &>/dev/null; then
    curl -fSL "$WINSPARKLE_URL" -o "$ARCHIVE"
elif command -v wget &>/dev/null; then
    wget -q "$WINSPARKLE_URL" -O "$ARCHIVE"
else
    echo "Error: Neither curl nor wget found"
    exit 1
fi

echo "Extracting..."

# Extract to temp dir
cd "$TEMP_DIR"
unzip -q "$ARCHIVE"

# WinSparkle ZIP extracts to WinSparkle-{version}/ containing:
#   include/          — headers
#   x64/Release/      — x64 DLL + lib + pdb
#   ARM64/Release/    — ARM64 DLL + lib + pdb
#   Release/          — x86 (32-bit, not needed)
#   bin/              — winsparkle-tool.exe and legacy scripts
EXTRACTED_DIR="$TEMP_DIR/WinSparkle-${WINSPARKLE_VERSION}"

if [[ ! -d "$EXTRACTED_DIR" ]]; then
    echo "Error: Expected extracted directory $EXTRACTED_DIR not found"
    echo "Contents of temp dir:"
    ls -la "$TEMP_DIR/" 2>/dev/null || echo "(empty)"
    exit 1
fi

# Create target directory
rm -rf "$WINSPARKLE_DIR"
mkdir -p "$WINSPARKLE_DIR"

# Copy headers
cp -R "$EXTRACTED_DIR/include" "$WINSPARKLE_DIR/"

# Copy x64 binaries (flatten from x64/Release/ to x64/)
if [[ -d "$EXTRACTED_DIR/x64/Release" ]]; then
    mkdir -p "$WINSPARKLE_DIR/x64"
    cp "$EXTRACTED_DIR/x64/Release/WinSparkle.dll" "$WINSPARKLE_DIR/x64/"
    cp "$EXTRACTED_DIR/x64/Release/WinSparkle.lib" "$WINSPARKLE_DIR/x64/"
    echo "  Copied x64 binaries"
fi

# Copy ARM64 binaries (flatten from ARM64/Release/ to arm64/)
if [[ -d "$EXTRACTED_DIR/ARM64/Release" ]]; then
    mkdir -p "$WINSPARKLE_DIR/arm64"
    cp "$EXTRACTED_DIR/ARM64/Release/WinSparkle.dll" "$WINSPARKLE_DIR/arm64/"
    cp "$EXTRACTED_DIR/ARM64/Release/WinSparkle.lib" "$WINSPARKLE_DIR/arm64/"
    echo "  Copied ARM64 binaries"
fi

# Copy CLI tools (winsparkle-tool.exe for EdDSA key generation and signing)
if [[ -d "$EXTRACTED_DIR/bin" ]]; then
    cp -R "$EXTRACTED_DIR/bin" "$WINSPARKLE_DIR/"
    echo "  Copied CLI tools (winsparkle-tool.exe)"
fi

# Copy license
if [[ -f "$EXTRACTED_DIR/COPYING" ]]; then
    cp "$EXTRACTED_DIR/COPYING" "$WINSPARKLE_DIR/"
fi

# Verify extraction
echo ""
echo "Verifying..."

ERRORS=0

if [[ -f "$WINSPARKLE_DIR/include/winsparkle.h" ]]; then
    echo "  ✓ Headers present"
else
    echo "  ✗ Headers missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "$WINSPARKLE_DIR/x64/WinSparkle.dll" && -f "$WINSPARKLE_DIR/x64/WinSparkle.lib" ]]; then
    echo "  ✓ x64 binaries present"
else
    echo "  ✗ x64 binaries missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "$WINSPARKLE_DIR/arm64/WinSparkle.dll" && -f "$WINSPARKLE_DIR/arm64/WinSparkle.lib" ]]; then
    echo "  ✓ ARM64 binaries present"
else
    echo "  ✗ ARM64 binaries missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "$WINSPARKLE_DIR/bin/winsparkle-tool.exe" ]]; then
    echo "  ✓ winsparkle-tool.exe present (EdDSA key generation and signing)"
else
    echo "  ✗ winsparkle-tool.exe missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Error: $ERRORS verification check(s) failed"
    echo "Contents of $WINSPARKLE_DIR:"
    ls -laR "$WINSPARKLE_DIR/" 2>/dev/null || echo "(empty)"
    exit 1
fi

echo ""
echo "=== WinSparkle $WINSPARKLE_VERSION setup complete ==="
echo ""
echo "Directory structure:"
echo "  external/WinSparkle/include/   — Headers"
echo "  external/WinSparkle/x64/       — x64 DLL + lib"
echo "  external/WinSparkle/arm64/     — ARM64 DLL + lib"
echo "  external/WinSparkle/bin/       — CLI tools (winsparkle-tool.exe)"
echo ""
echo "Next steps:"
echo "  1. Generate EdDSA keys:  external/WinSparkle/bin/winsparkle-tool.exe generate-keys"
echo "  2. Add public key to .env as AUTO_UPDATE_EDDSA_PUBLIC_KEY"
echo "  3. Rebuild with ENABLE_AUTO_UPDATE=true"

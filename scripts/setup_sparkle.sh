#!/bin/bash
# setup_sparkle.sh — Download Sparkle 2.x framework for macOS auto-update support
# Pinned to Sparkle 2.8.0 (known working, EdDSA support, PKG-compatible)
#
# Usage: ./scripts/setup_sparkle.sh
#
# Downloads and extracts to external/:
#   external/Sparkle.framework  — the framework to link against
#   external/bin/               — CLI tools (sign_update, generate_keys)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTERNAL_DIR="$ROOT_DIR/external"
SPARKLE_VERSION="2.8.0"
SPARKLE_FRAMEWORK="$EXTERNAL_DIR/Sparkle.framework"

echo "=== Setting up Sparkle $SPARKLE_VERSION ==="

# Only run on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: Sparkle is macOS-only. Skipping on $(uname)."
    exit 0
fi

# Check if already present
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle framework already present at $SPARKLE_FRAMEWORK"
    echo "To re-download, remove external/Sparkle.framework and run again."
    exit 0
fi

mkdir -p "$EXTERNAL_DIR"

SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
DOWNLOAD_FILE="$EXTERNAL_DIR/sparkle-$SPARKLE_VERSION.tar.xz"

echo "Downloading Sparkle $SPARKLE_VERSION..."
curl -fSL "$SPARKLE_URL" -o "$DOWNLOAD_FILE"

echo "Extracting..."
cd "$EXTERNAL_DIR"

# Remove any previous partial extraction
rm -rf Sparkle.framework bin Symbols sparkle.app "Sparkle Test App.app" \
       CHANGELOG INSTALL LICENSE SampleAppcast.xml

tar -xf "sparkle-$SPARKLE_VERSION.tar.xz"
rm -f "sparkle-$SPARKLE_VERSION.tar.xz"

# Sparkle 2.8.0 extracts directly into external/:
#   Sparkle.framework, bin/, Symbols/, sparkle.app, etc.

# Verify extraction
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle framework verified at: $SPARKLE_FRAMEWORK"
else
    echo "Error: Expected framework not found at $SPARKLE_FRAMEWORK"
    echo "Contents of external/:"
    ls -la "$EXTERNAL_DIR/" 2>/dev/null || echo "(empty)"
    exit 1
fi

# Check for key tools
SIGN_UPDATE="$EXTERNAL_DIR/bin/sign_update"
GENERATE_KEYS="$EXTERNAL_DIR/bin/generate_keys"

if [[ -x "$SIGN_UPDATE" ]]; then
    echo "sign_update tool found (for EdDSA signing at publish time)"
else
    echo "Warning: sign_update tool not found at $SIGN_UPDATE"
fi

if [[ -x "$GENERATE_KEYS" ]]; then
    echo "generate_keys tool found (for EdDSA key generation)"
else
    echo "Warning: generate_keys tool not found at $GENERATE_KEYS"
fi

echo ""
echo "=== Sparkle $SPARKLE_VERSION setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Generate EdDSA keys:  $GENERATE_KEYS"
echo "  2. Add public key to .env as AUTO_UPDATE_EDDSA_PUBLIC_KEY"
echo "  3. Rebuild with ENABLE_AUTO_UPDATE=true"

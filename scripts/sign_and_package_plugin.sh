#!/bin/bash
set -e

# === Load environment ===
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Missing .env file. Please create one based on .env.example"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

REQUIRED_VARS=(PROJECT_NAME APPLE_ID APP_SPECIFIC_PASSWORD APP_CERT INSTALLER_CERT)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ $var is not set in .env"
    exit 1
  fi
done

# === Phase 1: Optional Installer Assets Detection ===
INSTALLER_DIR="${ROOT_DIR}/installer"
OPTIONAL_ASSETS=()
USE_CUSTOM_INSTALLER=false

echo "🔍 Detecting optional installer assets..."

# Check for Welcome screen
if [ -f "${INSTALLER_DIR}/Welcome.txt" ]; then
  echo "✅ Found Welcome.txt - will include welcome screen"
  OPTIONAL_ASSETS+=("Welcome.txt")
  USE_CUSTOM_INSTALLER=true
else
  echo "ℹ️  Welcome.txt not found (rename Welcome.txt.example to enable)"
fi

# Check for Terms & Conditions
if [ -f "${INSTALLER_DIR}/TERMS.txt" ]; then
  echo "✅ Found TERMS.txt - will include terms & conditions"
  OPTIONAL_ASSETS+=("TERMS.txt")
  USE_CUSTOM_INSTALLER=true
else
  echo "ℹ️  TERMS.txt not found (rename TERMS.txt.example to enable)"
fi

# Check for custom distribution XML
if [ -f "${INSTALLER_DIR}/distribution.xml" ]; then
  echo "✅ Found distribution.xml - will use custom installer configuration"
  OPTIONAL_ASSETS+=("distribution.xml")
  USE_CUSTOM_INSTALLER=true
else
  echo "ℹ️  distribution.xml not found (rename distribution.xml.example to enable)"
fi

# Check for postinstall script
if [ -f "${INSTALLER_DIR}/postinstall" ]; then
  echo "✅ Found postinstall script - will include post-installation logic"
  OPTIONAL_ASSETS+=("postinstall")
  USE_CUSTOM_INSTALLER=true
else
  echo "ℹ️  postinstall script not found (rename postinstall.example to enable)"
fi

if [ "$USE_CUSTOM_INSTALLER" = true ]; then
  echo "🎨 Custom installer assets detected: ${OPTIONAL_ASSETS[*]}"
else
  echo "📦 Using basic installer (no optional assets found)"
fi

COMPONENT_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
DESKTOP="$HOME/Desktop"
ZIP_PATH="${DESKTOP}/${PROJECT_NAME}.zip"
PKG_PATH="${DESKTOP}/${PROJECT_NAME}.pkg"
DMG_PATH="${DESKTOP}/${PROJECT_NAME}.dmg"
STAGING_DMG_DIR="${DESKTOP}/${PROJECT_NAME}_Installer"

echo "🔏 Signing component..."
codesign --timestamp --options runtime --force --deep \
  --sign "$APP_CERT" "$COMPONENT_PATH"

echo "📦 Creating ZIP for notarization..."
cd "$(dirname "$COMPONENT_PATH")"
ditto -c -k --sequesterRsrc --keepParent "${PROJECT_NAME}.component" "$ZIP_PATH"

echo "☁️ Notarizing ZIP..."
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "📎 Stapling component..."
cd "$DESKTOP"
unzip -o "$ZIP_PATH"
xcrun stapler staple "${PROJECT_NAME}.component"

echo "📦 Building .pkg installer..."
if [ "$USE_CUSTOM_INSTALLER" = true ] && [ -f "${INSTALLER_DIR}/distribution.xml" ]; then
  echo "🎨 Using custom distribution.xml for advanced installer features"
  # Create temporary distribution file with PROJECT_NAME substitution
  TEMP_DIST="/tmp/${PROJECT_NAME}_distribution.xml"
  sed "s/\[PROJECT_NAME\]/${PROJECT_NAME}/g" "${INSTALLER_DIR}/distribution.xml" > "$TEMP_DIST"
  
  # Build with custom distribution
  productbuild --distribution "$TEMP_DIST" \
    --package-path "$DESKTOP" \
    --resources "$INSTALLER_DIR" \
    --sign "$INSTALLER_CERT" "$PKG_PATH"
  
  rm -f "$TEMP_DIST"
else
  # Standard build
  productbuild \
    --component "${COMPONENT_PATH}" /Library/Audio/Plug-Ins/Components \
    --sign "$INSTALLER_CERT" "$PKG_PATH"
fi

echo "☁️ Notarizing .pkg..."
xcrun notarytool submit "$PKG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "📎 Stapling .pkg..."
xcrun stapler staple "$PKG_PATH"

# === Phase 5 Enhancement: Uninstaller Script Support ===
# Check for uninstaller script
if [ -f "${INSTALLER_DIR}/uninstall_plugin.sh" ]; then
  echo "✅ Found uninstall_plugin.sh - will include in DMG"
  OPTIONAL_ASSETS+=("uninstall_plugin.sh")
  USE_UNINSTALLER=true
else
  echo "ℹ️  uninstall_plugin.sh not found (create installer/uninstall_plugin.sh to enable)"
  USE_UNINSTALLER=false
fi

# === Phase 5 Enhancement: DMG Creation with Uninstaller ===
echo "💽 Creating DMG with .pkg inside..."
mkdir -p "$STAGING_DMG_DIR"
cp "$PKG_PATH" "$STAGING_DMG_DIR/"

# Include uninstaller if present
if [ "$USE_UNINSTALLER" = true ]; then
  echo "📦 Including uninstaller script in DMG..."
  cp "${INSTALLER_DIR}/uninstall_plugin.sh" "$STAGING_DMG_DIR/"
  chmod +x "$STAGING_DMG_DIR/uninstall_plugin.sh"
fi

hdiutil create -volname "${PROJECT_NAME} Installer" \
  -srcfolder "$STAGING_DMG_DIR" \
  -ov -format UDZO "$DMG_PATH"

# === Phase 5 Enhancement: Optional DMG Zipping ===
ZIP_DMG=${ZIP_DMG:-true}  # Default to true, can be overridden in .env
if [ "$ZIP_DMG" = true ]; then
  echo "🗜️  Zipping DMG for distribution..."
  DMG_ZIP_PATH="${DESKTOP}/${PROJECT_NAME}_DMG.zip"
  ditto -c -k --sequesterRsrc --keepParent "$(basename "$DMG_PATH")" "$DMG_ZIP_PATH"
  echo "✅ DMG zipped: $DMG_ZIP_PATH"
fi

# === Phase 5 Enhancement: Optional PKG Zipping ===
ZIP_PKG=${ZIP_PKG:-false}  # Default to false, can be enabled in .env
if [ "$ZIP_PKG" = true ]; then
  echo "🗜️  Zipping PKG for distribution..."
  PKG_ZIP_PATH="${DESKTOP}/${PROJECT_NAME}_PKG.zip"
  ditto -c -k --sequesterRsrc --keepParent "$(basename "$PKG_PATH")" "$PKG_ZIP_PATH"
  echo "✅ PKG zipped: $PKG_ZIP_PATH"
fi

rm -rf "$STAGING_DMG_DIR"

echo ""
echo "✅ DONE!"
echo "• Notarized .zip: $ZIP_PATH"
echo "• Notarized .pkg: $PKG_PATH"
echo "• Distributable .dmg: $DMG_PATH"
if [ "$ZIP_DMG" = true ]; then
  echo "• Zipped DMG: $DMG_ZIP_PATH"
fi
if [ "$ZIP_PKG" = true ]; then
  echo "• Zipped PKG: $PKG_ZIP_PATH"
fi
if [ "$USE_CUSTOM_INSTALLER" = true ]; then
  echo "• Custom installer features: ${OPTIONAL_ASSETS[*]}"
fi
if [ "$USE_UNINSTALLER" = true ]; then
  echo "• Uninstaller included in DMG"
fi
echo ""

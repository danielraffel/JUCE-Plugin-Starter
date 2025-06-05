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
productbuild \
  --component "${COMPONENT_PATH}" /Library/Audio/Plug-Ins/Components \
  --sign "$INSTALLER_CERT" "$PKG_PATH"

echo "☁️ Notarizing .pkg..."
xcrun notarytool submit "$PKG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "📎 Stapling .pkg..."
xcrun stapler staple "$PKG_PATH"

echo "💽 Creating DMG with .pkg inside..."
mkdir -p "$STAGING_DMG_DIR"
cp "$PKG_PATH" "$STAGING_DMG_DIR/"

hdiutil create -volname "${PROJECT_NAME} Installer" \
  -srcfolder "$STAGING_DMG_DIR" \
  -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING_DMG_DIR"

echo ""
echo "✅ DONE!"
echo "• Notarized .zip: $ZIP_PATH"
echo "• Notarized .pkg: $PKG_PATH"
echo "• Distributable .dmg: $DMG_PATH"
echo ""

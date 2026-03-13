#!/bin/bash
# Strict mode
set -euo pipefail

# Log script execution start and arguments for debugging
echo "🚀 Starting post-build script..."
echo "PID: $$"
echo "Arguments: $@"
echo "Current directory: $(pwd)"
echo "Script path: $0"

# Expect the component path as the first argument
if [ -z "$1" ]; then
  echo "❌ Error: Component path argument is missing."
  exit 1
fi
component_path="$1"
echo "Component path from arg: $component_path"

# Define the Info.plist path
info_plist="$component_path/Contents/Info.plist"
echo "Info.plist path: $info_plist"

# Check that Info.plist exists
echo "🔍 Checking for Info.plist..."
if [ ! -f "$info_plist" ]; then
  echo "❌ Error: Info.plist not found at $info_plist"
  # Attempt to list parent directory contents for debugging
  echo "Contents of $component_path/Contents/:"; ls -la "$component_path/Contents/" || echo "Could not list $component_path/Contents/"
  echo "Contents of $component_path/": ls -la "$component_path/" || echo "Could not list $component_path/"
  exit 1
fi
echo "✅ Info.plist found."

# Try to read project name from plist
project_name_plist=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null || echo "UnknownPlistReadError")

project_name=""
if [ "$project_name_plist" != "UnknownPlistReadError" ] && [ -n "$project_name_plist" ]; then
  project_name="$project_name_plist (from plist)"
elif [ -n "${PROJECT_NAME_FROM_CMAKE:-}" ]; then # Use :- to avoid unbound variable error if not set
  project_name="$PROJECT_NAME_FROM_CMAKE (from env PROJECT_NAME_FROM_CMAKE)"
elif [ -n "${PROJECT_NAME:-}" ]; then # Generic PROJECT_NAME from Xcode build env
  project_name="$PROJECT_NAME (from env PROJECT_NAME)"
else
  project_name="Unknown (Not found in plist or env)"
fi
echo "📛 Project name: $project_name"

# --- Versioning Configuration ---
# Determine the project root directory relative to the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR="${SCRIPT_DIR}/.."
VERSION_CONFIG_FILE="${PROJECT_ROOT_DIR}/.env"

# Default base version if config file or variable is not found
DEFAULT_BASE_VERSION="0.1." # Defaulting to something like "0.1."
BASE_VERSION_FROM_FILE=""

if [ -f "$VERSION_CONFIG_FILE" ]; then
  echo "ℹ️ Reading version from: $VERSION_CONFIG_FILE"
  # Read semantic version components
  VERSION_MAJOR=$(grep -E "^VERSION_MAJOR=" "$VERSION_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  VERSION_MINOR=$(grep -E "^VERSION_MINOR=" "$VERSION_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  VERSION_PATCH=$(grep -E "^VERSION_PATCH=" "$VERSION_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  
  if [ -n "$VERSION_MAJOR" ] && [ -n "$VERSION_MINOR" ] && [ -n "$VERSION_PATCH" ]; then
    VERSION_SHORT="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
    echo "✅ Version loaded from file: $VERSION_SHORT"
  else
    # Fall back to old format if new format not found
    config_value=$(grep -E "^BASE_PROJECT_VERSION=" "$VERSION_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -n "$config_value" ]; then
      BASE_VERSION_FROM_FILE="$config_value"
      echo "✅ Base version loaded from file: $BASE_VERSION_FROM_FILE"
      TIMESTAMP=$(date +'%y%m%d%H%M')
      VERSION_SHORT="${BASE_VERSION_FROM_FILE}${TIMESTAMP}"
    else
      echo "⚠️ Version not found in $VERSION_CONFIG_FILE."
      VERSION_SHORT="$DEFAULT_BASE_VERSION"
    fi
  fi
else
  echo "⚠️ Version config file not found: $VERSION_CONFIG_FILE."
  VERSION_SHORT="$DEFAULT_BASE_VERSION"
fi

# For semantic versioning, use the version as-is
VERSION_SHORT_WITH_TIMESTAMP="$VERSION_SHORT"
VERSION_BUNDLE="$VERSION_SHORT"

echo "ℹ️ Final CFBundleShortVersionString: $VERSION_SHORT_WITH_TIMESTAMP"
echo "ℹ️ Final CFBundleVersion: $VERSION_BUNDLE"
# --- End Versioning Configuration ---

# --- Update CFBundleShortVersionString ---
echo "🚀 Attempting to Add/Set CFBundleShortVersionString to $VERSION_SHORT_WITH_TIMESTAMP..."
if ! /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION_SHORT_WITH_TIMESTAMP" "$info_plist" 2>/dev/null; then
  echo "ℹ️ Add CFBundleShortVersionString failed (key might already exist or other issue), attempting Set..."
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_SHORT_WITH_TIMESTAMP" "$info_plist"
fi
update_status_short=$?

if [ $update_status_short -ne 0 ]; then
  echo "❌ Error: PlistBuddy failed to update CFBundleShortVersionString. Exit code: $update_status_short"
  exit $update_status_short
fi
echo "✅ CFBundleShortVersionString updated to $VERSION_SHORT_WITH_TIMESTAMP successfully."

# --- Update CFBundleVersion ---
echo "🚀 Attempting to Add/Set CFBundleVersion to $VERSION_BUNDLE..."
if ! /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION_BUNDLE" "$info_plist" 2>/dev/null; then
  echo "ℹ️ Add CFBundleVersion failed (key might already exist or other issue), attempting Set..."
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_BUNDLE" "$info_plist"
fi
update_status_bundle=$?

if [ $update_status_bundle -ne 0 ]; then
  echo "❌ Error: PlistBuddy failed to update CFBundleVersion. Exit code: $update_status_bundle"
  exit $update_status_bundle
fi
echo "✅ CFBundleVersion updated to $VERSION_BUNDLE successfully."

# --- Sparkle Auto-Update Info.plist Entries (Standalone only) ---
# Only add Sparkle keys if auto-update is enabled and this is a Standalone app bundle
if [ "${ENABLE_AUTO_UPDATE:-false}" = "true" ]; then
  # Check if this looks like a Standalone app (has a MacOS executable, not a plugin)
  if [ -d "$component_path/Contents/MacOS" ] && [[ "$component_path" != *".component"* ]] && [[ "$component_path" != *".vst3"* ]]; then
    echo "🔄 Adding Sparkle auto-update entries to Info.plist..."

    # SUFeedURL — appcast feed URL for macOS
    FEED_URL="${AUTO_UPDATE_FEED_URL_MACOS:-}"
    if [ -n "$FEED_URL" ]; then
      /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $FEED_URL" "$info_plist" 2>/dev/null || \
      /usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED_URL" "$info_plist"
      echo "  ✅ SUFeedURL = $FEED_URL"
    else
      echo "  ⚠️ AUTO_UPDATE_FEED_URL_MACOS not set — SUFeedURL skipped"
    fi

    # SUPublicEDKey — EdDSA public key for signature verification
    EDDSA_KEY="${AUTO_UPDATE_EDDSA_PUBLIC_KEY:-}"
    if [ -n "$EDDSA_KEY" ]; then
      /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $EDDSA_KEY" "$info_plist" 2>/dev/null || \
      /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $EDDSA_KEY" "$info_plist"
      echo "  ✅ SUPublicEDKey set"
    else
      echo "  ⚠️ AUTO_UPDATE_EDDSA_PUBLIC_KEY not set — SUPublicEDKey skipped"
    fi

    # SUEnableAutomaticChecks — enable automatic background checks
    /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$info_plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks true" "$info_plist"
    echo "  ✅ SUEnableAutomaticChecks = true"
  fi
fi

echo "🎉 Post-build script finished successfully."
echo "📛 Project name: $project_name"
echo "🔍 Final Info.plist version strings:"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist"

echo "🔧 Post-build script finished."

# --- Copy to System Plug-Ins Directory ---
# The component_path variable already holds the path to the .component bundle in the build directory.
# Example: /Users/danielraffel/Code/PlunderTube/build/PlunderTube_artefacts/Debug/AU/PlunderTube.component

# Extract the component name (e.g., PlunderTube.component) from the component_path
COMPONENT_NAME=$(basename "${component_path}")

# Define the destination directory for AU plugins
DEST_DIR="$HOME/Library/Audio/Plug-Ins/Components/"

echo "ℹ️  Attempting to copy ${COMPONENT_NAME} from ${component_path} to ${DEST_DIR}"

# Ensure the destination directory exists
mkdir -p "${DEST_DIR}"

# Copy the entire .component bundle using rsync
# rsync is generally good for this as it handles directory contents well and can be efficient.
# The trailing slash on the source path is important for rsync to copy the *contents* of the source directory.
if rsync -av --delete "${component_path}/" "${DEST_DIR}${COMPONENT_NAME}/"; then
    echo "✅ Successfully copied ${COMPONENT_NAME} to ${DEST_DIR}"
    echo "🔔 For Logic Pro, you may need to open Plugin Manager and 'Reset & Rescan' ${PROJECT_NAME_FROM_CMAKE:-PlunderTube}."
else
    echo "❌ Error: Failed to copy ${COMPONENT_NAME} to ${DEST_DIR}. rsync exit code: $?"
    # Decide if this should be a fatal error for the build
    # exit 1 
fi

echo "🎉 All post-build operations complete."

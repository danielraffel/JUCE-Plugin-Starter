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
  echo "ℹ️ Reading base version from: $VERSION_CONFIG_FILE"
  # Source the file in a way that we can capture the specific variable
  # Ensure the variable name in the file is BASE_PROJECT_VERSION
  # Example content in .env: BASE_PROJECT_VERSION="1.0."
  config_value=$(grep -E "^BASE_PROJECT_VERSION=" "$VERSION_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  if [ -n "$config_value" ]; then
    BASE_VERSION_FROM_FILE="$config_value"
    echo "✅ Base version loaded from file: $BASE_VERSION_FROM_FILE"
  else
    echo "⚠️ BASE_PROJECT_VERSION not found or empty in $VERSION_CONFIG_FILE."
  fi
else
  echo "⚠️ Version config file not found: $VERSION_CONFIG_FILE."
fi

# Use loaded version or default
if [ -n "$BASE_VERSION_FROM_FILE" ]; then
  VERSION_SHORT="$BASE_VERSION_FROM_FILE"
else
  VERSION_SHORT="$DEFAULT_BASE_VERSION"
  echo "ℹ️ Using default base version: $VERSION_SHORT"
fi

# Generate dynamic bundle version with timestamp (YYMMDDHHMM)
# If VERSION_SHORT is "1.0.", we append the date. Example: "1.0.2505301505"
TIMESTAMP=$(date +'%y%m%d%H%M')
VERSION_BUNDLE="${VERSION_SHORT}${TIMESTAMP}"

echo "ℹ️ Final CFBundleShortVersionString: $VERSION_SHORT"
echo "ℹ️ Final CFBundleVersion: $VERSION_BUNDLE"
# --- End Versioning Configuration ---

# --- Update CFBundleShortVersionString ---
echo "🚀 Attempting to Add/Set CFBundleShortVersionString to $VERSION_SHORT..."
if ! /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION_SHORT" "$info_plist" 2>/dev/null; then
  echo "ℹ️ Add CFBundleShortVersionString failed (key might already exist or other issue), attempting Set..."
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_SHORT" "$info_plist"
fi
update_status_short=$?

if [ $update_status_short -ne 0 ]; then
  echo "❌ Error: PlistBuddy failed to update CFBundleShortVersionString. Exit code: $update_status_short"
  exit $update_status_short
fi
echo "✅ CFBundleShortVersionString updated to $VERSION_SHORT successfully."

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

echo "🎉 Post-build script finished successfully."
echo "📛 Project name: $project_name"
echo "🔍 Final Info.plist version strings:"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist"

echo "🔧 Post-build script finished."

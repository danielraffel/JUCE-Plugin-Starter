#!/bin/bash
set -e

component_path="$1"
info_plist="$component_path/Contents/Info.plist"

echo "🔧 Post-build script running..."
echo "📦 Component path received: $component_path"
echo "📝 Looking for Info.plist at: $info_plist"

# Check that Info.plist exists
if [ ! -f "$info_plist" ]; then
  echo "❌ Error: Info.plist not found at $info_plist"
  exit 1
fi

# Optional: Read project name from plist if needed
project_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null || echo "Unknown")

# Optionally extract from env (fallback)
if [ "$project_name" = "Unknown" ] && [ -n "$PROJECT_NAME" ]; then
  project_name="$PROJECT_NAME"
fi

echo "📛 Project name: $project_name"

# Update version string
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.0" "$info_plist"

echo "✅ Version updated in Info.plist for $project_name"

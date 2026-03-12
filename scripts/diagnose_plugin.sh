#!/bin/bash

# ============================================================================
# Plugin Diagnostic Script for macOS Audio Units
# ============================================================================
# 
# INSTRUCTIONS FOR RUNNING:
# 1. Open Terminal app (find it in Applications > Utilities)
# 2. Navigate to where you downloaded this script:
#    cd ~/Downloads
# 3. Make the script executable:
#    chmod +x diagnose_plugin.sh
# 4. Run the script:
#    ./diagnose_plugin.sh
# 5. The script will create a diagnostic log file on your Desktop
# 6. Share the log file with the developer for analysis
#
# ============================================================================

# Load environment variables to get project name
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
    PLUGIN_NAME="$PROJECT_NAME"
else
    echo "❌ .env file not found. Please run from project root directory."
    exit 1
fi

# Configuration
LOG_FILE="$HOME/Desktop/${PLUGIN_NAME}_diagnostic_$(date +%Y%m%d_%H%M%S).log"
COMPONENT_PATH="/Library/Audio/Plug-Ins/Components/${PLUGIN_NAME}.component"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "============================================================================"
echo " ${PLUGIN_NAME} Plugin Diagnostic Report"
echo " Generated: $(date)"
echo " macOS Version: $(sw_vers -productVersion)"
echo " Architecture: $(uname -m)"
echo "============================================================================"
echo ""

# 1. Check if plugin exists
echo "=== 1. PLUGIN LOCATION CHECK ==="
if [ -d "$COMPONENT_PATH" ]; then
    echo "✅ Plugin found at: $COMPONENT_PATH"
    echo "   Size: $(du -sh "$COMPONENT_PATH" | cut -f1)"
    echo "   Modified: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$COMPONENT_PATH")"
else
    echo "❌ Plugin NOT found at expected location: $COMPONENT_PATH"
    echo "   Checking alternate locations..."
    
    # Check user library
    USER_COMPONENT="$HOME/Library/Audio/Plug-Ins/Components/${PLUGIN_NAME}.component"
    if [ -d "$USER_COMPONENT" ]; then
        echo "   ⚠️  Found in user library: $USER_COMPONENT"
        echo "   Note: Some DAWs don't scan user library by default"
        COMPONENT_PATH="$USER_COMPONENT"
    else
        echo "   ❌ Not found in user library either"
    fi
fi
echo ""

# 2. Check file permissions
echo "=== 2. FILE PERMISSIONS ==="
if [ -d "$COMPONENT_PATH" ]; then
    echo "Plugin permissions:"
    ls -la "$COMPONENT_PATH" | head -5
    echo ""
    echo "Contents/MacOS binary permissions:"
    ls -la "$COMPONENT_PATH/Contents/MacOS/" 2>/dev/null | head -3
else
    echo "❌ Cannot check permissions - plugin not found"
fi
echo ""

# 3. Check code signature
echo "=== 3. CODE SIGNATURE CHECK ==="
if [ -d "$COMPONENT_PATH" ]; then
    echo "Basic signature check:"
    codesign -v "$COMPONENT_PATH" 2>&1
    
    echo ""
    echo "Detailed signature info:"
    codesign -dvv "$COMPONENT_PATH" 2>&1 | head -20
    
    echo ""
    echo "Signature verification:"
    codesign --verify --deep --verbose=2 "$COMPONENT_PATH" 2>&1
    
    echo ""
    echo "Checking notarization status:"
    spctl -a -vvv -t install "$COMPONENT_PATH" 2>&1
else
    echo "❌ Cannot check signature - plugin not found"
fi
echo ""

# 4. Check for quarantine flags
echo "=== 4. QUARANTINE STATUS ==="
if [ -d "$COMPONENT_PATH" ]; then
    echo "Checking for quarantine attributes..."
    xattr -l "$COMPONENT_PATH" 2>/dev/null | grep -i quarantine
    if [ $? -eq 0 ]; then
        echo "⚠️  Quarantine flag detected! This prevents the plugin from loading."
        echo "   To remove quarantine, run:"
        echo "   sudo xattr -r -d com.apple.quarantine '$COMPONENT_PATH'"
    else
        echo "✅ No quarantine flags found"
    fi
    
    echo ""
    echo "All extended attributes:"
    xattr -l "$COMPONENT_PATH" 2>/dev/null | head -20
else
    echo "❌ Cannot check quarantine - plugin not found"
fi
echo ""

# 5. Check plugin Info.plist
echo "=== 5. PLUGIN INFO.PLIST ==="
if [ -f "$COMPONENT_PATH/Contents/Info.plist" ]; then
    echo "Key plugin information:"
    defaults read "$COMPONENT_PATH/Contents/Info.plist" CFBundleIdentifier 2>/dev/null && echo ""
    defaults read "$COMPONENT_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null && echo ""
    defaults read "$COMPONENT_PATH/Contents/Info.plist" AudioComponents 2>/dev/null | head -30
else
    echo "❌ Info.plist not found or not readable"
fi
echo ""

# 6. Check Audio Unit validation
echo "=== 6. AUDIO UNIT VALIDATION ==="
echo "Running AU validation (this may take a moment)..."
if [ -d "$COMPONENT_PATH" ]; then
    # Get the component type and manufacturer from Info.plist
    if [ -f "$COMPONENT_PATH/Contents/Info.plist" ]; then
        # Try to extract AU info
        AU_TYPE=$(defaults read "$COMPONENT_PATH/Contents/Info.plist" AudioComponents 2>/dev/null | grep -A1 "type =" | tail -1 | sed 's/.*= //;s/;//')
        AU_SUBTYPE=$(defaults read "$COMPONENT_PATH/Contents/Info.plist" AudioComponents 2>/dev/null | grep -A1 "subtype =" | tail -1 | sed 's/.*= //;s/;//')
        AU_MANUFACTURER=$(defaults read "$COMPONENT_PATH/Contents/Info.plist" AudioComponents 2>/dev/null | grep -A1 "manufacturer =" | tail -1 | sed 's/.*= //;s/;//')
        
        if [ -n "$AU_TYPE" ] && [ -n "$AU_SUBTYPE" ] && [ -n "$AU_MANUFACTURER" ]; then
            echo "Testing: $AU_TYPE $AU_SUBTYPE $AU_MANUFACTURER"
            auval -v "$AU_TYPE" "$AU_SUBTYPE" "$AU_MANUFACTURER" 2>&1 | tail -50
        else
            echo "⚠️  Could not extract AU component info from Info.plist"
            echo "Attempting generic validation..."
            auval -a 2>&1 | grep -i "$PLUGIN_NAME"
        fi
    fi
else
    echo "❌ Cannot validate - plugin not found"
fi
echo ""

# 7. Check system integrity protection and security settings
echo "=== 7. SYSTEM SECURITY SETTINGS ==="
echo "Gatekeeper status:"
spctl --status 2>&1

echo ""
echo "Security assessment policy:"
sudo spctl --assess --type install "$COMPONENT_PATH" 2>&1

echo ""
echo "System Integrity Protection status:"
csrutil status 2>&1
echo ""

# 8. Check for missing dependencies
echo "=== 8. DEPENDENCY CHECK ==="
if [ -f "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}" ]; then
    echo "Checking linked libraries:"
    otool -L "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}" 2>&1 | head -30
    
    echo ""
    echo "Checking for missing dependencies:"
    otool -L "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}" 2>&1 | grep -E "@rpath|@executable_path|@loader_path" | while read -r line; do
        lib=$(echo "$line" | awk '{print $1}')
        echo "  Checking: $lib"
    done
else
    echo "❌ Binary not found at expected location"
fi
echo ""

# 9. Check Audio Unit cache
echo "=== 9. AUDIO UNIT CACHE ==="
echo "Checking AU cache status..."
AU_CACHE="$HOME/Library/Caches/AudioUnitCache"
if [ -d "$AU_CACHE" ]; then
    echo "AU Cache exists at: $AU_CACHE"
    echo "Cache files:"
    ls -la "$AU_CACHE" 2>/dev/null | head -10
    
    echo ""
    echo "Searching for ${PLUGIN_NAME} in cache:"
    grep -l "${PLUGIN_NAME}" "$AU_CACHE"/* 2>/dev/null | head -5
    
    echo ""
    echo "💡 TIP: If the plugin isn't loading, try clearing the AU cache:"
    echo "   rm -rf ~/Library/Caches/AudioUnitCache/*"
    echo "   Then restart Logic Pro"
else
    echo "AU Cache directory not found"
fi
echo ""

# 10. Check Logic Pro specific settings
echo "=== 10. LOGIC PRO SPECIFIC ==="
echo "Checking Logic Pro plugin manager cache..."
LOGIC_CACHE="$HOME/Library/Caches/com.apple.logic10"
if [ -d "$LOGIC_CACHE" ]; then
    echo "Logic cache exists"
    echo "💡 TIP: Reset Logic's plugin cache by:"
    echo "   1. Quit Logic Pro"
    echo "   2. Hold Control+Option while launching Logic"
    echo "   3. Choose 'Rescan All' when prompted"
else
    echo "Logic Pro cache not found (Logic may not be installed or hasn't been run)"
fi

echo ""
echo "Checking for Logic Pro preferences that might block plugins..."
LOGIC_PREFS="$HOME/Library/Preferences/com.apple.logic10.plist"
if [ -f "$LOGIC_PREFS" ]; then
    echo "Logic preferences file exists"
    # Check if plugin is in any block lists
    defaults read com.apple.logic10 2>/dev/null | grep -i "$PLUGIN_NAME" | head -5
fi
echo ""

# 11. Component architecture check
echo "=== 11. ARCHITECTURE COMPATIBILITY ==="
if [ -f "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}" ]; then
    echo "Plugin architecture:"
    file "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}"
    lipo -info "$COMPONENT_PATH/Contents/MacOS/${PLUGIN_NAME}" 2>&1
    
    echo ""
    echo "System architecture: $(uname -m)"
    echo "Logic Pro architecture requirement: arm64 (Apple Silicon) or x86_64 (Intel)"
else
    echo "❌ Cannot check architecture - binary not found"
fi
echo ""

# 12. Check for crash logs
echo "=== 12. RECENT CRASH LOGS ==="
echo "Checking for recent Audio Unit or Logic Pro crashes..."
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    echo "Recent AU-related crashes (last 7 days):"
    find "$CRASH_DIR" -name "*Audio*" -o -name "*Logic*" -o -name "*${PLUGIN_NAME}*" -mtime -7 2>/dev/null | while read -r crash; do
        echo "  - $(basename "$crash") ($(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$crash"))"
    done
else
    echo "Diagnostic reports directory not found"
fi
echo ""

# 13. Manual validation command
echo "=== 13. MANUAL VALIDATION STEPS ==="
echo "If automatic validation failed, try these manual steps:"
echo ""
echo "1. Kill Audio Unit daemon and clear cache:"
echo "   killall -9 AudioComponentRegistrar"
echo "   rm -rf ~/Library/Caches/AudioUnitCache"
echo ""
echo "2. Force rescan of Audio Units:"
echo "   auval -a"
echo ""
echo "3. Remove quarantine if present:"
echo "   sudo xattr -cr '$COMPONENT_PATH'"
echo ""
echo "4. Reset Logic Pro:"
echo "   - Hold Control+Option while launching Logic"
echo "   - Select 'Rescan All'"
echo ""

# 14. Summary and recommendations
echo "============================================================================"
echo " DIAGNOSTIC SUMMARY"
echo "============================================================================"
echo ""

# Analyze results and provide recommendations
if [ ! -d "$COMPONENT_PATH" ]; then
    echo "❌ CRITICAL: Plugin not installed in the correct location"
    echo "   ACTION: Reinstall the plugin"
elif ! codesign -v "$COMPONENT_PATH" 2>/dev/null; then
    echo "❌ CRITICAL: Code signature invalid or missing"
    echo "   ACTION: The plugin needs to be properly signed by the developer"
elif xattr -l "$COMPONENT_PATH" 2>/dev/null | grep -q quarantine; then
    echo "⚠️  WARNING: Plugin is quarantined"
    echo "   ACTION: Run: sudo xattr -cr '$COMPONENT_PATH'"
else
    echo "✅ Plugin appears to be properly installed and signed"
    echo "   If still not working:"
    echo "   1. Clear AU cache: rm -rf ~/Library/Caches/AudioUnitCache"
    echo "   2. Restart Logic with Control+Option held down"
    echo "   3. Select 'Rescan All' when prompted"
fi

echo ""
echo "============================================================================"
echo " Log file saved to: $LOG_FILE"
echo " Please share this file with the plugin developer for further analysis"
echo "============================================================================"
#!/bin/bash

# {{PROJECT_NAME}} Uninstaller - Dual Mode
# Supports both repair/reinstall and complete uninstall with receipt handling

set -e

# Check for admin privileges FIRST, before any user interaction
# This prevents the script from restarting and losing user choices
if [ "$EUID" -ne 0 ]; then
    if [ -t 0 ]; then
        # Running in terminal - use sudo
        echo "Administrator privileges required for {{PROJECT_NAME}} uninstaller."
        echo "You will be prompted for your password..."
        echo ""
        exec sudo "$0" "$@"
    else
        # Running from Finder - use osascript for GUI password prompt
        osascript -e "do shell script \"$0 $*\" with administrator privileges"
        exit $?
    fi
fi

# Parse command-line arguments for non-interactive mode
NON_INTERACTIVE=false
MODE=""
SKIP_BACKUP=true  # Default to no backup in non-interactive mode

while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive|--force)
            NON_INTERACTIVE=true
            shift
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        --backup)
            SKIP_BACKUP=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--non-interactive] [--mode=repair|uninstall] [--backup]"
            exit 1
            ;;
    esac
done

# Only show banner in interactive mode
if [ "$NON_INTERACTIVE" = false ]; then
    clear
    echo "{{PROJECT_NAME}} Uninstaller"
    echo "================================"
    echo ""
fi

# Define package receipts
RECEIPTS=(
    "{{PROJECT_BUNDLE_ID}}.core"
    "{{PROJECT_BUNDLE_ID}}.au"
    "{{PROJECT_BUNDLE_ID}}.vst3"
    "{{PROJECT_BUNDLE_ID}}.standalone"
    "{{PROJECT_BUNDLE_ID}}.diagnostics"
)

# Define plugin paths
USER_AU_PATH="$HOME/Library/Audio/Plug-Ins/Components/{{PROJECT_NAME}}.component"
SYSTEM_AU_PATH="/Library/Audio/Plug-Ins/Components/{{PROJECT_NAME}}.component"
USER_VST3_PATH="$HOME/Library/Audio/Plug-Ins/VST3/{{PROJECT_NAME}}.vst3"
SYSTEM_VST3_PATH="/Library/Audio/Plug-Ins/VST3/{{PROJECT_NAME}}.vst3"
USER_CLAP_PATH="$HOME/Library/Audio/Plug-Ins/CLAP/{{PROJECT_NAME}}.clap"
SYSTEM_CLAP_PATH="/Library/Audio/Plug-Ins/CLAP/{{PROJECT_NAME}}.clap"

# Check for folder-based or direct app installation
if [ -d "/Applications/{{PROJECT_NAME}}" ]; then
    # Folder-based installation (multiple apps)
    STANDALONE_PATH="/Applications/{{PROJECT_NAME}}/{{PROJECT_NAME}}.app"
    DIAGNOSTICS_PATH="/Applications/{{PROJECT_NAME}}/{{PROJECT_NAME}} Diagnostics.app"
    APP_FOLDER="/Applications/{{PROJECT_NAME}}"
    USING_FOLDER=true
else
    # Direct installation (single app)
    STANDALONE_PATH="/Applications/{{PROJECT_NAME}}.app"
    DIAGNOSTICS_PATH="/Applications/{{PROJECT_NAME}} Diagnostics.app"
    APP_FOLDER=""
    USING_FOLDER=false
fi

# Define user data paths
APP_SUPPORT_PATH="$HOME/Library/Application Support/{{PROJECT_NAME}}"
LOGS_PATH="$HOME/Library/Logs/{{PROJECT_NAME}}"
CACHE_PATH="$HOME/Library/Caches/{{PROJECT_BUNDLE_ID}}"
INSTALLER_RESOURCES="/tmp/{{PROJECT_NAME}}_installer_resources"

# ============================================================================
# SHARED FUNCTIONS
# ============================================================================

remove_plugins() {
    local removed=0

    echo "🗑️  Removing {{PROJECT_NAME}} plugins..."
    echo ""

    # User Audio Unit
    if [ -e "$USER_AU_PATH" ]; then
        rm -rf "$USER_AU_PATH" && echo "  ✅ Removed: $USER_AU_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $USER_AU_PATH"
    fi

    # System Audio Unit
    if [ -e "$SYSTEM_AU_PATH" ]; then
        rm -rf "$SYSTEM_AU_PATH" && echo "  ✅ Removed: $SYSTEM_AU_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $SYSTEM_AU_PATH"
    fi

    # User VST3
    if [ -e "$USER_VST3_PATH" ]; then
        rm -rf "$USER_VST3_PATH" && echo "  ✅ Removed: $USER_VST3_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $USER_VST3_PATH"
    fi

    # System VST3
    if [ -e "$SYSTEM_VST3_PATH" ]; then
        rm -rf "$SYSTEM_VST3_PATH" && echo "  ✅ Removed: $SYSTEM_VST3_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $SYSTEM_VST3_PATH"
    fi

    # User CLAP
    if [ -e "$USER_CLAP_PATH" ]; then
        rm -rf "$USER_CLAP_PATH" && echo "  ✅ Removed: $USER_CLAP_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $USER_CLAP_PATH"
    fi

    # System CLAP
    if [ -e "$SYSTEM_CLAP_PATH" ]; then
        rm -rf "$SYSTEM_CLAP_PATH" && echo "  ✅ Removed: $SYSTEM_CLAP_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $SYSTEM_CLAP_PATH"
    fi

    # Standalone app
    if [ -e "$STANDALONE_PATH" ]; then
        rm -rf "$STANDALONE_PATH" && echo "  ✅ Removed: $STANDALONE_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $STANDALONE_PATH"
    fi

    # Diagnostics app
    if [ -e "$DIAGNOSTICS_PATH" ]; then
        rm -rf "$DIAGNOSTICS_PATH" && echo "  ✅ Removed: $DIAGNOSTICS_PATH" && ((removed++))
    else
        echo "  ➖ Not found: $DIAGNOSTICS_PATH"
    fi

    # If using folder, remove entire folder after apps
    if [ "$USING_FOLDER" = true ] && [ -d "$APP_FOLDER" ]; then
        # Remove any remaining files in folder
        rm -rf "$APP_FOLDER" && echo "  ✅ Removed: $APP_FOLDER" && ((removed++))
    fi

    echo ""
    echo "  📊 Removed $removed component(s)"
    echo ""
}

clear_au_cache() {
    echo "🧹 Clearing Audio Unit cache..."
    echo ""

    # Kill AudioComponentRegistrar
    if killall -9 AudioComponentRegistrar 2>/dev/null; then
        echo "  ✅ Stopped AudioComponentRegistrar"
    else
        echo "  ➖ AudioComponentRegistrar not running"
    fi

    # Remove AU cache
    if [ -d "$HOME/Library/Caches/AudioUnitCache" ]; then
        rm -rf "$HOME/Library/Caches/AudioUnitCache" && echo "  ✅ Cleared AudioUnitCache"
    else
        echo "  ➖ AudioUnitCache not found"
    fi

    # Remove InfoHelper plist
    if [ -f "$HOME/Library/Preferences/com.apple.audio.InfoHelper.plist" ]; then
        rm -f "$HOME/Library/Preferences/com.apple.audio.InfoHelper.plist" && echo "  ✅ Cleared AU InfoHelper"
    else
        echo "  ➖ AU InfoHelper not found"
    fi

    # Restart coreaudiod
    if sudo killall -9 coreaudiod 2>/dev/null; then
        echo "  ✅ Restarted coreaudiod"
    else
        echo "  ⚠️  Could not restart coreaudiod"
    fi

    echo ""
}

verify_plugins_removed() {
    echo "🔍 Verifying plugins removed..."
    echo ""

    local found=0
    local paths=(
        "$USER_AU_PATH"
        "$SYSTEM_AU_PATH"
        "$USER_VST3_PATH"
        "$SYSTEM_VST3_PATH"
        "$USER_CLAP_PATH"
        "$SYSTEM_CLAP_PATH"
        "$STANDALONE_PATH"
        "$DIAGNOSTICS_PATH"
    )

    if [ "$USING_FOLDER" = true ]; then
        paths+=("$APP_FOLDER")
    fi

    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            echo "  ⚠️  Still exists: $path"
            ((found++))
        fi
    done

    if [ $found -eq 0 ]; then
        echo "  ✅ All plugins removed successfully"
        echo ""
        return 0
    else
        echo ""
        echo "  ⚠️  Warning: $found component(s) still present"
        echo ""
        return 1
    fi
}

verify_receipts_removed() {
    echo "🔍 Verifying receipts forgotten..."
    echo ""

    local found=0

    # Check current scheme receipts
    for receipt in "${RECEIPTS[@]}"; do
        if pkgutil --pkg-info "$receipt" &>/dev/null; then
            echo "  ⚠️  Still present: $receipt"
            ((found++))
        fi
    done

    if [ $found -eq 0 ]; then
        echo "  ✅ All receipts forgotten successfully"
        echo ""
        return 0
    else
        echo ""
        echo "  ⚠️  Warning: $found receipt(s) still present"
        echo ""
        return 1
    fi
}

get_latest_pkg_url() {
    local api_url="https://api.github.com/repos/{{GITHUB_USER}}/{{GITHUB_REPO}}/releases/latest"
    local response
    local pkg_url

    # Try to fetch from GitHub API
    response=$(curl -s "$api_url" 2>/dev/null)

    if [ -n "$response" ]; then
        # Try jq first (more reliable)
        if command -v jq &>/dev/null; then
            pkg_url=$(echo "$response" | jq -r '.assets[] | select(.name | endswith(".pkg")) | .browser_download_url' 2>/dev/null)
        else
            # Fallback to grep/sed
            pkg_url=$(echo "$response" | grep -o '"browser_download_url": "[^"]*\.pkg"' | head -1 | sed 's/.*: "\(.*\)"/\1/')
        fi
    fi

    # Return URL if found, otherwise empty string
    echo "$pkg_url"
}

# ============================================================================
# MODE 1: REPAIR/REINSTALL
# ============================================================================

mode_repair() {
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                      REPAIR/REINSTALL MODE                             ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This mode will:"
    echo "  ✓ Remove all {{PROJECT_NAME}} plugins (AU, VST3, CLAP, Standalone, Diagnostics)"
    echo "  ✓ Clear Audio Unit cache and restart audio services"
    echo "  ✓ Verify clean state"
    echo "  ✓ KEEP package receipts (pkgutil still tracks installation)"
    echo "  ✓ KEEP all user data:"
    echo "    - Settings and presets (~Library/Application Support/{{PROJECT_NAME}})"
    echo "    - Preferences"
    echo "  ✓ Provide link to latest PKG installer"
    echo ""
    echo "⚠️  You will need to reinstall {{PROJECT_NAME}} after this process!"
    echo ""

    # Skip confirmation in non-interactive mode
    if [ "$NON_INTERACTIVE" = false ]; then
        while true; do
            echo -n "Proceed with repair mode? (yes/no): "
            read -r REPLY
            echo ""

            REPLY_LOWER=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')

            case $REPLY_LOWER in
                yes|y)
                    break
                    ;;
                no|n)
                    echo "❌ Repair cancelled."
                    echo ""
                    exit 0
                    ;;
                *)
                    echo "Please answer 'yes' or 'no'."
                    echo ""
                    ;;
            esac
        done
    fi

    echo "🚀 Starting repair process..."
    echo ""

    # Step 1: Remove plugins
    remove_plugins

    # Step 2: Clear AU cache
    clear_au_cache

    # Step 3: Verify clean state
    if ! verify_plugins_removed; then
        echo "⚠️  Warning: Some plugins could not be removed."
        echo "   You may need to remove them manually before reinstalling."
        echo ""
    fi

    # Step 4: Show receipt status (kept)
    echo "📦 Package receipts status:"
    echo ""
    local receipt_count=0
    for receipt in "${RECEIPTS[@]}"; do
        if pkgutil --pkg-info "$receipt" &>/dev/null; then
            echo "  ✅ Kept: $receipt"
            ((receipt_count++))
        fi
    done
    echo ""
    echo "  📊 $receipt_count receipt(s) preserved"
    echo ""

    # Step 5: Show user data status (kept)
    echo "💾 User data status:"
    echo ""
    [ -d "$APP_SUPPORT_PATH" ] && echo "  ✅ Kept: Settings and presets (~Library/Application Support/{{PROJECT_NAME}})"
    echo ""

    # Step 6: Fetch and display latest PKG URL
    echo "📥 Next Steps: Reinstall {{PROJECT_NAME}}"
    echo "════════════════════════════════════"
    echo ""
    echo "Fetching latest installer..."

    pkg_url=$(get_latest_pkg_url)

    if [ -n "$pkg_url" ]; then
        echo ""
        echo "📦 Download the latest PKG installer:"
        echo "   $pkg_url"
        echo ""
        echo "ℹ️  After downloading, run the PKG installer to complete the repair."
    else
        echo ""
        echo "⚠️  Could not fetch latest release automatically."
        echo ""
        echo "📦 Please download the latest PKG manually from:"
        echo "   https://github.com/{{GITHUB_USER}}/{{GITHUB_REPO}}/releases/latest"
        echo ""
        echo "ℹ️  After downloading, run the PKG installer to complete the repair."
    fi

    echo ""
    echo "✅ Repair process complete!"
    echo ""
    echo "Your system is now ready for a clean reinstall."
    echo "{{PROJECT_NAME}} will be fully functional after reinstalling the PKG."
    echo ""
}

# ============================================================================
# MODE 2: COMPLETE UNINSTALL
# ============================================================================

mode_uninstall() {
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                      COMPLETE UNINSTALL MODE                           ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This mode will:"
    echo "  ✓ Remove all {{PROJECT_NAME}} plugins (AU, VST3, CLAP, Standalone, Diagnostics)"
    echo "  ✓ Remove all user data (settings, presets, preferences)"
    echo "  ✓ Clear Audio Unit cache and restart audio services"
    echo "  ✓ Forget all package receipts (system returns to pre-install state)"
    echo "  ✓ Optional: Create backup before removal"
    echo ""
    echo "⚠️  WARNING: This action CANNOT be undone!"
    echo "⚠️  All your settings and presets will be permanently lost!"
    echo ""

    # Offer backup (skip in non-interactive mode)
    local create_backup=false
    if [ "$NON_INTERACTIVE" = false ]; then
        while true; do
            echo -n "Create backup before uninstalling? (yes/no, default: no): "
            read -r BACKUP_REPLY
            echo ""

            BACKUP_REPLY_LOWER=$(echo "$BACKUP_REPLY" | tr '[:upper:]' '[:lower:]')

            case $BACKUP_REPLY_LOWER in
                yes|y)
                    create_backup=true
                    break
                    ;;
                no|n|"")
                    create_backup=false
                    break
                    ;;
                *)
                    echo "Please answer 'yes' or 'no'."
                    echo ""
                    ;;
            esac
        done

        # Confirm uninstall (interactive only)
        while true; do
            echo -n "Proceed with COMPLETE uninstall? (yes/no): "
            read -r REPLY
            echo ""

            REPLY_LOWER=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')

            case $REPLY_LOWER in
                yes|y)
                    break
                    ;;
                no|n)
                    echo "❌ Uninstall cancelled."
                    echo ""
                    exit 0
                    ;;
                *)
                    echo "Please answer 'yes' or 'no'."
                    echo ""
                    ;;
            esac
        done
    else
        # Non-interactive mode: use SKIP_BACKUP flag
        create_backup=$([ "$SKIP_BACKUP" = false ] && echo true || echo false)
    fi

    echo "🚀 Starting complete uninstall..."
    echo ""

    # Create backup if requested
    if [ "$create_backup" = true ]; then
        echo "💾 Creating backup..."
        echo ""

        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="$HOME/{{PROJECT_NAME}}_backup_${timestamp}.zip"

        # Create temporary directory for backup staging
        local temp_backup_dir=$(mktemp -d)
        mkdir -p "$temp_backup_dir/{{PROJECT_NAME}}_backup"

        # Copy settings and presets from Application Support
        if [ -d "$APP_SUPPORT_PATH" ]; then
            cp -R "$APP_SUPPORT_PATH" "$temp_backup_dir/{{PROJECT_NAME}}_backup/" 2>/dev/null
            echo "  📁 Backed up: Application Support"
        fi

        # Copy preferences
        mkdir -p "$temp_backup_dir/{{PROJECT_NAME}}_backup/Preferences"
        local pref_count=0
        for pref in "$HOME/Library/Preferences/"*{{PROJECT_NAME}}* "$HOME/Library/Preferences/{{PROJECT_BUNDLE_ID}}"*; do
            if [ -e "$pref" ]; then
                cp -R "$pref" "$temp_backup_dir/{{PROJECT_NAME}}_backup/Preferences/" 2>/dev/null
                ((pref_count++))
            fi
        done
        [ $pref_count -gt 0 ] && echo "  📁 Backed up: $pref_count preference file(s)"

        # Create README
        cat > "$temp_backup_dir/{{PROJECT_NAME}}_backup/README.txt" << EOF
{{PROJECT_NAME}} Backup
==================

Created: $(date)

This backup contains your user data:

1. {{PROJECT_NAME}}/
   - Your settings and presets
   - Restore to: ~/Library/Application Support/{{PROJECT_NAME}}/

2. Preferences/
   - Your plugin preferences and settings
   - Restore to: ~/Library/Preferences/
   - NOTE: Usually NOT recommended to restore unless you need specific settings
     Restoring old preferences may cause compatibility issues with newer versions

How to Restore After Reinstalling {{PROJECT_NAME}}:
----------------------------------------------
1. Copy {{PROJECT_NAME}}/ to ~/Library/Application Support/
2. (Optional) Copy preferences if you need your specific settings

Your settings and presets will be immediately available in {{PROJECT_NAME}}.

EOF

        echo ""

        # Create ZIP
        (cd "$temp_backup_dir" && zip -r "$backup_file" {{PROJECT_NAME}}_backup >/dev/null 2>&1)

        # Clean up temp directory
        rm -rf "$temp_backup_dir"

        if [ -f "$backup_file" ]; then
            local backup_size=$(du -sh "$backup_file" | cut -f1)
            echo "  ✅ Backup created: $backup_file ($backup_size)"
            echo ""
        else
            echo "  ⚠️  Backup creation failed"
            echo ""
        fi
    fi

    # Step 1: Remove plugins
    remove_plugins

    # Step 2: Remove user data
    echo "🗑️  Removing user data..."
    echo ""

    local removed=0

    [ -d "$APP_SUPPORT_PATH" ] && rm -rf "$APP_SUPPORT_PATH" && echo "  ✅ Removed: Application Support" && ((removed++))
    [ -d "$LOGS_PATH" ] && rm -rf "$LOGS_PATH" && echo "  ✅ Removed: Logs" && ((removed++))
    [ -d "$CACHE_PATH" ] && rm -rf "$CACHE_PATH" && echo "  ✅ Removed: Cache" && ((removed++))
    [ -d "$INSTALLER_RESOURCES" ] && rm -rf "$INSTALLER_RESOURCES" && echo "  ✅ Removed: Installer resources" && ((removed++))

    # Remove preferences
    for pref in "$HOME/Library/Preferences/"*{{PROJECT_NAME}}* "$HOME/Library/Preferences/{{PROJECT_BUNDLE_ID}}"*; do
        if [ -e "$pref" ]; then
            rm -rf "$pref" && echo "  ✅ Removed: $(basename "$pref")" && ((removed++))
        fi
    done

    # Clean up temp files
    echo "  Cleaning temporary files..."
    shopt -s nullglob
    for file in /tmp/{{PROJECT_NAME}}_* /var/tmp/{{PROJECT_NAME}}_*; do
        if [ -e "$file" ]; then
            rm -rf "$file" 2>/dev/null && echo "    Cleaned: $file"
        fi
    done
    shopt -u nullglob

    echo ""
    echo "  📊 Removed $removed user data item(s)"
    echo ""

    # Step 3: Clear AU cache
    clear_au_cache

    # Step 4: Forget receipts
    echo "📦 Forgetting package receipts..."
    echo ""

    local forgotten=0

    for receipt in "${RECEIPTS[@]}"; do
        if pkgutil --pkg-info "$receipt" &>/dev/null; then
            if sudo pkgutil --forget "$receipt" 2>/dev/null; then
                echo "  ✅ Forgotten: $receipt"
                ((forgotten++))
            else
                echo "  ⚠️  Failed to forget: $receipt"
            fi
        else
            echo "  ➖ Not found: $receipt"
        fi
    done

    echo ""
    echo "  📊 Forgotten $forgotten receipt(s)"
    echo ""

    # Step 5: Verify complete removal
    verify_plugins_removed
    verify_receipts_removed

    echo "✅ {{PROJECT_NAME}} has been completely removed from your system!"
    echo ""
    echo "Thank you for trying {{PROJECT_NAME}}! 🎵"
    echo ""
    echo "If you decide to reinstall in the future, download from:"
    echo "   https://github.com/{{GITHUB_USER}}/{{GITHUB_REPO}}/releases/latest"
    echo ""
}

# ============================================================================
# MAIN MENU
# ============================================================================

# Check if any {{PROJECT_NAME}} components exist
FOUND_COMPONENTS=0
for receipt in "${RECEIPTS[@]}"; do
    pkgutil --pkg-info "$receipt" &>/dev/null && ((FOUND_COMPONENTS++))
done

for path in "$USER_AU_PATH" "$SYSTEM_AU_PATH" "$USER_VST3_PATH" "$SYSTEM_VST3_PATH" "$USER_CLAP_PATH" "$SYSTEM_CLAP_PATH" "$STANDALONE_PATH" "$DIAGNOSTICS_PATH"; do
    [ -e "$path" ] && ((FOUND_COMPONENTS++))
done

# Check for folder-based installation
if [ "$USING_FOLDER" = true ] && [ -d "$APP_FOLDER" ]; then
    ((FOUND_COMPONENTS++))
fi

if [ $FOUND_COMPONENTS -eq 0 ]; then
    echo "✅ No {{PROJECT_NAME}} components found on this system."
    echo ""
    echo "Thank you for trying {{PROJECT_NAME}}! 🎵"
    echo ""
    exit 0
fi

echo "📊 Found {{PROJECT_NAME}} installation on this system."
echo ""

# Non-interactive mode: skip menu and go directly to specified mode
if [ "$NON_INTERACTIVE" = true ]; then
    # Default to complete uninstall in non-interactive mode (dev workflow)
    if [ -z "$MODE" ]; then
        MODE="uninstall"
    fi

    case $MODE in
        repair)
            mode_repair
            ;;
        uninstall)
            mode_uninstall
            ;;
        *)
            echo "❌ Error: Invalid mode '$MODE'. Use 'repair' or 'uninstall'."
            exit 1
            ;;
    esac

    # Self-delete before exiting (non-interactive path)
    if [ "$USING_FOLDER" = true ]; then
        UNINSTALLER_PATH="/Applications/{{PROJECT_NAME}}/{{PROJECT_NAME}} Uninstaller.command"
    else
        UNINSTALLER_PATH="/Applications/{{PROJECT_NAME}} Uninstaller.command"
    fi

    if [ -f "$UNINSTALLER_PATH" ]; then
        echo "🗑️  Removing uninstaller..."
        (sleep 0.1 && rm -f "$UNINSTALLER_PATH" 2>/dev/null) &
        disown
    fi

    exit 0
fi

# Interactive mode: show menu
echo "Choose an option:"
echo ""
echo "  1) Repair/Reinstall Mode"
echo "     • Remove plugins only (AU, VST3, CLAP, Standalone, Diagnostics)"
echo "     • Clear Audio Unit cache & restart audio services"
echo "     • KEEP package receipts (pkgutil tracking preserved)"
echo "     • KEEP all user data (settings, presets, preferences)"
echo "     • Get link to latest PKG installer"
echo "     → Use this to fix AU registration issues"
echo ""
echo "  2) Complete Uninstall"
echo "     • Optional backup of settings & presets"
echo "     • Remove all {{PROJECT_NAME}} files and user data"
echo "     • Forget all package receipts"
echo "     • Clear Audio Unit cache & restart audio services"
echo "     → System returns to pre-install state"
echo ""
echo "  0) Cancel"
echo ""

while true; do
    echo -n "Enter choice (1/2/0): "
    read -r CHOICE
    echo ""

    case $CHOICE in
        1)
            mode_repair
            break
            ;;
        2)
            mode_uninstall
            break
            ;;
        0)
            echo "❌ Operation cancelled."
            echo ""
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 0."
            echo ""
            ;;
    esac
done

# Self-delete the uninstaller if it exists
if [ "$USING_FOLDER" = true ]; then
    UNINSTALLER_PATH="/Applications/{{PROJECT_NAME}}/{{PROJECT_NAME}} Uninstaller.command"
else
    UNINSTALLER_PATH="/Applications/{{PROJECT_NAME}} Uninstaller.command"
fi

if [ -f "$UNINSTALLER_PATH" ]; then
    echo "🗑️  Removing uninstaller..."
    (sleep 0.1 && rm -f "$UNINSTALLER_PATH" 2>/dev/null) &
    disown
fi

exit 0

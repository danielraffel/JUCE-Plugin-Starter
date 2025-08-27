#!/bin/bash

# Unified Build System for JUCE Audio Plugins
# Reads all configuration from .env file - completely project-agnostic
# Supports: AU, VST3, Standalone (no CLAP)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find project root (where .env is)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$PROJECT_ROOT"  # Alias for compatibility
cd "$PROJECT_ROOT"

# Load environment variables from .env
if [[ -f ".env" ]]; then
    # Source .env file properly, handling spaces and quotes
    set -a  # Mark variables for export
    source .env
    set +a  # Disable auto-export
else
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Verify required environment variables
REQUIRED_VARS=("PROJECT_NAME" "PROJECT_BUNDLE_ID")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}Error: $var is not set in .env${NC}"
        exit 1
    fi
done

# Use DEVELOPER_NAME as COMPANY_NAME if COMPANY_NAME not set
if [[ -z "$COMPANY_NAME" ]]; then
    COMPANY_NAME="${DEVELOPER_NAME:-Unknown Company}"
fi

# Default values
BUILD_DIR="${BUILD_DIR:-build}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
FORMATS="${FORMATS:-AU VST3 Standalone}"

# GitHub release publishing defaults
GITHUB_REPO="${GITHUB_REPO:-$PROJECT_NAME}"
VERSION="${VERSION_MAJOR:-0}.${VERSION_MINOR:-0}.${VERSION_PATCH:-1}"

# Parse command line arguments
TARGET="all"  # all, au, vst3, standalone
ACTION="local"  # local, test, sign, notarize, publish

usage() {
    cat << EOF
Usage: $0 [TARGET] [ACTION]

TARGETS:
  all         Build all formats (default)
  au          Build Audio Unit only
  vst3        Build VST3 only
  standalone  Build Standalone only

ACTIONS:
  local       Build locally without signing (default)
  test        Build and run PluginVal tests
  sign        Build and code sign
  notarize    Build, sign, and notarize
  publish     Build, sign, notarize, and publish to GitHub

Examples:
  $0                    # Build all formats locally
  $0 au                 # Build AU only
  $0 all sign          # Build and sign all formats
  $0 vst3 test         # Build VST3 and test with PluginVal
  $0 all publish       # Build, sign, notarize and publish to GitHub

Configuration is read from .env file:
  PROJECT_NAME, COMPANY_NAME, APPLE_ID, etc.
EOF
}

# Process arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        all|au|vst3|standalone)
            TARGET="$1"
            ;;
        local|test|sign|notarize|publish)
            ACTION="$1"
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
fi

if [[ $# -gt 1 ]]; then
    case "$2" in
        local|test|sign|notarize|publish)
            ACTION="$2"
            ;;
        *)
            echo -e "${RED}Unknown action: $2${NC}"
            usage
            exit 1
            ;;
    esac
fi

# Determine which formats to build based on target
case "$TARGET" in
    all)
        BUILD_FORMATS="AU VST3 Standalone"
        ;;
    au)
        BUILD_FORMATS="AU"
        ;;
    vst3)
        BUILD_FORMATS="VST3"
        ;;
    standalone)
        BUILD_FORMATS="Standalone"
        ;;
esac

echo -e "${GREEN}Building ${PROJECT_NAME}${NC}"
echo "Target: $TARGET"
echo "Action: $ACTION"
echo "Formats: $BUILD_FORMATS"
echo "Build Type: $CMAKE_BUILD_TYPE"
echo ""

# Function to bump version
bump_version() {
    if [[ -f "scripts/bump_version.py" ]]; then
        echo -e "${GREEN}Bumping version...${NC}"
        python3 scripts/bump_version.py
    else
        echo -e "${YELLOW}Warning: bump_version.py not found${NC}"
    fi
}

# Function to configure CMake
configure_cmake() {
    echo -e "${GREEN}Configuring CMake...${NC}"
    
    # Set formats for CMake
    CMAKE_FORMATS=""
    for format in $BUILD_FORMATS; do
        CMAKE_FORMATS="$CMAKE_FORMATS -D${format}=ON"
    done
    
    cmake -B "$BUILD_DIR" \
        -G Xcode \
        -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
        -DPROJECT_NAME="$PROJECT_NAME" \
        -DPROJECT_BUNDLE_ID="$PROJECT_BUNDLE_ID" \
        -DCOMPANY_NAME="$COMPANY_NAME" \
        $CMAKE_FORMATS \
        .
}

# Function to build with Xcode
build_xcode() {
    echo -e "${GREEN}Building with Xcode...${NC}"
    
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                echo "Building Audio Unit..."
                xcodebuild -project "$BUILD_DIR/${PROJECT_NAME}.xcodeproj" \
                    -scheme "${PROJECT_NAME}_AU" \
                    -configuration "$CMAKE_BUILD_TYPE" \
                    build
                ;;
            VST3)
                echo "Building VST3..."
                xcodebuild -project "$BUILD_DIR/${PROJECT_NAME}.xcodeproj" \
                    -scheme "${PROJECT_NAME}_VST3" \
                    -configuration "$CMAKE_BUILD_TYPE" \
                    build
                ;;
            Standalone)
                echo "Building Standalone..."
                xcodebuild -project "$BUILD_DIR/${PROJECT_NAME}.xcodeproj" \
                    -scheme "${PROJECT_NAME}_Standalone" \
                    -configuration "$CMAKE_BUILD_TYPE" \
                    build
                ;;
        esac
    done
}

# Function to launch standalone app
launch_standalone() {
    local app_path="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone/${PROJECT_NAME}.app"
    
    if [[ ! -d "$app_path" ]]; then
        echo -e "${YELLOW}Warning: Standalone app not found at $app_path${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Launching standalone app...${NC}"
    
    # Check if app is already running and kill it
    if pgrep -x "$PROJECT_NAME" > /dev/null; then
        echo "Killing existing $PROJECT_NAME instance..."
        pkill -x "$PROJECT_NAME" || true
        sleep 1  # Give it time to exit
    fi
    
    # Launch the app in background
    open "$app_path"
    echo "Launched: $app_path"
}

# Function to run tests with PluginVal
run_tests() {
    echo -e "${GREEN}Running PluginVal tests...${NC}"
    
    local has_pluginval=true
    if ! command -v pluginval &> /dev/null; then
        echo -e "${YELLOW}Warning: PluginVal not installed${NC}"
        echo "Install with: brew install --cask pluginval"
        has_pluginval=false
    fi
    
    local tested_something=false
    
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
                if [[ -d "$PLUGIN_PATH" ]] && [[ "$has_pluginval" == "true" ]]; then
                    echo "Testing AU: $PLUGIN_PATH"
                    pluginval --validate-in-process --validate "$PLUGIN_PATH" || true
                    tested_something=true
                fi
                ;;
            VST3)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
                if [[ -d "$PLUGIN_PATH" ]] && [[ "$has_pluginval" == "true" ]]; then
                    echo "Testing VST3: $PLUGIN_PATH"
                    pluginval --validate-in-process --validate "$PLUGIN_PATH" || true
                    tested_something=true
                fi
                ;;
            Standalone)
                # For standalone, launch the app for manual testing
                launch_standalone
                tested_something=true
                ;;
        esac
    done
    
    if [[ "$tested_something" == "false" ]]; then
        echo -e "${YELLOW}No plugins were tested${NC}"
    fi
}

# Function to sign plugins
sign_plugins() {
    echo -e "${GREEN}Signing plugins...${NC}"
    
    if [[ -z "$APP_CERT" ]]; then
        echo -e "${RED}Error: APP_CERT not set in .env${NC}"
        return 1
    fi
    
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    echo "Signing AU: $PLUGIN_PATH"
                    codesign --force --deep --strict --timestamp \
                        --sign "$APP_CERT" \
                        --options runtime \
                        "$PLUGIN_PATH"
                fi
                ;;
            VST3)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    echo "Signing VST3: $PLUGIN_PATH"
                    codesign --force --deep --strict --timestamp \
                        --sign "$APP_CERT" \
                        --options runtime \
                        "$PLUGIN_PATH"
                fi
                ;;
            Standalone)
                APP_PATH="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone/${PROJECT_NAME}.app"
                if [[ -d "$APP_PATH" ]]; then
                    echo "Signing Standalone: $APP_PATH"
                    codesign --force --deep --strict --timestamp \
                        --sign "$APP_CERT" \
                        --options runtime \
                        "$APP_PATH"
                fi
                ;;
        esac
    done
}

# Function to notarize plugins
notarize_plugins() {
    echo -e "${GREEN}Notarizing plugins...${NC}"
    
    # Support both APP_SPECIFIC_PASSWORD and APP_PASSWORD for backward compatibility
    local NOTARY_PASSWORD="${APP_SPECIFIC_PASSWORD:-$APP_PASSWORD}"
    
    if [[ -z "$APPLE_ID" ]] || [[ -z "$NOTARY_PASSWORD" ]] || [[ -z "$TEAM_ID" ]]; then
        echo -e "${RED}Error: APPLE_ID, APP_SPECIFIC_PASSWORD (or APP_PASSWORD), or TEAM_ID not set in .env${NC}"
        return 1
    fi
    
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    echo "Notarizing AU..."
                    ZIP_PATH="/tmp/${PROJECT_NAME}_AU.zip"
                    ditto -c -k --keepParent "$PLUGIN_PATH" "$ZIP_PATH"
                    
                    xcrun notarytool submit "$ZIP_PATH" \
                        --apple-id "$APPLE_ID" \
                        --password "$NOTARY_PASSWORD" \
                        --team-id "$TEAM_ID" \
                        --wait
                    
                    xcrun stapler staple "$PLUGIN_PATH"
                    rm "$ZIP_PATH"
                fi
                ;;
            VST3)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    echo "Notarizing VST3..."
                    ZIP_PATH="/tmp/${PROJECT_NAME}_VST3.zip"
                    ditto -c -k --keepParent "$PLUGIN_PATH" "$ZIP_PATH"
                    
                    xcrun notarytool submit "$ZIP_PATH" \
                        --apple-id "$APPLE_ID" \
                        --password "$NOTARY_PASSWORD" \
                        --team-id "$TEAM_ID" \
                        --wait
                    
                    xcrun stapler staple "$PLUGIN_PATH"
                    rm "$ZIP_PATH"
                fi
                ;;
        esac
    done
}

# Function to create installer package
create_installer() {
    echo -e "${GREEN}Creating installer package...${NC}"
    
    if [[ -z "$INSTALLER_CERT" ]]; then
        echo -e "${RED}Error: INSTALLER_CERT not set in .env${NC}"
        return 1
    fi
    
    # Get version from .env
    VERSION="${VERSION_MAJOR:-1}.${VERSION_MINOR:-0}.${VERSION_PATCH:-0}"
    
    # Create temporary directory for package
    PKG_ROOT="/tmp/${PROJECT_NAME}_installer"
    rm -rf "$PKG_ROOT"
    mkdir -p "$PKG_ROOT"
    
    # Copy plugins to package
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    mkdir -p "$PKG_ROOT/Library/Audio/Plug-Ins/Components"
                    cp -R "$PLUGIN_PATH" "$PKG_ROOT/Library/Audio/Plug-Ins/Components/"
                fi
                ;;
            VST3)
                PLUGIN_PATH="$HOME/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
                if [[ -d "$PLUGIN_PATH" ]]; then
                    mkdir -p "$PKG_ROOT/Library/Audio/Plug-Ins/VST3"
                    cp -R "$PLUGIN_PATH" "$PKG_ROOT/Library/Audio/Plug-Ins/VST3/"
                fi
                ;;
        esac
    done
    
    # Check if we have standalone app to include
    STANDALONE_PATH="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone/${PROJECT_NAME}.app"
    if [[ -d "$STANDALONE_PATH" ]]; then
        echo "Including standalone app in installer..."
        mkdir -p "$PKG_ROOT/Applications"
        cp -R "$STANDALONE_PATH" "$PKG_ROOT/Applications/"
    fi
    
    # Build the package
    PKG_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}.pkg"
    
    pkgbuild --root "$PKG_ROOT" \
        --identifier "$PROJECT_BUNDLE_ID" \
        --version "$VERSION" \
        --sign "$INSTALLER_CERT" \
        "$PKG_PATH"
    
    # Notarize the installer
    echo "Notarizing installer..."
    xcrun notarytool submit "$PKG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "${APP_SPECIFIC_PASSWORD:-$APP_PASSWORD}" \
        --team-id "$TEAM_ID" \
        --wait
    
    xcrun stapler staple "$PKG_PATH"
    
    # Create DMG
    DMG_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}.dmg"
    echo "Creating DMG..."
    
    DMG_ROOT="/tmp/${PROJECT_NAME}_dmg"
    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp "$PKG_PATH" "$DMG_ROOT/"
    
    hdiutil create -volname "${PROJECT_NAME} ${VERSION}" \
        -srcfolder "$DMG_ROOT" \
        -ov -format UDZO \
        "$DMG_PATH"
    
    # Sign the DMG
    codesign --force --sign "$APP_CERT" "$DMG_PATH"
    
    # Create ZIP of the DMG for easier distribution
    ZIP_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}.zip"
    cd "$HOME/Desktop"
    zip -9 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")"
    
    # Clean up
    rm -rf "$PKG_ROOT" "$DMG_ROOT"
    
    echo -e "${GREEN}Installer created:${NC}"
    echo "  PKG: $PKG_PATH"
    echo "  DMG: $DMG_PATH"
    echo "  ZIP: $ZIP_PATH"
}

# Function to generate release notes
generate_release_notes() {
    echo -e "${GREEN}Generating release notes for version $VERSION...${NC}"
    
    local release_notes=""
    
    # Use the Python script if it exists
    if [[ -f "${ROOT_DIR}/scripts/generate_release_notes.py" ]]; then
        # Try AI-enhanced release notes if API keys are available
        if [[ -n "$OPENROUTER_KEY_PRIVATE" ]] || [[ -n "$OPENAI_API_KEY" ]]; then
            echo "🤖 Attempting AI-enhanced release notes..."
            release_notes=$(python3 "${ROOT_DIR}/scripts/generate_release_notes.py" --version "$VERSION" --format markdown --ai 2>/dev/null)
            
            if [[ -n "$release_notes" ]]; then
                echo "✅ AI-enhanced release notes generated"
            else
                echo "⚠️  AI generation failed, falling back to git log"
                release_notes=""
            fi
        fi
        
        # Fallback to standard generation if AI failed
        if [[ -z "$release_notes" ]]; then
            echo "📝 Generating standard release notes..."
            release_notes=$(python3 "${ROOT_DIR}/scripts/generate_release_notes.py" --version "$VERSION" --format markdown 2>/dev/null)
        fi
    fi
    
    # Ultimate fallback to git-based release notes
    if [[ -z "$release_notes" ]]; then
        echo "📝 Generating git-based release notes..."
        local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        local commit_range=""
        if [[ -n "$last_tag" ]]; then
            commit_range="$last_tag..HEAD"
        else
            commit_range="HEAD~5..HEAD"
        fi
        
        local commits=$(git log --pretty=format:"- %s" --no-merges "$commit_range" 2>/dev/null || echo "- Initial release")
        release_notes="## What's Changed

$commits

**Full Changelog**: https://github.com/${GITHUB_USER:-owner}/${GITHUB_REPO}/commits/v$VERSION"
    fi
    
    echo "$release_notes"
}

# Function to create GitHub release
create_github_release() {
    echo -e "${GREEN}Creating GitHub release...${NC}"
    
    # Check if GitHub CLI is authenticated
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) not installed${NC}"
        echo "Install with: brew install gh"
        return 1
    fi
    
    if ! gh auth status &>/dev/null; then
        echo -e "${RED}Error: GitHub CLI not authenticated${NC}"
        echo "Run: gh auth login"
        return 1
    fi
    
    local release_tag="v$VERSION"
    local release_title="$PROJECT_NAME $VERSION"
    local release_notes=$(generate_release_notes)
    
    # Find artifacts to upload
    local artifacts=()
    local desktop="$HOME/Desktop"
    
    # Look for PKG file
    local pkg_file=$(find "$desktop" -name "${PROJECT_NAME}*.pkg" -not -name "*component*" -not -name "*vst3*" -not -name "*standalone*" -not -name "*resources*" | head -1)
    if [[ -n "$pkg_file" ]] && [[ -f "$pkg_file" ]]; then
        artifacts+=("$pkg_file")
        echo "Found PKG: $(basename "$pkg_file")"
    fi
    
    # Look for DMG file
    local dmg_file=$(find "$desktop" -name "${PROJECT_NAME}*.dmg" | head -1)
    if [[ -n "$dmg_file" ]] && [[ -f "$dmg_file" ]]; then
        artifacts+=("$dmg_file")
        echo "Found DMG: $(basename "$dmg_file")"
    fi
    
    # Look for ZIP file
    local zip_file=$(find "$desktop" -name "${PROJECT_NAME}*.zip" | head -1)
    if [[ -n "$zip_file" ]] && [[ -f "$zip_file" ]]; then
        artifacts+=("$zip_file")
        echo "Found ZIP: $(basename "$zip_file")"
    fi
    
    if [[ ${#artifacts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No artifacts found on Desktop${NC}"
        echo "Expected files: ${PROJECT_NAME}*.pkg, ${PROJECT_NAME}*.dmg, ${PROJECT_NAME}*.zip"
        return 1
    fi
    
    # Create the release
    echo "Creating release $release_tag..."
    gh release create "$release_tag" \
        --repo "${GITHUB_USER:-owner}/${GITHUB_REPO}" \
        --title "$release_title" \
        --notes "$release_notes" \
        "${artifacts[@]}"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Successfully created GitHub release${NC}"
        echo "   Release URL: https://github.com/${GITHUB_USER:-owner}/${GITHUB_REPO}/releases/tag/$release_tag"
        return 0
    else
        echo -e "${RED}❌ Failed to create GitHub release${NC}"
        return 1
    fi
}

# Main build process
main() {
    # Always bump version (even for local builds to ensure proper versioning)
    bump_version
    
    # Configure and build
    configure_cmake
    build_xcode
    
    # Post-build actions
    case "$ACTION" in
        local)
            # Launch standalone if it was built
            if [[ "$BUILD_FORMATS" == *"Standalone"* ]]; then
                launch_standalone
            fi
            ;;
        test)
            run_tests
            ;;
        sign)
            sign_plugins
            ;;
        notarize)
            sign_plugins
            notarize_plugins
            ;;
        publish)
            sign_plugins
            notarize_plugins
            create_installer
            create_github_release
            ;;
    esac
    
    echo -e "${GREEN}Build complete!${NC}"
    
    # Show installed locations
    echo ""
    echo "Plugins installed to:"
    for format in $BUILD_FORMATS; do
        case "$format" in
            AU)
                echo "  AU: ~/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
                ;;
            VST3)
                echo "  VST3: ~/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
                ;;
            Standalone)
                echo "  App: $BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone/${PROJECT_NAME}.app"
                ;;
        esac
    done
}

# Run main function
main
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
TARGETS=()  # Array to hold multiple targets
ACTION="local"  # local, test, sign, notarize, publish, pkg, unsigned, uninstall
REGENERATE_PAGE=false  # Flag to force regeneration of GitHub Pages
BUILT_PLUGINS=()  # Track plugins built in this session

usage() {
    cat << EOF
Usage: $0 [TARGET(s)] [ACTION] [OPTIONS]

TARGETS (can specify multiple):
  all         Build all formats (default)
  au          Build Audio Unit only
  vst3        Build VST3 only
  standalone  Build Standalone only

ACTIONS:
  local       Build locally without signing (default)
  test        Build and run PluginVal tests
  sign        Build and code sign
  notarize    Build, sign, and notarize
  pkg         Build, sign, notarize, and package (no GitHub release)
  publish     Build, sign, notarize, and publish to GitHub with auto-download page
  unsigned    Build and create unsigned installer package (fast testing)
  uninstall   Run uninstaller in non-interactive mode (complete uninstall, no backup)

OPTIONS:
  --regenerate-page    Force regeneration of GitHub Pages index.html (use with publish)

Examples:
  $0                        # Build all formats locally
  $0 au                     # Build AU only
  $0 vst3                   # Build VST3 only
  $0 standalone             # Build Standalone only
  $0 au vst3                # Build both AU and VST3
  $0 au standalone          # Build both AU and Standalone
  $0 all sign               # Build and sign all formats
  $0 vst3 test              # Build VST3 and test with PluginVal
  $0 au vst3 test           # Build AU and VST3, then test both
  $0 all publish            # Build, sign, notarize and publish to GitHub
  $0 publish                # Same as above (builds all formats by default)
  $0 publish --regenerate-page  # Publish and force regenerate landing page
  $0 pkg                    # Build, sign, notarize PKG (no GitHub release)
  $0 unsigned               # Build unsigned installer (fast testing)
  $0 uninstall              # Uninstall all plugin components
  $0 uninstall && $0 unsigned  # Uninstall then rebuild (fast dev workflow)

GitHub Pages:
  When using 'publish', an auto-download landing page is created (first time only).
  The page uses JavaScript to always fetch the latest release automatically.
  Use --regenerate-page to update the page design or fix issues.

Configuration is read from .env file:
  PROJECT_NAME, COMPANY_NAME, APPLE_ID, etc.
EOF
}

# Process arguments - now supports multiple targets
while [[ $# -gt 0 ]]; do
    case "$1" in
        all|au|vst3|standalone)
            TARGETS+=("$1")
            shift
            ;;
        local|test|sign|notarize|publish|unsigned|pkg|uninstall)
            ACTION="$1"
            shift
            ;;
        --regenerate-page)
            REGENERATE_PAGE=true
            shift
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
done

# If no targets specified, default to "all"
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=("all")
fi

# Determine which formats to build based on targets
BUILD_FORMATS=""

for TARGET in "${TARGETS[@]}"; do
    case "$TARGET" in
        all)
            BUILD_FORMATS="AU VST3 Standalone"
            ;;
        au)
            if [[ ! $BUILD_FORMATS =~ "AU" ]]; then
                BUILD_FORMATS="$BUILD_FORMATS AU"
            fi
            ;;
        vst3)
            if [[ ! $BUILD_FORMATS =~ "VST3" ]]; then
                BUILD_FORMATS="$BUILD_FORMATS VST3"
            fi
            ;;
        standalone)
            if [[ ! $BUILD_FORMATS =~ "Standalone" ]]; then
                BUILD_FORMATS="$BUILD_FORMATS Standalone"
            fi
            ;;
    esac
done

# Trim leading/trailing spaces
BUILD_FORMATS=$(echo "$BUILD_FORMATS" | xargs)

echo -e "${GREEN}Building ${PROJECT_NAME}${NC}"
echo "Targets: ${TARGETS[*]}"
echo "Action: $ACTION"
if [[ -n "$BUILD_FORMATS" ]]; then
    echo "Formats: $BUILD_FORMATS"
fi
echo "Build Type: $CMAKE_BUILD_TYPE"
echo ""

# Function to run uninstaller (non-interactive mode for development)
run_uninstaller() {
    # Look for uninstaller in common locations
    local uninstaller_path=""

    # Check in /Applications folder (installed location)
    if [[ -f "/Applications/${PROJECT_NAME} Uninstaller.command" ]]; then
        uninstaller_path="/Applications/${PROJECT_NAME} Uninstaller.command"
    elif [[ -f "/Applications/${PROJECT_NAME}/${PROJECT_NAME} Uninstaller.command" ]]; then
        uninstaller_path="/Applications/${PROJECT_NAME}/${PROJECT_NAME} Uninstaller.command"
    fi

    if [[ -z "$uninstaller_path" ]]; then
        echo -e "${RED}Error: Uninstaller not found${NC}"
        echo ""
        echo "Expected locations:"
        echo "  /Applications/${PROJECT_NAME} Uninstaller.command"
        echo "  /Applications/${PROJECT_NAME}/${PROJECT_NAME} Uninstaller.command"
        echo ""
        echo "The uninstaller is installed when you run the PKG installer."
        echo "Try running: $0 unsigned"
        echo "Then install the PKG to get the uninstaller."
        exit 1
    fi

    echo -e "${GREEN}Running uninstaller (non-interactive mode)...${NC}"
    echo "Uninstaller: $uninstaller_path"
    echo ""

    # Run uninstaller in non-interactive mode (complete uninstall, no backup)
    if sudo "$uninstaller_path" --non-interactive --mode=uninstall; then
        echo ""
        echo -e "${GREEN}✅ Uninstall complete${NC}"
        return 0
    else
        echo -e "${RED}❌ Uninstall failed${NC}"
        return 1
    fi
}

# If action is uninstall, run it and exit
if [[ "$ACTION" == "uninstall" ]]; then
    run_uninstaller
    exit $?
fi

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

# Function to discover available schemes for a format
get_schemes_for_format() {
    local format="$1"
    local project_path="$BUILD_DIR/${PROJECT_NAME}.xcodeproj"

    # Get list of schemes from Xcode project
    local all_schemes=$(xcodebuild -project "$project_path" -list 2>/dev/null | \
        sed -n '/Schemes:/,/^$/p' | \
        tail -n +2 | \
        sed 's/^[[:space:]]*//' | \
        grep -v '^$')

    # Filter schemes by format suffix
    case "$format" in
        AU)
            echo "$all_schemes" | grep "_AU$"
            ;;
        VST3)
            echo "$all_schemes" | grep "_VST3$"
            ;;
        Standalone)
            echo "$all_schemes" | grep "_Standalone$"
            ;;
    esac
}

# Function to build with Xcode
build_xcode() {
    echo -e "${GREEN}Building with Xcode...${NC}"

    for format in $BUILD_FORMATS; do
        # Discover schemes for this format
        local schemes=$(get_schemes_for_format "$format")

        if [[ -z "$schemes" ]]; then
            echo -e "${YELLOW}Warning: No ${format} schemes found${NC}"
            continue
        fi

        # Build each scheme
        while IFS= read -r scheme; do
            [[ -z "$scheme" ]] && continue

            # Extract plugin name from scheme (remove format suffix)
            local plugin_name="${scheme%_AU}"
            plugin_name="${plugin_name%_VST3}"
            plugin_name="${plugin_name%_Standalone}"

            case "$format" in
                AU)
                    echo "Building Audio Unit: $scheme"
                    ;;
                VST3)
                    echo "Building VST3: $scheme"
                    ;;
                Standalone)
                    echo "Building Standalone: $scheme"
                    ;;
            esac

            xcodebuild -project "$BUILD_DIR/${PROJECT_NAME}.xcodeproj" \
                -scheme "$scheme" \
                -configuration "$CMAKE_BUILD_TYPE" \
                build

            # Record what was built
            BUILT_PLUGINS+=("$format:$plugin_name")
        done <<< "$schemes"
    done
}

# Function to launch standalone app
launch_standalone() {
    local standalone_dir="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone"

    if [[ ! -d "$standalone_dir" ]]; then
        echo -e "${YELLOW}Warning: Standalone directory not found${NC}"
        return 1
    fi

    # Find all .app files in standalone directory
    local apps=()
    while IFS= read -r -d '' app; do
        apps+=("$app")
    done < <(find "$standalone_dir" -maxdepth 1 -name "*.app" -print0)

    if [[ ${#apps[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No standalone apps found${NC}"
        return 1
    fi

    echo -e "${GREEN}Launching standalone app(s)...${NC}"

    # Launch each app
    for app_path in "${apps[@]}"; do
        local app_name=$(basename "$app_path" .app)

        # Check if app is already running and kill it
        if pgrep -x "$app_name" > /dev/null; then
            echo "Killing existing $app_name instance..."
            pkill -x "$app_name" || true
            sleep 1  # Give it time to exit
        fi

        # Launch the app in background
        open "$app_path"
        echo "Launched: $app_path"
    done
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
                # Find all AU plugins in Components directory
                local au_dir="$HOME/Library/Audio/Plug-Ins/Components"
                if [[ -d "$au_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        if [[ "$has_pluginval" == "true" ]]; then
                            echo "Testing AU: $plugin"
                            pluginval --validate-in-process --validate "$plugin" || true
                            tested_something=true
                        fi
                    done < <(find "$au_dir" -maxdepth 1 -name "*.component" -print0 2>/dev/null)
                fi
                ;;
            VST3)
                # Find all VST3 plugins in VST3 directory
                local vst3_dir="$HOME/Library/Audio/Plug-Ins/VST3"
                if [[ -d "$vst3_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        if [[ "$has_pluginval" == "true" ]]; then
                            echo "Testing VST3: $plugin"
                            pluginval --validate-in-process --validate "$plugin" || true
                            tested_something=true
                        fi
                    done < <(find "$vst3_dir" -maxdepth 1 -name "*.vst3" -print0 2>/dev/null)
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
                # Find all AU plugins in Components directory
                local au_dir="$HOME/Library/Audio/Plug-Ins/Components"
                if [[ -d "$au_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        echo "Signing AU: $plugin"
                        codesign --force --deep --strict --timestamp \
                            --sign "$APP_CERT" \
                            --options runtime \
                            "$plugin"
                    done < <(find "$au_dir" -maxdepth 1 -name "*.component" -print0 2>/dev/null)
                fi
                ;;
            VST3)
                # Find all VST3 plugins in VST3 directory
                local vst3_dir="$HOME/Library/Audio/Plug-Ins/VST3"
                if [[ -d "$vst3_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        echo "Signing VST3: $plugin"
                        codesign --force --deep --strict --timestamp \
                            --sign "$APP_CERT" \
                            --options runtime \
                            "$plugin"
                    done < <(find "$vst3_dir" -maxdepth 1 -name "*.vst3" -print0 2>/dev/null)
                fi
                ;;
            Standalone)
                # Find all standalone apps in build artefacts
                local standalone_dir="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone"
                if [[ -d "$standalone_dir" ]]; then
                    while IFS= read -r -d '' app; do
                        echo "Signing Standalone: $app"
                        codesign --force --deep --strict --timestamp \
                            --sign "$APP_CERT" \
                            --options runtime \
                            "$app"
                    done < <(find "$standalone_dir" -maxdepth 1 -name "*.app" -print0 2>/dev/null)
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
                # Find all AU plugins in Components directory
                local au_dir="$HOME/Library/Audio/Plug-Ins/Components"
                if [[ -d "$au_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        local plugin_name=$(basename "$plugin" .component)
                        echo "Notarizing AU: $plugin_name..."
                        local zip_path="/tmp/${plugin_name}_AU.zip"
                        ditto -c -k --keepParent "$plugin" "$zip_path"

                        xcrun notarytool submit "$zip_path" \
                            --apple-id "$APPLE_ID" \
                            --password "$NOTARY_PASSWORD" \
                            --team-id "$TEAM_ID" \
                            --wait

                        xcrun stapler staple "$plugin"
                        rm "$zip_path"
                    done < <(find "$au_dir" -maxdepth 1 -name "*.component" -print0 2>/dev/null)
                fi
                ;;
            VST3)
                # Find all VST3 plugins in VST3 directory
                local vst3_dir="$HOME/Library/Audio/Plug-Ins/VST3"
                if [[ -d "$vst3_dir" ]]; then
                    while IFS= read -r -d '' plugin; do
                        local plugin_name=$(basename "$plugin" .vst3)
                        echo "Notarizing VST3: $plugin_name..."
                        local zip_path="/tmp/${plugin_name}_VST3.zip"
                        ditto -c -k --keepParent "$plugin" "$zip_path"

                        xcrun notarytool submit "$zip_path" \
                            --apple-id "$APPLE_ID" \
                            --password "$NOTARY_PASSWORD" \
                            --team-id "$TEAM_ID" \
                            --wait

                        xcrun stapler staple "$plugin"
                        rm "$zip_path"
                    done < <(find "$vst3_dir" -maxdepth 1 -name "*.vst3" -print0 2>/dev/null)
                fi
                ;;
        esac
    done
}

# Function to generate DiagnosticKit .env from main project settings
generate_diagnostic_env() {
    local diagnostic_dir="$PROJECT_ROOT/Tools/DiagnosticKit"
    local diagnostic_env="${diagnostic_dir}/.env"

    echo "📝 Generating DiagnosticKit configuration..."

    # Check if DiagnosticKit directory exists
    if [[ ! -d "$diagnostic_dir" ]]; then
        echo -e "${YELLOW}Warning: DiagnosticKit directory not found${NC}"
        return 1
    fi

    # Copy template if .env.example exists
    if [[ -f "${diagnostic_dir}/.env.example" ]]; then
        cp "${diagnostic_dir}/.env.example" "$diagnostic_env"
    else
        echo -e "${RED}Error: .env.example not found in DiagnosticKit directory${NC}"
        return 1
    fi

    # Replace all placeholders
    sed -i '' \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{PROJECT_BUNDLE_ID}}|${PROJECT_BUNDLE_ID}|g" \
        -e "s|{{VERSION_MAJOR}}|${VERSION_MAJOR:-1}|g" \
        -e "s|{{VERSION_MINOR}}|${VERSION_MINOR:-0}|g" \
        -e "s|{{VERSION_PATCH}}|${VERSION_PATCH:-0}|g" \
        -e "s|{{DIAGNOSTIC_GITHUB_REPO}}|${DIAGNOSTIC_GITHUB_REPO:-}|g" \
        -e "s|{{DIAGNOSTIC_GITHUB_PAT}}|${DIAGNOSTIC_GITHUB_PAT:-}|g" \
        -e "s|{{DIAGNOSTIC_SUPPORT_EMAIL}}|${DIAGNOSTIC_SUPPORT_EMAIL:-${APPLE_ID:-}}|g" \
        -e "s|{{PROJECT_WEBSITE}}|${PROJECT_WEBSITE:-}|g" \
        -e "s|{{PLUGIN_CODE}}|${PLUGIN_CODE:-}|g" \
        -e "s|{{PLUGIN_MANUFACTURER_CODE}}|${PLUGIN_MANUFACTURER_CODE:-}|g" \
        "$diagnostic_env"

    echo "✅ Generated DiagnosticKit .env"
}

# Function to check if DiagnosticKit setup is complete
check_diagnostic_setup() {
    # Only check if diagnostics enabled
    if [[ "${ENABLE_DIAGNOSTICS:-false}" != "true" ]]; then
        return 0
    fi

    # Only check for packaging actions
    if [[ "$ACTION" != "publish" ]] && [[ "$ACTION" != "unsigned" ]] && \
       [[ "$ACTION" != "sign" ]] && [[ "$ACTION" != "notarize" ]] && \
       [[ "$ACTION" != "pkg" ]]; then
        return 0
    fi

    echo -e "${GREEN}Checking DiagnosticKit setup...${NC}"

    if [[ -x "scripts/setup_diagnostic_repo.sh" ]]; then
        if scripts/setup_diagnostic_repo.sh --check-only &>/dev/null; then
            echo "✅ DiagnosticKit fully configured"
            return 0
        else
            echo ""
            echo -e "${YELLOW}⚠️  DiagnosticKit Setup Required${NC}"
            echo ""
            echo "DiagnosticKit needs setup before packaging."
            echo ""
            echo "Options:"
            echo "  1) Run setup now (recommended)"
            echo "  2) Skip for this build only (will ask again next time)"
            echo "  3) Disable DiagnosticKit permanently (won't ask again)"
            echo ""
            read -p "Choose (1-3): " choice

            case "$choice" in
                1)
                    scripts/setup_diagnostic_repo.sh
                    ;;
                2)
                    echo "Skipping DiagnosticKit for this build only..."
                    ENABLE_DIAGNOSTICS="false"  # Temporarily disable for this build
                    ;;
                3)
                    echo "Disabling DiagnosticKit permanently..."
                    # Update .env file
                    if [[ -f .env ]]; then
                        sed -i '' 's/^ENABLE_DIAGNOSTICS=.*/ENABLE_DIAGNOSTICS=false/' .env
                        echo "✅ Updated .env: ENABLE_DIAGNOSTICS=false"
                        echo "   (You can re-enable it later by editing .env)"
                        ENABLE_DIAGNOSTICS="false"  # Also disable for current run
                    else
                        echo -e "${RED}Error: .env file not found${NC}"
                        exit 1
                    fi
                    ;;
                *)
                    echo "Invalid choice"
                    exit 1
                    ;;
            esac
        fi
    else
        echo -e "${YELLOW}Warning: setup_diagnostic_repo.sh not found${NC}"
        return 1
    fi
}

# Function to build DiagnosticKit app
build_diagnostics() {
    if [[ "${ENABLE_DIAGNOSTICS:-false}" != "true" ]]; then
        return 0
    fi

    echo -e "${GREEN}Building DiagnosticKit...${NC}"

    local DIAGNOSTIC_DIR="$PROJECT_ROOT/Tools/DiagnosticKit"

    if [[ ! -d "$DIAGNOSTIC_DIR" ]]; then
        echo -e "${YELLOW}Warning: DiagnosticKit not found at $DIAGNOSTIC_DIR${NC}"
        return 0
    fi

    # Generate .env for DiagnosticKit
    if ! generate_diagnostic_env; then
        echo -e "${YELLOW}Warning: Could not generate DiagnosticKit .env${NC}"
        return 1
    fi

    # Build using build script
    cd "$DIAGNOSTIC_DIR"
    if [[ -x "Scripts/build_app.sh" ]]; then
        # Determine build config
        local diag_build_config="release"
        if [[ "$CMAKE_BUILD_TYPE" == "Debug" ]]; then
            diag_build_config="debug"
        fi

        # Build and capture the app path
        DIAGNOSTIC_PATH=$(./Scripts/build_app.sh "$diag_build_config" 2>&1 | tail -1)

        if [[ -d "$DIAGNOSTIC_PATH" ]]; then
            echo -e "${GREEN}✅ DiagnosticKit built successfully${NC}"
            echo "Path: $DIAGNOSTIC_PATH"
            cd "$PROJECT_ROOT"

            # Export for use in create_installer
            export DIAGNOSTIC_PATH
            return 0
        else
            echo -e "${RED}Error: DiagnosticKit build failed${NC}"
            cd "$PROJECT_ROOT"
            return 1
        fi
    else
        echo -e "${RED}Error: Build script not found at $DIAGNOSTIC_DIR/Scripts/build_app.sh${NC}"
        cd "$PROJECT_ROOT"
        return 1
    fi
}

# Function to create installer package (both signed and unsigned)
create_installer() {
    local sign_package="${1:-true}"  # Default to signing

    if [[ "$sign_package" == "true" ]]; then
        echo -e "${GREEN}Creating signed installer package...${NC}"

        if [[ -z "$INSTALLER_CERT" ]]; then
            echo -e "${RED}Error: INSTALLER_CERT not set in .env${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}Creating unsigned installer package...${NC}"
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

    # Count applications to determine installation strategy
    local app_count=0
    local has_standalone=false
    local has_diagnostics=false
    local has_uninstaller=false

    # Check what's being installed
    STANDALONE_PATH="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone/${PROJECT_NAME}.app"
    if [[ -d "$STANDALONE_PATH" ]]; then
        has_standalone=true
        ((app_count++))
    fi

    # Check for diagnostics (placeholder for now - will be implemented in Phase 3)
    # DIAGNOSTIC_PATH will be set when diagnostics are built
    if [[ -n "${DIAGNOSTIC_PATH}" ]] && [[ -d "${DIAGNOSTIC_PATH}" ]]; then
        has_diagnostics=true
        ((app_count++))
    fi

    # Check if uninstaller will be included
    if [[ -f "scripts/uninstall_template.sh" ]]; then
        has_uninstaller=true
        ((app_count++))
    fi

    # Determine installation strategy
    local use_app_folder=false
    local app_install_root=""

    if [[ $app_count -gt 1 ]]; then
        use_app_folder=true
        app_install_root="$PKG_ROOT/Applications/${PROJECT_NAME}"
        echo "📁 Multiple apps detected ($app_count) - installing to /Applications/${PROJECT_NAME}/"
    else
        use_app_folder=false
        app_install_root="$PKG_ROOT/Applications"
        echo "📁 Single app - installing directly to /Applications/"
    fi

    # Create the appropriate directory structure
    mkdir -p "$app_install_root"

    # Install standalone app
    if [[ "$has_standalone" == "true" ]]; then
        echo "Including standalone app in installer..."
        cp -R "$STANDALONE_PATH" "$app_install_root/"
    fi

    # Install diagnostics app (if exists)
    if [[ "$has_diagnostics" == "true" ]]; then
        echo "Including diagnostics app in installer..."
        cp -R "$DIAGNOSTIC_PATH" "$app_install_root/"
    fi

    # Install uninstaller
    if [[ "$has_uninstaller" == "true" ]]; then
        echo "Including uninstaller..."
        local uninstaller_path="$app_install_root/${PROJECT_NAME} Uninstaller.command"

        # Copy and customize the uninstaller template
        sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            -e "s/{{PROJECT_BUNDLE_ID}}/$PROJECT_BUNDLE_ID/g" \
            -e "s/{{GITHUB_USER}}/${GITHUB_USER:-owner}/g" \
            -e "s/{{GITHUB_REPO}}/${GITHUB_REPO}/g" \
            "scripts/uninstall_template.sh" > "$uninstaller_path"

        chmod +x "$uninstaller_path"
    fi

    # Build the package
    if [[ "$sign_package" == "true" ]]; then
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
    else
        # Unsigned package for fast testing
        PKG_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}_unsigned.pkg"

        pkgbuild --root "$PKG_ROOT" \
            --identifier "$PROJECT_BUNDLE_ID" \
            --version "$VERSION" \
            "$PKG_PATH"
    fi

    # Create DMG
    if [[ "$sign_package" == "true" ]]; then
        DMG_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}.dmg"
    else
        DMG_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}_unsigned.dmg"
    fi

    echo "Creating DMG..."

    DMG_ROOT="/tmp/${PROJECT_NAME}_dmg"
    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp "$PKG_PATH" "$DMG_ROOT/"

    hdiutil create -volname "${PROJECT_NAME} ${VERSION}" \
        -srcfolder "$DMG_ROOT" \
        -ov -format UDZO \
        "$DMG_PATH"

    # Sign the DMG if signing
    if [[ "$sign_package" == "true" ]]; then
        codesign --force --sign "$APP_CERT" "$DMG_PATH"

        # Create ZIP of the DMG for easier distribution
        ZIP_PATH="$HOME/Desktop/${PROJECT_NAME}_${VERSION}.zip"
        cd "$HOME/Desktop"
        zip -9 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")"
    fi

    # Clean up
    rm -rf "$PKG_ROOT" "$DMG_ROOT"

    echo -e "${GREEN}Installer created:${NC}"
    echo "  PKG: $PKG_PATH"
    echo "  DMG: $DMG_PATH"
    if [[ "$sign_package" == "true" ]]; then
        echo "  ZIP: $ZIP_PATH"
    fi
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

# Function to enable GitHub Pages
enable_github_pages() {
    local repo="${GITHUB_USER:-owner}/${GITHUB_REPO}"

    echo ""
    echo -e "${GREEN}Enabling GitHub Pages...${NC}"

    # Check if Pages is already enabled
    if gh api "repos/${repo}/pages" &>/dev/null; then
        echo "✅ GitHub Pages already enabled"
        echo "   URL: https://${GITHUB_USER:-owner}.github.io/${GITHUB_REPO}/"
        return 0
    fi

    # Enable Pages on main branch
    if gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "repos/${repo}/pages" \
        -f source[branch]=main \
        -f source[path]=/ \
        2>/dev/null; then
        echo "✅ GitHub Pages enabled"
        echo "   URL: https://${GITHUB_USER:-owner}.github.io/${GITHUB_REPO}/"
        return 0
    else
        echo -e "${YELLOW}⚠️  Could not enable GitHub Pages automatically${NC}"
        echo "Enable manually: Settings → Pages → Deploy from main branch"
        return 1
    fi
}

# Function to generate and publish GitHub Pages landing page
generate_and_publish_landing_page() {
    local repo="${GITHUB_USER:-owner}/${GITHUB_REPO}"

    echo ""
    echo -e "${GREEN}Setting up GitHub Pages landing page...${NC}"

    # Check if templates directory exists
    if [[ ! -f "templates/index.html.template" ]]; then
        echo -e "${YELLOW}⚠️  Warning: templates/index.html.template not found${NC}"
        echo "   Skipping landing page generation"
        return 1
    fi

    # Check if index.html already exists in repo (unless regenerating)
    if [[ "$REGENERATE_PAGE" != "true" ]]; then
        if gh api "repos/${repo}/contents/index.html" &>/dev/null; then
            echo "✅ Landing page already exists"
            echo "   URL: https://${GITHUB_USER:-owner}.github.io/${GITHUB_REPO}/"
            echo "   (Use --regenerate-page to update)"
            return 0
        fi
    else
        echo "🔄 Regenerating landing page..."
    fi

    # Get plugin description from .env or use default
    local plugin_desc="${PLUGIN_DESCRIPTION:-Download the latest version of ${PROJECT_NAME}}"

    # Generate index.html from template
    local temp_index="/tmp/${PROJECT_NAME}_index.html"
    sed -e "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" \
        -e "s/{{PLUGIN_DESCRIPTION}}/${plugin_desc}/g" \
        -e "s/{{GITHUB_USER}}/${GITHUB_USER:-owner}/g" \
        -e "s/{{GITHUB_REPO}}/${GITHUB_REPO}/g" \
        "templates/index.html.template" > "$temp_index"

    echo "📝 Generated landing page from template"

    # Create a temporary directory for git operations
    local temp_dir="/tmp/${PROJECT_NAME}_pages_$$"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"

    # Clone the repo
    if ! git clone "https://github.com/${repo}.git" "$temp_dir" &>/dev/null; then
        echo -e "${RED}❌ Failed to clone repository${NC}"
        rm -rf "$temp_dir"
        return 1
    fi

    cd "$temp_dir" || return 1

    # Copy the generated index.html
    cp "$temp_index" index.html

    # Check if there are any changes
    if git diff --quiet index.html 2>/dev/null && [[ -f index.html ]]; then
        echo "✅ Landing page is already up to date"
        cd "$PROJECT_ROOT"
        rm -rf "$temp_dir"
        return 0
    fi

    # Commit and push
    git add index.html

    if [[ "$REGENERATE_PAGE" == "true" ]]; then
        git commit -m "Update auto-download landing page" || true
    else
        git commit -m "Add auto-download landing page

This page automatically fetches and downloads the latest release.
Generated from templates/index.html.template." || true
    fi

    if git push origin main &>/dev/null; then
        echo "✅ Landing page published"
        echo "   URL: https://${GITHUB_USER:-owner}.github.io/${GITHUB_REPO}/"
        echo "   (May take a few minutes to become available)"
    else
        echo -e "${YELLOW}⚠️  Could not push to repository${NC}"
        echo "   You may need to manually commit and push index.html"
    fi

    # Return to project root and cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir" "$temp_index"
}

# Function to show release URLs in consistent order
show_release_urls() {
    if [[ -z "$RELEASE_TAG" ]]; then
        return 0
    fi

    local release_repo="${GITHUB_USER:-owner}/${GITHUB_REPO}"
    local desktop="$HOME/Desktop"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 Release Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "📦 GitHub Release: https://github.com/${release_repo}/releases/tag/$RELEASE_TAG"
    echo "🌐 Auto-Download:   https://${GITHUB_USER:-owner}.github.io/${GITHUB_REPO}/"
    echo ""
    echo "Download links (copy/paste ready):"
    echo ""

    # PKG (first - primary download)
    local pkg_file=$(find "$desktop" -name "${PROJECT_NAME}*.pkg" -not -name "*component*" -not -name "*vst3*" -not -name "*standalone*" -not -name "*resources*" | head -1)
    if [[ -n "$pkg_file" ]] && [[ -f "$pkg_file" ]]; then
        local pkg_name=$(basename "$pkg_file")
        echo "  📄 PKG Installer:  https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${pkg_name}"
    fi

    # DMG (second)
    local dmg_file=$(find "$desktop" -name "${PROJECT_NAME}*.dmg" | head -1)
    if [[ -n "$dmg_file" ]] && [[ -f "$dmg_file" ]]; then
        local dmg_name=$(basename "$dmg_file")
        echo "  💿 DMG Disk Image: https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${dmg_name}"
    fi

    # ZIP (third)
    local zip_file=$(find "$desktop" -name "${PROJECT_NAME}*.zip" | head -1)
    if [[ -n "$zip_file" ]] && [[ -f "$zip_file" ]]; then
        local zip_name=$(basename "$zip_file")
        echo "  🗜️  ZIP Archive:    https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${zip_name}"
    fi

    echo ""
    echo "Copy any URL above to share with users! 🚀"
    echo ""
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

    # Export for show_release_urls
    RELEASE_TAG="v$VERSION"
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
    echo "Creating release $RELEASE_TAG..."
    gh release create "$RELEASE_TAG" \
        --repo "${GITHUB_USER:-owner}/${GITHUB_REPO}" \
        --title "$release_title" \
        --notes "$release_notes" \
        "${artifacts[@]}"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Successfully created GitHub release${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create GitHub release${NC}"
        RELEASE_TAG=""  # Clear on failure
        return 1
    fi
}

# Main build process
main() {
    # Always bump version (even for local builds to ensure proper versioning)
    bump_version

    # Check DiagnosticKit setup early (before building anything)
    check_diagnostic_setup

    # Configure and build
    configure_cmake
    build_xcode

    # Build DiagnosticKit if enabled (after main plugins are built)
    build_diagnostics

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
        unsigned)
            # Create unsigned package for fast testing
            create_installer false
            ;;
        pkg)
            # Build, sign, notarize, and package (no GitHub release)
            sign_plugins
            notarize_plugins
            create_installer true
            ;;
        publish)
            sign_plugins
            notarize_plugins
            create_installer true
            create_github_release
            enable_github_pages
            generate_and_publish_landing_page
            show_release_urls
            ;;
    esac

    echo -e "${GREEN}Build complete!${NC}"

    # Show what was built in this session
    if [[ ${#BUILT_PLUGINS[@]} -gt 0 ]]; then
        echo ""
        echo "Plugins built in this session:"

        # Remove duplicates and sort
        local unique_plugins=($(printf '%s\n' "${BUILT_PLUGINS[@]}" | sort -u))

        # Process each built plugin
        for entry in "${unique_plugins[@]}"; do
            # Parse format and plugin name from "FORMAT:PluginName"
            local format="${entry%%:*}"
            local plugin_name="${entry#*:}"

            case "$format" in
                AU)
                    # Search for component files matching the plugin name (handles spaces in filenames)
                    local au_dir="$HOME/Library/Audio/Plug-Ins/Components"
                    if [[ -d "$au_dir" ]]; then
                        # Find files that match the plugin name pattern
                        while IFS= read -r -d '' plugin_path; do
                            local basename=$(basename "$plugin_path" .component)
                            # Check if basename matches plugin_name (with or without spaces/punctuation)
                            local normalized_basename=$(echo "$basename" | tr -d ' -')
                            local normalized_plugin=$(echo "$plugin_name" | tr -d ' -')
                            if [[ "$normalized_basename" == "$normalized_plugin" ]]; then
                                echo "  AU: $plugin_path"
                            fi
                        done < <(find "$au_dir" -maxdepth 1 -name "*.component" -print0 2>/dev/null)
                    fi
                    ;;
                VST3)
                    # Search for VST3 files matching the plugin name
                    local vst3_dir="$HOME/Library/Audio/Plug-Ins/VST3"
                    if [[ -d "$vst3_dir" ]]; then
                        while IFS= read -r -d '' plugin_path; do
                            local basename=$(basename "$plugin_path" .vst3)
                            local normalized_basename=$(echo "$basename" | tr -d ' -')
                            local normalized_plugin=$(echo "$plugin_name" | tr -d ' -')
                            if [[ "$normalized_basename" == "$normalized_plugin" ]]; then
                                echo "  VST3: $plugin_path"
                            fi
                        done < <(find "$vst3_dir" -maxdepth 1 -name "*.vst3" -print0 2>/dev/null)
                    fi
                    ;;
                Standalone)
                    # Search for app files in build directory
                    local standalone_dir="$BUILD_DIR/${PROJECT_NAME}_artefacts/$CMAKE_BUILD_TYPE/Standalone"
                    if [[ -d "$standalone_dir" ]]; then
                        while IFS= read -r -d '' app_path; do
                            local basename=$(basename "$app_path" .app)
                            local normalized_basename=$(echo "$basename" | tr -d ' -')
                            local normalized_plugin=$(echo "$plugin_name" | tr -d ' -')
                            if [[ "$normalized_basename" == "$normalized_plugin" ]]; then
                                echo "  App: $app_path"
                            fi
                        done < <(find "$standalone_dir" -maxdepth 1 -name "*.app" -print0 2>/dev/null)
                    fi
                    ;;
            esac
        done
    fi
}

# Run main function
main

# JUCE-Plugin-Starter Update Plans

**Last Updated**: 2025-10-10
**Status**: Planning Phase
**Source**: PlunderTube build.sh enhancements

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [New Features Summary](#new-features-summary)
3. [Phase 1: Core Build System Features](#phase-1-core-build-system-features)
4. [Phase 2: init_plugin_project.sh Improvements](#phase-2-init_plugin_projectsh-improvements)
5. [Phase 3: DiagnosticKit Integration](#phase-3-diagnostickit-integration)
6. [Phase 4: Installation Path Changes](#phase-4-installation-path-changes)
7. [Phase 5: Smart /Applications Organization](#phase-5-smart-applications-organization)
8. [Phase 6: GitHub Release Output Consistency](#phase-6-github-release-output-consistency)
9. [Phase 7: Auto-Download Landing Page](#phase-7-auto-download-landing-page)
10. [Phase 8: Documentation Updates](#phase-8-documentation-updates)
11. [Phase 9: Testing & Validation](#phase-9-testing--validation)
12. [Implementation Priority](#implementation-priority)
13. [Security Considerations](#security-considerations)
14. [Known Challenges & Solutions](#known-challenges--solutions)

---

## Overview

This document outlines the comprehensive plan to bring new features from PlunderTube to JUCE-Plugin-Starter, including:
- Enhanced build system with new actions (uninstall, unsigned, pkg)
- Multiple target support for builds
- Optional DiagnosticKit integration for user support
- Improved init_plugin_project.sh flow
- Better installation paths avoiding user permission prompts

---

## New Features Summary

### ✅ From PlunderTube build.sh

1. **`uninstall` action** - Quick uninstall for dev workflows
2. **`unsigned` action** - Fast unsigned installer builds for testing
3. **`pkg` action** - Package without GitHub release
4. **Multiple target support** - Build multiple formats in one command (e.g., `au vst3`)
5. **Build config override** - Explicit debug/release/prod settings
6. **DiagnosticKit app** - Optional user support tool
7. **Enhanced error handling** - Better pipe and undefined variable detection
8. **Improved uninstaller** - Dual-mode (repair vs complete uninstall)

### ✅ New Requirements

9. **Improved init flow** - Better GitHub vs no-GitHub handling
10. **Diagnostics opt-in** - Ask before creating GitHub repo
11. **Better exit messages** - Consistent regardless of GitHub choice
12. **Proper git initialization** - Even without GitHub
13. **Smart /Applications folder organization** - Bundle multiple apps in folder
14. **Consistent GitHub URL output** - Match PlunderTube's deliberate order
15. **Auto-download landing page** - index.html for latest release

---

## Phase 1: Core Build System Features

### 1.1 Uninstall Action ✅

**Priority**: HIGH
**Complexity**: MEDIUM

#### Implementation

**New File**: `scripts/uninstall_TEMPLATE.command`
- Template uninstaller script with placeholders
- Will be customized by init_plugin_project.sh
- Handles spaces in project names properly

**Key Features**:
```bash
# Two modes:
1. Repair/Reinstall Mode
   - Remove plugins only (AU, VST3, Standalone, Diagnostics)
   - Clear Audio Unit cache
   - KEEP package receipts (pkgutil tracking)
   - KEEP all user data (Application Support, samples)
   - Provide link to latest installer

2. Complete Uninstall Mode
   - Remove all plugins
   - Remove all user data
   - Forget all package receipts
   - Optional backup before removal
   - Self-delete after completion
```

**Non-Interactive Mode**:
```bash
# For dev workflows
./scripts/build.sh uninstall
# or
bash uninstall_ProjectName.command --non-interactive
```

**Paths to Handle**:
```bash
# Plugins
USER_AU_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
SYSTEM_AU_PATH="/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
USER_VST3_PATH="$HOME/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
SYSTEM_VST3_PATH="/Library/Audio/Plug-Ins/VST3/${PROJECT_NAME}.vst3"
STANDALONE_PATH="/Applications/${PROJECT_NAME}.app"
DIAGNOSTICS_PATH="/Applications/${PROJECT_NAME} Diagnostics.app"

# User Data (NEW PATHS - see Phase 4)
APP_SUPPORT_PATH="$HOME/Library/Application Support/${PROJECT_NAME}"
SAMPLES_PATH="$APP_SUPPORT_PATH/Samples"
PRESETS_PATH="$APP_SUPPORT_PATH/Presets"
LOGS_PATH="$HOME/Library/Logs/${PROJECT_NAME}"
CACHE_PATH="$HOME/Library/Caches/${PROJECT_BUNDLE_ID}"

# Package Receipts
RECEIPTS=(
    "${PROJECT_BUNDLE_ID}.core"
    "${PROJECT_BUNDLE_ID}.au"
    "${PROJECT_BUNDLE_ID}.vst3"
    "${PROJECT_BUNDLE_ID}.standalone"
    "${PROJECT_BUNDLE_ID}.diagnostics"
)
```

**Usage Examples**:
```bash
# Interactive mode (launched from Finder or terminal)
open uninstall_MyPlugin.command

# Non-interactive (from build.sh)
./scripts/build.sh uninstall

# Dev workflow
./scripts/build.sh uninstall && ./scripts/build.sh unsigned
```

**Integration with build.sh**:
```bash
# In build.sh main() - handle early exit
if [[ "$ACTION" == "uninstall" ]]; then
    run_uninstaller
    exit $?
fi

# Function to run uninstaller
run_uninstaller() {
    local uninstaller_path="$PROJECT_ROOT/uninstall_${PROJECT_NAME}.command"

    if [[ ! -f "$uninstaller_path" ]]; then
        echo -e "${YELLOW}Warning: Uninstaller not found at $uninstaller_path${NC}"
        echo "This is optional - no uninstaller available"
        return 0
    fi

    echo -e "${GREEN}Running uninstaller (non-interactive mode)...${NC}"

    # Run in non-interactive mode (complete uninstall, no backup)
    if bash "$uninstaller_path" --non-interactive; then
        echo -e "${GREEN}✅ Uninstall completed successfully${NC}"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${YELLOW}ℹ️  No ${PROJECT_NAME} components found to uninstall${NC}"
            return 0
        else
            echo -e "${RED}❌ Uninstall failed with exit code $exit_code${NC}"
            return 1
        fi
    fi
}
```

**Special Handling for Spaces**:
```bash
# Always quote variables with potential spaces
rm -rf "/Applications/${PROJECT_NAME} Diagnostics.app"
open "/Applications/${PROJECT_NAME}.app"
```

---

### 1.2 Unsigned Action ✅

**Priority**: HIGH
**Complexity**: LOW

#### Implementation

**Purpose**: Create unsigned installer packages for fast development iteration

**Usage**:
```bash
./scripts/build.sh unsigned              # Release build (default)
./scripts/build.sh unsigned debug        # Debug build (with logging)
./scripts/build.sh au vst3 unsigned      # Build specific targets
```

**Benefits**:
- Skip code signing (saves ~2-3 minutes)
- Skip notarization (saves ~5-10 minutes)
- Perfect for testing installer layout/structure
- Fast iteration during development

**In build.sh**:
```bash
# Add to usage()
ACTIONS:
  ...
  unsigned    Build and create unsigned installer package (fast testing)

Examples:
  $0 unsigned              # Build unsigned installer (Release by default)
  $0 unsigned debug        # Build unsigned installer with Debug config

# Add to main action switch
case "$ACTION" in
    ...
    unsigned)
        # Build unsigned installer package for testing
        if [[ "$TARGET" != "diagnostics" ]]; then
            echo -e "${GREEN}Creating unsigned installer for testing...${NC}"
            create_unsigned_installer
        fi
        ;;
esac

# New function
create_unsigned_installer() {
    echo -e "${GREEN}Creating unsigned installer package for testing...${NC}"

    # Build the installer (unsigned)
    PKG_PATH=$(build_installer_components "false" "_unsigned")

    echo -e "${GREEN}Unsigned installer created:${NC}"
    echo "  PKG: $PKG_PATH"
    echo -e "${YELLOW}Note: This package is unsigned and for testing only${NC}"
}
```

**Warning Display**:
```bash
echo -e "${YELLOW}⚠️  UNSIGNED INSTALLER WARNING${NC}"
echo "This installer is unsigned and should ONLY be used for:"
echo "  • Local testing"
echo "  • Installer layout verification"
echo "  • Quick development iteration"
echo ""
echo "For distribution, use: ./scripts/build.sh all publish"
```

---

### 1.3 PKG Action ✅

**Priority**: MEDIUM
**Complexity**: LOW

#### Implementation

**Purpose**: Build, sign, notarize, and package WITHOUT creating GitHub release

**Usage**:
```bash
./scripts/build.sh all pkg
./scripts/build.sh au vst3 pkg
```

**Use Cases**:
- Create distributable package for manual distribution
- Test full signed/notarized build without publishing
- Send package directly to beta testers
- Keep releases separate from code commits

**In build.sh**:
```bash
# Add to usage()
ACTIONS:
  ...
  pkg         Build, sign, notarize, and package (like publish but no GitHub release)

Examples:
  $0 all pkg              # Create signed package without publishing

# Add to main action switch
case "$ACTION" in
    ...
    pkg)
        if [[ "$TARGET" != "diagnostics" ]]; then
            sign_plugins
            notarize_plugins
        fi
        create_installer

        echo -e "${GREEN}✅ Package created without GitHub release${NC}"
        ;;
esac
```

---

### 1.4 Multiple Target Support ✅

**Priority**: HIGH
**Complexity**: MEDIUM

#### Implementation

**Purpose**: Build multiple plugin formats in a single command

**Current Behavior** (single target only):
```bash
./scripts/build.sh au         # Build AU only
./scripts/build.sh vst3       # Build VST3 only
./scripts/build.sh standalone # Build Standalone only
```

**New Behavior** (multiple targets):
```bash
./scripts/build.sh au vst3                # Build AU and VST3
./scripts/build.sh au standalone          # Build AU and Standalone
./scripts/build.sh vst3 diagnostics       # Build VST3 and Diagnostics
./scripts/build.sh au vst3 standalone     # Build all three
./scripts/build.sh standalone diagnostics test  # Build, then test
```

**Implementation Changes**:

```bash
# Change TARGETS from string to array
TARGETS=()  # Array to hold multiple targets
ACTION="local"

# Update argument processing
while [[ $# -gt 0 ]]; do
    case "$1" in
        all|au|vst3|standalone|diagnostics)
            TARGETS+=("$1")
            shift
            ;;
        local|test|sign|notarize|publish|unsigned|pkg|uninstall)
            ACTION="$1"
            shift
            ;;
        debug|release|prod)
            BUILD_CONFIG="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Default to "all" if no targets specified
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=("all")
fi

# Determine which formats to build based on targets
BUILD_FORMATS=""
BUILD_DIAGNOSTICS=false

for TARGET in "${TARGETS[@]}"; do
    case "$TARGET" in
        all)
            BUILD_FORMATS="AU VST3 Standalone"
            BUILD_DIAGNOSTICS=true
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
        diagnostics)
            BUILD_DIAGNOSTICS=true
            ;;
    esac
done

# Trim leading/trailing spaces
BUILD_FORMATS=$(echo "$BUILD_FORMATS" | xargs)

# Display what we're building
echo -e "${GREEN}Building ${PROJECT_NAME}${NC}"
echo "Targets: ${TARGETS[*]}"
echo "Action: $ACTION"
if [[ -n "$BUILD_FORMATS" ]]; then
    echo "Formats: $BUILD_FORMATS"
fi
if [[ "$BUILD_DIAGNOSTICS" == "true" ]]; then
    echo "DiagnosticKit: Enabled"
fi
```

**Update Usage Examples**:
```bash
usage() {
    cat << EOF
Usage: $0 [TARGET(s)] [ACTION] [BUILD_CONFIG]

TARGETS (can specify multiple):
  all         Build all formats (default)
  au          Build Audio Unit only
  vst3        Build VST3 only
  standalone  Build Standalone only
  diagnostics Build DiagnosticKit app (WIP)

Examples:
  $0                        # Build all formats locally
  $0 au                     # Build AU only
  $0 au vst3                # Build both AU and VST3
  $0 au standalone test     # Build AU and Standalone, then test
  $0 standalone diagnostics # Build Standalone and DiagnosticKit
  $0 all publish            # Build all and publish
EOF
}
```

---

### 1.5 Build Configuration Override ✅

**Priority**: MEDIUM
**Complexity**: LOW

#### Implementation

**Purpose**: Explicitly set build type regardless of action

**Current Behavior**:
- Build type determined automatically based on action
- `publish` always uses Release
- No way to override

**New Behavior**:
```bash
./scripts/build.sh all publish debug     # Publish with Debug (not recommended)
./scripts/build.sh unsigned debug        # Unsigned installer with logging
./scripts/build.sh all local release     # Local Release build
./scripts/build.sh vst3 test debug       # Test Debug build
```

**Implementation**:
```bash
# Add BUILD_CONFIG variable
BUILD_CONFIG=""  # Can override with debug, release, prod

# Update usage
BUILD_CONFIG (optional):
  debug       Debug build (unoptimized, with logging)
  release     Release build (optimized, no debug logs) - DEFAULT for publish
  prod        Production build (maximum optimization)

# Process build config argument
debug|release|prod)
    BUILD_CONFIG="$1"
    shift
    ;;

# Determine CMAKE_BUILD_TYPE
if [[ -n "$BUILD_CONFIG" ]]; then
    # User explicitly specified build config
    BUILD_CONFIG_LOWER=$(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]')
    case "$BUILD_CONFIG_LOWER" in
        debug)
            CMAKE_BUILD_TYPE="Debug"
            ;;
        release)
            CMAKE_BUILD_TYPE="Release"
            ;;
        prod)
            CMAKE_BUILD_TYPE="Release"
            ;;
        *)
            echo -e "${RED}Unknown build config: $BUILD_CONFIG${NC}"
            exit 1
            ;;
    esac
elif [[ "$ACTION" == "publish" ]]; then
    # Publish defaults to Release unless overridden
    CMAKE_BUILD_TYPE="Release"
else
    # Use default from .env or fallback
    CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
fi

# Show config if overridden
echo "Build Type: $CMAKE_BUILD_TYPE"
if [[ -n "$BUILD_CONFIG" ]]; then
    echo "Build Config Override: $BUILD_CONFIG"
fi
```

---

### 1.6 Enhanced Error Handling ✅

**Priority**: LOW
**Complexity**: LOW

#### Implementation

**Change**:
```bash
# Old
set -e  # Exit on error

# New
set -euo pipefail  # Exit on error, undefined vars, and pipe failures
```

**Benefits**:
- `-e`: Exit immediately if command fails
- `-u`: Error on undefined variables (catches typos)
- `-o pipefail`: Detect failures in pipes (e.g., `cmd1 | cmd2`)

**Additional Safety**:
```bash
# Use safer variable expansion
if [[ -z "${COMPANY_NAME:-}" ]]; then
    COMPANY_NAME="${DEVELOPER_NAME:-Unknown Company}"
fi

# Instead of
if [[ -z "$COMPANY_NAME" ]]; then  # Can error if unset with -u
```

---

## Phase 2: init_plugin_project.sh Improvements

### 2.1 Critical Flow Improvements ⚠️

**Priority**: CRITICAL
**Complexity**: MEDIUM

#### Current Issues

1. **Abrupt ending when user declines GitHub repo**
   - Script asks if user wants to create GitHub repo
   - If user says "no", script just continues to success message
   - No clear confirmation that git repo was still initialized locally

2. **Inconsistent success messages**
   - GitHub URL shown only if GITHUB_USER set
   - But doesn't check if repo was actually created
   - "Push updates" instruction shown even if no remote exists

3. **No clear git initialization**
   - Git init happens earlier in script
   - User might not realize local repo is ready even without GitHub

4. **Diagnostics questions come AFTER GitHub section**
   - Should come BEFORE to inform GitHub repo creation decision
   - Diagnostic repo creation should be part of GitHub flow

#### Proposed New Flow

```
1. Welcome & Continue prompt
2. Project name & basic info
3. Developer information
4. Bundle ID generation
5. GitHub username (optional)
6. Apple Developer settings (optional)
7. ⭐ NEW: Diagnostics opt-in (BEFORE GitHub)
8. Copy & customize template files
9. Initialize local Git repository
10. ⭐ IMPROVED: GitHub repository creation (with diagnostics repo)
11. ⭐ IMPROVED: Success summary (consistent regardless of GitHub)
12. ⭐ NEW: Diagnostics setup instructions (if enabled)
```

### 2.2 Diagnostics Opt-In (NEW)

**Priority**: HIGH
**Complexity**: MEDIUM

#### Implementation

**Location in Script**: After Apple Developer settings, BEFORE GitHub section

```bash
# After Apple Developer settings...

# --- Diagnostics Configuration (Optional) ---
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Optional: Diagnostics App${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "DiagnosticKit is a user-friendly macOS app that:"
echo "  • Collects system info, plugin status, and crash logs"
echo "  • Allows users to submit reports with one click"
echo "  • Submits to a private GitHub repository (no email needed)"
echo "  • Requires minimal setup (2-3 minutes)"
echo ""
echo -e "${CYAN}ℹ️  This is completely optional and can be added later${NC}"
echo ""

ENABLE_DIAGNOSTICS="false"
DIAGNOSTIC_GITHUB_REPO=""
DIAGNOSTIC_NEEDS_SETUP=false

response=$(get_yes_no "Would you like to include DiagnosticKit in this project?" "n")
if [ "$response" = "y" ]; then
    echo ""
    echo -e "${GREEN}✅ DiagnosticKit will be included${NC}"
    echo ""

    # Confirm the choice
    echo -e "${YELLOW}Before we continue, please note:${NC}"
    echo "  1. DiagnosticKit will be added to your project"
    echo "  2. A private GitHub repository will be created for diagnostic reports"
    echo "  3. You'll need to complete a quick setup after project creation"
    echo ""

    response=$(get_yes_no "Confirm: Include DiagnosticKit?" "y")
    if [ "$response" = "y" ]; then
        ENABLE_DIAGNOSTICS="true"
        DIAGNOSTIC_NEEDS_SETUP=true

        # Suggest diagnostic repo name
        if [ -n "$GITHUB_USER" ]; then
            SUGGESTED_DIAG_REPO="${GITHUB_USER}/${PROJECT_FOLDER}-diagnostics"
        else
            SUGGESTED_DIAG_REPO="${PROJECT_FOLDER}-diagnostics"
        fi

        echo ""
        echo -e "${CYAN}📦 Diagnostic Repository Setup${NC}"
        echo "Diagnostic reports will be submitted to a private GitHub repository."
        echo ""
        echo -e "${GREEN}Suggested repository: ${SUGGESTED_DIAG_REPO}${NC}"
        echo ""

        response=$(get_yes_no "Use this repository name?" "y")
        if [ "$response" = "y" ]; then
            DIAGNOSTIC_GITHUB_REPO="$SUGGESTED_DIAG_REPO"
        else
            while true; do
                DIAGNOSTIC_GITHUB_REPO=$(get_confirmed_input "Enter diagnostic repository (format: owner/repo or just repo-name): " "$SUGGESTED_DIAG_REPO")
                # Validate format (basic check)
                if [[ "$DIAGNOSTIC_GITHUB_REPO" =~ ^[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)?$ ]]; then
                    break
                else
                    echo -e "${RED}Invalid format. Use 'owner/repo' or 'repo-name'${NC}"
                fi
            done
        fi

        echo ""
        echo -e "${GREEN}✅ DiagnosticKit configured${NC}"
        echo -e "${CYAN}Repository: $DIAGNOSTIC_GITHUB_REPO${NC}"
    else
        echo ""
        echo -e "${YELLOW}DiagnosticKit will not be included${NC}"
        ENABLE_DIAGNOSTICS="false"
        DIAGNOSTIC_NEEDS_SETUP=false
    fi
else
    echo ""
    echo -e "${CYAN}DiagnosticKit will not be included. You can add it later if needed.${NC}"
fi

echo ""
```

**Add to .env Generation**:
```bash
# In the .env creation section
cat > .env << EOF
# ... existing content ...

# ============================================================================
# DIAGNOSTICS CONFIGURATION (Optional)
# ============================================================================
# Enable DiagnosticKit app for user support
ENABLE_DIAGNOSTICS=$ENABLE_DIAGNOSTICS

# GitHub repository for diagnostic reports (format: owner/repo)
DIAGNOSTIC_GITHUB_REPO=$DIAGNOSTIC_GITHUB_REPO

# GitHub Personal Access Token for diagnostic submissions
# Create at: https://github.com/settings/tokens (Fine-grained, write-only to issues)
# Run ./scripts/setup_diagnostic_repo.sh for guided setup
DIAGNOSTIC_GITHUB_PAT=

# Support contact (shown in diagnostic app)
DIAGNOSTIC_SUPPORT_EMAIL=${APPLE_ID:-}

# Project website (optional)
PROJECT_WEBSITE=
EOF
```

### 2.3 Improved GitHub Repository Creation

**Priority**: HIGH
**Complexity**: MEDIUM

#### Enhanced GitHub Section

```bash
# --- Create GitHub Repository (if requested) ---
GITHUB_REPO_CREATED=false  # Track if repo was actually created

if [ -n "$GITHUB_USER" ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}GitHub Integration${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Show what will be created
    echo "The following can be created on GitHub:"
    echo "  • Main repository: ${GITHUB_USER}/${PROJECT_FOLDER}"
    if [ "$ENABLE_DIAGNOSTICS" = "true" ]; then
        echo "  • Diagnostics repository: ${DIAGNOSTIC_GITHUB_REPO}"
    fi
    echo ""

    response=$(get_yes_no "Create GitHub repository?" "y")
    if [ "$response" = "y" ]; then

        # Ask for repository visibility
        echo ""
        echo -e "${CYAN}💾 What kind of GitHub repository do you want to create?${NC}"
        echo -e "${MAGENTA}1. 🔒 Private (recommended for personal/work projects)${NC}"
        echo -e "${MAGENTA}2. 🔓 Public (visible to everyone)${NC}"
        echo ""

        # Check if stdin is a terminal (interactive mode) or pipe/heredoc (automated mode)
        if [ ! -t 0 ]; then
            # Non-interactive mode - default to private
            repo_choice="1"
        else
            # Interactive mode
            read -e -p "Enter choice (1/2, default: 1): " repo_choice
        fi

        if [[ "$repo_choice" == "2" ]]; then
            REPO_VISIBILITY="public"
            VISIBILITY_FLAG="--public"
            echo -e "${GREEN}You chose: 🔓 Public repository${NC}"
        else
            REPO_VISIBILITY="private"
            VISIBILITY_FLAG="--private"
            echo -e "${GREEN}You chose: 🔒 Private repository${NC}"
        fi

        echo ""
        response=$(get_yes_no "✅ Confirm: Create $REPO_VISIBILITY repository?" "y")
        if [ "$response" = "y" ]; then

            # --- Check GitHub CLI is available and authenticated ---
            if ! command -v gh &> /dev/null; then
                echo -e "${RED}❌ GitHub CLI (gh) not found.${NC}"
                echo -e "${CYAN}Install it: https://cli.github.com/${NC}"
                echo ""
                echo -e "${YELLOW}Continuing without GitHub integration...${NC}"
            elif ! gh api user &> /dev/null; then
                echo -e "${YELLOW}⚠️  GitHub CLI is not properly authenticated for API operations.${NC}"
                echo -e "${CYAN}👉 Run: gh auth login${NC}"
                echo ""
                echo -e "${YELLOW}Continuing without GitHub integration...${NC}"
            else
                # GitHub CLI is ready

                # Create main repository
                echo ""
                echo -e "${CYAN}🌐 Creating $REPO_VISIBILITY GitHub repository...${NC}"
                if gh repo create "$PROJECT_FOLDER" $VISIBILITY_FLAG --description "$PLUGIN_NAME - Audio Plugin built with JUCE"; then
                    git remote add origin "https://github.com/$GITHUB_USER/$PROJECT_FOLDER.git"
                    git branch -M main
                    git push -u origin main
                    echo -e "${GREEN}✓ Main repository created and pushed${NC}"
                    GITHUB_REPO_CREATED=true

                    # Create diagnostics repository if enabled
                    if [ "$ENABLE_DIAGNOSTICS" = "true" ]; then
                        echo ""
                        echo -e "${CYAN}🌐 Creating private diagnostics repository...${NC}"

                        # Extract repo name (handle both "owner/repo" and "repo" formats)
                        if [[ "$DIAGNOSTIC_GITHUB_REPO" =~ / ]]; then
                            DIAG_REPO_NAME="${DIAGNOSTIC_GITHUB_REPO##*/}"
                        else
                            DIAG_REPO_NAME="$DIAGNOSTIC_GITHUB_REPO"
                            DIAGNOSTIC_GITHUB_REPO="${GITHUB_USER}/${DIAG_REPO_NAME}"
                        fi

                        if gh repo create "$DIAG_REPO_NAME" --private --description "$PLUGIN_NAME - Diagnostic Reports (Private)"; then
                            echo -e "${GREEN}✓ Diagnostics repository created: $DIAGNOSTIC_GITHUB_REPO${NC}"

                            # Update .env with full repo path
                            sed -i '' "s|DIAGNOSTIC_GITHUB_REPO=.*|DIAGNOSTIC_GITHUB_REPO=$DIAGNOSTIC_GITHUB_REPO|" .env
                        else
                            echo -e "${YELLOW}⚠️  Could not create diagnostics repository${NC}"
                            echo "You can create it manually later: https://github.com/new"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to create GitHub repository${NC}"
                    echo -e "${YELLOW}Continuing with local git repository only...${NC}"
                fi
            fi
        else
            echo ""
            echo -e "${YELLOW}Skipping GitHub repository creation${NC}"
        fi
    else
        echo ""
        echo -e "${CYAN}No GitHub repository will be created.${NC}"
        echo -e "${CYAN}Your project has a local git repository and is ready to use.${NC}"
    fi
else
    echo ""
    echo -e "${CYAN}ℹ️  No GitHub username provided - skipping GitHub integration${NC}"
    echo -e "${CYAN}Your project has a local git repository and is ready to use.${NC}"
fi

echo ""
```

### 2.4 Improved Success Summary

**Priority**: HIGH
**Complexity**: LOW

#### Consistent Success Messages

```bash
# --- Success Summary ---
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Success! Your plugin project is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📁 Project Details${NC}"
echo -e "${CYAN}Location: $(pwd)${NC}"
echo -e "${CYAN}Plugin Name: $PLUGIN_NAME${NC}"
echo -e "${CYAN}Project Folder: $PROJECT_FOLDER${NC}"
echo -e "${CYAN}Bundle ID: $PROJECT_BUNDLE_ID${NC}"

# Show GitHub info if repo was actually created
if [ "$GITHUB_REPO_CREATED" = true ]; then
    echo ""
    echo -e "${BLUE}🐙 GitHub Repositories${NC}"
    echo -e "${CYAN}Main: https://github.com/$GITHUB_USER/$PROJECT_FOLDER${NC}"
    if [ "$ENABLE_DIAGNOSTICS" = "true" ] && [ -n "$DIAGNOSTIC_GITHUB_REPO" ]; then
        echo -e "${CYAN}Diagnostics: https://github.com/$DIAGNOSTIC_GITHUB_REPO${NC}"
    fi
fi

# Show git status
echo ""
echo -e "${BLUE}📝 Git Repository${NC}"
if [ "$GITHUB_REPO_CREATED" = true ]; then
    echo -e "${CYAN}✅ Local git initialized and pushed to GitHub${NC}"
else
    echo -e "${CYAN}✅ Local git repository initialized${NC}"
    echo -e "${CYAN}Remote: Not configured (local only)${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. 🎵 Explore the Source/ directory and customize your plugin code"
echo "2. 🔨 Run './scripts/generate_and_open_xcode.sh' to build and open in Xcode"
echo "3. 🧪 Test your plugin in a DAW or standalone"
echo "4. 💾 Commit changes: git add . && git commit -m \"Your changes\""

# Show push instructions only if GitHub repo was created
if [ "$GITHUB_REPO_CREATED" = true ]; then
    echo "5. 🚀 Push updates: git push"
elif [ -n "$GITHUB_USER" ]; then
    echo "5. 🐙 (Optional) Create GitHub repo later and add remote:"
    echo "   gh repo create $PROJECT_FOLDER --private"
    echo "   git remote add origin https://github.com/$GITHUB_USER/$PROJECT_FOLDER.git"
    echo "   git push -u origin main"
fi

echo ""

# Show diagnostics setup instructions if enabled
if [ "$ENABLE_DIAGNOSTICS" = "true" ] && [ "$DIAGNOSTIC_NEEDS_SETUP" = true ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚙️  DiagnosticKit Setup Required${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "DiagnosticKit has been added to your project, but needs a quick setup:"
    echo ""
    echo "📝 Setup Steps (takes ~2 minutes):"
    echo "   1. Navigate to your project: cd $(pwd)"
    echo "   2. Run setup script: ./scripts/setup_diagnostic_repo.sh"
    echo "   3. Follow the guided prompts to:"
    echo "      • Verify diagnostic repository exists"
    echo "      • Create a GitHub Personal Access Token (PAT)"
    echo "      • Configure DiagnosticKit settings"
    echo ""
    echo "📖 For detailed instructions, see:"
    echo "   • Tools/DiagnosticKit/README.md"
    echo "   • Tools/DiagnosticKit/SETUP.md"
    echo ""
    echo -e "${CYAN}ℹ️  Until setup is complete, DiagnosticKit won't be included in builds${NC}"
    echo ""
fi

echo -e "${GREEN}Happy plugin development! 🎵${NC}"
echo ""
```

### 2.5 Git Initialization Verification

**Priority**: HIGH
**Complexity**: LOW

#### Ensure Proper Git Setup

Add verification after git initialization:

```bash
# --- Initialize Git Repository ---
echo ""
echo -e "${YELLOW}Initializing Git repository...${NC}"

# Remove any existing git repo (from template copy)
if [ -d ".git" ]; then
    rm -rf .git
fi

# Initialize fresh git repo
git init

# Configure git if not already configured (optional)
if [ -z "$(git config user.name)" ] && [ -n "$DEVELOPER_NAME" ]; then
    git config user.name "$DEVELOPER_NAME"
fi
if [ -z "$(git config user.email)" ] && [ -n "$APPLE_ID" ]; then
    git config user.email "$APPLE_ID"
fi

# Create initial commit
git add .
git commit -m "Initial commit: $PLUGIN_NAME plugin from JUCE-Plugin-Starter template"

echo -e "${GREEN}✓ Git repository initialized${NC}"
echo -e "${CYAN}Branch: $(git branch --show-current)${NC}"
echo -e "${CYAN}Commits: $(git rev-list --count HEAD)${NC}"
echo ""
```

---

## Phase 3: DiagnosticKit Integration

### 3.1 Directory Structure

**Priority**: MEDIUM
**Complexity**: HIGH

#### Port DiagnosticKit from PlunderTube

**Location**: `Tools/DiagnosticKit/`

**Full Structure**:
```
Tools/
├── DiagnosticKit/
│   ├── .env.example           # Template configuration (project-agnostic)
│   ├── .gitignore
│   ├── DiagnosticKit.entitlements
│   ├── Package.swift          # Swift Package Manager config
│   ├── README.md              # User documentation
│   ├── SETUP.md               # NEW: Step-by-step setup guide
│   ├── Scripts/
│   │   ├── setup.sh          # Initial DiagnosticKit setup
│   │   ├── build_app.sh      # Build the Swift app
│   │   └── validate_config.sh # Validate .env settings
│   └── Sources/
│       ├── Config/           # Configuration loading
│       │   ├── AppConfig.swift
│       │   └── EnvironmentLoader.swift
│       ├── Views/            # SwiftUI views
│       │   ├── MainView.swift
│       │   ├── DiagnosticView.swift
│       │   └── ResultView.swift
│       ├── Services/         # Core services
│       │   ├── DiagnosticCollector.swift
│       │   ├── GitHubUploader.swift
│       │   └── KeychainHelper.swift
│       └── Resources/        # Assets
│           └── Assets.xcassets/
```

### 3.2 Make DiagnosticKit Project-Agnostic

**Priority**: HIGH
**Complexity**: MEDIUM

#### Template .env.example

Create `Tools/DiagnosticKit/.env.example` with placeholders:

```bash
# DiagnosticKit Configuration
# This file is auto-generated from your main project .env
# Do not edit manually - changes will be overwritten

# ============================================================================
# APP CONFIGURATION
# ============================================================================
APP_NAME="{{PROJECT_NAME}} Diagnostics"
APP_IDENTIFIER="{{PROJECT_BUNDLE_ID}}.diagnostics"
APP_VERSION="{{VERSION_MAJOR}}.{{VERSION_MINOR}}.{{VERSION_PATCH}}"
APP_ICON_NAME="AppIcon"

# ============================================================================
# GITHUB CONFIGURATION
# ============================================================================
# Repository where diagnostic issues will be created (format: owner/repo)
GITHUB_REPO="{{DIAGNOSTIC_GITHUB_REPO}}"

# GitHub Personal Access Token (write-only access to issues)
# Created during setup with: ./scripts/setup_diagnostic_repo.sh
GITHUB_PAT="{{DIAGNOSTIC_GITHUB_PAT}}"

# ============================================================================
# SUPPORT CONFIGURATION
# ============================================================================
SUPPORT_EMAIL="{{DIAGNOSTIC_SUPPORT_EMAIL}}"
PRODUCT_NAME="{{PROJECT_NAME}}"
PRODUCT_WEBSITE="{{PROJECT_WEBSITE}}"

# ============================================================================
# DIAGNOSTIC CONFIGURATION
# ============================================================================
# What to collect in diagnostics
COLLECT_PLUGIN_INFO=true
COLLECT_SYSTEM_INFO=true
COLLECT_CRASH_LOGS=true
COLLECT_AU_VALIDATION=true

# Plugin-specific settings
PLUGIN_NAME="{{PROJECT_NAME}}"
PLUGIN_BUNDLE_ID="{{PROJECT_BUNDLE_ID}}"
PLUGIN_MANUFACTURER="{{PLUGIN_MANUFACTURER_CODE}}"

# Plugin formats to check
CHECK_AU=true
CHECK_VST3=true
CHECK_STANDALONE=true

# Audio Unit specific (for auval)
AU_TYPE="aufx"
AU_SUBTYPE="{{PLUGIN_CODE}}"
AU_MANUFACTURER="{{PLUGIN_MANUFACTURER_CODE}}"

# ============================================================================
# UI CONFIGURATION
# ============================================================================
# Window dimensions
WINDOW_WIDTH=380
WINDOW_HEIGHT=550

# UI features
SHOW_TECHNICAL_DETAILS=false
ALLOW_USER_FEEDBACK=true
SHOW_PRIVACY_NOTICE=true
AUTO_SEND_ON_SUCCESS=false

# Theme colors (hex values)
PRIMARY_COLOR="#007AFF"
SUCCESS_COLOR="#34C759"
WARNING_COLOR="#FF9500"
ERROR_COLOR="#FF3B30"

# ============================================================================
# PRIVACY & SECURITY
# ============================================================================
# What NOT to collect
EXCLUDE_USER_PATHS=false
EXCLUDE_SERIAL_NUMBERS=false
ANONYMIZE_USERNAMES=false

# Diagnostic file settings
MAX_LOG_SIZE_MB=10
COMPRESS_LOGS=true

# ============================================================================
# ADVANCED SETTINGS
# ============================================================================
# Timeout for diagnostic operations (seconds)
DIAGNOSTIC_TIMEOUT=30

# GitHub API settings
GITHUB_API_TIMEOUT=10
GITHUB_API_RETRIES=3

# Debug mode (shows console output in app)
DEBUG_MODE=false
```

#### Auto-Generation Function in build.sh

Add function to generate DiagnosticKit .env from main project .env:

```bash
# Function to generate DiagnosticKit .env from main project settings
generate_diagnostic_env() {
    local diagnostic_dir="$1"
    local diagnostic_env="${diagnostic_dir}/.env"

    # Use dynamic naming from .env
    local DIAGNOSTIC_APP_NAME="${PROJECT_NAME} Diagnostics"
    local DIAGNOSTIC_BUNDLE_ID="${PROJECT_BUNDLE_ID}.diagnostics"

    echo "📝 Generating DiagnosticKit configuration..."

    # Copy template
    cp "${diagnostic_dir}/.env.example" "$diagnostic_env"

    # Replace all placeholders
    sed -i '' \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{PROJECT_BUNDLE_ID}}|${PROJECT_BUNDLE_ID}|g" \
        -e "s|{{VERSION_MAJOR}}|${VERSION_MAJOR:-1}|g" \
        -e "s|{{VERSION_MINOR}}|${VERSION_MINOR:-0}|g" \
        -e "s|{{VERSION_PATCH}}|${VERSION_PATCH:-0}|g" \
        -e "s|{{DIAGNOSTIC_GITHUB_REPO}}|${DIAGNOSTIC_GITHUB_REPO}|g" \
        -e "s|{{DIAGNOSTIC_GITHUB_PAT}}|${DIAGNOSTIC_GITHUB_PAT}|g" \
        -e "s|{{DIAGNOSTIC_SUPPORT_EMAIL}}|${DIAGNOSTIC_SUPPORT_EMAIL:-}|g" \
        -e "s|{{PROJECT_WEBSITE}}|${PROJECT_WEBSITE:-}|g" \
        -e "s|{{PLUGIN_CODE}}|${PLUGIN_CODE}|g" \
        -e "s|{{PLUGIN_MANUFACTURER_CODE}}|${PLUGIN_MANUFACTURER_CODE}|g" \
        "$diagnostic_env"

    echo "✅ Generated DiagnosticKit .env"
}
```

### 3.3 Setup Script

**Priority**: HIGH
**Complexity**: MEDIUM

#### Create scripts/setup_diagnostic_repo.sh

```bash
#!/bin/bash

# Setup DiagnosticKit - Validate and configure diagnostic reporting
# This script helps configure the GitHub repository and PAT for DiagnosticKit

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Find project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Load .env
if [[ -f ".env" ]]; then
    set -a
    source .env
    set +a
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check if diagnostics is enabled
if [[ "${ENABLE_DIAGNOSTICS:-false}" != "true" ]]; then
    echo -e "${YELLOW}DiagnosticKit is not enabled in .env${NC}"
    echo "Set ENABLE_DIAGNOSTICS=true to enable it"
    exit 0
fi

# Check-only mode (for build.sh)
CHECK_ONLY=false
if [[ "$1" == "--check-only" ]]; then
    CHECK_ONLY=true
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}DiagnosticKit Setup for $PROJECT_NAME${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Validate GitHub CLI
echo -e "${CYAN}Step 1: Checking GitHub CLI...${NC}"
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) not installed${NC}"
    echo "Install: brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo -e "${RED}❌ GitHub CLI not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI ready${NC}"
echo ""

# Step 2: Check diagnostic repository
echo -e "${CYAN}Step 2: Checking diagnostic repository...${NC}"
if [[ -z "$DIAGNOSTIC_GITHUB_REPO" ]]; then
    echo -e "${RED}❌ DIAGNOSTIC_GITHUB_REPO not set in .env${NC}"
    exit 1
fi

REPO_EXISTS=false
if gh repo view "$DIAGNOSTIC_GITHUB_REPO" &>/dev/null; then
    echo -e "${GREEN}✅ Repository exists: $DIAGNOSTIC_GITHUB_REPO${NC}"
    REPO_EXISTS=true
else
    echo -e "${YELLOW}⚠️  Repository does not exist: $DIAGNOSTIC_GITHUB_REPO${NC}"

    if [[ "$CHECK_ONLY" == "true" ]]; then
        echo "Repository does not exist"
        exit 1
    fi

    # Offer to create it
    echo ""
    read -p "Create private repository now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Extract owner and repo name
        REPO_OWNER="${DIAGNOSTIC_GITHUB_REPO%/*}"
        REPO_NAME="${DIAGNOSTIC_GITHUB_REPO##*/}"

        if gh repo create "$DIAGNOSTIC_GITHUB_REPO" --private --description "$PROJECT_NAME - Diagnostic Reports (Private)"; then
            echo -e "${GREEN}✅ Repository created: $DIAGNOSTIC_GITHUB_REPO${NC}"
            REPO_EXISTS=true
        else
            echo -e "${RED}❌ Failed to create repository${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Create manually: https://github.com/new${NC}"
        exit 1
    fi
fi
echo ""

# Step 3: Check/Create PAT
echo -e "${CYAN}Step 3: Checking Personal Access Token (PAT)...${NC}"
PAT_VALID=false

if [[ -n "$DIAGNOSTIC_GITHUB_PAT" ]] && [[ "$DIAGNOSTIC_GITHUB_PAT" != "" ]]; then
    # Test PAT
    if curl -s -H "Authorization: token $DIAGNOSTIC_GITHUB_PAT" \
        "https://api.github.com/repos/$DIAGNOSTIC_GITHUB_REPO" &>/dev/null; then
        echo -e "${GREEN}✅ PAT is valid${NC}"
        PAT_VALID=true
    else
        echo -e "${YELLOW}⚠️  PAT is invalid or expired${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  DIAGNOSTIC_GITHUB_PAT not configured in .env${NC}"
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
    if [[ "$PAT_VALID" == "true" ]]; then
        echo "PAT Valid: Yes"
        exit 0
    else
        echo "PAT Valid: No"
        exit 1
    fi
fi

if [[ "$PAT_VALID" == "false" ]]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Personal Access Token (PAT) Setup${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "You need to create a GitHub Personal Access Token (PAT) with write-only"
    echo "access to issues in your diagnostic repository."
    echo ""
    echo -e "${CYAN}Follow these steps:${NC}"
    echo ""
    echo "1. Open GitHub token settings:"
    echo "   https://github.com/settings/tokens?type=beta"
    echo ""
    echo "2. Click 'Generate new token'"
    echo ""
    echo "3. Configure:"
    echo "   • Token name: '$PROJECT_NAME Diagnostics'"
    echo "   • Expiration: 1 year (or custom)"
    echo "   • Repository access: Only select repositories"
    echo "   • Selected repositories: $DIAGNOSTIC_GITHUB_REPO"
    echo ""
    echo "4. Permissions:"
    echo "   • Issues: Read and Write (ONLY THIS)"
    echo "   • Metadata: Read (auto-selected)"
    echo ""
    echo "5. Click 'Generate token' and COPY IT"
    echo ""
    echo -e "${RED}⚠️  You won't be able to see the token again!${NC}"
    echo ""
    read -p "Press Enter when you have copied your token..."
    echo ""

    # Prompt for PAT
    read -s -p "Paste your token here: " NEW_PAT
    echo ""
    echo ""

    # Validate PAT
    echo "Validating token..."
    if curl -s -H "Authorization: token $NEW_PAT" \
        "https://api.github.com/repos/$DIAGNOSTIC_GITHUB_REPO" &>/dev/null; then
        echo -e "${GREEN}✅ Token is valid!${NC}"

        # Update .env
        sed -i '' "s|DIAGNOSTIC_GITHUB_PAT=.*|DIAGNOSTIC_GITHUB_PAT=$NEW_PAT|" .env
        echo -e "${GREEN}✅ Updated .env with new PAT${NC}"
        PAT_VALID=true
    else
        echo -e "${RED}❌ Token is invalid${NC}"
        echo "Please check:"
        echo "  • Token has 'Issues: Write' permission"
        echo "  • Token has access to $DIAGNOSTIC_GITHUB_REPO"
        echo "  • Token is not expired"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DiagnosticKit Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "DiagnosticKit is now configured and ready to use."
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "1. Build your project: ./scripts/build.sh all"
echo "2. The DiagnosticKit app will be included in builds"
echo "3. It will be packaged in installers (publish/pkg actions)"
echo ""
echo -e "${CYAN}For more info:${NC}"
echo "  • Tools/DiagnosticKit/README.md"
echo ""

# Create validation marker for build.sh
mkdir -p "$PROJECT_ROOT/build"
cat > "$PROJECT_ROOT/build/diagnostic_validation.txt" << EOF
DiagnosticKit Setup Validation
Timestamp: $(date)
Repository Exists: Yes
PAT Valid: Yes
Ready for Build: Yes
EOF
```

Make it executable:
```bash
chmod +x scripts/setup_diagnostic_repo.sh
```

### 3.4 Build Integration

**Priority**: HIGH
**Complexity**: HIGH

#### Add to build.sh

See comprehensive build.sh implementation in Phase 1 sections above, plus:

```bash
# Early validation before build
check_diagnostic_setup_upfront() {
    # Only check if diagnostics enabled and will be packaged
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
            echo "  2) Continue anyway (DiagnosticKit will be included but won't work)"
            echo "  3) Disable DiagnosticKit (set ENABLE_DIAGNOSTICS=false in .env)"
            echo ""
            read -p "Choose (1-3): " choice

            case "$choice" in
                1)
                    scripts/setup_diagnostic_repo.sh
                    ;;
                2)
                    echo "Continuing without setup..."
                    ;;
                3)
                    echo "Set ENABLE_DIAGNOSTICS=false in .env and try again"
                    exit 1
                    ;;
                *)
                    echo "Invalid choice"
                    exit 1
                    ;;
            esac
        fi
    fi
}

# Build DiagnosticKit
build_diagnostics() {
    if [[ "${ENABLE_DIAGNOSTICS:-false}" != "true" ]]; then
        return 0
    fi

    echo -e "${GREEN}Building DiagnosticKit...${NC}"

    local DIAGNOSTIC_DIR="$PROJECT_ROOT/Tools/DiagnosticKit"

    if [[ ! -d "$DIAGNOSTIC_DIR" ]]; then
        echo -e "${RED}Error: DiagnosticKit not found${NC}"
        return 1
    fi

    # Generate .env for DiagnosticKit
    generate_diagnostic_env "$DIAGNOSTIC_DIR"

    # Build
    cd "$DIAGNOSTIC_DIR"
    if [[ -x "Scripts/build_app.sh" ]]; then
        ./Scripts/build_app.sh release

        local app_name="${PROJECT_NAME} Diagnostics"
        local app_path="build/${app_name}.app"

        if [[ -d "$app_path" ]]; then
            echo "✅ DiagnosticKit built successfully"
            cd "$PROJECT_ROOT"
            return 0
        else
            echo -e "${RED}Error: DiagnosticKit build failed${NC}"
            cd "$PROJECT_ROOT"
            return 1
        fi
    else
        echo -e "${RED}Error: Build script not found${NC}"
        cd "$PROJECT_ROOT"
        return 1
    fi
}
```

---

## Phase 4: Installation Path Changes

### 4.1 Use Standard macOS Paths

**Priority**: HIGH
**Complexity**: MEDIUM

#### Problem

Current approach might use paths that trigger permission prompts:
- `$HOME/Documents/` - User folder, may need approval
- `/Users/Shared/` - Shared folder, needs admin
- Custom paths outside standard locations

#### Solution

Use **Apple-recommended Application Support** paths:

```bash
# Standard macOS paths (no permission prompts needed)
APP_SUPPORT_PATH="$HOME/Library/Application Support/${PROJECT_NAME}"
SAMPLES_PATH="$APP_SUPPORT_PATH/Samples"
PRESETS_PATH="$APP_SUPPORT_PATH/Presets"
USER_DATA_PATH="$APP_SUPPORT_PATH/UserData"
LOGS_PATH="$HOME/Library/Logs/${PROJECT_NAME}"
CACHE_PATH="$HOME/Library/Caches/${PROJECT_BUNDLE_ID}"

# Preferences (handled by macOS)
# These are managed automatically:
# ~/Library/Preferences/${PROJECT_BUNDLE_ID}.plist
```

#### Benefits

✅ No scary permission dialogs during install
✅ Standard location users expect
✅ Automatic cleanup with system tools
✅ Follows Apple Human Interface Guidelines
✅ Easier to find for support

### 4.2 Update All Path References

**Priority**: HIGH
**Complexity**: MEDIUM

#### Files to Update

1. **CMakeLists.txt** (if paths are defined)
2. **Source/PluginProcessor.cpp** (sample/preset loading)
3. **scripts/build.sh** (installer creation)
4. **scripts/uninstall_TEMPLATE.command** (cleanup paths)
5. **Tools/DiagnosticKit/** (diagnostic collection paths)
6. **README.md** (documentation)

#### Example: PluginProcessor.cpp

```cpp
// Get Application Support path
juce::File getApplicationSupportPath()
{
    auto appSupport = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory
    );

    auto projectFolder = appSupport.getChildFile("PROJECT_NAME_PLACEHOLDER");

    // Create if doesn't exist
    if (!projectFolder.exists())
        projectFolder.createDirectory();

    return projectFolder;
}

// Get samples path
juce::File getSamplesPath()
{
    return getApplicationSupportPath().getChildFile("Samples");
}

// Get presets path
juce::File getPresetsPath()
{
    return getApplicationSupportPath().getChildFile("Presets");
}
```

### 4.3 Installer Package Changes

**Priority**: HIGH
**Complexity**: LOW

#### PKG Installer Updates

Ensure installer creates Application Support structure:

```bash
# In build.sh create_installer function
mkdir -p "$PKG_ROOT/Library/Application Support/${PROJECT_NAME}/Samples"
mkdir -p "$PKG_ROOT/Library/Application Support/${PROJECT_NAME}/Presets"

# Add postinstall script to create user-specific paths
cat > "$PKG_ROOT/postinstall" << 'EOF'
#!/bin/bash
# Create Application Support structure for user
USER_HOME="$HOME"
APP_SUPPORT="$USER_HOME/Library/Application Support/PROJECT_NAME_PLACEHOLDER"

mkdir -p "$APP_SUPPORT/Samples"
mkdir -p "$APP_SUPPORT/Presets"
mkdir -p "$USER_HOME/Library/Logs/PROJECT_NAME_PLACEHOLDER"

# Set permissions
chmod 755 "$APP_SUPPORT"
chmod 755 "$APP_SUPPORT/Samples"
chmod 755 "$APP_SUPPORT/Presets"

exit 0
EOF

chmod +x "$PKG_ROOT/postinstall"
```

---

## Phase 5: Smart /Applications Organization

### 5.1 Problem Statement

**Priority**: HIGH
**Complexity**: MEDIUM

#### Current Behavior
- Standalone app installed to: `/Applications/ProjectName.app`
- DiagnosticKit app installed to: `/Applications/ProjectName Diagnostics.app`
- Uninstaller installed to: `/Applications/ProjectName Uninstaller.command`

**Issue**: Multiple related apps cluttering /Applications root

#### Proposed Behavior

**If only standalone app**:
```
/Applications/ProjectName.app
```

**If multiple apps** (2 or more items):
```
/Applications/ProjectName/
├── ProjectName.app
├── ProjectName Diagnostics.app
└── ProjectName Uninstaller.command
```

### 5.2 Implementation

**Priority**: HIGH
**Complexity**: MEDIUM

#### Detect Installation Scenario

```bash
# In build.sh - during PKG creation
count_applications() {
    local count=0

    # Check what's being installed
    [[ -n "$STANDALONE_PKG" ]] && ((count++))
    [[ -n "$DIAGNOSTIC_PKG" ]] && ((count++))
    # Uninstaller is always added if it exists
    [[ -f "$PROJECT_ROOT/uninstall_${PROJECT_NAME}.command" ]] && ((count++))

    echo "$count"
}

# Determine installation strategy
APP_COUNT=$(count_applications)
USE_APP_FOLDER=false

if [[ $APP_COUNT -gt 1 ]]; then
    USE_APP_FOLDER=true
    echo "📁 Multiple apps detected - will install to /Applications/${PROJECT_NAME}/"
else
    echo "📁 Single app - will install directly to /Applications/"
fi
```

#### Build Installer with Conditional Paths

```bash
# Modified PKG building logic
if [[ "$USE_APP_FOLDER" == "true" ]]; then
    # Create folder structure
    STANDALONE_ROOT="$PKG_BUILD/standalone_root/Applications/${PROJECT_NAME}"
    mkdir -p "$STANDALONE_ROOT"

    # Copy standalone app
    if [[ -d "$STANDALONE_APP" ]]; then
        rsync -a "$STANDALONE_APP" "$STANDALONE_ROOT/"
    fi

    # Copy diagnostics app
    if [[ "${ENABLE_DIAGNOSTICS:-false}" == "true" ]] && [[ -d "$DIAGNOSTIC_APP" ]]; then
        rsync -a "$DIAGNOSTIC_APP" "$STANDALONE_ROOT/"
    fi

    # Copy uninstaller
    if [[ -f "$UNINSTALLER_PATH" ]]; then
        cp "$UNINSTALLER_PATH" "$STANDALONE_ROOT/${PROJECT_NAME} Uninstaller.command"
        chmod +x "$STANDALONE_ROOT/${PROJECT_NAME} Uninstaller.command"
    fi

    # Create component with folder structure
    pkgbuild --root "$PKG_BUILD/standalone_root" \
        --identifier "${PROJECT_BUNDLE_ID}.apps" \
        --version "$VERSION" \
        --install-location "/" \
        "$PKG_BUILD/components/apps.pkg"
else
    # Single app - install directly to /Applications
    STANDALONE_ROOT="$PKG_BUILD/standalone_root/Applications"
    mkdir -p "$STANDALONE_ROOT"

    rsync -a "$STANDALONE_APP" "$STANDALONE_ROOT/"

    pkgbuild --root "$PKG_BUILD/standalone_root" \
        --identifier "${PROJECT_BUNDLE_ID}.standalone" \
        --version "$VERSION" \
        --install-location "/" \
        "$PKG_BUILD/components/standalone.pkg"
fi
```

#### Update Uninstaller for Both Scenarios

**Key Challenge**: Uninstaller must detect which installation method was used

```bash
# In uninstall_TEMPLATE.command

# Define possible paths
STANDALONE_PATH_DIRECT="/Applications/${PROJECT_NAME}.app"
STANDALONE_PATH_FOLDER="/Applications/${PROJECT_NAME}/${PROJECT_NAME}.app"
DIAGNOSTICS_PATH_DIRECT="/Applications/${PROJECT_NAME} Diagnostics.app"
DIAGNOSTICS_PATH_FOLDER="/Applications/${PROJECT_NAME}/${PROJECT_NAME} Diagnostics.app"
UNINSTALLER_PATH_DIRECT="/Applications/${PROJECT_NAME} Uninstaller.command"
UNINSTALLER_PATH_FOLDER="/Applications/${PROJECT_NAME}/${PROJECT_NAME} Uninstaller.command"
APP_FOLDER="/Applications/${PROJECT_NAME}"

# Smart detection function
detect_installation_type() {
    if [[ -d "$APP_FOLDER" ]]; then
        echo "folder"
    else
        echo "direct"
    fi
}

INSTALL_TYPE=$(detect_installation_type)

remove_applications() {
    local removed=0

    echo "🗑️  Removing ${PROJECT_NAME} applications..."
    echo ""

    if [[ "$INSTALL_TYPE" == "folder" ]]; then
        # Folder-based installation
        echo "  📁 Detected folder-based installation"

        if [[ -d "$APP_FOLDER" ]]; then
            # Remove entire folder and contents
            rm -rf "$APP_FOLDER" && echo "  ✅ Removed: $APP_FOLDER" && ((removed++))
        else
            echo "  ➖ Not found: $APP_FOLDER"
        fi
    else
        # Direct installation (individual apps)
        echo "  📁 Detected direct installation"

        # Standalone
        if [[ -e "$STANDALONE_PATH_DIRECT" ]]; then
            rm -rf "$STANDALONE_PATH_DIRECT" && echo "  ✅ Removed: $STANDALONE_PATH_DIRECT" && ((removed++))
        else
            echo "  ➖ Not found: $STANDALONE_PATH_DIRECT"
        fi

        # Diagnostics
        if [[ -e "$DIAGNOSTICS_PATH_DIRECT" ]]; then
            rm -rf "$DIAGNOSTICS_PATH_DIRECT" && echo "  ✅ Removed: $DIAGNOSTICS_PATH_DIRECT" && ((removed++))
        else
            echo "  ➖ Not found: $DIAGNOSTICS_PATH_DIRECT"
        fi

        # Uninstaller (if running from elsewhere)
        if [[ -e "$UNINSTALLER_PATH_DIRECT" ]]; then
            rm -f "$UNINSTALLER_PATH_DIRECT" && echo "  ✅ Removed: $UNINSTALLER_PATH_DIRECT" && ((removed++))
        else
            echo "  ➖ Not found: $UNINSTALLER_PATH_DIRECT"
        fi
    fi

    echo ""
    echo "  📊 Removed $removed application(s)"
    echo ""
}
```

#### Update PKG Receipt IDs

```bash
# Receipt strategy for both scenarios
if [[ "$USE_APP_FOLDER" == "true" ]]; then
    # Single receipt for folder-based install
    RECEIPTS=(
        "${PROJECT_BUNDLE_ID}.apps"
        "${PROJECT_BUNDLE_ID}.au"
        "${PROJECT_BUNDLE_ID}.vst3"
        "${PROJECT_BUNDLE_ID}.core"
    )
else
    # Individual receipts for direct install
    RECEIPTS=(
        "${PROJECT_BUNDLE_ID}.standalone"
        "${PROJECT_BUNDLE_ID}.diagnostics"
        "${PROJECT_BUNDLE_ID}.au"
        "${PROJECT_BUNDLE_ID}.vst3"
        "${PROJECT_BUNDLE_ID}.core"
    )
fi
```

### 5.3 User Experience Benefits

✅ **Single App**: Clean, no folder clutter
```
/Applications/
├── MyPlugin.app                    ← Clean!
├── Logic Pro.app
└── ...
```

✅ **Multiple Apps**: Organized folder
```
/Applications/
├── MyPlugin/                       ← Organized!
│   ├── MyPlugin.app
│   ├── MyPlugin Diagnostics.app
│   └── MyPlugin Uninstaller.command
├── Logic Pro.app
└── ...
```

### 5.4 Edge Cases to Handle

1. **User moves apps around**: Uninstaller checks both locations
2. **Partial installs**: Some formats not selected during install
3. **Upgrade scenarios**: Old version direct, new version folder-based
4. **Manual file deletion**: Uninstaller gracefully handles missing items

---

## Phase 6: GitHub Release Output Consistency

### 6.1 Problem Statement

**Priority**: MEDIUM
**Complexity**: LOW

#### Current State
- Build output may vary
- URLs not in consistent order
- Hard to copy/paste for sharing

#### Desired State (from PlunderTube)
- Consistent, deliberate ordering
- Easy to copy/paste
- Clear visual hierarchy

### 6.2 PlunderTube's Output Format

From `build.sh:2662-2683`:

```bash
echo "📦 Release page: https://github.com/${RELEASE_REPO}/releases/tag/$RELEASE_TAG"
echo ""
echo "Download links:"
echo ""
echo "  📦 PKG: https://github.com/${RELEASE_REPO}/releases/download/$RELEASE_TAG/filename.pkg"
echo "  💿 DMG: https://github.com/${RELEASE_REPO}/releases/download/$RELEASE_TAG/filename.dmg"
echo "  🗜️ ZIP: https://github.com/${RELEASE_REPO}/releases/download/$RELEASE_TAG/filename.zip"
```

**Order**: Release page → PKG → DMG → ZIP

### 6.3 Implementation

```bash
# At end of build.sh publish action
show_release_urls() {
    if [[ "$ACTION" == "publish" ]] && [[ -n "$RELEASE_TAG" ]]; then
        local release_repo="${GITHUB_USER}/${GITHUB_REPO}"

        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ Release Published Successfully!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "📦 Release page: https://github.com/${release_repo}/releases/tag/$RELEASE_TAG"
        echo ""
        echo "Download links:"
        echo ""

        # Find files on Desktop (consistent with PlunderTube)
        local desktop="$HOME/Desktop"

        # PKG (first)
        local pkg_file=$(find "$desktop" -name "${PROJECT_NAME}_${VERSION}.pkg" | head -1)
        if [[ -n "$pkg_file" ]] && [[ -f "$pkg_file" ]]; then
            local pkg_name=$(basename "$pkg_file")
            echo "  📦 PKG: https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${pkg_name}"
        fi

        # DMG (second)
        local dmg_file=$(find "$desktop" -name "${PROJECT_NAME}_${VERSION}.dmg" | head -1)
        if [[ -n "$dmg_file" ]] && [[ -f "$dmg_file" ]]; then
            local dmg_name=$(basename "$dmg_file")
            echo "  💿 DMG: https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${dmg_name}"
        fi

        # ZIP (third)
        local zip_file=$(find "$desktop" -name "${PROJECT_NAME}_${VERSION}.zip" | head -1)
        if [[ -n "$zip_file" ]] && [[ -f "$zip_file" ]]; then
            local zip_name=$(basename "$zip_file")
            echo "  🗜️  ZIP: https://github.com/${release_repo}/releases/download/$RELEASE_TAG/${zip_name}"
        fi

        echo ""
        echo -e "${CYAN}ℹ️  URLs are ready to copy/paste for sharing${NC}"
        echo ""
    fi
}

# Call at end of main()
case "$ACTION" in
    ...
    publish)
        sign_plugins
        notarize_plugins
        create_installer
        create_github_release
        show_release_urls  # ← Add this
        ;;
esac
```

### 6.4 Benefits

✅ **Consistent Order**: Always Release page → PKG → DMG → ZIP
✅ **Visual Hierarchy**: Clear sections with spacing
✅ **Easy Copy/Paste**: Each URL on its own line
✅ **Emoji Indicators**: Quick visual identification

---

## Phase 7: Auto-Download Landing Page

### 7.1 Problem Statement

**Priority**: HIGH
**Complexity**: MEDIUM

#### Goal
Create a shareable web page that:
- Always links to the latest release PKG
- Auto-downloads when visited
- Has proper Open Graph for social sharing (iMessage, Slack, Discord, Twitter)
- Is hosted via GitHub Pages
- Is project-agnostic (works for any plugin)

### 7.2 Template File Structure

**New Directory**: `templates/`

```
templates/
├── index.html.template     # Landing page template
└── README.md              # Template documentation
```

### 7.3 Landing Page Template

**File**: `templates/index.html.template`

```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />

    <!-- Open Graph (iMessage, Slack, Discord, etc.) -->
    <meta property="og:title" content="Download {{PROJECT_NAME}}">
    <meta property="og:description" content="{{PLUGIN_DESCRIPTION}}">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://{{GITHUB_USER}}.github.io/{{GITHUB_REPO}}/">
    <meta property="og:image" content="https://raw.githubusercontent.com/{{GITHUB_USER}}/{{GITHUB_REPO}}/main/{{PROJECT_NAME}}.png">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="Download {{PROJECT_NAME}}">
    <meta name="twitter:description" content="{{PLUGIN_DESCRIPTION}}">
    <meta name="twitter:image" content="https://raw.githubusercontent.com/{{GITHUB_USER}}/{{GITHUB_REPO}}/main/{{PROJECT_NAME}}.png">

    <title>Download {{PROJECT_NAME}}</title>

    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        text-align: center;
        background: #f5f5f7;
        color: #1d1d1f;
        padding: 3em 2em;
        margin: 0;
      }
      .container {
        max-width: 600px;
        margin: 0 auto;
        background: white;
        padding: 3em;
        border-radius: 18px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.08);
      }
      h1 {
        font-size: 2.5em;
        font-weight: 600;
        margin: 0 0 0.5em 0;
        color: #1d1d1f;
      }
      p {
        font-size: 1.2em;
        color: #6e6e73;
        margin: 0 0 2em 0;
      }
      .spinner {
        display: inline-block;
        width: 40px;
        height: 40px;
        border: 4px solid #f3f3f3;
        border-top: 4px solid #007aff;
        border-radius: 50%;
        animation: spin 1s linear infinite;
        margin: 2em 0;
      }
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
      .status {
        font-size: 0.95em;
        color: #86868b;
        margin-top: 2em;
      }
      a {
        color: #007aff;
        text-decoration: none;
      }
      a:hover {
        text-decoration: underline;
      }
    </style>

    <script>
      (async () => {
        const statusEl = document.getElementById("status");

        try {
          statusEl.textContent = "Fetching latest release...";

          const res = await fetch("https://api.github.com/repos/{{GITHUB_USER}}/{{GITHUB_REPO}}/releases/latest", {
            headers: { "Accept": "application/vnd.github+json" }
          });

          if (!res.ok) throw new Error("Failed to fetch release");

          const json = await res.json();
          const asset = (json.assets || []).find(a => a.name && a.name.endsWith(".pkg"));

          if (asset && asset.browser_download_url) {
            statusEl.textContent = "Starting download...";

            // Auto-redirect after a short delay
            setTimeout(() => {
              window.location.replace(asset.browser_download_url);
              statusEl.innerHTML = `Download started! If not, <a href="${asset.browser_download_url}">click here</a>.`;
            }, 1500);
          } else {
            throw new Error("No .pkg file found in latest release");
          }
        } catch (e) {
          console.error(e);
          statusEl.innerHTML = `Couldn't find the latest installer. Please visit the <a href="https://github.com/{{GITHUB_USER}}/{{GITHUB_REPO}}/releases/latest">releases page</a>.`;
        }
      })();
    </script>
  </head>

  <body>
    <div class="container">
      <h1>{{PROJECT_NAME}}</h1>
      <p>{{PLUGIN_DESCRIPTION}}</p>
      <div class="spinner"></div>
      <div class="status" id="status">Preparing download...</div>
    </div>
  </body>
</html>
```

### 7.4 Customization During init_plugin_project.sh

```bash
# After creating .env file, generate index.html

echo "Creating landing page..."

# Variables for index.html
PLUGIN_DESCRIPTION="${PLUGIN_NAME} - Audio Plugin built with JUCE"

# Copy and customize template
cp "templates/index.html.template" "../${PROJECT_FOLDER}/index.html"

sed -i '' \
    -e "s|{{PROJECT_NAME}}|${PLUGIN_NAME}|g" \
    -e "s|{{GITHUB_USER}}|${GITHUB_USER}|g" \
    -e "s|{{GITHUB_REPO}}|${PROJECT_FOLDER}|g" \
    -e "s|{{PLUGIN_DESCRIPTION}}|${PLUGIN_DESCRIPTION}|g" \
    "../${PROJECT_FOLDER}/index.html"

echo "✓ Landing page created: index.html"
echo ""
echo -e "${CYAN}📝 Note: Add a ${PROJECT_NAME}.png (1200x630px) to your repo for social sharing${NC}"
```

### 7.5 Enable GitHub Pages Automatically

**In build.sh create_github_release() function**:

```bash
# After creating GitHub release, enable Pages
enable_github_pages() {
    local repo="${GITHUB_USER}/${GITHUB_REPO}"

    echo ""
    echo -e "${CYAN}Enabling GitHub Pages...${NC}"

    # Check if Pages is already enabled
    if gh api "repos/${repo}/pages" &>/dev/null; then
        echo "✅ GitHub Pages already enabled"
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
        echo "   URL: https://${GITHUB_USER}.github.io/${GITHUB_REPO}/"
        return 0
    else
        echo -e "${YELLOW}⚠️  Could not enable GitHub Pages automatically${NC}"
        echo "Enable manually: Settings → Pages → Deploy from main branch"
        return 1
    fi
}

# In create_github_release function, after gh release create
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Successfully created GitHub release${NC}"

    # Enable GitHub Pages
    enable_github_pages

    # Show URLs
    echo ""
    echo "📦 Release page: https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/tag/$release_tag"
    echo "🌐 Download page: https://${GITHUB_USER}.github.io/${GITHUB_REPO}/"
fi
```

### 7.6 Commit and Push index.html

**In create_github_release() before creating release**:

```bash
# Ensure index.html is in repo
if [[ -f "index.html" ]]; then
    echo "Committing index.html for GitHub Pages..."

    # Check if index.html is already committed
    if ! git ls-files --error-unmatch index.html &>/dev/null; then
        git add index.html
        git commit -m "Add auto-download landing page"
        git push
        echo "✅ index.html committed and pushed"
    else
        echo "✅ index.html already in repository"
    fi
fi
```

### 7.7 Social Sharing Image Guidance

**Add to init script success message**:

```bash
echo ""
echo -e "${YELLOW}📸 Social Sharing Image (Optional)${NC}"
echo ""
echo "To enable rich previews when sharing your download link:"
echo "1. Create an image: ${PROJECT_NAME}.png (1200x630 px recommended)"
echo "2. Add to your repo root"
echo "3. Commit and push"
echo ""
echo "The image will appear in:"
echo "  • iMessage link previews"
echo "  • Slack/Discord embeds"
echo "  • Twitter cards"
echo "  • Facebook shares"
```

### 7.8 Complete Integration Flow

```
1. User runs: ./scripts/init_plugin_project.sh
   → index.html created from template
   → Customized with project name, GitHub user, etc.
   → Committed to repo

2. User runs: ./scripts/build.sh all publish
   → index.html pushed to GitHub
   → GitHub release created
   → GitHub Pages enabled automatically
   → URLs shown in output

3. User shares: https://{user}.github.io/{project}/
   → Visitor sees landing page
   → Auto-downloads latest PKG
   → Rich preview in messaging apps (if image exists)
```

### 7.9 Benefits

✅ **Always Current**: Fetches latest release dynamically
✅ **Easy Sharing**: Simple URL instead of GitHub release page
✅ **Rich Previews**: Open Graph for beautiful link previews
✅ **Auto-Download**: No clicking through release pages
✅ **Project-Agnostic**: Works for any plugin
✅ **Zero Maintenance**: Updates automatically with new releases

---

## Phase 8: Documentation Updates

### 8.1 README.md: Table of Contents Update

**Priority**: HIGH
**Complexity**: LOW

**Current Location**: Lines 62-99 in README.md

**Changes Needed**:

Add new sections to the TOC:
```markdown
- [🔨 Enhanced Build System](#-enhanced-build-system)
  - [Quick Build Commands](#quick-build-commands)
  - [Build Actions](#build-actions)
  - [Multiple Target Support](#multiple-target-support)
  - [Automatic Version Management](#automatic-version-management)
  - [Development Workflow](#development-workflow)
  - [Additional Tools](#additional-tools)
- [📍 Where Files Are Installed](#where-files-are-installed)
  - [Plugin Installation Paths](#plugin-installation-paths)
  - [User Data & Settings](#user-data--settings)
  - [Smart /Applications Organization](#smart-applications-organization)
- [🧪 Optional: DiagnosticKit](#-optional-diagnostickit)
  - [What is DiagnosticKit?](#what-is-diagnostickit)
  - [Setup Guide](#setup-guide)
  - [Privacy & Security](#privacy--security)
- [🌐 Auto-Download Landing Page](#-auto-download-landing-page)
  - [What Gets Created](#what-gets-created)
  - [How It Works](#how-it-works)
  - [Customization](#customization)
```

---

### 8.2 README.md: Enhanced Build System Section Update

**Priority**: HIGH
**Complexity**: MEDIUM

**Current Location**: Lines 509-554 in README.md

**Changes Needed**:

1. **Expand "Quick Build Commands" subsection**:

   **BEFORE** (current):
   ```markdown
   # Quick local build (all formats)
   ./scripts/build.sh

   # Build specific format
   ./scripts/build.sh au          # Audio Unit only
   ./scripts/build.sh vst3        # VST3 only
   ./scripts/build.sh standalone  # Standalone app only
   ```

   **AFTER** (new):
   ```markdown
   # Quick local build (all formats)
   ./scripts/build.sh

   # Build specific format
   ./scripts/build.sh au          # Audio Unit only
   ./scripts/build.sh vst3        # VST3 only
   ./scripts/build.sh standalone  # Standalone app only

   # Build multiple formats at once
   ./scripts/build.sh au vst3                    # AU and VST3
   ./scripts/build.sh au vst3 standalone         # All three formats
   ./scripts/build.sh standalone diagnostics     # Standalone + Diagnostics
   ```

2. **Add new "Build Actions" subsection** (after Quick Build Commands):
   ```markdown
   ### Build Actions

   The build system supports multiple actions for different development stages:

   | Action | Description | Use Case |
   |--------|-------------|----------|
   | `local` | Build locally (default) | Day-to-day development |
   | `test` | Build and run PluginVal | Validation before release |
   | `unsigned` | Create unsigned PKG installer | Fast testing without signing |
   | `pkg` | Build, sign, and notarize PKG | Create distributable without GitHub |
   | `publish` | Full release with GitHub | Public release with auto-download page |
   | `uninstall` | Remove all installed components | Clean uninstall for fresh testing |

   **Examples**:
   ```bash
   # Quick development cycle
   ./scripts/build.sh standalone local

   # Fast installer for testing (no signing)
   ./scripts/build.sh all unsigned

   # Production build without GitHub
   ./scripts/build.sh all pkg

   # Full release with GitHub + landing page
   ./scripts/build.sh all publish

   # Clean slate
   ./scripts/build.sh uninstall
   ```
   ```

3. **Add new "Multiple Target Support" subsection**:
   ```markdown
   ### Multiple Target Support

   Build multiple plugin formats in a single command:

   ```bash
   # Build specific combinations
   ./scripts/build.sh au vst3           # Just AU and VST3
   ./scripts/build.sh standalone test   # Standalone + PluginVal test
   ./scripts/build.sh all publish       # Everything + GitHub release
   ```

   **Available Targets**:
   - `au` - Audio Unit plugin
   - `vst3` - VST3 plugin
   - `aax` - AAX plugin (Pro Tools) [if configured]
   - `standalone` - Standalone application
   - `diagnostics` - DiagnosticKit app (if enabled)
   - `all` - All configured formats
   ```

4. **Add new "Development Workflow" subsection**:
   ```markdown
   ### Development Workflow

   **Recommended iteration cycle**:

   ```bash
   # 1. Build and test locally
   ./scripts/build.sh standalone local

   # 2. Make changes, quick rebuild
   ./scripts/build.sh standalone local

   # 3. Test with unsigned installer
   ./scripts/build.sh all unsigned

   # 4. Validate with PluginVal
   ./scripts/build.sh all test

   # 5. Clean slate for final test
   ./scripts/build.sh uninstall
   ./scripts/build.sh all pkg

   # 6. Full release
   ./scripts/build.sh all publish
   ```

   **Quick uninstall and rebuild**:
   ```bash
   # One-liner for fresh install
   ./scripts/build.sh uninstall && ./scripts/build.sh all unsigned
   ```
   ```

---

### 8.3 README.md: Installation Paths Section - Major Update

**Priority**: HIGH
**Complexity**: MEDIUM

**Current Location**: Section "📍 Where Files Are Generated (Plugins + App)" around line 241

**Changes Needed**:

**Replace entire section** with comprehensive new content:

```markdown
## 📍 Where Files Are Installed

### Plugin Installation Paths

When you build your plugin, files are installed to standard macOS plugin locations:

**Audio Plugins**:
```bash
~/Library/Audio/Plug-Ins/Components/YourPlugin.component  # Audio Unit
~/Library/Audio/Plug-Ins/VST3/YourPlugin.vst3            # VST3
~/Library/Application Support/Avid/Audio/Plug-Ins/YourPlugin.aaxplugin  # AAX (if configured)
```

**Applications**:

The installer intelligently organizes apps in `/Applications/`:

- **Single app** (standalone only): Installs directly to `/Applications/YourPlugin.app`
- **Multiple apps** (2 or more): Creates organized folder `/Applications/YourPlugin/`
  - `YourPlugin.app` - Main standalone application
  - `YourPlugin Diagnostics.app` - Diagnostic tool (if enabled)
  - `YourPlugin Uninstaller.command` - Uninstaller script

**Why the difference?**
- Single apps install directly for simplicity
- Multiple apps use a folder to avoid cluttering /Applications

### User Data & Settings

**All user data is stored in Application Support** (no permission prompts needed):

```bash
~/Library/Application Support/YourPlugin/
├── Settings/           # User preferences and configuration
├── Samples/           # Audio samples (if included)
├── Presets/           # User and factory presets
└── Cache/             # Temporary cache files

~/Library/Logs/YourPlugin/          # Crash logs and diagnostics
~/Library/Caches/com.company.YourPlugin/  # System caches
```

**Why Application Support?**
- ✅ No permission prompts (Monterey+ compatible)
- ✅ Proper sandboxing support
- ✅ Standard macOS location for app data
- ✅ Automatically backed up by Time Machine
- ✅ Easy to find for troubleshooting

> 💡 **Old projects** that used `~/Documents/YourPlugin/` should migrate to Application Support to avoid permission dialogs on modern macOS.

### Smart /Applications Organization

The build system automatically detects how many applications will be installed and organizes them appropriately:

**Detection Logic**:
```bash
# Counts applications:
# - Standalone app
# - Diagnostics app (if enabled)
# - Uninstaller.command (if included)

If count == 1:  Install to /Applications/YourPlugin.app
If count >= 2:  Install to /Applications/YourPlugin/ folder
```

**Uninstaller Awareness**:

The uninstaller automatically detects the installation type:

```bash
# Checks for folder-based install
if [ -d "/Applications/${PROJECT_NAME}" ]; then
    # Remove entire folder
    rm -rf "/Applications/${PROJECT_NAME}"
else
    # Remove standalone app only
    rm -rf "/Applications/${PROJECT_NAME}.app"
fi
```

**Example Scenarios**:

| Configuration | Installs To | Contains |
|--------------|-------------|----------|
| Standalone only | `/Applications/YourPlugin.app` | Just the app |
| Standalone + Diagnostics | `/Applications/YourPlugin/` | YourPlugin.app<br>YourPlugin Diagnostics.app |
| Standalone + Diagnostics + Uninstaller | `/Applications/YourPlugin/` | YourPlugin.app<br>YourPlugin Diagnostics.app<br>YourPlugin Uninstaller.command |
| Standalone + Uninstaller | `/Applications/YourPlugin/` | YourPlugin.app<br>YourPlugin Uninstaller.command |
```

---

### 8.4 README.md: Add DiagnosticKit Section (New)

**Priority**: HIGH
**Complexity**: MEDIUM

**Insert Location**: After "Where Files Are Installed" section

**New Section to Add**:

```markdown
## 🧪 Optional: DiagnosticKit

### What is DiagnosticKit?

DiagnosticKit is an optional macOS application that makes it easy for your users to submit diagnostic reports when they encounter issues with your plugin.

**User Benefits**:
- 🖱️ **One-click diagnostics** - No Terminal commands needed
- 📊 **Comprehensive reports** - System info, plugin status, crash logs
- 🔒 **Privacy-first** - Users see exactly what's being sent
- 🐙 **Direct to GitHub** - Reports submitted as private GitHub issues

**Developer Benefits**:
- 📥 **Organized reports** - All diagnostics in one private GitHub repo
- 🔍 **Better debugging** - Consistent format with all needed info
- ⏱️ **Faster support** - No back-and-forth for system details
- 🤖 **AI-ready** - Claude Code can read and analyze diagnostic issues

### Setup Guide

**1. Enable during project creation** (or add later to `.env`):
```bash
ENABLE_DIAGNOSTICS=true
DIAGNOSTIC_GITHUB_REPO="youruser/yourproject-diagnostics"
```

**2. Run the setup script**:
```bash
./scripts/setup_diagnostic_repo.sh
```

This interactive script will:
- ✅ Create a private GitHub repository for diagnostics
- ✅ Guide you through creating a Personal Access Token (PAT)
- ✅ Configure the PAT with minimal write-only permissions
- ✅ Test the configuration
- ✅ Build the DiagnosticKit app

**3. Build with diagnostics**:
```bash
# Build diagnostics only
./scripts/build.sh diagnostics

# Build everything including diagnostics
./scripts/build.sh all

# Include in signed installer
./scripts/build.sh all publish
```

**4. What gets created**:
- `YourPlugin Diagnostics.app` in build folder
- Automatically included in signed PKG installer
- Installed to `/Applications/YourPlugin/` folder (with other apps)

### How It Works

**For Users**:
1. Open "YourPlugin Diagnostics.app"
2. Click "Collect Diagnostics"
3. Review what will be sent (full transparency)
4. Add optional description
5. Click "Submit Report"
6. Get confirmation with issue number

**For Developers**:
1. Reports appear as GitHub issues in your private repo
2. Each issue contains:
   - System information (macOS version, architecture)
   - Plugin installation status
   - Crash logs (if any)
   - Audio Unit validation results
   - User's description
3. Use Claude Code to analyze issues directly from GitHub

### Privacy & Security

**What's Collected**:
- ✅ macOS version and architecture
- ✅ Plugin installation paths and versions
- ✅ Crash logs from `~/Library/Logs/`
- ✅ Audio Unit validation results
- ✅ User's optional description

**What's NOT Collected**:
- ❌ Personal files or documents
- ❌ Passwords or credentials
- ❌ Browsing history
- ❌ Email or contacts
- ❌ Other application data

**Token Security**:
- Personal Access Token (PAT) stored in `.env` (git-ignored)
- Write-only access to issues (can't read other reports)
- Scoped to single diagnostic repository only
- Can be revoked anytime at github.com/settings/tokens

### Detailed Setup Instructions

See comprehensive guide: [`Tools/DiagnosticKit/SETUP.md`](Tools/DiagnosticKit/SETUP.md)

**Troubleshooting**:
- **PAT not working?** Verify permissions at github.com/settings/tokens
- **App won't launch?** Check code signing: `codesign -vvv "path/to/app"`
- **Issues not appearing?** Test PAT: `curl -H "Authorization: token YOUR_PAT" https://api.github.com/repos/OWNER/REPO`
```

---

### 8.5 README.md: Add Auto-Download Landing Page Section (New)

**Priority**: HIGH
**Complexity**: LOW

**Insert Location**: After DiagnosticKit section

**New Section to Add**:

```markdown
## 🌐 Auto-Download Landing Page

When you publish a release with `./scripts/build.sh all publish`, the build system automatically creates a professional landing page with auto-download functionality.

### What Gets Created

**1. GitHub Pages Site** (auto-enabled):
- URL: `https://yourusername.github.io/yourplugin/`
- Automatically serves latest PKG installer
- No manual Pages configuration needed

**2. Landing Page Features**:
- 🚀 **Auto-download** - Automatically starts PKG download on page load
- 📱 **Responsive design** - Works on all devices
- 🎨 **Professional layout** - Clean, modern interface
- 🔗 **Social sharing** - Open Graph meta tags for link previews
- 📊 **GitHub integration** - Fetches latest release info via API
- ⬇️ **Multiple formats** - Links to PKG, DMG, and ZIP

**3. Meta Tags for Social Sharing**:
```html
<!-- Auto-generated with your plugin details -->
<meta property="og:title" content="Download YourPlugin">
<meta property="og:description" content="Latest version of YourPlugin for macOS">
<meta property="og:image" content="URL to your plugin icon/screenshot">
<meta property="og:url" content="https://yourusername.github.io/yourplugin/">
```

### How It Works

**During `publish` build**:

1. **Creates `index.html`** from template with your project details
2. **Enables GitHub Pages** automatically via GitHub API
3. **Publishes to main branch** so it's immediately live
4. **Displays download URL** at end of build for easy sharing

**Output Example**:
```bash
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Release Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 GitHub Release: https://github.com/user/plugin/releases/tag/v1.0.5
🌐 Auto-Download:   https://user.github.io/plugin/
📄 PKG Installer:   https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.pkg
💿 DMG Disk Image:  https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.dmg
🗜️  ZIP Archive:    https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.zip

Copy any URL above to share with users! 🚀
```

### Customization

**Template Location**: `templates/index.html.template`

**Customizable Elements**:
```html
<!-- Placeholders replaced during build -->
{{PROJECT_NAME}}          → Your plugin name
{{PROJECT_DESCRIPTION}}   → Brief description
{{GITHUB_USER}}           → Your GitHub username
{{GITHUB_REPO}}           → Repository name
{{PROJECT_ICON_URL}}      → Plugin icon URL (optional)
```

**Custom Styling**:
```bash
# Edit template before publishing
vim templates/index.html.template

# Your changes will be used in next publish
./scripts/build.sh all publish
```

**Manual Pages Enable** (if auto-enable fails):
```bash
# Via GitHub CLI
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  "repos/USER/REPO/pages" \
  -f source[branch]=main \
  -f source[path]=/

# Or via web UI
# 1. Go to repo Settings → Pages
# 2. Source: main branch
# 3. Click Save
```

### User Experience

**When users click your shared link**:

1. **Landing page loads** with plugin info
2. **PKG download starts automatically** (via JavaScript)
3. **Manual download links** available as backup
4. **Release notes** shown from latest GitHub release
5. **Social media preview** when link shared on Twitter/Slack/etc

**Perfect for**:
- 🔗 Sharing in forum posts
- 📧 Email newsletters
- 🐦 Social media posts
- 📱 Website integration
- 🤝 Beta tester distribution
```

---

### 8.6 README.md: Update "How to Distribute Your Plugin" Section

**Priority**: MEDIUM
**Complexity**: LOW

**Current Location**: Lines 618-712 in README.md (approximately)

**Changes Needed**:

1. **Update the "Run the Distribution Script" subsection**:

   **BEFORE** (current):
   ```markdown
   ### 🚀 Run the Distribution Script

   From your project root:

   ```bash
   ./scripts/build.sh all publish
   ```

   This command will:

   - ✅ Build all plugin formats
   - ✅ Sign and notarize your plugins
   - ✅ Create a signed `.pkg` installer and notarize it
   - ✅ Bundle it into a distributable `.dmg`
   - ✅ Create a GitHub release with all artifacts
   ```

   **AFTER** (updated):
   ```markdown
   ### 🚀 Run the Distribution Script

   From your project root:

   ```bash
   ./scripts/build.sh all publish
   ```

   This command will:

   - ✅ Build all plugin formats (AU, VST3, Standalone, Diagnostics)
   - ✅ Sign and notarize your plugins
   - ✅ Create a signed `.pkg` installer and notarize it
   - ✅ Bundle it into a distributable `.dmg`
   - ✅ Create a GitHub release with all artifacts
   - ✅ Enable GitHub Pages with auto-download landing page
   - ✅ Display shareable URLs in consistent order

   **Output URLs (easy to copy/paste)**:
   ```bash
   📦 GitHub Release: https://github.com/user/plugin/releases/tag/v1.0.5
   🌐 Auto-Download:   https://user.github.io/plugin/
   📄 PKG Installer:   https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.pkg
   💿 DMG Disk Image:  https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.dmg
   🗜️  ZIP Archive:    https://github.com/user/plugin/releases/download/v1.0.5/YourPlugin.zip
   ```

   > 💡 URLs are always displayed in the same order for easy copy/paste to release announcements, social media, or documentation.
   ```

2. **Add new "Other Build Actions" subsection** (after main distribution instructions):

   ```markdown
   ### 🛠️ Other Build Actions

   **Quick unsigned installer** (for testing without certificates):
   ```bash
   ./scripts/build.sh all unsigned
   # Creates unsigned PKG on Desktop
   # Install with: sudo installer -pkg ~/Desktop/YourPlugin.pkg -target /
   ```

   **Signed PKG without GitHub** (local distribution):
   ```bash
   ./scripts/build.sh all pkg
   # Creates signed, notarized PKG
   # No GitHub release created
   # Files saved to Desktop
   ```

   **Uninstall everything** (clean slate):
   ```bash
   ./scripts/build.sh uninstall
   # Removes all installed components:
   # - Audio plugins (AU, VST3)
   # - Applications
   # - User data (with confirmation)
   # - Receipts and caches
   ```
   ```

---

### 8.7 README.md: Update Quick Start Section

**Priority**: MEDIUM
**Complexity**: LOW

**Current Location**: Lines 72-97 (Step 3. Build Your Plugin)

**Changes Needed**:

**Update Step 3** to mention new build options:

**BEFORE** (current):
```markdown
### 3. Build Your Plugin

**Change to your new project directory first:**
```bash
cd ../your-plugin-name  # Use the actual folder name created in step 2
```

Then build using one of these methods:

**🤖 AI Tools (Recommended):**
If using Claude Code, it automatically knows how to build and test your plugin.

**🔨 Quick Build & Test:**
```bash
./scripts/build.sh standalone local  # Build and launch standalone app
```

**🎯 Xcode Development:**
```bash
./scripts/generate_and_open_xcode.sh  # Generate and open Xcode project
```
```

**AFTER** (updated):
```markdown
### 3. Build Your Plugin

**Change to your new project directory first:**
```bash
cd ../your-plugin-name  # Use the actual folder name created in step 2
```

Then build using one of these methods:

**🤖 AI Tools (Recommended):**
If using Claude Code, it automatically knows how to build and test your plugin.

**🔨 Quick Build & Test:**
```bash
# Build and launch standalone app
./scripts/build.sh standalone local

# Build all formats
./scripts/build.sh all

# Build multiple specific formats
./scripts/build.sh au vst3

# Fast unsigned installer (no code signing)
./scripts/build.sh all unsigned
```

**🎯 Xcode Development:**
```bash
./scripts/generate_and_open_xcode.sh  # Generate and open Xcode project
```

**🧹 Clean Uninstall:**
```bash
./scripts/build.sh uninstall  # Remove all installed components
```

> 💡 See [Enhanced Build System](#-enhanced-build-system) for complete build command reference.
```

---

### 8.8 README.md: Update Project File Structure Section

**Priority**: LOW
**Complexity**: LOW

**Current Location**: Lines 465-508 (Project File Structure)

**Changes Needed**:

**Update the file tree** to include new files:

**BEFORE** (current structure):
```
JUCE-Plugin-Starter/
├── scripts/
│   ├── about/
│   │   └── build_system.md
│   ├── build.sh
│   ├── bump_version.py
│   ├── dependencies.sh
│   ├── diagnose_plugin.sh
│   ├── generate_and_open_xcode.sh
│   ├── generate_release_notes.py
│   ├── init_plugin_project.sh
│   ├── post_build.sh
│   └── validate_plugin.sh
```

**AFTER** (updated structure):
```
JUCE-Plugin-Starter/
├── scripts/
│   ├── about/
│   │   └── build_system.md
│   ├── build.sh                   ← Enhanced with uninstall, unsigned, pkg actions
│   ├── bump_version.py
│   ├── dependencies.sh
│   ├── diagnose_plugin.sh
│   ├── generate_and_open_xcode.sh
│   ├── generate_release_notes.py
│   ├── init_plugin_project.sh     ← Now includes diagnostics opt-in
│   ├── post_build.sh
│   ├── setup_diagnostic_repo.sh   ← NEW: DiagnosticKit setup wizard
│   ├── validate_plugin.sh
│   └── uninstall_template.sh      ← NEW: Project-agnostic uninstaller template
├── templates/
│   ├── index.html.template        ← NEW: Auto-download landing page template
│   └── DiagnosticKit.entitlements ← NEW: Entitlements for diagnostics app
├── Tools/                          ← NEW: Optional DiagnosticKit
│   └── DiagnosticKit/
│       ├── README.md
│       ├── SETUP.md
│       ├── .env.example
│       └── Source/
```

---

### 8.9 README.md: Add Troubleshooting Section (New)

**Priority**: MEDIUM
**Complexity**: LOW

**Insert Location**: Before "📚 Resources" section (at end)

**New Section to Add**:

```markdown
## 🔧 Troubleshooting

### Build Issues

**CMake fails to generate**:
```bash
# Clean build directory
rm -rf build/

# Regenerate from scratch
./scripts/generate_and_open_xcode.sh
```

**"Unsigned" build fails**:
```bash
# Ensure PKG build tools are installed
brew install pkgbuild

# Check for signing certificate (should fail gracefully)
security find-identity -v -p codesigning
```

**Version not incrementing**:
```bash
# Manually bump version
python3 scripts/bump_version.py patch  # or minor/major

# Check .env file
cat .env | grep PROJECT_VERSION
```

### Installation Issues

**Plugin not appearing in DAW**:
```bash
# Verify installation paths
ls -la ~/Library/Audio/Plug-Ins/Components/*.component
ls -la ~/Library/Audio/Plug-Ins/VST3/*.vst3

# Re-scan plugins in your DAW
# Logic Pro: Preferences → Plug-in Manager → Reset & Rescan
# Reaper: Preferences → Plug-ins → VST → Re-scan
```

**Permission denied during install**:
```bash
# Install PKG with sudo
sudo installer -pkg ~/Desktop/YourPlugin.pkg -target /

# Or use unsigned build (development only)
./scripts/build.sh all unsigned
```

**Uninstaller fails**:
```bash
# Run with admin privileges
sudo "/Applications/YourPlugin Uninstaller.command"

# Or manual cleanup
./scripts/build.sh uninstall
```

### DiagnosticKit Issues

**App won't launch**:
```bash
# Check code signing
codesign -vvv "Tools/DiagnosticKit/build/YourPlugin Diagnostics.app"

# Remove quarantine flag
xattr -d com.apple.quarantine "Tools/DiagnosticKit/build/YourPlugin Diagnostics.app"

# Rebuild with signing
./scripts/build.sh diagnostics
```

**PAT not working**:
```bash
# Test your token
curl -H "Authorization: token YOUR_PAT" \
     https://api.github.com/repos/OWNER/REPO

# Verify permissions at GitHub
open https://github.com/settings/tokens

# Re-run setup
./scripts/setup_diagnostic_repo.sh
```

**Issues not appearing on GitHub**:
1. Verify PAT has "Issues: Write" permission
2. Check repository access in token settings
3. Ensure PAT is not expired
4. Test with: `./scripts/setup_diagnostic_repo.sh --test-connection`

### GitHub Pages Issues

**Landing page not loading**:
```bash
# Check if Pages is enabled
gh api repos/USER/REPO/pages

# Manually enable Pages
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  "repos/USER/REPO/pages" \
  -f source[branch]=main

# Verify index.html exists
git ls-files | grep index.html
```

**Auto-download not working**:
- Check browser console for JavaScript errors
- Verify release exists: `gh release list`
- Ensure PKG file is attached to latest release
- Test manual download link

### macOS Sequoia+ Issues

**Notarization fails**:
```bash
# Check notarization log
xcrun notarytool log --apple-id YOUR_ID --password YOUR_PASS --team-id YOUR_TEAM SUBMISSION_ID

# Common fixes:
# 1. Update code signing certificate
# 2. Add hardened runtime entitlements
# 3. Update Xcode Command Line Tools
```

**Permission prompts for Application Support**:
```bash
# Verify paths in .env
cat .env | grep -E "(SAMPLES_DIR|PRESETS_DIR|SETTINGS_DIR)"

# Should all be under ~/Library/Application Support/
# NOT ~/Documents/ or ~/Downloads/
```

### Getting Help

If you're still stuck:

1. **Check existing issues**: [GitHub Issues](https://github.com/danielraffel/JUCE-Plugin-Starter/issues)
2. **Enable debug mode**:
   ```bash
   DEBUG=1 ./scripts/build.sh all
   ```
3. **Collect diagnostics** (if DiagnosticKit enabled):
   ```bash
   ./scripts/build.sh diagnostics
   open "Tools/DiagnosticKit/build/YourPlugin Diagnostics.app"
   ```
4. **Ask Claude Code** (if using):
   - Share error output
   - Describe expected vs actual behavior
   - Mention macOS version and Xcode version
```

### 5.2 DiagnosticKit Documentation

**Priority**: HIGH
**Complexity**: LOW

Create `Tools/DiagnosticKit/SETUP.md`:

```markdown
# DiagnosticKit Setup Guide

## Overview

DiagnosticKit is a macOS app that helps your users:
- Collect diagnostic information with one click
- Submit reports directly to your private GitHub repository
- Avoid email attachments and Terminal commands

## Requirements

- GitHub account
- GitHub CLI (`gh`) installed and authenticated
- Private GitHub repository for diagnostic reports
- Personal Access Token (PAT) with write-only issue access

## Step-by-Step Setup

### 1. Enable DiagnosticKit

In your project's `.env` file:
```bash
ENABLE_DIAGNOSTICS=true
DIAGNOSTIC_GITHUB_REPO="youruser/yourproject-diagnostics"
```

### 2. Create Diagnostic Repository

Option A: Let the setup script create it for you
```bash
./scripts/setup_diagnostic_repo.sh
```

Option B: Create manually
1. Go to https://github.com/new
2. Repository name: `yourproject-diagnostics`
3. Visibility: Private
4. Click "Create repository"

### 3. Create Personal Access Token

1. Go to: https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Configure:
   - **Token name**: "YourProject Diagnostics"
   - **Expiration**: 1 year
   - **Repository access**: Only select repositories
   - **Selected repositories**: `youruser/yourproject-diagnostics`
4. **Permissions**:
   - ✅ Issues: Read and Write
   - ✅ Metadata: Read (auto-selected)
   - ❌ Everything else: No access
5. Click "Generate token"
6. **COPY THE TOKEN** (you won't see it again!)

### 4. Configure PAT

Run the setup script:
```bash
./scripts/setup_diagnostic_repo.sh
```

Or add manually to `.env`:
```bash
DIAGNOSTIC_GITHUB_PAT=github_pat_xxxxxxxxxxxxxxxxxxxxx
```

### 5. Build and Test

```bash
# Build DiagnosticKit
./scripts/build.sh diagnostics

# Test the app
open "Tools/DiagnosticKit/build/YourProject Diagnostics.app"
```

### 6. Include in Distribution

DiagnosticKit is automatically included when you build a signed installer:

```bash
./scripts/build.sh all publish
```

## Troubleshooting

### PAT Not Working

Test your token:
```bash
curl -H "Authorization: token YOUR_PAT" \
     https://api.github.com/repos/OWNER/REPO
```

### Repository Access Denied

Verify:
1. Token has "Issues: Write" permission
2. Token has access to the specific repository
3. Token is not expired

### App Won't Launch

Check:
1. App is code signed: `codesign -vvv "path/to/app"`
2. No quarantine flag: `xattr -d com.apple.quarantine "path/to/app"`

## Privacy & Security

### What's Collected
- System information (macOS version, architecture)
- Plugin installation status
- Crash logs (if any)
- Audio Unit validation results
- User feedback (optional)

### What's NOT Collected
- Personal files or documents
- Passwords or credentials
- Browsing history
- Other application data

### Token Security
- PAT stored securely in .env (git-ignored)
- Write-only access (can't read other reports)
- Limited to one repository
- Can be revoked anytime at GitHub

## Support

For issues with DiagnosticKit setup:
- Check: `Tools/DiagnosticKit/README.md`
- GitHub: https://github.com/youruser/JUCE-Plugin-Starter/issues
```

### 5.3 CLAUDE.md Updates

**Priority**: LOW
**Complexity**: LOW

Update project instructions for Claude Code:

```markdown
### Building with DiagnosticKit

If diagnostics are enabled (`ENABLE_DIAGNOSTICS=true` in .env):

```bash
# Build with diagnostics
./scripts/build.sh all

# Build diagnostics only
./scripts/build.sh diagnostics
```

**Important**: DiagnosticKit requires setup before first build.
If not configured, Claude should:
1. Check: `./scripts/setup_diagnostic_repo.sh --check-only`
2. If fails, prompt user to run: `./scripts/setup_diagnostic_repo.sh`
3. Don't attempt to build until setup is complete

### Uninstall for Dev Workflow

```bash
# Quick uninstall and rebuild
./scripts/build.sh uninstall && ./scripts/build.sh unsigned

# Uninstall only
./scripts/build.sh uninstall
```
```

---

## Phase 6: Testing & Validation

### 6.1 Test Matrix

**Priority**: CRITICAL
**Complexity**: HIGH

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| **Project Creation** | | |
| TC-1 | Create project without GitHub | ✅ Local git repo, no remote |
| TC-2 | Create project with private GitHub | ✅ Repo created and pushed |
| TC-3 | Create project with public GitHub | ✅ Public repo created |
| TC-4 | Create project with diagnostics enabled | ✅ Diagnostics included |
| TC-5 | Create project without diagnostics | ✅ Diagnostics excluded |
| TC-6 | Decline GitHub after diagnostics opt-in | ✅ Graceful handling |
| **Build Actions** | | |
| TC-7 | `./scripts/build.sh` (default) | ✅ All formats built |
| TC-8 | `./scripts/build.sh au vst3` | ✅ Only AU and VST3 built |
| TC-9 | `./scripts/build.sh unsigned` | ✅ Unsigned PKG created |
| TC-10 | `./scripts/build.sh all pkg` | ✅ Signed PKG without GitHub |
| TC-11 | `./scripts/build.sh uninstall` | ✅ All components removed |
| **Diagnostics** | | |
| TC-12 | Setup diagnostic repo (new) | ✅ Repo created, PAT configured |
| TC-13 | Setup diagnostic repo (exists) | ✅ Validates existing setup |
| TC-14 | Build with diagnostics unconfigured | ⚠️ Warning shown, skip diagnostic |
| TC-15 | Build diagnostics target only | ✅ Diagnostic app built |
| TC-16 | Submit diagnostic report | ✅ GitHub issue created |
| **Edge Cases** | | |
| TC-17 | Project name with spaces | ✅ Properly quoted everywhere |
| TC-18 | Special characters in bundle ID | ✅ Validated and sanitized |
| TC-19 | Missing GitHub credentials | ✅ Graceful fallback |
| TC-20 | Invalid PAT | ⚠️ Clear error message |
| **Uninstaller** | | |
| TC-21 | Repair mode (interactive) | ✅ Plugins removed, data kept |
| TC-22 | Complete uninstall (interactive) | ✅ Everything removed |
| TC-23 | Non-interactive uninstall | ✅ Auto-completes |
| TC-24 | Uninstall with backup | ✅ Backup ZIP created |
| **Paths** | | |
| TC-25 | Verify Application Support paths | ✅ No permission prompts |
| TC-26 | Installer creates directories | ✅ Paths exist after install |
| TC-27 | Uninstaller cleans Application Support | ✅ Paths removed |

### 6.2 Manual Testing Checklist

```markdown
## Pre-Release Testing

### Phase 1: Project Creation

- [ ] Run init_plugin_project.sh
- [ ] Choose "No" for diagnostics
- [ ] Choose "No" for GitHub
- [ ] Verify local git repo works
- [ ] Verify success message is clear
- [ ] Check .env file has correct values

### Phase 2: Build System

- [ ] Run `./scripts/build.sh`
- [ ] Verify AU, VST3, Standalone built
- [ ] Test in Logic Pro (AU)
- [ ] Test in Reaper (VST3)
- [ ] Launch Standalone app

### Phase 3: Multiple Targets

- [ ] Run `./scripts/build.sh au vst3`
- [ ] Verify only AU and VST3 built
- [ ] Verify Standalone NOT built

### Phase 4: Unsigned Build

- [ ] Run `./scripts/build.sh unsigned`
- [ ] Verify PKG created on Desktop
- [ ] Install PKG (no signing warnings in installer log)
- [ ] Verify plugins work

### Phase 5: Uninstaller

- [ ] Run `./scripts/build.sh uninstall`
- [ ] Check plugins removed
- [ ] Check Application Support removed
- [ ] Check receipts forgotten

### Phase 6: Diagnostics (Full Flow)

- [ ] Create new project with diagnostics enabled
- [ ] Run `./scripts/setup_diagnostic_repo.sh`
- [ ] Create PAT on GitHub
- [ ] Configure PAT in setup
- [ ] Build: `./scripts/build.sh diagnostics`
- [ ] Launch diagnostic app
- [ ] Submit test report
- [ ] Verify issue created on GitHub

### Phase 7: Distribution

- [ ] Run `./scripts/build.sh all publish`
- [ ] Verify signed PKG created
- [ ] Verify notarization succeeds
- [ ] Verify GitHub release created
- [ ] Download and install PKG from GitHub
- [ ] Verify diagnostics app included
```

---

## Implementation Priority

### 🔴 Phase 1: Critical (Do First)

**Week 1**:
1. ✅ Port uninstaller script (project-agnostic)
2. ✅ Add `uninstall`, `unsigned`, `pkg` actions
3. ✅ Update installation paths (Application Support)
4. ✅ Fix init_plugin_project.sh flow issues
5. ✅ Add multiple target support

**Deliverables**:
- Working uninstaller
- Fast unsigned builds for dev
- Improved init flow with proper git handling
- Multiple format builds in one command

### 🟡 Phase 2: High Priority (Do Next)

**Week 2**:
6. ✅ Add diagnostics opt-in to init script
7. ✅ Port DiagnosticKit directory structure
8. ✅ Create setup_diagnostic_repo.sh script
9. ✅ Update build.sh for diagnostics integration
10. ✅ Test complete workflow

**Deliverables**:
- Optional diagnostics during project creation
- Working DiagnosticKit integration
- Guided setup for diagnostic repo and PAT

### 🟢 Phase 3: Medium Priority (Polish)

**Week 3**:
11. Update all documentation (README, CLAUDE.md)
12. Create DiagnosticKit SETUP.md guide
13. Add troubleshooting sections
14. Create example projects
15. Video walkthrough (optional)

**Deliverables**:
- Complete documentation
- Setup guides
- Example projects

---

## Security Considerations

### 1. GitHub PAT Storage

**Risk**: PAT exposed in .env file

**Mitigation**:
- .env is git-ignored by default
- PAT has minimal permissions (write-only to issues)
- PAT scoped to specific repository only
- Users can revoke anytime at GitHub

**Best Practice**:
```bash
# Never commit .env
echo ".env" >> .gitignore

# Use .env.example for templates
# Keep actual .env local only
```

### 2. Code Signing DiagnosticKit

**Requirement**: DiagnosticKit MUST be code signed (especially for macOS Sequoia+)

**Implementation**:
```bash
# Always sign diagnostics app
codesign --force --timestamp --options runtime \
    --entitlements DiagnosticKit.entitlements \
    --sign "$APP_CERT" \
    "DiagnosticKit.app"
```

**Entitlements needed**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
```

### 3. Uninstaller Permissions

**Risk**: Uninstaller needs admin privileges

**Mitigation**:
- Use `sudo` for required operations only
- Clear prompt explaining why admin needed
- Verify paths before deletion
- Offer backup before uninstall

### 4. Privacy in Diagnostics

**Risk**: Collecting too much user data

**Mitigation**:
- Show users what will be collected BEFORE sending
- Allow users to review report contents
- Exclude personal information by default
- Clear privacy notice in app

**Options in .env**:
```bash
EXCLUDE_USER_PATHS=true
EXCLUDE_SERIAL_NUMBERS=true
ANONYMIZE_USERNAMES=true
```

---

## Known Challenges & Solutions

### Challenge 1: Spaces in Project Names

**Problem**: Project names like "My Awesome Plugin" break in shell scripts

**Solution**: Always quote variables
```bash
# ✅ Correct
rm -rf "/Applications/${PROJECT_NAME} Diagnostics.app"
open "${APP_PATH}"

# ❌ Wrong
rm -rf /Applications/${PROJECT_NAME} Diagnostics.app
open $APP_PATH
```

**Validation**: Add to init script
```bash
# Warn about spaces (optional)
if [[ "$PLUGIN_NAME" =~ \  ]]; then
    echo -e "${YELLOW}Note: Your plugin name contains spaces.${NC}"
    echo "This is fine, but be aware:"
    echo "  • Folder name will use hyphens: ${PROJECT_FOLDER}"
    echo "  • Shell scripts will quote the name properly"
fi
```

### Challenge 2: DiagnosticKit PAT Creation

**Problem**: Can't automate PAT creation (security requirement)

**Solution**: Provide crystal-clear walkthrough
- Step-by-step guide with screenshots
- Direct link to GitHub token page
- Exact permissions needed
- Validation after creation

**Improvement**: Add validation script
```bash
# scripts/validate_diagnostic_pat.sh
curl -s -H "Authorization: token $DIAGNOSTIC_GITHUB_PAT" \
    "https://api.github.com/repos/$DIAGNOSTIC_GITHUB_REPO" | \
    jq -r '.permissions'
```

### Challenge 3: Build Without DiagnosticKit Setup

**Problem**: User enables diagnostics but doesn't configure PAT

**Solution**: Multi-level approach
1. **Warning during build**: Show clear message
2. **Allow continuation**: Don't block build
3. **Exclude from PKG**: Don't package non-functional app
4. **Setup reminder**: Show instructions at end

```bash
if [[ "$ENABLE_DIAGNOSTICS" == "true" ]] && [[ -z "$DIAGNOSTIC_GITHUB_PAT" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  DiagnosticKit Enabled But Not Configured${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "DiagnosticKit will be SKIPPED in this build."
    echo ""
    echo "To configure: ./scripts/setup_diagnostic_repo.sh"
    echo ""
fi
```

### Challenge 4: Installation Permissions on Monterey+

**Problem**: Monterey+ requires explicit permissions for some paths

**Solution**: Use Application Support (no prompt needed)
```bash
# ✅ No prompt needed
~/Library/Application Support/MyPlugin/
~/Library/Logs/MyPlugin/
~/Library/Caches/com.company.myplugin/

# ⚠️ May need approval
~/Documents/MyPlugin/
~/Downloads/MyPlugin/
```

### Challenge 5: GitHub vs No-GitHub Flow

**Problem**: Different success messages confuse users

**Solution**: Unified ending with status-aware messages

```bash
# Track actual state
GITHUB_REPO_CREATED=false
LOCAL_GIT_INITIALIZED=true

# Show unified summary
echo -e "${BLUE}📝 Git Repository${NC}"
if [ "$GITHUB_REPO_CREATED" = true ]; then
    echo -e "${CYAN}✅ Local and remote (GitHub)${NC}"
    echo -e "${CYAN}URL: https://github.com/$GITHUB_USER/$PROJECT_FOLDER${NC}"
else
    echo -e "${CYAN}✅ Local only (no remote)${NC}"
    echo -e "${CYAN}Add remote later: gh repo create $PROJECT_FOLDER --private${NC}"
fi
```

### Challenge 6: Uninstaller Self-Deletion

**Problem**: Script can't delete itself while running

**Solution**: Background deletion with delay
```bash
# At end of uninstaller
UNINSTALLER_PATH="/Applications/${PROJECT_NAME} Uninstaller.command"
if [ -f "$UNINSTALLER_PATH" ]; then
    echo "🗑️  Removing uninstaller..."
    (sleep 0.1 && rm -f "$UNINSTALLER_PATH" 2>/dev/null) &
    disown
fi
```

---

## Rollout Plan

### Stage 1: Internal Testing (Week 1)
- Implement Phase 1 (core features)
- Test on multiple macOS versions
- Fix critical bugs
- Document known issues

### Stage 2: Beta Testing (Week 2)
- Implement Phase 2 (diagnostics)
- Share with beta testers
- Gather feedback
- Refine user experience

### Stage 3: Documentation (Week 3)
- Complete all documentation
- Create video tutorials
- Write blog post announcing features
- Update project templates

### Stage 4: Release (Week 4)
- Tag v2.0.0 release
- Publish to GitHub
- Announce on forums/social media
- Monitor for issues

---

## Success Metrics

- ✅ New projects can be created in < 2 minutes
- ✅ Diagnostics setup takes < 3 minutes
- ✅ Unsigned build completes in < 30 seconds
- ✅ Uninstall completes in < 10 seconds
- ✅ No permission prompts during normal install
- ✅ 100% of test cases passing
- ✅ Zero reported critical bugs in first month

---

## Maintenance Plan

### Regular Updates
- Update DiagnosticKit with latest Swift/SwiftUI
- Keep build scripts compatible with latest macOS
- Monitor for JUCE API changes

### User Support
- Monitor GitHub issues
- Provide quick responses to setup questions
- Update documentation based on feedback

### Security
- Regularly audit PAT permissions
- Update code signing requirements as needed
- Review and update privacy policy

---

**End of Update Plans**

_Last Updated: 2025-10-10_
_Version: 1.0_
_Status: Ready for Implementation_

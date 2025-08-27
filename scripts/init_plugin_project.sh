#!/usr/bin/env bash

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper function for confirmed input
get_confirmed_input() {
    local prompt="$1"
    local default_value="$2"
    local result=""
    
    # Check if stdin is a terminal (interactive mode) or pipe/heredoc (automated mode)
    if [ ! -t 0 ]; then
        # Non-interactive mode - skip confirmation
        read -r result
        if [ -z "$result" ] && [ -n "$default_value" ]; then
            result="$default_value"
        fi
        echo "$result"
        return
    fi
    
    while true; do
        # Use read -e to enable readline editing (arrow keys, backspace, etc.)
        read -e -p "$prompt" result
        
        # Use default if empty and default provided
        if [ -z "$result" ] && [ -n "$default_value" ]; then
            result="$default_value"
            printf "\n${CYAN}Using default: %s${NC}\n" "$result" >&2
        fi
        
        # Skip confirmation for empty optional fields
        if [ -z "$result" ]; then
            break
        fi
        
        # Show what was entered and confirm (with newline for clarity)
        printf "\n${GREEN}You entered: '%s'${NC}\n" "$result" >&2
        read -p "Is this correct? (Y/n): " confirm
        
        # Default to yes if just Enter pressed
        if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            echo -e "\nLet's try again..." >&2
        fi
    done
    
    echo "$result"
}

# Helper function for yes/no questions (no confirmation needed)
get_yes_no() {
    local prompt="$1"
    local default_value="$2"  # "y" or "n"
    
    # Check if stdin is a terminal (interactive mode) or pipe/heredoc (automated mode)
    if [ ! -t 0 ]; then
        # Non-interactive mode - read single line
        read -r response
        if [ -z "$response" ] && [ -n "$default_value" ]; then
            response="$default_value"
        fi
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "y"
            return 0
        else
            echo "n"
            return 1
        fi
    fi
    
    while true; do
        if [ -n "$default_value" ]; then
            if [ "$default_value" = "y" ]; then
                read -e -p "$prompt (Y/n): " response
            else
                read -e -p "$prompt (y/N): " response
            fi
        else
            read -e -p "$prompt (y/n): " response
        fi
        
        # Handle default
        if [ -z "$response" ] && [ -n "$default_value" ]; then
            response="$default_value"
        fi
        
        # Normalize response - no confirmation needed for y/n
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "y"
            return 0
        elif [[ "$response" =~ ^[Nn]$ ]]; then
            echo "n"
            return 1
        else
            printf "${RED}Please answer 'y' for yes or 'n' for no${NC}\n" >&2
        fi
    done
}

# Helper function to get default value from .env.example
get_env_default() {
    local var_name="$1"
    # Extract value from .env.example, handling quoted and unquoted values
    grep "^${var_name}=" .env.example 2>/dev/null | sed 's/^[^=]*=//' | sed 's/^"\(.*\)"$/\1/' || echo ""
}

# Helper function for values loaded from .env (only shows confirmation if different from default)
get_env_loaded_input() {
    local field_name="$1"
    local loaded_value="$2"
    local prompt="$3"
    local env_var_name="$4"
    
    if [ -n "$loaded_value" ]; then
        # Get the default value from .env.example
        local default_value
        default_value=$(get_env_default "$env_var_name")
        
        # Skip placeholder values
        case "$env_var_name" in
            "APPLE_ID")
                [[ "$loaded_value" == "your.email@example.com" ]] && loaded_value=""
                ;;
            "APP_CERT"|"INSTALLER_CERT")
                [[ "$loaded_value" =~ "Your Name" ]] && loaded_value=""
                ;;
            "TEAM_ID")
                [[ "$loaded_value" == "YOURTEAMID" ]] && loaded_value=""
                ;;
            "APP_SPECIFIC_PASSWORD")
                [[ "$loaded_value" == "xxxx-xxxx-xxxx-xxxx" ]] && loaded_value=""
                ;;
            "GITHUB_USER")
                [[ "$loaded_value" == "yourusername" ]] && loaded_value=""
                ;;
            "DEVELOPER_NAME")
                [[ "$loaded_value" == "Your Name" ]] && loaded_value=""
                ;;
        esac
        
        # If still have a value after filtering placeholders
        if [ -n "$loaded_value" ]; then
            # Only show confirmation dialog if the loaded value differs from the default
            if [ "$loaded_value" != "$default_value" ]; then
                # Show the loaded value and ask for confirmation
                printf "\n${GREEN}For your %s you have '%s' in your .env${NC}\n" "$field_name" "$loaded_value" >&2
                
                if get_yes_no "Is this correct?" "y" >/dev/null; then
                    echo "$loaded_value"
                    return 0
                else
                    # Let them enter a new value
                    echo -e "\nEnter a new value:" >&2
                    result=$(get_confirmed_input "$prompt" "")
                    echo "$result"
                    return 0
                fi
            else
                # Value matches default, use it silently (no confirmation needed)
                echo "$loaded_value"
                return 0
            fi
        fi
    fi
    
    # No loaded value or was placeholder, use normal input
    result=$(get_confirmed_input "$prompt" "")
    echo "$result"
    return 0
}

# Function to selectively load reusable values from .env file
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        echo -e "${CYAN}Found existing .env file. Loading reusable developer settings...${NC}" >&2
        
        # Only load these specific variables that are reusable across projects
        local reusable_vars=(
            "DEVELOPER_NAME"
            "APPLE_ID" 
            "TEAM_ID"
            "APP_CERT"
            "INSTALLER_CERT" 
            "APP_SPECIFIC_PASSWORD"
            "GITHUB_USER"
        )
        
        # Parse .env file, only loading reusable variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Only process reusable variables
            local is_reusable=false
            for reusable_var in "${reusable_vars[@]}"; do
                if [ "$key" = "$reusable_var" ]; then
                    is_reusable=true
                    break
                fi
            done
            
            if [ "$is_reusable" = true ]; then
                # Remove quotes if present
                value="${value%\"}"
                value="${value#\"}"
                
                # Export the variable
                export "$key=$value"
            fi
        done < "$env_file"
        
        echo -e "${GREEN}✓ Loaded reusable developer settings from .env${NC}\n" >&2
        return 0
    fi
    return 1
}

# --- Welcome Message ---
echo ""
echo -e "${BLUE}🚀 JUCE Plugin Project Creator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}This script will:${NC}"
echo -e "${CYAN}• Create a new JUCE plugin project from this template${NC}"
echo -e "${CYAN}• Copy all template files to a new project folder${NC}"
echo -e "${CYAN}• Initialize a fresh Git repository in the new project${NC}"
echo -e "${CYAN}• Create a new GitHub repository (public or private)${NC}"
echo -e "${CYAN}• Leave this template repository untouched${NC}"
echo ""

if ! get_yes_no "❓ Do you want to continue?" "y" >/dev/null; then
  echo -e "${RED}❌ Cancelled by user.${NC}"
  exit 0
fi

# --- Check if we're in the template directory ---
if [ ! -f "scripts/init_plugin_project.sh" ]; then
    echo -e "${RED}Error: Please run this script from the JUCE-Plugin-Starter template directory${NC}"
    exit 1
fi

# Load reusable developer settings from .env (skips placeholders)
load_env_file ".env"

# Extract developer name from certificate if not already set
if [ -n "$APP_CERT" ] && [ -z "$DEVELOPER_NAME" ]; then
    # Extract developer name from certificate (e.g., "Johnny Appleseed" from "Developer ID Application: Johnny Appleseed (ABC123)")
    DEVELOPER_NAME=$(echo "$APP_CERT" | sed -n 's/Developer ID Application: \(.*\) (.*)/\1/p')
fi

# Create smart bundle prefix from developer name if available
if [ -n "$DEVELOPER_NAME" ]; then
    # Convert "Daniel Raffel" to "com.danielraffel"
    BUNDLE_PREFIX=$(echo "$DEVELOPER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    DEFAULT_BUNDLE_PREFIX="com.${BUNDLE_PREFIX}"
fi

# --- Interactive Project Setup ---
echo -e "${YELLOW}Let's create your audio plugin project!${NC}\n"

# Plugin name
while true; do
    PLUGIN_NAME=$(get_confirmed_input "Plugin name (e.g., 'My Awesome Synth'): " "")
    if [ -z "$PLUGIN_NAME" ]; then
        echo -e "${RED}Plugin name cannot be empty${NC}"
    else
        break
    fi
done

# Generate class name, project folder, namespace, and manufacturer info
CLASS_NAME=$(echo "$PLUGIN_NAME" | sed 's/[^a-zA-Z0-9]//g')
PROJECT_FOLDER=$(echo "$PLUGIN_NAME" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')

# Create C++ namespace from developer name (safe for C++)
if [ -n "$DEVELOPER_NAME" ]; then
    NAMESPACE=$(echo "$DEVELOPER_NAME" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
else
    NAMESPACE="audio"  # fallback namespace
fi

# Plugin manufacturer for copyright
PLUGIN_MANUFACTURER="$DEVELOPER_NAME"

printf "\n${CYAN}Generated project details:${NC}\n"
printf "${GREEN}Class name will be: %s${NC}\n" "$CLASS_NAME"
printf "${GREEN}Project folder will be: %s${NC}\n" "$PROJECT_FOLDER"
printf "${GREEN}C++ namespace will be: %s${NC}\n" "$NAMESPACE"
if [ -n "$PLUGIN_MANUFACTURER" ]; then
    printf "${GREEN}Plugin manufacturer: %s${NC}\n" "$PLUGIN_MANUFACTURER"
fi
echo ""

# Check if project folder already exists
if [ -d "../$PROJECT_FOLDER" ]; then
    echo -e "${RED}Error: Project folder '../$PROJECT_FOLDER' already exists${NC}"
    if ! get_yes_no "Do you want to overwrite it?" "n" >/dev/null; then
        echo "Aborting..."
        exit 1
    fi
    rm -rf "../$PROJECT_FOLDER"
fi

# --- Handle Developer Information ---
echo -e "${CYAN}🏢 Developer Information:${NC}"

# Handle DEVELOPER_NAME with smart loading
NEW_DEVELOPER_NAME=$(get_env_loaded_input "Developer/Company name" "$DEVELOPER_NAME" "Developer/Company name (e.g., 'Acme Audio' or 'John Smith'): " "DEVELOPER_NAME")
if [ -n "$NEW_DEVELOPER_NAME" ]; then
    DEVELOPER_NAME="$NEW_DEVELOPER_NAME"
    PLUGIN_MANUFACTURER="$DEVELOPER_NAME"
    # Update bundle prefix and namespace based on new developer name
    BUNDLE_PREFIX=$(echo "$DEVELOPER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    DEFAULT_BUNDLE_PREFIX="com.${BUNDLE_PREFIX}"
    NAMESPACE=$(echo "$DEVELOPER_NAME" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
fi

# Smart Bundle ID generation
if [ -n "$DEFAULT_BUNDLE_PREFIX" ]; then
    SUGGESTED_BUNDLE_ID="${DEFAULT_BUNDLE_PREFIX}.${PROJECT_FOLDER}"
    
    echo ""
    echo -e "${CYAN}📦 Bundle ID Suggestion:${NC}"
    echo -e "${GREEN}  Based on your developer name, we suggest: ${SUGGESTED_BUNDLE_ID}${NC}"
    
    if get_yes_no "Use this bundle ID?" "y" >/dev/null; then
        PROJECT_BUNDLE_ID="$SUGGESTED_BUNDLE_ID"
    else
        PROJECT_BUNDLE_ID=$(get_confirmed_input "Enter your preferred bundle ID (e.g., com.yourcompany.yourplugin): " "$SUGGESTED_BUNDLE_ID")
    fi
else
    PROJECT_BUNDLE_ID=$(get_confirmed_input "Bundle ID (e.g., com.yourcompany.yourplugin): " "com.yourname.${PROJECT_FOLDER}")
fi

# GitHub repository (optional)
echo ""
echo -e "${YELLOW}Optional: GitHub Integration${NC}"
GITHUB_USER=$(get_env_loaded_input "GitHub username" "$GITHUB_USER" "GitHub username (e.g., johnsmith123, or press Enter to skip): " "GITHUB_USER")

# Apple Developer info (optional)
echo ""
echo -e "${YELLOW}Optional: Apple Developer Settings (for code signing and notarization)${NC}"
echo "Press Enter to skip any of these if you don't have an Apple Developer account yet."

# Apple ID
APPLE_ID=$(get_env_loaded_input "Apple ID" "$APPLE_ID" "Apple ID (e.g., johnny.appleseed@gmail.com): " "APPLE_ID")

if [ -n "$APPLE_ID" ]; then
    # Team ID
    TEAM_ID=$(get_env_loaded_input "Team ID" "$TEAM_ID" "Team ID (e.g., 96RC8Q31L9): " "TEAM_ID")
    
    # App Certificate 
    APP_CERT=$(get_env_loaded_input "Application certificate" "$APP_CERT" "Developer ID Application certificate name: " "APP_CERT")
    
    # Installer Certificate
    INSTALLER_CERT=$(get_env_loaded_input "Installer certificate" "$INSTALLER_CERT" "Developer ID Installer certificate name: " "INSTALLER_CERT")
    
    # App-Specific Password
    echo -e "\n${CYAN}App-Specific Password for notarization:${NC}" >&2
    echo "  Generate at: https://appleid.apple.com → Sign-In and Security → App-Specific Passwords" >&2
    echo "  This is required for notarizing your plugin for distribution" >&2
    APP_SPECIFIC_PASSWORD=$(get_env_loaded_input "App-Specific Password" "$APP_SPECIFIC_PASSWORD" "App-Specific Password (xxxx-xxxx-xxxx-xxxx format, or Enter to skip): " "APP_SPECIFIC_PASSWORD")
fi

# --- Create New Project ---
echo ""
echo -e "${YELLOW}Creating project...${NC}"

# Copy template files (excluding integrate/ and todo/)
echo "Copying template files..."
mkdir -p "../$PROJECT_FOLDER"

# Copy all files except integrate/ and todo/
rsync -av --exclude='integrate/' --exclude='todo/' --exclude='.git/' . "../$PROJECT_FOLDER/"

# Change to new project directory
cd "../$PROJECT_FOLDER"

# --- Replace Placeholders in Files ---
echo "Customizing project files..."

# Create placeholder replacements
find . -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.cmake" -o -name "*.txt" -o -name "*.md" -o -name ".env*" \) -exec sed -i '' \
    -e "s/PLUGIN_NAME_PLACEHOLDER/$PLUGIN_NAME/g" \
    -e "s/CLASS_NAME_PLACEHOLDER/$CLASS_NAME/g" \
    -e "s/PROJECT_FOLDER_PLACEHOLDER/$PROJECT_FOLDER/g" \
    -e "s/BUNDLE_ID_PLACEHOLDER/$PROJECT_BUNDLE_ID/g" \
    -e "s/DEVELOPER_NAME_PLACEHOLDER/$DEVELOPER_NAME/g" \
    -e "s/PLUGIN_MANUFACTURER_PLACEHOLDER/$PLUGIN_MANUFACTURER/g" \
    -e "s/NAMESPACE_PLACEHOLDER/$NAMESPACE/g" \
    {} \; 2>/dev/null || true

# --- Create Project-Specific .env File ---
echo "Creating configuration file..."
cat > .env << EOF
# Project Configuration
PROJECT_NAME=$PROJECT_FOLDER
PRODUCT_NAME="$PLUGIN_NAME"
PROJECT_BUNDLE_ID=$PROJECT_BUNDLE_ID
DEVELOPER_NAME="$DEVELOPER_NAME"

# Directory Path to project folder
PROJECT_PATH="$(pwd)"

# Version Information
VERSION_MAJOR=1
VERSION_MINOR=0
VERSION_PATCH=0
VERSION_BUILD=1

# Apple Developer Settings (for code signing/notarization)
APPLE_ID=$APPLE_ID
TEAM_ID=$TEAM_ID
APP_CERT="$APP_CERT"
INSTALLER_CERT="$INSTALLER_CERT"
APP_SPECIFIC_PASSWORD=$APP_SPECIFIC_PASSWORD

# GitHub Settings
GITHUB_USER=$GITHUB_USER
GITHUB_REPO=$PROJECT_FOLDER

# Build Configuration
CMAKE_BUILD_TYPE=Debug
BUILD_DIR=build

# JUCE Configuration
JUCE_REPO=https://github.com/juce-framework/JUCE.git
JUCE_BRANCH=master

# GitHub Release Settings
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
OPENROUTER_KEY_PRIVATE=sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
RELEASE_NOTES_MODEL=openai/gpt-4o-mini
EOF

# --- Make Scripts Executable ---
echo "Setting up build scripts..."
find scripts/ -name "*.sh" -exec chmod +x {} \;
find scripts/ -name "*.py" -exec chmod +x {} \;

# --- Initialize Git Repository ---
echo ""
echo -e "${YELLOW}Initializing Git repository...${NC}"
git init
git add .
git commit -m "Initial commit: $PLUGIN_NAME plugin from JUCE-Plugin-Starter template"

# --- Create GitHub Repository (if requested) ---
if [ -n "$GITHUB_USER" ]; then
    echo ""
    echo -e "${YELLOW}GitHub Integration:${NC}"
    if get_yes_no "Create GitHub repository?" "y" >/dev/null; then
        
        # Ask for repository visibility
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
        if get_yes_no "✅ Confirm: Create $REPO_VISIBILITY repository?" "y" >/dev/null; then
            
            # --- Check GitHub CLI is available and authenticated ---
            if ! command -v gh &> /dev/null; then
                echo -e "${RED}❌ GitHub CLI (gh) not found.${NC}"
                echo -e "${CYAN}Install it: https://cli.github.com/${NC}"
                exit 1
            fi

            # Temporarily unset GITHUB_TOKEN if it exists, as it can interfere with gh auth
            SAVED_GITHUB_TOKEN="$GITHUB_TOKEN"
            unset GITHUB_TOKEN

            # Check if we can actually use gh to create repos
            if ! gh api user &> /dev/null; then
                echo -e "${YELLOW}⚠️  GitHub CLI is not properly authenticated for API operations.${NC}"
                echo -e "${CYAN}👉 Run: gh auth login${NC}"
                if [ -n "$SAVED_GITHUB_TOKEN" ]; then
                    echo -e "${CYAN}   Note: You have a GITHUB_TOKEN environment variable that may be invalid/expired${NC}"
                fi
                exit 1
            fi

            echo -e "${CYAN}🌐 Creating $REPO_VISIBILITY GitHub repo...${NC}"
            gh repo create "$PROJECT_FOLDER" $VISIBILITY_FLAG --description "$PLUGIN_NAME - Audio Plugin built with JUCE"
            git remote add origin "https://github.com/$GITHUB_USER/$PROJECT_FOLDER.git"
            git branch -M main
            git push -u origin main
            echo -e "${GREEN}✓ GitHub $REPO_VISIBILITY repository created and pushed${NC}"
        fi
    fi
fi

# --- Success Summary ---
echo ""
echo -e "${GREEN}🎉 Success! Your plugin project is ready!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Project created in: $(pwd)${NC}"
echo -e "${CYAN}Plugin Name: $PLUGIN_NAME${NC}"
echo -e "${CYAN}Project Folder: $PROJECT_FOLDER${NC}"
echo -e "${CYAN}Bundle ID: $PROJECT_BUNDLE_ID${NC}"
if [ -n "$GITHUB_USER" ]; then
    echo -e "${CYAN}GitHub: https://github.com/$GITHUB_USER/$PROJECT_FOLDER${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Explore the Source/ directory and customize your plugin code"
echo "2. Run './scripts/generate_and_open_xcode.sh' to build and open in Xcode"
echo "3. Test your plugin in a DAW or standalone"
echo "4. Commit changes: git add . && git commit -m \"Your changes\""
if [ -n "$GITHUB_USER" ]; then
    echo "5. Push updates: git push"
fi
echo ""
echo -e "${GREEN}Happy plugin development! 🎵${NC}"
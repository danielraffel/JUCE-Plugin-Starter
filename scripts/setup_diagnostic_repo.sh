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

if [[ -n "${DIAGNOSTIC_GITHUB_PAT:-}" ]] && [[ "$DIAGNOSTIC_GITHUB_PAT" != "" ]]; then
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
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|DIAGNOSTIC_GITHUB_PAT=.*|DIAGNOSTIC_GITHUB_PAT=$NEW_PAT|" .env
        else
            sed -i "s|DIAGNOSTIC_GITHUB_PAT=.*|DIAGNOSTIC_GITHUB_PAT=$NEW_PAT|" .env
        fi
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

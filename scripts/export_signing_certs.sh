#!/bin/bash
# export_signing_certs.sh — Export signing certificates from Keychain and push to GitHub Secrets
#
# Reads APP_CERT and INSTALLER_CERT from .env, exports all identities as a single .p12,
# and pushes all required secrets to GitHub via `gh secret set`.
#
# The .p12 contains all identities in your login keychain. CI imports them into a temporary
# keychain and codesign/productbuild pick the right cert by name. Extra certs are harmless.
#
# Usage:
#   ./scripts/export_signing_certs.sh                    # Use defaults from .env
#   ./scripts/export_signing_certs.sh --repo my-repo     # Target a specific repo
#   ./scripts/export_signing_certs.sh --force             # Re-export from Keychain even if cached
#   ./scripts/export_signing_certs.sh --check             # Just show what would be pushed (dry run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/.secrets"

# ── Colors ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse arguments ──────────────────────────────────────────────────────
FORCE=false
DRY_RUN=false
REPO_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --check|--dry-run) DRY_RUN=true; shift ;;
        --repo) REPO_OVERRIDE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--repo <name>] [--force] [--check]"
            echo ""
            echo "Options:"
            echo "  --repo <name>   Target a specific GitHub repo (default: GITHUB_REPO from .env)"
            echo "  --force         Re-export .p12 from Keychain even if cached in .secrets/"
            echo "  --check         Dry run — show what would be pushed without pushing"
            echo ""
            echo "Reads APP_CERT, INSTALLER_CERT, APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID from .env"
            echo "Exports .p12 to .secrets/ (gitignored) and pushes 7 secrets to GitHub via gh CLI"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── Load .env ─────────────────────────────────────────────────────────────
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a; source "$ROOT_DIR/.env"; set +a
else
    echo -e "${RED}No .env file found at $ROOT_DIR/.env${NC}"
    exit 1
fi

# ── Determine target repo ────────────────────────────────────────────────
GITHUB_USER="${GITHUB_USER:-${GITHUB_USERNAME:-}}"
if [[ -n "$REPO_OVERRIDE" ]]; then
    TARGET_REPO="$REPO_OVERRIDE"
else
    TARGET_REPO="${GITHUB_REPO:-}"
fi

if [[ -z "$TARGET_REPO" ]]; then
    echo -e "${RED}No target repo specified. Use --repo <name> or set GITHUB_REPO in .env${NC}"
    exit 1
fi

if [[ -n "$GITHUB_USER" ]]; then
    FULL_REPO="${GITHUB_USER}/${TARGET_REPO}"
else
    FULL_REPO="$TARGET_REPO"
fi

# ── Validate required .env values ────────────────────────────────────────
MISSING=()
[[ -z "${APP_CERT:-}" ]] && MISSING+=("APP_CERT")
[[ -z "${INSTALLER_CERT:-}" ]] && MISSING+=("INSTALLER_CERT")
[[ -z "${APPLE_ID:-}" ]] && MISSING+=("APPLE_ID")
[[ -z "${APP_SPECIFIC_PASSWORD:-${APP_PASSWORD:-}}" ]] && MISSING+=("APP_SPECIFIC_PASSWORD or APP_PASSWORD")
[[ -z "${TEAM_ID:-}" ]] && MISSING+=("TEAM_ID")

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required .env values:${NC}"
    for m in "${MISSING[@]}"; do
        echo "  - $m"
    done
    exit 1
fi

# Normalize APP_SPECIFIC_PASSWORD (some projects use APP_PASSWORD)
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-${APP_PASSWORD:-}}"

# ── Check prerequisites ──────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    echo -e "${RED}GitHub CLI (gh) is required. Install with: brew install gh${NC}"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo -e "${RED}GitHub CLI not authenticated. Run: gh auth login${NC}"
    exit 1
fi

# ── Verify certificates exist in Keychain ─────────────────────────────────
echo ""
echo -e "${BOLD}Checking certificates in Keychain...${NC}"

# Check for Developer ID Application
if security find-identity -v -p codesigning | grep -q "$APP_CERT"; then
    echo -e "  ${GREEN}Found${NC} $APP_CERT"
else
    echo -e "  ${RED}Not found${NC}: $APP_CERT"
    echo "  Run: security find-identity -v -p codesigning"
    exit 1
fi

# Check for Developer ID Installer (not in codesigning policy — check all identities)
if security find-identity -v | grep -q "$INSTALLER_CERT"; then
    echo -e "  ${GREEN}Found${NC} $INSTALLER_CERT"
else
    echo -e "  ${YELLOW}Warning${NC}: $INSTALLER_CERT not found in Keychain"
    echo "  Installer signing may not work in CI. Continuing anyway..."
fi

# ── Ensure .secrets/ exists and is gitignored ─────────────────────────────
mkdir -p "$SECRETS_DIR"
GITIGNORE="$ROOT_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q '^\.secrets/' "$GITIGNORE" 2>/dev/null; then
        echo "" >> "$GITIGNORE"
        echo "# Exported signing certificates (never commit)" >> "$GITIGNORE"
        echo ".secrets/" >> "$GITIGNORE"
        echo -e "${GREEN}Added .secrets/ to .gitignore${NC}"
    fi
else
    echo ".secrets/" > "$GITIGNORE"
    echo -e "${GREEN}Created .gitignore with .secrets/ entry${NC}"
fi

# ── Export identities from Keychain ───────────────────────────────────────
P12_FILE="$SECRETS_DIR/signing_certs.p12"
PWD_FILE="$SECRETS_DIR/signing_certs_password.txt"

if [[ -f "$P12_FILE" ]] && [[ -f "$PWD_FILE" ]] && [[ "$FORCE" != "true" ]]; then
    echo ""
    echo -e "  ${GREEN}Using cached${NC} .p12: $(basename "$P12_FILE") ($(wc -c < "$P12_FILE" | xargs) bytes)"
    echo "  Use --force to re-export from Keychain"
else
    echo ""
    echo -e "${BOLD}Exporting identities from Keychain...${NC}"
    echo -e "  ${YELLOW}A macOS security dialog will appear — click 'Allow' to grant access${NC}"
    echo ""

    # Generate a random password for the .p12
    P12_PASSWORD=$(openssl rand -base64 24)

    # Export all identities from login keychain
    # This includes both Developer ID Application and Developer ID Installer
    security export -k ~/Library/Keychains/login.keychain-db \
        -t identities \
        -f pkcs12 \
        -P "$P12_PASSWORD" \
        -o "$P12_FILE" 2>/dev/null || {
        echo -e "  ${RED}Failed to export from login keychain${NC}"
        echo "  Trying default keychain..."
        security export \
            -t identities \
            -f pkcs12 \
            -P "$P12_PASSWORD" \
            -o "$P12_FILE" 2>/dev/null || {
            echo -e "  ${RED}Failed to export certificates${NC}"
            echo ""
            echo "  Manual alternative:"
            echo "  1. Open Keychain Access"
            echo "  2. Select your Developer ID certificates"
            echo "  3. File > Export Items... > Save as .p12"
            echo "  4. Save to: $P12_FILE"
            echo "  5. Save the password to: $PWD_FILE"
            echo "  6. Re-run this script"
            exit 1
        }
    }

    if [[ ! -s "$P12_FILE" ]]; then
        echo -e "  ${RED}Export produced empty .p12 file${NC}"
        exit 1
    fi

    # Save the password
    echo -n "$P12_PASSWORD" > "$PWD_FILE"
    chmod 600 "$P12_FILE" "$PWD_FILE"

    echo -e "  ${GREEN}Exported${NC} signing_certs.p12 ($(wc -c < "$P12_FILE" | xargs) bytes)"
fi

# ── Base64-encode .p12 ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Preparing secrets...${NC}"

CERT_B64=$(base64 -i "$P12_FILE")
CERT_PWD=$(cat "$PWD_FILE")

# Use the same .p12 for both app and installer cert secrets
# CI imports both into one keychain; codesign and productbuild pick the right cert by name
echo -e "  ${GREEN}Done${NC} (base64 size: ${#CERT_B64} chars)"

# ── Secret key→value mapping (bash 3.2 compatible — no associative arrays) ─
# Parallel arrays: SECRET_KEYS[i] corresponds to SECRET_VALS[i]
SECRET_KEYS=(
    APPLE_DEVELOPER_CERTIFICATE_P12_BASE64
    APPLE_DEVELOPER_CERTIFICATE_PASSWORD
    APPLE_INSTALLER_CERTIFICATE_P12_BASE64
    APPLE_INSTALLER_CERTIFICATE_PASSWORD
    APPLE_ID
    APP_SPECIFIC_PASSWORD
    TEAM_ID
)
SECRET_VALS=(
    "$CERT_B64"
    "$CERT_PWD"
    "$CERT_B64"
    "$CERT_PWD"
    "$APPLE_ID"
    "$APP_SPECIFIC_PASSWORD"
    "$TEAM_ID"
)

# ── Show summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Secrets to push to ${FULL_REPO}:${NC}"
echo ""
printf "  %-50s %s\n" "Secret Name" "Value Preview"
printf "  %-50s %s\n" "──────────────────────────────────────────────────" "─────────────────────"
for i in "${!SECRET_KEYS[@]}"; do
    key="${SECRET_KEYS[$i]}"
    val="${SECRET_VALS[$i]}"
    if [[ ${#val} -gt 30 ]]; then
        preview="${val:0:20}...${val: -5} (${#val} chars)"
    else
        preview="${val:0:4}****"
    fi
    printf "  %-50s %s\n" "$key" "$preview"
done
echo ""

# ── Dry run exit ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}Dry run — no secrets were pushed. Remove --check to push.${NC}"
    exit 0
fi

# ── Push secrets to GitHub ────────────────────────────────────────────────
echo -e "${BOLD}Pushing secrets to GitHub...${NC}"
echo ""

PUSHED=0
FAILED=0
for i in "${!SECRET_KEYS[@]}"; do
    key="${SECRET_KEYS[$i]}"
    val="${SECRET_VALS[$i]}"
    if echo -n "$val" | gh secret set "$key" --repo "$FULL_REPO" 2>/dev/null; then
        echo -e "  ${GREEN}Set${NC} $key"
        ((PUSHED++)) || true
    else
        echo -e "  ${RED}Failed${NC} $key"
        ((FAILED++)) || true
    fi
done

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All $PUSHED secrets pushed to ${FULL_REPO}${NC}"
else
    echo -e "${YELLOW}Pushed $PUSHED, failed $FAILED${NC}"
fi

# ── Verify ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Verification — secrets on ${FULL_REPO}:${NC}"
gh secret list --repo "$FULL_REPO" 2>/dev/null || echo -e "${YELLOW}Could not list secrets (check permissions)${NC}"
echo ""
echo "Done."

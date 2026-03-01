#!/usr/bin/env bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VISAGE_DIR="$PROJECT_DIR/external/visage"
PATCHES_DIR="$SCRIPT_DIR/patches/visage"
VISAGE_REPO="https://github.com/VitalAudio/visage.git"

usage() {
    echo "Usage: $0 [--verify] [--force]"
    echo ""
    echo "Clones Visage and applies patches for JUCE plugin compatibility."
    echo ""
    echo "Options:"
    echo "  --verify   Check if patches are already applied (don't modify anything)"
    echo "  --force    Remove existing external/visage/ and re-clone"
    echo "  -h|--help  Show this help"
}

VERIFY_ONLY=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify) VERIFY_ONLY=true; shift ;;
        --force)  FORCE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
    esac
done

# --- Verify mode ---
if [ "$VERIFY_ONLY" = true ]; then
    echo -e "${CYAN}Verifying patches...${NC}"
    if [ ! -d "$VISAGE_DIR" ]; then
        echo -e "${RED}Visage not found at $VISAGE_DIR${NC}"
        exit 1
    fi

    all_applied=true
    for patch_file in "$PATCHES_DIR"/*.patch; do
        [ -f "$patch_file" ] || continue
        patch_name=$(basename "$patch_file")
        # Extract PR number from comment
        pr_num=$(grep -m1 'pull/' "$patch_file" | grep -o '[0-9]*$' || echo "?")

        if git -C "$VISAGE_DIR" apply --check "$patch_file" 2>/dev/null; then
            echo -e "${YELLOW}  Not applied: $patch_name (PR #$pr_num)${NC}"
            all_applied=false
        else
            echo -e "${GREEN}  Already applied: $patch_name (PR #$pr_num)${NC}"
        fi
    done

    if [ "$all_applied" = true ]; then
        echo -e "${GREEN}All patches are applied.${NC}"
    else
        echo -e "${YELLOW}Some patches are not yet applied. Run without --verify to apply them.${NC}"
    fi
    exit 0
fi

# --- Clone or re-use ---
if [ -d "$VISAGE_DIR" ]; then
    if [ "$FORCE" = true ]; then
        echo -e "${YELLOW}Removing existing Visage directory (--force)...${NC}"
        rm -rf "$VISAGE_DIR"
    else
        echo -e "${YELLOW}Visage already exists at $VISAGE_DIR${NC}"
        echo -e "${CYAN}Use --force to re-clone, or --verify to check patch status.${NC}"
        echo ""
        echo -e "${CYAN}Attempting to apply any unapplied patches...${NC}"
    fi
fi

if [ ! -d "$VISAGE_DIR" ]; then
    echo -e "${CYAN}Cloning Visage from $VISAGE_REPO...${NC}"
    mkdir -p "$(dirname "$VISAGE_DIR")"
    git clone "$VISAGE_REPO" "$VISAGE_DIR"
    echo -e "${GREEN}Cloned Visage successfully.${NC}"
fi

# --- Apply patches ---
echo ""
echo -e "${CYAN}Applying patches...${NC}"

applied=0
skipped=0
failed=0

for patch_file in "$PATCHES_DIR"/*.patch; do
    [ -f "$patch_file" ] || continue
    patch_name=$(basename "$patch_file")
    # Extract PR number from comment
    pr_num=$(grep -m1 'pull/' "$patch_file" | grep -o '[0-9]*$' || echo "?")

    # Check if patch can be applied (if it can, it hasn't been applied yet)
    if git -C "$VISAGE_DIR" apply --check "$patch_file" 2>/dev/null; then
        if git -C "$VISAGE_DIR" apply "$patch_file" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Applied: $patch_name (PR #$pr_num)${NC}"
            ((applied++))
        else
            echo -e "${RED}  ✗ Failed: $patch_name (PR #$pr_num)${NC}"
            ((failed++))
        fi
    else
        echo -e "${CYAN}  ● Skipped: $patch_name (already applied or context changed)${NC}"
        ((skipped++))
    fi
done

echo ""
echo -e "${GREEN}Done: $applied applied, $skipped skipped, $failed failed${NC}"

if [ $failed -gt 0 ]; then
    echo -e "${RED}Some patches failed to apply. The upstream code may have changed.${NC}"
    echo -e "${YELLOW}Check if the corresponding PRs have been merged:${NC}"
    for patch_file in "$PATCHES_DIR"/*.patch; do
        [ -f "$patch_file" ] || continue
        pr_url=$(grep -m1 'https://github.com' "$patch_file" || echo "")
        if [ -n "$pr_url" ]; then
            echo "  $pr_url"
        fi
    done
    exit 1
fi

echo -e "${GREEN}Visage is ready for use.${NC}"

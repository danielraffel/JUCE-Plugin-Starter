#!/bin/bash
# update_download_links.sh — Updates download links in README.md and gh-pages index.html
# Called automatically during publish, or manually: ./scripts/update_download_links.sh [version]
#
# Handles two states:
#   1. First activation: replaces "Coming Soon" stub with active download button (marker-comment replacement)
#   2. Subsequent updates: replaces versioned URLs in existing active buttons (sed replacement)
#
# Usage:
#   ./scripts/update_download_links.sh          # reads version from .env
#   ./scripts/update_download_links.sh 1.0.15   # explicit version
#   ./scripts/update_download_links.sh 1.0.15 --platform macos   # update macOS links only
#   ./scripts/update_download_links.sh 1.0.15 --platform windows  # update Windows links only

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Load .env
if [[ -f .env ]]; then
    set -a; source .env; set +a
fi

# Determine version
VERSION_ARG=""
PLATFORM_FILTER=""  # empty = all platforms
while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform) PLATFORM_FILTER="$2"; shift 2 ;;
        *) VERSION_ARG="$1"; shift ;;
    esac
done

if [[ -n "$VERSION_ARG" ]]; then
    VERSION="$VERSION_ARG"
else
    VERSION="${VERSION_MAJOR:-0}.${VERSION_MINOR:-0}.${VERSION_PATCH:-0}"
fi

GITHUB_USER="${GITHUB_USER:-${GITHUB_USERNAME:-yourusername}}"
GITHUB_REPO="${GITHUB_REPO:-${PROJECT_NAME:-MyPlugin}}"
PROJECT_NAME="${PROJECT_NAME:-$GITHUB_REPO}"
TAG="v${VERSION}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Cross-platform sed -i (macOS vs Linux)
sedi() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

echo "Updating download links to version ${VERSION} (${TAG})..."

# ── Marker-comment block replacement ─────────────────────────────────
# Replaces everything between <!-- DOWNLOAD-PLATFORM-START --> and <!-- DOWNLOAD-PLATFORM-END -->
# with an active download button. Works for both first activation (stub→active) and updates.
replace_download_block() {
    local file="$1"
    local platform="$2"  # macos, windows, or linux
    local url="$3"
    local label="$4"
    local sublabel="$5"

    local start_marker="<!-- DOWNLOAD-${platform^^}-START -->"
    local end_marker="<!-- DOWNLOAD-${platform^^}-END -->"

    # Check if markers exist in file
    if ! grep -q "$start_marker" "$file" 2>/dev/null; then
        return 0  # No markers for this platform — skip silently
    fi

    # Build the replacement block
    local id="download-${platform}"
    local new_block="${start_marker}
<a id=\"${id}\" href=\"${url}\" class=\"btn btn-primary\">
    <span>${label}</span>
    <small>${sublabel}</small>
</a>
${end_marker}"

    # Use awk to replace between markers (portable across macOS/Linux)
    local tmpfile
    tmpfile=$(mktemp)
    awk -v start="$start_marker" -v end="$end_marker" -v replacement="$new_block" '
        $0 ~ start { print replacement; skip=1; next }
        $0 ~ end { skip=0; next }
        !skip { print }
    ' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}

# ── Update versioned URLs (for subsequent updates) ───────────────────
update_versioned_urls() {
    local file="$1"

    if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "macos" ]]; then
        sedi -E \
            "s|/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/${PROJECT_NAME}_[0-9]+\.[0-9]+\.[0-9]+\.pkg|/releases/download/${TAG}/${PROJECT_NAME}_${VERSION}.pkg|g" \
            "$file"
    fi

    if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "windows" ]]; then
        sedi -E \
            "s|/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/${PROJECT_NAME}_[0-9]+\.[0-9]+\.[0-9]+_Setup\.exe|/releases/download/${TAG}/${PROJECT_NAME}_${VERSION}_Setup.exe|g" \
            "$file"
    fi

    if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "linux" ]]; then
        sedi -E \
            "s|/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/${PROJECT_NAME}_[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz|/releases/download/${TAG}/${PROJECT_NAME}_${VERSION}.tar.gz|g" \
            "$file"
    fi
}

# ── Build download URLs ──────────────────────────────────────────────
RELEASE_BASE="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${TAG}"
MACOS_URL="${RELEASE_BASE}/${PROJECT_NAME}_${VERSION}.pkg"
WINDOWS_URL="${RELEASE_BASE}/${PROJECT_NAME}_${VERSION}_Setup.exe"
LINUX_URL="${RELEASE_BASE}/${PROJECT_NAME}_${VERSION}.tar.gz"

# ── 1. Update README.md ──────────────────────────────────────────────
README="$ROOT_DIR/README.md"
if [[ -f "$README" ]]; then
    update_versioned_urls "$README"
    echo -e "${GREEN}  Updated README.md download links${NC}"
else
    echo -e "${YELLOW}  README.md not found — skipping${NC}"
fi

# ── 2. Update gh-pages index.html ────────────────────────────────────
GHPAGES_BRANCH="gh-pages"

# Check both local and remote for gh-pages
HAS_GHPAGES=false
if git rev-parse --verify "$GHPAGES_BRANCH" &>/dev/null; then
    HAS_GHPAGES=true
elif git rev-parse --verify "origin/$GHPAGES_BRANCH" &>/dev/null; then
    # Fetch and create local tracking branch
    git fetch origin "$GHPAGES_BRANCH" --quiet 2>/dev/null || true
    git branch "$GHPAGES_BRANCH" "origin/$GHPAGES_BRANCH" --quiet 2>/dev/null || true
    HAS_GHPAGES=true
fi

if [[ "$HAS_GHPAGES" == "true" ]]; then
    TMPDIR=$(mktemp -d)
    git worktree add "$TMPDIR" "$GHPAGES_BRANCH" --quiet 2>/dev/null || {
        echo -e "${YELLOW}  Could not create gh-pages worktree — skipping website update${NC}"
        rm -rf "$TMPDIR"
        exit 0
    }

    INDEX="$TMPDIR/index.html"
    if [[ -f "$INDEX" ]]; then
        # First: marker-comment block replacement (handles stub→active AND active→updated)
        if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "macos" ]]; then
            replace_download_block "$INDEX" "macos" "$MACOS_URL" \
                "Download for macOS" "Universal Binary (Intel + Apple Silicon)"
        fi
        if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "windows" ]]; then
            replace_download_block "$INDEX" "windows" "$WINDOWS_URL" \
                "Download for Windows" "64-bit"
        fi
        if [[ -z "$PLATFORM_FILTER" ]] || [[ "$PLATFORM_FILTER" == "linux" ]]; then
            replace_download_block "$INDEX" "linux" "$LINUX_URL" \
                "Download for Linux" "x86_64"
        fi

        # Second: catch any other versioned URLs not inside marker blocks
        update_versioned_urls "$INDEX"

        # Commit and push if changed
        cd "$TMPDIR"
        if ! git diff --quiet index.html 2>/dev/null; then
            git add index.html
            git commit -m "Update download links to ${TAG}" --quiet
            git push origin "$GHPAGES_BRANCH" --quiet
            echo -e "${GREEN}  Updated gh-pages download links${NC}"
        else
            echo "  gh-pages index.html already up to date"
        fi
        cd "$ROOT_DIR"
    else
        echo -e "${YELLOW}  No index.html on gh-pages — skipping${NC}"
    fi

    # Cleanup worktree
    git worktree remove "$TMPDIR" --force 2>/dev/null || rm -rf "$TMPDIR"
else
    echo -e "${YELLOW}  No gh-pages branch found — skipping website update${NC}"
    echo "  Tip: Run /juce-dev:website to create a download page"
fi

# ── 3. Commit README changes if needed ────────────────────────────────
cd "$ROOT_DIR"
if ! git diff --quiet README.md 2>/dev/null; then
    git add README.md
    git commit -m "Update download links to ${TAG}" --quiet
    echo -e "${GREEN}  Committed README.md changes${NC}"
fi

echo "Done."

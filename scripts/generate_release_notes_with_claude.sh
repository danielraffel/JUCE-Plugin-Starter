#!/bin/bash
#
# Generate release notes using Claude Code
# This script prepares git commit data and provides a prompt for Claude Code
# to analyze and generate user-friendly release notes.
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Parse arguments
VERSION="${1:-1.0.0}"
SINCE_TAG="${2:-}"
OUTPUT_FILE="${3:-}"

# Get last tag if not specified
if [[ -z "$SINCE_TAG" ]]; then
    SINCE_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
fi

# Determine commit range
if [[ -n "$SINCE_TAG" ]]; then
    COMMIT_RANGE="$SINCE_TAG..HEAD"
    echo -e "${GREEN}📝 Analyzing commits since tag: $SINCE_TAG${NC}"
else
    # Count commits to determine safe range
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No commits found in repository${NC}"
        exit 1
    elif [[ "$COMMIT_COUNT" -eq 1 ]]; then
        COMMIT_RANGE="HEAD"
    else
        LOOKBACK=$((COMMIT_COUNT < 10 ? COMMIT_COUNT - 1 : 10))
        COMMIT_RANGE="HEAD~${LOOKBACK}..HEAD"
    fi
    echo -e "${GREEN}📝 Analyzing last ${LOOKBACK:-1} commits${NC}"
fi

# Get commit history
COMMITS=$(git log --oneline --no-merges "$COMMIT_RANGE" 2>/dev/null || echo "")

if [[ -z "$COMMITS" ]]; then
    echo -e "${YELLOW}⚠️  No commits found in range${NC}"
    exit 1
fi

# Count commits
COMMIT_COUNT=$(echo "$COMMITS" | wc -l | xargs)
echo -e "${GREEN}Found ${COMMIT_COUNT} commits${NC}"
echo ""

# Get full commit details for better context
DETAILED_COMMITS=$(git log --format="📝 %s%n   Author: %an <%ae>%n   Date: %ar%n" --no-merges "$COMMIT_RANGE" 2>/dev/null || echo "")

# Prepare prompt for Claude Code
echo -e "${GREEN}🤖 Preparing release notes prompt for Claude Code...${NC}"
echo ""

PROMPT="# Release Notes Generation Request

**Version:** $VERSION
**Commit Range:** $COMMIT_RANGE
**Number of Commits:** $COMMIT_COUNT

## Project Context
This is a JUCE audio plugin project. Users are musicians, producers, and audio engineers who install audio plugins for use in DAWs like Logic Pro, Ableton Live, Reaper, etc.

## Recent Commits

\`\`\`
$DETAILED_COMMITS
\`\`\`

## Task
Please analyze these commits and generate release notes in the following markdown format:

\`\`\`markdown
## Version $VERSION

### ✨ New Features
- [User-friendly description of new features]

### 🔧 Improvements
- [User-friendly description of improvements]

### 🐛 Bug Fixes
- [User-friendly description of bug fixes]
\`\`\`

## Guidelines
1. **User-focused**: Write for end users (musicians/producers), not developers
2. **Concise**: Each bullet point should be one clear sentence
3. **Impact-oriented**: Focus on what users will notice, not implementation details
4. **Categorize appropriately**: Features = new capabilities, Improvements = enhancements to existing features, Fixes = bug corrections
5. **Skip technical jargon**: Avoid terms like \"refactor\", \"CMake\", \"build system\" unless directly relevant to users
6. **Omit empty sections**: If there are no fixes, don't include the Fixes section

## Example Good Release Notes
\`\`\`markdown
## Version 1.2.0

### ✨ New Features
- Added support for MIDI learn - click any parameter to assign a MIDI controller
- New preset browser with search and favorites

### 🔧 Improvements
- Reduced CPU usage by 30% for better performance in large projects
- Improved audio quality at high sample rates

### 🐛 Bug Fixes
- Fixed crash when loading certain AU presets in Logic Pro
- Resolved audio glitches when changing buffer sizes
\`\`\`

Please generate the release notes now."

# Output the prompt
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$PROMPT" > "$OUTPUT_FILE"
    echo -e "${GREEN}✅ Prompt saved to: $OUTPUT_FILE${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Share this prompt with Claude Code"
    echo "2. Claude Code will generate the release notes"
    echo "3. Save the notes to: docs/release-notes-${VERSION}.md"
else
    echo "$PROMPT"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}💡 Using with Claude Code:${NC}"
    echo ""
    echo "1. Copy the prompt above"
    echo "2. Paste it to Claude Code"
    echo "3. Claude Code will generate user-friendly release notes"
    echo "4. Copy the generated notes"
    echo "5. Save to: docs/release-notes-${VERSION}.md"
    echo ""
    echo -e "${GREEN}💡 Or run with output file:${NC}"
    echo "   ./scripts/generate_release_notes_with_claude.sh $VERSION \"$SINCE_TAG\" /tmp/release-notes-prompt.txt"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

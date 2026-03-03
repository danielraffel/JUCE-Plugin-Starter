#!/bin/bash
# Setup Visage GPU UI framework for JUCE-Plugin-Starter projects
# Clones the patched Visage fork and copies bridge files into Source/Visage/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VISAGE_DIR="$PROJECT_DIR/external/visage"
VISAGE_REPO="https://github.com/danielraffel/visage.git"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=== Visage GPU UI Setup ==="
echo ""

# Step 1: Clone Visage
if [ -d "$VISAGE_DIR" ]; then
    echo -e "${YELLOW}external/visage/ already exists — pulling latest...${NC}"
    cd "$VISAGE_DIR" && git pull origin main 2>/dev/null || true
    cd "$PROJECT_DIR"
else
    echo "Cloning Visage from $VISAGE_REPO..."
    mkdir -p "$PROJECT_DIR/external"
    git clone "$VISAGE_REPO" "$VISAGE_DIR"
    echo -e "${GREEN}Cloned Visage into external/visage/${NC}"
fi

# Step 2: Copy bridge files
BRIDGE_SRC="$PROJECT_DIR/templates/visage"
BRIDGE_DST="$PROJECT_DIR/Source/Visage"

if [ -d "$BRIDGE_SRC" ]; then
    mkdir -p "$BRIDGE_DST"
    if [ -f "$BRIDGE_SRC/JuceVisageBridge.h" ]; then
        cp "$BRIDGE_SRC/JuceVisageBridge.h" "$BRIDGE_DST/"
        cp "$BRIDGE_SRC/JuceVisageBridge.cpp" "$BRIDGE_DST/"
        echo -e "${GREEN}Copied JuceVisageBridge to Source/Visage/${NC}"
    fi
fi

# Step 3: Update CMakeLists.txt (append Visage block if not already present)
CMAKE_FILE="$PROJECT_DIR/CMakeLists.txt"
if ! grep -q "external/visage" "$CMAKE_FILE" 2>/dev/null; then
    cat >> "$CMAKE_FILE" << 'VISAGE_CMAKE'

# ==============================================================================
# Visage GPU UI (Metal-accelerated rendering)
# ==============================================================================
# Added by setup_visage.sh — uses the danielraffel/visage patched fork
# with macOS plugin fixes and iOS support.
set(USE_VISAGE_UI $ENV{USE_VISAGE_UI})
if(NOT USE_VISAGE_UI)
    set(USE_VISAGE_UI "FALSE")
endif()

if(USE_VISAGE_UI STREQUAL "TRUE" AND EXISTS "${CMAKE_SOURCE_DIR}/external/visage/CMakeLists.txt")
    add_subdirectory(external/visage)

    target_sources(${PROJECT_NAME} PRIVATE
        Source/Visage/JuceVisageBridge.cpp
        Source/Visage/JuceVisageBridge.h
    )

    target_include_directories(${PROJECT_NAME} PRIVATE
        ${CMAKE_SOURCE_DIR}/external/visage
    )

    target_link_libraries(${PROJECT_NAME} PRIVATE visage)

    target_compile_definitions(${PROJECT_NAME} PUBLIC
        VISAGE_UI_ENABLED=1
    )

    message(STATUS "Visage GPU UI: ENABLED")
else()
    message(STATUS "Visage GPU UI: disabled (set USE_VISAGE_UI=TRUE in .env to enable)")
endif()
VISAGE_CMAKE
    echo -e "${GREEN}Added Visage CMake configuration to CMakeLists.txt${NC}"
else
    echo "CMakeLists.txt already has Visage configuration — skipping"
fi

# Step 4: Update .env
ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    if grep -q "USE_VISAGE_UI" "$ENV_FILE"; then
        sed -i '' 's/USE_VISAGE_UI=.*/USE_VISAGE_UI=TRUE/' "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "# Visage GPU UI" >> "$ENV_FILE"
        echo "USE_VISAGE_UI=TRUE" >> "$ENV_FILE"
    fi
    echo -e "${GREEN}Set USE_VISAGE_UI=TRUE in .env${NC}"
fi

echo ""
echo -e "${GREEN}Visage setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Rebuild: rm -rf build/ && ./scripts/generate_and_open_xcode.sh"
echo "  2. The juce-visage skill is available for UI development guidance"
echo ""

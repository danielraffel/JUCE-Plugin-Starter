#!/bin/bash

# Plugin validation script - checks build output for completeness
# Usage: ./scripts/validate_plugin.sh [component_path]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Plugin Validation Tool"
echo "========================"

# Get component path from argument or default location
if [ -n "$1" ]; then
    COMPONENT_PATH="$1"
else
    # Load environment to get project name
    if [ -f .env ]; then
        set -o allexport
        source .env
        set +o allexport
    else
        echo -e "${RED}❌ .env file not found${NC}"
        exit 1
    fi
    
    # Check default locations
    if [ -d "$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component" ]; then
        COMPONENT_PATH="$HOME/Library/Audio/Plug-Ins/Components/${PROJECT_NAME}.component"
    elif [ -d "build/${PROJECT_NAME}_artefacts/Debug/AU/${PROJECT_NAME}.component" ]; then
        COMPONENT_PATH="build/${PROJECT_NAME}_artefacts/Debug/AU/${PROJECT_NAME}.component"
    elif [ -d "build/${PROJECT_NAME}_artefacts/Release/AU/${PROJECT_NAME}.component" ]; then
        COMPONENT_PATH="build/${PROJECT_NAME}_artefacts/Release/AU/${PROJECT_NAME}.component"
    else
        echo -e "${RED}❌ Component not found in default locations${NC}"
        echo "   Please specify path as argument"
        exit 1
    fi
fi

echo "📦 Validating: $COMPONENT_PATH"
echo ""

# Track validation results
ERRORS=0
WARNINGS=0

# 1. Check component exists
echo "1. Component Bundle Structure"
echo "   -------------------------"
if [ ! -d "$COMPONENT_PATH" ]; then
    echo -e "   ${RED}❌ Component bundle not found${NC}"
    exit 1
fi

# Check required directories
for dir in "Contents" "Contents/MacOS" "Contents/Resources"; do
    if [ -d "$COMPONENT_PATH/$dir" ]; then
        echo -e "   ${GREEN}✓${NC} $dir exists"
    else
        echo -e "   ${RED}✗ Missing $dir${NC}"
        ((ERRORS++))
    fi
done

# 2. Check binary exists
echo ""
echo "2. Binary Validation"
echo "   ----------------"
BINARY_NAME=$(basename "$COMPONENT_PATH" .component)
BINARY_PATH="$COMPONENT_PATH/Contents/MacOS/$BINARY_NAME"

if [ -f "$BINARY_PATH" ]; then
    echo -e "   ${GREEN}✓${NC} Binary exists: $BINARY_NAME"
    
    # Check file type
    FILE_TYPE=$(file "$BINARY_PATH")
    if [[ "$FILE_TYPE" =~ "Mach-O" ]]; then
        echo -e "   ${GREEN}✓${NC} Valid Mach-O binary"
    else
        echo -e "   ${RED}✗ Not a valid Mach-O binary${NC}"
        echo "     Type: $FILE_TYPE"
        ((ERRORS++))
    fi
    
    # Check architectures
    ARCHS=$(lipo -archs "$BINARY_PATH" 2>/dev/null || echo "unknown")
    if [[ "$ARCHS" == "unknown" ]]; then
        echo -e "   ${RED}✗ Could not determine architectures${NC}"
        ((ERRORS++))
    else
        echo -e "   ${GREEN}✓${NC} Architectures: $ARCHS"
        
        # Check for universal binary
        if [[ "$ARCHS" =~ "x86_64" ]] && [[ "$ARCHS" =~ "arm64" ]]; then
            echo -e "   ${GREEN}✓${NC} Universal binary (Intel + Apple Silicon)"
        elif [[ "$ARCHS" == "arm64" ]]; then
            echo -e "   ${YELLOW}⚠${NC} Apple Silicon only"
            ((WARNINGS++))
        elif [[ "$ARCHS" == "x86_64" ]]; then
            echo -e "   ${YELLOW}⚠${NC} Intel only"
            ((WARNINGS++))
        fi
    fi
    
    # Check size (should be reasonable)
    SIZE=$(stat -f%z "$BINARY_PATH" 2>/dev/null || stat -c%s "$BINARY_PATH" 2>/dev/null || echo 0)
    SIZE_MB=$((SIZE / 1048576))
    if [ $SIZE -gt 1000000 ]; then
        echo -e "   ${GREEN}✓${NC} Binary size: ${SIZE_MB}MB"
    else
        echo -e "   ${RED}✗ Binary suspiciously small: ${SIZE} bytes${NC}"
        ((ERRORS++))
    fi
else
    echo -e "   ${RED}✗ Binary not found at: $BINARY_PATH${NC}"
    ((ERRORS++))
fi

# 3. Check Info.plist
echo ""
echo "3. Info.plist Validation"
echo "   --------------------"
PLIST_PATH="$COMPONENT_PATH/Contents/Info.plist"

if [ -f "$PLIST_PATH" ]; then
    echo -e "   ${GREEN}✓${NC} Info.plist exists"
    
    # Check bundle identifier
    BUNDLE_ID=$(defaults read "$PLIST_PATH" CFBundleIdentifier 2>/dev/null || echo "unknown")
    if [ "$BUNDLE_ID" != "unknown" ]; then
        echo -e "   ${GREEN}✓${NC} Bundle ID: $BUNDLE_ID"
    else
        echo -e "   ${RED}✗ Could not read Bundle ID${NC}"
        ((ERRORS++))
    fi
    
    # Check version
    VERSION=$(defaults read "$PLIST_PATH" CFBundleVersion 2>/dev/null || echo "unknown")
    if [ "$VERSION" != "unknown" ]; then
        echo -e "   ${GREEN}✓${NC} Version: $VERSION"
    else
        echo -e "   ${YELLOW}⚠${NC} Could not read version"
        ((WARNINGS++))
    fi
    
    # Check AU factory function
    FACTORY_FUNC=$(defaults read "$PLIST_PATH" AudioComponents 2>/dev/null | grep factoryFunction | head -1 | sed 's/.*= "\(.*\)";/\1/' || echo "unknown")
    if [ "$FACTORY_FUNC" != "unknown" ] && [ -n "$FACTORY_FUNC" ]; then
        echo -e "   ${GREEN}✓${NC} AU Factory: $FACTORY_FUNC"
    else
        echo -e "   ${RED}✗ Could not find AU factory function${NC}"
        ((ERRORS++))
    fi
else
    echo -e "   ${RED}✗ Info.plist not found${NC}"
    ((ERRORS++))
fi

# 4. Check library dependencies
echo ""
echo "4. Library Dependencies"
echo "   --------------------"
if [ -f "$BINARY_PATH" ]; then
    # Check for both architectures
    for arch in x86_64 arm64; do
        echo "   Architecture: $arch"
        DEPS=$(otool -arch $arch -L "$BINARY_PATH" 2>/dev/null | tail -n +2 || echo "")
        if [ -n "$DEPS" ]; then
            # Count system frameworks
            FRAMEWORK_COUNT=$(echo "$DEPS" | grep -c "/System/Library/Frameworks/" || echo 0)
            echo -e "     ${GREEN}✓${NC} System frameworks: $FRAMEWORK_COUNT"
            
            # Check for missing dependencies
            MISSING=$(echo "$DEPS" | grep "@rpath" | grep -v "@executable_path" || echo "")
            if [ -n "$MISSING" ]; then
                echo -e "     ${YELLOW}⚠${NC} Has @rpath dependencies (may need fixing)"
                ((WARNINGS++))
            fi
        else
            echo -e "     ${YELLOW}-${NC} No $arch slice or cannot read dependencies"
        fi
    done
fi

# 5. Code signature check
echo ""
echo "5. Code Signature"
echo "   --------------"
if codesign --verify --deep --verbose=2 "$COMPONENT_PATH" 2>&1 | grep -q "valid on disk"; then
    echo -e "   ${GREEN}✓${NC} Valid code signature"
    
    # Check signing authority
    SIGNER=$(codesign -dvv "$COMPONENT_PATH" 2>&1 | grep "Authority=" | head -1 | cut -d= -f2)
    if [ -n "$SIGNER" ]; then
        echo -e "   ${GREEN}✓${NC} Signed by: $SIGNER"
    fi
else
    echo -e "   ${YELLOW}⚠${NC} Not signed or invalid signature"
    ((WARNINGS++))
fi

# 6. AU Validation (if available)
echo ""
echo "6. Audio Unit Validation"
echo "   --------------------"
if command -v auval >/dev/null 2>&1; then
    # Extract AU info from plist
    if [ -f "$PLIST_PATH" ]; then
        AU_TYPE=$(defaults read "$PLIST_PATH" AudioComponents 2>/dev/null | grep "type =" | head -1 | sed 's/.*= \(.*\);/\1/' || echo "")
        AU_SUBTYPE=$(defaults read "$PLIST_PATH" AudioComponents 2>/dev/null | grep "subtype =" | head -1 | sed 's/.*= \(.*\);/\1/' || echo "")
        AU_MANU=$(defaults read "$PLIST_PATH" AudioComponents 2>/dev/null | grep "manufacturer =" | head -1 | sed 's/.*= \(.*\);/\1/' || echo "")
        
        if [ -n "$AU_TYPE" ] && [ -n "$AU_SUBTYPE" ] && [ -n "$AU_MANU" ]; then
            echo "   Testing: $AU_TYPE $AU_SUBTYPE $AU_MANU"
            
            # Quick validation test
            if auval -v "$AU_TYPE" "$AU_SUBTYPE" "$AU_MANU" 2>&1 | grep -q "PASS"; then
                echo -e "   ${GREEN}✓${NC} AU validation passed"
            else
                echo -e "   ${RED}✗ AU validation failed${NC}"
                echo "     Run: auval -v $AU_TYPE $AU_SUBTYPE $AU_MANU"
                ((ERRORS++))
            fi
        else
            echo -e "   ${YELLOW}⚠${NC} Could not extract AU component info"
            ((WARNINGS++))
        fi
    fi
else
    echo -e "   ${YELLOW}-${NC} auval not available"
fi

# Summary
echo ""
echo "========================================"
echo "VALIDATION SUMMARY"
echo "========================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo "The plugin appears to be properly built."
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Validation completed with $WARNINGS warning(s)${NC}"
    echo "The plugin should work but may have minor issues."
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "The plugin likely will not load properly."
fi

echo ""
echo "For detailed AU validation, run:"
echo "  auval -a  # List all Audio Units"
echo "  auval -v <type> <subtype> <manufacturer>  # Validate specific AU"

exit $ERRORS
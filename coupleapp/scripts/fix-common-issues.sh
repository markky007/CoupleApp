#!/bin/bash

# Couple Quest - Common Build Issues Fixer
# This script automatically fixes common build issues

set -e

echo "🔧 Couple Quest - Build Issue Fixer"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to show menu
show_menu() {
    echo -e "${BLUE}Select an option:${NC}"
    echo "1. Clean DerivedData"
    echo "2. Resolve Package Dependencies"
    echo "3. Clean Build Folder"
    echo "4. Fix All (1+2+3)"
    echo "5. Run Build Verification"
    echo "6. Exit"
    echo ""
}

# Function to clean derived data
clean_derived_data() {
    echo -e "${YELLOW}🧹 Cleaning DerivedData...${NC}"
    rm -rf ~/Library/Developer/Xcode/DerivedData/coupleapp-*
    echo -e "${GREEN}✅ DerivedData cleaned${NC}"
    echo ""
}

# Function to resolve packages
resolve_packages() {
    echo -e "${YELLOW}📦 Resolving Package Dependencies...${NC}"
    cd "$WORKSPACE_DIR"
    xcodebuild \
        -project coupleapp.xcodeproj \
        -scheme coupleapp \
        -resolvePackageDependencies \
        > /dev/null 2>&1
    echo -e "${GREEN}✅ Package dependencies resolved${NC}"
    echo ""
}

# Function to clean build folder
clean_build() {
    echo -e "${YELLOW}🧹 Cleaning Build Folder...${NC}"
    cd "$WORKSPACE_DIR"
    xcodebuild clean \
        -project coupleapp.xcodeproj \
        -scheme coupleapp \
        > /dev/null 2>&1
    echo -e "${GREEN}✅ Build folder cleaned${NC}"
    echo ""
}

# Function to fix all
fix_all() {
    echo -e "${BLUE}🔧 Running all fixes...${NC}"
    echo ""
    clean_derived_data
    resolve_packages
    clean_build
    echo -e "${GREEN}✅ All fixes applied!${NC}"
    echo ""
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo "1. Open Xcode"
    echo "2. Press Cmd + B to build"
    echo "3. Or run: ./scripts/verify-build.sh"
    echo ""
}

# Function to run build verification
run_verification() {
    echo -e "${BLUE}🔍 Running build verification...${NC}"
    echo ""
    "$WORKSPACE_DIR/scripts/verify-build.sh"
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice [1-6]: " choice
    echo ""
    
    case $choice in
        1)
            clean_derived_data
            ;;
        2)
            resolve_packages
            ;;
        3)
            clean_build
            ;;
        4)
            fix_all
            ;;
        5)
            run_verification
            ;;
        6)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Please try again.${NC}"
            echo ""
            ;;
    esac
done

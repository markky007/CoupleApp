#!/bin/bash

# Couple Quest - Build Verification Script
# This script verifies that the Xcode project builds successfully

set -e  # Exit on error

echo "🔍 Couple Quest - Build Verification"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="coupleapp"
SCHEME="coupleapp"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$WORKSPACE_DIR/$PROJECT_NAME.xcodeproj"

echo "📁 Project Path: $PROJECT_PATH"
echo ""

# Step 1: Check if Xcode is installed
echo "1️⃣  Checking Xcode installation..."
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Xcode found${NC}"
echo ""

# Step 2: Check if project exists
echo "2️⃣  Checking project file..."
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Error: Project not found at $PROJECT_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Project file found${NC}"
echo ""

# Step 3: Clean build folder
echo "3️⃣  Cleaning build folder..."
xcodebuild clean \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    > /dev/null 2>&1
echo -e "${GREEN}✅ Build folder cleaned${NC}"
echo ""

# Step 4: Resolve package dependencies
echo "4️⃣  Resolving Swift Package dependencies..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -resolvePackageDependencies \
    > /dev/null 2>&1
echo -e "${GREEN}✅ Package dependencies resolved${NC}"
echo ""

# Step 5: Build for iOS Simulator
echo "5️⃣  Building for iOS Simulator..."
echo -e "${YELLOW}⏳ This may take a few minutes...${NC}"
echo ""

BUILD_LOG="$WORKSPACE_DIR/build.log"

# Build for generic iOS Simulator (works with any available simulator)
if xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    > "$BUILD_LOG" 2>&1; then
    
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    echo ""
    echo "📊 Build Summary:"
    grep "Build Succeeded" "$BUILD_LOG" || echo "Build completed successfully"
    echo ""
    
    # Clean up log file
    rm -f "$BUILD_LOG"
    
    exit 0
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "📋 Error Details:"
    echo "=================="
    
    # Extract and display errors
    grep -A 5 "error:" "$BUILD_LOG" | head -20 || echo "See $BUILD_LOG for details"
    
    echo ""
    echo -e "${YELLOW}💡 Common Solutions:${NC}"
    echo "1. Open Xcode and check for missing imports"
    echo "2. Verify Swift Package dependencies are resolved"
    echo "3. Check for platform-specific code (iOS vs macOS)"
    echo "4. Run: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    echo ""
    echo "Full build log saved to: $BUILD_LOG"
    
    exit 1
fi

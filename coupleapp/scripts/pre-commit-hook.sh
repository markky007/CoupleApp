#!/bin/bash

# Couple Quest - Pre-Commit Hook
# This hook runs before each commit to verify build

echo "🔍 Running pre-commit checks..."
echo ""

# Run build verification
if ./scripts/verify-build.sh; then
    echo ""
    echo "✅ All checks passed! Proceeding with commit..."
    exit 0
else
    echo ""
    echo "❌ Build verification failed!"
    echo ""
    echo "Please fix the build errors before committing."
    echo "You can:"
    echo "1. Run: ./scripts/fix-common-issues.sh"
    echo "2. Fix errors manually in Xcode"
    echo "3. Skip this check with: git commit --no-verify"
    echo ""
    exit 1
fi

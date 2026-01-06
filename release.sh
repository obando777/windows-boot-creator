#!/bin/bash
# release.sh - Create a release zip for GitHub
# Usage: ./release.sh [version]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="WindowsBootCreator"
RELEASE_DIR="$SCRIPT_DIR/release"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Get version from argument, git tag, or default
get_version() {
    if [[ -n "$1" ]]; then
        echo "$1"
    elif git describe --tags --exact-match 2>/dev/null; then
        return
    elif git describe --tags 2>/dev/null; then
        return
    else
        echo "v1.0.0"
    fi
}

# ============================================================================
# Main
# ============================================================================

VERSION=$(get_version "$1")
ZIP_NAME="${APP_NAME}-${VERSION}-macos.zip"

log_info "Creating release: $VERSION"

# Step 1: Clean and build release
log_info "Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

BINARY_PATH="$SCRIPT_DIR/.build/release/$APP_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    log_error "Build failed: binary not found at $BINARY_PATH"
    exit 1
fi

# Step 2: Create release directory
log_info "Preparing release directory..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR/$APP_NAME"

# Step 3: Copy binary and resources
cp "$BINARY_PATH" "$RELEASE_DIR/$APP_NAME/"
cp "$SCRIPT_DIR/README.md" "$RELEASE_DIR/$APP_NAME/"

# Copy LICENSE if it exists
if [[ -f "$SCRIPT_DIR/LICENSE" ]]; then
    cp "$SCRIPT_DIR/LICENSE" "$RELEASE_DIR/$APP_NAME/"
fi

# Step 4: Create zip
log_info "Creating zip archive..."
cd "$RELEASE_DIR"
zip -r "$ZIP_NAME" "$APP_NAME"

# Move zip to project root
mv "$ZIP_NAME" "$SCRIPT_DIR/"

# Step 5: Cleanup
rm -rf "$RELEASE_DIR"

# Step 6: Show results
ZIP_PATH="$SCRIPT_DIR/$ZIP_NAME"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

echo ""
log_success "Release created successfully!"
echo ""
echo -e "  ${GREEN}File:${NC} $ZIP_PATH"
echo -e "  ${GREEN}Size:${NC} $ZIP_SIZE"
echo ""
echo -e "  ${BLUE}To create a GitHub release:${NC}"
echo "  1. Go to your repository on GitHub"
echo "  2. Click 'Releases' → 'Create a new release'"
echo "  3. Tag: $VERSION"
echo "  4. Upload: $ZIP_NAME"
echo ""

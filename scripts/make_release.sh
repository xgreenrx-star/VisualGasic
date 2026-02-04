#!/bin/bash
#
# Visual Gasic Release Package Script
# Creates a distributable package for the Godot Asset Library
#

set -e

# Configuration
VERSION="${1:-2.1.0}"
PROJECT_NAME="visual_gasic"
RELEASE_DIR="releases"
PACKAGE_NAME="${PROJECT_NAME}-v${VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Visual Gasic Release Builder v${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "\n${YELLOW}[1/6] Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -f "SConstruct" ]; then
    echo -e "${RED}Error: SConstruct not found. Run this from the project root.${NC}"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "\n${YELLOW}[2/6] Building extension...${NC}"

# Clean and build
scons -c platform=linux >/dev/null 2>&1 || true
scons platform=linux

# Verify build succeeded
if [ ! -f "addons/visual_gasic/bin/libvisualgasic.linux.template_debug.x86_64.so" ]; then
    echo -e "${RED}Error: Build failed - library not found${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"

echo -e "\n${YELLOW}[3/6] Creating release directory...${NC}"

# Create release directory
mkdir -p "${RELEASE_DIR}/${PACKAGE_NAME}"
DEST="${RELEASE_DIR}/${PACKAGE_NAME}"

echo -e "\n${YELLOW}[4/6] Copying files...${NC}"

# Copy addon directory
cp -r addons "${DEST}/"

# Copy documentation
mkdir -p "${DEST}/docs"
cp README.md "${DEST}/"
cp CHANGELOG.md "${DEST}/"
cp LICENSE "${DEST}/"
cp CONTRIBUTING.md "${DEST}/" 2>/dev/null || true

# Copy reference docs
cp -r docs/reference "${DEST}/docs/" 2>/dev/null || true
cp -r docs/guides "${DEST}/docs/" 2>/dev/null || true

# Copy examples
cp -r examples "${DEST}/" 2>/dev/null || true

# Copy tutorials
cp -r tutorials "${DEST}/" 2>/dev/null || true

echo -e "\n${YELLOW}[5/6] Cleaning package...${NC}"

# Remove development files from package
find "${DEST}" -name "*.os" -delete
find "${DEST}" -name "*.o" -delete
find "${DEST}" -name "*.uid" -delete
find "${DEST}" -name ".git*" -delete
find "${DEST}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "${DEST}" -name "*.pyc" -delete
find "${DEST}" -name ".DS_Store" -delete

# Remove test files
rm -rf "${DEST}/examples/test_*" 2>/dev/null || true

echo -e "\n${YELLOW}[6/6] Creating archive...${NC}"

# Create zip file
cd "${RELEASE_DIR}"
zip -r "${PACKAGE_NAME}.zip" "${PACKAGE_NAME}" -x "*.git*"

# Calculate checksums
sha256sum "${PACKAGE_NAME}.zip" > "${PACKAGE_NAME}.zip.sha256"

cd "$PROJECT_ROOT"

# Get package size
PACKAGE_SIZE=$(du -h "${RELEASE_DIR}/${PACKAGE_NAME}.zip" | cut -f1)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Release package created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Package: ${RELEASE_DIR}/${PACKAGE_NAME}.zip"
echo -e "Size: ${PACKAGE_SIZE}"
echo -e "Checksum: ${RELEASE_DIR}/${PACKAGE_NAME}.zip.sha256"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the package in a fresh Godot project"
echo "2. Create a GitHub release with tag v${VERSION}"
echo "3. Upload to the Godot Asset Library"
echo ""

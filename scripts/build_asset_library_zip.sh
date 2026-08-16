#!/bin/bash
# Build the Godot Asset Library submission zip for VisualGasic.
#
# Produces a single-addon archive (addons/visual_gasic only) with all
# platform GDExtension binaries — the format Godot AssetLib expects.
#
# Usage:
#   bash scripts/build_asset_library_zip.sh              # reads VERSION file
#   bash scripts/build_asset_library_zip.sh 5.3.0-Beta5
#
# Output:
#   release/v<version>/VisualGasic_AssetLibrary_v<version>.zip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
OUT_DIR="release/v${VERSION}"
STAGING="$OUT_DIR/assetlib_staging"
ZIP_NAME="VisualGasic_AssetLibrary_v${VERSION}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }

if [[ ! -d addons/visual_gasic ]]; then
    echo "addons/visual_gasic not found — run from repo root." >&2
    exit 1
fi

# Ensure non-dev Linux/Windows binaries exist (reuse build_release output if needed).
if [[ ! -f addons/visual_gasic/bin/libvisualgasic.linux.template_debug.x86_64.so ]]; then
    warn "Linux binaries missing — run: bash scripts/build_release.sh ${VERSION}"
    exit 1
fi

info "Building Asset Library zip ${ZIP_NAME}"

rm -rf "$STAGING"
mkdir -p "$STAGING/addons"
# -L dereferences bin/ symlink so GDExtension binaries are included in the zip.
cp -aL addons/visual_gasic "$STAGING/addons/"

# Asset Library: addon only — strip dev/incomplete pieces.
rm -rf "$STAGING/addons/visual_gasic/plugins/_disabled.gdsfx" 2>/dev/null || true
find "$STAGING" -type f \( -name '*.dev.*' -o -name '*.os' -o -name '*.o' \) -delete 2>/dev/null || true
find "$STAGING" -name '*.uid' -delete 2>/dev/null || true
find "$STAGING" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find "$STAGING" -name '.DS_Store' -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"
(
    cd "$STAGING"
    zip -qr "$PROJECT_ROOT/$ZIP_PATH" addons
)
rm -rf "$STAGING"

success "Asset Library zip: $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"
sha256sum "$ZIP_PATH" > "${ZIP_PATH}.sha256"
info "Checksum: ${ZIP_PATH}.sha256"

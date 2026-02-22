#!/bin/bash
# ============================================================================
# Sync addons/visual_gasic/ copies from the canonical demo/addons/visual_gasic/
# ============================================================================
# The demo/ project is the development copy — always edit there first.
# This script propagates changes to the distribution copies.
# Usage: ./scripts/sync_addons.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$ROOT/demo/addons/visual_gasic"
TARGETS=(
    "$ROOT/addons/visual_gasic"
    "$ROOT/package/addons/visual_gasic"
)

if [ ! -d "$SRC" ]; then
    echo "ERROR: Canonical source not found at $SRC"
    exit 1
fi

for dest in "${TARGETS[@]}"; do
    if [ ! -d "$dest" ]; then
        echo "SKIP: $dest does not exist"
        continue
    fi
    echo "Syncing → $(realpath --relative-to="$ROOT" "$dest")"
    rsync -a --delete \
        --exclude='bin/' \
        --exclude='.godot/' \
        --exclude='*.import' \
        --exclude='*.uid' \
        "$SRC/" "$dest/"
    echo "  ✓ done"
done

echo ""
echo "All addons copies synced from demo/addons/visual_gasic/"

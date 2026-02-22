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

# GDScript sync targets — every addon copy in the repo
TARGETS=(
    "$ROOT/addons/visual_gasic"
    "$ROOT/package/addons/visual_gasic"
)

# Auto-discover game_projects that have addon copies
for gp in "$ROOT"/game_projects/*/addons/visual_gasic; do
    [ -d "$gp" ] && TARGETS+=("$gp")
done

if [ ! -d "$SRC" ]; then
    echo "ERROR: Canonical source not found at $SRC"
    exit 1
fi

# --- Step 1: Sync GDScript / config files (bin/ lives separately) -----------
echo "=== Syncing GDScript files ==="
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

# --- Step 2: Sync compiled binaries -----------------------------------------
# The canonical built binaries live in addons/visual_gasic/bin/ (copied there
# after scons builds into demo/bin/).  Propagate them to every other addon copy
# that has its own bin/ directory.
BIN_SRC="$ROOT/addons/visual_gasic/bin"
if [ -d "$BIN_SRC" ]; then
    echo ""
    echo "=== Syncing compiled binaries ==="
    for dest in "${TARGETS[@]}"; do
        dest_bin="$dest/bin"
        # Skip the source itself
        [ "$dest_bin" = "$BIN_SRC" ] && continue
        if [ -d "$dest_bin" ]; then
            echo "Binaries → $(realpath --relative-to="$ROOT" "$dest_bin")"
            rsync -a --delete "$BIN_SRC/" "$dest_bin/"
            echo "  ✓ done"
        fi
    done
else
    echo ""
    echo "WARNING: No canonical binaries found at $BIN_SRC — skipping binary sync"
    echo "         (run 'scons platform=linux' first, then copy output to $BIN_SRC)"
fi

echo ""
echo "All addons copies synced from demo/addons/visual_gasic/"

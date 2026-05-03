#!/usr/bin/env bash
# Sync the canonical VisualGasic addon into one or more existing
# project directories. Useful for projects created before today's
# update that have a stale `addons/visual_gasic/` copy.
#
# Usage: scripts/sync_addon.sh <project_dir> [<project_dir> ...]
#        scripts/sync_addon.sh --all   # sync every recent project
set -e

VG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$VG_ROOT/addons/visual_gasic"

if [[ ! -f "$SRC/plugin.cfg" ]]; then
    echo "ERROR: canonical addon not found at $SRC" >&2
    exit 1
fi

sync_one() {
    local target="$1"
    if [[ ! -f "$target/project.godot" ]]; then
        echo "skip (no project.godot): $target"
        return
    fi
    mkdir -p "$target/addons"
    rsync -a --delete "$SRC/" "$target/addons/visual_gasic/"
    echo "synced -> $target"
}

if [[ "$1" == "--all" ]]; then
    cfg="$HOME/.config/visual_gasic/recent_projects.cfg"
    [[ -f "$cfg" ]] || { echo "no recent list at $cfg"; exit 1; }
    awk -F\" '/"path"/ {print $4}' "$cfg" | while read -r p; do
        [[ -n "$p" ]] && sync_one "$p"
    done
    exit 0
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <project_dir> [<project_dir> ...]" >&2
    echo "       $0 --all" >&2
    exit 2
fi

for d in "$@"; do
    sync_one "$d"
done

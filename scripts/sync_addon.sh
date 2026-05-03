#!/usr/bin/env bash
# Sync the canonical VisualGasic addon into one or more existing
# project directories. Useful for projects created before today's
# update that have a stale `addons/visual_gasic/` copy.
#
# Usage: scripts/sync_addon.sh <project_dir> [<project_dir> ...]
#        scripts/sync_addon.sh --all   # sync every recent project
set -u  # NOTE: not -e — rsync may exit 24 on harmless "vanished" races.

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
    local target_abs
    target_abs="$(cd "$target" && pwd)"
    # Refuse to sync the canonical repo itself, or any project nested
    # inside it (game_projects/, demo/, etc.) — the canonical addon's
    # `bin/` is a symlink to <repo>/bin and rsync -L --delete on a
    # nested target dereferences and clobbers the source symlink.
    if [[ "$target_abs" == "$VG_ROOT" || "$target_abs" == "$VG_ROOT"/* ]]; then
        echo "skip (inside repo, would clobber canonical bin symlink): $target"
        return
    fi
    mkdir -p "$target/addons"
    local target_addon="$target/addons/visual_gasic"
    # Drop a stale `bin` symlink in the target so rsync -L can write
    # the real .so/.dll files into a fresh directory.
    if [[ -L "$target_addon/bin" ]]; then
        rm -f "$target_addon/bin"
    fi
    # -L: dereference symlinks (the canonical addon's `bin/` is a symlink
    # to <repo>/bin; we need real binaries copied into each project).
    # Exit 24 ("some files vanished") is treated as non-fatal.
    rsync -aL --delete "$SRC/" "$target_addon/" || {
        local rc=$?
        if [[ $rc -ne 24 ]]; then
            echo "rsync failed ($rc) for $target" >&2
            return $rc
        fi
    }
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

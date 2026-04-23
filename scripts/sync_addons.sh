#!/usr/bin/env bash
# sync_addons.sh — single source of truth for the VisualGasic addon.
#
# Canonical:  <repo>/addons/visual_gasic
# Strategy:   Replace duplicated copies inside Godot projects with relative
#             symlinks pointing at the canonical, so edits propagate instantly
#             and drift becomes impossible.
#
# Commands:
#   status    List every live copy and its state (link | copy-in-sync | drift).
#   check     Exit 1 if any live copy differs from canonical (CI-friendly).
#   convert   Replace real-dir copies with relative symlinks. Skips copies with
#             local modifications unless --force is supplied.
#   restore   Replace symlinks with real-dir copies (e.g. before packaging).
#
# Options:
#   --dry-run         Print actions without modifying anything.
#   --force           During `convert`, overwrite locally-modified copies.
#   --include <path>  Add an extra project root to scan (repeatable).
#
# Excluded by design (these must keep real copies):
#   release/, releases/        — frozen release archives
#   vbnet_*_backup/            — legacy backups
#   package/                   — packaging staging area (must be self-contained)
#
# Typical workflow:
#   scripts/sync_addons.sh status           # see what needs attention
#   scripts/sync_addons.sh convert --dry-run
#   scripts/sync_addons.sh convert          # replace copies with symlinks
#   scripts/sync_addons.sh check            # run in CI

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$REPO_ROOT/addons/visual_gasic"

DRY_RUN=0
FORCE=0
EXTRA_INCLUDES=()

EXCLUDE_PREFIXES=(
    "$REPO_ROOT/release/"
    "$REPO_ROOT/releases/"
    "$REPO_ROOT/vbnet_examples_backup/"
    "$REPO_ROOT/vbnet_samples_backup/"
    "$REPO_ROOT/package/"
)

if [ -t 1 ]; then
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
    C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_OFF=""
fi

die() { printf "%serror:%s %s\n" "$C_RED" "$C_OFF" "$*" >&2; exit 2; }

is_excluded() {
    local path="$1" prefix
    for prefix in "${EXCLUDE_PREFIXES[@]}"; do
        case "$path" in "$prefix"*) return 0 ;; esac
    done
    return 1
}

# Stable sha256 over the contents of a directory tree. Ignores generated files
# (.uid, .import, .godot/) so Godot-regenerated metadata does not register as
# drift between copies.
tree_hash() {
    local dir="$1"
    (cd "$dir" && find . -type f \
            ! -name "*.uid" ! -name "*.import" \
            ! -path "./.godot/*" ! -path "./bin/*" \
            -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 sha256sum 2>/dev/null \
        | sha256sum | awk '{print $1}')
}

# Emit every live copy path (one per line).  A live copy is any
# */addons/visual_gasic that has a sibling project.godot and is not excluded.
find_copies() {
    local roots=(
        "$REPO_ROOT/demo"
        "$REPO_ROOT/demos"
        "$REPO_ROOT/examples"
        "$REPO_ROOT/game_projects"
        "$REPO_ROOT/test_proj"
    )
    local extra
    for extra in "${EXTRA_INCLUDES[@]}"; do roots+=("$extra"); done

    local root addon proj_root
    for root in "${roots[@]}"; do
        [ -d "$root" ] || continue
        # Match both real directories and symlinks named visual_gasic so that
        # already-converted copies remain visible to status/check.
        while IFS= read -r -d '' addon; do
            proj_root="$(dirname "$(dirname "$addon")")"
            [ -f "$proj_root/project.godot" ] || continue
            is_excluded "$addon" && continue
            [ "$addon" = "$CANONICAL" ] && continue
            printf "%s\n" "$addon"
        done < <(find "$root" \( -type d -o -type l \) -name "visual_gasic" -path "*/addons/visual_gasic" -print0 2>/dev/null)
    done
}

rel_link_target() {
    # Relative path from the link's parent dir to the canonical addon.
    realpath --relative-to="$(dirname "$1")" "$CANONICAL"
}

cmd_status() {
    local canonical_hash
    canonical_hash="$(tree_hash "$CANONICAL")"
    printf "%sCanonical:%s %s\n" "$C_BOLD" "$C_OFF" "$CANONICAL"
    printf "Hash:      %s\n\n" "$canonical_hash"
    printf "%-18s  %s\n" "STATE" "PATH"
    printf "%-18s  %s\n" "------------------" "----"
    local copy
    while IFS= read -r copy; do
        [ -z "$copy" ] && continue
        local rel="${copy#$REPO_ROOT/}"
        if [ -L "$copy" ]; then
            local target resolved
            target="$(readlink "$copy")"
            resolved="$(readlink -f "$copy" || true)"
            if [ "$resolved" = "$(readlink -f "$CANONICAL")" ]; then
                printf "%sLINK%s                %s -> %s\n" "$C_GREEN" "$C_OFF" "$rel" "$target"
            else
                printf "%sLINK?%s               %s -> %s (foreign target)\n" "$C_YELLOW" "$C_OFF" "$rel" "$target"
            fi
        elif [ -d "$copy" ]; then
            local h
            h="$(tree_hash "$copy")"
            if [ "$h" = "$canonical_hash" ]; then
                printf "%sCOPY (in sync)%s      %s\n" "$C_YELLOW" "$C_OFF" "$rel"
            else
                printf "%sDRIFT%s               %s\n" "$C_RED" "$C_OFF" "$rel"
            fi
        fi
    done < <(find_copies)
}

cmd_check() {
    local canonical_hash rc=0 links=0 copies=0 drifted=0
    canonical_hash="$(tree_hash "$CANONICAL")"
    local copy h resolved
    while IFS= read -r copy; do
        [ -z "$copy" ] && continue
        if [ -L "$copy" ]; then
            resolved="$(readlink -f "$copy" || true)"
            if [ "$resolved" = "$(readlink -f "$CANONICAL")" ]; then
                links=$((links+1))
            else
                printf "%sforeign symlink:%s %s\n" "$C_RED" "$C_OFF" "${copy#$REPO_ROOT/}"
                rc=1
            fi
        else
            h="$(tree_hash "$copy")"
            if [ "$h" = "$canonical_hash" ]; then
                copies=$((copies+1))
            else
                printf "%sdrift:%s %s\n" "$C_RED" "$C_OFF" "${copy#$REPO_ROOT/}"
                drifted=$((drifted+1))
                rc=1
            fi
        fi
    done < <(find_copies)
    echo
    printf "canonical hash: %s\n" "$canonical_hash"
    printf "symlinks OK:    %s\n" "$links"
    printf "copies OK:      %s\n" "$copies"
    printf "drifted:        %s\n" "$drifted"
    exit $rc
}

convert_one() {
    local copy="$1" canonical_hash="$2"
    [ -L "$copy" ] && return 0
    local h
    h="$(tree_hash "$copy")"
    if [ "$h" != "$canonical_hash" ] && [ "$FORCE" -ne 1 ]; then
        printf "%sskip (drift):%s %s — reconcile first, or re-run with --force\n" \
            "$C_YELLOW" "$C_OFF" "${copy#$REPO_ROOT/}"
        return 1
    fi
    local target
    target="$(rel_link_target "$copy")"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "%swould link:%s %s -> %s\n" "$C_GREEN" "$C_OFF" "${copy#$REPO_ROOT/}" "$target"
        return 0
    fi
    rm -rf "$copy"
    ln -s "$target" "$copy"
    printf "%slinked:%s %s -> %s\n" "$C_GREEN" "$C_OFF" "${copy#$REPO_ROOT/}" "$target"
}

cmd_convert() {
    local canonical_hash copy
    canonical_hash="$(tree_hash "$CANONICAL")"
    while IFS= read -r copy; do
        [ -z "$copy" ] && continue
        convert_one "$copy" "$canonical_hash" || true
    done < <(find_copies)
}

cmd_restore() {
    local copy resolved
    while IFS= read -r copy; do
        [ -z "$copy" ] && continue
        [ -L "$copy" ] || continue
        resolved="$(readlink -f "$copy" || true)"
        if [ "$resolved" != "$(readlink -f "$CANONICAL")" ]; then
            printf "%sskip (not canonical):%s %s\n" "$C_YELLOW" "$C_OFF" "${copy#$REPO_ROOT/}"
            continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            printf "%swould restore:%s %s\n" "$C_GREEN" "$C_OFF" "${copy#$REPO_ROOT/}"
            continue
        fi
        rm "$copy"
        cp -a "$CANONICAL" "$copy"
        printf "%srestored:%s %s\n" "$C_GREEN" "$C_OFF" "${copy#$REPO_ROOT/}"
    done < <(find_copies)
}

usage() {
    sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'
}

main() {
    local cmd=""
    while [ $# -gt 0 ]; do
        case "$1" in
            status|check|convert|restore) cmd="$1"; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            --force)   FORCE=1;   shift ;;
            --include) EXTRA_INCLUDES+=("$2"); shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -d "$CANONICAL" ] || die "canonical addon missing: $CANONICAL"
    case "$cmd" in
        status)  cmd_status ;;
        check)   cmd_check ;;
        convert) cmd_convert ;;
        restore) cmd_restore ;;
        "")      usage; exit 1 ;;
    esac
}

main "$@"

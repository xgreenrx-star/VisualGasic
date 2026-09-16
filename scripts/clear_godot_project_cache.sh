#!/usr/bin/env bash
# Delete a Godot project's .godot cache so the next editor launch rebuilds imports.
# Safe for VG projects when startup hangs at "Scanning actions..." or after addon rebuilds.
#
# Usage:
#   scripts/clear_godot_project_cache.sh samples/games/brotato_vg
#   scripts/clear_godot_project_cache.sh /path/to/project
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"

if [[ -z "$PROJECT" ]]; then
	echo "Usage: scripts/clear_godot_project_cache.sh <project_dir>" >&2
	exit 2
fi

if [[ ! -f "$PROJECT/project.godot" && -f "$ROOT/$PROJECT/project.godot" ]]; then
	PROJECT="$ROOT/$PROJECT"
fi

if [[ ! -f "$PROJECT/project.godot" ]]; then
	echo "ERROR: no project.godot in $PROJECT" >&2
	exit 2
fi

CACHE="$PROJECT/.godot"
if [[ ! -e "$CACHE" ]]; then
	echo "No .godot cache at $CACHE — nothing to clear."
	exit 0
fi

echo "Removing $CACHE"
rm -rf "$CACHE"
echo "Done. Reopen the project normally (not Recovery mode). First launch reimports assets."

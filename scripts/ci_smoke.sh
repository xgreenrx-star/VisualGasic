#!/usr/bin/env bash
# ci_smoke.sh — Headless parse smoke test across canonical projects.
#
# Boots Godot --headless --quit --editor against test_proj and (optionally)
# every demo / example / game_project listed in PROJECTS, scrapes stderr
# for Parse Errors and SCRIPT ERRORs, and exits non-zero if any are seen.
#
# Usage:
#   scripts/ci_smoke.sh                  # quick: just test_proj
#   scripts/ci_smoke.sh --all            # exhaustive: every project.godot under demo*/, examples/, game_projects/
#   scripts/ci_smoke.sh path/to/proj ... # specific projects
#
# Exit codes:
#   0  no errors
#   1  one or more projects reported parse / script errors
#   2  godot binary missing
#
# Noise filters (kept in sync with the manual command we've been running):
#   - "Binding duplicate"   - benign Godot/cpp double-binds at editor boot
#   - "preset.0.options"    - unused export-preset metadata warnings

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	echo "  (override with GODOT=/path/to/godot scripts/ci_smoke.sh)" >&2
	exit 2
fi

# Build project list.
projects=()
case "${1:-}" in
	--all)
		while IFS= read -r -d '' f; do
			projects+=("$(dirname "$f")")
		done < <(find "$ROOT/test_proj" "$ROOT/demo" "$ROOT/demos" "$ROOT/examples" "$ROOT/game_projects" \
			-maxdepth 4 -name project.godot -print0 2>/dev/null)
		;;
	"" )
		projects=("$ROOT/test_proj")
		;;
	* )
		for arg in "$@"; do
			if [[ -f "$arg/project.godot" ]]; then
				projects+=("$arg")
			elif [[ -f "$arg" ]]; then
				projects+=("$(dirname "$arg")")
			else
				echo "Skipping (no project.godot): $arg" >&2
			fi
		done
		;;
esac

if [[ ${#projects[@]} -eq 0 ]]; then
	echo "No projects to check." >&2
	exit 0
fi

failed=()
for proj in "${projects[@]}"; do
	rel="${proj#$ROOT/}"
	echo "── $rel ──"
	# 30s wall-clock cap per project. --quit makes the editor exit on first idle.
	output="$(cd "$proj" && timeout 30 "$GODOT" --headless --quit --editor 2>&1 || true)"
	errs="$(echo "$output" \
		| grep -E 'Parse Error|SCRIPT ERROR' \
		| grep -v 'Binding duplicate' \
		| grep -v 'preset.0.options' \
		|| true)"
	if [[ -n "$errs" ]]; then
		echo "$errs" | sed 's/^/  /'
		failed+=("$rel")
	else
		echo "  ok"
	fi
done

echo
if [[ ${#failed[@]} -gt 0 ]]; then
	echo "FAILED (${#failed[@]}):"
	printf '  %s\n' "${failed[@]}"
	exit 1
fi
echo "All ${#projects[@]} project(s) clean."
exit 0

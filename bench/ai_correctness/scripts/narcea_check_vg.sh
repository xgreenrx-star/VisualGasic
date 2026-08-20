#!/usr/bin/env bash
# Bridge Narcea harness VG paths to bench/ai_correctness check_vg.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
VG_FILE="${1:-}"
if [[ -z "$VG_FILE" || ! -f "$VG_FILE" ]]; then
	echo "Usage: $0 /path/to/file.vg" >&2
	exit 2
fi
export GODOT_BIN="${GODOT_BIN:-$REPO/Godot_v4.6.1-stable_linux.x86_64}"
exec bash "$REPO/bench/ai_correctness/checkers/check_vg.sh" "$VG_FILE"

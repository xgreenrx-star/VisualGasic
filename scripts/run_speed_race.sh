#!/bin/bash
# Launch the VG vs GD speed race WITHOUT the editor script debugger.
# (Opening the project in Godot and pressing F5 attaches the debugger and
#  can make .vg look much slower. This path is the fair demo.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
exec "$G" --path "$ROOT/samples/apps/vg_speed_race" "$@"

#!/usr/bin/env bash
# Explicit CP3 IR hand-example GODOT lane (bounded; not part of pure selftest).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GODOT:-}" || ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must be set" >&2
	exit 1
fi

OUT="${SEM_C2_IR_OUT:-${RUNNER_TEMP:-/tmp}/vg-semantic-c2-ir-lane}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "fail" >"$OUT/gate_status.txt"

unset VG_FORCE_AST VG_JIT VG_JIT_LOG || true

echo "==> semantic C2 IR example lane"
echo "    GODOT=$GODOT"
echo "    OUT=$OUT"

set +e
python3 -m tools.semantic_fuzz c2-ir-lane --out "$OUT"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
	echo "ERROR: C2 IR lane failed (exit $rc) — see $OUT/ir_lane_report.json" >&2
	echo "fail" >"$OUT/gate_status.txt"
	exit "$rc"
fi

st="$(cat "$OUT/gate_status.txt")"
if [[ "$st" != "ok" && "$st" != "ok_with_known_defects" ]]; then
	echo "ERROR: C2 IR lane gate_status=$st" >&2
	exit 1
fi

echo "==> semantic C2 IR lane PASSED ($st) (see $OUT/ir_lane_report.json)"

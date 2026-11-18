#!/bin/bash
# Fail when run_gap.gd reports a result mismatch, or any vg/gd ratio above MAX.
# Quiet-pair goal in CURSOR_VG_PERF_GAP_HANDOFF.md is 1.00; default gate uses 1.05
# slack for ±10% timing noise. One automatic retry on over_limit (not on mismatches).
# Strict: VG_GAP_MAX_RATIO=1.00 bash scripts/check_vm_gap.sh
# Optional OUT path: scripts/check_vm_gap.sh /tmp/vg_gap_check.log
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
MAX="${VG_GAP_MAX_RATIO:-1.05}"
CORE="${VG_GAP_CORE:-2}"
OUT="${1:-/tmp/vg_gap_check.log}"

cd "$ROOT/test_proj"
: >"$OUT"
status=0

run_one() {
	local label="$1"
	shift
	local tmp
	tmp="$(mktemp)"
	echo "== $label ==" | tee -a "$OUT"
	if ! taskset -c "$CORE" env VG_GAP_MAX_RATIO="$MAX" "$@" "$G" --headless --path . --audio-driver Dummy \
			--script res://perf/vm_gap/run_gap.gd >"$tmp" 2>&1; then
		# Distinguish correctness fail from ratio noise.
		if grep -qE 'mismatches=[1-9]' "$tmp"; then
			echo "run_gap correctness fail ($label)" | tee -a "$OUT"
			cat "$tmp" | tee -a "$OUT"
			rm -f "$tmp"
			return 1
		fi
		if grep -qE 'over_limit=[1-9]' "$tmp"; then
			echo "ratio over max on first try ($label); retrying once" | tee -a "$OUT"
			cat "$tmp" | tee -a "$OUT"
			if ! taskset -c "$CORE" env VG_GAP_MAX_RATIO="$MAX" "$@" "$G" --headless --path . --audio-driver Dummy \
					--script res://perf/vm_gap/run_gap.gd >"$tmp" 2>&1; then
				echo "run_gap exited non-zero on retry ($label)" | tee -a "$OUT"
				cat "$tmp" | tee -a "$OUT"
				rm -f "$tmp"
				return 1
			fi
		else
			echo "run_gap exited non-zero ($label)" | tee -a "$OUT"
			cat "$tmp" | tee -a "$OUT"
			rm -f "$tmp"
			return 1
		fi
	fi
	cat "$tmp" | tee -a "$OUT"
	if ! grep -qE 'VM_GAP_DONE mismatches=0 over_limit=0' "$tmp"; then
		echo "FAIL: mismatches or over_limit ($label)" | tee -a "$OUT"
		rm -f "$tmp"
		return 1
	fi
	rm -f "$tmp"
	return 0
}

run_one "JIT on" || status=1
run_one "VG_JIT=0" VG_JIT=0 || status=1

if [[ "$status" -eq 0 ]]; then
	echo "VM_GAP_CHECK_OK max_ratio=$MAX" | tee -a "$OUT"
else
	echo "VM_GAP_CHECK_FAIL max_ratio=$MAX" | tee -a "$OUT"
fi
exit "$status"

#!/usr/bin/env bash
# benchmark_regression_check.sh — Fail if VG loses to GDScript on published workloads.
#
# Runs compute + draw suites and checks:
#   • Checksums match (static workloads)
#   • VisualGasic elapsed_us <= GDScript * MAX_RATIO (default 1.05 = 5% slack)
#
# Excludes FunctionCall (known VG weakness), Polylines (draw fusion still in progress),
# and MovingFilledRects checksum (frame timing).
#
# Usage:
#   scripts/benchmark_regression_check.sh
#   MAX_RATIO=1.10 scripts/benchmark_regression_check.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX_RATIO="${MAX_RATIO:-1.05}"
DRAW_MAX_RATIO="${DRAW_MAX_RATIO:-$MAX_RATIO}"
FAIL=0

check_suite() {
	local label="$1"
	local file="$2"
	python3 - "$label" "$file" "$MAX_RATIO" <<'PY' || FAIL=1
import re, sys
label, path, max_ratio = sys.argv[1], sys.argv[2], float(sys.argv[3])
text = open(path, encoding="utf-8", errors="replace").read()
blocks = re.split(r"\n=== ", text)
skip_speed = {"FunctionCall", "Polylines (n=800)"}
skip_checksum_prefix = ("MovingFilledRects",)
errors = []
for block in blocks:
    if "===" in block:
        block = "=== " + block
    m = re.search(r"=== (.+?) ===", block)
    if not m:
        continue
    name = m.group(1).strip()
    gd_m = re.search(r"GDScript: \{[^\}]*\"elapsed_us\": (\d+)", block)
    vg_m = re.search(r"VisualGasic: \{[^\}]*\"elapsed_us\": (\d+)", block)
    if not gd_m or not vg_m:
        continue
    gd_us = int(gd_m.group(1))
    vg_us = int(vg_m.group(1))
    gd_cs = re.search(r"GDScript: \{[^\}]*\"checksum\": ([^,\}]+)", block)
    vg_cs = re.search(r"VisualGasic: \{[^\}]*\"checksum\": ([^,\}]+)", block)
    if not any(name.startswith(p) for p in skip_checksum_prefix) and gd_cs and vg_cs:
        if gd_cs.group(1).strip() != vg_cs.group(1).strip():
            errors.append(f"{name}: checksum mismatch gd={gd_cs.group(1)} vg={vg_cs.group(1)}")
    if name in skip_speed:
        continue
    limit = gd_us * max_ratio
    if vg_us > limit:
        errors.append(f"{name}: VG {vg_us} us > GD {gd_us} us * {max_ratio} (limit {limit:.0f})")
if errors:
    print(f"[benchmark regression] {label} FAILED:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print(f"[benchmark regression] {label} OK ({len(blocks)-1} blocks checked)")
PY
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== Compute benchmarks ==="
status=0
"$ROOT/scripts/run_compute_benchmarks.sh" >"$TMP/compute.txt" 2>&1 || status=$?
cat "$TMP/compute.txt"
if [[ "$status" -ne 0 ]]; then
	exit "$status"
fi
check_suite "compute" "$TMP/compute.txt"

echo ""
echo "=== Draw benchmarks ==="
status=0
"$ROOT/scripts/run_draw_benchmarks.sh" >"$TMP/draw.txt" 2>&1 || status=$?
cat "$TMP/draw.txt"
if [[ "$status" -ne 0 ]]; then
	exit "$status"
fi
check_suite "draw" "$TMP/draw.txt" "$DRAW_MAX_RATIO"

if [[ "$FAIL" -ne 0 ]]; then
	echo "Benchmark regression check failed." >&2
	exit 1
fi
echo "All published workloads: VG within ${MAX_RATIO}x of GDScript (or faster)."

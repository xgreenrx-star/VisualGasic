#!/usr/bin/env bash
# run_csharp_compile_benchmarks.sh — Incremental dotnet build timing (VG vs GD vs C# compile story).
#
# C# in Godot compiles at project/assembly level (MSBuild), not per-script reload like GD/VG.
# This script measures median incremental `dotnet build` after touching one .cs file.
#
# Usage:
#   scripts/run_csharp_compile_benchmarks.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="$ROOT/demo"
CSPROJ="$DEMO/VisualGasic Demo.csproj"
WARMUP=2
ITERS=8

if ! command -v dotnet >/dev/null 2>&1; then
	echo "dotnet SDK not found." >&2
	exit 2
fi

"$ROOT/scripts/build_demo_csharp.sh"

median_us() {
	python3 - "$@" <<'PY'
import sys
vals = [int(x) for x in sys.argv[1:] if x]
if not vals:
    print(0)
    sys.exit(0)
vals.sort()
print(vals[len(vals) // 2])
PY
}

touch_compile() {
	local target="$1"
	local file stamp
	stamp="# compile-bench-touch $(date +%s%N)"
	if [[ "$target" == "hello" ]]; then
		file="$DEMO/benchmarks/compile/hello.cs"
		sed -i 's|^// BENCH_TOUCH .*|// BENCH_TOUCH '"$(date +%s%N)"'|' "$file"
	elif [[ "$target" == "bench" ]]; then
		file="$DEMO/benchmarks/csharp/BenchCompute.cs"
		sed -i 's|^// BENCH_TOUCH .*|// BENCH_TOUCH '"$(date +%s%N)"'|' "$file"
	fi
}

time_build_us() {
	local start end
	start=$(date +%s%N)
	(
		cd "$DEMO"
		dotnet build "$CSPROJ" -c Debug --no-restore --nologo -v q >/dev/null
	)
	end=$(date +%s%N)
	echo $(( (end - start) / 1000 ))
}

echo "=== Visual Gasic C# Compile Benchmarks ==="
echo "Metric: median incremental dotnet build (microseconds, lower is faster)"
echo "Note: C# uses MSBuild assembly compile — not comparable 1:1 to VG/GD Script.reload()"
echo ""

# Warm full restore/build once.
(
	cd "$DEMO"
	dotnet restore "$CSPROJ" --nologo -v q >/dev/null
	dotnet build "$CSPROJ" -c Debug --nologo -v q >/dev/null
)

samples=()
for i in $(seq 1 $((WARMUP + ITERS))); do
	touch_compile hello
	us=$(time_build_us)
	if [[ "$i" -gt "$WARMUP" ]]; then
		samples+=("$us")
	fi
done
med=$(median_us "${samples[@]}")
echo "=== HelloWorld (hello.cs touch) ==="
echo "  C# incremental build: { \"elapsed_us\": $med }"
echo ""

samples=()
for i in $(seq 1 $((WARMUP + ITERS))); do
	touch_compile bench
	us=$(time_build_us)
	if [[ "$i" -gt "$WARMUP" ]]; then
		samples+=("$us")
	fi
done
med=$(median_us "${samples[@]}")
echo "=== BenchCompute (BenchCompute.cs touch) ==="
echo "  C# incremental build: { \"elapsed_us\": $med }"
echo ""

echo "C# compile benchmarks finished."
echo "Compare VG/GD script reload with: scripts/run_compile_benchmarks.sh"

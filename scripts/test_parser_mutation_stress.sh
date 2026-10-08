#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vg-mutation-checks-XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
cat > "$WORK/fake-godot" <<'ENGINE'
#!/usr/bin/env bash
if [[ "$*" == *test_arr_simple.vg* ]]; then
	if [[ "$VG_FAKE_CASE" == baseline ]]; then exit 0; fi
	echo 'PASS: baseline'
	echo VG_SUITE_COMPLETED
	exit 0
fi
case "$VG_FAKE_CASE" in
	rejection) echo 'Parser Error: expected End If' ;;
	incomplete) exit 0 ;;
	nonzero) echo VG_SUITE_COMPLETED; exit 3 ;;
	crash) echo 'handle_crash: Program crashed with signal 11'; exit 0 ;;
	timeout) sleep 3 ;;
esac
echo VG_SUITE_COMPLETED
ENGINE
chmod +x "$WORK/fake-godot"
CHECKS=0
check() {
	local name="$1" scenario="$2" expected="$3"
	shift 3
	local rc=0
	VG_FAKE_CASE="$scenario" GODOT="$WORK/fake-godot" \
		OUT_DIR="$WORK/$name" MUTATION_TIMEOUT=1 \
		bash "$ROOT/scripts/run_parser_mutation_stress.sh" "$@" \
		> "$WORK/$name.log" 2>&1 || rc=$?
	if [[ "$expected" == pass && "$rc" -ne 0 ]] ||
			[[ "$expected" == fail && "$rc" -eq 0 ]]; then
		echo "FAIL: $name (exit=$rc)" >&2
		cat "$WORK/$name.log" >&2
		exit 1
	fi
	echo "PASS: $name"
	CHECKS=$((CHECKS + 1))
}
check complete success pass 2 42
check repeat success pass 2 42
cmp "$WORK/complete/manifest.tsv" "$WORK/repeat/manifest.tsv"
cmp "$WORK/complete/mutant_000.vg" "$WORK/repeat/mutant_000.vg"
cmp "$WORK/complete/mutant_001.vg" "$WORK/repeat/mutant_001.vg"
echo "PASS: deterministic generated sources and manifest"
CHECKS=$((CHECKS + 1))
check parser-rejection rejection pass 2 42
check missing-completion incomplete fail 2 42
check engine-error nonzero fail 2 42
check crash-diagnostic crash fail 2 42
check hang timeout fail 1 42
check missing-baseline baseline fail 2 42
check empty-count success fail 0 42
check invalid-seed success fail 2 invalid
check reused-output success pass 1 42
rc=0
VG_FAKE_CASE=success GODOT="$WORK/fake-godot" OUT_DIR="$WORK/reused-output" \
	bash "$ROOT/scripts/run_parser_mutation_stress.sh" 1 42 \
	> "$WORK/reuse.log" 2>&1 || rc=$?
if [[ "$rc" -eq 0 ]]; then
	echo "FAIL: reused output directory was accepted" >&2
	exit 1
fi
echo "PASS: output reuse rejected"
CHECKS=$((CHECKS + 1))
echo "Mutation harness self-tests: $CHECKS passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != Linux ]]; then
	echo "ERROR: this hardening runner currently validates Linux only" >&2
	exit 1
fi
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
export GODOT
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-release-hardening-XXXXXX")}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
if [[ -e "$OUT_DIR/provenance.txt" ]]; then
	echo "ERROR: use a fresh OUT_DIR; provenance already exists" >&2
	exit 1
fi
{
	printf 'commit: %s\n' "$(git rev-parse HEAD)"
	printf 'utc: %s\n' "$(date -u +%FT%TZ)"
	printf 'engine: %s\n' "$GODOT"
	"$GODOT" --version
	printf '\nworking-tree:\n'
	git status --porcelain
	printf '\nsha256:\n'
	sha256sum "$GODOT" \
		addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so \
		addons/visual_gasic/bin/libvisualgasic.linux.template_debug.x86_64.so
} > "$OUT_DIR/provenance.txt"

FAILED=0
PASSED=0
run_gate() {
	local name="$1"
	shift
	local rc=0
	echo "RUN: $name"
	"$@" > "$OUT_DIR/$name.log" 2>&1 || rc=$?
	if [[ "$rc" -eq 0 ]]; then
		PASSED=$((PASSED + 1))
		printf 'PASS\t%s\n' "$name" >> "$OUT_DIR/results.tsv"
		echo "PASS: $name"
	else
		FAILED=$((FAILED + 1))
		printf 'FAIL\t%s\t%s\n' "$name" "$rc" >> "$OUT_DIR/results.tsv"
		echo "FAIL: $name (exit=$rc)"
		tail -n 20 "$OUT_DIR/$name.log"
	fi
}

# Suite fixtures share fixed filesystem paths, and the editor uses a fixed MCP
# port. Do not parallelize these gates or run another suite against this checkout.
run_gate mutation-harness bash scripts/test_parser_mutation_stress.sh
run_gate headless-errors env OUT_DIR="$OUT_DIR/headless-errors" \
	bash scripts/run_headless_error_regression.sh
run_gate differential env -u VG_FORCE_AST OUT_DIR="$OUT_DIR/differential" \
	bash scripts/run_ast_bytecode_diff.sh --all
run_gate corpus-default env -u VG_FORCE_AST bash scripts/audit_corpus.sh
run_gate corpus-ast env VG_FORCE_AST=1 bash scripts/audit_corpus.sh
run_gate mutation-default env -u VG_FORCE_AST OUT_DIR="$OUT_DIR/mutation-default" \
	bash scripts/run_parser_mutation_stress.sh 40 42
run_gate mutation-ast env VG_FORCE_AST=1 OUT_DIR="$OUT_DIR/mutation-ast" \
	bash scripts/run_parser_mutation_stress.sh 40 42
run_gate editor-components env -u VG_FORCE_AST FULL_PLUGIN=0 EXIT_ENABLED=0 \
	RENDER_MODE=headless OUT_DIR="$OUT_DIR/editor-components" \
	bash scripts/run_editor_lifecycle_regression.sh
run_gate editor-full env -u VG_FORCE_AST FULL_PLUGIN=1 EXIT_ENABLED=1 \
	RENDER_MODE=headless OUT_DIR="$OUT_DIR/editor-full" \
	bash scripts/run_editor_lifecycle_regression.sh
run_gate editor-reload env -u VG_FORCE_AST RENDER_MODE=headless \
	OUT_DIR="$OUT_DIR/editor-reload" bash scripts/run_editor_reload_regression.sh

echo "RELEASE-HARDENING RESULTS: $PASSED passed, $FAILED failed"
echo "Evidence: $OUT_DIR"
echo "This is a Linux headless hardening result, not full release certification."
[[ "$FAILED" -eq 0 ]]

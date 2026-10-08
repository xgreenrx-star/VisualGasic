#!/usr/bin/env bash
# Deterministic malformed-source stress. Parse/runtime rejection is acceptable;
# crashes, hangs, missing engine completion and infrastructure failures are not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
COUNT="${1:-40}"
SEED="${2:-42}"
TIMEOUT_SECS="${MUTATION_TIMEOUT:-8}"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
PYTHON="${PYTHON:-python3}"
for value in "$COUNT" "$TIMEOUT_SECS"; do
	if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
		echo "ERROR: count and MUTATION_TIMEOUT must be positive integers" >&2
		exit 1
	fi
done
if [[ ! "$SEED" =~ ^[0-9]+$ || ! -x "$GODOT" ]]; then
	echo "ERROR: seed must be a nonnegative integer and GODOT must be executable" >&2
	exit 1
fi
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-mutation-XXXXXX")}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
if [[ -e "$OUT_DIR/manifest.tsv" ]]; then
	echo "ERROR: use a fresh OUT_DIR; mutation manifest already exists" >&2
	exit 1
fi
DEST_DIR="$(mktemp -d "$ROOT/test_proj/mutation-audit-XXXXXX")"
cleanup() {
	rm -rf -- "$DEST_DIR"
}
trap cleanup EXIT
mkdir -p "$OUT_DIR/user"

smoke_rc=0
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path test_proj \
	--user-data-dir "$OUT_DIR/user" -s run_suite.gd -- res://test_suite/test_arr_simple.vg \
	> "$OUT_DIR/smoke.log" 2>&1 || smoke_rc=$?
if [[ "$smoke_rc" -ne 0 ]] ||
		! grep -q '^PASS:' "$OUT_DIR/smoke.log" ||
		! grep -Fxq VG_SUITE_COMPLETED "$OUT_DIR/smoke.log" ||
		grep -Eq '^FAIL:|^ERROR:|SCRIPT ERROR|Parser Error|VG Runtime Error|handle_crash:' "$OUT_DIR/smoke.log"; then
	echo "FAIL: mutation baseline did not load and complete; see $OUT_DIR/smoke.log" >&2
	exit 1
fi

"$PYTHON" - "$COUNT" "$SEED" "$OUT_DIR" <<'PY'
import pathlib
import random
import re
import sys

count, seed = int(sys.argv[1]), int(sys.argv[2])
out_dir = pathlib.Path(sys.argv[3])
sources = sorted(
    [*pathlib.Path("corpus").rglob("*.vg"),
     *pathlib.Path("test_proj/test_suite").glob("test_*.vg")]
)[:80]
if not sources:
    raise SystemExit("ERROR: no mutation sources found")
rng = random.Random(seed)

def del_line(lines):
    if len(lines) >= 3:
        del lines[rng.randrange(1, len(lines) - 1)]
    return lines

def flip_and_or(lines):
    text = "\n".join(lines)
    if " And " in text:
        text = text.replace(" And ", " Or ", 1)
    elif " Or " in text:
        text = text.replace(" Or ", " And ", 1)
    return text.split("\n")

def extra_if(lines):
    lines.insert(rng.randrange(len(lines)), "If True Then")
    return lines

def swap_brackets(lines):
    text = "\n".join(lines)
    match = re.search(r"(\w+)\((\d+|i|j|k|n|x)\)", text)
    if match:
        text = text[:match.start()] + f"{match[1]}[{match[2]}]" + text[match.end():]
    else:
        match = re.search(r"(\w+)\[(\d+|i|j|k|n|x)\]", text)
        if match:
            text = text[:match.start()] + f"{match[1]}({match[2]})" + text[match.end():]
    return text.split("\n")

def drop_end(lines):
    for index in range(len(lines) - 1, -1, -1):
        if re.match(r"^\s*End\s+(If|Sub|Function|Select|With|Class)\b", lines[index], re.I):
            del lines[index]
            break
    return lines

def dup_line(lines):
    index = rng.randrange(len(lines))
    lines.insert(index, lines[index])
    return lines

ops = [del_line, flip_and_or, extra_if, swap_brackets, drop_end, dup_line]
with (out_dir / "manifest.tsv").open("w") as manifest:
    manifest.write("mutant\tsource\toperation\tseed\n")
    for index in range(count):
        source = rng.choice(sources)
        raw = source.read_text(encoding="utf-8").splitlines() or ["Sub _Ready()", "End Sub"]
        operation = rng.choice(ops)
        body = "\n".join(operation(list(raw)))
        if "Sub " not in body and "Function " not in body:
            body = "Sub _Ready()\n" + body + "\nEnd Sub"
        name = f"mutant_{index:03d}.vg"
        (out_dir / name).write_text(body + "\n", encoding="utf-8")
        manifest.write(f"{name}\t{source}\t{operation.__name__}\t{seed}\n")
PY

OK=0
CRASH=0
TIMED_OUT=0
INCOMPLETE=0
printf 'Mutation stress: engine=%s count=%s seed=%s artifacts=%s\n' "$GODOT" "$COUNT" "$SEED" "$OUT_DIR"
while IFS=$'\t' read -r name source operation seed; do
	[[ "$name" == mutant ]] && continue
	cp "$OUT_DIR/$name" "$DEST_DIR/$name"
	rc=0
	log="$OUT_DIR/$name.log"
	timeout "$TIMEOUT_SECS" "$GODOT" --headless --path test_proj \
		--user-data-dir "$OUT_DIR/user" -s run_suite.gd \
		-- "res://${DEST_DIR#$ROOT/test_proj/}/$name" > "$log" 2>&1 || rc=$?
	if [[ "$rc" -eq 124 ]]; then
		TIMED_OUT=$((TIMED_OUT + 1))
		echo "TIMEOUT: $name ($source, $operation)"
	elif [[ "$rc" -gt 128 ]] ||
			grep -Eq 'handle_crash:|signal 11|SIGSEGV|SIGABRT|Aborted|Segmentation fault' "$log"; then
		CRASH=$((CRASH + 1))
		echo "CRASH: $name (rc=$rc, $source, $operation)"
	elif [[ "$rc" -ne 0 ]] || ! grep -Fxq VG_SUITE_COMPLETED "$log"; then
		INCOMPLETE=$((INCOMPLETE + 1))
		echo "INCOMPLETE: $name (rc=$rc, $source, $operation)"
	else
		OK=$((OK + 1))
		echo "OK: $name ($source, $operation)"
	fi
done < "$OUT_DIR/manifest.tsv"
echo "Mutation stress: ok=$OK crashes=$CRASH timeouts=$TIMED_OUT incomplete=$INCOMPLETE total=$COUNT"
[[ "$OK" -eq "$COUNT" && "$CRASH" -eq 0 && "$TIMED_OUT" -eq 0 && "$INCOMPLETE" -eq 0 ]]

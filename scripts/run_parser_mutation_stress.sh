#!/usr/bin/env bash
# ============================================================================
# Light tokenizer/parser/VM mutation stress
# ============================================================================
# Takes well-formed .vg sources, applies small random mutations, and asserts
# Godot+VG never hard-crashes (signal 11 / abort). Clean PASS/FAIL, parse
# errors, and runtime errors are all acceptable outcomes.
#
# Usage:
#   ./scripts/run_parser_mutation_stress.sh [count] [seed]
# Env:
#   GODOT — Godot binary
#   MUTATION_TIMEOUT — seconds per mutant (default 8)
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COUNT="${1:-40}"
SEED="${2:-42}"
TIMEOUT_SECS="${MUTATION_TIMEOUT:-8}"
OUT_DIR="${TMPDIR:-/tmp}/vg-mutation-$$"
mkdir -p "$OUT_DIR"

GODOT="${GODOT:-}"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	for candidate in \
		"./Godot_v4.6.1-stable_linux.x86_64" \
		"./Godot_v4.6-stable_linux.x86_64" \
		./Godot_v4.6*_linux.x86_64; do
		if [[ -x "$candidate" ]]; then
			GODOT="$candidate"
			break
		fi
	done
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "ERROR: Godot binary not found" >&2
	exit 1
fi

GODOT_USER_DATA_DIR="${TMPDIR:-/tmp}/vg-mut-user-$$"
mkdir -p "$GODOT_USER_DATA_DIR"

mapfile -t SOURCES < <(
	{
		find corpus -name '*.vg' -type f 2>/dev/null
		find test_proj/test_suite -name 'test_*.vg' -type f 2>/dev/null
	} | sort | head -80
)

if [[ ${#SOURCES[@]} -eq 0 ]]; then
	echo "No source .vg files found"
	exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║  VG parser/VM mutation stress                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo "Godot:   $GODOT"
echo "Pool:    ${#SOURCES[@]} files"
echo "Mutants: $COUNT  seed=$SEED"
echo "Out:     $OUT_DIR"
echo ""

CRASH=0
OK=0
python3 - "$COUNT" "$SEED" "$OUT_DIR" "${SOURCES[@]}" <<'PY'
import random, sys, pathlib, re, subprocess, os

count = int(sys.argv[1])
seed = int(sys.argv[2])
out_dir = pathlib.Path(sys.argv[3])
sources = [pathlib.Path(p) for p in sys.argv[4:]]
rng = random.Random(seed)

ops = [
    lambda lines: (_del_line(lines)),
    lambda lines: (_flip_and_or(lines)),
    lambda lines: (_extra_if(lines)),
    lambda lines: (_swap_brackets(lines)),
    lambda lines: (_drop_end(lines)),
    lambda lines: (_dup_line(lines)),
]

def _del_line(lines):
    if len(lines) < 3:
        return lines
    i = rng.randrange(1, len(lines) - 1)
    del lines[i]
    return lines

def _flip_and_or(lines):
    text = "\n".join(lines)
    if " And " in text:
        text = text.replace(" And ", " Or ", 1)
    elif " Or " in text:
        text = text.replace(" Or ", " And ", 1)
    elif "And" in text:
        text = text.replace("And", "Or", 1)
    return text.split("\n")

def _extra_if(lines):
    i = rng.randrange(0, len(lines))
    lines.insert(i, "If True Then")
    return lines

def _swap_brackets(lines):
    text = "\n".join(lines)
    # Flip first arr(i) <-> arr[i] occurrence
    m = re.search(r"(\w+)\((\d+|i|j|k|n|x)\)", text)
    if m:
        text = text[:m.start()] + f"{m.group(1)}[{m.group(2)}]" + text[m.end():]
    else:
        m = re.search(r"(\w+)\[(\d+|i|j|k|n|x)\]", text)
        if m:
            text = text[:m.start()] + f"{m.group(1)}({m.group(2)})" + text[m.end():]
    return text.split("\n")

def _drop_end(lines):
    for i in range(len(lines) - 1, -1, -1):
        if re.match(r"^\s*End\s+(If|Sub|Function|Select|With|Class)\b", lines[i], re.I):
            del lines[i]
            break
    return lines

def _dup_line(lines):
    if not lines:
        return lines
    i = rng.randrange(0, len(lines))
    lines.insert(i, lines[i])
    return lines

manifest = []
for n in range(count):
    src = sources[rng.randrange(0, len(sources))]
    raw = src.read_text(errors="replace").splitlines()
    if not raw:
        raw = ["Sub _Ready()", "End Sub"]
    mutated = list(raw)
    op = ops[rng.randrange(0, len(ops))]
    try:
        mutated = op(mutated)
    except Exception:
        mutated = raw
    # Ensure something runnable-ish
    body = "\n".join(mutated)
    if "Sub " not in body and "Function " not in body:
        body = "Sub _Ready()\n" + body + "\nEnd Sub\n"
    path = out_dir / f"mutant_{n:03d}.vg"
    path.write_text(body + ("\n" if not body.endswith("\n") else ""))
    manifest.append((str(path), str(src), op.__code__.co_consts[0] if False else op.__name__))

# Print paths for the shell runner
for p, s, _ in manifest:
    print(p)
PY

mapfile -t MUTANTS < <(python3 - "$COUNT" "$SEED" "$OUT_DIR" "${SOURCES[@]}" <<'PY'
import random, sys, pathlib, re
count = int(sys.argv[1]); seed = int(sys.argv[2]); out_dir = pathlib.Path(sys.argv[3])
sources = [pathlib.Path(p) for p in sys.argv[4:]]
rng = random.Random(seed)

def del_line(lines):
    if len(lines) < 3: return lines
    i = rng.randrange(1, len(lines)-1); del lines[i]; return lines
def flip_and_or(lines):
    t="\n".join(lines)
    if " And " in t: t=t.replace(" And "," Or ",1)
    elif " Or " in t: t=t.replace(" Or "," And ",1)
    return t.split("\n")
def extra_if(lines):
    lines.insert(rng.randrange(0,len(lines)), "If True Then"); return lines
def swap_brackets(lines):
    t="\n".join(lines)
    m=re.search(r"(\w+)\((\d+|i|j|k|n|x)\)", t)
    if m: t=t[:m.start()]+f"{m.group(1)}[{m.group(2)}]"+t[m.end():]
    else:
        m=re.search(r"(\w+)\[(\d+|i|j|k|n|x)\]", t)
        if m: t=t[:m.start()]+f"{m.group(1)}({m.group(2)})"+t[m.end():]
    return t.split("\n")
def drop_end(lines):
    for i in range(len(lines)-1,-1,-1):
        if re.match(r"^\s*End\s+(If|Sub|Function|Select|With|Class)\b", lines[i], re.I):
            del lines[i]; break
    return lines
def dup_line(lines):
    if lines: i=rng.randrange(0,len(lines)); lines.insert(i, lines[i])
    return lines
ops=[del_line,flip_and_or,extra_if,swap_brackets,drop_end,dup_line]
for n in range(count):
    src=sources[rng.randrange(0,len(sources))]
    raw=src.read_text(errors="replace").splitlines() or ["Sub _Ready()","End Sub"]
    mutated=list(raw)
    try: mutated=ops[rng.randrange(0,len(ops))](mutated)
    except Exception: mutated=raw
    body="\n".join(mutated)
    if "Sub " not in body and "Function " not in body:
        body="Sub _Ready()\n"+body+"\nEnd Sub\n"
    path=out_dir/f"mutant_{n:03d}.vg"
    path.write_text(body+("\n" if not body.endswith("\n") else ""))
    print(path)
PY
)

DEST="test_proj/test_suite/_mutation_tmp.vg"
CRASH_FILES=()

for mutant in "${MUTANTS[@]}"; do
	fname=$(basename "$mutant")
	cp -f "$mutant" "$DEST"
	(
		flock 9
		echo "res://test_suite/_mutation_tmp.vg" > test_proj/current_test.txt
	) 9>test_proj/current_test.lock

	raw_out="$OUT_DIR/${fname}.out"
	set +e
	timeout "$TIMEOUT_SECS" "$GODOT" --headless --path test_proj \
		--user-data-dir "$GODOT_USER_DATA_DIR" -s run_suite.gd \
		>"$raw_out" 2>&1
	rc=$?
	set -e

	# 139 = SIGSEGV, 134 = SIGABRT, 124 = timeout (acceptable)
	if [[ "$rc" -eq 139 || "$rc" -eq 134 ]] || grep -qE 'handle_crash:|signal 11|Aborted|Segmentation fault' "$raw_out"; then
		echo "  CRASH  $fname  (rc=$rc)"
		CRASH=$((CRASH + 1))
		CRASH_FILES+=("$fname")
		tail -12 "$raw_out" | sed 's/^/       /'
	else
		OK=$((OK + 1))
		echo "  ok     $fname  (rc=$rc)"
	fi
done

rm -f "$DEST" "${DEST}.uid" 2>/dev/null || true

echo ""
echo "══════════════════════════════════════════════════"
echo "Mutation stress: ok=$OK  crashes=$CRASH  total=$COUNT"
echo "Artifacts: $OUT_DIR"
if [[ "$CRASH" -gt 0 ]]; then
	echo "CRASHES:"
	printf '  %s\n' "${CRASH_FILES[@]}"
	exit 1
fi
echo "No hard crashes."
exit 0

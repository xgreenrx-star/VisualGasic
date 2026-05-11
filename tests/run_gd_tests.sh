#!/bin/bash
# ============================================================================
# VisualGasic GDScript Test Suite Runner
# ============================================================================
# Runs each tests/test_*.gd file under the AGCK_Tests project (which has
# the addons/visual_gasic symlink) and parses "RESULTS: X/Y passed, Z failed"
# from the output. Exits 0 only if every suite is fully green.
#
# Usage: ./tests/run_gd_tests.sh [filter]
# ============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST_PROJECT="$ROOT/game_projects/AGCK_Tests"
TESTS_DIR="$ROOT/tests"
FILTER="${1:-test_*.gd}"
TIMEOUT=45

if [[ ! -x "$GODOT" ]]; then
    echo "ERROR: Godot binary not found at $GODOT" >&2
    exit 2
fi
if [[ ! -d "$HOST_PROJECT" ]]; then
    echo "ERROR: Host project not found at $HOST_PROJECT" >&2
    exit 2
fi

# Locate test files
mapfile -t TEST_FILES < <(find "$TESTS_DIR" -maxdepth 1 -name "$FILTER" -type f | sort)
if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    echo "No GD tests matching '$FILTER' in $TESTS_DIR"
    exit 0
fi

TOTAL_PASS=0
TOTAL_FAIL=0
SUITES_OK=0
SUITES_BAD=0
FAILED_SUITES=()

for tf in "${TEST_FILES[@]}"; do
    name="$(basename "$tf")"
    staged="$HOST_PROJECT/_gd_test_running.gd"
    cp "$tf" "$staged"
    # Stage fixtures alongside the test so it can read them via res://.
    # Tests look up fixtures under res://_gd_fixtures/<group>/...
    fixtures_staged="$HOST_PROJECT/_gd_fixtures"
    rm -rf "$fixtures_staged"
    if [[ -d "$TESTS_DIR/fixtures" ]]; then
        cp -r "$TESTS_DIR/fixtures" "$fixtures_staged"
    fi
    # Detect whether the test is itself a SceneTree (run directly) or a Node
    # (needs a SceneTree wrapper that instantiates it).
    if head -5 "$staged" | grep -qE '^extends\s+SceneTree\b'; then
        output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s _gd_test_running.gd 2>&1 || true)"
        rm -f "$staged"
        rm -rf "$fixtures_staged"
    else
        wrapper="$HOST_PROJECT/_gd_test_runner.gd"
        cat > "$wrapper" <<'EOF'
extends SceneTree
func _init():
    var s = load("res://_gd_test_running.gd")
    if s == null:
        printerr("[gd-runner] cannot load staged test")
        quit(1)
        return
    var n: Node = s.new()
    root.add_child(n)
EOF
        output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s _gd_test_runner.gd 2>&1 || true)"
        rm -f "$staged" "$wrapper"
        rm -rf "$fixtures_staged"
    fi

    # Expected line: "RESULTS: 134/134 passed, 0 failed"
    line="$(echo "$output" | grep -E "^RESULTS: [0-9]+/[0-9]+ passed, [0-9]+ failed" | tail -1)"
    if [[ -z "$line" ]]; then
        echo "  ??? $name (no RESULTS line — suite did not finish cleanly)"
        SUITES_BAD=$((SUITES_BAD + 1))
        FAILED_SUITES+=("$name (no results)")
        # Surface tail of output for diagnosis
        echo "$output" | tail -5 | sed 's/^/      /'
        continue
    fi
    p=$(echo "$line" | sed -E 's/^RESULTS: ([0-9]+).*/\1/')
    t=$(echo "$line" | sed -E 's/^RESULTS: [0-9]+\/([0-9]+).*/\1/')
    f=$(echo "$line" | sed -E 's/.*passed, ([0-9]+) failed.*/\1/')
    TOTAL_PASS=$((TOTAL_PASS + p))
    TOTAL_FAIL=$((TOTAL_FAIL + f))
    if [[ "$f" -gt 0 ]]; then
        echo "  FAIL $name  ($p/$t passed, $f failed)"
        echo "$output" | grep -E "^  ✗ " | head -10 | sed 's/^/      /'
        SUITES_BAD=$((SUITES_BAD + 1))
        FAILED_SUITES+=("$name")
    else
        echo "  OK   $name  ($p/$t passed)"
        SUITES_OK=$((SUITES_OK + 1))
    fi
done

echo ""
echo "=================================================="
echo "GD TESTS: ${#TEST_FILES[@]} suite(s)  |  $TOTAL_PASS passed  |  $TOTAL_FAIL failed"
if [[ $SUITES_BAD -gt 0 ]]; then
    echo "Failing suites:"
    for s in "${FAILED_SUITES[@]}"; do
        echo "  - $s"
    done
    exit 1
fi
exit 0

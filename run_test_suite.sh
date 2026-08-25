#!/bin/bash
# ============================================================================
# VisualGasic Automated Test Suite Runner
# ============================================================================
# Runs all test_*.vg files in test_proj/test_suite/ headlessly.
# Each .vg file must print "PASS: <name>" or "FAIL: <name>: <reason>" lines.
# Usage: ./run_test_suite.sh [filter]
#   filter: optional glob pattern to match test filenames (e.g. "test_array*")
#   --vg-only: skip GDScript + Narcea golden phases (set automatically when
#              VG_TEST_SUITE_VG_ONLY=1, as in CI)
# Env:
#   GODOT — path to Godot binary (auto-detected if unset)
#   VG_TEST_SUITE_VG_ONLY=1 — same as --vg-only
# ============================================================================

set -euo pipefail

TEST_DIR="test_proj/test_suite"
RUNNER="run_suite.gd"
TIMEOUT_SECS=20
FILTER="test_*.vg"
VG_ONLY=0
# Data-only .vg fixtures (no Sub _Ready); tested via GDScript harnesses instead.
SKIP_FILES=(
    test_sprite_data_resolver.vg
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vg-only)
            VG_ONLY=1
            shift
            ;;
        *)
            FILTER="$1"
            shift
            ;;
    esac
done

if [[ "${VG_TEST_SUITE_VG_ONLY:-0}" == "1" ]]; then
    VG_ONLY=1
fi

# Godot binary: GODOT env, then 4.6, then 4.5, then any Godot_v* in repo root
GODOT="${GODOT:-}"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
    for candidate in \
        "./Godot_v4.6.1-stable_linux.x86_64" \
        "./Godot_v4.6-stable_linux.x86_64" \
        "./Godot_v4.5.1-stable_linux.x86_64" \
        ./Godot_v4.6*_linux.x86_64 \
        ./Godot_v4.5*_linux.x86_64; do
        if [[ -x "$candidate" ]]; then
            GODOT="$candidate"
            break
        fi
    done
fi

# Writable Godot user data (avoids headless crashes when $HOME/user:// is not writable).
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-user-$$}"
mkdir -p "$GODOT_USER_DATA_DIR"
GODOT_BASE_ARGS=(--headless --path test_proj --user-data-dir "$GODOT_USER_DATA_DIR" -s "$RUNNER")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

# Counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_ERROR=0
TOTAL_FILES=0
FAILED_FILES=()
ERROR_FILES=()

echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     VisualGasic Automated Test Suite             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if [ ! -x "$GODOT" ]; then
    echo -e "${RED}ERROR: Godot binary not found at $GODOT${NC}"
    exit 1
fi

if [ ! -d "$TEST_DIR" ]; then
    echo -e "${RED}ERROR: Test directory not found at $TEST_DIR${NC}"
    exit 1
fi

# Collect test files
mapfile -t TEST_FILES < <(find "$TEST_DIR" -name "$FILTER" -type f | sort)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No test files matching '$FILTER' in $TEST_DIR${NC}"
    exit 0
fi

echo -e "${CYAN}Found ${#TEST_FILES[@]} test file(s)${NC}"
echo -e "${CYAN}Godot: $GODOT${NC}"
echo ""

# Preflight: verify GDExtension loads and VG prints PASS/FAIL.
echo "res://test_suite/test_arr_simple.vg" > test_proj/current_test.txt
smoke_out=$(timeout "$TIMEOUT_SECS" "$GODOT" "${GODOT_BASE_ARGS[@]}" 2>&1) || true
if ! echo "$smoke_out" | grep -q "^PASS:"; then
    echo -e "${RED}FATAL: GDExtension smoke test failed (no PASS: from test_arr_simple.vg)${NC}"
    echo -e "${YELLOW}Hint: run scripts/prepare_ci_gdextension.sh after scons build${NC}"
    echo "$smoke_out" | tail -40
    exit 1
fi
echo -e "${GREEN}GDExtension smoke OK${NC}"
echo ""

# Run each test
for vg_file in "${TEST_FILES[@]}"; do
    fname=$(basename "$vg_file")
    skip=0
    for s in "${SKIP_FILES[@]}"; do
        if [[ "$fname" == "$s" ]]; then
            skip=1
            break
        fi
    done
    if [[ "$skip" -eq 1 ]]; then
        echo -e "  ${CYAN}SKIP${NC} $fname  ${CYAN}(fixture — GDScript harness)${NC}"
        continue
    fi
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Write current test path for the runner
    echo "res://test_suite/$fname" > test_proj/current_test.txt
    
    # Run headlessly, capture output
    output=$(timeout "$TIMEOUT_SECS" "$GODOT" "${GODOT_BASE_ARGS[@]}" 2>&1) || true
    
    # Count PASS and FAIL lines
    pass_count=$(echo "$output" | grep -c "^PASS:" || true)
    fail_count=$(echo "$output" | grep -c "^FAIL:" || true)
    
    # Detect if test produced no PASS/FAIL at all (broken test)
    if [ "$pass_count" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
        echo -e "  ${YELLOW}???${NC}  $fname  ${YELLOW}(no assertions)${NC}"
        echo "$output" | tail -8 | sed 's/^/       /'
        ERROR_FILES+=("$fname (no assertions)")
        TOTAL_ERROR=$((TOTAL_ERROR + 1))
    elif [ "$fail_count" -gt 0 ]; then
        echo -e "  ${RED}FAIL${NC} $fname  (${GREEN}$pass_count passed${NC}, ${RED}$fail_count failed${NC})"
        # Show failure details
        echo "$output" | grep "^FAIL:" | while read -r line; do
            echo -e "       ${RED}$line${NC}"
        done
        FAILED_FILES+=("$fname")
    else
        echo -e "  ${GREEN}OK${NC}   $fname  (${GREEN}$pass_count passed${NC})"
    fi
    
    TOTAL_PASS=$((TOTAL_PASS + pass_count))
    TOTAL_FAIL=$((TOTAL_FAIL + fail_count))
done

# Summary
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}RESULTS:${NC}"
echo -e "  Files:      $TOTAL_FILES"
echo -e "  Assertions: $((TOTAL_PASS + TOTAL_FAIL))"
echo -e "  ${GREEN}Passed:     $TOTAL_PASS${NC}"
echo -e "  ${RED}Failed:     $TOTAL_FAIL${NC}"
echo -e "  ${YELLOW}Errors:     $TOTAL_ERROR${NC}"

if [ ${#FAILED_FILES[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed files:${NC}"
    for f in "${FAILED_FILES[@]}"; do
        echo -e "  ${RED}✗${NC} $f"
    done
fi

if [ ${#ERROR_FILES[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Error files:${NC}"
    for f in "${ERROR_FILES[@]}"; do
        echo -e "  ${YELLOW}?${NC} $f"
    done
fi

echo -e "${BOLD}══════════════════════════════════════════════════${NC}"

# ---------------------------------------------------------------------------
# Phase 2: GDScript test suites (tests/test_*.gd) — covers VB6 importer, etc.
# ---------------------------------------------------------------------------
GD_FAIL=0
if [[ "$VG_ONLY" -eq 0 && -x "tests/run_gd_tests.sh" ]]; then
    echo ""
    echo -e "${BOLD}── GDScript suites (tests/) ──${NC}"
    if ! bash tests/run_gd_tests.sh; then
        GD_FAIL=1
    fi
fi

# ---------------------------------------------------------------------------
# Phase 3: Narcea Golden Path — Tier A + B (fixture + recorded replay)
# ---------------------------------------------------------------------------
NARCEA_GOLDEN_FAIL=0
if [[ "$VG_ONLY" -eq 0 && -x "scripts/run_narcea_golden.sh" ]]; then
    echo ""
    echo -e "${BOLD}── Narcea Golden Path (Tier A) ──${NC}"
    if ! bash scripts/run_narcea_golden.sh --tier A; then
        NARCEA_GOLDEN_FAIL=1
    fi
    echo ""
    echo -e "${BOLD}── Narcea Golden Path (Tier B) ──${NC}"
    if ! bash scripts/run_narcea_golden.sh --tier B; then
        NARCEA_GOLDEN_FAIL=1
    fi
fi

# Exit code
if [ "$TOTAL_FAIL" -gt 0 ] || [ "$TOTAL_ERROR" -gt 0 ] || [ "$GD_FAIL" -ne 0 ] || [ "$NARCEA_GOLDEN_FAIL" -ne 0 ]; then
    exit 1
else
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
fi

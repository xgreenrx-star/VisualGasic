#!/bin/bash
# ============================================================================
# VisualGasic Automated Test Suite Runner
# ============================================================================
# Runs all test_*.vg files in test_proj/test_suite/ headlessly.
# Each .vg file must print "PASS: <name>" or "FAIL: <name>: <reason>" lines.
# Usage: ./run_test_suite.sh [filter]
#   filter: optional glob pattern to match test filenames (e.g. "test_array*")
# ============================================================================

set -euo pipefail

GODOT="./Godot_v4.6.1-stable_linux.x86_64"
TEST_DIR="test_proj/test_suite"
RUNNER="run_suite.gd"
TIMEOUT_SECS=20
FILTER="${1:-test_*.vg}"

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
echo ""

# Run each test
for vg_file in "${TEST_FILES[@]}"; do
    fname=$(basename "$vg_file")
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Write current test path for the runner
    echo "res://test_suite/$fname" > test_proj/current_test.txt
    
    # Run headlessly, capture output
    output=$(timeout "$TIMEOUT_SECS" "$GODOT" --headless --path test_proj -s "$RUNNER" 2>&1) || true
    
    # Count PASS and FAIL lines
    pass_count=$(echo "$output" | grep -c "^PASS:" || true)
    fail_count=$(echo "$output" | grep -c "^FAIL:" || true)
    error_count=$(echo "$output" | grep -ci "ERROR\|CRASH\|Segfault" | head -1 || true)
    
    # Detect if test produced no PASS/FAIL at all (broken test)
    if [ "$pass_count" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
        echo -e "  ${YELLOW}???${NC}  $fname  ${YELLOW}(no assertions)${NC}"
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

# Exit code
if [ "$TOTAL_FAIL" -gt 0 ] || [ "$TOTAL_ERROR" -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
fi

#!/bin/bash
# Narcea Agent Loop Test
# Tests the full pipeline: provider routing → Narcea context → prompt → parse → simulate

set -e
ROOT=/home/Commodore/Documents/VisualGasic
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
TEST_PROJ="$ROOT/projects/vg_narcea_test"

echo "=== Narcea Agent Loop Smoke Test ==="
echo "Project: $TEST_PROJ"
echo ""

# Run the comprehensive Narcea test script
timeout 30 "$GODOT" --headless --path "$TEST_PROJ" -s "$ROOT/tests/test_narcea_agent_loop.gd" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ ALL NARCEA TESTS PASSED"
elif [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "⚠️ TEST TIMEOUT (30s)"
    exit 1
else
    echo ""
    echo "❌ TESTS FAILED (exit code $EXIT_CODE)"
    exit 1
fi

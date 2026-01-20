#!/bin/bash

GODOT_BIN="/home/Commodore/Documents/VisualGasic/Godot_v4.5.1-stable_linux.x86_64"
TEST_DIR="/home/Commodore/Documents/VisualGasic/examples"

echo "Starting Visual Gasic Test Suite..."
echo "Godot Binary: $GODOT_BIN"
echo "Test Directory: $TEST_DIR"
echo "---------------------------------------------------"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=""

# Change to the test directory so Godot sees it as the project root
cd "$TEST_DIR" || exit 1

# NOTE: We ASSUME .godot folder exists and is populated.
# If not, one must run `godot --editor --quit` first.

for script in run_*.gd; do
    if [ ! -f "$script" ]; then continue; fi
    
    test_name=$(basename "$script")
    echo -n "Running $test_name... "
    
    # Run godot in headless mode
    # --path . ensures Godot loads project.godot from current dir
    # Capture stderr to check for engine errors
    output=$("$GODOT_BIN" --headless --path . -s "$script" 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "FAIL (Exit Code: $exit_code)"
        FAILED_TESTS+="$test_name (Exit Code: $exit_code)\n"
        ((FAIL_COUNT++))
    elif echo "$output" | grep -q "FAIL:"; then
        echo "FAIL (Test Assertion)"
        echo "$output" | grep "FAIL:" | head -n 3
        FAILED_TESTS+="$test_name (Assertion)\n"
         ((FAIL_COUNT++))
    elif echo "$output" | grep -q "ERROR:"; then
        # Filter out the specific GDExtension error lines
        filtered_output=$(echo "$output" | grep -v "GDExtension dynamic library not found" | grep -v "Error loading GDExtension configuration file" | grep -v "Error loading extension" | grep -v "resources still in use at exit")
        
        if echo "$filtered_output" | grep -q "ERROR:"; then
            echo "FAIL (Engine Error Logged)"
            echo "$filtered_output" | grep "ERROR:" | head -n 5
            FAILED_TESTS+="$test_name (Engine Error)\n"
             ((FAIL_COUNT++))
        else
             echo "PASS"  # (With ignored GDExtension errors)
             ((PASS_COUNT++))
        fi
    else
        echo "PASS"
        ((PASS_COUNT++))
    fi
done

echo "---------------------------------------------------"
echo "Test Suite Completed."
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "\nFailed Tests:\n$FAILED_TESTS"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi

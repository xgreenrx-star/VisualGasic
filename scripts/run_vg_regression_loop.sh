#!/bin/bash
G=${GODOT:-godot}
cd "$(dirname "$0")/../test_proj"
OUT=${1:-/tmp/reg_new.log}
: > $OUT
for f in test_suite/*.vg; do
  echo "== $f" >> $OUT
  timeout 60 $G --headless --path . --audio-driver Dummy --script res://run_suite.gd -- res://$f >> $OUT 2>&1
  echo "EXIT $?" >> $OUT
done
echo "PASS=$(grep -c '^PASS' $OUT) FAIL=$(grep -c '^FAIL' $OUT)" >> $OUT

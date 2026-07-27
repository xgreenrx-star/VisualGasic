#!/bin/bash
set -e
cd /home/Commodore/Documents/VisualGasic
echo "=== Building VisualGasic ==="
scons platform=linux target=editor -j$(nproc) 2>&1 | grep -E "error:|Error|warning:" | head -30
echo "=== Build exit code: ${PIPESTATUS[0]} ==="
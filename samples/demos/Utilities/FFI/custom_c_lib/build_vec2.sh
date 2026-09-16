#!/bin/bash
# build_vec2.sh — Build the C++ Vec2 shared library for FFI demo
#
# Usage:  ./build_vec2.sh
# Output: vec2.so (in the current directory)
#
# Prerequisites: g++ with C++11 support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building vec2.so ==="
g++ -shared -fPIC -std=c++11 -O2 -o vec2.so vec2_lib.cpp

echo "Done: $(pwd)/vec2.so"
ls -lh vec2.so

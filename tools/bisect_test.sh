#!/bin/sh
set -eu

# Build the extension; exit 125 to tell git-bisect to skip if build fails
scons -j2 >/dev/null 2>&1 || exit 125

# Run the loader test with ASan preloaded so memory errors are raised reliably
LD_PRELOAD=/usr/lib/gcc/x86_64-linux-gnu/12/libasan.so ./tools/test_load_lib >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "BISECT_TEST: GOOD"
    exit 0
else
    echo "BISECT_TEST: BAD"
    exit 1
fi

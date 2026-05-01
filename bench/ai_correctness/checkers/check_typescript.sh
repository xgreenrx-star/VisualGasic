#!/bin/bash
# Parse-check a TypeScript file with a locally-installed tsc. Exit 0 = no errors.
# `npm install typescript` happens once in this directory at setup time.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -x "$DIR/node_modules/.bin/tsc" ]]; then
    TSC="$DIR/node_modules/.bin/tsc"
elif command -v tsc >/dev/null 2>&1; then
    TSC=tsc
else
    echo "ERROR: tsc not found. Run: cd bench/ai_correctness/checkers && npm install typescript" >&2
    exit 127
fi

# --noEmit: report errors but don't write JS. --strict for fairness.
"$TSC" --noEmit --strict --target es2020 --module commonjs --moduleResolution bundler --skipLibCheck "$1"

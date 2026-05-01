#!/bin/bash
# Parse-check a TypeScript file with tsc --noEmit. Exit 0 = no errors.
# Requires a global tsc (npm i -g typescript) or npx.
set -e

if command -v tsc >/dev/null 2>&1; then
    TSC=tsc
elif command -v npx >/dev/null 2>&1; then
    TSC="npx --yes typescript@latest tsc"
else
    echo "ERROR: neither tsc nor npx found on PATH" >&2
    exit 127
fi

# --noEmit means: report errors but don't write JS. --strict for fairness.
$TSC --noEmit --strict --target es2020 --module commonjs "$1"

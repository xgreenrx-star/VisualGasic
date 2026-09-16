#!/usr/bin/env bash
# build_demo_csharp.sh — Build Godot C# assemblies for demo benchmark project.
#
# Requires: dotnet SDK 8+, Godot .NET editor (for Godot.NET.Sdk restore on first build).
#
# Usage:
#   scripts/build_demo_csharp.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="$ROOT/demo"
CSPROJ="$DEMO/VisualGasic Demo.csproj"

if ! command -v dotnet >/dev/null 2>&1; then
	echo "dotnet SDK not found — install .NET 8+ for C# benchmarks." >&2
	exit 2
fi

if [[ ! -f "$CSPROJ" ]]; then
	echo "Missing $CSPROJ" >&2
	exit 2
fi

echo "Building demo C# project..."
(
	cd "$DEMO"
	dotnet build "$CSPROJ" -c Debug --nologo -v q
)
echo "Demo C# build OK."

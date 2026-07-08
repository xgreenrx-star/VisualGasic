#!/bin/bash
# Parse-check (compile) a C# file using the .NET SDK. Exit 0 = compiles OK.
# Requires: dotnet SDK >= 8.0
set -e

if ! command -v dotnet >/dev/null 2>&1; then
    echo "ERROR: dotnet not found. Install the .NET SDK." >&2
    exit 127
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$DIR/_csharp_check_proj"

# One-time setup: create a minimal console project
if [[ ! -f "$PROJ_DIR/check.csproj" ]]; then
    mkdir -p "$PROJ_DIR"
    cat > "$PROJ_DIR/check.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>disable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AllowUnsafeBlocks>false</AllowUnsafeBlocks>
  </PropertyGroup>
</Project>
EOF
    # Restore once so subsequent runs use --no-restore
    dotnet restore "$PROJ_DIR/check.csproj" --verbosity quiet 2>/dev/null || true
fi

# Copy candidate as the sole source file
cp "$1" "$PROJ_DIR/Program.cs"

# Build (compile only, no run). Suppress noisy output.
set +e
OUT="$(dotnet build "$PROJ_DIR/check.csproj" --no-restore --verbosity quiet 2>&1)"
EXIT=$?
set -e

if [[ $EXIT -ne 0 ]]; then
    echo "$OUT" | grep -E "error CS|Build FAILED" | head -10 >&2
    exit 1
fi
exit 0

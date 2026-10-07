#!/usr/bin/env bash
# Build GDSiON (vendored at vendor/gdsion/) and copy outputs into this plugin's bin/.
# Run from the repository root or from anywhere — paths are resolved from this script.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/../../../.." >/dev/null 2>&1 && pwd )"
GDSION_DIR="${REPO_ROOT}/vendor/gdsion"
BIN_DIR="${SCRIPT_DIR}/bin"
PATCH="${SCRIPT_DIR}/gdsion_pool_lifetime.patch"

if [[ ! -d "${GDSION_DIR}" ]]; then
    echo "error: GDSiON source not found at ${GDSION_DIR}" >&2
    echo "       Run: git clone https://github.com/YuriSizov/gdsion vendor/gdsion" >&2
    exit 1
fi

if git -C "${GDSION_DIR}" apply --check "${PATCH}" 2>/dev/null; then
    git -C "${GDSION_DIR}" apply "${PATCH}"
elif ! git -C "${GDSION_DIR}" apply --reverse --check "${PATCH}" 2>/dev/null; then
    echo "error: GDSiON pool lifetime patch conflicts with ${GDSION_DIR}" >&2
    exit 1
fi

if [[ ! -d "${GDSION_DIR}/godot-cpp/include" ]]; then
    echo "Initializing GDSiON's godot-cpp submodule (HTTPS)..."
    (cd "${GDSION_DIR}" && \
        git config -f .gitmodules submodule.godot-cpp.url https://github.com/godotengine/godot-cpp.git && \
        git submodule sync && \
        git submodule update --init --recursive --depth 1)
fi

PLATFORM="${PLATFORM:-linux}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
if [[ "$#" -gt 0 ]]; then
    TARGETS=("$@")
else
    TARGETS=(template_release template_debug)
fi

mkdir -p "${BIN_DIR}"

cd "${GDSION_DIR}"
for tgt in "${TARGETS[@]}"; do
    echo ">>> scons platform=${PLATFORM} target=${tgt} -j${JOBS}"
    scons platform="${PLATFORM}" target="${tgt}" -j"${JOBS}"
    shopt -s nullglob
    outputs=("${GDSION_DIR}/bin/"*"${PLATFORM}.${tgt}"*)
    if [[ "${#outputs[@]}" -eq 0 ]]; then
        echo "error: no GDSiON outputs found for ${PLATFORM}.${tgt}" >&2
        exit 1
    fi
    for f in "${outputs[@]}"; do
        cp -r "${f}" "${BIN_DIR}/"
    done
done

echo "GDSiON built successfully. Files in ${BIN_DIR}:"
ls -la "${BIN_DIR}/"

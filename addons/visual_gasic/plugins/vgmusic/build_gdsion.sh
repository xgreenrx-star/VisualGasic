#!/usr/bin/env bash
# Build GDSiON (vendored at vendor/gdsion/) and copy outputs into this plugin's bin/.
# Run from the repository root or from anywhere — paths are resolved from this script.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/../../../.." >/dev/null 2>&1 && pwd )"
GDSION_DIR="${REPO_ROOT}/vendor/gdsion"
BIN_DIR="${SCRIPT_DIR}/bin"

if [[ ! -d "${GDSION_DIR}" ]]; then
    echo "error: GDSiON source not found at ${GDSION_DIR}" >&2
    echo "       Run: git clone https://github.com/YuriSizov/gdsion vendor/gdsion" >&2
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
TARGETS=("${@:-template_release template_debug}")

mkdir -p "${BIN_DIR}"

cd "${GDSION_DIR}"
for tgt in ${TARGETS[*]}; do
    echo ">>> scons platform=${PLATFORM} target=${tgt} -j${JOBS}"
    scons platform="${PLATFORM}" target="${tgt}" -j"${JOBS}"
done

echo ">>> copying outputs to ${BIN_DIR}"
shopt -s nullglob
for f in "${GDSION_DIR}/bin/"*; do
    [[ -e "${f}" ]] || continue
    cp -r "${f}" "${BIN_DIR}/"
done

echo "GDSiON built successfully. Files in ${BIN_DIR}:"
ls -la "${BIN_DIR}/"

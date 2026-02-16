#!/bin/bash
# setup_demos.sh — Link each demo's addons/ to the shared top-level addon
# Run this once after extracting the release zip:
#   cd VisualGasic_v2.5.0
#   bash demos/setup_demos.sh
#
# On Linux/macOS the symlinks should already work. This script recreates them
# in case your unzip tool didn't preserve symlinks.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADDON_SRC="$ROOT_DIR/addons/visual_gasic"

if [ ! -d "$ADDON_SRC" ]; then
  echo "ERROR: Cannot find $ADDON_SRC"
  echo "Make sure you run this from the extracted release directory."
  exit 1
fi

count=0
for proj_dir in "$SCRIPT_DIR"/*/*/ "$SCRIPT_DIR"/*/*/*/; do
  [ -d "$proj_dir" ] || continue
  # Only process directories that have a project.godot
  [ -f "${proj_dir}project.godot" ] || continue

  addon_dir="${proj_dir}addons"
  link_target="${addon_dir}/visual_gasic"

  mkdir -p "$addon_dir"

  # Remove existing (broken symlink, directory, or file)
  if [ -L "$link_target" ] || [ -e "$link_target" ]; then
    rm -rf "$link_target"
  fi

  # Create relative symlink
  rel_path=$(python3 -c "import os.path; print(os.path.relpath('$ADDON_SRC', '$addon_dir'))" 2>/dev/null || echo "")
  if [ -z "$rel_path" ]; then
    # Fallback: absolute symlink
    ln -s "$ADDON_SRC" "$link_target"
  else
    ln -s "$rel_path" "$link_target"
  fi

  echo "  ✅ $(basename "$(dirname "$proj_dir")")/$(basename "$proj_dir") -> addons/visual_gasic"
  count=$((count + 1))
done

echo ""
echo "Linked $count demo projects to shared addon."
echo "Open any demo's project.godot in Godot 4.5+ to run it."

#!/bin/bash
# Setup symlinks for all demo projects to share the central VisualGasic addon
# Run from the VisualGasic/demos directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADDON_SOURCE="$ROOT_DIR/addons/visual_gasic"

echo "=================================="
echo "VisualGasic Demo Symlink Setup"
echo "=================================="
echo ""
echo "Script directory: $SCRIPT_DIR"
echo "Addon source: $ADDON_SOURCE"
echo ""

# Find all demo project folders recursively (those containing project.godot)
find "$SCRIPT_DIR" -name "project.godot" -type f | while read project_file; do
    project_dir=$(dirname "$project_file")
    project_name=$(basename "$project_dir")
    parent_dir=$(basename "$(dirname "$project_dir")")
    
    addon_target="${project_dir}/addons/visual_gasic"
    
    # Create addons directory if needed
    mkdir -p "${project_dir}/addons"
    
    # Remove existing symlink or directory
    if [ -L "$addon_target" ]; then
        rm "$addon_target"
    elif [ -d "$addon_target" ]; then
        echo "⚠ Warning: $parent_dir/$project_name has a real addon folder, skipping..."
        continue
    fi
    
    # Calculate relative path from the addons/ folder to the source
    # The symlink is created INSIDE project/addons/, so we need path from there
    rel_path=$(realpath --relative-to="${project_dir}/addons" "$ADDON_SOURCE" 2>/dev/null)
    
    if [ -z "$rel_path" ] || [ ! -d "$ADDON_SOURCE" ]; then
        echo "✗ Error: Cannot calculate path for $parent_dir/$project_name"
        continue
    fi
    
    # Create relative symlink
    ln -s "$rel_path" "$addon_target"
    echo "✓ Linked: $parent_dir/$project_name -> $rel_path"
done

echo ""
echo "=================================="
echo "Setup complete!"
echo "=================================="
echo ""
echo "All demo projects now share the central VisualGasic addon."
echo ""
echo "To run a demo:"
echo "  1. cd demos/<Category>/<DemoName>"
echo "  2. Open in Godot 4.5+"
echo "  3. Press F5 to run"

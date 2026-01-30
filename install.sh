#!/bin/bash
# VisualGasic Template Installer for Linux/macOS
# Usage: curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash

set -e

echo "========================================="
echo "  VisualGasic Template Installer"
echo "========================================="
echo ""

# Detect OS and set template directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    TEMPLATE_DIR="$HOME/Library/Application Support/Godot/project_templates"
else
    # Linux
    TEMPLATE_DIR="$HOME/.local/share/godot/project_templates"
fi

INSTALL_DIR="$TEMPLATE_DIR/VisualGasic"

echo "Installing to: $INSTALL_DIR"
echo ""

# Create directory
mkdir -p "$INSTALL_DIR"

# Download latest release or clone
echo "Downloading VisualGasic template..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Try to download release, fallback to git clone
if command -v curl &> /dev/null; then
    if curl -sSL "https://github.com/xgreenrx-star/VisualGasic/archive/refs/heads/main.zip" -o visualgasic.zip; then
        echo "Extracting template..."
        if command -v unzip &> /dev/null; then
            unzip -q visualgasic.zip
            
            # Copy necessary files to template directory
            cp -r VisualGasic-main/addons "$INSTALL_DIR/"
            cp VisualGasic-main/project.godot "$INSTALL_DIR/" 2>/dev/null || echo "project_name=\"VisualGasic Project\"" > "$INSTALL_DIR/project.godot"
            
            # Create template configuration
            cat > "$INSTALL_DIR/.template.cfg" << 'EOF'
[template]
name="VisualGasic Project"
description="A new VisualGasic project with the language already installed and configured."
version="1.0.0"
icon="res://icon.svg"
EOF
            
            # Copy example scripts
            mkdir -p "$INSTALL_DIR/examples"
            cp -r VisualGasic-main/examples/*.vg "$INSTALL_DIR/examples/" 2>/dev/null || true
            
        else
            echo "Error: unzip not found. Please install unzip and try again."
            exit 1
        fi
    else
        echo "Download failed. Please check your internet connection."
        exit 1
    fi
else
    echo "Error: curl not found. Please install curl and try again."
    exit 1
fi

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "========================================="
echo "  ✅ Installation Complete!"
echo "========================================="
echo ""
echo "VisualGasic template has been installed to:"
echo "  $INSTALL_DIR"
echo ""
echo "To use it:"
echo "  1. Open Godot"
echo "  2. Create New Project"
echo "  3. Select 'VisualGasic Project' from templates"
echo "  4. Start coding in .vg files!"
echo ""
echo "Documentation: https://github.com/xgreenrx-star/VisualGasic"
echo ""

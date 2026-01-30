#!/usr/bin/env python3
"""
VisualGasic Template Installer
Cross-platform installer for VisualGasic project templates
Usage: python3 install.py
"""

import os
import sys
import platform
import shutil
import urllib.request
import zipfile
import tempfile
from pathlib import Path

def get_template_directory():
    """Get the Godot project templates directory for the current OS"""
    system = platform.system()
    
    if system == "Windows":
        return Path(os.environ.get("APPDATA", "")) / "Godot" / "project_templates"
    elif system == "Darwin":  # macOS
        return Path.home() / "Library" / "Application Support" / "Godot" / "project_templates"
    else:  # Linux and others
        return Path.home() / ".local" / "share" / "godot" / "project_templates"

def download_file(url, destination):
    """Download a file with progress indication"""
    print(f"Downloading from {url}...")
    try:
        urllib.request.urlretrieve(url, destination)
        return True
    except Exception as e:
        print(f"Download failed: {e}")
        return False

def install_template():
    """Main installation function"""
    print("=" * 45)
    print("  VisualGasic Template Installer")
    print("=" * 45)
    print()
    
    # Get template directory
    template_dir = get_template_directory()
    install_dir = template_dir / "VisualGasic"
    
    print(f"Installing to: {install_dir}")
    print()
    
    # Create directory
    install_dir.mkdir(parents=True, exist_ok=True)
    
    # Download and extract
    temp_dir = Path(tempfile.mkdtemp())
    zip_path = temp_dir / "visualgasic.zip"
    
    try:
        # Download
        download_url = "https://github.com/xgreenrx-star/VisualGasic/archive/refs/heads/main.zip"
        if not download_file(download_url, zip_path):
            print("Failed to download VisualGasic. Please check your internet connection.")
            return False
        
        # Extract
        print("Extracting template...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
        
        source_dir = temp_dir / "VisualGasic-main"
        
        # Copy addons
        if (source_dir / "addons").exists():
            print("Copying VisualGasic addons...")
            if (install_dir / "addons").exists():
                shutil.rmtree(install_dir / "addons")
            shutil.copytree(source_dir / "addons", install_dir / "addons")
        
        # Copy or create project.godot
        project_file = install_dir / "project.godot"
        if (source_dir / "project.godot").exists():
            shutil.copy2(source_dir / "project.godot", project_file)
        else:
            project_file.write_text('project_name="VisualGasic Project"\n')
        
        # Create template configuration
        template_cfg = install_dir / ".template.cfg"
        template_cfg.write_text("""[template]
name="VisualGasic Project"
description="A new VisualGasic project with the language already installed and configured."
version="1.0.0"
icon="res://icon.svg"
""")
        
        # Copy example scripts
        examples_dir = install_dir / "examples"
        examples_dir.mkdir(exist_ok=True)
        
        source_examples = source_dir / "examples"
        if source_examples.exists():
            print("Copying example scripts...")
            for vg_file in source_examples.glob("*.vg"):
                try:
                    shutil.copy2(vg_file, examples_dir)
                except:
                    pass
        
        print()
        print("=" * 45)
        print("  ✅ Installation Complete!")
        print("=" * 45)
        print()
        print("VisualGasic template has been installed to:")
        print(f"  {install_dir}")
        print()
        print("To use it:")
        print("  1. Open Godot")
        print("  2. Create New Project")
        print("  3. Select 'VisualGasic Project' from templates")
        print("  4. Start coding in .vg files!")
        print()
        print("Documentation: https://github.com/xgreenrx-star/VisualGasic")
        print()
        
        return True
        
    except Exception as e:
        print(f"Installation failed: {e}")
        return False
        
    finally:
        # Cleanup
        try:
            shutil.rmtree(temp_dir)
        except:
            pass

if __name__ == "__main__":
    try:
        success = install_template()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nInstallation cancelled by user.")
        sys.exit(1)

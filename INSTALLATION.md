# VisualGasic Installation Guide

Choose your preferred installation method:

## 🚀 Quick Install (Recommended)

### Linux / macOS
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
```

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

### Cross-Platform (Python)
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.py | python3
```

Or download and run:
```bash
python3 install.py
```

---

## 📦 Manual Installation

### Method 1: From GitHub Releases

1. Download the latest release from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases)
2. Extract the archive
3. Copy the `addons/visual_gasic/` folder to your Godot project's `addons/` directory
4. Enable the plugin in Project → Project Settings → Plugins

### Method 2: From Asset Library (Coming Soon)

1. Open Godot
2. Click on the AssetLib tab
3. Search for "VisualGasic"
4. Click Download → Install
5. Enable the plugin in Project Settings → Plugins

### Method 3: Git Clone

```bash
cd YourGodotProject
git clone https://github.com/xgreenrx-star/VisualGasic.git temp_visualgasic
mkdir -p addons
cp -r temp_visualgasic/addons/visual_gasic addons/
rm -rf temp_visualgasic
```

Then enable the plugin in Godot.

---

## 🎯 Project Template Installation

The installer scripts automatically set up VisualGasic as a project template.

### Manual Template Setup

1. Locate your Godot templates directory:
   - **Linux**: `~/.local/share/godot/project_templates/`
   - **Windows**: `%APPDATA%\Godot\project_templates\`
   - **macOS**: `~/Library/Application Support/Godot/project_templates/`

2. Create a `VisualGasic` folder inside the templates directory

3. Copy these files/folders into it:
   - `addons/visual_gasic/` (the plugin)
   - `project.godot` (project configuration)
   - `.template.cfg` (template metadata)
   - `examples/` (optional starter scripts)

4. Create `.template.cfg` with:
   ```ini
   [template]
   name="VisualGasic Project"
   description="A new VisualGasic project with the language already installed and configured."
   version="1.0.0"
   icon="res://icon.svg"
   ```

### Using the Template

1. Open Godot
2. Click "New Project"
3. In the template dropdown, select **"VisualGasic Project"**
4. Name your project and click "Create & Edit"
5. Start coding in `.vg` files!

---

## 🔧 Building from Source

### Prerequisites
- Godot 4.5+ source or binary
- SCons build system
- Git with submodules
- Modern C++ compiler (GCC 9+, Clang 10+, MSVC 2019+)

### Build Steps

```bash
# Clone with submodules
git clone --recursive https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic

# Build the extension
scons platform=linux target=template_debug    # Linux
scons platform=windows target=template_debug  # Windows
scons platform=macos target=template_debug    # macOS

# The compiled extension will be in bin/
```

### Install Built Extension

Copy the compiled extension to your project:
```bash
mkdir -p YourProject/addons/visual_gasic/bin/
cp -r addons/visual_gasic/* YourProject/addons/visual_gasic/
cp bin/* YourProject/addons/visual_gasic/bin/
```

---

## ✅ Verification

After installation, verify VisualGasic is working:

1. Create a new `.vg` file in your project:
   ```vb
   ' hello.vg
   Sub Main()
       Print "Hello from VisualGasic!"
   End Sub
   ```

2. Attach it to a node as a script
3. Run the project
4. You should see the output in the console

---

## 🆘 Troubleshooting

### Plugin Not Showing Up
- Restart Godot after installation
- Check that `addons/visual_gasic/plugin.cfg` exists
- Verify the extension binary is in `addons/visual_gasic/bin/`

### Extension Failed to Load
- Ensure you downloaded the correct platform version
- Check Godot console for error messages
- Verify Godot version is 4.5 or newer

### Template Not Available
- Verify template is in the correct directory
- Check that `.template.cfg` exists in the template folder
- Restart Godot to refresh template list

### Build Issues
- Update godot-cpp submodule: `git submodule update --init --recursive`
- Install SCons: `pip install scons`
- Check compiler version meets requirements

---

## 📚 Next Steps

- Read the [Getting Started Guide](GET_STARTED.md)
- Check out [Examples](examples/)
- Join our [Community](COMMUNITY_HUB.md)
- Read the [Documentation](docs/)

---

## 🔗 Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **Issues**: https://github.com/xgreenrx-star/VisualGasic/issues
- **Documentation**: [docs/](docs/)
- **License**: GPL v3

# VisualGasic — Installation & Quick Start 🚀

This document explains how to build the VisualGasic native module, install the editor plugin into a Godot project, and verify the plugin/toolbox is available in the editor.

---

## Prerequisites

- Linux (tested on distributions with standard toolchains)
- Godot 4.x (this repo was tested with **Godot 4.5.1**)
- SCons (build system)
- A C++ toolchain (e.g., GCC or Clang) and standard build tools
- Python 3
- Recommended: run the commands from the repository root (where `SConstruct` is located)

---

## 1) Build the native VisualGasic library 🔧

1. Ensure dependencies are installed (example for Debian/Ubuntu):

```bash
sudo apt update
sudo apt install build-essential scons python3 pkg-config git
```

2. Build the module (editor build):

```bash
# from repo root
# Use -j$(nproc) to speed up builds on multicore systems
scons platform=x11 target=editor -j$(nproc)
```

Notes:
- The exact scons options may vary per environment (platform, bits, etc.). Adjust `platform`, `target`, and extra flags as needed.
- The produced library will look like `libvisualgasic.linux.editor.x86_64.so` (filename may include platform/arch tags).

---

## 2) Install into a Godot project 🧩

A convenient example project is included at `examples/assetlibs/converted` (the converted GodotStarterAssets with VisualGasic integration).

1. Copy the built editor library into the project's addon bin folder. Example:

```bash
# Example path -- adapt to the actual built filename
cp build/libvisualgasic.*.so examples/assetlibs/converted/addons/visual_gasic/bin/
```

2. Make sure the editor-target filename matches what Godot expects (it usually does). The important part is that the shared library exports `visual_gasic_library_init` (see troubleshooting below).

3. Open the Godot project (File → Open), or from the command line:

```bash
/path/to/Godot_v4.5.1-stable_linux.x86_64 --path examples/assetlibs/converted
```

4. Enable the plugin: Project → Project Settings → Plugins → enable `VisualGasic`.

---

## 3) Verify plugin & toolbox 👀

We include `tools/verify_toolbox.gd` — an EditorScript that checks whether the native toolbox is registered and lists available tools.

To run it:
- Open the editor, open the Script Editor, load `tools/verify_toolbox.gd` and run it as an EditorScript (or use the EditorScript menu).

Look for console output similar to:
```
VisualGasic: C++ editor init reached. Registering editor classes...
ClassDB checks -> Toolbox:true ToolButton:true Syntax:true Language:true
VisualGasic: Native Toolbox instantiated successfully
```

---

## Troubleshooting ⚠️

- Plugin is disabled with parse errors:
  - Check `Project > Editor > Output` or the terminal where Godot was started to see parse-related messages (e.g., stray characters or invalid GDScript constructs). Fix any syntax problems in `addons/visual_gasic/` scripts.

- Toolbox not present or ClassDB checks false:
  - Ensure you copied the *editor* build library into `addons/visual_gasic/bin` and that it exports `visual_gasic_library_init`:

```bash
nm -D examples/assetlibs/converted/addons/visual_gasic/bin/libvisualgasic.*.so | grep visual_gasic_library_init
```

  - If the symbol is missing, rebuild with the editor target (see Build step).

- Build fails at some commits (during development or bisect):
  - Some historical commits may be missing generated headers or sources (e.g., tokenizer or parser helpers). Ensure submodules are initialized or use a working commit.

- Scene warnings about invalid ext_resource UIDs after conversion:
  - Open affected scenes from the editor and re-link the `.bas` script resources (or save the scene again) to update `ext_resource` entries.

---

## Contributing & Pull Requests ✨

1. Create a feature branch:

```bash
git checkout -b wip/your-feature-name
```

2. Commit changes and push:

```bash
git add <files>
git commit -m "feat: <short description>"
git push -u origin wip/your-feature-name
```

3. Open a PR from your branch and include: summary, steps to reproduce, test notes, and any platform caveats.

---

## Quick reference commands

- Build: `scons platform=x11 target=editor -j$(nproc)`
- Inspect library exports: `nm -D <libfile> | grep visual_gasic_library_init`
- Run Godot with project path: `./Godot_v4.5.1-stable_linux.x86_64 --path examples/assetlibs/converted`

---

If you'd like, I can also add an `INSTALLATION.md` to the converted project folder, or create a small CI job that attempts to open the project headlessly to detect plugin load failures. ✅

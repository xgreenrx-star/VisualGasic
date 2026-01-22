# VisualGasic - Godot VB6 Support

[![CI](https://github.com/your-org/your-repo/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/your-repo/actions/workflows/ci.yml)

This project introduces a custom Scripting Language to Godot 4.x via GDExtension, emulating the syntax and flow of Visual Basic 6.

> Note: Replace `your-org/your-repo` in the badge above with your repository path to enable the CI status badge.

## Structure

*   `godot-cpp/` - Git submodule for Godot C++ Bindings.
*   `src/` - C++ source code for the extension.
*   `demo/` - Godot project for testing. The built library goes into `demo/bin/`.

## memory

1.  **Install SCons**:
    *   Linux: `sudo apt install scons` or `pip install scons`
    *   Windows: `pip install scons`
2.  **Build**:
    Open a terminal in this folder and run:
    ```bash
    scons platform=linux target=template_debug
    ```
    (Replace `linux` with `windows` or `macos` as needed).

## Usage

1.  Open `demo/project.godot` in Godot 4.x.
2.  Create a new script. You should see "VisualGasic" as a language option (once the plugin matures) or you can create `.bas` files and Godot will recognize them.
3.  Currently, the language registers itself but execution is a placeholder.

## Documentation
*   [Importing VB6 Projects](IMPORTING_VB6.md) - How to use the built-in Importer.
*   [Language Keyword Reference](docs/manual/keywords.md) - List of commands and functions.
*   [IDE Tools Guide](docs/manual/ide_tools.md) - Layout of the Menu Editor, Object Browser, and more.

### Builtin Functions

Core builtin functions and the extension points for adding or overriding them are documented in `docs/BUILTINS.md`.
This covers expression- and statement-level builtins, base-object handlers, and the small `VisualGasicInstance` wrappers used by the builtins implementation.

## Development

The core logic is in `src/visual_gasic_script.cpp` and `src/visual_gasic_language.cpp`. You will need to implement a parser (or integrate an existing BASIC parser) in `instance_create` to actually run code.

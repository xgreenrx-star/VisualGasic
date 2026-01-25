# VisualGasic IDE Tools

VisualGasic extends the Godot Editor with several tools designed to make Visual Basic 6 developers feel at home. These tools can be accessed via the **Project > Tools** menu or the **VisualGasic Toolbox**.

## Menu Editor
**Location**: `Project > Tools > Visual Gasic Menu Editor`

A visual editor for constructing `MenuBar` hierarchies.
*   **Caption**: The text displayed to the user.
*   **Name**: Key for code access (e.g., `mnuFileOpen`).
*   **Hierarchy**: Use Indent/Outdent to create submenus.
*   **Shortcuts**: Define keyboard shortcuts (Ctrl+C, etc.).

## Project Properties
**Location**: `Project > Tools > Visual Gasic Project Properties`

A simplified dialog for managing game configuration.
*   **Startup Object**: Select which Form/Scene runs when you press F5.
*   **Project Name**: Updates the window title.
*   **Dimensions**: Set the default window resolution (Width/Height).

## Object Browser
**Location**: `Project > Tools > Visual Gasic Object Browser`

A searchable reference guide for the VisualGasic language.
*   Lists all built-in Functions, Subs, and Keywords.
*   Provides syntax examples and descriptions.
*   Organized by category (Math, Graphics, AI, etc.).

## Tab Order Editor
**Location**: `Project > Tools > Visual Gasic Tab Order`

Visually rearrange the Focus order of controls.
1.  Select a Form or Container in the Scene tree.
2.  Open the Tab Order tool.
3.  Select controls and move them Up/Down to change their sequence.

## New Form Wizard
**Location**: `VisualGasic Toolbox > New Form`

Quickly generate a new Form scene.
*   Creates a `Panel` (acting as a Window).
*   Automatically creates and attaches a helper `.bas` script.
*   Saves as `Form1.tscn`, `Form2.tscn`, etc.

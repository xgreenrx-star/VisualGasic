# VisualGasic IDE Tools

VisualGasic extends the Godot Editor with several tools designed to make Visual Basic 6 developers feel at home. These tools can be accessed via the **Project > Tools** menu or the **VisualGasic Toolbox**.

---

## High-Priority Features (Complete)

### Watch Window
**Location**: `Immediate Window > Watch Tab`

Enhanced variable watching with color-coded changes.
*   **Color-Coded Values**: Yellow = changed, Green = unchanged
*   **Context Menu**: Right-click to delete watches
*   **Persistence**: Watch expressions saved between sessions
*   **Previous Value Tracking**: Compare current vs. previous values

### Snap-to-Grid & Alignment Tools
**Location**: `2D Canvas Editor Toolbar`

Professional form designer tools for precise control placement.
*   **Grid Snapping**: Configurable grid size (8px, 16px, 32px, etc.)
*   **Grid Overlay**: Visual grid drawn on form canvas
*   **Alignment**: Left, Center, Right, Top, Middle, Bottom
*   **Distribution**: Distribute Horizontally/Vertically
*   **Sizing**: Make Same Width/Height/Both

### Call Stack Panel
**Location**: `Debugger > Call Stack`

Visual call stack display during debugging.
*   **Tree View**: Frame #, function name, file:line
*   **Navigation**: Click to jump to stack frame
*   **Color-Coded**: Current frame highlighted
*   **Auto-Request**: Call stack fetched on breakpoint hit

### IntelliSense / Autocomplete
**Location**: Automatic in `.vg` script files

Full code completion for VB6-style programming.
*   **50+ VB6 Keywords**: Dim, Sub, Function, If, For, etc.
*   **12 VB6 Data Types**: Integer, Long, String, Boolean, etc.
*   **80+ Built-in Functions**: With signatures and descriptions
*   **30+ Godot Types**: Node, Control, Sprite2D, etc.
*   **14 Code Snippets**: sub, func, if, for, select, try, class

### Breakpoint Conditions
**Location**: Right-click on breakpoint gutter

Conditional breakpoints for advanced debugging.
*   **Condition Expressions**: Break when expression is true
*   **Hit Count**: Equals, greater-equal, or multiple of N
*   **Log Messages**: Tracepoints with `{variable}` substitution
*   **Temporary**: Auto-delete after first hit

---

## Medium-Priority Features (Complete)

### Recent Projects List
**Location**: `Project > Tools > Recent Projects`

Quick access to recently opened projects.
*   **Stores Last 10**: Projects automatically tracked
*   **Pin Favorites**: Keep important projects at top (📌)
*   **Clear History**: Remove all or individual entries
*   **Tooltip**: Shows full path on hover

### Code Formatter / Beautifier
**Location**: Coming to Tools menu

Automatic code formatting for .vg files.
*   **Auto-Indent**: Based on blocks (Sub/End Sub, If/End If)
*   **Operator Spacing**: Consistent spacing around `=`, `+`, etc.
*   **Keyword Capitalization**: `if` → `If`, `dim` → `Dim`
*   **100+ Keywords**: Properly formatted
*   **Format Selection**: Format only selected code

### Find All References
**Location**: Right-click on identifier

Show all usages of a variable, Sub, or Function.
*   **Results Panel**: Tree view with file:line listings
*   **Click to Navigate**: Jump to any reference
*   **Filter by Type**: Declaration, Read, Write, Call
*   **Search All .vg Files**: Workspace-wide search

### Go to Definition
**Location**: Ctrl+Click or F12 on identifier

Navigate to Sub/Function/Variable declarations.
*   **Ctrl+Click**: Jump to definition
*   **F12 Key**: Alternative shortcut
*   **Cross-File**: Works across all .vg files
*   **Symbol Types**: Sub, Function, Property, Class, Variable, Const

### Form Preview Toolbar
**Location**: `2D Canvas Editor Toolbar`

Quick form testing without full game launch.
*   **Preview Form Button**: Opens form in popup window
*   **F5 Shortcut**: Quick preview
*   **Preview + Debug**: Connect to Immediate Window
*   **Form Events**: Fires Form_Load, Form_Shown

### Form Designer Canvas Enhancements
**Location**: Form Designer canvas

Precision tools for control layout and form editing.
*   **Ctrl+Arrow Nudge**: Move selected controls by exactly 1 pixel
*   **Shift+Ctrl+Arrow Nudge**: Move selected controls by grid size
*   **Ctrl+Scroll Zoom**: Zoom the canvas in/out (25%–400%, 10% steps)
*   **Form Resize Handles**: 8 draggable handles on form edges and corners
*   **Z-Order Controls**: Right-click → Bring to Front / Send to Back
*   **Lock Position**: Right-click → Lock Position to prevent accidental moves
*   **Status Bar**: Live display of form name, dimensions, grid size, zoom %, and dirty indicator (`*`)
*   **Dirty Indicator**: Asterisk `*` appears in the status bar when the form has unsaved changes
*   **Undo/Redo Feedback**: Status bar flashes "Undo" / "Redo" on each operation

### Save All
**Location**: `File > Save All` or `Ctrl+Shift+S`

Save both the form layout (.tscn) and the code file (.vg) simultaneously.
*   **Keyboard Shortcut**: Ctrl+Shift+S
*   **Saves Form + Code**: Both files saved in one action
*   **Clears Dirty Flag**: The `*` indicator disappears after save
*   **Status Flash**: Shows "All files saved" briefly in status bar

### Properties Panel Enhancements
**Location**: Properties panel (right side)

Improved usability for the VB6-style Properties panel.
*   **🔍 Filter Search**: Type to filter properties by name — real-time, case-insensitive
*   **Hover Tooltips**: Every property label shows a description tooltip on hover
*   **Zebra Striping**: Alternating row backgrounds for easier visual scanning
*   **Numeric Stepping**: Arrow keys ±1, Shift+Arrow keys ±10 (±100 for Interval)
*   **Color Picker**: Click any color swatch for a full ColorPicker with alpha support

### Go To Line
**Location**: Code Editor — `Ctrl+G`

Jump to any line number in the current .vg script.
*   **Keyboard Shortcut**: Ctrl+G
*   **Shows Line Range**: Dialog displays valid range (1–N)
*   **Enter to Jump**: Type a number and press Enter
*   **Centers Viewport**: Editor scrolls to show the target line centered

### Keyboard Shortcuts Reference

For a complete list of all keyboard shortcuts, see [IDE Keyboard Shortcuts](IDE_SHORTCUTS.md).

---

## Nice-to-Have Features (Complete)

### Linting / Warnings
**Location**: Automatic in `.vg` files

Static analysis for code quality.
*   **VG001**: Unused variable detection
*   **VG002**: Undefined variable usage
*   **VG003**: Unreachable code warnings
*   **VG004**: Missing End statements
*   **VG005**: Deprecated syntax warnings
*   **VG006**: Empty block detection
*   **VG007**: Unused parameter warnings
*   **VG008**: Shadowed variable detection
*   **VG009**: Implicit Variant warnings
*   **VG010**: Missing Return warnings

### Snippet Manager
**Location**: IntelliSense / Autocomplete

User-defined code snippets with placeholders.
*   **40+ Built-in Snippets**: VB6 patterns ready to use
*   **8 Categories**: Control Flow, Loops, Procedures, Properties, Error Handling, Declarations, Events, Game, Utility
*   **Tabstop Placeholders**: `${1:default}` syntax
*   **User Snippets**: Create and save custom snippets
*   **Persistence**: Saved to `vg_snippets.cfg`

**Built-in Snippet Prefixes**:
| Prefix | Description |
|--------|-------------|
| `if` | If-Then-End If |
| `ife` | If-Then-Else-End If |
| `sel` | Select Case |
| `for` | For-Next loop |
| `fore` | For Each loop |
| `dow` | Do While loop |
| `sub` | Sub procedure |
| `func` | Function |
| `try` | Try-Catch |
| `prop` | Property Get/Let |
| `ready` | Godot _ready() |
| `proc` | Godot _process() |

### Theme Support
**Location**: Editor Settings (Coming Soon)

Visual theme options for the VB6 experience.

**Built-in Themes**:
| Theme | Description |
|-------|-------------|
| **VB6 Classic** | Authentic blue background, yellow text, cyan keywords |
| **Modern Dark** | VS Code-style dark theme |
| **Modern Light** | Clean light theme |
| **High Contrast** | Accessibility-focused |
| **Solarized Dark** | Popular color scheme |

*   **Custom Themes**: Create and save your own
*   **Color Options**: Background, text, keywords, strings, comments, etc.
*   **Font Settings**: Font name, size, bold keywords
*   **CSS Export**: Export theme for documentation

---

## Classic IDE Tools

### Menu Editor
**Location**: `Project > Tools > Visual Gasic Menu Editor`

A visual editor for constructing `MenuBar` hierarchies.
*   **Caption**: The text displayed to the user.
*   **Name**: Key for code access (e.g., `mnuFileOpen`).
*   **Hierarchy**: Use Indent/Outdent to create submenus.
*   **Shortcuts**: Define keyboard shortcuts (Ctrl+C, etc.).

### Project Properties
**Location**: `Project > Tools > Visual Gasic Project Properties`

A simplified dialog for managing game configuration.
*   **Startup Object**: Select which Form/Scene runs when you press F5.
*   **Project Name**: Updates the window title.
*   **Dimensions**: Set the default window resolution (Width/Height).

### Object Browser
**Location**: `Project > Tools > Visual Gasic Object Browser`

A searchable reference guide for the VisualGasic language.
*   Lists all built-in Functions, Subs, and Keywords.
*   Provides syntax examples and descriptions.
*   Organized by category (Math, Graphics, AI, etc.).

### Tab Order Editor
**Location**: `Project > Tools > Visual Gasic Tab Order`

Visually rearrange the Focus order of controls.
1.  Select a Form or Container in the Scene tree.
2.  Open the Tab Order tool.
3.  Select controls and move them Up/Down to change their sequence.

### New Form Wizard
**Location**: `VisualGasic Toolbox > New Form`

Quickly generate a new Form scene.
*   Creates a `Window` with VGFormBase functionality.
*   Automatically creates and attaches a `.vg` script.
*   Includes sample code with Form_Load, Form_Shown events.
*   Saves as `Form1.tscn`, `Form2.tscn`, etc.

**Form Templates**:
| Category | Templates |
|----------|-----------|
| **VB6 Classic** | Blank Form, About Box, Login Form, Splash Screen, Data Entry Form, MDI Parent Form |
| **Game Forms** | Main Menu, Settings, HUD, Inventory, Dialogue |
| **Platform** | macOS, Linux, Windows styles |
| **Custom** | User-saved templates |

### Components Dialog
**Location**: `Project > Visual Gasic Components...`

A VB6-style dialog for managing optional and custom controls in the Toolbox.
*   **Optional Components**: Enable/disable advanced controls
*   **Custom Controls**: Browse and add your own .tscn prototypes
*   **Custom Icons**: Each custom control gets a gear ⚙ fallback icon automatically. To provide a specific icon, add an SVG entry keyed to the control name in `vb6_toolbox_icons.gd` (see the [Custom Wobbly Form](../tutorials/custom_wobbly_form.md#custom-toolbox-icons) tutorial for details)
*   **Persistent Config**: Settings saved to `custom_components.cfg`
*   **Double-Click Toggle**: Quickly add/remove components

**Built-in Optional Components**:
| Component | Description |
|-----------|-------------|
| StatusBar | Status bar with panels |
| Toolbar | Button toolbar container |
| Animation | Sprite animation control |
| Calendar | Month/date picker calendar |
| DatePicker | Date selection control |
| MaskedEdit | Input mask text box |
| Winsock | Network socket control |
| UpDown | Spin button control |
| ListView | Multi-column list view |
| ImageCombo | Image + text combo box |

### Rename Refactoring
**Location**: `Ctrl+R` in any `.vg` script

Scope-aware variable renaming.
*   **Current Scope**: Rename only in current Sub/Function
*   **Entire Script**: Rename throughout the file
*   **Everywhere**: Rename in all .vg files
*   **Smart Matching**: Avoids strings and comments

# Visual Gasic Code Editor Manual

The embedded **Code** view in the Visual Gasic IDE (`.vg` files on forms and modules) is a full-featured editor built on Godot's `CodeEdit`, extended with VB6-style formatting, IntelliSense, debugging markers, and navigation.

For keyboard shortcuts only, see [IDE_SHORTCUTS.md](IDE_SHORTCUTS.md). For debugger panels and the Immediate Window, see [ide_tools.md](ide_tools.md) and [IMMEDIATE_WINDOW.md](../IMMEDIATE_WINDOW.md).

The **standalone Visual Gasic IDE** code surface is **experimental Alpha** — see [VG_IDE_ALPHA.md](VG_IDE_ALPHA.md). On Godot’s **Script** screen you can opt into the same embedded editor as a **floating panel** over the native `.vg` tab: **Project Settings → Vg → Editor → Floating Vg Code Editor On Script** (`vg/editor/floating_vg_code_editor_on_script`).

---

## Opening code

| Action | Result |
|--------|--------|
| **Code** toolbar button | Switch the main pane to the embedded code editor |
| Double-click a control on the form canvas | Jump to that control's event handler |
| **Project** tree → form or module | Open the `.vg` file |
| **Code Navigator** → Object / Procedure dropdown | Jump to a Sub, Function, or module member |

---

## Navigating symbols

### Go To Definition

Jump from a **use** of a name to where it is **declared**.

| Method | How |
|--------|-----|
| **Right-click menu** | Place the caret on the identifier, right-click → **Go To Definition** |
| **Ctrl+Click** | Hold **Ctrl** and click the identifier (Ctrl+hover underlines recognized symbols) |

**Resolves these symbol kinds** (current file first, then imported modules, then workspace `.vg` scan):

- `Sub`, `Function`, `Property`
- Variables and constants (`Dim`, `Public`, `Private`, `Const`, `ReDim`)
- `Enum` and `Type` blocks
- Line labels (`ErrorHandler:`)
- Public members of **Import** modules (including `ModuleName.Member` qualified calls)

Cross-file navigation opens the target module and scrolls to the declaration line.

> **Note:** Right-click **Go To Definition** uses the **caret** position, not the mouse position. Click the identifier first (or arrow to it), then right-click. **Ctrl+Click** uses the click position directly.

### Find All References

| Method | How |
|--------|-----|
| **Right-click menu** | Caret on identifier → **Find All References** |
| **Ctrl+Shift+F** | Same (when the code editor has focus) |

Opens the **Find References** bottom panel with file:line hits across the workspace. Click a result to jump there.

### Call Hierarchy

| Method | How |
|--------|-----|
| **Right-click menu** | Caret on a `Sub`/`Function` name → **Call Hierarchy** |
| **Ctrl+Shift+H** | Same |

Shows callers of the selected procedure (uses the Find References panel in caller mode).

### Other navigation

| Action | Shortcut |
|--------|----------|
| Go To Line… | **Ctrl+G** |
| Go to Matching Block | **Ctrl+Shift+]** (`If`↔`End If`, `Sub`↔`End Sub`, …) |
| Toggle Bookmark | **Ctrl+B** |
| Next / Previous Bookmark | **Ctrl+Shift+B** / **Ctrl+Alt+B** |
| Code Navigator Object dropdown | Includes **── Modules ──** for imported `.vg` files |

---

## Right-click context menu

Right-click anywhere in the code editor (not the gutter). Menu items match the live editor in `vg_code_edit.gd`.

### Clipboard & selection

| Menu item | Shortcut | Notes |
|-----------|----------|-------|
| Cut | Ctrl+X | Disabled with no selection |
| Copy | Ctrl+C | Disabled with no selection |
| Paste | Ctrl+V | |
| Select All | Ctrl+A | |

### Formatting & comments

| Menu item | Shortcut | Notes |
|-----------|----------|-------|
| Fix Indentation | Ctrl+Shift+I | Re-indent selection (or whole file) with VB6 block rules |
| Comment/Uncomment | Ctrl+' | Toggle `'` comment prefix per line |
| Wrap in Comment Block | — | Wrap selection in `' … '` block comment |

### Navigation & analysis

| Menu item | Shortcut | Notes |
|-----------|----------|-------|
| Go To Line… | Ctrl+G | Line-number dialog |
| Go To Definition | Ctrl+Click | Caret must be on the symbol (see above) |
| Find All References | Ctrl+Shift+F | Workspace-wide usages |
| Call Hierarchy | Ctrl+Shift+H | Who calls this Sub/Function |
| Toggle Breakpoint | F9 | Gutter click also toggles |
| Toggle Bookmark | Ctrl+B | Blue bookmark in gutter |

### Line editing

| Menu item | Shortcut | Notes |
|-----------|----------|-------|
| Move Lines Up | Alt+Up | |
| Move Lines Down | Alt+Down | |
| Duplicate Lines | Ctrl+Shift+D | |
| Delete Lines | Ctrl+Shift+K | |

### Folding

| Menu item | Notes |
|-----------|-------|
| Fold All Procedures | Collapse every `Sub` / `Function` / `Property` body |
| Unfold All | Expand all folded regions |

### Selection tools

| Menu item | Notes |
|-----------|-------|
| Sort Lines | **Disabled** unless two or more lines are selected; sorts A→Z |

### Sprite data (contextual)

| Menu item | Notes |
|-----------|-------|
| Edit Sprite Data as Image… | **Disabled** unless the caret is inside a `*Sprite Data` labeled block; opens the Sprite Editor on that sheet |

### File path submenu (contextual)

When the caret or click is on a `res://…` or `user://…` string literal, the menu shows **File "…"** (enabled). Submenu actions depend on file type:

| Action | When available |
|--------|----------------|
| Select file… | Always (native file picker) |
| Play audio | Audio path |
| Preview image / Preview as text | Image or text path |
| Open in Hex Editor | Binary / unknown paths |
| Open in Sprite Editor | Image paths |
| Create file if missing | Output paths that do not exist yet |
| Reveal in File Browser | Always |
| Show in folder | Always |
| Copy path | Always |
| Open externally | When the file exists |
| Find other uses of this path | Always |

Right-click directly on a path string for the fastest access; the submenu label shows a shortened path.

### Surround With ▶

Wraps the selection (or inserts an empty block at the caret):

| Submenu item | Wraps in |
|--------------|----------|
| If...End If | Conditional |
| For...Next | Counting loop |
| Sub...End Sub | Subroutine skeleton |
| Try...Catch | Error handler |
| With...End With | `With` block |
| Select Case...End Select | Multi-branch selector |

Selection is auto-indented inside the new block.

### View toggles (check items)

| Menu item | Effect |
|-----------|--------|
| Word Wrap ✓ | Wrap long lines at editor boundary |
| Show Whitespace ✓ | Visible dots (spaces) and arrows (tabs) |
| Minimap ✓ | Zoomed-out file strip on the right edge |

---

## Automatic editor behavior

Features that need no menu action:

- **Syntax highlighting** — VB6-style keywords, strings, comments
- **IntelliSense** — **Ctrl+Space**; `Module.` dot-completion for imports
- **Parameter hints** — typing `(` after a built-in function name
- **Smart bracket completion** — type `}` to close blocks
- **Procedure separator lines** — horizontal rule above each `Sub` / `Function` header
- **Highlight word under caret** — other occurrences tinted (scope-aware for locals)
- **Semantic underlines** — parameters, locals, module vars, constants
- **Change tracking gutter** — yellow = edited since open, green = saved baseline
- **Pretty listing on save** — keyword case, operator spacing, indent normalize

---

## Related documentation

| Topic | Document |
|-------|----------|
| Keyboard shortcut card | [IDE_SHORTCUTS.md](IDE_SHORTCUTS.md) |
| IDE panels (Profiler, AI Pair, Watch, …) | [ide_tools.md](ide_tools.md) |
| Breakpoints & debugging | [debugging.md](debugging.md) |
| Sprite `Data` blocks | [SPRITE_EDITOR_MANUAL.md](SPRITE_EDITOR_MANUAL.md) |
| Hex Editor for binary paths | [HEX_EDITOR_MANUAL.md](HEX_EDITOR_MANUAL.md) |

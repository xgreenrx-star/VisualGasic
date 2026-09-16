# Working Nodes — Manual

**Working Nodes** is a visual logic editor built into the VisualGasic IDE. It lets you design game behaviour by connecting nodes on a graph instead of writing code line-by-line. You build up sequences of **Trigger** nodes (On Start, Move, Rotate, Spawn, etc.) wired together with coloured execution arrows, grouped into numbered groups that fire in sequence.

Working Nodes appears as the **🧠 Working Nodes** button in the VG IDE toolbar.

---

## Table of Contents

1. [Opening Working Nodes](#1-opening-working-nodes)
2. [The Interface](#2-the-interface)
3. [Node Types](#3-node-types)
4. [Your First Program — Step by Step](#4-your-first-program--step-by-step)
5. [Working with Groups](#5-working-with-groups)
6. [Smart Wiring](#6-smart-wiring)
7. [The Node Palette (Shift+A)](#7-the-node-palette-shifta)
8. [Copy, Paste & Duplicate](#8-copy-paste--duplicate)
9. [Snippets](#9-snippets)
10. [Node Operations (Right-click Menu)](#10-node-operations-right-click-menu)
11. [Breakpoints](#11-breakpoints)
12. [Live VG Code Preview](#12-live-vg-code-preview)
13. [Graph Validator](#13-graph-validator)
14. [Execution-order Animation](#14-execution-order-animation)
15. [Exporting Your Graph](#15-exporting-your-graph)
16. [Saving and Loading](#16-saving-and-loading)
17. [Keyboard Shortcuts](#17-keyboard-shortcuts)
18. [File Format Reference](#18-file-format-reference)

---

## 1. Opening Working Nodes

1. Open your project in the **VisualGasic IDE** (click the *Visual Gasic IDE* tab in the Godot editor's centre screen selector).
2. Look at the right end of the VG menu bar for the plugin strip — you will see buttons for AGCK, VG3D, Web Publish, and **🧠 Working Nodes**.
3. Click **🧠 Working Nodes** to enter the Working Nodes workspace.

> **Screenshot placeholder**
>
> ![Working Nodes toolbar button](../../../../../../docs/screenshots/Screenshot%20at%202026-04-21%2013-41-33.png)
> *The Working Nodes editor with an Event node, an Action node, and a Math node connected. Group 1 is active in the sidebar.*

The workspace opens with a default graph containing one **Trigger** (Event) node and one **Action** node already placed for you.

---

## 2. The Interface

```
Row 1: New | Save | Save As | Load | Export VG | 2D Scene | 3D Scene
       + Event  + Action  + Math

Row 2: Triggers: On Start | Move | Rotate | Scale | Alpha | Color
                 Spawn | Stop | Toggle | Play SFX | Follow | Shake | Pulse | Animate

Row 3: Utility: +VecM | +MapR | +Bool | +Sw | +Cmp | +Rnd
                Export: GD Script

Row 4: Connect | +Group | Assign Group | All wires | Smart wiring
       Wire Group: [All Groups] | Node Color: [■]

Row 5: Preview | Validate | +Joints | Del | Copy | Paste
       Snippet | Snippets... | Shift+A palette | Help
```

Left sidebar: **Selected Groups** list + help text.  
Right area: **Graph Canvas** (nodes + wires).  
Optional below: **VG Code Preview** panel (toggled with Preview).

---

## 3. Node Types

Working Nodes has two main workflows: **Trigger nodes** (primary) and **Classic nodes**.

### Trigger Nodes (primary)

Add them from the **Triggers:** toolbar row or by right-clicking the canvas.

| Icon | Node | Parameters |
|------|------|------------|
| ▶ | **On Start** | *(none)* — fires at scene load |
| ↔ | **Move** | Group ID, X, Y, Duration, Easing |
| ↻ | **Rotate** | Group ID, Degrees, Duration, Lock Rot |
| ⤡ | **Scale** | Group ID, Scale X, Scale Y, Duration |
| ◑ | **Alpha** | Group ID, Alpha (0–1.0), Duration |
| ?? | **Color** | Channel, R, G, B, Duration |
| ✦ | **Spawn** | Group ID, Delay |
| ◼ | **Stop** | Group ID |
| ?? | **Toggle** | Group ID, Active (0/1) |
| ♪ | **Play SFX** | Sound (path), Volume, Pitch |
| ⟿ | **Follow** | Group ID, Target Group, X Mod, Y Mod, Duration |
| ⚡ | **Shake** | Strength, Interval, Duration |
| ?? | **Pulse** | Group ID, R, G, B, Fade In, Hold, Fade Out |
| ▷ | **Animate** | Group ID, Animation (index), Speed |

The **green** execution port on the right chains nodes in sequence. **Orange** value ports on parameter rows accept Math node outputs instead of typed values.

### Classic Nodes

| Icon | Type | Colour | Purpose |
|------|------|--------|---------|
| ⚡ | **Event** | Blue | Generic event (On Start, On Touch, On Timer, On Signal) |
| ⚙ | **Action** | Green | Generic action with freeform dropdown |
| ∑ | **Math** | Orange | Arithmetic (Add, Subtract, Multiply, Divide, Clamp, etc.) |

### Utility Nodes (via Palette)

| Category | Kinds |
|----------|-------|
| **Logic** | Condition, Switch, Compare |
| **Data** | Variable, Note |
| **Control flow** | Loop, Sequence, Function |
| **Math extensions** | VectorMath, MapRange, BoolMath, Random |

Every node has a **Group: N** label and a resizable corner.

---

## 4. Your First Program — Step by Step

This walkthrough creates a graph that moves a group when the scene starts.

### Step 1 — Open a new graph

Click **New** in the toolbar. You will see:

* **On Start 1** — fires when the scene loads (green output port only).
* **Move 2** — moves a group (green input + output, plus parameter fields).

They are already wired together.

### Step 2 — Set Move parameters

Click the **X** field in Move 2 and type `100`. Leave **Duration** at `0.5`. This tweens Group 1 nodes 100 units to the right over half a second.

### Step 3 — Add another node

Right-click the canvas → choose **◑ Alpha** to add an Alpha node. Wire Move 2’s right green port to Alpha’s left green port. Set **Alpha** to `0.5`.

### Step 4 — Validate

Click **✓ Validate**. You should see: *“✔ No issues found. Graph looks good!”*

### Step 5 — Preview the VG code

Click **◐ Preview**. The panel below the canvas shows:

```vb
Sub Form_Load()
    Call WN_Move(1, 100, 0, 0.5)
    Call WN_Alpha(1, 0.5, 0.5)
End Sub
```

### Step 6 — Export

Click **► Export VG** to save as a `.vg` file, or **⬡ 2D Scene** to generate a Godot 2D `.tscn` + companion `.vg` script. A root-type selector appears (choose `Node2D`, `CharacterBody2D`, etc.).

---

## 5. Working with Groups

Groups are the core organisational feature of Working Nodes. Every node belongs to a group. Wires are colour-coded by their source node's group.

### Creating a Group

1. Select one or more nodes on the canvas.
2. Click **+ Group** in the toolbar.
3. A new group is created and the selected nodes are assigned to it automatically.

Each group gets a unique colour derived from its ID.

### Assigning Nodes to a Group

1. Select the nodes you want to move.
2. In the **Selected Groups** sidebar, click the target group to highlight it.
3. Click **Assign Group** in the toolbar — all selected nodes are reassigned.

### Filtering Wires by Group

The **Wire Group** dropdown (toolbar row 1) and the **Selected Groups** sidebar both control wire visibility:

* **Wire Group dropdown** — choose a specific group to show only that group's wires; choose *All Groups* to show everything.
* **Selected Groups sidebar** — multi-select groups to show wires from any combination.
* **All wires toggle** — force every wire visible regardless of selection.

> **Screenshot placeholder**
>
> *[Add a screenshot showing the group sidebar with two groups selected and their wires highlighted]*

---

## 6. Smart Wiring

Smart wiring makes graphs easier to read by automatically routing wires around each other rather than drawing direct diagonal lines.

### Enabling / Disabling

The **Smart wiring** toggle button (toolbar row 1) switches between:

| Mode | Behaviour |
|------|-----------|
| On (default) | Wires are routed via a mid-column with lane offsets — up to 7 wires through the same horizontal band are spread out vertically |
| Off | Direct straight lines between node ports |

### Wire Labels

When a node is of type **Variable**, its outgoing wires display the node's title as a short label at the wire's midpoint. This makes it easy to track which value flows along each wire at a glance.

### Wire Colour

Every wire inherits the colour of the **source node's** node-colour setting. Change a node's colour with the **Node Color** picker (toolbar row 1) to visually group related wires.

---

## 7. The Node Palette (Shift+A)

The node palette gives quick access to all 25 node kinds without hunting through the toolbar buttons.

**How to open:**

* Press **Shift+A** anywhere on the canvas, **or**
* Click the *Shift+A → palette* hint label in toolbar row 2.

The palette opens as a floating window with:

* A **search box** at the top — type any part of a node's name to filter instantly.
* A scrollable **item list** — double-click any entry to insert that node at your mouse position.

The new node is placed exactly where your cursor was when you pressed Shift+A.

> **Screenshot placeholder**
>
> *[Add a screenshot of the palette popup with the search box and item list visible]*

---

## 8. Copy, Paste & Duplicate

### Copy & Paste (multi-node)

1. Select the nodes you want to copy (rubber-band drag or Shift+click).
2. Press **Ctrl+C** or click **⧉ Copy** in toolbar row 2.
3. Press **Ctrl+V** or click **⬡ Paste** — the nodes reappear 30 px offset from the originals with the same types, titles, colours, and inter-node wires.

Paste also works across sessions — the clipboard is synced to the system clipboard so you can paste between different Working Nodes projects.

### Duplicate (single node)

Right-click a node → **Duplicate**. A copy appears 40 px below and to the right.

---

## 9. Snippets

Snippets let you save a named subgraph and re-insert it into any project later.

### Saving a Snippet

1. Select the nodes that form the pattern you want to save.
2. Click **📌 Snippet** in toolbar row 2.
3. A dialog asks for a snippet name — type it and press **OK**.

Snippets are saved to `user://wn_snippets.json` (in Godot's user data folder) and survive project restarts.

### Inserting a Snippet

1. Click **📋 Snippets…** in toolbar row 2.
2. The snippet browser window opens — double-click any saved snippet name.
3. The nodes are inserted at position (300, 300) offset, with new unique names to avoid collisions.

> **Screenshot placeholder**
>
> *[Add a screenshot of the Snippets… browser window showing saved snippet names in the list]*

---

## 10. Node Operations (Right-click Menu)

### Right-click on a node

Right-clicking any node opens its context menu:

| Menu Item | Effect |
|-----------|--------|
| **Rename** | Opens a small dialog — type the new title and press OK |
| **Duplicate** | Creates a copy 40 px offset from the original |
| **?? Toggle Breakpoint** | Toggles a red debug border on the node |
| **?? Delete** | Removes the node and its connections |

**Inline rename** — double-clicking a node opens the rename dialog directly.

### Right-click on the canvas

Right-clicking empty canvas space opens a context menu:

| Menu Item | Effect |
|-----------|--------|
| ▶ On Start … ▷ Animate | Add any of the 14 trigger nodes |
| + Event / + Action / + Math | Add a classic generic node |
| Select All | Select every node on the canvas |
| Clear Graph | Reset to a fresh On Start + Move graph |

---

## 11. Breakpoints

Breakpoints visually mark nodes that you want to pay attention to during debugging or export review. A node with a breakpoint gets a thick **red border** instead of its normal colour border.

### Setting / Clearing

* Right-click → **🔴 Set Breakpoint** (or **Remove Breakpoint** if already set).
* Breakpoint state is saved in the `.wnodes` file.

### Effect on Export

When you export to VG code, breakpointed nodes emit a `' [BREAKPOINT]` comment marker in the generated source so you can identify them easily.

> **Screenshot placeholder**
>
> *[Add a screenshot of a graph node with the red breakpoint border active]*

---

## 12. Live VG Code Preview

The **◐ Preview** button (toolbar row 2) opens a read-only code panel docked below the canvas. It shows the VG code that the current graph would generate, updated instantly after every change.

Use this to:

* Confirm the graph translates to the logic you expect.
* Catch naming issues before export.
* Copy-paste snippets of the generated code into the VG code editor.

The preview uses the same code generator (`working_nodes_codegen.gd`) as the export buttons, so what you see is exactly what you get.

---

## 13. Graph Validator

Click **✓ Validate** (toolbar row 2) to run a static analysis of the graph. The validator checks for:

| Check | What it catches |
|-------|-----------------|
| No Event node | Graph has no ⚡ node — nothing would ever fire |
| Unreachable Action | An ⚙ node with no incoming wire — it can never execute |
| Self-connection | A wire from a node back to itself |

The result dialog lists all issues found, or shows *"✔ No issues found"* if the graph is clean.

> **Tip:** Always validate before exporting, especially for complex graphs.

---

## 14. Execution-order Animation

The execution-order animation shows the BFS (breadth-first) order in which nodes would fire at runtime. Every On Start / Event node is a starting point; downstream nodes receive order numbers as the traversal fans out.

This feature is accessible programmatically via `_highlight_exec_order_animated()`. Each node gets a temporary yellow numbered badge that fades in staggered, holds for 1.8 s, then fades out. Unreachable nodes do not receive a badge.

---

## 15. Exporting Your Graph

Working Nodes can output three formats from the same graph. All export buttons are in toolbar row 1.

### ▶ Export VG

Generates a `.vg` VisualGasic source file. The output structure:

```vb
' Working Nodes export
' Generated from: <project_stem>

' --- Group 1: "My Group" ---

Sub Trigger_1_OnStart()
    ' Action: Move
    Call Action_2_Move()
End Sub

Function Math_3_Result() As Double
    Return Math_3_A + Math_3_B  ' Add
End Function
```

### ⬡ 2D Scene

Generates two files:

| File | Contents |
|------|----------|
| `<name>.tscn` | Godot 2D scene with a `Node2D` root (or your chosen type) and a `VGScript` attachment |
| `<name>.vg` | The companion VisualGasic script with all the trigger/action/math logic |

After clicking **⬡ 2D Scene** you are shown the **Scene Root Selector** dialog. Choose the root node type from the dropdown (Node2D, CharacterBody2D, Area2D, RigidBody2D, Sprite2D, AnimatedSprite2D, etc.) then press **Confirm**.

### ◈ 3D Scene

Same as 2D Scene but generates `Node3D`-based content. Root type options include Node3D, CharacterBody3D, Area3D, RigidBody3D, MeshInstance3D, etc.

> **Screenshot placeholder**
>
> *[Add a screenshot of the Scene Root Selector dialog for 2D export]*

---

## 16. Saving and Loading

### Save

Click **Save** to write to the current file path. If no path has been set yet (new graph), a Save-As dialog opens automatically.

### Save As

Click **Save As** to choose a new file location. Working Nodes projects use the `.wnodes` extension.

### Load

Click **Load** to open a file browser filtered to `.wnodes` files.

### Auto-save (fallback mode)

When Working Nodes runs in its built-in fallback graph (the lighter editor inside the VG right-panel), an auto-save runs every **30 seconds** to `user://working_nodes_autosave.json`. This is independent of your main project file.

---

## 17. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Shift+A** | Open node palette at cursor position |
| **Ctrl+C** | Copy selected nodes to clipboard |
| **Ctrl+V** | Paste nodes from clipboard |
| **Delete** | Delete selected node(s) |
| **RMB drag** | Pan the graph canvas |
| **RMB click** (canvas) | Open canvas context menu |
| **RMB click** (node) | Open node context menu |
| **Double-click node** | Open inline rename dialog |
| **Ctrl+Z** | Undo |
| **Ctrl+Y** | Redo |

---

## 18. File Format Reference

Working Nodes projects are saved as **JSON** with the `.wnodes` extension. The format is human-readable and can be edited in any text editor.

```jsonc
{
    "version": 1,
    "next_node_id": 4,
    "next_group_id": 2,
    "groups": [
        { "id": 1, "name": "Group 1", "color": "#8FA8F2ff" }
    ],
    "nodes": [
        {
            "name": "WN_1",
            "title": "Trigger 1",
            "type": "event",
            "group": 1,
            "color": "#59A0FFff",
            "position": [120.0, 130.0],
            "_breakpoint": false
        },
        {
            "name": "WN_2",
            "title": "Action 2",
            "type": "action",
            "group": 1,
            "color": "#94E67Bff",
            "position": [480.0, 160.0]
        }
    ],
    "connections": [
        {
            "from": "WN_1", "from_port": 0,
            "to":   "WN_2", "to_port": 0,
            "group": 1,
            "color": "#59A0FFff"
        }
    ]
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `version` | int | File format version (always 1) |
| `next_node_id` | int | Counter used to generate unique node names |
| `next_group_id` | int | Counter used to generate unique group IDs |
| `groups` | Array | List of group objects (`id`, `name`, `color` in HTML hex) |
| `nodes` | Array | List of node objects (see below) |
| `connections` | Array | List of connection objects (see below) |

**Node fields:**

| Field | Description |
|-------|-------------|
| `name` | Internal identifier (e.g. `"WN_3"`) |
| `title` | Display name shown in the node header |
| `type` | `"event"`, `"action"`, or `"math"` |
| `group` | Group ID (integer) |
| `color` | Node colour in HTML hex with alpha |
| `position` | `[x, y]` canvas position in pixels |
| `_breakpoint` | Optional bool — `true` if a breakpoint is set |

**Connection fields:**

| Field | Description |
|-------|-------------|
| `from` | Source node name |
| `from_port` | Source port index (always 0 for the current version) |
| `to` | Target node name |
| `to_port` | Target port index (always 0 for the current version) |
| `group` | Group the wire belongs to |
| `color` | Wire colour in HTML hex with alpha |

---

## Appendix — Node Kind Quick Reference

### Trigger Nodes

| Icon | Kind | Parameters |
|------|------|------------|
| ▶ | **On Start** | *(none)* |
| ↔ | **Move** | Group ID, X, Y, Duration, Easing |
| ↻ | **Rotate** | Group ID, Degrees, Duration, Lock Rot |
| ⤡ | **Scale** | Group ID, Scale X, Scale Y, Duration |
| ◑ | **Alpha** | Group ID, Alpha, Duration |
| ?? | **Color** | Channel, R, G, B, Duration |
| ✦ | **Spawn** | Group ID, Delay |
| ◼ | **Stop** | Group ID |
| ?? | **Toggle** | Group ID, Active |
| ♪ | **Play SFX** | Sound, Volume, Pitch |
| ⟿ | **Follow** | Group ID, Target Group, X Mod, Y Mod, Duration |
| ⚡ | **Shake** | Strength, Interval, Duration |
| ?? | **Pulse** | Group ID, R, G, B, Fade In, Hold, Fade Out |
| ▷ | **Animate** | Group ID, Animation, Speed |

### Classic & Utility Nodes

| Icon | Kind | What it does |
|------|------|-------------|
| ⚡ | Event | Generic event node |
| ⚙ | Action | Generic action node |
| ∑ | Math | Arithmetic |
| ⎇ | Condition | Branches on true/false |
| ?? | Variable | Holds a named value |
| ?? | Note | Comment node |
| ⊞ | Group | Groups nodes visually |
| ↺ | Loop | Repeats a sequence N times |
| ⏩ | Sequence | Fires children in order |
| ƒ | Function | Defines a callable routine |
| ⟿ | VectorMath | 2D/3D vector operations |
| ↔ | MapRange | Remaps a value from one range to another |
| ∧ | BoolMath | AND, OR, NOT, XOR logic |
| ⇌ | Switch | Routes signals by index |
| ≤ | Compare | Less-than / greater-than / equal tests |
| ?? | Random | Generates random numbers |

---

*Working Nodes is part of the VisualGasic IDE plugin suite.*
*See also: [AGCK Manual](../../../../../../docs/manual/AGCK_MANUAL.md) | [Plugin System Guide](../../../../../../docs/guides/PLUGIN_SYSTEM.md)*

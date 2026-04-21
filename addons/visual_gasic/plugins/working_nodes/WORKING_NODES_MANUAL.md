# Working Nodes — Manual

**Working Nodes** is a visual logic editor built into the VisualGasic IDE. It lets you design game behaviour by connecting nodes on a graph instead of writing code line-by-line. The design is inspired by two well-known tools:

* **Geometry Dash triggers** — Event and Action nodes wired together in groups that fire in sequence.
* **Blender's Shader Editor** — Math nodes with typed inputs and smart routed wires.

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
┌─────────────────────────────────────────────────────────────────────────────┐
│  Toolbar Row 1  │ New  Save  Save As  Load │ ▶ Export VG  ⬡ 2D  ◈ 3D       │
│                 │ + Event  + Action  + Math │ Connect Selected               │
│                 │ + Group  Assign Group │ All wires  Smart wiring           │
│                 │ Wire Group: [All Groups ▼]  Node Color: [■]                │
├─────────────────────────────────────────────────────────────────────────────┤
│  Toolbar Row 2  │ ◐ Preview  ✓ Validate │ ⧉ Copy  ⬡ Paste                  │
│                 │ 📌 Snippet  📋 Snippets… │ Shift+A → palette              │
├───────────────┬─────────────────────────────────────────────────────────────┤
│  Left Sidebar │                  Graph Canvas                                │
│               │                                                              │
│  Selected     │   ╔══════════╗         ╔═════════════╗                      │
│  Groups       │   ║ ⚡ Event ║──────→  ║  ⚙ Action  ║                      │
│  ──────────── │   ║ On Start ║         ║  Move       ║                      │
│  [Group 1]    │   ║ Group: 1 ║         ║  Group: 1   ║                      │
│  [Group 2]    │   ╚══════════╝         ╚═════════════╝                      │
│               │                                                              │
│  Help text    │                ╔═══════════════╗                            │
│               │                ║  ∑ Math       ║                            │
│               │                ║  Add ▼  A  B  ║                            │
│               │                ╚═══════════════╝                            │
└───────────────┴─────────────────────────────────────────────────────────────┘
│  VG Code Preview (optional, toggled with ◐ Preview)                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Left Sidebar

| Element | Description |
|---------|-------------|
| **Selected Groups** label | Title of the group selector below |
| **Group list** | Multi-select list — click one or more groups to control which wires are visible on the canvas |
| **Help text** | Quick reminder of Working Nodes concepts |

### Graph Canvas

The large dark area where nodes live. You can:

* **Scroll** with the mouse wheel (vertical) or middle-mouse drag.
* **Pan** by right-mouse-button dragging anywhere on the canvas.
* **Zoom** with the zoom controls in the GraphEdit toolbar (top-left of canvas).
* **Select a node** by left-clicking it.
* **Select multiple nodes** by rubber-band dragging or Shift+clicking.

### Optional VG Preview Pane

A read-only code editor docked below the canvas. Visible only when the **◐ Preview** button is toggled on. Updates automatically whenever the graph changes.

---

## 3. Node Types

Working Nodes has three core node types, plus many extended types available through the palette.

### Core Types

| Icon | Type | Colour | Purpose |
|------|------|--------|---------|
| ⚡ | **Event** | Blue | Fires when something happens in the game (On Start, On Touch, On Timer, On Signal) |
| ⚙ | **Action** | Green | Does something when it receives a trigger (Move, Rotate, Scale, Play SFX, Set Variable) |
| ∑ | **Math** | Orange | Performs a calculation and passes the result to the next node (Add, Subtract, Multiply, Divide, Clamp, Map Range, Sine, Cosine) |

Every node has:
* A **header** showing the type icon and a dropdown to choose the specific event/action/operation.
* A **left input port** (circle on the left edge) — drag from another node's output port to connect.
* A **right output port** (circle on the right edge) — drag to the next node's input port.
* A **Group: N** label showing which group this node belongs to.
* A **resizable corner** — drag the bottom-right corner to make the node larger.

### Extended Types (via Palette)

These are added via **Shift+A** and cover:

| Category | Kinds |
|----------|-------|
| **Logic** | Condition, Switch, Compare |
| **Data** | Variable, Note |
| **Control flow** | Loop, Sequence, Function |
| **Math extensions** | VectorMath, MapRange, BoolMath, Random |
| **Gameplay (GD-style)** | Trigger, Move Group, Rotate Group, Spawn Trigger, Alpha Fade, Toggle Group, Collision Trigger, Timed Event |
| **Visual** | Color Channel |
| **Grouping** | Group |

> **Screenshot placeholder**
>
> *[Add a screenshot of the node palette popup here — showing the search box and the full list of 25 node kinds]*

---

## 4. Your First Program — Step by Step

This walkthrough creates a simple graph that moves a node on start.

### Step 1 — Open a new graph

Click **New** in the toolbar (or open Working Nodes fresh — it always starts with a default graph).

You will see:

* **Trigger 1** — an Event node set to *On Start*.
* **Action 2** — an Action node set to *Move*.

### Step 2 — Connect the nodes

If they are not already connected:

1. Hover over the **right output port** of Trigger 1 until the cursor becomes a hand.
2. Click and drag to the **left input port** of Action 2.
3. Release — a coloured wire appears between them.

Alternatively, select both nodes (Shift+click each) and press **Connect Selected** in the toolbar. Working Nodes will connect them left-to-right automatically.

### Step 3 — Configure the Event node

Click the dropdown inside Trigger 1. The options are:

| Option | When it fires |
|--------|--------------|
| On Start | When the scene loads |
| On Touch | When the player touches/clicks this object |
| On Timer | After a set delay |
| On Signal | When a named Godot signal is emitted |

Leave it on **On Start** for this example.

### Step 4 — Configure the Action node

Click the dropdown inside Action 2. Choose **Move**. This will move the target node in the direction/amount defined at runtime.

### Step 5 — Add a Math node

Press **+ Math** in the toolbar. A new Math node appears. Set its operation to **Multiply**. Wire the output of the Math node into the input of Action 2. This lets you scale the movement amount mathematically before it reaches the Action.

### Step 6 — Validate

Click **✓ Validate**. You should see: *"✔ No issues found. Graph looks good!"*

If you see warnings:
* *"No Event node found"* — make sure you have at least one ⚡ Event node.
* *"Action node X has no incoming connection"* — wire something to it or delete it.

### Step 7 — Preview the VG code

Click **◐ Preview** to open the live code panel. You will see the VG code that this graph represents, updating in real time as you edit.

> **Screenshot placeholder**
>
> *[Add a screenshot of the live preview panel showing generated VG code below the canvas]*

### Step 8 — Export

Click **▶ Export VG** to save the graph as a `.vg` file you can run in the VisualGasic interpreter.

Click **⬡ 2D Scene** to generate a Godot 2D `.tscn` scene file and a companion `.vg` script.

Click **◈ 3D Scene** to generate a 3D scene equivalent.

The export dialogs will ask you to:
1. Choose the scene root node type (e.g. `Node2D`, `CharacterBody2D`, `Node3D`, `CharacterBody3D`).
2. Confirm the save paths for the `.tscn` and `.vg` files.

After export, a success dialog shows you the paths of the generated files and offers **Open in Editor** buttons.

---

## 5. Working with Groups

Groups are the core organisational feature of Working Nodes, inspired by Geometry Dash's trigger group system. Every node belongs to a group. Wires are colour-coded by their source node's group.

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

Right-clicking any node opens its context menu:

| Menu Item | Effect |
|-----------|--------|
| **Rename** | Opens a small dialog — type the new title and press OK |
| **Duplicate** | Creates a copy 40 px offset from the original |
| *(separator)* | |
| **🔴 Set Breakpoint** / **🔴 Remove Breakpoint** | Toggles a red debug border on the node |

**Inline rename** — double-clicking a node is a shortcut that opens the rename dialog directly without right-clicking.

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

The execution-order animation shows you the BFS (breadth-first) order in which nodes would fire at runtime. Every Event node is a starting point; Action and Math nodes inherit order numbers as the traversal fans out.

**How to trigger it:**

This is accessible from the fallback graph's toolbar via the **Exec Order** button (when Working Nodes runs in fallback mode inside the VG IDE right-panel). In the full editor it can be called programmatically via `_highlight_exec_order_animated()`.

Each node gets a temporary yellow numbered badge (⓪1, ⓪2, …) that fades in staggered, holds for 1.8 s, then fades out. Nodes that are unreachable from any Event node do not receive a badge.

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
| **RMB drag** | Pan the graph canvas |
| **Double-click node** | Open inline rename dialog |
| **RMB on node** | Open node context menu |
| **Ctrl+Z** | Undo (fallback graph mode) |
| **Ctrl+Y** | Redo (fallback graph mode) |
| **Delete** | Delete selected node(s) (fallback graph mode) |

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

| Icon | Kind | What it does |
|------|------|-------------|
| ⚡ | Event | Fires on game events |
| ⚙ | Action | Executes a game command |
| ∑ | Math | Performs arithmetic |
| ⎇ | Condition | Branches on true/false |
| 📦 | Variable | Holds a named value |
| 📝 | Note | Comment/documentation node |
| ⊞ | Group | Groups nodes visually |
| ↺ | Loop | Repeats a sequence N times |
| ⏩ | Sequence | Fires children in order |
| ƒ | Function | Defines a callable routine |
| ⟿ | VectorMath | 2D/3D vector operations |
| ↔ | MapRange | Remaps a value from one range to another |
| ∧ | BoolMath | AND, OR, NOT, XOR logic |
| ⇌ | Switch | Routes signals by index |
| ≤ | Compare | Less-than / greater-than / equal tests |
| 🎲 | Random | Generates random numbers |
| ▶ | Trigger | GD-style group trigger |
| 🎨 | Color | Extracts/sets colour channels |
| ➡ | Move Group | Moves all nodes in a group |
| ↻ | Rotate Group | Rotates all nodes in a group |
| ✦ | Spawn Trigger | Instantiates a scene at runtime |
| ◑ | Alpha Fade | Fades a node's opacity |
| 👁 | Toggle Group | Shows/hides a group |
| 💥 | Collision Trigger | Fires on physics collision |
| ⏰ | Timed Event | Fires after a configurable delay |

---

*Working Nodes is part of the VisualGasic IDE plugin suite.*
*See also: [AGCK Manual](../../../../../../docs/manual/AGCK_MANUAL.md) | [Plugin System Guide](../../../../../../docs/guides/PLUGIN_SYSTEM.md)*

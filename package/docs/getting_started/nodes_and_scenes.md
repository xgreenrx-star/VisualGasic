# Nodes and Scenes

To create a game in Godot, you need two core concepts: **Nodes** and **Scenes**. If you come from VB6, think of nodes as individual controls and scenes as forms.

---

## Nodes

A **Node** is the smallest building block of your game. Every button, label, sprite, and timer is a node. A node:

- Has a **name** (like `btnStart` or `Timer1`).
- Has editable **properties** (position, visibility, color, text).
- Can receive **callbacks** (`_Ready`, `_Process`, `_Input`).
- Can be **extended** with new functions via a VisualGasic script.
- Can be **added to another node** as a child, forming a tree.

### Common Node Types

| Godot Node | VB6 Equivalent | VisualGasic Helper |
|------------|---------------|-------------------|
| `Label` | Label | `CreateLabel` |
| `Button` | CommandButton | `CreateButton` |
| `LineEdit` | TextBox | `CreateTextBox` |
| `Timer` | Timer | `CreateTimer` |
| `Sprite2D` | Image/PictureBox | `CreateSprite2D` |
| `CharacterBody2D` | *(no equivalent)* | `CreateActor2D` |
| `Panel` | Frame | `CreatePanel` |
| `CheckBox` | CheckBox | `CreateCheckBox` |
| `ItemList` | ListBox | `CreateListBox` |

In VisualGasic, you can add nodes **visually** (drag them into the scene in the Godot editor) or **in code** using helper functions like `CreateButton`.

---

## Scenes — Think "Forms"

A **Scene** is a group of nodes organized in a tree structure, saved as a `.tscn` file. If you come from VB6, a scene is the equivalent of a **Form** — it's a self-contained screen or reusable piece of your game.

Use the Godot Editor to arrange nodes into scenes:

- A **Character** (Sprite + CollisionShape).
- A **Level** (TileMap + Enemies + Pickups).
- A **Main Menu** (Labels + Buttons + Background).
- A **HUD** (Score label + Health bar + Timer).

You can save scenes to disk (`.tscn`) and then **instantiate** them at runtime — just like loading forms in VB6.

### Creating a Scene

1. In the Godot editor, click **Scene → New Scene**.
2. Choose a **root node** (e.g., `Control` for a UI form, `Node2D` for a game level).
3. Add child nodes — labels, buttons, sprites, etc.
4. Save as `res://MyScene.tscn`.

### Instantiating Scenes in Code

In VisualGasic, you load scenes using `LoadForm`:

```vb
' Load a scene from disk and add it to the game
LoadForm "res://Player.tscn"
```

This is equivalent to VB6's `Load Form1` / `Form1.Show`. The scene is instantiated and added to the scene tree automatically.

You can also load and hold a reference:

```vb
Dim playerScene
Set playerScene = LoadForm("res://Player.tscn")
playerScene.Position = Vector2(100, 200)
```

---

## The Scene Tree

All your scenes come together in the **Scene Tree** — a single tree that represents everything currently in the game. Every active node lives here.

```
Root (Viewport)
  └── Main (Node2D)
        ├── Player (CharacterBody2D)
        │     ├── Sprite2D
        │     └── CollisionShape2D
        ├── lblScore (Label)
        └── Timer1 (Timer)
```

### Accessing Nodes

Use `GetNode` to reach any node in the tree by name or path:

```vb
' Access a direct child by name
Dim label
Set label = GetNode("lblScore")
label.Text = "Score: 0"

' Access a nested child by path
Dim sprite
Set sprite = GetNode("Player/Sprite2D")
sprite.Visible = False
```

### The `Me` Keyword

In VisualGasic, `Me` refers to the current node — the node this script is attached to. This is similar to VB6's `Me` keyword which refers to the current form.

```vb
' Set the current node's properties
Me.Position = Vector2(400, 300)
Me.Visible = True

' Access the form/scene name
Print Me.Name           ' → "Main"

' Access children through Me
Me.lblTitle.Text = "Hello World"
Me.btnStart.Visible = True
```

---

## VB6 Properties on Nodes

VisualGasic adds **62+ VB6-style property aliases** to every node, so you can use familiar VB6 names instead of Godot names:

```vb
' VB6-style — feels like home
btnStart.Caption = "Play Game"
btnStart.Left = 100
btnStart.Top = 50
btnStart.Visible = True
btnStart.Enabled = True
btnStart.BackColor = vbBlue
btnStart.FontSize = 14
btnStart.FontBold = True

' These map to Godot properties under the hood:
'   Caption  →  text
'   Left     →  position.x
'   Top      →  position.y
'   Visible  →  visible
'   Enabled  →  disabled (inverted)
'   BackColor → self_modulate / theme override
```

### Common VB6 Property Aliases

| VB6 Property | Godot Equivalent | Description |
|-------------|-----------------|-------------|
| `Caption` / `Text` | `text` | Display text |
| `Left`, `Top` | `position.x`, `position.y` | Position |
| `Width`, `Height` | `size.x`, `size.y` | Size |
| `Visible` | `visible` | Show/hide |
| `Enabled` | `!disabled` | Enable/disable |
| `BackColor` | `self_modulate` / theme | Background color |
| `ForeColor` | theme `font_color` | Text color |
| `FontSize` | theme `font_size` | Font size |
| `FontBold` | theme `bold` | Bold text |
| `Name` | `name` | Node name |
| `Tag` | meta `vg_tag` | User data storage |
| `hWnd` | `get_instance_id()` | Unique handle |
| `Opacity` | `modulate.a` | Transparency |
| `ZOrder` | `z_index` | Draw order |

For the full list of 62+ properties, see the [IDE Tools reference](../manual/ide_tools.md).

---

## Putting It All Together

Here's a complete example — a simple main menu scene with a title and a start button:

```vb
' MainMenu.vg — attached to a Control node

Dim clickCount As Integer

Sub _Ready()
    ' Set up the form
    Me.lblTitle.Caption = "My Awesome Game"
    Me.lblTitle.FontSize = 32
    Me.lblTitle.ForeColor = vbWhite

    Me.btnStart.Caption = "Start Game"
    Me.btnStart.Left = 200
    Me.btnStart.Top = 300
    Me.btnStart.Width = 200
    Me.btnStart.Height = 50

    clickCount = 0
End Sub

' Auto-wired event — fires when btnStart is clicked
Sub btnStart_Click()
    clickCount = clickCount + 1
    Print "Starting game! (clicked " & clickCount & " times)"
    LoadForm "res://GameLevel.tscn"
End Sub

' Auto-wired event — fires when mouse enters the button
Sub btnStart_MouseEnter()
    Me.btnStart.FontBold = True
End Sub

Sub btnStart_MouseExit()
    Me.btnStart.FontBold = False
End Sub
```

### What's Happening Here

1. **`_Ready()`** — Runs when the scene enters the tree. Sets up labels and buttons using VB6 properties.
2. **`btnStart_Click()`** — Auto-wired event handler. No signal connections needed — just name the Sub `ControlName_EventName()`.
3. **`LoadForm`** — Loads the next scene, just like `Form2.Show` in VB6.

---

## Next Steps

- **[Scripting](scripting.md)** — Learn about variables, functions, and virtual methods.
- **[Signals and Events](signals.md)** — Deep dive into VB6-style auto-wiring and Godot signals.
- **[Debugging](../manual/debugging.md)** — Set breakpoints, inspect variables, and use the Immediate Window.

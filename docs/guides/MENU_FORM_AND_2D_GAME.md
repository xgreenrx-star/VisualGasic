# Menu Form + Node2D Canvas Game

A common VisualGasic pattern — especially with **Narcea AI** — is a **VB6-style menu form** (Start / Exit buttons) that launches a **separate 2D canvas game**. This guide shows the correct project structure and the mistakes to avoid.

---

## The pattern

| Piece | Root node | Script hooks | Purpose |
|-------|-----------|--------------|---------|
| **Menu** | `Window` (Form Designer form) | `Form_Load`, `btnStart_Click`, `btnExit_Click` | Title screen with buttons |
| **Game** | `Node2D` scene (`.tscn` + `.vg`) | `_Ready`, `_Process`, `_Draw` | Game loop, input, `DrawRect` / `DrawString` rendering |

**Rule:** keep menu logic on the form and game logic on the Node2D scene. Do not put `_Draw` game code on a Window form — Window forms cannot call `_Draw`.

---

## Example project layout

```
res://ai_projects/MyGame/
├── MenuForm.tscn          ' Main scene — Form Designer menu
├── MenuForm.vg            ' btnStart_Click / btnExit_Click handlers
├── Game.tscn              ' Node2D root for the canvas game
└── Game.vg                ' _Ready / _Process / _Draw
```

Set **Project → Project Settings → Application → Run → Main Scene** to the menu form (e.g. `MenuForm.tscn`).

---

## Menu form code

```vb
' MenuForm.vg — attached to the Window form

Sub Form_Load()
    Me.Caption = "My Game"
End Sub

Sub btnStart_Click()
    ChangeScene "res://ai_projects/MyGame/Game.tscn"
End Sub

Sub btnExit_Click()
    End    ' Terminates the application (SceneTree.quit())
End Sub
```

- **`ChangeScene`** — switches to the game scene (full scene replace).
- **`End`** — quits the app; use on Exit buttons (fixed in v5.3.0-Beta6).

---

## Game scene code

Attach a `.vg` script to a **Node2D** root:

```vb
' Game.vg — Node2D canvas game

Dim playerX As Single
Dim playerY As Single

Sub _Ready()
    playerX = 320
    playerY = 240
End Sub

Sub _Process(delta)
    If IsKeyPressed(KEY_LEFT) Then playerX = playerX - 200 * delta
    If IsKeyPressed(KEY_RIGHT) Then playerX = playerX + 200 * delta
    If IsKeyPressed(KEY_ESCAPE) Then ChangeScene "res://ai_projects/MyGame/MenuForm.tscn"
End Sub

Sub _Draw()
    DrawRect Rect2(0, 0, 640, 480), Color(0.1, 0.1, 0.15)
    DrawRect Rect2(playerX - 16, playerY - 16, 32, 32), Color(0.2, 0.8, 0.3)
End Sub
```

Use **`DrawRect`**, **`DrawString`**, **`DrawCircle`**, and related canvas APIs in `_Draw`. Read input in `_Process`.

---

## Narcea prompts

When asking Narcea to build a menu + game, describe both parts explicitly:

```
Make a form with a Start button and an Exit button.
When Exit is pressed, exit the program.
When Start is pressed, show a 2D tic-tac-toe game with a computer player
and arrow-key square selection.
```

Narcea should emit a **project spec** with:

- `forms[]` — the menu form (Window)
- `files[]` — the Node2D game `.tscn` and `.vg`
- `main_scene` — the menu form path

If the model puts game drawing code on the form script or leaves TODO stubs, VisualGasic's local **project synth** (`vg_ai_project_synth.gd`) can repair hybrid menu+game specs when it detects this intent.

---

## Common mistakes

| Mistake | Why it fails | Fix |
|---------|--------------|-----|
| `_Draw` on the menu form | Window forms don't support canvas `_Draw` | Move drawing to a Node2D `Game.vg` |
| `LoadForm` for the game | Adds a form overlay; not a full game scene switch | Use `ChangeScene "res://…/Game.tscn"` from Start |
| Game logic only in `btnStart_Click` | No game loop; no per-frame input/draw | Use `_Process` / `_Draw` on Node2D |
| Missing `End` on Exit | App keeps running | `Sub btnExit_Click()` → `End` |

---

## Related docs

- [WinForms Form Guide](../WINFORMS_FORM_GUIDE.md) — form lifecycle and Window behavior
- [ChangeScene](../reference/GODOT_FUNCTIONS_REFERENCE.md#changescenepath-as-string-as-integer) — scene switching
- [Program Control (`End`)](../reference/BUILTIN_FUNCTIONS_REFERENCE.md#program-control-statements) — quit the application
- [Quick Start — Narcea](../getting_started/QUICK_START.md#3-ai-set-up-narcea-and-generate-code) — AI-assisted project generation
- [Nodes and Scenes](../getting_started/nodes_and_scenes.md) — when to use `LoadForm` vs `ChangeScene`

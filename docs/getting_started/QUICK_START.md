# Getting Started with Visual Gasic

Welcome! This guide covers three ways to use VG: building UI, creating 2D games, and using AI (Narcea) to speed up development.

**Requires Godot 4.6.1+** with the VisualGasic plugin enabled. Current public beta: **v5.6.0-beta1**.

---

## 1. Forms: Your First "Hello World"

Forms (Control-rooted scenes) are the fastest way to build an interactive VG UI.

### Setup (2 minutes)

1. **Open Godot 4.6.1+** with VisualGasic installed ([Installation](installation.md))
2. **Create a project**: `vg new VGHelloForm` then `godot . --editor`, **or** from an existing VG project use **Project → VGasic Tools → New VG Project…** (keeps the current editor open; may open a second window — if not, open the new folder from the Project Manager)
3. **Enable the plugin** if needed: Project → Project Settings → Plugins → `visual_gasic` → Enable
4. **Restart Godot** if the GDExtension just loaded

### Create a simple contact UI (5 minutes)

1. **Scene → New Scene**, root type **Control**, rename root to `ContactForm`
2. Attach **`ContactForm.vg`** (right-click root → Attach Script → Language: VisualGasic)
3. Paste:

```vb
Option Explicit

Sub _Ready()
    ' Create controls in code (auto-parented to this node)
    CreateLabel "Name:", 10, 10
    CreateInput "", 10, 30, 280
    ' 4th argument is the click handler Sub name
    CreateButton "Submit", 10, 60, "SubmitForm"
End Sub

Sub SubmitForm()
    MsgBox "Thank you for submitting!"
End Sub
```

4. Set **Project → Project Settings → Application → Run → Main Scene** to your scene
5. Press **F5**, click **Submit**

**That's it.** No `.tscn` signal wiring — `CreateButton` connects `pressed` to your Sub.

### Designer path (optional)

For drag-and-drop layout, use the **Toolbox** to place Label / TextBox / Button controls, then write handlers by name:

```vb
Sub btnSubmit_Click()
    MsgBox "Thank you for submitting!"
End Sub
```

Legacy Form Designer / standalone shell is **experimental** — see [VG IDE Alpha](../manual/VG_IDE_ALPHA.md). Prefer Godot Script + floating VG panels for v6.0.

### Next Steps

- Explore **demos/UI/VG_UI_TOOLS/** (or `samples/demos/UI/VG_UI_TOOLS/`) for more UI examples
- [WinForms / Form Guide](../WINFORMS_FORM_GUIDE.md) · [Auto-Wiring Guide](../AUTO_WIRING_GUIDE.md)
- Classic BASIC CRT inside a form: place a **ScreenBox** from the toolbox ([QB graphics mode](../manual/qb_graphics_mode.md))

---

## 2. 2D: Step-by-Step to a Platformer

Building a simple 2D platformer teaches core game-dev concepts.

### Setup (2 minutes)

1. **Create a new Godot project** named `VGPlatformer`
2. **Enable VisualGasic plugin**
3. **Create a 2D Scene** with a Node2D root named `Main`
4. Attach **`Main.vg`** to that root

### Scene Structure

Create three child nodes under Main:
- **Player** (CharacterBody2D)
  - Sprite2D
  - CollisionShape2D
- **Level** (Node2D)
  - Ground (StaticBody2D) + CollisionShape2D
- **Camera2D** (as child of Player, or follow in code)

### The Main Script (`Main.vg`)

```vb
Option Explicit

Dim PlayerSpeed As Single = 200
Dim PlayerJump As Single = -400
Dim Gravity As Single = 800

Sub _PhysicsProcess(delta)
    Dim velocity As Vector2 = Player.Velocity

    If Input.IsKeyPressed(KEY_LEFT) Then
        velocity.x = -PlayerSpeed
    ElseIf Input.IsKeyPressed(KEY_RIGHT) Then
        velocity.x = PlayerSpeed
    Else
        velocity.x = 0
    End If

    velocity.y = velocity.y + (Gravity * delta)

    If Input.IsKeyJustPressed(KEY_SPACE) And Player.IsOnFloor() Then
        velocity.y = PlayerJump
    End If

    Player.Velocity = velocity
    Player.MoveAndSlide()
End Sub
```

### Run It

- Press F5
- Use **← →** to move, **SPACE** to jump

### Next Steps

- [Your First 2D Game](../tutorials/your_first_2d_game.md)
- Explore **demos/2D_Games/** and **samples/games/**
- [Performance Guide](../manual/performance.md) when you grow past a few entities
- Pixel / vector art: **Sprite Editor** and **Vector Editor** in the VG toolbar

---

## 3. AI: Set Up Narcea and Generate Code

Narcea is the built-in **Vibe Code** assistant that generates VG from plain English.

### Get a provider (3 minutes)

Narcea supports **OpenAI**, **Anthropic (Claude)**, **Google (Gemini)**, **local Ollama**, and optional **Cursor** handoff.

#### Option A: OpenAI

1. [platform.openai.com/account/api-keys](https://platform.openai.com/account/api-keys) → Create secret key → copy

#### Option B: Anthropic (Claude)

1. [console.anthropic.com/account/keys](https://console.anthropic.com/account/keys) → Create Key → copy

#### Option C: Local Ollama (free)

1. Install [Ollama](https://ollama.ai)
2. `ollama pull llama3.2` (or any model)
3. `ollama serve` — no API key

### Configure Narcea in VG

1. Open your project with VisualGasic enabled
2. Open the **Vibe Code** panel (VG toolbar / floating assist — not the Godot AssetLib)
3. Choose provider, paste API key if needed, save

### Try It: Generate a Login Form

Prompt:

```
Create a login form with:
- Username text box (label: "Username")
- Password text box (label: "Password")
- Login button
- A message that says "Incorrect password" if the user enters anything but "demo123"
```

Then:
1. **Read every line** — VG’s explicit blocks make audits easy
2. **Paste into your `.vg` file**
3. **F5** to test

### Why This Matters

**AI writes it, you understand it.** Verbose `End Sub` / `End If` syntax is built for auditing, not for hiding control flow.

### Next Steps

- [IDE Tools — Vibe Code / AI Help](../manual/ide_tools.md#ai-help-panel)
- [Menu Form + Node2D Game](../guides/MENU_FORM_AND_2D_GAME.md)
- [Immediate Window](../IMMEDIATE_WINDOW.md) for REPL-style checks

---

## What's Next?

| Time | Task | Link |
|------|------|------|
| 15 min | Explore the UI Toolkit demo | **demos/UI/VG_UI_TOOLS** |
| 30 min | Build a calculator | [Calculator Tutorial](../tutorials/calculator_form_designer.md) |
| 1 hour | Extend the platformer | [Your First 2D Game](../tutorials/your_first_2d_game.md) |
| Then | Full language reference | [Language Reference](../VisualGasic_Language_Reference.md) |

### Questions?

- **Installation issues?** → [Installation](installation.md) · [full Installation Guide](../guides/INSTALLATION.md)
- **Language syntax?** → [Language Reference](../VisualGasic_Language_Reference.md)
- **Built-in functions?** → [Builtins](../BUILTINS.md) · [Builtin Functions Reference](../reference/BUILTIN_FUNCTIONS_REFERENCE.md)
- **Report a bug?** → [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues)

---

**Welcome to Visual Gasic. Let's build something you can read.**

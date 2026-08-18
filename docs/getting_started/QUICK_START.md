# Getting Started with Visual Gasic

Welcome! This guide covers three ways to use VG: building UI forms, creating 2D games, and using AI to speed up development.

---

## 1. Forms: Your First "Hello World"

Forms are the fastest way to build an interactive VG project. You're building a simple contact form.

### Setup (2 minutes)

1. **Open Godot 4.6.1+** with VisualGasic installed
2. **Create a new project** named `VGHelloForm`
3. **Enable the plugin**: Project → Project Settings → Plugins → `visual_gasic` → Enable
4. **Restart Godot**

### Create the Form (5 minutes)

In the Script editor, create a new VG file named `ContactForm.vg`:

```vb
Option Explicit

Sub Form_Load()
    ' Set form title and size
    Me.Caption = "Contact Form"
    Me.Width = 300
    Me.Height = 200
    
    ' Add a label
    Dim lbl As Label
    Set lbl = CreateLabel("Name:", 10, 10, 100, 20)
    lbl.Parent = Me
    
    ' Add a text input
    Dim txt As TextEdit
    Set txt = CreateTextEdit(10, 30, 280, 20)
    txt.Parent = Me
    
    ' Add a submit button
    Dim btn As Button
    Set btn = CreateButton("Submit", 10, 60, 80, 30)
    btn.Parent = Me
    btn.OnClick = "SubmitForm"
End Sub

Sub SubmitForm()
    MsgBox "Thank you for submitting!"
End Sub
```

### Run It

- **Press F5** in Godot
- Click **Submit**
- See the message box

**That's it.** You've written an interactive VG form without a single line of `.tscn` boilerplate or signal wiring.

### Next Steps

- Explore **demos/UI/VG_UI_TOOLS/** in the VisualGasic GitHub repo for 11 more form examples
- Read [Form Designer Guide](WINFORMS_FORM_GUIDE.md) for drag-and-drop form building
- Check out [Auto-Wiring Guide](AUTO_WIRING_GUIDE.md) for event handler shortcuts

---

## 2. 2D: Step-by-Step to a Platformer

Building a simple 2D platformer in VG teaches core game-dev concepts.

### Setup (2 minutes)

1. **Create a new Godot project** named `VGPlatformer`
2. **Enable VisualGasic plugin**
3. **Create a 2D Scene** with a Node2D root named `Main`

### Scene Structure

Create three child nodes under Main:
- **Player** (CharacterBody2D)
  - Sprite2D (sprite image)
  - CollisionShape2D (rect shape)
- **Level** (Node2D)
  - Ground (StaticBody2D)
    - Sprite2D (brown rect)
    - CollisionShape2D (rect)
- **Camera** (Camera2D)

### The Main Script (`main.vg`)

```vb
Option Explicit

Global PlayerSpeed = 200
Global PlayerJump = -400
Global Gravity = 800

Sub _Ready()
    Camera.Target = Player
End Sub

Sub _Process(delta)
    Dim velocity = Player.Velocity
    
    ' Horizontal movement
    If Input.IsKeyPressed(KEY_LEFT) Then
        velocity.x = -PlayerSpeed
    ElseIf Input.IsKeyPressed(KEY_RIGHT) Then
        velocity.x = PlayerSpeed
    Else
        velocity.x = 0
    End If
    
    ' Gravity and jumping
    velocity.y = velocity.y + (Gravity * delta)
    
    If Input.IsKeyJustPressed(KEY_SPACE) And Player.IsOnFloor() Then
        velocity.y = PlayerJump
    End If
    
    ' Apply physics
    Player.Velocity = velocity
    Player.MoveAndSlide()
End Sub
```

### Run It

- Press F5
- Use **← →** to move, **SPACE** to jump
- You've built a playable platformer in ~30 lines of readable code

### Next Steps

- Read [Your First 2D Game](../tutorials/your_first_2d_game.md) for detailed explanations
- Explore **demos/** in the repo for collision detection, enemies, scoring, and more
- Check [Performance Guide](../manual/performance.md) for optimization tips as your game grows

---

## 3. AI: Set Up Narcea and Generate Code

VG is built for AI-assisted development. Narcea is the built-in AI pair that generates VG code from plain English.

### Get an API Key (3 minutes)

Narcea supports **OpenAI (ChatGPT)**, **Anthropic (Claude)**, **Google (Gemini)**, and **local Ollama**.

#### Option A: OpenAI API

1. Go to [platform.openai.com/account/api-keys](https://platform.openai.com/account/api-keys)
2. Click **Create new secret key**
3. Copy the key

#### Option B: Anthropic API (Claude)

1. Go to [console.anthropic.com/account/keys](https://console.anthropic.com/account/keys)
2. Click **Create Key**
3. Copy the key

#### Option C: Local Ollama (free, runs on your machine)

1. Download [Ollama](https://ollama.ai)
2. Run `ollama pull llama2` (or any model)
3. Start the server: `ollama serve`
4. No API key needed — it runs locally

### Configure Narcea in VG

1. **Open VisualGasic**
2. **Toolbox panel** → Narcea AI Pair tab
3. **Select provider**: OpenAI, Anthropic, Google, or Local Ollama
4. **Paste your API key** (or leave blank for Ollama)
5. **Save**

### Try It: Generate a Login Form

In Narcea, paste this prompt:

```
Create a login form with:
- Username text box (label: "Username")
- Password text box (label: "Password")
- Login button
- A message that says "Incorrect password" if the user enters anything but "demo123"
```

Narcea will generate working VG code. You:
1. **Read every line** — VG's explicit syntax makes it clear what happens
2. **Spot issues** — no hidden side effects, no implicit behavior
3. **Accept or reject** — clipboard copy, paste into your script, done
4. **Run it** — F5 to test

### Why This Matters

This is the VG pitch: **AI writes it, you understand it.** Unlike black-box AI tools, you read the code. You audit it. You trust it. You learn from it.

### Next Steps

- Explore the [Narcea AI Pair Guide](../manual/narcea_guide.md) (coming in v5.4)
- Try more prompts: "Make a calculator", "Build a todo list", "Create a high score leaderboard"
- Read [Menu Form + Node2D Game](../guides/MENU_FORM_AND_2D_GAME.md) when Narcea builds a Start/Exit menu that opens a canvas game
- Read [the Immediate Window guide](../IMMEDIATE_WINDOW.md) to test code snippets in real-time

---

## What's Next?

You now know:
- ✅ How to build a form (event handlers, controls, no signal wiring)
- ✅ How to write a 2D game (physics, input, frame loops)
- ✅ How to use AI to generate code (and understand what it wrote)

### Recommended Path

| Time | Task | Link |
|------|------|------|
| 15 min | Explore the UI Toolkit demo | **demos/UI/VG_UI_TOOLS** |
| 30 min | Build a calculator form | [Calculator Tutorial](../tutorials/calculator_form_designer.md) |
| 1 hour | Extend the platformer (enemies, coins, lives) | [Your First 2D Game](../tutorials/your_first_2d_game.md) |
| 2 hours | Prompt Narcea to build a full game menu system | Narcea Pair tab |
| Then | Read the full language reference | [VisualGasic Language Reference](../VisualGasic_Language_Reference.md) |

### Questions?

- **Installation issues?** → [Installation Guide](installation.md)
- **Language syntax?** → [Language Reference](../VisualGasic_Language_Reference.md)
- **Built-in functions?** → [Builtins Reference](../docs/BUILTINS.md)
- **Report a bug?** → [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues)
- **Join the community?** → [Discord](https://discord.gg/visualgasic) (coming soon)

---

**Welcome to Visual Gasic. Let's build something you can read.**

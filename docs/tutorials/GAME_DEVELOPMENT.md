# 🎮 Step-by-Step Tutorial: Building a Pong Game in VisualGasic

*Build a complete two-player Pong game — from blank project to playable game*

![Pong Demo](../screenshots/pong_demo.png)

---

## What You'll Build

A fully playable two-player Pong game with:
- Smooth paddle movement with keyboard controls
- Ball physics with angle-based paddle deflection
- Score tracking (first to 11 wins)
- Game states: Title → Playing → Paused → Game Over
- Dashed center-court line (classic 1972 aesthetic)
- Speed ramp-up on every paddle hit

**Time required:** 30–60 minutes  
**Difficulty:** Beginner to Intermediate  
**Prerequisites:** Godot 4.5+ with VisualGasic addon installed ([Installation Guide](../guides/INSTALLATION.md))

---

## Step 1 — Create a New Godot Project

1. Launch **Godot 4.5+** and click **New Project**.
2. Name it `Pong` and choose an empty folder.
3. Click **Create & Edit**.

### Enable the VisualGasic Plugin

1. Go to **Project → Project Settings → Plugins**.
2. Enable **VisualGasic**.

### Set Up Input Actions

Pong needs custom input actions. Go to **Project → Project Settings → Input Map** and add:

| Action Name | Key Binding |
|-------------|-------------|
| `player1_up` | W |
| `player1_down` | S |
| `player2_up` | Up Arrow |
| `player2_down` | Down Arrow |

> 💡 **Tip:** Godot's built-in `ui_accept` (Enter/Space) and `ui_cancel` (Escape) are used for pause and restart — no extra setup needed.

---

## Step 2 — Create the Main Scene

1. In the **Scene** dock, click **Other Node** and add a **Node2D**.
2. Rename it to `PongGame`.
3. Save the scene as `main.tscn`.
4. Set it as the **Main Scene** in Project Settings → General → Run.

---

## Step 3 — Create the VisualGasic Script

1. Select the `PongGame` node.
2. Click **Attach Script** in the Inspector.
3. Choose **VisualGasic**, name it `pong.vg`, click **Create**.

---

## Step 4 — Define Game Constants

Start by declaring the constants that control the game's dimensions and physics. Constants make your game easy to tune later.

```vb
Attribute VB_Name = "PongGame"

' --- GAME CONSTANTS ---
Const SCREEN_WIDTH As Integer = 800
Const SCREEN_HEIGHT As Integer = 600
Const PADDLE_WIDTH As Integer = 15
Const PADDLE_HEIGHT As Integer = 80
Const BALL_SIZE As Integer = 15
Const PADDLE_SPEED As Single = 400.0      ' Pixels per second
Const BALL_SPEED_INITIAL As Single = 300.0
Const BALL_SPEED_INCREMENT As Single = 25.0  ' Speed boost per paddle hit
Const WIN_SCORE As Integer = 11
```

### 🔍 What You Just Learned

| Concept | Syntax | Purpose |
|---------|--------|---------|
| Module name | `Attribute VB_Name = "PongGame"` | Registers the script identity (like GDScript's `class_name`) |
| Constants | `Const NAME As Type = value` | Compile-time values you can tune in one place |
| `As Integer` | Whole numbers | Pixel dimensions |
| `As Single` | 32-bit float | Speeds and physics values |

---

## Step 5 — Declare Game State Variables

Below the constants, declare all the variables that change during gameplay:

```vb
' --- Ball State ---
Dim ballX As Single       ' Ball X position (top-left corner)
Dim ballY As Single       ' Ball Y position
Dim ballVelX As Single    ' Horizontal velocity (negative = moving left)
Dim ballVelY As Single    ' Vertical velocity (negative = moving up)
Dim ballSpeed As Single   ' Scalar speed (increases each rally)

' --- Paddle Positions (Y only — X is fixed) ---
Dim paddle1Y As Single    ' Left paddle top edge
Dim paddle2Y As Single    ' Right paddle top edge

' --- Scores ---
Dim score1 As Integer
Dim score2 As Integer

' --- Game State Flags ---
Dim gameOver As Boolean
Dim winner As String      ' "Player 1" or "Player 2"
Dim paused As Boolean
```

> 💡 **Design Note:** Paddles only store their Y coordinate because their X position is fixed (left paddle at X=30, right paddle near the right edge). This is a classic Pong simplification.

---

## Step 6 — Initialization

Write the startup code — `_Ready()` is Godot's "scene entered" callback (equivalent to VB6's `Form_Load`):

```vb
Sub _Ready()
    Print "=== PONG ==="
    Print "Player 1: W/S keys"
    Print "Player 2: Arrow keys"
    Print "First to " & Str(WIN_SCORE) & " wins!"
    ResetGame
End Sub

Sub ResetGame()
    score1 = 0
    score2 = 0
    gameOver = False
    winner = ""
    paused = False
    ResetBall 0       ' 0 = serve to random direction
    ResetPaddles
End Sub

Sub ResetPaddles()
    paddle1Y = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2
    paddle2Y = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2
End Sub
```

### 🔍 Key Concepts

- **`Print`** outputs debug messages to Godot's Output panel.
- **`&`** is VB6 string concatenation; **`Str()`** converts a number to a string.
- Calling `ResetBall 0` without parentheses is standard VB6 style for single-argument calls.

---

## Step 7 — Ball Reset with Random Angle

When the ball resets (at start or after a goal), give it a random launch angle:

```vb
Sub ResetBall(serveDirection As Integer)
    ' Center the ball on screen
    ballX = SCREEN_WIDTH / 2
    ballY = SCREEN_HEIGHT / 2
    ballSpeed = BALL_SPEED_INITIAL

    ' Random launch angle: ±34° from horizontal
    Dim angle As Single
    angle = (Rnd() - 0.5) * 1.2    ' -0.6 to 0.6 radians

    ' Pick serve direction (0 = random coin flip)
    If serveDirection = 0 Then
        If Rnd() > 0.5 Then
            serveDirection = 1      ' Serve right
        Else
            serveDirection = -1     ' Serve left
        End If
    End If

    ' Decompose speed into X and Y components using trigonometry
    ballVelX = Cos(angle) * ballSpeed * serveDirection
    ballVelY = Sin(angle) * ballSpeed
End Sub
```

### 🔍 Math Functions Used

| Function | Purpose | Example |
|----------|---------|---------|
| `Rnd()` | Random number 0.0–1.0 | `Rnd() > 0.5` for coin flip |
| `Cos(angle)` | Cosine (radians) | Horizontal component of velocity |
| `Sin(angle)` | Sine (radians) | Vertical component of velocity |

> 🎓 **How the angle works:** The formula `(Rnd() - 0.5) * 1.2` produces a random angle between −0.6 and +0.6 radians (~±34°). This ensures the ball never launches perfectly vertically (which would be boring) or perfectly horizontally (too predictable).

---

## Step 8 — The Game Loop

`_Process(delta)` runs every frame. It implements a simple **state machine**:

```
Title → Playing → Paused (toggle) → Playing → Game Over → Restart
```

```vb
Sub _Process(delta As Single)
    ' --- STATE: GAME OVER ---
    If gameOver Then
        If Input.IsActionJustPressed("ui_accept") Then
            ResetGame
        End If
        Return
    End If

    ' --- STATE: PAUSED ---
    If paused Then
        If Input.IsActionJustPressed("ui_accept") Then
            paused = False
        End If
        Return
    End If

    ' --- TOGGLE PAUSE ---
    If Input.IsActionJustPressed("ui_cancel") Then
        paused = True
        Return
    End If

    ' --- STATE: PLAYING ---
    UpdatePaddles delta
    UpdateBall delta
    CheckCollisions
    CheckScore
End Sub
```

### 🔍 Key Concepts

- **`delta As Single`** — elapsed seconds since last frame (~0.016 at 60 FPS). Multiplying movement by delta makes the game **frame-rate independent**.
- **`Return`** exits the Sub early (equivalent to VB6's `Exit Sub`).
- **`Input.IsActionJustPressed()`** fires once on key-down; **`Input.IsActionPressed()`** fires every frame the key is held.
- The state machine uses early `Return` statements — the simplest game-state pattern.

---

## Step 9 — Paddle Movement

Read held-key input and move paddles vertically, clamped to the screen:

```vb
Sub UpdatePaddles(delta As Single)
    ' Player 1 (W/S)
    If Input.IsActionPressed("player1_up") Then
        paddle1Y = paddle1Y - PADDLE_SPEED * delta
    End If
    If Input.IsActionPressed("player1_down") Then
        paddle1Y = paddle1Y + PADDLE_SPEED * delta
    End If

    ' Player 2 (Arrow keys)
    If Input.IsActionPressed("player2_up") Then
        paddle2Y = paddle2Y - PADDLE_SPEED * delta
    End If
    If Input.IsActionPressed("player2_down") Then
        paddle2Y = paddle2Y + PADDLE_SPEED * delta
    End If

    ' Clamp to screen bounds
    paddle1Y = Clamp(paddle1Y, 0, SCREEN_HEIGHT - PADDLE_HEIGHT)
    paddle2Y = Clamp(paddle2Y, 0, SCREEN_HEIGHT - PADDLE_HEIGHT)
End Sub
```

> 💡 **Why subtract for "up"?** In Godot, the Y-axis points **downward**. So moving up means decreasing Y. This catches many beginners off guard!

---

## Step 10 — Ball Movement and Wall Bouncing

Simple Euler integration with top/bottom wall bouncing:

```vb
Sub UpdateBall(delta As Single)
    ' Move the ball: position += velocity × time
    ballX = ballX + ballVelX * delta
    ballY = ballY + ballVelY * delta

    ' Bounce off top wall
    If ballY <= 0 Then
        ballY = 0
        ballVelY = Abs(ballVelY)        ' Force downward
    ' Bounce off bottom wall
    ElseIf ballY >= SCREEN_HEIGHT - BALL_SIZE Then
        ballY = SCREEN_HEIGHT - BALL_SIZE
        ballVelY = -Abs(ballVelY)       ' Force upward
    End If
End Sub
```

### 🔍 Physics Explained

The formula `position = position + velocity × delta` is **Euler integration** — the simplest physics update. For Pong it's perfectly adequate. The `Abs()` function (VB6 built-in) forces the velocity in the correct direction after a wall bounce, preventing the ball from getting stuck.

---

## Step 11 — Paddle Collision with Angle Deflection

This is the most interesting part — where the ball hits a paddle, the bounce angle depends on **where on the paddle it struck**:

```
  Paddle Face          Hit Position → Angle
  ┌─────────┐         
  │ top     │  ← 0.0  → steep upward angle (-0.7 rad)
  │         │
  │ center  │  ← 0.5  → flat horizontal (0 rad)
  │         │
  │ bottom  │  ← 1.0  → steep downward angle (+0.7 rad)
  └─────────┘
```

```vb
Sub CheckCollisions()
    Dim paddleLeft As Single = 30
    Dim paddleRight As Single = SCREEN_WIDTH - 30 - PADDLE_WIDTH

    ' --- Ball vs Paddle 1 (left) ---
    If ballX <= paddleLeft + PADDLE_WIDTH Then
        If ballY + BALL_SIZE >= paddle1Y And ballY <= paddle1Y + PADDLE_HEIGHT Then
            ' Calculate WHERE on the paddle face the ball hit (0.0 to 1.0)
            Dim hitPos As Single
            hitPos = (ballY + BALL_SIZE/2 - paddle1Y) / PADDLE_HEIGHT

            ' Map 0..1 → -0.7..+0.7 radians for bounce angle
            Dim angle As Single
            angle = (hitPos - 0.5) * 1.4

            ' Increase ball speed (makes rallies harder!)
            ballSpeed = ballSpeed + BALL_SPEED_INCREMENT

            ' New velocity: Cos is always positive → ball goes RIGHT
            ballVelX = Cos(angle) * ballSpeed
            ballVelY = Sin(angle) * ballSpeed
            ballX = paddleLeft + PADDLE_WIDTH + 1  ' Nudge past paddle
        End If
    End If

    ' --- Ball vs Paddle 2 (right) ---
    If ballX + BALL_SIZE >= paddleRight Then
        If ballY + BALL_SIZE >= paddle2Y And ballY <= paddle2Y + PADDLE_HEIGHT Then
            Dim hitPos2 As Single
            hitPos2 = (ballY + BALL_SIZE/2 - paddle2Y) / PADDLE_HEIGHT
            Dim angle2 As Single
            angle2 = (hitPos2 - 0.5) * 1.4

            ballSpeed = ballSpeed + BALL_SPEED_INCREMENT

            ' NEGATIVE Cos → ball goes LEFT
            ballVelX = -Cos(angle2) * ballSpeed
            ballVelY = Sin(angle2) * ballSpeed
            ballX = paddleRight - BALL_SIZE - 1
        End If
    End If
End Sub
```

### 🔍 Collision Detection Explained

This uses **AABB (Axis-Aligned Bounding Box)** collision — the simplest 2D collision method:
1. Check if the ball's X overlaps the paddle's X range
2. Check if the ball's Y overlaps the paddle's Y range
3. If both overlap → collision!

The **hit position formula** `(ballCenter - paddleTop) / paddleHeight` normalizes where the ball hit to a 0.0–1.0 range. Mapping this to an angle gives the classic Pong "aim with your paddle" mechanic.

---

## Step 12 — Scoring

Detect when the ball leaves the screen and award points:

```vb
Sub CheckScore()
    ' Ball exited left → Player 2 scores
    If ballX < -BALL_SIZE Then
        score2 = score2 + 1
        Print "SCORE! Player 2: " & Str(score2)

        If score2 >= WIN_SCORE Then
            gameOver = True
            winner = "Player 2"
        Else
            ResetBall 1    ' Serve toward Player 2 (the scorer)
        End If
    End If

    ' Ball exited right → Player 1 scores
    If ballX > SCREEN_WIDTH Then
        score1 = score1 + 1
        Print "SCORE! Player 1: " & Str(score1)

        If score1 >= WIN_SCORE Then
            gameOver = True
            winner = "Player 1"
        Else
            ResetBall -1   ' Serve toward Player 1 (the scorer)
        End If
    End If
End Sub
```

> 💡 **Courtesy Serve:** After a goal, the ball is served toward the player who scored. This is traditional Pong etiquette!

---

## Step 13 — Render Everything

The `_Draw()` callback renders the game every frame:

```vb
Sub _Draw()
    Dim paddleLeft As Single = 30
    Dim paddleRight As Single = SCREEN_WIDTH - 30 - PADDLE_WIDTH

    ' Black background
    DrawRect 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Color.Black

    ' Dashed center-court line (classic 1972 Pong aesthetic)
    Dim i As Integer
    For i = 0 To SCREEN_HEIGHT Step 30
        DrawRect SCREEN_WIDTH/2 - 2, i, 4, 15, Color.Gray
    Next

    ' Paddles (white rectangles)
    DrawRect paddleLeft, paddle1Y, PADDLE_WIDTH, PADDLE_HEIGHT, Color.White
    DrawRect paddleRight, paddle2Y, PADDLE_WIDTH, PADDLE_HEIGHT, Color.White

    ' Ball (white square)
    DrawRect ballX, ballY, BALL_SIZE, BALL_SIZE, Color.White

    ' Scores (top of screen)
    DrawString Str(score1), SCREEN_WIDTH/4, 30, Color.White
    DrawString Str(score2), 3 * SCREEN_WIDTH/4, 30, Color.White

    ' Game state overlays
    If gameOver Then
        DrawString winner & " WINS!", SCREEN_WIDTH/2 - 80, SCREEN_HEIGHT/2 - 20, Color.Yellow
        DrawString "Press ENTER to restart", SCREEN_WIDTH/2 - 100, SCREEN_HEIGHT/2 + 20, Color.Gray
    ElseIf paused Then
        DrawString "PAUSED", SCREEN_WIDTH/2 - 40, SCREEN_HEIGHT/2, Color.Yellow
        DrawString "Press ENTER to continue", SCREEN_WIDTH/2 - 100, SCREEN_HEIGHT/2 + 30, Color.Gray
    End If
End Sub
```

### 🔍 Drawing Commands Used

| Command | What It Draws |
|---------|---------------|
| `DrawRect x, y, w, h, color` | Filled rectangle (paddles, ball, background) |
| `DrawString text, x, y, color` | Text (scores, overlays) |
| `Color.Black`, `Color.White` | Named colours |
| `Color.Yellow`, `Color.Gray` | Highlight and muted colours |
| `For i = 0 To N Step 30` | Loop to draw dashed line segments |

---

## Step 14 — Run Your Game!

1. Press **F5** to run the project.
2. **Player 1:** W (up) and S (down).
3. **Player 2:** Arrow Up and Arrow Down.
4. Press **Escape** to pause, **Enter** to resume.
5. First to 11 points wins!

**Congratulations!** 🎉 You've built a complete game in VisualGasic.

---

## What You Learned

| Concept | VB6 Syntax | Game Application |
|---------|------------|-----------------|
| Constants | `Const SPEED As Single = 400.0` | Tunable game parameters |
| Variables | `Dim ballX As Single` | Game object positions |
| Game loop | `Sub _Process(delta As Single)` | Frame-by-frame updates |
| Input | `Input.IsActionPressed("name")` | Continuous key reading |
| One-shot input | `Input.IsActionJustPressed("name")` | Pause/restart triggers |
| Trigonometry | `Cos(angle)`, `Sin(angle)` | Ball deflection physics |
| Randomness | `Rnd()` | Random serve angles |
| Clamping | `Clamp(val, min, max)` | Keep paddles on screen |
| State machine | `If gameOver Then ... Return` | Multiple game states |
| For loops | `For i = 0 To N Step 30` | Dashed court line |
| Drawing | `DrawRect`, `DrawString` | All visual output |
| String concat | `"Score: " & Str(n)` | Debug messages |

---

## Challenges: Extend Your Game!

Now that you have a working Pong, try these enhancements:

### 🟢 Easy
1. **Change the win score** — modify `WIN_SCORE` to 5 for quicker games.
2. **Change colours** — make Player 1's paddle blue and Player 2's red.
3. **Add a serve delay** — pause 1 second after a goal before the ball moves.

### 🟡 Medium
4. **Add sound effects** — play a "boop" on paddle hit and a "buzz" on scoring.
5. **Round ball** — replace `DrawRect` for the ball with `DrawCircle`.
6. **AI opponent** — make Player 2 track the ball's Y position automatically.

### 🔴 Hard
7. **Power-ups** — spawn random items that change ball speed or paddle size.
8. **Particle effects** — add sparks when the ball hits a paddle.
9. **Online multiplayer** — use Godot's networking for two-player online Pong.

---

## Complete Architecture

Here's how all the pieces fit together:

```
_Ready()  ──→  ResetGame()  ──→  ResetBall() + ResetPaddles()
                                       │
                                       ▼
_Process(delta)  ──→  State Machine:
    │                 ├─ gameOver? → wait for ENTER → ResetGame()
    │                 ├─ paused?   → wait for ENTER → unpause
    │                 └─ playing:
    │                     ├─ UpdatePaddles(delta)  ← keyboard input
    │                     ├─ UpdateBall(delta)     ← Euler integration
    │                     ├─ CheckCollisions()     ← AABB + angle math
    │                     └─ CheckScore()          ← goal detection
    │
_Draw()  ──→  Render everything:
    ├─ Background + court line
    ├─ Paddles + ball
    ├─ Scores
    └─ State overlays (PAUSED / GAME OVER)
```

---

## Next Steps

- 📱 **Build an app** → [App Development Tutorial](APP_DEVELOPMENT.md)
- 🚀 **Explore more demos** → `demos/2D_Games/` (Space Shooter, Breakout, Snake, and more)
- 🧰 **Use the Form Designer** → build UIs with drag-and-drop instead of custom drawing
- 📚 **Advanced game dev** → [Modern Features Guide](../guides/MODERN_FEATURES.md) (async/await, classes, generics)
- 🏎 **Benchmark your game** → [Performance Guide](../manual/performance.md)

---

## Complete Source Code

The full Pong source (386 lines with extensive comments) is available at:  
**`demos/2D_Games/Pong/pong.vg`**

To run the finished demo:
```bash
cd demos/2D_Games/Pong
godot --path . -s main.tscn
```

---

*Tutorial written for VisualGasic v3.2.0 Beta 1*

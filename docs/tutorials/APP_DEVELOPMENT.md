# 📱 Step-by-Step Tutorial: Building a Calculator App in VisualGasic

*Build a complete four-function calculator with memory — from blank project to finished application*

![Visual Gasic IDE](../screenshots/form_designer_ide.png)

---

## What You'll Build

A fully functional calculator application with:
- Four basic operations (+ − × ÷)
- Memory functions (MC, MR, M+, M−)
- Percentage and sign-toggle keys
- Full keyboard AND mouse input
- Custom-drawn button grid with colour themes

**Time required:** 30–60 minutes  
**Difficulty:** Beginner to Intermediate  
**Prerequisites:** Godot 4.6.1+ with VisualGasic addon installed ([Installation Guide](../guides/INSTALLATION.md))

---

## Step 1 — Create a New Godot Project

1. Launch **Godot 4.6.1+** and click **New Project**.
2. Name it `Calculator` and choose an empty folder.
3. Click **Create & Edit**.

> 💡 **Tip:** VisualGasic works as a Godot GDExtension. If you haven't installed
> the addon yet, follow the [Installation Guide](../guides/INSTALLATION.md) first.

### Enable the VisualGasic Plugin

1. Go to **Project → Project Settings → Plugins**.
2. Enable **VisualGasic**.
3. You should now see the VisualGasic toolbar and Visual Gasic IDE panel.

---

## Step 2 — Create the Main Scene

1. In the **Scene** dock, click **Other Node** and add a **Node2D**.
2. Rename it to `Calculator`.
3. Save the scene as `main.tscn` (**Ctrl+S**).
4. Go to **Project → Project Settings → General → Run** and set `main.tscn` as the **Main Scene**.

---

## Step 3 — Create the VisualGasic Script

1. Select the `Calculator` node.
2. In the **Inspector**, click **Attach Script**.
3. Choose **VisualGasic** as the language.
4. Name it `calculator.vg` and click **Create**.

The editor opens with a blank `.vg` file. This is where all the VB6-style code lives.

---

## Step 4 — Declare State Variables

Every calculator needs a **state machine**. At the top of `calculator.vg`, add the module attribute and variables:

```vb
Attribute VB_Name = "Calculator"

' --- Display state (the calculator's "brain") ---
Dim displayText As String         ' Text shown on screen ("0", "123.45", etc.)
Dim currentValue As Double        ' Numeric value of displayText
Dim storedValue As Double         ' Left operand saved when user presses an operator
Dim pendingOperation As String    ' The operator waiting to be applied (+, -, *, /)
Dim clearOnNextDigit As Boolean   ' When True, next digit replaces the display
Dim hasDecimalPoint As Boolean    ' Prevents a second decimal point

' --- Memory register ---
Dim memoryValue As Double
Dim hasMemory As Boolean

' --- Button layout constants ---
Const BUTTON_WIDTH As Integer = 70
Const BUTTON_HEIGHT As Integer = 50
Const BUTTON_MARGIN As Integer = 5
Const DISPLAY_HEIGHT As Integer = 80
```

### 🔍 What You Just Learned

| VB6 Keyword | Purpose | GDScript Equivalent |
|-------------|---------|---------------------|
| `Dim` | Declare a variable | `var` |
| `As String` | Type annotation | `: String` |
| `As Double` | 64-bit float | `: float` |
| `As Boolean` | True/False | `: bool` |
| `Const` | Compile-time constant | `const` |

---

## Step 5 — Write the Initialization Code

Add the `_Ready()` and `ClearAll()` subroutines. `_Ready()` is called once when the node enters the scene tree — it's the VB6 equivalent of `Form_Load`.

```vb
Sub _Ready()
    Print "Calculator Ready"
    ClearAll
End Sub

Sub ClearAll()
    displayText = "0"
    currentValue = 0
    storedValue = 0
    pendingOperation = ""
    clearOnNextDigit = True
    hasDecimalPoint = False
End Sub

Sub ClearEntry()
    displayText = "0"
    currentValue = 0
    clearOnNextDigit = True
    hasDecimalPoint = False
End Sub
```

### 🔍 Key Concepts

- **`Sub`** defines a subroutine (like a `func` with no return value in GDScript).
- **`Print`** outputs to Godot's Output panel (equivalent to GDScript's `print()`).
- Calling `ClearAll` without parentheses is standard VB6 style.
- `ClearEntry` resets only the current number, preserving the pending operation.

---

## Step 6 — Handle Keyboard Input

VisualGasic uses Godot's `_Input()` callback for event-driven input. Add:

```vb
Sub _Input(ev As Variant)
    If ev Is InputEventKey Then
        If ev.pressed Then
            HandleKeyPress ev.keycode
        End If
    End If
End Sub
```

Now write the keyboard dispatcher using VB6-style `Select Case`:

```vb
Sub HandleKeyPress(keycode As Integer)
    Select Case keycode
        ' --- Digit keys (main row AND numpad) ---
        Case KEY_0, KEY_KP_0: InputDigit "0"
        Case KEY_1, KEY_KP_1: InputDigit "1"
        Case KEY_2, KEY_KP_2: InputDigit "2"
        Case KEY_3, KEY_KP_3: InputDigit "3"
        Case KEY_4, KEY_KP_4: InputDigit "4"
        Case KEY_5, KEY_KP_5: InputDigit "5"
        Case KEY_6, KEY_KP_6: InputDigit "6"
        Case KEY_7, KEY_KP_7: InputDigit "7"
        Case KEY_8, KEY_KP_8: InputDigit "8"
        Case KEY_9, KEY_KP_9: InputDigit "9"

        ' --- Operators ---
        Case KEY_PLUS, KEY_KP_ADD:        InputOperation "+"
        Case KEY_MINUS, KEY_KP_SUBTRACT:  InputOperation "-"
        Case KEY_ASTERISK, KEY_KP_MULTIPLY: InputOperation "*"
        Case KEY_SLASH, KEY_KP_DIVIDE:    InputOperation "/"

        ' --- Evaluate ---
        Case KEY_ENTER, KEY_KP_ENTER, KEY_EQUAL: Calculate

        ' --- Other ---
        Case KEY_PERIOD, KEY_KP_PERIOD: InputDecimal
        Case KEY_ESCAPE:                ClearAll
        Case KEY_DELETE, KEY_BACKSPACE: Backspace
        Case KEY_PERCENT:               CalculatePercent
    End Select
End Sub
```

### 🔍 Key Concepts

- **`Select Case`** is VB6's equivalent of `match` in GDScript. Each `Case` can list multiple values separated by commas.
- **`ev Is InputEventKey`** uses VB6-style runtime type checking (like `is` in GDScript).
- Godot's `KEY_*` constants are accessible directly — no imports needed.

---

## Step 7 — Digit Entry Logic

These three subroutines handle the core digit-entry state machine:

```vb
Sub InputDigit(digit As String)
    If clearOnNextDigit Then
        displayText = digit
        clearOnNextDigit = False
    Else
        If displayText = "0" And digit <> "0" Then
            displayText = digit             ' Replace leading zero
        ElseIf displayText <> "0" Or hasDecimalPoint Then
            If Len(displayText) < 15 Then
                displayText = displayText & digit  ' "&" = VB6 string concat
            End If
        End If
    End If
    currentValue = Val(displayText)         ' Val() converts String → Double
End Sub

Sub InputDecimal()
    If clearOnNextDigit Then
        displayText = "0."
        clearOnNextDigit = False
        hasDecimalPoint = True
    ElseIf Not hasDecimalPoint Then
        displayText = displayText & "."
        hasDecimalPoint = True
    End If
End Sub

Sub InputOperation(op As String)
    ' Chain operations: "2 + 3 +" evaluates 2+3 first
    If pendingOperation <> "" And Not clearOnNextDigit Then
        Calculate
    End If
    storedValue = currentValue
    pendingOperation = op
    clearOnNextDigit = True
    hasDecimalPoint = False
End Sub
```

### 🔍 VB6 String Functions Used

| Function | Purpose | Example |
|----------|---------|---------|
| `Len(s)` | String length | `Len("Hello")` → 5 |
| `Val(s)` | String → Number | `Val("3.14")` → 3.14 |
| `&` | Concatenate strings | `"Hi" & " there"` → `"Hi there"` |

---

## Step 8 — The Calculate Engine

This is the heart of the calculator — evaluating `storedValue ⟨op⟩ currentValue`:

```vb
Sub Calculate()
    If pendingOperation = "" Then Exit Sub

    Dim result As Double

    Select Case pendingOperation
        Case "+": result = storedValue + currentValue
        Case "-": result = storedValue - currentValue
        Case "*": result = storedValue * currentValue
        Case "/"
            If currentValue = 0 Then
                displayText = "Error"
                ClearAll
                displayText = "Error"
                Return
            End If
            result = storedValue / currentValue
    End Select

    currentValue = result
    displayText = FormatNumber(result)
    pendingOperation = ""
    clearOnNextDigit = True
    hasDecimalPoint = InStr(displayText, ".") > 0
End Sub
```

And the number formatter that strips trailing zeros:

```vb
Function FormatNumber(value As Double) As String
    Dim result As String
    result = Str(value)

    If InStr(result, ".") > 0 Then
        Do While Right(result, 1) = "0"
            result = Left(result, Len(result) - 1)
        Loop
        If Right(result, 1) = "." Then
            result = Left(result, Len(result) - 1)
        End If
    End If

    If Len(result) > 15 Then
        result = Left(result, 15)
    End If

    Return result
End Function
```

### 🔍 Key Concepts

- **`Function ... As String`** returns a value (vs. `Sub` which doesn't).
- **`Exit Sub`** / **`Return`** for early exits — both are valid VB6 idioms.
- **`InStr(haystack, needle)`** returns the position of `needle` in `haystack` (0 if not found).
- **`Do While ... Loop`** — classic VB6 loop structure.

---

## Step 9 — Memory Functions

Classic M+/M−/MR/MC support — a single independent accumulator:

```vb
Sub MemoryClear()
    memoryValue = 0
    hasMemory = False
End Sub

Sub MemoryRecall()
    currentValue = memoryValue
    displayText = FormatNumber(memoryValue)
    clearOnNextDigit = True
End Sub

Sub MemoryAdd()
    memoryValue = memoryValue + currentValue
    hasMemory = True
    clearOnNextDigit = True
End Sub

Sub MemorySubtract()
    memoryValue = memoryValue - currentValue
    hasMemory = True
    clearOnNextDigit = True
End Sub
```

---

## Step 10 — Draw the Interface

VisualGasic wraps Godot's `CanvasItem` drawing API with VB6-friendly commands. Add the `_Draw()` callback:

```vb
Sub _Draw()
    Dim screenWidth As Integer = 320
    Dim screenHeight As Integer = 480

    ' Background
    DrawRect 0, 0, screenWidth, screenHeight, Color("#2D2D2D")

    ' Display panel
    DrawRect 10, 10, screenWidth - 20, DISPLAY_HEIGHT, Color("#1A1A1A")

    ' Display text (right-aligned)
    Dim fontSize As Integer = 32
    Dim textWidth As Integer = Len(displayText) * 18
    DrawString displayText, screenWidth - 20 - textWidth, 45, Color.White, fontSize

    ' Pending operation indicator
    If pendingOperation <> "" Then
        DrawString pendingOperation, 20, 30, Color("#888888"), 20
    End If

    ' Memory indicator
    If hasMemory Then
        DrawString "M", 20, 55, Color("#888888"), 16
    End If

    DrawButtons
End Sub
```

And the button-grid renderer:

```vb
Sub DrawButtons()
    Dim startY As Integer = DISPLAY_HEIGHT + 20
    Dim startX As Integer = 10

    ' Row 0: Memory keys
    DrawButton "MC", startX, startY, 1, Color("#505050")
    DrawButton "MR", startX + 75, startY, 1, Color("#505050")
    DrawButton "M+", startX + 150, startY, 1, Color("#505050")
    DrawButton "M-", startX + 225, startY, 1, Color("#505050")

    ' Row 1: Functions
    startY = startY + 55
    DrawButton "C",   startX, startY, 1, Color("#D4D4D2")
    DrawButton "+/-", startX + 75, startY, 1, Color("#D4D4D2")
    DrawButton "%",   startX + 150, startY, 1, Color("#D4D4D2")
    DrawButton "/",   startX + 225, startY, 1, Color("#FF9F0A")

    ' Rows 2–4: Digits and operators
    startY = startY + 55
    DrawButton "7", startX, startY, 1, Color("#505050")
    DrawButton "8", startX + 75, startY, 1, Color("#505050")
    DrawButton "9", startX + 150, startY, 1, Color("#505050")
    DrawButton "*", startX + 225, startY, 1, Color("#FF9F0A")
    
    ' ... (rows 3-4 follow the same pattern for 4-5-6 and 1-2-3)

    ' Row 5: Wide zero, decimal, equals
    startY = startY + 165  ' Skip rows 3 and 4
    DrawButtonWide "0", startX, startY, Color("#505050")
    DrawButton ".", startX + 150, startY, 1, Color("#505050")
    DrawButton "=", startX + 225, startY, 1, Color("#FF9F0A")
End Sub

Sub DrawButton(text As String, x As Integer, y As Integer, cols As Integer, bgColor As Variant)
    Dim width As Integer = BUTTON_WIDTH * cols + BUTTON_MARGIN * (cols - 1)
    DrawRect x, y, width, BUTTON_HEIGHT, bgColor
    Dim textX As Integer = x + width / 2 - Len(text) * 8
    Dim textY As Integer = y + BUTTON_HEIGHT / 2 - 10
    DrawString text, textX, textY, Color.White, 24
End Sub

Sub DrawButtonWide(text As String, x As Integer, y As Integer, bgColor As Variant)
    Dim width As Integer = BUTTON_WIDTH * 2 + BUTTON_MARGIN
    DrawRect x, y, width, BUTTON_HEIGHT, bgColor
    Dim textX As Integer = x + 30
    Dim textY As Integer = y + BUTTON_HEIGHT / 2 - 10
    DrawString text, textX, textY, Color.White, 24
End Sub
```

### 🔍 Drawing API

| Command | Purpose | GDScript Equivalent |
|---------|---------|---------------------|
| `DrawRect x, y, w, h, color` | Filled rectangle | `draw_rect()` |
| `DrawString text, x, y, color, size` | Text rendering | `draw_string()` |
| `Color("#hex")` | Colour from hex | `Color("#hex")` |
| `Color.White` | Named colour | `Color.WHITE` |

---

## Step 11 — Add Mouse Click Support

For touchscreen and mouse users, add hit detection using the button grid layout:

```vb
Sub _UnhandledInput(ev As Variant)
    If ev Is InputEventMouseButton Then
        If ev.pressed And ev.button_index = MOUSE_BUTTON_LEFT Then
            HandleMouseClick ev.position.x, ev.position.y
        End If
    End If
End Sub

Sub HandleMouseClick(mx As Single, my As Single)
    Dim startY As Integer = DISPLAY_HEIGHT + 20
    Dim startX As Integer = 10

    ' Convert pixel position to grid row/col
    Dim row As Integer = Int((my - startY) / 55)
    Dim col As Integer = Int((mx - startX) / 75)

    If row < 0 Or row > 5 Or col < 0 Or col > 3 Then Exit Sub

    Select Case row
        Case 0  ' Memory: MC | MR | M+ | M-
            Select Case col
                Case 0: MemoryClear
                Case 1: MemoryRecall
                Case 2: MemoryAdd
                Case 3: MemorySubtract
            End Select
        Case 1  ' Functions: C | +/- | % | /
            Select Case col
                Case 0: ClearAll
                Case 1: ToggleSign
                Case 2: CalculatePercent
                Case 3: InputOperation "/"
            End Select
        Case 2  ' 7 | 8 | 9 | *
            Select Case col
                Case 0: InputDigit "7"
                Case 1: InputDigit "8"
                Case 2: InputDigit "9"
                Case 3: InputOperation "*"
            End Select
        ' ... rows 3-5 follow the same pattern
    End Select
End Sub
```

### 🔍 Key Concepts

- **`_UnhandledInput()`** receives events not consumed by the GUI — prevents keyboard and mouse interference.
- **Integer division hit detection**: `Int((pixel - origin) / cellSize)` converts pixel coordinates to grid indices. No per-button bounding boxes needed!
- **Nested `Select Case`**: outer = row, inner = column. Clean and readable.

---

## Step 12 — Run Your Calculator!

1. Press **F5** (or click ▶ **Run Project**) in Godot.
2. Use the **keyboard** or **click buttons** with the mouse.
3. Try chained operations: `5 + 3 * 2 =` (evaluates left to right, like a physical calculator).
4. Test memory: type `42`, press **M+**, type `100 - MR =` → `58`.

**Congratulations!** 🎉 You've built a complete application in VisualGasic.

---

## What You Learned

| Concept | VB6 Syntax | Where Used |
|---------|------------|------------|
| Variables | `Dim x As Type` | State machine |
| Constants | `Const X As Integer = 70` | Button layout |
| Subroutines | `Sub Name() ... End Sub` | All logic |
| Functions | `Function Name() As Type` | `FormatNumber` |
| Select Case | `Select Case x ... End Select` | Input dispatch |
| String ops | `Len`, `Val`, `Left`, `Right`, `InStr` | Digit entry |
| Loops | `Do While ... Loop` | Trailing zeros |
| Type checks | `ev Is InputEventKey` | Input handling |
| Drawing | `DrawRect`, `DrawString` | UI rendering |
| Events | `_Ready`, `_Input`, `_Draw` | Godot lifecycle |

---

## Next Steps

- 🎮 **Build a game** → [Game Development Tutorial](GAME_DEVELOPMENT.md)
- 🧰 **Explore the Visual Gasic IDE** → drag-and-drop UI without custom drawing
- 📚 **Learn advanced features** → [Modern Features Guide](../guides/MODERN_FEATURES.md)
- 🏎 **Benchmark your code** → [Performance Guide](../manual/performance.md)

---

## Complete Source Code

The full calculator source (557 lines with extensive comments) is available at:  
**`demos/UI/Calculator/calculator.vg`**

To run the finished demo:
```bash
cd demos/UI/Calculator
godot --path . -s main.tscn
```

---

*Tutorial written for VisualGasic v3.2.0 Beta 1*

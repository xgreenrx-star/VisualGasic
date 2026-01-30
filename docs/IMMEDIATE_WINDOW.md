# Immediate Window - Interactive Development Console

The **Immediate Window** provides a live, interactive console for executing code expressions and statements during development.

## Overview

The Immediate Window is a comprehensive development tool featuring:
- ✅ Multi-line code editor with syntax highlighting
- ✅ Real-time variable tracking and inspection
- ✅ Object inspector with property drill-down
- ✅ Watch expressions for monitoring values
- ✅ Auto-completion for functions and variables
- ✅ Session save/load functionality
- ✅ Command history with full navigation
- ✅ Quick action toolbar

## Interface Layout

The window is split into three main sections:

### Left Panel: Console (70%)
- **Toolbar** with quick actions (Repeat, Save, Load, Clear, Help)
- **Output area** showing execution results (color-coded)
- **Multi-line input** with syntax highlighting (CodeEdit)

### Right Panel: Tabs (30%)
Three tabs for different views:
1. **Variables** - All declared variables with types and values
2. **Watch** - Monitored expressions that update automatically
3. **Inspector** - Deep object property and method browser

## Features

### 1. Multi-Line Code Input

The input field is a full CodeEdit control:
- **Shift+Enter** - Add new line without executing
- **Enter** - Execute all code
- **Syntax highlighting** - Keywords, strings, numbers colored
- **Line numbers** - Gutter shows line numbers
- **Auto-completion** - Ctrl+Space for suggestions
- **Brace matching** - Automatic brace/bracket completion

Example:
```
> For i = 1 To 5
    If i Mod 2 = 0 Then
      Print i & " is even"
    End If
  Next
```

### 2. Variable Inspector Panel

The **Variables** tab shows all declared variables:

| Name | Type | Value |
|------|------|-------|
| player_health | Integer | 100 |
| player_name | String | "Hero" |
| is_active | Boolean | true |

**Actions:**
- Click variable → Inserts name into input field
- Auto-updates after each execution
- Shows type information
- Persists during session

### 3. Watch Expressions

Monitor specific expressions continuously:

**Add watch:**
```
> :watch player_health * 2
> :watch enemy.position.x
```

Or click **➕ Add** button in Watch tab.

**Features:**
- Auto-evaluates after each command
- Persistent across commands
- Click expression to edit
- Remove by right-clicking (future)

**Watch Tab Display:**
| Expression | Value |
|------------|-------|
| player_health * 2 | 200 |
| enemy.position.x | 150.5 |

### 4. Object Inspector

When you execute an expression that returns an object, the Inspector tab activates:

```
> GetNode("/root/Player")
[Inspector shows full object hierarchy]
```

**Inspector Structure:**
```
▼ CharacterBody2D (Player)
  ├─ 📝 Properties
  │   ├─ position: Vector2(100, 200)
  │   ├─ velocity: Vector2(0, 0)
  │   ├─ health: 100
  │   └─ name: "Player"
  ├─ 🔧 Methods (25)
  │   ├─ move_and_slide() -> bool
  │   ├─ get_position() -> Vector2
  │   └─ set_health(value: int)
  └─ 👶 Children (3)
      ├─ Sprite2D (PlayerSprite)
      ├─ CollisionShape2D
      └─ AudioStreamPlayer
```

**Actions:**
- Click property → Copy to input field
- Click method → Insert method call
- Click child → Inspect nested object
- Expand complex types (Arrays, Dictionaries)
- Filter bar to search properties
- Pin button to keep object visible
- Refresh button to update view

**Expandable Types:**

**Arrays:**
```
▼ Array [5 items]
  ├─ [0]: "apple"
  ├─ [1]: "banana"
  └─ [2]: "cherry"
```

**Dictionaries:**
```
▼ Dictionary {3 keys}
  ├─ "name": "Player"
  ├─ "score": 1000
  └─▶ "inventory": Dictionary {5 keys}
```

### 5. Auto-Completion

Press **Ctrl+Space** to trigger auto-completion:

**Completes:**
- Built-in functions (Print, Len, Left, Right, etc.)
- Keywords (Dim, If, For, While, etc.)
- Your declared variables
- Object properties (when typing after `.`)

**Example:**
```
> Dim player_health = 100
> Dim player_name = "Hero"
> play[Ctrl+Space]
  → Suggestions: player_health, player_name
```

### 6. Syntax Highlighting

Input field uses full syntax highlighting:
- **Keywords** - Pink (Dim, If, For, etc.)
- **Strings** - Yellow ("text")
- **Numbers** - Cyan (42, 3.14)
- **Comments** - Green (' comment)
- **Operators** - White (+, -, *, =)

### 7. Quick Actions Toolbar

Top toolbar buttons:

| Button | Shortcut | Action |
|--------|----------|--------|
| ↻ Repeat | Ctrl+R | Repeat last command |
| 💾 Save | - | Save session to file |
| 📂 Load | - | Load session from file |
| Clear | Ctrl+L | Clear output window |
| Help | - | Show help message |

### 8. Session Save/Load

**Save Session:**
```
> :save my_session.vgsession
```
Or click **💾 Save** button.

Saves all executed commands to a file. Can be loaded later to replay the entire session.

**Load Session:**
```
> :load my_session.vgsession
```
Or click **📂 Load** button.

Executes all commands from the saved file in sequence.

**Use Cases:**
- Save debugging sessions
- Share test scenarios
- Create reproducible test cases
- Quick setup scripts

## Interactive Commands

Access special commands with `:` prefix:

| Command | Description |
|---------|-------------|
| `:help` | Show available commands |
| `:clear` | Clear output window |
| `:vars` | List all variables with types and values |
| `:history` | Show command history |
| `:reset` | Reset console state (clears everything) |
| `:watch [expr]` | Add watch expression |
| `:save [file]` | Save session to file |
| `:load [file]` | Load session from file |

### Examples:
```
> :vars
Variables:
  player_health: Integer = 100
  player_name: String = "Hero"

> :watch player_health
Added watch: player_health

> :save debug_session.vgsession
Session saved to: user://debug_session.vgsession

> :history
Command History:
  1: Dim x = 42
  2: x * 2
  3: Print x
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Enter** | Execute code |
| **Shift+Enter** | New line (multi-line input) |
| **Ctrl+Space** | Trigger auto-completion |
| **Ctrl+R** | Repeat last command |
| **Ctrl+L** | Clear output window |
| **Up Arrow** | Previous command (history) |
| **Down Arrow** | Next command (history) |
| **Tab** | Accept completion (future) |

## Usage Examples

### Quick Calculations
```
> 2 + 2
4

> 1920 / 16
120

> Abs(-42)
42
```

### Variable Declarations
```
> Dim x As Integer = 42
✓ x: Integer = 42

> Dim message As String = "Hello"
✓ message: String = "Hello"

> x * 2
84
```

### Multi-Line Code
```
> For i = 1 To 5
    Dim result = i * 2
    Print result
  Next
2
4
6Object Inspector Deep Dive

#### Inspecting Nodes
```
> GetNode("/root/Main/Player")

[Inspector shows:]
▼ CharacterBody2D (Player)
  ├─ 📝 Properties
  │   ├─ position: Vector2(100, 200)
  │   ├─ velocity: Vector2(50, -100)
  │   ├─ health: 100
  │   ├─ speed: 200.0
  │   └─ name: "Player"
  ├─ 🔧 Methods (48)
  │   ├─ move_and_slide() -> bool
  │   ├─ get_position() -> Vector2
  │   ├─ set_velocity(velocity: Vector2) -> void
  │   ├─ apply_force(force: Vector2) -> void
  │   └─ ... (44 more)
  └─ 👶 Children (4)
      ├─ Sprite2D (PlayerSprite)
      ├─ CollisionShape2D
      ├─ AnimationPlayer
      └─ AudioStreamPlayer
```

**Actions:**
- Click `position` → Input field: `obj.position`
- Click `move_and_slide()` → Input field: `obj.move_and_slide()`
- Click `Sprite2D` → Inspector switches to Sprite2D object

#### Inspecting Arrays
```
> Dim items = ["sword", "shield", "potion", "key"]
> items

[Inspector shows:]
▼ Array [4 items]
  ├─ [0]: "sword"
  ├─ [1]: "shield"
  ├─ [2]: "potion"
  └─ [3]: "key"
```

#### Inspecting Dictionaries
```
> Dim player_data = {"name": "Hero", "hp": 100, "items": ["sword"]}
> player_data

[Inspector shows:]
▼ Dictionary {3 keys}
  ├─ "name": "Hero"
  ├─ "hp": 100
  └─▶ "items": Array [1 item]
      └─ [0]: "sword"
```

#### Filter Properties
Use the filter bar at top of Inspector:
- Type "pos" → Shows only properties/methods containing "pos"
- Type "get_" → Shows only getters
- Case-insensitive search

### Watch Expression Patterns

**Monitor calculations:**
```
> :watch player.health / player.max_health
> :watch enemy_count * 10
```

**Track object properties:**
```
> :watch player.position.x
> :watch player.velocity.length()
```

**Boolean conditions:**
```
> :watch player.health > 0
> :watch player.position.x > 100 And player.position.y < 200
```

###Best Practices

### 1. Use Variables Tab
Instead of typing `:vars`, just switch to Variables tab to see all variables with types and values in real-time.

### 2. Pin Important Objects
When inspecting an object you'll reference frequently:
- Click 📌 Pin button in Inspector
- Object stays visible even when executing other commands

### 3. Watch Critical Values
Add watches for values you check repeatedly:
```
> :watch player.health
> :watch fps
> :watch enemy_count
```

### 4. Save Debug Sessions
When investigating bugs, save your session:
```
> :save bug_investigation.vgsession
```
Can replay later or share with team.

### 5. Multi-Line for Clarity
Use Shift+Enter to format complex code readably:
```
> For each in collection
    If item.valid Then
      Print item.name
    End If
  Next
```

### 6. Use Auto-Completion
Press Ctrl+Space after typing a few letters:
```
> Dim play[Ctrl+Space]
  → player_health, player_name, player_position
```

### 7. Quick Method Testing
Click methods in Inspector to test them:
- Inspector shows: `move_and_slide()`
- Click → Input field: `player.move_and_slide()`
- Press Enter to test

## Workflow Examples

### Debugging Scene Tree
```
1. > GetNode("/root/Main")
   [Inspector shows Main node]

2. Click "Children" in Inspector
   [See all child nodes]

3. Click on specific child
   [Inspector updates to show that child]

4. Check properties:
   position: Vector2(0, 0)
   visible: true
```

###Troubleshooting

### Expression Not Recognized
```
> unknownFunction()
[ERROR] Parse error: Unknown identifier 'unknownFunction'
```
**Solution:** Check spelling, ensure function exists, try Ctrl+Space for suggestions

### Variable Not Found
```
> player_health
[ERROR] Execution failed
```
**Solution:** Declare variable first with `Dim player_health = 100`

### Type Mismatch
```
> Dim x As Integer = "text"
[ERROR] Type mismatch
```
**Solution:** Ensure value matches declared type

### Object Inspector Empty
**Problem:** Inspector tab shows nothing after executing object expression  
**Solution:** 
- Check that expression actually returns an object
- Try refreshing with 🔄 button
- Ensure object is not null

### Watch Not Updating
**Problem:** Watch expression shows old value  
**Solution:**
- Watch updates after each command execution
- Execute any command to trigger update
- Or click refresh in Watch tab

### Multi-Line Not Working
**Problem:** Enter key executes before finishing multi-line code  
**Solution:** Use **Shift+Enter** to add new lines without executing

### History Navigation Not Working
**Problem:** Up/Down arrows don't navigate history  
**Solution:** 
- Ensure input field has focus
- Up/Down works only when cursor is in input field
- Click input field first

## Feature Summary

### ✅ Implemented Features

1. **Multi-Line Input** - CodeEdit with syntax highlighting
2. **Auto-Completion** - Ctrl+Space for suggestions
3. **Variable Inspector** - Real-time variable tracking in Variables tab
4. **Watch Expressions** - Monitor expressions in Watch tab
5. **Object Inspector** - Deep object drill-down in Inspector tab
6. **Syntax Highlighting** - Color-coded input with line numbers
7. **Quick Actions** - Toolbar with Repeat, Save, Load, Clear
8. **Session Save/Load** - Export/import command history
9. **Command History** - Up/Down navigation through past commands
10. **Enhanced Error Reporting** - Detailed error messages with context

### 🎯 Key Benefits

- **Faster Development** - Test code without recompiling
- **Better Debugging** - Inspect objects and watch values in real-time
- **Learning Tool** - Experiment with language features safely
- **Productivity** - Auto-completion and multi-line editing
- **Reproducibility** - Save and replay sessions

---

## Quick Reference Card

**Opening:** Bottom panel → **Immediate** tab

**Input:**
- Type code in input field
- Shift+Enter: new line
- Enter: execute
- Ctrl+Space: auto-complete

**Commands:**
- `:help` - Show help
- `:vars` - List variables
- `:watch expr` - Add watch
- `:save file` - Save session
- `:load file` - Load session
- `:clear` - Clear output
- `:reset` - Reset everything

**Shortcuts:**
- Ctrl+R: Repeat last
- Ctrl+L: Clear output
- Up/Down: Navigate history

**Panels:**
- **Variables** - View all variables
- **Watch** - Monitor expressions  
- **Inspector** - Explore objects

**Made development interactive and powerful!**

### Boolean Logic
```
> True And False
False

> True Or False
True

> Not True
False
```

### Type Conversions
```
> CInt("42")
42

> CStr(100)
"100"

> CDbl("3.14")
3.14
```

## Limitations

- No direct access to scene runtime (use Print to scene nodes)
- Variables reset on editor restart
- Complex multi-line structures may require careful formatting
- No breakpoint integration (separate debugger feature)

## Troubleshooting

### Expression Not Recognized
```
> unknownFunction()
[ERROR] Parse error: Unknown identifier
```
→ Check function name spelling and availability

### Type Mismatch
```
> Dim x As Integer = "text"
[ERROR] Type mismatch
```
→ Ensure value matches declared type

### Syntax Error
```
> Dim x As Integer
[ERROR] Expected assignment
```
→ Check statement syntax

## Best Practices

1. **Test First** - Verify expressions before adding to code
2. **Use Comments** - Document complex calculations
3. **Clear Regularly** - Use `:clear` to keep output manageable
4. **Check History** - Use `:history` to review past commands
5. **Save Important** - Copy useful expressions to script files

## Examples

### Game Development
```
> Dim screen_width As Integer = 1920
> Dim screen_height As Integer = 1080
> Dim center_x As Integer = screen_width / 2
> center_x
960

> Dim center_y As Integer = screen_height / 2
> center_y
540
```

### Data Processing
```
> Dim csv_data As String = "100,200,300"
> Dim parts As Array = csv_data.split(",")
> parts[0]
"100"

> CInt(parts[0]) + CInt(parts[1])
300
```

### Algorithm Testing
```
> Dim max_value As Integer = 100
> Dim min_value As Integer = 0
> Dim range As Integer = max_value - min_value
> range
100

> Dim normalized As Float = 0.5
> Dim value As Integer = min_value + (range * normalized)
> value
50
```

---

**The Immediate Window makes development faster and more interactive!**

Access it from the bottom panel → **Immediate** tab.

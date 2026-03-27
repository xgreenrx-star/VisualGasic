# Debugging in VisualGasic

VisualGasic provides a full VB6-style debugging experience: **Run**, **Break**, **Step**, **Watch**, and **Set Next Statement** — all integrated into the Godot editor.

---

## Debug Toolbar

The **Debug toolbar** is located in the Immediate Window panel at the bottom of the IDE:

```
Debug: ▶ Continue  ⏸ Break  ⏩ Step Over  ⬇ Step Into  ⬆ Step Out  ■ Stop
```

![Debug Toolbar](../screenshots/ide_debug_toolbar.png)

*The debug toolbar with all six controls. Buttons enable/disable based on the current debug state.*

### Button States

| State | Continue | Break | Step Over | Step Into | Step Out | Stop |
|-------|----------|-------|-----------|-----------|----------|------|
| **Not running** | Disabled | Disabled | Disabled | Disabled | Disabled | Disabled |
| **Running** | Disabled | ✅ Enabled | Disabled | Disabled | Disabled | ✅ Enabled |
| **Paused (break)** | ✅ Enabled | Disabled | ✅ Enabled | ✅ Enabled | ✅ Enabled | ✅ Enabled |

The toolbar automatically detects when a scene starts or stops playing and updates accordingly.

---

## Starting a Debug Session

There are several ways to run your project:

| Method | Shortcut | Description |
|--------|----------|-------------|
| **Debug → Start** | — | Run the project's main scene |
| **Debug → Start Current** | — | Run the currently open scene |
| **▶ Preview** (toolbar) | F5 | Preview the current form |
| **Preview+Debug** (toolbar) | Shift+F5 | Preview with Immediate Window connected |
| **▶ Run Project** (toolbar) | Ctrl+F5 | Run the main scene |
| **Debug → Break** | Pause | Pause execution at the next statement |
| **Debug → Stop** | — | Stop the running scene |

---

## Breakpoints

### Setting Breakpoints

Click in the **gutter** (left margin) of the Code Editor to toggle a breakpoint on that line. A red circle ● appears to indicate the breakpoint.

**Keyboard shortcut:** Press **F9** to toggle a breakpoint on the current line.

### Conditional Breakpoints

Right-click an existing breakpoint (or press **Ctrl+Shift+F9**) to set a condition:

- **Condition expression**: Break only when an expression is true (e.g., `i > 50`)
- **Hit count**: Break after a certain number of hits (equals N, ≥ N, or multiple of N)
- **Log message**: Print a message instead of breaking — use `{variable}` for substitution (tracepoints)
- **Temporary**: Auto-delete after the first hit

### When a Breakpoint Hits

When execution pauses at a breakpoint:

1. The **yellow arrow** (▶) appears in the gutter showing the current line
2. The Code Editor scrolls to and highlights the current line
3. The **Variables** tab in the Immediate Window updates with all local variables
4. The **Call Stack** tab shows the full call chain
5. All **Step** controls become active

---

## ⏸ Break (Pause) Button

The **Break** button (⏸) pauses a running program at the next executable statement — just like VB6's Break button.

**How it works:**
1. Click ⏸ **Break** (or press the **Pause** key) while your game is running
2. The VM sets an internal `break_requested` flag
3. At the next `OP_DEBUG_LINE` instruction, the VM enters the debugger
4. Execution pauses and you can inspect variables, step through code, or continue

**Use cases:**
- Pause a game that's running to inspect state
- Break into an infinite loop or long-running operation
- Interrupt normal execution to check variable values

> **Note:** Break pauses at the *next* statement the VM executes. If code is in a tight native loop (e.g., a Godot engine call), the pause will occur when control returns to VG code.

---

## Stepping Controls

Once paused at a breakpoint or break, use the stepping controls:

### ⏩ Step Over (F10)

Execute the current line and pause at the next line in the same procedure. If the line calls a Sub or Function, the entire call executes without pausing inside it.

```vb
Dim x = 10          ' ← paused here
Call DoSomething()   ' Step Over: runs DoSomething entirely, pauses on next line
Print x              ' ← pauses here
```

### ⬇ Step Into (F11)

Execute the current line. If it calls a Sub or Function, pause at the **first line** inside that routine.

```vb
Dim x = 10          ' ← paused here
Call DoSomething()   ' Step Into: jumps to the first line of DoSomething()
Print x
```

### ⬆ Step Out (Shift+F11)

Resume execution until the current Sub or Function returns, then pause at the line after the call site.

```vb
Sub DoSomething()
    Dim y = 20       ' ← paused here
    Print y          ' Step Out: runs this line...
End Sub              ' ...and this...
' ← pauses here (back in the caller)
```

### ▶ Continue (F5)

Resume full-speed execution until the next breakpoint is hit or the program ends.

---

## Set Next Statement (Yellow Arrow Drag)

**Drag the yellow arrow** (▶) in the gutter to move the execution point to a different line — skipping or re-executing code without restarting.

**Rules:**
- You can only move within the **current procedure** (Sub/Function)
- The arrow snaps to the nearest executable line
- Moving backwards re-executes code; moving forward skips it
- You cannot drag past `End Sub` / `End Function` boundaries

**Tip:** This is the same feature as VB6's "Set Next Statement" — useful for re-running a line after fixing a variable value in the Immediate Window.

![Set Next Statement hint](../screenshots/ide_debug_toolbar.png)

*The yellow status bar reads "Drag yellow arrow in gutter to Set Next Statement"*

---

## Exception Assistant

When an unhandled runtime error occurs, the **Exception Assistant** popup appears:

- Shows the error message and the line that caused it
- **Continue** button: Skip the error and keep running (advances past the faulting line)
- **Break** button: Pause at the error line so you can inspect state
- **Stop** button: End the program

The Exception Assistant mimics VB6's error dialog, letting you choose how to handle unexpected errors during development.

---

## Variables Panel

The **Variables** tab (in the Immediate Window's right panel) shows all variables in scope:

| Column | Description |
|--------|-------------|
| **Name** | Variable name (click column header to sort A-Z / Z-A) |
| **Type** | Data type (Integer, String, Boolean, etc.) |
| **Value** | Current value (click to edit in-place) |

- **Live toggle** (🔵): When enabled, variables refresh automatically every 500ms
- **Filter field** (🔍): Type to search by variable name
- **Sort by column**: Click any column header to sort ascending/descending
- **Color coding**: Changed values highlight in yellow; new values in green

---

## Watch Expressions

The **Watch** tab lets you monitor specific expressions:

1. Click **➕ Add** in the Watch tab
2. Type an expression (e.g., `player.health * 2`, `enemies.size()`)
3. The expression evaluates automatically whenever execution pauses

Watch expressions persist across debug sessions.

---

## Call Stack

The **Call Stack** tab shows the chain of procedure calls:

```
#0  btnEquals_Click()    Form1.vg:15
#1  _on_btnEquals_pressed()   Form1.vg:42
#2  Form_Load()          Form1.vg:5
```

- Click any frame to jump to that location in the Code Editor
- The current frame is highlighted
- Updated automatically on each break/step

---

## Immediate Window (REPL)

While paused, you can type expressions and statements directly in the **Immediate Window** input field:

```
> Print x
10
> x = 42
> Print x
42
> ? player.health
100
```

- **?** is shorthand for `Print`
- You can modify variables, call functions, and evaluate expressions
- Changes take effect immediately in the running program
- Press **Enter** to execute; **Shift+Enter** for multiline input

---

## Data Breakpoints (Watchpoints)

Break when a variable's value changes:

```
> :watchpoint player_health
```

The debugger will pause whenever `player_health` is modified by any code path.

---

## Debug Menu Reference

| Menu Item | ID | Shortcut | Description |
|-----------|----|----------|-------------|
| **Start** | 0 | — | Run main scene |
| **Start Current** | 1 | — | Run current scene |
| **Break** | 2 | Pause | Pause at next statement |
| **Stop** | 10 | — | Stop running scene |

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| **F5** | Preview Form / Continue |
| **Shift+F5** | Preview + Debug |
| **Ctrl+F5** | Run Project |
| **F9** | Toggle Breakpoint |
| **Ctrl+Shift+F9** | Conditional Breakpoint |
| **Pause** | Break (pause execution) |
| **F10** | Step Over |
| **F11** | Step Into |
| **Shift+F11** | Step Out |
| **Ctrl+G** | Go To Line |

---

## Tips

1. **Use Break for infinite loops** — if your game freezes, hit ⏸ Break to find the stuck line
2. **Set Next Statement to retry** — drag the yellow arrow back to re-execute a line after fixing a variable
3. **Combine Watch + Break** — set a watch on a variable, then use data breakpoints to catch unexpected changes
4. **Conditional breakpoints for hot paths** — use `hit count ≥ 100` to skip the first 99 iterations of a loop
5. **Tracepoints don't pause** — use log messages with `{variable}` substitution to trace without stopping
6. **Live variables** — toggle the Live switch in the Variables panel for real-time updates without stepping

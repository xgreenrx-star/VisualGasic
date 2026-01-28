### 1. Multiple Forms
You can now load external forms (scenes) using `LoadForm`.

```basic
Sub cmdOpenOptions_Click()
    ' Loads Options.tscn from res://
    LoadForm "Options.tscn"
End Sub
```

### 2. Autocomplete
When you type a dot `.`, the editor now suggests common control properties:
*   `text`
*   `visible`
*   `disabled`
*   `show()`
*   `stop()` (for Timers)

### 3. Debug Console
The `Print` command now supports a runtime Debug Console.
If you add a node (e.g., `RichTextLabel`) named `ImmediateWindow` or `DebugConsole` to your scene, `Print` output will potentially be appended to it automatically.

```basic
Sub cmdTest_Click()
    Print "This goes to the Output panel AND the runtime console if present."
End Sub
```

### 4. Modern Language Features (v2)
VisualGasic now supports several modern convenience features while maintaining backward compatibility.

#### Inline If (Python-Style Ternary)
You can now write concise conditional expressions that read like natural language. This is the preferred syntax for conditional assignment.
```basic
Dim status As String
status = "Winner" If score > 100 Else "Try Again"
```

#### IIf Function
The classic `IIf` function is fully supported and maps internally to the simplified Inline If logic (including short-circuiting). It also supports named arguments for clarity.
```basic
' Classic
res = IIf(x > 5, "Big", "Small")

' Named Arguments
res = IIf(x > 5, True="Big", False="Small")
```

#### Short-Circuit Logic
New operators `AndAlso` and `OrElse` allow for short-circuit evaluation (the second operand is skipped if the result is determined by the first).
```basic
If obj Is Nothing OrElse obj.Value = 0 Then
    Print "Safe!"
End If
```

#### String Interpolation
Embed variables directly in strings using the `$` prefix.
```basic
Dim name As String = " User"
Print $"Hello{name}, score is {score}"
```

#### Control Flow
*   `Return [Value]`: Exit a Sub or Function immediately (optionally returning a value).
*   `Continue For/Do/While`: Skip to the next iteration of a loop.

### Bytecode Baseline Updates
- 2026-01-27: Refreshed bytecode baseline for entries: BenchArithmetic, BenchArraySum, BenchStringConcat, BenchBranch.


### Benchmark Updates
- 2026-01-28: Updated [docs/manual/performance.md](docs/manual/performance.md) with the latest Arithmetic/ArraySum/StringConcat/Branching results and delta comparisons against the 2026-01-26 sweep.

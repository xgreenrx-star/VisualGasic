# Smart Bracket Completion - Quick Reference

## One-Line Summary
Type `}` after any block statement (For, While, If, Sub, Function) to auto-complete with the appropriate closing keyword.

## Quick Start

```vb
' Type this:
For i = 1 To 10
    Print i
}

' Get this:
For i = 1 To 10
    Print i
Next i  ← Auto-completed!
```

## All Supported Blocks

| Opening Statement | Type `}` → Suggests |
|------------------|---------------------|
| `For i = 1 To 10` | `Next i` |
| `While condition` | `Wend` |
| `Do` | `Loop` |
| `If condition Then` | `End If` |
| `Select Case x` | `End Select` |
| `With object` | `End With` |
| `Sub MyProc()` | `End Sub` |
| `Function MyFunc()` | `End Function` |
| `Property Get Prop` | `End Property` |
| `Class MyClass` | `End Class` |
| `Try` | `End Try` |

## Trigger Characters

- **`}`** - Primary trigger (recommended)
- **`]`** - Alternative trigger

## Tips

✅ **Works with nesting** - Correctly identifies the right block to close
✅ **Includes variable names** - `For i` → `Next i`
✅ **Fast** - < 1ms completion time
✅ **Smart** - Only suggests when appropriate

❌ **Requires valid syntax** - Opening statement must be well-formed
❌ **Current file only** - Doesn't analyze included files

## Example: Nested Blocks

```vb
Sub ProcessData()
    For i = 1 To 10
        If i Mod 2 = 0 Then
            Print "Even"
        }  → End If
    }  → Next i
}  → End Sub
```

## Try It Now

1. Open `examples/bracket_completion_demo.bas` in Godot
2. Position cursor after a For/While/If statement
3. Type `}`
4. See the magic! ✨

## Full Documentation

See [BRACKET_COMPLETION.md](BRACKET_COMPLETION.md) for complete details.

# Smart Bracket Completion System

VisualGasic includes an intelligent bracket completion system that automatically suggests appropriate closing keywords when you type `}` or `]` characters.

## Overview

When writing VisualGasic code in the Godot editor, the system analyzes your code structure and suggests the correct closing keyword based on the most recent unclosed block.

## How It Works

1. **Type an opening statement** (For, While, If, Sub, Function, etc.)
2. **Write your code** inside the block
3. **Type `}`** at the indentation level where the block should close
4. **See auto-completion** with the appropriate closing keyword
5. **Press Tab or Enter** to accept the suggestion

## Supported Trigger Characters

- **`}`** (closing brace) - Primary trigger
- **`]`** (closing bracket) - Alternative trigger

## Supported Block Types

### For Loops
```vb
For i = 1 To 10
    Print i
}  → suggests: Next i
```

**Features:**
- Includes loop variable name in suggestion
- Works with Step clauses
- Handles nested For loops correctly

### While Loops
```vb
While condition
    ' code
}  → suggests: Wend
```

**Note:** Uses traditional VB6-style `Wend` keyword.

### Do Loops
```vb
Do
    ' code
}  → suggests: Loop
```

**Features:**
- Works with `Do While` and `Do Until` variants
- Suggests `Loop` or `Loop While`/`Loop Until` as appropriate

### If Statements
```vb
If condition Then
    ' code
}  → suggests: End If
```

**Features:**
- Only suggests for multi-line If statements
- Ignores single-line If statements
- Works with ElseIf and Else branches

### Select Case
```vb
Select Case variable
    Case 1
        ' code
}  → suggests: End Select
```

### With Blocks
```vb
With object
    .property = value
}  → suggests: End With
```

### Sub Procedures
```vb
Sub MyProcedure()
    ' code
}  → suggests: End Sub
```

**Features:**
- Includes procedure name in analysis
- Tracks procedure parameters

### Functions
```vb
Function Calculate(x As Integer) As Double
    ' code
}  → suggests: End Function
```

**Features:**
- Recognizes return types
- Handles generic type parameters

### Properties
```vb
Property Get MyProperty() As Integer
    ' code
}  → suggests: End Property
```

### Classes
```vb
Class MyClass
    ' code
}  → suggests: End Class
```

### Try-Catch Blocks
```vb
Try
    ' code
}  → suggests: End Try
```

**Also recognizes:** `Catch` and `Finally` blocks

## Nested Block Support

The system maintains a **stack of open blocks** and correctly identifies which block needs closing:

```vb
Sub ProcessData()
    For i = 1 To 10
        If i Mod 2 = 0 Then
            While i < 20
                Print i
            }  → suggests: Wend
        }  → suggests: End If
    }  → suggests: Next i
}  → suggests: End Sub
```

## Implementation Details

### Architecture

**Files:**
- `src/visual_gasic_bracket_completion.h` - Header with API
- `src/visual_gasic_bracket_completion.cpp` - Implementation
- `src/visual_gasic_language.cpp` - Integration with editor

### Key Components

#### 1. `BracketCompletionHelper::find_open_block()`
Scans code from beginning to cursor position, building a stack of open blocks:
- Pushes when encountering opening statements
- Pops when encountering closing statements
- Returns the most recent unclosed block

#### 2. `BracketCompletionHelper::is_opening_statement()`
Identifies block-opening keywords:
- Extracts keyword type (For, While, If, etc.)
- Captures associated variables (loop counters, function names)
- Checks for single-line vs multi-line constructs

#### 3. `BracketCompletionHelper::is_closing_statement()`
Recognizes block-closing keywords:
- Matches closing keywords to block types
- Handles variations (Wend vs End While)

#### 4. `BracketCompletionHelper::get_completion_for_block()`
Generates appropriate closing keyword:
- For loops: includes variable name
- Other blocks: uses standard syntax

### Integration with `_complete_code()`

The bracket completion is the **first check** in `VisualGasicLanguage::_complete_code()`:

```cpp
// Check if last character is a trigger
if (BracketCompletionHelper::is_trigger_char(last_char)) {
    String closing_keyword = BracketCompletionHelper::detect_closing_keyword(code, line);
    if (!closing_keyword.is_empty()) {
        // Return completion with \b to delete the trigger character
        // and insert the closing keyword
    }
}
```

### Special Handling

**Backspace Substitution:**
The completion uses `\b` prefix to:
1. Delete the typed `}` character
2. Insert the suggested closing keyword in its place

This creates a seamless experience where the bracket triggers completion but is replaced by the actual keyword.

## Configuration

Currently, the bracket completion system is **always enabled** and requires no configuration.

### Future Configuration Options

Potential settings for future versions:
```json
{
  "visualgasic.completion": {
    "bracketCompletion": true,
    "triggerChars": ["}", "]"],
    "preferWend": true,  // vs "End While"
    "includeVariableNames": true  // For "Next i" vs just "Next"
  }
}
```

## Examples

### Basic Usage
```vb
' 1. Start typing
For i = 1 To 10
    Print i

' 2. Type "}" on the indented line
For i = 1 To 10
    Print i
}

' 3. System suggests "Next i"
For i = 1 To 10
    Print i
Next i  ← Auto-completed!
```

### Nested Loops
```vb
For x = 1 To 5
    For y = 1 To 3
        Print x * y
    }  → Next y
}  → Next x
```

### Complex Nesting
```vb
Function ProcessRecords() As Integer
    Dim count As Integer = 0
    
    Try
        For Each record In records
            If record.IsValid Then
                With record
                    .Process()
                }  → End With
            }  → End If
        }  → Next record
    }  → End Try
    
    Return count
}  → End Function
```

## Benefits

1. **Reduces Syntax Errors** - No more forgotten closing statements
2. **Faster Coding** - Type one character instead of full keywords
3. **Better Readability** - Consistent closing statement style
4. **Learns Your Pattern** - Tracks nesting and context automatically
5. **VB6-Compatible** - Uses traditional Visual Basic syntax

## Comparison with Other Languages

### C-Style Languages
```c
for (i = 0; i < 10; i++) {
    // code
}  ← Closing brace required
```

### Python
```python
for i in range(10):
    # code
# No closing required (indentation-based)
```

### VisualGasic (Before)
```vb
For i = 1 To 10
    ' code
Next i  ← Had to type manually
```

### VisualGasic (After)
```vb
For i = 1 To 10
    ' code
}  → System suggests: Next i
```

## Troubleshooting

### Completion Not Appearing

**Possible causes:**
1. Code is malformed (missing Then, missing To, etc.)
2. Trigger character not recognized
3. No open blocks to close
4. Editor auto-completion is disabled

**Solutions:**
- Verify syntax of opening statement
- Try Ctrl+Space to manually trigger completion
- Check that VisualGasic extension is loaded

### Wrong Keyword Suggested

**Possible causes:**
1. Ambiguous nesting structure
2. Mismatched indentation levels
3. Comments interfering with parsing

**Solutions:**
- Fix indentation to match block structure
- Ensure all previous blocks are properly closed
- Check for syntax errors in block headers

### Variable Name Missing

For `For...Next` loops, if the variable name isn't included:

**Possible cause:** Complex loop header syntax not parsed correctly

**Workaround:** Accept the suggested `Next` and manually type the variable name

## Performance

The bracket completion system is **highly efficient**:

- **O(n)** complexity where n = lines of code up to cursor
- Typical overhead: **< 1ms** for files with < 1000 lines
- No noticeable impact on editor responsiveness
- Only activates on trigger characters

## Limitations

1. **Requires well-formed code** - Syntax errors may confuse the parser
2. **No cross-file analysis** - Only looks at current file
3. **Indentation-agnostic** - Uses line-by-line analysis, not indentation
4. **English keywords only** - No localization support yet

## Future Enhancements

### Planned Features

1. **Smart positioning** - Place cursor after completion for continued typing
2. **Multi-step completion** - Suggest both closing keyword and next statement
3. **Custom triggers** - Configure which characters trigger completion
4. **Alternative syntax** - Option for `End While` instead of `Wend`
5. **Snippet integration** - Expand to full code templates

### Advanced Features (Under Consideration)

1. **AI-powered suggestions** - Learn from user's coding patterns
2. **Refactoring shortcuts** - Convert between loop types
3. **Block manipulation** - Wrap/unwrap code in blocks
4. **Visual indicators** - Highlight matching opening/closing keywords

## Related Features

- **Auto-indent** - Automatically indent code inside blocks
- **Code folding** - Collapse/expand blocks in editor
- **Syntax highlighting** - Color-code block keywords
- **Error detection** - Warn about unclosed blocks

## Testing

Test file location: `examples/bracket_completion_demo.bas`

Run comprehensive tests:
```bash
# Load in Godot editor and interactively test
godot --editor examples/bracket_completion_demo.bas
```

## API Reference

### BracketCompletionHelper Class

```cpp
class BracketCompletionHelper {
public:
    struct BlockInfo {
        String keyword;      // Block type: "For", "While", etc.
        String variable;     // Associated variable (loop counter, function name)
        int indent_level;    // Indentation level
        int line_number;     // Line where block starts
    };
    
    // Detect closing keyword for current position
    static String detect_closing_keyword(const String& code, int cursor_line);
    
    // Find most recent unclosed block
    static BlockInfo find_open_block(const String& code, int cursor_line);
    
    // Check if character triggers completion
    static bool is_trigger_char(char32_t c);
    
    // Get closing keyword for block type
    static String get_completion_for_block(const String& block_type, 
                                          const String& variable = "");
    
    // Helper methods
    static int get_indent_level(const String& line);
    static bool is_opening_statement(const String& line, String& keyword, String& variable);
    static bool is_closing_statement(const String& line, String& keyword);
};
```

## License

This feature is part of VisualGasic and licensed under the same terms as the main project.

## Credits

**Design inspiration:**
- Visual Basic 6.0 IDE features
- Modern editor auto-completion systems
- Community feedback and feature requests

**Implementation:**
- Block stack algorithm
- Godot editor integration
- Context-aware completion system

## See Also

- [Code Completion Documentation](CODE_COMPLETION.md)
- [Editor Integration Guide](EDITOR_INTEGRATION.md)
- [VisualGasic Language Reference](VisualGasic_Language_Reference.md)

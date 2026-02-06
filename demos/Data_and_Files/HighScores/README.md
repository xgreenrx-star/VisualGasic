# High Score Table Demo

A classic arcade-style high score table demonstrating the DATA statement.

## Features Demonstrated

### DATA Statement Features
- `Data` - Embed data directly in code
- `Read` - Read values from data into variables
- `Restore` - Jump to labeled data sections
- Multiple data sections with labels
- Reading mixed data types (strings, integers)

### Code Patterns
- Reading data in a loop until sentinel value ("END")
- Parallel arrays for structured data
- Labeled data sections for organization
- String padding functions

## Why DATA Statements?

The DATA statement is perfect for:
- **Default high scores** - No external file needed
- **Level data** - Enemy positions, item spawns
- **Lookup tables** - Color palettes, sound frequencies
- **Configuration** - Default settings embedded in code
- **Localization** - Text strings for different languages

## Code Example

```vb
' Label marks the start of a data section
HighScores:
Data "ACE", 1000000, "2026-01-15"
Data "MAX", 875000, "2026-01-14"
Data "END", 0, ""

' Reading the data
Restore HighScores
Do
    Read playerName
    If playerName = "END" Then Exit Do
    Read score, dateStr
    ' ... use the data
Loop
```

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)

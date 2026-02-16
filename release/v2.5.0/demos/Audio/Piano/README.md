# Piano Keyboard - Audio Demo

An interactive piano keyboard demonstrating VisualGasic's audio capabilities.

## Audio Features Demonstrated

### PlayTone Function
```vb
' Play a note with frequency, volume, and duration
PlayTone freq, 0.5, 300  ' 440 Hz, 50% volume, 300ms

' Using DATA for note frequencies
NoteData:
Data "A4", 440.00, "H", 0    ' A4 = 440 Hz
Data "C4", 261.63, "A", 0    ' Middle C
Data "C5", 523.25, "K", 0    ' C5 (one octave up)
```

### DATA Statements for Musical Data
```vb
NoteData:
' Name, Frequency, Keyboard Key, IsBlack (0/1)
Data "C4", 261.63, "A", 0
Data "C#4", 277.18, "W", 1
Data "D4", 293.66, "S", 0
Data "END", 0, "", 0

DemoSongData:
' NoteIndex, TimeOffset (seconds)
Data 4, 0.0      ' E4 at 0 seconds
Data 2, 0.4      ' D4 at 0.4 seconds
Data 0, 0.8      ' C4 at 0.8 seconds
Data -1, 0       ' End marker
```

### Select Case for Key Mapping
```vb
Function GetKeyCode(key As String) As Integer
    Select Case key
        Case "A": Return KEY_A
        Case "S": Return KEY_S
        Case "D": Return KEY_D
        ' ...
    End Select
End Function
```

## Features

- **15 Piano Keys** - Full octave plus a bit more
- **Real-time Play** - Press keys to hear notes instantly
- **Recording** - Record your melody
- **Playback** - Play back recorded melody
- **Demo Song** - "Mary Had a Little Lamb" built-in

## Controls

### White Keys (Bottom Row)
| Key | Note |
|-----|------|
| A | C4 |
| S | D4 |
| D | E4 |
| F | F4 |
| G | G4 |
| H | A4 (440 Hz) |
| J | B4 |
| K | C5 |
| L | D5 |

### Black Keys (Top Row)
| Key | Note |
|-----|------|
| W | C#4 |
| E | D#4 |
| T | F#4 |
| Y | G#4 |
| U | A#4 |
| O | C#5 |

### Special Keys
| Key | Action |
|-----|--------|
| R | Start/Stop Recording |
| P | Play Recording |
| D | Play Demo Song |

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
4. Press piano keys to play!

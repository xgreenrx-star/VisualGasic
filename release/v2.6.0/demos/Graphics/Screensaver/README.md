# Matrix Screensaver - Graphics Drawing Demo

A multi-mode screensaver demonstrating VisualGasic's drawing primitives.

## Drawing Commands Demonstrated

### DrawRect
```vb
DrawRect x, y, width, height, color
DrawRect 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Color.Black
DrawRect rx, ry, rectSize, rectSize, Color(1.0, 0.5, 0.5, 0.5)
```

### DrawCircle
```vb
DrawCircle x, y, radius, color
DrawCircle cx, cy, radius, Color(r, g, b, alpha)
```

### DrawLine
```vb
DrawLine x1, y1, x2, y2, color
DrawLine x2, y2, x, y, Color(brightness, brightness, brightness)
```

### DrawString
```vb
DrawString text, x, y, color, fontSize
DrawString columnChars(i, j), x, y, charColor, 18
```

### Color Functions
```vb
Color.Black                    ' Predefined color
Color.White
Color("#333333")               ' Hex color
Color(r, g, b)                 ' RGB (0.0 to 1.0)
Color(r, g, b, a)              ' RGBA with alpha
```

## Screensaver Modes

1. **Matrix Rain** - Falling characters with fade trails
2. **Geometric** - Rotating circles, lines, and rectangles
3. **Spiral** - Animated spiral of colorful dots
4. **Starfield** - Warp speed star effect

## Features Demonstrated

- **DATA Statements** - Character set stored in code
- **Animation** - Using delta time for smooth motion
- **Math Functions** - Sin, Cos for circular motion
- **Color Manipulation** - HSV-like effects
- **Conditional Drawing** - Skip off-screen elements

## Controls

- **Space** - Switch to next mode
- Modes auto-rotate every 10 seconds

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)

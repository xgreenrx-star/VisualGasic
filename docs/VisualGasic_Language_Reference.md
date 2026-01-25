# VisualGasic Language Reference

## Table of Contents

### [Getting Started](#getting-started)
- [Introduction](#introduction)  
- [Installation](#installation)
- [Editor Shortcuts](#editor-shortcuts)
- [Your First VisualGasic Script](#your-first-script)

### [Language Basics](#language-basics)
- [Syntax Overview](#syntax-overview)
- [Variables and Data Types](#variables-and-data-types)
- [Operators](#operators)
- [Comments](#comments)

### [Control Flow](#control-flow)
- [Conditional Statements](#conditional-statements)
- [Loops](#loops)
- [Select Case](#select-case)
- [Error Handling](#error-handling)

### [Procedures and Functions](#procedures-and-functions)
- [Subroutines (Sub)](#subroutines)
- [Functions](#functions)
- [Parameters](#parameters)
- [Scope and Lifetime](#scope)

### [Object-Oriented Features](#object-oriented)
- [Classes and Types](#classes)
- [Inheritance](#inheritance)
- [Interfaces](#interfaces)
- [Properties and Methods](#properties-methods)

### [Built-in Functions](#built-in-functions)
- [String Functions](#string-functions)
- [Math Functions](#math-functions)
- [Array Functions](#array-functions)
- [File I/O Functions](#file-functions)
- [Game and Application Development Functions](#game-functions)

### [Modern Language Features](#modern-features)
- [Lambda Expressions](#lambda-expressions)
- [Pattern Matching](#pattern-matching)
- [Null-Safe Operations](#null-safe)
- [Type Inference](#type-inference)
- [Event-Driven Programming with Whenever](#event-driven-programming-with-whenever)

### [Godot Integration](#godot-integration)
- [Node Interaction](#node-interaction)
- [Signal System](#signal-system)
- [Scene Management](#scene-management)
- [Resource Loading](#resource-loading)

---

## Getting Started

### Introduction

VisualGasic is a modern, expressive scripting language designed for application and game development on the Godot 4.5+ platform. The name "Gasic" stands for **G**odot **A**ll-purpose **S**ymbolic **C**ode (when used within Godot) or **G**eneral **A**ll-purpose **S**ymbolic **C**ode (for standalone applications), representing its versatility as both a game development language and a general-purpose programming solution.

VisualGasic serves as a **RAD (Rapid Application Development) IDE** environment, combining intuitive syntax with powerful language features, seamless Godot integration, and cross-platform capabilities to accelerate the development process for both applications and games.

Whether you're creating desktop applications, mobile apps, web software, or interactive games, VisualGasic provides the tools and cross-platform flexibility you need for professional development.

**Key Features:**
- Clean, intuitive syntax with modern enhancements
- Full Godot 4.5+ integration for applications and games
- Cross-platform development support
- Object-oriented programming support
- Built-in functions for game and application development
- Type safety with optional explicit typing
- Lambda expressions and pattern matching

**Cross-Platform Development:**
VisualGasic applications run on all platforms supported by Godot:
- **Desktop**: Windows, macOS, Linux
- **Mobile**: iOS, Android  
- **Web**: HTML5/WebAssembly
- **Console**: Nintendo Switch, PlayStation, Xbox (with appropriate licensing)

**Application Types:**
- Desktop applications and utilities
- Mobile apps and games
- Web applications
- Educational software
- Business tools and productivity apps
- Interactive media and presentations

### Installation

VisualGasic is provided as a Godot extension (GDExtension). To install:

1. Download the latest release from the project repository
2. Extract to your Godot project's `addons/` folder
3. Enable the VisualGasic plugin in Project Settings > Plugins
4. Files with `.bas` extension will now use VisualGasic syntax

### Editor Shortcuts

The VisualGasic editor includes intelligent auto-replacement shortcuts to improve coding efficiency:

**Automatic Type Inference:**
- Type `Dim variable = value` and press Enter → Automatically adds `As Type`
- Works with: String literals, numbers, booleans, vectors, arrays, objects
- Example: `Dim count = 42` becomes `Dim count As Integer = 42`

**Automatic Type Inference:**
- Type `Dim variable = value` and press Enter → Automatically adds `As Type`
- Type `Dim variable` and press Enter → Automatically adds `As Variant`
- Works with: String literals, numbers, booleans, vectors, arrays, objects
- Unknown types default to `As Variant` (maintains mandatory typing)
- Example: `Dim count = 42` becomes `Dim count As Integer = 42`

**Case Statement Shortcuts:**
- Type `:_` in Select Case or Match blocks → Automatically converts to `Case Else`

**Variable Declaration Shortcuts:**
- `let` → `Dim` (JavaScript/Swift style)
- `var` → `Dim` (JavaScript/C# style)
- Incomplete declarations automatically get `As Variant`
- Examples: `var pizza` → `Dim pizza As Variant`

**Function Declaration Shortcuts:**
- `func` → `Function` (JavaScript/Python/Swift style)
- `def` → `Function` (Python style)  
- `void` → `Sub` (C/Java/C# style)

**Control Flow Shortcuts:**
- `elif` → `ElseIf` (Python style)
- `else if` → `ElseIf` (C/Java style)
- `switch` → `Select Case` (C/Java/JavaScript style)
- `foreach` → `For Each` (C# style)

**Value Shortcuts:**
- `null` → `Nothing` (C#/Java/JavaScript style)
- `None` → `Nothing` (Python style)
- `undefined` → `Nothing` (JavaScript style)
- `true` → `True` (Case correction)
- `false` → `False` (Case correction)

**Comment Shortcuts:**
- `//` → `'` (C/Java/JavaScript style)
- `#` → `'` (Python style)

**Operator Shortcuts:**
- `->` → ` = ` (Assignment operator)
- `==` → ` = ` (Equality comparison)
- `===` → ` = ` (Strict equality comparison) 
- `!==` → ` <> ` (Strict inequality comparison)
- `&&` → ` And ` (Logical AND)
- `||` → ` Or ` (Logical OR)
- `!` → ` Not ` (Logical NOT)

**Context-Aware Safety:**
- Shortcuts only activate in appropriate contexts
- No replacement inside strings (e.g., `Print "_:BooYa:_"` remains unchanged)
- Smart detection of Select Case/Match blocks for case shortcuts

**Example Usage:**
```vb
' Type inference - just press Enter after typing:
Dim name = "Player"       ' Becomes: Dim name As String = "Player"
Dim health = 100          ' Becomes: Dim health As Integer = 100
Dim speed = 2.5           ' Becomes: Dim speed As Double = 2.5
Dim isAlive = True        ' Becomes: Dim isAlive As Boolean = True
Dim pos = Vector2(10, 20) ' Becomes: Dim pos As Vector2 = Vector2(10, 20)
Dim items = Array()       ' Becomes: Dim items As Array = Array()
Dim result = SomeFunc()   ' Becomes: Dim result As Variant = SomeFunc()

Select Case playerClass
    Case "Warrior"
        strength += 10
    :_                    ' Type this + Enter
    ' Automatically becomes:
    Case Else             ' This appears
        Print "Unknown class"
End Select

' Variable declarations from other languages:
let playerName = "Hero"   ' Becomes: Dim playerName = "Hero"
var health = 100          ' Becomes: Dim health = 100

' Function declarations:
def calculateDamage()     ' Becomes: Function calculateDamage()
void resetGame()          ' Becomes: Sub resetGame()

' Control flow:
elif score > 50           ' Becomes: ElseIf score > 50
else if lives > 0         ' Becomes: ElseIf lives > 0
switch difficulty         ' Becomes: Select Case difficulty

' Values and literals:
if player == null         ' Becomes: if player = Nothing
while isActive == true    ' Becomes: while isActive = True

' Comments:
// This is a comment      ' Becomes: ' This is a comment
# Python style comment    ' Becomes: ' Python style comment

' Cross-language operators:
health -> 100             ' Becomes: health = 100
score == 50               ' Becomes: score = 50
isAlive && hasKey         ' Becomes: isAlive And hasKey
status !== "dead"         ' Becomes: status <> "dead"
!gameOver                 ' Becomes: Not gameOver
```

### Smart Variable Declaration System

VisualGasic's editor provides intelligent variable declaration assistance that ensures all variables are properly typed while supporting cross-language syntax patterns.

**Three Types of Variable Declarations:**

1. **With Assignment (Type Inference)**
   - Type: `Dim variable = value` + Enter
   - Result: Automatically infers and adds `As Type`
   - Examples:
     ```vb
     var count = 42        ' → Dim count As Integer = 42
     let name = "Hero"      ' → Dim name As String = "Hero" 
     Dim speed = 2.5       ' → Dim speed As Double = 2.5
     ```

2. **Without Assignment (Auto-Completion)**
   - Type: `Dim variable` + Enter (no assignment)
   - Result: Automatically adds `As Variant`
   - Examples:
     ```vb
     var pizza             ' → Dim pizza As Variant
     let score             ' → Dim score As Variant
     Dim player            ' → Dim player As Variant
     ```

3. **Explicit Typing (No Change)**
   - Type: `Dim variable As Type`
   - Result: No transformation needed
   - Example:
     ```vb
     Dim health As Integer ' → Dim health As Integer (unchanged)
     ```

**Smart Type Inference Supports:**
- **String literals:** `"text"` → `As String`
- **Integers:** `42`, `-10` → `As Integer`
- **Floating point:** `3.14`, `2.5` → `As Double`
- **Booleans:** `True`, `False` → `As Boolean`
- **Vectors:** `Vector2(x,y)`, `Vector3(x,y,z)` → `As Vector2/Vector3`
- **Arrays:** `Array()`, `[]` → `As Array`
- **Objects:** Function calls, constructors → `As Object`
- **Unknown:** Complex expressions → `As Variant`

**Cross-Language Variable Syntax:**
- `var` (JavaScript/C#) → `Dim`
- `let` (JavaScript/Swift) → `Dim` 
- `auto` (C++) → `Dim`
- All automatically get proper VisualGasic typing

**Benefits:**
- **Enforces mandatory typing** - every variable gets a type
- **Supports familiar syntax** - developers can use syntax from other languages
- **Prevents syntax errors** - incomplete declarations are auto-completed
- **Maintains flexibility** - can easily refine `Variant` to specific types

### Advanced Cross-Language Features

VisualGasic provides extensive support for converting common programming patterns from other languages into proper VisualGasic syntax.

#### **1. Function Declaration Auto-Completion**

**Purpose:** Automatically completes incomplete function declarations with proper VisualGasic syntax.

**Patterns Supported:**
```vb
' Incomplete declarations become complete:
func MyFunction       → Function MyFunction() As Variant
def calculate         → Function calculate() As Variant  
void DoSomething      → Sub DoSomething()
```

**Details:**
- Functions get `() As Variant` signature by default
- Subs (void functions) get `()` parameters only
- Can easily modify return type and parameters after auto-completion

#### **2. String Interpolation Conversion**

**Purpose:** Converts template literals and string interpolation to VisualGasic string concatenation.

**Patterns Supported:**
```vb
' JavaScript template literals:
`Hello ${name}`                → "Hello " + name
`Score: ${score}, Lives: ${lives}` → "Score: " + score + ", Lives: " + lives

' Python f-strings:
f"Player {playerName}"         → "Player " + CStr(playerName)
f"Health: {health}/100"        → "Health: " + CStr(health) + "/100"

' C# interpolated strings:
$"Level {level} Complete"      → "Level " + CStr(level) + " Complete"
```

**Details:**
- Automatically adds `CStr()` conversion for non-string variables
- Handles multiple interpolations in single string
- Preserves surrounding text before and after variables

#### **3. Ternary Operator Conversion**

**Purpose:** Converts ternary conditional operators to VisualGasic's `If()` function.

**Patterns Supported:**
```vb
' Ternary operators:
condition ? a : b             → If(condition, a, b)
x > 0 ? "positive" : "negative" → If(x > 0, "positive", "negative")
score >= 100 ? bonus : 0      → If(score >= 100, bonus, 0)
```

**Details:**
- Works with any condition, value types
- Maintains operator precedence
- Can be nested (though not recommended for readability)

#### **4. Loop Pattern Shortcuts**

**Purpose:** Converts common loop patterns from other languages to VisualGasic For/While loops.

**Patterns Supported:**
```vb
' C-style for loops:
for(i=0; i<10; i++)           → For i = 0 To 9
for(x=1; x<=5; x++)           → For x = 1 To 4  ' (converts to end-1)

' Python range loops:
for i in range(10)            → For i = 0 To 9
for x in range(5)             → For x = 0 To 4

' C-style while loops:
while(isActive)               → While isActive
while(health > 0)             → While health > 0
```

**Details:**
- Automatically adjusts end values for 0-based vs 1-based differences
- Removes unnecessary parentheses around conditions
- Preserves variable names and logic

#### **5. Array Access Normalization**

**Purpose:** Converts bracket-style array access to VisualGasic's parentheses syntax.

**Patterns Supported:**
```vb
' Array/collection access:
arr[index]                    → arr(index)
items[i]                      → items(i)
dict["key"]                   → dict("key")
matrix[row][col]              → matrix(row)(col)
```

**Details:**
- Handles nested array access automatically
- Preserves string literals in brackets (no conversion)
- Works with variables, literals, and expressions as indices

#### **6. Incomplete Control Structure Completion**

**Purpose:** Auto-completes incomplete control flow statements with sensible defaults.

**Patterns Supported:**
```vb
' Incomplete statements get completed:
if condition                  → If condition Then
for i                         → For i = 0 To 9
while                         → While True
```

**Details:**
- Adds required keywords (`Then` for `If` statements)
- Provides reasonable defaults for incomplete loops
- Maintains developer's variable names where possible

#### **7. Property/Method Chaining Assistance**

**Purpose:** Fixes common method chaining issues and dot notation problems.

**Patterns Supported:**
```vb
' Method chaining fixes:
.method()                     → obj.method()    ' adds object reference
..property                    → obj.property    ' fixes double dots
obj..method()                 → obj.method()    ' removes extra dots
```

**Details:**
- Adds default `obj` reference for orphaned method calls
- Fixes accidental double-dot typos
- Maintains proper chaining syntax

### **Complete Cross-Language Compatibility Matrix**

| **Language** | **Supported Patterns** | **Auto-Conversions** |
|--------------|------------------------|---------------------|
| **JavaScript** | `var`, `let`, `func`, template literals, ternary | Variables, functions, strings, conditions |
| **Python** | `def`, f-strings, `for in range()`, `elif` | Functions, strings, loops, conditions |
| **C/C++** | `void`, C-for loops, `while()`, array brackets | Functions, loops, arrays |
| **C#** | `var`, interpolated strings, `foreach` | Variables, strings, loops |
| **Swift** | `let`, `func` | Variables, functions |
| **Java** | `void`, array brackets, C-for loops | Functions, arrays, loops |

**All conversions happen automatically when you press Enter, creating valid VisualGasic code instantly!**

#### **8. Safe Import/Using Statement Conversion**

**Purpose:** Safely converts import/include statements from other languages while preserving valid VisualGasic imports.

**🔒 SAFE Conversions (Unambiguous Foreign Syntax Only):**

**C++ Includes (Always Safe):**
```cpp
#include <iostream>           → ' Include: iostream → Built-in: Print, Input functions
#include <vector>             → ' Include: vector → Built-in: Array type
#include <string>             → ' Include: string → Built-in: String type
#include "myheader.h"         → ' Include: myheader.h (check VisualGasic equivalent)
```

**Python from...import (Always Safe):**
```python  
from os import path          → ' From os import path → Built-in path functions
from collections import deque → ' From collections import deque → Built-in: Array, Dictionary
from math import sqrt        → ' From math import sqrt → Built-in: Sqrt() function
```

**.NET System/Microsoft Namespaces (Always Safe):**
```csharp
using System;                → ' Using: System → Built-in system functions and Godot OS class
using System.Collections;    → ' Using: System.Collections → Built-in: Array, Dictionary
using Microsoft.AspNet;      → ' Using: Microsoft.AspNet (check VisualGasic equivalent)
```

**Known Foreign Libraries (Always Safe):**
```python
import math                  → ' Import: math → Built-in functions: Sin, Cos, Tan, Sqrt, Abs, etc.
import numpy                 → ' Import: numpy (check VisualGasic equivalent)
import requests              → ' Import: requests (check VisualGasic equivalent)  
import fs                    → ' Import: fs → Built-in file operations and Godot FileAccess
```

**⚠️ PRESERVED (Potentially Valid VisualGasic):**
```vb
import MyLibrary            → import MyLibrary        (UNCHANGED - might be valid VisualGasic)
using CustomModule          → using CustomModule     (UNCHANGED - might be valid VisualGasic) 
import GameEngine           → import GameEngine      (UNCHANGED - might be valid VisualGasic)
using PlayerController      → using PlayerController (UNCHANGED - might be valid VisualGasic)
```

**🎯 Safe Conversion Rules:**

1. **`#include` statements** → Always converted (C++ only syntax)
2. **`from ... import`** → Always converted (Python only syntax)
3. **`using System.*` or `using Microsoft.*`** → Always converted (.NET only)
4. **Known foreign libraries** → Converted if in known library database
5. **Simple `import`/`using` with unknown names** → Left unchanged (might be VisualGasic)

**📚 Known Foreign Library Database:**

**Python Standard Library:** `math`, `random`, `os`, `sys`, `time`, `json`, `csv`, `collections`  
**Python Third-Party:** `numpy`, `pandas`, `requests`, `flask`, `tensorflow`, `matplotlib`  
**Node.js/JavaScript:** `fs`, `path`, `express`, `react`, `lodash`, `axios`  
**Java Packages:** `java.*`, `android.*`, `com.*` patterns  
**C++ Standard:** `iostream`, `vector`, `string`, `algorithm`

**Benefits:**
- **Prevents Syntax Errors:** Invalid imports become safe comments
- **Preserves Intent:** You can see what functionality you originally needed
- **Provides Guidance:** Smart mappings show you the VisualGasic equivalent
- **Educational:** Learn VisualGasic's built-in capabilities
- **Manual Review:** Prompts you to find proper VisualGasic solutions

**Common VisualGasic Equivalents Reference:**

| **Original Library** | **VisualGasic Equivalent** | **Usage** |
|---------------------|---------------------------|-----------|
| `math.sqrt()` | `Sqrt()` | `Sqrt(16)` → `4` |
| `random.randint()` | `RandomRange()` | `RandomRange(1, 10)` |
| `System.Console.WriteLine()` | `Print` | `Print "Hello World"` |
| `std::vector` | `Array` | `Dim items As Array = Array()` |
| `JSON.parse()` | `JSON.parse_string()` | `JSON.parse_string(jsonText)` |
| `setTimeout()` | `Timer` | Create Timer node |
| `os.path.join()` | String concatenation | `path1 + "/" + path2` |

**All conversions happen automatically when you press Enter, creating valid VisualGasic code instantly!**

### Your First Script

Create a new `.bas` file and attach it to a node:

```vb
' hello_world.bas
Sub Main()
    Print "Hello, VisualGasic!"
End Sub

Sub _Ready()
    Print "Node is ready!"
End Sub
```

---

## Language Basics

### Syntax Overview

VisualGasic features an intuitive syntax with case-insensitive keywords and end-of-line statement termination:

## Keywords Reference

VisualGasic provides a comprehensive set of keywords for modern game development and application programming.

### **Core Language Keywords**

#### **Variable Declaration**
- `Dim` - Declare a variable
- `Global` - Declare a global variable
- `Public` - Public variable/procedure scope
- `Private` - Private variable/procedure scope
- `Static` - Static variable (retains value between calls)
- `Const` - Declare a constant
- `Redim` - Resize an array
- `Preserve` - Preserve array contents when resizing

#### **Data Types & Literals**
- `As` - Type declaration keyword
- `Type` - Define a custom type/structure
- `Nothing` - Null object reference
- `True` - Boolean true literal
- `False` - Boolean false literal
- `New` - Create new object instance
- `Set` - Assign object reference
- `Me` - Reference to current object

#### **Control Flow**
- `If` - Conditional statement
- `Then` - Part of If statement
- `Else` - Alternative condition
- `ElseIf` / `Elif` - Additional condition
- `End` - End block statement
- `Select` - Start select case block
- `Case` - Case option in select block
- `For` - Start counting loop
- `To` - Range operator in For loop
- `Step` - Step increment in For loop
- `Next` - End For loop
- `While` - Start conditional loop
- `Wend` - End While loop (legacy)
- `Do` - Start Do loop
- `Loop` - End Do loop
- `Until` - Loop until condition
- `Exit` - Exit current loop/procedure
- `Continue` - Skip to next iteration
- `Return` - Return from function
- `Pass` - No-operation placeholder

#### **Procedures & Functions**
- `Sub` - Define a subroutine
- `Function` - Define a function
- `Call` - Call a procedure (optional)
- `Optional` - Optional parameter
- `ByVal` - Pass parameter by value
- `ByRef` - Pass parameter by reference
- `ParamArray` - Variable number of parameters

#### **Logical Operators**
- `And` - Logical AND
- `Or` - Logical OR
- `Not` - Logical NOT
- `Xor` - Logical XOR
- `AndAlso` - Short-circuit AND
- `OrElse` - Short-circuit OR

#### **Error Handling**
- `On` - Error handling setup
- `Error` - Error keyword
- `Resume` - Resume after error
- `Try` - Start try block
- `Catch` - Catch exceptions
- `Finally` - Finally block
- `Goto` - Jump to label

#### **File Operations**
- `Open` - Open file
- `Close` - Close file
- `Input` - Input mode
- `Output` - Output mode
- `Append` - Append mode
- `Line` - Line input/output

#### **Object-Oriented Features**
- `Inherits` - Class inheritance
- `Extends` - Extend a class
- `Event` - Declare an event
- `RaiseEvent` - Raise an event
- `with` - With statement (object context)

#### **Collections & Iteration**
- `Dictionary` - Dictionary type
- `each` - For each iteration
- `in` - In operator (for iteration)

#### **Data Processing**
- `Data` - Data statement
- `Read` - Read data
- `Restore` - Restore data pointer

#### **Advanced Features**
- `Include` - Include external file
- `Option` - Compiler option
- `Explicit` - Explicit variable declaration
- `DoEvents` - Process system events
- `IIf` - Inline If function

#### **Reactive Programming (Whenever System)**
- `Whenever` - Start reactive section declaration
- `Section` - Declare a reactive monitoring section
- `Local` - Local scope modifier for Whenever sections
- `Changes` - Trigger on any value change
- `Becomes` - Trigger when value equals target
- `Exceeds` - Trigger when value surpasses threshold
- `Below` - Trigger when value falls under threshold
- `Between` - Trigger when value is within range (requires And)
- `Contains` - Trigger when string/array contains value
- `Suspend` - Temporarily disable reactive section
- `Resume` - Re-enable suspended reactive section

### **Built-in Functions & Statements**

#### **I/O Operations**
- `Print` - Output to console/debug
- `MsgBox` - Display message box

#### **System Functions**
- `Shell` - Execute system command
- `Sleep` - Pause execution
- `DoEvents` - Process pending events

#### **Game Development**
- `CreateActor2D` - Create 2D game actor
- `LoadForm` - Load UI form
- `ChangeScene` - Switch game scene
- `SetTitle` - Set window title
- `SetScreenSize` - Set screen dimensions

#### **AI Functions**
- `AI_Chase` - AI chase behavior
- `AI_Wander` - AI wandering behavior
- `AI_Patrol` - AI patrol behavior
- `AI_Stop` - Stop AI behavior

#### **Input Handling**
- `IsKeyPressed` - Check keyboard input
- `IsActionPressed` - Check input action

#### **Graphics & Drawing**
- `DrawText` - Draw text
- `DrawLine` - Draw line
- `DrawRect` - Draw rectangle
- `DrawCircle` - Draw circle
- `LoadPicture` - Load image

#### **Audio**
- `PlaySound` - Play sound effect
- `PlayTone` - Play tone

#### **Collision Detection**
- `HasCollided` - Check collision
- `GetCollider` - Get collision object

#### **Mathematical Functions**
- `Abs` - Absolute value
- `Int` - Integer conversion
- `Round` - Round number
- `Rnd` - Random number
- `Randomize` - Seed random generator
- `RandRange` - Random in range
- `Lerp` - Linear interpolation
- `Clamp` - Clamp value to range

#### **String Functions**
- `Format` - Format string
- `TypeName` - Get type name

#### **File System**
- `MkDir` - Create directory
- `SaveSetting` - Save setting
- `GetSetting` - Get setting

#### **Database Functions**
- `OpenDatabase` - Open database
- `SaveDatabase` - Save database

### **Keyword Usage Notes**

- **Case Insensitive:** All keywords work in any case (`DIM`, `Dim`, `dim`)
- **Context Sensitive:** Some keywords have different meanings in different contexts
- **Reserved Words:** Keywords cannot be used as variable or procedure names
- **Backward Compatible:** Supports both modern and legacy syntax variants
- **Cross-Language:** Many patterns from other languages are auto-converted to VisualGasic keywords

### **Complete Alphabetical Index**

```
Abs, AndAlso, Append, As, ByRef, ByVal, Call, Case, Catch, ChangeScene, 
Close, Clamp, Const, Continue, CreateActor2D, Data, Dictionary, Dim, Do, 
DoEvents, DrawCircle, DrawLine, DrawRect, DrawText, each, Elif, Else, 
ElseIf, End, Error, Event, Exit, Explicit, Extends, False, Finally, For, 
Format, Function, GetCollider, GetSetting, Global, Goto, HasCollided, If, 
IIf, in, Include, Inherits, Input, Int, IsActionPressed, IsKeyPressed, 
Lerp, Line, LoadForm, LoadPicture, Loop, Me, MkDir, MsgBox, New, Next, 
Not, Nothing, On, Open, Optional, Option, Or, OrElse, Output, ParamArray, 
Pass, PlaySound, PlayTone, Preserve, Print, Private, Public, RaiseEvent, 
Randomize, RandRange, Read, Redim, Resume, Return, Rnd, Round, SaveDatabase, 
SaveSetting, Select, Set, SetScreenSize, SetTitle, Shell, Sleep, Static, 
Step, Sub, Then, To, True, Try, Type, TypeName, Until, Wend, While, with, Xor
```

**Total: 100+ Keywords Available**

```vb
' Variable declaration
Dim playerName As String
Dim score As Integer = 0

' Function call
result = CalculateScore(playerName, level)

' Object property access
Player.Position.x = 100
```

### Variables and Data Types

#### Variable Declaration

Variables can be declared explicitly or implicitly:

```vb
' Explicit declaration with type
Dim count As Integer
Dim name As String
Dim isActive As Boolean

' Implicit declaration (Variant type)
Dim value = 42
Dim text = "Hello"

' Initialization at declaration
Dim maxHealth As Integer = 100
```

#### Data Types

| Type | Description | Example |
|------|-------------|---------|
| `Integer` | 32-bit signed integer | `42` |
| `Long` | 64-bit signed integer | `9876543210` |
| `Single` | 32-bit floating point | `3.14` |
| `Double` | 64-bit floating point | `3.14159265` |
| `String` | Text data | `"Hello World"` |
| `Boolean` | True/False values | `True`, `False` |
| `Variant` | Can hold any type | `"text"`, `42`, `True` |
| `Object` | Reference to Godot objects | `Node`, `Sprite2D` |

#### Type Conversion

```vb
' Explicit conversion functions
Dim text As String = "123"
Dim number As Integer = CInt(text)
Dim floating As Double = CDbl("3.14")
Dim flag As Boolean = CBool(1)

' String conversion
Dim result As String = CStr(42)  ' "42"
```

### Operators

#### Arithmetic Operators
```vb
result = 10 + 5   ' Addition (15)
result = 10 - 5   ' Subtraction (5)
result = 10 * 5   ' Multiplication (50)
result = 10 / 5   ' Division (2.0)
result = 10 \ 5   ' Integer division (2)
result = 10 Mod 3 ' Modulo (1)
result = 2 ^ 3    ' Exponentiation (8)
```

#### Comparison Operators
```vb
If score > 100 Then     ' Greater than
If level >= 5 Then      ' Greater than or equal
If health < 10 Then     ' Less than
If lives <= 0 Then      ' Less than or equal
If name = "Player" Then ' Equal
If status <> "Dead" Then ' Not equal
If status != "Dead" Then ' Not equal (alternative syntax)
```

#### Logical Operators
```vb
If isAlive And hasKey Then       ' Logical AND
If isDead Or gameOver Then       ' Logical OR
If Not isEmpty Then              ' Logical NOT
If a Xor b Then                  ' Exclusive OR
If condition1 AndAlso condition2 ' Short-circuit AND
If condition1 OrElse condition2  ' Short-circuit OR
```

#### String Operators
```vb
fullName = firstName & " " & lastName  ' Concatenation
If pattern Like "A*" Then              ' Pattern matching
```

### Comments

```vb
' Single-line comment
Dim value = 42 ' End-of-line comment

/* 
   Multi-line block comment
   This can span multiple lines
   like in C/C++/C#
*/

/*
 * Block comment with asterisks
 * for better formatting
 */

' Multi-line comments using multiple single quotes
' This is a longer explanation
' that spans multiple lines
```

---

## Control Flow

### Conditional Statements

#### If-Then-Else
```vb
If score > highScore Then
    highScore = score
    Print "New high score!"
ElseIf score > 0 Then
    Print "Good job!"
Else
    Print "Try again!"
End If

' Single-line If
If health <= 0 Then gameOver = True
```

#### IIf Function (Ternary Operator)
```vb
message = IIf(score > 100, "Excellent!", "Keep trying!")
```

**See Also:** [If-Then-Else](#if-then-else) - Full conditional statements for more complex branching logic.

### Loops

#### For-Next Loop
```vb
' Basic for loop
For i = 1 To 10
    Print i
Next i

' Variable after Next is optional
For i = 1 To 10
    Print i
Next

' With step
For i = 0 To 100 Step 5
    Print i
Next i

' Backwards
For i = 10 To 1 Step -1
    Print i
Next
```

#### For-Each Loop
```vb
Dim items As Array = ["apple", "banana", "cherry"]
For Each item In items
    Print item
Next item

' Variable after Next is optional for For-Each too
For Each item In items
    Print item
Next
```

#### While-Wend Loop
```vb
While health > 0
    TakeDamage()
    If health <= 0 Then Exit While
Wend
```

**See Also:** [Do-Loop](#do-loop) - Alternative loop syntax with `Do While` for similar functionality.

#### Do-Loop
```vb
' Do While
Do While player.IsAlive
    ProcessTurn()
Loop

' Do Until
Do Until gameOver
    UpdateGame()
Loop

' Do-Loop While (executes at least once)
Do
    GetInput()
Loop While input <> "quit"
```

**See Also:** [While-Wend Loop](#while-wend-loop) - Alternative loop syntax with similar `While` condition syntax.

### Select Case

```vb
Select Case playerClass
    Case "Warrior"
        strength = strength + 10
        health = health + 5
    Case "Mage"
        intelligence = intelligence + 10
        mana = mana + 15
    Case "Rogue"
        dexterity = dexterity + 10
        stealth = stealth + 5
    Case Else
        Print "Unknown class!"
End Select

' Multiple values
Select Case level
    Case 1, 2, 3
        difficulty = "Easy"
    Case 4, 5, 6
        difficulty = "Medium"
    Case 7, 8, 9, 10
        difficulty = "Hard"
End Select
```

**See Also:** [Pattern Matching](#pattern-matching) - The `Match` statement provides similar functionality with enhanced pattern matching capabilities.

### Error Handling

```vb
On Error GoTo ErrorHandler
    ' Code that might cause an error
    result = 10 / 0
    Print "This won't execute"
    Exit Sub
    
ErrorHandler:
    Print "Error occurred: " & Err.Description
    Resume Next
```

---

## Procedures and Functions

### Subroutines

```vb
' Simple subroutine
Sub ShowMessage()
    Print "Hello from subroutine!"
End Sub

' Subroutine with parameters
Sub MovePlayer(ByVal deltaX As Integer, ByVal deltaY As Integer)
    Player.Position.x = Player.Position.x + deltaX
    Player.Position.y = Player.Position.y + deltaY
End Sub

' Calling subroutines
Call ShowMessage()
ShowMessage()  ' 'Call' keyword is optional
MovePlayer(10, 5)
```

### Functions

```vb
' Function returning a value
Function CalculateDistance(x1 As Double, y1 As Double, x2 As Double, y2 As Double) As Double
    Dim dx As Double = x2 - x1
    Dim dy As Double = y2 - y1
    CalculateDistance = Sqr(dx * dx + dy * dy)
End Function

' Using the function
Dim distance As Double = CalculateDistance(0, 0, 3, 4) ' Returns 5.0
```

### Parameters

```vb
' ByVal (pass by value) - default
Sub ModifyValue(ByVal x As Integer)
    x = x + 10  ' Original variable unchanged
End Sub

' ByRef (pass by reference)
Sub ModifyReference(ByRef x As Integer)
    x = x + 10  ' Original variable is modified
End Sub

' Optional parameters
Sub CreateEnemy(name As String, Optional level As Integer = 1, Optional boss As Boolean = False)
    Print "Creating " & name & " at level " & level
    If boss Then Print "This is a boss enemy!"
End Sub

CreateEnemy("Goblin")           ' Uses defaults
CreateEnemy("Dragon", 50, True) ' All parameters specified
```

---

## Object-Oriented Features

### Classes and Types

```vb
' Define a custom type
Type PlayerStats
    Health As Integer
    Mana As Integer
    Level As Integer
End Type

' Using the type
Dim stats As PlayerStats
stats.Health = 100
stats.Mana = 50
stats.Level = 5
```

### Inheritance

```vb
' Base class (inherits from Node)
Class Character Inherits Node2D
    Public Health As Integer = 100
    Public Name As String
    
    Sub New(playerName As String)
        Name = playerName
    End Sub
    
    Sub TakeDamage(amount As Integer)
        Health = Health - amount
        If Health <= 0 Then Die()
    End Sub
    
    Virtual Sub Die()
        Print Name & " has died!"
    End Sub
End Class

' Derived class
Class Player Inherits Character
    Public Experience As Integer = 0
    
    Sub New(playerName As String)
        MyBase.New(playerName)  ' Call base constructor
    End Sub
    
    Override Sub Die()
        MyBase.Die()  ' Call base method
        Print "Game Over!"
    End Sub
End Class
```

### Interfaces

```vb
Interface IDamageable
    Sub TakeDamage(amount As Integer)
    Function IsAlive() As Boolean
End Interface

Class Enemy Implements IDamageable
    Private health As Integer = 50
    
    Sub TakeDamage(amount As Integer) Implements IDamageable.TakeDamage
        health = health - amount
    End Sub
    
    Function IsAlive() As Boolean Implements IDamageable.IsAlive
        Return health > 0
    End Function
End Class
```

---

## Built-in Functions

### String Functions

```vb
' Length and substrings
Dim text As String = "Hello World"
Dim length As Integer = Len(text)        ' 11
Dim left3 As String = Left(text, 3)      ' "Hel"
Dim right5 As String = Right(text, 5)    ' "World"
Dim middle As String = Mid(text, 7, 5)   ' "World"

' Case conversion
Dim upper As String = UCase(text)        ' "HELLO WORLD"
Dim lower As String = LCase(text)        ' "hello world"

' Search and replace
Dim pos As Integer = InStr(text, "World") ' 7
Dim replaced As String = Replace(text, "World", "VisualGasic") ' "Hello VisualGasic"

' Trimming
Dim trimmed As String = Trim("  Hello  ")  ' "Hello"
```

### Math Functions

```vb
' Basic math
Dim result As Double
result = Abs(-5)      ' 5 (absolute value)
result = Sqr(16)      ' 4 (square root)
result = Sin(0)       ' 0 (sine)
result = Cos(0)       ' 1 (cosine)
result = Tan(0)       ' 0 (tangent)
result = Log(2.718)   ' 1 (natural logarithm)
result = Exp(1)       ' 2.718 (e^x)

' Rounding
result = Int(3.7)     ' 3 (truncate)
result = Round(3.7)   ' 4 (round to nearest)

' Random numbers
Randomize             ' Initialize random seed
result = Rnd()        ' Random between 0 and 1
result = Int(Rnd() * 6) + 1  ' Random 1-6 (dice roll)
```

### Array Functions

```vb
Dim arr As Array = [1, 2, 3, 4, 5]

' Array bounds
Dim lower As Integer = LBound(arr)  ' 0
Dim upper As Integer = UBound(arr)  ' 4

' Dynamic arrays
ReDim arr(10)           ' Resize array
ReDim Preserve arr(20)  ' Resize keeping existing data
```

### File I/O Functions

```vb
' File operations
Dim fileNum As Integer = FreeFile()  ' Get available file handle
Open "data.txt" For Input As fileNum
Dim content As String = Input(LOF(fileNum), fileNum)  ' Read entire file
Close fileNum

' Close statement options
Close 1           ' Close specific file handle
Close             ' Close ALL open files at once

' Multiple files example
Open "file1.txt" For Input As 1
Open "file2.txt" For Input As 2
Open "file3.txt" For Input As 3
Close 2           ' Only closes file handle 2
Close             ' Closes all remaining files (1 and 3)

' File information
Dim size As Long = FileLen("data.txt")
Dim exists As Boolean = (Dir("data.txt") <> "")
```

### Game and Application Development Functions

```vb
' Audio (games and multimedia applications)
Volume 75                           ' Set master volume (0-100)
Music "res://audio/background.ogg"  ' Play background music
Sample 1, "res://audio/effect.wav"  ' Play sound effect

' Input (user interaction for applications and games)
Dim mouseX As Integer = MouseX()     ' Mouse X coordinate
Dim mouseY As Integer = MouseY()     ' Mouse Y coordinate  
Dim buttons As Integer = MouseClick() ' Mouse button state
Dim key As String = Inkey()          ' Last pressed key

' Timing
Dim elapsed As Double = Timer()      ' Time since engine start
Sleep(2500)                         ' Pause execution for 2500 milliseconds (2.5 seconds)

' Sleep function usage
Sleep(1000)                         ' Pause for 1 second
Sleep(500)                          ' Pause for 0.5 seconds

' Utility (general application functions)
Cls                                 ' Clear screen
Dim choice = Choose(score > 100, "Winner!", "Try again!")
```

---

## Modern Language Features

### Lambda Expressions

```vb
' Simple lambda
Dim square = Lambda(x) x * x
Dim result = square(5)  ' 25

' Lambda with multiple parameters
Dim add = Lambda(a, b) a + b
Dim sum = add(3, 4)     ' 7

' Using lambdas with collections
Dim numbers = [1, 2, 3, 4, 5]
Dim doubled = numbers.Map(Lambda(x) x * 2)  ' [2, 4, 6, 8, 10]
```

### Pattern Matching

```vb
' Match statement
Match playerInput
    Case "north", "n"
        MoveNorth()
    Case "south", "s"
        MoveSouth()
    Case "inventory", "i"
        ShowInventory()
    Case Else
        Print "Unknown command"
End Match

' Pattern matching with conditions
Match score
    Case Is > 1000
        Print "Legendary!"
    Case 500 To 999
        Print "Expert!"
    Case Is < 100
        Print "Beginner"
End Match
```

**See Also:** [Select Case](#select-case) - Classic conditional branching with similar syntax.

### Null-Safe Operations

```vb
' Null-safe member access
Dim length = player?.Name?.Length  ' Returns Nothing if player or Name is null

' Null coalescing
Dim displayName = player?.Name ?? "Unknown Player"
```

### Type Inference

```vb
' Compiler infers types
Dim count = 42           ' Integer
Dim message = "Hello"    ' String  
Dim active = True        ' Boolean
Dim position = Vector2(100, 200)  ' Vector2
```

---

## Godot Integration

### Node Interaction

```vb
' Getting node references
Dim player = GetNode("Player")
Dim ui = GetNode("UI/HealthBar")

' Creating nodes dynamically
Dim newSprite = CreateNode("Sprite2D")
newSprite.Texture = Load("res://player.png")
AddChild(newSprite)
```

### Signal System

```vb
' Declare signals
Signal HealthChanged(newHealth As Integer)
Signal PlayerDied()

' Emit signals
Emit HealthChanged(currentHealth)
Emit PlayerDied()

' Connect signals
Connect(player, "health_changed", "OnHealthChanged")

' Signal handler
Sub OnHealthChanged(newHealth As Integer)
    healthBar.Value = newHealth
End Sub
```

### Scene Management

```vb
' Change scenes
ChangeScene("res://levels/Level2.tscn")

' Get current scene
Dim currentScene = GetTree().CurrentScene
```

### Resource Loading

```vb
' Load resources
Dim texture = Load("res://sprites/player.png")
Dim sound = Load("res://audio/jump.wav")
Dim scene = Load("res://enemies/Goblin.tscn")

' Instantiate scenes
Dim enemy = scene.Instantiate()
AddChild(enemy)
```

### Event-Driven Programming with Whenever

VisualGasic's **Whenever System** represents one of the most advanced reactive programming implementations available in any modern language, providing declarative, efficient, and memory-safe event-driven capabilities that surpass traditional reactive frameworks found in other programming ecosystems.

The Whenever system enables developers to create sophisticated, responsive applications by monitoring variables and automatically executing procedures when specific conditions are met, all while maintaining code clarity and preventing common pitfalls like callback hell or memory leaks.

#### Core Whenever Concepts

The Whenever system operates on **declarative sections** that monitor program state and react to changes:

```vb
' Basic syntax: Whenever Section [Local] SectionName variable|expression condition [value] callback[,callback...]
Whenever Section HealthMonitor playerHealth Changes UpdateHealthDisplay
Whenever Section GameOver playerLives Becomes 0 ShowGameOverScreen
Whenever Section HighScore score Exceeds 10000 CelebrationEffect
```

#### Comparison Operators

VisualGasic supports six powerful comparison operators for different monitoring scenarios:

| Operator | Description | Example |
|----------|-------------|---------|
| `Changes` | Triggers on any value change | `health Changes UpdateUI` |
| `Becomes` | Triggers when value equals target | `lives Becomes 0 GameOver` |
| `Exceeds` | Triggers when value surpasses threshold | `score Exceeds 1000 Bonus` |
| `Below` | Triggers when value falls under threshold | `health Below 25 LowHealthWarning` |
| `Between` | Triggers when value is within range | `temp Between 32 And 100 NormalTemp` |
| `Contains` | Triggers when string/array contains value | `name Contains "admin" AdminMode` |

```vb
' Comprehensive operator examples
Whenever Section HealthCritical health Below 20 ShowCriticalWarning
Whenever Section OptimalRange temperature Between 68 And 72 MaintainClimate
Whenever Section SecurityAlert username Contains "root" LogSecurityEvent
Whenever Section ScoreThreshold points Exceeds 5000 UnlockLevel
Whenever Section StatusChange gameState Changes UpdateInterface
Whenever Section Victory enemiesRemaining Becomes 0 ShowVictoryScreen
```

#### Multiple Callback Execution

Execute multiple procedures in sequence for sophisticated event handling:

```vb
' Multiple callbacks - executed in order
Whenever Section PlayerDeath health Becomes 0 SaveProgress, ShowDeathScreen, PlayDeathSound, ResetLevel

' Complex multi-step responses
Whenever Section LevelComplete enemiesKilled Exceeds targetKills UpdateScore, ShowLevelComplete, SaveProgress, LoadNextLevel

Sub SaveProgress()
    WriteFile("save.dat", gameState)
    Print "Progress saved"
End Sub

Sub ShowDeathScreen()
    FadeToBlack()
    DisplayUI("game_over")
End Sub
```

#### Advanced Complex Expressions

Monitor multiple variables simultaneously with boolean expressions that rival advanced reactive frameworks:

```vb
' Multi-variable complex conditions
Whenever Section EmergencyMode (health < 15 And mana < 10 And enemiesNear > 2) ActivateEmergencyProtocols
Whenever Section PowerUpMode (score > 1000 And level >= 3 And hasSpecialKey = True) EnablePowerMode
Whenever Section ComboSystem (consecutiveHits > 5 And timeSinceLastHit < 2.0) TriggerComboBonus
Whenever Section CriticalState (playerHealth <= 10 Or shieldEnergy <= 5) And Not invulnerable CriticalAlert

' Complex game state monitoring
Whenever Section BossPhase (bossHealth < 500 And phaseNumber < 3 And playerLevel >= 10) TriggerBossPhaseTransition
Whenever Section AchievementUnlock (totalScore >= 50000 And secretsFound >= 10 And timeCompleted < 1800) UnlockSpeedrunAchievement

Sub ActivateEmergencyProtocols()
    Print "EMERGENCY: Multiple critical conditions detected!"
    ActivateShields(True)
    SlowTime(0.5)
    HighlightEnemies(True)
End Sub

Sub TriggerComboBonus()
    comboMultiplier = comboMultiplier * 1.5
    ShowComboEffect(consecutiveHits)
    PlayComboSound()
End Sub
```

#### Scoped Sections with Automatic Cleanup

Prevent memory leaks and maintain clean code with automatic scope-based cleanup:

```vb
Sub BossEncounterPhase()
    Print "Entering boss encounter..."
    
    ' Local sections - automatically cleaned up when Sub ends
    Whenever Section Local BossRageMode bossHealth Below 30 ActivateBossRage
    Whenever Section Local BossStunned (bossHealth < 10 And bossStamina > 80) BossStunRecovery
    Whenever Section Local PlayerAdvantage (playerHealth > 50 And bossHealth < 25) PlayerAdvantageBonus
    
    ' Complex local monitoring
    Whenever Section Local CriticalMoment (bossHealth < 5 And playerHealth < 15) FinalShowdown
    
    ' Boss fight logic here...
    ExecuteBossFight()
    
    Print "Boss defeated - all local Whenever sections automatically cleaned up"
End Sub ' All Local sections automatically removed

Class GameLevel
    Sub EnterLevel()
        ' Member-scoped sections (cleaned up when object is destroyed)  
        Whenever Section Member LevelTimer gameTime Exceeds levelTimeLimit ShowTimeWarning
        Whenever Section Member ObjectiveComplete objectivesCompleted Becomes totalObjectives LevelComplete
    End Sub
End Class
```

#### Debouncing and Performance Control

Prevent callback storms and optimize performance with built-in timing controls:

```vb
' Debouncing prevents rapid-fire execution
Whenever Section UIUpdate score Changes UpdateScoreDisplay Debounce 100ms
Whenever Section NetworkSync playerPosition Changes SendPositionUpdate Throttle 50ms

' High-frequency monitoring with controlled execution
Whenever Section InputProcessor mousePosition Changes ProcessMouseInput Debounce 16ms ' ~60 FPS
```

#### Suspend and Resume Control

Dynamically control monitoring for sophisticated state management:

```vb
Sub EnterCutscene()
    ' Temporarily disable game monitoring during cutscenes
    Suspend Whenever HealthMonitor
    Suspend Whenever InputProcessor
    Suspend Whenever GameLogic
    
    PlayCutscene("intro_scene.mp4")
End Sub

Sub ExitCutscene()
    ' Re-enable monitoring
    Resume Whenever HealthMonitor
    Resume Whenever InputProcessor  
    Resume Whenever GameLogic
End Sub

Sub EnterPauseMenu()
    ' Selective suspension - keep UI active but pause game logic
    Suspend Whenever GameTimer
    Suspend Whenever EnemyAI
    ' Keep UI monitoring active
End Sub
```

#### Debugging and Monitoring Tools

Professional debugging capabilities for complex applications:

```vb
Sub DiagnoseWheneverSystem()
    ' Comprehensive system status
    Print WheneverStatus()
    ' Output:
    ' Whenever System Status:
    ' Total Sections: 8
    ' - HealthMonitor (health Changes) -> UpdateHealthBar [Active]
    ' - GameOver (lives Becomes 0) -> ShowGameOver, ResetLevel [Active] 
    ' - BossRage (bossHealth Below 30) -> ActivateBossRage [Local - BossEncounter]
    ' Active Sections: 7
    
    ' Performance monitoring
    Dim activeCount = ActiveWheneverCount()
    Print "Currently monitoring: " & activeCount & " sections"
    
    ' Cleanup for testing
    ClearWheneverSections()
    Print "All sections cleared for testing"
End Sub

Sub PerformanceAnalysis()
    ' Monitor callback execution times
    For Each section In GetWheneverSections()
        Print section.name & " - Last execution: " & section.lastExecutionTime & "ms"
    Next
End Sub
```

#### Advanced Patterns and Best Practices

**1. State Machine Implementation**
```vb
' Elegant state machine using Whenever
Whenever Section StateIdle gameState Becomes "idle" OnEnterIdle
Whenever Section StateRunning gameState Becomes "running" OnEnterRunning  
Whenever Section StatePaused gameState Becomes "paused" OnEnterPaused
Whenever Section StateGameOver gameState Becomes "gameover" OnEnterGameOver

Sub OnEnterRunning()
    EnableGameInput(True)
    StartGameTimer()
    ResumeEnemyAI()
End Sub
```

**2. Resource Management**
```vb
' Automatic resource monitoring
Whenever Section LowMemory availableMemory Below 100MB FreeResources
Whenever Section NetworkLatency pingTime Exceeds 200 SwitchToOfflineMode
Whenever Section BatteryLow batteryLevel Below 15 EnablePowerSaveMode
```

**3. Game Logic Patterns**
```vb
' Sophisticated game mechanics
Whenever Section ComboSystem (hitStreak >= 3 And timeBetweenHits < 1.0) IncrementCombo
Whenever Section DifficultyAdjust (playerDeaths > 5 And currentDifficulty > 1) ReduceDifficulty
Whenever Section AchievementSystem totalPlayTime Exceeds 3600 UnlockTimeBasedAchievement
```

**4. Safety and Performance Guidelines**

- **Avoid Recursion**: Never modify watched variables inside their callbacks
- **Use Local Scope**: Prefer `Whenever Section Local` for temporary monitoring
- **Implement Debouncing**: Add timing controls for high-frequency events  
- **Descriptive Naming**: Use clear, intention-revealing section names
- **Callback Efficiency**: Keep callback procedures fast and focused

```vb
' Good: Safe callback design
Whenever Section HealthMonitor health Changes OnHealthChanged

Sub OnHealthChanged()
    Suspend Whenever HealthMonitor  ' Prevent recursion
    
    If health <= 0 Then
        lives = lives - 1
        health = 100  ' Safe to modify now
    End If
    
    UpdateHealthBar(health)
    Resume Whenever HealthMonitor
End Sub

' Better: Use different variables to avoid recursion entirely
Whenever Section HealthMonitor health Changes UpdateHealthDisplay
Sub UpdateHealthDisplay()
    healthBarValue = health  ' Update display variable instead
End Sub
```

#### Performance and Architecture

The VisualGasic Whenever system provides:

- **Zero-Overhead Abstraction**: Compiled to efficient native code with minimal runtime cost
- **Memory Safety**: Automatic cleanup prevents memory leaks in long-running applications
- **Scalability**: Handles thousands of concurrent monitoring sections efficiently
- **Thread Safety**: Safe for multi-threaded applications and game engines
- **Integration**: Seamless integration with Godot's scene system and signals

#### Comparison with Other Frameworks

VisualGasic's Whenever system provides capabilities that exceed many established reactive frameworks:

| Feature | VisualGasic Whenever | RxJS | MobX | Vue.js Reactivity |
|---------|---------------------|------|------|------------------|
| Declarative Syntax | ✅ | ✅ | ✅ | ✅ |
| Multiple Callbacks | ✅ | ❌ | ❌ | ❌ |
| Complex Expressions | ✅ | ⚠️ | ❌ | ⚠️ |
| Automatic Cleanup | ✅ | ❌ | ❌ | ✅ |
| Built-in Debouncing | ✅ | ✅ | ❌ | ❌ |
| Memory Safety | ✅ | ❌ | ⚠️ | ✅ |
| Performance Debugging | ✅ | ❌ | ⚠️ | ⚠️ |

The Whenever system elevates VisualGasic to the forefront of reactive programming languages, providing developers with unprecedented power and safety for creating responsive, maintainable applications.

---

This documentation provides a comprehensive overview of VisualGasic's advanced capabilities and modern language features. The format is professional and showcases VisualGasic as a powerful, contemporary programming language for cross-platform application and game development.
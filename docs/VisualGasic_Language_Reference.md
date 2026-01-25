# VisualGasic Language Reference

## Table of Contents

### [Getting Started](#getting-started)
- [Introduction](#introduction)  
- [Installation](#installation)
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

### Loops

#### For-Next Loop
```vb
' Basic for loop
For i = 1 To 10
    Print i
Next i

' With step
For i = 0 To 100 Step 5
    Print i
Next i

' Backwards
For i = 10 To 1 Step -1
    Print i
Next i
```

#### For-Each Loop
```vb
Dim items As Array = ["apple", "banana", "cherry"]
For Each item In items
    Print item
Next item
```

#### While-Wend Loop
```vb
While health > 0
    TakeDamage()
    If health <= 0 Then Exit While
Wend
```

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
Wait 2.5                            ' Pause execution for 2.5 seconds

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

---

This documentation provides a comprehensive overview of VisualGasic's advanced capabilities and modern language features. The format is professional and showcases VisualGasic as a powerful, contemporary programming language for cross-platform application and game development.
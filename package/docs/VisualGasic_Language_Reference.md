# VisualGasic Language Reference

## Table of Contents

### [Getting Started](#getting-started)
- [Introduction](#introduction)  
- [Visual Basic Heritage](#visual-basic-heritage)
- [Importing VB6 Projects](#importing-vb6-projects)
  - [Supported VB6 Controls](#supported-vb6-controls)
  - [VB6 Menu Support](#vb6-menu-support)
  - [Property Mapping](#property-mapping)
  - [Control Arrays](#control-arrays)
  - [Code Transformation](#code-transformation)
  - [VB6 Functions](#vb6-functions)
  - [VB6 Constants](#vb6-constants)
  - [Import Report](#import-report)
  - [Programmatic Import API](#programmatic-import-api)
- [Installation](#installation)
- [Editor Shortcuts](#editor-shortcuts)
- [Your First Script](#your-first-script)

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
- [Scope and Lifetime](#scope-and-lifetime)

### [Object-Oriented Features](#object-oriented-features)
- [Classes and Types](#classes-and-types)
- [Inheritance](#inheritance)
- [Interfaces](#interfaces)
- [Events (WithEvents / RaiseEvent)](#events-withevents--raiseevent)
- [Properties and Methods](#properties-and-methods)

### [Built-in Functions](#built-in-functions)
- [String Functions](#string-functions)
- [Math Functions](#math-functions)
- [Array Functions](#array-functions)
- [File I/O Functions](#file-io-functions-classic-vb6-style)
- [Classic DATA Statements](#classic-data-statements)
  - [Typed Read](#typed-read-new-in-v320)
  - [Empty Data Slots](#empty-data-slots-new-in-v320)
  - [ClearData Statement](#cleardata-statement-new-in-v320)
  - [DataFromString Statement](#datafromstring-statement-new-in-v320)
  - [Data Introspection Functions](#data-introspection-functions-new-in-v320)
  - [Performance: Data/Read vs Arrays](#performance-dataread-vs-arrays)
- [Game and Application Development Functions](#game-and-application-development-functions)

### [VB6 Global Objects](#vb6-global-objects)
- [App Object](#app-object)
- [Screen Object](#screen-object)
- [Err Object](#err-object)
- [Printer Object](#printer-object)
- [PrintForm Statement](#printform-statement)

### [COM-Style Objects](#com-style-objects)
- [VGCollection](#vgcollection)
- [VGRegEx](#vgregex)
- [VGHttpRequest](#vghttprequest)
- [VGTimer](#vgtimer)

### [System Integration](#system-integration)
- [NativeLibrary (FFI)](#nativelibrary-ffi)
- [NativeStruct](#nativestruct)
- [VGOdbc (Database)](#vgodbc-database)
- [VGCrypto (Cryptography)](#vgcrypto-cryptography)
- [VGXml (XML Processing)](#vgxml-xml-processing)
- [VGZip (ZIP Archives)](#vgzip-zip-archives)
- [VGTask (Async Tasks)](#vgtask-async-tasks)
- [VGTaskRunner (Parallel)](#vgtaskrunner-parallel)
- [VisualGasicPackage (Package Manager)](#visualgasicpackage-package-manager)

### [System-Level Programming](#system-level-programming)
- [VGSystem (System Info)](#vgsystem-system-info)
- [VGSignalHandler (OS Signals)](#vgsignalhandler-os-signals)
- [VGFilePermissions (Permissions & Links)](#vgfilepermissions-permissions--links)
- [VGMemoryBuffer (Raw Memory)](#vgmemorybuffer-raw-memory)
- [VGIPC (Inter-Process Communication)](#vgipc-inter-process-communication)
- [VGAndroidBridge (Android Platform)](#vgandroidbridge-android-platform)

### [Modern Language Features](#modern-language-features)
- [Lambda Expressions](#lambda-expressions)
- [Pattern Matching](#pattern-matching)
- [Null-Safe Operations](#null-safe-operations)
- [Type Inference](#type-inference)
- [Event-Driven Programming with Whenever](#event-driven-programming-with-whenever)
- [Multitasking and Concurrency](#multitasking-and-concurrency)

### [Godot Integration](#godot-integration)
- [Node Interaction](#node-interaction)
- [Signal System](#signal-system)
- [Scene Management](#scene-management)
- [Resource Loading](#resource-loading)

### [v3.5.0-beta4 Language Enhancements](#v350-beta4-language-enhancements)

### [v3.6.0 Language Enhancements](#v360-language-enhancements)
- [Compound Assignment Operators](#compound-assignment-operators)
- [Bit-Shift Operators](#bit-shift-operators)
- [LongLong Type](#longlong-type)
- [WithEvents / RaiseEvent](#withevents--raiseevent-v350)
- [Implements Verification](#implements-verification-v350)
- [Printer Object & PrintForm](#printer-object--printform-v350)
- [Optional Parameters](#optional-parameters-v350)

### [v3.7.0 Language Enhancements](#v370-language-enhancements)
- [Method Overloading](#method-overloading)
- [Parameterized Constructors](#parameterized-constructors)
- [Generics — Collection(Of T)](#generics)
- [Game UI Mode](#game-ui-mode)

---

## Getting Started

### Introduction

VisualGasic is a modern, forward-looking programming language designed for application and game development on the Godot 4.5+ platform. The name "Gasic" stands for **G**odot **A**ll-purpose **S**ymbolic **C**ode (when used within Godot) or **G**eneral **A**ll-purpose **S**ymbolic **C**ode (for standalone applications), representing its versatility as both a game development language and a general-purpose programming solution.

> **VisualGasic is not a VB6 clone.** It is a distinct, modern language that takes inspiration from VB6's legendary approachability — the simple syntax, the ease of learning, the RAD workflow — and builds something new on that foundation. If you know VB6, you'll feel at home in minutes. But VisualGasic goes far beyond VB6 with features like lambda expressions, async/await, pattern matching, null-safe operators, GPU computing, generics, and a JIT-compiled bytecode engine. VG is VB6-*compatible* where it makes sense, but it is designed to look forwards, not backwards.

VisualGasic serves as a **RAD (Rapid Application Development) IDE** environment, combining intuitive syntax with powerful language features, seamless Godot integration, and cross-platform capabilities to accelerate the development process for both applications and games.

Whether you're creating desktop applications, mobile apps, web software, or interactive games, VisualGasic provides the tools and cross-platform flexibility you need for professional development.

**Key Features:**
- Clean, intuitive syntax — familiar to VB6 developers, accessible to everyone
- Modern language features: lambdas, async/await, pattern matching, null-safety, generics
- Full Godot 4.5+ integration for applications and games
- Cross-platform development support
- Object-oriented programming with classes, inheritance, and interfaces
- JIT-compiled bytecode engine — faster than GDScript, competitive with native C++
- Built-in functions for game and application development
- Type safety with optional explicit typing

### Visual Basic Heritage
VisualGasic takes its inspiration from **Visual Basic 6.0** (VB6), one of the most successful programming languages in history. If you have experience with VB6, VBA (Visual Basic for Applications), or any BASIC dialect, you'll feel right at home with VisualGasic.

However, **VisualGasic is not a VB6 clone or reimplementation**. It is its own language. VB6's genius was its simplicity — anyone could learn it, and you could build real software in minutes. VisualGasic preserves that spirit while adding the features that modern developers expect: lambda expressions, async/await concurrency, pattern matching, null-safe operators (`??`, `?.`), generics, GPU computing, and a JIT-compiled bytecode engine. VB6 code will often run in VisualGasic with minimal changes, but VisualGasic code can do things VB6 never could.

#### What is BASIC?

BASIC (**B**eginner's **A**ll-purpose **S**ymbolic **I**nstruction **C**ode) was created in 1964 at Dartmouth College to make programming accessible to everyone. Visual Basic, introduced by Microsoft in 1991, added a graphical IDE and drag-and-drop form designer, revolutionizing Windows application development.

#### VB6 Compatibility

VisualGasic supports a large subset of VB6 syntax for easy porting and familiarity, including:

**Variables and Data Types:**
```vb
' VB6-style variable declarations
Dim playerName As String
Dim score As Integer
Dim isActive As Boolean
Dim position As Single

' Type suffixes (classic BASIC style)
Dim count%          ' Integer
Dim price#          ' Double
Dim message$        ' String
```

**Control Structures:**
```vb
' If/Then/Else (VB6 style)
If score > 100 Then
    Print "High score!"
ElseIf score > 50 Then
    Print "Good job!"
Else
    Print "Keep trying!"
End If

' Select Case (VB6's switch statement)
Select Case playerClass
    Case "Warrior"
        strength = 10
    Case "Mage"
        intelligence = 10
    Case Else
        charisma = 10
End Select

' For/Next loops
For i = 1 To 10
    Print i
Next i

' Do/Loop variations
Do While health > 0
    TakeDamage()
Loop

Do
    ProcessInput()
Loop Until gameOver
```

**Subroutines and Functions:**
```vb
' Subroutines (no return value)
Sub UpdateScore(points As Integer)
    score = score + points
    UpdateDisplay()
End Sub

' Functions (return a value)
Function CalculateDamage(baseAttack As Integer) As Integer
    Dim damage As Integer
    damage = baseAttack * Rnd() * 2
    CalculateDamage = damage   ' VB6 style return
End Function

' Or use Return statement (modern style)
Function GetPlayerName() As String
    Return "Player One"
End Function
```

**Built-in VB6 Functions:**
```vb
' String functions
Dim s As String
s = Left("Hello", 3)        ' Returns "Hel"
s = Right("Hello", 2)       ' Returns "lo"
s = Mid("Hello", 2, 3)      ' Returns "ell"
s = UCase("hello")          ' Returns "HELLO"
s = LCase("HELLO")          ' Returns "hello"
s = Trim("  hi  ")          ' Returns "hi"
x = Len("Hello")            ' Returns 5
x = InStr("Hello", "l")     ' Returns 3

' Math functions
x = Abs(-5)                 ' Returns 5
x = Sqr(16)                 ' Returns 4 (square root)
x = Int(3.7)                ' Returns 3
x = Rnd()                   ' Returns random 0-1
x = Round(3.567, 2)         ' Returns 3.57

' Conversion functions
s = CStr(42)                ' Convert to string
x = CInt("42")              ' Convert to integer
x = CDbl("3.14")            ' Convert to double
x = Val("123abc")           ' Returns 123

' Date/Time functions
Print Now                   ' Current date/time
Print Timer                 ' Seconds since midnight
Print Year(Now)             ' Current year
Print Month(Now)            ' Current month
Print Day(Now)              ' Current day
```

**Event-Driven Programming:**
```vb
' Classic VB6 event handlers
Private Sub Form_Load()
    ' Runs when form loads
    InitializeGame()
End Sub

Private Sub Command1_Click()
    ' Runs when button is clicked
    StartGame()
End Sub

Private Sub Timer1_Timer()
    ' Runs on timer interval
    UpdateGame()
End Sub
```

#### Importing VB6 Projects

VisualGasic includes a comprehensive importer for legacy VB6 projects. Simply use the **Import VB6 Project...** button in the Toolbox to convert:
- `.vbp` project files (complete projects)
- `.frm` form files with controls and code
- `.bas` module files
- `.cls` class files

Controls are automatically mapped to Godot equivalents, event handlers are wired up to signals, and code is transformed to VisualGasic syntax.

##### Supported VB6 Controls

The importer supports **60+ VB6 control types** with automatic mapping to Godot nodes:

| VB6 Control | Godot Equivalent |
|-------------|------------------|
| CommandButton | Button |
| TextBox | LineEdit / TextEdit |
| Label | Label |
| CheckBox | CheckBox |
| OptionButton | CheckBox (radio mode) |
| ComboBox | OptionButton |
| ListBox | ItemList |
| PictureBox / Image | TextureRect |
| Frame | Panel |
| Timer | Timer |
| HScrollBar / VScrollBar | HScrollBar / VScrollBar |
| Shape | ColorRect |
| Line | Line2D |
| ProgressBar | ProgressBar |
| Slider | HSlider |
| TreeView / ListView | Tree |
| TabStrip | TabContainer |
| StatusBar | Panel |
| Toolbar | HBoxContainer |
| CommonDialog | FileDialog |
| RichTextBox | RichTextLabel |
| DTPicker | SpinBox |
| Winsock | StreamPeerTCP |
| Inet | HTTPRequest |
| MMControl | AudioStreamPlayer |
| FlexGrid / DataGrid | Tree |

**Third-Party OCX Controls Also Supported:**
- MSComctlLib controls (comctl32.ocx, mscomctl.ocx)
- MSComDlg controls (comdlg32.ocx)
- RichText controls (richtx32.ocx)
- MSFlexGrid (msflxgrd.ocx)
- Threed controls (3D panels, buttons)
- And many more...

##### VB6 Menu Support

VB6 menus are automatically converted:
- Menu bars become `MenuBar` nodes
- Menu items become `PopupMenu` entries
- Separators (`Caption = "-"`) are preserved
- Shortcuts, Checked, Enabled states are maintained
- Menu event handlers (`mnuFile_Click`) are wired to signals

##### Property Mapping

The importer handles comprehensive property translation:

**Position & Size:**
- Left, Top, Width, Height (TWIPS → pixels @ 15:1 ratio)
- ClientLeft, ClientTop, ClientWidth, ClientHeight
- ScaleWidth, ScaleHeight

**Text & Appearance:**
- Caption, Text, Alignment
- Font properties (Name, Size, Bold, Italic, Underline)
- ForeColor, BackColor (with system color support)
- ToolTipText, Tag

**Control-Specific:**
- MultiLine, ScrollBars, PasswordChar, MaxLength (TextBox)
- Min, Max, Value, SmallChange, LargeChange (Scrollbars)
- Interval (Timer)
- Visible, Enabled, Locked

**Form/Window Properties:**
- WindowState, StartUpPosition
- ControlBox, MaxButton, MinButton
- BorderStyle, Moveable, ShowInTaskbar
- KeyPreview, Icon

##### Control Arrays

VB6 control arrays (controls with `Index` property) are automatically handled:
- Controls are renamed with index suffix: `Num(0)` → `Num_0`
- Code references are transformed: `Num(Index).Caption` → `Num_Index.Caption`
- Event handlers with Index parameter work correctly

##### Code Transformation

VB6 code is automatically transformed to VisualGasic:

**Automatic Transformations:**
- `Let x = 5` → `x = 5` (Let keyword removed)
- `Set obj = New Class` → `obj = New Class` (Set keyword removed)
- `Debug.Print` → `Print`
- `Me.Control` → `Control` (implicit self)
- Type suffixes: `Dim x$` → `Dim x As String`

**Error Handling (with comments):**
- `On Error GoTo label` → `' On Error GoTo label  ' TODO: Use Try/Catch`
- `On Error Resume Next` → `' On Error Resume Next  ' TODO: Use Try/Catch`

**Warnings Added:**
- Standalone `End` converted to `Exit Sub`

> **Note:** `GoSub`/`Return` is fully implemented in v2.10.0 and no longer flagged as deprecated.

##### VB6 Functions

All standard VB6 functions are supported:

**String Functions:**
`Len`, `Mid`, `Left`, `Right`, `UCase`, `LCase`, `Trim`, `LTrim`, `RTrim`, `InStr`, `InStrRev`, `Replace`, `Split`, `Join`, `Space`, `String`, `Asc`, `Chr`

**Conversion Functions:**
`Val`, `Str`, `CStr`, `CInt`, `CLng`, `CDbl`, `CSng`, `CBool`, `CDate`, `Hex`, `Oct`

**Math Functions:**
`Abs`, `Int`, `Fix`, `Sgn`, `Sqr`, `Log`, `Exp`, `Sin`, `Cos`, `Tan`, `Atn`, `Rnd`, `Round`

**Date/Time Functions:**
`Now`, `Date`, `Time`, `Timer`, `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second`, `Weekday`, `DateSerial`, `TimeSerial`, `DateAdd`, `DateDiff`

**Type Checking:**
`IsNumeric`, `IsDate`, `IsEmpty`, `IsNull`, `IsArray`, `IsObject`, `TypeName`, `VarType`

**File Functions:**
`Dir`, `FileLen`, `EOF`, `LOF`, `FreeFile`

**Miscellaneous:**
`IIf`, `Choose`, `Switch`, `Format`, `InputBox`, `MsgBox`, `DoEvents`, `Shell`, `Environ`

##### VB6 Constants

All VB6 constants are recognized:

**MsgBox:**
`vbOKOnly`, `vbOKCancel`, `vbYesNo`, `vbYesNoCancel`, `vbCritical`, `vbQuestion`, `vbExclamation`, `vbInformation`, `vbOK`, `vbCancel`, `vbYes`, `vbNo`

**String:**
`vbCrLf`, `vbCr`, `vbLf`, `vbTab`, `vbNewLine`, `vbNullChar`, `vbNullString`

**Other:**
`True`, `False`, `Nothing`, `vbEmpty`, `vbNull`, `vbBinaryCompare`, `vbTextCompare`

##### Import Report

After importing, a detailed report is generated:

```
============================================================
VB6 PROJECT IMPORT REPORT
============================================================

SUMMARY
----------------------------------------
Forms Imported:   3
Modules Imported: 2
Errors:           0
Warnings:         1

IMPORTED FORMS
----------------------------------------
  [OK] Calculate
       Scene: res://start_forms/Calculate.tscn
       Code:  res://mixed/Calculate.vg
       Control Arrays: ["Num"]

MANUAL STEPS REQUIRED
----------------------------------------
1. Review and fix any 'On Error' statements (convert to Try/Catch)
2. Replace VB6 'End' statements with appropriate exit commands
3. Check control array access patterns
4. Update any database/data control references
5. Review menu shortcut key bindings
6. Test signal connections for event handlers
7. Adjust form sizes/positions for Godot coordinate system
```

##### Programmatic Import API

You can also import VB6 projects programmatically:

```vb
' Import a complete project
Dim result As Dictionary = VB6Importer.import_project("C:/Projects/MyApp.vbp")
If result.success Then
    Print "Imported " & result.forms.size() & " forms"
End If

' Import a single form
Dim formResult As Dictionary = VB6Importer.import_form_file("C:/Projects/MainForm.frm")

' Generate and save import report
Dim report As String = VB6Importer.generate_import_report(result)
VB6Importer.save_import_report(report, "MyApp")

' Check if a control type is supported
If VB6Importer.is_control_supported("MSComctlLib.ProgressBar") Then
    Print "ProgressBar is supported!"
End If

' Get Godot equivalent for a VB6 control
Dim godotType As String = VB6Importer.get_godot_equivalent("VB.CommandButton")
' Returns: "Button"
```

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
4. Files with `.vg` or `.bas` extension will now use VisualGasic syntax

---

## The VisualGasic IDE

VisualGasic provides a complete **Rapid Application Development (RAD)** environment within Godot, inspired by Visual Basic 6's legendary productivity tools.

### Toolbox Panel

The **Toolbox** is located in the left dock and provides quick access to all development features:

**Import Section:**
- **Import VB6 Project...** - Import complete `.vbp` project files with all forms and modules
- **Import VB6 Form...** - Import individual `.frm` form files with control mappings

**Form Creation:**
- **New Form** - Create a new form from templates:
  - **Blank Form** - Empty form ready for controls
  - **Dialog Form** - Pre-configured with OK/Cancel buttons
  - **About Box** - Standard about dialog template
  - **Splash Screen** - Startup splash screen
  - **Login Form** - Username/password entry form
  - **Main Form with Menu** - Form with menu bar
  - **Data Entry Form** - Common data entry controls
  - **MDI Parent Form** - Multiple Document Interface parent
  - **MDI Child Form** - MDI child window

**Tools Menu (Project > Tools):**
- **Visual Gasic Menu Editor** - Design menu bars visually
- **Visual Gasic Project Properties** - Configure startup form and project settings
- **Visual Gasic Object Browser** - Browse all available objects and their members
- **Visual Gasic Tab Order** - Set control tab order visually

### Visual Gasic IDE

The **Visual Gasic IDE** provides a full WYSIWYG editing experience with 40+ controls, VB6-style properties (Caption, BackColor, ForeColor, BorderStyle, ControlBox, MinButton, MaxButton), and a live preview system.

![Visual Gasic IDE](screenshots/form_designer_ide.png)

**Creating a Form:**
1. Click **New Form** in the Toolbox
2. Select a template (or Blank Form)
3. Enter a form name
4. The form opens in the 2D editor for visual editing

**Adding Controls:**
- Click a control in the Toolbox, then click on the form to place it
- Use Godot's scene tree to add Control nodes
- Available VB6-style controls (mapped to Godot):

**Standard Controls:**
| VB6 Control | Godot Node | Description |
|-------------|------------|-------------|
| Label | Label | Display static text |
| TextBox | LineEdit | Single-line text input |
| TextArea | TextEdit | Multi-line text input |
| CommandButton | Button | Clickable button |
| CheckBox | CheckBox | On/off toggle |
| OptionButton | CheckBox (in group) | Radio button selection |
| ListBox | ItemList | Scrollable list |
| ComboBox | OptionButton | Dropdown selection |
| PictureBox | TextureRect | Image display |
| Frame | Panel | Container border |
| GroupBox | Panel | Captioned container |
| Timer | Timer | Timed events |
| HScroll | HScrollBar | Horizontal scrollbar |
| VScroll | VScrollBar | Vertical scrollbar |

**Additional Controls:**
| VB6 Control | Godot Node | Description |
|-------------|------------|-------------|
| ProgressBar | ProgressBar | Progress indicator |
| HSlider | HSlider | Horizontal slider |
| VSlider | VSlider | Vertical slider |
| SpinBox | SpinBox | Numeric up/down |
| Shape | ColorRect | Colored rectangle |
| HLine | HSeparator | Horizontal line |
| VLine | VSeparator | Vertical line |
| RichText | RichTextLabel | Formatted text display |
| TreeView | Tree | Hierarchical tree |
| TabStrip | TabContainer | Tabbed container |
| Files | FileDialog | File open/save dialog |

**2D Game Controls:**
| Control | Godot Node | Description |
|---------|------------|-------------|
| Sprite | Sprite2D | 2D sprite display |
| AnimatedSprite | AnimatedSprite2D | Animated sprites |
| Tilemap | TileMapLayer | Tile-based maps |
| RigidBody | RigidBody2D | Physics body |
| CharacterBody | CharacterBody2D | Player character |
| Area | Area2D | Collision detection |
| Camera | Camera2D | 2D camera view |

**3D Game Controls:**
| Control | Godot Node | Description |
|---------|------------|-------------|
| MeshInstance | MeshInstance3D | 3D mesh display |
| RigidBody3D | RigidBody3D | 3D physics body |
| CharacterBody3D | CharacterBody3D | 3D character |
| Camera3D | Camera3D | 3D camera |
| DirectionalLight | DirectionalLight3D | Sun light |
| SpotLight | SpotLight3D | Spotlight |
| OmniLight | OmniLight3D | Point light |
| WorldEnvironment | WorldEnvironment | Sky and fog |
| CSGBox | CSGBox3D | CSG primitive |
| DriveListBox | FileDialog | Drive selection |
| DirListBox | FileDialog | Directory selection |
| FileListBox | FileDialog | File selection |

**Event Wiring:**
Controls automatically wire up to event handlers in your VisualGasic code:

```vb
' Button click handler - automatically connected
Private Sub Command1_Click()
    MsgBox "Button clicked!"
End Sub

' TextBox change handler
Private Sub Text1_Change()
    lblPreview.Text = Text1.Text
End Sub

' Form load event
Private Sub Form_Load()
    ' Initialize form
    Me.Caption = "My Application"
End Sub
```

### Property Inspector

The **Property Inspector** (right dock) shows VB6-style properties for selected controls:

- **Name** - Control identifier for code
- **Text/Caption** - Display text
- **Left, Top, Width, Height** - Position and size
- **Visible** - Show/hide control
- **Enabled** - Enable/disable control
- **TabStop** - Include in tab order
- **TabIndex** - Tab order position
- **Font** - Text font properties
- **BackColor/ForeColor** - Colors

### Game UI Mode
The Form Designer supports a **Game UI Mode** that generates `CanvasLayer` overlays for in-game HUD elements instead of standalone `Window` nodes.

**Enabling Game UI Mode:**
- Set the form's `GameUIMode` property to `True` in the Property Inspector
- Or call `set_game_ui_mode(true)` programmatically

**Visual differences in Game UI Mode:**
- Dark canvas background (game-like) instead of Windows-style form
- Blue crosshair center guides for layout alignment
- 80% safe area rectangle for mobile-friendly design
- "GAME UI" badge in top-left corner

**Export behavior:**
- Generates `CanvasLayer` root node (layer 10) instead of `Window`
- Child controls are parented to a full-rect `Control` node with `anchors_preset = 15` (full rect)
- Compatible with running game scenes — the overlay sits on top of 2D/3D content

**Game UI Toolbox Controls:**

| Control | Description |
|---------|-------------|
| Pointer | Mouse cursor / selection tool |
| HealthBar | Player health display |
| ScoreLabel | Score/points display |
| DialogBox | NPC dialogue / story text |
| MiniMap | Mini-map overlay |
| Inventory | Item grid / inventory panel |
| ActionButton | Action/ability button |
| AmmoCounter | Ammunition display |
| BossBar | Boss health bar |
| Crosshair | Aiming crosshair |
| Tooltip | Hover tooltip |

### Menu Editor

The **Menu Editor** provides visual menu bar design:

1. Open via **Project > Tools > Visual Gasic Menu Editor**
2. Add top-level menus (File, Edit, View, Help, etc.)
3. Add menu items with:
   - Caption (display text)
   - Name (for code reference)
   - Shortcut key
   - Checked state
   - Enabled state
4. Create submenus by indenting items
5. Menus automatically wire to click handlers:

```vb
Private Sub mnuFileOpen_Click()
    ' Handle File > Open
    OpenFile()
End Sub

Private Sub mnuFileSave_Click()
    ' Handle File > Save
    SaveFile()
End Sub

Private Sub mnuEditCopy_Click()
    ' Handle Edit > Copy
    CopyToClipboard()
End Sub
```

### Immediate Window

The **Immediate Window** (bottom panel, "Immediate" tab) is a powerful debugging and testing tool that lets you interact with your running program in real-time.

**Features:**
- **Execute VisualGasic statements** - Run code directly
- **Evaluate expressions** - Print variable values
- **Call functions** - Test subroutines and functions
- **Inspect objects** - View object properties
- **Remote debugging** - Connect to running games

**Basic Usage:**
```vb
' Print a variable's value
? playerHealth
100

' Evaluate an expression
? 2 + 2 * 10
22

' Call a function
? Left("Hello World", 5)
Hello

' Execute a statement
Print "Debug message"
Debug message
```

**Commands:**
- `?` or `Print` - Evaluate and display expression
- `help` - Show available commands
- `clear` - Clear output
- `list` - List variables in scope
- `connect <instance>` - Connect to running instance for remote debugging

**Remote Debugging:**
When your game is running, the Immediate Window can connect to it:
1. Start your game (F5 or Play button)
2. Use the instance dropdown to select running instances
3. Execute commands that affect the live game:

```vb
' While game is running:
? player.position
(150, 200)

' Modify values in real-time
player.health = 100

' Call game methods
player.TakeDamage(10)
```

### Code Navigator

The **Code Navigator** (in Toolbox) provides quick navigation through your code:

- **Procedure Dropdown** - Jump to any Sub or Function
- **Object Dropdown** - Select control or module
- **Region Navigation** - Jump to code regions

### Object Browser

The **Object Browser** (Project > Tools > Visual Gasic Object Browser) lets you explore:

- All available classes and types
- Object members (properties, methods, events)
- Built-in VisualGasic functions
- Godot API wrapped for VisualGasic

### Tab Order Editor

The **Tab Order Editor** (Project > Tools > Visual Gasic Tab Order) provides:

- Visual tab order preview
- Drag-and-drop reordering
- Auto-numbering
- Focus testing

### Project Properties

The **Project Properties** dialog (Project > Tools > Visual Gasic Project Properties):

- **Startup Form** - Which form loads first
- **Project Name** - Application name
- **Version Info** - Version numbers
- **Icon** - Application icon
- **Compile Options** - Build settings

---

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
- `End Type` - End type definition
- `Nothing` - Null object reference
- `Null` - Null value (database compatibility)
- `Empty` - Empty/uninitialized value
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
- `End If` - End If block
- `Select` - Start select case block
- `Select Case` - Alternative syntax for Select
- `Select Match` - Pattern matching select
- `Case` - Case option in select block
- `Case Else` - Default case option
- `End Select` - End Select block
- `For` - Start counting loop
- `For Each` - Iterate over collection
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
- `Mod` - Modulo operator
- `Like` - Pattern matching operator
- `AndAlso` - Short-circuit AND
- `OrElse` - Short-circuit OR

#### **Error Handling**
- `On` - Error handling setup
- `Error` - Error keyword
- `Resume` - Resume after error
- `Resume Next` - Resume at next statement after error
- `GoSub` - Jump to label and return
- `Return` - Return from GoSub
- `GoTo` - Jump to label
- `Try` - Start try block
- `Catch` - Catch exceptions
- `Finally` - Finally block
- `End Try` - End try block
- `Throw` - Throw an exception

#### **File Operations**
- `Open` - Open file
- `Close` - Close file
- `Input` - Input mode
- `Output` - Output mode
- `Append` - Append mode
- `Line` - Line input/output

#### **Object-Oriented Features**
- `Class` - Declare a class
- `End Class` - End class declaration
- `Inherits` - Class inheritance
- `Extends` - Extend a class
- `Interface` - Declare an interface
- `End Interface` - End interface declaration
- `Implements` - Implement an interface
- `Property` - Declare a property
- `Let` - Property setter (legacy)
- `Get` - Property getter
- `Event` - Declare an event
- `RaiseEvent` - Raise an event
- `WithEvents` - Declare variable with event handling
- `Handles` - Event handler binding
- `with` - With statement (object context)
- `End With` - End With block
- `MyBase` - Reference to base class
- `MyClass` - Reference to current class type
- `Enum` - Declare an enumeration
- `End Enum` - End enumeration declaration

#### **Collections & Iteration**
- `Dictionary` - Dictionary type
- `each` - For each iteration
- `in` - In operator (for iteration)

#### **Data Processing**
- `Data` - Data statement (supports empty slots with consecutive commas)
- `Read` - Read data (supports typed Read: `Read x As Integer`)
- `Restore` - Restore data pointer (case-insensitive label matching)
- `ClearData` - Clear data tape and reset pointer
- `DataFromString` - Parse a string as data values and append to tape
- `DataFile` - Include data from external file at parse time
- `LoadData` - Load data from external file at runtime
- `DataCount()` - Total items or items in named section
- `DataRemain()` - Items remaining from current pointer
- `DataSectionCount()` - Items in current labeled section
- `DataSectionRemain()` - Remaining items in current section
- `DataPointer()` - Current read position
- `PeekData(index)` - Random-access read by absolute index
- `PeekData("label", offset)` - Random-access read relative to a labeled section
- `SetDataPointer(n)` - Set the read pointer to an arbitrary position
- `DataLabels()` - Array of all label names in the data tape
- `DataSectionName()` - Label name of the current section
- `DataToArray()` / `DataToArray("label")` / `DataToArray(n)` - Bulk-read data into an Array

#### **Advanced Features**
- `Include` - Include external file
- `Option` - Compiler option
- `Explicit` - Explicit variable declaration
- `DoEvents` - Process system events
- `IIf` - Inline If function
- `Lambda` - Lambda expression keyword
- `Of` - Type parameter for generics (e.g., `Task(Of String)`)

#### **Async/Parallel Programming (Multitasking)**
- `Async` - Mark procedure as asynchronous
- `Await` - Await asynchronous operation
- `Task` - Task type for async operations
- `Parallel` - Parallel execution modifier for loops and sections

#### **Pattern Matching & Type Checking**
- `Match` - Pattern matching keyword (used with `Select Match`)
- `When` - Guard clause in pattern matching
- `Where` - Where clause for filtering
- `Is` - Type comparison operator
- `IsNot` - Negative type comparison operator
- `TypeOf` - Get type of object for comparison
- `HasValue` - Check if nullable/optional has a value
- `Value` - Access value from nullable/optional type

#### **Reactive Programming (Whenever System)**
- `Whenever` - Start reactive section declaration
- `End Whenever` - End reactive section block
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

#### **Modern Features**
- `Using` - Resource management block
- `End Using` - End Using block
- `Yield` - Yield value in iterator
- `Iterator` - Mark function as iterator

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

#### **Graphics & Drawing — Primitives**
- `DrawText` - Draw text at position
- `DrawString` - Draw text using a font object
- `DrawLine` - Draw line between two points
- `DrawRect` - Draw rectangle (filled or outline)
- `DrawCircle` - Draw circle
- `DrawPixel` / `PSet` - Draw a single pixel
- `DrawTexture` - Draw a texture at a position
- `DrawTextureRect` - Draw a texture stretched into a rectangle
- `DrawArc` - Draw an arc (partial circle)
- `DrawPolygon` - Draw a filled polygon
- `DrawPolyline` - Draw a multi-segment line
- `SetDrawTransform` - Set translation/rotation/scale for drawing
- `ResetDrawTransform` - Reset draw transform to identity
- `QueueRedraw` - Request a redraw on next frame
- `CLS` - Clear the screen/canvas
- `LoadPicture` - Load image as texture

#### **Graphics & Drawing — Image Manipulation**
- `CreateImage` - Create a new Image object (RGBA8)
- `CreateTexture` - Create an ImageTexture from Image or dimensions
- `ImageToTexture` - Convert Image to ImageTexture
- `SetImagePixel` - Set a pixel on an Image
- `GetImagePixel` - Get a pixel color from an Image
- `FillImage` - Fill entire Image with a color
- `FillImageRect` - Fill a rectangular region of an Image
- `BlitImage` - Copy pixels between Images
- `UpdateTexture` - Push Image data to ImageTexture
- `ImageWidth` / `ImageHeight` - Get Image dimensions
- `TextureWidth` / `TextureHeight` - Get Texture dimensions
- `LoadImage` - Load image file as Image object
- `SaveImage` - Save Image as PNG file
- `GetTextureImage` - Extract Image from ImageTexture

#### **Graphics & Drawing — Native Image Drawing**

These builtins draw directly on an `Image` object in **native C++** for maximum speed.
Call `UpdateTexture tex, img` afterwards to push changes to screen.

- `DrawImageLine image, x1, y1, x2, y2, color[, width]` — Draw a Bresenham line (1px default; pass width for thick brush)
- `Line image, x1, y1, x2, y2, color[, width]` — VB6-style alias for `DrawImageLine`
- `DrawImageRect image, x1, y1, x2, y2, color` — Draw a 1px outline rectangle (corners auto-normalized)
- `DrawImageEllipse image, cx, cy, rx, ry, color` — Draw a 1px ellipse outline (midpoint algorithm; use rx=ry for circle)
- `DrawImageCircle image, cx, cy, radius, color` — Draw a **filled** circle (scanline; for outline use DrawImageEllipse)
- `FloodFillImage image, x, y, color` — Flood-fill connected pixels from seed point (4-connected, bounded by w×h)

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
Abs, AndAlso, Append, As, Beep, BlitImage, ByRef, ByVal, Call, Case,
Catch, ChDir, ChangeScene, CLS, Close, Clamp, Const, Continue,
CreateActor2D, CreateImage, CreateTexture, CurDir, Data, Dictionary,
Dim, Do, DoEvents, DrawArc, DrawCircle, DrawImageCircle, DrawImageEllipse,
DrawImageLine, DrawImageRect, DrawLine, DrawPixel, DrawPolygon,
DrawPolyline, DrawRect, DrawString, DrawText, DrawTexture, DrawTextureRect,
each, Elif, Else, ElseIf, End, Environ, Error, Event, Exit, Explicit,
Extends, False, FileCopy, FillImage, FillImageRect, Finally, FloodFillImage,
For, Format,
Function, GetCollider, GetImagePixel, GetSetting, GetTextureImage, Global,
Goto, HasCollided, If, IIf, ImageHeight, ImageToTexture, ImageWidth, in,
Include, Inherits, Input, Int, IsActionPressed, IsKeyPressed, Lerp, Line,
LoadForm, LoadImage, LoadPicture, Loop, Me, MkDir, MonthName, MsgBox, New,
Next, Not, Nothing, On, Open, Optional, Option, Or, OrElse, Output,
ParamArray, Pass, PlaySound, PlayTone, Preserve, Print, Private, PSet,
Public, QBColor, QueueRedraw, RaiseEvent, Randomize, RandRange, Read,
Redim, ResetDrawTransform, Resume, Return, RmDir, Rnd, Round,
SaveDatabase, SaveImage, SaveSetting, Select, Set, SetDrawTransform,
SetImagePixel, SetScreenSize, SetTitle, Shell, Sleep, Static, Step, Stop,
Sub, TextureHeight, TextureWidth, Then, To, True, Try, Type, TypeName,
Until, UpdateTexture, Weekday, WeekdayName, Wend, While, with, Xor
```

**Total: 115+ Keywords Available**

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
| `LongLong` | 64-bit signed integer (alias for Long) | `9876543210` |
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
Dim big As LongLong = CLngLng(3.7)  ' Rounds to 4

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

#### Bit-Shift Operators
```vb
result = 1 << 4    ' Left shift  (16)
result = 256 >> 3   ' Right shift (32)
result = flags << n  ' Shift by variable amount
```

#### Compound Assignment Operators
```vb
x += 5     ' x = x + 5
x -= 3     ' x = x - 3
x *= 2     ' x = x * 2
x /= 4     ' x = x / 4
s &= " ok" ' s = s & " ok"   (string concatenation)
x \= 3    ' x = x \ 3       (integer division)
x ^= 2     ' x = x ^ 2       (exponentiation)
x <<= 4    ' x = x << 4      (left shift)
x >>= 2    ' x = x >> 2      (right shift)
```

#### Keyword Compound Assignment Operators
```vb
flags And= mask      ' flags = flags And mask   (bitwise AND)
flags Or= newFlag    ' flags = flags Or newFlag (bitwise OR)
flags Xor= toggle    ' flags = flags Xor toggle (bitwise XOR)
x Mod= divisor       ' x = x Mod divisor       (modulo)
```

> **Note:** `And`, `Or`, and `Xor` perform **bitwise** operations when both operands are numeric (VB6 semantics). They fall back to **logical** boolean operations when either operand is non-numeric.

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

#### On Error Resume Next

`On Error Resume Next` catches runtime errors inline without jumping to a handler. This includes **method calls on Null objects** — a common scenario with optional object references:

```vb
Sub SafeProcess()
    On Error Resume Next
    
    Dim obj As Variant = Nothing
    
    ' This would normally crash — but On Error Resume Next catches it
    Dim result As Variant = obj.SomeMethod()
    
    ' Check if an error occurred
    If Err.Number <> 0 Then
        Print "Error caught: " & Err.Description
        Err.Clear
    End If
    
    ' Execution continues safely
    Print "Continuing after error"
End Sub
```

The `Err` object provides:
- `Err.Number` — Error code (0 = no error)
- `Err.Description` — Human-readable error message
- `Err.Source` — Source of the error
- `Err.Clear` — Reset the error state
- `Err.Raise number, source, description` — Raise a custom error

```vb
' Raise a custom error
On Error Resume Next
Err.Raise 1001, "MyModule", "Custom validation failed"
If Err.Number = 1001 Then
    Print "Source: " & Err.Source       ' "MyModule"
    Print "Error: " & Err.Description   ' "Custom validation failed"
    Err.Clear
End If
On Error GoTo 0
```

#### GoSub / Return

Classic VB6 `GoSub` jumps to a label within the current Sub/Function, then `Return` jumps back to the statement after the `GoSub`. This is useful for reusable code blocks without creating separate subroutines:

```vb
Sub ProcessData()
    Dim x As Integer
    x = 10
    GoSub DoubleIt
    Print x            ' 20
    x = 50
    GoSub DoubleIt
    Print x            ' 100
    Exit Sub

DoubleIt:
    x = x * 2
    Return
End Sub
```

> **Note:** `Return` checks the GoSub return stack first. If no GoSub is pending, bare `Return` acts as `Exit Sub`.

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

### Scope and Lifetime

```vb
' Module-level (Global) scope
Dim globalCounter As Integer = 0  ' Accessible throughout the module

Sub IncrementCounter()
    globalCounter = globalCounter + 1  ' Can access module-level variable
End Sub

' Procedure-level (Local) scope
Sub ProcessData()
    Dim localVar As Integer = 10  ' Only accessible within this Sub
    
    ' Block-level scope
    For i = 1 To 5
        Dim blockVar As Integer = i * 2  ' Only accessible within For loop
    Next
    
    ' blockVar is not accessible here
End Sub

' Static variables (persist between calls)
Sub CountCalls()
    Static callCount As Integer = 0  ' Initialized once, value persists
    callCount = callCount + 1
    Print "This function has been called " & callCount & " times"
End Sub
```

**Scope Rules:**
- `Dim` inside a procedure → Local scope
- `Dim` at module level → Module scope
- `Public` → Accessible from other modules
- `Private` → Only accessible within the module
- `Static` → Local variable that retains value between calls

---

## Object-Oriented Features

### Method Overloading
Define multiple `Sub` or `Function` with the same name but different parameter counts.
The runtime selects the best match based on the number of arguments passed (arity-based dispatch).

```vb
' Module-level overloads
Sub Spawn(x As Single, y As Single)
    ' 2-arg version: uses default speed/angle
    Spawn x, y, 100, 0
End Sub

Sub Spawn(x As Single, y As Single, speed As Single, angle As Single)
    ' 4-arg version: full control
    CreateBullet x, y, speed, angle
End Sub

' Class method overloads
Class Calculator
    Function Add(a As Integer) As Integer
        Return a
    End Function
    Function Add(a As Integer, b As Integer) As Integer
        Return a + b
    End Function
    Function Add(a As Integer, b As Integer, c As Integer) As Integer
        Return a + b + c
    End Function
End Class

Dim calc = New Calculator
Print calc.Add(5)       ' → 5
Print calc.Add(3, 4)    ' → 7
Print calc.Add(1, 2, 3) ' → 6
```

**Rules:**
- Overloads are resolved by argument count only (no type-based overloading yet)
- If no exact arity match exists, Optional parameters are considered
- Falls back to first-match if no arity match is found (backward compatibility)
- Works in module-level subs/functions, class methods, and bytecode-compiled code

### Parameterized Constructors
Pass arguments to `Class_Initialize` when creating new objects.

```vb
Class Bullet
    Public speed As Double
    Public angle As Double
    Public damage As Integer

    Sub Class_Initialize(s As Double, a As Double, d As Integer)
        speed = s
        angle = a
        damage = d
    End Sub
End Class

' Both syntaxes work:
Dim b1 = New Bullet(300, 45, 10)
Dim b2 As New Bullet(200, 90, 25)
```

**Notes:**
- `New ClassName` with no parentheses still calls zero-arg `Class_Initialize`
- Arguments are passed directly to `Class_Initialize` parameters
- Works with `Dim x = New Class(args)` and `Dim x As New Class(args)` forms

### Generics Phase 1 — Collection(Of T)
Type-safe collections with runtime type validation on `.Add()`.

```vb
' Typed collection — only accepts integers
Dim scores As New Collection(Of Integer)
scores.Add 100     ' OK
scores.Add 200     ' OK
' scores.Add "hi" ' ERROR: Type mismatch

' Typed collection of strings
Dim names As New Collection(Of String)
names.Add "Alice"
names.Add "Bob"

' Auto-instantiation (no New required)
Dim items As Collection(Of Double)
items.Add 3.14    ' Collection created automatically

' Untyped collection still works
Dim anything As New Collection
anything.Add 42
anything.Add "mixed"
anything.Add 3.14
```

**Supported type parameters:** `Integer`, `Long`, `LongLong`, `Double`, `Single`, `Float`,
`String`, `Boolean`, `Variant` (any type), and any class name.

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

> **Implements Runtime Verification:** When a module declares `Implements IFoo`, VisualGasic checks at load time that at least one `IFoo_*` method exists in the module. If none is found, a warning is printed to the console so you can catch unimplemented interfaces early.

### Events (WithEvents / RaiseEvent)
VisualGasic supports VB6-style custom events with `Event`, `RaiseEvent`, and `WithEvents`.

#### Declaring and Raising Events

```vb
' Declare an event in a class module
Event ProgressChanged(percent As Integer)
Event Completed()

Sub DoWork()
    Dim i As Integer
    For i = 1 To 100
        ' ... work ...
        RaiseEvent ProgressChanged(i)
    Next
    RaiseEvent Completed()
End Sub
```

`RaiseEvent` compiles to a dedicated bytecode opcode (`OP_RAISE_EVENT`) that emits a Godot signal with the same name, supporting up to 5 arguments.

#### WithEvents — Automatic Event Wiring

Declare a variable with `WithEvents` to automatically connect its events to handler subs in the current module. Handlers are named `VariableName_EventName`:

```vb
Dim WithEvents worker As Worker

Sub StartJob()
    Set worker = New Worker
    worker.DoWork   ' Events fire automatically
End Sub

' Handler — auto-connected when "worker" is assigned
Sub worker_ProgressChanged(percent As Integer)
    ProgressBar1.Value = percent
End Sub

Sub worker_Completed()
    MsgBox "Job finished!"
End Sub
```

When you `Set` a WithEvents variable, VisualGasic scans the module for subs matching the `varname_SignalName` pattern and connects them via Godot's signal system. Reassigning the variable disconnects old handlers automatically.

#### Event Wiring at a Glance

| Feature | Syntax | Notes |
|---------|--------|-------|
| Declare event | `Event Name(params)` | Compiles to Godot signal |
| Fire event | `RaiseEvent Name(args)` | Emits the signal (up to 5 args) |
| Auto-connect | `Dim WithEvents x As T` | Handlers: `x_EventName(...)` |
| Manual connect | `Connect obj, "signal", "handler"` | Standard Godot approach |

### Properties and Methods

```vb
' Properties with Get/Set
Class Player
    Private _health As Integer
    Private _name As String
    
    ' Read-write property
    Property Health As Integer
        Get
            Return _health
        End Get
        Set(value As Integer)
            _health = Clamp(value, 0, 100)  ' Validate on set
        End Set
    End Property
    
    ' Read-only property
    ReadOnly Property Name As String
        Get
            Return _name
        End Get
    End Property
    
    ' Auto-implemented property (simple)
    Property Score As Integer  ' Automatically creates backing field
    
    ' Methods
    Sub TakeDamage(amount As Integer)
        Health = Health - amount
        If Health <= 0 Then Die()
    End Sub
    
    Function IsAlive() As Boolean
        Return Health > 0
    End Function
End Class

' Using properties
Dim player As New Player()
player.Health = 100       ' Calls Set
Print player.Health       ' Calls Get
player.Score = 500        ' Auto property
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
result = RandRange(1, 100)   ' Random between 1 and 100

' Interpolation and clamping
result = Lerp(0, 100, 0.5)   ' Linear interpolation: 50
result = Clamp(150, 0, 100)  ' Clamp to range: 100
```

### Vector Math Functions

```vb
' Vector construction
Dim v2 = Vector2(10, 20)      ' Create 2D vector
Dim v3 = Vector3(1, 2, 3)     ' Create 3D vector
Dim v2 = Vec2(10, 20)         ' Shorthand for Vector2
Dim v3 = Vec3(1, 2, 3)        ' Shorthand for Vector3

' Vector arithmetic
Dim sum = VAdd(v1, v2)        ' Add vectors
Dim diff = VSub(v1, v2)       ' Subtract vectors
Dim scaled = VMul(v1, 2.5)    ' Multiply by scalar

' Vector operations
Dim length = VLen(v1)         ' Get vector length/magnitude
Dim norm = VNormalize(v1)     ' Get normalized (unit) vector
Dim dist = VDistance(v1, v2)  ' Distance between two points
Dim dot = VDot(v1, v2)        ' Dot product
Dim cross = VCross(v1, v2)    ' Cross product (3D only)
Dim interp = VLerp(v1, v2, 0.5) ' Linear interpolation between vectors
```

### Color Functions

```vb
' Color construction
Dim c1 = Color(1.0, 0.5, 0.0)       ' RGB (0-1 range)
Dim c2 = Color(1.0, 0.5, 0.0, 0.8)  ' RGBA with alpha
Dim c3 = Color8(255, 128, 0)        ' RGB (0-255 range)
Dim c4 = Color8(255, 128, 0, 200)   ' RGBA (0-255 range)

' Geometry
Dim rect = Rect2(0, 0, 100, 50)     ' Create rectangle (x, y, width, height)
```

### Input Functions

```vb
' Keyboard input
Dim keyDown = IsKeyDown("A")         ' Check if key is pressed
Dim keyDown = GetKey(KEY_SPACE)      ' Check key by constant

' Mouse input
Dim leftClick = IsMouseButtonDown(1) ' Check mouse button (1=left, 2=right)
```

### String Functions (Extended)

```vb
' Extended string operations
Dim starts = StartsWith("Hello", "He")  ' True
Dim ends = EndsWith("Hello", "lo")      ' True
Dim padded = PadLeft("42", 5, "0")      ' "00042"
Dim padded = PadRight("Hi", 5)          ' "Hi   "
Dim reversed = StrReverse("Hello")      ' "olleH"
```

### Date/Time Functions

```vb
' Day of week (1=Sunday, 7=Saturday by default)
Dim day = Weekday("7/4/2025")           ' 6 (Friday)
Dim day = Weekday("7/4/2025", 2)        ' 5 (Monday-based)

' Names from numbers
Dim name = WeekdayName(6)               ' "Friday"
Dim abbr = WeekdayName(6, True)         ' "Fri"
Dim month = MonthName(1)                ' "January"
Dim mabbr = MonthName(1, True)          ' "Jan"
```

### System/Environment Functions

```vb
' VB6 16-color palette
Dim black = QBColor(0)                  ' &H000000 (Black)
Dim blue  = QBColor(1)                  ' &HAA0000 (Blue)
Dim white = QBColor(15)                 ' &HFFFFFF (White)

' OS environment variables
Dim path = Environ("PATH")
Dim home = Environ("HOME")

' System beep
Beep                                    ' Prints "[BEEP]" to console
```

### File System Functions

```vb
' Directory management
MkDir "res://saves"                     ' Create directory
ChDir "res://saves"                     ' Change working directory
Print CurDir()                          ' Get current directory
RmDir "res://temp"                      ' Remove directory

' File copying
FileCopy "source.txt", "dest.txt"       ' Copy a file
```

### Debugging Statements

```vb
' Break into debugger — equivalent to VB6 Stop
Stop

' Use with conditional logic for targeted debugging
If score < 0 Then Stop  ' Break when unexpected negative
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

### Extended Array Functions

```vb
' Array manipulation
Dim arr = [1, 2, 3, 4, 5]
arr = Push(arr, 6)           ' Add element: [1,2,3,4,5,6]
Dim last = Pop(arr)          ' Remove and return last: 6
Dim sub = Slice(arr, 1, 3)   ' Get subarray: [2,3]

' Array search
Dim idx = IndexOf(arr, 3)    ' Find index: 2
Dim has = Contains(arr, 2)   ' Check if exists: True

' Array transform
Dim reversed = Reverse(arr)  ' Reverse order
Dim sorted = Sort(arr)       ' Sort ascending
Dim unique = Unique([1,2,2,3]) ' Remove duplicates: [1,2,3]
Dim flat = Flatten([[1,2],[3]]) ' Flatten: [1,2,3]

' Array generation
Dim repeated = Repeat("X", 3)    ' ["X","X","X"]
Dim range = Range(0, 10, 2)      ' [0,2,4,6,8]
Dim zipped = Zip([1,2], ["a","b"]) ' [[1,"a"],[2,"b"]]
```

### Dictionary Functions

```vb
Dim person = {"name": "Alice", "age": 30}

' Dictionary operations
Dim k = Keys(person)              ' ["name", "age"]
Dim v = Values(person)            ' ["Alice", 30]
Dim has = HasKey(person, "name")  ' True

' Merging dictionaries
Dim extra = {"city": "NYC"}
Dim merged = Merge(person, extra) ' {"name":"Alice", "age":30, "city":"NYC"}

' Removing keys
Dim removed = Remove(person, "age") ' {"name": "Alice"}
```

### Type Checking Functions

```vb
IsArray([1,2,3])             ' True
IsDict({"key": "val"})       ' True
IsString("hello")            ' True
IsNumber(42)                 ' True
IsNull(Nothing)              ' True
TypeName([1,2,3])            ' "Array"
TypeName(42)                 ' "Int"
```

### JSON Functions

```vb
' Parse JSON string to object
Dim json = '{"name":"Bob","age":25}'
Dim jsonData = JsonParse(json)
Print jsonData["name"]       ' "Bob"

' Convert object to JSON string
Dim person = {"name": "Alice", "age": 30}
Dim str = JsonStringify(person)
Print str                    ' {"name":"Alice","age":30}

' Pretty-print with indent
Dim pretty = JsonStringify(person, True)
```

### Modern File System Functions

```vb
' Modern file operations (simpler than Open/Close)
If FileExists("data.txt") Then
    Dim content = ReadAllText("data.txt")   ' Read entire file
    Print content
End If

If DirExists("./saves") Then
    Print "Saves folder exists"
End If

' Write file (overwrites)
WriteAllText("output.txt", "Hello World!")

' Read as array of lines
Dim lines = ReadLines("data.txt")
For Each line In lines
    Print line
Next
```

### Clipboard Functions

```vb
' Clipboard operations
Dim text = Clipboard.GetText()    ' Get text from clipboard
Clipboard.SetText("Hello!")       ' Copy text to clipboard
Clipboard.Clear()                 ' Clear clipboard contents
```

### File I/O Functions (Classic VB6 Style)
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

#### File I/O Statements
`Print #`, `Write #`, `Input #`, and `Line Input #` statements are now compiled to dedicated bytecode opcodes for full VB6-compatible sequential file I/O:

```vb
' Write data to a file
Dim f As Integer = FreeFile()
Open "output.csv" For Output As f
Print #f, "Name,Score,Level"       ' Print line as-is
Write #f, "Alice", 100, 5           ' Write with quotes and commas
Write #f, "Bob", 85, 3
Close f

' Read data from a file
Dim name As String, score As Integer, level As Integer
Open "output.csv" For Input As f
Dim header As String
Line Input #f, header              ' Read entire line
Input #f, name, score, level       ' Read comma-separated values
Print name & ": " & CStr(score)    ' "Alice: 100"
Close f
```

### Classic DATA Statements
**Classic DATA statements are back — and better than ever!**

Remember storing game data, level layouts, and lookup tables right in your code? VisualGasic brings back the beloved `Data`, `Read`, and `Restore` statements from classic BASIC, enhanced with modern features like external data files and labeled data sections.

#### Why DATA Statements?

- **No External Files Needed** — Embed data directly in your code
- **Instant Access** — No file I/O overhead for small datasets
- **Nearly as fast as arrays** — `Data`/`Read` is only ~12% slower than array indexing, and 2× faster than filling an array then reading it (see [Performance](#performance-dataread-vs-arrays) below)
- **Self-Documenting** — Data lives alongside the code that uses it
- **Classic Compatibility** — Works exactly like VB6/QBasic DATA
- **Modern Enhancements** — Load from external files, use labels for organization

#### Basic DATA and READ

```vb
' Store data inline
Data 10, 20, 30, "Hello", 3.14

' Read data into variables
Dim a, b, c As Integer
Dim msg As String
Dim pi As Double

Read a, b, c       ' a=10, b=20, c=30
Read msg           ' msg="Hello"
Read pi            ' pi=3.14
```

#### Game Data Example

```vb
' Perfect for game level data, enemy stats, item definitions
Sub LoadEnemyData()
    Dim name As String
    Dim hp, attack, defense As Integer
    
    ' Read enemy definitions
    For i = 1 To 3
        Read name, hp, attack, defense
        CreateEnemy(name, hp, attack, defense)
    Next
End Sub

' Enemy data embedded in code
Data "Goblin", 30, 10, 5
Data "Orc", 50, 15, 10
Data "Dragon", 200, 40, 25
```

#### Labeled Data Sections

Use labels to organize data and jump to specific sections:

```vb
' Jump to specific data section
Restore Level1Data
Read mapWidth, mapHeight

Restore Level2Data
Read mapWidth, mapHeight

' Data sections with labels
Level1Data:
Data 20, 15, "Forest"

Level2Data:
Data 30, 20, "Castle"

Level3Data:
Data 40, 25, "Dungeon"
```

#### RESTORE Statement

Reset the data pointer to read data again:

```vb
Data 1, 2, 3

Read a  ' a = 1
Read b  ' b = 2

Restore    ' Reset to beginning

Read c  ' c = 1 (starts over!)

' Restore to labeled section
Restore EnemyData
```

#### DataFile — Load from External Files

Load large datasets from external files at parse time:

```vb
' Load data from external file
DataFile "res://data/items.dat"

' items.dat contains:
' "Sword", 100, 10
' "Shield", 80, 0, 15
' "Potion", 25, 0, 0, 50

Dim itemName As String
Dim price, attack, defense, heal As Integer

Read itemName, price, attack              ' "Sword", 100, 10
Read itemName, price, attack, defense     ' "Shield", 80, 0, 15
```

#### LoadData — Runtime File Loading

Load data files dynamically at runtime:

```vb
' Load data file based on runtime conditions
Dim difficulty As String = GetDifficulty()
LoadData "res://data/enemies_" & difficulty & ".dat"

' Now Read from the loaded data
Read enemyCount
For i = 1 To enemyCount
    Read name, hp, damage
    SpawnEnemy(name, hp, damage)
Next
```

#### Typed Read

Coerce values to a specific type at read time with `Read variable As Type`:

```vb
Data 42, 3.14, "100", "True"

Dim s As String
Dim d As Double
Dim i As Integer
Dim b As Boolean

Read s As String    ' s = "42" (number coerced to string)
Read d As Double    ' d = 3.14
Read i As Integer   ' i = 100  (string coerced to integer)
Read b As Boolean   ' b = True (string coerced to boolean)
```

Supported type names: `Integer`, `Int`, `Long`, `Int32`, `Int64`, `Single`, `Float`, `Double`, `Float32`, `Float64`, `String`, `Boolean`, `Bool`.

**Practical example — parsing mixed configuration data:**

```vb
' Config data stored as strings from an INI-style source
Data "1280", "720", "60", "True", "My Game"

Dim width As Integer
Dim height As Integer
Dim fps As Integer
Dim fullscreen As Boolean
Dim title As String

' Typed Read ensures correct types even when data is all strings
Read width As Integer         ' 1280
Read height As Integer        ' 720
Read fps As Integer           ' 60
Read fullscreen As Boolean    ' True
Read title As String          ' "My Game"

OS.WindowSize = Vector2(width, height)
```

**Typed Read with LoadData — safely loading external CSV files:**

```vb
' External file scores.dat contains:
'   "Alice", "950", "3"
'   "Bob",   "820", "5"
LoadData "res://data/scores.dat"

Dim name As String
Dim score As Integer
Dim deaths As Integer

For i = 1 To 2
    Read name As String
    Read score As Integer      ' Coerced from string "950" → 950
    Read deaths As Integer     ' Coerced from string "3" → 3
    Print name & ": " & CStr(score) & " pts, " & CStr(deaths) & " deaths"
Next
```

#### Empty Data Slots

Use consecutive commas to insert `Nothing` (null) values:

```vb
Data 1,,3, "hello",, 99

Dim a, b, c, d, e, f
Read a, b, c, d, e, f
' a = 1, b = Nothing, c = 3, d = "hello", e = Nothing, f = 99
```

This is useful for sparse data tables where some positions are intentionally empty.

**Practical example — RPG item table with optional properties:**

```vb
' Item format: Name, Price, Attack, Defense, HealHP, ManaRestore
' Use empty slots when an item doesn't have a property
ItemTable:
Data "Sword",   100, 15,,, 
Data "Shield",  80,,  12,,
Data "Potion",  25,,,  50,
Data "Elixir",  60,,,  30, 20
Data "Amulet",  200,,  5,,

Restore ItemTable
For i = 1 To 5
    Dim itemName As String
    Dim price, atk, def, heal, mana
    Read itemName, price, atk, def, heal, mana
    
    Print itemName & " ($" & CStr(price) & ")"
    ' Check for Nothing before using optional stats
    If Not IsNothing(atk) Then Print "  ATK: " & CStr(atk)
    If Not IsNothing(def) Then Print "  DEF: " & CStr(def)
    If Not IsNothing(heal) Then Print "  Heal: +" & CStr(heal) & " HP"
    If Not IsNothing(mana) Then Print "  Mana: +" & CStr(mana)
Next
```

**Sparse grid / level flags:**

```vb
' Flags for 4 checkpoints: hasKey, hasShop, hasBoss, isSafe
Data True,,, True       ' Checkpoint 1: has key, is safe
Data, True,,            ' Checkpoint 2: has shop only
Data,, True,            ' Checkpoint 3: has boss only
Data True, True,, True  ' Checkpoint 4: key + shop + safe
```

#### ClearData Statement

Clear the entire data tape and reset the read pointer:

```vb
Data 10, 20, 30
Read a, b    ' a=10, b=20

ClearData    ' Tape emptied, pointer reset to 0

' DataCount() now returns 0
' You can LoadData to populate a fresh tape
LoadData "res://data/new_data.dat"
```

**Practical example — swapping level data on the fly:**

```vb
Sub LoadLevel(levelNum As Integer)
    ' Wipe previous level data
    ClearData
    
    ' Load the new level's data file
    LoadData "res://levels/level" & CStr(levelNum) & ".dat"
    
    ' Read level header
    Dim mapW As Integer, mapH As Integer, tileset As String
    Read mapW, mapH, tileset
    
    ' Read tile grid
    Dim tiles(mapH, mapW) As Integer
    For y = 1 To mapH
        For x = 1 To mapW
            Read tiles(y, x)
        Next
    Next
    
    Print "Loaded level " & CStr(levelNum) & " (" & CStr(mapW) & "x" & CStr(mapH) & ")"
End Sub
```

**Resetting between test runs:**

```vb
Sub RunTest(testData As String)
    ClearData
    DataFromString testData
    
    Dim result As Integer
    Dim expected As Integer
    Read result, expected
    
    If result = expected Then
        Print "PASS"
    Else
        Print "FAIL: got " & CStr(result) & " expected " & CStr(expected)
    End If
End Sub

RunTest "42, 42"    ' PASS
RunTest "10, 20"    ' FAIL: got 10 expected 20
```

#### DataFromString Statement

Parse a string expression as comma-separated data values and append them to the data tape. This is the runtime equivalent of `LoadData` but takes a string variable or expression instead of a file path:

```vb
' Syntax
DataFromString expression

' Example: build data from a variable
Dim csv As String
csv = "10, 20, 30"
DataFromString csv
Read a, b, c      ' a=10, b=20, c=30
```

The string contents follow normal `Data` statement syntax — numbers are bare, strings must be double-quoted:

```vb
Dim q As String
q = Chr(34)   ' double-quote character

' Build a string with quoted values
Dim s As String
s = "42, " & q & "hello" & q & ", 3.14, True"
DataFromString s
Read vi, vs, vf, vb   ' vi=42, vs="hello", vf=3.14, vb=True
```

**Typical use case** — load a file into a string, then feed it to the data tape:

```vb
Open "res://data/scores.csv" For Input As #1
Dim contents As String
contents = Input(LOF(1), 1)
Close #1

DataFromString contents
' Now Read values from the file contents
```

Multiple `DataFromString` calls append to the existing tape:

```vb
DataFromString "1, 2"
DataFromString "3, 4"
Read a, b, c, d   ' a=1, b=2, c=3, d=4
```

**Complete example — CSV high-score loader:**

```vb
' Load a CSV file into the data tape and read structured records
Sub LoadHighScores()
    ClearData
    
    ' Read the entire file into a string
    Open "res://data/highscores.csv" For Input As #1
    Dim raw As String
    raw = Input(LOF(1), 1)
    Close #1
    
    ' Feed the file contents to the data tape
    DataFromString raw
    
    ' highscores.csv contains lines like:
    '   "Alice", 9500, 12
    '   "Bob", 8200, 8
    '   "Charlie", 7100, 15
    
    Dim count As Integer
    count = DataCount() \ 3    ' 3 fields per record
    
    Dim q As String
    q = Chr(34)
    
    Print "=== HIGH SCORES ==="
    For i = 1 To count
        Dim playerName As String
        Dim score As Integer
        Dim level As Integer
        Read playerName, score, level
        Print CStr(i) & ". " & playerName & " - " & CStr(score) & " pts (Level " & CStr(level) & ")"
    Next
End Sub
```

**Building data programmatically from user input:**

```vb
' Collect settings at runtime and store as data
Sub SaveSettings()
    Dim q As String
    q = Chr(34)
    
    ' Build a data string from current game state
    Dim settings As String
    settings = CStr(screenWidth) & ", " & CStr(screenHeight) & ", "
    settings = settings & CStr(musicVolume) & ", " & CStr(sfxVolume) & ", "
    settings = settings & q & playerName & q
    
    ' Now we can store and reload it later
    ClearData
    DataFromString settings
    
    ' Verify by reading back
    Dim w As Integer, h As Integer, mv As Integer, sv As Integer, name As String
    Read w, h, mv, sv, name
    Print "Settings: " & CStr(w) & "x" & CStr(h) & " Vol:" & CStr(mv) & "/" & CStr(sv) & " Player:" & name
End Sub
```

#### Data Introspection Functions

Query the state of the data tape at runtime:

| Function | Returns | Description |
|----------|---------|-------------|
| `DataCount()` | Integer | Total number of items in the data tape |
| `DataCount("label")` | Integer | Number of items in a labeled section (case-insensitive) |
| `DataRemain()` | Integer | Items remaining from current pointer to end |
| `DataSectionCount()` | Integer | Total items in the current labeled section |
| `DataSectionRemain()` | Integer | Remaining items in the current labeled section |
| `DataPointer()` | Integer | Current read position (0-based) |
| `PeekData(index)` | Variant | Read value at absolute index without moving pointer |
| `PeekData("label", offset)` | Variant | Read value at label + offset without moving pointer |
| `SetDataPointer(n)` | (none) | Set the read pointer to position *n* (clamped to 0..DataCount) |
| `DataLabels()` | Array | Array of all label names in the data tape |
| `DataSectionName()` | String | Label name of the section the pointer is currently in ("" if preamble) |
| `DataToArray()` | Array | Read the entire data tape into an Array |
| `DataToArray("label")` | Array | Read all items in a labeled section into an Array |
| `DataToArray(n)` | Array | Read *n* items from the current pointer into an Array |

```vb
Data 10, 20, 30

Colors:
Data "Red", "Green", "Blue"

Numbers:
Data 100, 200, 300, 400, 500

Sub Main()
    Print DataCount()             ' 11 (total items)
    Print DataCount("Colors")     ' 3
    Print DataCount("Numbers")    ' 5
    
    Read a, b, c                  ' Read 10, 20, 30
    Print DataPointer()           ' 3
    Print DataRemain()            ' 8
    
    Restore Numbers
    Print DataSectionCount()      ' 5
    Read x, y
    Print DataSectionRemain()     ' 3
End Sub
```

> **Note:** `Restore` is case-insensitive — `Restore colors`, `Restore COLORS`, and `Restore Colors` all work.

**Practical example — safe reading with bounds checking:**

```vb
' Read all items without risking "Out of Data" errors
Sub ReadAllItems()
    Restore ItemData
    
    Do While DataRemain() >= 3    ' Each record is 3 fields
        Dim name As String
        Dim price As Integer
        Dim weight As Single
        Read name, price, weight
        Print name & ": $" & CStr(price) & " (" & CStr(weight) & " kg)"
    Loop
    
    If DataRemain() > 0 Then
        Print "WARNING: " & CStr(DataRemain()) & " leftover values (incomplete record)"
    End If
End Sub

ItemData:
Data "Sword", 150, 3.5
Data "Shield", 100, 5.0
Data "Potion", 25, 0.2
```

**Progress tracking while loading large datasets:**

```vb
Sub LoadWorldData()
    LoadData "res://data/world.dat"
    
    Dim total As Integer
    total = DataCount()
    Print "Loading " & CStr(total) & " data values..."
    
    Dim loaded As Integer
    loaded = 0
    
    Do While DataRemain() > 0
        Dim value
        Read value
        ProcessValue(value)
        loaded = loaded + 1
        
        ' Show progress every 100 items
        If loaded Mod 100 = 0 Then
            Dim pct As Integer
            pct = (loaded * 100) \ total
            Print "Progress: " & CStr(pct) & "%"
        End If
    Loop
    
    Print "Loaded " & CStr(loaded) & " values."
End Sub
```

**Section-aware menu system:**

```vb
MainMenu:
Data "New Game", "Load Game", "Settings", "Quit"

SettingsMenu:
Data "Video", "Audio", "Controls", "Back"

Sub ShowMenu(section As String)
    Restore section
    Dim count As Integer
    count = DataSectionCount()
    
    Print "┌──────────────────┐"
    For i = 1 To count
        Dim item As String
        Read item
        Print "│ " & CStr(i) & ". " & item & String(14 - Len(item), " ") & "│"
    Next
    Print "└──────────────────┘"
    Print "Choose 1-" & CStr(count) & ": ";
End Sub

ShowMenu "MainMenu"      ' Shows 4-item main menu
ShowMenu "SettingsMenu"   ' Shows 4-item settings menu
```

**Random-access reads with PeekData:**

```vb
' PeekData lets you read any value by index without disturbing the pointer.
' This is ideal for lookup tables, tile maps, and configuration.

Weapons:
Data "Sword", 150, 3.5
Data "Shield", 100, 5.0
Data "Potion",  25, 0.2

Sub Main()
    ' --- Absolute index ---
    Print PeekData(0)          ' "Sword"
    Print PeekData(3)          ' "Shield"
    Print DataPointer()        ' 0 — pointer unchanged!

    ' --- Label + offset ---
    Print PeekData("Weapons", 0)   ' "Sword"
    Print PeekData("Weapons", 4)   ' 100  (second item's price)

    ' --- Build an inventory lookup without Read ---
    Dim i As Integer
    For i = 0 To DataCount("Weapons") - 1 Step 3
        Dim n As String
        n = PeekData("Weapons", i)
        Dim p As Integer
        p = PeekData("Weapons", i + 1)
        Print n & ": $" & CStr(p)
    Next
End Sub
```

**SetDataPointer for save / restore patterns:**

```vb
Scores:
Data 1000, 850, 720, 600, 500

Sub Main()
    ' Save current position, jump to entry #3, read one value, restore
    Dim saved As Integer
    saved = DataPointer()

    SetDataPointer 2              ' Jump to index 2
    Dim third As Integer
    Read third                    ' Reads 720, pointer moves to 3
    Print "3rd place: " & CStr(third)

    SetDataPointer saved          ' Restore original position

    ' Negative or out-of-range values are clamped automatically
    SetDataPointer -1             ' Clamped to 0
    SetDataPointer 99999          ' Clamped to DataCount()
End Sub
```

**DataLabels — discover all sections dynamically:**

```vb
Weapons:
Data "Sword", 150, "Shield", 100

Armor:
Data "Helmet", 50, "Chestplate", 200

Potions:
Data "Health", 25, "Mana", 30

Sub Main()
    Dim sections As Variant
    sections = DataLabels()       ' ["weapons", "armor", "potions"]
    
    For Each s In sections
        Print UCase(Left(s, 1)) & Mid(s, 2) & ": " & CStr(DataCount(s)) & " items"
    Next
    ' Output:
    '   Weapons: 4 items
    '   Armor: 4 items
    '   Potions: 4 items
End Sub
```

**DataSectionName — know where the pointer is:**

```vb
Enemies:
Data "Goblin", 30, "Orc", 80, "Dragon", 500

Sub Main()
    Restore Enemies
    Do While DataRemain() > 0
        Dim name As String
        Dim hp As Integer
        Read name, hp
        Print "[" & DataSectionName() & "] " & name & " HP=" & CStr(hp)
    Loop
    ' Output:
    '   [enemies] Goblin HP=30
    '   [enemies] Orc HP=80
    '   [enemies] Dragon HP=500
End Sub
```

**DataToArray — bulk load without looping:**

```vb
Colors:
Data "Red", "Green", "Blue", "Yellow"

Scores:
Data 100, 95, 87, 72, 65

Sub Main()
    ' Load an entire section
    Dim c As Variant
    c = DataToArray("Colors")     ' ["Red", "Green", "Blue", "Yellow"]
    Print "Colors: " & Join(c, ", ")
    
    ' Load first 3 items from pointer position
    SetDataPointer 0
    Dim first3 As Variant
    first3 = DataToArray(3)       ' First 3 items from tape start
    
    ' Load everything
    Dim all As Variant
    all = DataToArray()           ' Entire tape as one array
    Print "Total items: " & CStr(UBound(all) + 1)
End Sub
```

#### Classic Use Cases

**Lookup Tables:**
```vb
' Month names lookup
Data "January", "February", "March", "April", "May", "June"
Data "July", "August", "September", "October", "November", "December"

Dim monthNames(12) As String
For i = 1 To 12
    Read monthNames(i)
Next
```

**ASCII Art and Text:**
```vb
' Store multi-line text/ASCII art
Data "╔════════════════╗"
Data "║  GAME OVER!    ║"
Data "║  Score: %SCORE%║"
Data "╚════════════════╝"

For i = 1 To 4
    Read line
    Print Replace(line, "%SCORE%", CStr(score))
Next
```

**Tile Maps:**
```vb
' Simple tilemap data
Data 1,1,1,1,1,1,1,1
Data 1,0,0,0,0,0,0,1
Data 1,0,2,0,0,3,0,1
Data 1,0,0,0,0,0,0,1
Data 1,1,1,1,1,1,1,1

Dim map(5, 8) As Integer
For y = 1 To 5
    For x = 1 To 8
        Read map(y, x)
    Next
Next
```

**Configuration Data:**
```vb
' Game configuration
Data "Window Title", 1280, 720, True, 60

Dim title As String
Dim width, height As Integer
Dim fullscreen As Boolean
Dim targetFPS As Integer

Read title, width, height, fullscreen, targetFPS
```

#### Putting It All Together

This example combines **DataFromString**, **ClearData**, **Typed Read**, **Empty Data Slots**, **Data Introspection**, **PeekData**, **SetDataPointer**, **DataLabels**, **DataSectionName**, and **DataToArray** in a realistic game scenario:

```vb
' ============================================================
' Dynamic Inventory System using all v3.2.0 Data features
' ============================================================

' Default shop inventory (embedded in code)
' Format: Name, Price, Qty, Attack, Defense, Heal
' Empty slots (,,) mean "not applicable"
ShopItems:
Data "Iron Sword",   50,  5,  12,,,
Data "Oak Shield",   35,  3,,  8,,
Data "Health Vial",  10, 20,,,  25
Data "Mana Ring",   100,  1,,  3, 10

Buffs:
Data "Strength", 1.5, 30
Data "Shield",   1.2, 60

Sub _Ready()
    ' --- Step 1: Discover all data sections dynamically ---
    Print "=== DATA SECTIONS ==="
    Dim sections As Variant
    sections = DataLabels()
    For Each s In sections
        Print "  " & s & ": " & CStr(DataCount(s)) & " values"
    Next
    
    ' --- Step 2: Bulk-load buffs with DataToArray ---
    Print ""
    Print "=== BUFFS (via DataToArray) ==="
    Dim buffs As Variant
    buffs = DataToArray("Buffs")     ' ["Strength", 1.5, 30, "Shield", 1.2, 60]
    Dim b As Integer
    For b = 0 To UBound(buffs) Step 3
        Print "  " & CStr(buffs(b)) & " x" & CStr(buffs(b + 1)) & " for " & CStr(buffs(b + 2)) & "s"
    Next
    
    ' --- Step 3: Random-access shop items with PeekData ---
    Print ""
    Print "=== PEEK ITEM #2 (no loop needed) ==="
    ' Each item is 6 fields; item #2 starts at offset 6
    Dim itemName As String
    itemName = PeekData("ShopItems", 6)
    Dim itemPrice As Integer
    itemPrice = PeekData("ShopItems", 7)
    Print "  " & itemName & " costs $" & CStr(itemPrice)
    Print "  Pointer still at: " & CStr(DataPointer()) & " (unchanged!)"

    ' --- Step 4: Read shop with DataSectionName tracking ---
    Print ""
    Print "=== FULL SHOP (sequential read) ==="
    Restore ShopItems
    Dim shopSize As Integer
    shopSize = DataSectionCount() \ 6   ' 6 fields per item
    
    For i = 1 To shopSize
        Dim name As String, price As Integer, qty As Integer
        Dim atk, def, heal
        Read name, price, qty, atk, def, heal
        
        Dim desc As String
        desc = "[" & DataSectionName() & "] " & name
        desc = desc & " ($" & CStr(price) & ", stock: " & CStr(qty) & ")"
        If Not IsNothing(atk)  Then desc = desc & " ATK+" & CStr(atk)
        If Not IsNothing(def)  Then desc = desc & " DEF+" & CStr(def)
        If Not IsNothing(heal) Then desc = desc & " HEAL+" & CStr(heal)
        Print "  " & desc
    Next
    
    ' --- Step 5: Save/restore pointer with SetDataPointer ---
    Print ""
    Print "=== SAVE/RESTORE POINTER ==="
    Dim saved As Integer
    saved = DataPointer()
    SetDataPointer 0               ' Jump to very beginning
    Dim firstItem As String
    Read firstItem
    Print "  First item in tape: " & firstItem
    SetDataPointer saved            ' Restore where we were
    Print "  Pointer restored to: " & CStr(DataPointer())
    
    ' --- Step 6: Load DLC items from a file ---
    Print ""
    Print "=== LOADING DLC PACK ==="
    ClearData
    
    Open "res://data/dlc_items.csv" For Input As #1
    Dim raw As String
    raw = Input(LOF(1), 1)
    Close #1
    
    DataFromString raw
    
    Dim dlcCount As Integer
    dlcCount = DataCount() \ 6
    Print "Loaded " & CStr(dlcCount) & " DLC items"
    
    ' Use Typed Read for safe parsing of external data
    Do While DataRemain() >= 6
        Dim dName As String
        Dim dPrice As Integer, dQty As Integer
        Read dName As String
        Read dPrice As Integer
        Read dQty As Integer
        Read atk    ' Could be Nothing (empty slot)
        Read def
        Read heal
        Print "  + " & dName & " ($" & CStr(dPrice) & ")"
    Loop
    
    ' --- Step 7: Merge user save data on top ---
    Print ""
    Print "=== MERGING SAVE DATA ==="
    Dim q As String
    q = Chr(34)
    
    ' Simulate save file content as a string
    Dim saveData As String
    saveData = q & "Iron Sword" & q & ", 50, 2, 12,,," & Chr(10)
    saveData = saveData & q & "Health Vial" & q & ", 10, 5,,, 25"
    
    ' Append save data without clearing DLC items
    DataFromString saveData
    Print "Tape now has " & CStr(DataCount()) & " total values"
    Print "Pointer at " & CStr(DataPointer()) & ", " & CStr(DataRemain()) & " values remaining"
    
    ' Grab everything as an array for processing
    Dim allData As Variant
    allData = DataToArray()
    Print "DataToArray() returned " & CStr(UBound(allData) + 1) & " items"
End Sub
```

#### Performance: Data/Read vs Arrays
Benchmark: 500 values × 200 iterations (100,000 sequential reads per test). All tests produce the same checksum to ensure correctness.

| Test | Time (µs) | Reads/sec | vs Array Read |
|------|----------:|----------:|--------------:|
| **Array Read** (pre-filled) | ~45,000 | ~2.2 M/s | 1.0× (baseline) |
| **Data/Read** + `Restore` | ~51,000 | ~2.0 M/s | 0.88× |
| **Array Write + Read** (round-trip) | ~110,000 | ~910 K/s | 0.41× |
| **DataFromString** + `ClearData` (per-iter) | ~170,000 | ~590 K/s | 0.26× |

**Guidelines:**

- **Use `Data`/`Read` for static tables** — only ~12% slower than a pre-filled array, with zero setup code. Ideal for lookup tables, level data, enemy stats, tile maps.
- **`Data`/`Read` is 2× faster than array round-trips** — if the alternative is building an array and then reading it, the data tape wins because values are parsed once at script load time.
- **Use arrays for random access** — `Data`/`Read` is strictly sequential. If you need `arr(i)` with arbitrary `i`, use an array.
- **`DataFromString` is for one-time loading** — the string-to-AST parsing adds overhead, so call it once (e.g. after reading a file), not in a hot loop.

> *Benchmark script: `demo/bench_data_vs_array.vg` — run with `./Godot --headless --path demo -s run_vg.gd -- bench_data_vs_array.vg`*

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

#### Drawing Primitives

```vb
' Basic drawing (available in _Draw())
DrawRect 10, 10, 100, 50, Color(1, 0, 0)          ' Red filled rectangle
DrawCircle 200, 100, 30, Color(0, 0, 1)           ' Blue circle
DrawLine 0, 0, 100, 100, Color(0, 1, 0), 2        ' Green line, 2px wide
DrawPixel 50, 50, Color(1, 1, 0)                   ' Yellow pixel (also: PSet)
DrawString GetThemeDefaultFont(), Vector2(10, 20), "Hello!", Color.White

' Textures
Dim tex As Variant = LoadPicture("res://icon.png")
DrawTexture tex, 100, 100                          ' Draw at position
DrawTextureRect tex, Rect2(0, 0, 200, 200), False  ' Stretch into rect

' Advanced shapes
DrawArc 100, 100, 50, 0, 3.14, 32, Color.Red, 2   ' Half-circle arc
DrawPolygon Array(Vector2(0,0), Vector2(100,0), Vector2(50,80)), Color.Green
DrawPolyline Array(Vector2(0,0), Vector2(50,30), Vector2(100,0)), Color.Blue, 2

' Transform
SetDrawTransform 100, 100, 0.5, 2.0, 2.0          ' Translate, rotate, scale
DrawRect 0, 0, 50, 50, Color.Red                   ' Drawn at transformed position
ResetDrawTransform                                  ' Back to normal
```

#### Image & Texture Manipulation

```vb
' Create an Image and Texture (for pixel-level drawing)
Dim img As Variant = CreateImage(320, 240, Color(1, 1, 1, 1))  ' White 320x240
Dim tex As Variant = CreateTexture(img)

' Draw pixels on the Image
SetImagePixel img, 10, 20, Color(1, 0, 0, 1)       ' Red pixel
Dim c As Variant = GetImagePixel(img, 10, 20)       ' Read it back
Print "Red: " & Str(c.r)                            ' Prints 1.0

' Bulk operations (much faster than per-pixel loops)
FillImage img, Color(0, 0, 0, 1)                    ' Fill entire image black
FillImageRect img, Rect2i(10, 10, 100, 50), Color(0, 1, 0, 1)  ' Green rect

' Copy between images
Dim img2 As Variant = CreateImage(320, 240)
BlitImage img2, img, Rect2i(0, 0, 100, 100), Vector2i(50, 50)  ' Copy region

' Push changes to texture and draw
UpdateTexture tex, img                              ' Sync Image → Texture
DrawTexture tex, 0, 0                               ' Render in _Draw()

' Native drawing builtins (fast C++ pixel operations)
' These run entirely in native code — much faster than VG script loops.

' Line: Bresenham from (x1,y1) to (x2,y2) — optional width for thick brush
DrawImageLine img, 10, 10, 200, 150, Color(1, 0, 0, 1)         ' 1px red diagonal
DrawImageLine img, 0, 120, 319, 120, Color8(0, 0, 255, 255), 8 ' 8px blue brush
Line img, 10, 180, 200, 180, Color(0, 1, 0, 1), 4              ' VB6 alias, 4px

' Rectangle: 1px outline between two corners (auto-normalized)
DrawImageRect img, 20, 20, 120, 80, Color(0, 0, 1, 1)        ' Blue rect outline
' For a FILLED rectangle, use FillImageRect instead:
FillImageRect img, 130, 20, 60, 40, Color(0, 1, 0, 1)        ' Green filled rect

' Ellipse: midpoint algorithm, center (cx,cy), radii (rx,ry)
DrawImageEllipse img, 160, 120, 60, 40, Color(0, 1, 0, 1)    ' Green ellipse
DrawImageEllipse img, 80, 80, 30, 30, Color(1, 0, 1, 1)      ' Circle outline (rx=ry)

' Circle: FILLED circle using scanline fill
DrawImageCircle img, 260, 50, 35, Color(1, 1, 0, 1)          ' Yellow filled sun
' For an outline-only circle, use DrawImageEllipse with rx=ry instead

' FloodFill: fill connected region from seed point
DrawImageRect img, 50, 160, 150, 230, Color(0, 0, 0, 1)      ' Black outline box
FloodFillImage img, 100, 195, Color(0, 0, 1, 1)              ' Blue fill inside
' Only pixels connected to seed (100,195) that match the target color are filled

UpdateTexture tex, img    ' Push all changes to texture for display

' File I/O
SaveImage img, "user://screenshot.png"              ' Save as PNG
Dim loaded As Variant = LoadImage("user://screenshot.png")  ' Load back

' Query dimensions
Print "Image: " & Str(ImageWidth(img)) & "x" & Str(ImageHeight(img))
Print "Texture: " & Str(TextureWidth(tex)) & "x" & Str(TextureHeight(tex))
```

---

## VB6 Global Objects
These virtual objects emulate VB6's built-in global objects. They are resolved automatically when referenced by name — no `Dim` or `New` required.

### App Object
The `App` object provides information about the running application, mirroring VB6's `App` global.

| Property | Type | Description |
|----------|------|-------------|
| `App.Path` | String | Directory containing the executable |
| `App.EXEName` | String | Executable filename (without extension) |
| `App.Title` | String | Application title from project settings |
| `App.Major` | Integer | Major version number |
| `App.Minor` | Integer | Minor version number |
| `App.Revision` | Integer | Revision number |
| `App.PrevInstance` | Boolean | Always `False` (reserved) |
| `App.ProductName` | String | Same as Title |
| `App.CompanyName` | String | Company name (empty by default) |

```vb
Print "Running from: " & App.Path
Print "Application: " & App.Title & " v" & CStr(App.Major) & "." & CStr(App.Minor)
```

### Screen Object
The `Screen` object provides display information, mirroring VB6's `Screen` global.

| Property | Type | Description |
|----------|------|-------------|
| `Screen.Width` | Integer | Screen width in pixels |
| `Screen.Height` | Integer | Screen height in pixels |
| `Screen.TwipsPerPixelX` | Integer | Always 1 (pixels, not twips) |
| `Screen.TwipsPerPixelY` | Integer | Always 1 (pixels, not twips) |
| `Screen.MousePointer` | Integer | Mouse cursor type (0 = default) |

```vb
Print "Resolution: " & CStr(Screen.Width) & "x" & CStr(Screen.Height)
```

### Err Object
The `Err` object is also documented under [Error Handling](#error-handling). It provides runtime error information and supports `Err.Raise` and `Err.Clear`:

```vb
On Error Resume Next
Err.Raise 5, "MyModule", "Invalid argument"
Print Err.Number         ' 5
Print Err.Source         ' "MyModule"
Print Err.Description    ' "Invalid argument"
Err.Clear
On Error GoTo 0
```

### Printer Object
The `Printer` object emulates VB6's global `Printer` object for generating printed output. It is resolved automatically by name — no `Dim` required.

#### Methods

| Method | Description |
|--------|-------------|
| `Printer.Print text` | Sends text to the output buffer |
| `Printer.EndDoc` | Finishes the print job and flushes output |
| `Printer.NewPage` | Starts a new page (increments `Page`) |
| `Printer.KillDoc` | Cancels the current print job |
| `Printer.Circle x, y, r` | Draws a circle (stub — logs parameters) |
| `Printer.Line x1, y1, x2, y2` | Draws a line (stub — logs parameters) |
| `Printer.PaintPicture pic, x, y` | Paints an image (stub — logs parameters) |
| `Printer.PSet x, y` | Sets a pixel (stub — logs parameters) |

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Printer.Font` | String | `"Arial"` | Current font name |
| `Printer.FontSize` | Integer | `12` | Font size in points |
| `Printer.FontBold` | Boolean | `False` | Bold flag |
| `Printer.FontItalic` | Boolean | `False` | Italic flag |
| `Printer.Orientation` | Integer | `1` | 1 = Portrait, 2 = Landscape |
| `Printer.Copies` | Integer | `1` | Number of copies |
| `Printer.Page` | Integer | `1` | Current page number (read-only, incremented by `NewPage`) |
| `Printer.CurrentX` | Integer | `0` | Horizontal print position |
| `Printer.CurrentY` | Integer | `0` | Vertical print position |
| `Printer.ScaleWidth` | Integer | `8500` | Logical page width |
| `Printer.ScaleHeight` | Integer | `11000` | Logical page height |
| `Printer.hDC` | Integer | `0` | Device context handle (stub) |
| `Printer.ColorMode` | Integer | `1` | 1 = Monochrome, 2 = Color |
| `Printer.PaperSize` | Integer | `1` | Paper size constant |

```vb
' Basic printing example
Printer.Font = "Courier New"
Printer.FontSize = 10
Printer.Print "Invoice #1234"
Printer.Print "Date: " & Format(Now, "yyyy-mm-dd")
Printer.NewPage
Printer.Print "Page 2 content"
Printer.EndDoc
```

### PrintForm Statement
`PrintForm` captures the current viewport to a PNG image file, emulating VB6's `PrintForm` statement.

```vb
' Capture the current form/viewport to an image
PrintForm
```

The image is saved to `user://printform_output.png` in the Godot user data directory. A confirmation message is printed to the console.

---

## COM-Style Objects
These classes emulate common VB6/VBScript COM objects. Instantiate with `Dim obj As New ClassName` or via `CreateObject("ProgID")`.

### VGCollection
A VB6-compatible ordered collection with optional string keys and **1-based indexing**.

**Aliases:** `New Collection` · `CreateObject("VB6.Collection")` · `CreateObject("VBA.Collection")`

| Method/Property | Description |
|-----------------|-------------|
| `Add item [, key] [, Before n] [, After n]` | Add an item with optional key and position |
| `Remove index_or_key` | Remove by 1-based index or key |
| `Item(index_or_key)` | Retrieve by 1-based index or key |
| `Count` | Number of items |
| `HasKey(key)` | Check if a key exists |
| `Clear` | Remove all items |
| `ToArray` | Return all items as an Array |

```vb
Dim col As New Collection
col.Add "Apple", "a"
col.Add "Banana", "b"
col.Add "Cherry", "c"

Print col.Count              ' 3
Print col.Item(1)            ' "Apple"
Print col.Item("b")          ' "Banana"

col.Remove 2                 ' Remove "Banana"
Print col.Count              ' 2

col.Clear
```

### VGRegEx
VBScript.RegExp emulation wrapping Godot's PCRE2-based RegEx engine.

**Aliases:** `New RegExp` · `CreateObject("VBScript.RegExp")`

| Property/Method | Description |
|-----------------|-------------|
| `Pattern` | The regular expression pattern |
| `Global` | Boolean — match all occurrences (default: False) |
| `IgnoreCase` | Boolean — case-insensitive matching |
| `Test(string)` | Returns True if the pattern matches |
| `Execute(string)` | Returns an Array of VGRegExMatch objects |
| `Replace(string, replacement)` | Replace matched text |

```vb
Dim re As New RegExp
re.Pattern = "\d+"
re.Global = True

If re.Test("abc123def") Then
    Print "Found digits!"
End If

Dim result As String = re.Replace("abc123def456", "NUM")
Print result    ' "abcNUMdefNUM"
```

### VGHttpRequest
MSXML2.XMLHTTP emulation wrapping Godot HTTPClient. Suitable for REST API calls.

**Aliases:** `New HttpRequest` · `New XMLHTTP` · `CreateObject("MSXML2.XMLHTTP")`

| Method/Property | Description |
|-----------------|-------------|
| `open method, url` | Initialize a request ("GET", "POST", etc.) |
| `setRequestHeader name, value` | Set a request header |
| `send [body]` | Send the request |
| `responseText` | The response body as a string |
| `status` | HTTP status code (200, 404, etc.) |
| `getAllResponseHeaders` | All response headers as a string |

```vb
Dim http As New HttpRequest
http.open "GET", "https://api.example.com/data"
http.setRequestHeader "Accept", "application/json"
http.send
If http.status = 200 Then
    Print http.responseText
End If
```

### VGTimer
A poll-based timer control for periodic events. Also provides the `Timer()` function.

**Aliases:** `New VBTimer` · `New Timer`

| Property | Description |
|----------|-------------|
| `Interval` | Timer interval in milliseconds |
| `Enabled` | Boolean — whether the timer is active |

**Timer() Function:** Returns the number of seconds since midnight as a Double.

```vb
' Timer function
Dim t As Double = Timer()
Print "Seconds since midnight: " & CStr(t)

' Timer class
Dim tmr As New VBTimer
tmr.Interval = 1000    ' Fire every second
tmr.Enabled = True
```

---

## System Integration
These classes provide C#-level system integration: native FFI, ODBC databases, cryptography, XML, ZIP, async threading, and package management. All classes use VB6-style PascalCase aliases for a familiar BASIC feel.

> **See also:** [docs/SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) for the full API reference with extended examples.

### NativeLibrary (FFI)
Load any shared library (`.so`, `.dll`, `.dylib`) and call its C functions — the cross-platform equivalent of VB6's `Declare Function`.

**Aliases:** `New NativeLibrary`

| Method/Property | Description |
|-----------------|-------------|
| `Load(path)` | Load a shared library. Returns `True` on success |
| `Unload()` | Unload the library |
| `QuickCall(name, ...)` | Call with auto-detected argument types |
| `CallFunction(name, returnType, argTypes, args)` | Full-signature call |
| `CallSimple(name, args)` | Array-based call |
| `CreateCallback(callable, returnType, argTypes)` | Create a C callback |
| `.IsLoaded` | Whether a library is loaded |
| `.Path` | The loaded library path |
| `.LastError` | Last error message |

```vb
Dim lib As New NativeLibrary
lib.Load "libm.so.6"

' Quick call — auto-detects types
Dim result As Variant
result = lib.QuickCall("sqrt", 144.0)
Print "sqrt(144) = " & CStr(result)       ' 12.0

' Full call with explicit types
result = lib.CallFunction("pow", "double", Array("double", "double"), Array(2.0, 10.0))
Print "pow(2,10) = " & CStr(result)       ' 1024.0

lib.Unload
```

**Supported FFI Types:** `void`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `pointer`, `string`, `int8`, `uint8`, `int16`, `uint16`, `int32`, `uint32`, `int64`, `uint64`

### NativeStruct
Describe C struct memory layouts and allocate/read/write fields.

**Aliases:** `New NativeStruct`

| Method/Property | Description |
|-----------------|-------------|
| `AddField(name, type)` | Add a field to the struct layout |
| `Create()` | Allocate a new struct instance → handle |
| `Destroy(handle)` | Free a struct instance |
| `SetField(handle, name, value)` | Write a field |
| `GetField(handle, name)` | Read a field |
| `GetPointer(handle)` | Get raw memory address |
| `.Size` | Struct size in bytes |
| `.FieldCount` | Number of fields |
| `.FieldNames` | Array of field name strings |

```vb
Dim s As New NativeStruct

' Define: struct Point { int x; int y; }
s.AddField "x", "int"
s.AddField "y", "int"

Print "Size: " & CStr(s.Size) & " bytes"   ' 8

Dim h As Integer = s.Create()
s.SetField h, "x", 100
s.SetField h, "y", 200
Print s.GetField(h, "x")                    ' 100
s.Destroy h
```

### VGOdbc (Database)
Connect to any ODBC database — PostgreSQL, MySQL, SQL Server, SQLite, Oracle, and more. The ODBC driver is loaded dynamically at runtime.

**Aliases:** `New VGOdbc`

| Method/Property | Description |
|-----------------|-------------|
| `Open()` | Connect using `.ConnectionString` |
| `OpenWithString(cs)` | Connect with a specified connection string |
| `Close()` | Disconnect |
| `Execute(sql)` | Run INSERT/UPDATE/DELETE |
| `ExecuteParams(sql, params)` | Parameterized execute (safe from injection) |
| `Query(sql)` | SELECT → `Array` of `Dictionary` rows |
| `QueryParams(sql, params)` | Parameterized query |
| `BeginTransaction()` | Start a transaction |
| `CommitTransaction()` | Commit |
| `RollbackTransaction()` | Rollback |
| `ListTables()` | List table names |
| `TableExists(name)` | Check if a table exists |
| `ListDrivers()` | List installed ODBC drivers |
| `.ConnectionString` | Get/set connection string |
| `.IsOpen` | Connection state |
| `.LastError` | Last error message |

```vb
Dim db As New VGOdbc
db.ConnectionString = "Driver={PostgreSQL};Server=localhost;Database=myapp;"
db.Open

' Query → Array of Dictionary
Dim rows As Variant
rows = db.Query("SELECT name, email FROM users ORDER BY name")
For i = 0 To rows.size() - 1
    Print rows[i]["name"] & " — " & rows[i]["email"]
Next i

' Parameterized query (safe)
rows = db.QueryParams("SELECT * FROM users WHERE age > ?", Array(18))

' Transactions
db.BeginTransaction
db.Execute "UPDATE accounts SET balance = balance - 100 WHERE id = 1"
db.Execute "UPDATE accounts SET balance = balance + 100 WHERE id = 2"
db.CommitTransaction

db.Close
```

### VGCrypto (Cryptography)
Static utility class for hashing, encoding, encryption, and random generation.

| Method | Description |
|--------|-------------|
| `MD5(text)` / `SHA1(text)` / `SHA256(text)` | Hash a string → hex |
| `MD5Bytes(data)` / `SHA1Bytes(data)` / `SHA256Bytes(data)` | Hash bytes → hex |
| `base64_encode(data)` / `base64_decode(b64)` | Base64 encode/decode |
| `hex_encode(data)` / `hex_decode(hex)` | Hex encode/decode |
| `encrypt_aes(data, key)` | AES-256-CBC encrypt |
| `decrypt_aes(data, key)` | AES-256-CBC decrypt |
| `random_bytes(count)` | Random byte array |
| `generate_uuid()` | RFC 4122 v4 UUID string |
| `hmac_sha256(data, key)` | HMAC-SHA256 hex signature |

```vb
' Hashing
Print VGCrypto.MD5("hello")        ' "5d41402abc4b2a76b9719d911017c592"
Print VGCrypto.SHA256("hello")     ' 64-char hex

' AES Encryption
Dim key As String = "MySecretKey12345MySecretKey12345"   ' 32 bytes
Dim encrypted As Variant
encrypted = VGCrypto.encrypt_aes("top secret".to_utf8_buffer(), key.to_utf8_buffer())
Dim decrypted As Variant
decrypted = VGCrypto.decrypt_aes(encrypted, key.to_utf8_buffer())
Print decrypted.get_string_from_utf8()    ' "top secret"

' UUID
Dim id As String = VGCrypto.generate_uuid()
Print id   ' "550e8400-e29b-41d4-a716-446655440000"
```

### VGXml (XML Processing)
Read, write, parse, and query XML documents.

**Aliases:** `New VGXml`

| Method/Property | Description |
|-----------------|-------------|
| `LoadFile(path)` | Load XML from a file |
| `LoadString(xml)` | Load XML from a string |
| `SaveFile(path)` | Save to file |
| `ToString()` | Get XML as a string |
| `Parse()` | Parse into a Dictionary tree |
| `SelectNodes(path)` | XPath query → Array of nodes |
| `SelectSingleNode(path)` | XPath query → first match |
| `.XmlContent` | Property — raw XML string |
| `.LastError` | Property — last error |

```vb
Dim xml As New VGXml
xml.LoadString "<catalog><book>Title A</book><book>Title B</book></catalog>"

' Parse to Dictionary tree
Dim tree As Variant = xml.Parse()
Print tree["tag"]                       ' "catalog"
Print tree["children"][0]["text"]       ' "Title A"

' XPath-style queries
Dim books As Variant = xml.SelectNodes("catalog/book")
Print "Found " & CStr(books.size()) & " books"

' Save
xml.SaveFile "user://output.xml"
```

### VGZip (ZIP Archives)
Create, read, and extract ZIP archives.

**Aliases:** `New VGZip`

| Method/Property | Description |
|-----------------|-------------|
| `OpenRead(path)` | Open for reading |
| `OpenWrite(path)` | Create/open for writing |
| `Close()` | Close the archive |
| `AddText(name, text)` | Add a text file to archive |
| `AddFile(name, data)` | Add a binary file (PackedByteArray) |
| `ListFiles()` | List file names → Array |
| `read_text(name)` | Read a file as String |
| `read_file(name)` | Read a file as PackedByteArray |
| `file_exists(name)` | Check if file exists |
| `extract_to(dir)` | Extract all files to a directory |
| `extract_file(name, dest)` | Extract a single file |
| `.FileCount` | Number of files |
| `.IsOpen` | Whether the archive is open |
| `.ArchivePath` | File path |
| `.LastError` | Last error |

```vb
' Create a ZIP
Dim zip As New VGZip
zip.OpenWrite "user://backup.zip"
zip.AddText "readme.txt", "Hello World!"
zip.AddText "data/config.ini", "[Settings]" & vbCrLf & "Theme=Dark"
zip.Close

' Read a ZIP
Dim reader As New VGZip
reader.OpenRead "user://backup.zip"
Print "Files: " & CStr(reader.FileCount)
Print reader.read_text("readme.txt")      ' "Hello World!"
reader.extract_to "user://restored/"
reader.Close
```

### VGTask (Async Tasks)
Run work on a background thread without freezing the game. Wraps `std::thread` with Godot-safe signalling.

**Aliases:** `New VGTask`

| Method/Property | Description |
|-----------------|-------------|
| `RunAsync(callable)` | Run a Callable on a background thread |
| `RunAsyncWithArgs(callable, args)` | Run with arguments |
| `RunDelayed(callable, seconds)` | Run after a delay |
| `Cancel()` | Cancel the task |
| `WaitForResult()` | Block until the result is ready |
| `.IsComplete` | Whether the task finished |
| `.IsRunning` | Whether it's currently running |
| `.IsFailed` | Whether an error occurred |
| `.IsCancelled` | Whether it was cancelled |
| `.Status` | String — `"pending"`, `"running"`, `"completed"`, `"failed"`, `"cancelled"` |
| `.Result` | The return value |
| `.ErrorMessage` | Error text (if failed) |

```vb
Dim task As New VGTask
task.RunAsync Callable(Me, "HeavyWork")

' ... do other things ...

Dim result As Variant = task.WaitForResult()
Print "Done: " & CStr(result)

' Delayed execution
Dim later As New VGTask
later.RunDelayed Callable(Me, "Greet"), 2.0   ' Run after 2 seconds

' Cancellation
task.Cancel
Print task.IsCancelled   ' True
```

### VGTaskRunner (Parallel)
Run multiple tasks in parallel and collect their results.

**Aliases:** `New VGTaskRunner`

| Method/Property | Description |
|-----------------|-------------|
| `AddTask(callable)` | Add a task to the queue |
| `RunAll()` | Run all tasks in parallel, wait for completion |
| `RunAllLimited(max)` | Run with a maximum thread count |
| `get_all_results()` | Get all results → Array |
| `.TaskCount` | Number of tasks |
| `.CompletedCount` | Number finished |
| `.Progress` | 0.0 – 1.0 progress float |

```vb
Dim runner As New VGTaskRunner

runner.AddTask Callable(Me, "Worker1")
runner.AddTask Callable(Me, "Worker2")
runner.AddTask Callable(Me, "Worker3")

Print "Running " & CStr(runner.TaskCount) & " tasks..."
runner.RunAll

Dim results As Variant = runner.get_all_results()
For i = 0 To results.size() - 1
    Print "Task " & CStr(i) & ": " & CStr(results[i])
Next i
```

### VisualGasicPackage (Package Manager)
Manage project dependencies with semantic versioning, registries, and `vgpkg.json` manifests.

**Aliases:** `New VisualGasicPackage`

| Method | Description |
|--------|-------------|
| `Initialize(workspace)` | Initialize the package manager |
| `Shutdown()` | Shut down cleanly |
| `InstallPackage(name, version)` | Install a package → Dictionary result |
| `UninstallPackage(name)` | Remove a package |
| `update_package(name)` | Update a package |
| `update_all_packages()` | Update everything |
| `AddRegistry(name, url [, token])` | Add a package registry |
| `search_packages(query)` | Search for packages |
| `get_installed_packages()` | List installed packages |
| `initialize_project(path)` | Create a `vgpkg.json` manifest |
| `add_dependency(name, constraint)` | Add a dependency |
| `remove_dependency(name)` | Remove a dependency |
| `get_project_dependencies()` | List dependencies |
| `create_package_template(name, type)` | Scaffold a new package |
| `build_package(path)` | Build a package for distribution |
| `publish_package(path, registry)` | Publish to a registry |
| `clear_cache()` | Clear download cache |

**Version constraints:** `^1.2.0` (compatible), `~1.2.0` (patch only), `>=2.0.0` (at least), `1.5.0` (exact).

```vb
Dim pkg As New VisualGasicPackage
pkg.Initialize "res://"

' Add a registry
pkg.AddRegistry "official", "https://packages.visualgasic.org"

' Install a package
Dim result As Variant = pkg.InstallPackage("vg-math", "^1.0.0")
Print result["message"]

' Project dependencies
pkg.initialize_project "res://"
pkg.add_dependency "vg-ui", ">=2.0.0"

Dim deps As Variant = pkg.get_project_dependencies()
Print "Dependencies: " & CStr(deps.size())

pkg.Shutdown
```

### Cross-Platform System Classes

The following system classes (introduced in v2.9.0) now have full **Windows** and **macOS** backends in v3.0. The same VG code runs on all three platforms:

| Class | Linux/macOS | Windows |
|-------|------------|--------|
| `VGProcess` (`New Process`) | fork / exec / pipe | CreateProcess / CreatePipe |
| `VGSocket` (`New WinSock`) | POSIX sockets | WinSock2 (WSAStartup) |
| `VGFileWatcher` (`New FileSystemWatcher`) | inotify / kqueue | FindFirstChangeNotification |
| `VGSysTray` (`New SysTray`) | stub | Shell_NotifyIcon + HWND_MESSAGE |

### Real COM Interop (Windows)

`CreateObject()` now falls through to the real COM subsystem on Windows when the requested ProgID isn't a built-in emulated object. This lets you automate Excel, Word, Outlook, or any installed COM server:

```vb
' Built-in objects — work on all platforms
Dim dict As Object = CreateObject("Scripting.Dictionary")

' Real COM — Windows only
Dim xl As Object = CreateObject("Excel.Application")
xl.Visible = True
xl.Workbooks.Add
xl.Cells(1, 1).Value = "Hello from VisualGasic!"
```

---

## System-Level Programming
These classes close every gap identified in the system-programming audit, making VisualGasic a proper system-level language on Linux, Windows, macOS, and Android.

> **See also:** [docs/SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) for the full API reference with extended examples.

### VGSystem (System Info)
Cross-platform system information queries — hostname, CPU, RAM, disk, OS, uptime, environment variables, and locale.

| Method | Returns | Description |
|--------|---------|-------------|
| `Hostname` | String | Machine hostname |
| `Username` | String | Current user name |
| `ProcessId` | int | Current process ID |
| `CpuCount` | int | Number of logical CPU cores |
| `CpuName` | String | CPU model name |
| `Architecture` | String | CPU architecture (x86_64, aarch64, etc.) |
| `TotalMemory` | int64 | Total RAM in bytes |
| `FreeMemory` | int64 | Free RAM in bytes |
| `UsedMemory` | int64 | Used RAM in bytes |
| `MemoryUsagePercent` | double | RAM usage as percentage |
| `FreeDiskSpace(path)` | int64 | Free disk space in bytes |
| `TotalDiskSpace(path)` | int64 | Total disk space in bytes |
| `DiskUsagePercent(path)` | double | Disk usage as percentage |
| `OsName` | String | Operating system name |
| `OsVersion` | String | OS version/release |
| `OsFull` | String | OS name + version combined |
| `Endianness` | String | "little" or "big" |
| `Uptime` | double | System uptime in seconds |
| `GetEnv(name)` | String | Get environment variable |
| `SetEnv(name, value)` | void | Set environment variable |
| `HasEnv(name)` | bool | Check if env var exists |
| `GetAllEnv()` | Dictionary | All environment variables |
| `GetLocale()` | String | System locale (e.g. "en_US.UTF-8") |
| `GetLanguage()` | String | Two-letter language code |
| `GetTimezone()` | String | Timezone name |
| `GetTimezoneOffset()` | int | UTC offset in seconds |
| `GetSystemInfo()` | Dictionary | Everything in one call |

```vb
Dim sys As Object = New VGSystem
Print "Host: " & sys.Hostname
Print "CPU: " & sys.CpuName & " (" & CStr(sys.CpuCount) & " cores)"
Print "RAM: " & CStr(sys.TotalMemory / 1073741824) & " GB"
Print "OS: " & sys.OsFull
Print "Uptime: " & CStr(CInt(sys.Uptime / 3600)) & " hours"
Print "Locale: " & sys.GetLocale()
Print "HOME=" & sys.GetEnv("HOME")
```

### VGSignalHandler (OS Signals)
Handle OS-level signals (SIGINT, SIGTERM, SIGHUP) and atexit cleanup. On Windows, maps to `SetConsoleCtrlHandler` events.

| Method | Description |
|--------|-------------|
| `OnInterrupt(handler)` | Register SIGINT (Ctrl+C) handler |
| `OnTerminate(handler)` | Register SIGTERM handler |
| `OnHangup(handler)` | Register SIGHUP handler |
| `OnUser1(handler)` | Register SIGUSR1 handler |
| `OnUser2(handler)` | Register SIGUSR2 handler |
| `OnExit(handler)` | Register atexit cleanup |
| `SetHandler(name, handler)` | Generic signal handler by name |
| `RemoveHandler(name)` | Remove a registered handler |
| `HasHandler(name)` | Check if handler is registered |
| `GetRegisteredSignals()` | List all registered signal names |
| `RaiseSignal(name)` | Send signal to self |
| `LastSignal` | Name of last received signal |
| `IsInstalled` | Whether any handlers are installed |

```vb
Dim sh As Object = New VGSignalHandler
sh.OnInterrupt(Lambda() => Print("Caught Ctrl+C!"))
sh.OnExit(Lambda() => Print("Cleaning up..."))
sh.OnTerminate(Lambda() => Print("Shutting down gracefully"))
```

### VGFilePermissions (Permissions & Links)
UNIX file permissions, ownership, symbolic links, file locking, and VB6-style file attributes.

| Method | Returns | Description |
|--------|---------|-------------|
| `Chmod(path, mode)` | bool | Set UNIX permissions (e.g. `&o755`) |
| `GetPermissions(path)` | int | Get permission bits |
| `GetPermissionsString(path)` | String | "rwxr-xr-x" format |
| `IsReadable(path)` | bool | Check read access |
| `IsWritable(path)` | bool | Check write access |
| `IsExecutable(path)` | bool | Check execute access |
| `Chown(path, owner, group)` | bool | Change ownership |
| `GetOwner(path)` | String | Get file owner name |
| `GetGroup(path)` | String | Get file group name |
| `CreateSymlink(link, target)` | bool | Create symbolic link |
| `CreateHardlink(link, target)` | bool | Create hard link |
| `IsSymlink(path)` | bool | Test for symlink |
| `ReadSymlink(path)` | String | Read symlink target |
| `LockFile(path)` | bool | Exclusive file lock (blocking) |
| `TryLockFile(path)` | bool | Non-blocking lock attempt |
| `UnlockFile(path)` | bool | Release file lock |
| `IsLocked(path)` | bool | Check if currently locked |
| `GetAttr(path)` | int | VB6-style attributes (1=ReadOnly, 2=Hidden, 4=System, 16=Dir, 32=Archive) |
| `SetAttr(path, flags)` | bool | Set VB6-style attributes |
| `GetFileInfo(path)` | Dictionary | Full stat info (size, created, modified, mode, etc.) |
| `FileLen(path)` | int64 | File size in bytes |
| `FileType(path)` | String | "file", "directory", "symlink", etc. |

```vb
Dim fp As Object = New VGFilePermissions
fp.Chmod "/tmp/script.sh", &o755
Print fp.GetPermissionsString("/tmp/script.sh")    ' "rwxr-xr-x"
fp.CreateSymlink "/tmp/link", "/tmp/script.sh"
Print "Owner: " & fp.GetOwner("/tmp/script.sh")

' VB6-style attributes
Dim attr As Integer = fp.GetAttr("C:\data.txt")
If attr And 1 Then Print "Read-only"

' File locking
If fp.TryLockFile("/tmp/data.lock") Then
    ' ... critical section ...
    fp.UnlockFile "/tmp/data.lock"
End If
```

### VGMemoryBuffer (Raw Memory)
Raw byte-level memory buffer with Peek/Poke access — the VB6 equivalent of `CopyMemory` / `RtlMoveMemory`. Useful for binary protocols, FFI interop, and system programming.

| Method | Description |
|--------|-------------|
| `Allocate(size)` | Allocate buffer (bytes) |
| `Resize(size)` | Resize preserving content |
| `Free()` | Release memory |
| `IsAllocated` | Check if allocated |
| `Size` | Current buffer size |
| `Fill(byte)` / `FillRange(off, len, byte)` | Fill with value |
| `Clear()` | Zero-fill |
| `PeekByte/Int16/UInt16/Int32/Int64(offset)` | Read typed value |
| `PeekFloat/Double(offset)` | Read floating point |
| `PeekString(offset, length)` | Read UTF-8 string |
| `PokeByte/Int16/UInt16/Int32/Int64(offset, value)` | Write typed value |
| `PokeFloat/Double(offset, value)` | Write floating point |
| `PokeString(offset, value)` | Write UTF-8 string |
| `CopyTo(dest, srcOff, dstOff, len)` | Copy to another buffer |
| `CopyFrom(src, srcOff, dstOff, len)` | Copy from another buffer |
| `ToByteArray()` / `ToByteArrayRange(off, len)` | Export to PackedByteArray |
| `FromByteArray(arr)` | Import from PackedByteArray |
| `FindByte(value, start)` | Search for byte |
| `FindPattern(bytes, start)` | Search for byte pattern |
| `HexDump(offset, length)` | Debug hex dump string |
| `GetPointer()` | Raw int64 address for FFI |

```vb
Dim buf As Object = New VGMemoryBuffer
buf.Allocate 1024

' Write a C-style struct: int32 id, float x, float y
buf.PokeInt32 0, 42
buf.PokeFloat 4, 3.14
buf.PokeFloat 8, 2.71

' Read it back
Print "ID: " & CStr(buf.PeekInt32(0))
Print "X: " & CStr(buf.PeekFloat(4))
Print "Y: " & CStr(buf.PeekFloat(8))

' Pass to FFI
Dim lib As Object = New NativeLibrary
lib.Load "mylib.so"
lib.CallFunction "process_data", "void", Array("pointer", "int"), Array(buf.GetPointer(), buf.Size)

Print buf.HexDump(0, 16)
buf.Free
```

### VGIPC (Inter-Process Communication)
Named pipes, UNIX domain sockets, and POSIX shared memory for communicating between processes.

#### Named Pipes

| Method | Description |
|--------|-------------|
| `CreateNamedPipe(path)` | Create a FIFO (mkfifo / CreateNamedPipe) |
| `OpenPipe(path, mode)` | Open pipe for "read" or "write" |
| `ReadPipe(maxBytes)` | Read string from pipe |
| `ReadPipeBytes(maxBytes)` | Read raw bytes from pipe |
| `WritePipe(data)` | Write string to pipe |
| `WritePipeBytes(data)` | Write raw bytes to pipe |
| `ClosePipe()` | Close pipe fd |
| `DeleteNamedPipe(path)` | Remove FIFO from filesystem |

#### UNIX Domain Sockets

| Method | Description |
|--------|-------------|
| `CreateDomainSocket(path)` | Create, bind, and listen |
| `ConnectDomainSocket(path)` | Connect as client |
| `AcceptConnection()` | Accept incoming connection |
| `ReadSocket(maxBytes)` | Read string |
| `ReadSocketBytes(maxBytes)` | Read raw bytes |
| `WriteSocket(data)` | Write string |
| `WriteSocketBytes(data)` | Write raw bytes |
| `CloseSocket()` | Close socket and unlink |

#### Shared Memory

| Method | Description |
|--------|-------------|
| `CreateSharedMemory(name, size)` | Create new shared segment (shm_open + mmap) |
| `OpenSharedMemory(name, size)` | Attach to existing segment |
| `WriteSharedMemory(offset, data)` | Write string at offset |
| `WriteSharedMemoryBytes(offset, data)` | Write bytes at offset |
| `ReadSharedMemory(offset, length)` | Read string |
| `ReadSharedMemoryBytes(offset, length)` | Read bytes |
| `CloseSharedMemory()` | Detach and unlink |

```vb
' === Named Pipe Example ===
Dim ipc As Object = New VGIPC
ipc.CreateNamedPipe "/tmp/myapp.pipe"
ipc.OpenPipe "/tmp/myapp.pipe", "write"
ipc.WritePipe "Hello from VG!"
ipc.ClosePipe

' === Shared Memory Example ===
Dim shm As Object = New VGIPC
shm.CreateSharedMemory "myapp_data", 4096
shm.WriteSharedMemory 0, "Shared state"
Dim data As String = shm.ReadSharedMemory(0, 12)
Print data  ' "Shared state"
shm.CloseSharedMemory

' === Domain Socket Server ===
Dim srv As Object = New VGIPC
srv.CreateDomainSocket "/tmp/myapp.sock"
srv.AcceptConnection
Dim msg As String = srv.ReadSocket(1024)
srv.WriteSocket "ACK: " & msg
srv.CloseSocket
```

### VGAndroidBridge (Android Platform)
JNI bridge for Android platform APIs. All methods return safe defaults on non-Android platforms (Linux, Windows, macOS).

| Method | Returns | Description |
|--------|---------|-------------|
| `SdkVersion` | int | Android SDK version (e.g. 34) |
| `DeviceModel` | String | Device model name |
| `DeviceManufacturer` | String | Device manufacturer |
| `AndroidVersion` | String | Android version string |
| `PackageName` | String | App package name |
| `AppVersion` | String | App version string |
| `DeviceId` | String | Device identifier |
| `HasPermission(perm)` | bool | Check if permission granted |
| `RequestPermission(perm)` | void | Request single permission |
| `RequestPermissions(perms)` | void | Request multiple permissions |
| `GetGrantedPermissions()` | Array | List granted permissions |
| `OpenUrl(url)` | void | Open URL in browser |
| `ShareText(text, title)` | void | Share text via intent |
| `SendEmail(to, subject, body)` | void | Send email via intent |
| `OpenAppSettings()` | void | Open app settings page |
| `ShowToast(message, duration)` | void | Show Android toast |
| `Vibrate(ms)` | void | Vibrate device |
| `ExternalStoragePath` | String | External storage path |
| `CacheDir` | String | App cache directory |
| `FilesDir` | String | App files directory |
| `GetBatteryInfo()` | Dictionary | Battery level, status, charging |
| `IsAndroid()` | bool | True on Android, false elsewhere |
| `KeepScreenOn(enabled)` | void | Prevent screen timeout |

```vb
Dim android As Object = New VGAndroidBridge

If android.IsAndroid() Then
    Print "Device: " & android.DeviceManufacturer & " " & android.DeviceModel
    Print "Android " & android.AndroidVersion & " (SDK " & CStr(android.SdkVersion) & ")"
    
    ' Check and request permissions
    If Not android.HasPermission("android.permission.CAMERA") Then
        android.RequestPermission "android.permission.CAMERA"
    End If
    
    ' UI
    android.ShowToast "Welcome to VisualGasic!", 1
    android.Vibrate 200
    
    ' Battery
    Dim batt As Dictionary = android.GetBatteryInfo()
    Print "Battery: " & CStr(batt("level")) & "%"
    
    ' Share
    android.ShareText "Check out VisualGasic!", "Share"
End If
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

### Godot Singleton Access

VisualGasic provides **universal access to all 37 Godot engine singletons** directly by name. Any registered Godot singleton can be used without imports or special setup:

```vb
' Engine singleton — performance monitoring
Dim fps As Integer = Engine.get_frames_per_second()
Dim physTicks As Integer = Engine.get_physics_ticks_per_second()
Dim isEditor As Boolean = Engine.is_editor_hint()

' OS singleton — system information
Dim osName As String = OS.get_name()
Dim cpuCount As Integer = OS.get_processor_count()
Dim cpuName As String = OS.get_processor_name()
Dim isDebug As Boolean = OS.is_debug_build()

' Time singleton — timing
Dim ms As Integer = Time.get_ticks_msec()
Dim us As Integer = Time.get_ticks_usec()
Dim unixTime As Double = Time.get_unix_time_from_system()

' Input singleton — input state
Dim mouseMode As Integer = Input.get_mouse_mode()
Dim joypads As Variant = Input.get_connected_joypads()

' DisplayServer — display info
Dim displayName As String = DisplayServer.get_name()

' AudioServer — audio info
Dim busCount As Integer = AudioServer.get_bus_count()
Dim mixRate As Double = AudioServer.get_mix_rate()
```

All 37 Godot singletons are supported, including `Engine`, `OS`, `Time`, `Input`, `DisplayServer`, `AudioServer`, `RenderingServer`, `PhysicsServer2D`, `PhysicsServer3D`, `NavigationServer2D`, `NavigationServer3D`, `ProjectSettings`, `ResourceLoader`, `ResourceSaver`, `ClassDB`, `Performance`, `IP`, `Geometry2D`, `Geometry3D`, `ThemeDB`, `TranslationServer`, `Marshalls`, and more.

### Godot Class Enum Constants

Access Godot class enum constants using `ClassName.CONSTANT_NAME` syntax:

```vb
' FileAccess mode flags
Dim mode As Integer = FileAccess.READ          ' = 1
Dim rw As Integer = FileAccess.READ_WRITE      ' = 3

' Input mouse modes
Dim captured As Integer = Input.MOUSE_MODE_CAPTURED  ' = 2

' Sky processing modes
Dim quality As Integer = Sky.PROCESS_MODE_QUALITY    ' = 1

' Node process modes
Dim inherit As Integer = Node.PROCESS_MODE_INHERIT   ' = 0
Dim always As Integer = Node.PROCESS_MODE_ALWAYS     ' = 1
```

Enum constants work with all Godot classes, including constants whose names match VG keywords (e.g., `FileAccess.READ` and `FileAccess.WRITE` work correctly even though `Read` and `Write` are VG keywords).

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

#### Implementation Notes

The Whenever system is fully compiled to bytecode for optimal performance:

**Bytecode Opcodes:**
- `OP_REGISTER_WHENEVER` - Registers a section with packed data Dictionary
- `OP_SUSPEND_WHENEVER` - Suspends monitoring by section name
- `OP_RESUME_WHENEVER` - Resumes monitoring of a suspended section

**Runtime Behavior:**
- Whenever sections are registered during function initialization
- The runtime monitors watched variables on each frame
- Conditions are evaluated efficiently using bytecode execution
- Local sections are automatically cleaned up when their scope ends

**Debugging Support:**
- All active sections visible in Immediate Window's "Whenever" tab
- Real-time status updates (Active/Paused)
- Right-click to pause/resume sections during gameplay
- Go to Definition to jump to section code

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

### Multitasking and Concurrency

VisualGasic's **Multitasking System** provides world-class asynchronous programming, parallel processing, and concurrency capabilities that rival and often surpass those found in modern languages like C#, TypeScript, and Kotlin. The system combines the simplicity of VB.NET async/await with the power of advanced parallel programming frameworks.

As of v3.1, all multitasking primitives are backed by **real `std::thread`** with per-thread scope cloning:

- **`Task.Run`** — spawns a real OS thread; variable scope is cloned via `Dictionary.duplicate(true)` so each thread gets independent state
- **`Parallel For`** — partitions the iteration space across `hardware_concurrency()` worker threads; falls back to serial execution for ≤4 iterations to avoid thread overhead
- **`Parallel Section`** — uses an atomic work-stealing pattern with `std::atomic<int>` next-item counter, spawning up to max-cores threads

#### Async/Await Programming

Create responsive applications with non-blocking asynchronous operations using familiar async/await syntax:

```vb
' Async function declaration
Async Function LoadPlayerDataAsync() As Task(Of PlayerData)
    ' Non-blocking database query
    Dim result = Await DatabaseQuery("SELECT * FROM players WHERE id = ?", playerId)
    
    ' Process result asynchronously
    Dim processed = Await ProcessPlayerStats(result)
    
    ' Async validation
    Dim validated = Await ValidatePlayerData(processed)
    
    Return validated
End Function

' Calling async functions
Sub GameInitialization()
    ' Start loading player data
    Dim playerTask = LoadPlayerDataAsync()
    
    ' Continue with other initialization
    LoadUIElements()
    InitializeAudio()
    SetupGameWorld()
    
    ' Wait for player data when needed
    Dim playerData = Await playerTask
    Print "Player loaded: " & playerData.Name
End Sub

' Multiple async operations
Async Sub LoadGameAssets()
    ' Parallel async operations
    Dim textureTask = LoadTexturesAsync()
    Dim soundTask = LoadSoundsAsync()
    Dim modelTask = LoadModelsAsync()
    
    ' Wait for all to complete
    Dim textures = Await textureTask
    Dim sounds = Await soundTask
    Dim models = Await modelTask
    
    Print "All assets loaded!"
End Sub
```

#### Background Task Processing

Execute long-running operations in background threads without blocking the main thread:

```vb
' Background data processing
Task.Run BackgroundAnalytics
    For i = 1 To 1000000
        ProcessAnalyticsEvent(events(i))
        
        ' Periodic progress update to main thread
        If i Mod 10000 = 0 Then
            UpdateProgressBar(i / 10000)
        End If
    Next
    
    SaveAnalyticsResults()
    NotifyCompletion()
End Task

' Named tasks for coordination
Task.Run SaveGameTask
    SerializeGameState()
    CompressGameData() 
    WriteToStorage()
    Print "Game saved successfully"
End Task

Task.Run BackupTask
    CreateBackupCopy()
    UploadToCloud()
    Print "Backup completed"
End Task

' Wait for both tasks
Task.WaitAll(SaveGameTask, BackupTask)
Print "All save operations completed"
```

#### Parallel Processing

Leverage multi-core processors with parallel loops and sections:

```vb
' Parallel For loops - automatic work distribution
Parallel For i = 0 To enemies.Count - 1
    enemies(i).UpdateAI()
    enemies(i).ProcessCollisions()
    enemies(i).UpdateAnimation()
Next

' Parallel processing with custom work distribution
Dim particleSystems(1000) As ParticleSystem
Parallel For particle = 0 To 999
    particleSystems(particle).Update(deltaTime)
    particleSystems(particle).CheckBounds()
    particleSystems(particle).ApplyPhysics()
Next

' Parallel sections for different operations
Parallel Section HighPriority
    ProcessPlayerInput()
    UpdateCameraSystem()
    ProcessAudio()
    
    ' Nested parallel processing
    Parallel For effect = 0 To activeEffects.Count - 1
        activeEffects(effect).Update()
    Next
End Section
```

#### Task Coordination and Synchronization

Coordinate multiple tasks with advanced synchronization:

```vb
' Task coordination example
Sub ComplexGameOperation()
    ' Start multiple related tasks
    Task.Run PhysicsTask
        UpdateRigidBodies()
        ProcessCollisions()
        ApplyForces()
    End Task
    
    Task.Run RenderingTask
        CullObjects()
        UpdateShaders()
        ProcessLighting()
    End Task
    
    Task.Run AITask
        For Each npc In gameWorld.NPCs
            npc.ProcessBehavior()
            npc.UpdateDecisionTree()
        Next
    End Task
    
    ' Wait for critical tasks before proceeding
    Task.WaitAll(PhysicsTask, RenderingTask)
    
    ' Continue with tasks that depend on physics/rendering
    Task.Run PostProcessingTask
        ApplyScreenEffects()
        ProcessParticles() 
        UpdateUI()
    End Task
    
    ' Wait for any single task to complete (first-wins scenario)
    Dim completedTask = Task.WaitAny(AITask, PostProcessingTask)
    
    If completedTask = AITask Then
        Print "AI processing completed first"
    Else
        Print "Post-processing completed first"
    End If
End Sub
```

#### Thread-Safe Reactive Programming

Combine multitasking with the Whenever system for concurrent reactive programming:

```vb
' Thread-safe Whenever monitoring across parallel tasks
Whenever Section Parallel SystemMonitor
    cpuUsage Changes LogPerformance, CheckCriticalLevels
    memoryUsage Exceeds 80 TriggerGarbageCollection
    frameRate Below 30 ReduceQualitySettings
End Whenever

' Parallel tasks updating monitored variables safely
Task.Run MonitoringTask1
    For i = 1 To 100
        cpuUsage = GetCPUUsage()
        memoryUsage = GetMemoryUsage()
        frameRate = Engine.GetFramesPerSecond()
        
        ' Whenever callbacks triggered thread-safely
        Thread.Sleep(100)
    Next
End Task

Task.Run MonitoringTask2
    For i = 1 To 50
        cpuUsage = cpuUsage + GetAdditionalLoad()
        
        ' Complex concurrent conditions
        If memoryUsage > 75 And frameRate < 45 Then
            OptimizeResources()
        End If
    Next
End Task

' Both tasks can safely trigger Whenever callbacks
Task.WaitAll(MonitoringTask1, MonitoringTask2)
```

#### Error Handling in Async Context

Robust error handling across asynchronous operations:

```vb
Async Function RobustAsyncOperation() As Task(Of String)
    Try
        ' Parallel async operations with error handling
        Dim dataTask = LoadDataAsync()
        Dim configTask = LoadConfigAsync()
        
        ' Wait with timeout
        Dim result = Await dataTask.WithTimeout(5000)
        Dim config = Await configTask.WithTimeout(3000)
        
        Return ProcessResultAndConfig(result, config)
        
    Catch timeoutEx As TimeoutException
        Print "Operation timed out: " & timeoutEx.Message
        Return GetCachedData()
        
    Catch networkEx As NetworkException
        Print "Network error: " & networkEx.Message
        Return GetOfflineData()
        
    Catch ex As Exception
        Print "Unexpected error: " & ex.Message
        Throw ' Re-throw for higher-level handling
        
    Finally
        ' Always cleanup resources
        CleanupNetworkConnections()
        CleanupTempFiles()
    End Try
End Function

' Task error handling
Task.Run RiskyOperation
    Try
        ProcessRiskyData()
    Catch ex As Exception
        LogError(ex)
        NotifyUser("Background operation failed")
    End Try
End Task
```

#### Performance Optimizations

Advanced multitasking patterns for maximum performance:

```vb
' CPU-intensive parallel processing
Sub OptimizedParallelProcessing()
    Dim dataChunks = SplitDataIntoChunks(bigDataSet, Environment.ProcessorCount)
    
    Parallel For chunk = 0 To dataChunks.Count - 1
        ProcessDataChunk(dataChunks(chunk))
    Next
End Sub

' Memory-efficient async streaming
Async Function StreamLargeFile() As Task
    Using fileStream = New FileStream("large_file.dat")
        Dim buffer(8192) As Byte
        
        While Not fileStream.AtEnd
            Dim bytesRead = Await fileStream.ReadAsync(buffer)
            Await ProcessBufferAsync(buffer, bytesRead)
        End While
    End Using
End Function

' Lock-free concurrent data structures
Sub ConcurrentDataProcessing()
    Dim concurrentQueue As New ConcurrentQueue(Of GameEvent)
    Dim concurrentDict As New ConcurrentDictionary(Of String, PlayerData)
    
    ' Producer tasks
    Task.Run EventProducer
        For i = 1 To 1000
            concurrentQueue.Enqueue(CreateGameEvent(i))
        Next
    End Task
    
    ' Consumer tasks  
    Task.Run EventConsumer1
        While Not concurrentQueue.IsEmpty
            Dim gameEvent
            If concurrentQueue.TryDequeue(gameEvent) Then
                ProcessGameEvent(gameEvent)
            End If
        End While
    End Task
    
    Task.Run EventConsumer2
        While Not concurrentQueue.IsEmpty
            Dim gameEvent
            If concurrentQueue.TryDequeue(gameEvent) Then
                ProcessGameEvent(gameEvent)
            End If  
        End While
    End Task
End Sub
```

#### Real-World Example: Game Engine Integration

Complete example integrating all multitasking features:

```vb
' Advanced game loop with multitasking
Async Sub GameLoop()
    ' Initialize concurrent systems
    Whenever Section Parallel PerformanceMonitor
        frameRate Below 30 ReduceQuality
        memoryUsage Exceeds 512 TriggerGC
    End Whenever
    
    While gameRunning
        ' Parallel frame processing
        Parallel Section GameUpdate
            ' Physics runs on dedicated thread
            Task.Run PhysicsUpdate
                physicsWorld.Step(deltaTime)
                ProcessCollisions()
            End Task
            
            ' AI processing in parallel
            Task.Run AIUpdate  
                Parallel For i = 0 To activeAI.Count - 1
                    activeAI(i).Update(deltaTime)
                Next
            End Task
            
            ' Audio processing
            Task.Run AudioUpdate
                audioEngine.Update()
                ProcessSpatialAudio()
            End Task
        End Section
        
        ' Wait for critical systems
        Task.WaitAll(PhysicsUpdate, AIUpdate)
        
        ' Render frame (main thread)
        RenderFrame()
        
        ' Async operations that don't block frame
        Dim saveTask = SaveGameStateAsync()
        Dim analyticsTask = SendAnalyticsAsync()
        
        ' Don't wait - let them complete in background
        
        frameCount += 1
        Await NextFrame() ' Yield until next frame
    End While
End Sub
```

#### Multitasking Capabilities Summary

**🚀 Advanced Features:**
- **Async/Await**: Modern asynchronous programming with familiar syntax
- **Task Management**: Background task execution with coordination
- **Parallel Processing**: Automatic multi-core utilization
- **Thread-Safe Reactive**: Concurrent Whenever system monitoring
- **WorkerThreadPool Integration**: Godot's optimized threading system

**🔥 Performance Benefits:**
- **Multi-Core Scaling**: Automatic work distribution across CPU cores
- **Non-Blocking I/O**: Responsive UI during long operations
- **Memory Efficiency**: Lock-free data structures and minimal overhead
- **Godot Integration**: Native engine thread pool utilization

**🛡️ Safety and Reliability:**
- **Exception Handling**: Robust error propagation in async context
- **Resource Management**: Automatic cleanup and disposal
- **Deadlock Prevention**: Safe task coordination patterns
- **Memory Safety**: Garbage collection integration

#### Framework Comparison

VisualGasic's multitasking capabilities compare favorably with industry leaders:

| Feature | VisualGasic | C# async/await | TypeScript Promises | Kotlin Coroutines |
|---------|-------------|----------------|-------------------|------------------|
| Async/Await Syntax | ✅ | ✅ | ✅ | ✅ |
| Parallel Processing | ✅ | ✅ | ❌ | ⚠️ |
| Task Coordination | ✅ | ✅ | ⚠️ | ✅ |
| Thread Safety | ✅ | ⚠️ | ❌ | ✅ |
| Reactive Integration | ✅ | ❌ | ❌ | ❌ |
| Game Engine Integration | ✅ | ❌ | ❌ | ❌ |
| Zero-Copy Optimization | ✅ | ⚠️ | ❌ | ⚠️ |

**Most Advanced**: VisualGasic surpasses traditional async frameworks by seamlessly integrating reactive programming, parallel processing, and game engine optimization into a unified, safe, and performant multitasking system.

---

## v3.3.0 Language Enhancements

### String Interpolation

Build strings with embedded expressions using `$"..."` syntax:

```vb
Dim name As String = "World"
Print $"Hello, {name}!"           ' → Hello, World!
Print $"2 + 2 = {2 + 2}"         ' → 2 + 2 = 4
Print $"Upper: {UCase(name)}"     ' → Upper: WORLD
```

### Count() Function

Returns the number of elements in an Array, Dictionary, or characters in a String:

```vb
Dim arr() = Array(1, 2, 3)
Print Count(arr)    ' → 3

Dim d As Object
Set d = CreateObject("Scripting.Dictionary")
d.Add "a", 1
Print Count(d)      ' → 1

Print Count("Hello") ' → 5
```

### Debug.Print and Assert

```vb
Debug.Print "This goes to Immediate Window"

' Assert — halts execution if condition is False
Assert 1 + 1 = 2, "Math is broken"
Assert x > 0, "x must be positive"
```

### Print Semicolons (Multiple Expressions)

Use `;` to concatenate output, or trailing `;` to suppress newline:

```vb
Print "Hello"; " "; "World"     ' → Hello World
Print "Name: "; name; " Age: "; age
Print "No newline";             ' Trailing ; suppresses newline
```

### Spc() and Tab() Functions

```vb
Print "Col1"; Spc(5); "Col2"    ' 5 spaces between columns
Print "Col1"; Tab(20); "Col2"   ' Pad to column 20
```

### Array and Dictionary Literals

Create arrays with `[...]` and dictionaries with `{...}`:

```vb
Dim arr = [1, 2, 3, 4, 5]
Dim names = ["Alice", "Bob", "Charlie"]
Dim config = {"host": "localhost", "port": 8080, "debug": True}

For Each item In [10, 20, 30]
    Print item
Next
```

### On n GoTo / On n GoSub

Branch to one of several labels based on an expression value:

```vb
On choice GoTo Label1, Label2, Label3

' On n GoSub — calls subroutine at label, returns with Return
On menuItem GoSub HandleNew, HandleOpen, HandleSave
```

### Resume / Resume Next / Resume Label

Error recovery after On Error:

```vb
On Error GoTo ErrorHandler
' ... code that might fail ...
Exit Sub

ErrorHandler:
    Print "Error: "; Err.Description
    Resume Next    ' Continue at next statement
    ' or: Resume RetryLabel
    ' or: Resume  (retry the failing statement)
```

### Get # / Put # (Binary File I/O)

Read and write binary data:

```vb
Open "data.bin" For Binary As #1
Put #1, 1, "Hello World"      ' Write at record 1
Dim result As String
Get #1, 1, result              ' Read from record 1
Close #1
```

### Open For Binary / Open For Random

```vb
Open "file.dat" For Binary As #1
Open "records.dat" For Random As #2 Len=128
```

### Static Local Variables

Variables that persist across function calls:

```vb
Function Counter() As Integer
    Static count As Integer
    count = count + 1
    Counter = count
End Function

Print Counter()  ' → 1
Print Counter()  ' → 2
Print Counter()  ' → 3
```

### Regular Expressions

```vb
' Test if pattern matches
Dim matched = RegExp.Test("Hello123", "\d+")    ' → True

' Execute — returns array of matches
Dim matches = RegExp.Execute("abc 123 def 456", "\d+")
Print matches(0)  ' → 123
Print matches(1)  ' → 456

' Replace
Dim result = RegExp.Replace("Hello World", "World", "VG")
Print result  ' → Hello VG
```

### Bitwise Functions

```vb
Print BitAnd(12, 10)       ' → 8
Print BitOr(12, 10)        ' → 14
Print BitXor(12, 10)       ' → 6
Print BitNot(0)             ' → -1
Print BitShiftLeft(1, 4)   ' → 16
Print BitShiftRight(16, 2) ' → 4
```

### StringBuilder

Efficient string building:

```vb
Dim sb = NewStringBuilder()
sb.Append "Hello"
sb.Append " "
sb.Append "World"
sb.AppendLine "!"
Print sb.ToString()   ' → Hello World!\n
Print sb.Length        ' → 13

sb.Replace "World", "VG"
sb.Insert 0, ">> "
sb.Clear
```

### For Each With Index

```vb
Dim fruits = Array("Apple", "Banana", "Cherry")
For Each fruit With Index i In fruits
    Print $"{i}: {fruit}"
Next
' → 0: Apple
' → 1: Banana
' → 2: Cherry

' Also works with Strings:
For Each ch In "Hello"
    Print ch;
Next
```

### Enum Improvements

Access enum values by name, get all values, and convert to/from strings:

```vb
Enum Color
    Red = 1
    Green = 2
    Blue = 3
End Enum

' Direct member access
Print Color.Red          ' → 1

' Parse from string
Dim val = Color.Parse("Green")   ' → 2

' Get all values
Dim values = Color.Values()      ' → [{Name: "Red", Value: 1}, ...]

' Convert to string
Print Color.ToString(3)          ' → Blue
```

#### `<Flags>` Enum
Mark an enum as a bitfield with the `<Flags>` attribute. This enables `HasFlag()` and flags-aware `ToString()` decomposition:

```vb
<Flags>
Enum Permissions
    Read = 1
    Write = 2
    Execute = 4
End Enum

' Combine flags with Or
Dim p = Permissions.Read Or Permissions.Write   ' 3

' Check flags
Print Permissions.HasFlag(p, Permissions.Read)   ' True
Print Permissions.HasFlag(p, Permissions.Execute) ' False

' Flags ToString decomposes combined values
Print Permissions.ToString(3)    ' → "Read, Write"
Print Permissions.ToString(7)    ' → "Read, Write, Execute"
Print Permissions.ToString(5)    ' → "Read, Execute"

' Compound assignment with keyword operators
Dim mask = 0
mask Or= Permissions.Read        ' Add Read flag
mask Or= Permissions.Execute     ' Add Execute flag
mask And= Not(Permissions.Read)  ' Remove Read flag
mask Xor= Permissions.Execute    ' Toggle Execute flag
```

> **Note:** `ToString()` uses a greedy largest-first decomposition. If the combined value doesn't exactly decompose into named members, the raw integer is returned.

### Swap Statement

```vb
Dim a = 10, b = 20
Swap a, b
Print a  ' → 20
Print b  ' → 10
```

### Math Constants

```vb
Print Math.PI        ' → 3.14159...
Print Math.E         ' → 2.71828...
Print Math.Tau       ' → 6.28318...
Print PI             ' → 3.14159... (standalone)
```

### Math Functions

```vb
Print Ceiling(3.2)   ' → 4
Print Floor(3.8)     ' → 3
Print Atan2(1, 1)    ' → 0.7854... (π/4)
```

### Array Utility Functions

```vb
Dim arr = Array(3, 1, 4, 1, 5)

Dim copy = Array.Copy(arr)        ' Deep copy
Dim filled = Array.Fill(5, 0)     ' [0, 0, 0, 0, 0]
Array.Shuffle arr                  ' Random order

' 2D array transpose
Dim matrix = Array(Array(1, 2), Array(3, 4))
Dim transposed = Array.Transpose(matrix)
```

### String Utility Functions

```vb
Print String.Contains("Hello World", "World")  ' → True
Print StrContains("Hello", "xyz")               ' → False
Print String.Repeat("ab", 3)                    ' → ababab
Print StrRepeat("-", 20)                         ' → --------------------
```

### Sleep Function

```vb
Sleep 1000   ' Pause for 1000 milliseconds
```

### VB6 Intrinsic Constants

```vb
Print "Line 1" & vbCrLf & "Line 2"
Print "Col1" & vbTab & "Col2"
Dim empty = vbNullString

' All available constants:
' vbCrLf, vbCr, vbLf, vbTab, vbNullString, vbNullChar
' vbNewLine, vbBack, vbFormFeed, vbVerticalTab
' vbTrue, vbFalse, Nothing, Null, Empty
```

### Module Statement

Group related code into named modules:

```vb
Module MathHelpers
    Function Square(x) As Double
        Square = x * x
    End Function
    
    Function Cube(x) As Double
        Cube = x * x * x
    End Function
End Module
```

---

## v3.5.0-beta4 Language Enhancements
*Released in v3.5.0-beta4.* This release adds core VB6 desktop-application features to bring VisualGasic closer to full VB6 parity.

### WithEvents / RaiseEvent
Full VB6-style custom event support:

- **`Event`** — declare a custom event (compiles to a Godot signal).
- **`RaiseEvent`** — fire the event (dedicated `OP_RAISE_EVENT` bytecode opcode, supports up to 5 arguments).
- **`Dim WithEvents`** — declare a variable whose events are auto-wired to `VarName_EventName` handler subs in the same module.

```vb
' Class module
Event DataReady(rows As Integer)

Sub LoadData()
    ' ... fetch data ...
    RaiseEvent DataReady(rowCount)
End Sub

' Form module
Dim WithEvents db As DatabaseLoader

Sub db_DataReady(rows As Integer)
    Label1.Caption = "Loaded " & CStr(rows) & " rows"
End Sub
```

See [Events (WithEvents / RaiseEvent)](#events-withevents--raiseevent) for full details.

### Implements Verification
When a module declares `Implements InterfaceName`, VisualGasic now verifies at load time that at least one method matching `InterfaceName_*` exists. If the interface is completely unimplemented, a warning is printed to the console:

```
VisualGasic: Module 'MyForm' declares Implements ISerializable but has no ISerializable_* methods
```

This catches missing interface implementations early without a hard runtime error.

### Printer Object & PrintForm
The global `Printer` object provides 20+ VB6-compatible properties and methods for generating printed output (font, orientation, page control, drawing primitives). `PrintForm` captures the current viewport to a PNG file.

```vb
Printer.Font = "Times New Roman"
Printer.FontSize = 14
Printer.Print "Report Title"
Printer.NewPage
Printer.Print "Page 2"
Printer.EndDoc

PrintForm   ' → saves user://printform_output.png
```

See [Printer Object](#printer-object) and [PrintForm Statement](#printform-statement) for full property/method tables.

### Optional Parameters
Optional parameters with default values have been fully supported and continue to work as expected:

```vb
Sub CreateWindow(title As String, Optional width As Integer = 800, Optional height As Integer = 600)
    ' width and height default to 800×600 if omitted
End Sub

CreateWindow("Main")              ' Uses defaults
CreateWindow("Main", 1024, 768)   ' Override both
```

The VM automatically fills missing arguments with their declared default values at call time.

---

## v3.6.0 Language Enhancements
*Released in v3.6.0.* This release adds essential VB.NET/TwinBASIC operators and a 64-bit integer type alias.

### Compound Assignment Operators
Compound assignment operators combine a binary operation with assignment. They are desugared at parse time into the equivalent `x = x op expr` form, so they work on any valid L-value (simple variable, array element, object member).

| Operator | Equivalent | Description |
|----------|------------|-------------|
| `+=` | `x = x + y` | Addition |
| `-=` | `x = x - y` | Subtraction |
| `*=` | `x = x * y` | Multiplication |
| `/=` | `x = x / y` | Division |
| `&=` | `x = x & y` | String concatenation |
| `\=` | `x = x \ y` | Integer division |
| `^=` | `x = x ^ y` | Exponentiation |
| `<<=` | `x = x << y` | Left bit-shift |
| `>>=` | `x = x >> y` | Right bit-shift |
| `And=` | `x = x And y` | Bitwise AND |
| `Or=` | `x = x Or y` | Bitwise OR |
| `Xor=` | `x = x Xor y` | Bitwise XOR |
| `Mod=` | `x = x Mod y` | Modulo |

```vb
Dim score As Integer = 100
score += 50        ' 150
score -= 25        ' 125
score *= 2         ' 250

Dim msg As String = "Hello"
msg &= " World"    ' "Hello World"

Dim flags As Integer = 1
flags <<= 8        ' 256
flags >>= 4        ' 16
```

### Bit-Shift Operators
The `<<` (left shift) and `>>` (right shift) operators perform bitwise shifting on integer values, matching VB.NET/TwinBASIC syntax.

```vb
Dim a As Integer = 1 << 8     ' 256
Dim b As Integer = 256 >> 4   ' 16
Dim c As Integer = 5 << 3     ' 40
```

**Precedence:** Bit-shift operators bind *tighter* than comparison operators but *looser* than arithmetic (`+`, `-`, `*`, `/`). This matches VB.NET:

```vb
' 1 << 2 + 1  is parsed as  1 << (2 + 1)  = 1 << 3 = 8
' (1 << 3) = 8  is a comparison: True
```

**Typical use cases:**
- Bitmask construction: `Dim mask As Integer = 1 << bitIndex`
- Efficient power-of-2 multiply/divide: `value = n << 2` (×4)
- Flag manipulation: `flags = flags Or (1 << FLAG_BIT)`

### LongLong Type
`LongLong` is a type alias for `Long` (64-bit signed integer). It is provided for compatibility with VBA 7+ / TwinBASIC code that declares 64-bit integers explicitly.

```vb
Dim big As LongLong = 2147483648    ' Exceeds 32-bit range
Dim huge As LongLong = 1000000 * 1000000  ' 1 trillion

' CLngLng() conversion function
Dim rounded As LongLong = CLngLng(3.7)  ' 4 (banker's rounding)
```

`LongLong` variables:
- Default to `0` on declaration
- Work with all arithmetic, comparison, and bit-shift operators
- Can be used as array element types: `Dim arr(9) As LongLong`
- Are interchangeable with `Long` in all contexts

---

## v3.7.0 Language Enhancements
*Released in v3.7.0.* This release adds method overloading, parameterized constructors, generic typed collections, and a game UI mode for the form designer.

### Method Overloading
Define multiple `Sub` or `Function` with the same name but different parameter counts. The runtime resolves to the best match by argument count (arity-based dispatch).

```vb
Sub Spawn(x As Single, y As Single)
    ' 2-arg: default speed/angle
End Sub

Sub Spawn(x As Single, y As Single, speed As Single, angle As Single)
    ' 4-arg: full control
End Sub

Spawn 10, 20            ' → calls 2-arg version
Spawn 10, 20, 300, 45   ' → calls 4-arg version
```

Class methods also support overloading:

```vb
Class Calculator
    Function Add(a As Integer) As Integer
        Return a
    End Function
    Function Add(a As Integer, b As Integer) As Integer
        Return a + b
    End Function
End Class
```

### Parameterized Constructors
Pass arguments to `Class_Initialize` when creating objects:

```vb
Class Bullet
    Public speed As Double, angle As Double, damage As Integer
    Sub Class_Initialize(s As Double, a As Double, d As Integer)
        speed = s : angle = a : damage = d
    End Sub
End Class

Dim b1 = New Bullet(300, 45, 10)       ' inline New
Dim b2 As New Bullet(200, 90, 25)      ' Dim As New
```

### Generics — Collection(Of T)
Type-safe collections with runtime type validation on `.Add()`:

```vb
Dim scores As New Collection(Of Integer)
scores.Add 100   ' OK
scores.Add 200   ' OK

Dim names As New Collection(Of String)
names.Add "Alice"

' Auto-instantiation without New:
Dim items As Collection(Of Double)
items.Add 3.14

' Supported type parameters: Integer, Long, LongLong, Double, Single,
' Float, String, Boolean, Variant, and any class name.
```

### Game UI Mode
The Form Designer supports a **Game UI Mode** that generates `CanvasLayer` overlays for in-game HUD elements instead of standalone `Window` nodes.

- Set the form property `GameUIMode = True` to enable
- Dark canvas background with crosshair guides and safe area rectangle
- Exports `CanvasLayer` root (layer 10) with full-rect anchored `Control` child
- 11 new Game UI toolbox controls: HealthBar, ScoreLabel, DialogBox, MiniMap, Inventory, ActionButton, AmmoCounter, BossBar, Crosshair, Tooltip, Pointer

---

## v3.8.0 Language Enhancements
*Released in v3.8.0.* This release completes the v3.6 roadmap by adding keyword compound assignment operators and enhancing Enums with `<Flags>` attribute support.

### Keyword Compound Assignment Operators
Four new compound assignment operators that use VB keywords instead of symbolic operators:

| Operator | Equivalent | Description |
|----------|------------|-------------|
| `And=` | `x = x And y` | Bitwise AND assignment |
| `Or=` | `x = x Or y` | Bitwise OR assignment |
| `Xor=` | `x = x Xor y` | Bitwise XOR assignment |
| `Mod=` | `x = x Mod y` | Modulo assignment |

```vb
Dim flags As Integer = 15       ' 1111 in binary
flags And= 6                    ' 0110 → flags = 6
flags Or= 8                     ' 1110 → flags = 14
flags Xor= 2                    ' 1100 → flags = 12
Dim remainder As Integer = 17
remainder Mod= 5                ' 2
```

These operators are desugared at parse time, just like `+=` and `-=`. They work on any L-value (simple variable, array element, object member).

### Bitwise And/Or/Xor Semantics
`And`, `Or`, and `Xor` now perform **bitwise** operations when both operands are numeric, matching VB6 semantics:

```vb
' Bitwise (both operands are numeric)
Print 12 And 10     ' → 8   (1100 & 1010 = 1000)
Print 12 Or 3       ' → 15  (1100 | 0011 = 1111)
Print 12 Xor 10     ' → 6   (1100 ^ 1010 = 0110)

' Logical (non-numeric operands — unchanged behaviour)
If x > 0 And y > 0 Then ...    ' logical AND
If a Or b Then ...              ' logical OR
```

### Enhanced Enum with `<Flags>`
The `<Flags>` attribute marks an enum as a bitfield, enabling two new capabilities:

**`HasFlag(value, flag)`** — Tests whether a combined value contains a specific flag:

```vb
<Flags>
Enum Layers
    Ground = 1
    Water = 2
    Air = 4
    All = 7
End Enum

Dim mask = Layers.Ground Or Layers.Air   ' 5
Print Layers.HasFlag(mask, Layers.Ground)  ' True
Print Layers.HasFlag(mask, Layers.Water)   ' False
Print Layers.HasFlag(mask, Layers.All)     ' False (5 And 7 ≠ 7)
```

**Flags-aware `ToString()`** — Decomposes combined values into named members:

```vb
Print Layers.ToString(5)   ' → "Ground, Air"
Print Layers.ToString(7)   ' → "All"  (exact match takes priority)
Print Layers.ToString(3)   ' → "Ground, Water"
```

### Compile-Time Enum Resolution
Enum member access (`MyEnum.MemberName`) is now resolved at compile time in the bytecode compiler. This eliminates runtime member lookups and produces a simple constant-load instruction.

---
This documentation provides a comprehensive overview of VisualGasic's advanced capabilities and modern language features. The format is professional and showcases VisualGasic as a powerful, contemporary programming language for cross-platform application and game development.

---

---

## Alphabetical Index

*Quick-jump: [#](#index-symbols) · [A](#index-a) · [B](#index-b) · [C](#index-c) · [D](#index-d) · [E](#index-e) · [F](#index-f) · [G](#index-g) · [I](#index-i) · [J](#index-j) · [K](#index-k) · [L](#index-l) · [M](#index-m) · [N](#index-n) · [O](#index-o) · [P](#index-p) · [R](#index-r) · [S](#index-s) · [T](#index-t) · [U](#index-u) · [V](#index-v) · [W](#index-w) · [Y](#index-y)*


### #
- **#built-in-functions** — [Built-in Functions](#built-in-functions)
- **#com-style-objects** — [COM-Style Objects](#com-style-objects)
- **#control-flow** — [Control Flow](#control-flow)
- **#getting-started** — [Getting Started](#getting-started)
- **#godot-integration** — [Godot Integration](#godot-integration)
- **#language-basics** — [Language Basics](#language-basics)
- **#modern-language-features** — [Modern Language Features](#modern-language-features)
- **#object-oriented-features** — [Object-Oriented Features](#object-oriented-features)
- **#procedures-and-functions** — [Procedures and Functions](#procedures-and-functions)
- **#system-integration** — [System Integration](#system-integration)
- **#system-level-programming** — [System-Level Programming](#system-level-programming)
- **#v350-beta4-language-enhancements** — [v3.5.0-beta4 Language Enhancements](#v350-beta4-language-enhancements)
- **#v360-language-enhancements** — [v3.6.0 Language Enhancements](#v360-language-enhancements)
- **#v370-language-enhancements** — [v3.7.0 Language Enhancements](#v370-language-enhancements)
- **#vb6-global-objects** — [VB6 Global Objects](#vb6-global-objects)
- **<Flags> Enum** — [<Flags> Enum](#flags-enum)
- **[Built-in Functions]** — [Built-in Functions](#built-in-functions)
- **COM-Style Objects** — [COM-Style Objects](#com-style-objects)
- **[Control Flow]** — [Control Flow](#control-flow)
- **[Getting Started]** — [Getting Started](#getting-started)
- **[Godot Integration]** — [Godot Integration](#godot-integration)
- **[Language Basics]** — [Language Basics](#language-basics)
- **[Modern Language Features]** — [Modern Language Features](#modern-language-features)
- **[Object-Oriented Features]** — [Object-Oriented Features](#object-oriented-features)
- **[Procedures and Functions]** — [Procedures and Functions](#procedures-and-functions)
- **System Integration** — [System Integration](#system-integration)
- **System-Level Programming** — [System-Level Programming](#system-level-programming)
- **[v3.5.0-beta4 Language Enhancements]** — [v3.5.0-beta4 Language Enhancements](#v350-beta4-language-enhancements)
- **[v3.6.0 Language Enhancements]** — [v3.6.0 Language Enhancements](#v360-language-enhancements)
- **[v3.7.0 Language Enhancements]** — [v3.7.0 Language Enhancements](#v370-language-enhancements)
- **VB6 Global Objects** — [VB6 Global Objects](#vb6-global-objects)

### A
- **Advanced Complex Expressions** — [Advanced Complex Expressions](#advanced-complex-expressions)
- **Advanced Cross-Language Features** — [Advanced Cross-Language Features](#advanced-cross-language-features)
- **Advanced Features** — [Advanced Features](#advanced-features)
- **Advanced Patterns and Best Practices** — [Advanced Patterns and Best Practices](#advanced-patterns-and-best-practices)
- **AI Functions** — [AI Functions](#ai-functions)
- **App Object** — [App Object](#app-object)
- **Arithmetic Operators** — [Arithmetic Operators](#arithmetic-operators)
- **Array Access Normalization** — [5. Array Access Normalization](#5-array-access-normalization)
- **Array and Dictionary Literals** — [Array and Dictionary Literals](#array-and-dictionary-literals)
- **Array Functions** — [Array Functions](#array-functions)
- **Array Utility Functions** — [Array Utility Functions](#array-utility-functions)
- **Async/Await Programming** — [Async/Await Programming](#asyncawait-programming)
- **Async/Parallel Programming** — [Async/Parallel Programming (Multitasking)](#asyncparallel-programming-multitasking)
- **Audio** — [Audio](#audio)

### B
- **Background Task Processing** — [Background Task Processing](#background-task-processing)
- **Basic DATA and READ** — [Basic DATA and READ](#basic-data-and-read)
- **Binary File I/O** — [Get # / Put # (Binary File I/O)](#get-put-binary-file-io)
- **Bit-Shift Operators** — [Bit-Shift Operators](#bit-shift-operators) · [Bit-Shift Operators](#bit-shift-operators)
- **Bitwise And/Or/Xor Semantics** — [Bitwise And/Or/Xor Semantics](#bitwise-semantics-v380)
- **Bitwise Functions** — [Bitwise Functions](#bitwise-functions)
- **Built-in Functions** — [Built-in Functions](#built-in-functions)
- **Built-in Functions & Statements** — [Built-in Functions & Statements](#built-in-functions-statements)

### C
- **Classes and Types** — [Classes and Types](#classes-and-types)
- **Classic DATA Statements** — [Classic DATA Statements](#classic-data-statements)
- **Classic Use Cases** — [Classic Use Cases](#classic-use-cases)
- **Classic VB6 Style** — [File I/O Functions (Classic VB6 Style)](#file-io-functions-classic-vb6-style)
- **ClearData Statement** — [ClearData Statement](#cleardata-statement)
- **Clipboard Functions** — [Clipboard Functions](#clipboard-functions)
- **Code Navigator** — [Code Navigator](#code-navigator)
- **Code Transformation** — [Code Transformation](#code-transformation)
- **Collections & Iteration** — [Collections & Iteration](#collections-iteration)
- **Collision Detection** — [Collision Detection](#collision-detection)
- **Color Functions** — [Color Functions](#color-functions)
- **COM-Style Objects** — [COM-Style Objects](#com-style-objects)
- **Comments** — [Comments](#comments)
- **Comparison Operators** — [Comparison Operators](#comparison-operators)
- **Comparison with Other Frameworks** — [Comparison with Other Frameworks](#comparison-with-other-frameworks)
- **Compile-Time Enum Resolution** — [Compile-Time Enum Resolution](#compile-time-enum-v380)
- **Complete Alphabetical Index** — [Complete Alphabetical Index](#complete-alphabetical-index)
- **Complete Cross-Language Compatibility Matrix** — [Complete Cross-Language Compatibility Matrix](#complete-cross-language-compatibility-matrix)
- **Compound Assignment Operators** — [Compound Assignment Operators](#compound-assignment-operators) · [Compound Assignment Operators](#compound-assignment-operators)
- **Conditional Statements** — [Conditional Statements](#conditional-statements)
- **Control Arrays** — [Control Arrays](#control-arrays)
- **Control Flow** — [Control Flow](#control-flow)
- **Core Language Keywords** — [Core Language Keywords](#core-language-keywords)
- **Core Whenever Concepts** — [Core Whenever Concepts](#core-whenever-concepts)
- **Count** — [Count() Function](#count-function)
- **Cross-Platform System Classes** — [Cross-Platform System Classes](#cross-platform-system-classes)

### D
- **Data Introspection Functions** — [Data Introspection Functions](#data-introspection-functions)
- **Data Processing** — [Data Processing](#data-processing)
- **Data Types** — [Data Types](#data-types)
- **Data Types & Literals** — [Data Types & Literals](#data-types-literals)
- **Database Functions** — [Database Functions](#database-functions)
- **DataFile** — [DataFile — Load from External Files](#datafile-load-from-external-files)
- **DataFromString Statement** — [DataFromString Statement](#datafromstring-statement)
- **Date/Time Functions** — [Date/Time Functions](#datetime-functions)
- **Debouncing and Performance Control** — [Debouncing and Performance Control](#debouncing-and-performance-control)
- **Debug.Print and Assert** — [Debug.Print and Assert](#debugprint-and-assert)
- **Debugging and Monitoring Tools** — [Debugging and Monitoring Tools](#debugging-and-monitoring-tools)
- **Debugging Statements** — [Debugging Statements](#debugging-statements)
- **Declaring and Raising Events** — [Declaring and Raising Events](#declaring-and-raising-events)
- **Dictionary Functions** — [Dictionary Functions](#dictionary-functions)
- **Do-Loop** — [Do-Loop](#do-loop)
- **Drawing Primitives** — [Drawing Primitives](#drawing-primitives)

### E
- **Editor Shortcuts** — [Editor Shortcuts](#editor-shortcuts)
- **Empty Data Slots** — [Empty Data Slots](#empty-data-slots)
- **Enhanced Enum with <Flags>** — [Enhanced Enum with <Flags>](#enhanced-enum-v380)
- **Enum Improvements** — [Enum Improvements](#enum-improvements)
- **Err Object** — [Err Object](#err-object)
- **Error Handling** — [Error Handling](#error-handling)
- **Error Handling in Async Context** — [Error Handling in Async Context](#error-handling-in-async-context)
- **Event Wiring at a Glance** — [Event Wiring at a Glance](#event-wiring-at-a-glance)
- **Event-Driven Programming with Whenever** — [Event-Driven Programming with Whenever](#event-driven-programming-with-whenever)
- **Events** — [Events (WithEvents / RaiseEvent)](#events-withevents--raiseevent)
- **Extended** — [String Functions (Extended)](#string-functions-extended)
- **Extended Array Functions** — [Extended Array Functions](#extended-array-functions)

### F
- **File I/O Functions** — [File I/O Functions (Classic VB6 Style)](#file-io-functions-classic-vb6-style)
- **File I/O Statements** — [File I/O Statements](#file-io-statements)
- **File Operations** — [File Operations](#file-operations)
- **File System** — [File System](#file-system)
- **File System Functions** — [File System Functions](#file-system-functions)
- **For Each With Index** — [For Each With Index](#for-each-with-index)
- **For-Each Loop** — [For-Each Loop](#for-each-loop)
- **For-Next Loop** — [For-Next Loop](#for-next-loop)
- **Framework Comparison** — [Framework Comparison](#framework-comparison)
- **Function Declaration Auto-Completion** — [1. Function Declaration Auto-Completion](#1-function-declaration-auto-completion)
- **Functions** — [Functions](#functions)

### G
- **Game and Application Development Functions** — [Game and Application Development Functions](#game-and-application-development-functions)
- **Game Data Example** — [Game Data Example](#game-data-example)
- **Game Development** — [Game Development](#game-development)
- **Game UI Mode** — [Game UI Mode](#game-ui-mode) · [Game UI Mode](#game-ui-mode-v370)
- **Generics Phase 1 — Collection(Of T)** — [Generics Phase 1 — Collection(Of T)](#generics-phase-1--collectionof-t)
- **Generics — Collection** — [Generics — Collection(Of T)](#generics-v370)
- **Get # / Put #** — [Get # / Put # (Binary File I/O)](#get-put-binary-file-io)
- **Getting Started** — [Getting Started](#getting-started)
- **Godot Class Enum Constants** — [Godot Class Enum Constants](#godot-class-enum-constants)
- **Godot Integration** — [Godot Integration](#godot-integration)
- **Godot Singleton Access** — [Godot Singleton Access](#godot-singleton-access)
- **GoSub** — [GoSub / Return](#gosub-return)
- **Graphics & Drawing — Image Manipulation** — [Graphics & Drawing — Image Manipulation](#graphics-drawing-image-manipulation)
- **Graphics & Drawing — Native Image Drawing** — [Graphics and Drawing: Native Image Drawing](#graphics-and-drawing-native-image-drawing)
- **Graphics & Drawing — Primitives** — [Graphics & Drawing — Primitives](#graphics-drawing-primitives)

### I
- **I/O Operations** — [I/O Operations](#io-operations)
- **If-Then-Else** — [If-Then-Else](#if-then-else)
- **IIf Function** — [IIf Function (Ternary Operator)](#iif-function-ternary-operator)
- **Image & Texture Manipulation** — [Image & Texture Manipulation](#image-texture-manipulation)
- **Immediate Window** — [Immediate Window](#immediate-window)
- **Implementation Notes** — [Implementation Notes](#implementation-notes)
- **Implements Verification** — [Implements Verification](#implements-verification)
- **Import Report** — [Import Report](#import-report)
- **Importing VB6 Projects** — [Importing VB6 Projects](#importing-vb6-projects)
- **Incomplete Control Structure Completion** — [6. Incomplete Control Structure Completion](#6-incomplete-control-structure-completion)
- **Inheritance** — [Inheritance](#inheritance)
- **Input Functions** — [Input Functions](#input-functions)
- **Input Handling** — [Input Handling](#input-handling)
- **Installation** — [Installation](#installation)
- **Interfaces** — [Interfaces](#interfaces)

### J
- **JSON Functions** — [JSON Functions](#json-functions)

### K
- **Keyword Compound Assignment Operators** — [Keyword Compound Assignment Operators](#keyword-compound-assignment-operators) · [Keyword Compound Assignment Operators](#keyword-compound-assignment-v380)
- **Keyword Usage Notes** — [Keyword Usage Notes](#keyword-usage-notes)
- **Keywords Reference** — [Keywords Reference](#keywords-reference)

### L
- **Labeled Data Sections** — [Labeled Data Sections](#labeled-data-sections)
- **Lambda Expressions** — [Lambda Expressions](#lambda-expressions)
- **Language Basics** — [Language Basics](#language-basics)
- **LoadData** — [LoadData — Runtime File Loading](#loaddata-runtime-file-loading)
- **Logical Operators** — [Logical Operators](#logical-operators)
- **LongLong Type** — [LongLong Type](#longlong-type)
- **Loop Pattern Shortcuts** — [4. Loop Pattern Shortcuts](#4-loop-pattern-shortcuts)
- **Loops** — [Loops](#loops)

### M
- **Math Constants** — [Math Constants](#math-constants)
- **Math Functions** — [Math Functions](#math-functions)
- **Mathematical Functions** — [Mathematical Functions](#mathematical-functions)
- **Menu Editor** — [Menu Editor](#menu-editor)
- **Method Overloading** — [Method Overloading](#method-overloading) · [Method Overloading](#method-overloading-v370)
- **Methods** — [Methods](#methods)
- **Modern Features** — [Modern Features](#modern-features)
- **Modern File System Functions** — [Modern File System Functions](#modern-file-system-functions)
- **Modern Language Features** — [Modern Language Features](#modern-language-features)
- **Module Statement** — [Module Statement](#module-statement)
- **Multiple Callback Execution** — [Multiple Callback Execution](#multiple-callback-execution)
- **Multiple Expressions** — [Print Semicolons (Multiple Expressions)](#print-semicolons-multiple-expressions)
- **Multitasking** — [Async/Parallel Programming (Multitasking)](#asyncparallel-programming-multitasking)
- **Multitasking and Concurrency** — [Multitasking and Concurrency](#multitasking-and-concurrency)
- **Multitasking Capabilities Summary** — [Multitasking Capabilities Summary](#multitasking-capabilities-summary)

### N
- **Named Pipes** — [Named Pipes](#named-pipes)
- **NativeLibrary** — [NativeLibrary (FFI)](#nativelibrary-ffi)
- **NativeStruct** — [NativeStruct](#nativestruct)
- **Node Interaction** — [Node Interaction](#node-interaction)
- **Null-Safe Operations** — [Null-Safe Operations](#null-safe-operations)

### O
- **Object Browser** — [Object Browser](#object-browser)
- **Object-Oriented Features** — [Object-Oriented Features](#object-oriented-features)
- **Of T** — [Generics — Collection(Of T)](#generics-v370)
- **On Error Resume Next** — [On Error Resume Next](#on-error-resume-next)
- **On n GoSub** — [On n GoTo / On n GoSub](#on-n-goto-on-n-gosub)
- **On n GoTo** — [On n GoTo / On n GoSub](#on-n-goto-on-n-gosub)
- **Open For Binary** — [Open For Binary / Open For Random](#open-for-binary-open-for-random)
- **Open For Random** — [Open For Binary / Open For Random](#open-for-binary-open-for-random)
- **Operators** — [Operators](#operators)
- **Optional Parameters** — [Optional Parameters](#optional-parameters)

### P
- **Parallel Processing** — [Parallel Processing](#parallel-processing)
- **Parameterized Constructors** — [Parameterized Constructors](#parameterized-constructors) · [Parameterized Constructors](#parameterized-constructors-v370)
- **Parameters** — [Parameters](#parameters)
- **Pattern Matching** — [Pattern Matching](#pattern-matching)
- **Pattern Matching & Type Checking** — [Pattern Matching & Type Checking](#pattern-matching-type-checking)
- **Performance and Architecture** — [Performance and Architecture](#performance-and-architecture)
- **Performance Optimizations** — [Performance Optimizations](#performance-optimizations)
- **Performance: Data/Read vs Arrays** — [Performance: Data/Read vs Arrays](#performance-dataread-vs-arrays)
- **Print Semicolons** — [Print Semicolons (Multiple Expressions)](#print-semicolons-multiple-expressions)
- **Printer Object** — [Printer Object](#printer-object)
- **Printer Object & PrintForm** — [Printer Object & PrintForm](#printer-object--printform)
- **PrintForm Statement** — [PrintForm Statement](#printform-statement)
- **Procedures & Functions** — [Procedures & Functions](#procedures-functions)
- **Procedures and Functions** — [Procedures and Functions](#procedures-and-functions)
- **Programmatic Import API** — [Programmatic Import API](#programmatic-import-api)
- **Project Properties** — [Project Properties](#project-properties)
- **Properties** — [Properties](#properties)
- **Properties and Methods** — [Properties and Methods](#properties-and-methods)
- **Property Inspector** — [Property Inspector](#property-inspector)
- **Property Mapping** — [Property Mapping](#property-mapping)
- **Property/Method Chaining Assistance** — [7. Property/Method Chaining Assistance](#7-propertymethod-chaining-assistance)
- **Putting It All Together** — [Putting It All Together](#putting-it-all-together)

### R
- **Reactive Programming** — [Reactive Programming (Whenever System)](#reactive-programming-whenever-system)
- **Real COM Interop** — [Real COM Interop (Windows)](#real-com-interop-windows)
- **Real-World Example: Game Engine Integration** — [Real-World Example: Game Engine Integration](#real-world-example-game-engine-integration)
- **Regular Expressions** — [Regular Expressions](#regular-expressions)
- **Resource Loading** — [Resource Loading](#resource-loading)
- **RESTORE Statement** — [RESTORE Statement](#restore-statement)
- **Resume** — [Resume / Resume Next / Resume Label](#resume-resume-next-resume-label)
- **Resume Label** — [Resume / Resume Next / Resume Label](#resume-resume-next-resume-label)
- **Resume Next** — [Resume / Resume Next / Resume Label](#resume-resume-next-resume-label)
- **Return** — [GoSub / Return](#gosub-return)

### S
- **Safe Import/Using Statement Conversion** — [8. Safe Import/Using Statement Conversion](#8-safe-importusing-statement-conversion)
- **Scene Management** — [Scene Management](#scene-management)
- **Scope and Lifetime** — [Scope and Lifetime](#scope-and-lifetime)
- **Scoped Sections with Automatic Cleanup** — [Scoped Sections with Automatic Cleanup](#scoped-sections-with-automatic-cleanup)
- **Screen Object** — [Screen Object](#screen-object)
- **Select Case** — [Select Case](#select-case)
- **Shared Memory** — [Shared Memory](#shared-memory)
- **Signal System** — [Signal System](#signal-system)
- **Sleep Function** — [Sleep Function](#sleep-function)
- **Smart Variable Declaration System** — [Smart Variable Declaration System](#smart-variable-declaration-system)
- **Spc** — [Spc() and Tab() Functions](#spc-and-tab-functions)
- **Static Local Variables** — [Static Local Variables](#static-local-variables)
- **String Functions** — [String Functions](#string-functions) · [String Functions (Extended)](#string-functions-extended)
- **String Interpolation** — [String Interpolation](#string-interpolation)
- **String Interpolation Conversion** — [2. String Interpolation Conversion](#2-string-interpolation-conversion)
- **String Operators** — [String Operators](#string-operators)
- **String Utility Functions** — [String Utility Functions](#string-utility-functions)
- **StringBuilder** — [StringBuilder](#stringbuilder)
- **Subroutines** — [Subroutines](#subroutines)
- **Supported VB6 Controls** — [Supported VB6 Controls](#supported-vb6-controls)
- **Suspend and Resume Control** — [Suspend and Resume Control](#suspend-and-resume-control)
- **Swap Statement** — [Swap Statement](#swap-statement)
- **Syntax Overview** — [Syntax Overview](#syntax-overview)
- **System Functions** — [System Functions](#system-functions)
- **System Integration** — [System Integration](#system-integration)
- **System-Level Programming** — [System-Level Programming](#system-level-programming)
- **System/Environment Functions** — [System/Environment Functions](#systemenvironment-functions)

### T
- **Tab Order Editor** — [Tab Order Editor](#tab-order-editor)
- **Task Coordination and Synchronization** — [Task Coordination and Synchronization](#task-coordination-and-synchronization)
- **Ternary Operator** — [IIf Function (Ternary Operator)](#iif-function-ternary-operator)
- **Ternary Operator Conversion** — [3. Ternary Operator Conversion](#3-ternary-operator-conversion)
- **The VisualGasic IDE** — [The VisualGasic IDE](#the-visualgasic-ide)
- **Thread-Safe Reactive Programming** — [Thread-Safe Reactive Programming](#thread-safe-reactive-programming)
- **Toolbox Panel** — [Toolbox Panel](#toolbox-panel)
- **Type Checking Functions** — [Type Checking Functions](#type-checking-functions)
- **Type Conversion** — [Type Conversion](#type-conversion)
- **Type Inference** — [Type Inference](#type-inference)
- **Typed Read** — [Typed Read](#typed-read)

### U
- **UNIX Domain Sockets** — [UNIX Domain Sockets](#unix-domain-sockets)

### V
- **v3.3.0 Language Enhancements** — [v3.3.0 Language Enhancements](#v330-language-enhancements)
- **v3.5.0-beta4 Language Enhancements** — [v3.5.0-beta4 Language Enhancements](#v350-beta4-language-enhancements)
- **v3.6.0 Language Enhancements** — [v3.6.0 Language Enhancements](#v360-language-enhancements)
- **v3.7.0 Language Enhancements** — [v3.7.0 Language Enhancements](#v370-language-enhancements)
- **v3.8.0 Language Enhancements** — [v3.8.0 Language Enhancements](#v380-language-enhancements)
- **Variable Declaration** — [Variable Declaration](#variable-declaration)
- **Variables and Data Types** — [Variables and Data Types](#variables-and-data-types)
- **VB6 Compatibility** — [VB6 Compatibility](#vb6-compatibility)
- **VB6 Constants** — [VB6 Constants](#vb6-constants)
- **VB6 Functions** — [VB6 Functions](#vb6-functions)
- **VB6 Global Objects** — [VB6 Global Objects](#vb6-global-objects)
- **VB6 Intrinsic Constants** — [VB6 Intrinsic Constants](#vb6-intrinsic-constants)
- **VB6 Menu Support** — [VB6 Menu Support](#vb6-menu-support)
- **Vector Math Functions** — [Vector Math Functions](#vector-math-functions)
- **VGAndroidBridge** — [VGAndroidBridge (Android Platform)](#vgandroidbridge-android-platform)
- **VGCollection** — [VGCollection](#vgcollection)
- **VGCrypto** — [VGCrypto (Cryptography)](#vgcrypto-cryptography)
- **VGFilePermissions** — [VGFilePermissions (Permissions & Links)](#vgfilepermissions-permissions--links)
- **VGHttpRequest** — [VGHttpRequest](#vghttprequest)
- **VGIPC** — [VGIPC (Inter-Process Communication)](#vgipc-inter-process-communication)
- **VGMemoryBuffer** — [VGMemoryBuffer (Raw Memory)](#vgmemorybuffer-raw-memory)
- **VGOdbc** — [VGOdbc (Database)](#vgodbc-database)
- **VGRegEx** — [VGRegEx](#vgregex)
- **VGSignalHandler** — [VGSignalHandler (OS Signals)](#vgsignalhandler-os-signals)
- **VGSystem** — [VGSystem (System Info)](#vgsystem-system-info)
- **VGTask** — [VGTask (Async Tasks)](#vgtask-async-tasks)
- **VGTaskRunner** — [VGTaskRunner (Parallel)](#vgtaskrunner-parallel)
- **VGTimer** — [VGTimer](#vgtimer)
- **VGXml** — [VGXml (XML Processing)](#vgxml-xml-processing)
- **VGZip** — [VGZip (ZIP Archives)](#vgzip-zip-archives)
- **Visual Basic Heritage** — [Visual Basic Heritage](#visual-basic-heritage)
- **Visual Gasic IDE** — [Visual Gasic IDE](#visual-gasic-ide)
- **VisualGasicPackage** — [VisualGasicPackage (Package Manager)](#visualgasicpackage-package-manager)

### W
- **What is BASIC?** — [What is BASIC?](#what-is-basic)
- **Whenever System** — [Reactive Programming (Whenever System)](#reactive-programming-whenever-system)
- **While-Wend Loop** — [While-Wend Loop](#while-wend-loop)
- **Why DATA Statements?** — [Why DATA Statements?](#why-data-statements)
- **Windows** — [Real COM Interop (Windows)](#real-com-interop-windows)
- **WithEvents** — [WithEvents — Automatic Event Wiring](#withevents-automatic-event-wiring)
- **WithEvents / RaiseEvent** — [WithEvents / RaiseEvent](#withevents--raiseevent)

### Y
- **Your First Script** — [Your First Script](#your-first-script)

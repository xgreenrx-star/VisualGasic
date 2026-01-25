# VisualGasic Tutorials Collection
*Learn VisualGasic step by step with comprehensive tutorials*

## 📚 Tutorial Index

### 🎯 Beginner Level
1. **[Hello World - Your First Program](01_hello_world.md)**
2. **[Variables and Data Types](02_variables_types.md)**
3. **[Control Structures and Loops](03_control_structures.md)**
4. **[Functions and Subroutines](04_functions.md)**
5. **[Working with Forms and UI](05_forms_ui.md)**

### 🎮 Game Development Basics
6. **[Introduction to Godot with VisualGasic](06_godot_intro.md)**
7. **[Your First 2D Game - Pong](07_first_2d_game.md)**
8. **[Character Movement and Input](08_character_movement.md)**
9. **[Collision Detection and Physics](09_collision_physics.md)**
10. **[Sprites, Animation, and Graphics](10_sprites_animation.md)**

### ⚡ Intermediate Topics
11. **[Object-Oriented Programming](11_oop_concepts.md)**
12. **[File Operations and Data Persistence](12_file_operations.md)**
13. **[Error Handling and Debugging](13_error_handling.md)**
14. **[Working with Arrays and Collections](14_arrays_collections.md)**
15. **[Multitasking and Async Programming](15_async_programming.md)**

### 🚀 Advanced Features
16. **[Performance Optimization Techniques](16_performance_optimization.md)**
17. **[Database Programming and SQL](17_database_programming.md)**
18. **[Network Programming and Web APIs](18_network_programming.md)**
19. **[Creating Custom Components](19_custom_components.md)**
20. **[Advanced Game Development Patterns](20_advanced_game_dev.md)**

---

## Tutorial 1: Hello World - Your First Program

### Introduction
Welcome to VisualGasic! In this tutorial, you'll create your first program and learn the basics of the VisualGasic development environment.

### What You'll Learn
- How to create a new VisualGasic project
- Basic program structure
- Writing and running your first code
- Understanding the development environment

### Step 1: Setting Up Your First Project

1. **Launch VisualGasic IDE**
2. **Create a New Project**
   - File → New → Project
   - Choose "Console Application" template
   - Name your project "HelloWorld"
   - Select a location for your project

### Step 2: Understanding the Code Structure

Every VisualGasic program has a basic structure:

```vb
' HelloWorld.vb
' Your first VisualGasic program

Option Explicit On
Option Strict On

Imports System

Module Program
    Sub Main()
        ' Your code goes here
        Console.WriteLine("Hello, World!")
        Console.WriteLine("Welcome to VisualGasic!")
        
        ' Keep console open
        Console.WriteLine("Press any key to exit...")
        Console.ReadKey()
    End Sub
End Module
```

### Step 3: Understanding the Components

```vb
' Comments start with single quote
' Option statements control compiler behavior
Option Explicit On    ' Must declare all variables
Option Strict On      ' Strict type checking

' Import system libraries
Imports System

' A Module contains procedures and functions
Module Program
    ' Main is the entry point of your program
    Sub Main()
        ' Program code goes here
    End Sub
End Module
```

### Step 4: Adding More Functionality

Let's enhance our Hello World program:

```vb
Option Explicit On
Option Strict On

Imports System

Module HelloWorldEnhanced
    Sub Main()
        ' Display a welcome message
        Console.WriteLine("=" * 40)
        Console.WriteLine("   Welcome to VisualGasic!")
        Console.WriteLine("=" * 40)
        
        ' Get user's name
        Console.Write("What is your name? ")
        Dim userName As String = Console.ReadLine()
        
        ' Personalized greeting
        If Not String.IsNullOrEmpty(userName) Then
            Console.WriteLine($"Hello, {userName}! Nice to meet you.")
        Else
            Console.WriteLine("Hello, anonymous user!")
        End If
        
        ' Display current date and time
        Console.WriteLine($"Today is: {DateTime.Now:dddd, MMMM dd, yyyy}")
        Console.WriteLine($"Current time: {DateTime.Now:HH:mm:ss}")
        
        ' Show system information
        Console.WriteLine()
        Console.WriteLine("System Information:")
        Console.WriteLine($"Operating System: {Environment.OSVersion}")
        Console.WriteLine($"Machine Name: {Environment.MachineName}")
        Console.WriteLine($"Current Directory: {Environment.CurrentDirectory}")
        
        ' Pause before exit
        Console.WriteLine()
        Console.WriteLine("Press any key to exit...")
        Console.ReadKey()
    End Sub
End Module
```

### Step 5: Running Your Program

1. **Build the Project**: Press F6 or Build → Build Solution
2. **Run the Program**: Press F5 or Debug → Start Debugging
3. **Test the Program**: Enter your name when prompted

### Step 6: Common Variations

#### Version 1: Simple Output
```vb
Sub Main()
    Console.WriteLine("Hello, World!")
End Sub
```

#### Version 2: With Variables
```vb
Sub Main()
    Dim message As String = "Hello, World!"
    Dim version As String = "VisualGasic 2.0"
    
    Console.WriteLine(message)
    Console.WriteLine($"Powered by {version}")
End Sub
```

#### Version 3: With User Interaction
```vb
Sub Main()
    Console.WriteLine("Hello! What's your favorite color?")
    Dim color As String = Console.ReadLine()
    Console.WriteLine($"{color} is a great choice!")
End Sub
```

### Key Concepts Learned
- **Program Structure**: Every program needs a Main() subroutine
- **Output**: Use `Console.WriteLine()` to display text
- **Input**: Use `Console.ReadLine()` to get user input
- **Variables**: Store data with `Dim variableName As Type`
- **Comments**: Use `'` for single-line comments
- **String Interpolation**: Use `$"text {variable}"` for formatted strings

### Next Steps
- Try modifying the program to ask different questions
- Experiment with different output formats
- Move on to Tutorial 2 to learn about variables and data types

### Practice Exercises

1. **Exercise 1**: Create a program that asks for your age and tells you how old you'll be in 10 years
2. **Exercise 2**: Make a simple calculator that adds two numbers the user enters
3. **Exercise 3**: Create a program that displays a personalized welcome message with ASCII art

#### Solution to Exercise 1:
```vb
Sub Main()
    Console.WriteLine("Age Calculator")
    Console.Write("Enter your current age: ")
    
    Dim currentAge As Integer = Integer.Parse(Console.ReadLine())
    Dim futureAge As Integer = currentAge + 10
    
    Console.WriteLine($"In 10 years, you will be {futureAge} years old!")
    Console.ReadKey()
End Sub
```

---

## Tutorial 2: Variables and Data Types

### Introduction
Variables are containers that store data values. In VisualGasic, you must declare variables before using them, and each variable has a specific data type.

### What You'll Learn
- How to declare and initialize variables
- Different data types available in VisualGasic
- Type conversion and casting
- Variable scope and lifetime
- Naming conventions and best practices

### Step 1: Basic Variable Declaration

```vb
Option Explicit On
Option Strict On

Imports System

Module VariablesDemo
    Sub Main()
        ' Basic variable declarations
        Dim name As String
        Dim age As Integer
        Dim height As Double
        Dim isStudent As Boolean
        
        ' Initialize variables
        name = "John Doe"
        age = 25
        height = 5.9
        isStudent = True
        
        ' Display values
        Console.WriteLine($"Name: {name}")
        Console.WriteLine($"Age: {age}")
        Console.WriteLine($"Height: {height} feet")
        Console.WriteLine($"Is Student: {isStudent}")
        
        Console.ReadKey()
    End Sub
End Module
```

### Step 2: Data Types Reference

#### Numeric Types
```vb
Sub NumericTypesDemo()
    ' Integer types
    Dim smallNumber As Byte = 255           ' 0 to 255
    Dim shortNumber As Short = 32767        ' -32,768 to 32,767
    Dim regularNumber As Integer = 2147483647  ' -2.1B to 2.1B
    Dim bigNumber As Long = 9223372036854775807 ' Very large range
    
    ' Floating-point types
    Dim precision As Single = 3.14159F      ' 7 digits precision
    Dim doublePrecision As Double = 3.14159265359 ' 15-16 digits precision
    Dim exactDecimal As Decimal = 123.456D  ' 28-29 digits precision
    
    ' Display values
    Console.WriteLine($"Byte: {smallNumber}")
    Console.WriteLine($"Short: {shortNumber}")
    Console.WriteLine($"Integer: {regularNumber}")
    Console.WriteLine($"Long: {bigNumber}")
    Console.WriteLine($"Single: {precision}")
    Console.WriteLine($"Double: {doublePrecision}")
    Console.WriteLine($"Decimal: {exactDecimal}")
End Sub
```

#### Text and Character Types
```vb
Sub TextTypesDemo()
    ' Character type (single character)
    Dim singleChar As Char = "A"c
    
    ' String type (text)
    Dim message As String = "Hello, VisualGasic!"
    Dim multiline As String = "Line 1" & vbCrLf & "Line 2"
    
    ' String operations
    Dim firstName As String = "John"
    Dim lastName As String = "Doe"
    Dim fullName As String = firstName & " " & lastName
    
    Console.WriteLine($"Character: {singleChar}")
    Console.WriteLine($"Message: {message}")
    Console.WriteLine($"Multiline:{vbCrLf}{multiline}")
    Console.WriteLine($"Full Name: {fullName}")
    Console.WriteLine($"Length of message: {message.Length}")
    Console.WriteLine($"Uppercase: {message.ToUpper()}")
End Sub
```

#### Boolean and Date Types
```vb
Sub OtherTypesDemo()
    ' Boolean type
    Dim isActive As Boolean = True
    Dim isCompleted As Boolean = False
    
    ' Date and Time
    Dim currentDate As DateTime = DateTime.Now
    Dim specificDate As DateTime = New DateTime(2026, 1, 25)
    Dim timeOnly As TimeSpan = New TimeSpan(14, 30, 0) ' 2:30 PM
    
    Console.WriteLine($"Is Active: {isActive}")
    Console.WriteLine($"Is Completed: {isCompleted}")
    Console.WriteLine($"Current Date/Time: {currentDate}")
    Console.WriteLine($"Specific Date: {specificDate:yyyy-MM-dd}")
    Console.WriteLine($"Time: {timeOnly}")
End Sub
```

### Step 3: Variable Initialization

```vb
Sub InitializationDemo()
    ' Declaration and initialization in one line
    Dim count As Integer = 10
    Dim price As Double = 29.99
    Dim productName As String = "Widget"
    Dim inStock As Boolean = True
    
    ' Multiple declarations
    Dim x As Integer, y As Integer, z As Integer
    x = 1 : y = 2 : z = 3
    
    ' Using New keyword for objects
    Dim currentTime As DateTime = New DateTime()
    Dim numbers As New List(Of Integer)
    
    Console.WriteLine($"Count: {count}")
    Console.WriteLine($"Price: ${price}")
    Console.WriteLine($"Product: {productName}")
    Console.WriteLine($"In Stock: {inStock}")
    Console.WriteLine($"Coordinates: ({x}, {y}, {z})")
End Sub
```

### Step 4: Type Conversion

```vb
Sub TypeConversionDemo()
    Console.WriteLine("=== Type Conversion Demo ===")
    
    ' Implicit conversion (automatic)
    Dim intValue As Integer = 42
    Dim doubleValue As Double = intValue  ' Int to Double (safe)
    
    Console.WriteLine($"Integer: {intValue}")
    Console.WriteLine($"Double: {doubleValue}")
    
    ' Explicit conversion (casting)
    Dim largeDouble As Double = 123.789
    Dim convertedInt As Integer = CInt(largeDouble)  ' Rounds to nearest
    Dim truncatedInt As Integer = CType(largeDouble, Integer)
    
    Console.WriteLine($"Original Double: {largeDouble}")
    Console.WriteLine($"Converted Int (CInt): {convertedInt}")
    Console.WriteLine($"Truncated Int: {truncatedInt}")
    
    ' String conversions
    Dim numberAsString As String = "456"
    Dim stringAsNumber As Integer = Integer.Parse(numberAsString)
    Dim safeConversion As Integer
    
    If Integer.TryParse("789", safeConversion) Then
        Console.WriteLine($"Safely converted: {safeConversion}")
    End If
    
    ' Convert numbers to strings
    Dim formattedCurrency As String = doubleValue.ToString("C")
    Dim formattedPercent As String = (0.85).ToString("P")
    
    Console.WriteLine($"Currency format: {formattedCurrency}")
    Console.WriteLine($"Percent format: {formattedPercent}")
End Sub
```

### Step 5: Variable Scope and Lifetime

```vb
Module ScopeDemo
    ' Module-level variable (accessible throughout module)
    Private moduleVariable As String = "I'm accessible to all procedures in this module"
    
    Sub Main()
        Console.WriteLine("=== Variable Scope Demo ===")
        DemoLocalVariables()
        DemoModuleVariable()
        Console.ReadKey()
    End Sub
    
    Sub DemoLocalVariables()
        ' Local variables (only accessible within this procedure)
        Dim localVar As String = "I'm only accessible in this procedure"
        
        Console.WriteLine(localVar)
        
        ' Block scope (within If, For, etc.)
        If True Then
            Dim blockVar As String = "I'm only accessible in this block"
            Console.WriteLine(blockVar)
        End If
        
        ' blockVar is not accessible here - would cause compilation error
        ' Console.WriteLine(blockVar)  ' This would cause an error
    End Sub
    
    Sub DemoModuleVariable()
        ' Can access module-level variable
        Console.WriteLine(moduleVariable)
        
        ' Can modify module-level variable
        moduleVariable = "Modified from DemoModuleVariable"
        Console.WriteLine($"Modified: {moduleVariable}")
    End Sub
End Module
```

### Step 6: Constants and Read-Only Variables

```vb
Sub ConstantsDemo()
    ' Constants - values that never change
    Const PI As Double = 3.14159265359
    Const COMPANY_NAME As String = "My Company"
    Const MAX_USERS As Integer = 100
    
    ' ReadOnly variables (can be set in constructor)
    Dim ReadOnly startTime As DateTime = DateTime.Now
    
    Console.WriteLine($"PI: {PI}")
    Console.WriteLine($"Company: {COMPANY_NAME}")
    Console.WriteLine($"Max Users: {MAX_USERS}")
    Console.WriteLine($"Start Time: {startTime}")
    
    ' PI = 3.14  ' This would cause a compilation error
End Sub
```

### Step 7: Practical Examples

#### Example 1: Personal Information System
```vb
Sub PersonalInfoSystem()
    Console.WriteLine("=== Personal Information System ===")
    
    ' Collect user information
    Console.Write("Enter your name: ")
    Dim name As String = Console.ReadLine()
    
    Console.Write("Enter your age: ")
    Dim age As Integer
    If Not Integer.TryParse(Console.ReadLine(), age) Then
        age = 0
        Console.WriteLine("Invalid age entered, using 0.")
    End If
    
    Console.Write("Enter your height in feet (e.g., 5.9): ")
    Dim height As Double
    If Not Double.TryParse(Console.ReadLine(), height) Then
        height = 0.0
        Console.WriteLine("Invalid height entered, using 0.0.")
    End If
    
    Console.Write("Are you a student? (y/n): ")
    Dim isStudentInput As String = Console.ReadLine().ToLower()
    Dim isStudent As Boolean = (isStudentInput = "y" Or isStudentInput = "yes")
    
    ' Calculate additional information
    Dim birthYear As Integer = DateTime.Now.Year - age
    Dim heightInCm As Double = height * 30.48 ' Convert feet to cm
    
    ' Display results
    Console.WriteLine()
    Console.WriteLine("=== Your Information ===")
    Console.WriteLine($"Name: {name}")
    Console.WriteLine($"Age: {age} years old")
    Console.WriteLine($"Estimated birth year: {birthYear}")
    Console.WriteLine($"Height: {height} feet ({heightInCm:F1} cm)")
    Console.WriteLine($"Student status: {If(isStudent, "Student", "Not a student")}")
    Console.WriteLine($"Profile created on: {DateTime.Now:F}")
End Sub
```

#### Example 2: Simple Calculator with Variables
```vb
Sub SimpleCalculator()
    Console.WriteLine("=== Simple Calculator ===")
    
    ' Get first number
    Console.Write("Enter first number: ")
    Dim num1 As Double
    If Not Double.TryParse(Console.ReadLine(), num1) Then
        Console.WriteLine("Invalid number. Exiting.")
        Return
    End If
    
    ' Get operation
    Console.Write("Enter operation (+, -, *, /): ")
    Dim operation As String = Console.ReadLine()
    
    ' Get second number
    Console.Write("Enter second number: ")
    Dim num2 As Double
    If Not Double.TryParse(Console.ReadLine(), num2) Then
        Console.WriteLine("Invalid number. Exiting.")
        Return
    End If
    
    ' Perform calculation
    Dim result As Double = 0
    Dim validOperation As Boolean = True
    
    Select Case operation
        Case "+"
            result = num1 + num2
        Case "-"
            result = num1 - num2
        Case "*"
            result = num1 * num2
        Case "/"
            If num2 = 0 Then
                Console.WriteLine("Error: Division by zero!")
                Return
            End If
            result = num1 / num2
        Case Else
            Console.WriteLine("Invalid operation!")
            validOperation = False
    End Select
    
    If validOperation Then
        Console.WriteLine($"{num1} {operation} {num2} = {result}")
        Console.WriteLine($"Result formatted as currency: {result:C}")
        Console.WriteLine($"Result with 2 decimal places: {result:F2}")
    End If
End Sub
```

### Best Practices for Variables

1. **Use Meaningful Names**
```vb
' Good
Dim customerName As String
Dim totalPrice As Double
Dim isOrderComplete As Boolean

' Bad  
Dim x As String
Dim temp As Double
Dim flag As Boolean
```

2. **Initialize Variables**
```vb
' Good - always initialize
Dim count As Integer = 0
Dim message As String = ""

' Avoid uninitialized variables
Dim count As Integer  ' Could contain garbage
```

3. **Use Appropriate Data Types**
```vb
' For money calculations, use Decimal
Dim price As Decimal = 29.99D

' For percentages, use Double
Dim taxRate As Double = 0.08

' For counts, use Integer
Dim itemCount As Integer = 5
```

4. **Follow Naming Conventions**
```vb
' Use camelCase for local variables
Dim firstName As String
Dim totalAmount As Double

' Use PascalCase for constants
Const MaximumRetries As Integer = 3
Const CompanyName As String = "Acme Corp"
```

### Common Pitfalls to Avoid

1. **Division by Zero**
```vb
' Always check before dividing
If denominator <> 0 Then
    result = numerator / denominator
Else
    Console.WriteLine("Cannot divide by zero!")
End If
```

2. **String vs Numeric Operations**
```vb
' Be careful with string concatenation vs addition
Dim a As String = "10"
Dim b As String = "20"
Console.WriteLine(a + b)    ' Outputs: "1020"
Console.WriteLine(CInt(a) + CInt(b))  ' Outputs: 30
```

3. **Type Conversion Errors**
```vb
' Use TryParse for safe conversions
Dim userInput As String = Console.ReadLine()
Dim number As Integer
If Integer.TryParse(userInput, number) Then
    ' Safe to use number
Else
    Console.WriteLine("Invalid number entered")
End If
```

### Practice Exercises

1. **Temperature Converter**: Create a program that converts Celsius to Fahrenheit and vice versa
2. **BMI Calculator**: Calculate Body Mass Index using height and weight
3. **Interest Calculator**: Calculate simple and compound interest
4. **Unit Converter**: Convert between different units (meters/feet, kilograms/pounds, etc.)

### Summary
In this tutorial, you learned:
- How to declare and initialize variables
- Different data types and their uses
- Type conversion techniques
- Variable scope and lifetime
- Best practices for naming and using variables

### Next Tutorial
[Tutorial 3: Control Structures and Loops](03_control_structures.md) - Learn how to control program flow with If statements, loops, and more.

---

*Continue building your VisualGasic knowledge with our comprehensive tutorial series!*
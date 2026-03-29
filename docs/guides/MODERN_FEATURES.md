# VisualGasic Modern Features Guide

This document describes all the modern features added to VisualGasic to improve upon classic VB6 syntax.

## Overview

VisualGasic now includes modern language features that make code more concise, readable, and expressive while maintaining full backward compatibility with VB6 code.

## 1. String Interpolation

**Status**: ✅ Tokenizer ready, AST support, parser ready  
**Syntax**: `$"text {expression} more text"`

String interpolation allows embedding expressions directly in string literals.

```vb
Dim name As String
Dim age As Integer
name = "Alice"
age = 25

' Modern: String interpolation
Print $"Hello, {name}! You are {age} years old."

' Traditional equivalent:
Print "Hello, " & name & "! You are " & age & " years old."
```

**Implementation Details**:
- Tokenizer recognizes `$"..."` as `TOKEN_STRING_INTERP`
- Parser splits interpolated string into parts and evaluates embedded expressions
- Expressions inside `{}` are evaluated and concatenated with string parts
- Supports nested expressions and method calls

## 2. Null-Coalescing Operator (??)

**Status**: ✅ Fully implemented  
**Syntax**: `value ?? default_value`

Returns the left operand if it's not null, otherwise returns the right operand.

```vb
Dim value
Dim result

value = Null
result = value ?? "default"  ' Returns "default"

value = "actual"
result = value ?? "default"  ' Returns "actual"
```

**Traditional equivalent**:
```vb
If IsNull(value) Then
    result = "default"
Else
    result = value
End If
```

**Implementation Details**:
- Tokenizer recognizes `??` as two-character operator
- Parser adds it as a precedence level between logical OR and AND
- Runtime checks if left operand is `Variant::NIL`, returns right if true

## 3. Elvis Operator (?.)

**Status**: ✅ Fully implemented  
**Syntax**: `object?.Property?.Method()`

Null-safe member access. If any part of the chain is null, the entire expression returns null instead of throwing an error.

```vb
Dim obj
obj = Null

' Modern: Null-safe navigation
Dim value = obj?.Property?.SubProperty

' Traditional equivalent requires explicit null checks:
Dim value
If Not IsNull(obj) Then
    If Not IsNull(obj.Property) Then
        value = obj.Property.SubProperty
    End If
End If
```

**Implementation Details**:
- Tokenizer recognizes `?.` as operator
- Parser sets `is_null_safe = true` flag on `MemberAccessNode`
- Runtime checks if base object is null before accessing member
- Returns `Variant()` (null) instead of error if base is null

## 4. Lambda Expressions

**Status**: ✅ Fully implemented (parser, runtime, invocation)  
**Syntax**: Multiple forms supported

Creates anonymous functions that can be passed as values and invoked at runtime.

### Syntax Forms

```vb
' Classic arrow syntax
Dim add = Lambda(a, b) => a + b

' Fn shorthand (recommended for concise lambdas)
Dim square = Fn(x) x * x

' VB.NET-style Function (no arrow needed)
Dim triple = Function(x) x * 3

' Function with arrow (also valid)
Dim negate = Function(x) => -x

' Sub lambda for statements
Dim greet = Sub(name) Print "Hello " & name

' Multi-parameter
Dim multiply = Fn(a, b) a * b
```

### Usage with Null-Coalescing

```vb
' Combine with ?? operator
Dim fallback = Lambda(x) => x ?? 0
```

### Formatter Auto-Replace

The VG code formatter automatically normalizes lambda syntax:
- `Lambda(x) => expr` → `Function(x) expr`
- `Fn(x) => expr` → `Function(x) expr`
- `Lambda(x) expr` → `Function(x) expr`

**Implementation Details**:
- `Lambda`, `Fn`, `Function`, `Sub` keywords trigger lambda parsing
- `=>` arrow operator is optional — parser detects style dynamically
- Runtime creates Dictionary wrapper with `__vg_lambda` marker, `__vg_params`, `__vg_ast_ptr`
- Invocation uses save/restore variable scoping for proper execution
- Expression-only lambdas (single expression body)
- Block lambdas with multi-statement bodies (see Section 4b)

## 4b. Block Lambdas (Multi-Statement Bodies)

**Status**: ✅ Fully implemented  
**Syntax**: `Function(params) ... Return value ... End Function` or `Sub(params) ... End Sub`

Block lambdas allow multi-statement lambda bodies, including control flow, loops, and the `Return` keyword.

### Block Function Lambda (returns value)
```vb
Dim compute = Function(a, b)
    Dim result As Integer
    result = a * b
    result = result + a
    Return result
End Function

Print compute(4, 5)  ' 24
```

### Block Sub Lambda (no return value)
```vb
Dim greet = Sub(name)
    Dim msg As String
    msg = "Hello " & name & "!"
    Print msg
End Sub

greet("Alice")  ' prints "Hello Alice!"
```

### Block Lambda with Control Flow
```vb
Dim classify = Function(n)
    If n > 0 Then
        Return "positive"
    ElseIf n < 0 Then
        Return "negative"
    Else
        Return "zero"
    End If
End Function
```

### Block Lambda with Loops
```vb
Dim sumTo = Function(n)
    Dim total As Integer
    total = 0
    Dim i As Integer
    For i = 1 To n
        total = total + i
    Next
    Return total
End Function

Print sumTo(10)  ' 55
```

**Implementation Details**:
- Parser stores `body_statements` (Vector of statements) for block lambdas
- `invoke_lambda()` creates a synthetic `SubDefinition` with name `"__lambda"` as `current_sub`
- `STMT_RETURN` sets `variables["__lambda"]` with the return value
- After execution, `variables["__lambda"]` is captured as the return value
- EXIT_SUB flag is properly cleared after lambda invocation

## 4c. Functional Programming Builtins

**Status**: ✅ Fully implemented (6 functions)  
**Requires**: Lambda expressions (Section 4)

Higher-order functions for working with arrays using lambda callbacks.

### Map — Transform Elements
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim doubled = Map(nums, Fn(x) x * 2)
' Result: [2, 4, 6, 8, 10]
```

### Filter — Select Matching Elements
```vb
Dim nums = [1, 2, 3, 4, 5, 6]
Dim evens = Filter(nums, Fn(x) x Mod 2 = 0)
' Result: [2, 4, 6]
```

### Reduce — Fold to Single Value
```vb
Dim nums = [1, 2, 3, 4, 5]

' With initial value
Dim sum = Reduce(nums, Fn(a, b) a + b, 0)
' Result: 15

' Without initial value (uses first element)
Dim product = Reduce(nums, Fn(a, b) a * b)
' Result: 120
```

### Any — Check If Any Match
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim hasEven = Any(nums, Fn(x) x Mod 2 = 0)
' Result: True

Dim allSmall = Any(nums, Fn(x) x > 100)
' Result: False
```

### All — Check If All Match
```vb
Dim nums = [2, 4, 6, 8]
Dim allEven = All(nums, Fn(x) x Mod 2 = 0)
' Result: True

Dim mixed = [1, 2, 3]
Dim allEvenMixed = All(mixed, Fn(x) x Mod 2 = 0)
' Result: False
```

### Find — First Matching Element
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim firstBig = Find(nums, Fn(x) x > 3)
' Result: 4
```

### Chaining
```vb
' Filter, transform, then reduce
Dim data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
Dim evens = Filter(data, Fn(x) x Mod 2 = 0)
Dim doubled = Map(evens, Fn(x) x * 2)
Dim total = Reduce(doubled, Fn(a, b) a + b, 0)
' total = 60 (evens: 2,4,6,8,10 → doubled: 4,8,12,16,20 → sum: 60)
```

### Using Block Lambdas with Functional Builtins
```vb
Dim result = Map([1, 2, 3], Function(x)
    Dim label As String
    label = "Item #" & CStr(x)
    Return label
End Function)
' Result: ["Item #1", "Item #2", "Item #3"]
```

**Implementation Details**:
- All 6 functions implemented as builtins in `visual_gasic_builtins.cpp`
- Each takes an Array and a lambda Dictionary, calls `instance->invoke_lambda()`
- Reduce supports optional initial value (2 or 3 arguments)
- Works with all lambda forms: `Fn`, `Lambda`, `Function`, `Sub`, block lambdas

## 5. Range Operator (..)

**Status**: ✅ Fully implemented  
**Syntax**: `start..end`

Creates a range of integers from start to end (inclusive).

```vb
' Create array of numbers 1 to 10
Dim numbers = 1..10

' Reverse range
Dim countdown = 10..1

' Can be used in loops (future enhancement)
For Each n In 0..9
    Print n
Next
```

**Implementation Details**:
- Tokenizer recognizes `..` as two-character operator
- Parser creates `RangeNode` with start and end expressions
- Runtime evaluates to an `Array` containing integers from start to end
- Supports both ascending and descending ranges

## 6. Modern Type Aliases

**Status**: ✅ Keywords added, mapping pending  
**Keywords**: `Int16`, `Int32`, `Int64`, `Float32`, `Float64`, `Bool`

Clear, unambiguous type names that specify exact bit sizes.

```vb
' Modern clear types:
Dim count As Int32        ' 32-bit signed integer
Dim bigNumber As Int64    ' 64-bit signed integer
Dim smallValue As Int16   ' 16-bit signed integer
Dim price As Float32      ' Single-precision float
Dim precise As Float64    ' Double-precision float
Dim flag As Bool          ' Boolean

' Traditional VB6 confusion:
' Integer = 16-bit (confusing!)
' Long = 32-bit (unclear)
' Single = float (non-descriptive)
' Double = double (vague)
```

**Type Mappings**:
- `Int16` → `Integer` (16-bit)
- `Int32` → `Long` (32-bit)
- `Int64` → `LongLong` (64-bit)
- `Float32` → `Single` (32-bit float)
- `Float64` → `Double` (64-bit float)
- `Bool` → `Boolean`

**Implementation Details**:
- All keywords added to tokenizer
- Type mapping in parser needs to convert modern names to VB6 equivalents
- Provides clear documentation of bit sizes

## 7. Using Statement

**Status**: ✅ Fully implemented  
**Syntax**: 
```vb
Using variable = resource_expression
    ' ... use resource ...
End Using  ' Automatically disposed
```

Automatic resource management with guaranteed cleanup.

```vb
' Modern: Automatic file closing
Using file = FileAccess.Open("data.txt", FileAccess.READ)
    Dim content = file.GetAsText()
    Print content
End Using  ' file.close() called automatically

' Traditional:
Dim file
file = FileAccess.Open("data.txt", FileAccess.READ)
Dim content = file.GetAsText()
Print content
file.Close()  ' Must remember to close
```

**Implementation Details**:
- `Using` keyword added to tokenizer
- Parser creates `UsingStatement` with variable name, resource expression, and body
- Runtime executes body, then automatically calls:
  1. `close()` / `Close()` if method exists
  2. `dispose()` / `Dispose()` if method exists
  3. `queue_free()` for Godot nodes
- Variable is removed from scope after cleanup

## 8. Array Literals

**Status**: ✅ Fully implemented  
**Syntax**: `[element1, element2, element3]`

Create arrays with inline syntax.

```vb
' Modern: Array literal
Dim numbers = [1, 2, 3, 4, 5]
Dim names = ["Alice", "Bob", "Charlie"]
Dim mixed = [1, "text", 3.14, True]

' Traditional:
Dim numbers(4) As Integer
numbers(0) = 1
numbers(1) = 2
numbers(2) = 3
numbers(3) = 4
numbers(4) = 5
```

**Implementation Details**:
- Tokenizer recognizes `[` and `]` as operators
- Parser creates `ArrayLiteralNode` with comma-separated expressions
- Runtime evaluates each element and creates a `godot::Array`
- Supports nested arrays and mixed types

## 9. Dictionary Literals

**Status**: ✅ Fully implemented  
**Syntax**: `{"key": value, "key2": value2}`

Create dictionaries with inline syntax.

```vb
' Modern: Dictionary literal
Dim person = {"name": "John", "age": 30, "city": "NYC"}

' Access values
Print person["name"]  ' "John"

' Traditional:
Dim person As Object
Set person = CreateObject("Scripting.Dictionary")
person("name") = "John"
person("age") = 30
person("city") = "NYC"
```

**Implementation Details**:
- Tokenizer recognizes `{` and `}` as operators
- Parser creates `DictLiteralNode` with key-value pairs
- Uses `:` (colon) to separate keys from values
- Runtime evaluates keys and values, creates `godot::Dictionary`
- Supports any expression as key or value

## 10. Short-Circuit IIf

**Status**: ✅ Fully implemented  
**Syntax**: `IIf(condition, true_value, false_value)`

IIf evaluates only the branch that matches the condition (short-circuit evaluation), making it safe to use with potentially dangerous expressions.

```vb
' Safe - only evaluates 100/x when x<>0
Dim x As Integer = 0
result = IIf(x <> 0, 100 / x, 0)  ' Returns 0, does NOT crash

' Safe - only evaluates the true branch
result = IIf(True, "yes", 1/0)  ' Returns "yes", no division error
```

**Implementation Details**:
- IIf is implemented via dedicated `IIfNode` AST node (not a function call)
- Runtime evaluates condition first, then only evaluates the matching branch
- This differs from classic VB6 where IIf is a function that evaluates both branches

## 11. Pattern Matching Select Case

**Status**: ⚠️ Planned feature  
**Syntax**:
```vb
Select Case value
    Case Is Integer n When n > 0
        Print "Positive integer:", n
    Case Is String s When Len(s) > 10
        Print "Long string:", s
    Case Else
        Print "Other"
End Select
```

**Implementation Details**:
- `When` keyword added to tokenizer
- Requires parser enhancement to recognize type patterns
- Runtime needs type checking and guard clause evaluation

## 12. Spread Operator

**Status**: ⚠️ Planned feature  
**Syntax**: `...array`

```vb
' Combine arrays
Dim arr1 = [1, 2, 3]
Dim arr2 = [4, 5, 6]
Dim combined = [...arr1, ...arr2]  ' [1, 2, 3, 4, 5, 6]

' Variadic functions
Sub PrintAll(ParamArray items())
    ' ...
End Sub
PrintAll(...myArray)
```

## Async/Await

**Status**: ⚠️ Planned for future  
**Keywords**: `Async`, `Await`

```vb
Async Sub LoadData()
    Dim data = Await FetchFromServer()
    Print data
End Sub
```

**Implementation Notes**:
- Keywords added to tokenizer
- Requires coroutine/continuation infrastructure
- Integration with Godot's async operations
- Complex runtime implementation

---

## 14. Classes & Objects

**Status**: ✅ Fully implemented (parser + runtime)  
**Syntax**: `Class ClassName ... End Class`

Full VB6/VB.NET-style class definitions with members, methods, properties, and events.

### Basic Class
```vb
Class Person
    Public Name As String
    Public Age As Integer

    Sub Greet()
        Print "Hello, I'm " & Me.Name
    End Sub
End Class

Dim p = New Person
p.Name = "Alice"
p.Age = 30
p.Greet()  ' "Hello, I'm Alice"
```

### Class with Constructor
```vb
Class Counter
    Public Count As Integer

    Sub Class_Initialize()
        Me.Count = 0
    End Sub

    Sub Increment()
        Me.Count = Me.Count + 1
    End Sub

    Function GetCount() As Integer
        Return Me.Count
    End Function
End Class

Dim c = New Counter  ' Count = 0 (from Class_Initialize)
c.Increment()
c.Increment()
c.Increment()
Print c.GetCount()  ' 3
```

### Multiple Independent Instances
```vb
Class Calculator
    Public Total As Integer

    Sub Accumulate(value As Integer)
        Me.Total = Me.Total + value
    End Sub

    Function Add(a As Integer, b As Integer) As Integer
        Return a + b
    End Function
End Class

Dim c1 = New Calculator
Dim c2 = New Calculator
c1.Accumulate(10)
c2.Accumulate(50)
Print c1.Total  ' 10
Print c2.Total  ' 50 — independent state
```

### Property Accessors
```vb
Class Temperature
    Private mDegrees As Double

    Property Get Degrees() As Double
        Degrees = mDegrees
    End Property

    Property Let Degrees(value As Double)
        If value < -273.15 Then
            Print "Invalid temperature"
        Else
            mDegrees = value
        End If
    End Property
End Class
```

### Class Features
- `Public`/`Private` member visibility
- `Sub`/`Function` methods
- `Property Get`/`Let`/`Set` accessors
- `Class_Initialize` (auto-called on `New`)
- `Class_Terminate` (destructor scaffolding)
- `Me` keyword for self-reference
- `Inherits BaseClass` syntax (parsed, runtime pending)

**Implementation Details**:
- Parser: `parse_class()` handles full Class...End Class blocks
- Runtime: `register_class()` stores `ClassDefinition*` in `class_registry`
- `New ClassName`: `EXPR_NEW` checks `class_registry` before Godot ClassDB
- Instances stored in `object_instances` Dictionary keyed by integer `obj_id`
- Member access/assignment and method dispatch check integer obj_id for VG objects

---

## Summary Table

| Feature | Status | Parser | Runtime | Notes |
|---------|--------|--------|---------|-------|
| String Interpolation ($"...") | ✅ Ready | ✅ | ✅ | Fully functional |
| Null-Coalescing (??) | ✅ Complete | ✅ | ✅ | Production ready |
| Elvis Operator (?.) | ✅ Complete | ✅ | ✅ | Null-safe navigation |
| Lambda Expressions | ✅ Complete | ✅ | ✅ | All 4 syntax forms |
| Block Lambdas | ✅ Complete | ✅ | ✅ | Multi-statement bodies |
| Functional Builtins | ✅ Complete | ✅ | ✅ | Map/Filter/Reduce/Any/All/Find |
| Range Operator (..) | ✅ Complete | ✅ | ✅ | Creates arrays |
| Modern Type Aliases | ⚠️ Keywords only | ⚠️ | ⚠️ | Needs mapping |
| Using Statement | ✅ Complete | ✅ | ✅ | Auto-dispose |
| Array Literals [...] | ✅ Complete | ✅ | ✅ | Production ready |
| Dict Literals {...} | ✅ Complete | ✅ | ✅ | Production ready |
| Short-Circuit IIf | ✅ Complete | ✅ | ✅ | Safe branch eval |
| Classes & Objects | ✅ Complete | ✅ | ✅ | Full OOP support |
| Pattern Matching | 🔜 Planned | 🔜 | 🔜 | Future feature |
| Spread Operator | 🔜 Planned | 🔜 | 🔜 | Future feature |
| Async/Await | 🔜 Planned | 🔜 | 🔜 | Complex feature |
| Whenever Sections | ✅ Complete | ✅ | ✅ | Bytecode compiled |
| GoSub/Return | ✅ Complete | ✅ | ✅ | Bytecode OP_GOSUB/OP_RETURN_GOSUB |
| Implements Keyword | ✅ Complete | ✅ | ✅ | Interface declaration in classes |
| COM-Style Objects | ✅ Complete | ✅ | ✅ | VGCollection, VGRegEx, VGHttpRequest, VGTimer |
| VB6 Global Objects | ✅ Complete | ✅ | ✅ | App, Screen, Err virtual objects |
| File I/O Opcodes | ✅ Complete | ✅ | ✅ | Print#, Write#, Input#, Line Input# |

Legend:
- ✅ Complete and tested
- ⚠️ Partial implementation or needs work
- 🔜 Planned for future release

---

## Testing

See [examples/test_modern_features.vg](../examples/test_modern_features.vg) for comprehensive examples and testing.

## Backward Compatibility

All modern features are **additive** - existing VB6 code continues to work without modifications. Modern syntax can be gradually adopted in new code or mixed with traditional syntax as needed.

## Future Enhancements

1. **Type inference**: `Dim x = 42` infers Int32 type
2. **Enhanced pattern matching**: Destructuring, exhaustiveness checking
3. **Async/Await**: Full coroutine support for async operations
4. **Null safety annotations**: Optional `?` suffix on types
5. **Collection builders**: LINQ-style operations on arrays/dictionaries
6. **Inheritance runtime**: `Inherits BaseClass` with method overriding and `MyBase` calls

---

**Last Updated**: February 2026  
**VisualGasic Version**: 2.10.0

---

## 13. Whenever Reactive Sections

**Status**: ✅ Fully implemented with bytecode compilation  
**Syntax**:
```vb
Whenever Section <SectionName> <Variable> <Operator> [Value] <CallbackProcedure>
```

Reactive programming system for automatically responding to variable state changes.

```vb
' Trigger when a score changes
Whenever Section Player1Scores Score1 Changes OnPlayer1Score

' Trigger when health drops below threshold
Whenever Section LowHealth Health Below 30 OnLowHealthWarning

' Trigger when value equals target
Whenever Section Victory Score1 Becomes 10 OnVictory

' Trigger when value exceeds threshold
Whenever Section SpeedBoost Speed Exceeds 500 OnSpeedBoost
```

**Operators Supported**:
- `Changes` - Triggers when value changes at all
- `Becomes` - Triggers when value equals target
- `Exceeds` - Triggers when value goes above threshold
- `Below` - Triggers when value drops below threshold
- `Between...And` - Triggers when in range
- `Contains` - For string matching

**Control Statements**:
```vb
' Pause monitoring
Suspend Whenever Player1Scores

' Resume monitoring
Resume Whenever Player1Scores
```

**Implementation Details**:
- Compiles to dedicated bytecode opcodes: `OP_REGISTER_WHENEVER`, `OP_SUSPEND_WHENEVER`, `OP_RESUME_WHENEVER`
- Section data packed into Dictionary constant for efficient runtime unpacking
- Monitoring integrated with `_process` loop for frame-by-frame variable tracking
- Visible in Immediate Window's "Whenever" tab with pause/resume support
- Supports both global and local scope sections

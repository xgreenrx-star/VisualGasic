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

**Status**: ✅ Parser implemented, runtime metadata support  
**Syntax**: `Lambda(param1, param2) => expression`

Creates anonymous functions that can be passed as values.

```vb
' Lambda expression
Dim add = Lambda(a, b) => a + b

' Can be stored and passed around
Dim multiply = Lambda(x, y) => x * y
```

**Current Limitations**:
- Lambda parsing is complete
- Runtime returns metadata dictionary (type, params) for inspection
- Full callable execution requires additional runtime infrastructure
- Expression-only lambdas (no multi-statement bodies)

**Implementation Details**:
- `Lambda` keyword added to tokenizer
- `=>` arrow operator tokenized
- Parser creates `LambdaNode` with parameter names and expression
- AST structure defined for expression-only lambdas

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

**Status**: ⚠️ Planned optimization  
**Current**: IIf evaluates both branches  
**Goal**: Only evaluate the needed branch

```vb
' VB6 IIf evaluates BOTH branches (inefficient/dangerous):
result = IIf(x <> 0, 100 / x, 0)  ' Crashes if x=0!

' Modern short-circuit (planned):
result = IIf(x <> 0, 100 / x, 0)  ' Safe - only evaluates 100/x if x<>0
```

**Implementation Status**:
- IIf currently implemented as `IIfNode` in AST
- Runtime evaluates condition first
- Optimization needed to skip unused branch evaluation

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

## Summary Table

| Feature | Status | Parser | Runtime | Notes |
|---------|--------|--------|---------|-------|
| String Interpolation ($"...") | ✅ Ready | ✅ | ✅ | Fully functional |
| Null-Coalescing (??) | ✅ Complete | ✅ | ✅ | Production ready |
| Elvis Operator (?.) | ✅ Complete | ✅ | ✅ | Null-safe navigation |
| Lambda Expressions | ⚠️ Partial | ✅ | ⚠️ | Metadata only |
| Range Operator (..) | ✅ Complete | ✅ | ✅ | Creates arrays |
| Modern Type Aliases | ⚠️ Keywords only | ⚠️ | ⚠️ | Needs mapping |
| Using Statement | ✅ Complete | ✅ | ✅ | Auto-dispose |
| Array Literals [...] | ✅ Complete | ✅ | ✅ | Production ready |
| Dict Literals {...} | ✅ Complete | ✅ | ✅ | Production ready |
| Short-Circuit IIf | ⚠️ Planned | ✅ | ⚠️ | Needs optimization |
| Pattern Matching | 🔜 Planned | 🔜 | 🔜 | Future feature |
| Spread Operator | 🔜 Planned | 🔜 | 🔜 | Future feature |
| Async/Await | 🔜 Planned | 🔜 | 🔜 | Complex feature |
| Whenever Sections | ✅ Complete | ✅ | ✅ | Bytecode compiled |

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

1. **Lambda callable support**: Full closure implementation for passing and invoking lambdas
2. **Type inference**: `Dim x = 42` infers Int32 type
3. **Enhanced pattern matching**: Destructuring, exhaustiveness checking
4. **Async/Await**: Full coroutine support for async operations
5. **Null safety annotations**: Optional `?` suffix on types
6. **Collection builders**: LINQ-style operations on arrays/dictionaries

---

**Last Updated**: January 2025  
**VisualGasic Version**: 4.5.1

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

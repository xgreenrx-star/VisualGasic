# VisualGasic Modern Syntax - Quick Reference

## Quick Comparison: Traditional vs Modern

### Array Creation
```vb
' Traditional
Dim arr(4) As Integer
arr(0) = 1
arr(1) = 2
arr(2) = 3

' Modern ✅
Dim arr = [1, 2, 3]
```

### Dictionary Creation
```vb
' Traditional
Dim dict As Object
Set dict = CreateObject("Scripting.Dictionary")
dict("name") = "John"
dict("age") = 30

' Modern ✅
Dim dict = {"name": "John", "age": 30}
```

### Null Checking
```vb
' Traditional
If IsNull(value) Then
    result = "default"
Else
    result = value
End If

' Modern ✅
result = value ?? "default"
```

### Null-Safe Member Access
```vb
' Traditional
If Not IsNull(obj) Then
    If Not IsNull(obj.Property) Then
        value = obj.Property.SubProperty
    End If
End If

' Modern ✅
value = obj?.Property?.SubProperty
```

### String Building
```vb
' Traditional
Print "Hello, " & name & "! You are " & age & " years old."

' Modern ✅
Print $"Hello, {name}! You are {age} years old."
```

### Resource Management
```vb
' Traditional
Dim file
file = FileAccess.Open("data.txt")
' ... use file ...
file.Close()  ' Must remember!

' Modern ✅
Using file = FileAccess.Open("data.txt")
    ' ... use file ...
End Using  ' Auto-closed
```

### Range Generation
```vb
' Traditional
Dim i As Integer
For i = 1 To 10
    arr(i-1) = i
Next

' Modern ✅
Dim arr = 1..10
```

---

## Modern Operators

| Operator | Name | Example | Description |
|----------|------|---------|-------------|
| `??` | Null-coalescing | `x ?? y` | Returns x if not null, else y |
| `?.` | Elvis | `obj?.prop` | Safe navigation, returns null if obj is null |
| `..` | Range | `1..10` | Creates array [1,2,3,4,5,6,7,8,9,10] |
| `=>` | Lambda arrow | `(a,b) => a+b` | Lambda expression (partial support) |
| `[...]` | Array literal | `[1, 2, 3]` | Creates array inline |
| `{...}` | Dict literal | `{"key": val}` | Creates dictionary inline |

---

## Modern Keywords

| Keyword | Purpose | Example |
|---------|---------|---------|
| `Lambda` | Anonymous function | `Lambda(x) => x * 2` |
| `Using` | Resource management | `Using f = Open(...) ... End Using` |
| `Int32` | 32-bit integer type | `Dim x As Int32` |
| `Int64` | 64-bit integer type | `Dim big As Int64` |
| `Float32` | Single-precision float | `Dim f As Float32` |
| `Float64` | Double-precision float | `Dim d As Float64` |
| `Bool` | Boolean type | `Dim flag As Bool` |

---

## Type Aliases (Clear vs Confusing)

| Modern (Clear) | VB6 (Confusing) | Size |
|----------------|-----------------|------|
| `Int16` | `Integer` | 16-bit signed |
| `Int32` | `Long` | 32-bit signed |
| `Int64` | `LongLong` | 64-bit signed |
| `Float32` | `Single` | 32-bit float |
| `Float64` | `Double` | 64-bit float |
| `Bool` | `Boolean` | True/False |

---

## Status Legend

- ✅ **Fully working** - Parse, evaluate, execute
- ⚠️ **Partial** - Parse ready, runtime pending
- 🔜 **Planned** - Future implementation

---

## Examples in One Place

```vb
' Array and Dictionary Literals ✅
Dim numbers = [1, 2, 3, 4, 5]
Dim person = {"name": "Alice", "age": 25}

' Null Safety ✅
Dim safe = maybeNull ?? "default"
Dim value = obj?.Property?.Value

' Ranges ✅
Dim range = 1..10
Dim countdown = 10..1

' String Interpolation ✅
Dim msg = $"Hello {name}, you are {age} years old"

' Resource Management ✅
Using file = FileAccess.Open("data.txt")
    Print file.GetAsText()
End Using

' Lambda (metadata only) ⚠️
Dim add = Lambda(a, b) => a + b

' Modern Types (keywords only) ⚠️
Dim count As Int32
Dim total As Int64
Dim price As Float32
```

---

## When to Use Modern Features

### Use Array Literals When:
- Creating small fixed arrays
- Initializing with known values
- Testing with sample data

### Use Dict Literals When:
- Creating configuration objects
- Returning multiple values
- Mock data for testing

### Use ?? When:
- Providing default values
- Handling optional parameters
- Database null checking

### Use ?. When:
- Accessing nested properties
- Working with optional objects
- Avoiding deep null checks

### Use Using When:
- Opening files
- Database connections
- Any disposable resource

### Use Ranges When:
- Generating sequences
- Loop iteration ranges
- Array slicing operations

---

## Mixing Traditional and Modern

You can mix both styles freely:

```vb
' Traditional Dim with modern literal
Dim arr(10) As Integer
Dim init = [0, 1, 2]

' Modern literal with traditional loop
Dim numbers = [1, 2, 3, 4, 5]
For i = 0 To UBound(numbers)
    Print numbers(i)
Next

' Traditional null check with modern operator
If Not IsNull(obj) Then
    value = obj.Property ?? "default"
End If
```

---

**Quick Start**: Try array literals and null-coalescing first - they're the easiest wins!

**Reference**: See [MODERN_FEATURES.md](MODERN_FEATURES.md) for full documentation.

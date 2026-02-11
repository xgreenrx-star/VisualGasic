# VisualGasic v2.3.2 — Modern Language Features

**Release Date:** June 2025  
**Tag:** `v2.3.2`  
**Godot:** 4.5.1 Stable

---

## 🚀 New Language Features

This release transforms VG from a VB6 compatibility layer into a **modern language** with first-class support for functional programming and null-safety patterns.

### Lambda Expressions `Lambda(params) => expression`

VG now supports arrow-style lambda expressions — anonymous functions that can be stored in variables, passed as arguments, and invoked like regular functions.

```vb
' Arrow syntax (single expression)
Dim doubleIt = Lambda(x) => x * 2
Print doubleIt(5)   ' Output: 10

' Multi-parameter lambdas
Dim add = Lambda(a, b) => a + b
Print add(3, 7)     ' Output: 10

' String operations in lambdas
Dim greet = Lambda(name) => "Hello, " & name & "!"
Print greet("VG")   ' Output: Hello, VG!

' Block syntax (multi-statement)
Dim clamp = Function(val, lo, hi)
    If val < lo Then Return lo
    If val > hi Then Return hi
    Return val
End Function
```

**Supported features:**
- ByVal/ByRef parameter modifiers (defaults to ByVal)
- Optional `As Type` annotations on parameters
- Arrow syntax (`=>`) for single-expression lambdas
- Block syntax (`Function...End Function`) for multi-statement lambdas
- Closures capture surrounding scope variables
- Lambdas are first-class values (store in variables, pass to functions)

### Null Coalescing Operator `??`

The null coalescing operator provides a concise fallback for null values, eliminating verbose `If x Is Nothing Then` blocks.

```vb
Dim name = GetUserName() ?? "Guest"
Dim config = LoadConfig() ?? CreateDefaultConfig()

' Chainable for multiple fallbacks
Dim value = primary ?? secondary ?? "default"
```

**Behavior:** Returns the left operand if non-null; otherwise evaluates and returns the right operand. Short-circuits: the right side is only evaluated if the left is null.

### Optional Chaining Operator `?.`

Safely access members on potentially null objects without risking runtime errors.

```vb
Dim safe = nullObj?.Name        ' Returns Nothing instead of error
Dim length = data?.Items?.Count ' Chain multiple levels
```

**Behavior:** If the base object is `Nothing`, the entire expression evaluates to `Nothing` without error. If the base is non-null, member access proceeds normally.

### Erase Statement

The `Erase` statement resets arrays, dictionaries, and variables to their default state.

```vb
Dim arr As Variant
ReDim arr(10)
arr(0) = "Hello"
Erase arr   ' arr is now an empty array
```

**Behavior:**
- Arrays → empty `Array()`
- Dictionaries → empty `Dictionary()`
- Other types → `Variant()` (null)

---

## 🏗️ Technical Details

### Parser Changes
- New `parse_lambda()` method handles both arrow and block lambda syntax
- `parse_null_coalesce()` inserted in expression precedence chain (above `Or`)
- Optional chaining `?.` wired into member access loop in `parse_factor()`
- `parse_erase()` statement handler added

### Tokenizer Changes
- Added `Lambda` and `Erase` keywords
- Added `??` and `?.` operator recognition

### Runtime Changes
- Lambda expressions evaluate to Dictionary objects with `__vg_lambda` marker
- Lambda invocation supported in both ARRAY_ACCESS and EXPRESSION_CALL paths
- `??` short-circuit evaluation in BINARY_OP handler
- `?.` null-safe member access in OPTIONAL_ACCESS handler
- `STMT_ERASE` runtime handler clears arrays/dictionaries/variables

### Compiler
- `STMT_ERASE` falls back to interpreter (bytecode support deferred)

---

## 📊 Test Results

| Test | Status |
|------|--------|
| Erase statement | ✅ PASS |
| Numeric lambda `Lambda(x) => x * 2` | ✅ PASS |
| Multi-param lambda `Lambda(a, b) => a + b` | ✅ PASS |
| String lambda `Lambda(s) => "Hello " & s` | ✅ PASS |
| Null coalescing `Nothing ?? "default"` | ✅ PASS |
| Non-null coalescing `"actual" ?? "default"` | ✅ PASS |
| Chained null coalescing `x ?? y ?? z` | ✅ PASS |
| Optional chaining `Nothing?.Name` | ✅ PASS |

**8/8 tests pass, 0 failures**

---

## 📦 Downloads

| Platform | File |
|----------|------|
| Linux x86_64 | `VisualGasic-v2.3.2-linux-x86_64.zip` |
| Windows x86_64 | `VisualGasic-v2.3.2-windows-x86_64.zip` |

---

## 🔮 Vision

> *"We are not making VB6. We are making VG. It's derived from VB6 but modernized. VB6 is over 25 years old now — we are bringing the syntax back with VB6 compatibility but this is fundamentally a new language. We want all the features new languages have."*

This release is the first step toward that vision. Lambda expressions, null safety operators, and optional chaining bring VG in line with modern languages like C#, Kotlin, and Swift — while keeping the familiar VB6 syntax that makes it approachable.

**Next up:** Classes & OOP, pattern matching, async/await enhancements, list comprehensions.

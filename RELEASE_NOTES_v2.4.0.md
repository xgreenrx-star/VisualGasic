# VisualGasic v2.4.0 — Classes & Objects, Functional Programming

**Release Date:** February 12, 2026  
**Godot Compatibility:** 4.3+ (built with 4.5.1 stable)  
**Platforms:** Linux x86_64, Windows x86_64

---

## 🔥 Highlights

- **Full Class System** — `Class...End Class`, `New`, `Property Get/Let/Set`, `Class_Initialize`
- **6 Functional Programming Builtins** — `Map`, `Filter`, `Reduce`, `Any`, `All`, `Find`
- **Block Lambda Runtime** — Multi-statement lambda bodies with `Return`
- **Short-Circuit IIf Confirmed** — IIf safely skips unused branches
- **24 new automated tests** across 3 test suites, all passing

---

## ✨ Classes & Objects

Full VB6/VB.NET-style class system with parser and runtime integration.

### Basic Class
```vb
Class Person
    Public Name As String
    Public Age As Integer

    Sub Greet()
        Print "Hello, I'm " & Me.Name
    End Sub
End Class

Sub Main()
    Dim p = New Person
    p.Name = "Alice"
    p.Age = 30
    p.Greet()  ' "Hello, I'm Alice"
End Sub
```

### Constructor (Class_Initialize)
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

Sub Main()
    Dim c = New Counter  ' Count = 0
    c.Increment()
    c.Increment()
    c.Increment()
    Print c.GetCount()  ' 3
End Sub
```

### Independent Instances
```vb
Class Calculator
    Public Total As Integer

    Sub Accumulate(value As Integer)
        Me.Total = Me.Total + value
    End Sub
End Class

Sub Main()
    Dim c1 = New Calculator
    Dim c2 = New Calculator
    c1.Accumulate(10)
    c2.Accumulate(50)
    Print c1.Total  ' 10
    Print c2.Total  ' 50 — separate state
End Sub
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
- `Sub`/`Function` methods with parameters
- `Property Get`/`Let`/`Set` with parameter support
- `Class_Initialize` auto-called on `New`
- `Class_Terminate` destructor scaffolding
- `Me` keyword for self-reference
- `Inherits BaseClass` syntax (parsed, runtime pending)

---

## ✨ Functional Programming Builtins

Six higher-order functions for declarative array processing using lambda callbacks.

### Map — Transform Each Element
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
Dim sum = Reduce(nums, Fn(a, b) a + b, 0)    ' 15
Dim product = Reduce(nums, Fn(a, b) a * b)    ' 120 (no init)
```

### Any / All / Find
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim hasEven = Any(nums, Fn(x) x Mod 2 = 0)   ' True
Dim allPos = All(nums, Fn(x) x > 0)           ' True
Dim firstBig = Find(nums, Fn(x) x > 3)        ' 4
```

### Chaining
```vb
Dim data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
Dim evens = Filter(data, Fn(x) x Mod 2 = 0)   ' [2,4,6,8,10]
Dim doubled = Map(evens, Fn(x) x * 2)          ' [4,8,12,16,20]
Dim total = Reduce(doubled, Fn(a, b) a + b, 0) ' 60
```

### Block Lambda with Functional Builtins
```vb
Dim result = Map([1, 2, 3], Function(x)
    Dim label = "Item #" & CStr(x)
    Return label
End Function)
' Result: ["Item #1", "Item #2", "Item #3"]
```

---

## ✨ Block Lambda (Multi-Statement) Runtime

Block lambdas now fully work with `Return` for values and `Sub` for statements.

### Block Function Lambda
```vb
Dim compute = Function(a, b)
    Dim result As Integer
    result = a * b
    result = result + a
    Return result
End Function

Print compute(4, 5)  ' 24
```

### Block Sub Lambda
```vb
Dim greet = Sub(name)
    Dim msg = "Hello " & name & "!"
    Print msg
End Sub

greet("Alice")  ' "Hello Alice!"
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
    Dim total As Integer = 0
    Dim i As Integer
    For i = 1 To n
        total = total + i
    Next
    Return total
End Function

Print sumTo(10)  ' 55
```

---

## ✅ Short-Circuit IIf Confirmed

IIf uses a dedicated `IIfNode` AST node that evaluates only the matching branch — making it safe for potentially dangerous expressions:

```vb
Dim x As Integer = 0
Dim result = IIf(x <> 0, 100 / x, 0)  ' Returns 0, does NOT crash
```

---

## 🐛 Bug Fixes

- **Block lambda return values**: `STMT_RETURN` now correctly captures return values via synthetic `current_sub` with name `"__lambda"`
- **STMT_CALL lambda invocation**: `greet("Alice")` now works when `greet` is a lambda variable
- **Builtin dispatch from interpreter**: `call_builtin_expr_evaluated()` now called from interpreter's `CallExpression` handler (was only reachable from bytecode VM)
- **Keyword parameter names**: Parser now accepts keywords like `value`, `get`, `let` as function parameter names

---

## 🧪 Test Results

| Suite | Tests | Status |
|-------|-------|--------|
| Block Lambda (`test_block_lambda.vg`) | 6 | ✅ 6/6 PASS |
| Functional (`test_functional.vg`) | 11 | ✅ 11/11 PASS |
| Classes (`test_classes.vg`) | 7 | ✅ 7/7 PASS |
| Regression (`test_modern.vg`) | 8 | ✅ All PASS |
| **Total** | **32** | **✅ 100%** |

All 4 binary targets built clean:
- `libvisual_gasic.linux.template_debug.x86_64.so`
- `libvisual_gasic.linux.editor.x86_64.so`
- `libvisual_gasic.linux.template_release.x86_64.so`
- `libvisual_gasic.windows.editor.x86_64.dll`

---

## 📁 Files Modified

### New Files
| File | Purpose |
|------|---------|
| `demo/test_block_lambda.vg` | 6 block lambda tests |
| `demo/test_functional.vg` | 11 functional programming tests |
| `demo/test_classes.vg` | 7 class & object tests |
| `demo/run_vg.gd` | Generic .vg test runner |

### Modified Source Files
| File | Changes |
|------|---------|
| `src/visual_gasic_parser.cpp` | `parse_class()`, `parse_property()`, Class dispatch, keyword param names |
| `src/visual_gasic_parser.h` | `parse_class()`, `parse_property()` declarations |
| `src/visual_gasic_ast.h` | `ClassDefinition` forward decl, `class_defs` in ModuleNode |
| `src/visual_gasic_tokenizer.cpp` | `Class`, `Property`, `Get`, `Let`, `Implements` keywords |
| `src/visual_gasic_instance.cpp` | `invoke_lambda()`, class bridges (EXPR_NEW, MEMBER_ACCESS, STMT_CALL, assign_to_target), builtin dispatch fix |
| `src/visual_gasic_instance.h` | `invoke_lambda()` declaration |
| `src/visual_gasic_builtins.cpp` | Map, Filter, Reduce, Any, All, Find implementations |

### Modified Documentation
| File | Changes |
|------|---------|
| `CHANGELOG.md` | v2.4.0 entry |
| `README.md` | Version badge, feature list |
| `ROADMAP.md` | Version, completed features |
| `PROJECT_STATUS.md` | Version, recent updates |
| `docs/guides/MODERN_FEATURES.md` | Block lambda, functional, class sections; IIf updated |
| `docs/guides/MODERN_FEATURES_README.md` | Feature count 13, new examples |
| `docs/reference/MODERN_SYNTAX_QUICK_REF.md` | New keywords, examples |
| `docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md` | Expanded functional docs |

---

## ⬆️ Upgrade Notes

- **No breaking changes** — all existing .vg code continues to work
- **New keywords**: `Class`, `Property`, `Get`, `Let`, `Implements` are now reserved
- **`Value` is no longer a keyword** — can be used as variable/parameter name
- Block lambdas use `Return value` (not VB-style function-name assignment)

---

## 🗺️ What's Next

- Inheritance runtime (`Inherits BaseClass` with method overriding)
- LINQ-style query expressions
- Pattern matching with destructuring
- Async/Await coroutines
- Dictionary performance optimization

---

**Full changelog**: See [CHANGELOG.md](CHANGELOG.md)  
**Documentation**: See [docs/guides/MODERN_FEATURES.md](docs/guides/MODERN_FEATURES.md)

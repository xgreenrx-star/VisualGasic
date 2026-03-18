# VisualGasic New Builtin Functions Reference

Quick reference for all newly implemented builtin functions (44 total).

## String Functions (5)

```vb
' String testing
StartsWith(string, prefix)      ' Returns True if string starts with prefix
EndsWith(string, suffix)         ' Returns True if string ends with suffix  
Contains(string, substring)      ' Returns True if string contains substring

' String padding
PadLeft(string, length)          ' Pad left with spaces: PadLeft("5", 3) → "  5"
PadLeft(string, length, char)    ' Pad with custom char: PadLeft("5", 3, "0") → "005"
PadRight(string, length)         ' Pad right with spaces
PadRight(string, length, char)   ' Pad right with custom char
```

**Examples:**
```vb
StartsWith("Hello", "He")     ' True
EndsWith("World", "ld")       ' True
Contains("Hello", "ell")      ' True
PadLeft("42", 5)              ' "   42"
PadRight("42", 5, "0")        ' "42000"
```

---

## Array Functions (15)

### Array Manipulation
```vb
Push(array, value)              ' Add element to end: Push([1,2], 3) → [1,2,3]
Pop(array)                      ' Remove and return last element
Slice(array, start, end)        ' Get subarray: Slice([1,2,3,4,5], 1, 3) → [2,3]
```

### Array Search
```vb
IndexOf(array, value)           ' Find index: IndexOf([1,2,3], 2) → 1
Contains(array, value)          ' Check if exists: Contains([1,2,3], 2) → True
```

### Array Transform
```vb
Reverse(array)                  ' Reverse: Reverse([1,2,3]) → [3,2,1]
Sort(array)                     ' Sort ascending: Sort([3,1,2]) → [1,2,3]
Unique(array)                   ' Remove duplicates: Unique([1,2,2,3]) → [1,2,3]
Flatten(array)                  ' Flatten nested: Flatten([[1,2],[3]]) → [1,2,3]
```

### Array Generation
```vb
Repeat(value, count)            ' Repeat value: Repeat("X", 3) → ["X","X","X"]
Range(start, end, step)         ' Range with step: Range(0, 10, 2) → [0,2,4,6,8,10]
Zip(array1, array2)             ' Combine arrays: Zip([1,2], ["a","b"]) → [[1,"a"],[2,"b"]]
```

**Examples:**
```vb
Dim arr = [1, 2, 3, 4, 5]
Dim arr2 = Push(arr, 6)         ' [1,2,3,4,5,6]
Dim last = Pop(arr2)            ' 6
Dim sub = Slice(arr, 1, 3)      ' [2,3]
Dim idx = IndexOf(arr, 3)       ' 2
Dim sorted = Sort([5,2,8,1])    ' [1,2,5,8]
Dim unique = Unique([1,2,2,3])  ' [1,2,3]
Dim flat = Flatten([[1,2],[3]]) ' [1,2,3]
```

---

## Dictionary Functions (5)

```vb
Keys(dictionary)                ' Get array of all keys
Values(dictionary)              ' Get array of all values
HasKey(dictionary, key)         ' Check if key exists: HasKey(dict, "name") → True
Merge(dict1, dict2)             ' Combine dictionaries (dict2 overwrites dict1)
Remove(dictionary, key)         ' Remove key from dictionary
Clear(dictionary)               ' Remove all keys
```

**Examples:**
```vb
Dim person = {"name": "Alice", "age": 30}
Dim k = Keys(person)            ' ["name", "age"]
Dim v = Values(person)          ' ["Alice", 30]
Dim has = HasKey(person, "age") ' True

Dim extra = {"city": "NYC"}
Dim merged = Merge(person, extra) ' {"name":"Alice", "age":30, "city":"NYC"}

Dim removed = Remove(person, "age") ' {"name": "Alice"}
```

---

## Type Checking Functions (6)

```vb
IsArray(value)                  ' Returns True if value is an Array
IsDict(value)                   ' Returns True if value is a Dictionary
IsString(value)                 ' Returns True if value is a String
IsNumber(value)                 ' Returns True if value is Int or Float
IsNull(value)                   ' Returns True if value is Null/Nil
TypeName(value)                 ' Returns type name as string: "Array", "Dictionary", etc.
```

**Examples:**
```vb
IsArray([1,2,3])               ' True
IsDict({"key": "val"})         ' True
IsString("hello")              ' True
IsNumber(42)                   ' True
IsNull(Null)                   ' True
TypeName([1,2,3])              ' "Array"
TypeName(42)                   ' "Int"
```

---

## JSON Functions (2)

```vb
JsonParse(json_string)                          ' Parse JSON string to Dictionary/Array
JsonStringify(value)                            ' Convert value to JSON string
JsonStringify(value, indent)                    ' Pretty-print with indent
JsonStringify(value, indent, sort_keys, full)   ' Full control
```

**Examples:**
```vb
' Parse JSON
Dim json = '{"name":"Bob","age":25}'
Dim data = JsonParse(json)
Print data["name"]              ' "Bob"

' Create JSON
Dim person = {"name": "Alice", "age": 30}
Dim str = JsonStringify(person)
Print str                       ' {"name":"Alice","age":30}

' Pretty-print with indent
Dim pretty = JsonStringify(person, "  ")
```

---

## File System Functions (5)

```vb
FileExists(path)                ' Check if file exists: FileExists("data.txt") → True
DirExists(path)                 ' Check if directory exists: DirExists("folder") → True
ReadAllText(path)               ' Read entire file as string
WriteAllText(path, text)        ' Write string to file (overwrites)
ReadLines(path)                 ' Read file as array of lines
```

**Examples:**
```vb
' Write file
WriteAllText("test.txt", "Hello" & Chr(10) & "World")

' Check existence
If FileExists("test.txt") Then
    Print "File exists!"
End If

' Read entire file
Dim content = ReadAllText("test.txt")
Print content

' Read as lines
Dim lines = ReadLines("test.txt")
Print lines(0)  ' "Hello"
Print lines(1)  ' "World"

' Check directory
If DirExists("./folder") Then
    Print "Directory exists!"
End If
```

---

## Functional Programming Functions (6) ✅

**Status**: ✅ Fully implemented. Lambda expressions required — use `Lambda`, `Fn`, `Function`, or `Sub` keywords.

### Map — Transform Each Element
```vb
Map(array, lambda)              ' Transform: Map([1,2,3], Fn(x) x*2) → [2,4,6]
```

**Examples:**
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim doubled = Map(nums, Fn(x) x * 2)       ' [2, 4, 6, 8, 10]
Dim labels = Map(nums, Fn(x) "Item " & CStr(x))  ' ["Item 1", "Item 2", ...]

' With block lambda
Dim result = Map(nums, Function(x)
    Dim label = "Val: " & CStr(x * 10)
    Return label
End Function)
```

### Filter — Select Matching Elements
```vb
Filter(array, lambda)           ' Filter: Filter([1,2,3,4], Fn(x) x>2) → [3,4]
```

**Examples:**
```vb
Dim nums = [1, 2, 3, 4, 5, 6, 7, 8]
Dim evens = Filter(nums, Fn(x) x Mod 2 = 0)    ' [2, 4, 6, 8]
Dim big = Filter(nums, Fn(x) x > 5)             ' [6, 7, 8]
```

### Reduce — Fold to Single Value
```vb
Reduce(array, lambda, init)     ' With initial: Reduce([1,2,3], Fn(a,b) a+b, 0) → 6
Reduce(array, lambda)           ' Without initial: uses first element as accumulator
```

**Examples:**
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim sum = Reduce(nums, Fn(a, b) a + b, 0)        ' 15
Dim product = Reduce(nums, Fn(a, b) a * b)        ' 120 (no init, uses 1 as start)
Dim maxVal = Reduce(nums, Fn(a, b) IIf(a > b, a, b))  ' 5
```

### Any — Check If Any Match
```vb
Any(array, lambda)              ' True if any element matches predicate
```

**Examples:**
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim hasEven = Any(nums, Fn(x) x Mod 2 = 0)     ' True
Dim hasHuge = Any(nums, Fn(x) x > 100)          ' False
```

### All — Check If All Match
```vb
All(array, lambda)              ' True if all elements match predicate
```

**Examples:**
```vb
Dim evens = [2, 4, 6, 8]
Dim allEven = All(evens, Fn(x) x Mod 2 = 0)    ' True

Dim mixed = [1, 2, 3]
Dim allEvenMixed = All(mixed, Fn(x) x Mod 2 = 0)  ' False
```

### Find — First Matching Element
```vb
Find(array, lambda)             ' Returns first element matching predicate, or Null
```

**Examples:**
```vb
Dim nums = [1, 2, 3, 4, 5]
Dim firstBig = Find(nums, Fn(x) x > 3)          ' 4
Dim firstHuge = Find(nums, Fn(x) x > 100)       ' Null
```

### Chaining Functional Operations
```vb
' Pipeline: filter → map → reduce
Dim data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
Dim evens = Filter(data, Fn(x) x Mod 2 = 0)     ' [2, 4, 6, 8, 10]
Dim doubled = Map(evens, Fn(x) x * 2)            ' [4, 8, 12, 16, 20]
Dim total = Reduce(doubled, Fn(a, b) a + b, 0)   ' 60
```

---

## Date/Time Functions (4) — *Updated in v2.10.0*

```vb
Weekday(date, [firstDayOfWeek])   ' Day of week 1-7 (1=Sunday default)
WeekdayName(day, [abbreviate])    ' Name from number: WeekdayName(6) → "Friday"
MonthName(month, [abbreviate])    ' Name from number: MonthName(1) → "January"
Timer()                           ' Seconds since midnight as Double (New in v2.10.0)
```

**Examples:**
```vb
Dim d = Weekday("7/4/2025")        ' 6 (Friday)
Dim full = WeekdayName(6)           ' "Friday"
Dim short = WeekdayName(6, True)    ' "Fri"
Dim month = MonthName(12)           ' "December"
Dim abbr = MonthName(12, True)      ' "Dec"
```

---

## System/Environment Functions (3) — *New in v2.5.0*

```vb
QBColor(colorIndex)               ' Classic VB6 16-color palette (0-15)
Environ(variable)                 ' Read OS environment variable
Beep                              ' System beep (prints "[BEEP]" to console)
```

**Examples:**
```vb
Dim black = QBColor(0)             ' 0x000000
Dim white = QBColor(15)            ' 0xFFFFFF
Dim red = QBColor(4)               ' 0xAA0000
Dim path = Environ("PATH")         ' OS PATH variable
Dim home = Environ("HOME")         ' Home directory
Beep                               ' Audible alert
```

---

## File System Functions (5) — *New in v2.5.0*

```vb
MkDir path                        ' Create directory
RmDir path                        ' Remove directory
ChDir path                        ' Change current working directory
CurDir()                          ' Get current working directory
FileCopy source, destination      ' Copy a file
```

**Examples:**
```vb
MkDir "res://saves"
ChDir "res://saves"
Print CurDir()                     ' "res://saves"
FileCopy "res://template.dat", "res://saves/game.dat"
RmDir "res://temp"
```

---

## Debugging Statements (1) — *New in v2.5.0*

```vb
Stop                              ' Break into debugger (VB6-compatible)
```

**Examples:**
```vb
Sub ProcessData(value)
    If value < 0 Then
        Stop                       ' Break here to inspect negative value
    End If
    ' ... processing
End Sub
```

---

## VB6 Global Objects (3) — *New in v2.10.0*

Virtual global objects resolved automatically — no `Dim` or `New` required.

```vb
App.Path                          ' Directory containing the executable
App.EXEName                       ' Executable filename
App.Title                         ' Application title
App.Major / App.Minor / App.Revision  ' Version numbers

Screen.Width / Screen.Height      ' Screen dimensions in pixels
Screen.TwipsPerPixelX/Y           ' Always 1 (pixel units)

Err.Number                        ' Last error number
Err.Description                   ' Last error description
Err.Source                        ' Error source module (New in v2.10.0)
Err.Clear                         ' Reset error state
Err.Raise number, source, desc    ' Raise a runtime error
```

---

## COM-Style Objects (4) — *New in v2.10.0*

Instantiate with `Dim obj As New ClassName` or `CreateObject("ProgID")`.

### VGCollection
```vb
Dim col As New Collection         ' or CreateObject("VB6.Collection")
col.Add item [, key] [, Before n] [, After n]
col.Remove index_or_key
col.Item(index_or_key)            ' 1-based indexing
col.Count                         ' Number of items
col.HasKey(key)                   ' Check key existence
col.Clear                         ' Remove all items
col.ToArray                       ' Return all items as Array
```

### VGRegEx
```vb
Dim re As New RegExp              ' or CreateObject("VBScript.RegExp")
re.Pattern = "\d+"
re.Global = True
re.IgnoreCase = False
re.Test(string)                   ' Returns True if pattern matches
re.Execute(string)                ' Returns Array of VGRegExMatch objects
re.Replace(string, replacement)   ' Replace matched text
```

### VGHttpRequest
```vb
Dim http As New HttpRequest       ' or CreateObject("MSXML2.XMLHTTP")
http.open method, url
http.setRequestHeader name, value
http.send [body]
http.responseText                 ' Response body string
http.status                       ' HTTP status code
http.getAllResponseHeaders         ' All headers as string
```

### VGTimer
```vb
Dim tmr As New VBTimer
tmr.Interval = 1000               ' Milliseconds
tmr.Enabled = True                ' Start/stop the timer
Timer()                           ' Seconds since midnight as Double
```

---

## File I/O Statements (4 opcodes) — *New in v2.10.0*

Bytecode-compiled file I/O statements:

```vb
Print #fileNum, expression        ' Write formatted output
Write #fileNum, expression        ' Write CSV-style quoted output
Input #fileNum, variable          ' Read delimited value
Line Input #fileNum, variable     ' Read entire line
```

---

## GoSub/Return — *New in v2.10.0*

Intra-procedure branching with return address stack:

```vb
GoSub label                       ' Push return address and jump to label
Return                            ' Pop and return to caller
```

---

## Existing VB6 Functions Still Available

These were already implemented and still work:

### String Functions
- `Len()`, `Left()`, `Right()`, `Mid()`
- `UCase()`, `LCase()`
- `Trim()`, `LTrim()`, `RTrim()`
- `Asc()`, `Chr()`, `Space()`, `String()`
- `Str()`, `Val()`, `InStr()`
- `Replace()`, `Split()`, `Join()`
- `StrReverse()`, `Hex()`, `Oct()`

### Array Functions
- `UBound()`, `LBound()`

### Math Functions
- `Sin()`, `Cos()`, `Tan()`, `Atn()`, `Log()`, `Exp()`
- `Sqr()`, `Abs()`, `Sgn()`, `Int()`, `Rnd()`
- `Round()`, `RandRange()`, `Lerp()`, `Clamp()`

### Type Conversion
- `CInt()`, `CDbl()`, `CBool()`

### File Functions
- `LOF()`, `Loc()`, `EOF()`, `FreeFile()`, `FileLen()`, `Dir()`

### Vector Math
- `Vec2()`, `Vec3()` - Create vector from components
- `VAdd()`, `VSub()`, `VMul()` - Vector arithmetic
- `VDot()`, `VCross()` - Vector products
- `VLen()`, `VNormalize()` - Vector length and normalization
- `VDistance()`, `VLerp()` - Distance and interpolation

### Utility
- `SetProp(obj, property, value)` - Set object property dynamically
- `AddChild(child)` - Add node as child of current form/script owner

---

## Complete Function Count

- **String**: 5 new + 13 existing = **18 total**
- **Array**: 15 new + 2 existing = **17 total**
- **Dictionary**: 5 new = **5 total**
- **Type Checking**: 6 new = **6 total**
- **JSON**: 2 new = **2 total**
- **File System**: 5 new (v2.5) + 5 new + 6 existing = **16 total**
- **Functional**: 6 new = **6 total** ✅
- **Date/Time**: 3 + 1 (Timer, v2.10) = **4 total**
- **System/Environment**: 3 new (v2.5) = **3 total**
- **Debugging**: 1 new (v2.5, Stop statement) = **1 total**
- **Math**: 0 new + 11 existing = **11 total**
- **Vector**: 12 (Vec2, Vec3, VAdd, VSub, VMul, VDot, VCross, VLen, VNormalize, VDistance, VLerp, SetProp) = **12 total**
- **Utility**: 2 new (SetProp, AddChild) = **2 total**
- **VB6 Global Objects** (v2.10): App, Screen, Err = **3 virtual objects**
- **COM-Style Objects** (v2.10): VGCollection, VGRegEx, VGHttpRequest, VGTimer = **4 classes**
- **File I/O Opcodes** (v2.10): Print#, Write#, Input#, Line Input# = **4 statements**
- **GoSub/Return** (v2.10): GoSub, Return = **2 flow-control statements**

**Grand Total**: 57 new functions + 52 existing + 13 v2.10.0 features = **122 builtins & features!**

---

## Usage Tips

### String Operations
```vb
' Modern approach with new functions
If StartsWith(filename, "data_") And EndsWith(filename, ".txt") Then
    Print "Valid data file"
End If
```

### Array Processing
```vb
' Build arrays easily
Dim data = [1, 2, 3, 4, 5]
data = Push(data, 6)
data = Sort(data)
data = Unique(data)
```

### Dictionary Usage
```vb
' Work with configuration
Dim config = {"host": "localhost", "port": 8080}
If HasKey(config, "timeout") Then
    Print "Timeout:", config["timeout"]
Else
    config["timeout"] = 30
End If
```

### JSON for Data Exchange
```vb
' Save/load data as JSON
Dim settings = {"theme": "dark", "fontSize": 14}
WriteAllText("settings.json", JsonStringify(settings, "  "))

' Later...
Dim loaded = JsonParse(ReadAllText("settings.json"))
Print "Theme:", loaded["theme"]
```

### Type Safety
```vb
' Validate input
Function ProcessData(input)
    If Not IsArray(input) Then
        Print "Error: Expected array, got", TypeName(input)
        Exit Function
    End If
    ' Process array...
End Function
```

---

## v3.3.0 New Builtins

### Count(collection)
Returns element count for Array, Dictionary, or String length.
```vb
Count(Array(1,2,3))   ' → 3
Count("Hello")         ' → 5
```

### Spc(n) / Tab(n)
`Spc(n)` returns n spaces. `Tab(n)` returns spaces to fill to column n.
```vb
Print "A"; Spc(5); "B"    ' → A     B
Print "A"; Tab(10); "B"   ' → A         B
```

### Bitwise Functions
`BitAnd(a,b)`, `BitOr(a,b)`, `BitXor(a,b)`, `BitNot(a)`, `BitShiftLeft(val,bits)`, `BitShiftRight(val,bits)`

### Math Functions
`Ceiling(n)` — round up. `Floor(n)` — round down. `Atan2(y,x)` — arc tangent of y/x.

### Array Utilities
- `Array.Copy(arr)` — deep copy
- `Array.Fill(size, value)` — create filled array
- `Array.Shuffle(arr)` — randomize in place
- `Array.Transpose(matrix)` — transpose 2D array

### String Utilities
- `String.Contains(str, search)` / `StrContains(str, search)` — boolean
- `String.Repeat(str, n)` / `StrRepeat(str, n)` — repeat string n times

### RegExp
- `RegExp.Test(str, pattern)` — returns Boolean
- `RegExp.Execute(str, pattern)` — returns Array of matches
- `RegExp.Replace(str, pattern, replacement)` — returns new string

### StringBuilder
```vb
Dim sb = NewStringBuilder()
sb.Append "text"
sb.AppendLine "with newline"
sb.Insert 0, "prefix"
sb.Replace "old", "new"
sb.Length  ' property
sb.ToString()
sb.Clear
```

### Sleep(ms)
Pauses execution for `ms` milliseconds.

### Assert(condition, message)
Raises error if condition is False.

### Image & Texture APIs *(New in v4.2.0)*

**Creation:**
- `CreateImage(w, h [, fillColor])` — create RGBA8 Image (1–4096 px)
- `CreateTexture(image)` / `CreateTexture(w, h [, fillColor])` — create ImageTexture
- `ImageToTexture(image)` — convert Image → ImageTexture

**Pixel Access:**
- `SetImagePixel(image, x, y, color)` — write pixel
- `GetImagePixel(image, x, y)` — read pixel → Color
- `FillImage(image, color)` — fill entire Image
- `FillImageRect(image, x, y, w, h, color)` — fill rectangular region

**Native Drawing** *(v4.2.0-beta5)*:
- `DrawImageLine(image, x1, y1, x2, y2, color)` — Bresenham line
- `DrawImageRect(image, x1, y1, x2, y2, color)` — 1px outline rectangle
- `DrawImageEllipse(image, cx, cy, rx, ry, color)` — midpoint ellipse outline
- `DrawImageCircle(image, cx, cy, radius, color)` — filled circle (scanline)
- `FloodFillImage(image, x, y, color)` — 4-connected flood fill (native C++)

**Copy / Sync:**
- `BlitImage(dest, src, srcRect, destPos)` — copy pixel region between Images
- `UpdateTexture(texture, image)` — push Image data to ImageTexture

**Query:**
- `ImageWidth(image)`, `ImageHeight(image)` — Image dimensions
- `TextureWidth(texture)`, `TextureHeight(texture)` — Texture dimensions
- `GetTextureImage(texture)` — extract Image from ImageTexture

**File I/O:**
- `SaveImage(image, path)` — save as PNG
- `LoadImage(path)` — load image file as Image

---

## See Also

- [Modern Features Guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/MODERN_FEATURES.md) - Modern syntax features
- [VisualGasic Language Reference](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/VisualGasic_Language_Reference.md) - Complete language manual
- [System Integration (v3.0)](../SYSTEM_INTEGRATION.md) - FFI, ODBC, Crypto, XML, ZIP, Async, Packages
- [test_new_builtins.vg](https://github.com/xgreenrx-star/VisualGasic/blob/main/test_proj/test_suite/test_new_builtins.vg) - Comprehensive test examples

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

## Functional Programming Functions (6) ⚠️

**Note**: These require lambda callable support (currently placeholder implementations)

```vb
Map(array, lambda)              ' Transform: Map([1,2,3], Lambda(x) => x*2) → [2,4,6]
Filter(array, lambda)           ' Filter: Filter([1,2,3,4], Lambda(x) => x>2) → [3,4]
Reduce(array, lambda, init)     ' Reduce: Reduce([1,2,3], Lambda(a,b) => a+b, 0) → 6
Any(array, lambda)              ' Check if any match condition
All(array, lambda)              ' Check if all match condition
Find(array, lambda)             ' Find first matching element
```

**Status**: Parser ready, runtime execution pending full lambda callable support.

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
- `Vec3()`, `VAdd()`, `VSub()`, `VDot()`, `VCross()`, `VLen()`, `VNormalize()`

---

## Complete Function Count

- **String**: 5 new + 13 existing = **18 total**
- **Array**: 15 new + 2 existing = **17 total**
- **Dictionary**: 5 new = **5 total**
- **Type Checking**: 6 new = **6 total**
- **JSON**: 2 new = **2 total**
- **File System**: 5 new + 6 existing = **11 total**
- **Functional**: 6 new (partial) = **6 total**
- **Math**: 0 new + 11 existing = **11 total**
- **Vector**: 0 new + 7 existing = **7 total**

**Grand Total**: 44 new functions + 39 existing = **83 builtin functions!**

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

## See Also

- [MODERN_FEATURES.md](MODERN_FEATURES.md) - Modern syntax features
- [examples/test_new_builtins.vg](examples/test_new_builtins.vg) - Comprehensive test examples

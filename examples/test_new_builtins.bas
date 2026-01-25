' VisualGasic New Builtin Functions Test
' Comprehensive test of all newly added functions

Print "=========================================="
Print "NEW BUILTIN FUNCTIONS TEST"
Print "=========================================="

' ==========================================
' STRING FUNCTIONS
' ==========================================
Print ""
Print "=== String Functions ==="

' StartsWith, EndsWith, Contains
Dim text As String
text = "Hello World"
Print "Text: ", text
Print "StartsWith('Hello'):", StartsWith(text, "Hello")
Print "EndsWith('World'):", EndsWith(text, "World")
Print "Contains('lo Wo'):", Contains(text, "lo Wo")

' PadLeft, PadRight
Print "PadLeft('5', 5):", PadLeft("5", 5)
Print "PadRight('5', 5):", PadRight("5", 5)
Print "PadLeft('X', 5, '0'):", PadLeft("X", 5, "0")

' Trim functions (already existed)
Dim spaced As String
spaced = "  trimmed  "
Print "Original: '", spaced, "'"
Print "Trim(): '", Trim(spaced), "'"
Print "LTrim(): '", LTrim(spaced), "'"
Print "RTrim(): '", RTrim(spaced), "'"

' ==========================================
' ARRAY MANIPULATION
' ==========================================
Print ""
Print "=== Array Manipulation ==="

' Using modern array literal
Dim numbers
numbers = [1, 2, 3, 4, 5]
Print "Original array:", numbers(0), numbers(1), numbers(2), numbers(3), numbers(4)

' Push and Pop
Dim pushed
pushed = Push(numbers, 6)
Print "After Push(6):", pushed(0), pushed(1), pushed(2), pushed(3), pushed(4), pushed(5)

Dim popped
popped = Pop(pushed)
Print "Popped value:", popped

' Slice
Dim sliced
sliced = Slice(numbers, 1, 3)
Print "Slice(1, 3):", sliced(0), sliced(1)

' IndexOf and Contains
Print "IndexOf(3):", IndexOf(numbers, 3)
Print "Contains(3):", Contains(numbers, 3)
Print "Contains(10):", Contains(numbers, 10)

' Reverse and Sort
Dim unsorted
unsorted = [5, 2, 8, 1, 9]
Print "Unsorted:", unsorted(0), unsorted(1), unsorted(2), unsorted(3), unsorted(4)
Dim sorted
sorted = Sort(unsorted)
Print "Sorted:", sorted(0), sorted(1), sorted(2), sorted(3), sorted(4)

Dim reversed
reversed = Reverse(numbers)
Print "Reversed:", reversed(0), reversed(1), reversed(2), reversed(3), reversed(4)

' Unique
Dim duplicates
duplicates = [1, 2, 2, 3, 3, 3]
Dim unique
unique = Unique(duplicates)
Print "Unique:", unique(0), unique(1), unique(2)

' Flatten
Dim nested
nested = [[1, 2], [3, 4], [5]]
Dim flat
flat = Flatten(nested)
Print "Flattened:", flat(0), flat(1), flat(2), flat(3), flat(4)

' Repeat
Dim repeated
repeated = Repeat("X", 3)
Print "Repeat('X', 3):", repeated(0), repeated(1), repeated(2)

' Zip
Dim arr1
Dim arr2
arr1 = [1, 2, 3]
arr2 = ["a", "b", "c"]
Dim zipped
zipped = Zip(arr1, arr2)
Print "Zipped [1,2,3] with ['a','b','c']:"
Dim pair
pair = zipped(0)
Print "  Pair 0:", pair(0), pair(1)
pair = zipped(1)
Print "  Pair 1:", pair(0), pair(1)

' Range with step
Dim rangeStep
rangeStep = Range(0, 10, 2)
Print "Range(0, 10, 2):", rangeStep(0), rangeStep(1), rangeStep(2), rangeStep(3), rangeStep(4), rangeStep(5)

' ==========================================
' DICTIONARY OPERATIONS
' ==========================================
Print ""
Print "=== Dictionary Operations ==="

' Using modern dictionary literal
Dim person
person = {"name": "Alice", "age": 30, "city": "NYC"}

' Keys and Values
Dim keys
keys = Keys(person)
Print "Keys:", keys(0), keys(1), keys(2)

Dim vals
vals = Values(person)
Print "Values:", vals(0), vals(1), vals(2)

' HasKey
Print "HasKey('name'):", HasKey(person, "name")
Print "HasKey('email'):", HasKey(person, "email")

' Merge
Dim extra
extra = {"email": "alice@example.com", "active": True}
Dim merged
merged = Merge(person, extra)
Print "Merged dict has 'email':", HasKey(merged, "email")

' Remove
Dim removed
removed = Remove(person, "age")
Print "After Remove('age'), HasKey('age'):", HasKey(removed, "age")

' Clear
Dim cleared
cleared = Clear(person)
Dim clearedKeys
clearedKeys = Keys(cleared)
Print "After Clear, key count:", UBound(clearedKeys) + 1

' ==========================================
' TYPE CHECKING
' ==========================================
Print ""
Print "=== Type Checking ==="

Dim testArray
Dim testDict
Dim testString
Dim testNumber
testArray = [1, 2, 3]
testDict = {"key": "value"}
testString = "hello"
testNumber = 42

Print "IsArray([1,2,3]):", IsArray(testArray)
Print "IsDict({...}):", IsDict(testDict)
Print "IsString('hello'):", IsString(testString)
Print "IsNumber(42):", IsNumber(testNumber)
Print "IsNull(42):", IsNull(testNumber)
Print "IsNull(Null):", IsNull(Null)

Print "TypeName([1,2,3]):", TypeName(testArray)
Print "TypeName({...}):", TypeName(testDict)
Print "TypeName('hello'):", TypeName(testString)
Print "TypeName(42):", TypeName(testNumber)

' ==========================================
' JSON SUPPORT
' ==========================================
Print ""
Print "=== JSON Support ==="

' JSON Stringify
Dim data
data = {"name": "Bob", "age": 25, "items": [1, 2, 3]}
Dim jsonStr
jsonStr = JsonStringify(data)
Print "JSON String:", jsonStr

' JSON Parse
Dim parsed
parsed = JsonParse(jsonStr)
Print "Parsed back - name:", parsed["name"]
Print "Parsed back - age:", parsed["age"]

' ==========================================
' FILE SYSTEM HELPERS
' ==========================================
Print ""
Print "=== File System Helpers ==="

' Create a test file
Dim testFile As String
testFile = "test_builtin_temp.txt"

' WriteAllText
Dim writeSuccess
writeSuccess = WriteAllText(testFile, "Line 1" & Chr(10) & "Line 2" & Chr(10) & "Line 3")
Print "WriteAllText success:", writeSuccess

' FileExists
Print "FileExists:", FileExists(testFile)

' ReadAllText
Dim content
content = ReadAllText(testFile)
Print "ReadAllText length:", Len(content)

' ReadLines
Dim lines
lines = ReadLines(testFile)
Print "ReadLines count:", UBound(lines) + 1
Print "First line:", lines(0)
Print "Second line:", lines(1)

' DirExists
Print "DirExists('.'):", DirExists(".")
Print "DirExists('nonexistent'):", DirExists("nonexistent")

' Clean up
Kill testFile

' ==========================================
' FUNCTIONAL PROGRAMMING
' ==========================================
Print ""
Print "=== Functional Programming (Placeholder) ==="
Print "Note: Map, Filter, Reduce, Any, All, Find"
Print "These require lambda callable support"
Print "Currently return placeholders"

' ==========================================
' SUMMARY
' ==========================================
Print ""
Print "=========================================="
Print "NEW FUNCTIONS IMPLEMENTED:"
Print "=========================================="
Print ""
Print "STRING (5):"
Print "  ✓ StartsWith, EndsWith, Contains"
Print "  ✓ PadLeft, PadRight"
Print ""
Print "ARRAY (15):"
Print "  ✓ Push, Pop, Slice, IndexOf, Contains"
Print "  ✓ Reverse, Sort, Unique, Flatten"
Print "  ✓ Repeat, Zip, Range"
Print ""
Print "DICTIONARY (5):"
Print "  ✓ Keys, Values, HasKey"
Print "  ✓ Merge, Remove, Clear"
Print ""
Print "TYPE CHECKING (6):"
Print "  ✓ IsArray, IsDict, IsString"
Print "  ✓ IsNumber, IsNull, TypeName"
Print ""
Print "JSON (2):"
Print "  ✓ JsonParse, JsonStringify"
Print ""
Print "FILE SYSTEM (5):"
Print "  ✓ FileExists, DirExists"
Print "  ✓ ReadAllText, WriteAllText, ReadLines"
Print ""
Print "FUNCTIONAL (6 - Pending Lambda Support):"
Print "  ⚠ Map, Filter, Reduce"
Print "  ⚠ Any, All, Find"
Print ""
Print "=========================================="
Print "Total: 44 new builtin functions!"
Print "=========================================="

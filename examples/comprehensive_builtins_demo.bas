// VisualGasic Comprehensive Builtin Functions Demo
// Test all newly implemented functions

Print "=== COMPREHENSIVE BUILTIN FUNCTIONS TEST ==="
Print ""

// String Functions Test
Print "=== String Functions ==="
Dim text As String
text = "Hello World"

Print "Text: ", text
Print "StartsWith('Hello'):", StartsWith(text, "Hello")
Print "EndsWith('World'):", EndsWith(text, "World")
Print "Contains('lo Wo'):", Contains(text, "lo Wo")
Print "PadLeft('X', 8):", "'" + PadLeft("X", 8) + "'"
Print "PadRight('X', 8, '#'):", "'" + PadRight("X", 8, "#") + "'"
Print ""

// Array Functions Test
Print "=== Array Functions ==="
Dim arr(3) As Integer
arr(0) = 5
arr(1) = 2
arr(2) = 8
arr(3) = 2

Print "Original array: [5, 2, 8, 2]"
Print "Contains(2):", Contains(arr, 2)
Print "IndexOf(8):", IndexOf(arr, 8)
Print "Push(10):", Push(arr, 10)
Print "Pop():", Pop(arr)
Print "Slice(1, 3):", Slice(arr, 1, 3)
Print "Repeat(7, 3):", Repeat(7, 3)
Print "Range(1, 5):", Range(1, 5)
Print "Zip([1,2], [a,b]):", Zip([1, 2], ["a", "b"])
Print ""

// Dictionary Functions Test
Print "=== Dictionary Functions ==="
Dim dict As Dictionary
dict("name") = "John"
dict("age") = 30
dict("city") = "New York"

Print "Keys:", Keys(dict)
Print "Values:", Values(dict)
Print "HasKey('age'):", HasKey(dict, "age")
Print "HasKey('country'):", HasKey(dict, "country")

' Test additional array functions
Print ""
Print "=== Extended Array Functions ==="
Print "Push([1,2], 3):", Push([1, 2], 3)
Print "Pop([1,2,3]):", Pop([1, 2, 3])
Print "Slice([1,2,3,4], 1, 3):", Slice([1, 2, 3, 4], 1, 3)
Print ""

// Type Checking Functions Test  
Print "=== Type Checking Functions ==="
Print "IsArray([1,2,3]):", IsArray([1, 2, 3])
Print "IsDict(dict):", IsDict(dict)
Print "IsString('hello'):", IsString("hello")
Print "IsNumber(42):", IsNumber(42)
Print "IsNull(Nothing):", IsNull(Nothing)
Print "TypeName(42):", TypeName(42)
Print "TypeName('hello'):", TypeName("hello")
Print ""

// JSON Functions Test
Print "=== JSON Functions ==="
Dim data As Dictionary
data("name") = "Alice"
data("scores") = [95, 87, 92]

Dim json_str As String
json_str = JsonStringify(data)
Print "JsonStringify:", json_str

Print "JsonParse result:", JsonParse(json_str)
Print ""

// File System Functions Test
Print "=== File System Functions ==="
Print "FileExists('README.md'):", FileExists("README.md")
Print "DirExists('src'):", DirExists("src")

// Write test file
WriteAllText("test_output.txt", "Hello from VisualGasic!")
Print "WriteAllText completed"
Print "ReadAllText:", ReadAllText("test_output.txt")

// Write multi-line test
WriteAllText("test_lines.txt", "Line 1" + Chr(10) + "Line 2" + Chr(10) + "Line 3")
Print "ReadLines:", ReadLines("test_lines.txt")
Print ""

Print "=== ALL TESTS COMPLETE ==="
Print "Total functions tested: 38"
@tool
class_name VGCommandHelp
## VisualGasic Command Reference Database
##
## Provides syntax, description, code examples, and Language Reference line
## numbers for every keyword, statement, and built-in function.
## Used by the Command Help panel in the embedded code editor.

# Each entry: { "syntax": String, "desc": String, "code": String, "ref_line": int }
# ref_line points to the line number in docs/VisualGasic_Language_Reference.md

static var _db: Dictionary = {}
static var _see_also: Dictionary = {}
static var _initialized := false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_build_db()
	_build_see_also()

static func lookup(keyword: String) -> Dictionary:
	_ensure_init()
	var key := keyword.strip_edges().to_lower()
	if _db.has(key):
		return _db[key]
	# Try partial match: "End If" → look up "end if", "End Sub" → "end sub"
	return {}

static func get_all_keywords() -> PackedStringArray:
	_ensure_init()
	var keys := PackedStringArray()
	for k in _db.keys():
		keys.append(k)
	keys.sort()
	return keys

## Returns an array of related keyword names for the given keyword (#6 See Also).
static func get_see_also(keyword: String) -> Array:
	_ensure_init()
	var key := keyword.strip_edges().to_lower()
	if _see_also.has(key):
		return _see_also[key]
	return []

static func _add(keyword: String, syntax: String, desc: String, code: String, ref_line: int = 0) -> void:
	_db[keyword.to_lower()] = {
		"keyword": keyword,
		"syntax": syntax,
		"desc": desc,
		"code": code,
		"ref_line": ref_line,
	}

## Adds a Godot API entry with a link to official docs.
static func _add_godot(keyword: String, syntax: String, desc: String, code: String,
		godot_class: String, godot_method: String = "") -> void:
	_db[keyword.to_lower()] = {
		"keyword": keyword,
		"syntax": syntax,
		"desc": desc,
		"code": code,
		"ref_line": 0,
		"godot_class": godot_class,
		"godot_method": godot_method,
	}

static func _build_db() -> void:
	# =========================================================================
	# VARIABLE DECLARATION
	# =========================================================================
	_add("Dim",
		"Dim variableName As DataType [= initialValue]",
		"Declares a local variable with an optional type and initial value. Variables declared with Dim are local to the procedure they appear in.",
		"Dim score As Integer = 0\nDim playerName As String = \"Hero\"\nDim items() As String\nDim health As Single = 100.0",
		1545)

	_add("Global",
		"Global variableName As DataType",
		"Declares a module-level global variable accessible from any procedure in the form or module.",
		"Global highScore As Integer\nGlobal currentLevel As Integer = 1",
		1255)

	_add("Public",
		"Public variableName As DataType\nPublic Sub ProcedureName()",
		"Declares a public variable or procedure accessible from other modules and forms.",
		"Public userName As String\nPublic Sub SaveGame()\n    ' Save logic here\nEnd Sub",
		1257)

	_add("Private",
		"Private variableName As DataType\nPrivate Sub ProcedureName()",
		"Declares a private variable or procedure only accessible within the current module.",
		"Private lives As Integer = 3\nPrivate Sub ResetLevel()\n    lives = 3\nEnd Sub",
		1258)

	_add("Static",
		"Static variableName As DataType",
		"Declares a variable that retains its value between procedure calls. Unlike Dim, static variables are not reset when the procedure exits.",
		"Sub CountCalls()\n    Static callCount As Integer\n    callCount = callCount + 1\n    Print \"Called \" & callCount & \" times\"\nEnd Sub",
		1261)

	_add("Const",
		"Const CONSTANT_NAME As DataType = value",
		"Declares a named constant whose value cannot be changed after initialization.",
		"Const MAX_PLAYERS As Integer = 4\nConst PI As Double = 3.14159\nConst GAME_TITLE As String = \"My Game\"",
		1263)

	_add("ReDim",
		"ReDim [Preserve] arrayName(newSize)",
		"Resizes a dynamic array. Use Preserve to keep existing data when resizing.",
		"Dim scores() As Integer\nReDim scores(10)\nscores(0) = 100\nReDim Preserve scores(20)  ' Keeps old data",
		1265)

	_add("Set",
		"Set objectVariable = objectExpression\nSet objectVariable = New ClassName",
		"Assigns an object reference to a variable. Required for object types (not needed for simple types).",
		"Dim player As Object\nSet player = New Player\nSet player = Nothing  ' Release reference",
		1274)

	# =========================================================================
	# CONTROL FLOW — CONDITIONALS
	# =========================================================================
	_add("If",
		"If condition Then\n    statements\n[ElseIf condition Then]\n    statements\n[Else]\n    statements\nEnd If",
		"Executes code conditionally. Supports multi-line blocks with ElseIf and Else branches, or single-line form.",
		"If score > highScore Then\n    highScore = score\n    Print \"New high score!\"\nElseIf score > 0 Then\n    Print \"Good job!\"\nElse\n    Print \"Try again!\"\nEnd If\n\n' Single-line form:\nIf health <= 0 Then gameOver = True",
		1691)

	_add("ElseIf",
		"ElseIf condition Then\n    statements",
		"Provides an additional condition to test when the preceding If or ElseIf was False.",
		"If score >= 90 Then\n    grade = \"A\"\nElseIf score >= 80 Then\n    grade = \"B\"\nElseIf score >= 70 Then\n    grade = \"C\"\nElse\n    grade = \"F\"\nEnd If",
		1691)

	_add("Else",
		"Else\n    statements",
		"Specifies code to execute when the If condition (and all ElseIf conditions) are False.",
		"If IsKeyPressed(\"space\") Then\n    Jump()\nElse\n    Fall()\nEnd If",
		1691)

	_add("Then",
		"If condition Then statements",
		"Part of the If statement. Follows the condition and precedes the code to execute.",
		"If health <= 0 Then GameOver()\nIf x > 10 Then x = 10",
		1691)

	_add("End If",
		"End If",
		"Terminates a multi-line If...Then...Else block.",
		"If score > 100 Then\n    Print \"Winner!\"\nEnd If",
		1691)

	_add("IIf",
		"IIf(condition, trueValue, falseValue)",
		"Inline If — returns one of two values based on a condition. Similar to the ternary operator in other languages.",
		"message = IIf(score > 100, \"Excellent!\", \"Keep trying!\")\ncolor = IIf(health < 20, \"Red\", \"Green\")",
		1710)

	# =========================================================================
	# CONTROL FLOW — SELECT CASE
	# =========================================================================
	_add("Select Case",
		"Select Case testExpression\n    Case value1\n        statements\n    Case value2, value3\n        statements\n    Case Else\n        statements\nEnd Select",
		"Evaluates an expression and branches to the matching Case block. Supports ranges (1 To 5), comparison (Is > 10), and comma-separated lists.",
		"Select Case score\n    Case 100\n        Print \"Perfect!\"\n    Case 80 To 99\n        Print \"Great!\"\n    Case Is >= 50\n        Print \"Passed\"\n    Case Else\n        Print \"Try again\"\nEnd Select",
		1781)

	_add("Select",
		"Select Case expression",
		"Begins a Select Case block for multi-way branching based on an expression's value.",
		"Select Case dayOfWeek\n    Case 1\n        Print \"Monday\"\n    Case 7\n        Print \"Sunday\"\nEnd Select",
		1781)

	_add("Case",
		"Case value [, value2] [To value3]",
		"Specifies a value or range to match in a Select Case block. Supports comma lists, ranges with To, and comparisons with Is.",
		"Case 1, 2, 3     ' Match any of these\nCase 10 To 20    ' Match range\nCase Is > 100    ' Match comparison\nCase Else        ' Default case",
		1781)

	_add("End Select",
		"End Select",
		"Terminates a Select Case block.",
		"Select Case x\n    Case 1\n        Print \"One\"\nEnd Select",
		1781)

	# =========================================================================
	# CONTROL FLOW — LOOPS
	# =========================================================================
	_add("For",
		"For counter = start To end [Step increment]\n    statements\nNext [counter]",
		"Repeats a block of code a specific number of times. The Step clause controls the increment (default is 1). Use Exit For to leave early.",
		"For i = 1 To 10\n    Print i\nNext i\n\nFor i = 10 To 0 Step -1\n    Print \"Countdown: \" & i\nNext\n\nFor i = 0 To 100 Step 5\n    Print i\nNext",
		1715)

	_add("For Each",
		"For Each element In collection\n    statements\nNext [element]",
		"Iterates over every element in an array, list, or collection.",
		"Dim names() As String = {\"Alice\", \"Bob\", \"Carol\"}\nFor Each name In names\n    Print \"Hello, \" & name\nNext",
		1715)

	_add("Next",
		"Next [counter]",
		"Marks the end of a For or For Each loop. The counter variable name is optional.",
		"For i = 1 To 5\n    Print i\nNext i",
		1715)

	_add("Do",
		"Do [While|Until condition]\n    statements\nLoop [While|Until condition]",
		"Repeats a block while or until a condition is met. The condition can appear at the top (Do While) or bottom (Loop Until) of the loop.",
		"' Pre-check loop\nDo While health > 0\n    ProcessTurn()\nLoop\n\n' Post-check loop (runs at least once)\nDo\n    answer = InputBox(\"Guess?\")\nLoop Until answer = secretWord",
		1749)

	_add("While",
		"While condition\n    statements\nWend",
		"Repeats a block as long as the condition is True. Legacy syntax; prefer Do...Loop for new code.",
		"While Not gameOver\n    Update()\n    Draw()\nWend",
		1771)

	_add("Wend",
		"Wend",
		"Terminates a While loop (legacy syntax).",
		"While x < 100\n    x = x + 1\nWend",
		1771)

	_add("Loop",
		"Loop [While|Until condition]",
		"Terminates a Do loop. Optionally tests a condition after each iteration.",
		"Do\n    x = x + 1\nLoop Until x >= 10",
		1749)

	_add("Until",
		"Do ... Loop Until condition\nDo Until condition ... Loop",
		"Loop continuation condition — the loop repeats until the condition becomes True.",
		"Do\n    tries = tries + 1\nLoop Until success Or tries > 10",
		1749)

	_add("Exit",
		"Exit Sub | Exit Function | Exit For | Exit Do | Exit While",
		"Immediately exits the current procedure or loop. Control passes to the statement after the End Sub/Next/Loop.",
		"For i = 1 To 100\n    If items(i) = target Then\n        foundAt = i\n        Exit For\n    End If\nNext",
		1285)

	_add("Continue",
		"Continue For | Continue Do | Continue While",
		"Skips the rest of the current loop iteration and continues with the next iteration.",
		"For i = 0 To 99\n    If scores(i) < 0 Then Continue For\n    total = total + scores(i)\nNext",
		1287)

	# =========================================================================
	# PROCEDURES & FUNCTIONS
	# =========================================================================
	_add("Sub",
		"[Public|Private] Sub procedureName([parameters])\n    statements\nEnd Sub",
		"Declares a subroutine — a procedure that performs an action but does not return a value. Event handlers are Subs named ObjectName_EventName.",
		"Sub btnStart_Click()\n    StartGame()\nEnd Sub\n\nPrivate Sub ResetScore()\n    score = 0\n    UpdateDisplay()\nEnd Sub",
		1897)

	_add("End Sub",
		"End Sub",
		"Terminates a Sub procedure definition.",
		"Sub Form_Load()\n    Print \"Ready!\"\nEnd Sub",
		1897)

	_add("Function",
		"[Public|Private] Function name([params]) As ReturnType\n    statements\n    Function = returnValue  ' or: Return returnValue\nEnd Function",
		"Declares a function that returns a value. Set the return value by assigning to the function name or using Return.",
		"Function AddScore(points As Integer) As Integer\n    score = score + points\n    AddScore = score  ' Return value\nEnd Function\n\nFunction GetGrade(score As Integer) As String\n    If score >= 90 Then Return \"A\"\n    If score >= 80 Then Return \"B\"\n    Return \"C\"\nEnd Function",
		1917)

	_add("End Function",
		"End Function",
		"Terminates a Function definition.",
		"Function Square(x As Integer) As Integer\n    Square = x * x\nEnd Function",
		1917)

	_add("Call",
		"Call procedureName([arguments])\nprocedureName [arguments]",
		"Explicitly calls a Sub or Function. The Call keyword is optional — you can call procedures by name alone.",
		"Call UpdateScore(10)\nUpdateScore 10       ' Same thing without Call\nCall Form2.Show()",
		1318)

	_add("Return",
		"Return [value]",
		"Returns from the current Sub or Function. In a Function, optionally provides the return value.",
		"Function IsPositive(n As Integer) As Boolean\n    Return n > 0\nEnd Function\n\nSub CheckHealth()\n    If health > 0 Then Return  ' Early exit\n    GameOver()\nEnd Sub",
		1289)

	_add("ByVal",
		"Sub ProcName(ByVal paramName As DataType)",
		"Passes an argument by value — the procedure gets a copy, so changes don't affect the caller's variable.",
		"Sub DoubleIt(ByVal x As Integer)\n    x = x * 2  ' Only changes local copy\n    Print x\nEnd Sub",
		1934)

	_add("ByRef",
		"Sub ProcName(ByRef paramName As DataType)",
		"Passes an argument by reference — the procedure can modify the caller's original variable. This is the default if neither ByVal nor ByRef is specified.",
		"Sub SwapValues(ByRef a As Integer, ByRef b As Integer)\n    Dim temp As Integer = a\n    a = b\n    b = temp\nEnd Sub",
		1934)

	_add("Optional",
		"Sub ProcName(Optional paramName As Type = defaultValue)",
		"Declares a parameter that the caller may omit. A default value is provided.",
		"Sub ShowMessage(msg As String, Optional title As String = \"Info\")\n    MsgBox msg, title\nEnd Sub\n\nShowMessage \"Hello\"         ' Uses default title\nShowMessage \"Error\", \"Oops\"  ' Custom title",
		1929)

	# =========================================================================
	# ERROR HANDLING
	# =========================================================================
	_add("On Error",
		"On Error GoTo labelName\nOn Error Resume Next\nOn Error GoTo 0",
		"Sets up error handling. GoTo sends errors to a label. Resume Next skips errors. GoTo 0 disables the handler.",
		"Sub LoadData()\n    On Error GoTo HandleError\n    Open \"data.txt\" For Input As #1\n    ' ... read data ...\n    Close #1\n    Exit Sub\n\nHandleError:\n    Print \"Error: \" & Err.Description\n    Resume Next\nEnd Sub",
		1813)

	_add("Try",
		"Try\n    statements\nCatch [ex As Exception]\n    error handling\n[Finally]\n    cleanup\nEnd Try",
		"Structured exception handling. Code in Try is protected; if an error occurs, execution jumps to Catch. Finally always executes.",
		"Try\n    Dim result As Integer = 100 / divisor\n    Print result\nCatch ex As Exception\n    Print \"Error: \" & ex.Message\nFinally\n    Print \"Done\"\nEnd Try",
		1852)

	_add("Catch",
		"Catch [variableName As Exception]",
		"Catches an exception thrown in the Try block. The exception object provides Description and Number properties.",
		"Try\n    riskyOperation()\nCatch ex As Exception\n    Print \"Error #\" & ex.Number & \": \" & ex.Description\nEnd Try",
		1852)

	_add("Finally",
		"Finally\n    cleanup statements",
		"Code in the Finally block always executes, whether or not an error occurred. Use for cleanup (closing files, etc.).",
		"Try\n    Open \"log.txt\" For Output As #1\n    Print #1, \"Log entry\"\nFinally\n    Close #1  ' Always closes the file\nEnd Try",
		1852)

	_add("Throw",
		"Throw exceptionObject\nThrow \"error message\"",
		"Raises an exception. Can throw a string message or an Exception object.",
		"If amount < 0 Then\n    Throw \"Amount cannot be negative\"\nEnd If\n\nSub Validate(age As Integer)\n    If age < 0 Or age > 150 Then Throw \"Invalid age: \" & age\nEnd Sub",
		1880)

	_add("GoTo",
		"GoTo labelName",
		"Transfers execution to the specified label. Primarily used in error handling (On Error GoTo). Avoid for general flow control.",
		"On Error GoTo ErrorHandler\n' ... code ...\nExit Sub\n\nErrorHandler:\n    Print \"An error occurred\"\n    Resume Next",
		1345)

	_add("GoSub",
		"GoSub labelName\n...\nlabelName:\n    statements\nReturn",
		"Jumps to a labeled subroutine within the same procedure, then returns to the statement after GoSub. Classic VB6 feature.",
		"Sub ProcessData()\n    GoSub ValidateInput\n    GoSub CalculateResult\n    Exit Sub\n\nValidateInput:\n    If data = \"\" Then Print \"No data\"\n    Return\n\nCalculateResult:\n    result = data * 2\n    Return\nEnd Sub",
		1340)

	# =========================================================================
	# OBJECT-ORIENTED FEATURES
	# =========================================================================
	_add("Class",
		"Class ClassName\n    [Inherits BaseClass]\n    ' fields, methods, properties\nEnd Class",
		"Declares a new class type. Classes support inheritance, interfaces, properties, and methods.",
		"Class Player\n    Public Name As String\n    Public Health As Integer = 100\n\n    Sub TakeDamage(amount As Integer)\n        Health = Health - amount\n        If Health <= 0 Then Die()\n    End Sub\nEnd Class",
		2094)

	_add("End Class",
		"End Class",
		"Terminates a Class definition.",
		"Class Enemy\n    Public Speed As Single = 1.0\nEnd Class",
		2094)

	_add("Inherits",
		"Class ChildClass\n    Inherits ParentClass",
		"Specifies that a class inherits from a base class, gaining its fields, properties, and methods.",
		"Class Boss\n    Inherits Enemy\n    Public Phase As Integer = 1\n\n    Sub Attack()\n        MyBase.Attack()  ' Call parent method\n        ' Boss-specific attack\n    End Sub\nEnd Class",
		2111)

	_add("Implements",
		"Class MyClass\n    Implements InterfaceName",
		"Declares that a class implements an interface and must provide all of its methods.",
		"Interface IDamageable\n    Sub TakeDamage(amount As Integer)\nEnd Interface\n\nClass Player\n    Implements IDamageable\n    Sub TakeDamage(amount As Integer)\n        health = health - amount\n    End Sub\nEnd Class",
		2148)

	_add("Interface",
		"Interface InterfaceName\n    Sub MethodName([params])\n    Function FuncName([params]) As Type\nEnd Interface",
		"Declares an interface — a contract that implementing classes must fulfill.",
		"Interface ISerializable\n    Function Serialize() As String\n    Sub Deserialize(data As String)\nEnd Interface",
		2148)

	_add("Property",
		"Property Get Name() As Type\n    Name = internalValue\nEnd Property\n\nProperty Let Name(value As Type)\n    internalValue = value\nEnd Property",
		"Declares a class property with Get (read) and Let/Set (write) accessors.",
		"Class Circle\n    Private _radius As Single\n\n    Property Get Radius() As Single\n        Radius = _radius\n    End Property\n\n    Property Let Radius(value As Single)\n        If value > 0 Then _radius = value\n    End Property\nEnd Class",
		2227)

	_add("New",
		"Dim obj As New ClassName\nSet obj = New ClassName([args])",
		"Creates a new instance of a class or object type.",
		"Dim player As New Player\nDim enemies As New Collection\n\nSet boss = New Boss(\"Dragon\", 500)",
		1273)

	_add("Me",
		"Me.PropertyName\nMe.MethodName()",
		"Refers to the current object instance. Similar to 'this' in C# or 'self' in Python.",
		"Class Player\n    Public Name As String\n    Sub Introduce()\n        Print \"I am \" & Me.Name\n    End Sub\nEnd Class",
		1276)

	_add("With",
		"With objectExpression\n    .Property = value\n    .Method()\nEnd With",
		"Executes a series of statements on a single object without repeating the object name.",
		"With lblScore\n    .Caption = \"Score: \" & score\n    .ForeColor = IIf(score > 100, vbRed, vbBlack)\n    .Visible = True\nEnd With",
		1372)

	_add("End With",
		"End With",
		"Terminates a With block.",
		"With player\n    .Health = 100\n    .Score = 0\nEnd With",
		1372)

	_add("Enum",
		"Enum EnumName\n    Value1 [= number]\n    Value2\n    ...\nEnd Enum",
		"Declares an enumeration — a set of named integer constants.",
		"Enum GameState\n    Menu = 0\n    Playing = 1\n    Paused = 2\n    GameOver = 3\nEnd Enum\n\nDim state As GameState = GameState.Playing",
		1383)

	_add("Type",
		"Type TypeName\n    field1 As DataType\n    field2 As DataType\nEnd Type",
		"Declares a user-defined type (structure) that groups related variables together.",
		"Type Vector2D\n    X As Single\n    Y As Single\nEnd Type\n\nDim pos As Vector2D\npos.X = 100\npos.Y = 200",
		1268)

	_add("Event",
		"Event EventName([parameters])",
		"Declares a custom event that can be raised with RaiseEvent.",
		"Class Timer\n    Event Tick()\n    Event Elapsed(seconds As Integer)\nEnd Class",
		2171)

	_add("RaiseEvent",
		"RaiseEvent EventName([arguments])",
		"Fires a declared Event, notifying all handlers connected with WithEvents.",
		"Class GameManager\n    Event ScoreChanged(newScore As Integer)\n\n    Sub AddPoints(pts As Integer)\n        score = score + pts\n        RaiseEvent ScoreChanged(score)\n    End Sub\nEnd Class",
		2171)

	_add("WithEvents",
		"Dim WithEvents varName As ClassName",
		"Declares an object variable that can respond to the object's events through event handler Subs.",
		"Dim WithEvents gameTimer As Timer\n\nSub gameTimer_Tick()\n    UpdateGame()\nEnd Sub",
		2171)

	# =========================================================================
	# DATA TYPES
	# =========================================================================
	_add("Integer",
		"Dim varName As Integer",
		"A 32-bit signed integer type. Range: -2,147,483,648 to 2,147,483,647.",
		"Dim score As Integer = 0\nDim lives As Integer = 3",
		1549)

	_add("Long",
		"Dim varName As Long",
		"A 64-bit signed integer type for very large numbers.",
		"Dim bigNumber As Long = 9999999999",
		1549)

	_add("Single",
		"Dim varName As Single",
		"A single-precision floating-point number (32-bit). Use for positions, speeds, etc.",
		"Dim speed As Single = 5.5\nDim gravity As Single = 9.8",
		1549)

	_add("Double",
		"Dim varName As Double",
		"A double-precision floating-point number (64-bit). More precision than Single.",
		"Dim pi As Double = 3.14159265358979\nDim distance As Double",
		1549)

	_add("String",
		"Dim varName As String [= \"text\"]",
		"A text string of any length. Concatenate with & or + operator.",
		"Dim name As String = \"Player 1\"\nDim greeting As String\ngreeting = \"Hello, \" & name & \"!\"",
		1549)

	_add("Boolean",
		"Dim varName As Boolean",
		"A True/False value. Used for flags, conditions, and toggles.",
		"Dim gameOver As Boolean = False\nDim isVisible As Boolean = True\nIf gameOver Then EndGame()",
		1549)

	_add("Variant",
		"Dim varName As Variant\nDim varName  ' Also Variant by default",
		"A flexible type that can hold any value — integer, string, object, array, etc. Default type when no As clause is given.",
		"Dim value As Variant\nvalue = 42\nvalue = \"Hello\"\nvalue = True",
		1549)

	# =========================================================================
	# I/O & PRINTING
	# =========================================================================
	_add("Print",
		"Print expression [; expression ...]\nPrint #fileNumber, expression",
		"Outputs text to the debug console (or to a file when used with a file number). Semicolons suppress the newline between items.",
		"Print \"Score: \" & score\nPrint \"X=\"; x; \" Y=\"; y\nPrint #1, \"Log entry: \" & message",
		1440)

	_add("MsgBox",
		"MsgBox prompt [, buttons] [, title]\nresult = MsgBox(prompt, buttons, title)",
		"Displays a message dialog box. Can include OK/Cancel/Yes/No buttons and return the user's choice.",
		"MsgBox \"Game Over!\"\nMsgBox \"Save game?\", vbYesNo, \"Save\"\n\nDim answer As Integer\nanswer = MsgBox(\"Quit?\", vbYesNo + vbQuestion, \"Exit\")\nIf answer = vbYes Then End",
		1442)

	_add("InputBox",
		"result = InputBox(prompt [, title] [, default])",
		"Displays a dialog with a text input field and returns the user's text.",
		"Dim name As String\nname = InputBox(\"Enter your name:\", \"Player Setup\", \"Player 1\")\nIf name <> \"\" Then Print \"Welcome, \" & name",
		0)

	# =========================================================================
	# FILE I/O
	# =========================================================================
	_add("Open",
		"Open filename For mode As #fileNumber",
		"Opens a file for reading, writing, or appending. Modes: Input, Output, Append, Binary, Random.",
		"' Read a file\nOpen \"scores.txt\" For Input As #1\nLine Input #1, firstLine\nClose #1\n\n' Write a file\nOpen \"log.txt\" For Output As #2\nPrint #2, \"Game started\"\nClose #2",
		2556)

	_add("Close",
		"Close [#fileNumber [, #fileNumber ...]]",
		"Closes one or more open files. Always close files when done to flush data to disk.",
		"Open \"data.txt\" For Input As #1\n' ... read data ...\nClose #1\n\nClose  ' Close all open files",
		2556)

	_add("Line Input",
		"Line Input #fileNumber, variableName",
		"Reads an entire line of text from a file (up to the newline character).",
		"Open \"names.txt\" For Input As #1\nDo While Not EOF(1)\n    Line Input #1, currentLine\n    Print currentLine\nLoop\nClose #1",
		2556)

	# =========================================================================
	# DATA STATEMENTS
	# =========================================================================
	_add("Data",
		"Data value1, value2, value3, ...\nData \"string\", 42, 3.14",
		"Stores inline data values that can be read sequentially with Read. Supports strings, numbers, and empty slots (consecutive commas).",
		"Data \"Sword\", 10, 50\nData \"Shield\", 5, 30\nData \"Potion\", 0, 15\n\nDim itemName As String, atk As Integer, cost As Integer\nRead itemName, atk, cost",
		2604)

	_add("Read",
		"Read variable1 [, variable2, ...]\nRead variable As Type",
		"Reads the next value(s) from the Data tape into variables. Supports typed Read for automatic conversion.",
		"Data 100, 200, 300\n\nDim x As Integer, y As Integer, z As Integer\nRead x, y, z\nPrint x  ' 100\n\n' Typed read\nRead score As Integer",
		2604)

	_add("Restore",
		"Restore [labelName]",
		"Resets the Data read pointer to the beginning, or to a named data section.",
		"Data \"First\", 1\ndata_section2:\nData \"Second\", 2\n\nRead a, b\nRestore data_section2\nRead c, d  ' Reads \"Second\", 2",
		2604)

	# =========================================================================
	# STRING FUNCTIONS
	# =========================================================================
	_add("Len",
		"Len(string)",
		"Returns the number of characters in a string.",
		"Dim s As String = \"Hello\"\nPrint Len(s)  ' 5",
		2277)

	_add("Left",
		"Left(string, length)",
		"Returns the specified number of characters from the beginning of a string.",
		"Print Left(\"Hello World\", 5)  ' \"Hello\"",
		2277)

	_add("Right",
		"Right(string, length)",
		"Returns the specified number of characters from the end of a string.",
		"Print Right(\"Hello World\", 5)  ' \"World\"",
		2277)

	_add("Mid",
		"Mid(string, start [, length])",
		"Returns a substring starting at position start (1-based). If length is omitted, returns the rest of the string.",
		"Print Mid(\"Hello World\", 7)     ' \"World\"\nPrint Mid(\"Hello World\", 1, 5)  ' \"Hello\"",
		2277)

	_add("InStr",
		"InStr([start,] string, search)",
		"Returns the position of the first occurrence of search within string (1-based). Returns 0 if not found.",
		"Dim pos As Integer\npos = InStr(\"Hello World\", \"World\")  ' 7\npos = InStr(\"Hello\", \"xyz\")  ' 0",
		2277)

	_add("UCase",
		"UCase(string)",
		"Converts a string to uppercase.",
		"Print UCase(\"hello\")  ' \"HELLO\"",
		2277)

	_add("LCase",
		"LCase(string)",
		"Converts a string to lowercase.",
		"Print LCase(\"HELLO\")  ' \"hello\"",
		2277)

	_add("Trim",
		"Trim(string)",
		"Removes leading and trailing spaces from a string.",
		"Print Trim(\"  Hello  \")  ' \"Hello\"",
		2277)

	_add("Replace",
		"Replace(string, find, replaceWith)",
		"Returns a string with all occurrences of find replaced by replaceWith.",
		"Dim s As String = Replace(\"Hello World\", \"World\", \"VB\")\nPrint s  ' \"Hello VB\"",
		2277)

	_add("Split",
		"Split(string, delimiter)",
		"Splits a string into an array of substrings based on a delimiter.",
		"Dim parts() As String\nparts = Split(\"A,B,C\", \",\")\nPrint parts(0)  ' \"A\"\nPrint parts(1)  ' \"B\"",
		2277)

	_add("Join",
		"Join(array, delimiter)",
		"Joins an array of strings into a single string with a delimiter between each element.",
		"Dim arr() As String = {\"Red\", \"Green\", \"Blue\"}\nPrint Join(arr, \", \")  ' \"Red, Green, Blue\"",
		2277)

	_add("Format",
		"Format(expression, formatString)",
		"Formats a number, date, or string according to the format pattern.",
		"Print Format(1234.5, \"#,##0.00\")  ' \"1,234.50\"\nPrint Format(0.75, \"0%\")          ' \"75%\"",
		2277)

	_add("Val",
		"Val(string)",
		"Converts the numeric portion of a string to a number.",
		"Dim n As Integer = Val(\"42 cats\")  ' 42\nDim d As Double = Val(\"3.14\")      ' 3.14",
		2277)

	_add("Str",
		"Str(number)",
		"Converts a number to its string representation.",
		"Dim s As String = Str(42)  ' \" 42\" (note leading space)\nPrint \"Score: \" & Str(score)",
		2277)

	_add("CStr",
		"CStr(expression)",
		"Explicitly converts any expression to a String.",
		"Dim s As String = CStr(42)    ' \"42\"\nDim t As String = CStr(True)  ' \"True\"",
		2277)

	_add("CInt",
		"CInt(expression)",
		"Converts an expression to an Integer, rounding if necessary.",
		"Dim n As Integer = CInt(3.7)   ' 4\nDim m As Integer = CInt(\"42\")  ' 42",
		2277)

	# =========================================================================
	# MATH FUNCTIONS
	# =========================================================================
	_add("Abs",
		"Abs(number)",
		"Returns the absolute value of a number.",
		"Print Abs(-5)    ' 5\nPrint Abs(3.14)  ' 3.14",
		2299)

	_add("Int",
		"Int(number)",
		"Returns the integer portion of a number (truncates toward negative infinity).",
		"Print Int(3.7)   ' 3\nPrint Int(-3.7)  ' -4",
		2299)

	_add("Round",
		"Round(number [, decimals])",
		"Rounds a number to the specified number of decimal places.",
		"Print Round(3.14159, 2)  ' 3.14\nPrint Round(2.5)         ' 2 (banker's rounding)",
		2299)

	_add("Rnd",
		"Rnd([upperBound])",
		"Returns a random floating-point number between 0 and 1 (or 0 and upperBound if specified).",
		"Randomize\nDim r As Single = Rnd()      ' 0.0 to 1.0\nDim d As Integer = Int(Rnd(6)) + 1  ' Dice roll 1-6",
		2299)

	_add("Randomize",
		"Randomize [seed]",
		"Seeds the random number generator. Call once at program start for unpredictable sequences.",
		"Randomize\nPrint Rnd()  ' Different each run\n\nRandomize 42  ' Reproducible sequence",
		2299)

	_add("RandRange",
		"RandRange(min, max)",
		"Returns a random number between min and max (inclusive).",
		"Dim damage As Integer = RandRange(5, 20)\nDim x As Single = RandRange(0.0, 1.0)",
		2299)

	_add("Lerp",
		"Lerp(a, b, t)",
		"Linearly interpolates between a and b by factor t (0.0 to 1.0).",
		"' Smooth camera follow\ncameraX = Lerp(cameraX, playerX, 0.1)\n\n' Fade color\nalpha = Lerp(0.0, 1.0, fadeProgress)",
		2299)

	_add("Clamp",
		"Clamp(value, min, max)",
		"Constrains a value to the range [min, max].",
		"health = Clamp(health, 0, maxHealth)\nspeed = Clamp(speed, 0.0, maxSpeed)",
		2299)

	_add("Sqr",
		"Sqr(number)",
		"Returns the square root of a number.",
		"Print Sqr(16)   ' 4\nPrint Sqr(2.0)  ' 1.41421...",
		2299)

	_add("Sin",
		"Sin(angle)",
		"Returns the sine of an angle (in radians).",
		"Dim y As Single = Sin(3.14159 / 2)  ' 1.0\n' Oscillating motion\ny = Sin(time * 2.0) * amplitude",
		2299)

	_add("Cos",
		"Cos(angle)",
		"Returns the cosine of an angle (in radians).",
		"Dim x As Single = Cos(0)  ' 1.0\n' Circular motion\nx = Cos(angle) * radius",
		2299)

	# =========================================================================
	# PASS 1 — MATH BUILT-IN TYPES (Quaternion, Basis, Transform, Plane, AABB)
	# =========================================================================
	_add("Quaternion",
		"Quaternion() | Quaternion(x, y, z, w)",
		"Creates a Quaternion — 3D rotation as four numbers. Identity rotation by default. Use Slerp to blend two rotations smoothly. Multiply two Quaternions to combine rotations.",
		"Dim qIdentity = Quaternion()\nDim q = Quaternion(0, 0, 0, 1)  ' identity in (x,y,z,w)\n\n' Rotate halfway between two orientations\nDim qHalf = Slerp(qStart, qEnd, 0.5)")

	_add("QuaternionFromEuler",
		"QuaternionFromEuler(xRad, yRad, zRad)",
		"Builds a Quaternion from Euler angles (pitch, yaw, roll) in radians. Easier than constructing the four components directly.",
		"' 90-degree yaw (turn right)\nDim qTurn = QuaternionFromEuler(0, 1.5707963, 0)\nplayer.quaternion = qTurn")

	_add("Basis",
		"Basis() | Basis(quaternion)",
		"Creates a 3x3 rotation/scale matrix used inside Transform3D. Pass a Quaternion to build a rotation-only Basis. Methods like .Scaled(v), .Rotated(axis, angle), .Inverse(), .Orthonormalized() are available on the result.",
		"Dim b = Basis(QuaternionFromEuler(0, 0.5, 0))\nDim b2 = b.Scaled(Vector3(2, 2, 2))")

	_add("Transform2D",
		"Transform2D() | Transform2D(rotationRad, origin) | Transform2D(rotation, scale, skew, origin)",
		"2D transform (rotation + scale + skew + position). Defaults to identity. Useful for positioning Node2D children procedurally. Methods .Translated(v), .Rotated(rad), .Scaled(v), .AffineInverse() return new Transform2Ds.",
		"Dim t = Transform2D(0.785, Vector2(100, 50))  ' 45 deg, at (100,50)\nDim t2 = t.Translated(Vector2(10, 0)).Rotated(0.1)")

	_add("Transform3D",
		"Transform3D() | Transform3D(basis, origin)",
		"3D transform combining a Basis (rotation+scale) with an origin Vector3. Used for positioning Node3Ds. .LookingAt(target, up) is the easy way to face a point.",
		"Dim tr = Transform3D(Basis(), Vector3(0, 2, 5))\ncam.transform = tr.LookingAt(player.position, Vector3(0, 1, 0))")

	_add("Plane",
		"Plane() | Plane(normalVec3) | Plane(normalVec3, d) | Plane(a, b, c, d)",
		"Infinite plane defined by a normal vector and signed distance from origin. Used for clipping, side-of-plane tests, and raycast results. Methods include .IsPointOver(p), .DistanceTo(p), .Intersect3(plane2, plane3).",
		"Dim floor = Plane(Vector3(0, 1, 0), 0)  ' ground plane (y=0)\nIf floor.IsPointOver(actor.position) Then\n    Print \"actor is above the floor\"\nEnd If")

	_add("AABB",
		"AABB() | AABB(positionVec3, sizeVec3)",
		"Axis-aligned bounding box in 3D. Used for visibility culling, region tests. Methods: .HasPoint(p), .Intersects(other), .GetCenter(), .Grow(by), .Encloses(other), .GetVolume().",
		"Dim region = AABB(Vector3(-5, 0, -5), Vector3(10, 4, 10))\nIf region.HasPoint(enemy.position) Then\n    enemy.Aggro()\nEnd If")

	_add("NewRNG",
		"NewRNG([seed])",
		"Creates a per-stream RandomNumberGenerator. Unlike global Rnd(), each NewRNG has its own seed for reproducible sequences. Access via .Randf(), .RandiRange(lo, hi), .RandfRange(lo, hi), .Randfn(mean, deviation).",
		"Dim rng = NewRNG(42)            ' fixed seed\nDim damage = rng.RandiRange(5, 10)\nDim spread = rng.Randfn(0, 0.2)  ' normal distribution")

	_add("NewNoise",
		"NewNoise([seed])",
		"Creates a FastNoiseLite generator for procedural content (terrain heightmaps, cloud patterns, perlin/simplex noise). Set .Seed, .Frequency, .NoiseType. Sample with .GetNoise2D(x, y), .GetNoise3D(x, y, z) — returns -1..1.",
		"Dim n = NewNoise(1337)\nn.Frequency = 0.05\nFor x = 0 To 99\n    For y = 0 To 99\n        Dim h = (n.GetNoise2D(x, y) + 1) * 0.5  ' 0..1\n        heightmap(x, y) = h * 64\n    Next\nNext")

	_add("NewCurve",
		"NewCurve()",
		"Creates an editable Curve resource for animation/easing. Use .AddPoint(Vector2(x, y)) to add control points then .Sample(t) — where t is 0..1 — to read the interpolated value. Great for designer-tunable shapes (jump arc, damage falloff).",
		"Dim arc = NewCurve()\narc.AddPoint(Vector2(0, 0))\narc.AddPoint(Vector2(0.5, 1.0))\narc.AddPoint(Vector2(1.0, 0))\nDim height = arc.Sample(t) * jumpMax")

	# =========================================================================
	# PASS 1 — GLOBAL MATH VERBS
	# =========================================================================
	_add("Slerp",
		"Slerp(a, b, t)",
		"Spherical interpolation. Smoothly blends between two Quaternions, Vector3s, or Vector2s by factor t (0..1). Like Lerp but preserves length/rotation rate — use for camera orbits, rotation interpolation, smooth aim.",
		"' Rotate halfway from current to target\nplayer.quaternion = Slerp(player.quaternion, targetRot, 0.1)\n\n' Smooth aim direction\naim = Slerp(aim, desiredAim, 0.2)")

	_add("ColorFromHSV",
		"ColorFromHSV(h, s, v [, a])",
		"Builds a Color from Hue/Saturation/Value (each 0..1). Use when you want rainbow effects, palette cycling, or to tint by hue without RGB math.",
		"' Animate the rainbow\nFor i = 0 To 60\n    Dim c = ColorFromHSV(i / 60.0, 0.8, 1.0)\n    DrawRect i * 10, 0, 10, 100, c\nNext")

	_add("ColorToHSV",
		"ColorToHSV(color)",
		"Splits a Color into its Hue, Saturation, Value, Alpha components. Returns a Dictionary with keys h, s, v, a (each 0..1).",
		"Dim parts = ColorToHSV(Color.Red)\nPrint parts.h  ' 0.0  (red is hue 0)\nPrint parts.s  ' 1.0")

	_add("Lighten",
		"Lighten(color, amount)",
		"Returns a lighter shade of the color. Amount is 0..1 (0=unchanged, 1=white).",
		"buttonHover = Lighten(buttonNormal, 0.2)")

	_add("Darken",
		"Darken(color, amount)",
		"Returns a darker shade of the color. Amount is 0..1 (0=unchanged, 1=black).",
		"shadow = Darken(skinColor, 0.4)")

	# =========================================================================
	# PASS 2 — CAMERA NAMESPACE
	#
	# Camera.* verbs target the *active* camera (the one currently rendering).
	# Every verb also takes an optional final 'h' argument: pass a specific
	# Camera2D/Camera3D node to override the active one. Use h when you have
	# multiple cameras and want to control a non-active one.
	# =========================================================================
	_add("Camera.Position",
		"Camera.Position(pos [, h])",
		"Sets the active camera's position. Use Vector2 for Camera2D, Vector3 for Camera3D. Optional h overrides which camera is targeted.\n\nCalled inside Sub _Process() it tracks any target — Camera.Position(player.Position) for instant follow.",
		"' Snap to player every frame\nSub _Process(delta)\n    Camera.Position(player.Position)\nEnd Sub")

	_add("Camera.Zoom",
		"Camera.Zoom(zoom [, h])",
		"Sets Camera2D zoom level. Pass a Vector2 for non-uniform zoom, or a scalar for uniform. Bigger numbers = closer in. (Camera3D uses FOV instead — see Camera.FOV.)",
		"Camera.Zoom Vector2(2, 2)       ' 2x zoom in\nCamera.Zoom 0.5                  ' zoom out to half")

	_add("Camera.Limits",
		"Camera.Limits(left, top, right, bottom [, h])",
		"Sets Camera2D pan limits in pixels. The camera will refuse to scroll past these edges — perfect for keeping the view inside your level.",
		"' Lock view to a 1920x1080 level\nCamera.Limits 0, 0, 1920, 1080")

	_add("Camera.FOV",
		"Camera.FOV(degrees [, h])",
		"Sets Camera3D field of view in degrees. 75 is the default. Smaller = telephoto/zoomed; larger = wide-angle.",
		"Camera.FOV 90    ' wide cinematic\nCamera.FOV 45    ' sniper scope")

	_add("Camera.MakeCurrent",
		"Camera.MakeCurrent([h])",
		"Makes a camera the active one — useful when you have multiple cameras (e.g., gameplay vs cutscene) and want to switch which one renders.",
		"Camera.MakeCurrent cutsceneCam\n' ... play cutscene ...\nCamera.MakeCurrent gameplayCam")

	_add("Camera.Rotation",
		"Camera.Rotation(angle [, h])",
		"Rotates the camera. For Camera2D pass a number in radians; for Camera3D pass a Vector3 of Euler angles in radians.",
		"' Quick screen tilt (Camera2D)\nCamera.Rotation 0.1   ' ~6 degrees")

	_add("Camera.Follow",
		"Camera.Follow(target [, h])",
		"Continuously follow a target node. Internally adds a RemoteTransform that mirrors target.Position to the camera every frame — zero per-frame code on your side. Pass Nothing to stop following. Camera.Position(...) called inside Sub _Process() takes precedence for the frame it runs.",
		"Sub _Ready()\n    Camera.Follow player    ' auto-track player forever\nEnd Sub\n\nSub OnPlayerDied()\n    Camera.Follow Nothing   ' stop following\nEnd Sub")

	_add("Camera.Shake",
		"Camera.Shake(intensity, duration [, h])",
		"Quick screen shake. Intensity is offset in pixels (2D) or units (3D). Duration is seconds. Camera settles back to its original offset when done.",
		"' Boom!\nCamera.Shake 12, 0.4")

	# =========================================================================
	# PASS 2 — SOUND NAMESPACE
	#
	# Sound.Play returns a handle (an Integer). Pass that handle to Stop /
	# Pause / Resume / Seek / Volume / Pitch to control just that one sound.
	# When you ignore the return value, the sound auto-frees when it finishes.
	# =========================================================================
	_add("Sound.Play",
		"Sound.Play(path [, busName]) As Long",
		"Plays a sound and returns a handle (Integer). Save the handle if you want to stop, pause, change volume, or seek the sound later. Optional busName routes the sound through a named speaker/bus (default \"Master\").",
		"' Fire and forget\nSound.Play \"res://blast.wav\"\n\n' Keep a handle to control it later\nDim music = Sound.Play(\"res://song.ogg\", \"Music\")\nSound.Volume 60, music")

	_add("Sound.Stop",
		"Sound.Stop(h)",
		"Stops a sound that was started with Sound.Play and frees it.",
		"Sound.Stop music")

	_add("Sound.Pause",
		"Sound.Pause(h)",
		"Pauses a sound without stopping it. Resume with Sound.Resume(h).",
		"Sound.Pause music")

	_add("Sound.Resume",
		"Sound.Resume(h)",
		"Resumes a paused sound from where it left off.",
		"Sound.Resume music")

	_add("Sound.Seek",
		"Sound.Seek(h, seconds)",
		"Jumps to a position (in seconds) inside a playing sound. Useful for skipping intros or implementing scrub bars.",
		"Sound.Seek music, 30.0   ' jump to 30 seconds in")

	_add("Sound.Volume",
		"Sound.Volume(pct [, h])",
		"Sets volume in percent (0..100). With a handle, changes that one sound. Without a handle, sets the master speaker volume — the global volume knob.",
		"Sound.Volume 75           ' master at 75%\nSound.Volume 50, music    ' just this song at 50%")

	_add("Sound.Pitch",
		"Sound.Pitch(scale, h)",
		"Changes playback speed/pitch of a sound. 1.0 = normal, 2.0 = double speed (one octave up), 0.5 = half speed (one octave down).",
		"Sound.Pitch 1.2, music   ' slightly faster/higher")

	_add("Sound.IsPlaying",
		"Sound.IsPlaying(h) As Boolean",
		"Returns True if the sound is currently playing.",
		"If Not Sound.IsPlaying(music) Then\n    music = Sound.Play(\"res://song.ogg\")\nEnd If")

	_add("Sound.Position",
		"Sound.Position(h) As Double",
		"Returns the current playback position in seconds.",
		"Dim t = Sound.Position(music)\nPrint \"At \" & Round(t, 1) & \" seconds\"")

	# =========================================================================
	# PASS 2 — SPEAKER NAMESPACE (audio buses)
	#
	# Speakers are named volume channels — \"Master\", \"Music\", \"SFX\", or
	# whatever you set up in Project Settings → Audio → Buses. Use them to
	# build settings menus with separate music/SFX sliders, or to route stereo
	# / surround channels (\"Left\", \"Right\", \"Center\", \"LeftSurround\").
	#
	# Bus.* is accepted as an alias of Speaker.* (Godot calls them buses).
	# =========================================================================
	_add("Speaker.Volume",
		"Speaker.Volume(name [, pct])",
		"Get or set a speaker's volume in percent (0..100). With one argument, returns current volume. With two, sets it. Works on any bus defined in Project Settings → Audio.",
		"' Build a music slider\nSpeaker.Volume \"Music\", musicSlider.Value\n\n' Read current\nlbl.Text = \"Music: \" & Round(Speaker.Volume(\"Music\")) & \"%\"")

	_add("Speaker.Mute",
		"Speaker.Mute(name, muted)",
		"Mutes or unmutes a speaker. Pass True to mute, False to unmute.",
		"Speaker.Mute \"Music\", True     ' silence music\nSpeaker.Mute \"Music\", False    ' unmute")

	_add("Speaker.IsMuted",
		"Speaker.IsMuted(name) As Boolean",
		"Returns True if the named speaker is currently muted.",
		"If Speaker.IsMuted(\"Master\") Then\n    Print \"Audio is off\"\nEnd If")

	_add("Speaker.Solo",
		"Speaker.Solo(name, soloed)",
		"Solos a speaker so only it is audible (others silent). Pass False to unsolo.",
		"Speaker.Solo \"SFX\", True   ' only sound effects audible")

	_add("Speaker.Exists",
		"Speaker.Exists(name) As Boolean",
		"Returns True if a speaker with this name exists in Project Settings → Audio → Buses.",
		"If Speaker.Exists(\"Music\") Then\n    Speaker.Volume \"Music\", 50\nEnd If")

	_add("Speaker.Count",
		"Speaker.Count() As Integer",
		"Returns the number of configured speakers/buses.",
		"For i = 0 To Speaker.Count() - 1\n    Print Speaker.Name(i)\nNext")

	_add("Speaker.Name",
		"Speaker.Name(index) As String",
		"Returns the name of the speaker at the given index (0-based).",
		"Print Speaker.Name(0)   ' usually \"Master\"")

	# =========================================================================
	# PASS 3 — ANIMATION NAMESPACE
	#
	# Wraps AnimationPlayer node. All verbs take the player node as the first
	# argument. Signals (AnimationFinished, AnimationStarted, AnimationChanged)
	# are auto-wired by name: name the AnimationPlayer "PlayerAnim", then write
	# Sub PlayerAnim_AnimationFinished(anim_name)
	#     Print "Done: " & anim_name
	# End Sub
	# =========================================================================
	_add("Animation.Play",
		"Animation.Play(player, name [, speed])",
		"Plays a named animation on an AnimationPlayer node. Optional speed scale (1.0 = normal, 2.0 = double).",
		"Animation.Play playerAnim, \"walk\"\nAnimation.Play playerAnim, \"sprint\", 1.5")

	_add("Animation.Stop",
		"Animation.Stop(player [, keepState])",
		"Stops the current animation. Pass True for keepState to leave the animated properties at their current values (don't reset).",
		"Animation.Stop playerAnim")

	_add("Animation.Pause",
		"Animation.Pause(player)",
		"Pauses the current animation without resetting it. Resume with Animation.Resume.",
		"Animation.Pause playerAnim")

	_add("Animation.Resume",
		"Animation.Resume(player)",
		"Resumes a paused animation from its current position.",
		"Animation.Resume playerAnim")

	_add("Animation.Seek",
		"Animation.Seek(player, seconds [, update])",
		"Jumps to a specific time in the current animation. update=True applies the change immediately.",
		"Animation.Seek playerAnim, 1.5")

	_add("Animation.Speed",
		"Animation.Speed(player, scale)",
		"Sets playback speed for all animations on this player. 1.0 = normal, 0.5 = slow-mo, 2.0 = fast.",
		"Animation.Speed playerAnim, 0.5   ' slow motion")

	_add("Animation.Current",
		"Animation.Current(player) As String",
		"Returns the name of the currently playing animation, or empty string if none.",
		"If Animation.Current(playerAnim) = \"die\" Then\n    GameOver()\nEnd If")

	_add("Animation.IsPlaying",
		"Animation.IsPlaying(player) As Boolean",
		"Returns True if the player is currently playing an animation.",
		"If Not Animation.IsPlaying(playerAnim) Then\n    Animation.Play playerAnim, \"idle\"\nEnd If")

	_add("Animation.Length",
		"Animation.Length(player [, name]) As Double",
		"Returns the length in seconds of an animation. With no name, returns the current animation's length.",
		"Dim total = Animation.Length(playerAnim, \"walk\")\nPrint \"Walk is \" & total & \"s long\"")

	# =========================================================================
	# PASS 3 — PHYSICS NAMESPACE
	#
	# Physics.Ray is a one-shot query — no node required. Returns a Dictionary
	# with Hit, Collider, Point, Normal, Distance. 2D vs 3D is picked by the
	# 'from' Vector type.
	#
	# For applying forces to RigidBody2D/3D, the plain-English verbs Push/Pull
	# /Spin are aliases for Physics.Impulse/Force/Torque — both work.
	# =========================================================================
	_add("Physics.Ray",
		"Physics.Ray(from, to [, collisionMask]) As Dictionary",
		"Casts an instant ray from one point to another and returns what it hit. Returns Dictionary with keys: Hit (Boolean), Collider (Object), Point (Vector), Normal (Vector), Distance (Double). Pass Vector2 for 2D, Vector3 for 3D.",
		"Dim hit = Physics.Ray(player.Position, mouse.Position)\nIf hit.Hit Then\n    Print \"Hit \" & hit.Collider.Name & \" at \" & hit.Distance & \" px\"\nEnd If")

	_add("Physics.Impulse",
		"Physics.Impulse(body, vec [, pos])",
		"Applies an instant impulse (one-frame push) to a RigidBody. Optional pos is the offset from body center where the force is applied. Alias: Push.",
		"Physics.Impulse ball, Vector2(500, -200)   ' kick the ball")

	_add("Physics.Force",
		"Physics.Force(body, vec [, pos])",
		"Applies a continuous force to a RigidBody (call every frame for sustained push). Alias: Pull.",
		"Sub _PhysicsProcess(delta)\n    Physics.Force rocket, Vector2(0, -800)   ' constant thrust\nEnd Sub")

	_add("Physics.Torque",
		"Physics.Torque(body, amount)",
		"Applies a rotational impulse to a RigidBody. For 2D pass a number, for 3D pass a Vector3. Alias: Spin.",
		"Physics.Torque wheel, 50")

	_add("Push",
		"Push(body, vec [, pos])",
		"Instant impulse — kicks a RigidBody once. Plain-English alias for Physics.Impulse.",
		"Push enemy, Vector2(-300, 0)")

	_add("Pull",
		"Pull(body, vec [, pos])",
		"Continuous force — call each frame to keep applying. Plain-English alias for Physics.Force.",
		"Pull magnet, towardPlayer * 800")

	_add("Spin",
		"Spin(body, amount)",
		"Rotational impulse. Plain-English alias for Physics.Torque.",
		"Spin coin, 12.5")

	# =========================================================================
	# PASS 3 — RAY NAMESPACE (placed RayCast2D/3D nodes)
	#
	# Use these when you have a RayCast2D/3D node in your scene that updates
	# every frame. For one-off casts, use Physics.Ray instead.
	# =========================================================================
	_add("Ray.Hit",
		"Ray.Hit(rayNode) As Boolean",
		"Returns True if the RayCast2D/3D node is currently colliding with something.",
		"If Ray.Hit(groundRay) Then\n    Print \"On the ground\"\nEnd If")

	_add("Ray.Collider",
		"Ray.Collider(rayNode) As Object",
		"Returns the node the ray is currently hitting, or Nothing if no hit.",
		"If Ray.Hit(aimRay) Then\n    target = Ray.Collider(aimRay)\nEnd If")

	_add("Ray.Point",
		"Ray.Point(rayNode) As Vector",
		"Returns the world-space hit point of the ray, or Vector.Zero if no hit.",
		"DrawCircle Ray.Point(aimRay), 5, Color.Red")

	_add("Ray.Normal",
		"Ray.Normal(rayNode) As Vector",
		"Returns the surface normal at the hit point — useful for bouncing or aligning to surfaces.",
		"' Bounce projectile\nvelocity = velocity.Bounce(Ray.Normal(hitRay))")

	_add("Ray.Enable",
		"Ray.Enable(rayNode, on)",
		"Enables or disables a RayCast node. Disabled rays don't query the physics world.",
		"Ray.Enable scanner, True")

	_add("Ray.Target",
		"Ray.Target(rayNode, pos)",
		"Sets the ray's target_position (relative to the ray's own position). Use to redirect the ray.",
		"Ray.Target aimRay, mousePos - aimRay.Position")

	_add("Ray.ForceUpdate",
		"Ray.ForceUpdate(rayNode)",
		"Forces an immediate raycast update (don't wait for next physics frame). Useful right after moving the ray.",
		"Ray.Target groundRay, Vector2(0, 50)\nRay.ForceUpdate groundRay\nIf Ray.Hit(groundRay) Then Print \"floor below\"")

	# =========================================================================
	# PASS 3 — CELL NAMESPACE (TileMapLayer)
	#
	# Cell.Get / Set treat a TileMapLayer like a 2D array of tiles. Each tile
	# is identified by Source ID (which TileSet source) + AtlasX/Y (which tile
	# within that source's atlas).
	# =========================================================================
	_add("Cell.Get",
		"Cell.Get(layer, x, y) As Dictionary",
		"Reads a tile at cell coords (x, y) on a TileMapLayer. Returns Dictionary: Source, AtlasX, AtlasY, Alt. Empty cells return Source = -1.",
		"Dim c = Cell.Get(world, 5, 10)\nIf c.Source >= 0 Then\n    Print \"Tile from source \" & c.Source\nEnd If")

	_add("Cell.Set",
		"Cell.Set(layer, x, y, source, atlasX, atlasY [, alt])",
		"Writes a tile at cell coords (x, y). source = -1 erases. atlasX/Y picks the tile within the source's atlas.",
		"' Place a grass tile from source 0, atlas (3, 1)\nCell.Set world, 5, 10, 0, 3, 1")

	_add("Cell.Clear",
		"Cell.Clear(layer, x, y)",
		"Erases a single tile. Shortcut for Cell.Set with source = -1.",
		"Cell.Clear world, 5, 10")

	_add("Cell.ClearAll",
		"Cell.ClearAll(layer)",
		"Erases all tiles in a TileMapLayer.",
		"Cell.ClearAll world")

	_add("Cell.Used",
		"Cell.Used(layer) As Array",
		"Returns an Array of Vector2 cell coordinates that contain a tile (non-empty).",
		"Dim cells = Cell.Used(world)\nFor Each c In cells\n    Print c.x & \",\" & c.y\nNext")

	# =========================================================================
	# PASS 3 — NAV NAMESPACE (NavigationAgent2D / 3D)
	#
	# Wraps NavigationAgent for AI pathfinding. Drop a NavigationAgent2D/3D
	# as a child of the unit you want to move, then:
	#   Nav.SetTarget agent, destination
	#   Inside _PhysicsProcess: move toward Nav.NextPos(agent)
	#
	# Signals auto-wire: name the agent "EnemyNav" and write
	#   Sub EnemyNav_TargetReached()  →  goal reached
	#   Sub EnemyNav_NavigationFinished()  →  path done (success or fail)
	# =========================================================================
	_add("Nav.SetTarget",
		"Nav.SetTarget(agent, pos)",
		"Sets the destination for a NavigationAgent. The agent computes a path and starts moving when you read NextPos each frame.",
		"Nav.SetTarget enemyNav, player.Position")

	_add("Nav.NextPos",
		"Nav.NextPos(agent) As Vector",
		"Returns the next step along the path. Call inside _PhysicsProcess to drive movement toward this point.",
		"Sub _PhysicsProcess(delta)\n    Dim step = Nav.NextPos(enemyNav)\n    velocity = (step - Position).Normalized() * 200\n    MoveAndSlide Me\nEnd Sub")

	_add("Nav.Distance",
		"Nav.Distance(agent) As Double",
		"Returns the remaining distance to the target along the path.",
		"If Nav.Distance(enemyNav) < 50 Then Attack()")

	_add("Nav.Reached",
		"Nav.Reached(agent) As Boolean",
		"Returns True if the agent has finished navigating (arrived at target or path is invalid).",
		"If Nav.Reached(enemyNav) Then PickNewTarget()")

	_add("Nav.Path",
		"Nav.Path(agent) As Array",
		"Returns the full computed path as an Array of Vector positions.",
		"For Each pt In Nav.Path(enemyNav)\n    DrawCircle pt, 3, Color.Yellow\nNext")

	# =========================================================================
	# ARRAY FUNCTIONS
	# =========================================================================
	_add("UBound",
		"UBound(arrayName [, dimension])",
		"Returns the highest valid index of an array.",
		"Dim arr(10) As Integer\nPrint UBound(arr)  ' 10\n\nFor i = 0 To UBound(arr)\n    arr(i) = i * 2\nNext",
		2438)

	_add("LBound",
		"LBound(arrayName [, dimension])",
		"Returns the lowest valid index of an array (usually 0).",
		"For i = LBound(arr) To UBound(arr)\n    Print arr(i)\nNext",
		2438)

	_add("Array",
		"Array(value1, value2, ...)",
		"Creates and returns an array containing the specified values.",
		"Dim colors As Variant = Array(\"Red\", \"Green\", \"Blue\")\nPrint colors(0)  ' \"Red\"",
		2438)

	# =========================================================================
	# GAME DEVELOPMENT
	# =========================================================================
	_add("CreateActor2D",
		"CreateActor2D(name, x, y [, texturePath])",
		"Creates a 2D game actor (sprite) at the specified position.",
		"CreateActor2D \"Player\", 100, 200, \"res://player.png\"\nCreateActor2D \"Enemy\", 400, 200",
		3500)

	_add("IsKeyPressed",
		"IsKeyPressed(keyName) As Boolean",
		"Returns True if the specified keyboard key is currently held down.",
		"If IsKeyPressed(\"space\") Then\n    Jump()\nEnd If\n\nIf IsKeyPressed(\"left\") Then x = x - speed\nIf IsKeyPressed(\"right\") Then x = x + speed",
		2363)

	_add("IsActionPressed",
		"IsActionPressed(actionName) As Boolean",
		"Returns True if the specified input action (defined in Project Settings) is active.",
		"If IsActionPressed(\"ui_accept\") Then\n    SelectMenuItem()\nEnd If",
		2363)

	_add("PlaySound",
		"PlaySound(path [, volume] [, pitch])",
		"Plays a sound effect from the specified resource path.",
		"PlaySound \"res://sounds/explosion.wav\"\nPlaySound \"res://sounds/jump.ogg\", 0.8, 1.2",
		3500)

	_add("LoadForm",
		"LoadForm formName",
		"Loads and displays a form by name.",
		"LoadForm \"SettingsForm\"\nLoadForm \"HighScores\"",
		3500)

	_add("ChangeScene",
		"ChangeScene(scenePath)",
		"Changes the current game scene to the specified .tscn file.",
		"ChangeScene \"res://levels/Level2.tscn\"\n\n' Or using GetTree:\nGetTree().change_scene_to_file(\"res://MainMenu.tscn\")",
		3500)

	# =========================================================================
	# ASYNC / PARALLEL
	# =========================================================================
	_add("Async",
		"Async Sub ProcedureName()\nAsync Function FuncName() As Task(Of Type)",
		"Marks a procedure as asynchronous, allowing the use of Await inside it.",
		"Async Sub LoadLevel()\n    Dim data As String = Await ReadFileAsync(\"level.dat\")\n    ParseLevel(data)\nEnd Sub",
		0)

	_add("Await",
		"Await asyncExpression",
		"Pauses execution until an asynchronous operation completes, then returns its result.",
		"Async Sub FetchData()\n    Dim response As String = Await Http.Get(\"https://api.example.com/data\")\n    Print response\nEnd Sub",
		0)

	# =========================================================================
	# MODERN FEATURES
	# =========================================================================
	_add("Lambda",
		"Lambda(params) expression\nLambda(params)\n    statements\nEnd Lambda",
		"Creates an anonymous function (closure) that can be stored in a variable or passed as an argument.",
		"Dim double As Function = Lambda(x) x * 2\nPrint double(5)  ' 10\n\nDim greet As Function = Lambda(name)\n    Print \"Hello, \" & name\nEnd Lambda\ngreet(\"World\")",
		0)

	_add("Whenever",
		"Whenever condition [Changes|Becomes|Exceeds|Below value]\n    statements\nEnd Whenever",
		"Reactive programming — automatically triggers code when a monitored condition changes.",
		"Whenever health Below 20\n    lblWarning.Visible = True\n    lblWarning.Caption = \"Low Health!\"\nEnd Whenever\n\nWhenever score Changes\n    lblScore.Caption = \"Score: \" & score\nEnd Whenever",
		0)

	_add("Using",
		"Using resource = expression\n    statements\nEnd Using",
		"Ensures a resource is properly disposed/cleaned up when the block exits.",
		"Using conn = OpenDatabase(\"game.db\")\n    conn.Execute \"INSERT INTO scores VALUES(\" & score & \")\"\nEnd Using  ' Connection automatically closed",
		0)

	_add("DoEvents",
		"DoEvents",
		"Yields control to the engine to process pending events (UI updates, input, etc.). Use sparingly in long-running loops.",
		"For i = 1 To 10000\n    ProcessItem(i)\n    If i Mod 100 = 0 Then DoEvents  ' Keep UI responsive\nNext",
		1449)

	# =========================================================================
	# SPECIAL STATEMENTS
	# =========================================================================
	_add("End",
		"End [Sub|Function|If|Select|Class|Type|With|Enum|Try|Using|Whenever]",
		"Terminates a block or ends program execution. When used alone, terminates the application.",
		"End Sub\nEnd Function\nEnd If\nEnd Select\nEnd Class\nEnd  ' Terminate program",
		1283)

	_add("Option Explicit",
		"Option Explicit",
		"Requires all variables to be declared with Dim before use. Helps catch typos. Place at the top of your module.",
		"Option Explicit\n\nSub Form_Load()\n    Dim score As Integer  ' Required with Option Explicit\n    score = 100\nEnd Sub",
		1391)

	_add("Nothing",
		"Set obj = Nothing\nIf obj Is Nothing Then ...",
		"Represents a null object reference. Use to release object references or test if an object is unset.",
		"Set player = Nothing\n\nIf currentEnemy Is Nothing Then\n    Print \"No enemy nearby\"\nEnd If",
		1271)

	_add("True",
		"True",
		"Boolean literal representing a true/on state.",
		"Dim isReady As Boolean = True\nVisible = True",
		1270)

	_add("False",
		"False",
		"Boolean literal representing a false/off state.",
		"Dim gameOver As Boolean = False\nEnabled = False",
		1270)

	# =========================================================================
	# LOGICAL OPERATORS
	# =========================================================================
	_add("And",
		"expression1 And expression2",
		"Logical AND — returns True only if both expressions are True.",
		"If health > 0 And ammo > 0 Then\n    Fire()\nEnd If",
		1331)

	_add("Or",
		"expression1 Or expression2",
		"Logical OR — returns True if either expression is True.",
		"If key = \"escape\" Or key = \"q\" Then\n    QuitGame()\nEnd If",
		1332)

	_add("Not",
		"Not expression",
		"Logical NOT — inverts a Boolean value.",
		"If Not gameOver Then\n    UpdateGame()\nEnd If\n\nVisible = Not Visible  ' Toggle",
		1333)

	_add("Xor",
		"expression1 Xor expression2",
		"Logical XOR — returns True if exactly one expression is True.",
		"If a Xor b Then\n    Print \"Exactly one is true\"\nEnd If",
		1334)

	_add("Mod",
		"number1 Mod number2",
		"Modulo operator — returns the remainder after integer division.",
		"If i Mod 2 = 0 Then\n    Print i & \" is even\"\nEnd If\n\nframe = frame Mod maxFrames",
		1335)

	# =========================================================================
	# DRAWING COMMANDS — Primitives
	# =========================================================================
	_add("DrawRect",
		"DrawRect x, y, width, height, color [, filled]\nDrawRect Rect2(x, y, w, h), color",
		"Draws a rectangle on screen in _Draw(). Can use VB-style (x, y, w, h) or Godot-style (Rect2) arguments. If filled is False, draws only the outline.",
		"Sub _Draw()\n    DrawRect 10, 10, 200, 100, Color(1, 0, 0)     ' Filled red rect\n    DrawRect 10, 10, 200, 100, Color(0, 0, 0), False  ' Black outline\n    DrawRect Rect2(50, 50, 100, 80), Color(0, 0, 1)   ' Godot-style\nEnd Sub",
		0)

	_add("DrawCircle",
		"DrawCircle x, y, radius, color\nDrawCircle Vector2(x, y), radius, color",
		"Draws a filled circle at the specified center position with the given radius and color.",
		"Sub _Draw()\n    DrawCircle 200, 150, 50, Color(0, 1, 0)        ' Green circle\n    DrawCircle Vector2(400, 300), 30, Color.Red      ' Godot-style\nEnd Sub",
		0)

	_add("DrawLine",
		"DrawLine x1, y1, x2, y2, color [, width]\nDrawLine Vector2(x1,y1), Vector2(x2,y2), color [, width]",
		"Draws a line between two points with an optional width.",
		"Sub _Draw()\n    DrawLine 0, 0, 100, 100, Color(1, 1, 0), 2     ' Yellow 2px line\n    DrawLine Vector2(50, 50), Vector2(200, 100), Color.White\nEnd Sub",
		0)

	_add("DrawPixel",
		"DrawPixel x, y, color",
		"Draws a single pixel at the specified position. Equivalent to PSet. For per-pixel rendering, consider using CreateImage + SetImagePixel + DrawTexture instead for much better performance.",
		"Sub _Draw()\n    DrawPixel 100, 50, Color(1, 0, 0)   ' Red pixel\n    PSet 101, 50, Color(0, 1, 0)         ' Green pixel (alias)\nEnd Sub\n\n' For heavy pixel work, use Image APIs:\nDim img = CreateImage(320, 240)\nSetImagePixel img, 100, 50, Color(1, 0, 0)",
		0)

	_add("PSet",
		"PSet x, y, color",
		"Draws a single pixel (VB6-style name). Alias for DrawPixel.",
		"PSet 100, 50, Color(1, 0, 0)   ' Red pixel\nPSet 101, 50, RGB(0, 255, 0)   ' Green pixel",
		0)

	_add("DrawString",
		"DrawString font, position, text, color [, fontSize]",
		"Draws text using a Godot Font object at the specified position. Use GetThemeDefaultFont() to get the default font.",
		"Sub _Draw()\n    Dim f As Variant = GetThemeDefaultFont()\n    DrawString f, Vector2(10, 20), \"Hello World!\", Color.White\n    DrawString f, Vector2(10, 40), \"Score: \" & score, Color.Yellow\nEnd Sub",
		0)

	_add("DrawTexture",
		"DrawTexture texture, x, y [, modulate]\nDrawTexture texture, Vector2(x, y) [, modulate]",
		"Draws a Texture2D at the given position. Use with LoadPicture, CreateTexture, or ImageToTexture. The modulate parameter tints the texture with a color.",
		"' Load and draw a texture\nDim tex As Variant = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTexture tex, 100, 100\n    DrawTexture tex, 300, 100, Color(1, 0.5, 0.5, 0.8)  ' Tinted\nEnd Sub\n\n' Draw from an Image\nDim img = CreateImage(64, 64, Color.Red)\nDim tex2 = CreateTexture(img)\nDrawTexture tex2, 0, 0",
		0)

	_add("DrawTextureRect",
		"DrawTextureRect texture, Rect2(x, y, w, h), tile [, modulate]\nDrawTextureRect texture, x, y, w, h [, tile] [, modulate]",
		"Draws a texture stretched or tiled into a rectangular area. Set tile=True to tile the texture instead of stretching. Essential for rendering Image-based canvases at a display scale.",
		"' Stretch a texture to fill a region\nDim tex = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTextureRect tex, Rect2(0, 0, 640, 480), False\nEnd Sub\n\n' Image-based canvas with scaled display:\nDim img = CreateImage(160, 120)   ' Small canvas\nDim tex = CreateTexture(img)\nSub _Draw()\n    UpdateTexture tex, img\n    DrawTextureRect tex, Rect2(0, 0, 640, 480), False  ' 4x scale\nEnd Sub",
		0)

	_add("DrawArc",
		"DrawArc x, y, radius, startAngle, endAngle [, pointCount] [, color] [, width]",
		"Draws an arc (partial circle outline) centered at (x,y). Angles are in radians (0 = right, PI/2 = down). pointCount controls smoothness (default 32).",
		"Sub _Draw()\n    ' Half circle (0 to PI)\n    DrawArc 200, 200, 80, 0, 3.14159, 32, Color.Red, 2\n    ' Quarter circle\n    DrawArc 400, 200, 60, 0, 1.5708, 16, Color.Blue, 3\n    ' Full circle outline\n    DrawArc 300, 300, 100, 0, 6.28318, 64, Color.White, 1\nEnd Sub",
		0)

	_add("DrawPolygon",
		"DrawPolygon points, color",
		"Draws a filled polygon from an array of Vector2 points. Points should be in order (clockwise or counter-clockwise). Use for triangles, custom shapes, filled regions.",
		"Sub _Draw()\n    ' Triangle\n    Dim tri As Variant = Array(Vector2(100,200), Vector2(200,50), Vector2(300,200))\n    DrawPolygon tri, Color.Green\n    ' Pentagon\n    Dim pent As Variant = Array( _\n        Vector2(200,50), Vector2(300,120), Vector2(260,230), _\n        Vector2(140,230), Vector2(100,120))\n    DrawPolygon pent, Color(0.5, 0.2, 0.8)\nEnd Sub",
		0)

	_add("DrawPolyline",
		"DrawPolyline points, color [, width]",
		"Draws a multi-segment line through an array of Vector2 points. Unlike DrawPolygon, this draws open lines (not filled). Great for graphs, paths, vector shapes.",
		"Sub _Draw()\n    ' Zigzag line\n    Dim pts As Variant = Array( _\n        Vector2(10,100), Vector2(50,50), Vector2(90,100), _\n        Vector2(130,50), Vector2(170,100))\n    DrawPolyline pts, Color.Yellow, 2\nEnd Sub",
		0)

	_add("SetDrawTransform",
		"SetDrawTransform x, y [, rotation] [, scaleX] [, scaleY]",
		"Sets a 2D transform for all subsequent draw calls. Translation (x,y), rotation in radians, and scale factors. Use to draw rotated or scaled groups of shapes.",
		"Sub _Draw()\n    ' Draw a rotated square\n    SetDrawTransform 200, 200, 0.785  ' 45 degrees\n    DrawRect -25, -25, 50, 50, Color.Red\n    ResetDrawTransform\n\n    ' Draw scaled UI\n    SetDrawTransform 0, 0, 0, 2.0, 2.0  ' 2x scale\n    DrawRect 0, 0, 50, 50, Color.Blue    ' Appears as 100x100\n    ResetDrawTransform\nEnd Sub",
		0)

	_add("ResetDrawTransform",
		"ResetDrawTransform",
		"Resets the drawing transform to identity (no translation, rotation, or scale). Always call after SetDrawTransform to restore normal coordinates.",
		"SetDrawTransform 100, 100, 0.5, 2.0, 2.0\nDrawCircle 0, 0, 30, Color.Red   ' Drawn transformed\nResetDrawTransform                    ' Back to normal\nDrawCircle 50, 50, 10, Color.Blue ' Drawn at actual 50,50",
		0)

	_add("QueueRedraw",
		"QueueRedraw",
		"Requests the node to redraw on the next frame. Call this after changing any visual state that should be reflected in _Draw(). Useful in _Process() or event handlers to trigger a visual update.",
		"Sub _Process(delta)\n    If stateChanged Then\n        QueueRedraw  ' Triggers _Draw() next frame\n    End If\nEnd Sub\n\n' Or simply call every frame:\nSub _Process(delta)\n    QueueRedraw\nEnd Sub",
		0)

	_add("CLS",
		"CLS\nCLS()",
		"Clears the screen/canvas. Removes all dynamically created child nodes and triggers a redraw. VB6 classic command.",
		"CLS  ' Clear everything\n\n' Typical usage: clear before redrawing\nSub _Draw()\n    ' CLS is implicit in _Draw — each frame starts clean\n    DrawRect 0, 0, 640, 480, Color.Black   ' Background\n    DrawString GetThemeDefaultFont(), Vector2(10, 20), \"Game Over\", Color.White\nEnd Sub",
		0)

	# =========================================================================
	# IMAGE & TEXTURE MANIPULATION
	# =========================================================================
	_add("CreateImage",
		"CreateImage(width, height [, fillColor]) As Image",
		"Creates a new RGBA8 Image object with the specified dimensions (1-4096 pixels). The optional fillColor sets all pixels to that color (default is transparent black). Images are in-memory pixel buffers — use SetImagePixel to draw on them, then CreateTexture or UpdateTexture to display them.",
		"' Create a white 640x480 canvas\nDim img As Variant = CreateImage(640, 480, Color(1, 1, 1, 1))\n\n' Create a transparent 256x256 sprite sheet\nDim sheet As Variant = CreateImage(256, 256)\n\n' Draw on it\nSetImagePixel img, 100, 100, Color.Red\nSetImagePixel img, 101, 100, Color.Red\n\n' Display it\nDim tex As Variant = CreateTexture(img)\nDrawTexture tex, 0, 0",
		0)

	_add("CreateTexture",
		"CreateTexture(image) As ImageTexture\nCreateTexture(width, height [, fillColor]) As ImageTexture",
		"Creates an ImageTexture for display with DrawTexture. Can accept an existing Image, or width/height to create both an Image and Texture in one call. ImageTextures live on the GPU and are fast to render.",
		"' From an existing Image\nDim img = CreateImage(320, 240, Color.White)\nDim tex = CreateTexture(img)\n\n' Quick one-liner: create texture directly\nDim tex2 = CreateTexture(64, 64, Color.Blue)\n\n' Display in _Draw()\nSub _Draw()\n    DrawTexture tex, 0, 0\nEnd Sub",
		0)

	_add("ImageToTexture",
		"ImageToTexture(image) As ImageTexture",
		"Converts an Image object to a new ImageTexture. Similar to CreateTexture(image) but always creates a new texture object.",
		"Dim img = CreateImage(100, 100, Color.Green)\nDim tex = ImageToTexture(img)\nDrawTexture tex, 50, 50",
		0)

	_add("SetImagePixel",
		"SetImagePixel image, x, y, color",
		"Sets a pixel color on an Image object. After modifying pixels, call UpdateTexture to push changes to the display texture. Use Color() or Color8() to create the color value.",
		"Dim img = CreateImage(100, 100)\nDim tex = CreateTexture(img)\n\n' Draw a red diagonal line\nFor i = 0 To 99\n    SetImagePixel img, i, i, Color(1, 0, 0, 1)\nNext\nUpdateTexture tex, img  ' Push changes to GPU\n\n' Using Color8 (0-255 range)\nSetImagePixel img, 50, 50, Color8(0, 255, 0, 255)",
		0)

	_add("GetImagePixel",
		"GetImagePixel(image, x, y) As Color",
		"Returns the color of a pixel from an Image. The returned Color has .r, .g, .b, .a properties (0.0 to 1.0 range). Multiply by 255 for integer RGB values.",
		"Dim img = CreateImage(100, 100, Color.Red)\nDim c As Variant = GetImagePixel(img, 50, 50)\nPrint \"R=\" & Str(c.r)   ' 1.0\nPrint \"G=\" & Str(c.g)   ' 0.0\n\n' Get as integer 0-255\nDim r As Integer = Int(c.r * 255)\nDim g As Integer = Int(c.g * 255)\nDim b As Integer = Int(c.b * 255)",
		0)

	_add("FillImage",
		"FillImage image, color",
		"Fills the entire Image with a solid color. Much faster than looping over every pixel with SetImagePixel. Use for clearing a canvas or setting a background.",
		"Dim img = CreateImage(640, 480)\n\n' Clear to white\nFillImage img, Color(1, 1, 1, 1)\n\n' Clear to black\nFillImage img, Color(0, 0, 0, 1)\n\n' Using Color8\nFillImage img, Color8(100, 150, 200, 255)",
		0)

	_add("FillImageRect",
		"FillImageRect image, Rect2i(x, y, w, h), color\nFillImageRect image, x, y, w, h, color",
		"Fills a rectangular region of an Image with a color. Faster than per-pixel loops for rectangular fills.",
		"Dim img = CreateImage(320, 240, Color.White)\n\n' Draw a green rectangle\nFillImageRect img, Rect2i(10, 10, 100, 50), Color(0, 1, 0, 1)\n\n' VB-style arguments\nFillImageRect img, 50, 80, 200, 30, Color.Blue",
		0)

	_add("BlitImage",
		"BlitImage destImage, srcImage, srcRect, destPos",
		"Copies a rectangular region of pixels from a source Image to a destination Image. srcRect is a Rect2i defining the source region, destPos is a Vector2i for the destination top-left corner.",
		"Dim canvas = CreateImage(640, 480, Color.White)\nDim stamp = CreateImage(32, 32, Color.Red)\n\n' Stamp the red square onto the canvas at (100, 100)\nBlitImage canvas, stamp, Rect2i(0, 0, 32, 32), Vector2i(100, 100)\n\n' Copy part of canvas to another location\nBlitImage canvas, canvas, Rect2i(0, 0, 100, 100), Vector2i(200, 200)",
		0)

	_add("UpdateTexture",
		"UpdateTexture texture, image",
		"Pushes updated Image pixel data to an existing ImageTexture. Call this after modifying pixels with SetImagePixel, FillImage, or BlitImage to make the changes visible on screen. This is an essential step in the Image → Texture rendering pipeline.",
		"Dim img = CreateImage(320, 240)\nDim tex = CreateTexture(img)\n\n' Modify pixels\nFor x = 0 To 319\n    SetImagePixel img, x, 120, Color.Red\nNext\n\n' IMPORTANT: Push to GPU\nUpdateTexture tex, img\n\n' Now DrawTexture will show the changes\nSub _Draw()\n    DrawTexture tex, 0, 0\nEnd Sub",
		0)

	_add("ImageWidth",
		"ImageWidth(image) As Integer",
		"Returns the width of an Image in pixels.",
		"Dim img = CreateImage(320, 240)\nPrint ImageWidth(img)   ' 320\nPrint ImageHeight(img)  ' 240",
		0)

	_add("ImageHeight",
		"ImageHeight(image) As Integer",
		"Returns the height of an Image in pixels.",
		"Dim img = CreateImage(320, 240)\nPrint ImageHeight(img)  ' 240\n\n' Iterate all pixels\nFor y = 0 To ImageHeight(img) - 1\n    For x = 0 To ImageWidth(img) - 1\n        SetImagePixel img, x, y, Color(x/320.0, y/240.0, 0.5, 1)\n    Next\nNext",
		0)

	_add("TextureWidth",
		"TextureWidth(texture) As Integer",
		"Returns the width of a Texture2D in pixels.",
		"Dim tex = LoadPicture(\"res://icon.png\")\nPrint TextureWidth(tex)   ' e.g. 128\nPrint TextureHeight(tex)  ' e.g. 128",
		0)

	_add("TextureHeight",
		"TextureHeight(texture) As Integer",
		"Returns the height of a Texture2D in pixels.",
		"Dim tex = CreateTexture(256, 128)\nPrint TextureWidth(tex)    ' 256\nPrint TextureHeight(tex)   ' 128",
		0)

	_add("GetTextureImage",
		"GetTextureImage(texture) As Image",
		"Extracts the Image data from an ImageTexture. Useful for reading pixel data from a loaded texture. The returned Image can be modified and pushed back with UpdateTexture.",
		"Dim tex = LoadPicture(\"res://icon.png\")\nDim img = GetTextureImage(tex)\nDim c = GetImagePixel(img, 0, 0)  ' Read top-left pixel\nPrint \"Top-left color: R=\" & Str(Int(c.r * 255))",
		0)

	_add("SaveImage",
		"SaveImage(image, path) As Boolean",
		"Saves an Image to a PNG file. Returns True on success. Use user:// paths for writable locations. Great for screenshots or saving user-created art.",
		"Dim img = CreateImage(640, 480, Color.White)\n' ... draw on img ...\nDim ok As Boolean = SaveImage(img, \"user://screenshot.png\")\nIf ok Then\n    Print \"Saved!\"\nEnd If",
		0)

	_add("LoadImage",
		"LoadImage(path) As Image",
		"Loads an image file (PNG, JPG, BMP, etc.) and returns it as an RGBA8 Image object. Unlike LoadPicture (which returns a Texture2D), LoadImage gives you direct pixel access via GetImagePixel.",
		"Dim img = LoadImage(\"user://painting.png\")\nPrint \"Size: \" & Str(ImageWidth(img)) & \"x\" & Str(ImageHeight(img))\n\n' Read a pixel\nDim c = GetImagePixel(img, 0, 0)\nPrint \"R=\" & Str(Int(c.r * 255))\n\n' Convert to texture for display\nDim tex = ImageToTexture(img)\nDrawTexture tex, 0, 0",
		0)

	_add("LoadPicture",
		"LoadPicture(path) As Texture2D",
		"Loads an image file from the given resource path and returns a Texture2D for use with DrawTexture. The classic VB6-style way to load images.",
		"Dim tex As Variant = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTexture tex, 100, 100\nEnd Sub",
		0)

	_add("RGB",
		"RGB(red, green, blue) As Color",
		"Creates a Color from integer red, green, blue values (0-255). VB6-compatible function.",
		"Dim c As Variant = RGB(255, 0, 0)  ' Red\nDrawRect 0, 0, 100, 100, RGB(0, 128, 255)  ' Sky blue",
		0)

	# =========================================================================
	# GODOT API — common game-dev methods, properties, and callbacks
	# =========================================================================
	_add_godot("move_and_slide",
		"move_and_slide() As Boolean",
		"Moves the body based on [b]velocity[/b], sliding along collisions. Call in [b]_PhysicsProcess[/b]. Returns True if a collision occurred.",
		"Sub _PhysicsProcess(delta As Single)\n    velocity.y += 980 * delta   ' gravity\n    move_and_slide\nEnd Sub",
		"CharacterBody2D", "move_and_slide")

	_add_godot("velocity",
		"velocity As Vector2",
		"The current velocity vector of a CharacterBody2D or CharacterBody3D. Set this before calling [b]move_and_slide[/b].",
		"velocity.x = 200   ' move right\nvelocity.y = -400  ' jump\nmove_and_slide",
		"CharacterBody2D")

	_add_godot("position",
		"position As Vector2",
		"The position of the node relative to its parent. For Node2D and Control nodes.",
		"position = Vector2(100, 200)\nposition.x += 5  ' move right",
		"Node2D")

	_add_godot("rotation",
		"rotation As Single",
		"The rotation of the node in radians. For Node2D and Node3D.",
		"rotation = 1.57     ' 90 degrees\nrotation += delta   ' spin continuously",
		"Node2D")

	_add_godot("rotation_degrees",
		"rotation_degrees As Single",
		"The rotation of the node in degrees. Convenience wrapper around [b]rotation[/b].",
		"rotation_degrees = 90\nrotation_degrees += 180 * delta",
		"Node2D")

	_add_godot("scale",
		"scale As Vector2",
		"The scale of the node. Vector2(1, 1) is the default (no scaling).",
		"scale = Vector2(2, 2)  ' double size\nscale *= 0.5           ' halve size",
		"Node2D")

	_add_godot("global_position",
		"global_position As Vector2",
		"The position of the node in global (world) coordinates, not relative to the parent.",
		"global_position = Vector2(500, 300)\nDim dist As Single = global_position.distance_to(target.global_position)",
		"Node2D")

	_add_godot("delta",
		"delta As Single",
		"The elapsed time since the previous frame (in seconds). Passed to [b]_Process[/b] and [b]_PhysicsProcess[/b]. Use it to make movement frame-rate independent.",
		"Sub _Process(delta As Single)\n    position.x += speed * delta\nEnd Sub",
		"Node", "_process")

	_add_godot("get_node",
		"get_node(path As NodePath) As Node",
		"Returns the node at the given path relative to this node. Also available via the [b]$[/b] shorthand.",
		"Dim player As Node = get_node(\"Player\")\nDim label As Node = get_node(\"UI/ScoreLabel\")",
		"Node", "get_node")

	_add_godot("queue_free",
		"queue_free()",
		"Queues this node for deletion at the end of the current frame. Safer than calling [b]free()[/b] directly.",
		"Sub _on_body_entered(body)\n    body.queue_free   ' destroy the other node\nEnd Sub",
		"Node", "queue_free")

	_add_godot("add_child",
		"add_child(node As Node)",
		"Adds a child node to this node. The child will appear in the scene tree under this node.",
		"Dim bullet As Node2D = preload(\"res://Bullet.tscn\").instantiate()\nadd_child bullet",
		"Node", "add_child")

	_add_godot("remove_child",
		"remove_child(node As Node)",
		"Removes a child node from this node without freeing it.",
		"remove_child(oldNode)\noldNode.queue_free",
		"Node", "remove_child")

	_add_godot("connect",
		"connect(signal_name As String, callable As Callable)",
		"Connects a signal to a callback method. Use Godot 4 Callable syntax.",
		"connect(\"body_entered\", _on_body_entered)\ntimer.connect(\"timeout\", _on_timeout)",
		"Object", "connect")

	_add_godot("emit_signal",
		"emit_signal(signal_name As String, ...)",
		"Emits the given signal, optionally passing arguments to connected callbacks.",
		"emit_signal(\"health_changed\", currentHP)\nemit_signal(\"died\")",
		"Object", "emit_signal")

	_add_godot("_ready",
		"Sub _Ready()",
		"Called when the node and all its children have entered the scene tree. Use for initialization.",
		"Sub _Ready()\n    Dim startPos As Vector2 = position\n    visible = True\nEnd Sub",
		"Node", "_ready")

	_add_godot("_process",
		"Sub _Process(delta As Single)",
		"Called every frame. [b]delta[/b] is the elapsed time in seconds. Use for game logic, animation, and non-physics movement.",
		"Sub _Process(delta As Single)\n    rotation_degrees += 90 * delta\nEnd Sub",
		"Node", "_process")

	_add_godot("_physics_process",
		"Sub _PhysicsProcess(delta As Single)",
		"Called every physics frame (default 60 fps). Use for physics-based movement and collision detection.",
		"Sub _PhysicsProcess(delta As Single)\n    velocity.y += gravity * delta\n    move_and_slide\nEnd Sub",
		"Node", "_physics_process")

	_add_godot("_input",
		"Sub _Input(event As InputEvent)",
		"Called when any input event occurs (keyboard, mouse, touch, gamepad). Consume with [b]set_input_as_handled[/b].",
		"Sub _Input(event As InputEvent)\n    If event.is_action_pressed(\"jump\") Then\n        velocity.y = -400\n    End If\nEnd Sub",
		"Node", "_input")

	_add_godot("_draw",
		"Sub _Draw()",
		"Called when the CanvasItem needs to be redrawn. Use draw_* methods inside. Call [b]queue_redraw[/b] to trigger.",
		"Sub _Draw()\n    DrawCircle 100, 100, 50, RGB(255, 0, 0)\n    DrawLine 0, 0, 200, 200, RGB(0, 255, 0)\nEnd Sub",
		"CanvasItem", "_draw")

	_add_godot("visible",
		"visible As Boolean",
		"Controls whether this CanvasItem (2D) or Node3D is visible. Setting to False hides the node and its children.",
		"visible = False  ' hide\nvisible = True   ' show",
		"CanvasItem")

	_add_godot("modulate",
		"modulate As Color",
		"The color modulation applied to this CanvasItem and its children. Useful for tinting or fading.",
		"modulate = Color(1, 0, 0, 1)      ' tint red\nmodulate.a = 0.5                   ' semi-transparent",
		"CanvasItem")

	_add_godot("show",
		"show()",
		"Makes this node visible. Equivalent to setting [b]visible = True[/b].",
		"show   ' make visible",
		"CanvasItem", "show")

	_add_godot("hide",
		"hide()",
		"Makes this node invisible. Equivalent to setting [b]visible = False[/b].",
		"hide   ' make invisible",
		"CanvasItem", "hide")

	_add_godot("queue_redraw",
		"queue_redraw()",
		"Queues a redraw of this CanvasItem. This triggers [b]_Draw[/b] to be called again.",
		"score += 1\nqueue_redraw   ' refresh the display",
		"CanvasItem", "queue_redraw")

	_add_godot("get_tree",
		"get_tree() As SceneTree",
		"Returns the SceneTree this node belongs to. Used for scene management, groups, and timers.",
		"get_tree().change_scene_to_file(\"res://GameOver.tscn\")\nget_tree().quit()",
		"Node", "get_tree")

	_add_godot("instantiate",
		"instantiate() As Node",
		"Creates an instance of a PackedScene. Load the scene first with [b]preload[/b] or [b]load[/b].",
		"Dim scene As PackedScene = preload(\"res://Bullet.tscn\")\nDim bullet As Node = scene.instantiate()\nadd_child bullet",
		"PackedScene", "instantiate")

	_add_godot("is_on_floor",
		"is_on_floor() As Boolean",
		"Returns True if the CharacterBody was on the floor during the last [b]move_and_slide[/b] call.",
		"If is_on_floor() Then\n    velocity.y = -jump_force\nEnd If",
		"CharacterBody2D", "is_on_floor")

	_add_godot("is_on_wall",
		"is_on_wall() As Boolean",
		"Returns True if the CharacterBody was touching a wall during the last [b]move_and_slide[/b] call.",
		"If is_on_wall() Then\n    ' wall slide or wall jump\nEnd If",
		"CharacterBody2D", "is_on_wall")

	_add_godot("look_at",
		"look_at(target As Vector2)",
		"Rotates the node so it points toward the target position.",
		"look_at(get_global_mouse_position())",
		"Node2D", "look_at")

	_add_godot("get_global_mouse_position",
		"get_global_mouse_position() As Vector2",
		"Returns the mouse position in global coordinates.",
		"Dim mouse As Vector2 = get_global_mouse_position()\nlook_at(mouse)",
		"CanvasItem", "get_global_mouse_position")

	_add_godot("set_process",
		"set_process(enable As Boolean)",
		"Enables or disables [b]_Process[/b] for this node.",
		"set_process(False)   ' pause processing\nset_process(True)    ' resume",
		"Node", "set_process")

	_add_godot("is_action_pressed",
		"Input.is_action_pressed(action As String) As Boolean",
		"Returns True while the specified input action is held down. Defined in Project → Input Map.",
		"If Input.is_action_pressed(\"move_left\") Then\n    velocity.x = -speed\nEnd If",
		"Input", "is_action_pressed")

	_add_godot("is_action_just_pressed",
		"Input.is_action_just_pressed(action As String) As Boolean",
		"Returns True only on the frame the action was first pressed.",
		"If Input.is_action_just_pressed(\"jump\") And is_on_floor() Then\n    velocity.y = -jump_force\nEnd If",
		"Input", "is_action_just_pressed")

	_add_godot("is_action_just_released",
		"Input.is_action_just_released(action As String) As Boolean",
		"Returns True only on the frame the action was released.",
		"If Input.is_action_just_released(\"shoot\") Then\n    ' fire charged shot\nEnd If",
		"Input", "is_action_just_released")

## =========================================================================
## SEE ALSO — cross-reference groups (#6)
## =========================================================================
static func _build_see_also() -> void:
	# Helper: assign bidirectional see-also for a group of keywords
	var groups: Array = [
		# Variable declaration
		["Dim", "Private", "Public", "Global", "Static", "Const", "ReDim", "Type"],
		# Data types
		["Integer", "Long", "Single", "Double", "String", "Boolean", "Variant", "Array"],
		# If / branching
		["If", "Then", "Else", "ElseIf", "End If", "Select Case", "IIf"],
		# Select
		["Select", "Select Case", "Case", "End Select"],
		# For loop
		["For", "Next", "For Each", "Continue", "Exit"],
		# Do loop
		["Do", "Loop", "While", "Wend", "Until", "Exit"],
		# Error handling
		["On Error", "Try", "Catch", "Finally", "Throw"],
		# Procedures
		["Sub", "Function", "End Sub", "End Function", "Call", "Return", "ByRef", "ByVal", "Optional", "Lambda"],
		# String functions
		["Left", "Right", "Mid", "Trim", "LCase", "UCase", "Len", "InStr", "Replace", "Split", "Join", "Format"],
		# Type conversion
		["CInt", "CStr", "Val", "Str", "Int"],
		# Math
		["Abs", "Int", "Sqr", "Rnd", "Randomize", "RandRange", "Round", "Clamp", "Lerp", "Mod"],
		# Trig
		["Sin", "Cos"],
		# Logical operators
		["And", "Or", "Not", "Xor"],
		# Drawing — shapes
		["DrawLine", "DrawRect", "DrawCircle", "DrawArc", "DrawPixel", "DrawPolygon", "DrawPolyline", "PSet", "CLS", "QueueRedraw"],
		# Drawing — text & images
		["DrawString", "DrawTexture", "DrawTextureRect"],
		# Drawing — transform
		["SetDrawTransform", "ResetDrawTransform"],
		# Image manipulation
		["CreateImage", "FillImage", "FillImageRect", "GetImagePixel", "SetImagePixel", "BlitImage", "ImageWidth", "ImageHeight"],
		# Image ↔ Texture
		["ImageToTexture", "CreateTexture", "UpdateTexture", "GetTextureImage", "TextureWidth", "TextureHeight"],
		# Image I/O
		["LoadImage", "LoadPicture", "SaveImage", "RGB"],
		# File I/O
		["Open", "Close", "Line Input", "Data", "Read", "Restore"],
		# OOP
		["Class", "End Class", "New", "Set", "Me", "Implements", "Inherits", "Interface", "Property"],
		# Events
		["Event", "RaiseEvent", "WithEvents"],
		# UI
		["MsgBox", "InputBox", "LoadForm"],
		# Boolean literals
		["True", "False", "Nothing"],
		# Array functions
		["Array", "ReDim", "LBound", "UBound"],
		# Async
		["Async", "Await", "DoEvents"],
		# Scope modifiers
		["With", "End With", "Using"],
		# Game
		["IsActionPressed", "IsKeyPressed", "PlaySound", "ChangeScene", "CreateActor2D"],
		# GoTo
		["GoTo", "GoSub", "Return"],
		# Godot — Movement / Physics
		["move_and_slide", "velocity", "is_on_floor", "is_on_wall", "_physics_process", "delta"],
		# Godot — Position / Transform
		["position", "global_position", "rotation", "rotation_degrees", "scale", "look_at"],
		# Godot — Node lifecycle
		["_ready", "_process", "_physics_process", "_input", "_draw"],
		# Godot — Scene tree
		["get_node", "add_child", "remove_child", "queue_free", "get_tree", "instantiate"],
		# Godot — Signals
		["connect", "emit_signal"],
		# Godot — Visibility
		["visible", "show", "hide", "modulate"],
		# Godot — Input
		["is_action_pressed", "is_action_just_pressed", "is_action_just_released"],
	]
	for group in groups:
		for kw in group:
			var key := (kw as String).to_lower()
			if not _see_also.has(key):
				_see_also[key] = []
			for other in group:
				if (other as String).to_lower() != key:
					if not _see_also[key].has(other):
						_see_also[key].append(other)

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
		"Dim score As Integer = 0\nDim playerName As String = \"Hero\"\nDim items() As String\nDim health As Single = 100.0", 6195)

	_add("Global",
		"Global variableName As DataType",
		"Declares a module-level global variable accessible from any procedure in the form or module.",
		"Global highScore As Integer\nGlobal currentLevel As Integer = 1", 7322)

	_add("Public",
		"Public variableName As DataType\nPublic Sub ProcedureName()",
		"Declares a public variable or procedure accessible from other modules and forms.",
		"Public userName As String\nPublic Sub SaveGame()\n    ' Save logic here\nEnd Sub", 9814)

	_add("Private",
		"Private variableName As DataType\nPrivate Sub ProcedureName()",
		"Declares a private variable or procedure only accessible within the current module.",
		"Private lives As Integer = 3\nPrivate Sub ResetLevel()\n    lives = 3\nEnd Sub", 9727)

	_add("Static",
		"Static variableName As DataType",
		"Declares a variable that retains its value between procedure calls. Unlike Dim, static variables are not reset when the procedure exits.",
		"Sub CountCalls()\n    Static callCount As Integer\n    callCount = callCount + 1\n    Print \"Called \" & callCount & \" times\"\nEnd Sub", 11938)

	_add("Const",
		"Const CONSTANT_NAME As DataType = value",
		"Declares a named constant whose value cannot be changed after initialization.",
		"Const MAX_PLAYERS As Integer = 4\nConst PI As Double = 3.14159\nConst GAME_TITLE As String = \"My Game\"", 5666)

	_add("ReDim",
		"ReDim [Preserve] arrayName(newSize)",
		"Resizes a dynamic array. Use Preserve to keep existing data when resizing.",
		"Dim scores() As Integer\nReDim scores(10)\nscores(0) = 100\nReDim Preserve scores(20)  ' Keeps old data", 10364)

	_add("Set",
		"Set objectVariable = objectExpression\nSet objectVariable = New ClassName",
		"Assigns an object reference to a variable. Required for object types (not needed for simple types).",
		"Dim player As Object\nSet player = New Player\nSet player = Nothing  ' Release reference", 11030)

	# =========================================================================
	# CONTROL FLOW — CONDITIONALS
	# =========================================================================
	_add("If",
		"If condition Then\n    statements\n[ElseIf condition Then]\n    statements\n[Else]\n    statements\nEnd If",
		"Executes code conditionally. Supports multi-line blocks with ElseIf and Else branches, or single-line form.",
		"If score > highScore Then\n    highScore = score\n    Print \"New high score!\"\nElseIf score > 0 Then\n    Print \"Good job!\"\nElse\n    Print \"Try again!\"\nEnd If\n\n' Single-line form:\nIf health <= 0 Then gameOver = True", 7541)

	_add("ElseIf",
		"ElseIf condition Then\n    statements",
		"Provides an additional condition to test when the preceding If or ElseIf was False.",
		"If score >= 90 Then\n    grade = \"A\"\nElseIf score >= 80 Then\n    grade = \"B\"\nElseIf score >= 70 Then\n    grade = \"C\"\nElse\n    grade = \"F\"\nEnd If", 6634)

	_add("Else",
		"Else\n    statements",
		"Specifies code to execute when the If condition (and all ElseIf conditions) are False.",
		"If IsKeyPressed(\"space\") Then\n    Jump()\nElse\n    Fall()\nEnd If", 6609)

	_add("Then",
		"If condition Then statements",
		"Part of the If statement. Follows the condition and precedes the code to execute.",
		"If health <= 0 Then GameOver()\nIf x > 10 Then x = 10", 12420)

	_add("End If",
		"End If",
		"Terminates a multi-line If...Then...Else block.",
		"If score > 100 Then\n    Print \"Winner!\"\nEnd If", 6770)

	_add("IIf",
		"IIf(condition, trueValue, falseValue)",
		"Inline If — returns one of two values based on a condition. Similar to the ternary operator in other languages.",
		"message = IIf(score > 100, \"Excellent!\", \"Keep trying!\")\ncolor = IIf(health < 20, \"Red\", \"Green\")", 7577)

	# =========================================================================
	# CONTROL FLOW — SELECT CASE
	# =========================================================================
	_add("Select Case",
		"Select Case testExpression\n    Case value1\n        statements\n    Case value2, value3\n        statements\n    Case Else\n        statements\nEnd Select",
		"Evaluates an expression and branches to the matching Case block. Supports ranges (1 To 5), comparison (Is > 10), and comma-separated lists.",
		"Select Case score\n    Case 100\n        Print \"Perfect!\"\n    Case 80 To 99\n        Print \"Great!\"\n    Case Is >= 50\n        Print \"Passed\"\n    Case Else\n        Print \"Try again\"\nEnd Select", 10845)

	_add("Select",
		"Select Case expression",
		"Begins a Select Case block for multi-way branching based on an expression's value.",
		"Select Case dayOfWeek\n    Case 1\n        Print \"Monday\"\n    Case 7\n        Print \"Sunday\"\nEnd Select", 10816)

	_add("Case",
		"Case value [, value2] [To value3]",
		"Specifies a value or range to match in a Select Case block. Supports comma lists, ranges with To, and comparisons with Is.",
		"Case 1, 2, 3     ' Match any of these\nCase 10 To 20    ' Match range\nCase Is > 100    ' Match comparison\nCase Else        ' Default case", 5221)

	_add("End Select",
		"End Select",
		"Terminates a Select Case block.",
		"Select Case x\n    Case 1\n        Print \"One\"\nEnd Select", 6796)

	# =========================================================================
	# CONTROL FLOW — LOOPS
	# =========================================================================
	_add("For",
		"For counter = start To end [Step increment]\n    statements\nNext [counter]",
		"Repeats a block of code a specific number of times. The Step clause controls the increment (default is 1). Use Exit For to leave early.",
		"For i = 1 To 10\n    Print i\nNext i\n\nFor i = 10 To 0 Step -1\n    Print \"Countdown: \" & i\nNext\n\nFor i = 0 To 100 Step 5\n    Print i\nNext", 7072)

	_add("For Each",
		"For Each element In collection\n    statements\nNext [element]",
		"Iterates over every element in an array, list, or collection.",
		"Dim names() As String = {\"Alice\", \"Bob\", \"Carol\"}\nFor Each name In names\n    Print \"Hello, \" & name\nNext", 7104)

	_add("Next",
		"Next [counter]",
		"Marks the end of a For or For Each loop. The counter variable name is optional.",
		"For i = 1 To 5\n    Print i\nNext i", 9146)

	_add("Do",
		"Do [While|Until condition]\n    statements\nLoop [While|Until condition]",
		"Repeats a block while or until a condition is met. The condition can appear at the top (Do While) or bottom (Loop Until) of the loop.",
		"' Pre-check loop\nDo While health > 0\n    ProcessTurn()\nLoop\n\n' Post-check loop (runs at least once)\nDo\n    answer = InputBox(\"Guess?\")\nLoop Until answer = secretWord", 6222)

	_add("While",
		"While condition\n    statements\nWend",
		"Repeats a block as long as the condition is True. Legacy syntax; prefer Do...Loop for new code.",
		"While Not gameOver\n    Update()\n    Draw()\nWend", 13111)

	_add("Wend",
		"Wend",
		"Terminates a While loop (legacy syntax).",
		"While x < 100\n    x = x + 1\nWend", 13062)

	_add("Loop",
		"Loop [While|Until condition]",
		"Terminates a Do loop. Optionally tests a condition after each iteration.",
		"Do\n    x = x + 1\nLoop Until x >= 10", 8698)

	_add("Until",
		"Do ... Loop Until condition\nDo Until condition ... Loop",
		"Loop continuation condition — the loop repeats until the condition becomes True.",
		"Do\n    tries = tries + 1\nLoop Until success Or tries > 10", 12679)

	_add("Exit",
		"Exit Sub | Exit Function | Exit For | Exit Do | Exit While",
		"Immediately exits the current procedure or loop. Control passes to the statement after the End Sub/Next/Loop.",
		"For i = 1 To 100\n    If items(i) = target Then\n        foundAt = i\n        Exit For\n    End If\nNext", 6932)

	_add("Continue",
		"Continue For | Continue Do | Continue While",
		"Skips the rest of the current loop iteration and continues with the next iteration.",
		"For i = 0 To 99\n    If scores(i) < 0 Then Continue For\n    total = total + scores(i)\nNext", 5692)

	# =========================================================================
	# PROCEDURES & FUNCTIONS
	# =========================================================================
	_add("Sub",
		"[Public|Private] Sub procedureName([parameters])\n    statements\nEnd Sub",
		"Declares a subroutine — a procedure that performs an action but does not return a value. Event handlers are Subs named ObjectName_EventName.",
		"Sub btnStart_Click()\n    StartGame()\nEnd Sub\n\nPrivate Sub ResetScore()\n    score = 0\n    UpdateDisplay()\nEnd Sub", 12077)

	_add("End Sub",
		"End Sub",
		"Terminates a Sub procedure definition.",
		"Sub Form_Load()\n    Print \"Ready!\"\nEnd Sub", 6823)

	_add("Function",
		"[Public|Private] Function name([params]) As ReturnType\n    statements\n    Function = returnValue  ' or: Return returnValue\nEnd Function",
		"Declares a function that returns a value. Set the return value by assigning to the function name or using Return.",
		"Function AddScore(points As Integer) As Integer\n    score = score + points\n    AddScore = score  ' Return value\nEnd Function\n\nFunction GetGrade(score As Integer) As String\n    If score >= 90 Then Return \"A\"\n    If score >= 80 Then Return \"B\"\n    Return \"C\"\nEnd Function", 7155)

	_add("End Function",
		"End Function",
		"Terminates a Function definition.",
		"Function Square(x As Integer) As Integer\n    Square = x * x\nEnd Function", 6744)

	_add("Call",
		"Call procedureName([arguments])\nprocedureName [arguments]",
		"Explicitly calls a Sub or Function. The Call keyword is optional — you can call procedures by name alone.",
		"Call UpdateScore(10)\nUpdateScore 10       ' Same thing without Call\nCall Form2.Show()", 4896)

	_add("Return",
		"Return [value]",
		"Returns from the current Sub or Function. In a Function, optionally provides the return value.",
		"Function IsPositive(n As Integer) As Boolean\n    Return n > 0\nEnd Function\n\nSub CheckHealth()\n    If health > 0 Then Return  ' Early exit\n    GameOver()\nEnd Sub", 10498)

	_add("ByVal",
		"Sub ProcName(ByVal paramName As DataType)",
		"Passes an argument by value — the procedure gets a copy, so changes don't affect the caller's variable.",
		"Sub DoubleIt(ByVal x As Integer)\n    x = x * 2  ' Only changes local copy\n    Print x\nEnd Sub", 4866)

	_add("ByRef",
		"Sub ProcName(ByRef paramName As DataType)",
		"Passes an argument by reference — the procedure can modify the caller's original variable. This is the default if neither ByVal nor ByRef is specified.",
		"Sub SwapValues(ByRef a As Integer, ByRef b As Integer)\n    Dim temp As Integer = a\n    a = b\n    b = temp\nEnd Sub", 4838)

	_add("Optional",
		"Sub ProcName(Optional paramName As Type = defaultValue)",
		"Declares a parameter that the caller may omit. A default value is provided.",
		"Sub ShowMessage(msg As String, Optional title As String = \"Info\")\n    MsgBox msg, title\nEnd Sub\n\nShowMessage \"Hello\"         ' Uses default title\nShowMessage \"Error\", \"Oops\"  ' Custom title", 9319)

	# =========================================================================
	# ERROR HANDLING
	# =========================================================================
	_add("On Error",
		"On Error GoTo labelName\nOn Error Resume Next\nOn Error GoTo 0",
		"Sets up error handling. GoTo sends errors to a label. Resume Next skips errors. GoTo 0 disables the handler.",
		"Sub LoadData()\n    On Error GoTo HandleError\n    Open \"data.txt\" For Input As #1\n    ' ... read data ...\n    Close #1\n    Exit Sub\n\nHandleError:\n    Print \"Error: \" & Err.Description\n    Resume Next\nEnd Sub", 9228)

	_add("Try",
		"Try\n    statements\nCatch [ex As Exception]\n    error handling\n[Finally]\n    cleanup\nEnd Try",
		"Structured exception handling. Code in Try is protected; if an error occurs, execution jumps to Catch. Finally always executes.",
		"Try\n    Dim result As Integer = 100 / divisor\n    Print result\nCatch ex As Exception\n    Print \"Error: \" & ex.Message\nFinally\n    Print \"Done\"\nEnd Try", 12559)

	_add("Catch",
		"Catch [variableName As Exception]",
		"Catches an exception thrown in the Try block. The exception object provides Description and Number properties.",
		"Try\n    riskyOperation()\nCatch ex As Exception\n    Print \"Error #\" & ex.Number & \": \" & ex.Description\nEnd Try", 5249)

	_add("Finally",
		"Finally\n    cleanup statements",
		"Code in the Finally block always executes, whether or not an error occurred. Use for cleanup (closing files, etc.).",
		"Try\n    Open \"log.txt\" For Output As #1\n    Print #1, \"Log entry\"\nFinally\n    Close #1  ' Always closes the file\nEnd Try", 7046)

	_add("Throw",
		"Throw exceptionObject\nThrow \"error message\"",
		"Raises an exception. Can throw a string message or an Exception object.",
		"If amount < 0 Then\n    Throw \"Amount cannot be negative\"\nEnd If\n\nSub Validate(age As Integer)\n    If age < 0 Or age > 150 Then Throw \"Invalid age: \" & age\nEnd Sub", 12445)

	_add("GoTo",
		"GoTo labelName",
		"Transfers execution to the specified label. Primarily used in error handling (On Error GoTo). Avoid for general flow control.",
		"On Error GoTo ErrorHandler\n' ... code ...\nExit Sub\n\nErrorHandler:\n    Print \"An error occurred\"\n    Resume Next", 7383)

	_add("GoSub",
		"GoSub labelName\n...\nlabelName:\n    statements\nReturn",
		"Jumps to a labeled subroutine within the same procedure, then returns to the statement after GoSub. Classic VB6 feature.",
		"Sub ProcessData()\n    GoSub ValidateInput\n    GoSub CalculateResult\n    Exit Sub\n\nValidateInput:\n    If data = \"\" Then Print \"No data\"\n    Return\n\nCalculateResult:\n    result = data * 2\n    Return\nEnd Sub", 7347)

	# =========================================================================
	# OBJECT-ORIENTED FEATURES
	# =========================================================================
	_add("Class",
		"Class ClassName\n    [Inherits BaseClass]\n    ' fields, methods, properties\nEnd Class",
		"Declares a new class type. Classes support inheritance, interfaces, properties, and methods.",
		"Class Player\n    Public Name As String\n    Public Health As Integer = 100\n\n    Sub TakeDamage(amount As Integer)\n        Health = Health - amount\n        If Health <= 0 Then Die()\n    End Sub\nEnd Class", 5493)

	_add("End Class",
		"End Class",
		"Terminates a Class definition.",
		"Class Enemy\n    Public Speed As Single = 1.0\nEnd Class", 6718)

	_add("Inherits",
		"Class ChildClass\n    Inherits ParentClass",
		"Specifies that a class inherits from a base class, gaining its fields, properties, and methods.",
		"Class Boss\n    Inherits Enemy\n    Public Phase As Integer = 1\n\n    Sub Attack()\n        MyBase.Attack()  ' Call parent method\n        ' Boss-specific attack\n    End Sub\nEnd Class", 7718)

	_add("Implements",
		"Class MyClass\n    Implements InterfaceName",
		"Declares that a class implements an interface and must provide all of its methods.",
		"Interface IDamageable\n    Sub TakeDamage(amount As Integer)\nEnd Interface\n\nClass Player\n    Implements IDamageable\n    Sub TakeDamage(amount As Integer)\n        health = health - amount\n    End Sub\nEnd Class", 7688)

	_add("Interface",
		"Interface InterfaceName\n    Sub MethodName([params])\n    Function FuncName([params]) As Type\nEnd Interface",
		"Declares an interface — a contract that implementing classes must fulfill.",
		"Interface ISerializable\n    Function Serialize() As String\n    Sub Deserialize(data As String)\nEnd Interface", 7877)

	_add("Property",
		"Property Get Name() As Type\n    Name = internalValue\nEnd Property\n\nProperty Let Name(value As Type)\n    internalValue = value\nEnd Property",
		"Declares a class property with Get (read) and Let/Set (write) accessors.",
		"Class Circle\n    Private _radius As Single\n\n    Property Get Radius() As Single\n        Radius = _radius\n    End Property\n\n    Property Let Radius(value As Single)\n        If value > 0 Then _radius = value\n    End Property\nEnd Class", 9751)

	_add("New",
		"Dim obj As New ClassName\nSet obj = New ClassName([args])",
		"Creates a new instance of a class or object type.",
		"Dim player As New Player\nDim enemies As New Collection\n\nSet boss = New Boss(\"Dragon\", 500)", 9041)

	_add("Me",
		"Me.PropertyName\nMe.MethodName()",
		"Refers to the current object instance. Similar to 'this' in C# or 'self' in Python.",
		"Class Player\n    Public Name As String\n    Sub Introduce()\n        Print \"I am \" & Me.Name\n    End Sub\nEnd Class", 8779)

	_add("With",
		"With objectExpression\n    .Property = value\n    .Method()\nEnd With",
		"Executes a series of statements on a single object without repeating the object name.",
		"With lblScore\n    .Caption = \"Score: \" & score\n    .ForeColor = IIf(score > 100, vbRed, vbBlack)\n    .Visible = True\nEnd With", 13136)

	_add("End With",
		"End With",
		"Terminates a With block.",
		"With player\n    .Health = 100\n    .Score = 0\nEnd With", 6849)

	_add("Enum",
		"Enum EnumName\n    Value1 [= number]\n    Value2\n    ...\nEnd Enum",
		"Declares an enumeration — a set of named integer constants.",
		"Enum GameState\n    Menu = 0\n    Playing = 1\n    Paused = 2\n    GameOver = 3\nEnd Enum\n\nDim state As GameState = GameState.Playing", 6876)

	_add("Type",
		"Type TypeName\n    field1 As DataType\n    field2 As DataType\nEnd Type",
		"Declares a user-defined type (structure) that groups related variables together.",
		"Type Vector2D\n    X As Single\n    Y As Single\nEnd Type\n\nDim pos As Vector2D\npos.X = 100\npos.Y = 200", 12592)

	_add("Event",
		"Event EventName([parameters])",
		"Declares a custom event that can be raised with RaiseEvent.",
		"Class Timer\n    Event Tick()\n    Event Elapsed(seconds As Integer)\nEnd Class", 6905)

	_add("RaiseEvent",
		"RaiseEvent EventName([arguments])",
		"Fires a declared Event, notifying all handlers connected with WithEvents.",
		"Class GameManager\n    Event ScoreChanged(newScore As Integer)\n\n    Sub AddPoints(pts As Integer)\n        score = score + pts\n        RaiseEvent ScoreChanged(score)\n    End Sub\nEnd Class", 10022)

	_add("WithEvents",
		"Dim WithEvents varName As ClassName",
		"Declares an object variable that can respond to the object's events through event handler Subs.",
		"Dim WithEvents gameTimer As Timer\n\nSub gameTimer_Tick()\n    UpdateGame()\nEnd Sub", 13163)

	# =========================================================================
	# DATA TYPES
	# =========================================================================
	_add("Integer",
		"Dim varName As Integer",
		"A 32-bit signed integer type. Range: -2,147,483,648 to 2,147,483,647.",
		"Dim score As Integer = 0\nDim lives As Integer = 3", 7852)

	_add("Long",
		"Dim varName As Long",
		"A 64-bit signed integer type for very large numbers.",
		"Dim bigNumber As Long = 9999999999", 8648)

	_add("Single",
		"Dim varName As Single",
		"A single-precision floating-point number (32-bit). Use for positions, speeds, etc.",
		"Dim speed As Single = 5.5\nDim gravity As Single = 9.8", 11303)

	_add("Double",
		"Dim varName As Double",
		"A double-precision floating-point number (64-bit). More precision than Single.",
		"Dim pi As Double = 3.14159265358979\nDim distance As Double", 6275)

	_add("String",
		"Dim varName As String [= \"text\"]",
		"A text string of any length. Concatenate with & or + operator.",
		"Dim name As String = \"Player 1\"\nDim greeting As String\ngreeting = \"Hello, \" & name & \"!\"", 12051)

	_add("Boolean",
		"Dim varName As Boolean",
		"A True/False value. Used for flags, conditions, and toggles.",
		"Dim gameOver As Boolean = False\nDim isVisible As Boolean = True\nIf gameOver Then EndGame()", 4812)

	_add("Variant",
		"Dim varName As Variant\nDim varName  ' Also Variant by default",
		"A flexible type that can hold any value — integer, string, object, array, etc. Default type when no As clause is given.",
		"Dim value As Variant\nvalue = 42\nvalue = \"Hello\"\nvalue = True", 12793)

	# =========================================================================
	# I/O & PRINTING
	# =========================================================================
	_add("Print",
		"Print expression [; expression ...]\nPrint #fileNumber, expression",
		"Outputs text to the debug console (or to a file when used with a file number). Semicolons suppress the newline between items.",
		"Print \"Score: \" & score\nPrint \"X=\"; x; \" Y=\"; y\nPrint #1, \"Log entry: \" & message", 9706)

	_add("MsgBox",
		"MsgBox prompt [, buttons] [, title]\nresult = MsgBox(prompt, buttons, title)",
		"Displays a message dialog box. Can include OK/Cancel/Yes/No buttons and return the user's choice.",
		"MsgBox \"Game Over!\"\nMsgBox \"Save game?\", vbYesNo, \"Save\"\n\nDim answer As Integer\nanswer = MsgBox(\"Quit?\", vbYesNo + vbQuestion, \"Exit\")\nIf answer = vbYes Then End", 8885)

	_add("InputBox",
		"result = InputBox(prompt [, title] [, default])",
		"Displays a dialog with a text input field and returns the user's text.",
		"Dim name As String\nname = InputBox(\"Enter your name:\", \"Player Setup\", \"Player 1\")\nIf name <> \"\" Then Print \"Welcome, \" & name", 7747)

	# =========================================================================
	# FILE I/O
	# =========================================================================
	_add("Open",
		"Open filename For mode As #fileNumber",
		"Opens a file for reading, writing, or appending. Modes: Input, Output, Append, Binary, Random.",
		"' Read a file\nOpen \"scores.txt\" For Input As #1\nLine Input #1, firstLine\nClose #1\n\n' Write a file\nOpen \"log.txt\" For Output As #2\nPrint #2, \"Game started\"\nClose #2", 9260)

	_add("Close",
		"Close [#fileNumber [, #fileNumber ...]]",
		"Closes one or more open files. Always close files when done to flush data to disk.",
		"Open \"data.txt\" For Input As #1\n' ... read data ...\nClose #1\n\nClose  ' Close all open files", 5524)

	_add("Line Input",
		"Line Input #fileNumber, variableName",
		"Reads an entire line of text from a file (up to the newline character).",
		"Open \"names.txt\" For Input As #1\nDo While Not EOF(1)\n    Line Input #1, currentLine\n    Print currentLine\nLoop\nClose #1", 8533)

	# =========================================================================
	# DATA STATEMENTS
	# =========================================================================
	_add("Data",
		"Data value1, value2, value3, ...\nData \"string\", 42, 3.14",
		"Stores inline data values that can be read sequentially with Read. Supports strings, numbers, and empty slots (consecutive commas).",
		"Data \"Sword\", 10, 50\nData \"Shield\", 5, 30\nData \"Potion\", 0, 15\n\nDim itemName As String, atk As Integer, cost As Integer\nRead itemName, atk, cost", 6141)

	_add("Read",
		"Read variable1 [, variable2, ...]\nRead variable As Type",
		"Reads the next value(s) from the Data tape into variables. Supports typed Read for automatic conversion.",
		"Data 100, 200, 300\n\nDim x As Integer, y As Integer, z As Integer\nRead x, y, z\nPrint x  ' 100\n\n' Typed read\nRead score As Integer", 10336)

	_add("Restore",
		"Restore [labelName]",
		"Resets the Data read pointer to the beginning, or to a named data section.",
		"Data \"First\", 1\ndata_section2:\nData \"Second\", 2\n\nRead a, b\nRestore data_section2\nRead c, d  ' Reads \"Second\", 2", 10468)

	# =========================================================================
	# STRING FUNCTIONS
	# =========================================================================
	_add("Len",
		"Len(string)",
		"Returns the number of characters in a string.",
		"Dim s As String = \"Hello\"\nPrint Len(s)  ' 5", 8453)

	_add("Left",
		"Left(string, length)",
		"Returns the specified number of characters from the beginning of a string.",
		"Print Left(\"Hello World\", 5)  ' \"Hello\"", 8428)

	_add("Right",
		"Right(string, length)",
		"Returns the specified number of characters from the end of a string.",
		"Print Right(\"Hello World\", 5)  ' \"World\"", 10556)

	_add("Mid",
		"Mid(string, start [, length])",
		"Returns a substring starting at position start (1-based). If length is omitted, returns the rest of the string.",
		"Print Mid(\"Hello World\", 7)     ' \"World\"\nPrint Mid(\"Hello World\", 1, 5)  ' \"Hello\"", 8805)

	_add("InStr",
		"InStr([start,] string, search)",
		"Returns the position of the first occurrence of search within string (1-based). Returns 0 if not found.",
		"Dim pos As Integer\npos = InStr(\"Hello World\", \"World\")  ' 7\npos = InStr(\"Hello\", \"xyz\")  ' 0", 7799)

	_add("UCase",
		"UCase(string)",
		"Converts a string to uppercase.",
		"Print UCase(\"hello\")  ' \"HELLO\"", 12655)

	_add("LCase",
		"LCase(string)",
		"Converts a string to lowercase.",
		"Print LCase(\"HELLO\")  ' \"hello\"", 8404)

	_add("Trim",
		"Trim(string)",
		"Removes leading and trailing spaces from a string.",
		"Print Trim(\"  Hello  \")  ' \"Hello\"", 12514)

	_add("Replace",
		"Replace(string, find, replaceWith)",
		"Returns a string with all occurrences of find replaced by replaceWith.",
		"Dim s As String = Replace(\"Hello World\", \"World\", \"VB\")\nPrint s  ' \"Hello VB\"", 10418)

	_add("Split",
		"Split(string, delimiter)",
		"Splits a string into an array of substrings based on a delimiter.",
		"Dim parts() As String\nparts = Split(\"A,B,C\", \",\")\nPrint parts(0)  ' \"A\"\nPrint parts(1)  ' \"B\"", 11885)

	_add("StringFormat",
		"StringFormat(format, arg0[, arg1, ...])",
		"Replaces {0}, {1}, ... placeholders in format with the given arguments.",
		"Dim s As String = StringFormat(\"{0} is {1} years old\", \"Alice\", 30)\nPrint s  ' \"Alice is 30 years old\"")

	_add("Join",
		"Join(array, delimiter)",
		"Joins an array of strings into a single string with a delimiter between each element.",
		"Dim arr As Variant\narr = [\"Red\", \"Green\", \"Blue\"]\nPrint Join(arr, \", \")  ' \"Red, Green, Blue\"", 8093)

	_add("Format",
		"Format(expression, formatString)",
		"Formats a number, date, or string according to the format pattern.",
		"Print Format(1234.5, \"#,##0.00\")  ' \"1,234.50\"\nPrint Format(0.75, \"0%\")          ' \"75%\"", 7129)

	_add("Val",
		"Val(string)",
		"Converts the numeric portion of a string to a number.",
		"Dim n As Integer = Val(\"42 cats\")  ' 42\nDim d As Double = Val(\"3.14\")      ' 3.14", 12768)

	_add("Str",
		"Str(number)",
		"Converts a number to its string representation.",
		"Dim s As String = Str(42)  ' \" 42\" (note leading space)\nPrint \"Score: \" & Str(score)", 12026)

	_add("CStr",
		"CStr(expression)",
		"Explicitly converts any expression to a String.",
		"Dim s As String = CStr(42)    ' \"42\"\nDim t As String = CStr(True)  ' \"True\"", 6088)

	_add("CInt",
		"CInt(expression)",
		"Converts an expression to an Integer, rounding if necessary.",
		"Dim n As Integer = CInt(3.7)   ' 4\nDim m As Integer = CInt(\"42\")  ' 42", 5441)

	# =========================================================================
	# MATH FUNCTIONS
	# =========================================================================
	_add("Abs",
		"Abs(number)",
		"Returns the absolute value of a number.",
		"Print Abs(-5)    ' 5\nPrint Abs(3.14)  ' 3.14", 4138)

	_add("Int",
		"Int(number)",
		"Returns the integer portion of a number (truncates toward negative infinity).",
		"Print Int(3.7)   ' 3\nPrint Int(-3.7)  ' -4", 7827)

	_add("Round",
		"Round(number [, decimals])",
		"Rounds a number to the specified number of decimal places.",
		"Print Round(3.14159, 2)  ' 3.14\nPrint Round(2.5)         ' 2 (banker's rounding)", 10607)

	_add("Rnd",
		"Rnd([upperBound])",
		"Returns a random floating-point number between 0 and 1 (or 0 and upperBound if specified).",
		"Randomize\nDim r As Single = Rnd()      ' 0.0 to 1.0\nDim d As Integer = Int(Rnd(6)) + 1  ' Dice roll 1-6", 10581)

	_add("Randomize",
		"Randomize [seed]",
		"Seeds the random number generator. Call once at program start for unpredictable sequences.",
		"Randomize\nPrint Rnd()  ' Different each run\n\nRandomize 42  ' Reproducible sequence", 10053)

	_add("RandRange",
		"RandRange(min, max)",
		"Returns a random number between min and max (inclusive).",
		"Dim damage As Integer = RandRange(5, 20)\nDim x As Single = RandRange(0.0, 1.0)", 10080)

	_add("Lerp",
		"Lerp(a, b, t)",
		"Linearly interpolates between a and b by factor t (0.0 to 1.0).",
		"' Smooth camera follow\ncameraX = Lerp(cameraX, playerX, 0.1)\n\n' Fade color\nalpha = Lerp(0.0, 1.0, fadeProgress)", 8478)

	_add("Clamp",
		"Clamp(value, min, max)",
		"Constrains a value to the range [min, max].",
		"health = Clamp(health, 0, maxHealth)\nspeed = Clamp(speed, 0.0, maxSpeed)", 5466)

	_add("Sqr",
		"Sqr(number)",
		"Returns the square root of a number.",
		"Print Sqr(16)   ' 4\nPrint Sqr(2.0)  ' 1.41421...", 11913)

	_add("Sin",
		"Sin(angle)",
		"Returns the sine of an angle (in radians).",
		"Dim y As Single = Sin(3.14159 / 2)  ' 1.0\n' Oscillating motion\ny = Sin(time * 2.0) * amplitude", 11277)

	_add("Cos",
		"Cos(angle)",
		"Returns the cosine of an angle (in radians).",
		"Dim x As Single = Cos(0)  ' 1.0\n' Circular motion\nx = Cos(angle) * radius", 5719)

	# =========================================================================
	# PASS 1 — MATH BUILT-IN TYPES (Quaternion, Basis, Transform, Plane, AABB)
	# =========================================================================
	_add("Quaternion",
		"Quaternion() | Quaternion(x, y, z, w)",
		"Creates a Quaternion — 3D rotation as four numbers. Identity rotation by default. Use Slerp to blend two rotations smoothly. Multiply two Quaternions to combine rotations.",
		"Dim qIdentity = Quaternion()\nDim q = Quaternion(0, 0, 0, 1)  ' identity in (x,y,z,w)\n\n' Rotate halfway between two orientations\nDim qHalf = Slerp(qStart, qEnd, 0.5)", 9893)

	_add("QuaternionFromEuler",
		"QuaternionFromEuler(xRad, yRad, zRad)",
		"Builds a Quaternion from Euler angles (pitch, yaw, roll) in radians. Easier than constructing the four components directly.",
		"' 90-degree yaw (turn right)\nDim qTurn = QuaternionFromEuler(0, 1.5707963, 0)\nplayer.quaternion = qTurn", 9917)

	_add("Basis",
		"Basis() | Basis(quaternion)",
		"Creates a 3x3 rotation/scale matrix used inside Transform3D. Pass a Quaternion to build a rotation-only Basis. Methods like .Scaled(v), .Rotated(axis, angle), .Inverse(), .Orthonormalized() are available on the result.",
		"Dim b = Basis(QuaternionFromEuler(0, 0.5, 0))\nDim b2 = b.Scaled(Vector3(2, 2, 2))", 4553)

	_add("Transform2D",
		"Transform2D() | Transform2D(rotationRad, origin) | Transform2D(rotation, scale, skew, origin)",
		"2D transform (rotation + scale + skew + position). Defaults to identity. Useful for positioning Node2D children procedurally. Methods .Translated(v), .Rotated(rad), .Scaled(v), .AffineInverse() return new Transform2Ds.",
		"Dim t = Transform2D(0.785, Vector2(100, 50))  ' 45 deg, at (100,50)\nDim t2 = t.Translated(Vector2(10, 0)).Rotated(0.1)", 12472)

	_add("Transform3D",
		"Transform3D() | Transform3D(basis, origin)",
		"3D transform combining a Basis (rotation+scale) with an origin Vector3. Used for positioning Node3Ds. .LookingAt(target, up) is the easy way to face a point.",
		"Dim tr = Transform3D(Basis(), Vector3(0, 2, 5))\ncam.transform = tr.LookingAt(player.position, Vector3(0, 1, 0))", 12493)

	_add("Plane",
		"Plane() | Plane(normalVec3) | Plane(normalVec3, d) | Plane(a, b, c, d)",
		"Infinite plane defined by a normal vector and signed distance from origin. Used for clipping, side-of-plane tests, and raycast results. Methods include .IsPointOver(p), .DistanceTo(p), .Intersect3(plane2, plane3).",
		"Dim floor = Plane(Vector3(0, 1, 0), 0)  ' ground plane (y=0)\nIf floor.IsPointOver(actor.position) Then\n    Print \"actor is above the floor\"\nEnd If", 9656)

	_add("AABB",
		"AABB() | AABB(positionVec3, sizeVec3)",
		"Axis-aligned bounding box in 3D. Used for visibility culling, region tests. Methods: .HasPoint(p), .Intersects(other), .GetCenter(), .Grow(by), .Encloses(other), .GetVolume().",
		"Dim region = AABB(Vector3(-5, 0, -5), Vector3(10, 4, 10))\nIf region.HasPoint(enemy.position) Then\n    enemy.Aggro()\nEnd If", 4115)

	_add("NewRNG",
		"NewRNG([seed])",
		"Creates a per-stream RandomNumberGenerator. Unlike global Rnd(), each NewRNG has its own seed for reproducible sequences. Access via .Randf(), .RandiRange(lo, hi), .RandfRange(lo, hi), .Randfn(mean, deviation).",
		"Dim rng = NewRNG(42)            ' fixed seed\nDim damage = rng.RandiRange(5, 10)\nDim spread = rng.Randfn(0, 0.2)  ' normal distribution", 9120)

	_add("NewNoise",
		"NewNoise([seed])",
		"Creates a FastNoiseLite generator for procedural content (terrain heightmaps, cloud patterns, perlin/simplex noise). Set .Seed, .Frequency, .NoiseType. Sample with .GetNoise2D(x, y), .GetNoise3D(x, y, z) — returns -1..1.",
		"Dim n = NewNoise(1337)\nn.Frequency = 0.05\nFor x = 0 To 99\n    For y = 0 To 99\n        Dim h = (n.GetNoise2D(x, y) + 1) * 0.5  ' 0..1\n        heightmap(x, y) = h * 64\n    Next\nNext", 9089)

	_add("NewCurve",
		"NewCurve()",
		"Creates an editable Curve resource for animation/easing. Use .AddPoint(Vector2(x, y)) to add control points then .Sample(t) — where t is 0..1 — to read the interpolated value. Great for designer-tunable shapes (jump arc, damage falloff).",
		"Dim arc = NewCurve()\narc.AddPoint(Vector2(0, 0))\narc.AddPoint(Vector2(0.5, 1.0))\narc.AddPoint(Vector2(1.0, 0))\nDim height = arc.Sample(t) * jumpMax", 9065)

	# =========================================================================
	# PASS 1 — GLOBAL MATH VERBS
	# =========================================================================
	_add("Slerp",
		"Slerp(a, b, t)",
		"Spherical interpolation. Smoothly blends between two Quaternions, Vector3s, or Vector2s by factor t (0..1). Like Lerp but preserves length/rotation rate — use for camera orbits, rotation interpolation, smooth aim.",
		"' Rotate halfway from current to target\nplayer.quaternion = Slerp(player.quaternion, targetRot, 0.1)\n\n' Smooth aim direction\naim = Slerp(aim, desiredAim, 0.2)", 11403)

	_add("ColorFromHSV",
		"ColorFromHSV(h, s, v [, a])",
		"Builds a Color from Hue/Saturation/Value (each 0..1). Use when you want rainbow effects, palette cycling, or to tint by hue without RGB math.",
		"' Animate the rainbow\nFor i = 0 To 60\n    Dim c = ColorFromHSV(i / 60.0, 0.8, 1.0)\n    DrawRect i * 10, 0, 10, 100, c\nNext", 5581)

	_add("ColorToHSV",
		"ColorToHSV(color)",
		"Splits a Color into its Hue, Saturation, Value, Alpha components. Returns a Dictionary with keys h, s, v, a (each 0..1).",
		"Dim parts = ColorToHSV(Color.Red)\nPrint parts.h  ' 0.0  (red is hue 0)\nPrint parts.s  ' 1.0", 5612)

	_add("Lighten",
		"Lighten(color, amount)",
		"Returns a lighter shade of the color. Amount is 0..1 (0=unchanged, 1=white).",
		"buttonHover = Lighten(buttonNormal, 0.2)", 8508)

	_add("Darken",
		"Darken(color, amount)",
		"Returns a darker shade of the color. Amount is 0..1 (0=unchanged, 1=black).",
		"shadow = Darken(skinColor, 0.4)", 6116)

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
		"' Snap to player every frame\nSub _Process(delta)\n    Camera.Position(player.Position)\nEnd Sub", 5112)

	_add("Camera.Zoom",
		"Camera.Zoom(zoom [, h])",
		"Sets Camera2D zoom level. Pass a Vector2 for non-uniform zoom, or a scalar for uniform. Bigger numbers = closer in. (Camera3D uses FOV instead — see Camera.FOV.)",
		"Camera.Zoom Vector2(2, 2)       ' 2x zoom in\nCamera.Zoom 0.5                  ' zoom out to half", 5195)

	_add("Camera.Limits",
		"Camera.Limits(left, top, right, bottom [, h])",
		"Sets Camera2D pan limits in pixels. The camera will refuse to scroll past these edges — perfect for keeping the view inside your level.",
		"' Lock view to a 1920x1080 level\nCamera.Limits 0, 0, 1920, 1080", 5030)

	_add("Camera.FOV",
		"Camera.FOV(degrees [, h])",
		"Sets Camera3D field of view in degrees. 75 is the default. Smaller = telephoto/zoomed; larger = wide-angle.",
		"Camera.FOV 90    ' wide cinematic\nCamera.FOV 45    ' sniper scope", 5004)

	_add("Camera.MakeCurrent",
		"Camera.MakeCurrent([h])",
		"Makes a camera the active one — useful when you have multiple cameras (e.g., gameplay vs cutscene) and want to switch which one renders.",
		"Camera.MakeCurrent cutsceneCam\n' ... play cutscene ...\nCamera.MakeCurrent gameplayCam", 5059)

	_add("Camera.Rotation",
		"Camera.Rotation(angle [, h])",
		"Rotates the camera. For Camera2D pass a number in radians; for Camera3D pass a Vector3 of Euler angles in radians.",
		"' Quick screen tilt (Camera2D)\nCamera.Rotation 0.1   ' ~6 degrees", 5142)

	_add("Camera.Follow",
		"Camera.Follow(target [, h])",
		"Continuously follow a target node. Internally adds a RemoteTransform that mirrors target.Position to the camera every frame — zero per-frame code on your side. Pass Nothing to stop following. Camera.Position(...) called inside Sub _Process() takes precedence for the frame it runs.",
		"Sub _Ready()\n    Camera.Follow player    ' auto-track player forever\nEnd Sub\n\nSub OnPlayerDied()\n    Camera.Follow Nothing   ' stop following\nEnd Sub", 4973)

	_add("Camera.Shake",
		"Camera.Shake(intensity, duration [, h])",
		"Quick screen shake. Intensity is offset in pixels (2D) or units (3D). Duration is seconds. Camera settles back to its original offset when done.",
		"' Boom!\nCamera.Shake 12, 0.4", 5168)

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
		"' Fire and forget\nSound.Play \"res://blast.wav\"\n\n' Keep a handle to control it later\nDim music = Sound.Play(\"res://song.ogg\", \"Music\")\nSound.Volume 60, music", 11508)

	_add("Sound.Stop",
		"Sound.Stop(h)",
		"Stops a sound that was started with Sound.Play and frees it.",
		"Sound.Stop music", 11612)

	_add("Sound.Pause",
		"Sound.Pause(h)",
		"Pauses a sound without stopping it. Resume with Sound.Resume(h).",
		"Sound.Pause music", 11459)

	_add("Sound.Resume",
		"Sound.Resume(h)",
		"Resumes a paused sound from where it left off.",
		"Sound.Resume music", 11563)

	_add("Sound.Seek",
		"Sound.Seek(h, seconds)",
		"Jumps to a position (in seconds) inside a playing sound. Useful for skipping intros or implementing scrub bars.",
		"Sound.Seek music, 30.0   ' jump to 30 seconds in", 11587)

	_add("Sound.Volume",
		"Sound.Volume(pct [, h])",
		"Sets volume in percent (0..100). With a handle, changes that one sound. Without a handle, sets the master speaker volume — the global volume knob.",
		"Sound.Volume 75           ' master at 75%\nSound.Volume 50, music    ' just this song at 50%", 11636)

	_add("Sound.Pitch",
		"Sound.Pitch(scale, h)",
		"Changes playback speed/pitch of a sound. 1.0 = normal, 2.0 = double speed (one octave up), 0.5 = half speed (one octave down).",
		"Sound.Pitch 1.2, music   ' slightly faster/higher", 11483)

	_add("Sound.IsPlaying",
		"Sound.IsPlaying(h) As Boolean",
		"Returns True if the sound is currently playing.",
		"If Not Sound.IsPlaying(music) Then\n    music = Sound.Play(\"res://song.ogg\")\nEnd If", 11433)

	_add("Sound.Position",
		"Sound.Position(h) As Double",
		"Returns the current playback position in seconds.",
		"Dim t = Sound.Position(music)\nPrint \"At \" & Round(t, 1) & \" seconds\"", 11538)

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
		"' Build a music slider\nSpeaker.Volume \"Music\", musicSlider.Value\n\n' Read current\nlbl.Text = \"Music: \" & Round(Speaker.Volume(\"Music\")) & \"%\"", 11831)

	_add("Speaker.Mute",
		"Speaker.Mute(name, muted)",
		"Mutes or unmutes a speaker. Pass True to mute, False to unmute.",
		"Speaker.Mute \"Music\", True     ' silence music\nSpeaker.Mute \"Music\", False    ' unmute", 11756)

	_add("Speaker.IsMuted",
		"Speaker.IsMuted(name) As Boolean",
		"Returns True if the named speaker is currently muted.",
		"If Speaker.IsMuted(\"Master\") Then\n    Print \"Audio is off\"\nEnd If", 11730)

	_add("Speaker.Solo",
		"Speaker.Solo(name, soloed)",
		"Solos a speaker so only it is audible (others silent). Pass False to unsolo.",
		"Speaker.Solo \"SFX\", True   ' only sound effects audible", 11806)

	_add("Speaker.Exists",
		"Speaker.Exists(name) As Boolean",
		"Returns True if a speaker with this name exists in Project Settings → Audio → Buses.",
		"If Speaker.Exists(\"Music\") Then\n    Speaker.Volume \"Music\", 50\nEnd If", 11704)

	_add("Speaker.Count",
		"Speaker.Count() As Integer",
		"Returns the number of configured speakers/buses.",
		"For i = 0 To Speaker.Count() - 1\n    Print Speaker.Name(i)\nNext", 11682)

	_add("Speaker.Name",
		"Speaker.Name(index) As String",
		"Returns the name of the speaker at the given index (0-based).",
		"Print Speaker.Name(0)   ' usually \"Master\"", 11782)

	# =========================================================================
	# PASS 2.5 — SOUNDGEN NAMESPACE
	#
	# Real-time PCM synthesis via Godot's AudioStreamGenerator.
	# SoundGen.Open creates an AudioStreamPlayer with an AudioStreamGenerator
	# stream attached, starts playback, and returns a handle (Long/ObjectID).
	# Call SoundGen.Available(h) each _Process() to get available buffer space,
	# then push exactly that many frames with SoundGen.PushMono or PushStereo.
	# Always call SoundGen.Close(h) when done (era exit, scene change).
	#
	# Typical pattern:
	#   Dim hum As Long
	#   Sub _Ready()
	#       hum = SoundGen.Open(44100.0, 0.1)
	#   End Sub
	#   Sub _Process(delta)
	#       Dim n As Integer = SoundGen.Available(hum)
	#       For i = 0 To n - 1
	#           phase += f / 44100.0 * 6.28318
	#           SoundGen.PushMono hum, Sin(phase) * 0.1
	#       Next
	#   End Sub
	#   Sub _ExitTree()
	#       SoundGen.Close hum
	#   End Sub
	# =========================================================================
	_add("SoundGen.Open",
		"SoundGen.Open(mix_rate As Single, buffer_length As Single) As Long",
		"Creates an AudioStreamGenerator player and starts playback. Returns a handle used by all other SoundGen verbs.\n\nmix_rate: samples per second (typically 44100.0)\nbuffer_length: ring-buffer size in seconds (0.05–0.2 recommended).\n\nThe player is added as a child of the current node and plays silently until frames are pushed.",
		"Dim hum As Long = SoundGen.Open(44100.0, 0.1)", 11850)

	_add("SoundGen.Close",
		"SoundGen.Close(h As Long)",
		"Stops and frees the AudioStreamPlayer created by SoundGen.Open. Call this when the sound is no longer needed (e.g. in _ExitTree or when the era ends).",
		"SoundGen.Close hum", 11820)

	_add("SoundGen.Available",
		"SoundGen.Available(h As Long) As Integer",
		"Returns the number of stereo frames the playback buffer can accept right now. Call once per _Process() and push exactly this many frames to keep the buffer full without blocking.",
		"Dim n As Integer = SoundGen.Available(hum)\nFor i = 0 To n - 1\n    SoundGen.PushMono hum, Sin(phase) * 0.05\n    phase += freq / 44100.0 * 6.28318\nNext", 11838)

	_add("SoundGen.PushMono",
		"SoundGen.PushMono(h As Long, sample As Single)",
		"Pushes one mono PCM sample into the playback buffer. The sample is broadcast to both L and R channels. Values outside ±1.0 will clip.\n\nCall inside a For loop after SoundGen.Available(h) to fill the buffer each frame.",
		"' Sine wave hum\nphase += 440.0 / 44100.0 * 6.28318\nSoundGen.PushMono hum, Sin(phase) * 0.12", 11862)

	_add("SoundGen.PushStereo",
		"SoundGen.PushStereo(h As Long, left As Single, right As Single)",
		"Pushes one stereo PCM frame into the playback buffer. Use when L and R channels differ (e.g. panning effects). Values outside ±1.0 will clip.",
		"SoundGen.PushStereo hum, leftSample, rightSample", 11870)

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
		"Animation.Play playerAnim, \"walk\"\nAnimation.Play playerAnim, \"sprint\", 1.5", 4345)

	_add("Animation.Stop",
		"Animation.Stop(player [, keepState])",
		"Stops the current animation. Pass True for keepState to leave the animated properties at their current values (don't reset).",
		"Animation.Stop playerAnim", 4447)

	_add("Animation.Pause",
		"Animation.Pause(player)",
		"Pauses the current animation without resetting it. Resume with Animation.Resume.",
		"Animation.Pause playerAnim", 4321)

	_add("Animation.Resume",
		"Animation.Resume(player)",
		"Resumes a paused animation from its current position.",
		"Animation.Resume playerAnim", 4372)

	_add("Animation.Seek",
		"Animation.Seek(player, seconds [, update])",
		"Jumps to a specific time in the current animation. update=True applies the change immediately.",
		"Animation.Seek playerAnim, 1.5", 4396)

	_add("Animation.Speed",
		"Animation.Speed(player, scale)",
		"Sets playback speed for all animations on this player. 1.0 = normal, 0.5 = slow-mo, 2.0 = fast.",
		"Animation.Speed playerAnim, 0.5   ' slow motion", 4422)

	_add("Animation.Current",
		"Animation.Current(player) As String",
		"Returns the name of the currently playing animation, or empty string if none.",
		"If Animation.Current(playerAnim) = \"die\" Then\n    GameOver()\nEnd If", 4216)

	_add("Animation.IsPlaying",
		"Animation.IsPlaying(player) As Boolean",
		"Returns True if the player is currently playing an animation.",
		"If Not Animation.IsPlaying(playerAnim) Then\n    Animation.Play playerAnim, \"idle\"\nEnd If", 4242)

	_add("Animation.Length",
		"Animation.Length(player [, name]) As Double",
		"Returns the length in seconds of an animation. With no name, returns the current animation's length.",
		"Dim total = Animation.Length(playerAnim, \"walk\")\nPrint \"Walk is \" & total & \"s long\"", 4268)

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
		"Dim hit = Physics.Ray(player.Position, mouse.Position)\nIf hit.Hit Then\n    Print \"Hit \" & hit.Collider.Name & \" at \" & hit.Distance & \" px\"\nEnd If", 9602)

	_add("Physics.Impulse",
		"Physics.Impulse(body, vec [, pos])",
		"Applies an instant impulse (one-frame push) to a RigidBody. Optional pos is the offset from body center where the force is applied. Alias: Push.",
		"Physics.Impulse ball, Vector2(500, -200)   ' kick the ball", 9576)

	_add("Physics.Force",
		"Physics.Force(body, vec [, pos])",
		"Applies a continuous force to a RigidBody (call every frame for sustained push). Alias: Pull.",
		"Sub _PhysicsProcess(delta)\n    Physics.Force rocket, Vector2(0, -800)   ' constant thrust\nEnd Sub", 9472)

	_add("Physics.Torque",
		"Physics.Torque(body, amount)",
		"Applies a rotational impulse to a RigidBody. For 2D pass a number, for 3D pass a Vector3. Alias: Spin.",
		"Physics.Torque wheel, 50", 9631)

	_add("Push",
		"Push(body, vec [, pos])",
		"Instant impulse — kicks a RigidBody once. Plain-English alias for Physics.Impulse.",
		"Push enemy, Vector2(-300, 0)", 9864)

	_add("Pull",
		"Pull(body, vec [, pos])",
		"Continuous force — call each frame to keep applying. Plain-English alias for Physics.Force.",
		"Pull magnet, towardPlayer * 800", 9838)

	_add("Spin",
		"Spin(body, amount)",
		"Rotational impulse. Plain-English alias for Physics.Torque.",
		"Spin coin, 12.5", 11860)

	# =========================================================================
	# PASS 3 — RAY NAMESPACE (placed RayCast2D/3D nodes)
	#
	# Use these when you have a RayCast2D/3D node in your scene that updates
	# every frame. For one-off casts, use Physics.Ray instead.
	# =========================================================================
	_add("Ray.Hit",
		"Ray.Hit(rayNode) As Boolean",
		"Returns True if the RayCast2D/3D node is currently colliding with something.",
		"If Ray.Hit(groundRay) Then\n    Print \"On the ground\"\nEnd If", 10236)

	_add("Ray.Collider",
		"Ray.Collider(rayNode) As Object",
		"Returns the node the ray is currently hitting, or Nothing if no hit.",
		"If Ray.Hit(aimRay) Then\n    target = Ray.Collider(aimRay)\nEnd If", 10159)

	_add("Ray.Point",
		"Ray.Point(rayNode) As Vector",
		"Returns the world-space hit point of the ray, or Vector.Zero if no hit.",
		"DrawCircle Ray.Point(aimRay), 5, Color.Red", 10287)

	_add("Ray.Normal",
		"Ray.Normal(rayNode) As Vector",
		"Returns the surface normal at the hit point — useful for bouncing or aligning to surfaces.",
		"' Bounce projectile\nvelocity = velocity.Bounce(Ray.Normal(hitRay))", 10262)

	_add("Ray.Enable",
		"Ray.Enable(rayNode, on)",
		"Enables or disables a RayCast node. Disabled rays don't query the physics world.",
		"Ray.Enable scanner, True", 10185)

	_add("Ray.Target",
		"Ray.Target(rayNode, pos)",
		"Sets the ray's target_position (relative to the ray's own position). Use to redirect the ray.",
		"Ray.Target aimRay, mousePos - aimRay.Position", 10311)

	_add("Ray.ForceUpdate",
		"Ray.ForceUpdate(rayNode)",
		"Forces an immediate raycast update (don't wait for next physics frame). Useful right after moving the ray.",
		"Ray.Target groundRay, Vector2(0, 50)\nRay.ForceUpdate groundRay\nIf Ray.Hit(groundRay) Then Print \"floor below\"", 10210)

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
		"Dim c = Cell.Get(world, 5, 10)\nIf c.Source >= 0 Then\n    Print \"Tile from source \" & c.Source\nEnd If", 5327)

	_add("Cell.Set",
		"Cell.Set(layer, x, y, source, atlasX, atlasY [, alt])",
		"Writes a tile at cell coords (x, y). source = -1 erases. atlasX/Y picks the tile within the source's atlas.",
		"' Place a grass tile from source 0, atlas (3, 1)\nCell.Set world, 5, 10, 0, 3, 1", 5356)

	_add("Cell.Clear",
		"Cell.Clear(layer, x, y)",
		"Erases a single tile. Shortcut for Cell.Set with source = -1.",
		"Cell.Clear world, 5, 10", 5277)

	_add("Cell.ClearAll",
		"Cell.ClearAll(layer)",
		"Erases all tiles in a TileMapLayer.",
		"Cell.ClearAll world", 5303)

	_add("Cell.Used",
		"Cell.Used(layer) As Array",
		"Returns an Array of Vector2 cell coordinates that contain a tile (non-empty).",
		"Dim cells = Cell.Used(world)\nFor Each c In cells\n    Print c.x & \",\" & c.y\nNext", 5387)

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
		"Nav.SetTarget enemyNav, player.Position", 9016)

	_add("Nav.NextPos",
		"Nav.NextPos(agent) As Vector",
		"Returns the next step along the path. Call inside _PhysicsProcess to drive movement toward this point.",
		"Sub _PhysicsProcess(delta)\n    Dim nextStep As Vector2\n    nextStep = Nav.NextPos(enemyNav)\n    velocity = nextStep - Position\n    MoveAndSlide Me\nEnd Sub", 8938)

	_add("Nav.Distance",
		"Nav.Distance(agent) As Double",
		"Returns the remaining distance to the target along the path.",
		"If Nav.Distance(enemyNav) < 50 Then Attack()", 8914)

	_add("Nav.Reached",
		"Nav.Reached(agent) As Boolean",
		"Returns True if the agent has finished navigating (arrived at target or path is invalid).",
		"If Nav.Reached(enemyNav) Then PickNewTarget()", 8992)

	_add("Nav.Path",
		"Nav.Path(agent) As Array",
		"Returns the full computed path as an Array of Vector positions.",
		"For Each pt In Nav.Path(enemyNav)\n    DrawCircle pt, 3, Color.Yellow\nNext", 8966)

	# =========================================================================
	# PASS 4 — SCREEN NAMESPACE (display / window)
	#
	# Wraps Godot's DisplayServer. Reads pixel size, DPI, orientation, and
	# lets you control fullscreen + keep-awake. Property-style calls use
	# parens: Screen.Width(), Screen.DPI().
	# =========================================================================
	_add("Screen.Width",
		"Screen.Width() As Long",
		"Returns the screen width in pixels.",
		"If Screen.Width() < 600 Then SetMobileUI()", 10796)

	_add("Screen.Height",
		"Screen.Height() As Long",
		"Returns the screen height in pixels.",
		"Print Screen.Width() & \"x\" & Screen.Height()", 10710)

	_add("Screen.DPI",
		"Screen.DPI() As Long",
		"Returns the screen DPI (dots per inch). Useful for sizing UI on high-density displays.",
		"Dim scale = Screen.DPI() / 96.0   ' 1.0 on standard displays", 10666)

	_add("Screen.Orientation",
		"Screen.Orientation() As String",
		"Returns \"portrait\" or \"landscape\".",
		"If Screen.Orientation() = \"portrait\" Then\n    UseVerticalLayout()\nEnd If", 10774)

	_add("Screen.KeepOn",
		"Screen.KeepOn(on)",
		"Prevents the screen from auto-sleeping while True. Critical for games and video apps.",
		"Screen.KeepOn True", 10750)

	_add("Screen.FullScreen",
		"Screen.FullScreen(on)",
		"Toggles fullscreen mode for the main window.",
		"Screen.FullScreen True", 10686)

	_add("Screen.IsFullScreen",
		"Screen.IsFullScreen() As Boolean",
		"Returns True if the window is currently fullscreen.",
		"If Not Screen.IsFullScreen() Then Screen.FullScreen True", 10730)

	# =========================================================================
	# PASS 4 — JOYPAD NAMESPACE (gamepad polling)
	#
	# Device is the joypad index (0-based). Axis index is 0=LX, 1=LY, 2=RX,
	# 3=RY, 4=LT, 5=RT (Godot JoyAxis enum). Button index is the JoyButton
	# enum: 0=A, 1=B, 2=X, 3=Y, 4=Back, 5=Guide, 6=Start, etc.
	# =========================================================================
	_add("Joypad.Connected",
		"Joypad.Connected(device) As Boolean",
		"Returns True if a joypad is connected at the given device index (0-based).",
		"If Joypad.Connected(0) Then Print \"Player 1 controller ready\"", 8172)

	_add("Joypad.Name",
		"Joypad.Name(device) As String",
		"Returns the joypad's name (e.g. \"Xbox Wireless Controller\"). Empty string if not connected.",
		"Print \"P1: \" & Joypad.Name(0)", 8220)

	_add("Joypad.Axis",
		"Joypad.Axis(device, axisIndex) As Double",
		"Returns the analog axis value (-1.0 to 1.0). Axis 0/1 = left stick, 2/3 = right stick, 4/5 = triggers.",
		"' Move with left stick\nDim mx = Joypad.Axis(0, 0)\nDim my = Joypad.Axis(0, 1)\nposition += Vector2(mx, my) * 200 * delta", 8119)

	_add("Joypad.Button",
		"Joypad.Button(device, buttonIndex) As Boolean",
		"Returns True if the given button is currently held down. 0=A/Cross, 1=B/Circle, 2=X/Square, 3=Y/Triangle, 6=Start.",
		"If Joypad.Button(0, 0) Then Jump()", 8147)

	# =========================================================================
	# PASS 4 — SENSOR NAMESPACE (phone motion sensors)
	#
	# Reads the device's accelerometer / gyroscope / magnetometer / gravity
	# sensors. Works on Android and iOS automatically. On desktop returns
	# zero vectors.
	#
	# By default uses "game" units (Gs, degrees/sec) — more intuitive. Call
	# Sensor.Units "metric" to switch to m/s² and radians/sec.
	# =========================================================================
	_add("Sensor.Units",
		"Sensor.Units(system)",
		"Sets the unit system for subsequent Sensor reads. \"game\" (default) = Gs and degrees/sec. \"metric\" = m/s² and rad/sec.",
		"Sensor.Units \"game\"     ' default, easy mode\nSensor.Units \"metric\"   ' physics-accurate", 11005)

	_add("Sensor.Accel",
		"Sensor.Accel() As Vector3",
		"Returns the accelerometer reading. In game units, ~1.0 G on the Y axis when the phone is upright. Includes gravity.",
		"Dim a = Sensor.Accel()\nIf a.Length() > 2.0 Then Print \"Shake detected!\"", 10881)

	_add("Sensor.Gyro",
		"Sensor.Gyro() As Vector3",
		"Returns the gyroscope reading — angular velocity. In game units = degrees/sec.",
		"Dim g = Sensor.Gyro()\nIf Abs(g.y) > 90 Then Print \"Fast spin!\"", 10923)

	_add("Sensor.Magnet",
		"Sensor.Magnet() As Vector3",
		"Returns the magnetometer reading in µT (microtesla). Useful for compass apps.",
		"Dim m = Sensor.Magnet()\nDim heading = Atan2(m.y, m.x) * 57.2958", 10944)

	_add("Sensor.Gravity",
		"Sensor.Gravity() As Vector3",
		"Returns just the gravity component (low-pass filtered accelerometer). In game units = Gs.",
		"' Use as level reference\nDim down = Sensor.Gravity().Normalized()", 10902)

	_add("Sensor.Tilt",
		"Sensor.Tilt() As Double",
		"Returns device tilt in degrees (rotation around vertical axis). 0 = phone upright, ±90 = phone flat on its side.",
		"player.Velocity.x = Sensor.Tilt() * 10   ' tilt-to-steer", 10985)

	# =========================================================================
	# PASS 4 — PERMISSION NAMESPACE (Android runtime permissions)
	#
	# On Android/iOS, sensitive features require runtime permission. On
	# desktop these always return True. Short names recognised: "camera",
	# "microphone", "location", "storage" (or pass full Android permission
	# string).
	#
	# Future auto-wire: Sub Permission_Granted(name) / Permission_Denied(name)
	# will be called when the user responds to the OS dialog (Pass 4 ships
	# the API; the signal hookup lands with the Android plugin in v5.2).
	# =========================================================================
	_add("Permission.Has",
		"Permission.Has(name) As Boolean",
		"Returns True if the permission is currently granted. On desktop always True.",
		"If Not Permission.Has(\"camera\") Then Permission.Request \"camera\"", 9399)

	_add("Permission.Request",
		"Permission.Request(name)",
		"Prompts the OS to ask the user for a permission. Resolves async — check Permission.Has next frame, or define Sub Permission_Granted(name).",
		"Permission.Request \"location\"", 9423)

	_add("Permission.All",
		"Permission.All() As Array",
		"Returns an Array of all currently-granted permission strings.",
		"For Each p In Permission.All()\n    Print p\nNext", 9377)

	# =========================================================================
	# PASS 4 — VIBRATE (global verb)
	# =========================================================================
	_add("Vibrate",
		"Vibrate ms [, amplitude]",
		"Vibrates the device for the given milliseconds. Amplitude is 0.0–1.0 (default = full). No-op on desktop.",
		"Vibrate 100           ' short buzz\nVibrate 500, 0.3      ' half-second gentle", 12817)

	# =========================================================================
	# PASS 4 — GPS / STEPS (stubs — need platform plugin)
	#
	# These return safe defaults (0 / -1) on every platform today. The
	# namespace + signal names are reserved now so user code written
	# against them will Just Work once the Android/iOS plugins ship.
	# =========================================================================
	_add("GPS.Lat",
		"GPS.Lat() As Double",
		"Returns latitude in decimal degrees. Returns 0 until a platform plugin publishes real values.",
		"Print \"Lat: \" & GPS.Lat()", 7453)

	_add("GPS.Lng",
		"GPS.Lng() As Double",
		"Returns longitude in decimal degrees. Returns 0 until a platform plugin publishes real values.",
		"Print \"Lng: \" & GPS.Lng()", 7473)

	_add("GPS.Alt",
		"GPS.Alt() As Double",
		"Returns altitude in meters above sea level. Stub returns 0.",
		"Print GPS.Alt() & \" m\"", 7433)

	_add("GPS.Accuracy",
		"GPS.Accuracy() As Double",
		"Returns horizontal accuracy in meters. -1 means unknown / no fix yet.",
		"If GPS.Accuracy() > 0 And GPS.Accuracy() < 20 Then UpdateMap()", 7413)

	_add("GPS.Speed",
		"GPS.Speed() As Double",
		"Returns ground speed in m/s. Stub returns 0.",
		"Print (GPS.Speed() * 3.6) & \" km/h\"", 7493)

	_add("Steps.Total",
		"Steps.Total() As Long",
		"Returns total step count since boot (or since plugin install). Stub returns 0.",
		"Print \"Today you walked \" & Steps.Total() & \" steps\"", 12006)

	_add("Steps.Today",
		"Steps.Today() As Long",
		"Returns step count for today (midnight rollover). Stub returns 0.",
		"goalProgress = Steps.Today() / 10000.0", 11986)

	_add("Steps.Reset",
		"Steps.Reset()",
		"Resets the step counter to zero. Plugin-dependent.",
		"Steps.Reset()", 11966)

	# =========================================================================
	# PASS 5 — CRYPTO NAMESPACE (+ global aliases)
	#
	# Hashing, HMAC, base64, and secure random bytes. Every Crypto.* verb
	# has a plain-English global alias (SHA256, MD5, Base64Encode, etc.).
	# Hash output is lowercase hex string.
	# =========================================================================
	_add("Crypto.SHA256",
		"Crypto.SHA256(text_or_bytes) As String",
		"Returns the SHA-256 hash as lowercase hex. Accepts a String (UTF-8) or PackedByteArray. Alias: SHA256.",
		"Dim h = SHA256(\"password\")\nPrint h", 6063)

	_add("Crypto.SHA1",
		"Crypto.SHA1(text_or_bytes) As String",
		"Returns the SHA-1 hash as lowercase hex. Alias: SHA1.",
		"Print SHA1(\"hello\")", 6039)

	_add("Crypto.MD5",
		"Crypto.MD5(text_or_bytes) As String",
		"Returns the MD5 hash as lowercase hex. (MD5 is fast but not secure for passwords — use SHA256.) Alias: MD5.",
		"Print MD5(fileContent)", 5990)

	_add("Crypto.HMAC",
		"Crypto.HMAC(key, msg [, algorithm]) As String",
		"Keyed-hash message auth code. algorithm = \"sha256\" (default), \"sha1\", or \"md5\".",
		"Dim sig = Crypto.HMAC(secretKey, payload, \"sha256\")", 5964)

	_add("Crypto.RandomBytes",
		"Crypto.RandomBytes(n) As PackedByteArray",
		"Returns n cryptographically secure random bytes. Alias: RandomBytes.",
		"Dim token = RandomBytes(32)\nDim hex = Base64Encode(token)", 6014)

	_add("Crypto.Base64Encode",
		"Crypto.Base64Encode(text_or_bytes) As String",
		"Encodes input as Base64. String → UTF-8 → Base64. PackedByteArray → Base64 directly. Alias: Base64Encode.",
		"Print Base64Encode(\"hello world\")  ' aGVsbG8gd29ybGQ=", 5892)

	_add("Crypto.Base64Decode",
		"Crypto.Base64Decode(b64 [, raw]) As String/Bytes",
		"Decodes Base64. By default returns UTF-8 String. Pass True for raw PackedByteArray. Alias: Base64Decode.",
		"Print Base64Decode(\"aGVsbG8=\")  ' hello\nDim bin = Base64Decode(encoded, True)", 5866)

	# =========================================================================
	# PASS 5 — THEME NAMESPACE (Control overrides)
	#
	# Per-control theme overrides. Use to restyle individual nodes without
	# editing the project Theme resource.
	# =========================================================================
	_add("Theme.Color",
		"Theme.Color(control, key) As Color",
		"Reads a theme color override (or falls back to the inherited theme). Common keys: \"font_color\", \"font_disabled_color\".",
		"Print Theme.Color(myLabel, \"font_color\")", 12161)

	_add("Theme.Font",
		"Theme.Font(control, key) As Font",
		"Reads the font assigned to a control for the given key (e.g. \"font\").",
		"Dim f = Theme.Font(myLabel, \"font\")", 12211)

	_add("Theme.Constant",
		"Theme.Constant(control, key) As Long",
		"Reads a theme constant (e.g. \"separation\", \"margin_left\").",
		"Print Theme.Constant(hbox, \"separation\")", 12186)

	_add("Theme.SetColor",
		"Theme.SetColor(control, key, color)",
		"Overrides a theme color on a single control. Persists until the control is freed.",
		"Theme.SetColor warningLabel, \"font_color\", Color.Red", 12290)

	_add("Theme.SetFont",
		"Theme.SetFont(control, key, font)",
		"Overrides the font on a single control. font is a Font resource.",
		"Theme.SetFont titleLabel, \"font\", myCustomFont", 12342)

	_add("Theme.SetConstant",
		"Theme.SetConstant(control, key, value)",
		"Overrides a theme integer constant (margins, spacings, etc.).",
		"Theme.SetConstant hbox, \"separation\", 20", 12316)

	_add("Theme.SetFontSize",
		"Theme.SetFontSize(control, key, size)",
		"Overrides the font size for a control. key is usually \"font_size\".",
		"Theme.SetFontSize titleLabel, \"font_size\", 48", 12368)

	_add("Theme.SetStyle",
		"Theme.SetStyle(control, key, stylebox)",
		"Overrides a theme StyleBox (backgrounds, borders). Pass a StyleBox resource.",
		"Theme.SetStyle myPanel, \"panel\", customStyleBox", 12394)

	# =========================================================================
	# PASS 5 — JS NAMESPACE (HTML5 web export)
	#
	# Calls JavaScript from VG when running in the browser. Returns Nothing
	# on every native platform. Numbers/Strings/Bools cross the boundary
	# automatically; complex JS objects come back as opaque wrappers.
	# =========================================================================
	_add("JS.Eval",
		"JS.Eval(code [, useGlobal]) As Variant",
		"Evaluates a JavaScript expression and returns the result. useGlobal=True runs in the global scope (window).",
		"Dim t = JS.Eval(\"document.title\", True)\nJS.Eval \"alert('hi from VG')\"", 8295)

	_add("JS.Call",
		"JS.Call(funcName, args...) As Variant",
		"Calls a JavaScript function in global scope. String args are quoted automatically.",
		"JS.Call \"console.log\", \"VG says hi\"", 8270)

	_add("JS.Get",
		"JS.Get(path) As Variant",
		"Reads a JavaScript value by path (e.g. \"window.location.href\"). Shortcut for JS.Eval with useGlobal=True.",
		"Print JS.Get(\"navigator.userAgent\")", 8321)

	# =========================================================================
	# PASS 5 — SHADER / MATERIAL NAMESPACES
	#
	# Material.New creates a ShaderMaterial from inline shader code (handy
	# for retro effects, dissolve, glow). Shader.Param/GetParam reads and
	# writes shader uniforms.
	# =========================================================================
	_add("Material.New",
		"Material.New(shader_code) As ShaderMaterial",
		"Compiles a shader from inline GLSL-like code and wraps it in a ShaderMaterial. Assign the result to a node's material property.",
		"Dim m = Material.New(\"shader_type canvas_item;\\nuniform float glow = 0.5;\\nvoid fragment() { COLOR = vec4(glow, 0.0, 0.0, 1.0); }\")\nsprite.Material = m", 8727)

	_add("Material.SetShader",
		"Material.SetShader(material, shader)",
		"Replaces the Shader resource of an existing ShaderMaterial.",
		"Material.SetShader sprite.Material, glowShader", 8754)

	_add("Shader.Param",
		"Shader.Param(material, key, value)",
		"Sets a shader uniform on a ShaderMaterial.",
		"Shader.Param sprite.Material, \"glow\", 1.5", 11203)

	_add("Shader.GetParam",
		"Shader.GetParam(material, key) As Variant",
		"Reads the current value of a shader uniform.",
		"Print Shader.GetParam(sprite.Material, \"glow\")", 11178)

	# =========================================================================
	# PASS 5 — SKELETON / BONE NAMESPACES (Skeleton3D)
	#
	# Read and write bone poses on a Skeleton3D. Bone indices come from
	# Bone.Find by name. Pose values are local to the bone's rest pose.
	# =========================================================================
	_add("Skeleton.Count",
		"Skeleton.Count(skeleton) As Long",
		"Returns the number of bones in the skeleton.",
		"For i = 0 To Skeleton.Count(skel) - 1\n    Print Skeleton.Name(skel, i)\nNext", 11328)

	_add("Skeleton.Name",
		"Skeleton.Name(skeleton, idx) As String",
		"Returns the name of the bone at the given index.",
		"Print Skeleton.Name(skel, 0)", 11354)

	_add("Skeleton.Reset",
		"Skeleton.Reset(skeleton)",
		"Resets all bones back to their rest pose.",
		"Skeleton.Reset character", 11379)

	_add("Bone.Find",
		"Bone.Find(skeleton, name) As Long",
		"Looks up a bone by name. Returns -1 if not found.",
		"Dim head = Bone.Find(skel, \"head\")", 4608)

	_add("Bone.Pos",
		"Bone.Pos(skeleton, idx) As Vector3",
		"Returns the bone's current pose position (relative to its rest).",
		"Print Bone.Pos(skel, head)", 4659)

	_add("Bone.Rot",
		"Bone.Rot(skeleton, idx) As Quaternion",
		"Returns the bone's current pose rotation.",
		"Dim q = Bone.Rot(skel, head)", 4684)

	_add("Bone.Scale",
		"Bone.Scale(skeleton, idx) As Vector3",
		"Returns the bone's current pose scale.",
		"Print Bone.Scale(skel, head)", 4709)

	_add("Bone.SetPos",
		"Bone.SetPos(skeleton, idx, pos)",
		"Sets the bone's pose position.",
		"Bone.SetPos skel, head, Vector3(0, 0.1, 0)", 4734)

	_add("Bone.SetRot",
		"Bone.SetRot(skeleton, idx, quat)",
		"Sets the bone's pose rotation. Use Quaternion(axis, angle) to build one.",
		"Bone.SetRot skel, head, Quaternion(Vector3(0,1,0), Deg2Rad(45))", 4760)

	_add("Bone.SetScale",
		"Bone.SetScale(skeleton, idx, vec)",
		"Sets the bone's pose scale.",
		"Bone.SetScale skel, head, Vector3(1.2, 1.2, 1.2)", 4786)

	_add("Bone.LookAt",
		"Bone.LookAt(skeleton, idx, targetPos)",
		"Rotates the bone so its +Y axis points at targetPos (world space). Simple IK for heads/eyes.",
		"Bone.LookAt skel, headIdx, player.GlobalPosition", 4633)

	# =========================================================================
	# PASS 5 — VIDEO NAMESPACE (VideoStreamPlayer)
	# =========================================================================
	_add("Video.Play",
		"Video.Play(player)",
		"Starts video playback.",
		"Video.Play introVid", 12913)

	_add("Video.Stop",
		"Video.Stop(player)",
		"Stops playback and resets position to 0.",
		"Video.Stop introVid", 13010)

	_add("Video.Pause",
		"Video.Pause(player)",
		"Pauses without resetting position. Resume with Video.Resume.",
		"Video.Pause introVid", 12889)

	_add("Video.Resume",
		"Video.Resume(player)",
		"Resumes a paused video.",
		"Video.Resume introVid", 12961)

	_add("Video.Seek",
		"Video.Seek(player, seconds)",
		"Jumps to a specific time in the video.",
		"Video.Seek introVid, 30", 12985)

	_add("Video.Position",
		"Video.Position(player) As Double",
		"Returns current playback position in seconds.",
		"Print Video.Position(introVid)", 12937)

	_add("Video.Length",
		"Video.Length(player) As Double",
		"Returns video length in seconds. Returns 0 if the stream doesn't report a length.",
		"Print \"Duration: \" & Video.Length(introVid)", 12865)

	_add("Video.IsPlaying",
		"Video.IsPlaying(player) As Boolean",
		"Returns True if the video is currently playing.",
		"If Not Video.IsPlaying(introVid) Then ShowMenu()", 12841)

	_add("Video.Volume",
		"Video.Volume(player, percent)",
		"Sets video audio volume (0-100%). Same percent system as Speaker.Volume.",
		"Video.Volume introVid, 75", 13034)

	# =========================================================================
	# ARRAY FUNCTIONS
	# =========================================================================
	_add("UBound",
		"UBound(arrayName [, dimension])",
		"Returns the highest valid index of an array.",
		"Dim arr(10) As Integer\nPrint UBound(arr)  ' 10\n\nFor i = 0 To UBound(arr)\n    arr(i) = i * 2\nNext", 12625)

	_add("LBound",
		"LBound(arrayName [, dimension])",
		"Returns the lowest valid index of an array (usually 0).",
		"For i = LBound(arr) To UBound(arr)\n    Print arr(i)\nNext", 8377)

	_add("Array",
		"Array(value1, value2, ...)",
		"Creates and returns an array containing the specified values.",
		"Dim colors As Variant = Array(\"Red\", \"Green\", \"Blue\")\nPrint colors(0)  ' \"Red\"", 4472)

	# =========================================================================
	# GAME DEVELOPMENT
	# =========================================================================
	_add("CreateActor2D",
		"CreateActor2D(name, x, y [, texturePath])",
		"Creates a 2D game actor (sprite) at the specified position.",
		"CreateActor2D \"Player\", 100, 200, \"res://player.png\"\nCreateActor2D \"Enemy\", 400, 200", 5745)

	_add("IsKeyPressed",
		"IsKeyPressed(keyName) As Boolean",
		"Returns True if the specified keyboard key is currently held down.",
		"If IsKeyPressed(\"space\") Then\n    Jump()\nEnd If\n\nIf IsKeyPressed(\"left\") Then x = x - speed\nIf IsKeyPressed(\"right\") Then x = x + speed", 8061)

	_add("IsActionPressed",
		"IsActionPressed(actionName) As Boolean",
		"Returns True if the specified input action (defined in Project Settings) is active.",
		"If IsActionPressed(\"ui_accept\") Then\n    SelectMenuItem()\nEnd If", 8035)

	_add("PlaySound",
		"PlaySound(path [, volume] [, pitch])",
		"Plays a sound effect from the specified resource path.",
		"PlaySound \"res://sounds/explosion.wav\"\nPlaySound \"res://sounds/jump.ogg\", 0.8, 1.2", 9679)

	_add("LoadForm",
		"LoadForm formName",
		"Loads and displays a form by name.",
		"LoadForm \"SettingsForm\"\nLoadForm \"HighScores\"", 8563)

	_add("ChangeScene",
		"ChangeScene(scenePath)",
		"Changes the current game scene to the specified .tscn file.",
		"ChangeScene \"res://levels/Level2.tscn\"\n\n' Or using GetTree:\nGetTree().change_scene_to_file(\"res://MainMenu.tscn\")", 5414)

	# =========================================================================
	# ASYNC / PARALLEL
	# =========================================================================
	_add("Async",
		"Async Sub ProcedureName()\nAsync Function FuncName() As Task(Of Type)",
		"Marks a procedure as asynchronous, allowing the use of Await inside it.",
		"Async Sub LoadLevel()\n    Dim data As String = Await ReadFileAsync(\"level.dat\")\n    ParseLevel(data)\nEnd Sub", 4499)

	_add("Await",
		"Await asyncExpression",
		"Pauses execution until an asynchronous operation completes, then returns its result.",
		"Async Sub FetchData()\n    Dim response As String = Await Http.Get(\"https://api.example.com/data\")\n    Print response\nEnd Sub", 4523)

	# =========================================================================
	# MODERN FEATURES
	# =========================================================================
	_add("Lambda",
		"Lambda(params) expression\nLambda(params)\n    statements\nEnd Lambda",
		"Creates an anonymous function (closure) that can be stored in a variable or passed as an argument.",
		"Dim double As Function = Lambda(x) x * 2\nPrint double(5)  ' 10\n\nDim greet As Function = Lambda(name)\n    Print \"Hello, \" & name\nEnd Lambda\ngreet(\"World\")", 8348)

	_add("Whenever",
		"Whenever Section sectionName variableName Changes|Becomes|Exceeds|Below [value] callbackProc[, ...]",
		"Reactive programming — registers a callback Sub when a monitored variable changes. Use Whenever Section at module level (not End Whenever blocks).",
		"Whenever Section WatchHealth health Below 20 OnHealthLow\n\nSub OnHealthLow()\n    lblWarning.Visible = True\n    lblWarning.Caption = \"Low Health!\"\nEnd Sub\n\nWhenever Section ScoreTrack score Changes OnScoreChanged\n\nSub OnScoreChanged()\n    lblScore.Caption = \"Score: \" & score\nEnd Sub", 13084)

	_add("Using",
		"Using resource = expression\n    statements\nEnd Using",
		"Ensures a resource is properly disposed/cleaned up when the block exits.",
		"Using conn = OpenDatabase(\"game.db\")\n    conn.Execute \"INSERT INTO scores VALUES(\" & score & \")\"\nEnd Using  ' Connection automatically closed", 12741)

	_add("DoEvents",
		"DoEvents",
		"Yields control to the engine to process pending events (UI updates, input, etc.). Use sparingly in long-running loops.",
		"For i = 1 To 10000\n    ProcessItem(i)\n    If i Mod 100 = 0 Then DoEvents  ' Keep UI responsive\nNext", 6252)

	# =========================================================================
	# SPECIAL STATEMENTS
	# =========================================================================
	_add("End",
		"End [Sub|Function|If|Select|Class|Type|With|Enum|Try|Using|Whenever]",
		"Terminates a block or ends program execution. When used alone, terminates the application.",
		"End Sub\nEnd Function\nEnd If\nEnd Select\nEnd Class\nEnd  ' Terminate program")

	_add("Option Explicit",
		"Option Explicit",
		"Requires all variables to be declared with Dim before use. Helps catch typos. Place at the top of your module.",
		"Option Explicit\n\nSub Form_Load()\n    Dim score As Integer  ' Required with Option Explicit\n    score = 100\nEnd Sub")

	_add("Nothing",
		"Set obj = Nothing\nIf obj Is Nothing Then ...",
		"Represents a null object reference. Use to release object references or test if an object is unset.",
		"Set player = Nothing\n\nIf currentEnemy Is Nothing Then\n    Print \"No enemy nearby\"\nEnd If")

	_add("True",
		"True",
		"Boolean literal representing a true/on state.",
		"Dim isReady As Boolean = True\nVisible = True")

	_add("False",
		"False",
		"Boolean literal representing a false/off state.",
		"Dim gameOver As Boolean = False\nEnabled = False")

	# =========================================================================
	# LOGICAL OPERATORS
	# =========================================================================
	_add("And",
		"expression1 And expression2",
		"Logical AND — returns True only if both expressions are True.",
		"If health > 0 And ammo > 0 Then\n    Fire()\nEnd If")

	_add("Or",
		"expression1 Or expression2",
		"Logical OR — returns True if either expression is True.",
		"If key = \"escape\" Or key = \"q\" Then\n    QuitGame()\nEnd If")

	_add("Not",
		"Not expression",
		"Logical NOT — inverts a Boolean value.",
		"If Not gameOver Then\n    UpdateGame()\nEnd If\n\nVisible = Not Visible  ' Toggle")

	_add("Xor",
		"expression1 Xor expression2",
		"Logical XOR — returns True if exactly one expression is True.",
		"If a Xor b Then\n    Print \"Exactly one is true\"\nEnd If")

	_add("Mod",
		"number1 Mod number2",
		"Modulo operator — returns the remainder after integer division.",
		"If i Mod 2 = 0 Then\n    Print i & \" is even\"\nEnd If\n\nframe = frame Mod maxFrames")

	# =========================================================================
	# DRAWING COMMANDS — Primitives
	# =========================================================================
	_add("DrawRect",
		"DrawRect x, y, width, height, color [, filled]\nDrawRect Rect2(x, y, w, h), color",
		"Draws a rectangle on screen in _Draw(). Can use VB-style (x, y, w, h) or Godot-style (Rect2) arguments. If filled is False, draws only the outline.",
		"Sub _Draw()\n    DrawRect 10, 10, 200, 100, Color(1, 0, 0)     ' Filled red rect\n    DrawRect 10, 10, 200, 100, Color(0, 0, 0), False  ' Black outline\n    DrawRect Rect2(50, 50, 100, 80), Color(0, 0, 1)   ' Godot-style\nEnd Sub", 6485)

	_add("DrawCircle",
		"DrawCircle x, y, radius, color\nDrawCircle Vector2(x, y), radius, color",
		"Draws a filled circle at the specified center position with the given radius and color.",
		"Sub _Draw()\n    DrawCircle 200, 150, 50, Color(0, 1, 0)        ' Green circle\n    DrawCircle Vector2(400, 300), 30, Color.Red      ' Godot-style\nEnd Sub", 6338)

	_add("DrawLine",
		"DrawLine x1, y1, x2, y2, color [, width]\nDrawLine Vector2(x1,y1), Vector2(x2,y2), color [, width]",
		"Draws a line between two points with an optional width.",
		"Sub _Draw()\n    DrawLine 0, 0, 100, 100, Color(1, 1, 0), 2     ' Yellow 2px line\n    DrawLine Vector2(50, 50), Vector2(200, 100), Color.White\nEnd Sub", 6362)

	_add("DrawPixel",
		"DrawPixel x, y, color",
		"Draws a single pixel at the specified position. Equivalent to PSet. For per-pixel rendering, consider using CreateImage + SetImagePixel + DrawTexture instead for much better performance.",
		"Sub _Draw()\n    DrawPixel 100, 50, Color(1, 0, 0)   ' Red pixel\n    PSet 101, 50, Color(0, 1, 0)         ' Green pixel (alias)\nEnd Sub\n\n' For heavy pixel work, use Image APIs:\nDim img = CreateImage(320, 240)\nSetImagePixel img, 100, 50, Color(1, 0, 0)", 6386)

	_add("PSet",
		"PSet x, y, color",
		"Draws a single pixel (VB6-style name). Alias for DrawPixel.",
		"PSet 100, 50, Color(1, 0, 0)   ' Red pixel\nPSet 101, 50, RGB(0, 255, 0)   ' Green pixel", 9787)

	_add("DrawString",
		"DrawString font, position, text, color [, fontSize]",
		"Draws text using a Godot Font object at the specified position. Use GetThemeDefaultFont() to get the default font.",
		"Sub _Draw()\n    Dim f As Variant = GetThemeDefaultFont()\n    DrawString f, Vector2(10, 20), \"Hello World!\", Color.White\n    DrawString f, Vector2(10, 40), \"Score: \" & score, Color.Yellow\nEnd Sub", 6510)

	_add("DrawTexture",
		"DrawTexture texture, x, y [, modulate]\nDrawTexture texture, Vector2(x, y) [, modulate]",
		"Draws a Texture2D at the given position. Use with LoadPicture, CreateTexture, or ImageToTexture. The modulate parameter tints the texture with a color.",
		"' Load and draw a texture\nDim tex As Variant = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTexture tex, 100, 100\n    DrawTexture tex, 300, 100, Color(1, 0.5, 0.5, 0.8)  ' Tinted\nEnd Sub\n\n' Draw from an Image\nDim img = CreateImage(64, 64, Color.Red)\nDim tex2 = CreateTexture(img)\nDrawTexture tex2, 0, 0", 6542)

	_add("DrawTextureRect",
		"DrawTextureRect texture, Rect2(x, y, w, h), tile [, modulate]\nDrawTextureRect texture, x, y, w, h [, tile] [, modulate]",
		"Draws a texture stretched or tiled into a rectangular area. Set tile=True to tile the texture instead of stretching. Essential for rendering Image-based canvases at a display scale.",
		"' Stretch a texture to fill a region\nDim tex = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTextureRect tex, Rect2(0, 0, 640, 480), False\nEnd Sub\n\n' Image-based canvas with scaled display:\nDim img = CreateImage(160, 120)   ' Small canvas\nDim tex = CreateTexture(img)\nSub _Draw()\n    UpdateTexture tex, img\n    DrawTextureRect tex, Rect2(0, 0, 640, 480), False  ' 4x scale\nEnd Sub", 6573)

	_add("DrawArc",
		"DrawArc x, y, radius, startAngle, endAngle [, pointCount] [, color] [, width]",
		"Draws an arc (partial circle outline) centered at (x,y). Angles are in radians (0 = right, PI/2 = down). pointCount controls smoothness (default 32).",
		"Sub _Draw()\n    ' Half circle (0 to PI)\n    DrawArc 200, 200, 80, 0, 3.14159, 32, Color.Red, 2\n    ' Quarter circle\n    DrawArc 400, 200, 60, 0, 1.5708, 16, Color.Blue, 3\n    ' Full circle outline\n    DrawArc 300, 300, 100, 0, 6.28318, 64, Color.White, 1\nEnd Sub", 6300)

	_add("DrawPolygon",
		"DrawPolygon points, color",
		"Draws a filled polygon from an array of Vector2 points. Points should be in order (clockwise or counter-clockwise). Use for triangles, custom shapes, filled regions.",
		"Sub _Draw()\n    ' Triangle\n    Dim tri As Variant = Array(Vector2(100,200), Vector2(200,50), Vector2(300,200))\n    DrawPolygon tri, Color.Green\n    ' Pentagon\n    Dim pent As Variant = Array( _\n        Vector2(200,50), Vector2(300,120), Vector2(260,230), _\n        Vector2(140,230), Vector2(100,120))\n    DrawPolygon pent, Color(0.5, 0.2, 0.8)\nEnd Sub", 6419)

	_add("DrawPolyline",
		"DrawPolyline points, color [, width]",
		"Draws a multi-segment line through an array of Vector2 points. Unlike DrawPolygon, this draws open lines (not filled). Great for graphs, paths, vector shapes.",
		"Sub _Draw()\n    ' Zigzag line\n    Dim pts As Variant = Array( _\n        Vector2(10,100), Vector2(50,50), Vector2(90,100), _\n        Vector2(130,50), Vector2(170,100))\n    DrawPolyline pts, Color.Yellow, 2\nEnd Sub", 6453)

	_add("SetDrawTransform",
		"SetDrawTransform x, y [, rotation] [, scaleX] [, scaleY]",
		"Sets a 2D transform for all subsequent draw calls. Translation (x,y), rotation in radians, and scale factors. Use to draw rotated or scaled groups of shapes.",
		"Sub _Draw()\n    ' Draw a rotated square\n    SetDrawTransform 200, 200, 0.785  ' 45 degrees\n    DrawRect -25, -25, 50, 50, Color.Red\n    ResetDrawTransform\n\n    ' Draw scaled UI\n    SetDrawTransform 0, 0, 0, 2.0, 2.0  ' 2x scale\n    DrawRect 0, 0, 50, 50, Color.Blue    ' Appears as 100x100\n    ResetDrawTransform\nEnd Sub", 11078)

	_add("ResetDrawTransform",
		"ResetDrawTransform",
		"Resets the drawing transform to identity (no translation, rotation, or scale). Always call after SetDrawTransform to restore normal coordinates.",
		"SetDrawTransform 100, 100, 0.5, 2.0, 2.0\nDrawCircle 0, 0, 30, Color.Red   ' Drawn transformed\nResetDrawTransform                    ' Back to normal\nDrawCircle 50, 50, 10, Color.Blue ' Drawn at actual 50,50", 10445)

	_add("QueueRedraw",
		"QueueRedraw",
		"Requests the node to redraw on the next frame. Call this after changing any visual state that should be reflected in _Draw(). Useful in _Process() or event handlers to trigger a visual update.",
		"Sub _Process(delta)\n    If stateChanged Then\n        QueueRedraw  ' Triggers _Draw() next frame\n    End If\nEnd Sub\n\n' Or simply call every frame:\nSub _Process(delta)\n    QueueRedraw\nEnd Sub", 9990)

	_add("CLS",
		"CLS\nCLS()",
		"Clears the screen/canvas. Removes all dynamically created child nodes and triggers a redraw. VB6 classic command.",
		"CLS  ' Clear everything\n\n' Typical usage: clear before redrawing\nSub _Draw()\n    ' CLS is implicit in _Draw — each frame starts clean\n    DrawRect 0, 0, 640, 480, Color.Black   ' Background\n    DrawString GetThemeDefaultFont(), Vector2(10, 20), \"Game Over\", Color.White\nEnd Sub", 5553)

	# =========================================================================
	# IMAGE & TEXTURE MANIPULATION
	# =========================================================================
	_add("CreateImage",
		"CreateImage(width, height [, fillColor]) As Image",
		"Creates a new RGBA8 Image object with the specified dimensions (1-4096 pixels). The optional fillColor sets all pixels to that color (default is transparent black). Images are in-memory pixel buffers — use SetImagePixel to draw on them, then CreateTexture or UpdateTexture to display them.",
		"' Create a white 640x480 canvas\nDim img As Variant = CreateImage(640, 480, Color(1, 1, 1, 1))\n\n' Create a transparent 256x256 sprite sheet\nDim sheet As Variant = CreateImage(256, 256)\n\n' Draw on it\nSetImagePixel img, 100, 100, Color.Red\nSetImagePixel img, 101, 100, Color.Red\n\n' Display it\nDim tex As Variant = CreateTexture(img)\nDrawTexture tex, 0, 0", 5773)

	_add("CreateTexture",
		"CreateTexture(image) As ImageTexture\nCreateTexture(width, height [, fillColor]) As ImageTexture",
		"Creates an ImageTexture for display with DrawTexture. Can accept an existing Image, or width/height to create both an Image and Texture in one call. ImageTextures live on the GPU and are fast to render.",
		"' From an existing Image\nDim img = CreateImage(320, 240, Color.White)\nDim tex = CreateTexture(img)\n\n' Quick one-liner: create texture directly\nDim tex2 = CreateTexture(64, 64, Color.Blue)\n\n' Display in _Draw()\nSub _Draw()\n    DrawTexture tex, 0, 0\nEnd Sub", 5811)

	_add("ImageToTexture",
		"ImageToTexture(image) As ImageTexture",
		"Converts an Image object to a new ImageTexture. Similar to CreateTexture(image) but always creates a new texture object.",
		"Dim img = CreateImage(100, 100, Color.Green)\nDim tex = ImageToTexture(img)\nDrawTexture tex, 50, 50", 7636)

	_add("SetImagePixel",
		"SetImagePixel image, x, y, color",
		"Sets a pixel color on an Image object. After modifying pixels, call UpdateTexture to push changes to the display texture. Use Color() or Color8() to create the color value.",
		"Dim img = CreateImage(100, 100)\nDim tex = CreateTexture(img)\n\n' Draw a red diagonal line\nFor i = 0 To 99\n    SetImagePixel img, i, i, Color(1, 0, 0, 1)\nNext\nUpdateTexture tex, img  ' Push changes to GPU\n\n' Using Color8 (0-255 range)\nSetImagePixel img, 50, 50, Color8(0, 255, 0, 255)", 11116)

	_add("GetImagePixel",
		"GetImagePixel(image, x, y) As Color",
		"Returns the color of a pixel from an Image. The returned Color has .r, .g, .b, .a properties (0.0 to 1.0 range). Multiply by 255 for integer RGB values.",
		"Dim img = CreateImage(100, 100, Color.Red)\nDim c As Variant = GetImagePixel(img, 50, 50)\nPrint \"R=\" & Str(c.r)   ' 1.0\nPrint \"G=\" & Str(c.g)   ' 0.0\n\n' Get as integer 0-255\nDim r As Integer = Int(c.r * 255)\nDim g As Integer = Int(c.g * 255)\nDim b As Integer = Int(c.b * 255)", 7261)

	_add("FillImage",
		"FillImage image, color",
		"Fills the entire Image with a solid color. Much faster than looping over every pixel with SetImagePixel. Use for clearing a canvas or setting a background.",
		"Dim img = CreateImage(640, 480)\n\n' Clear to white\nFillImage img, Color(1, 1, 1, 1)\n\n' Clear to black\nFillImage img, Color(0, 0, 0, 1)\n\n' Using Color8\nFillImage img, Color8(100, 150, 200, 255)", 6985)

	_add("FillImageRect",
		"FillImageRect image, Rect2i(x, y, w, h), color\nFillImageRect image, x, y, w, h, color",
		"Fills a rectangular region of an Image with a color. Faster than per-pixel loops for rectangular fills.",
		"Dim img = CreateImage(320, 240, Color.White)\n\n' Draw a green rectangle\nFillImageRect img, Rect2i(10, 10, 100, 50), Color(0, 1, 0, 1)\n\n' VB-style arguments\nFillImageRect img, 50, 80, 200, 30, Color.Blue", 7019)

	_add("BlitImage",
		"BlitImage destImage, srcImage, srcRect, destPos",
		"Copies a rectangular region of pixels from a source Image to a destination Image. srcRect is a Rect2i defining the source region, destPos is a Vector2i for the destination top-left corner.",
		"Dim canvas = CreateImage(640, 480, Color.White)\nDim stamp = CreateImage(32, 32, Color.Red)\n\n' Stamp the red square onto the canvas at (100, 100)\nBlitImage canvas, stamp, Rect2i(0, 0, 32, 32), Vector2i(100, 100)\n\n' Copy part of canvas to another location\nBlitImage canvas, canvas, Rect2i(0, 0, 100, 100), Vector2i(200, 200)", 4574)

	_add("UpdateTexture",
		"UpdateTexture texture, image",
		"Pushes updated Image pixel data to an existing ImageTexture. Call this after modifying pixels with SetImagePixel, FillImage, or BlitImage to make the changes visible on screen. This is an essential step in the Image → Texture rendering pipeline.",
		"Dim img = CreateImage(320, 240)\nDim tex = CreateTexture(img)\n\n' Modify pixels\nFor x = 0 To 319\n    SetImagePixel img, x, 120, Color.Red\nNext\n\n' IMPORTANT: Push to GPU\nUpdateTexture tex, img\n\n' Now DrawTexture will show the changes\nSub _Draw()\n    DrawTexture tex, 0, 0\nEnd Sub", 12702)

	_add("ImageWidth",
		"ImageWidth(image) As Integer",
		"Returns the width of an Image in pixels.",
		"Dim img = CreateImage(320, 240)\nPrint ImageWidth(img)   ' 320\nPrint ImageHeight(img)  ' 240", 7662)

	_add("ImageHeight",
		"ImageHeight(image) As Integer",
		"Returns the height of an Image in pixels.",
		"Dim img = CreateImage(320, 240)\nPrint ImageHeight(img)  ' 240\n\n' Iterate all pixels\nFor y = 0 To ImageHeight(img) - 1\n    For x = 0 To ImageWidth(img) - 1\n        SetImagePixel img, x, y, Color(x/320.0, y/240.0, 0.5, 1)\n    Next\nNext", 7604)

	_add("TextureWidth",
		"TextureWidth(texture) As Integer",
		"Returns the width of a Texture2D in pixels.",
		"Dim tex = LoadPicture(\"res://icon.png\")\nPrint TextureWidth(tex)   ' e.g. 128\nPrint TextureHeight(tex)  ' e.g. 128", 12135)

	_add("TextureHeight",
		"TextureHeight(texture) As Integer",
		"Returns the height of a Texture2D in pixels.",
		"Dim tex = CreateTexture(256, 128)\nPrint TextureWidth(tex)    ' 256\nPrint TextureHeight(tex)   ' 128", 12109)

	_add("GetTextureImage",
		"GetTextureImage(texture) As Image",
		"Extracts the Image data from an ImageTexture. Useful for reading pixel data from a loaded texture. The returned Image can be modified and pushed back with UpdateTexture.",
		"Dim tex = LoadPicture(\"res://icon.png\")\nDim img = GetTextureImage(tex)\nDim c = GetImagePixel(img, 0, 0)  ' Read top-left pixel\nPrint \"Top-left color: R=\" & Str(Int(c.r * 255))", 7295)

	_add("SaveImage",
		"SaveImage(image, path) As Boolean",
		"Saves an Image to a PNG file. Returns True on success. Use user:// paths for writable locations. Great for screenshots or saving user-created art.",
		"Dim img = CreateImage(640, 480, Color.White)\n' ... draw on img ...\nDim ok As Boolean = SaveImage(img, \"user://screenshot.png\")\nIf ok Then\n    Print \"Saved!\"\nEnd If", 10636)

	_add("LoadImage",
		"LoadImage(path) As Image",
		"Loads an image file (PNG, JPG, BMP, etc.) and returns it as an RGBA8 Image object. Unlike LoadPicture (which returns a Texture2D), LoadImage gives you direct pixel access via GetImagePixel.",
		"Dim img = LoadImage(\"user://painting.png\")\nPrint \"Size: \" & Str(ImageWidth(img)) & \"x\" & Str(ImageHeight(img))\n\n' Read a pixel\nDim c = GetImagePixel(img, 0, 0)\nPrint \"R=\" & Str(Int(c.r * 255))\n\n' Convert to texture for display\nDim tex = ImageToTexture(img)\nDrawTexture tex, 0, 0", 8588)

	_add("LoadPicture",
		"LoadPicture(path) As Texture2D",
		"Loads an image file from the given resource path and returns a Texture2D for use with DrawTexture. The classic VB6-style way to load images.",
		"Dim tex As Variant = LoadPicture(\"res://icon.png\")\nSub _Draw()\n    DrawTexture tex, 100, 100\nEnd Sub", 8621)

	_add("RGB",
		"RGB(red, green, blue) As Color",
		"Creates a Color from integer red, green, blue values (0-255). VB6-compatible function.",
		"Dim c As Variant = RGB(255, 0, 0)  ' Red\nDrawRect 0, 0, 100, 100, RGB(0, 128, 255)  ' Sky blue", 10529)

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

	# =========================================================================
	# PASS 6 — v5.1 GAP-FILLERS
	#
	# Verbs added in v5.1 to round out the Pass 1–5 namespaces. All entries
	# point at the v4.x–v5.1 Godot Namespace Wrappers section of the manual.
	# =========================================================================

	# --- Camera v5.1 ---
	_add("Camera.PanTo",
		"Camera.PanTo(pos, duration [, h])",
		"Tween-pans the active camera to pos over duration seconds. Smoother than setting Camera.Position directly. Works for Camera2D (Vector2) or Camera3D (Vector3).",
		"' Cinematic reveal\nCamera.PanTo Vector2(800, 400), 1.5", 5085)

	_add("Camera.Bounce",
		"Camera.Bounce(direction, strength [, h])",
		"One-shot recoil pulse — pushes the camera in `direction` by `strength` and snaps back. Good for explosions, weapon kick, or hit-stop reactions.",
		"' Shotgun recoil\nCamera.Bounce Vector2(-1, 0), 18", 4919)

	_add("Camera.FlashColor",
		"Camera.FlashColor(color, duration [, h])",
		"Briefly fills the viewport with `color`, then fades it out over `duration`. Use for hit flashes, lightning, screen blanks.",
		"' Damage flash\nCamera.FlashColor RGB(255, 0, 0), 0.15", 4946)

	# --- Animation v5.1 ---
	_add("Animation.Loop",
		"Animation.Loop(name, looped [, player])",
		"Sets whether the named animation should loop. Persisted on the underlying Animation resource, so it survives stop/play.",
		"Animation.Loop \"idle\", True\nAnimation.Loop \"jump\", False", 4294)

	# --- Physics v5.1 ---
	_add("Physics.Gravity",
		"Physics.Gravity(vector [, body])",
		"Sets the world gravity. Pass a scalar for default-direction gravity, or a Vector2/Vector3 for arbitrary direction. With `body`, sets per-body gravity scale.",
		"Physics.Gravity 980        ' classic down\nPhysics.Gravity Vector2(0, -980)  ' anti-gravity zone", 9500)

	_add("Physics.GravityV2",
		"Physics.GravityV2(Vector2 [, body])",
		"Explicit Vector2 form of Physics.Gravity — avoids overload guessing when you need 2D.",
		"Physics.GravityV2 Vector2(0, 1200)", 9526)

	_add("Physics.GravityV3",
		"Physics.GravityV3(Vector3 [, body])",
		"Explicit Vector3 form of Physics.Gravity for 3D worlds.",
		"Physics.GravityV3 Vector3(0, -9.8, 0)", 9551)

	_add("Physics.Bounce",
		"Physics.Bounce(value, body)",
		"Sets the restitution (bounciness) of a RigidBody, 0.0 = dead, 1.0 = full energy return.",
		"Physics.Bounce 0.8, ball   ' rubber ball", 9447)

	# --- Ray v5.1 ---
	_add("Ray.Cast2D",
		"Ray.Cast2D(from, to [, mask]) As Dictionary",
		"One-shot 2D raycast through PhysicsDirectSpaceState — no RayCast2D node required. Returns a Dictionary { position, normal, collider, … } or empty if nothing hit.",
		"Dim hit = Ray.Cast2D(player.Position, Mouse.Position)\nIf Not hit.is_empty() Then Print hit.collider.name", 10106)

	_add("Ray.Cast3D",
		"Ray.Cast3D(from, to [, mask]) As Dictionary",
		"One-shot 3D raycast — see Ray.Cast2D. Useful for shooter logic without permanent RayCast3D nodes.",
		"Dim hit = Ray.Cast3D(cam.GlobalPosition, cam.GlobalPosition + cam.Basis.z * -100)", 10133)

	# --- Joypad v5.1 ---
	_add("Joypad.IsConnected",
		"Joypad.IsConnected(index) As Boolean",
		"Returns True if a joypad/gamepad is currently connected at the given device index. Companion to Joypad.Connected (which returns the count).",
		"If Joypad.IsConnected(0) Then ShowPlayerJoinedIcon()", 8196)

	_add("Joypad.Stick",
		"Joypad.Stick(index, side) As Vector2",
		"Returns the analog stick position as a Vector2 (-1..1 per axis). `side` is 0 for left stick, 1 for right.",
		"Dim move = Joypad.Stick(0, 0)\nplayer.Velocity = move * speed", 8244)

	# --- Sensor v5.1 ---
	_add("Sensor.Magnetometer",
		"Sensor.Magnetometer() As Vector3",
		"Alias of Sensor.Magnet — returns the device magnetometer reading (µT). Provided for naming consistency with platform docs.",
		"Dim compass = Sensor.Magnetometer()", 10965)

	# --- Crypto v5.1 ---
	_add("Crypto.Hex",
		"Crypto.Hex(bytes) As String",
		"Converts a PackedByteArray (or hashable input) to a lowercase hex string. Inverse of Crypto.FromHex.",
		"Print Crypto.Hex(Crypto.RandomBytes(8))   ' e.g. \"a1b2c3d4e5f60718\"", 5940)

	_add("Crypto.FromHex",
		"Crypto.FromHex(hexString) As PackedByteArray",
		"Parses a hex string back into raw bytes. Whitespace is ignored; case-insensitive.",
		"Dim raw = Crypto.FromHex(\"deadbeef\")", 5916)

	_add("Crypto.Base64",
		"Crypto.Base64(bytes) As String",
		"Short form of Crypto.Base64Encode — encodes bytes to a standard Base64 string.",
		"Print Crypto.Base64(\"hello world\")   ' \"aGVsbG8gd29ybGQ=\"", 5842)

	# --- Theme v5.1 (generic get/set) ---
	_add("Theme.Get",
		"Theme.Get(control, kind, name) As Variant",
		"Generic theme-item reader. `kind` is \"color\" | \"constant\" | \"font\" | \"font_size\" | \"style\". Returns the inherited value if the control has no override.",
		"Dim panelBg = Theme.Get(myPanel, \"color\", \"bg_color\")", 12236)

	_add("Theme.Set",
		"Theme.Set(control, kind, name, value)",
		"Generic theme-item writer. Same kind values as Theme.Get. Convenience wrapper around the typed Theme.SetColor / SetConstant / SetFont / SetFontSize / SetStyle verbs.",
		"Theme.Set lblTitle, \"color\", \"font_color\", RGB(255, 200, 0)\nTheme.Set lblTitle, \"font_size\", \"font_size\", 32", 12262)

	# --- Shader v5.1 aliases ---
	_add("Shader.Set",
		"Shader.Set(material, key, value)",
		"Alias of Shader.Param — sets a shader uniform. Use whichever name reads better in your code.",
		"Shader.Set sprite.Material, \"hit_flash\", 1.0", 11229)

	_add("Shader.Get",
		"Shader.Get(material, key) As Variant",
		"Alias of Shader.GetParam — reads a shader uniform.",
		"Print Shader.Get(sprite.Material, \"hit_flash\")", 11153)

	# --- Speaker alias ---
	_add("Speaker.Bus",
		"Speaker.Bus",
		"Alias of the Speaker namespace — same verbs (Volume, Mute, Solo, etc.) just spelled `Speaker.Bus.Volume`. Provided for readers who think \"bus\" first.",
		"Speaker.Bus.Volume \"Master\", 75", 11662)

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

		# --- v4.x–v5.1 namespace wrappers ---
		# Camera namespace
		["Camera.Position", "Camera.Zoom", "Camera.Rotation", "Camera.FOV", "Camera.Follow",
			"Camera.Shake", "Camera.Limits", "Camera.MakeCurrent",
			"Camera.PanTo", "Camera.Bounce", "Camera.FlashColor"],
		# Sound namespace
		["Sound.Play", "Sound.Stop", "Sound.Pause", "Sound.Resume", "Sound.Seek",
			"Sound.Volume", "Sound.Pitch", "Sound.IsPlaying", "Sound.Position"],
		# Speaker namespace
		["Speaker.Volume", "Speaker.Mute", "Speaker.IsMuted", "Speaker.Solo",
			"Speaker.Exists", "Speaker.Count", "Speaker.Name", "Speaker.Bus"],
		# SoundGen namespace
		["SoundGen.Open", "SoundGen.Close", "SoundGen.Available",
			"SoundGen.PushMono", "SoundGen.PushStereo"],
		# Animation namespace
		["Animation.Play", "Animation.Stop", "Animation.Pause", "Animation.Resume",
			"Animation.Seek", "Animation.Speed", "Animation.Current", "Animation.IsPlaying",
			"Animation.Length", "Animation.Loop"],
		# Physics namespace + globals
		["Physics.Gravity", "Physics.GravityV2", "Physics.GravityV3", "Physics.Bounce",
			"Physics.Force", "Physics.Impulse", "Physics.Torque", "Physics.Ray",
			"Push", "Pull", "Spin"],
		# Ray namespace
		["Ray.Cast2D", "Ray.Cast3D", "Ray.Target", "Ray.Enable", "Ray.ForceUpdate",
			"Ray.Hit", "Ray.Collider", "Ray.Point", "Ray.Normal"],
		# Cell namespace
		["Cell.Get", "Cell.Set", "Cell.Clear", "Cell.ClearAll", "Cell.Used"],
		# Nav namespace
		["Nav.SetTarget", "Nav.NextPos", "Nav.Distance", "Nav.Reached", "Nav.Path"],
		# Screen namespace
		["Screen.Width", "Screen.Height", "Screen.DPI", "Screen.Orientation",
			"Screen.KeepOn", "Screen.FullScreen", "Screen.IsFullScreen"],
		# Joypad namespace
		["Joypad.Connected", "Joypad.IsConnected", "Joypad.Name",
			"Joypad.Axis", "Joypad.Button", "Joypad.Stick"],
		# Sensor namespace
		["Sensor.Units", "Sensor.Accel", "Sensor.Gyro", "Sensor.Magnet",
			"Sensor.Magnetometer", "Sensor.Gravity", "Sensor.Tilt"],
		# Permission namespace
		["Permission.Has", "Permission.Request", "Permission.All"],
		# GPS namespace
		["GPS.Lat", "GPS.Lng", "GPS.Alt", "GPS.Accuracy", "GPS.Speed"],
		# Steps namespace
		["Steps.Today", "Steps.Total", "Steps.Reset"],
		# Crypto namespace
		["Crypto.MD5", "Crypto.SHA1", "Crypto.SHA256", "Crypto.HMAC", "Crypto.RandomBytes",
			"Crypto.Hex", "Crypto.FromHex", "Crypto.Base64", "Crypto.Base64Encode", "Crypto.Base64Decode"],
		# Theme namespace
		["Theme.Color", "Theme.Constant", "Theme.Font",
			"Theme.SetColor", "Theme.SetConstant", "Theme.SetFont",
			"Theme.SetFontSize", "Theme.SetStyle", "Theme.Get", "Theme.Set"],
		# Shader / Material
		["Material.New", "Material.SetShader", "Shader.Param", "Shader.GetParam",
			"Shader.Set", "Shader.Get"],
		# Skeleton / Bone
		["Skeleton.Count", "Skeleton.Name", "Skeleton.Reset",
			"Bone.Find", "Bone.Pos", "Bone.Rot", "Bone.Scale",
			"Bone.SetPos", "Bone.SetRot", "Bone.SetScale", "Bone.LookAt"],
		# Video namespace
		["Video.Play", "Video.Stop", "Video.Pause", "Video.Resume", "Video.Seek",
			"Video.Position", "Video.Length", "Video.IsPlaying", "Video.Volume"],
		# JS namespace
		["JS.Eval", "JS.Call", "JS.Get"],
		# Pass 1 math helpers
		["Quaternion", "QuaternionFromEuler", "Basis", "Transform2D", "Transform3D",
			"Plane", "AABB", "Slerp"],
		# RNG / Noise / Curve
		["NewRNG", "NewNoise", "NewCurve", "Rnd", "Randomize", "RandRange"],
		# Color helpers
		["ColorFromHSV", "ColorToHSV", "Lighten", "Darken", "RGB"],
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

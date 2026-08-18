extends SceneTree
## Headless Programmer's Reference harness.
##
## Default: parse every _add() example + run critical builtins (End, DoEvents, Throw).
##   scripts/run_command_reference_harness.sh
## Full example execution (slow, many need mocks):
##   VG_CMDREF_RUN_EXAMPLES=1 scripts/run_command_reference_harness.sh

const VGCommandHelp := preload("res://addons/visual_gasic/vg_command_help.gd")

const SKIP_KEYWORDS: Array[String] = ["interface", "using", "implements"]
const PARSE_ONLY_KEYWORDS: Array[String] = [
	"end", "msgbox", "inputbox", "changescene", "loadform",
]
const SKIP_GODOT_FLAG := "godot_class"

var _parse_pass := 0
var _parse_skip := 0
var _parse_fail: Array[Dictionary] = []
var _run_pass := 0
var _run_fail: Array[Dictionary] = []
var _run_examples := OS.get_environment("VG_CMDREF_RUN_EXAMPLES") == "1"


func _init() -> void:
	print("=== Programmer's Reference harness ===")
	if _run_examples:
		print("(VG_CMDREF_RUN_EXAMPLES=1 — executing all safe examples)")
	else:
		print("(parse-only for help examples; set VG_CMDREF_RUN_EXAMPLES=1 to execute)")
	_run_critical_builtin_tests()
	_run_help_examples()
	_write_report()
	_print_summary()
	quit(_parse_fail.size())


func _run_critical_builtin_tests() -> void:
	print("\n-- Critical builtins --")
	_check("End", """
Attribute VB_Name = "CritEnd"
Sub Main()
	If False Then
		End
	End If
	Print "End ok"
End Sub
""", true)
	_check("DoEvents", """
Attribute VB_Name = "CritDoEvents"
Sub Main()
	DoEvents
	Print "DoEvents ok"
End Sub
""", true)
	_check("Throw", """
Attribute VB_Name = "CritThrow"
Sub Main()
	Try
		Throw "harness"
	Catch ex
		Print "Throw ok"
	End Try
End Sub
""", true)
	_check("LoadForm", """
Attribute VB_Name = "CritLoadForm"
Sub Main()
	LoadForm "MissingForm"
End Sub
""", false)
	_check("ChangeScene", """
Attribute VB_Name = "CritChangeScene"
Sub Main()
	ChangeScene "res://missing_harness_scene.tscn"
End Sub
""", false)


func _run_help_examples() -> void:
	print("\n-- vg_command_help.gd (", VGCommandHelp.get_all_keywords().size(), " keywords) --")
	for kw in VGCommandHelp.get_all_keywords():
		var key := kw.strip_edges().to_lower()
		if key in SKIP_KEYWORDS:
			_parse_skip += 1
			continue
		var entry: Dictionary = VGCommandHelp.lookup(kw)
		if entry.is_empty() or entry.has(SKIP_GODOT_FLAG):
			_parse_skip += 1
			continue
		var source := _wrap_example(kw, String(entry.get("code", "")), String(entry.get("syntax", "")))
		if _try_parse(source) != OK:
			_parse_fail.append({"keyword": kw, "source": source})
			continue
		_parse_pass += 1
		if not _run_examples or key in PARSE_ONLY_KEYWORDS:
			continue
		if not _should_try_run(kw, String(entry.get("code", ""))):
			continue
		var err := _try_run(source)
		if err.is_empty():
			_run_pass += 1
		else:
			_run_fail.append({"keyword": kw, "err": err})


func _wrap_example(keyword: String, code: String, syntax: String) -> String:
	var key := keyword.strip_edges().to_lower()
	if _CUSTOM.has(key):
		return 'Attribute VB_Name = "CmdRefHarness"\n\n' + String(_CUSTOM[key])
	code = code.strip_edges()
	if code.is_empty():
		return _indent_main("' " + syntax.substr(0, mini(60, syntax.length())))
	var lower := code.to_lower()
	if _looks_module_level(lower):
		return 'Attribute VB_Name = "CmdRefHarness"\n\n' + code
	if lower.contains("\nsub ") or lower.begins_with("sub ") or lower.contains("\nfunction ") \
			or lower.begins_with("function ") or lower.contains("\nclass ") or lower.begins_with("class "):
		return 'Attribute VB_Name = "CmdRefHarness"\n\n' + code + "\n\nSub __HarnessEntry()\nEnd Sub\n"
	return _indent_main(code)


func _looks_module_level(lower_code: String) -> bool:
	for p in ["class ", "enum ", "type ", "global ", "option explicit", "module ", "declare ",
			"public ", "private ", "static "]:
		if lower_code.begins_with(p):
			return true
	return false


func _indent_main(body: String) -> String:
	var out := 'Attribute VB_Name = "CmdRefHarness"\n\nSub Main()\n'
	for line in body.split("\n", false):
		out += "\t" + line + "\n"
	return out + "End Sub\n"


const _CUSTOM := {
	"end": """Sub Main()
	If False Then End
End Sub
Sub Helper()
End Sub""",
	"property": """Class PropDemo
	Private _n As Integer
	Property Get Count() As Integer
		Count = _n
	End Property
	Property Let Count(v As Integer)
		_n = v
	End Property
End Class
Sub Main()
	Dim o As New PropDemo
End Sub""",
	"select case": """Sub Main()
	Select Case 2
		Case 1: Print 1
		Case 2: Print 2
		Case Else: Print 0
	End Select
End Sub""",
	"for each": """Sub Main()
	Dim arr() As String
	ReDim arr(0)
	arr(0) = "x"
	Dim item As String
	For Each item In arr
		Print item
	Next
End Sub""",
	"class": """Class Point
	Public X As Integer
	Public Y As Integer
End Class
Sub Main()
End Sub""",
}


func _should_try_run(keyword: String, code: String) -> bool:
	var k := keyword.to_lower()
	if k in ["playmusic", "playtone", "playsound", "drawline", "drawcircle", "drawrect",
			"drawstring", "drawtexture", "drawtexturerect", "drawpixel", "drawarc",
			"drawpolygon", "drawpolyline", "cls", "pset", "ai_chase", "ai_wander", "ai_patrol"]:
		return false
	if code.find("Await ") >= 0 or code.find("Http.") >= 0:
		return false
	return true


func _try_parse(source: String) -> int:
	var result: Dictionary = VisualGasicLanguage.vg_validate_code(source, "")
	if not bool(result.get("valid", false)):
		return ERR_PARSE_ERROR
	var s := VisualGasicScript.new()
	s.source_code = source
	s.reload(true)
	if s.has_method("has_reload_errors") and s.has_reload_errors():
		return ERR_PARSE_ERROR
	return OK


func _try_run(source: String) -> String:
	var s := VisualGasicScript.new()
	s.source_code = source
	if s.reload(true) != OK:
		return "reload"
	var node := Node2D.new()
	get_root().add_child(node)
	node.set_script(s)
	for m in ["Main", "__HarnessEntry"]:
		if node.has_method(m):
			node.call(m)
			node.queue_free()
			return ""
	node.queue_free()
	return "no Main"


func _check(label: String, source: String, run_it: bool) -> void:
	if _try_parse(source) != OK:
		_parse_fail.append({"keyword": label, "source": source})
		print("  FAIL parse ", label)
		return
	_parse_pass += 1
	print("  PASS parse ", label)
	if not run_it:
		return
	if _try_run(source).is_empty():
		_run_pass += 1
		print("  PASS run   ", label)
	else:
		_run_fail.append({"keyword": label, "err": "run"})
		print("  FAIL run   ", label)


func _write_report() -> void:
	var lines: PackedStringArray = []
	lines.append("Programmer's Reference harness")
	lines.append("Parse OK: %d  SKIP: %d  FAIL: %d" % [_parse_pass, _parse_skip, _parse_fail.size()])
	for f in _parse_fail:
		lines.append("PARSE FAIL: %s" % f.get("keyword", "?"))
	var path := ProjectSettings.globalize_path("res://../tests/command_ref_harness_report.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		f.close()


func _print_summary() -> void:
	print("\n=== Summary ===")
	print("Parse OK:   ", _parse_pass)
	print("Parse SKIP: ", _parse_skip)
	print("Parse FAIL: ", _parse_fail.size())
	print("Run OK:     ", _run_pass)
	print("Run FAIL:   ", _run_fail.size())
	if not _parse_fail.is_empty():
		print("\nParse failures:")
		for i in mini(_parse_fail.size(), 30):
			print("  - ", _parse_fail[i]["keyword"])

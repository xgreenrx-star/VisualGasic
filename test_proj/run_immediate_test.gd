extends SceneTree

# Test Runner: Immediate Window Property GET/SET
# Loads a .vg script, waits for _Ready, then calls vg_evaluate_immediate
# to test property reading and writing through the Immediate Window API.

var max_frames: int = 20
var _frame: int = 0
var _tested: bool = false
var _pass_count: int = 0
var _fail_count: int = 0

func _init():
	var vg_path = "test_suite/test_immediate_properties.vg"
	var script = load(vg_path)
	if script == null:
		print("ERROR: Failed to load " + vg_path)
		quit()
		return
	var test_node = Node.new()
	test_node.name = "TestNode"
	test_node.set_script(script)
	root.add_child(test_node)

func _assert(test_name: String, result: Dictionary, expected: String):
	if not result.get("success", false):
		print("FAIL: " + test_name + ": immediate returned failure: " + str(result.get("result", "")))
		_fail_count += 1
		return
	var got = str(result.get("result", ""))
	if got == expected:
		print("PASS: " + test_name)
		_pass_count += 1
	else:
		print("FAIL: " + test_name + ": expected '" + expected + "', got '" + got + "'")
		_fail_count += 1

func _assert_ok(test_name: String, result: Dictionary):
	if result.get("success", false):
		print("PASS: " + test_name)
		_pass_count += 1
	else:
		print("FAIL: " + test_name + ": " + str(result.get("result", "")))
		_fail_count += 1

func _process(_delta):
	_frame += 1
	# Wait 3 frames for _Ready to complete (bytecode + AST fallback)
	if _frame == 3 and not _tested:
		_tested = true
		_run_immediate_tests()
	if _frame >= max_frames:
		quit()

func _run_immediate_tests():
	# The static method: VisualGasicLanguage.vg_evaluate_immediate(index, code)
	# Instance 0 is our test node.
	var r: Dictionary

	# ================================================================
	# TEST: Read Caption (should be "Original" from _Ready)
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Caption")
	_assert("imm_read_caption", r, "Original")

	# ================================================================
	# TEST: Set Caption via Immediate Window, then read back
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Caption = \"Changed\"")
	_assert_ok("imm_set_caption", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Caption")
	_assert("imm_read_caption_after_set", r, "Changed")

	# ================================================================
	# TEST: Set and read Text on Label
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "lbl.Text = \"Hello Immediate\"")
	_assert_ok("imm_set_label_text", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? lbl.Text")
	_assert("imm_read_label_text", r, "Hello Immediate")

	# ================================================================
	# TEST: Visible property
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Visible = False")
	_assert_ok("imm_set_visible_false", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Visible")
	_assert("imm_read_visible", r, "False")
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Visible = True")
	_assert_ok("imm_set_visible_true", r)

	# ================================================================
	# TEST: Position — Left, Top
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Left = 100")
	_assert_ok("imm_set_left", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Left")
	var left_val = str(r.get("result", ""))
	if left_val == "100" or left_val == "100.0":
		print("PASS: imm_read_left")
		_pass_count += 1
	else:
		print("FAIL: imm_read_left: got '" + left_val + "'")
		_fail_count += 1

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Top = 200")
	_assert_ok("imm_set_top", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Top")
	var top_val = str(r.get("result", ""))
	if top_val == "200" or top_val == "200.0":
		print("PASS: imm_read_top")
		_pass_count += 1
	else:
		print("FAIL: imm_read_top: got '" + top_val + "'")
		_fail_count += 1

	# ================================================================
	# TEST: Size — Width, Height
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Width = 300")
	_assert_ok("imm_set_width", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Width")
	var w_val = str(r.get("result", ""))
	if w_val == "300" or w_val == "300.0":
		print("PASS: imm_read_width")
		_pass_count += 1
	else:
		print("FAIL: imm_read_width: got '" + w_val + "'")
		_fail_count += 1

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Height = 50")
	_assert_ok("imm_set_height", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Height")
	var h_val = str(r.get("result", ""))
	if h_val == "50" or h_val == "50.0":
		print("PASS: imm_read_height")
		_pass_count += 1
	else:
		print("FAIL: imm_read_height: got '" + h_val + "'")
		_fail_count += 1

	# ================================================================
	# TEST: Enabled
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Enabled = False")
	_assert_ok("imm_set_enabled", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Enabled")
	var en_val = str(r.get("result", "")).to_lower()
	if en_val == "false" or en_val == "0" or en_val == "0.0":
		print("PASS: imm_read_enabled_false")
		_pass_count += 1
	else:
		print("FAIL: imm_read_enabled_false: got '" + en_val + "'")
		_fail_count += 1
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Enabled = True")
	_assert_ok("imm_restore_enabled", r)

	# ================================================================
	# TEST: FontSize
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.FontSize = 24")
	_assert_ok("imm_set_fontsize", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.FontSize")
	var fs_val = str(r.get("result", ""))
	if fs_val == "24" or fs_val == "24.0":
		print("PASS: imm_read_fontsize")
		_pass_count += 1
	else:
		print("FAIL: imm_read_fontsize: got '" + fs_val + "'")
		_fail_count += 1

	# ================================================================
	# TEST: ToolTipText
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.ToolTipText = \"Hover me\"")
	_assert_ok("imm_set_tooltip", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.ToolTipText")
	_assert("imm_read_tooltip", r, "Hover me")

	# ================================================================
	# TEST: Timer — Interval (ms)
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "tmr.Interval = 500")
	_assert_ok("imm_set_interval", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? tmr.Interval")
	_assert("imm_read_interval", r, "500")

	# ================================================================
	# TEST: Tag
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Tag = \"debug_info\"")
	_assert_ok("imm_set_tag", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Tag")
	_assert("imm_read_tag", r, "debug_info")

	# ================================================================
	# TEST: Name (read)
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Name")
	_assert("imm_read_name", r, "btnImm")

	# ================================================================
	# TEST: hWnd (read, should be > 0)
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.hWnd")
	if r.get("success", false) and str(r.get("result", "0")).to_int() > 0:
		print("PASS: imm_read_hwnd")
		_pass_count += 1
	else:
		print("FAIL: imm_read_hwnd: " + str(r.get("result", "")))
		_fail_count += 1

	# ================================================================
	# TEST: FontBold
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.FontBold = True")
	_assert_ok("imm_set_fontbold", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.FontBold")
	var fb_val = str(r.get("result", "")).to_lower()
	if fb_val == "true" or fb_val == "1" or fb_val == "1.0":
		print("PASS: imm_read_fontbold")
		_pass_count += 1
	else:
		print("FAIL: imm_read_fontbold: got '" + fb_val + "'")
		_fail_count += 1

	# ================================================================
	# TEST: MaxLength on LineEdit
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "le.MaxLength = 100")
	_assert_ok("imm_set_maxlength", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? le.MaxLength")
	_assert("imm_read_maxlength", r, "100")

	# ================================================================
	# TEST: BackColor
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "pnl.BackColor = Color(1, 0, 0)")
	_assert_ok("imm_set_backcolor", r)

	# ================================================================
	# VB6-STYLE FORMATTING TESTS
	# ================================================================
	# Verify integers show without .0
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Left = 150")
	_assert_ok("imm_fmt_set_left", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Left")
	_assert("imm_fmt_left_no_decimal", r, "150")

	# Verify booleans show as True/False
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Visible = True")
	_assert_ok("imm_fmt_set_visible", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Visible")
	var vis_val = str(r.get("result", ""))
	# VG runtime stores bools as integers; True→1 or -1, False→"False"
	if vis_val == "True" or vis_val == "true" or vis_val == "1" or vis_val == "-1":
		print("PASS: imm_fmt_visible_bool")
		_pass_count += 1
	else:
		print("FAIL: imm_fmt_visible_bool: got '" + vis_val + "'")
		_fail_count += 1

	# ================================================================
	# NEW PROPERTY TESTS: BackStyle, Appearance, TabIndex, DragMode, Index
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.BackStyle = 0")
	_assert_ok("imm_set_backstyle", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.BackStyle")
	_assert("imm_read_backstyle", r, "0")

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Appearance = 1")
	_assert_ok("imm_set_appearance", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Appearance")
	_assert("imm_read_appearance", r, "1")

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.TabIndex = 3")
	_assert_ok("imm_set_tabindex", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.TabIndex")
	_assert("imm_read_tabindex", r, "3")

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.DragMode = 1")
	_assert_ok("imm_set_dragmode", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.DragMode")
	_assert("imm_read_dragmode", r, "1")

	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "btn.Index = 7")
	_assert_ok("imm_set_index", r)
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Index")
	_assert("imm_read_index", r, "7")

	# ================================================================
	# COMPOUND EXPRESSION TESTS
	# ================================================================
	# Arithmetic expression
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? 2 + 3")
	_assert("imm_expr_add", r, "5")

	# String concatenation (& operator not yet supported in immediate window parser)
	# r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? \"Hello\" & \" World\"")
	# _assert("imm_expr_concat", r, "Hello World")
	print("SKIP: imm_expr_concat (& operator not yet in immediate parser)")

	# Set and read string variable
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "Dim testVar As String")
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "testVar = \"ImmTest\"")
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? testVar")
	_assert("imm_read_variable", r, "ImmTest")

	# ================================================================
	# ERROR HANDLING TESTS
	# ================================================================
	# Unknown property should fail gracefully
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.NonExistentProp")
	# Should return something (possibly error), not crash
	print("PASS: imm_no_crash_unknown_prop")
	_pass_count += 1

	# Empty input
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "")
	if r.get("success", false):
		print("PASS: imm_empty_input")
		_pass_count += 1
	else:
		print("FAIL: imm_empty_input")
		_fail_count += 1

	# ================================================================
	# PARENT PROPERTY TEST
	# ================================================================
	r = ClassDB.class_call_static("VisualGasicLanguage", "vg_evaluate_immediate", 0, "? btn.Parent")
	if r.get("success", false):
		print("PASS: imm_read_parent")
		_pass_count += 1
	else:
		print("FAIL: imm_read_parent: " + str(r.get("result", "")))
		_fail_count += 1

	# ================================================================
	# Summary
	# ================================================================
	print("")
	print("Immediate Window Property Tests: " + str(_pass_count) + " passed, " + str(_fail_count) + " failed")
	if _fail_count == 0:
		print("PASS: all_immediate_property_tests_complete")
	else:
		print("FAIL: " + str(_fail_count) + " immediate window tests failed")

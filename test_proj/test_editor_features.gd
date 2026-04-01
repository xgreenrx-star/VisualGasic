extends SceneTree

## Headless test for VGCodeEdit editor features:
##   - Semantic token parsing (params, locals, module vars, consts)
##   - Procedure boundary detection
##   - Scope-aware occurrence highlighting logic
##   - Change tracking gutter state
##   - Code folding (fold all / unfold all)
##   - Sticky scroll procedure detection
##   - Rainbow bracket depth counting
##   - Minimap marker word-boundary detection

var _pass := 0
var _fail := 0

func _assert(condition: bool, desc: String) -> void:
	if condition:
		_pass += 1
		print("  PASS: " + desc)
	else:
		_fail += 1
		print("  FAIL: " + desc)

# ─── VB6 test source code ─────────────────────────────────────────────────
# NOTE: Body lines use TAB indentation — VGCodeEdit sets indent_use_spaces=false
# so Godot's indent-based folding only recognises tab-indented blocks.
var VB6_CODE: String

func _build_vb6_code() -> String:
	var t := "\t"  # tab character
	var lines := PackedStringArray([
		"Option Explicit",
		"",
		"Dim Score As Integer",
		"Public PlayerName As String",
		"Const MAX_LIVES = 3",
		"",
		"Private Sub Form_Load(ByVal sender As Object, ByRef e As EventArgs)",
		t + "Dim localVar As Integer",
		t + "Dim tempStr As String",
		t + "localVar = Score + MAX_LIVES",
		t + 'PlayerName = "Test"',
		t + 'tempStr = "Hello " & PlayerName',
		t + "MsgBox tempStr",
		"End Sub",
		"",
		"Public Function GetScore(ByVal bonus As Integer) As Integer",
		t + "Dim result As Integer",
		t + "result = Score + bonus",
		t + "GetScore = result",
		"End Function",
		"",
		"Private Sub cmdReset_Click()",
		t + "Score = 0",
		t + 'PlayerName = ""',
		"End Sub",
	])
	return "\n".join(lines)

func _init():
	VB6_CODE = _build_vb6_code()
	var ce := VGCodeEdit.new()
	ce.name = "TestCodeEdit"
	# Must add to tree for CodeEdit methods to work
	root.add_child.call_deferred(ce)
	# Wait a frame for the node to enter tree, then run tests
	call_deferred("_run_tests", ce)

func _run_tests(ce: VGCodeEdit) -> void:
	# Ensure it's in the tree
	if not ce.is_inside_tree():
		print("ERROR: VGCodeEdit not in tree yet")
		quit()
		return

	ce.text = VB6_CODE

	print("")
	print("══════════════════════════════════════════════")
	print("  VGCodeEdit Editor Features — Headless Tests")
	print("══════════════════════════════════════════════")
	print("")

	_test_procedure_detection(ce)
	_test_semantic_tokens(ce)
	_test_enclosing_procedure_range(ce)
	_test_scope_aware_highlight_data(ce)
	_test_change_tracking(ce)
	_test_code_folding(ce)
	_test_word_under_caret(ce)
	_test_mark_saved(ce)
	_test_rainbow_bracket_depth()
	_test_minimap_word_boundary()

	print("")
	print("══════════════════════════════════════════════")
	if _fail == 0:
		print("  ALL %d TESTS PASSED ✓" % _pass)
	else:
		print("  %d passed, %d FAILED ✗" % [_pass, _fail])
	print("══════════════════════════════════════════════")
	print("")

	ce.queue_free()
	quit()

# ─── Test 1: _is_procedure_start / _is_procedure_end ─────────────────────
func _test_procedure_detection(ce: VGCodeEdit) -> void:
	print("── Procedure Boundary Detection ──")
	_assert(ce._is_procedure_start("Private Sub Form_Load()"), "Private Sub detected")
	_assert(ce._is_procedure_start("Public Function GetScore(ByVal bonus As Integer) As Integer"),
			"Public Function detected")
	_assert(ce._is_procedure_start("Sub Main()"), "Sub Main detected")
	_assert(ce._is_procedure_start("Friend Static Function Calc() As Long"),
			"Friend Static Function detected")
	_assert(not ce._is_procedure_start("Dim x As Integer"), "Dim is not a proc start")
	_assert(not ce._is_procedure_start("' Sub Comment()"), "Comment is not a proc start")
	_assert(ce._is_procedure_end("End Sub"), "End Sub detected")
	_assert(ce._is_procedure_end("End Function"), "End Function detected")
	_assert(ce._is_procedure_end("  End Sub  "), "End Sub with whitespace detected")
	_assert(not ce._is_procedure_end("End If"), "End If is NOT a proc end")
	_assert(not ce._is_procedure_end("End"), "bare End is NOT a proc end")

# ─── Test 2: Semantic Token Parsing ───────────────────────────────────────
func _test_semantic_tokens(ce: VGCodeEdit) -> void:
	print("── Semantic Token Parsing ──")
	ce._parse_semantic_tokens()

	# Parameters: sender, e, bonus (from Sub/Function signatures)
	_assert(ce._semantic_params.has("sender"), "param 'sender' found")
	_assert(ce._semantic_params.has("e"), "param 'e' found")
	_assert(ce._semantic_params.has("bonus"), "param 'bonus' found")
	_assert(not ce._semantic_params.has("score"), "module var 'score' NOT in params")

	# Locals: localVar, tempStr, result (Dim inside procedures)
	_assert(ce._semantic_locals.has("localvar"), "local 'localvar' found")
	_assert(ce._semantic_locals.has("tempstr"), "local 'tempstr' found")
	_assert(ce._semantic_locals.has("result"), "local 'result' found")
	_assert(not ce._semantic_locals.has("score"), "module var 'Score' NOT in locals")

	# Module variables: Score, PlayerName (Dim/Public at module level)
	_assert(ce._semantic_module_vars.has("score"), "module var 'score' found")
	_assert(ce._semantic_module_vars.has("playername"), "module var 'playername' found")
	_assert(not ce._semantic_module_vars.has("localvar"), "local NOT in module vars")

	# Constants: MAX_LIVES
	_assert(ce._semantic_consts.has("max_lives"), "const 'max_lives' found")
	_assert(not ce._semantic_consts.has("score"), "'score' NOT in consts")

# ─── Test 3: Enclosing Procedure Range ───────────────────────────────────
func _test_enclosing_procedure_range(ce: VGCodeEdit) -> void:
	print("── Enclosing Procedure Range ──")

	# Line 0 = "Option Explicit" — outside any procedure
	var range_outside := ce._get_enclosing_procedure_range(0)
	_assert(range_outside.x == -1, "line 0 (Option Explicit) is outside a procedure")

	# Line 3 = "Const MAX_LIVES = 3" — outside any procedure
	var range_const := ce._get_enclosing_procedure_range(3)
	_assert(range_const.x == -1, "line 3 (Const) is outside a procedure")

	# Find the "Private Sub Form_Load" line and test inside it
	var form_load_line := -1
	for i in range(ce.get_line_count()):
		if ce.get_line(i).strip_edges().to_lower().begins_with("private sub form_load"):
			form_load_line = i
			break
	_assert(form_load_line >= 0, "Found Form_Load line at %d" % form_load_line)

	if form_load_line >= 0:
		# A line inside Form_Load body (form_load_line + 2 should be "localVar = Score + MAX_LIVES")
		var range_inside := ce._get_enclosing_procedure_range(form_load_line + 3)
		_assert(range_inside.x == form_load_line,
				"inside Form_Load: scope starts at line %d (expected %d)" % [range_inside.x, form_load_line])
		_assert(range_inside.y > form_load_line,
				"inside Form_Load: scope ends at line %d (after start)" % range_inside.y)

	# Find GetScore and test
	var getscore_line := -1
	for i in range(ce.get_line_count()):
		if ce.get_line(i).strip_edges().to_lower().begins_with("public function getscore"):
			getscore_line = i
			break
	_assert(getscore_line >= 0, "Found GetScore line at %d" % getscore_line)

	if getscore_line >= 0:
		var range_gs := ce._get_enclosing_procedure_range(getscore_line + 1)
		_assert(range_gs.x == getscore_line,
				"inside GetScore: scope starts at line %d" % range_gs.x)

# ─── Test 4: Scope-aware Highlight Data ──────────────────────────────────
func _test_scope_aware_highlight_data(ce: VGCodeEdit) -> void:
	print("── Scope-aware Highlight Data ──")
	# Verify that when highlighting a local variable, the semantic data
	# can correctly distinguish local vs module scope
	ce._parse_semantic_tokens()

	var is_local_localvar := ce._semantic_locals.has("localvar") or ce._semantic_params.has("localvar")
	_assert(is_local_localvar, "'localvar' is classified as local/param (scope-restricted)")

	var is_local_score := ce._semantic_locals.has("score") or ce._semantic_params.has("score")
	_assert(not is_local_score, "'score' is NOT local/param (module-wide highlight)")

	# Constants should also highlight everywhere (not scope-restricted)
	var is_local_maxlives := ce._semantic_locals.has("max_lives") or ce._semantic_params.has("max_lives")
	_assert(not is_local_maxlives, "'max_lives' is NOT local/param (const, file-wide)")

# ─── Test 5: Change Tracking Gutter ──────────────────────────────────────
func _test_change_tracking(ce: VGCodeEdit) -> void:
	print("── Change Tracking Gutter ──")

	# Capture the initial baseline
	ce._capture_change_base()
	_assert(ce._change_base_set, "change base is set after capture")
	_assert(ce._change_base_lines.size() > 0, "base lines array is populated")

	var original_line_0 := ce._change_base_lines[0]
	_assert(original_line_0 == ce.get_line(0), "base line 0 matches current text")

	# Modify a line — change tracking should detect the difference
	var old_text := ce.get_line(2)
	ce.set_line(2, "Dim ModifiedVar As Long")
	_assert(ce.get_line(2) != ce._change_base_lines[2],
			"after edit, line 2 differs from base (yellow bar)")

	# mark_saved: saved lines should now capture the modified state
	ce.mark_saved()
	_assert(ce._change_saved_lines[2] == "Dim ModifiedVar As Long",
			"after mark_saved, saved line 2 reflects edit")

	# Restore original line
	ce.set_line(2, old_text)

# ─── Test 6: Code Folding ────────────────────────────────────────────────
func _test_code_folding(ce: VGCodeEdit) -> void:
	print("── Code Folding ──")

	# Ensure folding is enabled — the correct property name is "line_folding"
	ce.set("line_folding", true)
	ce.indent_size = 4
	ce.indent_use_spaces = false
	# Forcibly re-set the text so CodeEdit recalculates indent levels
	var code_copy := ce.text
	ce.text = ""
	ce.text = code_copy

	# First unfold everything
	ce.unfold_all()

	# Count procedure-start lines that can_fold_line() reports as foldable
	var foldable_count := 0
	for i in range(ce.get_line_count()):
		if ce._is_procedure_start(ce.get_line(i).strip_edges()) and ce.can_fold_line(i):
			foldable_count += 1
	_assert(foldable_count >= 3,
			"found %d foldable procedure lines (expected 3: Form_Load, GetScore, cmdReset)" % foldable_count)

	# Fold all procedures and verify they actually fold
	ce.fold_all_procedures()
	var folded_count := 0
	for i in range(ce.get_line_count()):
		if ce.is_line_folded(i):
			folded_count += 1
	_assert(folded_count >= 3, "fold_all_procedures folded %d lines (expected 3)" % folded_count)

	# Unfold all and verify nothing remains folded
	ce.unfold_all()
	var still_folded := 0
	for i in range(ce.get_line_count()):
		if ce.is_line_folded(i):
			still_folded += 1
	_assert(still_folded == 0, "unfold_all: no lines remain folded")

	# Verify that fold_all_procedures only targets proc-start lines (logic test)
	_assert(ce._is_procedure_start("Private Sub Form_Load(ByVal sender As Object, ByRef e As EventArgs)"),
			"Form_Load line is a valid fold target")
	_assert(not ce._is_procedure_start("End Sub"),
			"End Sub is NOT a fold target")

# ─── Test 7: Get Word Under Caret ────────────────────────────────────────
func _test_word_under_caret(ce: VGCodeEdit) -> void:
	print("── Word Under Caret ──")

	# Position caret on "Score" in "Dim Score As Integer" (line 2)
	# "Dim Score As Integer" -> "Score" starts at col 4
	var target_line := -1
	for i in range(ce.get_line_count()):
		if ce.get_line(i).strip_edges().to_lower().begins_with("dim score"):
			target_line = i
			break
	if target_line >= 0:
		var col_of_score := ce.get_line(target_line).to_lower().find("score")
		ce.set_caret_line(target_line)
		ce.set_caret_column(col_of_score + 2)  # Middle of "Score"
		var word := ce._get_word_under_caret()
		_assert(word.to_lower() == "score", "word under caret is 'score' (got '%s')" % word)
	else:
		_assert(false, "Could not find 'Dim Score' line")

	# Position on empty area (beginning of blank line or end-of-line)
	ce.set_caret_line(0)
	ce.set_caret_column(0)
	# "Option Explicit" -> caret at 0 should get "Option"
	var word2 := ce._get_word_under_caret()
	_assert(word2 == "Option", "word at col 0 of 'Option Explicit' is '%s'" % word2)

# ─── Test 8: Mark Saved State ────────────────────────────────────────────
func _test_mark_saved(ce: VGCodeEdit) -> void:
	print("── Mark Saved ──")

	# Re-capture base from current text
	ce._capture_change_base()

	var line5_orig := ce.get_line(5)
	ce.set_line(5, "' Modified comment")

	# Before save: current != base
	_assert(ce.get_line(5) != ce._change_base_lines[5],
			"modified line differs from base (unsaved)")

	# Save
	ce.mark_saved()
	_assert(ce._change_saved_lines[5] == "' Modified comment",
			"saved lines updated after mark_saved")

	# Now the line matches saved but differs from base → green bar territory
	_assert(ce.get_line(5) == ce._change_saved_lines[5],
			"current matches saved (green bar)")
	_assert(ce.get_line(5) != ce._change_base_lines[5],
			"current differs from base (was modified)")

	# Restore
	ce.set_line(5, line5_orig)

# ─── Test 9: Rainbow Bracket Depth Logic ─────────────────────────────────
func _test_rainbow_bracket_depth() -> void:
	print("── Rainbow Bracket Depth Logic ──")
	# Test the depth-counting algorithm used by _draw_rainbow_brackets
	# We replicate the pre-scan logic on a string to verify depth tracking
	var test_line := 'MsgBox(Trim(Left("Hello", Len(x))))'
	var depth := 0
	var max_depth := 0
	var in_str := false
	for ch in test_line:
		if ch == "\"":
			in_str = not in_str
			continue
		if ch == "'" and not in_str:
			break
		if in_str:
			continue
		if ch == "(":
			depth += 1
			max_depth = maxi(max_depth, depth)
		elif ch == ")":
			depth = maxi(0, depth - 1)

	_assert(max_depth == 4, "nested brackets reach depth 4 (got %d)" % max_depth)
	_assert(depth == 0, "brackets balance to 0 at end (got %d)" % depth)

	# Test string-skip: brackets inside strings should not count
	var str_line := '"()()()" & x'
	depth = 0
	in_str = false
	for ch in str_line:
		if ch == "\"":
			in_str = not in_str
			continue
		if ch == "'" and not in_str:
			break
		if in_str:
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(0, depth - 1)
	_assert(depth == 0, "brackets inside string are ignored (depth=%d)" % depth)

	# Test comment-skip: brackets after ' should not count
	var comment_line := "x = 1 ' (((("
	depth = 0
	in_str = false
	for ch in comment_line:
		if ch == "\"":
			in_str = not in_str
			continue
		if ch == "'" and not in_str:
			break
		if in_str:
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(0, depth - 1)
	_assert(depth == 0, "brackets after comment marker are ignored (depth=%d)" % depth)

# ─── Test 10: Minimap Word Boundary Logic ────────────────────────────────
func _test_minimap_word_boundary() -> void:
	print("── Minimap Word Boundary Logic ──")
	# The minimap marker checks whole-word boundaries before drawing a marker
	var hw := "score"
	var hw_len := hw.length()

	# Case 1: exact match surrounded by spaces
	var line1 := "    Score = 10"
	var line1_lower := line1.to_lower()
	var found1 := line1_lower.find(hw)
	var before_ok1 := (found1 == 0) or not _is_word_ch(line1[found1 - 1])
	var after_pos1 := found1 + hw_len
	var after_ok1 := (after_pos1 >= line1.length()) or not _is_word_ch(line1[after_pos1])
	_assert(found1 >= 0 and before_ok1 and after_ok1, "'Score' whole-word match in '    Score = 10'")

	# Case 2: partial match should NOT match (e.g. "HighScore")
	var line2 := "Dim HighScore As Integer"
	var line2_lower := line2.to_lower()
	var found2 := line2_lower.find(hw)
	var whole_word2 := false
	if found2 >= 0:
		var bk2 := (found2 == 0) or not _is_word_ch(line2[found2 - 1])
		var ap2 := found2 + hw_len
		var ak2 := (ap2 >= line2.length()) or not _is_word_ch(line2[ap2])
		whole_word2 = bk2 and ak2
	_assert(not whole_word2, "'score' inside 'HighScore' does NOT whole-word match")

	# Case 3: match at end of line
	var line3 := "x = Score"
	var line3_lower := line3.to_lower()
	var found3 := line3_lower.find(hw)
	var whole_word3 := false
	if found3 >= 0:
		var bk3 := (found3 == 0) or not _is_word_ch(line3[found3 - 1])
		var ap3 := found3 + hw_len
		var ak3 := (ap3 >= line3.length()) or not _is_word_ch(line3[ap3])
		whole_word3 = bk3 and ak3
	_assert(whole_word3, "'Score' at end of line matches")

# Helper matching VGCodeEdit._is_word_char
func _is_word_ch(ch: String) -> bool:
	var o := ch.unicode_at(0)
	return (o >= 65 and o <= 90) or (o >= 97 and o <= 122) or \
		   (o >= 48 and o <= 57) or o == 95

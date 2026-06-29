## Bug #4 regression test: _get_tscn_connection_method parses existing
## [connection] lines from .tscn files correctly.
##
## The double-click handler must read signal connections BEFORE save_form()
## rewrites the file. This test validates the parsing logic that extracts
## method names from [connection] lines — the same algorithm used in
## visual_gasic_plugin.gd::_get_tscn_connection_method().
##
## Run:  bash tests/run_gd_tests.sh test_tscn_connection_preserve.gd
extends SceneTree

var _pass := 0
var _fail := 0

func _init() -> void:
	_test_parse_simple_connection()
	_test_parse_nested_path_connection()
	_test_parse_no_match_returns_empty()
	_test_parse_ignores_connections_to_other_nodes()
	_test_parse_multiple_controls_returns_first_match()
	print("")
	print("RESULTS: %d/%d passed, %d failed" % [_pass, _pass + _fail, _fail])
	quit(0 if _fail == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("PASS: ", msg)
	else:
		_fail += 1
		print("FAIL: ", msg)


## Replicates the parsing logic from visual_gasic_plugin.gd::_get_tscn_connection_method
func _get_tscn_connection_method(tscn_text: String, ctrl_name: String) -> String:
	for line in tscn_text.split("\n"):
		var stripped := line.strip_edges()
		if not stripped.begins_with("[connection "):
			continue
		var from_match := false
		var from_idx := stripped.find("from=\"")
		if from_idx >= 0:
			var from_start := from_idx + 6
			var from_end := stripped.find("\"", from_start)
			if from_end > from_start:
				var from_val := stripped.substr(from_start, from_end - from_start)
				if from_val == ctrl_name or from_val.ends_with("/" + ctrl_name):
					from_match = true
		if not from_match:
			continue
		if stripped.find("to=\".\"") < 0:
			continue
		var method_idx := stripped.find("method=\"")
		if method_idx < 0:
			continue
		var method_start := method_idx + 8
		var method_end := stripped.find("\"", method_start)
		if method_end > method_start:
			return stripped.substr(method_start, method_end - method_start)
	return ""


func _test_parse_simple_connection() -> void:
	var tscn := """[gd_scene format=3]
[node name="Form1" type="Control"]
[connection signal="pressed" from="btnOK" to="." method="btnOK_Click"]
"""
	var result := _get_tscn_connection_method(tscn, "btnOK")
	_assert(result == "btnOK_Click", "simple connection: got '%s'" % result)


func _test_parse_nested_path_connection() -> void:
	var tscn := """[gd_scene format=3]
[node name="Form1" type="Control"]
[connection signal="pressed" from="Shell/Row/btnSave" to="." method="btnSave_Click"]
"""
	var result := _get_tscn_connection_method(tscn, "btnSave")
	_assert(result == "btnSave_Click", "nested path connection: got '%s'" % result)


func _test_parse_no_match_returns_empty() -> void:
	var tscn := """[gd_scene format=3]
[node name="Form1" type="Control"]
[connection signal="pressed" from="btnOK" to="." method="btnOK_Click"]
"""
	var result := _get_tscn_connection_method(tscn, "btnCancel")
	_assert(result == "", "no match returns empty: got '%s'" % result)


func _test_parse_ignores_connections_to_other_nodes() -> void:
	# to="SomeOtherNode" should be ignored — only to="." is relevant
	var tscn := """[gd_scene format=3]
[node name="Form1" type="Control"]
[connection signal="pressed" from="btnOK" to="SomeOtherNode" method="wrong_handler"]
[connection signal="pressed" from="btnOK" to="." method="btnOK_Click"]
"""
	var result := _get_tscn_connection_method(tscn, "btnOK")
	_assert(result == "btnOK_Click", "ignores to=other: got '%s'" % result)


func _test_parse_multiple_controls_returns_first_match() -> void:
	var tscn := """[gd_scene format=3]
[node name="Form1" type="Control"]
[connection signal="pressed" from="btnOK" to="." method="btnOK_Click"]
[connection signal="text_changed" from="txtName" to="." method="txtName_Change"]
"""
	var result1 := _get_tscn_connection_method(tscn, "btnOK")
	var result2 := _get_tscn_connection_method(tscn, "txtName")
	_assert(result1 == "btnOK_Click", "multi: btnOK got '%s'" % result1)
	_assert(result2 == "txtName_Change", "multi: txtName got '%s'" % result2)

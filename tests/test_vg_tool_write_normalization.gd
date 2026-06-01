@tool
extends SceneTree

## Smoke test for _normalize_vg_for_form (vg_ai_tools.gd).
##
## Reproduces the test16 failure mode:
##   AI wrote a .vg via the `write_file` tool with:
##     - Class Form1 / Inherits Form / End Class wrapper
##     - VB6 alias names (TextBox1, Command1) instead of Godot
##       names (LineEdit1, Button1)
## Verifies the normalizer strips the wrapper and remaps names
## even with no live form designer (so the source-only path works).

func _initialize() -> void:
	var script := load("res://addons/visual_gasic/vg_ai_tools.gd")
	if script == null:
		push_error("Could not load vg_ai_tools.gd")
		quit(1)
		return
	var tools = script.new()
	# Without a live FormDesigner the alias map is empty, but the
	# Class/Inherits stripper must still work.
	var bad := """' Form1
Class Form1
    Inherits Form

    ' Event handler for Command1 button click
    Sub Command1_Click()
        TextBox1.Text = "Hello World"
    End Sub

End Class
"""
	var fixed: String = tools._normalize_vg_source(bad, {})
	var ok := true
	if fixed.findn("Class Form1") != -1:
		push_error("FAIL: Class wrapper not stripped:\n" + fixed)
		ok = false
	else:
		print("✓ Class wrapper stripped")
	if fixed.findn("Inherits Form") != -1:
		push_error("FAIL: Inherits line not stripped:\n" + fixed)
		ok = false
	else:
		print("✓ Inherits line stripped")
	if fixed.findn("End Class") != -1:
		push_error("FAIL: End Class not stripped:\n" + fixed)
		ok = false
	else:
		print("✓ End Class stripped")
	if fixed.findn("Sub Command1_Click()") == -1:
		push_error("FAIL: body lost during strip:\n" + fixed)
		ok = false
	else:
		print("✓ event handler body preserved")
	# Verify idempotence — running again must be a no-op.
	var twice: String = tools._normalize_vg_source(fixed, {})
	if twice != fixed:
		push_error("FAIL: normalizer not idempotent")
		ok = false
	else:
		print("✓ idempotent")
	# Verify alias remap works with an explicit map.
	var alias_map := {"TextBox1": "LineEdit1", "Command1": "Button1"}
	var remapped: String = tools._normalize_vg_source(bad, alias_map)
	if remapped.find("TextBox1.Text") != -1:
		push_error("FAIL: TextBox1 not remapped:\n" + remapped)
		ok = false
	elif remapped.find("LineEdit1.Text") == -1:
		push_error("FAIL: LineEdit1.Text missing after remap:\n" + remapped)
		ok = false
	else:
		print("✓ TextBox1 → LineEdit1 remap")
	if remapped.find("Command1_Click") != -1:
		push_error("FAIL: Command1 not remapped:\n" + remapped)
		ok = false
	elif remapped.find("Button1_Click") == -1:
		push_error("FAIL: Button1_Click missing after remap:\n" + remapped)
		ok = false
	else:
		print("✓ Command1 → Button1 remap")
	# Verify Text1 → LineEdit1 (insert_text bypass landmine from test18).
	var text1_src := """' Form1
Option Explicit

Private Sub Command1_Click()
    Text1.Text = "Hello World"
End Sub
"""
	var text1_map := {"Text1": "LineEdit1", "Command1": "Button1"}
	var text1_fixed: String = tools._normalize_vg_source(text1_src, text1_map)
	if text1_fixed.find("Text1.Text") != -1:
		push_error("FAIL: Text1 not remapped:\n" + text1_fixed)
		ok = false
	elif text1_fixed.find("LineEdit1.Text") == -1:
		push_error("FAIL: LineEdit1.Text missing:\n" + text1_fixed)
		ok = false
	else:
		print("✓ Text1 → LineEdit1 remap")
	# Verify duplicate Option Explicit / header collapsed.
	var dup_src := """' Form1
Option Explicit

Private Sub Command1_Click()
    Text1.Text = "Hello World"
End Sub
' Visual Gasic Form Script
Option Explicit
"""
	var dup_fixed: String = tools._normalize_vg_source(dup_src, {})
	var opt_count := 0
	for ln in dup_fixed.split("\n"):
		if ln.strip_edges().to_lower() == "option explicit":
			opt_count += 1
	if opt_count != 1:
		push_error("FAIL: expected 1 Option Explicit, got %d:\n%s" % [opt_count, dup_fixed])
		ok = false
	else:
		print("✓ duplicate Option Explicit collapsed")
	if ok:
		print("[PASS] test_vg_tool_write_normalization.gd")
		quit(0)
	else:
		print("[FAIL] test_vg_tool_write_normalization.gd")
		quit(1)

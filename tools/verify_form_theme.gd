extends SceneTree

var _instances: Array = []
var _pass_count: int = 0
var _fail_count: int = 0
var _frame_count: int = 0

func _init():
	print("=== VB6 Form Theme Verification (form_editor_helper) ===")
	print("")
	var forms = ["res://Form4.tscn", "res://Form3.tscn", "res://Form2.tscn",
	             "res://Form1.tscn", "res://MyCalculator.tscn"]

	for form_path in forms:
		if not ResourceLoader.exists(form_path):
			print("SKIP: ", form_path, " not found")
			continue
		var packed = ResourceLoader.load(form_path, "PackedScene")
		if packed:
			var inst = packed.instantiate()
			if inst:
				root.add_child(inst)
				_instances.append({"path": form_path, "instance": inst})

func _process(_delta):
	_frame_count += 1
	if _frame_count < 3:
		return

	for entry in _instances:
		var form_path = entry["path"]
		var instance = entry["instance"]
		print("-- Testing: ", form_path, " --")

		var theme = instance.theme
		if not theme:
			print("  FAIL: theme is null!")
			_fail_count += 1
			continue

		var btn_sb = theme.get_stylebox("normal", "Button") as StyleBoxFlat
		var le_sb = theme.get_stylebox("normal", "LineEdit") as StyleBoxFlat
		var panel_sb = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

		if not btn_sb or not le_sb or not panel_sb:
			print("  FAIL: Missing styleboxes")
			_fail_count += 1
			continue

		var btn_ok = btn_sb.bg_color.is_equal_approx(Color(0.831, 0.816, 0.784))
		var le_ok = le_sb.bg_color.is_equal_approx(Color(1, 1, 1))
		var panel_ok = panel_sb.bg_color.is_equal_approx(Color(0.753, 0.753, 0.753))
		var text_ok = theme.get_color("font_color", "Label").is_equal_approx(Color(0, 0, 0))

		print("  Button bg=#D4D0C8: ", btn_ok)
		print("  LineEdit bg=white: ", le_ok)
		print("  Panel bg=#C0C0C0: ", panel_ok)
		print("  Label text=black: ", text_ok)

		if btn_ok and le_ok and panel_ok and text_ok:
			print("  PASS")
			_pass_count += 1
		else:
			print("  FAIL")
			_fail_count += 1

	for entry in _instances:
		entry["instance"].queue_free()

	print("")
	print("=== Results: ", _pass_count, " passed, ", _fail_count, " failed ===")
	if _fail_count == 0 and _pass_count > 0:
		print("ALL TESTS PASSED")
	else:
		print("SOME TESTS FAILED")
	quit()

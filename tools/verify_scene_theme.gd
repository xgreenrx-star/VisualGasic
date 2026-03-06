## Headless verification: Load a VG form .tscn, apply the VB6 scene theme
## via GDScript (same code as the plugin), and verify the theme is correct.
##
## Usage:  Godot --headless --script tools/verify_scene_theme.gd
## Run from the examples/my-calculator project directory.

extends SceneTree

func _init():
	print("=== VB6 Scene Theme Verification ===")
	print("")

	# ── Build the VB6 Scene Theme (same logic as _build_vb6_scene_theme) ──
	var t = Theme.new()

	var btn_face     := Color(0.831, 0.816, 0.784)
	var btn_shadow   := Color(0.51, 0.51, 0.51)
	var dark_shadow  := Color(0.25, 0.25, 0.25)
	var win_bg       := Color(1.0, 1.0, 1.0)
	var win_text     := Color(0.0, 0.0, 0.0)
	var form_bg      := Color(0.753, 0.753, 0.753)
	var scrollbar_bg := Color(0.87, 0.87, 0.87)
	var progress_fill:= Color(0.0, 0.5, 0.0)
	var placeholder  := Color(0.6, 0.6, 0.6)
	var title_bg     := Color(0.0, 0.0, 0.5)
	var title_text   := Color(1.0, 1.0, 1.0)
	var disabled_text:= Color(0.51, 0.51, 0.51)

	# Button normal
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = btn_face
	btn_normal.border_color = Color(0.6, 0.6, 0.6)
	btn_normal.set_border_width_all(2)
	btn_normal.set_content_margin_all(4)
	t.set_stylebox("normal", "Button", btn_normal)

	# LineEdit normal
	var le_normal = StyleBoxFlat.new()
	le_normal.bg_color = win_bg
	le_normal.border_color = btn_shadow
	le_normal.set_border_width_all(2)
	le_normal.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_normal)

	# Panel
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = form_bg
	t.set_stylebox("panel", "Panel", panel_sb)

	# Colors
	t.set_color("font_color", "Button", win_text)
	t.set_color("font_color", "LineEdit", win_text)
	t.set_color("font_color", "Label", win_text)

	print("Theme built successfully!")
	print("  Button/normal stylebox bg_color: ", t.get_stylebox("normal", "Button").bg_color)
	print("  LineEdit/normal stylebox bg_color: ", t.get_stylebox("normal", "LineEdit").bg_color)
	print("  Panel/panel stylebox bg_color: ", t.get_stylebox("panel", "Panel").bg_color)
	print("  Button font_color: ", t.get_color("font_color", "Button"))
	print("  Label font_color: ", t.get_color("font_color", "Label"))

	# ── Load form scenes and apply theme ──
	var forms = ["res://Form3.tscn", "res://Form2.tscn", "res://Form1.tscn", "res://MyCalculator.tscn"]
	var pass_count = 0
	var fail_count = 0

	for form_path in forms:
		if not ResourceLoader.exists(form_path):
			print("\n⚠ SKIP: ", form_path, " not found")
			continue

		print("\n── Testing: ", form_path, " ──")
		var packed = ResourceLoader.load(form_path, "PackedScene")
		if not packed:
			print("  ✗ FAIL: Could not load PackedScene")
			fail_count += 1
			continue

		var instance = packed.instantiate()
		if not instance:
			print("  ✗ FAIL: Could not instantiate")
			fail_count += 1
			continue

		# Check it's a Window with _FormBackground
		var is_vg_form = instance is Window and instance.has_node("_FormBackground")
		print("  Is VG form: ", is_vg_form, "  (", instance.get_class(), ", has _FormBackground: ", instance.has_node("_FormBackground"), ")")

		if is_vg_form:
			# Apply theme to scene root (same as _apply_vb6_theme_to_scene_root)
			instance.theme = t
			print("  Theme applied to scene root!")

			# Verify theme is accessible from scene root
			var root_theme = instance.theme
			if root_theme:
				var btn_sb = root_theme.get_stylebox("normal", "Button")
				var le_sb = root_theme.get_stylebox("normal", "LineEdit")
				var p_sb = root_theme.get_stylebox("panel", "Panel")

				print("  Root theme has Button/normal: ", btn_sb != null)
				print("  Root theme has LineEdit/normal: ", le_sb != null)
				print("  Root theme has Panel/panel: ", p_sb != null)

				if btn_sb and le_sb and p_sb:
					var btn_ok = btn_sb.bg_color.is_equal_approx(btn_face)
					var le_ok = le_sb.bg_color.is_equal_approx(win_bg)
					var p_ok = p_sb.bg_color.is_equal_approx(form_bg)
					print("  Button bg_color correct: ", btn_ok, " (", btn_sb.bg_color, " vs ", btn_face, ")")
					print("  LineEdit bg_color correct: ", le_ok, " (", le_sb.bg_color, " vs ", win_bg, ")")
					print("  Panel bg_color correct: ", p_ok, " (", p_sb.bg_color, " vs ", form_bg, ")")

					if btn_ok and le_ok and p_ok:
						print("  ✓ PASS")
						pass_count += 1
					else:
						print("  ✗ FAIL: Color mismatch")
						fail_count += 1
				else:
					print("  ✗ FAIL: Missing styleboxes")
					fail_count += 1
			else:
				print("  ✗ FAIL: theme is null after assignment!")
				fail_count += 1

			# Check children get the theme through inheritance
			print("  Children: ", instance.get_child_count())
			for ci in instance.get_child_count():
				var child = instance.get_child(ci)
				print("    [", ci, "] ", child.name, " (", child.get_class(), ")")
		else:
			print("  ✗ FAIL: Not a VG form")
			fail_count += 1

		instance.queue_free()

	print("\n=== Results: ", pass_count, " passed, ", fail_count, " failed ===")
	if fail_count == 0 and pass_count > 0:
		print("ALL TESTS PASSED ✓")
	elif pass_count == 0:
		print("NO TESTS RAN")
	else:
		print("SOME TESTS FAILED ✗")

	quit()

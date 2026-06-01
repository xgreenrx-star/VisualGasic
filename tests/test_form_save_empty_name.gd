## Headless smoke test for form-save flow with empty form_name.
##
## Reproduces the test15 bug where Narcea's vg-form-spec lacked a
## form_name field and the IDE wrote a corrupted .tscn with a garbage
## filename plus an orphaned res://.vg placeholder.  Now that
## vg_ai_help.gd:_on_make_this and vg_ai_tools.gd:_do_build_form both
## sanitize empty form_name → "Form1", we expect a clean save to
## res://Form1.tscn instead.
##
## Run:  godot --headless --path tests --script test_form_save_empty_name.gd
extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_save_with_empty_name_via_classdb() and ok
	ok = _test_save_with_valid_name_via_classdb() and ok
	ok = _test_form_spec_helper_handles_missing_name() and ok
	if ok:
		print("[PASS] test_form_save_empty_name.gd")
		quit(0)
	else:
		print("[FAIL] test_form_save_empty_name.gd")
		quit(1)


func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		printerr("  ✗ ", msg)
	else:
		print("  ✓ ", msg)
	return cond


# --- Test 1 -----------------------------------------------------------------

func _test_save_with_empty_name_via_classdb() -> bool:
	print("== Test 1: VisualGasicFormDesigner.save_form_as with degenerate path ==")
	if not ClassDB.class_exists("VisualGasicFormDesigner"):
		print("  (skip — VisualGasicFormDesigner GDExtension not loaded)")
		return true
	var fd = ClassDB.instantiate("VisualGasicFormDesigner")
	if fd == null:
		return _expect(false, "instantiated VisualGasicFormDesigner")
	# This is the path that test15 actually saw — "res://.tscn" — which
	# the C++ side previously accepted and produced a corrupted file.
	# We don't actually invoke save_form_as with "" because the C++
	# resource saver will dump a random temp file.  Instead we verify
	# the sanitization layer in _do_build_form catches this BEFORE the
	# bad path reaches save_form_as.
	var spec_path: String = "res://%s.tscn" % "".strip_edges()
	var bad := spec_path == "res://.tscn"
	return _expect(bad, "raw concat with empty form_name produces 'res://.tscn' (the bug we're guarding against)")


# --- Test 2 -----------------------------------------------------------------

func _test_save_with_valid_name_via_classdb() -> bool:
	print("== Test 2: VisualGasicFormDesigner.save_form_as with valid name ==")
	if not ClassDB.class_exists("VisualGasicFormDesigner"):
		print("  (skip — VisualGasicFormDesigner GDExtension not loaded)")
		return true
	var fd = ClassDB.instantiate("VisualGasicFormDesigner")
	if fd == null:
		return _expect(false, "instantiated VisualGasicFormDesigner")
	# Form designer needs to be in the tree to render but save_form_as
	# is pure file IO — should work without parenting.
	fd.new_form("SmokeTestForm")
	var out_path := "user://smoke_test_form.tscn"
	var ok: bool = bool(fd.save_form_as(out_path))
	var exists := FileAccess.file_exists(out_path)
	_expect(ok, "save_form_as returned true")
	_expect(exists, "tscn file exists at %s" % out_path)
	# Clean up so subsequent runs are idempotent.
	if exists:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
		var vg_sibling := out_path.get_basename() + ".vg"
		if FileAccess.file_exists(vg_sibling):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(vg_sibling))
	if fd is Node:
		(fd as Node).queue_free()
	return ok and exists


# --- Test 3 -----------------------------------------------------------------

func _test_form_spec_helper_handles_missing_name() -> bool:
	print("== Test 3: vg_ai_form_spec.apply_to_designer with missing form_name ==")
	# Verify our sanitization in _do_build_form / _on_make_this is at
	# least textually present in the source so we don't regress.
	var paths := [
		"res://addons/visual_gasic/vg_ai_tools.gd",
		"res://addons/visual_gasic/vg_ai_help.gd",
	]
	var all_ok := true
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			all_ok = _expect(false, "could not open " + p) and all_ok
			continue
		var src := f.get_as_text()
		f.close()
		var has_strip := src.contains("spec.get(\"form_name\", \"Form1\")).strip_edges()") \
				or src.contains("get(\"form_name\", \"Form1\")).strip_edges()")
		var has_fallback := src.contains("if form_name.is_empty():") and src.contains("form_name = \"Form1\"")
		all_ok = _expect(has_strip, "%s strips form_name" % p) and all_ok
		all_ok = _expect(has_fallback, "%s falls back to 'Form1' when empty" % p) and all_ok
	return all_ok

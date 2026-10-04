extends SceneTree
## Headless checks for Vector Editor data sync / insert / resolve parity.

func _init() -> void:
	var ok := true
	const Sync := preload("res://addons/visual_gasic/vg_vector_data_sync.gd")
	const Resolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
	const Vgv := preload("res://addons/visual_gasic/vg_vgv_resolver.gd")

	var edit := CodeEdit.new()
	root.add_child(edit)
	edit.text = """Option Explicit

Sub _Ready()
End Sub
"""

	var inserted := Sync.insert_new_block(edit, 2, "ArrowVector", 64, 64, 4)
	if not bool(inserted.get("ok", false)):
		push_error("insert_new_block failed: %s" % str(inserted))
		ok = false
	var sec: Dictionary = inserted.get("section", {})
	if sec.is_empty():
		push_error("insert_new_block returned empty section")
		ok = false
	elif str(sec.get("label", "")) != "ArrowVector":
		push_error("expected label ArrowVector, got %s" % str(sec.get("label", "")))
		ok = false

	var blocks: Array = Resolver.enumerate_blocks(edit.text)
	if blocks.is_empty():
		push_error("enumerate_blocks empty after insert\n" + edit.text)
		ok = false

	var shapes: Array = (sec.get("shapes", []) as Array).duplicate(true)
	if shapes.is_empty():
		push_error("expected default shape after insert")
		ok = false
	else:
		shapes.append({
			"type": "RECT",
			"points": PackedVector2Array([Vector2(8, 8), Vector2(40, 40)]),
			"stroke_r": 255, "stroke_g": 0, "stroke_b": 0, "stroke_a": 255, "stroke_w": 1.0,
		})
		if not Sync.apply_shapes(edit, sec, shapes):
			push_error("apply_shapes failed")
			ok = false
		var live := Resolver.resolve_at_line(edit.text, int(sec.get("label_line", 0)))
		if live.is_empty():
			push_error("resolve after apply_shapes failed\n" + edit.text)
			ok = false
		elif (live.get("shapes", []) as Array).size() != 2:
			push_error("expected 2 shapes after apply, got %d\n%s" % [
				(live.get("shapes", []) as Array).size(), edit.text
			])
			ok = false
		else:
			sec = live

	var model := {
		"view_w": int(sec.get("view_w", 64)),
		"view_h": int(sec.get("view_h", 64)),
		"grid_step": int(sec.get("grid_step", 4)),
		"shapes": sec.get("shapes", []),
	}
	var txt: String = Vgv.serialize(model)
	var parsed: Dictionary = Vgv.parse_text(txt)
	if parsed.is_empty():
		push_error("vgv parse_text failed")
		ok = false
	elif (parsed.get("shapes", []) as Array).size() != (sec.get("shapes", []) as Array).size():
		push_error("vgv round-trip shape count mismatch")
		ok = false

	var bad := Sync.validate_new_label(edit.text, "ArrowVector")
	if bad.is_empty():
		push_error("validate_new_label should reject duplicate ArrowVector")
		ok = false

	if ok:
		print("VECTOR_EDITOR_UX_OK")
		quit(0)
	else:
		print("VECTOR_EDITOR_UX_FAIL")
		quit(1)

extends SceneTree
## Headless checks for vg_sprite_data_ux helpers (migrate / draw stubs / DataToArray scan).

func _init() -> void:
	var ok := true
	const Ux := preload("res://addons/visual_gasic/vg_sprite_data_ux.gd")
	const Sync := preload("res://addons/visual_gasic/vg_sprite_data_sync.gd")
	const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")

	var edit := CodeEdit.new()
	root.add_child(edit)
	edit.text = """Option Explicit

CloudSprite:
Data 2, 2, 0, 0
Data 1, 1
Data 1, 1

Sub _Ready()
End Sub

Sub _Draw()
End Sub
"""
	var migrated := Ux.migrate_sprite_indents(edit)
	if migrated < 1:
		push_error("expected migrate_sprite_indents >= 1, got %d" % migrated)
		ok = false
	if not edit.get_line(3).begins_with("\t"):
		push_error("header Data row should be indented after migrate: '%s'" % edit.get_line(3))
		ok = false

	var vars0 := Ux.find_data_to_array_vars(edit.text, "CloudSprite")
	if vars0.size() != 0:
		push_error("expected no DataToArray vars yet")
		ok = false

	var wired := Ux.insert_draw_helpers(edit, "CloudSprite", 3)
	if not bool(wired.get("ok", false)):
		push_error("insert_draw_helpers failed: %s" % str(wired))
		ok = false
	var vars1 := Ux.find_data_to_array_vars(edit.text, "CloudSprite")
	if vars1.is_empty():
		push_error("expected DataToArray var after insert helpers\n" + edit.text)
		ok = false
	if edit.text.findn("DrawDataSprite") < 0:
		push_error("expected DrawDataSprite after insert helpers\n" + edit.text)
		ok = false

	var lit := Ux.build_array_literal({
		"w": 2, "h": 2, "transparent": 0, "palette_id": 0,
		"pixels": PackedInt32Array([1, 1, 1, 1]),
	})
	if not lit.begins_with("Array(2, 2, 0, 0"):
		push_error("bad array literal: " + lit)
		ok = false

	var sec := {}
	for b in Resolver.enumerate_blocks(edit.text):
		if str(b.get("label", "")) == "CloudSprite":
			sec = Resolver.resolve_at_line(edit.text, int(b.get("label_line", 0)))
			break
	if sec.is_empty():
		push_error("could not resolve CloudSprite after helpers\n" + edit.text)
		ok = false
	else:
		var pixels := PackedInt32Array([2, 2, 2, 2])
		if not Sync.apply_section(edit, sec, pixels, 2, 2, 0, 0):
			push_error("apply_section failed")
			ok = false
		var header_line := -1
		for b2 in Resolver.enumerate_blocks(edit.text):
			if str(b2.get("label", "")) == "CloudSprite":
				header_line = int(b2.get("header_line", -1))
				break
		if header_line >= 0 and not edit.get_line(header_line).begins_with("\t"):
			push_error("apply_section should keep Data indented: '%s'" % edit.get_line(header_line))
			ok = false

	if ok:
		print("SPRITE_DATA_UX_OK")
		quit(0)
	else:
		print("SPRITE_DATA_UX_FAIL")
		quit(1)

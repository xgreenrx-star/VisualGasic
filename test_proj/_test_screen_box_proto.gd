extends SceneTree
## Headless check that ScreenBox prototype carries the host meta.

func _init() -> void:
	var ok := true
	var packed := load("res://addons/visual_gasic/prototypes/ScreenBox.tscn") as PackedScene
	if packed == null:
		push_error("ScreenBox.tscn missing")
		ok = false
	else:
		var node := packed.instantiate()
		if node == null or not (node is TextureRect):
			push_error("ScreenBox root must be TextureRect")
			ok = false
		else:
			var tr := node as TextureRect
			if not tr.has_meta("vg_screen_box") or not bool(tr.get_meta("vg_screen_box")):
				push_error("ScreenBox missing metadata/vg_screen_box")
				ok = false
			if str(tr.get_meta("vg_control_type", "")) != "ScreenBox":
				push_error("ScreenBox missing vg_control_type")
				ok = false
			if tr.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				push_error("ScreenBox stretch_mode should be KEEP_ASPECT_CENTERED")
				ok = false
		if node:
			node.free()

	if ok:
		print("SCREEN_BOX_PROTO_OK")
		quit(0)
	else:
		print("SCREEN_BOX_PROTO_FAIL")
		quit(1)

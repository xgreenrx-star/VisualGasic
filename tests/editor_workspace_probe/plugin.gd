@tool
extends EditorPlugin

var _passed := 0
var _failed := 0

func _enter_tree() -> void:
	call_deferred("_run")

func _run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.edit_script(load("res://Caverns.vg"), 72, 0, true)
	EditorInterface.set_main_screen_editor("Script")
	await get_tree().create_timer(2).timeout
	var vg := _find_vg(get_tree().root)
	if vg == null:
		_check("VG plugin available", false)
		_finish()
		return
	vg._activate_vg_ui_forms_workspace()
	vg._open_floating_vg_code_editor("res://Caverns.vg")
	await get_tree().create_timer(1).timeout
	var embedded = vg._embedded_code_editor
	var edit: CodeEdit = embedded.get_code_edit()
	var native: CodeEdit = vg._current_code_edit
	_check("floating editor visible", embedded.is_visible_in_tree())
	_check("legacy view flag does not identify floating editor", not vg._showing_code_view)
	_check("native peer available", is_instance_valid(native))
	var source := edit.text
	var sprite_panel = vg._float_assist["sprite_panel"]
	var blocks: Array = edit.get_sprite_data_blocks()
	_check("Data blocks collapsed on open", blocks.all(func(block): return edit.is_line_folded(int(block["line"]))))
	edit.set_caret_line(int(blocks[9]["line"]))
	sprite_panel.update_for_caret(edit.text, edit.get_caret_line())
	var cream := Color("#F0EDE8")
	for label in [sprite_panel._format_help, sprite_panel._status, sprite_panel._brush_label]:
		_check("Sprite label contrast: " + label.text.left(24), _contrast(label.get_theme_color("font_color"), cream) >= 4.5)
	var inherited := Label.new()
	inherited.text = "Future panel label"
	sprite_panel.add_child(inherited)
	_check("assist children inherit readable text", _contrast(inherited.get_theme_color("font_color"), cream) >= 4.5)
	inherited.free()
	var float_content: Control = vg._vg_project_explorer_window.get_meta("_content")
	var fallback := Label.new()
	fallback.text = "Unavailable"
	float_content.add_child(fallback)
	_check("floating content inherits matching text", _contrast(fallback.get_theme_color("font_color"), cream) >= 4.5)
	fallback.free()
	var theme_utils = load("res://addons/visual_gasic/vg_theme_utils.gd")
	var controls := VBoxContainer.new()
	var button := Button.new()
	var option := OptionButton.new()
	option.add_item("Choice")
	controls.add_child(button)
	controls.add_child(option)
	float_content.add_child(controls)
	theme_utils.style_light_toolbar_tree(controls)
	for control in [button, option]:
		for pair in [["font_color", "normal"], ["font_hover_color", "hover"], ["font_pressed_color", "pressed"], ["font_hover_pressed_color", "hover_pressed"], ["font_focus_color", "focus"], ["font_disabled_color", "disabled"]]:
			var background: StyleBoxFlat = control.get_theme_stylebox(pair[1])
			_check("light toolbar contrast: " + control.get_class() + " " + pair[0], _contrast(control.get_theme_color(pair[0]), background.bg_color) >= 4.5)
	_check("OptionButton dropdown themed by tree helper", option.get_popup().has_theme_color_override("font_color"))
	controls.free()
	native.text = source
	vg._dual_editor_bridge.clear_path("res://Caverns.vg")
	edit.grab_focus()
	var caret := edit.get_caret_line()
	edit.set_caret_line(0)
	edit.set_caret_column(0)
	var typed := "' repeated typing regression\n"
	for character in typed:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_ENTER if character == "\n" else 0
		key.unicode = character.unicode_at(0)
		edit.get_viewport().push_input(key, true)
		await get_tree().process_frame
		vg._poll_dual_editor_stale()
		_check("typing never opens a stale dialog", _count_stale_dialogs(EditorInterface.get_base_control()) == 0)
		_check("typing retains keyboard focus", edit.has_focus())
	_check("all typed characters reach source", edit.text == typed + source)
	_check("peer source not overwritten", native.text == source)
	_check("native peer shows nonmodal warning", vg._native_stale_strip.visible)
	var warning: Label = vg._native_stale_strip.find_child("StaleLabel", true, false)
	_check("native warning is readable", _contrast(warning.get_theme_color("font_color"), Color(0.95, 0.82, 0.45)) >= 4.5)
	vg._on_native_stale_banner_dismissed()
	vg._poll_dual_editor_stale()
	_check("native warning dismissal survives polling", not vg._native_stale_strip.visible)
	vg._dual_editor_bridge.note_modified("res://Caverns.vg", 0)
	vg._poll_dual_editor_stale()
	_check("same-side editing does not rearm dismissed warning", not vg._native_stale_strip.visible)
	vg._refresh_native_from_embedded_editor()
	_check("explicit native refresh copies source", native.text == edit.text)
	_check("matching buffers clear warning", not vg._native_stale_strip.visible)
	native.text = "' native edit\n" + source
	vg._on_native_code_edit_text_changed()
	vg._poll_dual_editor_stale()
	_check("native editing never opens modal", _count_stale_dialogs(EditorInterface.get_base_control()) == 0)
	_check("embedded peer shows nonmodal warning", embedded._stale_strip.visible)
	_check("embedded edits retained before explicit refresh", edit.text == typed + source)
	embedded._dismiss_stale_strip()
	vg._poll_dual_editor_stale()
	_check("embedded warning dismissal survives polling", not embedded._stale_strip.visible)
	vg._refresh_embedded_from_native_editor()
	_check("explicit embedded refresh copies source", edit.text == native.text)
	_check("embedded refresh clears warning", not embedded._stale_strip.visible)
	embedded.apply_peer_buffer(source)
	vg._native_stale_applying = true
	native.text = source
	vg._native_stale_applying = false
	edit.set_caret_line(caret)
	await get_tree().process_frame
	sprite_panel.update_for_caret(edit.text, edit.get_caret_line())
	sprite_panel._new_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var dialog: AcceptDialog = sprite_panel._new_dialog
	print("NEW SPRITE SIZE: ", dialog.size, " minimum=", dialog.get_contents_minimum_size())
	_check("New Sprite dialog height bounded", dialog.size.y <= 380)
	dialog.canceled.emit()
	await get_tree().process_frame
	sprite_panel._edit_btn.pressed.emit()
	await get_tree().process_frame
	_check("full Sprite Editor visible", vg._vg_sprite_editor.is_visible_in_tree())
	_check("code stays visible while editing sprites", embedded.is_visible_in_tree())
	_check("full editor binds selected sprite", vg._vg_sprite_editor.is_data_mode() and vg._vg_sprite_editor._data_section.get("label", "") == sprite_panel._section.get("label", ""))
	_check("pixel canvas uses nearest-neighbor filtering", vg._vg_sprite_editor._canvas_panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	_check("full editor retains readable dark chrome", vg._vg_sprite_float.get_theme_stylebox("panel").bg_color.get_luminance() < 0.2)
	if not OS.get_environment("WORKSPACE_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(OS.get_environment("WORKSPACE_CAPTURE").get_base_dir().path_join("sprite-editor.png"))
	var full_sprite = vg._vg_sprite_editor
	var sprite_source := edit.text
	var px_before: PackedInt32Array = sprite_panel._section["pixels"].duplicate()
	var image: Image = full_sprite._layers[0]["image"]
	var palettes = load("res://addons/visual_gasic/vg_sprite_data_palettes.gd")
	image.set_pixel(0, 0, palettes.color_for_index(2, 1))
	full_sprite._save_sprite_data()
	var resolver = load("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
	var saved: Dictionary = resolver.resolve_at_line(edit.text, int(sprite_panel._section["label_line"]))
	_check("full Sprite Editor saves painted pixel", saved["pixels"][0] == 1)
	_check("full save keeps other pixels", saved["pixels"].slice(1) == px_before.slice(1))
	vg._on_sprite_editor_back()
	await get_tree().process_frame
	for child in EditorInterface.get_base_control().get_children():
		if child is ConfirmationDialog and child.title == "Wire DrawDataSprite?":
			child.canceled.emit()
	await get_tree().process_frame
	_check("Back returns to visible code", embedded.is_visible_in_tree())
	_check("Back hides floating Sprite Editor", not vg._vg_sprite_float.visible)
	embedded.apply_peer_buffer(sprite_source)
	edit.set_caret_line(caret)
	await get_tree().process_frame
	sprite_panel.bind_code_edit(edit)
	sprite_panel.update_for_caret(edit.text, edit.get_caret_line())
	sprite_panel._edit_btn.pressed.emit()
	await get_tree().process_frame
	_check("Sprite Editor reopens in same floating panel", vg._vg_sprite_editor.is_visible_in_tree())
	vg._vg_sprite_float.hide()
	_check("closing sprite panel never hides code", embedded.is_visible_in_tree())
	var ux = load("res://addons/visual_gasic/vg_sprite_data_ux.gd")
	var all_blocks: Array = ux.data_blocks(edit.text)
	ux.set_data_folded(edit, false)
	var before_indent := edit.text
	_check("indent action is idempotent on foldable source", ux.migrate_all_indents(edit) == 0 and edit.text == before_indent)
	sprite_panel._fold_btn.pressed.emit()
	_check("Collapse Data collapses every block", ux.all_data_folded(edit))
	_check("collapsed button offers Expand Data", sprite_panel._fold_btn.text == "Expand Data")
	sprite_panel._fold_btn.pressed.emit()
	edit.set_caret_line(edit.get_line_count() - 1)
	sprite_panel._new_btn.pressed.emit()
	await get_tree().process_frame
	dialog = sprite_panel._new_dialog
	var label_field: LineEdit = dialog.find_child("SpriteLabel", true, false)
	label_field.text = "invalid label"
	dialog.confirmed.emit()
	await get_tree().process_frame
	_check("New Sprite validation keeps dialog open", dialog.visible)
	_check("validation does not stretch dialog", dialog.size.y <= 380)
	label_field.text = "WorkspaceTestSprite"
	dialog.confirmed.emit()
	await get_tree().process_frame
	_check("New Sprite inserts complete Data section", resolver.enumerate_blocks(edit.text).size() == blocks.size() + 1)
	_check("New Sprite opens visible full editor", vg._vg_sprite_editor.is_visible_in_tree())
	_check("New Sprite binds new label", vg._vg_sprite_editor._data_section.get("label", "") == "WorkspaceTestSprite")
	vg._on_sprite_editor_back()
	_check("new sprite Back preserves code visibility", embedded.is_visible_in_tree())
	embedded.apply_peer_buffer(before_indent)
	edit.set_caret_line(caret)
	await get_tree().process_frame
	_check("Expand Data expands every block", all_blocks.all(func(block): return not edit.is_line_folded(int(block["label_line"]))))
	_check("expanded button offers Collapse Data", sprite_panel._fold_btn.text == "Collapse Data")
	_check("fold toggle does not edit source", edit.text == before_indent)
	sprite_panel._fold_btn.pressed.emit()
	if not OS.get_environment("WORKSPACE_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(OS.get_environment("WORKSPACE_CAPTURE"))
	_finish()

func _find_vg(node: Node) -> Node:
	if node.has_method("_activate_vg_ui_forms_workspace"):
		return node
	for child in node.get_children():
		var found := _find_vg(child)
		if found:
			return found
	return null

func _count_stale_dialogs(node: Node) -> int:
	var count := 1 if node is AcceptDialog and node.title == "Code editor out of date" else 0
	for child in node.get_children():
		count += _count_stale_dialogs(child)
	return count

func _contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] " + label)

func _finish() -> void:
	print("WORKSPACE RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)

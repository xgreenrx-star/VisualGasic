extends SceneTree

var _passed := 0
var _failed := 0
var _sprite_open_requests := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var embedded = load("res://addons/visual_gasic/vg_embedded_code_editor.gd").new()
	root.add_child(embedded)
	root.size = Vector2i(1100, 700)
	embedded.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	embedded.load_file("res://Caverns.vg")
	embedded.set_control_names([])
	var edit: CodeEdit = embedded._code_edit
	var resolver = load("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
	for block in resolver.enumerate_blocks(edit.text):
		edit.set_line(int(block["label_line"]), edit.get_line(int(block["label_line"])).strip_edges())
		for line in range(int(block["label_line"]) + 1, int(block["end_line"]) + 1):
			edit.set_line(line, "\t" + edit.get_line(line).strip_edges())
	edit.edit_sprite_data_at_line_requested.connect(func(_line: int): _sprite_open_requests += 1)
	edit.call("_refresh_sprite_data_highlights")
	var blocks: Array = edit.call("get_sprite_data_blocks")
	_check("all twelve sprite blocks recognized", blocks.size() == 12)
	_check("source validates", embedded.validate_code())
	await process_frame
	var signature_line := -1
	for line in edit.get_line_count():
		if edit.get_line(line).contains('label = MakeLabel("CRYSTAL CAVERNS"'):
			signature_line = line
			break
	assert(signature_line >= 0, "Showcase title call missing")
	edit.set_caret_line(signature_line)
	for column in range(edit.get_line(signature_line).find(", Color(") + 1):
		edit.set_caret_column(column)
		embedded._on_caret_moved()
		embedded._context_rail._flush_caret_update()
	await create_timer(0.3).timeout
	_check("signature helper creates its label", is_instance_valid(embedded._param_label))
	_check("signature popup belongs to editor", is_instance_valid(embedded._param_popup) and embedded._param_popup.get_parent() == embedded)
	var source: String = edit.text
	for group in ["(Sprites)", "(Whenever)"]:
		var object_index := -1
		for i in embedded._object_combo.item_count:
			if embedded._object_combo.get_item_text(i) == group:
				object_index = i
		_check(group + " available in replacement editor", object_index >= 0)
		_check(group + " present in actual dropdown menu", object_index >= 0 and embedded._object_combo.get_popup().get_item_text(object_index) == group)
		if object_index < 0:
			continue
		embedded._object_combo.select(object_index)
		embedded._on_object_selected(object_index)
		_check(group + " entry count", embedded._proc_combo.item_count == (12 if group == "(Sprites)" else 6))
		for i in embedded._proc_combo.item_count:
			var meta: Dictionary = embedded._proc_combo.get_item_metadata(i)
			embedded._on_proc_selected(i)
			_check(group + " navigates to declaration", edit.get_caret_line() == int(meta["line"]))
			if group == "(Sprites)":
				var panel = embedded._context_rail._sprite_panel
				panel.update_for_caret(edit.text, edit.get_caret_line())
				_check("sprite panel loads selected pixels", panel._pixels.size() == 64 and panel._grid.visible)
				var thumb: Dictionary = edit._sprite_thumb_cache.get(embedded._proc_combo.get_item_text(i), {})
				_check("sprite thumbnail texture exists", thumb.get("tex") is Texture2D)
		embedded._on_caret_moved()
		_check(group + " survives caret update", embedded._object_combo.get_item_text(embedded._object_combo.selected) == group)
		embedded._rebuild_proc_list()
		_check(group + " survives list refresh", embedded._object_combo.get_item_text(embedded._object_combo.selected) == group)
		embedded.set_control_names([])
		_check(group + " survives workspace control refresh", embedded._object_combo.get_item_text(embedded._object_combo.selected) == group)
	_check("navigation never changes source", edit.text == source)
	var sprite_panel = embedded._context_rail._sprite_panel
	edit.set_caret_line(int(blocks[9]["line"]))
	sprite_panel.update_for_caret(edit.text, edit.get_caret_line())
	_check("sprite help explains actual header", sprite_panel._format_help.text.contains("Header: Data 8, 8, 0, 2") and sprite_panel._format_help.text.contains("transparent index = 0") and sprite_panel._format_help.text.contains("C64"))
	_check("sprite help explains pixel row order", sprite_panel._format_help.text.contains("left to right, top to bottom"))
	var walk_section: Dictionary = load("res://addons/visual_gasic/vg_sprite_data_resolver.gd").resolve_at_line(edit.text, edit.get_caret_line())
	var row_line := int(walk_section["data_start_line"])
	var original_row := edit.get_line(row_line)
	var values := original_row.strip_edges().substr(5).split(",")
	edit.set_line(row_line, "\tData " + ",".join(values).replace(" ", ""))
	var alignment_before := edit.text
	sprite_panel.update_for_caret(edit.text, edit.get_caret_line())
	sprite_panel._align_btn.pressed.emit()
	_check("Align Data grid button pads selected sprite", edit.get_line(int(walk_section["data_start_line"])).begins_with("\tData  0,  0,"))
	_check("grid alignment leaves header intact", edit.get_line(int(walk_section["header_line"])) == source.split("\n")[int(walk_section["header_line"])])
	_check("grid alignment marks source dirty", embedded.is_dirty())
	edit.undo()
	_check("grid alignment undo restores source", edit.text == alignment_before)
	edit.text = source
	var factory = load("res://addons/visual_gasic/vg_assist_panel_factory.gd")
	var assist: Dictionary = factory.create_panel()
	root.add_child(assist["root"])
	assist["root"].size = Vector2(320, 600)
	await process_frame
	var tabs: TabContainer = assist["tabs"]
	var state: Dictionary = assist["state"]
	state["in_sprite_block"] = true
	factory.update_context_tab(tabs, state)
	_check("Sprite tab initially follows sprite context", tabs.current_tab == 1)
	var help_rect := tabs.get_tab_bar().get_tab_rect(0)
	var help_click_pos := tabs.get_tab_bar().global_position + help_rect.get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = help_click_pos
		click.global_position = help_click_pos
		root.push_input(click, true)
	_check("Help click records manual selection", tabs.current_tab == 0 and state.get("manual_tab_selection", false))
	factory.update_context_tab(tabs, state)
	_check("sprite caret update respects Help choice", tabs.current_tab == 0)
	state["in_vector_block"] = true
	factory.update_context_tab(tabs, state)
	_check("vector caret update respects Help choice", tabs.current_tab == 0)
	assist["root"].free()
	for block in blocks:
		var line: int = block["line"]
		edit.set_caret_line(line)
		edit.set_caret_column(0)
		edit.center_viewport_to_caret()
		await process_frame
		await process_frame
		var hits: Array = edit._sprite_thumb_hits
		_check("visible folded sprite has thumbnail: " + str(block["label"]), hits.any(func(hit): return hit["label"] == block["label"]))
		edit._show_sprite_peek(str(block["label"]), Vector2(100, 150))
		_check("hover preview has texture: " + str(block["label"]), is_instance_valid(edit._sprite_peek_tex_rect) and edit._sprite_peek_tex_rect.texture != null)
		edit._hide_sprite_peek()
		await process_frame
		var fold_x := edit.get_theme_stylebox("normal").get_margin(SIDE_LEFT)
		var fold_width := 0
		for gutter in edit.get_gutter_count():
			if not edit.is_gutter_drawn(gutter):
				continue
			if "fold" in edit.get_gutter_name(gutter):
				fold_width = edit.get_gutter_width(gutter)
				break
			fold_x += edit.get_gutter_width(gutter)
		_check("fold gutter located", fold_width > 0)
		for cycle in range(2):
			var row_pos := edit.get_pos_at_line_column(line, 0)
			var click_pos := edit.global_position + Vector2(fold_x + fold_width * 0.5, row_pos.y - edit.get_line_height() * 0.5)
			var was_folded := edit.is_line_folded(line)
			var request_count := _sprite_open_requests
			var motion := InputEventMouseMotion.new()
			motion.position = click_pos
			motion.global_position = click_pos
			root.push_input(motion, true)
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				click.position = click_pos
				click.global_position = click_pos
				root.push_input(click, true)
			await process_frame
			_check("fold click toggles block: " + str(block["label"]), edit.is_line_folded(line) != was_folded)
			_check("fold click never opens sprite view", request_count == _sprite_open_requests and embedded.visible)
			_check("fold click preserves source", edit.text == source)
	edit.text += "\n' Whenever Section Fake value Changes OnFake\nwhenever section local Extra value changes OnExtra\n"
	embedded._rebuild_proc_list()
	_check("Whenever handles local/case and ignores comments", embedded._source_navigation_entries("(Whenever)").size() == 7)
	edit.text = "' Empty module\n"
	embedded._rebuild_proc_list()
	_check("removed sections disappear", embedded._object_combo.item_count == 2)
	await process_frame
	embedded.free()
	print("EDITOR RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error(label)

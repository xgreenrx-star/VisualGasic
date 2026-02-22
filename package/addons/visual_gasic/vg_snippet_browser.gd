@tool
extends Window
## VG Snippet Browser — Visual dialog for browsing, inserting, and managing code snippets.
## Launched from the script editor toolbar or Ctrl+Shift+S shortcut.

const VGSnippetManager = preload("res://addons/visual_gasic/vg_snippet_manager.gd")

signal snippet_insert_requested(text: String)

var _category_list: ItemList
var _snippet_list: ItemList
var _preview_edit: TextEdit
var _search_field: LineEdit
var _insert_btn: Button
var _delete_btn: Button
var _add_btn: Button
var _current_snippets: Array = []

func _init():
	title = "VisualGasic Snippet Browser"
	size = Vector2i(720, 500)
	min_size = Vector2i(520, 380)
	exclusive = false
	transient = true
	visible = false

func _ready():
	# Main layout
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)

	# Top bar — search + Add button
	var top_bar = HBoxContainer.new()
	root.add_child(top_bar)

	var search_label = Label.new()
	search_label.text = "Search:"
	top_bar.add_child(search_label)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Type to filter snippets..."
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_field.text_changed.connect(_on_search_changed)
	top_bar.add_child(_search_field)

	_add_btn = Button.new()
	_add_btn.text = "+ New Snippet"
	_add_btn.pressed.connect(_on_add_snippet)
	top_bar.add_child(_add_btn)

	# Content — 3-pane layout
	var content = HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# Left: Categories
	var cat_panel = VBoxContainer.new()
	cat_panel.custom_minimum_size = Vector2(140, 0)
	content.add_child(cat_panel)

	var cat_label = Label.new()
	cat_label.text = "Categories"
	cat_label.add_theme_font_size_override("font_size", 13)
	cat_panel.add_child(cat_label)

	_category_list = ItemList.new()
	_category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_category_list.item_selected.connect(_on_category_selected)
	cat_panel.add_child(_category_list)

	# Middle: Snippet list
	var snip_panel = VBoxContainer.new()
	snip_panel.custom_minimum_size = Vector2(200, 0)
	snip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(snip_panel)

	var snip_label = Label.new()
	snip_label.text = "Snippets"
	snip_label.add_theme_font_size_override("font_size", 13)
	snip_panel.add_child(snip_label)

	_snippet_list = ItemList.new()
	_snippet_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_snippet_list.item_selected.connect(_on_snippet_selected)
	_snippet_list.item_activated.connect(_on_snippet_activated)
	snip_panel.add_child(_snippet_list)

	# Right: Preview
	var preview_panel = VBoxContainer.new()
	preview_panel.custom_minimum_size = Vector2(280, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(preview_panel)

	var preview_label = Label.new()
	preview_label.text = "Preview"
	preview_label.add_theme_font_size_override("font_size", 13)
	preview_panel.add_child(preview_label)

	_preview_edit = TextEdit.new()
	_preview_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_edit.editable = false
	_preview_edit.add_theme_color_override("background_color", Color(0.12, 0.12, 0.16))
	_preview_edit.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	preview_panel.add_child(_preview_edit)

	# Bottom bar — Insert / Delete
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom_bar)

	var info_label = Label.new()
	info_label.text = "Double-click or press Insert to add snippet"
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(info_label)

	_delete_btn = Button.new()
	_delete_btn.text = "Delete"
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete_snippet)
	bottom_bar.add_child(_delete_btn)

	_insert_btn = Button.new()
	_insert_btn.text = "Insert"
	_insert_btn.disabled = true
	_insert_btn.pressed.connect(_on_insert_pressed)
	bottom_bar.add_child(_insert_btn)

	# Populate
	_populate_categories()
	close_requested.connect(hide)

func _populate_categories():
	_category_list.clear()
	_category_list.add_item("All")
	var cats = VGSnippetManager.get_categories()
	for cat in cats:
		_category_list.add_item(cat)
	_category_list.select(0)
	_populate_snippets("All")

func _populate_snippets(category: String, filter: String = ""):
	_snippet_list.clear()
	_current_snippets.clear()
	
	var all_snippets: Array
	if category == "All":
		all_snippets = VGSnippetManager.get_all_snippets()
	else:
		all_snippets = VGSnippetManager.get_snippets_by_category(category)
	
	for s in all_snippets:
		if filter.length() > 0:
			var lower_filter = filter.to_lower()
			if not s.name.to_lower().contains(lower_filter) and not s.prefix.to_lower().contains(lower_filter):
				continue
		
		var icon_text = "★ " if s.is_builtin else "✎ "
		_snippet_list.add_item(icon_text + s.name + "  [" + s.prefix + "]")
		_current_snippets.append(s)
	
	_preview_edit.text = ""
	_insert_btn.disabled = true
	_delete_btn.disabled = true

func _on_category_selected(index: int):
	var cat = _category_list.get_item_text(index)
	_populate_snippets(cat, _search_field.text)

func _on_search_changed(text: String):
	var cat_idx = _category_list.get_selected_items()
	var cat = "All"
	if cat_idx.size() > 0:
		cat = _category_list.get_item_text(cat_idx[0])
	_populate_snippets(cat, text)

func _on_snippet_selected(index: int):
	if index < 0 or index >= _current_snippets.size():
		return
	var s = _current_snippets[index]
	_preview_edit.text = "' Trigger: " + s.prefix + "\n' Category: " + s.category + "\n' " + s.description + "\n\n" + s.body
	_insert_btn.disabled = false
	_delete_btn.disabled = s.is_builtin  # Can only delete user snippets

func _on_snippet_activated(index: int):
	# Double-click = insert
	_on_insert_pressed()

func _on_insert_pressed():
	var sel = _snippet_list.get_selected_items()
	if sel.size() == 0:
		return
	var s = _current_snippets[sel[0]]
	var expanded = VGSnippetManager.expand_snippet(s)
	snippet_insert_requested.emit(expanded.text)
	hide()

func _on_delete_snippet():
	var sel = _snippet_list.get_selected_items()
	if sel.size() == 0:
		return
	var s = _current_snippets[sel[0]]
	if s.is_builtin:
		return
	VGSnippetManager.remove_user_snippet(s.prefix)
	# Refresh
	var cat_idx = _category_list.get_selected_items()
	var cat = "All" if cat_idx.size() == 0 else _category_list.get_item_text(cat_idx[0])
	_populate_snippets(cat, _search_field.text)

func _on_add_snippet():
	# Show a simple add dialog
	var dlg = AcceptDialog.new()
	dlg.title = "New Snippet"
	dlg.size = Vector2i(400, 320)
	
	var form = VBoxContainer.new()
	dlg.add_child(form)
	
	var name_field = _make_field(form, "Name:", "My Snippet")
	var prefix_field = _make_field(form, "Trigger:", "mysnip")
	var cat_field = _make_field(form, "Category:", "Utility")
	var desc_field = _make_field(form, "Description:", "A custom snippet")
	
	var body_label = Label.new()
	body_label.text = "Body (use ${1:placeholder} for tab stops):"
	form.add_child(body_label)
	
	var body_edit = TextEdit.new()
	body_edit.custom_minimum_size = Vector2(0, 120)
	body_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_edit.text = "' ${1:Your code here}\n"
	form.add_child(body_edit)
	
	dlg.confirmed.connect(func():
		VGSnippetManager.add_user_snippet(
			name_field.text, prefix_field.text, desc_field.text,
			cat_field.text, body_edit.text
		)
		_populate_categories()
		dlg.queue_free()
	)
	
	add_child(dlg)
	dlg.popup_centered()

func _make_field(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(lbl)
	var field = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = placeholder
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(field)
	return field

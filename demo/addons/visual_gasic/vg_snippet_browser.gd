@tool
extends Window
## VG Snippet Browser — Visual dialog for browsing, inserting, and managing code snippets.
## Launched from the script editor toolbar or Ctrl+Shift+S shortcut.

const VGSnippetManager = preload("res://addons/visual_gasic/vg_snippet_manager.gd")
const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")

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
	theme = _build_vb6_theme()

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
	VGTheme.hook_line_edit(_search_field)
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
	VGTheme.hook_text_edit(_preview_edit)
	preview_panel.add_child(_preview_edit)

	# Bottom bar — Insert / Delete
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom_bar)

	var info_label = Label.new()
	info_label.text = "Double-click or press Insert to add snippet"
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
	VGTheme.hook_text_edit(body_edit)
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
	VGTheme.hook_line_edit(field)
	hbox.add_child(field)
	return field

func _build_vb6_theme() -> Theme:
	var t = Theme.new()
	var panel_bg     := Color(0.941, 0.929, 0.910)   # #F0EDE8 cream
	var panel_border := Color(0.72, 0.71, 0.68)
	var header_bg    := Color(0.58, 0.58, 0.62)
	var header_border:= Color(0.4, 0.4, 0.4)
	var text_color   := Color(0.0, 0.0, 0.0)
	var list_bg      := Color(1.0, 1.0, 1.0)
	var btn_hover    := Color(0.95, 0.94, 0.92)
	var btn_pressed  := Color(0.88, 0.87, 0.85)
	var active_title := Color(0.0, 0.0, 0.5)

	# ── Window chrome ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = header_bg
	win_sb.border_color = header_border
	win_sb.set_border_width_all(2)
	win_sb.set_content_margin_all(4)
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", Color.WHITE)
	t.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)

	# ── Panel (root background) ──
	var p_sb = StyleBoxFlat.new()
	p_sb.bg_color = panel_bg
	p_sb.set_content_margin_all(0)
	t.set_stylebox("panel", "Panel", p_sb)

	# ── Label ──
	t.set_color("font_color", "Label", text_color)

	# ── LineEdit ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = list_bg
	le_sb.border_color = panel_border
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_stylebox("focus", "LineEdit", le_sb.duplicate())
	t.set_color("font_color", "LineEdit", text_color)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

	# ── TextEdit (preview) ──
	var te_sb = StyleBoxFlat.new()
	te_sb.bg_color = list_bg
	te_sb.border_color = panel_border
	te_sb.set_border_width_all(1)
	te_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "TextEdit", te_sb)
	t.set_stylebox("focus", "TextEdit", te_sb.duplicate())
	t.set_stylebox("read_only", "TextEdit", te_sb.duplicate())
	t.set_color("font_color", "TextEdit", text_color)
	t.set_color("font_readonly_color", "TextEdit", text_color)

	# ── ItemList (categories + snippets) ──
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = list_bg
	il_sb.border_color = panel_border
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", text_color)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = active_title
	t.set_stylebox("selected", "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)

	# ── Button ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = panel_bg
	btn_sb.border_color = panel_border
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var bh = btn_sb.duplicate()
	bh.bg_color = btn_hover
	t.set_stylebox("hover", "Button", bh)
	var bp = btn_sb.duplicate()
	bp.bg_color = btn_pressed
	t.set_stylebox("pressed", "Button", bp)
	var bd = btn_sb.duplicate()
	bd.bg_color = Color(0.90, 0.89, 0.87)
	t.set_stylebox("disabled", "Button", bd)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))

	# ── HSeparator ──
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = panel_border
	sep_sb.content_margin_top = 4; sep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_sb)

	# ── ScrollBar ──
	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.92, 0.91, 0.89)
	scroll_bg.set_content_margin_all(2)
	var grabber_sb = StyleBoxFlat.new()
	grabber_sb.bg_color = Color(0.72, 0.71, 0.68)
	grabber_sb.set_content_margin_all(2)
	var grabber_hl = StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.60, 0.59, 0.56)
	grabber_hl.set_content_margin_all(2)
	var grabber_pr = StyleBoxFlat.new()
	grabber_pr.bg_color = Color(0.50, 0.49, 0.46)
	grabber_pr.set_content_margin_all(2)
	for sbar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbar, scroll_bg)
		t.set_stylebox("grabber", sbar, grabber_sb)
		t.set_stylebox("grabber_highlight", sbar, grabber_hl)
		t.set_stylebox("grabber_pressed", sbar, grabber_pr)

	return t

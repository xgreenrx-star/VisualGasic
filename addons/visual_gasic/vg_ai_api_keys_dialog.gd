@tool
extends ConfirmationDialog
## API key entry — VB6-styled, fixed size. Custom footer buttons (right-aligned).

const PANEL_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_COLOR := Color(0.0, 0.0, 0.0)
const MUTED_COLOR := Color(0.25, 0.25, 0.30)
const ACCENT_COLOR := Color(0.0, 0.0, 0.5)
const LIST_BG := Color(1.0, 1.0, 1.0)

const DIALOG_SIZE := Vector2i(520, 660)

var _key_edits: Dictionary = {}  # provider_id -> LineEdit
var _health_box: VBoxContainer = null
var _custom_cancel_btn: Button = null
var _custom_save_btn: Button = null


func _init() -> void:
	title = "⚙  AI Provider API Keys"
	ok_button_text = "Save"
	wrap_controls = false
	unresizable = true
	min_size = DIALOG_SIZE
	max_size = DIALOG_SIZE
	size = DIALOG_SIZE
	exclusive = true
	theme = _build_theme()


func setup(providers_script: Variant) -> void:
	for c in get_children():
		if c is VBoxContainer:
			c.queue_free()
	_key_edits.clear()
	_build_ui(providers_script)
	call_deferred("_install_custom_footer_buttons")


func get_key_edits() -> Dictionary:
	return _key_edits


func _ready() -> void:
	call_deferred("_refresh_cursor_health_async")


func _install_custom_footer_buttons() -> void:
	# Hide Godot's built-in footer — it lands on the left and overlaps hint text.
	var ok := get_ok_button()
	var cancel := get_cancel_button()
	if ok:
		ok.visible = false
	if cancel:
		cancel.visible = false
	var builtin_row := ok.get_parent() if ok else null
	if builtin_row is Control:
		(builtin_row as Control).visible = false

	if _custom_save_btn and is_instance_valid(_custom_save_btn):
		return

	var outer: VBoxContainer = null
	for c in get_children():
		if c is VBoxContainer:
			outer = c
			break
	if outer == null:
		return

	var btn_row := HBoxContainer.new()
	btn_row.name = "FooterButtons"
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.custom_minimum_size.y = 36
	outer.add_child(btn_row)

	_custom_cancel_btn = Button.new()
	_custom_cancel_btn.text = "Cancel"
	_custom_cancel_btn.custom_minimum_size = Vector2(84, 30)
	_custom_cancel_btn.pressed.connect(_on_custom_cancel)
	btn_row.add_child(_custom_cancel_btn)

	_custom_save_btn = Button.new()
	_custom_save_btn.text = "Save"
	_custom_save_btn.custom_minimum_size = Vector2(84, 30)
	_custom_save_btn.pressed.connect(_on_custom_save)
	btn_row.add_child(_custom_save_btn)

	_style_footer_button(_custom_cancel_btn)
	_style_footer_button(_custom_save_btn)


func _on_custom_cancel() -> void:
	emit_signal("canceled")
	hide()


func _on_custom_save() -> void:
	emit_signal("confirmed")


func _style_footer_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", TEXT_COLOR)
	btn.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	btn.add_theme_color_override("font_focus_color", TEXT_COLOR)


func _build_ui(providers_script: Variant) -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var desc := Label.new()
	desc.text = "Enter API keys for cloud AI providers.\nKeys are stored locally in user://vg_ai_keys.cfg"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", MUTED_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(desc)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2i(0, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	if providers_script != null and providers_script.has_method("get_providers"):
		for p in providers_script.get_providers():
			if p.is_local:
				continue
			_add_provider_row(vbox, providers_script, p)

	vbox.add_child(HSeparator.new())

	_health_box = VBoxContainer.new()
	_health_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_health_box)
	var health_title := Label.new()
	health_title.text = "Cursor (Composer) readiness"
	health_title.add_theme_font_size_override("font_size", 12)
	health_title.add_theme_color_override("font_color", ACCENT_COLOR)
	_health_box.add_child(health_title)
	var pending := Label.new()
	pending.name = "HealthPending"
	pending.text = "Checking…"
	pending.add_theme_font_size_override("font_size", 11)
	pending.add_theme_color_override("font_color", MUTED_COLOR)
	_health_box.add_child(pending)

	vbox.add_child(HSeparator.new())

	var hints := Label.new()
	hints.text = (
		"Get keys from:\n"
		+ "• OpenAI: platform.openai.com/api-keys\n"
		+ "• Claude: console.anthropic.com/settings/keys\n"
		+ "• Gemini: aistudio.google.com/apikey\n"
		+ "• DeepSeek: platform.deepseek.com/api-keys\n"
		+ "• Qwen: dashscope.console.aliyun.com/apiKey\n"
		+ "• Codeium: codeium.com/profile → API Keys\n"
		+ "• Amazon Q: Set up Bedrock Access Gateway locally\n"
		+ "• Cursor: cursor.com/dashboard/integrations"
	)
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", MUTED_COLOR)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hints)


func _add_provider_row(vbox: VBoxContainer, providers_script: Variant, p: Variant) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var lbl := Label.new()
	lbl.text = str(p.display_name) + ":"
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	hbox.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = providers_script.load_api_key(str(p.id))
	edit.placeholder_text = "sk-... / api-key-..."
	edit.secret = true
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	hbox.add_child(edit)
	_key_edits[str(p.id)] = edit

	var eye := Button.new()
	eye.text = "👁"
	eye.tooltip_text = "Show/hide key"
	eye.custom_minimum_size = Vector2(32, 0)
	eye.pressed.connect(func(): edit.secret = not edit.secret)
	hbox.add_child(eye)


func _refresh_cursor_health_async() -> void:
	if _health_box == null:
		return
	WorkerThreadPool.add_task(func():
		var Health = load("res://addons/visual_gasic/vg_ai_provider_health.gd")
		var lines: PackedStringArray = PackedStringArray()
		if Health != null:
			var result: Dictionary = Health.check_cursor()
			for line in result.get("lines", []):
				lines.append(str(line))
		else:
			lines.append("⚠ Health module missing")
		call_deferred("_apply_health_lines", lines)
	)


func _apply_health_lines(lines: PackedStringArray) -> void:
	if not is_instance_valid(_health_box):
		return
	var pending := _health_box.get_node_or_null("HealthPending")
	if pending:
		pending.queue_free()
	for line in lines:
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", TEXT_COLOR)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_health_box.add_child(row)


func _build_theme() -> Theme:
	var t := Theme.new()

	var dlg_sb := StyleBoxFlat.new()
	dlg_sb.bg_color = PANEL_BG
	dlg_sb.border_color = PANEL_BORDER
	dlg_sb.set_border_width_all(1)
	dlg_sb.set_content_margin_all(10)
	t.set_stylebox("panel", "AcceptDialog", dlg_sb)
	t.set_stylebox("panel", "ConfirmationDialog", dlg_sb)

	t.set_color("font_color", "Label", TEXT_COLOR)

	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = LIST_BG
	le_sb.border_color = PANEL_BORDER
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_stylebox("focus", "LineEdit", le_sb.duplicate())
	t.set_color("font_color", "LineEdit", TEXT_COLOR)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.45, 0.45, 0.45))

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = LIST_BG
	btn_sb.border_color = PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8
	btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 4
	btn_sb.content_margin_bottom = 4
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hover := btn_sb.duplicate()
	btn_hover.bg_color = Color(0.95, 0.96, 1.0, 1.0)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_color("font_color", "Button", TEXT_COLOR)

	var sep_sb := StyleBoxFlat.new()
	sep_sb.bg_color = PANEL_BORDER
	sep_sb.content_margin_top = 4
	sep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_sb)

	return t

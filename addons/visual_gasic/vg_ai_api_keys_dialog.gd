@tool
extends ConfirmationDialog
## API key entry — VB6-styled, fixed size. Custom footer buttons (right-aligned).

const PANEL_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_COLOR := Color(0.0, 0.0, 0.0)
const MUTED_COLOR := Color(0.25, 0.25, 0.30)
const ACCENT_COLOR := Color(0.0, 0.0, 0.5)
const LIST_BG := Color(1.0, 1.0, 1.0)

const DIALOG_SIZE := Vector2i(540, 720)
const DIALOG_MIN := Vector2i(520, 560)
const DIALOG_MAX := Vector2i(900, 920)

var _key_edits: Dictionary = {}  # provider_id -> LineEdit
var _health_box: VBoxContainer = null
var _install_sdk_btn: Button = null
var _custom_cancel_btn: Button = null
var _custom_save_btn: Button = null
var _scroll: ScrollContainer = null


func _init() -> void:
	title = "⚙  AI Provider API Keys"
	ok_button_text = "Save"
	wrap_controls = true
	unresizable = false
	min_size = DIALOG_MIN
	max_size = DIALOG_MAX
	size = DIALOG_SIZE
	exclusive = true
	theme = _build_theme()


func setup(providers_script: Variant) -> void:
	for c in get_children():
		c.queue_free()
	_key_edits.clear()
	_scroll = null
	_custom_cancel_btn = null
	_custom_save_btn = null
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
		if c is MarginContainer:
			for ch in c.get_children():
				if ch is VBoxContainer:
					outer = ch
					break
		if outer:
			break
	if outer == null:
		return

	var btn_row := HBoxContainer.new()
	btn_row.name = "FooterButtons"
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
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
	# Fill dialog client area so the scroll region gets a bounded height and
	# footer buttons stay visible (unbounded VBox children were clipping the bottom).
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var desc := Label.new()
	desc.text = "Enter API keys for cloud AI providers.\nKeys are stored locally in user://vg_ai_keys.cfg"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", MUTED_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(desc)

	outer.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2i(0, 280)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	_scroll.add_child(vbox)

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

	_install_sdk_btn = Button.new()
	_install_sdk_btn.name = "InstallSdkBtn"
	_install_sdk_btn.text = "Install cursor-sdk (venv)"
	_install_sdk_btn.tooltip_text = (
		"Creates a project-local Python venv and pip installs cursor-sdk.\n"
		+ "Works on Windows, Linux, and macOS. On Windows uses Scripts\\python.exe."
	)
	_install_sdk_btn.pressed.connect(_on_install_cursor_sdk)
	_health_box.add_child(_install_sdk_btn)

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
	# Keep install button last in the health section.
	if is_instance_valid(_install_sdk_btn):
		_health_box.move_child(_install_sdk_btn, _health_box.get_child_count() - 1)
		var sdk_ok := false
		for line in lines:
			if str(line).begins_with("✅ cursor-sdk"):
				sdk_ok = true
				break
		_install_sdk_btn.visible = not sdk_ok
		_install_sdk_btn.disabled = false
		_install_sdk_btn.text = "Install cursor-sdk (venv)"


func _on_install_cursor_sdk() -> void:
	if not is_instance_valid(_install_sdk_btn):
		return
	_install_sdk_btn.disabled = true
	_install_sdk_btn.text = "Installing cursor-sdk…"
	WorkerThreadPool.add_task(func():
		var CursorSession = load("res://addons/visual_gasic/vg_ai_cursor_session.gd")
		var result: Dictionary = {"ok": false, "error": "module missing"}
		if CursorSession != null:
			result = CursorSession.bootstrap_cursor_sdk()
		call_deferred("_on_install_cursor_sdk_done", result)
	)


func _on_install_cursor_sdk_done(result: Dictionary) -> void:
	if not is_instance_valid(_install_sdk_btn):
		return
	if bool(result.get("ok", false)):
		_install_sdk_btn.text = "Installed ✓"
		_install_sdk_btn.visible = false
	else:
		_install_sdk_btn.disabled = false
		_install_sdk_btn.text = "Install cursor-sdk (venv)"
		var err_lbl := Label.new()
		err_lbl.text = "Install failed: %s" % str(result.get("error", "unknown"))
		err_lbl.add_theme_font_size_override("font_size", 11)
		err_lbl.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
		err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_health_box.add_child(err_lbl)
		if is_instance_valid(_install_sdk_btn):
			_health_box.move_child(_install_sdk_btn, _health_box.get_child_count() - 1)
	_refresh_cursor_health_async()


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

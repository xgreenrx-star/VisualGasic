@tool
extends ConfirmationDialog
## Form / code / project description entry — VB6-styled, fixed size.
##
## Use via EditorInterface.popup_dialog_centered() so Godot hosts the dialog
## on the editor root (not inside the AI Pair dock, which stretches embedded
## AcceptDialogs to full panel height).

const PANEL_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_COLOR := Color(0.0, 0.0, 0.0)
const LIST_BG := Color(1.0, 1.0, 1.0)
const ACTIVE_TITLE := Color(0.0, 0.0, 0.5)

var _desc_label: Label
var _desc_input: TextEdit
var _desc_mode: String = "form"


func _init() -> void:
	ok_button_text = "Design with Narcea"
	get_cancel_button().text = "Cancel"
	wrap_controls = false
	unresizable = true
	min_size = Vector2i(520, 280)
	max_size = Vector2i(520, 280)
	theme = _build_theme()
	_style_dialog_buttons()
	_build_ui()


func _ready() -> void:
	call_deferred("_wire_text_context_menu")


func _wire_text_context_menu() -> void:
	if _desc_input == null:
		return
	var menu := _desc_input.get_menu()
	if menu == null:
		return
	menu.theme = theme
	if not menu.about_to_popup.is_connected(_on_text_menu_about_to_popup):
		menu.about_to_popup.connect(_on_text_menu_about_to_popup)


func _on_text_menu_about_to_popup() -> void:
	if _desc_input == null:
		return
	var menu := _desc_input.get_menu()
	if menu:
		menu.theme = theme


func configure(mode: String) -> void:
	_desc_mode = mode
	var title := ""
	var lbl_text := ""
	var placeholder := ""
	match mode:
		"code":
			title = "Generate code from description"
			lbl_text = "Describe the code change or new files (one or more .vg / .gd / .txt).\nNarcea will reply with a vg-code-spec — then click 📝 Make code."
			placeholder = "Example: add a helper Sub ClampToScreen(ctrl) in helpers.vg that keeps a control within the form's client area. Wire it from Form_Resize."
		"project":
			title = "Scaffold project from description"
			lbl_text = "Describe a runnable mini-project (forms + code + assets).\nNarcea will reply with a vg-project-spec — then click 🆕 Make project."
			placeholder = "Example: a Pong clone — one playfield form ~640x480, two paddles, ball, score label, Timer at 16ms, simple AI for the right paddle."
		_:
			title = "Build form from description"
			lbl_text = "Describe the form in plain English (controls, sizes, behaviour).\nNarcea will reply with a vg-form-spec — then click 🔨 Build form."
			placeholder = "Example: a Login form ~280x160 with two labelled fields (User, Password), an OK button and a Cancel button. auto_events on."
	self.title = title
	_desc_label.text = lbl_text
	_desc_input.placeholder_text = placeholder
	_desc_input.text = ""


func get_desc_mode() -> String:
	return _desc_mode


func get_description() -> String:
	return _desc_input.text.strip_edges() if _desc_input else ""


func grab_description_focus() -> void:
	if _desc_input:
		_desc_input.grab_focus()


func _build_ui() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_desc_label)

	_desc_input = TextEdit.new()
	_desc_input.custom_minimum_size = Vector2(480, 120)
	_desc_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vb.add_child(_desc_input)


func _style_dialog_buttons() -> void:
	for btn in [get_ok_button(), get_cancel_button()]:
		if btn == null:
			continue
		btn.add_theme_color_override("font_color", TEXT_COLOR)
		btn.add_theme_color_override("font_hover_color", TEXT_COLOR)
		btn.add_theme_color_override("font_pressed_color", TEXT_COLOR)
		btn.add_theme_color_override("font_focus_color", TEXT_COLOR)
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))


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

	var te_sb := StyleBoxFlat.new()
	te_sb.bg_color = LIST_BG
	te_sb.border_color = PANEL_BORDER
	te_sb.set_border_width_all(1)
	te_sb.set_content_margin_all(6)
	te_sb.set_corner_radius_all(3)
	t.set_stylebox("normal", "TextEdit", te_sb)
	t.set_stylebox("focus", "TextEdit", te_sb.duplicate())
	t.set_color("font_color", "TextEdit", TEXT_COLOR)
	t.set_color("font_placeholder_color", "TextEdit", Color(0.45, 0.45, 0.45))

	var pm_sb := StyleBoxFlat.new()
	pm_sb.bg_color = LIST_BG
	pm_sb.border_color = PANEL_BORDER
	pm_sb.set_border_width_all(1)
	pm_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", pm_sb)
	t.set_color("font_color", "PopupMenu", TEXT_COLOR)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.55, 0.55, 0.55))
	t.set_color("font_separator_color", "PopupMenu", Color(0.4, 0.4, 0.4))
	t.set_color("font_accelerator_color", "PopupMenu", Color(0.25, 0.35, 0.6))
	t.set_color("font_focus_color", "PopupMenu", TEXT_COLOR)
	t.set_color("font_pressed_color", "PopupMenu", TEXT_COLOR)
	var pm_hov := StyleBoxFlat.new()
	pm_hov.bg_color = ACTIVE_TITLE
	pm_hov.set_corner_radius_all(2)
	t.set_stylebox("hover", "PopupMenu", pm_hov)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = PANEL_BG
	btn_sb.border_color = PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 10
	btn_sb.content_margin_right = 10
	btn_sb.content_margin_top = 4
	btn_sb.content_margin_bottom = 4
	t.set_stylebox("normal", "Button", btn_sb)
	t.set_color("font_color", "Button", TEXT_COLOR)

	return t

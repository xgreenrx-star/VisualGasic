@tool
extends PanelContainer
## Game UI — Scrollable chat log with message input field.

signal message_sent(text: String)

# ── VB6-style properties ──────────────────────────────────────

@export_range(10, 500) var MaxLines: int = 100:
	set(v):
		MaxLines = clampi(v, 10, 500)

@export var ShowInput: bool = true:
	set(v):
		ShowInput = v
		if _input_field: _input_field.visible = v

@export var PlaceholderText: String = "Type a message...":
	set(v):
		PlaceholderText = v
		if _input_field: _input_field.placeholder_text = v

@export var ChatTitle: String = "Chat":
	set(v):
		ChatTitle = v
		if _title_label: _title_label.text = v

@export var BackgroundAlpha: float = 0.85:
	set(v):
		BackgroundAlpha = clampf(v, 0.0, 1.0)
		_apply_panel_style()

@export var SystemColor: Color = Color(0.6, 0.6, 0.7)
@export var PlayerColor: Color = Color(0.3, 0.8, 1.0)

var _title_label: Label
var _chat_log: RichTextLabel
var _input_field: LineEdit

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(260, 180)
	_apply_panel_style()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Title bar
	_title_label = Label.new()
	_title_label.text = ChatTitle
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(_title_label)

	# Chat log
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(_chat_log)

	if Engine.is_editor_hint():
		_chat_log.append_text("[color=#9999aa][System] Welcome to chat[/color]\n")
		_chat_log.append_text("[color=#55ccff]Player1:[/color] Hello!\n")
		_chat_log.append_text("[color=#55ff88]Player2:[/color] GG\n")

	# Input field
	_input_field = LineEdit.new()
	_input_field.placeholder_text = PlaceholderText
	_input_field.visible = ShowInput
	_input_field.custom_minimum_size = Vector2(0, 28)
	if not Engine.is_editor_hint():
		_input_field.text_submitted.connect(_on_submit)
	vbox.add_child(_input_field)

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, BackgroundAlpha)
	style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

func _on_submit(msg: String) -> void:
	if msg.strip_edges().is_empty(): return
	_input_field.clear()
	message_sent.emit(msg)

func add_message(sender: String, text: String, col: Color = PlayerColor) -> void:
	if not _chat_log: return
	var hex := col.to_html(false)
	_chat_log.append_text("[color=#%s]%s:[/color] %s\n" % [hex, sender, text])
	while _chat_log.get_line_count() > MaxLines:
		_chat_log.remove_paragraph(0)

func add_system_message(text: String) -> void:
	if not _chat_log: return
	var hex := SystemColor.to_html(false)
	_chat_log.append_text("[color=#%s][System] %s[/color]\n" % [hex, text])

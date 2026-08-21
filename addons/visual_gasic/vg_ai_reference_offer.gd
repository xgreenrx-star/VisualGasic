@tool
extends PanelContainer
## Countdown reference offer shown before Send when the catalog matches.
## Emits accepted(url) or skipped(); parent fetches and continues the send.

signal accepted(url: String)
signal skipped()
signal alternate_chosen(entry: Dictionary)

const DEFAULT_SECONDS := 5
const Catalog = preload("res://addons/visual_gasic/vg_ai_reference_catalog.gd")

var _countdown_sec: int = DEFAULT_SECONDS
var _remaining: int = 0
var _primary: Dictionary = {}
var _alternates: Array = []
var _custom_mode: bool = false

var _title_lbl: Label
var _body_lbl: Label
var _url_lbl: Label
var _countdown_lbl: Label
var _custom_edit: LineEdit
var _alt_row: HBoxContainer
var _timer: Timer


func _ready() -> void:
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22, 0.95)
	sb.border_color = Color(0.35, 0.55, 0.85, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_title_lbl = Label.new()
	_title_lbl.text = "Use a reference for this build?"
	_title_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	root.add_child(_title_lbl)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	root.add_child(_body_lbl)

	_url_lbl = Label.new()
	_url_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_url_lbl.add_theme_font_size_override("font_size", 11)
	_url_lbl.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
	root.add_child(_url_lbl)

	_custom_edit = LineEdit.new()
	_custom_edit.placeholder_text = "https://en.wikipedia.org/wiki/..."
	_custom_edit.visible = false
	_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_custom_edit)

	_alt_row = HBoxContainer.new()
	_alt_row.add_theme_constant_override("separation", 6)
	_alt_row.visible = false
	root.add_child(_alt_row)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	root.add_child(btn_row)

	var use_btn := Button.new()
	use_btn.text = "Use this reference"
	use_btn.pressed.connect(_on_use_pressed)
	btn_row.add_child(use_btn)

	var custom_btn := Button.new()
	custom_btn.text = "Different URL…"
	custom_btn.pressed.connect(_on_custom_pressed)
	btn_row.add_child(custom_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(_on_skip_pressed)
	btn_row.add_child(skip_btn)

	_countdown_lbl = Label.new()
	_countdown_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	btn_row.add_child(_countdown_lbl)

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func show_offer(primary: Dictionary, alternates: Array, countdown_sec: int = DEFAULT_SECONDS) -> void:
	cancel_offer()
	_primary = primary if typeof(primary) == TYPE_DICTIONARY else {}
	_alternates = alternates if typeof(alternates) == TYPE_ARRAY else []
	_countdown_sec = maxi(0, countdown_sec)
	_remaining = _countdown_sec
	_custom_mode = false
	_custom_edit.visible = false
	_custom_edit.text = ""

	var label := str(_primary.get("label", "Reference"))
	var source := Catalog.source_blurb(str(_primary.get("source", "")))
	_title_lbl.text = "Use a reference for this build?"
	_body_lbl.text = "%s — %s" % [label, source]
	_url_lbl.text = str(_primary.get("url", ""))

	for c in _alt_row.get_children():
		c.queue_free()
	_alt_row.visible = not _alternates.is_empty()
	for alt in _alternates:
		if typeof(alt) != TYPE_DICTIONARY:
			continue
		var ab := Button.new()
		ab.text = "Or: %s" % str(alt.get("label", "alt"))
		ab.tooltip_text = str(alt.get("url", ""))
		var entry: Dictionary = alt
		ab.pressed.connect(func() -> void:
			alternate_chosen.emit(entry)
			_apply_entry(entry))
		_alt_row.add_child(ab)

	_update_countdown_label()
	visible = true
	if _countdown_sec > 0:
		_timer.start()
	else:
		_countdown_lbl.text = ""


func cancel_offer() -> void:
	_timer.stop()
	visible = false
	_primary = {}
	_alternates = []


func is_active() -> bool:
	return visible


func _update_countdown_label() -> void:
	if _countdown_sec <= 0:
		_countdown_lbl.text = ""
	elif _remaining > 0:
		_countdown_lbl.text = "Auto-using in %d…" % _remaining
	else:
		_countdown_lbl.text = "Fetching…"


func _on_tick() -> void:
	if _custom_mode:
		return
	_remaining -= 1
	if _remaining <= 0:
		_timer.stop()
		_countdown_lbl.text = "Fetching…"
		_accept_primary()
	else:
		_update_countdown_label()


func _on_use_pressed() -> void:
	_timer.stop()
	if _custom_mode:
		var u := _custom_edit.text.strip_edges()
		if u.is_empty():
			return
		accepted.emit(u)
		cancel_offer()
		return
	_accept_primary()


func _on_custom_pressed() -> void:
	_custom_mode = true
	_timer.stop()
	_custom_edit.visible = true
	_custom_edit.text = str(_primary.get("url", ""))
	_countdown_lbl.text = "Enter URL, then Use"
	_custom_edit.grab_focus()


func _on_skip_pressed() -> void:
	_timer.stop()
	cancel_offer()
	skipped.emit()


func _accept_primary() -> void:
	var url := str(_primary.get("url", "")).strip_edges()
	if url.is_empty():
		skipped.emit()
		cancel_offer()
		return
	accepted.emit(url)
	cancel_offer()


func _apply_entry(entry: Dictionary) -> void:
	_timer.stop()
	var url := str(entry.get("url", "")).strip_edges()
	if url.is_empty():
		return
	_primary = entry
	accepted.emit(url)
	cancel_offer()

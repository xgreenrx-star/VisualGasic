@tool
extends PanelContainer
## Game UI — Game-styled tab container with selectable pages.

signal tab_changed(index: int)

# ── VB6-style properties ──────────────────────────────────────

@export var TabNames: String = "Inventory,Skills,Map":
	set(v):
		TabNames = v
		_rebuild_tabs()

@export var ActiveTab: int = 0:
	set(v):
		ActiveTab = clampi(v, 0, _tab_count() - 1)
		_highlight_active()
		tab_changed.emit(ActiveTab)

@export var TabHeight: int = 28:
	set(v):
		TabHeight = clampi(v, 20, 60)
		_rebuild_tabs()

@export var ActiveColor: Color = Color(0.2, 0.55, 0.9):
	set(v):
		ActiveColor = v
		_highlight_active()

@export var InactiveColor: Color = Color(0.2, 0.2, 0.28):
	set(v):
		InactiveColor = v
		_highlight_active()

@export var PanelAlpha: float = 0.9:
	set(v):
		PanelAlpha = clampf(v, 0.0, 1.0)
		_apply_style()

var _tab_bar: HBoxContainer
var _content_area: PanelContainer
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	_tab_buttons.clear()
	custom_minimum_size = Vector2(300, 200)
	_apply_style()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Tab bar
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	_tab_bar.custom_minimum_size = Vector2(0, TabHeight)
	vbox.add_child(_tab_bar)

	# Content area
	_content_area = PanelContainer.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.1, 0.1, 0.15, PanelAlpha)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.3, 0.3, 0.4, 0.5)
	cstyle.set_content_margin_all(8)
	_content_area.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(_content_area)

	# Placeholder content
	var placeholder := Label.new()
	placeholder.text = "(Tab content area)"
	placeholder.add_theme_font_size_override("font_size", 11)
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_child(placeholder)

	_rebuild_tabs()

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, PanelAlpha)
	style.border_color = Color(0.35, 0.35, 0.45, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

func _rebuild_tabs() -> void:
	if not _tab_bar: return
	for c in _tab_bar.get_children(): c.queue_free()
	_tab_buttons.clear()
	var names := TabNames.split(",")
	for i in names.size():
		var btn := Button.new()
		btn.text = names[i].strip_edge()
		btn.custom_minimum_size = Vector2(0, TabHeight)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		if not Engine.is_editor_hint():
			var idx := i
			btn.pressed.connect(func(): ActiveTab = idx)
		_tab_bar.add_child(btn)
		_tab_buttons.append(btn)
	_highlight_active()

func _highlight_active() -> void:
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		var is_active := (i == ActiveTab)
		var style := StyleBoxFlat.new()
		style.bg_color = ActiveColor if is_active else InactiveColor
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.7, 0.7, 0.8))

func _tab_count() -> int:
	return TabNames.split(",").size()

func set_tab(index: int) -> void:
	ActiveTab = index

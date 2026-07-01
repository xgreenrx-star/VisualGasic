@tool
## UI Forms control picker.
##
## A resizable popup that shows each placeable VB6 control at its actual
## rendered size so you can see exactly what you're about to drop.  Clicking
## a row closes the window and emits control_chosen(godot_type), which arms
## the canvas ghost-placement mode.
extends Window

## Emitted with the Godot class name of the chosen control (e.g. "Button").
signal control_chosen(godot_type: String)

## Palette of placeable controls: VB6 display name + Godot class.
const PALETTE := [
	{"label": "Button",   "type": "Button"},
	{"label": "Label",    "type": "Label"},
	{"label": "TextBox",  "type": "LineEdit"},
	{"label": "CheckBox", "type": "CheckBox"},
	{"label": "ComboBox", "type": "OptionButton"},
	{"label": "ListBox",  "type": "ItemList"},
]


func _init() -> void:
	title = "Add Control"
	size = Vector2i(300, 380)
	min_size = Vector2i(220, 260)
	unresizable = false
	exclusive = false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	add_child(margin)

	var vb := VBoxContainer.new()
	margin.add_child(vb)

	var hint := Label.new()
	hint.text = "Click a control to place it:"
	vb.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)

	for entry in PALETTE:
		item_list.add_child(_make_row(entry))

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(hide)
	vb.add_child(cancel_btn)

	close_requested.connect(hide)


## Build one clickable row: VB6 name | separator | live rendered control.
func _make_row(entry: Dictionary) -> Control:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.tooltip_text = "Place a %s" % entry["label"]

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	# VB6 name label (fixed 80 px column)
	var name_lbl := Label.new()
	name_lbl.text = entry["label"]
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(name_lbl)

	var sep := VSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sep)

	# Actual rendered control preview — non-interactive (purely visual).
	var preview = ClassDB.instantiate(entry["type"])
	if preview is Control:
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.focus_mode = Control.FOCUS_NONE
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if preview.has_method("set_text"):
			preview.set_text(entry["label"])
		hb.add_child(preview)

	var godot_type: String = entry["type"]
	btn.pressed.connect(func() -> void:
		hide()
		control_chosen.emit(godot_type)
	)
	return btn


## Show the picker centered on screen.
func popup_picker() -> void:
	popup_centered()

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

## Palette of placeable controls: VB6 display name, Godot class, preview size.
const PALETTE := [
	{"label": "Button",   "type": "Button",       "size": Vector2(96, 30)},
	{"label": "Label",    "type": "Label",        "size": Vector2(96, 24)},
	{"label": "TextBox",  "type": "LineEdit",     "size": Vector2(120, 30)},
	{"label": "CheckBox", "type": "CheckBox",     "size": Vector2(110, 28)},
	{"label": "ComboBox", "type": "OptionButton", "size": Vector2(120, 30)},
	{"label": "ListBox",  "type": "ItemList",     "size": Vector2(120, 72)},
]


func _init() -> void:
	title = "Add Control"
	size = Vector2i(300, 420)
	min_size = Vector2i(260, 300)
	unresizable = false
	exclusive = false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var hint := Label.new()
	hint.text = "Click a control to place it:"
	vb.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)

	for entry in PALETTE:
		rows.add_child(_make_row(entry))

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(hide)
	vb.add_child(cancel_btn)

	close_requested.connect(hide)


## Build one clickable row: fixed-size VB6 name column + live rendered control.
## Nothing in the row uses expand flags, so the previews keep their real size
## no matter how the window is resized.
func _make_row(entry: Dictionary) -> Control:
	var preview_size: Vector2 = entry["size"]

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, preview_size.y + 16)
	row.tooltip_text = "Place a %s" % entry["label"]
	row.focus_mode = Control.FOCUS_NONE

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	# VB6 name column — fixed width so all previews line up.
	var name_lbl := Label.new()
	name_lbl.text = entry["label"]
	name_lbl.custom_minimum_size = Vector2(72, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(name_lbl)

	var sep := VSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sep)

	# Actual rendered control preview — fixed size, non-interactive.
	var preview = ClassDB.instantiate(entry["type"])
	if preview is Control:
		preview.custom_minimum_size = preview_size
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.focus_mode = Control.FOCUS_NONE
		if preview.has_method("set_text"):
			preview.set_text(entry["label"])
		if entry["type"] == "OptionButton":
			preview.add_item(entry["label"])
		elif entry["type"] == "ItemList":
			preview.add_item("Item 1")
			preview.add_item("Item 2")
			preview.add_item("Item 3")
		hb.add_child(preview)

	# Trailing spacer keeps everything left-aligned without stretching preview.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)

	var godot_type: String = entry["type"]
	row.pressed.connect(func() -> void:
		hide()
		control_chosen.emit(godot_type)
	)
	return row


## Show the picker centered on screen.
func popup_picker() -> void:
	popup_centered()

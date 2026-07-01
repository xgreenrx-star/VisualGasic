@tool
## UI Forms control picker (experimental).
##
## A small transient popup that lists the placeable VB6 controls.  When the
## user chooses one (double-click a row or press "Place"), it emits
## control_chosen(godot_type) and hides itself.  The plugin controller then
## arms the viewport adapter to place a control of that type on the next click.
extends Window

## Emitted with the Godot class name of the chosen control (e.g. "Button").
signal control_chosen(godot_type: String)

## Palette of placeable controls: display label (VB6 name), Godot class, icon.
const PALETTE := [
	{"label": "Button", "type": "Button", "icon": "🔘"},
	{"label": "Label", "type": "Label", "icon": "🏷"},
	{"label": "TextBox", "type": "LineEdit", "icon": "⌨"},
	{"label": "CheckBox", "type": "CheckBox", "icon": "☑"},
	{"label": "ComboBox", "type": "OptionButton", "icon": "▾"},
	{"label": "ListBox", "type": "ItemList", "icon": "📋"},
]

var _list: ItemList = null


func _init() -> void:
	title = "Add Control"
	size = Vector2i(240, 320)
	min_size = Vector2i(200, 240)
	unresizable = false
	exclusive = false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vb := VBoxContainer.new()
	margin.add_child(vb)

	var hint := Label.new()
	hint.text = "Choose a control to place:"
	vb.add_child(hint)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in PALETTE:
		var idx := _list.add_item(entry["icon"] + "  " + entry["label"])
		_list.set_item_metadata(idx, entry["type"])
	_list.item_activated.connect(_on_item_activated)
	vb.add_child(_list)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(btns)

	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.pressed.connect(_on_place_pressed)
	btns.add_child(place_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(hide)
	btns.add_child(cancel_btn)

	close_requested.connect(hide)


## Show the picker centered over its parent, with the first item selected.
func popup_picker() -> void:
	if _list and _list.item_count > 0:
		_list.select(0)
	popup_centered()


func _on_item_activated(idx: int) -> void:
	_emit_choice(idx)


func _on_place_pressed() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	_emit_choice(sel[0])


func _emit_choice(idx: int) -> void:
	if idx < 0 or idx >= _list.item_count:
		return
	var godot_type := str(_list.get_item_metadata(idx))
	hide()
	control_chosen.emit(godot_type)

@tool
extends PanelContainer
## Game UI — Single inventory/equipment slot with icon, count badge, and drag support.

signal slot_clicked
signal slot_right_clicked
signal item_dropped(data: Dictionary)

# ── VB6-style properties ──────────────────────────────────────

@export var ItemName: String = "":
	set(v):
		ItemName = v
		if _name_label: _name_label.text = v

@export var ItemCount: int = 1:
	set(v):
		ItemCount = maxi(v, 0)
		if _count_label:
			_count_label.text = str(v) if v > 1 else ""
			_count_label.visible = v > 1 and ShowCount

@export var ShowCount: bool = true:
	set(v):
		ShowCount = v
		if _count_label:
			_count_label.visible = v and ItemCount > 1

@export var RarityColor: Color = Color(0.5, 0.5, 0.6):
	set(v):
		RarityColor = v
		_apply_style()

@export var SlotSize: int = 48:
	set(v):
		SlotSize = clampi(v, 24, 128)
		custom_minimum_size = Vector2(SlotSize, SlotSize)

@export var IsEmpty: bool = true:
	set(v):
		IsEmpty = v
		_refresh()

var _icon_rect: ColorRect   # placeholder for TextureRect
var _count_label: Label
var _name_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(SlotSize, SlotSize)
	_apply_style()

	# Icon placeholder (colored square)
	_icon_rect = ColorRect.new()
	_icon_rect.set_anchors_preset(PRESET_FULL_RECT)
	_icon_rect.color = Color(0.3, 0.35, 0.45, 0.5) if IsEmpty else Color(0.45, 0.5, 0.6, 0.6)
	add_child(_icon_rect)

	# Count badge (bottom-right)
	_count_label = Label.new()
	_count_label.text = str(ItemCount) if ItemCount > 1 else ""
	_count_label.visible = ShowCount and ItemCount > 1
	_count_label.add_theme_font_size_override("font_size", 10)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	_count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_count_label)

	# Center label (item name initial or "?")
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(PRESET_FULL_RECT)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_name_label.text = ItemName if ItemName != "" else ("" if IsEmpty else "?")
	add_child(_name_label)

	if Engine.is_editor_hint():
		if IsEmpty:
			_name_label.text = ""
			_icon_rect.color.a = 0.3
		else:
			_name_label.text = ItemName.left(2) if ItemName.length() > 0 else "?"

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_color = RarityColor
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	add_theme_stylebox_override("panel", style)

func _refresh() -> void:
	if _icon_rect:
		_icon_rect.color.a = 0.3 if IsEmpty else 0.6
	if _name_label:
		if IsEmpty:
			_name_label.text = ""
		else:
			_name_label.text = ItemName.left(2) if ItemName.length() > 0 else "?"

func set_item(item_name: String, count: int = 1, rarity: Color = Color(0.5, 0.5, 0.6)) -> void:
	ItemName = item_name
	ItemCount = count
	RarityColor = rarity
	IsEmpty = false

func clear_slot() -> void:
	ItemName = ""
	ItemCount = 0
	IsEmpty = true

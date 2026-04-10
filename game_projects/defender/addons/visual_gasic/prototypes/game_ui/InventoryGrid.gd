@tool
extends PanelContainer
## Game UI — N×M inventory grid with selectable item slots.

signal slot_clicked(row: int, col: int)
signal slot_double_clicked(row: int, col: int)

# ── VB6-style properties ──────────────────────────────────────

@export var Rows: int = 4:
	set(v):
		Rows = maxi(v, 1)
		if is_inside_tree(): _rebuild_grid()

@export var Columns: int = 4:
	set(v):
		Columns = maxi(v, 1)
		if is_inside_tree(): _rebuild_grid()

@export var SlotSize: int = 48:
	set(v):
		SlotSize = maxi(v, 16)
		if is_inside_tree(): _rebuild_grid()

@export var SlotSpacing: int = 4:
	set(v):
		SlotSpacing = maxi(v, 0)
		if is_inside_tree(): _rebuild_grid()

@export var SlotColor: Color = Color(0.2, 0.2, 0.25, 0.8)
@export var SlotHoverColor: Color = Color(0.35, 0.35, 0.4, 0.9)
@export var SelectedSlot: Vector2i = Vector2i(-1, -1)

@export_enum("SlideUp", "FadeIn", "ScaleUp", "PopBounce", "None") var ShowAnimation: int = 1
@export_enum("SlideDown", "FadeOut", "ScaleDown", "None") var HideAnimation: int = 1
@export var TransitionSpeed: float = 0.3

# ── Internal ──────────────────────────────────────────────────

var _grid: GridContainer
var _slots: Array = []  # 2D array [row][col] of Panel
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_grid = GridContainer.new()
	_grid.columns = Columns
	_grid.add_theme_constant_override("h_separation", SlotSpacing)
	_grid.add_theme_constant_override("v_separation", SlotSpacing)
	margin.add_child(_grid)

	_rebuild_grid()

func _rebuild_grid() -> void:
	if not _grid: return
	for c in _grid.get_children(): c.queue_free()
	_grid.columns = Columns
	_grid.add_theme_constant_override("h_separation", SlotSpacing)
	_grid.add_theme_constant_override("v_separation", SlotSpacing)

	_slots.clear()
	for r in Rows:
		var row_arr: Array = []
		for c in Columns:
			var slot := _create_slot(r, c)
			_grid.add_child(slot)
			row_arr.append(slot)
		_slots.append(row_arr)

func _create_slot(row: int, col: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SlotSize, SlotSize)

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = SlotColor
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.45, 0.6)
	slot.add_theme_stylebox_override("panel", style)

	# Icon placeholder
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon)

	# Input
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.double_click:
				slot_double_clicked.emit(row, col)
			else:
				SelectedSlot = Vector2i(row, col)
				slot_clicked.emit(row, col)
	)
	slot.mouse_entered.connect(func():
		var s: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
		s.bg_color = SlotHoverColor
		slot.add_theme_stylebox_override("panel", s)
	)
	slot.mouse_exited.connect(func():
		var s: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
		s.bg_color = SlotColor
		slot.add_theme_stylebox_override("panel", s)
	)
	return slot

# ── Public API ────────────────────────────────────────────────

## Set a texture in a specific slot.
func SetSlotIcon(row: int, col: int, tex: Texture2D) -> void:
	if row >= 0 and row < Rows and col >= 0 and col < Columns:
		var icon: TextureRect = _slots[row][col].get_node("Icon")
		icon.texture = tex

## Clear a specific slot.
func ClearSlot(row: int, col: int) -> void:
	SetSlotIcon(row, col, null)

## Clear all slots.
func ClearAll() -> void:
	for r in Rows:
		for c in Columns:
			ClearSlot(r, c)

## Show with configured animation.
func Show() -> void:
	_animate_show()

## Hide with configured animation.
func Hide() -> void:
	_animate_hide()

# ── Animations ────────────────────────────────────────────────

func _animate_show() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	visible = true
	match ShowAnimation:
		0: # SlideUp
			var target_y := position.y
			position.y += 50; modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", target_y, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.6)
		1: # FadeIn
			modulate.a = 0.0
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed)
		2: # ScaleUp
			scale = Vector2(0.8, 0.8); modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.6)
		3: # PopBounce
			scale = Vector2(0.5, 0.5); modulate.a = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2.ONE, TransitionSpeed) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			_tween.tween_property(self, "modulate:a", 1.0, TransitionSpeed * 0.5)
		_: modulate.a = 1.0

func _animate_hide() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match HideAnimation:
		0:
			_tween.set_parallel(true)
			_tween.tween_property(self, "position:y", position.y + 50, TransitionSpeed)
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		1:
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		2:
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2(0.8, 0.8), TransitionSpeed)
			_tween.tween_property(self, "modulate:a", 0.0, TransitionSpeed)
		_: modulate.a = 0.0
	_tween.tween_callback(func(): visible = false)

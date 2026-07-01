@tool
## UI Forms viewport adapter (experimental).
##
## The design canvas.  A single Control that owns ALL pointer input for the
## form surface and manages the placed control nodes as its children.  It
## implements the VB6-style interaction model:
##   * armed (ghost) mode  — a control type is chosen; a ghost rectangle
##     follows the mouse and a single click places the control.
##   * select / move        — click a placed control to select it, drag to move.
##   * resize               — drag one of the selection overlay's handles.
##   * wire                 — double-click a placed control to request an event
##     handler stub + jump to code.
##
## Placed controls are set to MOUSE_FILTER_IGNORE so they are visual only at
## design time; this adapter does all hit-testing by geometry, keeping a single
## unambiguous input owner.  The selection overlay is a sibling drawn on top and
## is queried (not driven by input) for handle geometry.
extends Control

const SelectionOverlay = preload("res://addons/visual_gasic/plugins/ui_forms/ui_forms_selection_overlay.gd")

## Emitted on a placement click while armed: (godot_type, snapped_position).
signal place_requested(godot_type: String, position: Vector2)
## Emitted when a placed control becomes selected.
signal control_selected(node: Control)
## Emitted when the selection is cleared (click on empty canvas).
signal selection_cleared
## Emitted live during move/resize and once more on commit: (node, new_rect).
signal control_geometry_changed(node: Control, rect: Rect2)
## Emitted on double-click of a placed control (request to wire an event).
signal wire_requested(node: Control)

enum DragMode { NONE, MOVE, RESIZE }

## Grid size (px) for snapping placement, move and resize.
const GRID := 8

var _overlay = null                  # ui_forms_selection_overlay.gd instance
var _placed: Array[Control] = []     # controls managed by this canvas
var _selected: Control = null
var _armed_type: String = ""         # "" = not armed for placement

var _drag_mode: int = DragMode.NONE
var _drag_start_mouse: Vector2 = Vector2()
var _drag_start_rect: Rect2 = Rect2()
var _resize_handle: int = -1

var _ghost_pos: Vector2 = Vector2()
var _ghost_visible: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## Wire the selection overlay this canvas should drive/query.
func set_overlay(overlay) -> void:
	_overlay = overlay


# ─── Placement arming ───────────────────────────────────────

## Arm the canvas to place a control of the given Godot type on the next click.
func arm_placement(godot_type: String) -> void:
	_armed_type = godot_type
	_ghost_visible = false
	queue_redraw()


func is_armed() -> bool:
	return _armed_type != ""


func cancel_placement() -> void:
	_armed_type = ""
	_ghost_visible = false
	queue_redraw()


# ─── Placed-control management (called by the controller) ───

## Adds an already-created control node to the canvas at rect.
func add_placed_control(node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	add_child(node)
	_placed.append(node)
	_apply_rect(node, rect)


## Removes and frees all placed controls (used when loading a form).
func clear_controls() -> void:
	for c in _placed:
		if is_instance_valid(c):
			c.queue_free()
	_placed.clear()
	_selected = null
	if _overlay:
		_overlay.clear_target()


func get_placed() -> Array:
	return _placed


func select_node(node: Control) -> void:
	_selected = node
	if node and _overlay:
		_overlay.set_target(_rect_of(node))
	control_selected.emit(node)


func rect_of(node: Control) -> Rect2:
	return _rect_of(node)


# ─── Input ──────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_motion(event)
	elif event is InputEventMouseButton:
		_handle_button(event)


func _handle_motion(event: InputEventMouseMotion) -> void:
	if _armed_type != "":
		_ghost_pos = _snap_vec(event.position)
		_ghost_visible = true
		queue_redraw()
		return
	if _drag_mode == DragMode.MOVE and is_instance_valid(_selected):
		var delta := event.position - _drag_start_mouse
		var new_pos := _snap_vec(_drag_start_rect.position + delta)
		var r := Rect2(new_pos, _drag_start_rect.size)
		_apply_rect(_selected, r)
		if _overlay:
			_overlay.set_target(r)
		control_geometry_changed.emit(_selected, r)
	elif _drag_mode == DragMode.RESIZE and is_instance_valid(_selected):
		var delta2 := event.position - _drag_start_mouse
		var raw: Rect2 = SelectionOverlay.apply_handle_delta(_drag_start_rect, _resize_handle, delta2)
		var snapped := _snap_rect(raw)
		_apply_rect(_selected, snapped)
		if _overlay:
			_overlay.set_target(snapped)
		control_geometry_changed.emit(_selected, snapped)


func _handle_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _armed_type != "":
			cancel_placement()
			accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		# 1) Placement takes priority when armed.
		if _armed_type != "":
			var pos := _snap_vec(event.position)
			var t := _armed_type
			cancel_placement()
			place_requested.emit(t, pos)
			accept_event()
			return
		# 2) Double-click a control → wire request.
		if event.double_click:
			var hit_dc := _control_at(event.position)
			if hit_dc:
				select_node(hit_dc)
				wire_requested.emit(hit_dc)
				accept_event()
			return
		# 3) Resize handle on the current selection?
		if is_instance_valid(_selected) and _overlay:
			var h: int = _overlay.handle_at(event.position)
			if h >= 0:
				_drag_mode = DragMode.RESIZE
				_resize_handle = h
				_drag_start_mouse = event.position
				_drag_start_rect = _rect_of(_selected)
				accept_event()
				return
		# 4) Select / begin move on a control, or clear selection.
		var hit := _control_at(event.position)
		if hit:
			select_node(hit)
			_drag_mode = DragMode.MOVE
			_drag_start_mouse = event.position
			_drag_start_rect = _rect_of(hit)
		else:
			_selected = null
			if _overlay:
				_overlay.clear_target()
			selection_cleared.emit()
		accept_event()
	else:
		# Mouse released — commit any in-progress drag.
		if _drag_mode != DragMode.NONE and is_instance_valid(_selected):
			control_geometry_changed.emit(_selected, _rect_of(_selected))
		_drag_mode = DragMode.NONE
		_resize_handle = -1


# ─── Drawing (grid + placement ghost) ───────────────────────

func _draw() -> void:
	var sz := size
	# Faint grid dots.
	var dot := Color(1, 1, 1, 0.08)
	var x := 0.0
	while x <= sz.x:
		var y := 0.0
		while y <= sz.y:
			draw_rect(Rect2(x - 0.5, y - 0.5, 1.0, 1.0), dot)
			y += GRID
		x += GRID
	# Placement ghost.
	if _armed_type != "" and _ghost_visible:
		var gsize := default_size_for(_armed_type)
		var grect := Rect2(_ghost_pos, gsize)
		draw_rect(grect, Color(0.30, 0.60, 1.0, 0.20))
		draw_rect(grect, Color(0.30, 0.60, 1.0, 0.9), false, 1.0)


# ─── Helpers ────────────────────────────────────────────────

## Default size for a freshly placed control of the given type.
static func default_size_for(godot_type: String) -> Vector2:
	match godot_type:
		"Label": return Vector2(96, 24)
		"LineEdit": return Vector2(140, 30)
		"CheckBox": return Vector2(120, 28)
		"OptionButton": return Vector2(140, 30)
		"ItemList": return Vector2(140, 100)
		_: return Vector2(100, 30)


func _control_at(pos: Vector2) -> Control:
	# Topmost first (last added draws on top).
	for i in range(_placed.size() - 1, -1, -1):
		var c := _placed[i]
		if is_instance_valid(c) and _rect_of(c).has_point(pos):
			return c
	return null


func _rect_of(node: Control) -> Rect2:
	# The designer-intended rect, stored in metadata, is authoritative: live
	# controls may clamp their height up to a theme-driven content minimum, but
	# the form model must round-trip the exact rect the user placed.
	if node.has_meta("ui_forms_rect"):
		return node.get_meta("ui_forms_rect")
	return Rect2(node.position, node.size)


func _apply_rect(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.position.x + rect.size.x
	node.offset_bottom = rect.position.y + rect.size.y
	node.position = rect.position
	node.size = rect.size
	node.set_meta("ui_forms_rect", rect)


func _snap(v: float) -> float:
	return roundf(v / float(GRID)) * float(GRID)


func _snap_vec(v: Vector2) -> Vector2:
	return Vector2(_snap(v.x), _snap(v.y))


func _snap_rect(r: Rect2) -> Rect2:
	var p := _snap_vec(r.position)
	var e := _snap_vec(r.position + r.size)
	return Rect2(p, e - p)

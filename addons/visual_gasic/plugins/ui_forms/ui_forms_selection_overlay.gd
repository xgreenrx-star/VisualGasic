@tool
## UI Forms selection overlay (experimental).
##
## A purely visual Control drawn on top of the design canvas.  It renders the
## selection rectangle and eight resize handles around the currently selected
## control.  It does NOT handle input itself (MOUSE_FILTER_IGNORE) — the
## viewport adapter owns all pointer input and queries this overlay for handle
## geometry so there is a single, unambiguous input owner.
extends Control

## Handle indices, in the order returned by handle_positions().
const H_TL := 0
const H_T := 1
const H_TR := 2
const H_R := 3
const H_BR := 4
const H_B := 5
const H_BL := 6
const H_L := 7

## Half-size (px) of the square resize handles.
const HANDLE_HALF := 4.0
## Extra hit-test padding (px) around each handle so they're easy to grab.
const HANDLE_GRAB := 6.0
## Minimum control size enforced during resize.
const MIN_SIZE := 8.0

var _target_rect: Rect2 = Rect2()
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func has_target() -> bool:
	return _active


func get_target_rect() -> Rect2:
	return _target_rect


func set_target(rect: Rect2) -> void:
	_target_rect = rect
	_active = true
	queue_redraw()


func clear_target() -> void:
	_active = false
	queue_redraw()


## World-space (canvas-local) centers of the 8 handles for a given rect.
static func handle_positions(r: Rect2) -> Array:
	var p := r.position
	var s := r.size
	return [
		p,                                # 0 TL
		p + Vector2(s.x * 0.5, 0.0),      # 1 T
		p + Vector2(s.x, 0.0),            # 2 TR
		p + Vector2(s.x, s.y * 0.5),      # 3 R
		p + Vector2(s.x, s.y),            # 4 BR
		p + Vector2(s.x * 0.5, s.y),      # 5 B
		p + Vector2(0.0, s.y),            # 6 BL
		p + Vector2(0.0, s.y * 0.5),      # 7 L
	]


## Returns the handle index under pos (canvas-local), or -1 if none.
func handle_at(pos: Vector2) -> int:
	if not _active:
		return -1
	var hps := handle_positions(_target_rect)
	for i in hps.size():
		var hit := Rect2(hps[i] - Vector2(HANDLE_GRAB, HANDLE_GRAB),
			Vector2(HANDLE_GRAB, HANDLE_GRAB) * 2.0)
		if hit.has_point(pos):
			return i
	return -1


## Applies a drag delta on a given handle to a rect, enforcing MIN_SIZE.
static func apply_handle_delta(r: Rect2, handle: int, d: Vector2) -> Rect2:
	var left := r.position.x
	var top := r.position.y
	var right := r.position.x + r.size.x
	var bottom := r.position.y + r.size.y
	match handle:
		H_TL: left += d.x; top += d.y
		H_T: top += d.y
		H_TR: right += d.x; top += d.y
		H_R: right += d.x
		H_BR: right += d.x; bottom += d.y
		H_B: bottom += d.y
		H_BL: left += d.x; bottom += d.y
		H_L: left += d.x
	if right - left < MIN_SIZE:
		if handle == H_TL or handle == H_BL or handle == H_L:
			left = right - MIN_SIZE
		else:
			right = left + MIN_SIZE
	if bottom - top < MIN_SIZE:
		if handle == H_TL or handle == H_T or handle == H_TR:
			top = bottom - MIN_SIZE
		else:
			bottom = top + MIN_SIZE
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _draw() -> void:
	if not _active:
		return
	var accent := Color(0.30, 0.60, 1.0)
	# Selection outline.
	draw_rect(_target_rect, accent, false, 1.0)
	# Resize handles.
	for hp in handle_positions(_target_rect):
		var hr := Rect2(hp - Vector2(HANDLE_HALF, HANDLE_HALF),
			Vector2(HANDLE_HALF, HANDLE_HALF) * 2.0)
		draw_rect(hr, Color.WHITE)
		draw_rect(hr, accent, false, 1.0)

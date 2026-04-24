@tool
extends Control

var editor: Node = null

# ─── Joint-edit state ────────────────────────────────────────────────────────
var joint_edit_mode: bool = false
var _joint_drag_conn: int  = -1   # connection index being dragged
var _joint_drag_idx:  int  = -1   # joint index within that connection
var _hover_conn:      int  = -1   # connection the cursor is near (for preview dot)
var _hover_point:     Vector2 = Vector2.ZERO

const JOINT_RADIUS    := 6.0
const WIRE_HIT_THRESH := 10.0

func _ready() -> void:
	# MOUSE_FILTER_PASS: lets clicks reach underlying GraphEdit nodes AND fires _gui_input here.
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


## Called by the editor when the joint-edit toolbar button is toggled.
func set_joint_mode(enabled: bool) -> void:
	joint_edit_mode = enabled
	_hover_conn      = -1
	_joint_drag_conn = -1
	_joint_drag_idx  = -1
	queue_redraw()


# ─── Bezier helpers ──────────────────────────────────────────────────────────

## Sample a cubic Bezier into a PackedVector2Array.
func _bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t  := float(i) / float(steps)
		var mt := 1.0 - t
		pts.push_back(mt*mt*mt*p0 + 3.0*mt*mt*t*c1 + 3.0*mt*t*t*c2 + t*t*t*p3)
	return pts


## Build a bezier segment between two screen-space points.
func _bezier_segment(p0: Vector2, p3: Vector2, steps: int = 20) -> PackedVector2Array:
	var ctrl := clamp(abs(p3.x - p0.x) * 0.5, 40.0, 200.0)
	var c1   := p0 + Vector2( ctrl, 0.0)
	var c2   := p3 + Vector2(-ctrl, 0.0)
	return _bezier(p0, c1, c2, p3, steps)


## Build a single polyline that passes through all waypoints via bezier segments.
func _build_full_curve(waypoints: PackedVector2Array) -> PackedVector2Array:
	var full := PackedVector2Array()
	if waypoints.size() < 2:
		return full
	for i in range(waypoints.size() - 1):
		var seg := _bezier_segment(waypoints[i], waypoints[i + 1], 20)
		if full.size() > 0 and seg.size() > 0:
			seg.remove_at(0)   # remove duplicate junction point
		full.append_array(seg)
	return full


# ─── Draw ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if editor == null or not is_instance_valid(editor):
		return
	if not editor.has_method("_get_visible_connections_for_overlay"):
		return

	var visible_connections: Array = editor._get_visible_connections_for_overlay()

	for c in visible_connections:
		var waypoints: PackedVector2Array = c.get("waypoints", PackedVector2Array())
		if waypoints.size() < 2:
			continue
		var color:    Color = c.get("color", Color(0.8, 0.8, 0.9, 0.95))
		var width:    float = c.get("width", 2.0)
		var conn_idx: int   = c.get("conn_idx", -1)

		# ── Wire polyline through all waypoints ────────────────────────────
		var curve := _build_full_curve(waypoints)
		draw_polyline(curve, color, width, true)

		# ── Label at midpoint ──────────────────────────────────────────────
		var label: String = c.get("label", "")
		if not label.is_empty() and curve.size() > 0:
			var mid: Vector2 = curve[curve.size() / 2]
			var font      := ThemeDB.fallback_font
			var font_size := 10
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pad       := Vector2(4, 2)
			draw_rect(Rect2(mid - text_size * 0.5 - pad, text_size + pad * 2),
				Color(0.08, 0.08, 0.12, 0.80), true)
			draw_string(font, mid - text_size * 0.5, label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.92, 0.55, 0.95))

		# ── Joint handles (only in joint-edit mode) ────────────────────────
		if joint_edit_mode:
			var joints_screen: Array = c.get("joints_screen", [])
			for ji in joints_screen.size():
				var jp: Vector2 = joints_screen[ji]
				var is_drag := (_joint_drag_conn == conn_idx and _joint_drag_idx == ji)
				var hc      := color.lightened(0.55) if is_drag else color.lightened(0.30)
				draw_circle(jp, JOINT_RADIUS, hc)
				draw_arc(jp, JOINT_RADIUS, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.55), 1.5)

	# ── Hover preview dot (joint-edit mode only) ───────────────────────────
	if joint_edit_mode and _hover_conn >= 0 and _joint_drag_conn < 0:
		draw_circle(_hover_point, 4.5, Color(1.0, 1.0, 0.4, 0.75))


# ─── Input handling for joint editing ────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not joint_edit_mode:
		return
	if editor == null or not is_instance_valid(editor):
		return

	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position

		if _joint_drag_conn >= 0:
			# Dragging an existing joint
			var scroll: Vector2 = editor.get_scroll_offset() if editor.has_method("get_scroll_offset") else Vector2.ZERO
			if editor.has_method("update_joint"):
				editor.update_joint(_joint_drag_conn, _joint_drag_idx, pos + scroll)
			accept_event()
			return

		# Hover detection
		var jf := _find_joint_at(pos)
		if jf[0] >= 0:
			_hover_conn  = jf[0]
			_hover_point = pos
			queue_redraw()
			accept_event()
			return
		var wh := _find_wire_at(pos)
		if wh[0] >= 0:
			_hover_conn  = wh[0]
			_hover_point = pos
			queue_redraw()
			accept_event()
		else:
			if _hover_conn >= 0:
				_hover_conn = -1
				queue_redraw()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check for existing joint first
				var jf := _find_joint_at(mb.position)
				if jf[0] >= 0:
					_joint_drag_conn = jf[0]
					_joint_drag_idx  = jf[1]
					accept_event()
					return
				# Then check wire — click adds a new joint
				var wh := _find_wire_at(mb.position)
				if wh[0] >= 0:
					var scroll: Vector2 = editor.get_scroll_offset() if editor.has_method("get_scroll_offset") else Vector2.ZERO
					if editor.has_method("add_joint"):
						editor.add_joint(wh[0], mb.position + scroll, wh[1])
					accept_event()
			else:
				# Mouse release — end drag
				if _joint_drag_conn >= 0:
					_joint_drag_conn = -1
					_joint_drag_idx  = -1
					queue_redraw()
					accept_event()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Right-click on a joint → remove it
			var jf := _find_joint_at(mb.position)
			if jf[0] >= 0:
				if editor.has_method("remove_joint"):
					editor.remove_joint(jf[0], jf[1])
				accept_event()


# ─── Hit-testing helpers ─────────────────────────────────────────────────────

## Return [conn_idx, joint_idx] of the joint handle under pos, or [-1, -1].
func _find_joint_at(pos: Vector2) -> Array:
	if editor == null or not is_instance_valid(editor):
		return [-1, -1]
	for c in editor._get_visible_connections_for_overlay():
		var joints_screen: Array = c.get("joints_screen", [])
		var conn_idx: int = c.get("conn_idx", -1)
		for ji in joints_screen.size():
			if (joints_screen[ji] as Vector2).distance_to(pos) <= JOINT_RADIUS + 3.0:
				return [conn_idx, ji]
	return [-1, -1]


## Return [conn_idx, insert_after_segment] of the wire nearest to pos, or [-1, -1].
func _find_wire_at(pos: Vector2) -> Array:
	if editor == null or not is_instance_valid(editor):
		return [-1, -1]
	for c in editor._get_visible_connections_for_overlay():
		var waypoints: PackedVector2Array = c.get("waypoints", PackedVector2Array())
		if waypoints.size() < 2:
			continue
		var conn_idx: int = c.get("conn_idx", -1)
		for seg in range(waypoints.size() - 1):
			var seg_pts := _bezier_segment(waypoints[seg], waypoints[seg + 1], 20)
			for i in range(seg_pts.size() - 1):
				if _dist_point_to_segment(pos, seg_pts[i], seg_pts[i + 1]) <= WIRE_HIT_THRESH:
					return [conn_idx, seg]
	return [-1, -1]


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab     := b - a
	var ap     := p - a
	var len_sq := ab.dot(ab)
	if len_sq < 0.0001:
		return ap.length()
	var t := clamp(ap.dot(ab) / len_sq, 0.0, 1.0)
	return (p - (a + ab * t)).length()

@tool
extends ColorRect
## VGShape — VB6-faithful Shape control.
##
## Wraps Godot's ColorRect with the standard VB6 Shape API.
## Overrides _draw() to render different shape types (oval, circle, rounded rect, etc.).
## The ColorRect base color is set to transparent; all drawing is done via _draw().
##
## VB6-compatible API:
##   Properties: Shape, FillColor, FillStyle, BorderColor, BorderWidth,
##               BorderStyle, BackColor, BackStyle, Tag
##   Shape types:
##     0 = vbShapeRectangle       4 = vbShapeRoundedRectangle
##     1 = vbShapeSquare          5 = vbShapeRoundedSquare
##     2 = vbShapeOval
##     3 = vbShapeCircle

# =============================================================================
# Shape type constants (match VB6)
# =============================================================================

const vbShapeRectangle: int = 0
const vbShapeSquare: int = 1
const vbShapeOval: int = 2
const vbShapeCircle: int = 3
const vbShapeRoundedRectangle: int = 4
const vbShapeRoundedSquare: int = 5

# =============================================================================
# Internal state
# =============================================================================

var _shape_type: int = 0
var _fill_color: Color = Color(0.2, 0.4, 0.8, 1.0)
var _fill_style: int = 0         # 0=Solid, 1=Transparent
var _border_color: Color = Color.BLACK
var _border_width: int = 1
var _border_style: int = 1       # 0=Transparent, 1=Solid
var _back_style: int = 1         # 0=Transparent, 1=Opaque
var _back_color: Color = Color(0.2, 0.4, 0.8, 1.0)

# =============================================================================
# VB6 Properties
# =============================================================================

## Shape — the shape type (0–5, see constants above).
@export_enum("Rectangle:0", "Square:1", "Oval:2", "Circle:3", "RoundedRectangle:4", "RoundedSquare:5")
var Shape: int = 0:
	get: return _shape_type
	set(v):
		_shape_type = clampi(v, 0, 5)
		queue_redraw()

## FillColor — the interior fill color.
@export var FillColor: Color = Color(0.2, 0.4, 0.8, 1.0):
	get: return _fill_color
	set(v):
		_fill_color = v
		queue_redraw()

## FillStyle — 0=Solid (filled), 1=Transparent (outline only).
@export_enum("Solid:0", "Transparent:1") var FillStyle: int = 0:
	get: return _fill_style
	set(v):
		_fill_style = v
		queue_redraw()

## BorderColor — the border/outline color.
@export var BorderColor: Color = Color.BLACK:
	get: return _border_color
	set(v):
		_border_color = v
		queue_redraw()

## BorderWidth — border thickness in pixels.
@export_range(0, 20, 1) var BorderWidth: int = 1:
	get: return _border_width
	set(v):
		_border_width = maxi(v, 0)
		queue_redraw()

## BorderStyle — 0=Transparent (no border), 1=Solid.
@export_enum("Transparent:0", "Solid:1") var BorderStyle: int = 1:
	get: return _border_style
	set(v):
		_border_style = v
		queue_redraw()

## BackColor — alias for FillColor (VB6 compat).
var BackColor: Color:
	get: return _fill_color
	set(v): FillColor = v

## BackStyle — 0=Transparent, 1=Opaque. Controls whether fill is drawn.
@export_enum("Transparent:0", "Opaque:1") var BackStyle: int = 1:
	get: return _back_style
	set(v):
		_back_style = v
		queue_redraw()

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# Construction
# =============================================================================

func _init() -> void:
	# Make the ColorRect base transparent; we draw everything in _draw().
	color = Color(0, 0, 0, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

# =============================================================================
# Drawing
# =============================================================================

func _draw() -> void:
	var r := _get_shape_rect()
	var do_fill := (_fill_style == 0 and _back_style == 1)
	var do_border := (_border_style == 1 and _border_width > 0)
	var radius := 8.0  # corner radius for rounded shapes

	match _shape_type:
		vbShapeRectangle, vbShapeSquare:
			if do_fill:
				draw_rect(r, _fill_color, true)
			if do_border:
				draw_rect(r, _border_color, false, float(_border_width))

		vbShapeOval, vbShapeCircle:
			var center := r.get_center()
			var rx := r.size.x * 0.5
			var ry := r.size.y * 0.5
			var points := _make_ellipse_points(center, rx, ry, 64)
			if do_fill:
				draw_colored_polygon(points, _fill_color)
			if do_border:
				# Close the polyline
				var outline := points.duplicate()
				outline.append(points[0])
				draw_polyline(outline, _border_color, float(_border_width), true)

		vbShapeRoundedRectangle, vbShapeRoundedSquare:
			# Use Godot's StyleBoxFlat for rounded rect rendering
			if do_fill:
				_draw_rounded_rect(r, radius, _fill_color, true)
			if do_border:
				_draw_rounded_rect(r, radius, _border_color, false)

## Compute the drawing rectangle, enforcing square aspect for Square/Circle/RoundedSquare.
func _get_shape_rect() -> Rect2:
	var s := size
	var bw := float(_border_width) if _border_style == 1 else 0.0
	var half_bw := bw * 0.5
	var r := Rect2(half_bw, half_bw, s.x - bw, s.y - bw)
	# Enforce square aspect ratio for square variants
	if _shape_type in [vbShapeSquare, vbShapeCircle, vbShapeRoundedSquare]:
		var side := minf(r.size.x, r.size.y)
		r.position.x += (r.size.x - side) * 0.5
		r.position.y += (r.size.y - side) * 0.5
		r.size = Vector2(side, side)
	return r

## Generate points for an ellipse.
func _make_ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		pts.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	return pts

## Draw a rounded rectangle (fill or outline).
func _draw_rounded_rect(rect: Rect2, radius: float, col: Color, filled: bool) -> void:
	# Clamp radius to half the smallest dimension
	var max_r := minf(rect.size.x, rect.size.y) * 0.5
	var r := minf(radius, max_r)
	var pts := PackedVector2Array()
	var segs := 8  # segments per corner

	# Top-right corner
	for i in range(segs + 1):
		var a := -PI * 0.5 + PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(rect.end.x - r + cos(a) * r, rect.position.y + r + sin(a) * r))
	# Bottom-right corner
	for i in range(segs + 1):
		var a := PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(rect.end.x - r + cos(a) * r, rect.end.y - r + sin(a) * r))
	# Bottom-left corner
	for i in range(segs + 1):
		var a := PI * 0.5 + PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(rect.position.x + r + cos(a) * r, rect.end.y - r + sin(a) * r))
	# Top-left corner
	for i in range(segs + 1):
		var a := PI + PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(rect.position.x + r + cos(a) * r, rect.position.y + r + sin(a) * r))

	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])  # close the outline
		draw_polyline(pts, col, float(_border_width), true)

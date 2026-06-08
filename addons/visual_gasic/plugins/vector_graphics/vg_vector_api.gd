@tool
extends Resource
class_name VGVectorAPI

static var _instance: VGVectorAPI = null

static func Get() -> VGVectorAPI:
	if _instance == null:
		_instance = VGVectorAPI.new()
	return _instance

static func _load_vector_canvas() -> Object:
	return load("res://addons/visual_gasic/plugins/vector_graphics/vector_canvas.gd")

static func CreateVectorCanvas() -> Node:
	var canvas_script = _load_vector_canvas()
	var canvas = canvas_script.new()
	return canvas

static func DrawLine(canvas: Node, from: Vector2, to: Vector2, width: float = 2.0, color: Color = Color(1, 1, 1, 1)) -> void:
	if canvas and canvas.has_method("DrawLine"):
		canvas.DrawLine(from, to, width, color)

static func DrawRect(canvas: Node, rect: Rect2, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	if canvas and canvas.has_method("DrawRect"):
		canvas.DrawRect(rect, width, color, fill, fill_color)

static func DrawRoundedRect(canvas: Node, rect: Rect2, radius: float = 16.0, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	if canvas and canvas.has_method("DrawRoundedRect"):
		canvas.DrawRoundedRect(rect, radius, width, color, fill, fill_color)

static func DrawEllipse(canvas: Node, rect: Rect2, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), segments: int = 32) -> void:
	if canvas and canvas.has_method("DrawEllipse"):
		canvas.DrawEllipse(rect, width, color, fill, fill_color, segments)

static func DrawCircle(canvas: Node, center: Vector2, radius: float, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	if canvas and canvas.has_method("DrawCircle"):
		canvas.DrawCircle(center, radius, color, fill, fill_color)

static func DrawArc(canvas: Node, center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int = 32, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	if canvas and canvas.has_method("DrawArc"):
		canvas.DrawArc(center, radius, start_angle, end_angle, segments, width, color, fill, fill_color)

static func DrawPolygon(canvas: Node, points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	if canvas and canvas.has_method("DrawPolygon"):
		canvas.DrawPolygon(points, width, color, fill, fill_color)

static func DrawPolyline(canvas: Node, points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), close: bool = false) -> void:
	if canvas and canvas.has_method("DrawPolyline"):
		canvas.DrawPolyline(points, width, color, fill, fill_color, close)

static func DrawPath(canvas: Node, points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), close: bool = false) -> void:
	if canvas and canvas.has_method("DrawPath"):
		canvas.DrawPath(points, width, color, fill, fill_color, close)

static func DrawText(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	if canvas and canvas.has_method("DrawText"):
		canvas.DrawText(position, text, color, font)

static func DrawTextCentered(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	if canvas and canvas.has_method("DrawTextCentered"):
		canvas.DrawTextCentered(position, text, color, font)

static func DrawTextRightAligned(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	if canvas and canvas.has_method("DrawTextRightAligned"):
		canvas.DrawTextRightAligned(position, text, color, font)

static func DrawVectorText(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, align: String = "left", spacing: float = 2.0, font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorText"):
		canvas.DrawVectorText(position, text, color, scale, width, align, spacing, font_name)

static func DrawVectorTextCentered(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, spacing: float = 2.0, font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorTextCentered"):
		canvas.DrawVectorTextCentered(position, text, color, scale, width, spacing, font_name)

static func DrawVectorTextRightAligned(canvas: Node, position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, spacing: float = 2.0, font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorTextRightAligned"):
		canvas.DrawVectorTextRightAligned(position, text, color, scale, width, spacing, font_name)

static func RegisterVectorFont(canvas: Node, name: String, glyphs: Dictionary, make_default: bool = false) -> void:
	if canvas and canvas.has_method("RegisterVectorFont"):
		canvas.RegisterVectorFont(name, glyphs, make_default)

static func SetVectorFont(canvas: Node, name: String) -> void:
	if canvas and canvas.has_method("SetVectorFont"):
		canvas.SetVectorFont(name)

static func GetVectorFontNames(canvas: Node) -> Array:
	if canvas and canvas.has_method("GetVectorFontNames"):
		return canvas.GetVectorFontNames()
	return []

static func DrawGauge(canvas: Node, center: Vector2, radius: float, progress: float, width: float = 6.0, color: Color = Color(1, 1, 1, 1), bg_color: Color = Color(0.4, 0.4, 0.4, 0.4), start_angle: float = -1.0 * PI * 0.75, end_angle: float = PI * 0.25) -> void:
	if canvas == null:
		return
	var segs = 48
	DrawArc(canvas, center, radius, start_angle, end_angle, segs, width, bg_color, false)
	var fill_angle = start_angle + (end_angle - start_angle) * clamp(progress, 0.0, 1.0)
	DrawArc(canvas, center, radius, start_angle, fill_angle, segs, width, color, false)
	var needle = Vector2(radius - width * 1.5, 0).rotated(fill_angle)
	DrawLine(canvas, center, center + needle, width * 1.2, color)
	DrawCircle(canvas, center, width * 1.8, color, true, color)

static func SetStrokeColor(canvas: Node, color: Color) -> void:
	if canvas and canvas.has_method("SetStrokeColor"):
		canvas.SetStrokeColor(color)

static func SetFillColor(canvas: Node, color: Color) -> void:
	if canvas and canvas.has_method("SetFillColor"):
		canvas.SetFillColor(color)

static func SetDefaultFont(canvas: Node, font: Font) -> void:
	if canvas and canvas.has_method("SetDefaultFont"):
		canvas.SetDefaultFont(font)

static func PushTransform(canvas: Node, transform: Transform2D) -> void:
	if canvas and canvas.has_method("PushTransform"):
		canvas.PushTransform(transform)

static func PopTransform(canvas: Node) -> void:
	if canvas and canvas.has_method("PopTransform"):
		canvas.PopTransform()

static func Translate(canvas: Node, offset: Vector2) -> void:
	if canvas and canvas.has_method("Translate"):
		canvas.Translate(offset)

static func Rotate(canvas: Node, angle: float) -> void:
	if canvas and canvas.has_method("Rotate"):
		canvas.Rotate(angle)

static func Scale(canvas: Node, scale: Vector2) -> void:
	if canvas and canvas.has_method("Scale"):
		canvas.Scale(scale)

static func Clear(canvas: Node) -> void:
	if canvas and canvas.has_method("Clear"):
		canvas.Clear()

static func Render(canvas: Node) -> void:
	if canvas and canvas.has_method("Render"):
		canvas.Render()

static func BeginGroup(canvas: Node, name: String) -> void:
	if canvas and canvas.has_method("BeginGroup"):
		canvas.BeginGroup(name)

static func EndGroup(canvas: Node) -> void:
	if canvas and canvas.has_method("EndGroup"):
		canvas.EndGroup()

static func TagSource(canvas: Node, group_name: String, prop: String, file: String, line: int, literal: String, col: int = -1) -> void:
	if canvas and canvas.has_method("TagSource"):
		canvas.TagSource(group_name, prop, file, line, literal, col)

static func PushIdentity(canvas: Node) -> void:
	if canvas and canvas.has_method("PushIdentity"):
		canvas.PushIdentity()

static func DrawVectorTextWave(canvas: Node, text: String, x_offset: float, base_y: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		amplitude: float = 60.0, wave_freq: float = 0.18, wave_speed: float = 3.0,
		spacing: float = 2.0, hue_cycle: bool = true, font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorTextWave"):
		canvas.DrawVectorTextWave(text, x_offset, base_y, time, color, scale, width, amplitude, wave_freq, wave_speed, spacing, hue_cycle, font_name)

static func DrawVectorTextHelix(canvas: Node, text: String, cx: float, cy: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		radius: float = 200.0, perspective: float = 0.6, helical_pitch: float = 18.0,
		twist_speed: float = 1.2, char_spacing: float = 0.22, font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorTextHelix"):
		canvas.DrawVectorTextHelix(text, cx, cy, time, color, scale, width, radius, perspective, helical_pitch, twist_speed, char_spacing, font_name)

static func DrawVectorTextFlip(canvas: Node, text: String, x_offset: float, base_y: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		char_spacing: float = 52.0, flip_speed: float = 0.9, flip_wave: float = 0.38,
		font_name: String = "") -> void:
	if canvas and canvas.has_method("DrawVectorTextFlip"):
		canvas.DrawVectorTextFlip(text, x_offset, base_y, time, color, scale, width, char_spacing, flip_speed, flip_wave, font_name)

static func DrawLines(canvas: Node, segments: PackedVector2Array, width: float = 2.0, color: Color = Color(1,1,1,1)) -> void:
	if canvas and canvas.has_method("DrawLines"):
		canvas.DrawLines(segments, width, color)

static func DrawRects(canvas: Node, rects_xywh: PackedVector2Array, colors: PackedColorArray, fill: bool = true) -> void:
	if canvas and canvas.has_method("DrawRects"):
		canvas.DrawRects(rects_xywh, colors, fill)

static func DrawRectsUniform(canvas: Node, rects_xywh: PackedVector2Array, color: Color = Color(1,1,1,1), fill: bool = true) -> void:
	if canvas and canvas.has_method("DrawRectsUniform"):
		canvas.DrawRectsUniform(rects_xywh, color, fill)

static func DrawPlasmaCells(canvas: Node, gw: int, gh: int, spd: float, fade: float, pw: float, ph: float, parity: int) -> void:
	if canvas and canvas.has_method("DrawPlasmaCells"):
		canvas.DrawPlasmaCells(gw, gh, spd, fade, pw, ph, parity)

static func DrawTorusWireframe(canvas: Node, rot_y: float, rot_x: float, hue_off: float, tt: float,
		fade: float, cx: float, cy: float, scale: float = 1.0) -> void:
	if canvas and canvas.has_method("DrawTorusWireframe"):
		canvas.DrawTorusWireframe(rot_y, rot_x, hue_off, tt, fade, cx, cy, scale)

static func DrawSpriteLines(canvas: Node, texture: Texture2D, segments: PackedVector2Array, width: float = 6.0, color: Color = Color(1,1,1,1)) -> void:
	if canvas and canvas.has_method("DrawSpriteLines"):
		canvas.DrawSpriteLines(texture, segments, width, color)

static func SetAdditiveBlend(canvas: Node, enable: bool) -> void:
	if canvas and canvas.has_method("SetAdditiveBlend"):
		canvas.SetAdditiveBlend(enable)

static func SetBatchMode(canvas: Node, enable: bool) -> void:
	if canvas and canvas.has_method("SetBatchMode"):
		canvas.SetBatchMode(enable)

static func MakeGlowTexture(canvas: Node, size: int = 32, core_color: Color = Color(1,1,1,1)) -> Texture2D:
	if canvas and canvas.has_method("MakeGlowTexture"):
		return canvas.MakeGlowTexture(size, core_color)
	return null

static func MakeRadialGlowTexture(canvas: Node, size: int = 48, core_color: Color = Color(1,1,1,1)) -> Texture2D:
	if canvas and canvas.has_method("MakeRadialGlowTexture"):
		return canvas.MakeRadialGlowTexture(size, core_color)
	return null

#include "visual_gasic_vector_canvas.h"
#include "visual_gasic_language.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/canvas_item_material.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {
void vg_draw_solid_segments(CanvasItem *item, const PackedVector2Array &pts, const PackedColorArray &cols, float width);

// CanvasItem::draw_* requires Godot's per-node `drawing` flag (NOTIFICATION_DRAW).
// Direct `_draw()` / headless flushes skip that flag and print one error per
// primitive. RenderingServer canvas_item_add_* is legal at any time.
static RID vg_ci_rid(CanvasItem *item) {
	return item ? item->get_canvas_item() : RID();
}

static PackedColorArray vg_solid_colors(const Color &c, int n) {
	PackedColorArray cols;
	cols.resize(n);
	for (int i = 0; i < n; ++i) {
		cols[i] = c;
	}
	return cols;
}

static void vg_add_line(CanvasItem *item, const Vector2 &from, const Vector2 &to, const Color &color, float width) {
	RenderingServer::get_singleton()->canvas_item_add_line(vg_ci_rid(item), from, to, color, width, false);
}

static void vg_add_rect(CanvasItem *item, const Rect2 &rect, const Color &color, bool filled, float width) {
	RenderingServer *rs = RenderingServer::get_singleton();
	RID ci = vg_ci_rid(item);
	if (filled) {
		rs->canvas_item_add_rect(ci, rect, color, false);
	}
	if (!filled || width > 0.0f) {
		const float w = width > 0.0f ? width : 1.0f;
		Vector2 p0 = rect.position;
		Vector2 p1(p0.x + rect.size.x, p0.y);
		Vector2 p2 = p0 + rect.size;
		Vector2 p3(p0.x, p0.y + rect.size.y);
		rs->canvas_item_add_line(ci, p0, p1, color, w, false);
		rs->canvas_item_add_line(ci, p1, p2, color, w, false);
		rs->canvas_item_add_line(ci, p2, p3, color, w, false);
		rs->canvas_item_add_line(ci, p3, p0, color, w, false);
	}
}

static void vg_add_polyline(CanvasItem *item, const PackedVector2Array &pts, const Color &color, float width) {
	if (pts.size() < 2) {
		return;
	}
	RenderingServer::get_singleton()->canvas_item_add_polyline(vg_ci_rid(item), pts, vg_solid_colors(color, pts.size()), width, false);
}

static void vg_add_polygon(CanvasItem *item, const PackedVector2Array &pts, const PackedColorArray &cols) {
	if (pts.size() < 3) {
		return;
	}
	RenderingServer::get_singleton()->canvas_item_add_polygon(vg_ci_rid(item), pts, cols);
}

static void vg_add_multiline(CanvasItem *item, const PackedVector2Array &pts, const Color &color, float width) {
	if (pts.size() < 2) {
		return;
	}
	// Godot 4: colors is 1 (uniform) or one color per segment (points/2).
	PackedColorArray cols;
	cols.resize(1);
	cols[0] = color;
	RenderingServer::get_singleton()->canvas_item_add_multiline(vg_ci_rid(item), pts, cols, width, false);
}
}

VGVectorCanvas2D::VGVectorCanvas2D() {
	_transform_stack.append(Transform2D());
}

VGVectorCanvas2D::~VGVectorCanvas2D() {
	if (_batch_mesh.is_valid()) {
		RenderingServer::get_singleton()->free_rid(_batch_mesh);
	}
}

// ---------------------------------------------------------------------------
// _bind_methods
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::_bind_methods() {
	// Enum exposure for GDScript: VGVectorCanvas2D.CMD_LINE etc.
	BIND_ENUM_CONSTANT(CMD_LINE);
	BIND_ENUM_CONSTANT(CMD_RECT);
	BIND_ENUM_CONSTANT(CMD_ROUNDED_RECT);
	BIND_ENUM_CONSTANT(CMD_ELLIPSE);
	BIND_ENUM_CONSTANT(CMD_ARC);
	BIND_ENUM_CONSTANT(CMD_PIE_SLICE);
	BIND_ENUM_CONSTANT(CMD_POLYGON);
	BIND_ENUM_CONSTANT(CMD_POLYLINE);
	BIND_ENUM_CONSTANT(CMD_TEXT);
	BIND_ENUM_CONSTANT(CMD_MULTILINE);
	BIND_ENUM_CONSTANT(CMD_SPRITE_LINES);
	BIND_ENUM_CONSTANT(CMD_RECTS);
	BIND_ENUM_CONSTANT(CMD_RECTS_UNIFORM);
	BIND_ENUM_CONSTANT(CMD_PLASMA_CELLS);
	BIND_ENUM_CONSTANT(CMD_TORUS_WIREFRAME);
	BIND_ENUM_CONSTANT(CMD_FIRE_CELLS);
	BIND_ENUM_CONSTANT(CMD_MULTILINE_COLORS);
	BIND_ENUM_CONSTANT(CMD_RAW_WIRE_MESH);

	// ---- Draw* (preserve VB-style PascalCase names) ----
	ClassDB::bind_method(D_METHOD("DrawLine", "from", "to", "width", "color"),
			&VGVectorCanvas2D::DrawLine,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("DrawRect", "rect", "width", "color", "fill", "fill_color"),
			&VGVectorCanvas2D::DrawRect,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)));
	ClassDB::bind_method(D_METHOD("DrawRoundedRect", "rect", "radius", "width", "color", "fill", "fill_color", "segments"),
			&VGVectorCanvas2D::DrawRoundedRect,
			DEFVAL(16.0f), DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)), DEFVAL(8));
	ClassDB::bind_method(D_METHOD("DrawEllipse", "rect", "width", "color", "fill", "fill_color", "segments"),
			&VGVectorCanvas2D::DrawEllipse,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)), DEFVAL(32));
	ClassDB::bind_method(D_METHOD("DrawArc", "center", "radius", "start_angle", "end_angle", "segments", "width", "color", "fill", "fill_color"),
			&VGVectorCanvas2D::DrawArc,
			DEFVAL(32), DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)));
	ClassDB::bind_method(D_METHOD("DrawPolygon", "points", "width", "color", "fill", "fill_color"),
			&VGVectorCanvas2D::DrawPolygon,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)));
	ClassDB::bind_method(D_METHOD("DrawPolyline", "points", "width", "color", "fill", "fill_color", "close"),
			&VGVectorCanvas2D::DrawPolyline,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)), DEFVAL(false));
	ClassDB::bind_method(D_METHOD("DrawLines", "segments", "width", "color"),
			&VGVectorCanvas2D::DrawLines,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("DrawLinesColored", "segments", "colors", "width"),
			&VGVectorCanvas2D::DrawLinesColored,
			DEFVAL(2.0f));
	ClassDB::bind_method(D_METHOD("DrawRawWireMesh", "vertices", "edges", "rot_x", "rot_y", "rot_z", "cx", "cy", "scale", "z_depth", "width", "color", "edge_colors", "offset_x", "offset_y", "offset_z"),
			&VGVectorCanvas2D::DrawRawWireMesh,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(PackedColorArray()),
			DEFVAL(0.0f), DEFVAL(0.0f), DEFVAL(0.0f));
	ClassDB::bind_method(D_METHOD("BeginWire3D"), &VGVectorCanvas2D::BeginWire3D);
	ClassDB::bind_method(D_METHOD("SetWireRoom", "room"), &VGVectorCanvas2D::SetWireRoom);
	ClassDB::bind_method(D_METHOD("SetWireAnchor", "x", "y", "z"), &VGVectorCanvas2D::SetWireAnchor);
	ClassDB::bind_method(D_METHOD("ClearWireAnchor"), &VGVectorCanvas2D::ClearWireAnchor);
	ClassDB::bind_method(D_METHOD("SetWireBias", "bias"), &VGVectorCanvas2D::SetWireBias);
	ClassDB::bind_method(D_METHOD("SetEyeRoom", "room"), &VGVectorCanvas2D::SetEyeRoom);
	ClassDB::bind_method(D_METHOD("MarkWireBaked"), &VGVectorCanvas2D::MarkWireBaked);
	ClassDB::bind_method(D_METHOD("BeginDynamic3D"), &VGVectorCanvas2D::BeginDynamic3D);
	ClassDB::bind_method(D_METHOD("SetDrawnRoom", "room"), &VGVectorCanvas2D::SetDrawnRoom);
	ClassDB::bind_method(D_METHOD("SetDrawnMask", "mask"), &VGVectorCanvas2D::SetDrawnMask);
	ClassDB::bind_method(D_METHOD("AddWireLine3D", "x0", "y0", "z0", "x1", "y1", "z1", "width", "color"),
			&VGVectorCanvas2D::AddWireLine3D);
	ClassDB::bind_method(D_METHOD("AddWireTri3D", "x0", "y0", "z0", "x1", "y1", "z1", "x2", "y2", "z2", "color"),
			&VGVectorCanvas2D::AddWireTri3D);
	ClassDB::bind_method(D_METHOD("AddWireQuad3D", "x0", "y0", "z0", "x1", "y1", "z1", "x2", "y2", "z2", "x3", "y3", "z3", "color"),
			&VGVectorCanvas2D::AddWireQuad3D);
	ClassDB::bind_method(D_METHOD("BuildDepthMesh", "cam_x", "cam_y", "cam_z"),
			&VGVectorCanvas2D::BuildDepthMesh);
	ClassDB::bind_method(D_METHOD("DrawWire3D", "cam_x", "cam_y", "cam_z", "yaw", "focal", "origin_x", "origin_y", "near_z", "fill_cull", "pitch"),
			&VGVectorCanvas2D::DrawWire3D, DEFVAL(0.0f));
	ClassDB::bind_method(D_METHOD("GetWirePrimCount"), &VGVectorCanvas2D::GetWirePrimCount);
	ClassDB::bind_method(D_METHOD("DrawRects", "rects_xywh", "colors", "fill"),
			&VGVectorCanvas2D::DrawRects,
			DEFVAL(true));
	ClassDB::bind_method(D_METHOD("DrawRectsUniform", "rects_xywh", "color", "fill"),
			&VGVectorCanvas2D::DrawRectsUniform,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("DrawPlasmaCells", "gw", "gh", "spd", "fade", "pw", "ph", "parity"),
			&VGVectorCanvas2D::DrawPlasmaCells);
	ClassDB::bind_method(D_METHOD("DrawTorusWireframe", "rot_y", "rot_x", "hue_off", "tt", "fade", "cx", "cy", "scale"),
			&VGVectorCanvas2D::DrawTorusWireframe, DEFVAL(1.0));
	ClassDB::bind_method(D_METHOD("DrawFireCells", "grid", "gw", "gh", "pw", "ph", "fade", "skip_rows"),
			&VGVectorCanvas2D::DrawFireCells, DEFVAL(4));
	ClassDB::bind_method(D_METHOD("DrawSpriteLines", "texture", "segments", "width", "color"),
			&VGVectorCanvas2D::DrawSpriteLines,
			DEFVAL(6.0f), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("MakeGlowTexture", "size", "core_color"),
			&VGVectorCanvas2D::MakeGlowTexture,
			DEFVAL(32), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("MakeRadialGlowTexture", "size", "core_color"),
			&VGVectorCanvas2D::MakeRadialGlowTexture,
			DEFVAL(48), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("SetAdditiveBlend", "enable"),
			&VGVectorCanvas2D::SetAdditiveBlend);
	ClassDB::bind_method(D_METHOD("SetBatchMode", "enable"),
			&VGVectorCanvas2D::SetBatchMode);
	ClassDB::bind_method(D_METHOD("DrawPath", "points", "width", "color", "fill", "fill_color", "close"),
			&VGVectorCanvas2D::DrawPath,
			DEFVAL(2.0f), DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)), DEFVAL(false));
	ClassDB::bind_method(D_METHOD("DrawCircle", "center", "radius", "color", "fill", "fill_color"),
			&VGVectorCanvas2D::DrawCircle,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(false), DEFVAL(Color(1, 1, 1, 0)));
	ClassDB::bind_method(D_METHOD("DrawText", "position", "text", "color", "font"),
			&VGVectorCanvas2D::DrawText,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(Variant()));
	ClassDB::bind_method(D_METHOD("DrawTextCentered", "position", "text", "color", "font"),
			&VGVectorCanvas2D::DrawTextCentered,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(Variant()));
	ClassDB::bind_method(D_METHOD("DrawTextRightAligned", "position", "text", "color", "font"),
			&VGVectorCanvas2D::DrawTextRightAligned,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(Variant()));

	// Vector text
	ClassDB::bind_method(D_METHOD("DrawVectorText", "position", "text", "color", "scale", "width", "align", "spacing", "font_name"),
			&VGVectorCanvas2D::DrawVectorText,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f), DEFVAL("left"), DEFVAL(2.0f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextCentered", "position", "text", "color", "scale", "width", "spacing", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextCentered,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f), DEFVAL(2.0f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextRightAligned", "position", "text", "color", "scale", "width", "spacing", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextRightAligned,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f), DEFVAL(2.0f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextHelix",
			"text", "cx", "cy", "time", "color", "scale", "width",
			"radius", "perspective", "helical_pitch", "twist_speed", "char_spacing", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextHelix,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f),
			DEFVAL(200.0f), DEFVAL(0.6f), DEFVAL(18.0f), DEFVAL(1.2f), DEFVAL(0.22f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextWave",
			"text", "x_offset", "base_y", "time", "color", "scale", "width",
			"amplitude", "wave_freq", "wave_speed", "spacing", "hue_cycle", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextWave,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f),
			DEFVAL(60.0f), DEFVAL(0.18f), DEFVAL(3.0f), DEFVAL(2.0f), DEFVAL(true), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextFlip",
			"text", "x_offset", "base_y", "time", "color", "scale", "width",
			"char_spacing", "flip_speed", "flip_wave", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextFlip,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f),
			DEFVAL(52.0f), DEFVAL(0.9f), DEFVAL(0.38f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("DrawVectorTextPath",
			"origin", "cw_angle", "read_angle", "text", "color", "scale", "width", "spacing", "font_name"),
			&VGVectorCanvas2D::DrawVectorTextPath,
			DEFVAL(Color(1, 1, 1, 1)), DEFVAL(1.0f), DEFVAL(2.0f), DEFVAL(2.0f), DEFVAL(""));
	ClassDB::bind_method(D_METHOD("RegisterVectorFont", "name", "glyphs", "make_default"),
			&VGVectorCanvas2D::RegisterVectorFont, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("SetVectorFont", "name"), &VGVectorCanvas2D::SetVectorFont);
	ClassDB::bind_method(D_METHOD("GetVectorFontNames"), &VGVectorCanvas2D::GetVectorFontNames);

	// State / transform
	ClassDB::bind_method(D_METHOD("SetStrokeColor", "color"), &VGVectorCanvas2D::SetStrokeColor);
	ClassDB::bind_method(D_METHOD("SetFillColor", "color"), &VGVectorCanvas2D::SetFillColor);
	ClassDB::bind_method(D_METHOD("SetDefaultFont", "font"), &VGVectorCanvas2D::SetDefaultFont);
	ClassDB::bind_method(D_METHOD("PushTransform", "transform"), &VGVectorCanvas2D::PushTransform);
	ClassDB::bind_method(D_METHOD("PushIdentity"), &VGVectorCanvas2D::PushIdentity);
	ClassDB::bind_method(D_METHOD("PopTransform"), &VGVectorCanvas2D::PopTransform);
	ClassDB::bind_method(D_METHOD("Translate", "offset"), &VGVectorCanvas2D::Translate);
	ClassDB::bind_method(D_METHOD("Rotate", "angle"), &VGVectorCanvas2D::Rotate);
	ClassDB::bind_method(D_METHOD("Scale", "scale"), &VGVectorCanvas2D::Scale);
	ClassDB::bind_method(D_METHOD("Clear"), &VGVectorCanvas2D::Clear);
	ClassDB::bind_method(D_METHOD("GetCommandCount"), &VGVectorCanvas2D::GetCommandCount);
	ClassDB::bind_method(D_METHOD("Render"), &VGVectorCanvas2D::Render);
	ClassDB::bind_method(D_METHOD("ExecuteQueuedCommands"), &VGVectorCanvas2D::ExecuteQueuedCommands);

	// Groups & source tagging
	ClassDB::bind_method(D_METHOD("BeginGroup", "name"), &VGVectorCanvas2D::BeginGroup);
	ClassDB::bind_method(D_METHOD("EndGroup"), &VGVectorCanvas2D::EndGroup);
	ClassDB::bind_method(D_METHOD("TagSource", "group_name", "prop", "file", "line", "literal", "col"),
			&VGVectorCanvas2D::TagSource, DEFVAL(-1));

	// Exposed internal state (named with leading underscore to match the
	// pre-port GDScript variable names so the subclass touches the same
	// objects without renaming).
	ClassDB::bind_method(D_METHOD("_get_commands"), &VGVectorCanvas2D::get_commands_array);
	ClassDB::bind_method(D_METHOD("_set_commands", "value"), &VGVectorCanvas2D::set_commands_array);
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "_commands"), "_set_commands", "_get_commands");

	ClassDB::bind_method(D_METHOD("_get_runtime_commands"), &VGVectorCanvas2D::get_runtime_commands_array);
	ClassDB::bind_method(D_METHOD("_set_runtime_commands", "value"), &VGVectorCanvas2D::set_runtime_commands_array);
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "_runtime_commands"), "_set_runtime_commands", "_get_runtime_commands");

	ClassDB::bind_method(D_METHOD("_get_group_overrides"), &VGVectorCanvas2D::get_group_overrides_dict);
	ClassDB::bind_method(D_METHOD("_set_group_overrides", "value"), &VGVectorCanvas2D::set_group_overrides_dict);
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "_group_overrides"), "_set_group_overrides", "_get_group_overrides");

	ClassDB::bind_method(D_METHOD("_get_command_overrides"), &VGVectorCanvas2D::get_command_overrides_dict);
	ClassDB::bind_method(D_METHOD("_set_command_overrides", "value"), &VGVectorCanvas2D::set_command_overrides_dict);
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "_command_overrides"), "_set_command_overrides", "_get_command_overrides");

	ClassDB::bind_method(D_METHOD("_get_group_source_hints"), &VGVectorCanvas2D::get_group_source_hints_dict);
	ClassDB::bind_method(D_METHOD("_set_group_source_hints", "value"), &VGVectorCanvas2D::set_group_source_hints_dict);
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "_group_source_hints"), "_set_group_source_hints", "_get_group_source_hints");

	ClassDB::bind_method(D_METHOD("_get_group_stack"), &VGVectorCanvas2D::get_group_stack_array);
	ClassDB::bind_method(D_METHOD("_set_group_stack", "value"), &VGVectorCanvas2D::set_group_stack_array);
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "_group_stack"), "_set_group_stack", "_get_group_stack");

	ClassDB::bind_method(D_METHOD("_get_transform_stack"), &VGVectorCanvas2D::get_transform_stack_array);
	ClassDB::bind_method(D_METHOD("_set_transform_stack", "value"), &VGVectorCanvas2D::set_transform_stack_array);
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "_transform_stack"), "_set_transform_stack", "_get_transform_stack");

	ClassDB::bind_method(D_METHOD("_get_frame_line_ord"), &VGVectorCanvas2D::get_frame_line_ord_dict);
	ClassDB::bind_method(D_METHOD("_set_frame_line_ord", "value"), &VGVectorCanvas2D::set_frame_line_ord_dict);
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "_frame_line_ord"), "_set_frame_line_ord", "_get_frame_line_ord");

	ClassDB::bind_method(D_METHOD("get_stroke_color"), &VGVectorCanvas2D::get_stroke_color);
	ClassDB::bind_method(D_METHOD("set_stroke_color", "value"), &VGVectorCanvas2D::set_stroke_color_prop);
	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "stroke_color"), "set_stroke_color", "get_stroke_color");

	ClassDB::bind_method(D_METHOD("get_fill_color"), &VGVectorCanvas2D::get_fill_color_prop);
	ClassDB::bind_method(D_METHOD("set_fill_color", "value"), &VGVectorCanvas2D::set_fill_color_prop);
	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "fill_color"), "set_fill_color", "get_fill_color");

	ClassDB::bind_method(D_METHOD("get_stroke_width"), &VGVectorCanvas2D::get_stroke_width);
	ClassDB::bind_method(D_METHOD("set_stroke_width", "value"), &VGVectorCanvas2D::set_stroke_width);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stroke_width"), "set_stroke_width", "get_stroke_width");

	ClassDB::bind_method(D_METHOD("get_default_font"), &VGVectorCanvas2D::get_default_font);
	ClassDB::bind_method(D_METHOD("set_default_font", "value"), &VGVectorCanvas2D::set_default_font_prop);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "default_font", PROPERTY_HINT_RESOURCE_TYPE, "Font"), "set_default_font", "get_default_font");
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::_ready() {
	queue_redraw();
}

// ---------------------------------------------------------------------------
// Transform stack
// ---------------------------------------------------------------------------
Transform2D VGVectorCanvas2D::_get_current_transform() const {
	int n = _transform_stack.size();
	if (n == 0) {
		return Transform2D();
	}
	return (Transform2D)_transform_stack[n - 1];
}

PackedVector2Array VGVectorCanvas2D::_transform_points_array(const Array &points, const Transform2D &t) const {
	// Fast path: identity transform — common case for game projects that
	// don't push transforms on the canvas. Pack directly.
	if (t == Transform2D()) {
		return PackedVector2Array(points);
	}
	int n = points.size();
	PackedVector2Array result;
	result.resize(n);
	for (int i = 0; i < n; ++i) {
		result[i] = t.xform((Vector2)points[i]);
	}
	return result;
}

PackedVector2Array VGVectorCanvas2D::_transform_points_packed(const PackedVector2Array &points, const Transform2D &t) const {
	if (t == Transform2D()) {
		return points;
	}
	int n = points.size();
	PackedVector2Array result;
	result.resize(n);
	for (int i = 0; i < n; ++i) {
		result[i] = t.xform(points[i]);
	}
	return result;
}

PackedColorArray VGVectorCanvas2D::_make_fill_color_array(const Color &c, int count) {
	PackedColorArray result;
	result.resize(count);
	for (int i = 0; i < count; ++i) {
		result[i] = c;
	}
	return result;
}

Array VGVectorCanvas2D::_rect_corner_points(const Rect2 &rect) {
	Array out;
	out.append(rect.position);
	out.append(rect.position + Vector2(rect.size.x, 0));
	out.append(rect.position + rect.size);
	out.append(rect.position + Vector2(0, rect.size.y));
	return out;
}

Array VGVectorCanvas2D::_ellipse_corner_points(const Rect2 &rect, int segments) {
	Array out;
	Vector2 center = rect.position + rect.size * 0.5f;
	Vector2 radius = rect.size * 0.5f;
	for (int i = 0; i < segments; ++i) {
		double angle = Math_TAU * (double)i / (double)segments;
		out.append(center + Vector2(std::cos(angle) * radius.x, std::sin(angle) * radius.y));
	}
	return out;
}

Array VGVectorCanvas2D::_rounded_rect_corner_points(const Rect2 &rect, float radius, int segments) {
	float max_r = std::min(rect.size.x, rect.size.y) * 0.5f;
	float r = std::min(radius, max_r);
	Array out;
	Vector2 end = rect.position + rect.size;

	for (int i = 0; i <= segments; ++i) {
		double a = -Math_PI * 0.5 + Math_PI * 0.5 * (double)i / (double)segments;
		out.append(Vector2(end.x - r + std::cos(a) * r, rect.position.y + r + std::sin(a) * r));
	}
	for (int i = 0; i <= segments; ++i) {
		double a = Math_PI * 0.5 * (double)i / (double)segments;
		out.append(Vector2(end.x - r + std::cos(a) * r, end.y - r + std::sin(a) * r));
	}
	for (int i = 0; i <= segments; ++i) {
		double a = Math_PI * 0.5 + Math_PI * 0.5 * (double)i / (double)segments;
		out.append(Vector2(rect.position.x + r + std::cos(a) * r, end.y - r + std::sin(a) * r));
	}
	for (int i = 0; i <= segments; ++i) {
		double a = Math_PI + Math_PI * 0.5 * (double)i / (double)segments;
		out.append(Vector2(rect.position.x + r + std::cos(a) * r, rect.position.y + r + std::sin(a) * r));
	}
	return out;
}

Array VGVectorCanvas2D::_arc_corner_points(const Vector2 &center, float radius, float start_angle, float end_angle, int segments) {
	Array out;
	double sweep = (double)end_angle - (double)start_angle;
	for (int i = 0; i <= segments; ++i) {
		double angle = (double)start_angle + sweep * (double)i / (double)segments;
		out.append(center + Vector2(std::cos(angle) * radius, std::sin(angle) * radius));
	}
	return out;
}

// ---------------------------------------------------------------------------
// _queue_command — appends to buffer and triggers redraw.
// Mirrors the GDScript fast path/slow path split.
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::_queue_command(Dictionary command) {
	command["command_id"] = _command_id_counter++;

	// Source hints are for the tweak overlay only — do not latch the slow
	// path just because a debug line was seen (that used to disable the
	// fast path for the rest of the session after the first Draw*).
	bool overlay_in_use = _group_stack.size() > 0
			|| !_group_overrides.is_empty()
			|| !_command_overrides.is_empty();

	if (!overlay_in_use) {
		// Fast path: ~100% of frames in production games.
		_commands.append(command);
		FastPrim prim;
		prim.is_line = false;
		prim.cmd_index = _commands.size() - 1;
		_fast_prims.push_back(prim);
		if (!_pending_redraw) {
			_pending_redraw = true;
			queue_redraw();
		}
		return;
	}

	// Slow path: Tweak Overlay is active. Capture per-command provenance.
	String cmd_id_str = String::num_int64((int64_t)command["command_id"]);
	if (!command.has("target_id")) {
		command["target_id"] = cmd_id_str;
	}
	String gname = _group_stack.size() > 0 ? (String)_group_stack[_group_stack.size() - 1] : String("");
	command["group"] = gname;

	String src_file = VisualGasicLanguage::get_current_debug_file();
	int src_line = VisualGasicLanguage::get_current_debug_line();
	command["__src_file"] = src_file;
	command["__src_line"] = src_line;

	String lkey = src_file + ":" + String::num_int64((int64_t)src_line);
	int ord = (int)_frame_line_ord.get(lkey, 0);
	_frame_line_ord[lkey] = ord + 1;
	command["__src_ord"] = ord;
	command["__stable_id"] = !src_file.is_empty()
			? (src_file + ":" + String::num_int64((int64_t)src_line) + ":" + String::num_int64((int64_t)ord))
			: String("");

	String gkey = gname.is_empty() ? String("__misc") : gname;
	if (!src_file.is_empty() && src_line > 0 && !_group_source_hints.has(gkey)) {
		Dictionary auto_hint;
		auto_hint["file"] = src_file;
		auto_hint["line"] = src_line;
		auto_hint["col"] = -1;
		auto_hint["literal"] = String("");
		Dictionary hint_entry;
		hint_entry["position"] = auto_hint;
		hint_entry["color"] = auto_hint;
		hint_entry["fill_color"] = auto_hint;
		hint_entry["width"] = auto_hint;
		hint_entry["visible"] = auto_hint;
		_group_source_hints[gkey] = hint_entry;
	}

	Dictionary ov = _group_overrides.get(gkey, Dictionary());
	if (!ov.is_empty()) {
		_apply_override_to_command(command, ov);
	}
	String stable_id = (String)command["__stable_id"];
	if (!stable_id.is_empty()) {
		Dictionary cov = _command_overrides.get(stable_id, Dictionary());
		if (!cov.is_empty()) {
			_apply_override_to_command(command, cov);
		}
	}

	_commands.append(command);
	if (!_pending_redraw) {
		_pending_redraw = true;
		queue_redraw();
	}
}

void VGVectorCanvas2D::_apply_override_to_command(Dictionary &command, const Dictionary &override_dict) {
	Array keys = override_dict.keys();
	for (int i = 0; i < keys.size(); ++i) {
		String prop = keys[i];
		Variant value = override_dict[prop];
		if (prop == "position" || prop == "translate") {
			Transform2D base = command.has("_base_transform")
					? (Transform2D)command["_base_transform"]
					: (command.has("transform") ? (Transform2D)command["transform"] : Transform2D());
			command["_base_transform"] = base;
			Transform2D t = base;
			t.set_origin(base.get_origin() + (Vector2)value);
			command["transform"] = t;
		} else if (prop == "visible") {
			command["_visible"] = (bool)value;
		} else {
			if (command.has(prop)) {
				command[prop] = value;
			}
		}
	}
}

// ---------------------------------------------------------------------------
// _draw — main dispatch loop.
// ---------------------------------------------------------------------------
bool VGVectorCanvas2D::_overlay_in_use() const {
	return _group_stack.size() > 0 || !_group_overrides.is_empty() || !_command_overrides.is_empty();
}

void VGVectorCanvas2D::_batch_tri(const Vector2 &a, const Vector2 &b, const Vector2 &c, const Color &color) {
	_batch_pos.push_back(a);
	_batch_pos.push_back(b);
	_batch_pos.push_back(c);
	_batch_col.push_back(color);
	_batch_col.push_back(color);
	_batch_col.push_back(color);
}

void VGVectorCanvas2D::_batch_line(float x0, float y0, float x1, float y1, float width, const Color &color) {
	Vector2 a(x0, y0);
	Vector2 b(x1, y1);
	Vector2 d = b - a;
	float len = d.length();
	if (len < 0.01f) {
		return;
	}
	float hw = width * 0.5f;
	if (hw < 0.5f) {
		hw = 0.5f;
	}
	Vector2 n(-d.y / len * hw, d.x / len * hw);
	Vector2 v0 = a - n;
	Vector2 v1 = a + n;
	Vector2 v2 = b + n;
	Vector2 v3 = b - n;
	_batch_tri(v0, v1, v2, color);
	_batch_tri(v0, v2, v3, color);
}

void VGVectorCanvas2D::_batch_polygon(const PackedVector2Array &pts, const Color &fill, float width, const Color &stroke) {
	const int n = pts.size();
	if (fill.a > 0.001f && n >= 3) {
		for (int i = 1; i < n - 1; ++i) {
			_batch_tri(pts[0], pts[i], pts[i + 1], fill);
		}
	}
	if (width > 0.0f && n >= 2) {
		for (int i = 0; i < n; ++i) {
			Vector2 p0 = pts[i];
			Vector2 p1 = pts[(i + 1) % n];
			_batch_line(p0.x, p0.y, p1.x, p1.y, width, stroke);
		}
	}
}

void VGVectorCanvas2D::_flush_batch_mesh() {
	const int n = (int)_batch_pos.size();
	if (n < 3) {
		_batch_pos.clear();
		_batch_col.clear();
		return;
	}
	// Reuse the packed buffers. canvas_item_add_mesh drops vertex color on the
	// compatibility renderer, so this stays a triangle array (one submit, color kept).
	// resize keeps capacity, so a stable vertex count does not allocate again.
	if (_tri_verts.size() != n) {
		_tri_verts.resize(n);
		_tri_cols.resize(n);
	}
	if (_tri_idx.size() != n) {
		int old = _tri_idx.size();
		_tri_idx.resize(n);
		if (n > old) {
			int32_t *ip = _tri_idx.ptrw();
			for (int i = old; i < n; ++i) {
				ip[i] = i;
			}
		}
	}
	Vector2 *vp = _tri_verts.ptrw();
	Color *cp = _tri_cols.ptrw();
	for (int i = 0; i < n; ++i) {
		vp[i] = _batch_pos[i];
		cp[i] = _batch_col[i];
	}
	RenderingServer::get_singleton()->canvas_item_add_triangle_array(
			vg_ci_rid(this), _tri_idx, _tri_verts, _tri_cols);
	_batch_pos.clear();
	_batch_col.clear();
}

void VGVectorCanvas2D::_depth_cache_clear() {
	for (int i = 0; i < DEPTH_CACHE_N; ++i) {
		_depth_cache[i].mask = -1;
		_depth_cache[i].baked = -2;
		_depth_cache[i].mesh.unref();
	}
	_depth_cache_next = 0;
	_depth_mesh.unref();
	_depth_baked = -2;
	_depth_mask = -1;
}

Ref<ArrayMesh> VGVectorCanvas2D::_depth_cache_find(int mask, int baked) {
	for (int i = 0; i < DEPTH_CACHE_N; ++i) {
		if (_depth_cache[i].mask == mask && _depth_cache[i].baked == baked && _depth_cache[i].mesh.is_valid()) {
			return _depth_cache[i].mesh;
		}
	}
	return Ref<ArrayMesh>();
}

void VGVectorCanvas2D::_depth_cache_store(int mask, int baked, const Ref<ArrayMesh> &mesh) {
	if (mesh.is_null()) {
		return;
	}
	for (int i = 0; i < DEPTH_CACHE_N; ++i) {
		if (_depth_cache[i].mask == mask) {
			_depth_cache[i].baked = baked;
			_depth_cache[i].mesh = mesh;
			return;
		}
	}
	_depth_cache[_depth_cache_next].mask = mask;
	_depth_cache[_depth_cache_next].baked = baked;
	_depth_cache[_depth_cache_next].mesh = mesh;
	_depth_cache_next = (_depth_cache_next + 1) % DEPTH_CACHE_N;
}

void VGVectorCanvas2D::BeginWire3D() {
	_wire.clear();
	_wire.reserve(8192);
	_wire_anchor_set = false;
	_wire_line_anchor = false;
	_wire_bias = 0.0f;
	_wire_baked = -1;
	_depth_cache_clear();
}

void VGVectorCanvas2D::SetWireAnchor(float x, float y, float z) {
	_wire_anchor_set = true;
	_wire_ax = x;
	_wire_ay = y;
	_wire_az = z;
}

void VGVectorCanvas2D::ClearWireAnchor() {
	_wire_anchor_set = false;
	_wire_line_anchor = false;
	_wire_bias = 0.0f;
}

void VGVectorCanvas2D::SetWireBias(float bias) {
	_wire_bias = bias;
}

void VGVectorCanvas2D::SetEyeRoom(int room) {
	_wire_eye_room = room < 1 ? 0 : room;
}

void VGVectorCanvas2D::MarkWireBaked() {
	_wire_baked = (int)_wire.size();
}

void VGVectorCanvas2D::BeginDynamic3D() {
	if (_wire_baked >= 0 && (int)_wire.size() > _wire_baked) {
		_wire.resize((size_t)_wire_baked);
	}
	_wire_anchor_set = false;
	_wire_line_anchor = false;
	_wire_bias = 0.0f;
}

void VGVectorCanvas2D::SetWireRoom(int room) {
	_wire_room = room < 1 ? 1 : room;
}

void VGVectorCanvas2D::SetDrawnRoom(int room) {
	_wire_draw_room = room < 0 ? 0 : room;
	if (room <= 0 || room >= 31) {
		_wire_draw_mask = 0;
	} else {
		_wire_draw_mask = 1u << room;
	}
}

void VGVectorCanvas2D::SetDrawnMask(int mask) {
	_wire_draw_mask = mask <= 0 ? 0 : (uint32_t)mask;
	_wire_draw_room = _wire_draw_mask == 0 ? 0 : 1;
}

void VGVectorCanvas2D::AddWireTri3D(float x0, float y0, float z0, float x1, float y1, float z1, float x2, float y2, float z2, const Color &color) {
	if (color.a <= 0.001f) {
		return;
	}
	WirePrim a;
	a.kind = 1;
	a.x0 = x0;
	a.y0 = y0;
	a.z0 = z0;
	a.x1 = x1;
	a.y1 = y1;
	a.z1 = z1;
	a.x2 = x2;
	a.y2 = y2;
	a.z2 = z2;
	a.color = color;
	a.room = (uint8_t)_wire_room;
	a.has_anchor = 0;
	_wire.push_back(a);
}

void VGVectorCanvas2D::AddWireLine3D(float x0, float y0, float z0, float x1, float y1, float z1, float width, const Color &color) {
	if (width <= 0.0f) {
		return;
	}
	WirePrim p;
	p.kind = 0;
	p.x0 = x0;
	p.y0 = y0;
	p.z0 = z0;
	p.x1 = x1;
	p.y1 = y1;
	p.z1 = z1;
	p.width = width;
	p.color = color;
	p.room = (uint8_t)_wire_room;
	if (_wire_anchor_set) {
		p.ax = _wire_ax;
		p.ay = _wire_ay;
		p.az = _wire_az;
		p.anchor_bias = _wire_bias;
		p.has_anchor = 1;
	} else if (_wire_line_anchor) {
		p.ax = _wire_lax;
		p.ay = _wire_lay;
		p.az = _wire_laz;
		p.anchor_bias = _wire_bias;
		p.has_anchor = 1;
	}
	_wire.push_back(p);
}

void VGVectorCanvas2D::AddWireQuad3D(float x0, float y0, float z0, float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, const Color &color) {
	if (color.a <= 0.001f) {
		return;
	}
	// One quad, two triangles. Slicing a face into coplanar pieces makes the
	// depth buffer flicker along every seam.
	float mx = (x0 + x1 + x2 + x3) * 0.25f;
	float my = (y0 + y1 + y2 + y3) * 0.25f;
	float mz = (z0 + z1 + z2 + z3) * 0.25f;
	if (_wire_anchor_set) {
		mx = _wire_ax;
		my = _wire_ay;
		mz = _wire_az;
	} else {
		_wire_line_anchor = true;
		_wire_lax = mx;
		_wire_lay = my;
		_wire_laz = mz;
	}
	WirePrim a;
	a.kind = 1;
	a.x0 = x0;
	a.y0 = y0;
	a.z0 = z0;
	a.x1 = x1;
	a.y1 = y1;
	a.z1 = z1;
	a.x2 = x2;
	a.y2 = y2;
	a.z2 = z2;
	a.color = color;
	a.room = (uint8_t)_wire_room;
	a.ax = mx;
	a.ay = my;
	a.az = mz;
	a.anchor_bias = _wire_bias;
	a.has_anchor = 1;
	_wire.push_back(a);
	WirePrim b;
	b.kind = 1;
	b.x0 = x0;
	b.y0 = y0;
	b.z0 = z0;
	b.x1 = x2;
	b.y1 = y2;
	b.z1 = z2;
	b.x2 = x3;
	b.y2 = y3;
	b.z2 = z3;
	b.color = color;
	b.room = (uint8_t)_wire_room;
	b.ax = mx;
	b.ay = my;
	b.az = mz;
	b.anchor_bias = _wire_bias;
	b.has_anchor = 1;
	_wire.push_back(b);
}

namespace {

void vg_depth_push(PackedVector3Array &verts, PackedColorArray &cols, int &v, const Vector3 &a, const Vector3 &b, const Vector3 &c, const Color &color) {
	if (v + 3 > verts.size()) {
		int n = verts.size() * 2;
		if (n < v + 3) {
			n = v + 3;
		}
		verts.resize(n);
		cols.resize(n);
	}
	verts[v] = a;
	cols[v] = color;
	v++;
	verts[v] = b;
	cols[v] = color;
	v++;
	verts[v] = c;
	cols[v] = color;
	v++;
}

} // namespace

void VGVectorCanvas2D::_depth_append_prim(const WirePrim &p, PackedVector3Array &verts, PackedColorArray &cols, int &v) {
	if (p.kind == 1) {
		Vector3 a(p.x0, p.y0, p.z0);
		Vector3 b(p.x1, p.y1, p.z1);
		Vector3 c(p.x2, p.y2, p.z2);
		// Bias separates coplanar coats. Positive = push along winding normal
		// (black fill into the wall). Negative = push the opposite way so neon
		// strips sit on the room side of the fill from either winding.
		if (p.anchor_bias > 0.0001f || p.anchor_bias < -0.0001f) {
			Vector3 nrm = (b - a).cross(c - a);
			if (nrm.length_squared() > 0.0000001f) {
				nrm = nrm.normalized();
				float lift = p.anchor_bias;
				if (lift < 0.0f) {
					lift = -lift;
					nrm = -nrm;
				}
				if (lift < 0.012f) {
					lift = 0.012f;
				}
				if (lift > 0.05f) {
					lift = 0.05f;
				}
				a += nrm * lift;
				b += nrm * lift;
				c += nrm * lift;
			}
		}
		vg_depth_push(verts, cols, v, a, b, c, p.color);
		return;
	}
	Vector3 a(p.x0, p.y0, p.z0);
	Vector3 b(p.x1, p.y1, p.z1);
	Vector3 dir = b - a;
	const float len = dir.length();
	if (len < 0.0001f) {
		return;
	}
	dir /= len;
	// One stable ribbon. A camera-facing cross turns spirals into crawling dots.
	Vector3 side = dir.cross(Vector3(0.0f, 1.0f, 0.0f));
	if (side.length_squared() < 0.0000001f) {
		side = dir.cross(Vector3(1.0f, 0.0f, 0.0f));
	}
	side = side.normalized();
	// World-space ribbon thickness. Thin enough to stay sharp, thick enough to read.
	float half = 0.0055f;
	if (p.width > 1.8f) {
		half = 0.0085f;
	}
	side *= half;
	Vector3 lift = side.cross(dir);
	if (lift.length_squared() > 0.0000001f) {
		lift = lift.normalized() * 0.006f;
	} else {
		lift = Vector3(0.0f, 0.006f, 0.0f);
	}
	a += lift;
	b += lift;
	Color ink = p.color;
	vg_depth_push(verts, cols, v, a - side, b - side, b + side, ink);
	vg_depth_push(verts, cols, v, a - side, b + side, a + side, ink);
}

void vg_depth_upload(const Ref<ArrayMesh> &mesh, const PackedVector3Array &verts, const PackedColorArray &cols, int v) {
	if (v < 3) {
		return;
	}
	PackedVector3Array used = verts;
	PackedColorArray used_c = cols;
	used.resize(v);
	used_c.resize(v);
	Array arrays;
	arrays.resize(Mesh::ARRAY_MAX);
	arrays[Mesh::ARRAY_VERTEX] = used;
	arrays[Mesh::ARRAY_COLOR] = used_c;
	mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
}

Ref<ArrayMesh> VGVectorCanvas2D::BuildDepthMesh(float cam_x, float cam_y, float cam_z) {
	(void)cam_x;
	(void)cam_y;
	(void)cam_z;
	const int n = (int)_wire.size();
	int baked = _wire_baked;
	if (baked < 0 || baked > n) {
		baked = n;
	}
	const int mask = (int)_wire_draw_mask;
	// Rooms are baked once. Swap to a cached mesh when the visible mask changes
	// so a smash / door reveal does not rebuild thousands of tris mid-frame.
	if (_depth_baked != _wire_baked || _depth_mask != mask || _depth_mesh.is_null()) {
		Ref<ArrayMesh> hit = _depth_cache_find(mask, baked);
		if (hit.is_valid()) {
			_depth_mesh = hit;
			_depth_baked = baked;
			_depth_mask = mask;
		} else {
			Ref<ArrayMesh> built;
			built.instantiate();
			PackedVector3Array verts;
			PackedColorArray cols;
			verts.resize(baked * 6 + 16);
			cols.resize(baked * 6 + 16);
			int v = 0;
			for (int i = 0; i < baked; ++i) {
				const WirePrim &p = _wire[(size_t)i];
				if (mask != 0 && (p.room >= 31 || (mask & (1 << p.room)) == 0)) {
					continue;
				}
				_depth_append_prim(p, verts, cols, v);
			}
			vg_depth_upload(built, verts, cols, v);
			_depth_cache_store(mask, baked, built);
			_depth_mesh = built;
			_depth_baked = baked;
			_depth_mask = mask;
		}
	}
	if (_depth_mesh.is_null()) {
		_depth_mesh.instantiate();
	}
	while (_depth_mesh->get_surface_count() > 1) {
		_depth_mesh->surface_remove(1);
	}
	if (n > baked) {
		PackedVector3Array verts;
		PackedColorArray cols;
		int dyn = n - baked;
		verts.resize(dyn * 6 + 16);
		cols.resize(dyn * 6 + 16);
		int v = 0;
		for (int i = baked; i < n; ++i) {
			_depth_append_prim(_wire[(size_t)i], verts, cols, v);
		}
		vg_depth_upload(_depth_mesh, verts, cols, v);
	}
	return _depth_mesh;
}

void VGVectorCanvas2D::DrawWire3D(float cam_x, float cam_y, float cam_z, float yaw, float focal, float origin_x, float origin_y, float near_z, float fill_cull, float pitch) {
	_wire_cam_x = cam_x;
	_wire_cam_y = cam_y;
	_wire_cam_z = cam_z;
	_wire_yaw = yaw;
	_wire_focal = focal < 1.0f ? 1.0f : focal;
	_wire_ox = origin_x;
	_wire_oy = origin_y;
	_wire_near = near_z < 0.05f ? 0.05f : near_z;
	_wire_fill_cull = fill_cull;
	_wire_pitch = pitch;
	_wire_draw = true;
	if (!_pending_redraw) {
		_pending_redraw = true;
		queue_redraw();
	}
}

namespace {
struct VgCamPt {
	float x, y, z;
};

void vg_apply_pitch(float cp, float sp, float &y, float &z) {
	float py = y * cp - z * sp;
	float pz = y * sp + z * cp;
	y = py;
	z = pz;
}

float vg_view_z(float wx, float wy, float wz, float cam_x, float cam_y, float cam_z, float cyaw, float syaw, float cpitch, float spitch) {
	float dx = wx - cam_x;
	float dy = wy - cam_y;
	float dz = wz - cam_z;
	float z = dx * syaw + dz * cyaw;
	return dy * spitch + z * cpitch;
}

int vg_clip_tri_near(const VgCamPt in_pts[3], float near_z, VgCamPt out_pts[4]) {
	int n = 0;
	for (int i = 0; i < 3; ++i) {
		VgCamPt a = in_pts[i];
		VgCamPt b = in_pts[(i + 1) % 3];
		bool ain = a.z >= near_z;
		bool bin = b.z >= near_z;
		if (ain && bin) {
			if (n < 4) {
				out_pts[n++] = b;
			}
		} else if (ain != bin) {
			float dz = b.z - a.z;
			if (dz > 0.0001f || dz < -0.0001f) {
				float t = (near_z - a.z) / dz;
				VgCamPt h;
				h.x = a.x + (b.x - a.x) * t;
				h.y = a.y + (b.y - a.y) * t;
				h.z = near_z;
				if (n < 4) {
					out_pts[n++] = h;
				}
			}
			if (!ain && bin && n < 4) {
				out_pts[n++] = b;
			}
		}
	}
	return n;
}
}

void VGVectorCanvas2D::_project_wire3d() {
	const float cyaw = std::cos(_wire_yaw);
	const float syaw = std::sin(_wire_yaw);
	const float cpitch = std::cos(_wire_pitch);
	const float spitch = std::sin(_wire_pitch);
	const float cam_x = _wire_cam_x;
	const float cam_y = _wire_cam_y;
	const float cam_z = _wire_cam_z;
	const float focal = _wire_focal;
	const float ox = _wire_ox;
	const float oy = _wire_oy;
	const float near_z = _wire_near;
	const float clip_z = near_z > _wire_fill_cull ? near_z : _wire_fill_cull;
	const int n = (int)_wire.size();
	const int eye_room = _wire_eye_room;
	// Other rooms draw first. The doorway is a hole, so the next room shows
	// there, and the wall you are standing behind covers everything else.
	auto depth_key = [&](float z, const WirePrim &prim, bool line) -> float {
		float key = z;
		if (line) {
			key -= 0.0002f;
		}
		if (eye_room > 0 && (int)prim.room != eye_room) {
			key += 800.0f;
		}
		return key;
	};
	// Far slices first, so a nearer wall covers the room behind it.
	_wire_spans.clear();
	_wire_spans.reserve((size_t)n);
	for (int i = 0; i < n; ++i) {
		const WirePrim &p = _wire[i];
		if (_wire_draw_mask != 0 && (p.room >= 31 || (_wire_draw_mask & (1u << p.room)) == 0)) {
			continue;
		}
		if (p.has_anchor) {
			float azn = vg_view_z(p.ax, p.ay, p.az, cam_x, cam_y, cam_z, cyaw, syaw, cpitch, spitch);
			if (azn > 0.05f) {
				WireSpan spn;
				spn.index = i;
				spn.t0 = 0.0f;
				spn.t1 = 1.0f;
				// Lines sit just nearer than the fill that shares this anchor.
				spn.key = depth_key(azn + p.anchor_bias, p, p.kind == 0);
				_wire_spans.push_back(spn);
				continue;
			}
		}
		float z0 = vg_view_z(p.x0, p.y0, p.z0, cam_x, cam_y, cam_z, cyaw, syaw, cpitch, spitch);
		float z1 = vg_view_z(p.x1, p.y1, p.z1, cam_x, cam_y, cam_z, cyaw, syaw, cpitch, spitch);
		if (p.kind == 0) {
			float span = z1 - z0;
			if (span < 0.0f) {
				span = -span;
			}
			int parts = 1;
			if (span > 1.0f) {
				parts = (int)(span / 0.65f) + 1;
				if (parts > 16) {
					parts = 16;
				}
			}
			for (int s = 0; s < parts; ++s) {
				float t0 = (float)s / (float)parts;
				float t1 = (float)(s + 1) / (float)parts;
				float za = z0 + (z1 - z0) * t0;
				float zb = z0 + (z1 - z0) * t1;
				if (za < 0.05f && zb < 0.05f) {
					continue;
				}
				float near_pt = za < zb ? za : zb;
				if (near_pt < 0.05f) {
					near_pt = za > zb ? za : zb;
				}
				WireSpan spn;
				spn.index = i;
				spn.t0 = t0;
				spn.t1 = t1;
				spn.key = depth_key(near_pt, p, true);
				_wire_spans.push_back(spn);
			}
		} else {
			float z2 = vg_view_z(p.x2, p.y2, p.z2, cam_x, cam_y, cam_z, cyaw, syaw, cpitch, spitch);
			float near_pt = 1.0e9f;
			if (z0 > 0.05f && z0 < near_pt) near_pt = z0;
			if (z1 > 0.05f && z1 < near_pt) near_pt = z1;
			if (z2 > 0.05f && z2 < near_pt) near_pt = z2;
			WireSpan spn;
			spn.index = i;
			spn.t0 = 0.0f;
			spn.t1 = 1.0f;
			spn.key = near_pt < 1.0e8f ? depth_key(near_pt, p, false) : -1.0f;
			_wire_spans.push_back(spn);
		}
	}
	std::sort(_wire_spans.begin(), _wire_spans.end(), [](const WireSpan &a, const WireSpan &b) {
		return a.key > b.key;
	});
	for (int ord = 0; ord < (int)_wire_spans.size(); ++ord) {
		const WireSpan &spn = _wire_spans[ord];
		const WirePrim &p = _wire[spn.index];
		float dx = p.x0 - cam_x;
		float dy = p.y0 - cam_y;
		float dz = p.z0 - cam_z;
		float ax = dx * cyaw - dz * syaw;
		float ay = dy;
		float az = dx * syaw + dz * cyaw;
		vg_apply_pitch(cpitch, spitch, ay, az);
		dx = p.x1 - cam_x;
		dy = p.y1 - cam_y;
		dz = p.z1 - cam_z;
		float bx = dx * cyaw - dz * syaw;
		float by = dy;
		float bz = dx * syaw + dz * cyaw;
		vg_apply_pitch(cpitch, spitch, by, bz);
		if (p.kind == 0 && (spn.t0 > 0.001f || spn.t1 < 0.999f)) {
			float nx = ax + (bx - ax) * spn.t0;
			float ny = ay + (by - ay) * spn.t0;
			float nz = az + (bz - az) * spn.t0;
			bx = ax + (bx - ax) * spn.t1;
			by = ay + (by - ay) * spn.t1;
			bz = az + (bz - az) * spn.t1;
			ax = nx;
			ay = ny;
			az = nz;
		}
		if (p.kind == 0) {
			if (az < near_z && bz < near_z) {
				continue;
			}
			if (az < near_z) {
				float t = (near_z - az) / (bz - az);
				ax = ax + (bx - ax) * t;
				ay = ay + (by - ay) * t;
				az = near_z;
			} else if (bz < near_z) {
				float t = (near_z - bz) / (az - bz);
				bx = bx + (ax - bx) * t;
				by = by + (ay - by) * t;
				bz = near_z;
			}
			float sc = focal / az;
			float sx0 = ox + ax * sc;
			float sy0 = oy - ay * sc;
			sc = focal / bz;
			_batch_line(sx0, sy0, ox + bx * sc, oy - by * sc, p.width, p.color);
			continue;
		}
		dx = p.x2 - cam_x;
		dy = p.y2 - cam_y;
		dz = p.z2 - cam_z;
		float cx = dx * cyaw - dz * syaw;
		float cy = dy;
		float cz = dx * syaw + dz * cyaw;
		vg_apply_pitch(cpitch, spitch, cy, cz);
		VgCamPt in_pts[3] = { { ax, ay, az }, { bx, by, bz }, { cx, cy, cz } };
		VgCamPt near_pts[4];
		int nout = vg_clip_tri_near(in_pts, clip_z, near_pts);
		if (nout < 3) {
			continue;
		}
		Vector2 screen[4];
		for (int k = 0; k < nout; ++k) {
			float sc = focal / near_pts[k].z;
			screen[k] = Vector2(ox + near_pts[k].x * sc, oy - near_pts[k].y * sc);
		}
		for (int k = 1; k < nout - 1; ++k) {
			_batch_tri(screen[0], screen[k], screen[k + 1], p.color);
		}
	}
}

void VGVectorCanvas2D::_draw_fast_prims() {
	_batch_pos.clear();
	_batch_col.clear();
	size_t reserve_n = _fast_prims.size() * 6;
	if (_wire_draw) {
		reserve_n += _wire.size() * 6;
	}
	_batch_pos.reserve(reserve_n);
	_batch_col.reserve(reserve_n);
	if (_wire_draw) {
		_project_wire3d();
		_wire_draw = false;
	}
	for (int i = 0; i < (int)_fast_prims.size(); ++i) {
		const FastPrim &p = _fast_prims[i];
		if (p.is_line) {
			_batch_line(p.x0, p.y0, p.x1, p.y1, p.width, p.color);
			continue;
		}
		if (p.cmd_index < 0 || p.cmd_index >= _commands.size()) {
			continue;
		}
		Dictionary cmd = _commands[p.cmd_index];
		Variant vis = cmd.get("_visible", true);
		if (vis.get_type() == Variant::BOOL && !(bool)vis) {
			continue;
		}
		int t = (int)cmd["type"];
		if (t == CMD_POLYGON) {
			Transform2D xf = (Transform2D)cmd["transform"];
			PackedVector2Array pts = _transform_points_packed((PackedVector2Array)cmd["points"], xf);
			Color fill = (bool)cmd["fill"] ? (Color)cmd["fill_color"] : Color(0, 0, 0, 0);
			float width = (float)cmd["width"];
			_batch_polygon(pts, fill, width, (Color)cmd["color"]);
			continue;
		}
		_flush_batch_mesh();
		_dispatch_command(cmd, t);
	}
	_flush_batch_mesh();
}

void VGVectorCanvas2D::_draw() {
	_pending_redraw = false;
	_sprite_pool_index = 0;
	if (_wire_draw || !_fast_prims.empty()) {
		_draw_fast_prims();
		return;
	}
	int n = _commands.size();

	// Batch mode: collect all CMD_LINE segments with matching (color, width)
	// into groups and emit as draw_multiline() calls — reduces N draw calls to
	// at most N_unique_colors draw calls. Off by default; enable with
	// Canvas.SetBatchMode(True) before drawing. Useful for starfields, grids,
	// and other scenes with many same-color lines.
	if (_batch_mode) {
		// Two-pass: first collect non-line commands and line groups, then draw.
		struct LineGroup {
			PackedVector2Array pts;
			Color color;
			float width;
		};
		std::vector<LineGroup> groups;
		// Map (color_as_uint64, width_as_bits) → group index — simple linear
		// scan is fine for the typical <20 unique colors per frame.
		auto find_group = [&](const Color &c, float w) -> int {
			for (int g = 0; g < (int)groups.size(); ++g) {
				if (groups[g].color == c && groups[g].width == w) return g;
			}
			groups.push_back({PackedVector2Array(), c, w});
			return (int)groups.size() - 1;
		};
		for (int i = 0; i < n; ++i) {
			Dictionary cmd = _commands[i];
			Variant vis = cmd.get("_visible", true);
			if (vis.get_type() == Variant::BOOL && !(bool)vis) continue;
			int t = (int)cmd["type"];
			if (t == CMD_LINE) {
				Transform2D xf = (Transform2D)cmd["transform"];
				Color col = (Color)cmd["color"];
				float w   = (float)cmd["width"];
				int g = find_group(col, w);
				groups[g].pts.append(xf.xform((Vector2)cmd["from"]));
				groups[g].pts.append(xf.xform((Vector2)cmd["to"]));
			} else {
				// Flush accumulated lines before any non-line command.
				for (auto &g : groups) {
					const int np = g.pts.size();
					for (int li = 0; li + 1 < np; li += 2) {
						vg_add_line(this, g.pts[li], g.pts[li + 1], g.color, g.width);
					}
				}
				groups.clear();
				_dispatch_command(cmd, t);
			}
		}
		for (auto &g : groups) {
			const int np = g.pts.size();
			for (int li = 0; li + 1 < np; li += 2) {
				vg_add_line(this, g.pts[li], g.pts[li + 1], g.color, g.width);
			}
		}
		return;
	}

	for (int i = 0; i < n; ++i) {
		Dictionary cmd = _commands[i];
		Variant vis = cmd.get("_visible", true);
		if (vis.get_type() == Variant::BOOL && !(bool)vis) {
			continue;
		}
		_dispatch_command(cmd, (int)cmd["type"]);
	}
}

void VGVectorCanvas2D::_dispatch_command(const Dictionary &cmd, int t) {
	switch (t) {
		case CMD_LINE:
			_draw_line_command(cmd);
			break;
		case CMD_RECT:
			_draw_rect_command(cmd);
			break;
		case CMD_ROUNDED_RECT:
			_draw_rounded_rect_command(cmd);
			break;
		case CMD_ELLIPSE:
			_draw_ellipse_command(cmd);
			break;
		case CMD_ARC:
			_draw_arc_command(cmd);
			break;
		case CMD_PIE_SLICE:
			_draw_pie_slice_command(cmd);
			break;
		case CMD_POLYGON:
			_draw_polygon_command(cmd);
			break;
		case CMD_POLYLINE:
			_draw_polyline_command(cmd);
			break;
		case CMD_TEXT:
			_draw_text_command(cmd);
			break;
		case CMD_MULTILINE:
			_draw_multiline_command(cmd);
			break;
		case CMD_SPRITE_LINES:
			_draw_sprite_lines_command(cmd);
			break;
		case CMD_RECTS:
			_draw_rects_command(cmd);
			break;
		case CMD_RECTS_UNIFORM:
			_draw_rects_uniform_command(cmd);
			break;
		case CMD_PLASMA_CELLS:
			_draw_plasma_cells_command(cmd);
			break;
		case CMD_TORUS_WIREFRAME:
			_draw_torus_wireframe_command(cmd);
			break;
		case CMD_FIRE_CELLS:
			_draw_fire_cells_command(cmd);
			break;
		case CMD_MULTILINE_COLORS:
			_draw_multiline_colors_command(cmd);
			break;
		case CMD_RAW_WIRE_MESH:
			_draw_raw_wire_mesh_command(cmd);
			break;
		default:
			break;
	}
}

void VGVectorCanvas2D::_draw_line_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Vector2 from = t.xform((Vector2)cmd["from"]);
	Vector2 to = t.xform((Vector2)cmd["to"]);
	vg_add_line(this, from, to, (Color)cmd["color"], (float)cmd["width"]);
}

void VGVectorCanvas2D::_draw_rect_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Rect2 rect = (Rect2)cmd["rect"];
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	Color color = (Color)cmd["color"];
	Color fc = (Color)cmd["fill_color"];

	if (t == Transform2D()) {
		if (fill) {
			vg_add_rect(this, rect, fc, true, 0.0f);
		}
		if (width > 0.0f) {
			vg_add_rect(this, rect, color, false, width);
		}
	} else {
		PackedVector2Array points = _transform_points_array(_rect_corner_points(rect), t);
		if (fill) {
			vg_add_polygon(this, points, _make_fill_color_array(fc, points.size()));
		}
		if (width > 0.0f) {
			PackedVector2Array outline = points;
			if (points.size() > 0) {
				outline.append(points[0]);
			}
			vg_add_polyline(this, outline, color, width);
		}
	}
}

void VGVectorCanvas2D::_draw_rects_command(const Dictionary &cmd) {
	// rects_xywh: flat PackedVector2Array — pairs (pos, size) per rect
	// colors: one Color per rect (PackedColorArray)
	PackedVector2Array rects = (PackedVector2Array)cmd["rects"];
	PackedColorArray colors = (PackedColorArray)cmd["colors"];
	bool fill = (bool)cmd["fill"];
	int n = rects.size() / 2;
	for (int i = 0; i < n; i++) {
		Vector2 pos = rects[i * 2];
		Vector2 sz  = rects[i * 2 + 1];
		Rect2 rect(pos, sz);
		Color c = (i < colors.size()) ? colors[i] : Color(1, 1, 1, 1);
		if (fill) {
			vg_add_rect(this, rect, c, true, 0.0f);
		} else {
			vg_add_rect(this, rect, c, false, 1.0f);
		}
	}
}

void VGVectorCanvas2D::_draw_rects_uniform_command(const Dictionary &cmd) {
	PackedVector2Array rects = (PackedVector2Array)cmd["rects"];
	Color color = (Color)cmd["color"];
	bool fill = (bool)cmd["fill"];
	int n = rects.size() / 2;
	for (int i = 0; i < n; i++) {
		Vector2 pos = rects[i * 2];
		Vector2 sz  = rects[i * 2 + 1];
		Rect2 rect(pos, sz);
		if (fill) {
			vg_add_rect(this, rect, color, true, 0.0f);
		} else {
			vg_add_rect(this, rect, color, false, 1.0f);
		}
	}
}

void VGVectorCanvas2D::_draw_plasma_cells_command(const Dictionary &cmd) {
	int gw     = (int)(int64_t)cmd["gw"];
	int gh     = (int)(int64_t)cmd["gh"];
	int parity = (int)(int64_t)cmd["parity"];
	float spd  = (float)(double)cmd["spd"];
	float fade = (float)(double)cmd["fade"];
	float pw   = (float)(double)cmd["pw"];
	float ph   = (float)(double)cmd["ph"];
	const float TAU = 6.28318530718f;
	for (int cy = 0; cy < gh; ++cy) {
		for (int cx = 0; cx < gw; ++cx) {
			if ((cx + cy) % 2 != parity) continue;
			float v = ::sinf(cx * 0.42f + spd)
					+ ::sinf(cy * 0.31f + spd * 1.07f)
					+ ::sinf((cx + cy) * 0.23f + spd * 0.73f);
			v = (v + 3.0f) / 6.0f;
			float cr = ::sinf(v * TAU) * 0.5f + 0.5f;
			float cg = ::sinf(v * TAU + 2.094f) * 0.5f + 0.5f;
			float cb = ::sinf(v * TAU + 4.189f) * 0.5f + 0.5f;
			vg_add_rect(this, Rect2(cx * pw, cy * ph, pw + 1.0f, ph + 1.0f), Color(cr, cg, cb, fade), true, 0.0f);
		}
	}
}

void VGVectorCanvas2D::_draw_torus_wireframe_command(const Dictionary &cmd) {
	float rot_y  = (float)(double)cmd["rot_y"];
	float rot_x  = (float)(double)cmd["rot_x"];
	float hue_off= (float)(double)cmd["hue_off"];
	float tt     = (float)(double)cmd["tt"];
	float fade   = (float)(double)cmd["fade"];
	float vcx    = (float)(double)cmd["cx"];
	float vcy    = (float)(double)cmd["cy"];
	const int U = 20, V = 14;
	float scale_v = cmd.has("scale") ? (float)(double)cmd["scale"] : 1.0f;
	const float R = 0.68f, r = 0.27f, proj_d = 3.4f;
	const float scale = 320.0f * scale_v;
	const float TAU = 6.28318530718f;
	float cos_ry = ::cosf(rot_y), sin_ry = ::sinf(rot_y);
	float cos_rx = ::cosf(rot_x), sin_rx = ::sinf(rot_x);

	// Batch all U*V line segments into a single draw_multiline_colors call.
	// Reduces ~280 individual draw_line() calls to 1 GPU-side batch.
	const int SEG = U * V;
	PackedVector2Array pts;  pts.resize(SEG * 2);
	PackedColorArray   cols; cols.resize(SEG);

	int seg = 0;
	for (int ui = 0; ui < U; ++ui) {
		float u0 = ui * TAU / U;
		float u1 = (ui + 1) * TAU / U;
		float hue = (float)ui / U + tt * 0.08f + hue_off;
		hue -= ::floorf(hue);
		float cr = ::sinf(hue * TAU) * 0.5f + 0.5f;
		float cg = ::sinf(hue * TAU + 2.094f) * 0.5f + 0.5f;
		float cb = ::sinf(hue * TAU + 4.189f) * 0.5f + 0.5f;
		Color c(cr, cg, cb, fade * 0.85f);
		for (int vi = 0; vi < V; ++vi) {
			float v0 = vi * TAU / V;
			// Point A (u0, v0)
			float rcv0 = r * ::cosf(v0), rsv0 = r * ::sinf(v0);
			float ax3  = (R + rcv0) * ::cosf(u0);
			float ay3  = (R + rcv0) * ::sinf(u0);
			float az3  = rsv0;
			float ax3r = ax3 * cos_ry + az3 * sin_ry;
			float az3r = -ax3 * sin_ry + az3 * cos_ry;
			float ay3f = ay3 * cos_rx - az3r * sin_rx;
			float az3f = ay3 * sin_rx + az3r * cos_rx + proj_d;
			if (az3f < 0.1f) az3f = 0.1f;
			// Point B (u1, v0)
			float bx3  = (R + rcv0) * ::cosf(u1);
			float by3  = (R + rcv0) * ::sinf(u1);
			float bz3  = rsv0;
			float bx3r = bx3 * cos_ry + bz3 * sin_ry;
			float bz3r = -bx3 * sin_ry + bz3 * cos_ry;
			float by3f = by3 * cos_rx - bz3r * sin_rx;
			float bz3f = by3 * sin_rx + bz3r * cos_rx + proj_d;
			if (bz3f < 0.1f) bz3f = 0.1f;
			pts[seg * 2]     = Vector2(ax3r / az3f * scale + vcx, ay3f / az3f * scale + vcy);
			pts[seg * 2 + 1] = Vector2(bx3r / bz3f * scale + vcx, by3f / bz3f * scale + vcy);
			cols[seg]        = c;
			++seg;
		}
	}
	vg_draw_solid_segments(this, pts, cols, 1.4f);
}

void VGVectorCanvas2D::_draw_rounded_rect_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Array raw = _rounded_rect_corner_points((Rect2)cmd["rect"], (float)cmd["radius"], (int)cmd["segments"]);
	PackedVector2Array points = _transform_points_array(raw, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		vg_add_polygon(this, points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		PackedVector2Array outline = points;
		if (points.size() > 0) {
			outline.append(points[0]);
		}
		vg_add_polyline(this, outline, (Color)cmd["color"], width);
	}
}

void VGVectorCanvas2D::_draw_ellipse_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Array raw = _ellipse_corner_points((Rect2)cmd["rect"], (int)cmd["segments"]);
	PackedVector2Array points = _transform_points_array(raw, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		vg_add_polygon(this, points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		vg_add_polyline(this, points, (Color)cmd["color"], width);
	}
}

void VGVectorCanvas2D::_draw_arc_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Vector2 center = (Vector2)cmd["center"];
	Array raw = _arc_corner_points(center, (float)cmd["radius"],
			(float)cmd["start_angle"], (float)cmd["end_angle"], (int)cmd["segments"]);
	PackedVector2Array points = _transform_points_array(raw, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	Color color = (Color)cmd["color"];
	if (fill) {
		PackedVector2Array filled = points;
		filled.append(t.xform(center));
		vg_add_polygon(this, filled, _make_fill_color_array((Color)cmd["fill_color"], filled.size()));
	}
	if (width > 0.0f || !fill) {
		vg_add_polyline(this, points, color, width > 0.0f ? width : 1.0f);
	}
}

void VGVectorCanvas2D::_draw_pie_slice_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Vector2 center = (Vector2)cmd["center"];
	Array raw = _arc_corner_points(center, (float)cmd["radius"],
			(float)cmd["start_angle"], (float)cmd["end_angle"], (int)cmd["segments"]);
	// Insert center at the front (matches GDScript: points.insert(0, center)).
	Array with_center;
	with_center.append(center);
	for (int i = 0; i < raw.size(); ++i) {
		with_center.append(raw[i]);
	}
	PackedVector2Array points = _transform_points_array(with_center, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		vg_add_polygon(this, points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f && points.size() > 1) {
		PackedVector2Array outline = points;
		outline.append(points[1]); // close back to first arc point, not center
		vg_add_polyline(this, outline, (Color)cmd["color"], width);
	}
}

void VGVectorCanvas2D::_draw_polygon_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	PackedVector2Array points = _transform_points_packed((PackedVector2Array)cmd["points"], t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		vg_add_polygon(this, points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		PackedVector2Array outline = points;
		if (outline.size() > 0) {
			outline.append(outline[0]);
		}
		vg_add_polyline(this, outline, (Color)cmd["color"], width);
	}
}

void VGVectorCanvas2D::_draw_polyline_command(const Dictionary &cmd) {
	PackedVector2Array points;
	if (cmd.has("absolute") && (bool)cmd["absolute"]) {
		points = (PackedVector2Array)cmd["points"];
	} else {
		Transform2D t = (Transform2D)cmd["transform"];
		points = _transform_points_packed((PackedVector2Array)cmd["points"], t);
	}
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	bool close = (bool)cmd["close"];
	if (fill) {
		vg_add_polygon(this, points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		if (close && points.size() > 0) {
			PackedVector2Array outline = points;
			outline.append(points[0]);
			vg_add_polyline(this, outline, (Color)cmd["color"], width);
		} else {
			vg_add_polyline(this, points, (Color)cmd["color"], width);
		}
	}
}

void VGVectorCanvas2D::_draw_multiline_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	PackedVector2Array segments = _transform_points_packed((PackedVector2Array)cmd["segments"], t);
	float width = (float)cmd["width"];
	Color color = (Color)cmd["color"];
	// Drop trailing odd point if any (segments must come in pairs).
	int sz = segments.size();
	if (sz < 2) {
		return;
	}
	if (sz & 1) {
		segments.resize(sz - 1);
	}
	vg_add_multiline(this, segments, color, width);
}

namespace {
bool vg_clip_segment(Vector2 &a, Vector2 &b, const Rect2 &rect);
Rect2 vg_line_clip_rect(Node2D *node);
void vg_draw_solid_segments(CanvasItem *item, const PackedVector2Array &pts, const PackedColorArray &cols, float width);
}

void VGVectorCanvas2D::_draw_multiline_colors_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	PackedVector2Array segments = _transform_points_packed((PackedVector2Array)cmd["segments"], t);
	PackedColorArray colors = (PackedColorArray)cmd["colors"];
	float width = (float)cmd["width"];
	int sz = segments.size();
	if (sz < 2 || colors.size() < 1) {
		return;
	}
	if (sz & 1) {
		segments.resize(sz - 1);
		sz = segments.size();
	}
	int seg_count = sz / 2;
	if (colors.size() < (uint32_t)seg_count) {
		Color fill = Color(1, 1, 1, 1);
		PackedColorArray padded;
		padded.resize(seg_count);
		for (int i = 0; i < seg_count; i++) {
			padded[i] = (i < colors.size()) ? colors[i] : fill;
		}
		colors = padded;
	}
	Rect2 clip = vg_line_clip_rect(this);
	PackedVector2Array kept;
	PackedColorArray kept_cols;
	for (int i = 0; i < seg_count; i++) {
		Vector2 a = segments[i * 2];
		Vector2 b = segments[i * 2 + 1];
		if (!vg_clip_segment(a, b, clip)) {
			continue;
		}
		kept.append(a);
		kept.append(b);
		kept_cols.append(colors[i]);
	}
	if (kept.size() < 2) {
		return;
	}
	vg_draw_solid_segments(this, kept, kept_cols, width);
}

namespace {

void vg_rotate_yxz(float &x, float &y, float &z, float rot_y, float rot_x, float rot_z) {
	float cos_ry = ::cosf(rot_y);
	float sin_ry = ::sinf(rot_y);
	float xr = x * cos_ry + z * sin_ry;
	float zr = -x * sin_ry + z * cos_ry;
	float cos_rx = ::cosf(rot_x);
	float sin_rx = ::sinf(rot_x);
	float yr = y * cos_rx - zr * sin_rx;
	float zf = y * sin_rx + zr * cos_rx;
	float cos_rz = ::cosf(rot_z);
	float sin_rz = ::sinf(rot_z);
	x = xr * cos_rz - yr * sin_rz;
	y = xr * sin_rz + yr * cos_rz;
	z = zf;
}

// Keep line endpoints inside the view. The compatibility renderer smears
// segments whose ends lie far off-screen back into the viewport as dashes
// that stick in place while the camera pitches.
int vg_clip_outcode(float x, float y, float xmin, float ymin, float xmax, float ymax) {
	int c = 0;
	if (x < xmin) {
		c |= 1;
	} else if (x > xmax) {
		c |= 2;
	}
	if (y < ymin) {
		c |= 4;
	} else if (y > ymax) {
		c |= 8;
	}
	return c;
}

bool vg_clip_segment(Vector2 &a, Vector2 &b, const Rect2 &rect) {
	const float xmin = rect.position.x;
	const float ymin = rect.position.y;
	const float xmax = xmin + rect.size.x;
	const float ymax = ymin + rect.size.y;
	float x0 = a.x;
	float y0 = a.y;
	float x1 = b.x;
	float y1 = b.y;
	for (int n = 0; n < 12; n++) {
		int c0 = vg_clip_outcode(x0, y0, xmin, ymin, xmax, ymax);
		int c1 = vg_clip_outcode(x1, y1, xmin, ymin, xmax, ymax);
		if ((c0 | c1) == 0) {
			a = Vector2(x0, y0);
			b = Vector2(x1, y1);
			return true;
		}
		if (c0 & c1) {
			return false;
		}
		int c = c0 ? c0 : c1;
		float x = x0;
		float y = y0;
		if (c & 1) {
			float dx = x1 - x0;
			if (dx == 0.0f) {
				return false;
			}
			y = y0 + (y1 - y0) * (xmin - x0) / dx;
			x = xmin;
		} else if (c & 2) {
			float dx = x1 - x0;
			if (dx == 0.0f) {
				return false;
			}
			y = y0 + (y1 - y0) * (xmax - x0) / dx;
			x = xmax;
		} else if (c & 4) {
			float dy = y1 - y0;
			if (dy == 0.0f) {
				return false;
			}
			x = x0 + (x1 - x0) * (ymin - y0) / dy;
			y = ymin;
		} else {
			float dy = y1 - y0;
			if (dy == 0.0f) {
				return false;
			}
			x = x0 + (x1 - x0) * (ymax - y0) / dy;
			y = ymax;
		}
		if (c == c0) {
			x0 = x;
			y0 = y;
		} else {
			x1 = x;
			y1 = y;
		}
	}
	return false;
}

Rect2 vg_line_clip_rect(Node2D *node) {
	Rect2 view(0, 0, 4096, 4096);
	if (!node) {
		return view;
	}
	Viewport *vp = node->get_viewport();
	if (vp) {
		Rect2 vr = vp->get_visible_rect();
		if (vr.size.x > 1.0f && vr.size.y > 1.0f) {
			view = vr.grow(4.0f);
		}
	}
	return view;
}

void vg_draw_solid_segments(CanvasItem *item, const PackedVector2Array &pts, const PackedColorArray &cols, float width) {
	if (!item) {
		return;
	}
	const int n = pts.size() / 2;
	const float hw = width * 0.5f;
	if (hw < 0.05f) {
		return;
	}
	for (int i = 0; i < n; i++) {
		Vector2 a = pts[i * 2];
		Vector2 b = pts[i * 2 + 1];
		Vector2 d = b - a;
		float len = d.length();
		if (len < 0.001f) {
			continue;
		}
		Vector2 nrm(-d.y / len * hw, d.x / len * hw);
		PackedVector2Array quad;
		quad.resize(4);
		quad.set(0, a - nrm);
		quad.set(1, a + nrm);
		quad.set(2, b + nrm);
		quad.set(3, b - nrm);
		Color c = (i < cols.size()) ? cols[i] : Color(1, 1, 1, 1);
		PackedColorArray cc;
		cc.resize(4);
		cc.set(0, c);
		cc.set(1, c);
		cc.set(2, c);
		cc.set(3, c);
		vg_add_polygon(item, quad, cc);
	}
}

} // namespace

void VGVectorCanvas2D::_draw_raw_wire_mesh_command(const Dictionary &cmd) {
	PackedVector3Array verts = (PackedVector3Array)cmd["vertices"];
	PackedInt32Array edges = (PackedInt32Array)cmd["edges"];
	if (verts.size() < 2 || edges.size() < 2) {
		return;
	}
	float rot_x = (float)(double)cmd["rot_x"];
	float rot_y = (float)(double)cmd["rot_y"];
	float rot_z = (float)(double)cmd["rot_z"];
	float cx = (float)(double)cmd["cx"];
	float cy = (float)(double)cmd["cy"];
	float scale = (float)(double)cmd["scale"];
	float z_depth = (float)(double)cmd["z_depth"];
	float width = (float)cmd["width"];
	Color fallback = (Color)cmd["color"];
	PackedColorArray edge_colors;
	if (cmd.has("edge_colors")) {
		edge_colors = (PackedColorArray)cmd["edge_colors"];
	}
	float offset_x = 0.0f;
	float offset_y = 0.0f;
	float offset_z = 0.0f;
	if (cmd.has("offset_x")) {
		offset_x = (float)(double)cmd["offset_x"];
		offset_y = (float)(double)cmd["offset_y"];
		offset_z = (float)(double)cmd["offset_z"];
	}
	const int edge_pairs = edges.size() / 2;
	if (edge_pairs < 1) {
		return;
	}
	PackedVector2Array pts;
	pts.resize(edge_pairs * 2);
	PackedColorArray cols;
	cols.resize(edge_pairs);
	Rect2 clip = vg_line_clip_rect(this);
	int out_seg = 0;
	for (int e = 0; e < edge_pairs; e++) {
		int i0 = edges[e * 2];
		int i1 = edges[e * 2 + 1];
		if (i0 < 0 || i1 < 0 || i0 >= verts.size() || i1 >= verts.size()) {
			continue;
		}
		Vector3 v0 = verts[i0];
		Vector3 v1 = verts[i1];
		float x0 = v0.x;
		float y0 = v0.y;
		float z0 = v0.z;
		float x1 = v1.x;
		float y1 = v1.y;
		float z1 = v1.z;
		vg_rotate_yxz(x0, y0, z0, rot_y, rot_x, rot_z);
		vg_rotate_yxz(x1, y1, z1, rot_y, rot_x, rot_z);
		x0 += offset_x;
		y0 += offset_y;
		z0 += offset_z;
		x1 += offset_x;
		y1 += offset_y;
		z1 += offset_z;
		float z0p = z0 + z_depth;
		float z1p = z1 + z_depth;
		if (z0p < 0.05f || z1p < 0.05f) {
			continue;
		}
		Vector2 s0(x0 / z0p * scale + cx, -y0 / z0p * scale + cy);
		Vector2 s1(x1 / z1p * scale + cx, -y1 / z1p * scale + cy);
		if (!vg_clip_segment(s0, s1, clip)) {
			continue;
		}
		pts[out_seg * 2] = s0;
		pts[out_seg * 2 + 1] = s1;
		cols[out_seg] = (e < edge_colors.size()) ? edge_colors[e] : fallback;
		out_seg++;
	}
	if (out_seg < 1) {
		return;
	}
	if (out_seg < edge_pairs) {
		pts.resize(out_seg * 2);
		cols.resize(out_seg);
	}
	vg_draw_solid_segments(this, pts, cols, width);
}

void VGVectorCanvas2D::_draw_sprite_lines_command(const Dictionary &cmd) {
	Ref<Texture2D> tex = cmd["texture"];
	if (tex.is_null()) {
		return;
	}
	PackedVector2Array segs = _transform_points_packed((PackedVector2Array)cmd["segments"], (Transform2D)cmd["transform"]);
	int n_inst = segs.size() / 2;
	if (n_inst <= 0) {
		return;
	}
	float width = (float)cmd["width"];
	Color tint = (Color)cmd["color"];

	// Lazy-init shared QuadMesh (unit quad in XY plane, centered at origin).
	if (_sprite_quad.is_null()) {
		_sprite_quad.instantiate();
		_sprite_quad->set_size(Vector2(1.0f, 1.0f));
	}
	// Grab a MultiMesh from the per-frame pool, allocating if needed.
	while (_sprite_pool_index >= _sprite_multimesh_pool.size()) {
		Ref<MultiMesh> mm;
		mm.instantiate();
		mm->set_transform_format(MultiMesh::TRANSFORM_2D);
		mm->set_use_colors(true);
		mm->set_mesh(_sprite_quad);
		_sprite_multimesh_pool.push_back(mm);
	}
	Ref<MultiMesh> mm = _sprite_multimesh_pool[_sprite_pool_index++];
	mm->set_instance_count(n_inst);

	const Vector2 *pts = segs.ptr();
	for (int i = 0; i < n_inst; ++i) {
		Vector2 a = pts[i * 2];
		Vector2 b = pts[i * 2 + 1];
		Vector2 dir = b - a;
		float len = dir.length();
		if (len < 0.0001f) {
			len = 1.0f;
		}
		float ang = std::atan2(dir.y, dir.x);
		Vector2 mid = (a + b) * 0.5f;
		float cs = std::cos(ang);
		float sn = std::sin(ang);
		// Column-major Transform2D: x basis = (cos*len, sin*len),
		// y basis = (-sin*width, cos*width), origin = mid.
		Transform2D xf(Vector2(cs * len, sn * len), Vector2(-sn * width, cs * width), mid);
		mm->set_instance_transform_2d(i, xf);
		mm->set_instance_color(i, tint);
	}

	RID tex_rid = tex.is_valid() ? tex->get_rid() : RID();
	RID mm_rid = mm.is_valid() ? mm->get_rid() : RID();
	if (mm_rid.is_valid()) {
		RenderingServer::get_singleton()->canvas_item_add_multimesh(get_canvas_item(), mm_rid, tex_rid);
	}
}

void VGVectorCanvas2D::DrawSpriteLines(const Ref<Texture2D> &texture, const PackedVector2Array &segments, float width, const Color &color) {
	Dictionary c;
	c["type"] = (int)CMD_SPRITE_LINES;
	c["texture"] = texture;
	c["segments"] = segments;
	c["width"] = width;
	c["color"] = color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

Ref<Texture2D> VGVectorCanvas2D::MakeGlowTexture(int size, const Color &core_color) {
	if (size < 2) {
		size = 2;
	}
	Ref<Image> img = Image::create_empty(size, size, false, Image::FORMAT_RGBA8);
	float half = (size - 1) * 0.5f;
	for (int y = 0; y < size; ++y) {
		float ny = (y - half) / half; // -1..1 across the short axis
		float fy = 1.0f - ny * ny;
		if (fy < 0.0f) {
			fy = 0.0f;
		}
		// Sharper bright core in the middle, soft halo at the edges.
		float core = fy * fy * fy;
		for (int x = 0; x < size; ++x) {
			float nx = (x - half) / half;
			float fx = 1.0f - nx * nx * 0.4f; // mild end-fade
			if (fx < 0.0f) {
				fx = 0.0f;
			}
			float a = core * fx * core_color.a;
			if (a < 0.0f) {
				a = 0.0f;
			}
			if (a > 1.0f) {
				a = 1.0f;
			}
			img->set_pixel(x, y, Color(core_color.r, core_color.g, core_color.b, a));
		}
	}
	Ref<ImageTexture> tex = ImageTexture::create_from_image(img);
	return tex;
}

Ref<Texture2D> VGVectorCanvas2D::MakeRadialGlowTexture(int size, const Color &core_color) {
	if (size < 2) {
		size = 2;
	}
	Ref<Image> img = Image::create_empty(size, size, false, Image::FORMAT_RGBA8);
	float half = (size - 1) * 0.5f;
	for (int y = 0; y < size; ++y) {
		float ny = (y - half) / half;
		for (int x = 0; x < size; ++x) {
			float nx = (x - half) / half;
			float r2 = nx * nx + ny * ny;
			float f = 1.0f - r2;
			if (f < 0.0f) {
				f = 0.0f;
			}
			// Bright hot core, soft falloff: f^3 keeps a tight bright center
			// with a gentle additive halo around it.
			float a = f * f * f * core_color.a;
			if (a > 1.0f) {
				a = 1.0f;
			}
			img->set_pixel(x, y, Color(core_color.r, core_color.g, core_color.b, a));
		}
	}
	Ref<ImageTexture> tex = ImageTexture::create_from_image(img);
	return tex;
}

void VGVectorCanvas2D::SetAdditiveBlend(bool enable) {
	if (enable) {
		if (_additive_material.is_null()) {
			_additive_material.instantiate();
			_additive_material->set_blend_mode(CanvasItemMaterial::BLEND_MODE_ADD);
		}
		set_material(_additive_material);
	} else {
		set_material(Ref<Material>());
	}
}

void VGVectorCanvas2D::SetBatchMode(bool enable) {
	_batch_mode = enable;
}

void VGVectorCanvas2D::_draw_text_command(const Dictionary &cmd) {
	Variant font_v = cmd.get("font", Variant());
	String text = (String)cmd["text"];
	Color color = (Color)cmd["color"];
	String align = (String)cmd.get("align", "left");
	Transform2D t = (Transform2D)cmd["transform"];
	Vector2 position = t.xform((Vector2)cmd["position"]);

	if (font_v.get_type() == Variant::NIL && !text.is_empty()) {
		// Stroke immediately. DrawVectorText queues commands — calling it
		// from _draw grew the buffer every frame and forced a redraw loop.
		_emit_vector_text(position, text, color, 1.0f, 2.0f, align, 2.0f, String(""), false);
		return;
	}
	if (font_v.get_type() == Variant::STRING) {
		_emit_vector_text(position, text, color, 1.0f, 2.0f, align, 2.0f, (String)font_v, false);
		return;
	}
	Ref<Font> font;
	if (font_v.get_type() == Variant::OBJECT) {
		font = Ref<Font>(font_v);
	}
	if (font.is_null()) {
		font = _default_font;
	}
	if (font.is_valid()) {
		Vector2 text_size = font->get_string_size(text);
		Vector2 pos = position;
		if (align == "center") {
			pos.x -= text_size.x * 0.5f;
		} else if (align == "right") {
			pos.x -= text_size.x;
		}
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, color);
	}
}

// ---------------------------------------------------------------------------
// Public Draw* — queue methods.
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::DrawLine(const Vector2 &from, const Vector2 &to, float width, const Color &color) {
	if (!_overlay_in_use() && _get_current_transform() == Transform2D()) {
		FastPrim prim;
		prim.is_line = true;
		prim.x0 = from.x;
		prim.y0 = from.y;
		prim.x1 = to.x;
		prim.y1 = to.y;
		prim.width = width;
		prim.color = color;
		_fast_prims.push_back(prim);
		if (!_pending_redraw) {
			_pending_redraw = true;
			queue_redraw();
		}
		return;
	}
	Dictionary c;
	c["type"] = (int)CMD_LINE;
	c["from"] = from;
	c["to"] = to;
	c["width"] = width;
	c["color"] = color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawRect(const Rect2 &rect, float width, const Color &color, bool fill, const Color &fill_color) {
	Dictionary c;
	c["type"] = (int)CMD_RECT;
	c["rect"] = rect;
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawRoundedRect(const Rect2 &rect, float radius, float width, const Color &color, bool fill, const Color &fill_color, int segments) {
	Dictionary c;
	c["type"] = (int)CMD_ROUNDED_RECT;
	c["rect"] = rect;
	c["radius"] = radius;
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["segments"] = segments;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawEllipse(const Rect2 &rect, float width, const Color &color, bool fill, const Color &fill_color, int segments) {
	Dictionary c;
	c["type"] = (int)CMD_ELLIPSE;
	c["rect"] = rect;
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["segments"] = segments;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawArc(const Vector2 &center, float radius, float start_angle, float end_angle, int segments, float width, const Color &color, bool fill, const Color &fill_color) {
	Dictionary c;
	c["type"] = (int)CMD_ARC;
	c["center"] = center;
	c["radius"] = radius;
	c["start_angle"] = start_angle;
	c["end_angle"] = end_angle;
	c["segments"] = segments;
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawPolygon(const Array &points, float width, const Color &color, bool fill, const Color &fill_color) {
	Dictionary c;
	c["type"] = (int)CMD_POLYGON;
	c["points"] = PackedVector2Array(points);
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawPolyline(const Array &points, float width, const Color &color, bool fill, const Color &fill_color, bool close) {
	Dictionary c;
	c["type"] = (int)CMD_POLYLINE;
	c["points"] = PackedVector2Array(points);
	c["width"] = width;
	c["color"] = color;
	c["fill"] = fill;
	c["fill_color"] = fill_color;
	c["close"] = close;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawLines(const PackedVector2Array &segments, float width, const Color &color) {
	Dictionary c;
	c["type"] = (int)CMD_MULTILINE;
	c["segments"] = segments;
	c["width"] = width;
	c["color"] = color;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawLinesColored(const PackedVector2Array &segments, const PackedColorArray &colors, float width) {
	Dictionary c;
	c["type"] = (int)CMD_MULTILINE_COLORS;
	c["segments"] = segments;
	c["colors"] = colors;
	c["width"] = width;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawRawWireMesh(const PackedVector3Array &vertices, const PackedInt32Array &edges,
		float rot_x, float rot_y, float rot_z, float cx, float cy, float scale, float z_depth,
		float width, const Color &color, const PackedColorArray &edge_colors,
		float offset_x, float offset_y, float offset_z) {
	Dictionary c;
	c["type"] = (int)CMD_RAW_WIRE_MESH;
	c["vertices"] = vertices;
	c["edges"] = edges;
	c["rot_x"] = rot_x;
	c["rot_y"] = rot_y;
	c["rot_z"] = rot_z;
	c["cx"] = cx;
	c["cy"] = cy;
	c["scale"] = scale;
	c["z_depth"] = z_depth;
	c["width"] = width;
	c["color"] = color;
	c["edge_colors"] = edge_colors;
	c["offset_x"] = offset_x;
	c["offset_y"] = offset_y;
	c["offset_z"] = offset_z;
	_queue_command(c);
}

void VGVectorCanvas2D::DrawRects(const PackedVector2Array &rects_xywh, const PackedColorArray &colors, bool fill) {
	Dictionary c;
	c["type"] = (int)CMD_RECTS;
	c["rects"] = rects_xywh;
	c["colors"] = colors;
	c["fill"] = fill;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawRectsUniform(const PackedVector2Array &rects_xywh, const Color &color, bool fill) {
	Dictionary c;
	c["type"] = (int)CMD_RECTS_UNIFORM;
	c["rects"] = rects_xywh;
	c["color"] = color;
	c["fill"] = fill;
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawPlasmaCells(int gw, int gh, float spd, float fade, float pw, float ph, int parity) {
	Dictionary c;
	c["type"] = (int)CMD_PLASMA_CELLS;
	c["gw"] = gw;
	c["gh"] = gh;
	c["spd"] = spd;
	c["fade"] = fade;
	c["pw"] = pw;
	c["ph"] = ph;
	c["parity"] = parity;
	_queue_command(c);
}

void VGVectorCanvas2D::DrawFireCells(const Array &grid, int gw, int gh, float pw, float ph, float fade, int skip_rows) {
	Dictionary c;
	c["type"]      = (int)CMD_FIRE_CELLS;
	c["grid"]      = grid;
	c["gw"]        = gw;
	c["gh"]        = gh;
	c["pw"]        = pw;
	c["ph"]        = ph;
	c["fade"]      = fade;
	c["skip_rows"] = skip_rows;
	_queue_command(c);
}

void VGVectorCanvas2D::_draw_fire_cells_command(const Dictionary &cmd) {
	Array grid = (Array)cmd["grid"];
	int   gw        = (int)(int64_t)cmd["gw"];
	int   gh        = (int)(int64_t)cmd["gh"];
	float pw        = (float)(double)cmd["pw"];
	float ph        = (float)(double)cmd["ph"];
	float fade      = (float)(double)cmd["fade"];
	int   skip_rows = (int)(int64_t)cmd["skip_rows"];

	// Colour ramp: black → red → orange/yellow → white
	//   heat < 0.333  →  black..red
	//   heat < 0.667  →  red..orange-yellow
	//   heat >= 0.667 →  orange..white
	for (int y = skip_rows; y < gh; ++y) {
		for (int x = 0; x < gw; ++x) {
			float heat = (float)(double)grid[y * gw + x] * fade;
			if (heat < 0.05f) continue;
			float cr, cg, cb, ha;
			if (heat < 0.333f) {
				float s = heat * 3.0f;
				cr = s;  cg = 0.0f; cb = 0.0f;
			} else if (heat < 0.667f) {
				float s = (heat - 0.333f) * 3.0f;
				cr = 1.0f; cg = s * 0.6f; cb = 0.0f;
			} else {
				float s = (heat - 0.667f) * 3.0f;
				cr = 1.0f; cg = 0.6f + s * 0.4f; cb = s;
			}
			ha = heat * 5.0f;
			if (ha > 1.0f) ha = 1.0f;
			vg_add_rect(this, Rect2(x * pw, y * ph, pw + 1.0f, ph + 1.0f),
					Color(cr, cg, cb, ha), true, 0.0f);
		}
	}
}

void VGVectorCanvas2D::DrawTorusWireframe(float rot_y, float rot_x, float hue_off, float tt, float fade, float cx, float cy, float scale) {
	Dictionary c;
	c["type"] = (int)CMD_TORUS_WIREFRAME;
	c["rot_y"] = rot_y;
	c["rot_x"] = rot_x;
	c["hue_off"] = hue_off;
	c["tt"] = tt;
	c["fade"] = fade;
	c["cx"] = cx;
	c["cy"] = cy;
	c["scale"] = scale;
	_queue_command(c);
}

void VGVectorCanvas2D::DrawPath(const Array &points, float width, const Color &color, bool fill, const Color &fill_color, bool close) {
	DrawPolyline(points, width, color, fill, fill_color, close);
}

void VGVectorCanvas2D::DrawCircle(const Vector2 &center, float radius, const Color &color, bool fill, const Color &fill_color) {
	// Outline needs a stroke; width 0 + fill false used to queue an invisible ellipse.
	const float stroke = fill ? 0.0f : 2.0f;
	DrawEllipse(Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0f, radius * 2.0f)), stroke, color, fill, fill_color);
}

void VGVectorCanvas2D::DrawText(const Vector2 &position, const String &text, const Color &color, const Variant &font) {
	Dictionary c;
	c["type"] = (int)CMD_TEXT;
	c["position"] = position;
	c["text"] = text;
	c["color"] = color;
	c["font"] = font;
	c["align"] = String("left");
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawTextCentered(const Vector2 &position, const String &text, const Color &color, const Variant &font) {
	Dictionary c;
	c["type"] = (int)CMD_TEXT;
	c["position"] = position;
	c["text"] = text;
	c["color"] = color;
	c["font"] = font;
	c["align"] = String("center");
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

void VGVectorCanvas2D::DrawTextRightAligned(const Vector2 &position, const String &text, const Color &color, const Variant &font) {
	Dictionary c;
	c["type"] = (int)CMD_TEXT;
	c["position"] = position;
	c["text"] = text;
	c["color"] = color;
	c["font"] = font;
	c["align"] = String("right");
	c["transform"] = _get_current_transform();
	_queue_command(c);
}

// ---------------------------------------------------------------------------
// State + transform
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::SetStrokeColor(const Color &color) { _stroke_color = color; }
void VGVectorCanvas2D::SetFillColor(const Color &color) { _fill_color = color; }
void VGVectorCanvas2D::SetDefaultFont(const Ref<Font> &font) { _default_font = font; }

void VGVectorCanvas2D::PushTransform(const Transform2D &transform) {
	_transform_stack.append(_get_current_transform() * transform);
}

void VGVectorCanvas2D::PushIdentity() {
	// Save current transform and push a fresh identity so that subsequent
	// Translate/Rotate/Scale calls start from a clean slate.
	_transform_stack.append(Transform2D());
}

void VGVectorCanvas2D::PopTransform() {
	if (_transform_stack.size() > 1) {
		_transform_stack.pop_back();
	}
}

void VGVectorCanvas2D::Translate(const Vector2 &offset) {
	int top = _transform_stack.size() - 1;
	if (top < 0) {
		_transform_stack.append(Transform2D().translated(offset));
		return;
	}
	Transform2D cur = (Transform2D)_transform_stack[top];
	_transform_stack[top] = cur.translated(offset);
}

void VGVectorCanvas2D::Rotate(float angle) {
	int top = _transform_stack.size() - 1;
	if (top < 0) {
		return;
	}
	Transform2D cur = (Transform2D)_transform_stack[top];
	_transform_stack[top] = cur.rotated(angle);
}

void VGVectorCanvas2D::Scale(const Vector2 &scale) {
	int top = _transform_stack.size() - 1;
	if (top < 0) {
		return;
	}
	Transform2D cur = (Transform2D)_transform_stack[top];
	_transform_stack[top] = cur.scaled(scale);
}

bool VGVectorCanvas2D::try_call_pascal_method(const String &method, const Array &args) {
	const String m = method.to_lower();
	auto f = [&](int i, float def) -> float {
		return i < args.size() ? (float)args[i] : def;
	};
	auto b = [&](int i, bool def) -> bool {
		return i < args.size() ? (bool)args[i] : def;
	};
	auto col = [&](int i, const Color &def) -> Color {
		return i < args.size() ? Color(args[i]) : def;
	};
	const Color white(1, 1, 1, 1);
	const Color none(1, 1, 1, 0);

	if (m == "clear") {
		Clear();
		return true;
	}
	if (m == "render") {
		Render();
		return true;
	}
	if (m == "setadditiveblend" && args.size() >= 1) {
		SetAdditiveBlend((bool)args[0]);
		return true;
	}
	if (m == "setbatchmode" && args.size() >= 1) {
		SetBatchMode((bool)args[0]);
		return true;
	}
	if (m == "drawrect" && args.size() >= 1) {
		DrawRect((Rect2)args[0], f(1, 2.0f), col(2, white), b(3, false), col(4, none));
		return true;
	}
	if (m == "drawline" && args.size() >= 2) {
		DrawLine((Vector2)args[0], (Vector2)args[1], f(2, 2.0f), col(3, white));
		return true;
	}
	if (m == "drawcircle" && args.size() >= 2) {
		DrawCircle((Vector2)args[0], f(1, 1.0f), col(2, white), b(3, false), col(4, none));
		return true;
	}
	if (m == "drawarc" && args.size() >= 4) {
		DrawArc((Vector2)args[0], f(1, 1.0f), f(2, 0.0f), f(3, 6.283185f),
				args.size() > 4 ? (int)args[4] : 32, f(5, 2.0f), col(6, white), b(7, false), col(8, none));
		return true;
	}
	if (m == "drawpolygon" && args.size() >= 1) {
		DrawPolygon(args[0], f(1, 2.0f), col(2, white), b(3, false), col(4, none));
		return true;
	}
	if (m == "drawpolyline" && args.size() >= 1) {
		DrawPolyline(args[0], f(1, 2.0f), col(2, white), b(3, false), col(4, none), b(5, false));
		return true;
	}
	if (m == "drawpath" && args.size() >= 1) {
		DrawPath(args[0], f(1, 2.0f), col(2, white), b(3, false), col(4, none), b(5, false));
		return true;
	}
	if (m == "drawellipse" && args.size() >= 1) {
		DrawEllipse((Rect2)args[0], f(1, 2.0f), col(2, white), b(3, false), col(4, none),
				args.size() > 5 ? (int)args[5] : 32);
		return true;
	}
	if (m == "drawroundedrect" && args.size() >= 1) {
		DrawRoundedRect((Rect2)args[0], f(1, 16.0f), f(2, 2.0f), col(3, white), b(4, false), col(5, none),
				args.size() > 6 ? (int)args[6] : 8);
		return true;
	}
	if ((m == "drawtext" || m == "drawstring") && args.size() >= 2) {
		DrawText((Vector2)args[0], String(args[1]), col(2, white), args.size() > 3 ? args[3] : Variant());
		return true;
	}
	if (m == "drawtextcentered" && args.size() >= 2) {
		DrawTextCentered((Vector2)args[0], String(args[1]), col(2, white), args.size() > 3 ? args[3] : Variant());
		return true;
	}
	if (m == "drawtextrightaligned" && args.size() >= 2) {
		DrawTextRightAligned((Vector2)args[0], String(args[1]), col(2, white), args.size() > 3 ? args[3] : Variant());
		return true;
	}
	if (m == "drawvectortext" && args.size() >= 2) {
		DrawVectorText((Vector2)args[0], String(args[1]), col(2, white), f(3, 1.0f), f(4, 2.0f),
				args.size() > 5 ? String(args[5]) : String("left"), f(6, 2.0f),
				args.size() > 7 ? String(args[7]) : String(""));
		return true;
	}
	if (m == "drawvectortextcentered" && args.size() >= 2) {
		DrawVectorTextCentered((Vector2)args[0], String(args[1]), col(2, white), f(3, 1.0f), f(4, 2.0f),
				f(5, 2.0f), args.size() > 6 ? String(args[6]) : String(""));
		return true;
	}
	if (m == "drawvectortextrightaligned" && args.size() >= 2) {
		DrawVectorTextRightAligned((Vector2)args[0], String(args[1]), col(2, white), f(3, 1.0f), f(4, 2.0f),
				f(5, 2.0f), args.size() > 6 ? String(args[6]) : String(""));
		return true;
	}
	return false;
}

void VGVectorCanvas2D::Clear() {
	_commands.clear();
	_fast_prims.clear();
	_group_stack.clear();
	_frame_line_ord.clear();
	_pending_redraw = false;
	// Reset transform stack — DrawVectorText bakes absolute coords; a stale
	// Scale/Rotate on the stack mirrors all subsequent vector text strokes.
	_transform_stack.clear();
	_transform_stack.append(Transform2D());
	// Re-attach runtime-placed commands so they survive Clear/Draw cycles.
	for (int i = 0; i < _runtime_commands.size(); ++i) {
		Dictionary rc = _runtime_commands[i];
		_commands.append(rc.duplicate(true));
		FastPrim prim;
		prim.is_line = false;
		prim.cmd_index = _commands.size() - 1;
		_fast_prims.push_back(prim);
	}
	queue_redraw();
}

void VGVectorCanvas2D::Render() {
	if (!_pending_redraw) {
		_pending_redraw = true;
		queue_redraw();
	}
}

void VGVectorCanvas2D::ExecuteQueuedCommands() {
	// Never call `_draw()` here. Godot only sets CanvasItem::drawing around
	// NOTIFICATION_DRAW; a direct `_draw()` prints one error per primitive
	// (~450/frame in Circuit Breaker) and can stall quit while the log floods.
	queue_redraw();
}

void VGVectorCanvas2D::BeginGroup(const String &name) {
	_group_stack.append(name);
}

void VGVectorCanvas2D::EndGroup() {
	if (_group_stack.size() > 0) {
		_group_stack.pop_back();
	}
}

void VGVectorCanvas2D::TagSource(const String &group_name, const String &prop, const String &file, int line, const String &literal, int col) {
	String key = group_name.is_empty() ? String("__misc") : group_name;
	Dictionary hints = _group_source_hints.get(key, Dictionary());
	Dictionary entry;
	entry["file"] = file;
	entry["line"] = line;
	entry["col"] = col;
	entry["literal"] = literal;
	hints[prop] = entry;
	_group_source_hints[key] = hints;
}

// ---------------------------------------------------------------------------
// Vector font
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::RegisterVectorFont(const String &name, const Dictionary &glyphs, bool make_default) {
	if (name.is_empty()) {
		return;
	}
	_vector_fonts[name] = glyphs;
	if (make_default) {
		_vector_font_name = name;
	}
}

void VGVectorCanvas2D::SetVectorFont(const String &name) {
	if (_vector_fonts.has(name)) {
		_vector_font_name = name;
	}
}

Array VGVectorCanvas2D::GetVectorFontNames() {
	return _vector_fonts.keys();
}

void VGVectorCanvas2D::_ensure_default_vector_font() {
	if (_default_font_registered) {
		return;
	}
	_default_font_registered = true;

	// Helper macros to build glyph entries succinctly.
	#define V2(x, y) Vector2((real_t)(x), (real_t)(y))
	#define STROKE_BEGIN(arr) Array arr;
	#define STROKE_APPEND(arr, ...) { Array __s; \
		Vector2 __pts[] = { __VA_ARGS__ }; \
		for (size_t __i = 0; __i < sizeof(__pts)/sizeof(__pts[0]); ++__i) { __s.append(__pts[__i]); } \
		arr.append(__s); }
	#define GLYPH(font, ch, w, body) { \
		Dictionary __g; __g["width"] = (real_t)(w); \
		STROKE_BEGIN(__strokes) \
		body \
		__g["strokes"] = __strokes; \
		(font)[String(ch)] = __g; \
	}

	Dictionary font;

	{ Dictionary g; g["width"] = (real_t)6.0; g["strokes"] = Array(); font[" "] = g; }

	GLYPH(font, "A", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(4, 0), V2(8, 10))
		STROKE_APPEND(__strokes, V2(2, 5), V2(6, 5))
	);
	GLYPH(font, "B", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 10), V2(5, 10), V2(7, 8), V2(7, 6), V2(5, 4), V2(0, 4))
		STROKE_APPEND(__strokes, V2(5, 4), V2(7, 2), V2(7, 0), V2(5, 0), V2(0, 0))
	);
	GLYPH(font, "C", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(2, 0), V2(0, 2), V2(0, 8), V2(2, 10), V2(8, 10))
	);
	GLYPH(font, "D", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 10), V2(5, 10), V2(8, 7), V2(8, 3), V2(5, 0), V2(0, 0))
	);
	GLYPH(font, "E", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(0, 0), V2(0, 10), V2(8, 10))
		STROKE_APPEND(__strokes, V2(0, 5), V2(6, 5))
	);
	GLYPH(font, "F", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(0, 0), V2(8, 0))
		STROKE_APPEND(__strokes, V2(0, 5), V2(6, 5))
	);
	GLYPH(font, "G", 10.0,
		STROKE_APPEND(__strokes, V2(8, 2), V2(6, 0), V2(2, 0), V2(0, 2), V2(0, 8), V2(2, 10), V2(8, 10), V2(8, 6), V2(5, 6))
	);
	GLYPH(font, "H", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 10))
		STROKE_APPEND(__strokes, V2(8, 0), V2(8, 10))
		STROKE_APPEND(__strokes, V2(0, 5), V2(8, 5))
	);
	GLYPH(font, "I", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 0))
		STROKE_APPEND(__strokes, V2(4, 0), V2(4, 10))
		STROKE_APPEND(__strokes, V2(0, 10), V2(8, 10))
	);
	GLYPH(font, "J", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(8, 10), V2(4, 10), V2(2, 8), V2(2, 6))
	);
	GLYPH(font, "K", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 10))
		STROKE_APPEND(__strokes, V2(8, 0), V2(0, 5), V2(8, 10))
	);
	GLYPH(font, "L", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 10), V2(8, 10))
	);
	GLYPH(font, "M", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(0, 0), V2(4, 6), V2(8, 0), V2(8, 10))
	);
	GLYPH(font, "N", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(0, 0), V2(8, 10), V2(8, 0))
	);
	GLYPH(font, "O", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 8), V2(6, 10), V2(2, 10), V2(0, 8), V2(0, 2), V2(2, 0))
	);
	GLYPH(font, "P", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(0, 0), V2(6, 0), V2(8, 2), V2(8, 4), V2(6, 6), V2(0, 6))
	);
	GLYPH(font, "Q", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 8), V2(6, 10), V2(2, 10), V2(0, 8), V2(0, 2), V2(2, 0))
		STROKE_APPEND(__strokes, V2(5, 6), V2(8, 10))
	);
	GLYPH(font, "R", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(0, 0), V2(6, 0), V2(8, 2), V2(8, 4), V2(6, 6), V2(0, 6))
		STROKE_APPEND(__strokes, V2(0, 6), V2(8, 10))
	);
	GLYPH(font, "S", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(2, 0), V2(0, 2), V2(0, 4), V2(2, 6), V2(6, 6), V2(8, 8), V2(8, 10), V2(2, 10), V2(0, 8))
	);
	GLYPH(font, "T", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 0))
		STROKE_APPEND(__strokes, V2(4, 0), V2(4, 10))
	);
	GLYPH(font, "U", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 8), V2(2, 10), V2(6, 10), V2(8, 8), V2(8, 0))
	);
	GLYPH(font, "V", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(4, 10), V2(8, 0))
	);
	GLYPH(font, "W", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(2, 10), V2(4, 4), V2(6, 10), V2(8, 0))
	);
	GLYPH(font, "X", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 10))
		STROKE_APPEND(__strokes, V2(8, 0), V2(0, 10))
	);
	GLYPH(font, "Y", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(4, 5), V2(8, 0))
		STROKE_APPEND(__strokes, V2(4, 5), V2(4, 10))
	);
	GLYPH(font, "Z", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 0), V2(0, 10), V2(8, 10))
	);
	GLYPH(font, "0", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 8), V2(6, 10), V2(2, 10), V2(0, 8), V2(0, 2), V2(2, 0))
	);
	GLYPH(font, "1", 10.0,
		STROKE_APPEND(__strokes, V2(2, 3), V2(5, 0), V2(5, 10))
		STROKE_APPEND(__strokes, V2(3, 10), V2(7, 10))
	);
	GLYPH(font, "2", 10.0,
		STROKE_APPEND(__strokes, V2(0, 2), V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 4), V2(0, 10), V2(8, 10))
	);
	GLYPH(font, "3", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(6, 0), V2(8, 2), V2(6, 4), V2(8, 6), V2(8, 8), V2(6, 10), V2(0, 10))
	);
	GLYPH(font, "4", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 4), V2(8, 4))
		STROKE_APPEND(__strokes, V2(8, 0), V2(8, 10))
	);
	GLYPH(font, "5", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 0))
		STROKE_APPEND(__strokes, V2(0, 0), V2(0, 5), V2(8, 5), V2(4, 10), V2(0, 10))
	);
	GLYPH(font, "6", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(2, 0), V2(0, 2), V2(0, 8), V2(2, 10), V2(6, 10), V2(8, 8), V2(8, 6), V2(6, 4), V2(2, 4))
	);
	GLYPH(font, "7", 10.0,
		STROKE_APPEND(__strokes, V2(0, 0), V2(8, 0), V2(4, 10))
	);
	GLYPH(font, "8", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 4), V2(6, 6), V2(8, 8), V2(8, 10), V2(6, 10), V2(2, 10), V2(0, 8), V2(0, 6), V2(2, 4), V2(0, 2), V2(2, 0))
	);
	GLYPH(font, "9", 10.0,
		STROKE_APPEND(__strokes, V2(8, 8), V2(6, 10), V2(2, 10), V2(0, 8), V2(0, 6), V2(2, 4), V2(6, 4), V2(8, 6), V2(8, 0), V2(0, 0))
	);
	GLYPH(font, "-", 10.0,
		STROKE_APPEND(__strokes, V2(1, 5), V2(9, 5))
	);
	GLYPH(font, "=", 10.0,
		STROKE_APPEND(__strokes, V2(1, 4), V2(9, 4))
		STROKE_APPEND(__strokes, V2(1, 6), V2(9, 6))
	);
	GLYPH(font, ":", 10.0,
		STROKE_APPEND(__strokes, V2(4, 2), V2(6, 2))
		STROKE_APPEND(__strokes, V2(4, 8), V2(6, 8))
	);
	GLYPH(font, ".", 10.0,
		STROKE_APPEND(__strokes, V2(5, 8), V2(5, 10))
	);
	// * — three lines crossing at centre (5,5)
	GLYPH(font, "*", 10.0,
		STROKE_APPEND(__strokes, V2(5, 1), V2(5, 9))
		STROKE_APPEND(__strokes, V2(1, 3), V2(9, 7))
		STROKE_APPEND(__strokes, V2(9, 3), V2(1, 7))
	);
	// % — top-left circle, diagonal slash, bottom-right circle
	GLYPH(font, "%", 12.0,
		STROKE_APPEND(__strokes, V2(1, 0), V2(3, 0), V2(4, 1), V2(4, 3), V2(3, 4), V2(1, 4), V2(0, 3), V2(0, 1), V2(1, 0))
		STROKE_APPEND(__strokes, V2(0, 10), V2(10, 0))
		STROKE_APPEND(__strokes, V2(7, 6), V2(9, 6), V2(10, 7), V2(10, 9), V2(9, 10), V2(7, 10), V2(6, 9), V2(6, 7), V2(7, 6))
	);
	// + — horizontal and vertical through centre
	GLYPH(font, "+", 10.0,
		STROKE_APPEND(__strokes, V2(5, 1), V2(5, 9))
		STROKE_APPEND(__strokes, V2(1, 5), V2(9, 5))
	);
	// _ — baseline underline
	GLYPH(font, "_", 10.0,
		STROKE_APPEND(__strokes, V2(0, 10), V2(10, 10))
	);
	// / — forward slash
	GLYPH(font, "/", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(2, 10))
	);
	// ! — vertical stroke + dot
	GLYPH(font, "!", 6.0,
		STROKE_APPEND(__strokes, V2(3, 0), V2(3, 7))
		STROKE_APPEND(__strokes, V2(3, 9), V2(3, 10))
	);
	// ? — arc, vertical gap, dot
	GLYPH(font, "?", 10.0,
		STROKE_APPEND(__strokes, V2(0, 2), V2(2, 0), V2(6, 0), V2(8, 2), V2(8, 4), V2(5, 6), V2(5, 7))
		STROKE_APPEND(__strokes, V2(5, 9), V2(5, 10))
	);
	// ' — short top-right tick
	GLYPH(font, "'", 4.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(2, 3))
	);
	// , — descending dot
	GLYPH(font, ",", 6.0,
		STROKE_APPEND(__strokes, V2(3, 8), V2(3, 10), V2(1, 12))
	);
	// ; — colon with descending lower dot
	GLYPH(font, ";", 6.0,
		STROKE_APPEND(__strokes, V2(3, 2), V2(3, 3))
		STROKE_APPEND(__strokes, V2(3, 7), V2(3, 9), V2(1, 11))
	);
	// ( — left parenthesis
	GLYPH(font, "(", 6.0,
		STROKE_APPEND(__strokes, V2(5, 0), V2(2, 3), V2(2, 7), V2(5, 10))
	);
	// ) — right parenthesis
	GLYPH(font, ")", 6.0,
		STROKE_APPEND(__strokes, V2(1, 0), V2(4, 3), V2(4, 7), V2(1, 10))
	);
	// # — two horizontal bars + two verticals
	GLYPH(font, "#", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(2, 10))
		STROKE_APPEND(__strokes, V2(7, 0), V2(7, 10))
		STROKE_APPEND(__strokes, V2(0, 3), V2(10, 3))
		STROKE_APPEND(__strokes, V2(0, 7), V2(10, 7))
	);
	// @ — circle with inner hook
	GLYPH(font, "@", 12.0,
		STROKE_APPEND(__strokes, V2(9, 4), V2(7, 2), V2(5, 2), V2(4, 4), V2(4, 6), V2(5, 8), V2(7, 8), V2(9, 6), V2(9, 2), V2(7, 0), V2(4, 0), V2(1, 2), V2(0, 5), V2(1, 9), V2(4, 11), V2(7, 11), V2(10, 9))
	);
	// < and >
	GLYPH(font, "<", 10.0,
		STROKE_APPEND(__strokes, V2(8, 0), V2(2, 5), V2(8, 10))
	);
	GLYPH(font, ">", 10.0,
		STROKE_APPEND(__strokes, V2(2, 0), V2(8, 5), V2(2, 10))
	);
	// [ and ]
	GLYPH(font, "[", 6.0,
		STROKE_APPEND(__strokes, V2(5, 0), V2(2, 0), V2(2, 10), V2(5, 10))
	);
	GLYPH(font, "]", 6.0,
		STROKE_APPEND(__strokes, V2(1, 0), V2(4, 0), V2(4, 10), V2(1, 10))
	);

	#undef V2
	#undef STROKE_BEGIN
	#undef STROKE_APPEND
	#undef GLYPH

	_vector_fonts["default"] = font;
}

Dictionary VGVectorCanvas2D::_get_vector_font(const String &name) {
	if (_vector_fonts.is_empty()) {
		_ensure_default_vector_font();
	}
	String selected = name.is_empty() ? _vector_font_name : name;
	if (_vector_fonts.has(selected)) {
		return _vector_fonts[selected];
	}
	return _vector_fonts.get("default", Dictionary());
}

// Queue polyline in absolute canvas coordinates (identity transform).
void VGVectorCanvas2D::_queue_polyline_absolute(const PackedVector2Array &points, float width, const Color &color) {
	if (points.size() < 2) {
		return;
	}
	Dictionary c;
	c["type"] = (int)CMD_POLYLINE;
	c["points"] = points;
	c["width"] = width;
	c["color"] = color;
	c["fill"] = false;
	c["fill_color"] = Color(1, 1, 1, 0);
	c["close"] = false;
	c["absolute"] = true;
	c["transform"] = Transform2D();
	_queue_command(c);
}

void VGVectorCanvas2D::_emit_vector_text(const Vector2 &position, const String &text, const Color &color, float scale, float width, const String &align, float spacing, const String &font_name, bool queue) {
	String upper_text = text.to_upper();
	Dictionary font_map = _get_vector_font(font_name);

	double total_width = 0.0;
	int n = upper_text.length();
	Array glyphs;
	glyphs.resize(n);
	for (int i = 0; i < n; ++i) {
		String ch = upper_text.substr(i, 1);
		Variant g_v = font_map.get(ch, Variant());
		Dictionary g;
		if (g_v.get_type() == Variant::DICTIONARY) {
			g = (Dictionary)g_v;
		} else {
			g["width"] = (real_t)8.0;
			g["strokes"] = Array();
		}
		glyphs[i] = g;
		total_width += (double)((real_t)g["width"]) * (double)scale;
		if (i < n - 1) {
			total_width += (double)spacing;
		}
	}

	Vector2 pos = position;
	if (total_width > 0.0) {
		if (align == "center") {
			pos.x -= (real_t)(total_width * 0.5);
		} else if (align == "right") {
			pos.x -= (real_t)total_width;
		}
	}

	double x_offset = 0.0;
	for (int gi = 0; gi < glyphs.size(); ++gi) {
		Dictionary g = glyphs[gi];
		Array strokes = g["strokes"];
		for (int si = 0; si < strokes.size(); ++si) {
			Array stroke = strokes[si];
			PackedVector2Array pts;
			pts.resize(stroke.size());
			for (int pi = 0; pi < stroke.size(); ++pi) {
				Vector2 op = (Vector2)stroke[pi];
				pts[pi] = pos + Vector2((real_t)(x_offset + (double)op.x * (double)scale),
						(real_t)((double)op.y * (double)scale));
			}
			if (pts.size() > 1) {
				if (queue) {
					_queue_polyline_absolute(pts, width, color);
				} else {
					vg_add_polyline(this, pts, color, width);
				}
			}
		}
		x_offset += (double)((real_t)g["width"]) * (double)scale + (double)spacing;
	}
}

void VGVectorCanvas2D::DrawVectorText(const Vector2 &position, const String &text, const Color &color, float scale, float width, const String &align, float spacing, const String &font_name) {
	_emit_vector_text(position, text, color, scale, width, align, spacing, font_name, true);
}

void VGVectorCanvas2D::DrawVectorTextCentered(const Vector2 &position, const String &text, const Color &color, float scale, float width, float spacing, const String &font_name) {
	DrawVectorText(position, text, color, scale, width, "center", spacing, font_name);
}

void VGVectorCanvas2D::DrawVectorTextRightAligned(const Vector2 &position, const String &text, const Color &color, float scale, float width, float spacing, const String &font_name) {
	DrawVectorText(position, text, color, scale, width, "right", spacing, font_name);
}

// ---------------------------------------------------------------------------
// DrawVectorTextHelix — text orbiting a 3D helix projected to 2D.
// Each character is placed at angle = base_angle + i*char_spacing, orbiting
// cx/cy at the given radius. Y is offset by helical_pitch*i and a 3D
// perspective sine. Each glyph is rotated to follow the orbit tangent.
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::DrawVectorTextHelix(const String &text, float cx, float cy, float time,
		const Color &color, float scale, float width,
		float radius, float perspective, float helical_pitch,
		float twist_speed, float char_spacing, const String &font_name) {
	_ensure_default_vector_font();
	String upper_text = text.to_upper();
	Dictionary font_map = _get_vector_font(font_name);
	int n = upper_text.length();
	const float TAU = 6.28318530718f;

	for (int gi = 0; gi < n; ++gi) {
		String ch = upper_text.substr(gi, 1);
		Variant g_v = font_map.get(ch, Variant());
		Dictionary g;
		if (g_v.get_type() == Variant::DICTIONARY) {
			g = (Dictionary)g_v;
		} else {
			g["width"] = (real_t)8.0;
			g["strokes"] = Array();
		}

		// Angle on the helix for this character
		float angle = (float)gi * char_spacing - time * twist_speed;
		float cos_a = ::cosf(angle);
		float sin_a = ::sinf(angle);

		// 3D perspective: cos_a controls front/back depth
		float depth = (cos_a + 1.0f) * 0.5f; // 0=back, 1=front
		float persp = 1.0f - perspective * (1.0f - depth) * 0.5f; // scale: back chars smaller
		float char_scale = scale * persp;

		// Position on orbit
		float px = cx + radius * sin_a;
		float py = cy + radius * cos_a * perspective + (float)gi * helical_pitch - (float)n * helical_pitch * 0.5f;

		// Tangent direction (perpendicular to radial) = direction of character baseline
		float tan_x = cos_a;
		float tan_y = -sin_a * perspective;
		// Normalise tangent
		float tan_len = ::sqrtf(tan_x * tan_x + tan_y * tan_y);
		if (tan_len > 0.001f) { tan_x /= tan_len; tan_y /= tan_len; }
		// Normal = perpendicular to tangent (for glyph height direction)
		float nor_x = -tan_y;
		float nor_y = tan_x;

		// Glyph char_width for centring
		float gw = (float)(real_t)g["width"] * char_scale;

		// Hue cycling along the string
		float hue = (float)gi / (float)n;
		float cr = ::sinf(hue * TAU) * 0.5f + 0.5f;
		float cg = ::sinf(hue * TAU + 2.094f) * 0.5f + 0.5f;
		float cb = ::sinf(hue * TAU + 4.189f) * 0.5f + 0.5f;
		// Blend with base colour
		Color char_color(
			color.r * 0.4f + cr * 0.6f,
			color.g * 0.4f + cg * 0.6f,
			color.b * 0.4f + cb * 0.6f,
			color.a * persp  // fade chars at back
		);

		// Draw each stroke, transforming points by (tangent, normal) basis
		Array strokes = g["strokes"];
		for (int si = 0; si < strokes.size(); ++si) {
			Array stroke = strokes[si];
			if (stroke.size() < 2) continue;
			PackedVector2Array pts_packed;
			for (int pi = 0; pi < stroke.size(); ++pi) {
				Vector2 op = (Vector2)stroke[pi];
				// Local glyph space: x along baseline (centred), y up into normal
				float lx = (op.x - gw * 0.5f / char_scale) * char_scale;
				float ly = op.y * char_scale;
				// Transform into world space using tangent/normal basis
				float wx = px + tan_x * lx + nor_x * ly;
				float wy = py + tan_y * lx + nor_y * ly;
				pts_packed.append(Vector2(wx, wy));
			}
			_queue_polyline_absolute(pts_packed, width * persp, char_color);
		}
	}
}

// ---------------------------------------------------------------------------
// DrawVectorTextWave — horizontal sine scroller with per-character
// Y displacement, foreshortening scale, and optional hue cycling.
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::DrawVectorTextWave(const String &text, float x_offset, float base_y, float time,
		const Color &color, float scale, float width,
		float amplitude, float wave_freq, float wave_speed,
		float spacing, bool hue_cycle, const String &font_name) {
	_ensure_default_vector_font();
	String upper_text = text.to_upper();
	Dictionary font_map = _get_vector_font(font_name);
	int n = upper_text.length();
	const float TAU = 6.28318530718f;

	float x_cur = x_offset;
	for (int gi = 0; gi < n; ++gi) {
		String ch = upper_text.substr(gi, 1);
		Variant g_v = font_map.get(ch, Variant());
		Dictionary g;
		if (g_v.get_type() == Variant::DICTIONARY) {
			g = (Dictionary)g_v;
		} else {
			g["width"] = (real_t)8.0;
			g["strokes"] = Array();
		}
		float gw = (float)(real_t)g["width"];

		// Wave: Y displacement, tangent rotation, gentle foreshortening
		float phase = x_cur * wave_freq + time * wave_speed;
		float dy = ::sinf(phase) * amplitude;
		float angle = ::atanf(::cosf(phase) * wave_freq * amplitude);
		float char_scale = scale * (1.0f + 0.05f * ::cosf(phase));
		float cos_a = ::cosf(angle);
		float sin_a = ::sinf(angle);
		float cx = x_cur + gw * char_scale * 0.5f;
		float cy = base_y + dy;

		// Hue cycling
		Color char_color = color;
		if (hue_cycle) {
			float hue = (float)gi / MAX(1.0f, (float)n) + time * 0.25f;
			hue -= ::floorf(hue);
			char_color.r = color.r * 0.5f + (::sinf(hue * TAU) * 0.5f + 0.5f) * 0.5f;
			char_color.g = color.g * 0.5f + (::sinf(hue * TAU + 2.094f) * 0.5f + 0.5f) * 0.5f;
			char_color.b = color.b * 0.5f + (::sinf(hue * TAU + 4.189f) * 0.5f + 0.5f) * 0.5f;
		}

		Array strokes = g["strokes"];
		for (int si = 0; si < strokes.size(); ++si) {
			Array stroke = strokes[si];
			if (stroke.size() < 2) continue;
			PackedVector2Array pts_packed;
			for (int pi = 0; pi < stroke.size(); ++pi) {
				Vector2 op = (Vector2)stroke[pi];
				float lx = op.x * char_scale - gw * char_scale * 0.5f;
				float ly = op.y * char_scale;
				pts_packed.append(Vector2(
					cx + lx * cos_a - ly * sin_a,
					cy + lx * sin_a + ly * cos_a
				));
			}
			_queue_polyline_absolute(pts_packed, width, char_color);
		}
		x_cur += gw * char_scale + spacing;
	}
}

// ---------------------------------------------------------------------------
// DrawVectorTextFlip — horizontal scroller with per-character vertical-axis spin.
// Each letter x-squishes around its own centre as |cos(phase)|, giving a
// coin-flip / revolving-door effect. Brightness tracks x_squish so edge-on
// chars fade to invisible.
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::DrawVectorTextFlip(const String &text, float x_offset, float base_y, float time,
		const Color &color, float scale, float width,
		float char_spacing, float flip_speed, float flip_wave,
		const String &font_name) {
	_ensure_default_vector_font();
	String upper_text = text.to_upper();
	Dictionary font_map = _get_vector_font(font_name);
	int n = upper_text.length();

	for (int gi = 0; gi < n; ++gi) {
		float char_left = x_offset + (float)gi * char_spacing;
		float char_cx   = char_left + char_spacing * 0.5f;
		// Viewport cull (generous margin for wide chars)
		if (char_cx + char_spacing < -50.0f || char_cx - char_spacing > 3000.0f) continue;

		// Flip phase — each character offset by flip_wave radians.
		// y_squish rotates around the HORIZONTAL axis: head-over-heels tumble.
		// cos() full range -1..1 so the letter passes through upside-down.
		float phase    = time * flip_speed + (float)gi * flip_wave;
		float y_squish = ::cosf(phase);           // -1..1, negative = upside-down
		float abs_sq   = ::fabsf(y_squish);
		if (abs_sq < 0.02f) continue;             // edge-on: skip

		// Brightness dims toward edge-on for a natural lighting feel
		float bright = abs_sq * abs_sq;
		Color char_color(color.r * bright, color.g * bright, color.b * bright, color.a * bright);

		String ch = upper_text.substr(gi, 1);
		Variant g_v = font_map.get(ch, Variant());
		Dictionary g;
		if (g_v.get_type() == Variant::DICTIONARY) {
			g = (Dictionary)g_v;
		} else {
			g["width"]   = (real_t)8.0;
			g["strokes"] = Array();
		}
		float gw              = (float)(real_t)g["width"];
		float glyph_center_lx = gw * 0.5f * scale;
		// Glyph vertical centre: vector fonts typically span 0..10 units
		const float GLYPH_HALF_H = 5.0f;
		float glyph_cy = GLYPH_HALF_H * scale;

		Array strokes = g["strokes"];
		for (int si = 0; si < strokes.size(); ++si) {
			Array stroke = strokes[si];
			if (stroke.size() < 2) continue;
			PackedVector2Array pts_packed;
			for (int pi = 0; pi < stroke.size(); ++pi) {
				Vector2 op = (Vector2)stroke[pi];
				float local_x = op.x * scale;
				float local_y = op.y * scale;
				// X: full width (no horizontal squish)
				float sx = char_cx + (local_x - glyph_center_lx);
				// Y: squish around vertical centre — creates head-over-heels spin
				float sy = base_y + glyph_cy + (local_y - glyph_cy) * y_squish;
				pts_packed.append(Vector2(sx, sy));
			}
			_queue_polyline_absolute(pts_packed, width * (0.5f + abs_sq * 0.5f), char_color);
		}
	}
}

// ---------------------------------------------------------------------------
// DrawVectorTextPath — border belt. read_angle = baseline (LTR on screen);
// cw_angle = path tangent used for inward hang (right-side-up on all edges).
// ---------------------------------------------------------------------------
void VGVectorCanvas2D::DrawVectorTextPath(const Vector2 &origin, float cw_angle, float read_angle, const String &text,
		const Color &color, float scale, float width, float spacing, const String &font_name) {
	_ensure_default_vector_font();
	String upper_text = text.to_upper();
	Dictionary font_map = _get_vector_font(font_name);
	int n = upper_text.length();
	float lay_x = ::cosf(read_angle);
	float lay_y = ::sinf(read_angle);
	float in_x = -::sinf(cw_angle);
	float in_y = ::cosf(cw_angle);
	float x_along = 0.0f;

	for (int gi = 0; gi < n; ++gi) {
		String ch = upper_text.substr(gi, 1);
		Variant g_v = font_map.get(ch, Variant());
		Dictionary g;
		if (g_v.get_type() == Variant::DICTIONARY) {
			g = (Dictionary)g_v;
		} else {
			g["width"] = (real_t)8.0;
			g["strokes"] = Array();
		}
		float gw = (float)(real_t)g["width"] * scale;
		Array strokes = g["strokes"];
		for (int si = 0; si < strokes.size(); ++si) {
			Array stroke = strokes[si];
			if (stroke.size() < 2) {
				continue;
			}
			PackedVector2Array pts_packed;
			for (int pi = 0; pi < stroke.size(); ++pi) {
				Vector2 op = (Vector2)stroke[pi];
				float lx = x_along + op.x * scale;
				float ly = op.y * scale;
				float wx = origin.x + lay_x * lx + in_x * ly;
				float wy = origin.y + lay_y * lx + in_y * ly;
				pts_packed.append(Vector2(wx, wy));
			}
			_queue_polyline_absolute(pts_packed, width, color);
		}
		x_along += gw + spacing;
	}
}

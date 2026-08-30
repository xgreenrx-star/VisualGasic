#include "visual_gasic_vector_canvas.h"
#include "visual_gasic_language.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/canvas_item_material.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cmath>

using namespace godot;

VGVectorCanvas2D::VGVectorCanvas2D() {
	_transform_stack.append(Transform2D());
}

VGVectorCanvas2D::~VGVectorCanvas2D() {}

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

	bool overlay_in_use = _group_stack.size() > 0
			|| !_group_overrides.is_empty()
			|| !_command_overrides.is_empty()
			|| !_group_source_hints.is_empty();

	if (!overlay_in_use) {
		// Fast path: ~100% of frames in production games.
		_commands.append(command);
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
void VGVectorCanvas2D::_draw() {
	_pending_redraw = false;
	_sprite_pool_index = 0;
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
					if (g.pts.size() >= 2) draw_multiline(g.pts, g.color, g.width);
				}
				groups.clear();
				_dispatch_command(cmd, t);
			}
		}
		for (auto &g : groups) {
			if (g.pts.size() >= 2) draw_multiline(g.pts, g.color, g.width);
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
		default:
			break;
	}
}

void VGVectorCanvas2D::_draw_line_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Vector2 from = t.xform((Vector2)cmd["from"]);
	Vector2 to = t.xform((Vector2)cmd["to"]);
	draw_line(from, to, (Color)cmd["color"], (double)cmd["width"]);
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
			draw_rect(rect, fc, true);
		}
		if (width > 0.0f) {
			draw_rect(rect, color, false, (double)width);
		}
	} else {
		PackedVector2Array points = _transform_points_array(_rect_corner_points(rect), t);
		if (fill) {
			draw_polygon(points, _make_fill_color_array(fc, points.size()));
		}
		if (width > 0.0f) {
			PackedVector2Array outline = points;
			if (points.size() > 0) {
				outline.append(points[0]);
			}
			draw_polyline(outline, color, (double)width);
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
			draw_rect(rect, c, true);
		} else {
			draw_rect(rect, c, false, 1.0f);
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
			draw_rect(rect, color, true);
		} else {
			draw_rect(rect, color, false, 1.0f);
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
			draw_rect(Rect2(cx * pw, cy * ph, pw + 1.0f, ph + 1.0f), Color(cr, cg, cb, fade), true);
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
	draw_multiline_colors(pts, cols, 1.4f);
}

void VGVectorCanvas2D::_draw_rounded_rect_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Array raw = _rounded_rect_corner_points((Rect2)cmd["rect"], (float)cmd["radius"], (int)cmd["segments"]);
	PackedVector2Array points = _transform_points_array(raw, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		draw_polygon(points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		PackedVector2Array outline = points;
		if (points.size() > 0) {
			outline.append(points[0]);
		}
		draw_polyline(outline, (Color)cmd["color"], (double)width);
	}
}

void VGVectorCanvas2D::_draw_ellipse_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	Array raw = _ellipse_corner_points((Rect2)cmd["rect"], (int)cmd["segments"]);
	PackedVector2Array points = _transform_points_array(raw, t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		draw_polygon(points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		draw_polyline(points, (Color)cmd["color"], (double)width);
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
		draw_polygon(filled, _make_fill_color_array((Color)cmd["fill_color"], filled.size()));
	}
	if (width > 0.0f || !fill) {
		draw_polyline(points, color, (double)width);
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
		draw_polygon(points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f && points.size() > 1) {
		PackedVector2Array outline = points;
		outline.append(points[1]); // close back to first arc point, not center
		draw_polyline(outline, (Color)cmd["color"], (double)width);
	}
}

void VGVectorCanvas2D::_draw_polygon_command(const Dictionary &cmd) {
	Transform2D t = (Transform2D)cmd["transform"];
	PackedVector2Array points = _transform_points_packed((PackedVector2Array)cmd["points"], t);
	bool fill = (bool)cmd["fill"];
	float width = (float)cmd["width"];
	if (fill) {
		draw_polygon(points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		PackedVector2Array outline = points;
		if (outline.size() > 0) {
			outline.append(outline[0]);
		}
		draw_polyline(outline, (Color)cmd["color"], (double)width);
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
		draw_polygon(points, _make_fill_color_array((Color)cmd["fill_color"], points.size()));
	}
	if (width > 0.0f) {
		if (close && points.size() > 0) {
			PackedVector2Array outline = points;
			outline.append(points[0]);
			draw_polyline(outline, (Color)cmd["color"], (double)width);
		} else {
			draw_polyline(points, (Color)cmd["color"], (double)width);
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
	draw_multiline(segments, color, (double)width);
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

	draw_multimesh(mm, tex);
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
		DrawVectorText(position, text, color, 1.0f, 2.0f, align);
		return;
	}
	if (font_v.get_type() == Variant::STRING) {
		DrawVectorText(position, text, color, 1.0f, 2.0f, align, 2.0f, (String)font_v);
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
			draw_rect(Rect2(x * pw, y * ph, pw + 1.0f, ph + 1.0f),
					  Color(cr, cg, cb, ha), true);
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
	DrawEllipse(Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0f, radius * 2.0f)), 0.0f, color, fill, fill_color);
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

void VGVectorCanvas2D::Clear() {
	_commands.clear();
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
	_draw();
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

void VGVectorCanvas2D::DrawVectorText(const Vector2 &position, const String &text, const Color &color, float scale, float width, const String &align, float spacing, const String &font_name) {
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
				_queue_polyline_absolute(pts, width, color);
			}
		}
		x_offset += (double)((real_t)g["width"]) * (double)scale + (double)spacing;
	}
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

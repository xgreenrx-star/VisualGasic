#ifndef VISUAL_GASIC_VECTOR_CANVAS_H
#define VISUAL_GASIC_VECTOR_CANVAS_H

// VGVectorCanvas2D — native hot-path implementation of the Vector Graphics
// addon's VectorCanvas node. Ports the per-frame draw loop and the public
// Draw* / state / transform API to C++. The Tweak Overlay / persistence /
// runtime-command editing layer continues to live in the GDScript subclass
// addons/visual_gasic/plugins/vector_graphics/vector_canvas.gd, which now
// `extends VGVectorCanvas2D` and reaches into the protected/exposed state
// via property accessors bound below.

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/quad_mesh.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/canvas_item_material.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/rect2.hpp>

using namespace godot;

class VGVectorCanvas2D : public Node2D {
	GDCLASS(VGVectorCanvas2D, Node2D);

public:
	enum CommandType {
		CMD_LINE = 0,
		CMD_RECT = 1,
		CMD_ROUNDED_RECT = 2,
		CMD_ELLIPSE = 3,
		CMD_ARC = 4,
		CMD_PIE_SLICE = 5,
		CMD_POLYGON = 6,
		CMD_POLYLINE = 7,
		CMD_TEXT = 8,
		CMD_MULTILINE = 9,
		CMD_SPRITE_LINES = 10,
        CMD_RECTS = 11,          // Batch rectangles: PackedVector2Array(x,y,w,h pairs) + per-rect colors
        CMD_RECTS_UNIFORM = 12,   // Batch rectangles: all same color
        CMD_PLASMA_CELLS = 13,    // Compute+draw plasma grid in C++ — no VG loop needed
        CMD_TORUS_WIREFRAME = 14, // Compute+draw full torus wireframe in C++ — no VG loop needed
    };
private:
	// Command buffer + bookkeeping. Stored as Array<Dictionary> so the
	// GDScript overlay subclass can still read/modify entries in place.
	Array _commands;
	Array _runtime_commands;
	int _command_id_counter = 0;
	int _runtime_id_counter = 0;
	Array _transform_stack; // Array of Transform2D; seeded with identity in ctor.
	Array _group_stack; // Array of String.
	Dictionary _group_overrides;
	Dictionary _group_source_hints;
	Dictionary _command_overrides;
	Dictionary _frame_line_ord;
	bool _pending_redraw = false;

	// Drawing state.
	Color _stroke_color = Color(1, 1, 1, 1);
	Color _fill_color = Color(1, 1, 1, 0);
	float _stroke_width = 2.0f;
	Ref<Font> _default_font;

	// Vector-font (Asteroids-style stroke glyphs).
	Dictionary _vector_fonts;
	String _vector_font_name = "default";
	bool _default_font_registered = false;

	// Sprite-batch infra (CMD_SPRITE_LINES). One MultiMesh per command
	// in the current frame so concurrent batches don't clobber each
	// other's instance buffers before the rendering server consumes them.
	Vector<Ref<MultiMesh>> _sprite_multimesh_pool;
	Ref<QuadMesh> _sprite_quad;
	int _sprite_pool_index = 0;
	Ref<CanvasItemMaterial> _additive_material;

	// --- internals ---
	Transform2D _get_current_transform() const;
	PackedVector2Array _transform_points_array(const Array &points, const Transform2D &t) const;
	PackedVector2Array _transform_points_packed(const PackedVector2Array &points, const Transform2D &t) const;
	static PackedColorArray _make_fill_color_array(const Color &c, int count);
	static Array _rect_corner_points(const Rect2 &rect);
	static Array _ellipse_corner_points(const Rect2 &rect, int segments);
	static Array _rounded_rect_corner_points(const Rect2 &rect, float radius, int segments);
	static Array _arc_corner_points(const Vector2 &center, float radius, float start_angle, float end_angle, int segments);
	void _apply_override_to_command(Dictionary &command, const Dictionary &override_dict);
	void _queue_command(Dictionary command);

	void _draw_line_command(const Dictionary &cmd);
	void _draw_rect_command(const Dictionary &cmd);
	void _draw_rounded_rect_command(const Dictionary &cmd);
	void _draw_ellipse_command(const Dictionary &cmd);
	void _draw_arc_command(const Dictionary &cmd);
	void _draw_pie_slice_command(const Dictionary &cmd);
	void _draw_polygon_command(const Dictionary &cmd);
	void _draw_polyline_command(const Dictionary &cmd);
	void _draw_text_command(const Dictionary &cmd);
	void _draw_multiline_command(const Dictionary &cmd);
	void _draw_sprite_lines_command(const Dictionary &cmd);
	void _draw_rects_command(const Dictionary &cmd);
	void _draw_rects_uniform_command(const Dictionary &cmd);
	void _draw_plasma_cells_command(const Dictionary &cmd);
	void _draw_torus_wireframe_command(const Dictionary &cmd);

	void _ensure_default_vector_font();
	Dictionary _get_vector_font(const String &name);

protected:
	static void _bind_methods();

public:
	VGVectorCanvas2D();
	~VGVectorCanvas2D();

	void _ready() override;
	void _draw() override;

	// ---- Public Draw* API (1:1 with vector_canvas.gd) ----
	void DrawLine(const Vector2 &from, const Vector2 &to, float width = 2.0f, const Color &color = Color(1, 1, 1, 1));
	void DrawRect(const Rect2 &rect, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0));
	void DrawRoundedRect(const Rect2 &rect, float radius = 16.0f, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0), int segments = 8);
	void DrawEllipse(const Rect2 &rect, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0), int segments = 32);
	void DrawArc(const Vector2 &center, float radius, float start_angle, float end_angle, int segments = 32, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0));
	void DrawPolygon(const Array &points, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0));
	void DrawPolyline(const Array &points, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0), bool close = false);
	void DrawLines(const PackedVector2Array &segments, float width = 2.0f, const Color &color = Color(1, 1, 1, 1));
	// Batch rect drawing: rects_xywh is a flat PackedVector2Array where each pair (Vector2(x,y), Vector2(w,h)) is one rect.
	// DrawRects: per-rect colors supplied in PackedColorArray (same count as rect count).
	// DrawRectsUniform: all rects share one color.
	void DrawRects(const PackedVector2Array &rects_xywh, const PackedColorArray &colors, bool fill = true);
	void DrawRectsUniform(const PackedVector2Array &rects_xywh, const Color &color = Color(1, 1, 1, 1), bool fill = true);
	// DrawPlasmaCells: compute HSV plasma grid and render all cells matching parity (0=even, 1=odd) entirely in C++.
	void DrawPlasmaCells(int gw, int gh, float spd, float fade, float pw, float ph, int parity);
	// DrawTorusWireframe: compute and render full torus wireframe with hue-cycling in C++.
	void DrawTorusWireframe(float rot_y, float rot_x, float hue_off, float tt, float fade, float cx, float cy);
	void DrawSpriteLines(const Ref<Texture2D> &texture, const PackedVector2Array &segments, float width = 6.0f, const Color &color = Color(1, 1, 1, 1));
	Ref<Texture2D> MakeGlowTexture(int size = 32, const Color &core_color = Color(1, 1, 1, 1));
	Ref<Texture2D> MakeRadialGlowTexture(int size = 48, const Color &core_color = Color(1, 1, 1, 1));
	void SetAdditiveBlend(bool enable);
	void DrawPath(const Array &points, float width = 2.0f, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0), bool close = false);
	void DrawCircle(const Vector2 &center, float radius, const Color &color = Color(1, 1, 1, 1), bool fill = false, const Color &fill_color = Color(1, 1, 1, 0));
	void DrawText(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), const Variant &font = Variant());
	void DrawTextCentered(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), const Variant &font = Variant());
	void DrawTextRightAligned(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), const Variant &font = Variant());

	// ---- Vector-font text ----
	void DrawVectorText(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), float scale = 1.0f, float width = 2.0f, const String &align = "left", float spacing = 2.0f, const String &font_name = "");
	void DrawVectorTextCentered(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), float scale = 1.0f, float width = 2.0f, float spacing = 2.0f, const String &font_name = "");
	void DrawVectorTextRightAligned(const Vector2 &position, const String &text, const Color &color = Color(1, 1, 1, 1), float scale = 1.0f, float width = 2.0f, float spacing = 2.0f, const String &font_name = "");
	void RegisterVectorFont(const String &name, const Dictionary &glyphs, bool make_default = false);
	void SetVectorFont(const String &name);
	Array GetVectorFontNames();

	// ---- State / transform ----
	void SetStrokeColor(const Color &color);
	void SetFillColor(const Color &color);
	void SetDefaultFont(const Ref<Font> &font);
	void PushTransform(const Transform2D &transform);
	void PopTransform();
	void Translate(const Vector2 &offset);
	void Rotate(float angle);
	void Scale(const Vector2 &scale);
	void Clear();
	void Render();

	// ---- Groups & source tagging (used by Tweak Overlay) ----
	void BeginGroup(const String &name);
	void EndGroup();
	void TagSource(const String &group_name, const String &prop, const String &file, int line, const String &literal, int col = -1);

	// ---- Exposed state for GDScript overlay subclass ----
	// Bound as `_commands`, `_runtime_commands`, etc. so existing GDScript
	// code that reads/mutates those names finds the same underlying objects.
	Array get_commands_array() const { return _commands; }
	void set_commands_array(const Array &a) { _commands = a; }
	Array get_runtime_commands_array() const { return _runtime_commands; }
	void set_runtime_commands_array(const Array &a) { _runtime_commands = a; }
	Dictionary get_group_overrides_dict() const { return _group_overrides; }
	void set_group_overrides_dict(const Dictionary &d) { _group_overrides = d; }
	Dictionary get_command_overrides_dict() const { return _command_overrides; }
	void set_command_overrides_dict(const Dictionary &d) { _command_overrides = d; }
	Dictionary get_group_source_hints_dict() const { return _group_source_hints; }
	void set_group_source_hints_dict(const Dictionary &d) { _group_source_hints = d; }
	Array get_group_stack_array() const { return _group_stack; }
	void set_group_stack_array(const Array &a) { _group_stack = a; }
	Array get_transform_stack_array() const { return _transform_stack; }
	void set_transform_stack_array(const Array &a) { _transform_stack = a; }
	Dictionary get_frame_line_ord_dict() const { return _frame_line_ord; }
	void set_frame_line_ord_dict(const Dictionary &d) { _frame_line_ord = d; }

	Color get_stroke_color() const { return _stroke_color; }
	void set_stroke_color_prop(const Color &c) { _stroke_color = c; }
	Color get_fill_color_prop() const { return _fill_color; }
	void set_fill_color_prop(const Color &c) { _fill_color = c; }
	float get_stroke_width() const { return _stroke_width; }
	void set_stroke_width(float w) { _stroke_width = w; }
	Ref<Font> get_default_font() const { return _default_font; }
	void set_default_font_prop(const Ref<Font> &f) { _default_font = f; }
};

VARIANT_ENUM_CAST(VGVectorCanvas2D::CommandType);

#endif // VISUAL_GASIC_VECTOR_CANVAS_H

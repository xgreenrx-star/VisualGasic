#ifndef VISUAL_GASIC_FORM_DESIGNER_H
#define VISUAL_GASIC_FORM_DESIGNER_H

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/menu_bar.hpp>
#include <godot_cpp/classes/popup_menu.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_uid.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

// =============================================================================
// FormControlItem — One control on the form (in-memory model)
// =============================================================================

struct FormControlItem {
    String name;           // e.g. "Button1"
    String type;           // e.g. "Button", "Label", "LineEdit"
    String scene_path;     // e.g. "res://addons/visual_gasic/prototypes/Button.tscn"
    String script_path;    // e.g. "res://addons/visual_gasic/vg_button.gd" (from tscn)
    Rect2  rect;           // Position + size on the form canvas
    String text;           // Display text (for Button, Label, CheckBox, etc.)
    bool   selected = false;
    bool   visible  = true;

    // Generic property bag for any extra properties
    Dictionary properties;
};

// =============================================================================
// UndoRedoCommand — Simple command pattern for undo/redo
// =============================================================================

struct FormUndoAction {
    enum Type {
        ACTION_ADD,
        ACTION_DELETE,
        ACTION_MOVE,
        ACTION_RESIZE,
        ACTION_PROPERTY,
        ACTION_MULTI  // Group of sub-actions
    };

    Type type;
    int  control_index = -1;      // Index into controls array
    FormControlItem before_state;  // Snapshot before change
    FormControlItem after_state;   // Snapshot after change
    Vector<FormUndoAction> sub_actions; // For ACTION_MULTI
};

// =============================================================================
// VisualGasicFormDesigner — The custom form designer canvas
// =============================================================================
//
// This is a self-contained Control that:
//   - Maintains an in-memory list of FormControlItems (NO Godot scene tree)
//   - Renders them as VB6-style rectangles on a grid
//   - Handles mouse interaction: select, move, resize, multi-select
//   - Accepts drag-drop from the C++ Toolbox (via Engine meta)
//   - Serializes to/from standard Godot .tscn files
//   - Has its own undo/redo stack
//   - Extensible: custom tools can be registered
//

class VisualGasicFormDesigner : public Control {
    GDCLASS(VisualGasicFormDesigner, Control);

public:
    // Selection resize handle IDs
    enum HandleID {
        HANDLE_NONE = -1,
        HANDLE_TL = 0,  // Top-left
        HANDLE_TM,      // Top-middle
        HANDLE_TR,      // Top-right
        HANDLE_ML,      // Middle-left
        HANDLE_MR,      // Middle-right
        HANDLE_BL,      // Bottom-left
        HANDLE_BM,      // Bottom-middle
        HANDLE_BR,      // Bottom-right
    };

    // Mouse interaction mode
    enum InteractionMode {
        MODE_NONE,
        MODE_SELECTING,      // Drawing rubber-band rectangle
        MODE_MOVING,         // Dragging selected controls
        MODE_RESIZING,       // Dragging a resize handle
        MODE_TOOLBOX_DROP,   // Dragging from toolbox (preview shown)
    };

protected:
    static void _bind_methods();

public:
    VisualGasicFormDesigner();
    ~VisualGasicFormDesigner();

    // --- Godot overrides ---
    void _ready() override;
    void _draw() override;
    void _gui_input(const Ref<InputEvent> &p_event) override;
    void _process(double p_delta) override;
    bool _can_drop_data(const Vector2 &p_point, const Variant &p_data) const override;
    void _drop_data(const Vector2 &p_point, const Variant &p_data) override;

    // --- Form file I/O ---
    void new_form(const String &p_name = "Form1");
    bool open_form(const String &p_tscn_path);
    bool save_form();
    bool save_form_as(const String &p_tscn_path);
    String get_form_path() const;
    String get_form_name() const;
    void set_form_name(const String &p_name);
    bool is_dirty() const;

    // --- Control manipulation (GDScript-accessible) ---
    int  add_control(const String &p_type, const String &p_scene_path, const Vector2 &p_position, const Vector2 &p_size = Vector2(-1, -1));
    void remove_selected();
    void select_all();
    void select_none();
    int  get_selected_count() const;
    PackedStringArray get_selected_names() const;
    void set_control_property(int p_index, const String &p_key, const Variant &p_value);
    Variant get_control_property(int p_index, const String &p_key) const;
    int  get_control_count() const;
    Dictionary get_control_info(int p_index) const;

    // --- Grid / snap ---
    void set_grid_size(int p_size);
    int  get_grid_size() const;
    void set_grid_visible(bool p_visible);
    bool get_grid_visible() const;
    void set_snap_enabled(bool p_enabled);
    bool get_snap_enabled() const;

    // --- Alignment helpers ---
    void align_left();
    void align_right();
    void align_top();
    void align_bottom();
    void align_center_h();
    void align_center_v();
    void make_same_width();
    void make_same_height();

    // --- Undo / Redo ---
    void undo();
    void redo();
    bool can_undo() const;
    bool can_redo() const;

    // --- Clipboard ---
    void cut();
    void copy();
    void paste();

    // --- Custom tool extensibility ---
    void register_custom_control_type(const String &p_type_name, const String &p_scene_path,
                                      const Vector2 &p_default_size, const Color &p_design_color);

    // --- Signals ---
    // "control_selected"  (index: int)
    // "control_deselected" ()
    // "form_modified" ()
    // "control_double_clicked" (index: int)

private:
    // --- Drawing helpers ---
    void _draw_grid();
    void _draw_form_background();
    void _draw_control(const FormControlItem &item, int index);
    void _draw_selection_handles(const Rect2 &rect);
    void _draw_rubber_band();
    void _draw_toolbox_preview();

    // --- Hit testing ---
    int      _hit_test(const Vector2 &p_pos) const;
    HandleID _hit_test_handle(const Vector2 &p_pos) const;
    Rect2    _get_handle_rect(const Rect2 &ctrl_rect, HandleID handle) const;

    // --- Mouse handlers ---
    void _on_mouse_down(const Ref<InputEventMouseButton> &p_event);
    void _on_mouse_up(const Ref<InputEventMouseButton> &p_event);
    void _on_mouse_motion(const Ref<InputEventMouseMotion> &p_event);

    // --- Snap helper ---
    Vector2 _snap(const Vector2 &p_pos) const;

    // --- Unique name generation ---
    String _make_unique_name(const String &p_base) const;

    // --- Default sizes for known control types ---
    Vector2 _default_size_for_type(const String &p_type) const;
    Color   _design_color_for_type(const String &p_type) const;
    String  _display_label_for_type(const String &p_type) const;

    // --- .tscn serialization ---
    String _serialize_to_tscn() const;
    bool   _parse_tscn(const String &p_text);

    // --- Undo helpers ---
    void _push_undo(const FormUndoAction &action);
    void _mark_dirty();

    // =========================================================================
    // Data
    // =========================================================================

    // Form metadata
    String form_name = "Form1";
    String form_path;  // .tscn path (empty = unsaved)
    Vector2i form_size = Vector2i(600, 400);
    bool dirty = false;

    // Controls in the form
    Vector<FormControlItem> controls;

    // Grid
    int  grid_size    = 8;
    bool grid_visible = true;
    bool snap_enabled = true;

    // Interaction state
    InteractionMode mode = MODE_NONE;
    Vector2 mouse_down_pos;
    Vector2 mouse_current_pos;
    Vector2 drag_offset;         // Offset from control origin at grab
    HandleID active_handle = HANDLE_NONE;
    Rect2   original_rect;       // Rect before resize started
    mutable int drag_control_index = -1; // mutable: set by const _hit_test_handle

    // Rubber-band selection
    Rect2 rubber_band_rect;

    // Toolbox drag preview
    String  preview_type;
    String  preview_scene_path;
    Vector2 preview_pos;
    bool    show_preview = false;

    // Undo / Redo stacks
    Vector<FormUndoAction> undo_stack;
    Vector<FormUndoAction> redo_stack;
    static const int MAX_UNDO = 100;

    // Clipboard
    Vector<FormControlItem> clipboard;

    // Custom control type registry (extensible)
    struct CustomControlDef {
        String scene_path;
        Vector2 default_size;
        Color design_color;
    };
    HashMap<String, CustomControlDef> custom_control_types;

    // Drawing constants
    static constexpr float HANDLE_SIZE      = 6.0f;
    static constexpr float HANDLE_HALF      = 3.0f;
    static constexpr float MIN_CONTROL_SIZE = 8.0f;

    // Colors (VB6-style)
    Color color_form_bg      = Color(0.753, 0.753, 0.753, 1.0); // Classic gray
    Color color_grid_dot     = Color(0.0, 0.0, 0.0, 0.3);
    Color color_control_bg   = Color(0.85, 0.85, 0.85, 1.0);
    Color color_control_border = Color(0.0, 0.0, 0.0, 1.0);
    Color color_selected     = Color(0.0, 0.0, 0.6, 1.0);     // VB6 dark blue
    Color color_handle       = Color(0.0, 0.0, 0.0, 1.0);
    Color color_rubber_band  = Color(0.0, 0.0, 0.6, 0.3);
    Color color_text         = Color(0.0, 0.0, 0.0, 1.0);
};

#endif // VISUAL_GASIC_FORM_DESIGNER_H

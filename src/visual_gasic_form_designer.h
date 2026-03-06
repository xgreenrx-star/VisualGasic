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
#include <godot_cpp/classes/texture2d.hpp>
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
        MODE_PLACING,        // Click-to-place: first click = origin, drag = size
        MODE_FORM_RESIZING,  // Dragging a form border handle to resize the form
    };

    // Window type for the form (affects .tscn root node and runtime container)
    enum WindowType {
        WINDOW_GAME = 0,     // SubViewport-based (embedded in game)
        WINDOW_WINDOWS = 1,  // Native OS Window (Windows-style)
        WINDOW_LINUX = 2,    // Native OS Window (Linux/CSD-style)
        WINDOW_MAC = 3,      // Native OS Window (Mac-style)
    };

    // VB6 BorderStyle — controls form chrome appearance
    enum FormBorderStyle {
        BORDER_NONE = 0,           // No border, no title bar
        BORDER_FIXED_SINGLE = 1,   // Fixed (non-resizable) with title bar
        BORDER_SIZABLE = 2,        // Default — sizable with title bar
        BORDER_FIXED_DIALOG = 3,   // Fixed dialog — no min/max buttons
        BORDER_FIXED_TOOL = 4,     // Thin title bar, close only
        BORDER_SIZABLE_TOOL = 5,   // Thin title bar, close only, sizable
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
    void set_control_preview_texture(const String &p_type_name, const Ref<Texture2D> &p_texture);

    // --- Active tool (click-to-place mode) ---
    void set_active_tool(const String &p_class_name, const String &p_scene_path);
    String get_active_tool() const;
    void clear_active_tool();

    // --- Window type ---
    void set_window_type(int p_type);
    int  get_window_type() const;

    // --- Form size ---
    void set_form_size(const Vector2i &p_size);
    Vector2i get_form_size() const;

    // --- VB6 Form Properties ---
    void set_form_property(const String &p_key, const Variant &p_value);
    Variant get_form_property(const String &p_key) const;
    Dictionary get_form_properties() const;

    // --- Status info for toolbar/statusbar ---
    String get_status_text() const;
    Vector2 get_mouse_canvas_pos() const;

    // --- Theme colors (configurable from GDScript theme file) ---
    void set_theme_colors(const Dictionary &p_colors);
    Dictionary get_theme_colors() const;

    // --- Signals ---
    // "control_selected"  (index: int)
    // "control_deselected" ()
    // "form_modified" ()
    // "control_double_clicked" (index: int)
    // "control_right_clicked" (index: int, position: Vector2) — context menu
    // "status_changed" (text: String)  — for toolbar/statusbar coordinate display
    // "form_resized" (size: Vector2i)  — when user resizes the form via handles

private:
    // --- Drawing helpers ---
    void _draw_grid();
    void _draw_form_background();
    void _draw_form_menu_bar();        // VB6-style menu bar for has_menu_bar forms
    void _draw_mdi_frame();           // Outer MDI window frame around the form
    void _draw_form_caption_buttons(); // Min/Max/Close buttons on the title bar
    void _draw_form_resize_handles();  // Blue handles at form edges for resizing
    void _draw_control(const FormControlItem &item, int index);
    void _draw_selection_handles(const Rect2 &rect);
    void _draw_rubber_band();
    void _draw_toolbox_preview();

    // --- Form resize hit testing ---
    HandleID _hit_test_form_handle(const Vector2 &p_pos) const;
    Rect2    _get_form_handle_rect(HandleID handle) const;

    // --- WYSIWYG per-type drawing (WinForms-style) ---
    void _draw_raised_rect(const Rect2 &r, const Color &face);   // 3D raised border
    void _draw_sunken_rect(const Rect2 &r, const Color &face);   // 3D sunken border
    void _draw_etched_rect(const Rect2 &r);                      // Etched frame border
    void _draw_button_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_label_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign = HORIZONTAL_ALIGNMENT_LEFT);
    void _draw_textbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign = HORIZONTAL_ALIGNMENT_LEFT);
    void _draw_textarea_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign = HORIZONTAL_ALIGNMENT_LEFT);
    void _draw_checkbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_option_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_combobox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_listbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_frame_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_progressbar_control(const Rect2 &r, const Ref<Font> &font, int font_size);
    void _draw_hscrollbar_control(const Rect2 &r);
    void _draw_vscrollbar_control(const Rect2 &r);
    void _draw_hslider_control(const Rect2 &r);
    void _draw_vslider_control(const Rect2 &r);
    void _draw_spinbox_control(const Rect2 &r, const Ref<Font> &font, int font_size);
    void _draw_timer_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size);
    void _draw_picture_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size);
    void _draw_treeview_control(const Rect2 &r, const Ref<Font> &font, int font_size);
    void _draw_richtext_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_tabstrip_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size);
    void _draw_shape_control(const Rect2 &r);

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
    void   _validate_scene_paths();
    String _serialize_to_tscn() const;
    bool   _parse_tscn(const String &p_text);

    // --- Undo helpers ---
    void _push_undo(const FormUndoAction &action);
    void _mark_dirty();

    // --- VB6 default property initializer ---
    void _init_vb6_defaults(FormControlItem &item) const;

    // =========================================================================
    // Data
    // =========================================================================

    // Form metadata
    String form_name = "Form1";
    String form_path;  // .tscn path (empty = unsaved)
    Vector2i form_size = Vector2i(600, 400);
    bool dirty = false;
    WindowType window_type = WINDOW_GAME;

    // VB6 form properties
    FormBorderStyle form_border_style = BORDER_SIZABLE;  // Default: sizable with full chrome
    bool form_control_box = true;   // Show system menu / close button
    bool form_min_button  = true;   // Show minimize button
    bool form_max_button  = true;   // Show maximize button
    bool form_moveable    = true;   // Form can be moved at runtime
    bool form_show_in_taskbar = true; // Show in OS taskbar
    int  form_window_state = 0;     // 0=Normal, 1=Minimized, 2=Maximized
    int  form_start_position = 2;   // 0=Manual, 1=CenterOwner, 2=CenterScreen, 3=Default
    bool form_key_preview = false;  // Fire form key events before control events
    bool form_auto_redraw = true;   // Auto paint
    Color form_back_color = Color(0.753, 0.753, 0.753, 1.0); // SystemButtonFace
    Color form_fore_color = Color(0.0, 0.0, 0.0, 1.0);       // Black
    String form_icon = "";          // Icon path

    // Menu bar
    bool has_menu_bar = false;       // True if form was created with "Main Form with Menu" template
    String menu_bar_node_name;       // Name used in .tscn (e.g., "MainMenu")
    Vector<String> menu_child_raw_blocks;  // Raw [node ...] blocks for PopupMenu children
    Vector<String> menu_titles;      // Display titles extracted from PopupMenu node names

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

    // Active tool for click-to-place
    String placing_tool_class;       // e.g. "Button"
    String placing_tool_scene_path;  // e.g. "res://addons/visual_gasic/prototypes/Button.tscn"
    Rect2  placing_rect;             // Rect being drawn during MODE_PLACING

    // Form resize state
    HandleID form_resize_handle = HANDLE_NONE;
    Vector2i original_form_size;
    Vector2  form_resize_mouse_start;

    // Canvas offset (padding around the form for the MDI frame)
    static constexpr int   VB6_FONT_SIZE = 12;     // VB6 default 8pt → 12px  (pt * 1.5)
    // Convert VB6 point size to Godot pixel size (96 DPI rounding)
    static inline int vb6_pt_to_px(int pt) { return pt > 0 ? (int)Math::round(pt * 1.5) : VB6_FONT_SIZE; }
    static constexpr float FORM_PADDING_X = 40.0f;
    static constexpr float FORM_PADDING_Y = 60.0f;  // Space for MDI title bar + form title bar + border
    static constexpr float MDI_TITLE_HEIGHT = 20.0f; // MDI parent window title bar
    static constexpr float FORM_TITLE_HEIGHT = 24.0f;
    static constexpr float CAPTION_BTN_W = 16.0f;
    static constexpr float CAPTION_BTN_H = 14.0f;
    static constexpr float FORM_HANDLE_SIZE = 8.0f;
    static constexpr float FORM_HANDLE_HALF = 4.0f;
    // Extra client-area padding inside the MDI frame (space around the form body)
    static constexpr float MDI_CLIENT_PAD_RIGHT  = 120.0f;
    static constexpr float MDI_CLIENT_PAD_BOTTOM = 100.0f;

    // Helper: update custom_minimum_size to always be bigger than the form
    void _update_min_size();

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

    // Preview textures for custom controls (rendered thumbnails for design-time display)
    HashMap<String, Ref<Texture2D>> control_preview_textures;

    // Drawing constants
    static constexpr float HANDLE_SIZE      = 6.0f;
    static constexpr float HANDLE_HALF      = 3.0f;
    static constexpr float MIN_CONTROL_SIZE = 8.0f;

    // Colors — form canvas
    Color color_form_bg      = Color(0.753, 0.753, 0.753, 1.0); // Classic gray
    Color color_form_border  = Color(0.4, 0.4, 0.4, 1.0);       // Form outline
    Color color_grid_dot     = Color(0.0, 0.0, 0.0, 0.3);
    Color color_selected     = Color(0.0, 0.0, 0.6, 1.0);       // Selection border
    Color color_handle       = Color(0.0, 0.0, 0.0, 1.0);       // Resize handles
    Color color_rubber_band  = Color(0.0, 0.0, 0.6, 0.3);       // Rubber-band rect
    Color color_text         = Color(0.0, 0.0, 0.0, 1.0);       // Default text

    // Win32 system color palette — used by WYSIWYG control drawing
    Color sys_button_face      = Color(0.831, 0.816, 0.784);    // Button/control face
    Color sys_button_highlight = Color(1.0, 1.0, 1.0);          // 3D highlight
    Color sys_button_shadow    = Color(0.51, 0.51, 0.51);       // 3D shadow
    Color sys_3d_dark_shadow   = Color(0.25, 0.25, 0.25);       // Dark shadow
    Color sys_3d_light         = Color(0.93, 0.93, 0.89);       // Inner highlight
    Color sys_window           = Color(1.0, 1.0, 1.0);          // Window/textbox bg
    Color sys_window_text      = Color(0.0, 0.0, 0.0);          // Text in windows
    Color sys_active_title     = Color(0.0, 0.0, 0.5);          // Title bar bg
    Color sys_inactive_title   = Color(0.5, 0.5, 0.5);          // MDI parent title bar
    Color sys_title_text       = Color(1.0, 1.0, 1.0);          // Title bar text
    Color mdi_background       = Color(0.64, 0.64, 0.64);       // MDI client area bg
    Color form_handle_color    = Color(0.0, 0.0, 0.0);          // Form resize handles (black like VB6)
    Color sys_scrollbar        = Color(0.87, 0.87, 0.87);       // Scrollbar track
    Color sys_glyph            = Color(0.0, 0.0, 0.0);          // Arrow glyphs
    Color sys_progress_fill    = Color(0.0, 0.5, 0.0);          // Progress bar
    Color design_outline       = Color(0.0, 0.0, 0.0, 0.35);   // Design-time dashes
    Color nonvisual_bg         = Color(0.9, 0.85, 0.72);        // Timer/non-visual bg
    Color nonvisual_border     = Color(0.6, 0.55, 0.45);        // Timer/non-visual border
    Color placeholder_color    = Color(0.6, 0.6, 0.6);          // Image placeholders
};

#endif // VISUAL_GASIC_FORM_DESIGNER_H

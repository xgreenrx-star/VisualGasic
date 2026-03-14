#include "visual_gasic_form_designer.h"

#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/spin_box.hpp>
#include <godot_cpp/classes/check_box.hpp>
#include <godot_cpp/classes/check_button.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/range.hpp>
#include <godot_cpp/classes/base_button.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/slider.hpp>
#include <godot_cpp/classes/scroll_bar.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/color_rect.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/texture_button.hpp>
#include <godot_cpp/classes/rich_text_label.hpp>
#include <godot_cpp/classes/menu_bar.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/tab_bar.hpp>
#include <godot_cpp/classes/system_font.hpp>

using namespace godot;

// =============================================================================
// Bind methods — exposes everything to GDScript
// =============================================================================

void VisualGasicFormDesigner::_bind_methods() {
    // File I/O
    ClassDB::bind_method(D_METHOD("new_form", "name"), &VisualGasicFormDesigner::new_form, DEFVAL("Form1"));
    ClassDB::bind_method(D_METHOD("open_form", "tscn_path"), &VisualGasicFormDesigner::open_form);
    ClassDB::bind_method(D_METHOD("save_form"), &VisualGasicFormDesigner::save_form);
    ClassDB::bind_method(D_METHOD("save_form_as", "tscn_path"), &VisualGasicFormDesigner::save_form_as);
    ClassDB::bind_method(D_METHOD("get_form_path"), &VisualGasicFormDesigner::get_form_path);
    ClassDB::bind_method(D_METHOD("get_form_name"), &VisualGasicFormDesigner::get_form_name);
    ClassDB::bind_method(D_METHOD("set_form_name", "name"), &VisualGasicFormDesigner::set_form_name);
    ClassDB::bind_method(D_METHOD("is_dirty"), &VisualGasicFormDesigner::is_dirty);

    // Control manipulation
    ClassDB::bind_method(D_METHOD("add_control", "type", "scene_path", "position", "size"), &VisualGasicFormDesigner::add_control, DEFVAL(Vector2(-1, -1)));
    ClassDB::bind_method(D_METHOD("remove_selected"), &VisualGasicFormDesigner::remove_selected);
    ClassDB::bind_method(D_METHOD("select_all"), &VisualGasicFormDesigner::select_all);
    ClassDB::bind_method(D_METHOD("select_none"), &VisualGasicFormDesigner::select_none);
    ClassDB::bind_method(D_METHOD("get_selected_count"), &VisualGasicFormDesigner::get_selected_count);
    ClassDB::bind_method(D_METHOD("get_selected_names"), &VisualGasicFormDesigner::get_selected_names);
    ClassDB::bind_method(D_METHOD("set_control_property", "index", "key", "value"), &VisualGasicFormDesigner::set_control_property);
    ClassDB::bind_method(D_METHOD("get_control_property", "index", "key"), &VisualGasicFormDesigner::get_control_property);
    ClassDB::bind_method(D_METHOD("get_control_count"), &VisualGasicFormDesigner::get_control_count);
    ClassDB::bind_method(D_METHOD("get_control_info", "index"), &VisualGasicFormDesigner::get_control_info);

    // Grid
    ClassDB::bind_method(D_METHOD("set_grid_size", "size"), &VisualGasicFormDesigner::set_grid_size);
    ClassDB::bind_method(D_METHOD("get_grid_size"), &VisualGasicFormDesigner::get_grid_size);
    ClassDB::bind_method(D_METHOD("set_grid_visible", "visible"), &VisualGasicFormDesigner::set_grid_visible);
    ClassDB::bind_method(D_METHOD("get_grid_visible"), &VisualGasicFormDesigner::get_grid_visible);
    ClassDB::bind_method(D_METHOD("set_snap_enabled", "enabled"), &VisualGasicFormDesigner::set_snap_enabled);
    ClassDB::bind_method(D_METHOD("get_snap_enabled"), &VisualGasicFormDesigner::get_snap_enabled);

    // Show Indexes overlay
    ClassDB::bind_method(D_METHOD("set_show_indexes", "show"), &VisualGasicFormDesigner::set_show_indexes);
    ClassDB::bind_method(D_METHOD("get_show_indexes"), &VisualGasicFormDesigner::get_show_indexes);

    // Alignment
    ClassDB::bind_method(D_METHOD("align_left"), &VisualGasicFormDesigner::align_left);
    ClassDB::bind_method(D_METHOD("align_right"), &VisualGasicFormDesigner::align_right);
    ClassDB::bind_method(D_METHOD("align_top"), &VisualGasicFormDesigner::align_top);
    ClassDB::bind_method(D_METHOD("align_bottom"), &VisualGasicFormDesigner::align_bottom);
    ClassDB::bind_method(D_METHOD("align_center_h"), &VisualGasicFormDesigner::align_center_h);
    ClassDB::bind_method(D_METHOD("align_center_v"), &VisualGasicFormDesigner::align_center_v);
    ClassDB::bind_method(D_METHOD("make_same_width"), &VisualGasicFormDesigner::make_same_width);
    ClassDB::bind_method(D_METHOD("make_same_height"), &VisualGasicFormDesigner::make_same_height);

    // Undo/Redo
    ClassDB::bind_method(D_METHOD("undo"), &VisualGasicFormDesigner::undo);
    ClassDB::bind_method(D_METHOD("redo"), &VisualGasicFormDesigner::redo);
    ClassDB::bind_method(D_METHOD("can_undo"), &VisualGasicFormDesigner::can_undo);
    ClassDB::bind_method(D_METHOD("can_redo"), &VisualGasicFormDesigner::can_redo);

    // Clipboard
    ClassDB::bind_method(D_METHOD("cut"), &VisualGasicFormDesigner::cut);
    ClassDB::bind_method(D_METHOD("copy"), &VisualGasicFormDesigner::copy);
    ClassDB::bind_method(D_METHOD("paste"), &VisualGasicFormDesigner::paste);

    // Extensibility
    ClassDB::bind_method(D_METHOD("register_custom_control_type", "type_name", "scene_path", "default_size", "design_color"),
                         &VisualGasicFormDesigner::register_custom_control_type);
    ClassDB::bind_method(D_METHOD("set_control_preview_texture", "type_name", "texture"),
                         &VisualGasicFormDesigner::set_control_preview_texture);

    // Active tool (click-to-place)
    ClassDB::bind_method(D_METHOD("set_active_tool", "class_name", "scene_path"), &VisualGasicFormDesigner::set_active_tool);
    ClassDB::bind_method(D_METHOD("get_active_tool"), &VisualGasicFormDesigner::get_active_tool);
    ClassDB::bind_method(D_METHOD("clear_active_tool"), &VisualGasicFormDesigner::clear_active_tool);

    // Window type
    ClassDB::bind_method(D_METHOD("set_window_type", "type"), &VisualGasicFormDesigner::set_window_type);
    ClassDB::bind_method(D_METHOD("get_window_type"), &VisualGasicFormDesigner::get_window_type);

    // Game UI Mode
    ClassDB::bind_method(D_METHOD("set_game_ui_mode", "enabled"), &VisualGasicFormDesigner::set_game_ui_mode);
    ClassDB::bind_method(D_METHOD("get_game_ui_mode"), &VisualGasicFormDesigner::get_game_ui_mode);

    // Theme colors
    ClassDB::bind_method(D_METHOD("set_theme_colors", "colors"), &VisualGasicFormDesigner::set_theme_colors);
    ClassDB::bind_method(D_METHOD("get_theme_colors"), &VisualGasicFormDesigner::get_theme_colors);

    // VB6 Form Properties
    ClassDB::bind_method(D_METHOD("set_form_property", "key", "value"), &VisualGasicFormDesigner::set_form_property);
    ClassDB::bind_method(D_METHOD("get_form_property", "key"), &VisualGasicFormDesigner::get_form_property);
    ClassDB::bind_method(D_METHOD("get_form_properties"), &VisualGasicFormDesigner::get_form_properties);

    // Properties
    ADD_PROPERTY(PropertyInfo(Variant::INT, "grid_size"), "set_grid_size", "get_grid_size");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "grid_visible"), "set_grid_visible", "get_grid_visible");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "snap_enabled"), "set_snap_enabled", "get_snap_enabled");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "show_indexes"), "set_show_indexes", "get_show_indexes");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "window_type"), "set_window_type", "get_window_type");

    // Form size
    ClassDB::bind_method(D_METHOD("set_form_size", "size"), &VisualGasicFormDesigner::set_form_size);
    ClassDB::bind_method(D_METHOD("get_form_size"), &VisualGasicFormDesigner::get_form_size);
    ClassDB::bind_method(D_METHOD("get_status_text"), &VisualGasicFormDesigner::get_status_text);
    ClassDB::bind_method(D_METHOD("get_mouse_canvas_pos"), &VisualGasicFormDesigner::get_mouse_canvas_pos);

    // Game UI mode
    ClassDB::bind_method(D_METHOD("set_game_ui_mode", "enabled"), &VisualGasicFormDesigner::set_game_ui_mode);
    ClassDB::bind_method(D_METHOD("get_game_ui_mode"), &VisualGasicFormDesigner::get_game_ui_mode);

    // Signals
    ADD_SIGNAL(MethodInfo("control_selected", PropertyInfo(Variant::INT, "index")));
    ADD_SIGNAL(MethodInfo("control_deselected"));
    ADD_SIGNAL(MethodInfo("form_modified"));
    ADD_SIGNAL(MethodInfo("control_double_clicked", PropertyInfo(Variant::INT, "index")));
    ADD_SIGNAL(MethodInfo("control_right_clicked", PropertyInfo(Variant::INT, "index"), PropertyInfo(Variant::VECTOR2, "position")));
    ADD_SIGNAL(MethodInfo("status_changed", PropertyInfo(Variant::STRING, "text")));
    ADD_SIGNAL(MethodInfo("form_resized", PropertyInfo(Variant::VECTOR2I, "size")));
    ADD_SIGNAL(MethodInfo("scene_file_dropped", PropertyInfo(Variant::STRING, "scene_path"), PropertyInfo(Variant::STRING, "control_name")));
    ADD_SIGNAL(MethodInfo("game_ui_mode_changed", PropertyInfo(Variant::BOOL, "enabled")));

    // Internal methods (used for signal connections)
    ClassDB::bind_method(D_METHOD("_on_overlay_draw"), &VisualGasicFormDesigner::_on_overlay_draw);
}

// =============================================================================
// Constructor / Destructor
// =============================================================================

VisualGasicFormDesigner::VisualGasicFormDesigner() {
    set_name("FormDesigner");
    set_focus_mode(FOCUS_ALL);
    set_clip_contents(true);
}

VisualGasicFormDesigner::~VisualGasicFormDesigner() {
}

// =============================================================================
// Godot lifecycle
// =============================================================================

void VisualGasicFormDesigner::_ready() {
    _update_min_size();
    _create_preview_layer();
    // If open_form was called before _ready (common with editor layout restore),
    // the live previews couldn't be created. Rebuild them now.
    if (preview_container && controls.size() > 0 && live_previews.size() == 0) {
        _rebuild_all_live_previews();
    }
}

void VisualGasicFormDesigner::_update_min_size() {
    // Set minimum size to exactly what the form needs.
    // Inside a ScrollContainer, this determines the scrollable area.
    // The MDI frame always fills get_size() (which may be larger).
    float w = FORM_PADDING_X + (float)form_size.x + FORM_HANDLE_SIZE + 20.0f;
    float h = FORM_PADDING_Y + (float)form_size.y + FORM_HANDLE_SIZE + 20.0f;
    set_custom_minimum_size(Vector2(w, h));
}

void VisualGasicFormDesigner::_process(double p_delta) {
    // ── Animated form designer: always tick animation clock ──
    anim_time += (float)p_delta;
    if (anim_time > 3600.0f) anim_time -= 3600.0f;
    // Keep overlay in sync (selection handles, rubber band)
    if (overlay_node) overlay_node->queue_redraw();

    // Detect toolbox drag (Engine meta set by C++ toolbox)
    if (Engine::get_singleton()->has_meta("_vg_active_drag")) {
        Variant meta = Engine::get_singleton()->get_meta("_vg_active_drag");
        if (meta.get_type() == Variant::DICTIONARY) {
            Dictionary data = meta;
            if (data.has("type") && String(data["type"]) == "vg_control") {
                // Show preview while hovering
                if (!show_preview) {
                    preview_type = data.get("class_name", "Control");
                    preview_scene_path = data.get("scene_path", "");
                    show_preview = true;
                    queue_redraw();
                }
            }
        }
    } else if (show_preview) {
        show_preview = false;
        queue_redraw();
    }
}

// =============================================================================
// Drawing
// =============================================================================

void VisualGasicFormDesigner::_draw() {
    // Draw MDI background area (the gray workspace behind all forms)
    Rect2 full = Rect2(Vector2(), get_size());
    draw_rect(full, mdi_background);

    // Draw MDI parent window frame
    _draw_mdi_frame();

    // Translate to form body origin (inside the MDI frame)
    // The form body starts at (FORM_PADDING_X, FORM_PADDING_Y)
    draw_set_transform(Vector2(FORM_PADDING_X, FORM_PADDING_Y));

    _draw_form_background();
    _draw_form_menu_bar();
    _draw_grid();

    // Draw controls back-to-front (only those without live preview instances)
    for (int i = 0; i < controls.size(); i++) {
        if (live_previews.has(controls[i].name) && live_previews[controls[i].name] != nullptr) {
            // Rendered by live preview scene instance.
            // If invisible, the live preview handles the ghost appearance.
            continue;
        }
        if (controls[i].visible) {
            _draw_control(controls[i], i);
        } else {
            // Design-time ghost: draw the control at reduced opacity so the
            // designer can still see, select, and edit invisible controls.
            _draw_control(controls[i], i);
            // Overlay a semi-transparent hatch pattern to signal "invisible at runtime"
            Rect2 r = controls[i].rect;
            draw_rect(r, Color(0.5, 0.5, 0.5, 0.25));
            // Diagonal hatch lines
            float step = 8.0f;
            Color hatch_color(0.4, 0.4, 0.4, 0.3);
            for (float d = -r.size.y; d < r.size.x; d += step) {
                Vector2 p1(MAX(r.position.x, r.position.x + d), r.position.y + MAX(0.0f, -d));
                Vector2 p2(MIN(r.position.x + r.size.x, r.position.x + d + r.size.y),
                           MIN(r.position.y + r.size.y, r.position.y + r.size.x - d));
                if (p1.x < r.position.x + r.size.x && p2.y > r.position.y) {
                    draw_line(p1, p2, hatch_color, 1.0);
                }
            }
        }
    }

    _draw_toolbox_preview();

    // Reset transform for form-level drawing
    draw_set_transform(Vector2());

    // Selection handles, rubber band, and form resize handles are drawn
    // by the overlay_node (on top of live preview children).
}

void VisualGasicFormDesigner::_draw_form_background() {
    // Classic VB6 form background (drawn in form-local coordinates, 0,0 = top-left of form body)
    Rect2 bg = Rect2(Vector2(), Vector2(form_size));

    // Game UI Mode: dark semi-transparent canvas (simulating a game viewport)
    if (game_ui_mode) {
        draw_rect(bg, Color(0.12, 0.12, 0.15, 1.0)); // Dark game background
        // Crosshair guides at center
        Color guide = Color(0.3, 0.6, 1.0, 0.25);
        float cx = form_size.x * 0.5f;
        float cy = form_size.y * 0.5f;
        draw_line(Vector2(cx, 0), Vector2(cx, form_size.y), guide, 1.0);
        draw_line(Vector2(0, cy), Vector2(form_size.x, cy), guide, 1.0);
        // Safe area rectangle (80% of form)
        float mx = form_size.x * 0.1f;
        float my = form_size.y * 0.1f;
        draw_rect(Rect2(mx, my, form_size.x - mx * 2, form_size.y - my * 2), Color(0.3, 0.6, 1.0, 0.12), false, 1.0);
        // "GAME UI" badge in top-left
        Ref<Font> font = get_theme_default_font();
        if (font.is_valid()) {
            draw_string(font, Vector2(6, 14), "GAME UI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.6, 1.0, 0.5));
        }
        // Thin outline border (design-time only)
        draw_rect(bg, Color(0.3, 0.6, 1.0, 0.3), false, 1.0);
        return;
    }

    draw_rect(bg, color_form_bg);

    // BorderStyle 0 (None) = no border, no title bar at all
    if (form_border_style == BORDER_NONE) {
        // Just the form body with a thin design-time dashed outline
        draw_rect(bg, design_outline, false, 1.0);
        return;
    }

    // Border
    draw_rect(bg, color_form_border, false, 1.0);

    // Title bar height depends on tool window vs. normal
    float title_h = (form_border_style == BORDER_FIXED_TOOL || form_border_style == BORDER_SIZABLE_TOOL)
                    ? FORM_TITLE_HEIGHT * 0.75f : FORM_TITLE_HEIGHT;

    // Title bar (above form body, at Y = -title_h)
    Rect2 title_bar(Vector2(0, -title_h), Vector2(form_size.x, title_h));
    draw_rect(title_bar, sys_active_title);

    // Title text
    Ref<Font> font = get_theme_default_font();
    if (font.is_valid()) {
        draw_string(font, Vector2(4, -title_h + title_h - 6), form_name, HORIZONTAL_ALIGNMENT_LEFT, form_size.x - 80, VB6_FONT_SIZE, sys_title_text);
    }

    // Caption buttons (only if ControlBox is true)
    if (form_control_box) {
        _draw_form_caption_buttons();
    }
}

void VisualGasicFormDesigner::_draw_form_menu_bar() {
    // Draw a VB6-style menu bar for forms created with "Main Form with Menu" template.
    // This renders at the top of the form body (Y=0), using actual menu titles
    // extracted from the PopupMenu children (menu_titles vector).
    if (!has_menu_bar || menu_titles.size() == 0) return;

    float bar_h = 20.0f;  // VB6 menu bar height
    Rect2 bar(Vector2(0, 0), Vector2(form_size.x, bar_h));

    // Background: standard button face color (flat gray)
    draw_rect(bar, sys_button_face);
    // Bottom border: subtle shadow line
    draw_rect(Rect2(0, bar_h - 1, form_size.x, 1), sys_button_shadow);

    Ref<Font> font = get_theme_default_font();
    if (!font.is_valid()) return;
    int fsize = VB6_FONT_SIZE;

    float tx = 6.0f;
    float ty = (bar_h + fsize) * 0.5f - 2.0f;

    for (int m = 0; m < menu_titles.size(); m++) {
        String title = menu_titles[m];
        float tw = font->get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x;
        // Draw with 6px padding on each side of each item (VB6 menu item spacing)
        draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color_text);
        tx += tw + 12.0f;  // text width + padding between items
    }
}

void VisualGasicFormDesigner::_draw_mdi_frame() {
    // The MDI parent window frame fills the ENTIRE available widget area.
    // In VB6, this is the large window that contains the form designer workspace.
    // The form floats inside it.
    Vector2 sz = get_size();
    float margin = 2.0f;
    Rect2 frame(Vector2(margin, margin), Vector2(sz.x - margin * 2, sz.y - margin * 2));

    // Outer 3D raised border (Win95/98 style)
    draw_rect(frame, sys_button_highlight, false, 1.0);
    Rect2 inner_border(frame.position + Vector2(1, 1), frame.size - Vector2(2, 2));
    draw_rect(inner_border, sys_3d_dark_shadow, false, 1.0);

    // MDI title bar (blue bar across top of workspace)
    Rect2 mdi_title(Vector2(margin + 2, margin + 2),
                     Vector2(sz.x - margin * 2 - 4, MDI_TITLE_HEIGHT));
    draw_rect(mdi_title, sys_active_title);

    // MDI title text: "ProjectName - FormName (Form)"
    Ref<Font> font = get_theme_default_font();
    if (font.is_valid()) {
        String mdi_text = form_name + String(" (Form)");
        draw_string(font, Vector2(mdi_title.position.x + 4, mdi_title.position.y + 15),
                    mdi_text, HORIZONTAL_ALIGNMENT_LEFT, mdi_title.size.x - 8, VB6_FONT_SIZE, sys_title_text);
    }

    // Sunken client area (below MDI title bar — the gray workspace)
    float client_y = margin + 2 + MDI_TITLE_HEIGHT;
    Rect2 client(Vector2(margin + 2, client_y),
                 Vector2(sz.x - margin * 2 - 4, sz.y - client_y - margin - 2));
    // Sunken border lines
    draw_rect(client, sys_button_shadow, false, 1.0);
    draw_rect(Rect2(client.position + Vector2(1, 1), client.size - Vector2(2, 2)),
              sys_button_highlight, false, 1.0);
}

void VisualGasicFormDesigner::_draw_form_caption_buttons() {
    // Draw caption buttons based on VB6 form properties
    // Tool windows only get a close button; FixedDialog has no min/max
    bool is_tool = (form_border_style == BORDER_FIXED_TOOL || form_border_style == BORDER_SIZABLE_TOOL);
    bool is_dialog = (form_border_style == BORDER_FIXED_DIALOG);

    bool show_close = form_control_box;
    bool show_max = form_max_button && !is_tool && !is_dialog;
    bool show_min = form_min_button && !is_tool && !is_dialog;

    float title_h = is_tool ? FORM_TITLE_HEIGHT * 0.75f : FORM_TITLE_HEIGHT;
    float btn_h = is_tool ? CAPTION_BTN_H * 0.75f : CAPTION_BTN_H;
    float btn_w = is_tool ? CAPTION_BTN_W * 0.85f : CAPTION_BTN_W;
    float btn_y = -title_h + (title_h - btn_h) / 2.0f;

    // Position buttons from right to left
    float x = form_size.x - btn_w - 3;

    // Button backgrounds (raised 3D look)
    auto draw_caption_btn = [&](float bx, float by, float bw, float bh) {
        Rect2 btn_rect(Vector2(bx, by), Vector2(bw, bh));
        draw_rect(btn_rect, sys_button_face);
        draw_line(Vector2(bx, by), Vector2(bx + bw, by), sys_button_highlight);
        draw_line(Vector2(bx, by), Vector2(bx, by + bh), sys_button_highlight);
        draw_line(Vector2(bx + bw - 1, by), Vector2(bx + bw - 1, by + bh), sys_3d_dark_shadow);
        draw_line(Vector2(bx, by + bh - 1), Vector2(bx + bw, by + bh - 1), sys_3d_dark_shadow);
    };

    Color glyph = sys_glyph;

    // Close button
    if (show_close) {
        draw_caption_btn(x, btn_y, btn_w, btn_h);
        // X glyph
        float g_cx1 = x + 4;
        float g_cy1 = btn_y + 3;
        float g_cx2 = x + btn_w - 4;
        float g_cy2 = btn_y + btn_h - 3;
        draw_line(Vector2(g_cx1, g_cy1), Vector2(g_cx2, g_cy2), glyph, 1.5);
        draw_line(Vector2(g_cx2, g_cy1), Vector2(g_cx1, g_cy2), glyph, 1.5);
        x -= btn_w + 1;
    }

    // Maximize button
    if (show_max) {
        draw_caption_btn(x, btn_y, btn_w, btn_h);
        // Rectangle glyph
        float g_x1 = x + 3;
        float g_y1 = btn_y + 3;
        float g_x2 = x + btn_w - 4;
        float g_y2 = btn_y + btn_h - 3;
        draw_rect(Rect2(Vector2(g_x1, g_y1), Vector2(g_x2 - g_x1, g_y2 - g_y1)), glyph, false, 1.0);
        draw_line(Vector2(g_x1, g_y1 + 1), Vector2(g_x2, g_y1 + 1), glyph, 1.0);
        x -= btn_w + 1;
    }

    // Minimize button
    if (show_min) {
        draw_caption_btn(x, btn_y, btn_w, btn_h);
        // Horizontal line glyph at bottom
        float g_min_y = btn_y + btn_h - 5;
        draw_line(Vector2(x + 4, g_min_y), Vector2(x + btn_w - 4, g_min_y), glyph, 2.0);
    }
}

void VisualGasicFormDesigner::_draw_form_resize_handles() {
    // Draw 8 blue/black resize handles at the form border edges
    // These are drawn in global (non-transformed) coordinates
    for (int h = 0; h < 8; h++) {
        Rect2 hr = _get_form_handle_rect((HandleID)h);
        draw_rect(hr, form_handle_color);
    }
}

void VisualGasicFormDesigner::_draw_grid() {
    if (!grid_visible) return;

    // VB6-style dot grid
    for (int x = 0; x <= form_size.x; x += grid_size) {
        for (int y = 0; y <= form_size.y; y += grid_size) {
            draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), color_grid_dot);
        }
    }
}

void VisualGasicFormDesigner::_draw_control(const FormControlItem &item, int index) {
    Rect2 r = item.rect;
    Ref<Font> font = get_theme_default_font();
    // Per-control font size: read VB6 FontSize (points) and convert to Godot px
    int font_size = VB6_FONT_SIZE;  // default = 8pt → 12px
    if (item.properties.has("FontSize")) {
        int vb6_pt = int(item.properties["FontSize"]);
        font_size = vb6_pt_to_px(vb6_pt);
    }
    String label = item.text.is_empty() ? item.name : item.text;

    // Extract VB6 Alignment property: 0=Left, 1=Right, 2=Center
    HorizontalAlignment halign = HORIZONTAL_ALIGNMENT_LEFT;
    if (item.properties.has("Alignment")) {
        int vb6_align = int(item.properties["Alignment"]);
        switch (vb6_align) {
            case 1: halign = HORIZONTAL_ALIGNMENT_RIGHT; break;
            case 2: halign = HORIZONTAL_ALIGNMENT_CENTER; break;
            default: halign = HORIZONTAL_ALIGNMENT_LEFT; break;
        }
    }

    // Dispatch to per-type WYSIWYG drawing
    if (item.type == "Button") {
        _draw_button_control(r, label, font, font_size);
    } else if (item.type == "Label") {
        _draw_label_control(r, label, font, font_size, halign);
    } else if (item.type == "LineEdit") {
        _draw_textbox_control(r, label, font, font_size, halign);
    } else if (item.type == "TextEdit") {
        _draw_textarea_control(r, label, font, font_size, halign);
    } else if (item.type == "RadioButton") {
        _draw_option_control(r, label, font, font_size);
    } else if (item.type == "CheckBox") {
        _draw_checkbox_control(r, label, font, font_size);
    } else if (item.type == "OptionButton") {
        _draw_combobox_control(r, label, font, font_size);
    } else if (item.type == "ItemList") {
        _draw_listbox_control(r, label, font, font_size);
    } else if (item.type == "Panel") {
        _draw_frame_control(r, label, font, font_size);
    } else if (item.type == "ProgressBar") {
        _draw_progressbar_control(r, font, font_size);
    } else if (item.type == "HScrollBar") {
        _draw_hscrollbar_control(r);
    } else if (item.type == "VScrollBar") {
        _draw_vscrollbar_control(r);
    } else if (item.type == "HSlider") {
        _draw_hslider_control(r);
    } else if (item.type == "VSlider") {
        _draw_vslider_control(r);
    } else if (item.type == "SpinBox") {
        _draw_spinbox_control(r, font, font_size);
    } else if (item.type == "Timer") {
        _draw_timer_control(r, item.name, font, font_size);
    } else if (item.type == "TextureRect") {
        _draw_picture_control(r, item.name, font, font_size);
    } else if (item.type == "Tree") {
        _draw_treeview_control(r, font, font_size);
    } else if (item.type == "RichTextLabel") {
        _draw_richtext_control(r, label, font, font_size);
    } else if (item.type == "TabContainer") {
        _draw_tabstrip_control(r, label, font, font_size);
    } else if (item.type == "ColorRect") {
        _draw_shape_control(r);
    } else if (item.type == "HSeparator") {
        // Horizontal separator: etched line across the center
        draw_rect(r, color_form_bg);
        float mid_y = r.position.y + r.size.y * 0.5f;
        draw_rect(Rect2(r.position.x, mid_y - 1, r.size.x, 1), sys_button_shadow);
        draw_rect(Rect2(r.position.x, mid_y, r.size.x, 1), sys_button_highlight);
    } else if (item.type == "VSeparator") {
        // Vertical separator: etched line down the center
        draw_rect(r, color_form_bg);
        float mid_x = r.position.x + r.size.x * 0.5f;
        draw_rect(Rect2(mid_x - 1, r.position.y, 1, r.size.y), sys_button_shadow);
        draw_rect(Rect2(mid_x, r.position.y, 1, r.size.y), sys_button_highlight);
    } else if (item.type == "ColorPickerButton") {
        // Color button: raised button with a color swatch
        _draw_raised_rect(r, sys_button_face);
        float pad = 4;
        if (r.size.x > pad * 2 + 6 && r.size.y > pad * 2 + 4) {
            Rect2 swatch(r.position + Vector2(pad, pad), Vector2(r.size.x - pad * 2, r.size.y - pad * 2));
            draw_rect(swatch, sys_glyph);
            draw_rect(Rect2(swatch.position + Vector2(1, 1), swatch.size - Vector2(2, 2)), Color(1, 0, 0));
        }
    } else if (item.type == "TextureButton") {
        // PictureButton: raised button with a small image icon in center
        _draw_raised_rect(r, sys_button_face);
        if (font.is_valid()) {
            // Draw a small landscape icon to indicate "image button"
            float cx = r.position.x + r.size.x * 0.5f;
            float cy = r.position.y + r.size.y * 0.5f;
            float iw = MIN(r.size.x * 0.5f, 20.0f);
            float ih = MIN(r.size.y * 0.5f, 14.0f);
            Rect2 img_r(cx - iw * 0.5f, cy - ih * 0.5f, iw, ih);
            draw_rect(img_r, Color(0.9, 0.9, 0.9));
            draw_rect(img_r, sys_button_shadow, false, 1.0);
        }
    } else if (item.type == "MenuBar") {
        // MenuBar: VB6-style flat gray bar with menu titles
        // The default prototype has File/Edit/View children
        draw_rect(r, sys_button_face);
        // Bottom border
        draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1), sys_button_shadow);
        if (font.is_valid()) {
            float tx = r.position.x + 6;
            float ty = r.position.y + (r.size.y + font_size) * 0.5f - 2;
            // Default menu titles from the prototype MenuBar.tscn
            const char *titles[] = { "File", "Edit", "View" };
            for (int m = 0; m < 3; m++) {
                String title = String(titles[m]);
                float tw = font->get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x;
                draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_text);
                tx += tw + 12.0f;
            }
        }
    } else if (item.type == "Line") {
        // Line control: solid black line across the control rect
        float mid_y = r.position.y + r.size.y * 0.5f;
        draw_rect(Rect2(r.position.x, mid_y - 1, r.size.x, 2), Color(0, 0, 0));
    } else if (item.type == "StatusBar") {
        // StatusBar: VB6-style status bar docked at bottom with 3 panels
        draw_rect(r, sys_button_face);
        // Top border (sunken look)
        draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), sys_button_shadow);
        draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, 1), sys_button_highlight);
        if (font.is_valid()) {
            float ty = r.position.y + (r.size.y + font_size) * 0.5f - 2;
            // Panel 1: "Ready" text
            float p1_w = r.size.x * 0.5f;
            Rect2 p1(r.position.x + 2, r.position.y + 3, p1_w - 4, r.size.y - 6);
            draw_rect(p1, sys_button_shadow, false, 1.0);
            draw_string(font, Vector2(r.position.x + 6, ty), "Ready",
                        HORIZONTAL_ALIGNMENT_LEFT, p1_w - 10, font_size, color_text);
            // Panel separator
            float sep_x = r.position.x + p1_w;
            Rect2 p2(sep_x + 2, r.position.y + 3, r.size.x - p1_w - 4, r.size.y - 6);
            draw_rect(p2, sys_button_shadow, false, 1.0);
        }
    } else if (item.type == "Toolbar") {
        // Toolbar: VB6-style toolbar with raised buttons
        draw_rect(r, sys_button_face);
        // Bottom border
        draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1), sys_button_shadow);
        // Draw a few button placeholders
        float bx = r.position.x + 4;
        float by = r.position.y + 2;
        float bsz = r.size.y - 4;
        for (int b = 0; b < 6 && bx + bsz < r.position.x + r.size.x; b++) {
            Rect2 btn(bx, by, bsz, bsz);
            _draw_raised_rect(btn, sys_button_face);
            bx += bsz + 2;
            // Add a separator after every 3 buttons
            if (b == 2) {
                float sx = bx + 1;
                draw_rect(Rect2(sx, by + 2, 1, bsz - 4), sys_button_shadow);
                draw_rect(Rect2(sx + 1, by + 2, 1, bsz - 4), sys_button_highlight);
                bx += 6;
            }
        }
    } else if (item.type == "ListView") {
        // ListView: multi-column list with column headers
        draw_rect(r, Color(1, 1, 1)); // White background
        // Sunken border
        draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), sys_button_shadow);
        draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), sys_button_shadow);
        draw_rect(Rect2(r.position.x + r.size.x - 1, r.position.y, 1, r.size.y), sys_button_highlight);
        draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1), sys_button_highlight);
        // Column headers
        float hdr_h = 20;
        Rect2 hdr(r.position.x + 1, r.position.y + 1, r.size.x - 2, hdr_h);
        _draw_raised_rect(hdr, sys_button_face);
        if (font.is_valid()) {
            float col_w = (r.size.x - 2) / 3.0f;
            for (int c = 0; c < 3; c++) {
                float cx = r.position.x + 1 + c * col_w;
                Rect2 ch(cx, r.position.y + 1, col_w, hdr_h);
                _draw_raised_rect(ch, sys_button_face);
                String col_label = "Column " + String::num_int64(c + 1);
                draw_string(font, Vector2(cx + 4, r.position.y + 1 + (hdr_h + font_size) * 0.5f - 2),
                            col_label, HORIZONTAL_ALIGNMENT_LEFT, col_w - 8, font_size - 1, color_text);
            }
        }
    } else if (item.type == "DriveListBox") {
        // DriveListBox: combo-style with "C:" text
        _draw_combobox_control(r, "C:\\", font, font_size);
    // ── Game UI Tier 1 controls (v4.0 animated WYSIWYG) ──
    } else if (item.type == "DialogPanel") {
        _draw_dialog_panel_control(r, item.name, font, font_size, anim_time);
    } else if (item.type == "InventoryGrid") {
        _draw_inventory_grid_control(r, item, font, font_size, anim_time);
    } else if (item.type == "StatBar") {
        _draw_stat_bar_control(r, item, font, font_size, anim_time);
    } else if (item.type == "HUDCounter") {
        _draw_hud_counter_control(r, item, font, font_size, anim_time);
    } else if (item.type == "CooldownButton") {
        _draw_cooldown_button_control(r, font, font_size, anim_time);
    } else if (item.type == "NotificationToast") {
        _draw_notification_toast_control(r, item.name, font, font_size, anim_time);
    } else if (item.type == "GameMenu") {
        _draw_game_menu_control(r, item, font, font_size, anim_time);
    } else if (item.type == "HBoxContainer" || item.type == "VBoxContainer" ||
               item.type == "GridContainer" || item.type == "SubViewportContainer") {
        // Container types: dashed outline with label
        draw_rect(r, Color(sys_button_face.r, sys_button_face.g, sys_button_face.b, 0.3));
        Color dash(design_outline.r, design_outline.g, design_outline.b, 0.6);
        float x1 = r.position.x, y1 = r.position.y;
        float x2 = x1 + r.size.x, y2 = y1 + r.size.y;
        for (float dx = x1; dx < x2; dx += 6.0f) {
            draw_rect(Rect2(dx, y1, 3, 1), dash);
            draw_rect(Rect2(dx, y2 - 1, 3, 1), dash);
        }
        for (float dy = y1; dy < y2; dy += 6.0f) {
            draw_rect(Rect2(x1, dy, 1, 3), dash);
            draw_rect(Rect2(x2 - 1, dy, 1, 3), dash);
        }
        if (font.is_valid()) {
            draw_string(font, r.position + Vector2(3, font_size + 2), label,
                        HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, font_size - 1, color_text);
        }
    } else {
        // Check for a preview texture (design-time rendering from SubViewport capture)
        if (control_preview_textures.has(item.type) && control_preview_textures[item.type].is_valid()) {
            Ref<Texture2D> tex = control_preview_textures[item.type];
            // Draw the preview texture scaled to fit the control rect
            draw_texture_rect(tex, r, false);
            // Draw a subtle border so the user knows it's a custom control
            draw_rect(r, Color(0.5, 0.6, 0.8, 0.4), false, 1.0);
        } else {
            // Fallback: generic raised control (like a button)
            _draw_raised_rect(r, sys_button_face);
            // Custom control types get a tinted banner with their name
            if (custom_control_types.has(item.type)) {
                Color tint = custom_control_types[item.type].design_color;
                draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 14), Color(tint.r, tint.g, tint.b, 0.3));
            }
            if (font.is_valid()) {
                float max_w = r.size.x - 6;
                if (max_w > 10) {
                    draw_string(font, r.position + Vector2(3, font_size + 2), label,
                                HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, color_text);
                }
            }
        }
    }

    // Selection border is drawn by the overlay_node (on top of live previews)
}

// =============================================================================
// WYSIWYG 3D border helpers (WinForms / VB6 classic style)
// Uses filled rects instead of single-pixel lines for visibility at all zoom levels
// =============================================================================

void VisualGasicFormDesigner::_draw_raised_rect(const Rect2 &r, const Color &face) {
    // Classic Windows 3D raised button look
    Color highlight = sys_button_highlight;
    Color shadow = sys_button_shadow;
    Color dark_shadow = sys_3d_dark_shadow;

    // Face fill
    draw_rect(r, face);

    float x = r.position.x, y = r.position.y;
    float w = r.size.x, h = r.size.y;

    // Top highlight band (2px)
    draw_rect(Rect2(x, y, w, 1), highlight);
    draw_rect(Rect2(x + 1, y + 1, w - 2, 1), sys_3d_light);
    // Left highlight band (2px)
    draw_rect(Rect2(x, y, 1, h), highlight);
    draw_rect(Rect2(x + 1, y + 1, 1, h - 2), sys_3d_light);
    // Bottom shadow band (2px)
    draw_rect(Rect2(x, y + h - 1, w, 1), dark_shadow);
    draw_rect(Rect2(x + 1, y + h - 2, w - 2, 1), shadow);
    // Right shadow band (2px)
    draw_rect(Rect2(x + w - 1, y, 1, h), dark_shadow);
    draw_rect(Rect2(x + w - 2, y + 1, 1, h - 2), shadow);
}

void VisualGasicFormDesigner::_draw_sunken_rect(const Rect2 &r, const Color &face) {
    // Classic Windows 3D sunken edit look
    Color highlight = sys_button_highlight;
    Color shadow = sys_button_shadow;
    Color dark_shadow = sys_3d_dark_shadow;

    // Face fill
    draw_rect(r, face);

    float x = r.position.x, y = r.position.y;
    float w = r.size.x, h = r.size.y;

    // Top shadow band (2px)
    draw_rect(Rect2(x, y, w, 1), shadow);
    draw_rect(Rect2(x + 1, y + 1, w - 2, 1), dark_shadow);
    // Left shadow band (2px)
    draw_rect(Rect2(x, y, 1, h), shadow);
    draw_rect(Rect2(x + 1, y + 1, 1, h - 2), dark_shadow);
    // Bottom highlight band (2px)
    draw_rect(Rect2(x, y + h - 1, w, 1), highlight);
    draw_rect(Rect2(x + 1, y + h - 2, w - 2, 1), sys_3d_light);
    // Right highlight band (2px)
    draw_rect(Rect2(x + w - 1, y, 1, h), highlight);
    draw_rect(Rect2(x + w - 2, y + 1, 1, h - 2), sys_3d_light);
}

void VisualGasicFormDesigner::_draw_etched_rect(const Rect2 &r) {
    Color shadow = sys_button_shadow;
    Color highlight = sys_button_highlight;
    float x = r.position.x, y = r.position.y;
    float w = r.size.x, h = r.size.y;

    // Shadow lines
    draw_rect(Rect2(x, y, w - 1, 1), shadow);
    draw_rect(Rect2(x, y, 1, h - 1), shadow);
    // Highlight lines (offset +1)
    draw_rect(Rect2(x + 1, y + 1, w - 1, 1), highlight);
    draw_rect(Rect2(x + 1, y + 1, 1, h - 1), highlight);
    // Bottom/right highlight
    draw_rect(Rect2(x + 1, y + h - 1, w - 1, 1), highlight);
    draw_rect(Rect2(x + w - 1, y + 1, 1, h - 1), highlight);
    // Bottom/right inner shadow
    draw_rect(Rect2(x, y + h - 2, w - 1, 1), shadow);
    draw_rect(Rect2(x + w - 2, y, 1, h - 1), shadow);
}

// =============================================================================
// WYSIWYG per-type control drawing
// =============================================================================

void VisualGasicFormDesigner::_draw_button_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    Color face = sys_button_face;
    _draw_raised_rect(r, face);

    if (font.is_valid() && r.size.x > 8 && r.size.y > 8) {
        float tw = font->get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x;
        float x_off = MAX((r.size.x - tw) * 0.5f, 3.0f);
        float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
        draw_string(font, r.position + Vector2(x_off, y_off), text,
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, font_size, color_text);
    }
}

void VisualGasicFormDesigner::_draw_label_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign) {
    // Label: transparent bg, just text, thin dashed outline at design time
    if (font.is_valid() && r.size.x > 4) {
        float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
        draw_string(font, r.position + Vector2(1, y_off), text,
                    halign, r.size.x - 2, font_size, color_text);
    }
    // Design-time dashed boundary (draw small dots along the edges)
    Color dot_c = design_outline;
    float x1 = r.position.x, y1 = r.position.y;
    float x2 = x1 + r.size.x, y2 = y1 + r.size.y;
    for (float dx = x1; dx < x2; dx += 4.0f) {
        draw_rect(Rect2(dx, y1, 2, 1), dot_c);
        draw_rect(Rect2(dx, y2 - 1, 2, 1), dot_c);
    }
    for (float dy = y1; dy < y2; dy += 4.0f) {
        draw_rect(Rect2(x1, dy, 1, 2), dot_c);
        draw_rect(Rect2(x2 - 1, dy, 1, 2), dot_c);
    }
}

void VisualGasicFormDesigner::_draw_textbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign) {
    _draw_sunken_rect(r, sys_window);
    if (font.is_valid() && r.size.x > 8) {
        float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
        draw_string(font, r.position + Vector2(4, y_off), text,
                    halign, r.size.x - 8, font_size, color_text);
    }
}

void VisualGasicFormDesigner::_draw_textarea_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size, HorizontalAlignment halign) {
    float sb_w = 16.0f;
    // Main text area
    Rect2 text_area(r.position, Vector2(r.size.x - sb_w, r.size.y));
    _draw_sunken_rect(text_area, sys_window);

    if (font.is_valid() && text_area.size.x > 8) {
        draw_string(font, r.position + Vector2(4, font_size + 3), text,
                    halign, text_area.size.x - 8, font_size, color_text);
    }

    // Scrollbar column
    Color face = sys_button_face;
    Rect2 sb(r.position + Vector2(r.size.x - sb_w, 0), Vector2(sb_w, r.size.y));
    _draw_raised_rect(sb, face);

    // Up arrow button
    Rect2 up_btn(sb.position, Vector2(sb_w, sb_w));
    _draw_raised_rect(up_btn, face);
    // Down arrow button
    Rect2 dn_btn(sb.position + Vector2(0, sb.size.y - sb_w), Vector2(sb_w, sb_w));
    _draw_raised_rect(dn_btn, face);

    // Arrow glyphs (filled triangles via small rects)
    float cx = sb.position.x + sb_w * 0.5f;
    // Up arrow
    float uy = up_btn.position.y + sb_w * 0.35f;
    draw_rect(Rect2(cx - 0.5f, uy, 1, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, uy + 1, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 2.5f, uy + 2, 5, 1), sys_glyph);
    draw_rect(Rect2(cx - 3.5f, uy + 3, 7, 1), sys_glyph);
    // Down arrow
    float dy = dn_btn.position.y + sb_w * 0.4f;
    draw_rect(Rect2(cx - 3.5f, dy, 7, 1), sys_glyph);
    draw_rect(Rect2(cx - 2.5f, dy + 1, 5, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, dy + 2, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 0.5f, dy + 3, 1, 1), sys_glyph);
}

void VisualGasicFormDesigner::_draw_checkbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    // Solid form-colored background so checkbox square stands out
    draw_rect(r, color_form_bg);

    // Checkbox indicator: 13x13 sunken white square
    float box_size = 13.0f;
    float box_x = r.position.x + 3;
    float box_y = r.position.y + (r.size.y - box_size) * 0.5f;
    Rect2 box(Vector2(box_x, box_y), Vector2(box_size, box_size));
    _draw_sunken_rect(box, sys_window);

    // Text to the right
    if (font.is_valid()) {
        float text_x = box_x + box_size + 4;
        float avail_w = r.size.x - box_size - 9;
        if (avail_w > 4) {
            float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
            draw_string(font, Vector2(text_x, r.position.y + y_off), text,
                        HORIZONTAL_ALIGNMENT_LEFT, avail_w, font_size, color_text);
        }
    }

    // Design-time outline
    draw_rect(r, Color(design_outline.r, design_outline.g, design_outline.b, 0.2), false, 1.0);
}

void VisualGasicFormDesigner::_draw_option_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    // Radio button: form-colored bg + circle indicator + text
    draw_rect(r, color_form_bg);

    float circle_d = 12.0f;
    float cx = r.position.x + 3 + circle_d * 0.5f;
    float cy = r.position.y + r.size.y * 0.5f;
    float cr = circle_d * 0.5f;

    // Draw outer circle border using small filled segments
    // Shadow arc (top-left)
    int segs = 32;
    for (int i = 0; i < segs; i++) {
        float a1 = (float)i / segs * Math_TAU;
        float a2 = (float)(i + 1) / segs * Math_TAU;
        Vector2 p1(cx + Math::cos(a1) * cr, cy + Math::sin(a1) * cr);
        Vector2 p2(cx + Math::cos(a2) * cr, cy + Math::sin(a2) * cr);
        bool top_left = (a1 >= Math_PI * 0.75f && a1 <= Math_PI * 1.75f);
        Color c = top_left ? sys_button_shadow : sys_button_highlight;
        draw_line(p1, p2, c, 1.5);
    }
    // White fill inside
    for (int i = 0; i < segs; i++) {
        float a1 = (float)i / segs * Math_TAU;
        float a2 = (float)(i + 1) / segs * Math_TAU;
        Vector2 p1(cx + Math::cos(a1) * (cr - 2), cy + Math::sin(a1) * (cr - 2));
        Vector2 p2(cx + Math::cos(a2) * (cr - 2), cy + Math::sin(a2) * (cr - 2));
        draw_line(p1, p2, sys_window, 3.0);
    }
    // Center white fill
    draw_rect(Rect2(cx - 2, cy - 2, 4, 4), sys_window);

    // Text
    if (font.is_valid()) {
        float text_x = r.position.x + circle_d + 7;
        float avail_w = r.size.x - circle_d - 10;
        if (avail_w > 4) {
            float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
            draw_string(font, Vector2(text_x, r.position.y + y_off), text,
                        HORIZONTAL_ALIGNMENT_LEFT, avail_w, font_size, color_text);
        }
    }

    draw_rect(r, Color(design_outline.r, design_outline.g, design_outline.b, 0.2), false, 1.0);
}

void VisualGasicFormDesigner::_draw_combobox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    // ComboBox: sunken white text field + raised dropdown button with arrow
    float btn_w = 17.0f;
    if (btn_w > r.size.x * 0.4f) btn_w = r.size.x * 0.4f;

    // Text field area
    Rect2 text_area(r.position, Vector2(r.size.x - btn_w, r.size.y));
    _draw_sunken_rect(text_area, sys_window);

    // Dropdown button
    Rect2 btn(r.position + Vector2(r.size.x - btn_w, 0), Vector2(btn_w, r.size.y));
    _draw_raised_rect(btn, sys_button_face);

    // Down arrow glyph (filled triangle using horizontal rect scanlines)
    float acx = btn.position.x + btn_w * 0.5f;
    float acy = btn.position.y + r.size.y * 0.5f - 2;
    draw_rect(Rect2(acx - 4, acy, 9, 1), sys_glyph);
    draw_rect(Rect2(acx - 3, acy + 1, 7, 1), sys_glyph);
    draw_rect(Rect2(acx - 2, acy + 2, 5, 1), sys_glyph);
    draw_rect(Rect2(acx - 1, acy + 3, 3, 1), sys_glyph);
    draw_rect(Rect2(acx, acy + 4, 1, 1), sys_glyph);

    // Text in text area
    if (font.is_valid() && text_area.size.x > 8) {
        float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
        draw_string(font, r.position + Vector2(4, y_off), text,
                    HORIZONTAL_ALIGNMENT_LEFT, text_area.size.x - 8, font_size, color_text);
    }
}

void VisualGasicFormDesigner::_draw_listbox_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    float sb_w = 16.0f;
    // Main list area
    Rect2 list_area(r.position, Vector2(r.size.x - sb_w, r.size.y));
    _draw_sunken_rect(list_area, sys_window);

    // Placeholder list items
    if (font.is_valid()) {
        float line_h = font_size + 4;
        float y = r.position.y + 3;
        int max_lines = MIN((int)((r.size.y - 4) / line_h), 6);
        for (int i = 0; i < max_lines && y + font_size < r.position.y + r.size.y - 2; i++) {
            if (i == 0 && !text.is_empty()) {
                draw_string(font, Vector2(r.position.x + 4, y + font_size), text,
                            HORIZONTAL_ALIGNMENT_LEFT, list_area.size.x - 8, font_size, color_text);
            }
            y += line_h;
        }
    }

    // Scrollbar
    Color face = sys_button_face;
    Rect2 sb(r.position + Vector2(r.size.x - sb_w, 0), Vector2(sb_w, r.size.y));
    _draw_raised_rect(sb, face);
    // Up button
    Rect2 up_btn(sb.position, Vector2(sb_w, sb_w));
    _draw_raised_rect(up_btn, face);
    // Down button
    Rect2 dn_btn(sb.position + Vector2(0, sb.size.y - sb_w), Vector2(sb_w, sb_w));
    _draw_raised_rect(dn_btn, face);
    // Arrow glyphs
    float acx = sb.position.x + sb_w * 0.5f;
    float uy = up_btn.position.y + sb_w * 0.35f;
    draw_rect(Rect2(acx - 0.5f, uy, 1, 1), sys_glyph);
    draw_rect(Rect2(acx - 1.5f, uy + 1, 3, 1), sys_glyph);
    draw_rect(Rect2(acx - 2.5f, uy + 2, 5, 1), sys_glyph);
    draw_rect(Rect2(acx - 3.5f, uy + 3, 7, 1), sys_glyph);
    float dny = dn_btn.position.y + sb_w * 0.4f;
    draw_rect(Rect2(acx - 3.5f, dny, 7, 1), sys_glyph);
    draw_rect(Rect2(acx - 2.5f, dny + 1, 5, 1), sys_glyph);
    draw_rect(Rect2(acx - 1.5f, dny + 2, 3, 1), sys_glyph);
    draw_rect(Rect2(acx - 0.5f, dny + 3, 1, 1), sys_glyph);
}

void VisualGasicFormDesigner::_draw_frame_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    // GroupBox/Frame: form-colored fill with etched border and label gap
    draw_rect(r, color_form_bg);

    float label_y = r.position.y + (font.is_valid() ? font_size * 0.5f : 8);
    float gap_x1 = r.position.x + 10;
    float gap_x2 = gap_x1;

    if (font.is_valid() && !text.is_empty()) {
        float tw = font->get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x;
        gap_x2 = gap_x1 + tw + 4;
    }

    Color shadow = sys_button_shadow;
    Color highlight = sys_button_highlight;
    float x1 = r.position.x, x2 = r.position.x + r.size.x - 1;
    float y2 = r.position.y + r.size.y - 1;

    // Top etched line (with gap for label)
    draw_rect(Rect2(x1, label_y, gap_x1 - x1, 1), shadow);
    draw_rect(Rect2(gap_x2, label_y, x2 - gap_x2, 1), shadow);
    draw_rect(Rect2(x1 + 1, label_y + 1, gap_x1 - x1 - 1, 1), highlight);
    draw_rect(Rect2(gap_x2, label_y + 1, x2 - gap_x2, 1), highlight);
    // Left
    draw_rect(Rect2(x1, label_y, 1, y2 - label_y), shadow);
    draw_rect(Rect2(x1 + 1, label_y + 1, 1, y2 - label_y - 2), highlight);
    // Bottom
    draw_rect(Rect2(x1, y2, r.size.x, 1), highlight);
    draw_rect(Rect2(x1 + 1, y2 - 1, r.size.x - 2, 1), shadow);
    // Right
    draw_rect(Rect2(x2, label_y, 1, y2 - label_y + 1), highlight);
    draw_rect(Rect2(x2 - 1, label_y + 1, 1, y2 - label_y - 1), shadow);

    // Label text
    if (font.is_valid() && !text.is_empty()) {
        draw_string(font, Vector2(gap_x1 + 2, label_y + font_size * 0.35f), text,
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, font_size, color_text);
    }
}

void VisualGasicFormDesigner::_draw_progressbar_control(const Rect2 &r, const Ref<Font> &font, int font_size) {
    _draw_sunken_rect(r, sys_window);

    // Green progress blocks (30% fill)
    float pad = 3;
    float inner_h = r.size.y - pad * 2;
    float fill_w = (r.size.x - pad * 2) * 0.3f;
    float block_w = 8.0f, gap = 2.0f;
    Color block_c = sys_progress_fill;
    for (float bx = r.position.x + pad; bx < r.position.x + pad + fill_w; bx += block_w + gap) {
        float w = MIN(block_w, r.position.x + pad + fill_w - bx);
        if (w > 0) draw_rect(Rect2(bx, r.position.y + pad, w, inner_h), block_c);
    }
}

void VisualGasicFormDesigner::_draw_hscrollbar_control(const Rect2 &r) {
    Color face = sys_button_face;
    float btn_w = MIN(r.size.y, 17.0f);

    // Track
    _draw_sunken_rect(r, sys_scrollbar);
    // Left button
    _draw_raised_rect(Rect2(r.position, Vector2(btn_w, r.size.y)), face);
    // Right button
    _draw_raised_rect(Rect2(r.position + Vector2(r.size.x - btn_w, 0), Vector2(btn_w, r.size.y)), face);

    // Left arrow glyph
    float cy = r.position.y + r.size.y * 0.5f;
    float lx = r.position.x + btn_w * 0.5f + 1;
    draw_rect(Rect2(lx - 1, cy - 0.5f, 1, 1), sys_glyph);
    draw_rect(Rect2(lx, cy - 1.5f, 1, 3), sys_glyph);
    draw_rect(Rect2(lx + 1, cy - 2.5f, 1, 5), sys_glyph);
    draw_rect(Rect2(lx + 2, cy - 3.5f, 1, 7), sys_glyph);
    // Right arrow glyph
    float rx = r.position.x + r.size.x - btn_w * 0.5f - 2;
    draw_rect(Rect2(rx + 1, cy - 0.5f, 1, 1), sys_glyph);
    draw_rect(Rect2(rx, cy - 1.5f, 1, 3), sys_glyph);
    draw_rect(Rect2(rx - 1, cy - 2.5f, 1, 5), sys_glyph);
    draw_rect(Rect2(rx - 2, cy - 3.5f, 1, 7), sys_glyph);

    // Thumb
    float thumb_w = MAX((r.size.x - btn_w * 2) * 0.3f, 12.0f);
    float thumb_x = r.position.x + btn_w + (r.size.x - btn_w * 2 - thumb_w) * 0.5f;
    _draw_raised_rect(Rect2(thumb_x, r.position.y, thumb_w, r.size.y), face);
}

void VisualGasicFormDesigner::_draw_vscrollbar_control(const Rect2 &r) {
    Color face = sys_button_face;
    float btn_h = MIN(r.size.x, 17.0f);

    _draw_sunken_rect(r, sys_scrollbar);
    _draw_raised_rect(Rect2(r.position, Vector2(r.size.x, btn_h)), face);
    _draw_raised_rect(Rect2(r.position + Vector2(0, r.size.y - btn_h), Vector2(r.size.x, btn_h)), face);

    // Up arrow glyph
    float cx = r.position.x + r.size.x * 0.5f;
    float uy = r.position.y + btn_h * 0.5f - 1;
    draw_rect(Rect2(cx - 0.5f, uy - 1, 1, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, uy, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 2.5f, uy + 1, 5, 1), sys_glyph);
    draw_rect(Rect2(cx - 3.5f, uy + 2, 7, 1), sys_glyph);
    // Down arrow glyph
    float dny = r.position.y + r.size.y - btn_h * 0.5f - 2;
    draw_rect(Rect2(cx - 3.5f, dny, 7, 1), sys_glyph);
    draw_rect(Rect2(cx - 2.5f, dny + 1, 5, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, dny + 2, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 0.5f, dny + 3, 1, 1), sys_glyph);

    // Thumb
    float thumb_h = MAX((r.size.y - btn_h * 2) * 0.3f, 12.0f);
    float thumb_y = r.position.y + btn_h + (r.size.y - btn_h * 2 - thumb_h) * 0.5f;
    _draw_raised_rect(Rect2(r.position.x, thumb_y, r.size.x, thumb_h), face);
}

void VisualGasicFormDesigner::_draw_hslider_control(const Rect2 &r) {
    Color face = sys_button_face;
    draw_rect(r, color_form_bg);

    // Sunken channel groove
    float ch_h = 4.0f;
    float ch_y = r.position.y + (r.size.y - ch_h) * 0.5f;
    _draw_sunken_rect(Rect2(r.position.x + 6, ch_y, r.size.x - 12, ch_h), sys_window);

    // Tick marks
    for (float tx = r.position.x + 6; tx <= r.position.x + r.size.x - 6; tx += 10) {
        draw_rect(Rect2(tx, ch_y + ch_h + 3, 1, 4), sys_glyph);
    }

    // Thumb
    float tw = 11.0f, th = r.size.y - 8;
    _draw_raised_rect(Rect2(r.position.x + (r.size.x - tw) * 0.5f, r.position.y + 3, tw, th), face);
}

void VisualGasicFormDesigner::_draw_vslider_control(const Rect2 &r) {
    Color face = sys_button_face;
    draw_rect(r, color_form_bg);

    float ch_w = 4.0f;
    float ch_x = r.position.x + (r.size.x - ch_w) * 0.5f;
    _draw_sunken_rect(Rect2(ch_x, r.position.y + 6, ch_w, r.size.y - 12), sys_window);

    for (float ty = r.position.y + 6; ty <= r.position.y + r.size.y - 6; ty += 10) {
        draw_rect(Rect2(ch_x + ch_w + 3, ty, 4, 1), sys_glyph);
    }

    float tw = r.size.x - 8, th = 11.0f;
    _draw_raised_rect(Rect2(r.position.x + 3, r.position.y + (r.size.y - th) * 0.5f, tw, th), face);
}

void VisualGasicFormDesigner::_draw_spinbox_control(const Rect2 &r, const Ref<Font> &font, int font_size) {
    float btn_w = 16.0f;
    Rect2 text_area(r.position, Vector2(r.size.x - btn_w, r.size.y));
    _draw_sunken_rect(text_area, sys_window);

    if (font.is_valid()) {
        float y_off = (r.size.y + font_size * 0.7f) * 0.5f;
        draw_string(font, r.position + Vector2(4, y_off), "0",
                    HORIZONTAL_ALIGNMENT_LEFT, text_area.size.x - 8, font_size, color_text);
    }

    Color face = sys_button_face;
    float half_h = r.size.y * 0.5f;
    // Up spin button
    Rect2 up_btn(r.position + Vector2(r.size.x - btn_w, 0), Vector2(btn_w, half_h));
    _draw_raised_rect(up_btn, face);
    float cx = up_btn.position.x + btn_w * 0.5f;
    float uy = up_btn.position.y + half_h * 0.35f;
    draw_rect(Rect2(cx - 0.5f, uy, 1, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, uy + 1, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 2.5f, uy + 2, 5, 1), sys_glyph);

    // Down spin button
    Rect2 dn_btn(r.position + Vector2(r.size.x - btn_w, half_h), Vector2(btn_w, r.size.y - half_h));
    _draw_raised_rect(dn_btn, face);
    float dy = dn_btn.position.y + (r.size.y - half_h) * 0.35f;
    draw_rect(Rect2(cx - 2.5f, dy, 5, 1), sys_glyph);
    draw_rect(Rect2(cx - 1.5f, dy + 1, 3, 1), sys_glyph);
    draw_rect(Rect2(cx - 0.5f, dy + 2, 1, 1), sys_glyph);
}

void VisualGasicFormDesigner::_draw_timer_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size) {
    // Non-visual component: warm bg with clock icon
    draw_rect(r, nonvisual_bg);
    draw_rect(r, nonvisual_border, false, 1.0);

    float cx = r.position.x + r.size.x * 0.5f;
    float cy = r.position.y + r.size.y * 0.5f - 2;
    float cr = MIN(r.size.x, r.size.y) * 0.3f;

    int segs = 24;
    for (int i = 0; i < segs; i++) {
        float a1 = (float)i / segs * Math_TAU;
        float a2 = (float)(i + 1) / segs * Math_TAU;
        draw_line(Vector2(cx + Math::cos(a1) * cr, cy + Math::sin(a1) * cr),
                  Vector2(cx + Math::cos(a2) * cr, cy + Math::sin(a2) * cr),
                  sys_glyph, 2.0);
    }
    draw_line(Vector2(cx, cy), Vector2(cx, cy - cr * 0.7f), sys_glyph, 2.0);
    draw_line(Vector2(cx, cy), Vector2(cx + cr * 0.5f, cy), sys_glyph, 1.5);

    if (font.is_valid()) {
        draw_string(font, Vector2(r.position.x + 2, r.position.y + r.size.y - 2), name,
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 9, color_text);
    }
}

void VisualGasicFormDesigner::_draw_picture_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size) {
    _draw_sunken_rect(r, sys_window);

    // Cross lines (image placeholder)
    Color cross = placeholder_color;
    draw_line(r.position + Vector2(3, 3), r.position + r.size - Vector2(3, 3), cross, 1.0);
    draw_line(Vector2(r.position.x + r.size.x - 3, r.position.y + 3),
              Vector2(r.position.x + 3, r.position.y + r.size.y - 3), cross, 1.0);

    // Simple mountain + sun icon
    float mx = r.position.x + r.size.x * 0.5f;
    float my = r.position.y + r.size.y * 0.5f;
    Color ic = placeholder_color;
    // Mountain
    draw_line(Vector2(mx - 10, my + 8), Vector2(mx, my - 2), ic, 1.5);
    draw_line(Vector2(mx, my - 2), Vector2(mx + 10, my + 8), ic, 1.5);
    draw_line(Vector2(mx - 10, my + 8), Vector2(mx + 10, my + 8), ic, 1.5);
    // Sun
    int ss = 12;
    float sr = 4, sx = mx - 6, sy = my - 5;
    for (int i = 0; i < ss; i++) {
        float a1 = (float)i / ss * Math_TAU;
        float a2 = (float)(i + 1) / ss * Math_TAU;
        draw_line(Vector2(sx + Math::cos(a1) * sr, sy + Math::sin(a1) * sr),
                  Vector2(sx + Math::cos(a2) * sr, sy + Math::sin(a2) * sr), ic, 1.5);
    }
}

void VisualGasicFormDesigner::_draw_treeview_control(const Rect2 &r, const Ref<Font> &font, int font_size) {
    _draw_sunken_rect(r, sys_window);
    if (!font.is_valid()) return;

    float lh = font_size + 4;
    float bx = r.position.x + 6, by = r.position.y + 4;
    Color lc = placeholder_color;

    // Root expand box [+]
    if (by + font_size < r.position.y + r.size.y) {
        Rect2 box(bx, by + 2, 9, 9);
        draw_rect(box, sys_window);
        draw_rect(box, lc, false, 1.0);
        // Plus sign
        draw_rect(Rect2(bx + 2, by + 6, 5, 1), sys_glyph);
        draw_rect(Rect2(bx + 4, by + 4, 1, 5), sys_glyph);
        // Connector
        draw_rect(Rect2(bx + 9, by + 6, 7, 1), lc);
        draw_string(font, Vector2(bx + 18, by + font_size), "Node",
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, font_size - 2, color_text);
    }

    // Children
    float cx2 = bx + 16;
    for (int i = 1; i <= 2 && (by + lh * i + font_size) < r.position.y + r.size.y - 2; i++) {
        float ny = by + lh * i;
        draw_rect(Rect2(bx + 4, by + 11, 1, ny + 6 - by - 11), lc);
        draw_rect(Rect2(bx + 4, ny + 6, cx2 - bx - 4, 1), lc);
        draw_string(font, Vector2(cx2 + 4, ny + font_size), (i == 1) ? "Child1" : "Child2",
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, font_size - 2, color_text);
    }
}

void VisualGasicFormDesigner::_draw_richtext_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    _draw_sunken_rect(r, sys_window);
    if (font.is_valid() && r.size.x > 8) {
        String display = text.is_empty() ? "RichText" : text;
        draw_string(font, r.position + Vector2(4, font_size + 3), display,
                    HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, font_size, color_text);
        if (r.size.y > font_size * 2 + 10) {
            draw_string(font, r.position + Vector2(4, font_size * 2 + 6), "formatted text...",
                        HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, font_size - 1, placeholder_color);
        }
    }
}

void VisualGasicFormDesigner::_draw_tabstrip_control(const Rect2 &r, const String &text, const Ref<Font> &font, int font_size) {
    Color face = sys_button_face;
    float tab_h = 22.0f;

    // Body below tabs
    Rect2 body(r.position + Vector2(0, tab_h), Vector2(r.size.x, r.size.y - tab_h));
    _draw_raised_rect(body, face);

    // Active tab
    String tab_text = text.is_empty() ? "Tab1" : text;
    float tab_w = 60;
    if (font.is_valid()) {
        tab_w = font->get_string_size(tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1).x + 16;
    }
    if (tab_w > r.size.x - 4) tab_w = r.size.x - 4;
    float tab_x = r.position.x + 2;

    Rect2 active_tab(tab_x, r.position.y, tab_w, tab_h + 1);
    draw_rect(active_tab, face);
    // Tab borders
    draw_rect(Rect2(tab_x, r.position.y, tab_w, 1), Color(1, 1, 1));
    draw_rect(Rect2(tab_x, r.position.y, 1, tab_h), Color(1, 1, 1));
    draw_rect(Rect2(tab_x + tab_w - 1, r.position.y, 1, tab_h), Color(0.51, 0.51, 0.51));

    if (font.is_valid()) {
        float tw = font->get_string_size(tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1).x;
        draw_string(font, Vector2(tab_x + (tab_w - tw) * 0.5f, r.position.y + font_size + 3), tab_text,
                    HORIZONTAL_ALIGNMENT_LEFT, tab_w - 4, font_size - 1, color_text);
    }

    // Inactive tab hint
    if (r.size.x > tab_w + 50) {
        Rect2 itab(tab_x + tab_w + 1, r.position.y + 2, 50, tab_h - 2);
        draw_rect(itab, Color(0.78, 0.78, 0.78));
        draw_rect(itab, Color(0.6, 0.6, 0.6), false, 1.0);
        if (font.is_valid()) {
            draw_string(font, Vector2(itab.position.x + 8, r.position.y + font_size + 3), "Tab2",
                        HORIZONTAL_ALIGNMENT_LEFT, 40, font_size - 1, Color(0.3, 0.3, 0.3));
        }
    }
}

void VisualGasicFormDesigner::_draw_shape_control(const Rect2 &r) {
    draw_rect(r, Color(0.5, 0.5, 0.5));
    draw_rect(r, Color(0.0, 0.0, 0.0), false, 2.0);
}

// =============================================================================
// Game UI Tier 1 — WYSIWYG control drawing (v4.0)
// These render pixel-accurate visual representations matching the runtime
// prototype appearance.  Each method mirrors the node tree, colors, font
// sizes, margins, and StyleBox settings from the corresponding .gd prototype
// so that WYSIWYG holds true at design time.
// =============================================================================

void VisualGasicFormDesigner::_draw_dialog_panel_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size, float t) {
    // Animated: typewriter text reveal (runtime: visible_ratio tween at 0.03s/char)
    // plus blinking cursor at the reveal edge
    Color bg(0.12, 0.15, 0.22, 0.92);
    draw_rect(r, bg);

    // Double-border for PanelContainer depth
    draw_rect(r, Color(0.22, 0.28, 0.42, 0.8), false, 2.0);
    Rect2 inner_b(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2);
    draw_rect(inner_b, Color(0.35, 0.45, 0.65, 0.4), false, 1.0);

    if (!font.is_valid()) return;
    float mh = 12.0f, mv = 8.0f;
    float x = r.position.x + mh;
    float y = r.position.y + mv;
    float w = r.size.x - mh * 2;

    // Portrait placeholder (48×48)
    float portrait_sz = MIN(48.0f, r.size.y - mv * 2 - 20.0f);
    if (portrait_sz > 16 && w > portrait_sz + 60) {
        Rect2 portrait(x, y, portrait_sz, portrait_sz);
        draw_rect(portrait, Color(0.18, 0.20, 0.28));
        draw_rect(Rect2(x, y, portrait_sz, 1), Color(0.10, 0.12, 0.18));
        draw_rect(Rect2(x, y, 1, portrait_sz), Color(0.10, 0.12, 0.18));
        draw_rect(Rect2(x, y + portrait_sz - 1, portrait_sz, 1), Color(0.30, 0.35, 0.42, 0.5));
        draw_rect(Rect2(x + portrait_sz - 1, y, 1, portrait_sz), Color(0.30, 0.35, 0.42, 0.5));
        // Person silhouette
        float pcx = x + portrait_sz * 0.5f;
        float pcy = y + portrait_sz * 0.32f;
        float hr = portrait_sz * 0.14f;
        draw_rect(Rect2(pcx - hr, pcy - hr, hr * 2, hr * 2), Color(0.35, 0.38, 0.48));
        float bw_s = hr * 3.0f, bh_s = portrait_sz * 0.28f;
        draw_rect(Rect2(pcx - bw_s * 0.5f, pcy + hr + 3, bw_s, bh_s), Color(0.35, 0.38, 0.48));
        draw_rect(portrait, Color(0.40, 0.45, 0.58, 0.6), false, 1.0);

        // Speaker name with a subtle fade-in (first 0.3s of each 6s cycle)
        int name_fs = MIN(16, font_size + 2);
        float nx = x + portrait_sz + 8;
        float cycle = fmod(t, 6.0f);
        float name_alpha = CLAMP(cycle / 0.3f, 0.0f, 1.0f);
        draw_string(font, Vector2(nx, y + name_fs), "Speaker Name",
                    HORIZONTAL_ALIGNMENT_LEFT, w - portrait_sz - 16, name_fs,
                    Color(0.88, 0.88, 0.98, name_alpha));

        // Separator
        float sep_y = y + portrait_sz + 4;
        if (sep_y < r.position.y + r.size.y - mv - 16) {
            draw_rect(Rect2(x, sep_y, w, 1), Color(0.30, 0.35, 0.50, 0.4));
            float ty = sep_y + 6;
            if (ty + font_size < r.position.y + r.size.y - mv) {
                // ── Typewriter animation ──
                // Full text cycles: 0.03s/char reveal, 1.5s hold, then restarts
                String full_text = "Dialog text goes here...";
                int total_chars = full_text.length();
                float char_rate = 0.03f;                      // match runtime
                float reveal_dur = total_chars * char_rate;
                float hold_dur = 1.5f;
                float type_cycle = fmod(cycle, reveal_dur + hold_dur);
                int visible_chars = (type_cycle < reveal_dur)
                    ? CLAMP(int(type_cycle / char_rate), 0, total_chars)
                    : total_chars;

                String visible_str = full_text.substr(0, visible_chars);
                int body_fs = font_size - 1;
                draw_string(font, Vector2(x, ty + body_fs - 2), visible_str,
                            HORIZONTAL_ALIGNMENT_LEFT, w, body_fs,
                            Color(0.72, 0.74, 0.82, 0.85));

                // Blinking cursor at reveal edge (0.5s period)
                if (visible_chars < total_chars) {
                    float cw_t = font->get_string_size(visible_str,
                                     HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs).x;
                    float cursor_x = x + cw_t + 2;
                    float blink = fmod(t, 0.5f) < 0.25f ? 0.85f : 0.15f;
                    if (cursor_x < r.position.x + r.size.x - mh) {
                        draw_rect(Rect2(cursor_x, ty, 2, body_fs),
                                  Color(0.80, 0.80, 0.90, blink));
                    }
                }
            }
        }
    } else {
        draw_string(font, Vector2(x, y + font_size), name,
                    HORIZONTAL_ALIGNMENT_LEFT, w, font_size,
                    Color(0.88, 0.88, 0.98));
    }
}

void VisualGasicFormDesigner::_draw_inventory_grid_control(const Rect2 &r, const FormControlItem &item, const Ref<Font> &font, int font_size, float t) {
    // Animated: subtle breathing glow cycles through slot borders
    Color bg(0.14, 0.14, 0.18, 0.92);
    draw_rect(r, bg);

    // PanelContainer outer border — subtle 3D
    draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1),
              Color(0.25, 0.25, 0.32, 0.6));
    draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y),
              Color(0.25, 0.25, 0.32, 0.6));
    draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1),
              Color(0.08, 0.08, 0.10, 0.8));
    draw_rect(Rect2(r.position.x + r.size.x - 1, r.position.y, 1, r.size.y),
              Color(0.08, 0.08, 0.10, 0.8));

    int rows = 4, cols = 4, slot_sz = 48, spacing = 4;
    if (item.properties.has("Rows"))        rows    = MAX(int(item.properties["Rows"]), 1);
    if (item.properties.has("Columns"))     cols    = MAX(int(item.properties["Columns"]), 1);
    if (item.properties.has("SlotSize"))    slot_sz = MAX(int(item.properties["SlotSize"]), 16);
    if (item.properties.has("SlotSpacing")) spacing = MAX(int(item.properties["SlotSpacing"]), 0);

    float pad = 8.0f;
    float avail_w = r.size.x - pad * 2;
    float avail_h = r.size.y - pad * 2;

    float needed_w = cols * slot_sz + (cols - 1) * spacing;
    float needed_h = rows * slot_sz + (rows - 1) * spacing;
    float scale_f = 1.0f;
    if (needed_w > avail_w) scale_f = MIN(scale_f, avail_w / needed_w);
    if (needed_h > avail_h) scale_f = MIN(scale_f, avail_h / needed_h);
    float ssz = slot_sz * scale_f;
    float ssp = spacing * scale_f;

    float grid_w = cols * ssz + (cols - 1) * ssp;
    float grid_h = rows * ssz + (rows - 1) * ssp;
    float ox = r.position.x + pad + (avail_w - grid_w) * 0.5f;
    float oy = r.position.y + pad + (avail_h - grid_h) * 0.5f;

    // Exact runtime StyleBoxFlat colors
    Color slot_bg(0.20, 0.20, 0.25, 0.80);
    Color slot_border(0.40, 0.40, 0.45, 0.60);
    Color slot_hi(0.28, 0.28, 0.33, 0.55);
    Color slot_sh(0.12, 0.12, 0.16, 0.65);

    // ── Breathing glow: a highlight wave sweeps across the grid ──
    // Wave period = 3s, highlight covers ~2 slots wide
    float wave_period = 3.0f;
    float wave_pos = fmod(t, wave_period) / wave_period; // 0..1 progress
    float total_slots = (float)(rows * cols);

    for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
            float sx = ox + col * (ssz + ssp);
            float sy = oy + row * (ssz + ssp);
            Rect2 slot(sx, sy, ssz, ssz);

            draw_rect(slot, slot_bg);

            // Inner bevel
            draw_rect(Rect2(sx + 2, sy,     ssz - 4, 1), slot_hi);
            draw_rect(Rect2(sx + 1, sy + 1, ssz - 2, 1), Color(slot_hi.r, slot_hi.g, slot_hi.b, slot_hi.a * 0.5f));
            draw_rect(Rect2(sx,     sy + 2, 1, ssz - 4), slot_hi);
            draw_rect(Rect2(sx + 1, sy + 1, 1, ssz - 2), Color(slot_hi.r, slot_hi.g, slot_hi.b, slot_hi.a * 0.5f));
            draw_rect(Rect2(sx + 2, sy + ssz - 1, ssz - 4, 1), slot_sh);
            draw_rect(Rect2(sx + 1, sy + ssz - 2, ssz - 2, 1), Color(slot_sh.r, slot_sh.g, slot_sh.b, slot_sh.a * 0.5f));
            draw_rect(Rect2(sx + ssz - 1, sy + 2, 1, ssz - 4), slot_sh);
            draw_rect(Rect2(sx + ssz - 2, sy + 1, 1, ssz - 2), Color(slot_sh.r, slot_sh.g, slot_sh.b, slot_sh.a * 0.5f));

            // ── Animated breathing border glow ──
            float slot_idx = (float)(row * cols + col);
            float slot_norm = slot_idx / MAX(total_slots - 1.0f, 1.0f);
            float dist = Math::abs(wave_pos - slot_norm);
            dist = MIN(dist, 1.0f - dist); // wrap-around distance
            float glow = MAX(0.0f, 1.0f - dist * total_slots * 0.5f);
            Color border_c = slot_border;
            border_c.r = Math::lerp(border_c.r, 0.55f, glow * 0.5f);
            border_c.g = Math::lerp(border_c.g, 0.65f, glow * 0.5f);
            border_c.b = Math::lerp(border_c.b, 0.85f, glow * 0.5f);
            border_c.a = Math::lerp(border_c.a, 0.95f, glow);
            draw_rect(slot, border_c, false, 1.0);

            if (ssz > 20) {
                draw_rect(Rect2(sx + 2, sy + 2, ssz - 4, 3),
                          Color(0.16, 0.16, 0.20, 0.25));
            }
        }
    }
}

void VisualGasicFormDesigner::_draw_stat_bar_control(const Rect2 &r, const FormControlItem &item, const Ref<Font> &font, int font_size, float t) {
    // Animated: glossy shimmer sweeps across fill bar (2s period),
    // trail bar pulses subtly, value animates between 65-85 range
    float value = 75.0f, max_val = 100.0f;
    Color bar_color(0.2, 0.8, 0.3);
    Color trail_color(0.9, 0.2, 0.2, 0.6);
    if (item.properties.has("Value"))    value   = float(item.properties["Value"]);
    if (item.properties.has("MaxValue")) max_val = MAX(float(item.properties["MaxValue"]), 1.0f);
    if (item.properties.has("BarColor")) bar_color = Color(item.properties["BarColor"]);

    // ── Animated value: oscillate ±10% around set value (4s cycle) ──
    float osc = Math::sin(t * Math_PI * 0.5f) * max_val * 0.10f;
    float anim_val = CLAMP(value + osc, 0.0f, max_val);
    float ratio = CLAMP(anim_val / max_val, 0.0f, 1.0f);

    // Background
    draw_rect(r, Color(0.15, 0.15, 0.18));
    draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1),
              Color(0.10, 0.10, 0.12, 0.5));
    draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2),
              Color(0.10, 0.10, 0.12, 0.5));

    // ── Trail bar: lags behind main fill, 0.5s delay (runtime behavior) ──
    float trail_osc = Math::sin((t - 0.5f) * Math_PI * 0.5f) * max_val * 0.10f;
    float trail_val = CLAMP(value + trail_osc, 0.0f, max_val);
    float trail_ratio = CLAMP(trail_val / max_val + 0.05f, 0.0f, 1.0f);
    float trail_w = r.size.x * trail_ratio;
    if (trail_w > 0) {
        // Pulse the trail alpha slightly
        float trail_pulse = 0.5f + Math::sin(t * 4.0f) * 0.1f;
        Color tc = trail_color;
        tc.a = trail_pulse;
        draw_rect(Rect2(r.position, Vector2(trail_w, r.size.y)), tc);
    }

    // Fill bar
    float fill_w = r.size.x * ratio;
    if (fill_w > 0) {
        draw_rect(Rect2(r.position, Vector2(fill_w, r.size.y)), bar_color);

        // ── Shimmer highlight sweeps left to right (2s cycle) ──
        if (r.size.y > 8) {
            float shimmer_w = MAX(fill_w * 0.15f, 8.0f);
            float shimmer_cycle = fmod(t, 2.0f) / 2.0f; // 0..1
            float shimmer_x = r.position.x + shimmer_cycle * (fill_w + shimmer_w) - shimmer_w;
            float sx1 = MAX(shimmer_x, r.position.x);
            float sx2 = MIN(shimmer_x + shimmer_w, r.position.x + fill_w);
            if (sx2 > sx1) {
                Color hi(MIN(bar_color.r + 0.25f, 1.0f),
                         MIN(bar_color.g + 0.25f, 1.0f),
                         MIN(bar_color.b + 0.25f, 1.0f), 0.45f);
                draw_rect(Rect2(sx1, r.position.y + 1,
                                sx2 - sx1, MAX(r.size.y * 0.35f, 2.0f)), hi);
            }
            // Static glossy top highlight (dimmer, behind shimmer)
            Color hi_base(MIN(bar_color.r + 0.12f, 1.0f),
                          MIN(bar_color.g + 0.12f, 1.0f),
                          MIN(bar_color.b + 0.12f, 1.0f), 0.20f);
            draw_rect(Rect2(r.position.x, r.position.y + 1,
                            fill_w, MAX(r.size.y * 0.3f, 2.0f)), hi_base);
        }
    }

    // Label
    if (font.is_valid() && r.size.y >= 10) {
        String lbl = String::num_int64(int(anim_val)) + " / " + String::num_int64(int(max_val));
        int lbl_fs = MIN(12, int(r.size.y - 4));
        float ty = r.position.y + (r.size.y + lbl_fs * 0.7f) * 0.5f;
        draw_string(font, Vector2(r.position.x + 5, ty + 1), lbl,
                    HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, lbl_fs,
                    Color(0, 0, 0, 0.45));
        draw_string(font, Vector2(r.position.x + 4, ty), lbl,
                    HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, lbl_fs,
                    Color(1, 1, 1, 0.95));
    }

    draw_rect(r, Color(0.25, 0.25, 0.30, 0.6), false, 1.0);
}

void VisualGasicFormDesigner::_draw_hud_counter_control(const Rect2 &r, const FormControlItem &item, const Ref<Font> &font, int font_size, float t) {
    // Animated: value ticks up every 2s with a punch-scale effect (runtime: 0.5s EASE_OUT, 1.3→1.0 in 0.2s)
    draw_rect(r, Color(0.08, 0.08, 0.10, 0.35));

    if (!font.is_valid()) return;

    String prefix = "", suffix = "";
    int value = 0;
    Color font_color(1.0, 0.85, 0.2);
    int disp_fs = 18;
    if (item.properties.has("Prefix"))    prefix     = String(item.properties["Prefix"]);
    if (item.properties.has("Suffix"))    suffix     = String(item.properties["Suffix"]);
    if (item.properties.has("Value"))     value      = int(item.properties["Value"]);
    if (item.properties.has("FontSize"))  disp_fs    = vb6_pt_to_px(int(item.properties["FontSize"]));
    if (item.properties.has("FontColor")) font_color = Color(item.properties["FontColor"]);

    // ── Animated value: increments by 10 every 2s, wraps at +100 ──
    float tick_period = 2.0f;
    float cycle_pos = fmod(t, tick_period * 10.0f); // 20s full cycle
    int bonus = int(cycle_pos / tick_period) * 10;
    int anim_val = value + bonus;

    // ── Punch scale: first 0.2s after each tick, scale 1.3→1.0 ──
    float tick_frac = fmod(t, tick_period);
    float punch = 1.0f;
    if (tick_frac < 0.2f) {
        float p = tick_frac / 0.2f;       // 0→1 over 0.2s
        punch = Math::lerp(1.3f, 1.0f, p * p); // ease-out quadratic
    }
    int anim_fs = MAX(1, int(disp_fs * punch));

    float sep = 6.0f, pad_x = 4.0f;
    float x = r.position.x + pad_x;

    // Icon placeholder (24×24, centered vertically)
    float icon_sz = MIN(24.0f, r.size.y - 4);
    if (r.size.x > icon_sz + 40) {
        float iy = r.position.y + (r.size.y - icon_sz) * 0.5f;
        Rect2 icon_r(x, iy, icon_sz, icon_sz);
        draw_rect(icon_r, Color(0.22, 0.22, 0.28, 0.7));
        draw_rect(Rect2(x, iy, icon_sz, 1), Color(0.35, 0.35, 0.42, 0.5));
        draw_rect(Rect2(x, iy, 1, icon_sz), Color(0.35, 0.35, 0.42, 0.5));
        draw_rect(Rect2(x, iy + icon_sz - 1, icon_sz, 1), Color(0.12, 0.12, 0.16, 0.6));
        draw_rect(Rect2(x + icon_sz - 1, iy, 1, icon_sz), Color(0.12, 0.12, 0.16, 0.6));
        // Diamond/cross icon
        float dsz = icon_sz * 0.28f;
        float dcx = x + icon_sz * 0.5f;
        float dcy = iy + icon_sz * 0.5f;
        draw_rect(Rect2(dcx - dsz * 0.5f, dcy - dsz, dsz, dsz * 2),
                  Color(font_color.r * 0.7f, font_color.g * 0.7f, font_color.b * 0.7f));
        draw_rect(Rect2(dcx - dsz, dcy - dsz * 0.5f, dsz * 2, dsz),
                  Color(font_color.r * 0.7f, font_color.g * 0.7f, font_color.b * 0.7f));
        draw_rect(icon_r, Color(0.45, 0.45, 0.52, 0.5), false, 1.0);
        x += icon_sz + sep;
    }

    // Value text (with punch-scale font size)
    String display = prefix + String::num_int64(anim_val) + suffix;
    float ty = r.position.y + (r.size.y + anim_fs * 0.7f) * 0.5f;
    float avail = r.size.x - (x - r.position.x) - pad_x;
    // Drop shadow
    draw_string(font, Vector2(x + 1, ty + 1), display,
                HORIZONTAL_ALIGNMENT_LEFT, avail, anim_fs, Color(0, 0, 0, 0.5));

    // ── Flash brighter on the tick moment (first 0.15s) ──
    Color draw_color = font_color;
    if (tick_frac < 0.15f) {
        float flash = 1.0f - tick_frac / 0.15f;
        draw_color.r = MIN(draw_color.r + flash * 0.4f, 1.0f);
        draw_color.g = MIN(draw_color.g + flash * 0.4f, 1.0f);
        draw_color.b = MIN(draw_color.b + flash * 0.4f, 1.0f);
    }
    draw_string(font, Vector2(x, ty), display,
                HORIZONTAL_ALIGNMENT_LEFT, avail, anim_fs, draw_color);
}

void VisualGasicFormDesigner::_draw_cooldown_button_control(const Rect2 &r, const Ref<Font> &font, int font_size, float t) {
    // Animated: radial sweep rotates continuously (5s cycle = full cooldown)
    // Runtime: overlay Color(0,0,0,0.55), radius=max(w,h)*0.72, 32 segments

    // Raised 3D button base
    Color face(0.28, 0.32, 0.42);
    Color hi(0.45, 0.50, 0.62);
    Color sh(0.15, 0.18, 0.25);
    Color dsh(0.08, 0.10, 0.15);

    draw_rect(r, face);
    float bx = r.position.x, by = r.position.y;
    float bw = r.size.x, bh = r.size.y;
    draw_rect(Rect2(bx, by, bw, 1), hi);
    draw_rect(Rect2(bx + 1, by + 1, bw - 2, 1), Color(hi.r + 0.08f, hi.g + 0.08f, hi.b + 0.08f, 0.45f));
    draw_rect(Rect2(bx, by, 1, bh), hi);
    draw_rect(Rect2(bx + 1, by + 1, 1, bh - 2), Color(hi.r + 0.08f, hi.g + 0.08f, hi.b + 0.08f, 0.45f));
    draw_rect(Rect2(bx, by + bh - 1, bw, 1), dsh);
    draw_rect(Rect2(bx + 1, by + bh - 2, bw - 2, 1), sh);
    draw_rect(Rect2(bx + bw - 1, by, 1, bh), dsh);
    draw_rect(Rect2(bx + bw - 2, by + 1, 1, bh - 2), sh);

    // ── Animated radial overlay sweep (5s cycle) ──
    float cx = bx + bw * 0.5f;
    float cy = by + bh * 0.5f;
    float radius = MIN(bw, bh) * 0.72f;
    Color overlay(0.0, 0.0, 0.0, 0.55);

    float cd_period = 5.0f;
    float cd_frac = fmod(t, cd_period) / cd_period; // 0..1 = fraction of cooldown remaining

    if (radius > 8 && cd_frac > 0.01f) {
        float start_a = -Math_PI * 0.5f;
        float end_a = start_a + Math_TAU * cd_frac;
        int segs = 32;  // match runtime 32 segments
        for (int i = 0; i < segs; i++) {
            float a1 = Math::lerp(start_a, end_a, float(i) / segs);
            float a2 = Math::lerp(start_a, end_a, float(i + 1) / segs);
            float px1 = cx + Math::cos(a1) * radius;
            float py1 = cy + Math::sin(a1) * radius;
            float px2 = cx + Math::cos(a2) * radius;
            float py2 = cy + Math::sin(a2) * radius;
            float mn_x = MIN(MIN(cx, px1), px2);
            float mx_x = MAX(MAX(cx, px1), px2);
            float mn_y = MIN(MIN(cy, py1), py2);
            float mx_y = MAX(MAX(cy, py1), py2);
            draw_rect(Rect2(mn_x, mn_y, mx_x - mn_x + 1, mx_y - mn_y + 1), overlay);
        }
    }

    // Countdown label (shows remaining seconds, counting down)
    if (font.is_valid()) {
        int remaining = int(Math::ceil(cd_frac * cd_period));
        if (remaining <= 0) remaining = int(cd_period);
        String cd_txt = String::num_int64(remaining);
        int cd_fs = MIN(14, int(MIN(bw, bh) * 0.4f));
        float ty = cy + cd_fs * 0.35f;
        draw_string(font, Vector2(bx + 1, ty + 1), cd_txt,
                    HORIZONTAL_ALIGNMENT_CENTER, bw, cd_fs,
                    Color(0, 0, 0, 0.5));
        // Flash text brighter at the top of each second
        float sec_frac = fmod(cd_frac * cd_period, 1.0f);
        float flash_a = sec_frac < 0.1f ? 1.0f : 0.9f;
        draw_string(font, Vector2(bx, ty), cd_txt,
                    HORIZONTAL_ALIGNMENT_CENTER, bw, cd_fs,
                    Color(1, 1, 1, flash_a));
    }
}

void VisualGasicFormDesigner::_draw_notification_toast_control(const Rect2 &r, const String &name, const Ref<Font> &font, int font_size, float t) {
    // Animated: slides in from top (runtime: SlideFromTop -50px TRANS_BACK),
    // fade in 0.3s, bell icon pulses, auto-dismiss cycle 4s
    float cycle = 4.0f;
    float phase = fmod(t, cycle);

    // ── Slide + fade animation ──
    // 0.0–0.3s: slide in from above (y offset -30→0) + fade 0→1
    // 0.3–2.5s: visible
    // 2.5–3.0s: fade out + slide up
    // 3.0–4.0s: invisible (gap before next)
    float y_offset = 0.0f;
    float alpha = 1.0f;
    if (phase < 0.3f) {
        float p = phase / 0.3f;
        // TRANS_BACK overshoot curve approximation
        float ease = p * p * (2.7f * p - 1.7f);
        ease = CLAMP(ease, 0.0f, 1.0f);
        y_offset = -30.0f * (1.0f - ease);
        alpha = p;
    } else if (phase > 2.5f && phase < 3.0f) {
        float p = (phase - 2.5f) / 0.5f;
        y_offset = -20.0f * p;
        alpha = 1.0f - p;
    } else if (phase >= 3.0f) {
        alpha = 0.0f;
    }

    if (alpha < 0.01f) return; // nothing visible

    Rect2 anim_r(r.position.x, r.position.y + y_offset, r.size.x, r.size.y);
    Color bg(0.18, 0.18, 0.22, 0.92 * alpha);

    draw_rect(anim_r, bg);
    // 3D panel border
    draw_rect(Rect2(anim_r.position.x, anim_r.position.y, anim_r.size.x, 1),
              Color(0.42, 0.42, 0.50, 0.35 * alpha));
    draw_rect(Rect2(anim_r.position.x, anim_r.position.y, 1, anim_r.size.y),
              Color(0.42, 0.42, 0.50, 0.35 * alpha));
    draw_rect(Rect2(anim_r.position.x, anim_r.position.y + anim_r.size.y - 1, anim_r.size.x, 1),
              Color(0.10, 0.10, 0.14, 0.7 * alpha));
    draw_rect(Rect2(anim_r.position.x + anim_r.size.x - 1, anim_r.position.y, 1, anim_r.size.y),
              Color(0.10, 0.10, 0.14, 0.7 * alpha));
    draw_rect(anim_r, Color(0.32, 0.32, 0.38, 0.6 * alpha), false, 1.0);

    if (!font.is_valid()) return;
    float mh = 10.0f, mv = 6.0f;
    float x = anim_r.position.x + mh;
    float cw = anim_r.size.x - mh * 2;

    // Icon placeholder (24×24) with pulse animation
    float icon_sz = MIN(24.0f, anim_r.size.y - mv * 2);
    if (cw > icon_sz + 60 && icon_sz > 10) {
        float iy = anim_r.position.y + (anim_r.size.y - icon_sz) * 0.5f;
        Rect2 icon_r(x, iy, icon_sz, icon_sz);
        draw_rect(icon_r, Color(0.25, 0.25, 0.30, 0.7 * alpha));
        draw_rect(icon_r, Color(0.45, 0.45, 0.52, 0.5 * alpha), false, 1.0);

        // ── Bell icon with swing animation ──
        float bell_pulse = 0.8f + Math::sin(t * 6.0f) * 0.2f;  // subtle size pulse
        float bcx = icon_r.position.x + icon_sz * 0.5f;
        float bcy = icon_r.position.y + icon_sz * 0.38f;
        float bell_w = icon_sz * 0.40f * bell_pulse;
        float bell_h = icon_sz * 0.35f;
        Color bell_c(1.0, 0.85, 0.3, 0.8 * alpha);
        draw_rect(Rect2(bcx - bell_w * 0.5f, bcy, bell_w, bell_h), bell_c);
        draw_rect(Rect2(bcx - bell_w * 0.65f, bcy + bell_h, bell_w * 1.3f, 2), bell_c);
        draw_rect(Rect2(bcx - 1, bcy + bell_h + 3, 2, 2),
                  Color(1.0, 0.85, 0.3, 0.6 * alpha));
        x += icon_sz + 8;
    }

    // Message text
    int msg_fs = MIN(14, font_size);
    float ty = anim_r.position.y + (anim_r.size.y + msg_fs * 0.7f) * 0.5f;
    draw_string(font, Vector2(x, ty), "Notification message",
                HORIZONTAL_ALIGNMENT_LEFT, anim_r.size.x - (x - anim_r.position.x) - mh,
                msg_fs, Color(0.95, 0.95, 0.98, alpha));

    // Close × hint
    float cl_x = anim_r.position.x + anim_r.size.x - mh - 10;
    if (cl_x > x + 40) {
        draw_string(font, Vector2(cl_x, anim_r.position.y + mv + 10),
                    String::utf8("\xc3\x97"),
                    HORIZONTAL_ALIGNMENT_LEFT, 12, 12,
                    Color(0.60, 0.60, 0.65, 0.45 * alpha));
    }
}

void VisualGasicFormDesigner::_draw_game_menu_control(const Rect2 &r, const FormControlItem &item, const Ref<Font> &font, int font_size, float t) {
    // Animated: fade-in + scale-up from 0.8→1.0 (runtime: FadeIn 0.3s, ScaleUp TRANS_BACK)
    // Button hover glow cycles through buttons sequentially
    float cycle = 6.0f;
    float phase = fmod(t, cycle);

    // ── Fade-in/scale-up: first 0.4s of each 6s cycle ──
    float menu_alpha = 1.0f;
    float menu_scale = 1.0f;
    if (phase < 0.4f) {
        float p = phase / 0.4f;
        menu_alpha = p;
        // TRANS_BACK approximation: overshoot to 1.05 then settle
        menu_scale = Math::lerp(0.8f, 1.0f, p * (2.0f - p)); // ease-out quad
    }

    // Semi-transparent overlay
    draw_rect(r, Color(0.0, 0.0, 0.0, 0.6 * menu_alpha));

    if (!font.is_valid()) return;

    String title = "PAUSED";
    int title_fs = 28;
    int btn_fs = 18;
    if (item.properties.has("Title"))          title    = String(item.properties["Title"]);
    if (item.properties.has("TitleFontSize"))  title_fs = vb6_pt_to_px(int(item.properties["TitleFontSize"]));
    if (item.properties.has("ButtonFontSize")) btn_fs   = vb6_pt_to_px(int(item.properties["ButtonFontSize"]));

    PackedStringArray labels;
    {
        String btn_raw;
        if (item.properties.has("Buttons")) {
            btn_raw = String(item.properties["Buttons"]);
        } else if (item.properties.has("ButtonLabels")) {
            btn_raw = String(item.properties["ButtonLabels"]);
        }
        if (!btn_raw.is_empty()) {
            // Strip PackedStringArray(...) wrapper if present (corrupted save)
            if (btn_raw.begins_with("PackedStringArray(") && btn_raw.ends_with(")")) {
                btn_raw = btn_raw.substr(18, btn_raw.length() - 19);
                btn_raw = btn_raw.replace("\"", "");
            }
            labels = btn_raw.split(",", false);
            for (int i = 0; i < labels.size(); i++) {
                labels.set(i, labels[i].strip_edges());
            }
        }
    }
    if (labels.is_empty()) {
        labels.push_back("Resume");
        labels.push_back("Settings");
        labels.push_back("Quit");
    }
    int btn_count = labels.size();

    float vbox_sep = 20.0f;
    float btn_sep = 10.0f;
    float btn_w = MIN(200.0f, r.size.x * 0.65f);
    float btn_h = MAX(32.0f, btn_fs + 14.0f);

    // Apply scale around center
    float scaled_btn_w = btn_w * menu_scale;
    float scaled_btn_h = btn_h * menu_scale;
    float scaled_title_fs = int(title_fs * menu_scale);
    float scaled_btn_fs = int(btn_fs * menu_scale);

    float title_block = scaled_title_fs + 4;
    float btns_block = btn_count * scaled_btn_h + (btn_count - 1) * btn_sep;
    float total_h = title_block + vbox_sep + btns_block;

    float cy = r.position.y + (r.size.y - total_h) * 0.5f;
    cy = MAX(cy, r.position.y + 10);

    // Title with drop shadow
    float ty = cy + scaled_title_fs;
    draw_string(font, Vector2(r.position.x + 2, ty + 2), title,
                HORIZONTAL_ALIGNMENT_CENTER, r.size.x, scaled_title_fs,
                Color(0, 0, 0, 0.5 * menu_alpha));
    draw_string(font, Vector2(r.position.x, ty), title,
                HORIZONTAL_ALIGNMENT_CENTER, r.size.x, scaled_title_fs,
                Color(1, 1, 1, menu_alpha));

    // ── Buttons with cycling hover glow ──
    // One button glows at a time, cycling every 1.5s
    float hover_period = 1.5f;
    int hover_idx = int(fmod(t, hover_period * btn_count) / hover_period);
    float hover_frac = fmod(t, hover_period) / hover_period;
    // Smooth glow: ramp up then down
    float glow_strength = Math::sin(hover_frac * Math_PI); // 0→1→0

    float bx = r.position.x + (r.size.x - scaled_btn_w) * 0.5f;
    float btn_y = cy + title_block + vbox_sep;
    if (btn_y + btns_block > r.position.y + r.size.y - 8) {
        btn_y = r.position.y + r.size.y - btns_block - 8;
    }

    for (int i = 0; i < btn_count; i++) {
        float bty = btn_y + i * (scaled_btn_h + btn_sep);
        Rect2 btn_r(bx, bty, scaled_btn_w, scaled_btn_h);

        // Hover glow: brighten the face color for the active button
        Color btn_face = sys_button_face;
        if (i == hover_idx && menu_alpha > 0.5f) {
            btn_face.r = Math::lerp(btn_face.r, MIN(btn_face.r + 0.25f, 1.0f), glow_strength);
            btn_face.g = Math::lerp(btn_face.g, MIN(btn_face.g + 0.25f, 1.0f), glow_strength);
            btn_face.b = Math::lerp(btn_face.b, MIN(btn_face.b + 0.25f, 1.0f), glow_strength);
        }
        _draw_raised_rect(btn_r, btn_face);

        // Glow border highlight on hovered button
        if (i == hover_idx && glow_strength > 0.05f) {
            Color glow_c(0.5, 0.6, 0.9, glow_strength * 0.6f * menu_alpha);
            draw_rect(btn_r, glow_c, false, 2.0);
        }

        float text_y = bty + (scaled_btn_h + scaled_btn_fs * 0.7f) * 0.5f;
        draw_string(font, Vector2(bx, text_y), labels[i],
                    HORIZONTAL_ALIGNMENT_CENTER, scaled_btn_w, scaled_btn_fs,
                    Color(color_text.r, color_text.g, color_text.b, menu_alpha));
    }
}

// =============================================================================
// Live Preview Layer — instantiates actual Godot scenes for WYSIWYG rendering
// =============================================================================

void VisualGasicFormDesigner::_set_mouse_filter_recursive(Node *p_node) {
    Control *ctrl = Object::cast_to<Control>(p_node);
    if (ctrl) {
        ctrl->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    }
    for (int i = 0; i < p_node->get_child_count(); i++) {
        _set_mouse_filter_recursive(p_node->get_child(i));
    }
}

void VisualGasicFormDesigner::_create_preview_layer() {
    if (preview_container) return;
    if (!is_inside_tree()) return; // Can't add children until in scene tree

    // Container for live scene instances — positioned at form body origin
    preview_container = memnew(Control);
    preview_container->set_name("__preview_container");
    preview_container->set_position(Vector2(FORM_PADDING_X, FORM_PADDING_Y));
    preview_container->set_size(Vector2(form_size));
    preview_container->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    preview_container->set_clip_children_mode(CanvasItem::CLIP_CHILDREN_AND_DRAW);
    add_child(preview_container);

    // Overlay drawn ON TOP of preview children (for selection handles, rubber band, etc.)
    overlay_node = memnew(Control);
    overlay_node->set_name("__overlay");
    overlay_node->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
    overlay_node->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    add_child(overlay_node);
    overlay_node->connect("draw", Callable(this, "_on_overlay_draw"));
}

void VisualGasicFormDesigner::_create_live_preview(int idx) {
    if (!preview_container || idx < 0 || idx >= controls.size()) return;
    FormControlItem &item = controls.write[idx];

    // Destroy existing preview for this name if any
    _destroy_live_preview(item.name);

    // ── Resolve scene_path from type when empty ──
    String scene_path = item.scene_path;
    if (scene_path.is_empty() && !item.type.is_empty()) {
        // Try game_ui subfolder first, then top-level prototypes
        String game_ui_path = "res://addons/visual_gasic/prototypes/game_ui/" + item.type + ".tscn";
        String standard_path = "res://addons/visual_gasic/prototypes/" + item.type + ".tscn";
        if (FileAccess::file_exists(game_ui_path)) {
            scene_path = game_ui_path;
            item.scene_path = game_ui_path;
        } else if (FileAccess::file_exists(standard_path)) {
            scene_path = standard_path;
            item.scene_path = standard_path;
        }
    }

    if (scene_path.is_empty()) return;

    // Load and instantiate the prototype scene
    Ref<PackedScene> scene = ResourceLoader::get_singleton()->load(scene_path);
    if (!scene.is_valid()) {
        return;
    }

    Node *instance = scene->instantiate();
    if (!instance) return;

    Control *ctrl = Object::cast_to<Control>(instance);
    if (!ctrl) {
        // Not a Control — can't position in the form
        memdelete(instance);
        return;
    }

    ctrl->set_name("__lp_" + item.name);

    // Add to tree FIRST so _ready() runs and _build_ui() creates children
    preview_container->add_child(ctrl);

    // ── Force design-time visibility ──
    // Many prototypes (GameMenu, NotificationToast, etc.) set visible=false
    // in _build_ui() — override that for design-time preview.
    ctrl->set_visible(true);
    ctrl->set_modulate(Color(1, 1, 1, 1));

    // ── Reset anchors so our explicit position/size takes effect ──
    // Prototypes like GameMenu call set_anchors_and_offsets_preset(FULL_RECT)
    // which would stretch them to fill the preview_container.
    ctrl->set_anchors_preset(Control::PRESET_TOP_LEFT);
    ctrl->set_anchor(SIDE_RIGHT, 0);
    ctrl->set_anchor(SIDE_BOTTOM, 0);
    ctrl->set_position(item.rect.position);
    ctrl->set_custom_minimum_size(Vector2());
    ctrl->set_size(item.rect.size);

    // ── Prevent live preview from stealing mouse events ──
    // Apply AFTER add_child so _ready() children are already created.
    _set_mouse_filter_recursive(ctrl);

    live_previews[item.name] = ctrl;

    // Sync basic display properties from the form data model
    _sync_live_preview_properties(idx);
}

void VisualGasicFormDesigner::_destroy_live_preview(const String &p_name) {
    if (!live_previews.has(p_name)) return;
    Node *node = live_previews[p_name];
    if (node) {
        node->queue_free();
    }
    live_previews.erase(p_name);
}

void VisualGasicFormDesigner::_sync_live_preview_rect(int idx) {
    if (idx < 0 || idx >= controls.size()) return;
    const FormControlItem &item = controls[idx];
    if (!live_previews.has(item.name)) return;

    Control *ctrl = Object::cast_to<Control>(live_previews[item.name]);
    if (ctrl) {
        // Ensure anchors stay at top-left (prototypes may reset them)
        ctrl->set_anchors_preset(Control::PRESET_TOP_LEFT);
        ctrl->set_anchor(SIDE_RIGHT, 0);
        ctrl->set_anchor(SIDE_BOTTOM, 0);
        ctrl->set_position(item.rect.position);
        ctrl->set_size(item.rect.size);
    }
}

void VisualGasicFormDesigner::_sync_live_preview_properties(int idx) {
    if (idx < 0 || idx >= controls.size()) return;
    const FormControlItem &item = controls[idx];
    if (!live_previews.has(item.name)) return;

    Node *node = live_previews[item.name];
    if (!node) return;
    Control *ctrl = Object::cast_to<Control>(node);

    // ── 1. Sync text property for text-bearing controls ──
    if (!item.text.is_empty()) {
        if (node->has_method("set_text")) {
            node->call("set_text", item.text);
        }
    }

    // ── 2. Force design-time visibility ──
    if (ctrl) {
        ctrl->set_visible(true);
        if (item.visible) {
            ctrl->set_modulate(Color(1, 1, 1, 1));
        } else {
            ctrl->set_modulate(Color(0.7, 0.7, 0.8, 0.35));
        }
    }

    // ── 3. Apply generic properties from the properties dict ──
    const Dictionary &props = item.properties;
    String t = item.type;
    bool is_prototype = !item.scene_path.is_empty() &&
                        (item.scene_path.find("prototypes/game_ui/") >= 0 ||
                         item.scene_path.find("prototypes/") >= 0);

    // ---------- ItemList / ListBox ----------
    ItemList *ilist = Object::cast_to<ItemList>(node);
    if (ilist) {
        // List items
        if (props.has("List")) {
            String list_str = props["List"];
            ilist->clear();
            if (!list_str.is_empty()) {
                PackedStringArray items = list_str.split(",", false);
                for (int i = 0; i < items.size(); i++) {
                    ilist->add_item(items[i].strip_edges());
                }
            }
        }
        // ListStyle: 0=Standard, 1=Checkbox (not native to Godot ItemList but
        // we can show a visual hint by enabling/disabling selectable items)
        // Sorted
        if (props.has("Sorted") && (bool)props["Sorted"]) {
            ilist->sort_items_by_text();
        }
        // MultiSelect
        if (props.has("MultiSelect")) {
            int ms = props["MultiSelect"];
            ilist->set_select_mode(ms == 0 ? ItemList::SELECT_SINGLE : ItemList::SELECT_MULTI);
        }
        // MaxColumns
        if (props.has("MaxColumns")) {
            ilist->set_max_columns(int(props["MaxColumns"]));
        }
        // FixedColumnWidth
        if (props.has("FixedColumnWidth")) {
            ilist->set_fixed_column_width(int(props["FixedColumnWidth"]));
        }
        // IconMode
        if (props.has("IconMode")) {
            ilist->set_icon_mode(int(props["IconMode"]) == 0 ? ItemList::ICON_MODE_TOP : ItemList::ICON_MODE_LEFT);
        }
        // AutoHeight
        if (props.has("AutoHeight")) {
            ilist->set_auto_height((bool)props["AutoHeight"]);
        }
        // SameColumnWidth
        if (props.has("SameColumnWidth")) {
            ilist->set_same_column_width((bool)props["SameColumnWidth"]);
        }
        // AllowReselect
        if (props.has("AllowReselect")) {
            ilist->set_allow_reselect((bool)props["AllowReselect"]);
        }
        // FixedIconSize
        if (props.has("FixedIconSize")) {
            int icon_sz = int(props["FixedIconSize"]);
            ilist->set_fixed_icon_size(Vector2i(icon_sz, icon_sz));
        }
    }

    // ---------- OptionButton / ComboBox ----------
    OptionButton *opt = Object::cast_to<OptionButton>(node);
    if (opt) {
        if (props.has("ListItems")) {
            String list_str = props["ListItems"];
            opt->clear();
            if (!list_str.is_empty()) {
                PackedStringArray items = list_str.split(",", false);
                for (int i = 0; i < items.size(); i++) {
                    opt->add_item(items[i].strip_edges());
                }
            }
        }
        if (props.has("Selected")) {
            int sel = props["Selected"];
            if (sel >= 0 && sel < opt->get_item_count()) {
                opt->select(sel);
            }
        }
        if (props.has("FitToLongestItem")) {
            opt->set_fit_to_longest_item((bool)props["FitToLongestItem"]);
        }
    }

    // ---------- Range controls (ProgressBar, Slider, SpinBox, ScrollBar) ----------
    Range *range = Object::cast_to<Range>(node);
    if (range) {
        // Apply Min first to avoid clamping issues
        if (props.has("Min")) range->set_min(float(props["Min"]));
        if (props.has("Max")) range->set_max(float(props["Max"]));
        if (props.has("Step")) range->set_step(float(props["Step"]));
        if (props.has("Value")) range->set_value(float(props["Value"]));
        if (props.has("AllowGreater")) range->set_allow_greater((bool)props["AllowGreater"]);
        if (props.has("AllowLesser")) range->set_allow_lesser((bool)props["AllowLesser"]);
        if (props.has("Rounded")) range->set_use_rounded_values((bool)props["Rounded"]);
    }

    // ---------- ProgressBar-specific ----------
    ProgressBar *pbar = Object::cast_to<ProgressBar>(node);
    if (pbar) {
        if (props.has("ShowPercentage")) pbar->set_show_percentage((bool)props["ShowPercentage"]);
        if (props.has("Indeterminate")) pbar->set_indeterminate((bool)props["Indeterminate"]);
        if (props.has("FillMode")) pbar->set_fill_mode(int(props["FillMode"]));
    }

    // ---------- SpinBox-specific ----------
    SpinBox *sbox = Object::cast_to<SpinBox>(node);
    if (sbox) {
        if (props.has("Prefix")) sbox->set_prefix(String(props["Prefix"]));
        if (props.has("Suffix")) sbox->set_suffix(String(props["Suffix"]));
        if (props.has("Editable")) sbox->set_editable((bool)props["Editable"]);
        if (props.has("Alignment")) sbox->set_horizontal_alignment(HorizontalAlignment(int(props["Alignment"])));
        if (props.has("SelectAllOnFocus")) sbox->set_select_all_on_focus((bool)props["SelectAllOnFocus"]);
        if (props.has("UpdateOnTextChanged")) sbox->set_update_on_text_changed((bool)props["UpdateOnTextChanged"]);
    }

    // ---------- Slider-specific (HSlider / VSlider) ----------
    Slider *slider = Object::cast_to<Slider>(node);
    if (slider) {
        if (props.has("TickCount")) slider->set_ticks(int(props["TickCount"]));
        if (props.has("TicksOnBorders")) slider->set_ticks_on_borders((bool)props["TicksOnBorders"]);
        if (props.has("Scrollable")) slider->set_scrollable((bool)props["Scrollable"]);
    }

    // ---------- ScrollBar-specific (HScrollBar / VScrollBar) ----------
    ScrollBar *sbar = Object::cast_to<ScrollBar>(node);
    if (sbar) {
        if (props.has("Page")) range->set_page(float(props["Page"]));
        if (props.has("CustomStep")) sbar->set_custom_step(float(props["CustomStep"]));
    }

    // ---------- Tree / TreeView ----------
    Tree *tree = Object::cast_to<Tree>(node);
    if (tree) {
        if (props.has("HideRoot")) tree->set_hide_root((bool)props["HideRoot"]);
        if (props.has("HideFolding")) tree->set_hide_folding((bool)props["HideFolding"]);
        if (props.has("AllowReselect")) tree->set_allow_reselect((bool)props["AllowReselect"]);
        if (props.has("AllowRmbSelect")) tree->set_allow_rmb_select((bool)props["AllowRmbSelect"]);
        if (props.has("SelectMode")) tree->set_select_mode(Tree::SelectMode(int(props["SelectMode"])));
        if (props.has("Columns")) tree->set_columns(int(props["Columns"]));
        if (props.has("ColumnTitlesVisible")) tree->set_column_titles_visible((bool)props["ColumnTitlesVisible"]);
        if (props.has("ScrollHorizontalEnabled")) tree->set_h_scroll_enabled((bool)props["ScrollHorizontalEnabled"]);
        if (props.has("ScrollVerticalEnabled")) tree->set_v_scroll_enabled((bool)props["ScrollVerticalEnabled"]);
    }

    // ---------- CheckBox / CheckButton ----------
    CheckBox *chk = Object::cast_to<CheckBox>(node);
    if (chk && props.has("Value")) {
        chk->set_pressed((bool)props["Value"]);
    }
    CheckButton *chkbtn = Object::cast_to<CheckButton>(node);
    if (chkbtn && props.has("Value")) {
        chkbtn->set_pressed((bool)props["Value"]);
    }

    // ---------- Button-specific ----------
    Button *btn = Object::cast_to<Button>(node);
    if (btn) {
        if (props.has("Flat")) btn->set_flat((bool)props["Flat"]);
        if (props.has("ClipText")) btn->set_clip_text((bool)props["ClipText"]);
    }
    // BaseButton behaviour (Button, CheckBox, CheckButton, etc.)
    BaseButton *bbase = Object::cast_to<BaseButton>(node);
    if (bbase) {
        if (props.has("KeepPressedOutside")) bbase->set_keep_pressed_outside((bool)props["KeepPressedOutside"]);
        if (props.has("ActionMode")) bbase->set_action_mode(BaseButton::ActionMode(int(props["ActionMode"])));
    }

    // ---------- LineEdit-specific ----------
    LineEdit *le = Object::cast_to<LineEdit>(node);
    if (le) {
        if (props.has("MaxLength")) le->set_max_length(int(props["MaxLength"]));
        if (props.has("PlaceholderText")) le->set_placeholder(String(props["PlaceholderText"]));
        if (props.has("Locked")) le->set_editable(!(bool)props["Locked"]);
        if (props.has("ClearButton")) le->set_clear_button_enabled((bool)props["ClearButton"]);
        if (props.has("SelectAllOnFocus")) le->set_select_all_on_focus((bool)props["SelectAllOnFocus"]);
        if (props.has("Alignment")) le->set_horizontal_alignment(HorizontalAlignment(int(props["Alignment"])));
        if (props.has("PasswordChar")) {
            String pc = props["PasswordChar"];
            if (!pc.is_empty()) {
                le->set_secret(true);
                le->set_secret_character(pc);
            } else {
                le->set_secret(false);
            }
        }
        if (props.has("RightToLeft")) {
            le->set_text_direction((bool)props["RightToLeft"] ? Control::TEXT_DIRECTION_RTL : Control::TEXT_DIRECTION_LTR);
        }
        if (props.has("VirtualKeyboardEnabled")) {
            le->set_virtual_keyboard_enabled((bool)props["VirtualKeyboardEnabled"]);
        }
    }

    // ---------- TextEdit-specific ----------
    TextEdit *te = Object::cast_to<TextEdit>(node);
    if (te) {
        if (props.has("Locked") || props.has("Editable")) {
            bool editable = true;
            if (props.has("Locked")) editable = !(bool)props["Locked"];
            if (props.has("Editable")) editable = (bool)props["Editable"];
            te->set_editable(editable);
        }
        if (props.has("PlaceholderText")) te->set_placeholder(String(props["PlaceholderText"]));
        if (props.has("RightToLeft")) {
            te->set_text_direction((bool)props["RightToLeft"] ? Control::TEXT_DIRECTION_RTL : Control::TEXT_DIRECTION_LTR);
        }
    }

    // ---------- TabContainer-specific ----------
    TabContainer *tabs = Object::cast_to<TabContainer>(node);
    if (tabs) {
        if (props.has("Tabs")) {
            String tabs_str = props["Tabs"];
            // Build child panels for each tab name
            if (!tabs_str.is_empty()) {
                PackedStringArray tab_names = tabs_str.split(",", false);
                // Only rebuild if count differs (avoid flickering)
                int current_count = tabs->get_tab_count();
                if (current_count != tab_names.size()) {
                    // Remove excess tabs
                    while (tabs->get_child_count() > tab_names.size()) {
                        Node *last = tabs->get_child(tabs->get_child_count() - 1);
                        tabs->remove_child(last);
                        last->queue_free();
                    }
                    // Add missing tabs
                    while (tabs->get_child_count() < tab_names.size()) {
                        Control *panel = memnew(Control);
                        tabs->add_child(panel);
                    }
                }
                // Set tab titles
                for (int i = 0; i < tab_names.size(); i++) {
                    tabs->set_tab_title(i, tab_names[i].strip_edges());
                }
            }
        }
        if (props.has("CurrentTab")) {
            int ct = props["CurrentTab"];
            if (ct >= 0 && ct < tabs->get_tab_count()) {
                tabs->set_current_tab(ct);
            }
        }
        if (props.has("TabAlignment")) tabs->set_tab_alignment(TabBar::AlignmentMode(int(props["TabAlignment"])));
        if (props.has("ClipTabs")) tabs->set_clip_tabs((bool)props["ClipTabs"]);
        if (props.has("DragToRearrangeEnabled")) tabs->set_drag_to_rearrange_enabled((bool)props["DragToRearrangeEnabled"]);
    }

    // ---------- Label-specific ----------
    if (t == "Label" && ctrl) {
        if (props.has("Alignment") && node->has_method("set_horizontal_alignment")) {
            node->call("set_horizontal_alignment", int(props["Alignment"]));
        }
        if (props.has("VerticalAlignment") && node->has_method("set_vertical_alignment")) {
            node->call("set_vertical_alignment", int(props["VerticalAlignment"]));
        }
        if (props.has("WordWrap") && node->has_method("set_autowrap_mode")) {
            node->call("set_autowrap_mode", (bool)props["WordWrap"] ? 3 : 0);  // AUTOWRAP_WORD_SMART=3
        }
        if (props.has("AutoSize") && node->has_method("set_autowrap_mode")) {
            if ((bool)props["AutoSize"]) {
                node->call("set_autowrap_mode", 0);  // AUTOWRAP_OFF
            }
        }
        if (props.has("ClipText") && node->has_method("set_clip_text")) {
            node->call("set_clip_text", (bool)props["ClipText"]);
        }
        if (props.has("MaxLinesVisible") && node->has_method("set_max_lines_visible")) {
            node->call("set_max_lines_visible", int(props["MaxLinesVisible"]));
        }
        if (props.has("TextOverrunBehavior") && node->has_method("set_text_overrun_behavior")) {
            node->call("set_text_overrun_behavior", int(props["TextOverrunBehavior"]));
        }
    }

    // ---------- RadioButton (treated as CheckBox variant) ----------
    if (t == "RadioButton" && node->has_method("set_pressed")) {
        if (props.has("Value")) {
            node->call("set_pressed", (bool)props["Value"]);
        }
    }

    // ---------- ColorRect / Shape ----------
    ColorRect *crect = Object::cast_to<ColorRect>(node);
    if (crect) {
        if (props.has("ShapeColor")) {
            Variant v = props["ShapeColor"];
            if (v.get_type() == Variant::COLOR) {
                crect->set_color((Color)v);
            }
        }
    }

    // ---------- TextureRect / PictureBox ----------
    TextureRect *trect = Object::cast_to<TextureRect>(node);
    if (trect) {
        if (props.has("FlipH")) trect->set_flip_h((bool)props["FlipH"]);
        if (props.has("FlipV")) trect->set_flip_v((bool)props["FlipV"]);
        if (props.has("StretchMode")) trect->set_stretch_mode(TextureRect::StretchMode(int(props["StretchMode"])));
    }

    // ---------- TextureButton ----------
    TextureButton *tbtn = Object::cast_to<TextureButton>(node);
    if (tbtn) {
        if (props.has("FlipH")) tbtn->set_flip_h((bool)props["FlipH"]);
        if (props.has("FlipV")) tbtn->set_flip_v((bool)props["FlipV"]);
        if (props.has("IgnoreTextureSize")) tbtn->set_ignore_texture_size((bool)props["IgnoreTextureSize"]);
        if (props.has("StretchMode")) tbtn->set_stretch_mode(TextureButton::StretchMode(int(props["StretchMode"])));
    }

    // ---------- RichTextLabel ----------
    RichTextLabel *rtl = Object::cast_to<RichTextLabel>(node);
    if (rtl) {
        if (props.has("BbcodeEnabled")) rtl->set_use_bbcode((bool)props["BbcodeEnabled"]);
        if (props.has("FitContent")) rtl->set_fit_content((bool)props["FitContent"]);
        if (props.has("ScrollActive")) rtl->set_scroll_active((bool)props["ScrollActive"]);
        if (props.has("SelectionEnabled")) rtl->set_selection_enabled((bool)props["SelectionEnabled"]);
        if (props.has("WordWrap")) {
            rtl->set_autowrap_mode((bool)props["WordWrap"] ? TextServer::AUTOWRAP_WORD_SMART : TextServer::AUTOWRAP_OFF);
        }
    }

    // ---------- MenuBar ----------
    MenuBar *mbar = Object::cast_to<MenuBar>(node);
    if (mbar) {
        if (props.has("Flat")) mbar->set_flat((bool)props["Flat"]);
        if (props.has("SwitchOnHover")) mbar->set_switch_on_hover((bool)props["SwitchOnHover"]);
        if (props.has("PreferGlobalMenu")) mbar->set_prefer_global_menu((bool)props["PreferGlobalMenu"]);
    }

    // ── 4. Universal visual properties ──
    if (ctrl) {
        // FontSize — theme override
        if (props.has("FontSize")) {
            int vb6_pt = int(props["FontSize"]);
            // VB6 8pt ≈ Godot 12px, rough scaling: px = pt * 1.5
            int godot_px = (int)(vb6_pt * 1.5);
            if (godot_px < 8) godot_px = 8;
            ctrl->add_theme_font_size_override("font_size", godot_px);
        }

        // FontName / FontBold / FontItalic → SystemFont theme override
        {
            String font_name = props.has("FontName") ? String(props["FontName"]) : "";
            bool font_bold = props.has("FontBold") ? (bool)(props["FontBold"]) : false;
            bool font_italic = props.has("FontItalic") ? (bool)(props["FontItalic"]) : false;

            bool need_font = (!font_name.is_empty() && font_name != "MS Sans Serif") ||
                             font_bold || font_italic;
            if (need_font) {
                Ref<SystemFont> sf;
                sf.instantiate();
                if (!font_name.is_empty() && font_name != "MS Sans Serif") {
                    PackedStringArray names;
                    names.push_back(font_name);
                    sf->set_font_names(names);
                }
                if (font_bold) {
                    sf->set_font_weight(700);
                }
                if (font_italic) {
                    sf->set_font_italic(true);
                }
                ctrl->add_theme_font_override("font", sf);
            }
        }

        // BorderStyle → StyleBoxFlat with/without border
        if (props.has("BorderStyle")) {
            int bs = int(props["BorderStyle"]);
            // Only override for explicit 0 (None) or 1 (Fixed Single)
            Ref<StyleBoxFlat> sbf;
            sbf.instantiate();
            // Preserve any existing BackColor, otherwise use a sensible default
            Color bg_color(0.93f, 0.93f, 0.93f);  // light gray default
            if (props.has("BackColor") && props["BackColor"].get_type() == Variant::COLOR) {
                bg_color = Color(props["BackColor"]);
            }
            sbf->set_bg_color(bg_color);
            sbf->set_content_margin_all(4.0f);
            if (bs == 1) {
                // Fixed Single: 1px dark border
                sbf->set_border_width_all(1);
                sbf->set_border_color(Color(0.4f, 0.4f, 0.4f));
            } else {
                // None: no border
                sbf->set_border_width_all(0);
            }
            if (ctrl->has_theme_stylebox("normal")) {
                ctrl->add_theme_stylebox_override("normal", sbf);
            } else if (ctrl->has_theme_stylebox("panel")) {
                ctrl->add_theme_stylebox_override("panel", sbf);
            }
        }

        // Opacity (0-100 → modulate alpha)
        if (props.has("Opacity") && item.visible) {
            float alpha = float(int(props["Opacity"])) / 100.0f;
            ctrl->set_modulate(Color(1, 1, 1, CLAMP(alpha, 0.0f, 1.0f)));
        }

        // ForeColor → font_color override
        if (props.has("ForeColor")) {
            Variant v = props["ForeColor"];
            if (v.get_type() == Variant::COLOR) {
                Color fc = v;
                ctrl->add_theme_color_override("font_color", fc);
            }
        }

        // BackColor → use a StyleBoxFlat bg for controls that support it
        if (props.has("BackColor")) {
            Variant v = props["BackColor"];
            if (v.get_type() == Variant::COLOR) {
                Color bc = v;
                // Only apply opaque backgrounds (alpha > 0.5)
                if (bc.a > 0.5f) {
                    Ref<StyleBoxFlat> sbf;
                    sbf.instantiate();
                    sbf->set_bg_color(bc);
                    sbf->set_border_width_all(0);
                    // Try "normal" first (most controls), then "panel" (Panel, TabContainer)
                    if (ctrl->has_theme_stylebox("normal")) {
                        ctrl->add_theme_stylebox_override("normal", sbf);
                    } else if (ctrl->has_theme_stylebox("panel")) {
                        ctrl->add_theme_stylebox_override("panel", sbf);
                    }
                }
            }
        }

        // Enabled
        if (props.has("Enabled")) {
            BaseButton *bb = Object::cast_to<BaseButton>(node);
            if (bb) {
                bb->set_disabled(!(bool)props["Enabled"]);
            }
            if (le) {
                le->set_editable((bool)props["Enabled"]);
            }
        }

        // Rotation (degrees → radians for Godot)
        if (props.has("Rotation")) {
            ctrl->set_rotation_degrees(float(props["Rotation"]));
        }

        // Scale
        float sx = props.has("ScaleX") ? float(props["ScaleX"]) : 1.0f;
        float sy = props.has("ScaleY") ? float(props["ScaleY"]) : 1.0f;
        if (props.has("ScaleX") || props.has("ScaleY")) {
            ctrl->set_scale(Vector2(sx, sy));
        }

        // PivotOffset
        float px = props.has("PivotOffsetX") ? float(props["PivotOffsetX"]) : 0.0f;
        float py = props.has("PivotOffsetY") ? float(props["PivotOffsetY"]) : 0.0f;
        if (props.has("PivotOffsetX") || props.has("PivotOffsetY")) {
            ctrl->set_pivot_offset(Vector2(px, py));
        }

        // MinWidth / MinHeight → custom_minimum_size
        if (props.has("MinWidth") || props.has("MinHeight")) {
            float mw = props.has("MinWidth") ? float(int(props["MinWidth"])) : 0.0f;
            float mh = props.has("MinHeight") ? float(int(props["MinHeight"])) : 0.0f;
            ctrl->set_custom_minimum_size(Vector2(mw, mh));
        }

        // ClipContents
        if (props.has("ClipContents")) {
            ctrl->set_clip_contents((bool)props["ClipContents"]);
        }

        // LayoutDirection
        if (props.has("LayoutDirection")) {
            ctrl->set_layout_direction(Control::LayoutDirection(int(props["LayoutDirection"])));
        }

        // SelfModulate
        if (props.has("SelfModulate")) {
            Variant v = props["SelfModulate"];
            if (v.get_type() == Variant::COLOR) {
                ctrl->set_self_modulate((Color)v);
            }
        }

        // ShowBehindParent
        if (props.has("ShowBehindParent")) {
            ctrl->set_draw_behind_parent((bool)props["ShowBehindParent"]);
        }
    }

    // ── 5. Prototype / Game UI controls — set @export properties directly ──
    if (is_prototype) {
        // Build a set of known node properties ONCE for efficient lookup
        Array prop_list = node->get_property_list();
        HashMap<String, bool> node_props;
        for (int pl = 0; pl < prop_list.size(); pl++) {
            Dictionary pd = prop_list[pl];
            node_props[String(pd["name"])] = true;
        }

        Array keys = props.keys();
        for (int k = 0; k < keys.size(); k++) {
            String key = keys[k];
            Variant val = props[key];
            // Skip universal properties already handled above
            if (key == "Enabled" || key == "TabStop" || key == "TabIndex" ||
                key == "Tag" || key == "ToolTipText" || key == "MousePointer" ||
                key == "FontName" || key == "FontSize" || key == "FontBold" ||
                key == "FontItalic" || key == "FontUnderline" || key == "FontStrikethrough" ||
                key == "Appearance" || key == "BorderStyle" || key == "Opacity" ||
                key == "BackColor" || key == "ForeColor" ||
                key == "Rotation" || key == "ScaleX" || key == "ScaleY" ||
                key == "PivotOffsetX" || key == "PivotOffsetY" ||
                key == "MinWidth" || key == "MinHeight" || key == "ClipContents" ||
                key == "SizeFlagsHorizontal" || key == "SizeFlagsVertical" ||
                key == "GrowHorizontal" || key == "GrowVertical" ||
                key == "LayoutDirection" || key == "SelfModulate" ||
                key == "ShowBehindParent" || key == "MouseDefaultCursorShape" ||
                key == "ThemeTypeVariation" || key == "FocusMode" ||
                key == "MouseFilter" || key == "CausesValidation") {
                continue;
            }
            // Try setting the property directly on the prototype node
            if (!node_props.has(key)) continue;

            // Convert comma-separated String to PackedStringArray if needed
            if (val.get_type() == Variant::STRING) {
                // Check if the node expects a PackedStringArray for this property
                Variant current = node->get(key);
                if (current.get_type() == Variant::PACKED_STRING_ARRAY) {
                    String s = val;
                    // Strip PackedStringArray(...) wrapper if present (corrupted save)
                    if (s.begins_with("PackedStringArray(") && s.ends_with(")")) {
                        s = s.substr(18, s.length() - 19);
                        s = s.replace("\"", "");
                    }
                    PackedStringArray arr;
                    if (!s.is_empty()) {
                        PackedStringArray parts = s.split(",", false);
                        for (int p = 0; p < parts.size(); p++) {
                            arr.push_back(parts[p].strip_edges());
                        }
                    }
                    node->set(key, arr);
                    continue;
                }
            }
            node->set(key, val);
        }
    }

    // ── 6. Re-apply mouse filter after property changes ──
    // Some property setters may re-enable mouse events on children.
    if (ctrl) {
        _set_mouse_filter_recursive(ctrl);
    }
}

void VisualGasicFormDesigner::_rebuild_all_live_previews() {
    _clear_all_live_previews();
    // Lazy-create the preview layer if it hasn't been created yet
    // (open_form can be called before _ready)
    if (!preview_container) {
        _create_preview_layer();
    }
    if (!preview_container) {
        return;
    }

    // Update preview container size to match current form
    preview_container->set_size(Vector2(form_size));

    for (int i = 0; i < controls.size(); i++) {
        _create_live_preview(i);
    }
}

void VisualGasicFormDesigner::_clear_all_live_previews() {
    // Remove all preview instances from the container
    for (const KeyValue<String, Node *> &kv : live_previews) {
        if (kv.value) {
            kv.value->queue_free();
        }
    }
    live_previews.clear();
}

void VisualGasicFormDesigner::_on_overlay_draw() {
    if (!overlay_node) return;

    // Draw selection handles and rubber band in form-local coordinates
    overlay_node->draw_set_transform(Vector2(FORM_PADDING_X, FORM_PADDING_Y));

    // Invisible-control indicators: draw hatched outline + badge for every
    // control with Visible=False so the designer clearly marks them.
    Ref<Font> overlay_font = overlay_node->get_theme_default_font();
    for (int i = 0; i < controls.size(); i++) {
        if (!controls[i].visible) {
            Rect2 r = controls[i].rect;
            // Dashed border
            Color inv_border(0.6, 0.6, 1.0, 0.5);
            overlay_node->draw_rect(r, inv_border, false, 1.0);
            // Diagonal hatch lines over the live preview area
            float step = 8.0f;
            Color hatch_color(0.5, 0.5, 0.7, 0.18);
            for (float d = -r.size.y; d < r.size.x; d += step) {
                Vector2 p1(MAX(r.position.x, r.position.x + d), r.position.y + MAX(0.0f, -d));
                Vector2 p2(MIN(r.position.x + r.size.x, r.position.x + d + r.size.y),
                           MIN(r.position.y + r.size.y, r.position.y + r.size.x - d));
                if (p1.x < r.position.x + r.size.x && p2.y > r.position.y) {
                    overlay_node->draw_line(p1, p2, hatch_color, 1.0);
                }
            }
            // "Invisible" badge at top-left
            if (overlay_font.is_valid()) {
                String badge = "Invisible";
                int badge_fs = 9;
                float tw = overlay_font->get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_fs).x;
                Rect2 badge_bg(r.position.x, r.position.y - 14, tw + 6, 14);
                overlay_node->draw_rect(badge_bg, Color(0.15, 0.15, 0.3, 0.8));
                overlay_node->draw_string(overlay_font, Vector2(r.position.x + 3, r.position.y - 3),
                                          badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_fs, Color(0.7, 0.7, 1.0, 0.9));
            }
        }
    }

    // ── Show Indexes overlay: numbered badges for control arrays + Game UI ──
    if (show_indexes && overlay_font.is_valid()) {
        int idx_fs = 10;
        Color idx_bg_color(0.1, 0.3, 0.6, 0.85);      // dark blue pill
        Color idx_text_color(1.0, 1.0, 1.0, 0.95);     // white text
        Color slot_idx_bg(0.0, 0.0, 0.0, 0.55);        // semi-transparent black for slot labels
        Color slot_idx_text(0.85, 0.9, 1.0, 0.9);      // light blue text for slot labels

        for (int i = 0; i < controls.size(); i++) {
            const FormControlItem &item = controls[i];
            Rect2 r = item.rect;

            // ── VB6 Control Array index badge — top-right pill "(N)" ──
            if (item.control_array_index >= 0) {
                String badge = "(" + String::num_int64(item.control_array_index) + ")";
                float tw = overlay_font->get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs).x;
                float bw = tw + 8;
                float bh = 16;
                // Position at top-right corner of the control
                Rect2 badge_rect(r.position.x + r.size.x - bw, r.position.y - bh, bw, bh);
                // Rounded pill background
                overlay_node->draw_rect(badge_rect, idx_bg_color);
                // Top corners rounded illusion (small rects to soften)
                overlay_node->draw_rect(Rect2(badge_rect.position.x + 1, badge_rect.position.y,
                                              bw - 2, 1), idx_bg_color);
                overlay_node->draw_string(overlay_font,
                                          Vector2(badge_rect.position.x + 4, badge_rect.position.y + bh - 4),
                                          badge, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs, idx_text_color);
            }

            // ── InventoryGrid: row,col labels in each slot ──
            if (item.type == "InventoryGrid") {
                int rows = 4, cols = 4, slot_sz = 48, spacing = 4;
                if (item.properties.has("Rows"))        rows    = MAX(int(item.properties["Rows"]), 1);
                if (item.properties.has("Columns"))     cols    = MAX(int(item.properties["Columns"]), 1);
                if (item.properties.has("SlotSize"))    slot_sz = MAX(int(item.properties["SlotSize"]), 16);
                if (item.properties.has("SlotSpacing")) spacing = MAX(int(item.properties["SlotSpacing"]), 0);

                float pad = 8.0f;
                float avail_w = r.size.x - pad * 2;
                float avail_h = r.size.y - pad * 2;
                float needed_w = cols * slot_sz + (cols - 1) * spacing;
                float needed_h = rows * slot_sz + (rows - 1) * spacing;
                float scale_f = 1.0f;
                if (needed_w > avail_w) scale_f = MIN(scale_f, avail_w / needed_w);
                if (needed_h > avail_h) scale_f = MIN(scale_f, avail_h / needed_h);
                float ssz = slot_sz * scale_f;
                float ssp = spacing * scale_f;
                float grid_w = cols * ssz + (cols - 1) * ssp;
                float grid_h = rows * ssz + (rows - 1) * ssp;
                float ox = r.position.x + pad + (avail_w - grid_w) * 0.5f;
                float oy = r.position.y + pad + (avail_h - grid_h) * 0.5f;

                int small_fs = MAX(7, (int)(idx_fs * scale_f));
                for (int row = 0; row < rows; row++) {
                    for (int col = 0; col < cols; col++) {
                        float sx = ox + col * (ssz + ssp);
                        float sy = oy + row * (ssz + ssp);
                        String lbl = String::num_int64(row) + "," + String::num_int64(col);
                        float lw = overlay_font->get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs).x;
                        // Center the label in the slot
                        float lx = sx + (ssz - lw) * 0.5f;
                        float ly = sy + (ssz + small_fs * 0.7f) * 0.5f;
                        // Dark background pill behind the text
                        Rect2 lbl_bg(lx - 2, ly - small_fs + 1, lw + 4, small_fs + 2);
                        overlay_node->draw_rect(lbl_bg, slot_idx_bg);
                        overlay_node->draw_string(overlay_font, Vector2(lx, ly),
                                                  lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, slot_idx_text);
                    }
                }
            }

            // ── GameMenu: sequential index next to each button ──
            if (item.type == "GameMenu") {
                PackedStringArray labels;
                {
                    String btn_raw;
                    if (item.properties.has("Buttons")) {
                        btn_raw = String(item.properties["Buttons"]);
                    } else if (item.properties.has("ButtonLabels")) {
                        btn_raw = String(item.properties["ButtonLabels"]);
                    }
                    if (!btn_raw.is_empty()) {
                        if (btn_raw.begins_with("PackedStringArray(") && btn_raw.ends_with(")")) {
                            btn_raw = btn_raw.substr(18, btn_raw.length() - 19);
                            btn_raw = btn_raw.replace("\"", "");
                        }
                        labels = btn_raw.split(",", false);
                        for (int li = 0; li < labels.size(); li++) {
                            labels.set(li, labels[li].strip_edges());
                        }
                    }
                }
                if (labels.is_empty()) {
                    labels.push_back("Resume");
                    labels.push_back("Settings");
                    labels.push_back("Quit");
                }
                int btn_count = labels.size();
                int btn_fs_prop = 18;
                if (item.properties.has("ButtonFontSize")) btn_fs_prop = vb6_pt_to_px(int(item.properties["ButtonFontSize"]));
                float btn_w = MIN(200.0f, r.size.x * 0.65f);
                float btn_h = MAX(32.0f, btn_fs_prop + 14.0f);
                float btn_sep = 10.0f;
                float vbox_sep = 20.0f;
                int title_fs = 28;
                if (item.properties.has("TitleFontSize")) title_fs = vb6_pt_to_px(int(item.properties["TitleFontSize"]));
                float title_block = title_fs + 4;
                float btns_block = btn_count * btn_h + (btn_count - 1) * btn_sep;
                float total_h = title_block + vbox_sep + btns_block;
                float cy = r.position.y + (r.size.y - total_h) * 0.5f;
                cy = MAX(cy, r.position.y + 10);
                float bx = r.position.x + (r.size.x - btn_w) * 0.5f;
                float btn_y = cy + title_block + vbox_sep;
                if (btn_y + btns_block > r.position.y + r.size.y - 8) {
                    btn_y = r.position.y + r.size.y - btns_block - 8;
                }

                for (int bi = 0; bi < btn_count; bi++) {
                    float bty = btn_y + bi * (btn_h + btn_sep);
                    // Index badge to the left of the button
                    String bi_str = String::num_int64(bi);
                    float biw = overlay_font->get_string_size(bi_str, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs).x;
                    float badge_w = biw + 8;
                    float badge_h = 16;
                    float badge_x = bx - badge_w - 4;
                    float badge_y = bty + (btn_h - badge_h) * 0.5f;
                    overlay_node->draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), idx_bg_color);
                    overlay_node->draw_string(overlay_font,
                                              Vector2(badge_x + 4, badge_y + badge_h - 4),
                                              bi_str, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs, idx_text_color);
                }
            }

            // ── RadialMenu: numbered circles for each wedge/item ──
            if (item.type == "RadialMenu") {
                int item_count = 6;
                if (item.properties.has("ItemCount")) item_count = MAX(int(item.properties["ItemCount"]), 1);
                float cx = r.position.x + r.size.x * 0.5f;
                float cy_rm = r.position.y + r.size.y * 0.5f;
                float radius = MIN(r.size.x, r.size.y) * 0.35f;

                for (int wi = 0; wi < item_count; wi++) {
                    float angle = (float)wi / (float)item_count * Math_TAU - Math_PI * 0.5f;
                    float wx = cx + Math::cos(angle) * radius;
                    float wy = cy_rm + Math::sin(angle) * radius;
                    // Draw a small numbered circle
                    float circle_r = 10.0f;
                    // Fill circle (approximated with rect for simplicity)
                    Rect2 circle_rect(wx - circle_r, wy - circle_r, circle_r * 2, circle_r * 2);
                    overlay_node->draw_rect(circle_rect, idx_bg_color);
                    String wi_str = String::num_int64(wi);
                    float wiw = overlay_font->get_string_size(wi_str, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs).x;
                    overlay_node->draw_string(overlay_font,
                                              Vector2(wx - wiw * 0.5f, wy + idx_fs * 0.35f),
                                              wi_str, HORIZONTAL_ALIGNMENT_LEFT, -1, idx_fs, idx_text_color);
                }
            }
        }
    }

    // Selection border + 8 resize handles for each selected control
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) {
            Rect2 r = controls[i].rect;
            overlay_node->draw_rect(r, color_selected, false, 2.0);
            for (int h = 0; h < 8; h++) {
                Rect2 hr = _get_handle_rect(r, (HandleID)h);
                overlay_node->draw_rect(hr, color_handle);
            }
        }
    }

    // Rubber band selection rectangle
    if (mode == MODE_SELECTING) {
        Rect2 rb = rubber_band_rect.abs();
        overlay_node->draw_rect(rb, color_rubber_band);
        overlay_node->draw_rect(rb, color_selected, false, 1.0);
    }

    overlay_node->draw_set_transform(Vector2());

    // Form resize handles (in widget space, outside the form body)
    for (int h = 0; h < 8; h++) {
        Rect2 hr = _get_form_handle_rect((HandleID)h);
        overlay_node->draw_rect(hr, form_handle_color);
    }
}

void VisualGasicFormDesigner::_draw_selection_handles(const Rect2 &rect) {
    for (int h = 0; h < 8; h++) {
        Rect2 hr = _get_handle_rect(rect, (HandleID)h);
        draw_rect(hr, color_handle);
    }
}

void VisualGasicFormDesigner::_draw_rubber_band() {
    if (mode != MODE_SELECTING) return;
    Rect2 rb = rubber_band_rect.abs();
    draw_rect(rb, color_rubber_band);
    draw_rect(rb, color_selected, false, 1.0);
}

void VisualGasicFormDesigner::_draw_toolbox_preview() {
    if (!show_preview && mode != MODE_PLACING) return;

    if (mode == MODE_PLACING) {
        // Draw the control being placed using WYSIWYG rendering with alpha
        Rect2 r = placing_rect.abs();
        if (r.size.x > MIN_CONTROL_SIZE || r.size.y > MIN_CONTROL_SIZE) {
            // Use a temporary item to render via the WYSIWYG path
            FormControlItem tmp;
            tmp.type = placing_tool_class;
            tmp.name = placing_tool_class;
            tmp.text = placing_tool_class;
            tmp.rect = r;
            tmp.selected = false;
            tmp.visible = true;
            _draw_control(tmp, -1);
            // Semi-transparent overlay to show it's a preview
            draw_rect(r, Color(0.5, 0.5, 1.0, 0.15));
            draw_rect(r, color_selected, false, 2.0);
        } else if (r.size.x > 0 || r.size.y > 0) {
            // Too small for WYSIWYG — just draw a simple outline
            draw_rect(r, Color(0.5, 0.5, 1.0, 0.3));
            draw_rect(r, color_selected, false, 1.0);
        }
        return;
    }

    if (!show_preview) return;

    Vector2 sz = _default_size_for_type(preview_type);
    Rect2 preview_rect(preview_pos - sz * 0.5, sz);

    // Use WYSIWYG rendering for hover preview too
    FormControlItem tmp;
    tmp.type = preview_type;
    tmp.name = preview_type;
    tmp.text = preview_type;
    tmp.rect = preview_rect;
    tmp.selected = false;
    tmp.visible = true;
    _draw_control(tmp, -1);
    // Semi-transparent overlay
    draw_rect(preview_rect, Color(0.5, 0.5, 1.0, 0.2));
    draw_rect(preview_rect, Color(0, 0, 0.6, 0.7), false, 1.0);
}

// =============================================================================
// Hit testing
// =============================================================================

int VisualGasicFormDesigner::_hit_test(const Vector2 &p_pos) const {
    // Back-to-front (topmost first)
    // Design-time: invisible controls are still selectable so the user
    // can click them and change their properties (e.g. make them visible again).
    for (int i = controls.size() - 1; i >= 0; i--) {
        if (controls[i].rect.has_point(p_pos)) {
            return i;
        }
    }
    return -1;
}

VisualGasicFormDesigner::HandleID VisualGasicFormDesigner::_hit_test_handle(const Vector2 &p_pos) const {
    // Only test handles on single-selected controls
    for (int i = 0; i < controls.size(); i++) {
        if (!controls[i].selected) continue;
        for (int h = 0; h < 8; h++) {
            Rect2 hr = _get_handle_rect(controls[i].rect, (HandleID)h);
            if (hr.has_point(p_pos)) {
                drag_control_index = i; // Ugly mutable trick, but clean alternative is out param
                return (HandleID)h;
            }
        }
    }
    return HANDLE_NONE;
}

Rect2 VisualGasicFormDesigner::_get_handle_rect(const Rect2 &r, HandleID h) const {
    Vector2 pos;
    switch (h) {
        case HANDLE_TL: pos = r.position; break;
        case HANDLE_TM: pos = Vector2(r.position.x + r.size.x * 0.5f, r.position.y); break;
        case HANDLE_TR: pos = Vector2(r.position.x + r.size.x, r.position.y); break;
        case HANDLE_ML: pos = Vector2(r.position.x, r.position.y + r.size.y * 0.5f); break;
        case HANDLE_MR: pos = Vector2(r.position.x + r.size.x, r.position.y + r.size.y * 0.5f); break;
        case HANDLE_BL: pos = Vector2(r.position.x, r.position.y + r.size.y); break;
        case HANDLE_BM: pos = Vector2(r.position.x + r.size.x * 0.5f, r.position.y + r.size.y); break;
        case HANDLE_BR: pos = r.position + r.size; break;
        default: return Rect2();
    }
    return Rect2(pos - Vector2(HANDLE_HALF, HANDLE_HALF), Vector2(HANDLE_SIZE, HANDLE_SIZE));
}

// =============================================================================
// Form-level resize handle geometry and hit testing
// =============================================================================

Rect2 VisualGasicFormDesigner::_get_form_handle_rect(HandleID h) const {
    // Form body in screen coords: starts at (FORM_PADDING_X, FORM_PADDING_Y)
    float fx = FORM_PADDING_X;
    float fy = FORM_PADDING_Y;
    float fw = (float)form_size.x;
    float fh = (float)form_size.y;

    Vector2 pos;
    switch (h) {
        case HANDLE_TL: pos = Vector2(fx, fy); break;
        case HANDLE_TM: pos = Vector2(fx + fw * 0.5f, fy); break;
        case HANDLE_TR: pos = Vector2(fx + fw, fy); break;
        case HANDLE_ML: pos = Vector2(fx, fy + fh * 0.5f); break;
        case HANDLE_MR: pos = Vector2(fx + fw, fy + fh * 0.5f); break;
        case HANDLE_BL: pos = Vector2(fx, fy + fh); break;
        case HANDLE_BM: pos = Vector2(fx + fw * 0.5f, fy + fh); break;
        case HANDLE_BR: pos = Vector2(fx + fw, fy + fh); break;
        default: return Rect2();
    }
    return Rect2(pos - Vector2(FORM_HANDLE_HALF, FORM_HANDLE_HALF), Vector2(FORM_HANDLE_SIZE, FORM_HANDLE_SIZE));
}

VisualGasicFormDesigner::HandleID VisualGasicFormDesigner::_hit_test_form_handle(const Vector2 &p_pos) const {
    for (int h = 0; h < 8; h++) {
        Rect2 hr = _get_form_handle_rect((HandleID)h);
        if (hr.has_point(p_pos)) {
            return (HandleID)h;
        }
    }
    return HANDLE_NONE;
}

// =============================================================================
// Form size get/set
// =============================================================================

void VisualGasicFormDesigner::set_form_size(const Vector2i &p_size) {
    form_size = p_size;
    if (form_size.x < 100) form_size.x = 100;
    if (form_size.y < 60) form_size.y = 60;
    if (preview_container) preview_container->set_size(Vector2(form_size));
    _update_min_size();
    _mark_dirty();
    queue_redraw();
    emit_signal("form_resized", form_size);
}

Vector2i VisualGasicFormDesigner::get_form_size() const {
    return form_size;
}

String VisualGasicFormDesigner::get_status_text() const {
    // Build a VB6-style status string
    int sel_count = get_selected_count();
    if (sel_count == 1) {
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].selected) {
                return controls[i].name + String(" - ") +
                    String::num_int64((int)controls[i].rect.position.x) + String(", ") +
                    String::num_int64((int)controls[i].rect.position.y) + String("  ") +
                    String::num_int64((int)controls[i].rect.size.x) + String(" x ") +
                    String::num_int64((int)controls[i].rect.size.y);
            }
        }
    } else if (sel_count > 1) {
        return String::num_int64(sel_count) + String(" controls selected");
    }
    return String::num_int64(form_size.x) + String(" x ") + String::num_int64(form_size.y);
}

Vector2 VisualGasicFormDesigner::get_mouse_canvas_pos() const {
    return mouse_current_pos - Vector2(FORM_PADDING_X, FORM_PADDING_Y);
}

// =============================================================================
// Mouse input
// =============================================================================

void VisualGasicFormDesigner::_gui_input(const Ref<InputEvent> &p_event) {
    Ref<InputEventMouseButton> mb = p_event;
    Ref<InputEventMouseMotion> mm = p_event;
    Ref<InputEventKey> key = p_event;

    if (mb.is_valid()) {
        if (mb->is_pressed()) {
            if (mb->get_button_index() == MOUSE_BUTTON_RIGHT) {
                // Right-click: hit-test and emit context menu signal
                Vector2 screen_pos = mb->get_position();
                Vector2 pos = screen_pos - Vector2(FORM_PADDING_X, FORM_PADDING_Y);
                int idx = _hit_test(pos);
                if (idx >= 0) {
                    // Select the right-clicked control
                    select_none();
                    controls.write[idx].selected = true;
                    queue_redraw();
                    emit_signal("control_selected", idx);
                }
                emit_signal("control_right_clicked", idx, screen_pos + get_global_position());
                accept_event();
            } else {
                _on_mouse_down(mb);
            }
        } else {
            _on_mouse_up(mb);
        }
    }

    if (mm.is_valid()) {
        _on_mouse_motion(mm);
    }

    // Keyboard shortcuts
    if (key.is_valid() && key->is_pressed()) {
        if (key->get_keycode() == KEY_DELETE || key->get_keycode() == KEY_BACKSPACE) {
            remove_selected();
            accept_event();
        }
        if (key->is_ctrl_pressed()) {
            switch (key->get_keycode()) {
                case KEY_A: select_all(); accept_event(); break;
                case KEY_Z: undo(); accept_event(); break;
                case KEY_Y: redo(); accept_event(); break;
                case KEY_X: cut(); accept_event(); break;
                case KEY_C: copy(); accept_event(); break;
                case KEY_V: paste(); accept_event(); break;
                case KEY_S: save_form(); accept_event(); break;
                default: break;
            }
        }
    }
}

void VisualGasicFormDesigner::_on_mouse_down(const Ref<InputEventMouseButton> &p_event) {
    if (p_event->get_button_index() != MOUSE_BUTTON_LEFT) return;

    Vector2 screen_pos = p_event->get_position();
    // Convert to form-local coordinates (account for FORM_PADDING offset)
    Vector2 pos = screen_pos - Vector2(FORM_PADDING_X, FORM_PADDING_Y);
    mouse_down_pos = pos;
    mouse_current_pos = screen_pos;

    // --- Check form resize handles first (in screen coordinates) ---
    HandleID fh = _hit_test_form_handle(screen_pos);
    if (fh != HANDLE_NONE) {
        mode = MODE_FORM_RESIZING;
        form_resize_handle = fh;
        original_form_size = form_size;
        form_resize_mouse_start = screen_pos;
        accept_event();
        return;
    }

    // --- Click-to-place mode: start drawing the new control rect ---
    // BUT: double-clicks on existing controls should always open code editor,
    // even if a tool is active — cancel the tool and handle the double-click.
    if (!placing_tool_class.is_empty()) {
        if (p_event->is_double_click()) {
            int idx = _hit_test(pos);
            if (idx >= 0) {
                // Cancel the active tool and open the code editor instead
                placing_tool_class = "";
                placing_tool_scene_path = "";
                emit_signal("control_double_clicked", idx);
                return;
            }
        }
        mode = MODE_PLACING;
        placing_rect = Rect2(_snap(pos), Vector2(0, 0));
        accept_event();
        return;
    }

    // Double-click → signal
    if (p_event->is_double_click()) {
        int idx = _hit_test(pos);
        if (idx >= 0) {
            emit_signal("control_double_clicked", idx);
            return;
        }
    }

    // Check resize handles first (only if something is selected)
    int handle_ctrl_idx = -1;
    HandleID h = _hit_test_handle(pos);
    if (h != HANDLE_NONE) {
        handle_ctrl_idx = drag_control_index; // Set by _hit_test_handle
        mode = MODE_RESIZING;
        active_handle = h;
        original_rect = controls[handle_ctrl_idx].rect;
        accept_event();
        return;
    }

    // Hit test controls
    int idx = _hit_test(pos);
    if (idx >= 0) {
        // Shift-click toggles selection
        if (p_event->is_shift_pressed()) {
            controls.write[idx].selected = !controls[idx].selected;
        } else if (!controls[idx].selected) {
            // Click on unselected → clear others, select this
            select_none();
            controls.write[idx].selected = true;
        }
        // Start moving
        mode = MODE_MOVING;
        drag_control_index = idx;
        drag_offset = pos - controls[idx].rect.position;

        emit_signal("control_selected", idx);
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        accept_event();
    } else {
        // Click on empty space → start rubber-band
        if (!p_event->is_shift_pressed()) {
            select_none();
        }
        mode = MODE_SELECTING;
        rubber_band_rect = Rect2(pos, Vector2());
        emit_signal("control_deselected");
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        accept_event();
    }
}

void VisualGasicFormDesigner::_on_mouse_up(const Ref<InputEventMouseButton> &p_event) {
    if (p_event->get_button_index() != MOUSE_BUTTON_LEFT) return;

    if (mode == MODE_FORM_RESIZING) {
        form_resize_handle = HANDLE_NONE;
        mode = MODE_NONE;
        emit_signal("form_resized", form_size);
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        accept_event();
        return;
    }

    if (mode == MODE_PLACING) {
        // Finalize click-to-place: create the control at the drawn rect
        Rect2 r = placing_rect.abs();
        Vector2 def_size = _default_size_for_type(placing_tool_class);
        // If user just clicked without dragging, use default size
        if (r.size.x < MIN_CONTROL_SIZE || r.size.y < MIN_CONTROL_SIZE) {
            r.size = def_size;
        }
        int idx = add_control(placing_tool_class, placing_tool_scene_path, r.position, r.size);
        // After placing, reset to pointer (VB6 behavior: one placement then back to pointer)
        clear_active_tool();
        mode = MODE_NONE;
        queue_redraw();
        accept_event();
        return;
    }

    if (mode == MODE_SELECTING) {
        // Finalize rubber-band selection
        Rect2 rb = rubber_band_rect.abs();
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].rect.intersects(rb)) {
                controls.write[i].selected = true;
            }
        }
    }

    if (mode == MODE_MOVING) {
        // Push undo for the move
        // (We captured original positions at mouse_down already)
    }

    mode = MODE_NONE;
    active_handle = HANDLE_NONE;
    queue_redraw();
    accept_event();
}

void VisualGasicFormDesigner::_on_mouse_motion(const Ref<InputEventMouseMotion> &p_event) {
    Vector2 screen_pos = p_event->get_position();
    mouse_current_pos = screen_pos;
    // Form-local coordinates
    Vector2 pos = screen_pos - Vector2(FORM_PADDING_X, FORM_PADDING_Y);

    // Update toolbox preview position (in form-local coords)
    if (show_preview) {
        preview_pos = pos;
        queue_redraw();
    }

    // Form resize mode
    if (mode == MODE_FORM_RESIZING) {
        Vector2 delta = screen_pos - form_resize_mouse_start;
        Vector2i new_size = original_form_size;

        switch (form_resize_handle) {
            case HANDLE_MR:
                new_size.x = original_form_size.x + (int)delta.x;
                break;
            case HANDLE_BM:
                new_size.y = original_form_size.y + (int)delta.y;
                break;
            case HANDLE_BR:
                new_size.x = original_form_size.x + (int)delta.x;
                new_size.y = original_form_size.y + (int)delta.y;
                break;
            case HANDLE_ML:
                new_size.x = original_form_size.x - (int)delta.x;
                break;
            case HANDLE_TM:
                new_size.y = original_form_size.y - (int)delta.y;
                break;
            case HANDLE_TL:
                new_size.x = original_form_size.x - (int)delta.x;
                new_size.y = original_form_size.y - (int)delta.y;
                break;
            case HANDLE_TR:
                new_size.x = original_form_size.x + (int)delta.x;
                new_size.y = original_form_size.y - (int)delta.y;
                break;
            case HANDLE_BL:
                new_size.x = original_form_size.x - (int)delta.x;
                new_size.y = original_form_size.y + (int)delta.y;
                break;
            default: break;
        }

        // Snap to grid
        if (snap_enabled) {
            new_size.x = ((new_size.x + grid_size / 2) / grid_size) * grid_size;
            new_size.y = ((new_size.y + grid_size / 2) / grid_size) * grid_size;
        }

        // Enforce minimum
        if (new_size.x < 100) new_size.x = 100;
        if (new_size.y < 60) new_size.y = 60;

        form_size = new_size;
        if (preview_container) preview_container->set_size(Vector2(form_size));
        _update_min_size();
        _mark_dirty();
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        return;
    }

    if (mode == MODE_SELECTING) {
        rubber_band_rect = Rect2(mouse_down_pos, pos - mouse_down_pos);
        queue_redraw();
        return;
    }

    if (mode == MODE_PLACING) {
        // Update the placing rect as user drags
        Vector2 snapped = _snap(pos);
        placing_rect = Rect2(placing_rect.position, snapped - placing_rect.position);
        queue_redraw();
        return;
    }

    if (mode == MODE_MOVING) {
        Vector2 delta = _snap(pos - drag_offset) - controls[drag_control_index].rect.position;
        // Move all selected controls by the same delta
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].selected) {
                controls.write[i].rect.position += delta;
                _sync_live_preview_rect(i);
            }
        }
        _mark_dirty();
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        return;
    }

    if (mode == MODE_RESIZING && drag_control_index >= 0) {
        Vector2 snapped = _snap(pos);
        Rect2 r = original_rect;

        switch (active_handle) {
            case HANDLE_TL:
                r.position = snapped;
                r.size = (original_rect.position + original_rect.size) - snapped;
                break;
            case HANDLE_TM:
                r.position.y = snapped.y;
                r.size.y = (original_rect.position.y + original_rect.size.y) - snapped.y;
                break;
            case HANDLE_TR:
                r.position.y = snapped.y;
                r.size.x = snapped.x - original_rect.position.x;
                r.size.y = (original_rect.position.y + original_rect.size.y) - snapped.y;
                break;
            case HANDLE_ML:
                r.position.x = snapped.x;
                r.size.x = (original_rect.position.x + original_rect.size.x) - snapped.x;
                break;
            case HANDLE_MR:
                r.size.x = snapped.x - original_rect.position.x;
                break;
            case HANDLE_BL:
                r.position.x = snapped.x;
                r.size.x = (original_rect.position.x + original_rect.size.x) - snapped.x;
                r.size.y = snapped.y - original_rect.position.y;
                break;
            case HANDLE_BM:
                r.size.y = snapped.y - original_rect.position.y;
                break;
            case HANDLE_BR:
                r.size = snapped - original_rect.position;
                break;
            default: break;
        }

        // Enforce minimum size
        if (r.size.x < MIN_CONTROL_SIZE) r.size.x = MIN_CONTROL_SIZE;
        if (r.size.y < MIN_CONTROL_SIZE) r.size.y = MIN_CONTROL_SIZE;

        controls.write[drag_control_index].rect = r;
        _sync_live_preview_rect(drag_control_index);
        _mark_dirty();
        emit_signal("status_changed", get_status_text());
        queue_redraw();
        return;
    }
}

// =============================================================================
// Drag-drop from toolbox
// =============================================================================

bool VisualGasicFormDesigner::_can_drop_data(const Vector2 &p_point, const Variant &p_data) const {
    if (p_data.get_type() == Variant::DICTIONARY) {
        Dictionary data = p_data;
        if (data.has("type") && String(data["type"]) == "vg_control") {
            return true;
        }
        // Accept .tscn files dragged from Godot's FileSystem dock
        if (data.has("type") && String(data["type"]) == "files") {
            PackedStringArray files = data.get("files", PackedStringArray());
            for (int i = 0; i < files.size(); i++) {
                if (files[i].ends_with(".tscn")) {
                    return true;
                }
            }
        }
    }
    return false;
}

void VisualGasicFormDesigner::_drop_data(const Vector2 &p_point, const Variant &p_data) {
    Dictionary data = p_data;

    // ── Handle .tscn file drop from FileSystem dock ──
    if (data.has("type") && String(data["type"]) == "files") {
        PackedStringArray files = data.get("files", PackedStringArray());
        for (int i = 0; i < files.size(); i++) {
            if (files[i].ends_with(".tscn")) {
                String scene_path = files[i];
                String name = scene_path.get_file().get_basename();

                // Register as custom type if not already known
                if (!custom_control_types.has(name)) {
                    CustomControlDef def;
                    def.scene_path = scene_path;
                    def.default_size = Vector2(100, 60);
                    def.design_color = Color(0.7, 0.8, 0.9);
                    custom_control_types[name] = def;
                }

                Vector2 sz = _default_size_for_type(name);
                Vector2 form_pos = p_point - Vector2(FORM_PADDING_X, FORM_PADDING_Y);
                Vector2 pos = _snap(form_pos - sz * 0.5);

                int idx = add_control(name, scene_path, pos, sz);

                // Emit signal so GDScript can auto-register in Components config
                emit_signal("scene_file_dropped", scene_path, name);

                UtilityFunctions::print("FormDesigner: Dropped scene file '", name, "' at ", pos);
                break;  // Place only the first .tscn
            }
        }
        show_preview = false;
        queue_redraw();
        return;
    }

    // ── Original vg_control handling ──
    String type = data.get("class_name", "Control");
    String scene_path = data.get("scene_path", "");

    Vector2 sz = _default_size_for_type(type);
    // Convert screen coords to form-local coords
    Vector2 form_pos = p_point - Vector2(FORM_PADDING_X, FORM_PADDING_Y);
    Vector2 pos = _snap(form_pos - sz * 0.5);

    int idx = add_control(type, scene_path, pos, sz);

    // Consume the Engine meta so other paths don't also fire
    if (Engine::get_singleton()->has_meta("_vg_active_drag")) {
        Engine::get_singleton()->remove_meta("_vg_active_drag");
    }

    show_preview = false;
    queue_redraw();

    UtilityFunctions::print("FormDesigner: Dropped ", controls[idx].name, " at ", pos);
}

// =============================================================================
// Snap
// =============================================================================

Vector2 VisualGasicFormDesigner::_snap(const Vector2 &p_pos) const {
    if (!snap_enabled || grid_size <= 1) return p_pos;
    return Vector2(
        Math::round(p_pos.x / grid_size) * grid_size,
        Math::round(p_pos.y / grid_size) * grid_size
    );
}

// =============================================================================
// Control manipulation
// =============================================================================

int VisualGasicFormDesigner::add_control(const String &p_type, const String &p_scene_path, const Vector2 &p_position, const Vector2 &p_size) {
    FormControlItem item;
    // When placed from a prototype scene, use the scene basename as the type.
    // This ensures RadioButton.tscn → type "RadioButton", StatusBar.tscn → "StatusBar", etc.
    // instead of the generic Godot class name ("CheckBox", "PanelContainer").
    if (!p_scene_path.is_empty()) {
        String basename = p_scene_path.get_file().get_basename();
        item.type = basename;
    } else {
        item.type = p_type;
    }
    item.scene_path = p_scene_path;
    item.name = _make_unique_name(item.type);
    item.rect.position = p_position;
    item.rect.size = (p_size.x > 0 && p_size.y > 0) ? p_size : _default_size_for_type(item.type);

    // MenuBar auto-docks to top of form, full width
    if (item.type == "MenuBar") {
        item.rect.position = Vector2(0, 0);
        item.rect.size = Vector2(form_size.x, 24);
    }
    // StatusBar auto-docks to bottom of form, full width
    if (item.type == "StatusBar") {
        item.rect.position = Vector2(0, form_size.y - 24);
        item.rect.size = Vector2(form_size.x, 24);
    }
    // Toolbar auto-docks below menu bar, full width
    if (item.type == "Toolbar") {
        // Place below any existing MenuBar
        float top = 0;
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].type == "MenuBar") {
                top = controls[i].rect.position.y + controls[i].rect.size.y;
                break;
            }
        }
        item.rect.position = Vector2(0, top);
        item.rect.size = Vector2(form_size.x, 32);
    }

    // Set default text for text-bearing controls
    if (item.type == "Button" || item.type == "Label" || item.type == "CheckBox" ||
        item.type == "OptionButton" || item.type == "RadioButton") {
        item.text = item.name;
    }

    // Initialize full VB6 default properties
    _init_vb6_defaults(item);

    controls.push_back(item);
    int idx = controls.size() - 1;

    // Create live preview scene instance
    _create_live_preview(idx);

    // Push undo
    FormUndoAction action;
    action.type = FormUndoAction::ACTION_ADD;
    action.control_index = idx;
    action.after_state = item;
    _push_undo(action);

    // Select it
    select_none();
    controls.write[idx].selected = true;

    _mark_dirty();
    queue_redraw();
    emit_signal("control_selected", idx);
    return idx;
}

void VisualGasicFormDesigner::remove_selected() {
    // Collect indices to remove (reverse order for safe removal)
    Vector<int> to_remove;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) {
            to_remove.push_back(i);
        }
    }
    if (to_remove.is_empty()) return;

    // Push undo for each removal
    FormUndoAction multi;
    multi.type = FormUndoAction::ACTION_MULTI;
    for (int i = to_remove.size() - 1; i >= 0; i--) {
        FormUndoAction sub;
        sub.type = FormUndoAction::ACTION_DELETE;
        sub.control_index = to_remove[i];
        sub.before_state = controls[to_remove[i]];
        multi.sub_actions.push_back(sub);
    }
    _push_undo(multi);

    // Destroy live previews for removed controls
    for (int i = to_remove.size() - 1; i >= 0; i--) {
        _destroy_live_preview(controls[to_remove[i]].name);
    }

    // Remove in reverse order
    for (int i = to_remove.size() - 1; i >= 0; i--) {
        controls.remove_at(to_remove[i]);
    }

    _mark_dirty();
    queue_redraw();
    emit_signal("control_deselected");
}

void VisualGasicFormDesigner::select_all() {
    for (int i = 0; i < controls.size(); i++) {
        controls.write[i].selected = true;
    }
    queue_redraw();
}

void VisualGasicFormDesigner::select_none() {
    for (int i = 0; i < controls.size(); i++) {
        controls.write[i].selected = false;
    }
    queue_redraw();
}

int VisualGasicFormDesigner::get_selected_count() const {
    int count = 0;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) count++;
    }
    return count;
}

PackedStringArray VisualGasicFormDesigner::get_selected_names() const {
    PackedStringArray names;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) {
            names.push_back(controls[i].name);
        }
    }
    return names;
}

void VisualGasicFormDesigner::set_control_property(int p_index, const String &p_key, const Variant &p_value) {
    if (p_index < 0 || p_index >= controls.size()) return;

    // Snapshot before
    FormUndoAction action;
    action.type = FormUndoAction::ACTION_PROPERTY;
    action.control_index = p_index;
    action.before_state = controls[p_index];

    // Apply well-known properties
    if (p_key == "name") {
        controls.write[p_index].name = p_value;
    } else if (p_key == "text") {
        controls.write[p_index].text = p_value;
    } else if (p_key == "x") {
        controls.write[p_index].rect.position.x = p_value;
    } else if (p_key == "y") {
        controls.write[p_index].rect.position.y = p_value;
    } else if (p_key == "width") {
        controls.write[p_index].rect.size.x = p_value;
    } else if (p_key == "height") {
        controls.write[p_index].rect.size.y = p_value;
    } else if (p_key == "visible") {
        controls.write[p_index].visible = p_value;
    } else if (p_key == "scene_path") {
        controls.write[p_index].scene_path = p_value;
    } else if (p_key == "control_array_index") {
        controls.write[p_index].control_array_index = p_value;
    } else {
        // Store in generic property bag
        controls.write[p_index].properties[p_key] = p_value;
    }

    action.after_state = controls[p_index];
    _push_undo(action);

    // Sync live preview
    _sync_live_preview_rect(p_index);
    _sync_live_preview_properties(p_index);

    _mark_dirty();
    queue_redraw();
    emit_signal("form_modified");
}

Variant VisualGasicFormDesigner::get_control_property(int p_index, const String &p_key) const {
    if (p_index < 0 || p_index >= controls.size()) return Variant();

    const FormControlItem &item = controls[p_index];
    if (p_key == "name") return item.name;
    if (p_key == "type") return item.type;
    if (p_key == "text") return item.text;
    if (p_key == "x") return item.rect.position.x;
    if (p_key == "y") return item.rect.position.y;
    if (p_key == "width") return item.rect.size.x;
    if (p_key == "height") return item.rect.size.y;
    if (p_key == "visible") return item.visible;
    if (p_key == "control_array_index") return item.control_array_index;
    if (item.properties.has(p_key)) return item.properties[p_key];
    return Variant();
}

int VisualGasicFormDesigner::get_control_count() const {
    return controls.size();
}

Dictionary VisualGasicFormDesigner::get_control_info(int p_index) const {
    Dictionary info;
    if (p_index < 0 || p_index >= controls.size()) return info;
    const FormControlItem &item = controls[p_index];
    info["name"] = item.name;
    info["type"] = item.type;
    info["scene_path"] = item.scene_path;
    info["x"] = item.rect.position.x;
    info["y"] = item.rect.position.y;
    info["width"] = item.rect.size.x;
    info["height"] = item.rect.size.y;
    info["text"] = item.text;
    info["selected"] = item.selected;
    info["visible"] = item.visible;
    info["control_array_index"] = item.control_array_index;
    info["properties"] = item.properties;
    return info;
}

// =============================================================================
// Grid properties
// =============================================================================

void VisualGasicFormDesigner::set_grid_size(int p_size) { grid_size = MAX(1, p_size); queue_redraw(); }
int  VisualGasicFormDesigner::get_grid_size() const { return grid_size; }
void VisualGasicFormDesigner::set_grid_visible(bool p_visible) { grid_visible = p_visible; queue_redraw(); }
bool VisualGasicFormDesigner::get_grid_visible() const { return grid_visible; }
void VisualGasicFormDesigner::set_snap_enabled(bool p_enabled) { snap_enabled = p_enabled; }
bool VisualGasicFormDesigner::get_snap_enabled() const { return snap_enabled; }

void VisualGasicFormDesigner::set_show_indexes(bool p_show) {
    show_indexes = p_show;
    queue_redraw();
    if (overlay_node) overlay_node->queue_redraw();
}
bool VisualGasicFormDesigner::get_show_indexes() const { return show_indexes; }

// =============================================================================
// Alignment
// =============================================================================

void VisualGasicFormDesigner::align_left() {
    float min_x = 999999;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) min_x = MIN(min_x, controls[i].rect.position.x);
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.x = min_x;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::align_right() {
    float max_r = -999999;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) max_r = MAX(max_r, controls[i].rect.position.x + controls[i].rect.size.x);
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.x = max_r - controls[i].rect.size.x;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::align_top() {
    float min_y = 999999;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) min_y = MIN(min_y, controls[i].rect.position.y);
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.y = min_y;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::align_bottom() {
    float max_b = -999999;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) max_b = MAX(max_b, controls[i].rect.position.y + controls[i].rect.size.y);
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.y = max_b - controls[i].rect.size.y;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::align_center_h() {
    if (get_selected_count() < 2) return;
    float total = 0; int count = 0;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) { total += controls[i].rect.position.x + controls[i].rect.size.x * 0.5f; count++; }
    }
    float center = total / count;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.x = center - controls[i].rect.size.x * 0.5f;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::align_center_v() {
    if (get_selected_count() < 2) return;
    float total = 0; int count = 0;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) { total += controls[i].rect.position.y + controls[i].rect.size.y * 0.5f; count++; }
    }
    float center = total / count;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.position.y = center - controls[i].rect.size.y * 0.5f;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::make_same_width() {
    if (get_selected_count() < 2) return;
    float w = 0;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) { w = controls[i].rect.size.x; break; }
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.size.x = w;
    }
    _mark_dirty(); queue_redraw();
}

void VisualGasicFormDesigner::make_same_height() {
    if (get_selected_count() < 2) return;
    float h = 0;
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) { h = controls[i].rect.size.y; break; }
    }
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) controls.write[i].rect.size.y = h;
    }
    _mark_dirty(); queue_redraw();
}

// =============================================================================
// Undo / Redo
// =============================================================================

void VisualGasicFormDesigner::_push_undo(const FormUndoAction &action) {
    undo_stack.push_back(action);
    if (undo_stack.size() > MAX_UNDO) {
        undo_stack.remove_at(0);
    }
    redo_stack.clear(); // New action invalidates redo
}

void VisualGasicFormDesigner::undo() {
    if (undo_stack.is_empty()) return;
    FormUndoAction action = undo_stack[undo_stack.size() - 1];
    undo_stack.remove_at(undo_stack.size() - 1);

    switch (action.type) {
        case FormUndoAction::ACTION_ADD:
            if (action.control_index < controls.size()) {
                controls.remove_at(action.control_index);
            }
            break;
        case FormUndoAction::ACTION_DELETE:
            if (action.control_index <= controls.size()) {
                controls.insert(action.control_index, action.before_state);
            }
            break;
        case FormUndoAction::ACTION_MOVE:
        case FormUndoAction::ACTION_RESIZE:
        case FormUndoAction::ACTION_PROPERTY:
            if (action.control_index < controls.size()) {
                controls.write[action.control_index] = action.before_state;
            }
            break;
        case FormUndoAction::ACTION_MULTI:
            // Undo sub-actions in reverse
            for (int i = action.sub_actions.size() - 1; i >= 0; i--) {
                FormUndoAction sub = action.sub_actions[i];
                if (sub.type == FormUndoAction::ACTION_DELETE && sub.control_index <= controls.size()) {
                    controls.insert(sub.control_index, sub.before_state);
                }
            }
            break;
    }

    redo_stack.push_back(action);
    _rebuild_all_live_previews();
    _mark_dirty();
    queue_redraw();
}

void VisualGasicFormDesigner::redo() {
    if (redo_stack.is_empty()) return;
    FormUndoAction action = redo_stack[redo_stack.size() - 1];
    redo_stack.remove_at(redo_stack.size() - 1);

    switch (action.type) {
        case FormUndoAction::ACTION_ADD:
            if (action.control_index <= controls.size()) {
                controls.insert(action.control_index, action.after_state);
            }
            break;
        case FormUndoAction::ACTION_DELETE:
            if (action.control_index < controls.size()) {
                controls.remove_at(action.control_index);
            }
            break;
        case FormUndoAction::ACTION_MOVE:
        case FormUndoAction::ACTION_RESIZE:
        case FormUndoAction::ACTION_PROPERTY:
            if (action.control_index < controls.size()) {
                controls.write[action.control_index] = action.after_state;
            }
            break;
        case FormUndoAction::ACTION_MULTI:
            for (int i = 0; i < action.sub_actions.size(); i++) {
                FormUndoAction sub = action.sub_actions[i];
                if (sub.type == FormUndoAction::ACTION_DELETE && sub.control_index < controls.size()) {
                    controls.remove_at(sub.control_index);
                }
            }
            break;
    }

    undo_stack.push_back(action);
    _rebuild_all_live_previews();
    _mark_dirty();
    queue_redraw();
}

bool VisualGasicFormDesigner::can_undo() const { return !undo_stack.is_empty(); }
bool VisualGasicFormDesigner::can_redo() const { return !redo_stack.is_empty(); }

// =============================================================================
// Clipboard
// =============================================================================

void VisualGasicFormDesigner::cut() {
    copy();
    remove_selected();
}

void VisualGasicFormDesigner::copy() {
    clipboard.clear();
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) {
            clipboard.push_back(controls[i]);
        }
    }
}

void VisualGasicFormDesigner::paste() {
    if (clipboard.is_empty()) return;

    select_none();
    Vector2 offset(grid_size, grid_size); // Offset pasted controls slightly

    for (int i = 0; i < clipboard.size(); i++) {
        FormControlItem item = clipboard[i];

        // VB6-style control array detection:
        // If a control with the same base name already exists, create a control array.
        // The original becomes index 0, and the paste gets the next available index.
        String base_name = item.name;
        int existing_idx = -1;
        for (int c = 0; c < controls.size(); c++) {
            if (controls[c].name == base_name) {
                existing_idx = c;
                break;
            }
        }

        if (existing_idx >= 0) {
            // Create control array: set original to index 0 if not yet in an array
            if (controls.write[existing_idx].control_array_index < 0) {
                controls.write[existing_idx].control_array_index = 0;
            }
            // Find the next available index in the array
            int max_idx = 0;
            for (int c = 0; c < controls.size(); c++) {
                if (controls[c].name == base_name && controls[c].control_array_index > max_idx) {
                    max_idx = controls[c].control_array_index;
                }
            }
            item.control_array_index = max_idx + 1;
            // Keep the same name (VB6 control arrays share the base name)
        } else {
            item.name = _make_unique_name(item.type);
        }

        item.rect.position += offset;
        item.selected = true;
        if (!item.text.is_empty() && item.control_array_index < 0) {
            item.text = item.name;
        }
        controls.push_back(item);
        _create_live_preview(controls.size() - 1);
    }

    _mark_dirty();
    queue_redraw();
    emit_signal("form_modified");
}

// =============================================================================
// Custom tool extensibility
// =============================================================================

void VisualGasicFormDesigner::register_custom_control_type(const String &p_type_name, const String &p_scene_path,
                                                            const Vector2 &p_default_size, const Color &p_design_color) {
    CustomControlDef def;
    def.scene_path = p_scene_path;
    def.default_size = p_default_size;
    def.design_color = p_design_color;
    custom_control_types[p_type_name] = def;
    UtilityFunctions::print("FormDesigner: Registered custom control type '", p_type_name, "'");
}

void VisualGasicFormDesigner::set_control_preview_texture(const String &p_type_name, const Ref<Texture2D> &p_texture) {
    if (p_texture.is_valid()) {
        control_preview_textures[p_type_name] = p_texture;
        queue_redraw();
        UtilityFunctions::print("FormDesigner: Set preview texture for '", p_type_name, "' (", p_texture->get_width(), "x", p_texture->get_height(), ")");
    } else {
        control_preview_textures.erase(p_type_name);
        queue_redraw();
    }
}

// =============================================================================
// Active tool (click-to-place mode)
// =============================================================================

void VisualGasicFormDesigner::set_active_tool(const String &p_class_name, const String &p_scene_path) {
    placing_tool_class = p_class_name;
    placing_tool_scene_path = p_scene_path;
    // Change cursor to crosshair while a tool is active
    set_default_cursor_shape(p_class_name.is_empty() ? CURSOR_ARROW : CURSOR_CROSS);
    UtilityFunctions::print("FormDesigner: Active tool = '", p_class_name, "'");
}

String VisualGasicFormDesigner::get_active_tool() const {
    return placing_tool_class;
}

void VisualGasicFormDesigner::clear_active_tool() {
    placing_tool_class = "";
    placing_tool_scene_path = "";
    set_default_cursor_shape(CURSOR_ARROW);
}

// =============================================================================
// Window type
// =============================================================================

void VisualGasicFormDesigner::set_window_type(int p_type) {
    window_type = (WindowType)CLAMP(p_type, 0, 3);
    _mark_dirty();
}

int VisualGasicFormDesigner::get_window_type() const {
    return (int)window_type;
}

void VisualGasicFormDesigner::set_game_ui_mode(bool p_enabled) {
    game_ui_mode = p_enabled;
    _mark_dirty();
    queue_redraw();
    emit_signal("game_ui_mode_changed", p_enabled);
}

bool VisualGasicFormDesigner::get_game_ui_mode() const {
    return game_ui_mode;
}

// =============================================================================
// Theme colors — configurable from GDScript via VGFormDesignerTheme
// =============================================================================

void VisualGasicFormDesigner::set_theme_colors(const Dictionary &p_colors) {
    // Form canvas colors
    if (p_colors.has("form_background"))    color_form_bg      = p_colors["form_background"];
    if (p_colors.has("form_border"))        color_form_border  = p_colors["form_border"];
    if (p_colors.has("grid_dots"))          color_grid_dot     = p_colors["grid_dots"];
    if (p_colors.has("selection_border"))   color_selected     = p_colors["selection_border"];
    if (p_colors.has("selection_handle"))   color_handle       = p_colors["selection_handle"];
    if (p_colors.has("rubber_band"))        color_rubber_band  = p_colors["rubber_band"];
    // Win32 system colors
    if (p_colors.has("sys_button_face"))      sys_button_face      = p_colors["sys_button_face"];
    if (p_colors.has("sys_button_highlight")) sys_button_highlight = p_colors["sys_button_highlight"];
    if (p_colors.has("sys_button_shadow"))    sys_button_shadow    = p_colors["sys_button_shadow"];
    if (p_colors.has("sys_3d_dark_shadow"))   sys_3d_dark_shadow   = p_colors["sys_3d_dark_shadow"];
    if (p_colors.has("sys_3d_light"))         sys_3d_light         = p_colors["sys_3d_light"];
    if (p_colors.has("sys_window"))           sys_window           = p_colors["sys_window"];
    if (p_colors.has("sys_window_text"))    { sys_window_text      = p_colors["sys_window_text"];
                                              color_text           = sys_window_text; }
    if (p_colors.has("sys_active_title"))     sys_active_title     = p_colors["sys_active_title"];
    if (p_colors.has("sys_title_text"))       sys_title_text       = p_colors["sys_title_text"];
    if (p_colors.has("sys_scrollbar"))        sys_scrollbar        = p_colors["sys_scrollbar"];
    if (p_colors.has("sys_glyph"))            sys_glyph            = p_colors["sys_glyph"];
    if (p_colors.has("sys_progress_fill"))    sys_progress_fill    = p_colors["sys_progress_fill"];
    if (p_colors.has("design_time_outline"))  design_outline       = p_colors["design_time_outline"];
    if (p_colors.has("nonvisual_bg"))         nonvisual_bg         = p_colors["nonvisual_bg"];
    if (p_colors.has("nonvisual_border"))     nonvisual_border     = p_colors["nonvisual_border"];
    if (p_colors.has("placeholder_color"))    placeholder_color    = p_colors["placeholder_color"];
    if (p_colors.has("mdi_background"))       mdi_background       = p_colors["mdi_background"];
    if (p_colors.has("form_handle_color"))    form_handle_color    = p_colors["form_handle_color"];
    if (p_colors.has("sys_inactive_title"))   sys_inactive_title   = p_colors["sys_inactive_title"];
    queue_redraw();
}

Dictionary VisualGasicFormDesigner::get_theme_colors() const {
    Dictionary d;
    d["form_background"]    = color_form_bg;
    d["form_border"]        = color_form_border;
    d["grid_dots"]          = color_grid_dot;
    d["selection_border"]   = color_selected;
    d["selection_handle"]   = color_handle;
    d["rubber_band"]        = color_rubber_band;
    d["sys_button_face"]      = sys_button_face;
    d["sys_button_highlight"] = sys_button_highlight;
    d["sys_button_shadow"]    = sys_button_shadow;
    d["sys_3d_dark_shadow"]   = sys_3d_dark_shadow;
    d["sys_3d_light"]         = sys_3d_light;
    d["sys_window"]           = sys_window;
    d["sys_window_text"]      = sys_window_text;
    d["sys_active_title"]     = sys_active_title;
    d["sys_title_text"]       = sys_title_text;
    d["sys_scrollbar"]        = sys_scrollbar;
    d["sys_glyph"]            = sys_glyph;
    d["sys_progress_fill"]    = sys_progress_fill;
    d["design_time_outline"]  = design_outline;
    d["nonvisual_bg"]         = nonvisual_bg;
    d["nonvisual_border"]     = nonvisual_border;
    d["placeholder_color"]    = placeholder_color;
    d["mdi_background"]       = mdi_background;
    d["form_handle_color"]    = form_handle_color;
    d["sys_inactive_title"]   = sys_inactive_title;
    return d;
}

// =============================================================================
// VB6 default property initializer
// =============================================================================

void VisualGasicFormDesigner::_init_vb6_defaults(FormControlItem &item) const {
    Dictionary &p = item.properties;

    // Universal VB6 properties
    p["Enabled"]       = true;
    p["TabStop"]       = true;
    p["TabIndex"]      = (int)controls.size(); // Auto-increment
    p["Tag"]           = String("");
    p["ToolTipText"]   = String("");
    p["MousePointer"]  = 0;  // Default
    p["BackColor"]     = Color(0.85, 0.85, 0.85);
    p["ForeColor"]     = Color(0.0, 0.0, 0.0);
    p["FontName"]      = String("MS Sans Serif");
    p["FontSize"]      = 8;
    p["FontBold"]      = false;
    p["FontItalic"]    = false;
    p["Appearance"]    = 1; // 3D
    p["BorderStyle"]   = 0; // None

    // Type-specific VB6 defaults
    String t = item.type;

    if (t == "Button") {
        p["Default"]    = false;
        p["Cancel"]     = false;
        p["Style"]      = 0;  // Standard
        p["BackColor"]  = Color(0.85, 0.85, 0.85);
    }
    else if (t == "Label") {
        p["Alignment"]   = 0;  // Left
        p["AutoSize"]    = false;
        p["WordWrap"]    = false;
        p["BackColor"]   = Color(0.753, 0.753, 0.753, 0.0); // Transparent
        p["BorderStyle"] = 0;
        p["TabStop"]     = false;
    }
    else if (t == "LineEdit") {
        p["Locked"]          = false;
        p["MaxLength"]       = 0;
        p["PasswordChar"]    = String("");
        p["PlaceholderText"] = String("");
        p["BackColor"]       = Color(1.0, 1.0, 1.0);
        p["BorderStyle"]     = 1; // Fixed Single
    }
    else if (t == "TextEdit") {
        p["MultiLine"]   = true;
        p["ScrollBars"]  = 3;  // Both
        p["Locked"]      = false;
        p["BackColor"]   = Color(1.0, 1.0, 1.0);
        p["BorderStyle"] = 1;
    }
    else if (t == "CheckBox" || t == "CheckButton") {
        p["Value"]      = false;
    }
    else if (t == "OptionButton") {
        p["Value"]      = false;
    }
    else if (t == "ItemList") {
        p["Sorted"]      = false;
        p["MultiSelect"] = 0;  // None
        p["Columns"]     = 0;
        p["BackColor"]   = Color(1.0, 1.0, 1.0);
        p["BorderStyle"] = 1;
    }
    else if (t == "Tree") {
        p["Sorted"]      = false;
        p["BackColor"]   = Color(1.0, 1.0, 1.0);
        p["BorderStyle"] = 1;
    }
    else if (t == "ProgressBar") {
        p["Value"] = 0.0;
        p["Min"]   = 0.0;
        p["Max"]   = 100.0;
        p["Step"]  = 1.0;
    }
    else if (t == "HSlider" || t == "VSlider") {
        p["Value"] = 0.0;
        p["Min"]   = 0.0;
        p["Max"]   = 100.0;
        p["Step"]  = 1.0;
    }
    else if (t == "HScrollBar" || t == "VScrollBar") {
        p["Value"] = 0.0;
        p["Min"]   = 0.0;
        p["Max"]   = 100.0;
        p["Step"]  = 1.0;
    }
    else if (t == "SpinBox") {
        p["Value"] = 0.0;
        p["Min"]   = 0.0;
        p["Max"]   = 100.0;
        p["Step"]  = 1.0;
    }
    else if (t == "Timer") {
        p["Interval"] = 1000;
        p["Enabled"]  = false; // VB6: Timer starts disabled
        p["TabStop"]  = false;
    }
    else if (t == "TextureRect" || t == "Picture") {
        p["Picture"]  = String("");
        p["Stretch"]  = false;
        p["TabStop"]  = false;
    }
    else if (t == "Panel" || t == "ColorRect") {
        p["BorderStyle"] = 1;
    }
    else if (t == "RichTextLabel") {
        p["BackColor"]   = Color(1.0, 1.0, 1.0);
        p["BorderStyle"] = 1;
    }
    else if (t == "TabContainer") {
        p["BackColor"] = Color(0.85, 0.85, 0.85);
    }
    else if (t == "RadioButton") {
        p["Value"]     = false;
        p["BackColor"] = Color(0.753, 0.753, 0.753, 0.0); // Transparent
    }
    else if (t == "MenuBar") {
        p["TabStop"]   = false;
    }
    else if (t == "StatusBar") {
        p["TabStop"]   = false;
        p["SimpleText"] = String("Ready");
    }
    else if (t == "Toolbar") {
        p["TabStop"]   = false;
    }
    else if (t == "ListView") {
        p["View"]        = 3; // Report view (VB6 default: lvwReport)
        p["Sorted"]      = false;
        p["MultiSelect"] = 0;
        p["BackColor"]   = Color(1.0, 1.0, 1.0);
        p["BorderStyle"] = 1;
    }
    // ── Game UI Tier 1 controls (v4.0) ──
    else if (t == "DialogPanel") {
        p["SpeakerName"]    = String("");
        p["DialogText"]     = String("");
        p["ShowAnimation"]  = 0;    // SlideUp
        p["HideAnimation"]  = 0;    // SlideDown
        p["TransitionSpeed"]= 0.3;
        p["TypewriterSpeed"]= 0.03;
        p["TabStop"]        = false;
    }
    else if (t == "InventoryGrid") {
        p["Rows"]           = 4;
        p["Columns"]        = 4;
        p["SlotSize"]       = 48;
        p["SlotSpacing"]    = 4;
        p["ShowAnimation"]  = 1;    // FadeIn
        p["HideAnimation"]  = 1;    // FadeOut
        p["TransitionSpeed"]= 0.3;
    }
    else if (t == "StatBar") {
        p["Value"]          = 75.0;
        p["MaxValue"]       = 100.0;
        p["ShowLabel"]      = true;
        p["LabelFormat"]    = String("{value} / {max}");
        p["TransitionSpeed"]= 0.4;
        p["TrailDelay"]     = 0.5;
        p["TabStop"]        = false;
    }
    else if (t == "HUDCounter") {
        p["Value"]          = 0;
        p["Prefix"]         = String("");
        p["Suffix"]         = String("");
        p["FontSize"]       = 18;
        p["CountSpeed"]     = 0.5;
        p["PunchScale"]     = true;
        p["TabStop"]        = false;
    }
    else if (t == "CooldownButton") {
        p["CooldownTime"]   = 3.0;
        p["ShowCountdown"]  = true;
    }
    else if (t == "NotificationToast") {
        p["Message"]        = String("");
        p["Duration"]       = 3.0;
        p["ShowAnimation"]  = 0;    // SlideFromTop
        p["TransitionSpeed"]= 0.35;
        p["MaxVisible"]     = 3;
        p["TabStop"]        = false;
    }
    else if (t == "GameMenu") {
        p["Title"]          = String("PAUSED");
        p["Buttons"]        = String("Resume,Settings,Quit");
        p["ShowAnimation"]  = 0;    // FadeIn
        p["HideAnimation"]  = 0;    // FadeOut
        p["TransitionSpeed"]= 0.3;
        p["TabStop"]        = false;
    }
}

// =============================================================================
// Naming helpers
// =============================================================================

String VisualGasicFormDesigner::_make_unique_name(const String &p_base) const {
    for (int n = 1; n < 1000; n++) {
        String candidate = p_base + String::num_int64(n);
        bool found = false;
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].name == candidate) { found = true; break; }
        }
        if (!found) return candidate;
    }
    return p_base + String("_") + String::num_int64(controls.size());
}

// =============================================================================
// Type → visual defaults
// =============================================================================

Vector2 VisualGasicFormDesigner::_default_size_for_type(const String &p_type) const {
    // Check custom registry first
    if (custom_control_types.has(p_type)) {
        return custom_control_types[p_type].default_size;
    }
    // Built-in defaults matching VB6 conventions
    if (p_type == "Button")       return Vector2(75, 23);
    if (p_type == "Label")        return Vector2(100, 16);
    if (p_type == "LineEdit")     return Vector2(120, 23);
    if (p_type == "TextEdit")     return Vector2(150, 80);
    if (p_type == "CheckBox")     return Vector2(100, 23);
    if (p_type == "OptionButton") return Vector2(150, 28);
    if (p_type == "ItemList")     return Vector2(120, 96);
    if (p_type == "ProgressBar")  return Vector2(150, 23);
    if (p_type == "HScrollBar")   return Vector2(120, 16);
    if (p_type == "VScrollBar")   return Vector2(16, 120);
    if (p_type == "HSlider")      return Vector2(120, 23);
    if (p_type == "VSlider")      return Vector2(23, 120);
    if (p_type == "SpinBox")      return Vector2(80, 23);
    if (p_type == "Timer")        return Vector2(32, 32);
    if (p_type == "Panel")        return Vector2(120, 80);
    if (p_type == "ColorRect")    return Vector2(80, 60);
    if (p_type == "TextureRect")  return Vector2(64, 64);
    if (p_type == "Tree")         return Vector2(150, 120);
    if (p_type == "RichTextLabel") return Vector2(150, 80);
    if (p_type == "TabContainer") return Vector2(200, 150);
    if (p_type == "MenuBar")     return Vector2(300, 24);
    if (p_type == "Line")        return Vector2(150, 4);
    if (p_type == "RadioButton") return Vector2(100, 23);
    if (p_type == "TextureButton") return Vector2(40, 40);
    if (p_type == "DriveListBox") return Vector2(150, 28);
    if (p_type == "StatusBar")   return Vector2(300, 24);
    if (p_type == "Toolbar")     return Vector2(300, 32);
    if (p_type == "ListView")    return Vector2(200, 150);
    if (p_type == "Control")      return Vector2(150, 28); // VGComboBox
    // ── Game UI Tier 1 controls (v4.0) ──
    if (p_type == "DialogPanel")       return Vector2(320, 120);
    if (p_type == "InventoryGrid")     return Vector2(220, 220);
    if (p_type == "StatBar")           return Vector2(200, 24);
    if (p_type == "HUDCounter")        return Vector2(120, 28);
    if (p_type == "CooldownButton")    return Vector2(48, 48);
    if (p_type == "NotificationToast") return Vector2(250, 40);
    if (p_type == "GameMenu")          return Vector2(300, 250);
    // ── Game UI Tier 2 controls (v4.1) ──
    if (p_type == "Tooltip")            return Vector2(180, 60);
    if (p_type == "RadialMenu")         return Vector2(200, 200);
    if (p_type == "MiniMap")            return Vector2(140, 140);
    if (p_type == "QuestTracker")       return Vector2(200, 160);
    if (p_type == "SettingsPanel")      return Vector2(320, 280);
    if (p_type == "ConfirmDialog")      return Vector2(280, 140);
    if (p_type == "LoadingScreen")      return Vector2(320, 180);
    if (p_type == "DamageNumber")       return Vector2(60, 28);
    // ── Game UI Tier 3 controls (v4.1) ──
    if (p_type == "SkillTree")          return Vector2(240, 240);
    if (p_type == "ChatBox")            return Vector2(260, 180);
    if (p_type == "ItemSlot")           return Vector2(48, 48);
    if (p_type == "TabPanel")           return Vector2(300, 200);
    if (p_type == "GamePopup")          return Vector2(260, 160);
    if (p_type == "Compass")            return Vector2(200, 28);
    if (p_type == "AmmoCounter")        return Vector2(110, 28);
    if (p_type == "XPBar")              return Vector2(260, 20);
    return Vector2(80, 23);
}

Color VisualGasicFormDesigner::_design_color_for_type(const String &p_type) const {
    // Check custom registry first
    if (custom_control_types.has(p_type)) {
        return custom_control_types[p_type].design_color;
    }
    // VB6-style design-time colors
    if (p_type == "Button")       return Color(0.85, 0.85, 0.85);
    if (p_type == "Label")        return Color(0.753, 0.753, 0.753, 0.0); // Transparent like VB6
    if (p_type == "LineEdit")     return Color(1.0, 1.0, 1.0);
    if (p_type == "TextEdit")     return Color(1.0, 1.0, 1.0);
    if (p_type == "CheckBox")     return Color(0.753, 0.753, 0.753, 0.0);
    if (p_type == "OptionButton") return Color(0.85, 0.85, 0.85);
    if (p_type == "ItemList")     return Color(1.0, 1.0, 1.0);
    if (p_type == "ProgressBar")  return Color(0.85, 0.85, 0.85);
    if (p_type == "Panel")        return Color(0.85, 0.85, 0.85);
    if (p_type == "ColorRect")    return Color(0.5, 0.5, 0.5);
    if (p_type == "Timer")        return Color(0.9, 0.8, 0.6);
    // ── Game UI Tier 1 (v4.0) ──
    if (p_type == "DialogPanel")       return Color(0.18, 0.22, 0.30, 0.9);
    if (p_type == "InventoryGrid")     return Color(0.20, 0.20, 0.25, 0.9);
    if (p_type == "StatBar")           return Color(0.20, 0.80, 0.30);
    if (p_type == "HUDCounter")        return Color(1.0, 0.85, 0.2);
    if (p_type == "CooldownButton")    return Color(0.30, 0.55, 0.80);
    if (p_type == "NotificationToast") return Color(0.25, 0.25, 0.30, 0.85);
    if (p_type == "GameMenu")          return Color(0.0, 0.0, 0.0, 0.6);
    // ── Game UI Tier 2 (v4.1) ──
    if (p_type == "Tooltip")            return Color(0.15, 0.15, 0.20, 0.95);
    if (p_type == "RadialMenu")         return Color(0.12, 0.14, 0.22, 0.9);
    if (p_type == "MiniMap")            return Color(0.10, 0.15, 0.10, 0.9);
    if (p_type == "QuestTracker")       return Color(0.15, 0.12, 0.20, 0.9);
    if (p_type == "SettingsPanel")      return Color(0.12, 0.12, 0.18, 0.9);
    if (p_type == "ConfirmDialog")      return Color(0.12, 0.12, 0.18, 0.95);
    if (p_type == "LoadingScreen")      return Color(0.05, 0.05, 0.08, 1.0);
    if (p_type == "DamageNumber")       return Color(1.0, 0.3, 0.2);
    // ── Game UI Tier 3 (v4.1) ──
    if (p_type == "SkillTree")          return Color(0.10, 0.12, 0.18, 0.9);
    if (p_type == "ChatBox")            return Color(0.08, 0.08, 0.12, 0.85);
    if (p_type == "ItemSlot")           return Color(0.12, 0.12, 0.18, 0.9);
    if (p_type == "TabPanel")           return Color(0.08, 0.08, 0.12, 0.9);
    if (p_type == "GamePopup")          return Color(0.10, 0.10, 0.16, 0.95);
    if (p_type == "Compass")            return Color(0.08, 0.08, 0.12, 0.85);
    if (p_type == "AmmoCounter")        return Color(1.0, 1.0, 1.0);
    if (p_type == "XPBar")              return Color(0.30, 0.75, 1.0);
    return Color(0.85, 0.85, 0.85);
}

String VisualGasicFormDesigner::_display_label_for_type(const String &p_type) const {
    // Short label shown in the design-time control rectangle
    if (p_type == "Button")       return "Btn";
    if (p_type == "Label")        return "Lbl";
    if (p_type == "LineEdit")     return "Txt";
    if (p_type == "TextEdit")     return "TxA";
    if (p_type == "CheckBox")     return "Chk";
    if (p_type == "OptionButton") return "Cbo";
    if (p_type == "ItemList")     return "Lst";
    if (p_type == "ProgressBar")  return "Prg";
    if (p_type == "HScrollBar")   return "HSb";
    if (p_type == "VScrollBar")   return "VSb";
    if (p_type == "HSlider")      return "HSl";
    if (p_type == "VSlider")      return "VSl";
    if (p_type == "SpinBox")      return "Spn";
    if (p_type == "Timer")        return "Tmr";
    if (p_type == "Panel")        return "Pnl";
    if (p_type == "ColorRect")    return "Shp";
    if (p_type == "TextureRect")  return "Pic";
    if (p_type == "Tree")         return "Tre";
    if (p_type == "RichTextLabel") return "RTx";
    if (p_type == "TabContainer") return "Tab";
    if (p_type == "Control")      return "Ctl";
    // ── Game UI Tier 1 (v4.0) ──
    if (p_type == "DialogPanel")       return "Dlg";
    if (p_type == "InventoryGrid")     return "Inv";
    if (p_type == "StatBar")           return "Sta";
    if (p_type == "HUDCounter")        return "HUD";
    if (p_type == "CooldownButton")    return "CDb";
    if (p_type == "NotificationToast") return "Tst";
    if (p_type == "GameMenu")          return "Mnu";
    // ── Game UI Tier 2 (v4.1) ──
    if (p_type == "Tooltip")            return "Tip";
    if (p_type == "RadialMenu")         return "Rad";
    if (p_type == "MiniMap")            return "Map";
    if (p_type == "QuestTracker")       return "Qst";
    if (p_type == "SettingsPanel")      return "Set";
    if (p_type == "ConfirmDialog")      return "Cfm";
    if (p_type == "LoadingScreen")      return "Lod";
    if (p_type == "DamageNumber")       return "Dmg";
    // ── Game UI Tier 3 (v4.1) ──
    if (p_type == "SkillTree")          return "Skl";
    if (p_type == "ChatBox")            return "Cht";
    if (p_type == "ItemSlot")           return "Itm";
    if (p_type == "TabPanel")           return "TPn";
    if (p_type == "GamePopup")          return "Pop";
    if (p_type == "Compass")            return "Cmp";
    if (p_type == "AmmoCounter")        return "Amo";
    if (p_type == "XPBar")              return "XPB";
    return p_type.left(3);
}

// =============================================================================
// Dirty flag
// =============================================================================

void VisualGasicFormDesigner::_mark_dirty() {
    dirty = true;
    emit_signal("form_modified");
}

bool VisualGasicFormDesigner::is_dirty() const { return dirty; }

// =============================================================================
// Form metadata
// =============================================================================

String VisualGasicFormDesigner::get_form_path() const { return form_path; }
String VisualGasicFormDesigner::get_form_name() const { return form_name; }
void VisualGasicFormDesigner::set_form_name(const String &p_name) { form_name = p_name; _mark_dirty(); queue_redraw(); }

// =============================================================================
// VB6 Form Properties — get/set/getAll
// =============================================================================

void VisualGasicFormDesigner::set_form_property(const String &p_key, const Variant &p_value) {
    if (p_key == "Caption" || p_key == "caption") {
        form_name = p_value;
    } else if (p_key == "BorderStyle" || p_key == "borderstyle") {
        form_border_style = (FormBorderStyle)(int)p_value;
    } else if (p_key == "ControlBox" || p_key == "controlbox") {
        form_control_box = p_value;
    } else if (p_key == "MinButton" || p_key == "minbutton") {
        form_min_button = p_value;
    } else if (p_key == "MaxButton" || p_key == "maxbutton") {
        form_max_button = p_value;
    } else if (p_key == "Moveable" || p_key == "moveable") {
        form_moveable = p_value;
    } else if (p_key == "ShowInTaskbar" || p_key == "showintaskbar") {
        form_show_in_taskbar = p_value;
    } else if (p_key == "WindowState" || p_key == "windowstate") {
        form_window_state = p_value;
    } else if (p_key == "StartUpPosition" || p_key == "startposition") {
        form_start_position = p_value;
    } else if (p_key == "KeyPreview" || p_key == "keypreview") {
        form_key_preview = p_value;
    } else if (p_key == "AutoRedraw" || p_key == "autoredraw") {
        form_auto_redraw = p_value;
    } else if (p_key == "BackColor" || p_key == "backcolor") {
        form_back_color = p_value;
        color_form_bg = form_back_color;
    } else if (p_key == "ForeColor" || p_key == "forecolor") {
        form_fore_color = p_value;
    } else if (p_key == "Icon" || p_key == "icon") {
        form_icon = p_value;
    } else if (p_key == "Width" || p_key == "width") {
        form_size.x = (int)(float)p_value;
        _update_min_size();
    } else if (p_key == "Height" || p_key == "height") {
        form_size.y = (int)(float)p_value;
        _update_min_size();
    } else if (p_key == "WindowType" || p_key == "windowtype") {
        window_type = (WindowType)(int)p_value;
    } else if (p_key == "GameUIMode" || p_key == "gameuimode") {
        game_ui_mode = (bool)p_value;
    } else {
        UtilityFunctions::print("FormDesigner: Unknown form property '", p_key, "'");
        return;
    }
    _mark_dirty();
    queue_redraw();
}

Variant VisualGasicFormDesigner::get_form_property(const String &p_key) const {
    if (p_key == "Caption" || p_key == "caption") return form_name;
    if (p_key == "BorderStyle" || p_key == "borderstyle") return (int)form_border_style;
    if (p_key == "ControlBox" || p_key == "controlbox") return form_control_box;
    if (p_key == "MinButton" || p_key == "minbutton") return form_min_button;
    if (p_key == "MaxButton" || p_key == "maxbutton") return form_max_button;
    if (p_key == "Moveable" || p_key == "moveable") return form_moveable;
    if (p_key == "ShowInTaskbar" || p_key == "showintaskbar") return form_show_in_taskbar;
    if (p_key == "WindowState" || p_key == "windowstate") return form_window_state;
    if (p_key == "StartUpPosition" || p_key == "startposition") return form_start_position;
    if (p_key == "KeyPreview" || p_key == "keypreview") return form_key_preview;
    if (p_key == "AutoRedraw" || p_key == "autoredraw") return form_auto_redraw;
    if (p_key == "BackColor" || p_key == "backcolor") return form_back_color;
    if (p_key == "ForeColor" || p_key == "forecolor") return form_fore_color;
    if (p_key == "Icon" || p_key == "icon") return form_icon;
    if (p_key == "Width" || p_key == "width") return form_size.x;
    if (p_key == "Height" || p_key == "height") return form_size.y;
    if (p_key == "WindowType" || p_key == "windowtype") return (int)window_type;
    if (p_key == "GameUIMode" || p_key == "gameuimode") return game_ui_mode;
    return Variant();
}

Dictionary VisualGasicFormDesigner::get_form_properties() const {
    Dictionary d;
    d["(Name)"]           = form_name;
    d["Caption"]          = form_name;
    d["BorderStyle"]      = (int)form_border_style;
    d["ControlBox"]       = form_control_box;
    d["MinButton"]        = form_min_button;
    d["MaxButton"]        = form_max_button;
    d["Moveable"]         = form_moveable;
    d["ShowInTaskbar"]    = form_show_in_taskbar;
    d["WindowState"]      = form_window_state;
    d["StartUpPosition"]  = form_start_position;
    d["BackColor"]        = form_back_color;
    d["ForeColor"]        = form_fore_color;
    d["Width"]            = form_size.x;
    d["Height"]           = form_size.y;
    d["KeyPreview"]       = form_key_preview;
    d["AutoRedraw"]       = form_auto_redraw;
    d["Icon"]             = form_icon;
    d["WindowType"]       = (int)window_type;
    d["GameUIMode"]       = game_ui_mode;
    return d;
}

// =============================================================================
// New form
// =============================================================================

void VisualGasicFormDesigner::new_form(const String &p_name) {
    controls.clear();
    undo_stack.clear();
    redo_stack.clear();
    clipboard.clear();
    form_name = p_name;
    form_path = "";
    form_size = Vector2i(600, 400);
    // Reset VB6 form properties to defaults
    form_border_style = BORDER_SIZABLE;
    form_control_box = true;
    form_min_button = true;
    form_max_button = true;
    form_moveable = true;
    form_show_in_taskbar = true;
    form_window_state = 0;
    form_start_position = 2;
    form_key_preview = false;
    form_auto_redraw = true;
    form_back_color = Color(0.753, 0.753, 0.753, 1.0);
    color_form_bg = form_back_color;
    form_fore_color = Color(0.0, 0.0, 0.0, 1.0);
    form_icon = "";
    dirty = false;
    _clear_all_live_previews();
    if (preview_container) preview_container->set_size(Vector2(form_size));
    _update_min_size();
    queue_redraw();
    UtilityFunctions::print("FormDesigner: New form '", p_name, "'");
}

// =============================================================================
// .tscn serializer
// =============================================================================

void VisualGasicFormDesigner::_validate_scene_paths() {
    for (int i = 0; i < controls.size(); i++) {
        String sp = controls[i].scene_path;
        if (sp.is_empty()) continue;
        if (FileAccess::file_exists(sp)) continue;
        // Custom scene was deleted — fall back to built-in prototype
        String fallback = "res://addons/visual_gasic/prototypes/" + controls[i].type + ".tscn";
        if (FileAccess::file_exists(fallback)) {
            controls.write[i].scene_path = fallback;
            UtilityFunctions::print("FormDesigner: Custom scene '", sp,
                "' not found — falling back to prototype for '", controls[i].name, "'");
        } else {
            controls.write[i].scene_path = "";
            UtilityFunctions::print("FormDesigner: Scene '", sp,
                "' not found and no prototype available for '", controls[i].name, "'");
        }
    }
}

String VisualGasicFormDesigner::_serialize_to_tscn() const {
    // Collect unique scene paths → ext_resource entries
    struct ExtRes {
        String type;
        String path;
        String uid;
    };
    Vector<ExtRes> ext_resources;
    HashMap<String, int> path_to_idx; // scene_path → 1-based ext_resource ID

    // The form script (VG script)
    String vg_script_path = form_path.get_basename() + ".vg";
    {
        ExtRes er;
        er.type = "Script";
        er.path = vg_script_path;
        // Try to get UID
        int64_t uid_val = ResourceLoader::get_singleton()->get_resource_uid(vg_script_path);
        if (uid_val >= 0) {
            er.uid = ResourceUID::get_singleton()->id_to_text(uid_val);
        }
        ext_resources.push_back(er);
        path_to_idx[vg_script_path] = 1;
    }

    // Form editor helper script
    String helper_path = "res://addons/visual_gasic/form_editor_helper.gd";
    {
        ExtRes er;
        er.type = "Script";
        er.path = helper_path;
        int64_t uid_val = ResourceLoader::get_singleton()->get_resource_uid(helper_path);
        if (uid_val >= 0) {
            er.uid = ResourceUID::get_singleton()->id_to_text(uid_val);
        }
        ext_resources.push_back(er);
        path_to_idx[helper_path] = 2;
    }

    // Menu bar helper (only if form has a menu bar)
    String menubar_helper_path = "res://addons/visual_gasic/menu_bar_helper.gd";
    if (has_menu_bar) {
        ExtRes er;
        er.type = "Script";
        er.path = menubar_helper_path;
        int64_t uid_val = ResourceLoader::get_singleton()->get_resource_uid(menubar_helper_path);
        if (uid_val >= 0) {
            er.uid = ResourceUID::get_singleton()->id_to_text(uid_val);
        }
        ext_resources.push_back(er);
        path_to_idx[menubar_helper_path] = 3;
    }

    // Control prototype scenes
    int next_id = has_menu_bar ? 4 : 3;
    for (int i = 0; i < controls.size(); i++) {
        String sp = controls[i].scene_path;
        if (sp.is_empty() || path_to_idx.has(sp)) continue;
        ExtRes er;
        er.type = "PackedScene";
        er.path = sp;
        int64_t uid_val = ResourceLoader::get_singleton()->get_resource_uid(sp);
        if (uid_val >= 0) {
            er.uid = ResourceUID::get_singleton()->id_to_text(uid_val);
        }
        ext_resources.push_back(er);
        path_to_idx[sp] = next_id++;
    }

    // =========================================================================
    // Check whether any custom controls exist (scene_path NOT under prototypes/)
    // so we know whether to emit an empty theme blocker
    // =========================================================================
    String proto_prefix = "res://addons/visual_gasic/prototypes/";
    bool has_custom_controls = false;
    for (int i = 0; i < controls.size(); i++) {
        if (!controls[i].scene_path.is_empty() && !controls[i].scene_path.begins_with(proto_prefix)) {
            has_custom_controls = true;
            break;
        }
    }

    // =========================================================================
    // Build VB6 Classic Theme sub_resources (StyleBoxFlat + Theme)
    // These inline resources make the Godot scene preview match the Form Designer
    // =========================================================================

    // Helper: format a Color for .tscn
    auto fmt_color = [](const Color &c) -> String {
        return "Color(" + String::num(c.r, 4) + ", " + String::num(c.g, 4) + ", " + String::num(c.b, 4) + ", " + String::num(c.a, 4) + ")";
    };

    // StyleBoxFlat helper — returns a [sub_resource] block
    // border_widths: top, right, bottom, left
    auto make_stylebox = [&](const String &id, const Color &bg,
                             int bw_top, int bw_right, int bw_bottom, int bw_left,
                             const Color &border_top, const Color &border_right,
                             const Color &border_bottom, const Color &border_left,
                             int corner_radius = 0, int content_margin = -1) -> String {
        String s;
        s += "[sub_resource type=\"StyleBoxFlat\" id=\"" + id + "\"]\n";
        s += "bg_color = " + fmt_color(bg) + "\n";
        if (bw_top > 0)    s += "border_width_top = "    + String::num_int64(bw_top) + "\n";
        if (bw_right > 0)  s += "border_width_right = "  + String::num_int64(bw_right) + "\n";
        if (bw_bottom > 0) s += "border_width_bottom = " + String::num_int64(bw_bottom) + "\n";
        if (bw_left > 0)   s += "border_width_left = "   + String::num_int64(bw_left) + "\n";
        s += "border_color = " + fmt_color(border_top) + "\n"; // Godot uses single border_color
        if (corner_radius > 0) {
            s += "corner_radius_top_left = "     + String::num_int64(corner_radius) + "\n";
            s += "corner_radius_top_right = "    + String::num_int64(corner_radius) + "\n";
            s += "corner_radius_bottom_right = " + String::num_int64(corner_radius) + "\n";
            s += "corner_radius_bottom_left = "  + String::num_int64(corner_radius) + "\n";
        }
        if (content_margin >= 0) {
            s += "content_margin_left = "   + String::num_int64(content_margin) + ".0\n";
            s += "content_margin_top = "    + String::num_int64(content_margin) + ".0\n";
            s += "content_margin_right = "  + String::num_int64(content_margin) + ".0\n";
            s += "content_margin_bottom = " + String::num_int64(content_margin) + ".0\n";
        }
        s += "\n";
        return s;
    };

    // Per-type VB6 border emulation using Godot's single border_color:
    // - Raised (button): light face + dark border  → border_color = shadow
    // - Sunken (edit):   white fill + dark border  → border_color = shadow

    String sub_resources;

    // --- Button StyleBoxes ---
    // Normal: raised 3D look (warm gray face, dark shadow border)
    sub_resources += make_stylebox("vb6_btn_normal", sys_button_face,
        2, 2, 2, 2, sys_button_highlight, sys_3d_dark_shadow, sys_3d_dark_shadow, sys_button_highlight, 0, 4);
    // Hover: slightly lighter
    Color btn_hover_face(MIN(sys_button_face.r + 0.04f, 1.0f), MIN(sys_button_face.g + 0.04f, 1.0f), MIN(sys_button_face.b + 0.04f, 1.0f));
    sub_resources += make_stylebox("vb6_btn_hover", btn_hover_face,
        2, 2, 2, 2, sys_button_highlight, sys_3d_dark_shadow, sys_3d_dark_shadow, sys_button_highlight, 0, 4);
    // Pressed: sunken (swap highlight/shadow)
    sub_resources += make_stylebox("vb6_btn_pressed", sys_button_face,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 4);
    // Focus: same as normal with highlight border
    sub_resources += make_stylebox("vb6_btn_focus", sys_button_face,
        2, 2, 2, 2, sys_button_highlight, sys_3d_dark_shadow, sys_3d_dark_shadow, sys_button_highlight, 0, 4);
    // Disabled: lighter face
    Color btn_disabled_face(0.85f, 0.85f, 0.85f);
    sub_resources += make_stylebox("vb6_btn_disabled", btn_disabled_face,
        2, 2, 2, 2, sys_button_shadow, sys_button_shadow, sys_button_shadow, sys_button_shadow, 0, 4);

    // --- LineEdit StyleBoxes (sunken white) ---
    sub_resources += make_stylebox("vb6_edit_normal", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_edit_focus", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_edit_read_only", Color(0.93f, 0.93f, 0.93f),
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 3);

    // --- TextEdit StyleBoxes (same sunken look as LineEdit) ---
    sub_resources += make_stylebox("vb6_textedit_normal", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_textedit_focus", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_textedit_read_only", Color(0.93f, 0.93f, 0.93f),
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 3);

    // --- CheckBox StyleBoxes (transparent, just text on form bg) ---
    Color transparent(0, 0, 0, 0);
    sub_resources += make_stylebox("vb6_check_normal", transparent, 0, 0, 0, 0, transparent, transparent, transparent, transparent);
    sub_resources += make_stylebox("vb6_check_hover", Color(sys_button_face.r, sys_button_face.g, sys_button_face.b, 0.3f),
        0, 0, 0, 0, transparent, transparent, transparent, transparent);
    sub_resources += make_stylebox("vb6_check_pressed", transparent, 0, 0, 0, 0, transparent, transparent, transparent, transparent);

    // --- OptionButton (ComboBox) StyleBoxes ---
    sub_resources += make_stylebox("vb6_combo_normal", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_combo_hover", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 3);
    sub_resources += make_stylebox("vb6_combo_pressed", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 3);

    // --- Panel / Frame StyleBox (form background gray + etched border) ---
    sub_resources += make_stylebox("vb6_panel", color_form_bg,
        1, 1, 1, 1, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 4);

    // --- ItemList StyleBox (sunken white like TextEdit) ---
    sub_resources += make_stylebox("vb6_itemlist_normal", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 2);
    sub_resources += make_stylebox("vb6_itemlist_focus", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 2);

    // --- ProgressBar StyleBoxes ---
    sub_resources += make_stylebox("vb6_progress_bg", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow);
    sub_resources += make_stylebox("vb6_progress_fill", sys_progress_fill,
        0, 0, 0, 0, transparent, transparent, transparent, transparent);

    // --- TabContainer StyleBoxes ---
    sub_resources += make_stylebox("vb6_tab_panel", sys_button_face,
        1, 1, 1, 1, sys_button_shadow, sys_button_shadow, sys_button_shadow, sys_button_shadow, 0, 4);
    sub_resources += make_stylebox("vb6_tab_selected", sys_button_face,
        1, 1, 0, 1, sys_button_highlight, sys_3d_dark_shadow, sys_button_face, sys_button_highlight, 0, 4);
    sub_resources += make_stylebox("vb6_tab_unselected", Color(0.72f, 0.72f, 0.72f),
        1, 1, 1, 1, sys_button_shadow, sys_button_shadow, sys_button_shadow, sys_button_shadow, 0, 4);
    sub_resources += make_stylebox("vb6_tab_hovered", Color(0.80f, 0.80f, 0.78f),
        1, 1, 0, 1, sys_button_highlight, sys_3d_dark_shadow, sys_button_face, sys_button_highlight, 0, 4);

    // --- ScrollBar StyleBoxes ---
    sub_resources += make_stylebox("vb6_scrollbar_scroll", sys_scrollbar,
        0, 0, 0, 0, transparent, transparent, transparent, transparent);
    sub_resources += make_stylebox("vb6_scrollbar_grabber", sys_button_face,
        1, 1, 1, 1, sys_button_highlight, sys_3d_dark_shadow, sys_3d_dark_shadow, sys_button_highlight);
    sub_resources += make_stylebox("vb6_scrollbar_grabber_hl", btn_hover_face,
        1, 1, 1, 1, sys_button_highlight, sys_3d_dark_shadow, sys_3d_dark_shadow, sys_button_highlight);
    sub_resources += make_stylebox("vb6_scrollbar_grabber_pressed", sys_button_face,
        1, 1, 1, 1, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow);

    // --- SpinBox (uses LineEdit styles + Button for arrows) ---
    // SpinBox inherits LineEdit styles automatically

    // --- Label StyleBoxes (transparent) ---
    sub_resources += make_stylebox("vb6_label_normal", transparent, 0, 0, 0, 0, transparent, transparent, transparent, transparent);

    // --- RadioButton StyleBoxes (transparent like CheckBox) ---
    sub_resources += make_stylebox("vb6_radio_normal", transparent, 0, 0, 0, 0, transparent, transparent, transparent, transparent);
    sub_resources += make_stylebox("vb6_radio_hover", Color(sys_button_face.r, sys_button_face.g, sys_button_face.b, 0.3f),
        0, 0, 0, 0, transparent, transparent, transparent, transparent);
    sub_resources += make_stylebox("vb6_radio_pressed", transparent, 0, 0, 0, 0, transparent, transparent, transparent, transparent);

    // --- Tree (TreeView) StyleBox ---
    sub_resources += make_stylebox("vb6_tree_panel", sys_window,
        2, 2, 2, 2, sys_button_shadow, sys_button_highlight, sys_button_highlight, sys_button_shadow, 0, 2);
    sub_resources += make_stylebox("vb6_tree_focus", sys_window,
        2, 2, 2, 2, sys_3d_dark_shadow, sys_button_highlight, sys_button_highlight, sys_3d_dark_shadow, 0, 2);

    // =========================================================================
    // VB6 Classic Theme sub_resource — maps StyleBoxes to control types
    // =========================================================================

    String theme_res;
    theme_res += "[sub_resource type=\"Theme\" id=\"vb6_theme\"]\n";
    theme_res += "default_font_size = " + String::num_int64(VB6_FONT_SIZE) + "\n";

    // -- Button --
    theme_res += "Button/colors/font_color = " + fmt_color(color_text) + "\n";
    theme_res += "Button/colors/font_hover_color = " + fmt_color(color_text) + "\n";
    theme_res += "Button/colors/font_pressed_color = " + fmt_color(color_text) + "\n";
    theme_res += "Button/colors/font_disabled_color = " + fmt_color(Color(0.5f, 0.5f, 0.5f)) + "\n";
    theme_res += "Button/styles/normal = SubResource(\"vb6_btn_normal\")\n";
    theme_res += "Button/styles/hover = SubResource(\"vb6_btn_hover\")\n";
    theme_res += "Button/styles/pressed = SubResource(\"vb6_btn_pressed\")\n";
    theme_res += "Button/styles/focus = SubResource(\"vb6_btn_focus\")\n";
    theme_res += "Button/styles/disabled = SubResource(\"vb6_btn_disabled\")\n";

    // -- LineEdit --
    theme_res += "LineEdit/colors/font_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "LineEdit/colors/font_placeholder_color = " + fmt_color(placeholder_color) + "\n";
    theme_res += "LineEdit/colors/caret_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "LineEdit/colors/selection_color = " + fmt_color(Color(0.0f, 0.0f, 0.5f, 0.4f)) + "\n";
    theme_res += "LineEdit/styles/normal = SubResource(\"vb6_edit_normal\")\n";
    theme_res += "LineEdit/styles/focus = SubResource(\"vb6_edit_focus\")\n";
    theme_res += "LineEdit/styles/read_only = SubResource(\"vb6_edit_read_only\")\n";

    // -- TextEdit --
    theme_res += "TextEdit/colors/font_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "TextEdit/colors/font_placeholder_color = " + fmt_color(placeholder_color) + "\n";
    theme_res += "TextEdit/colors/caret_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "TextEdit/styles/normal = SubResource(\"vb6_textedit_normal\")\n";
    theme_res += "TextEdit/styles/focus = SubResource(\"vb6_textedit_focus\")\n";
    theme_res += "TextEdit/styles/read_only = SubResource(\"vb6_textedit_read_only\")\n";

    // -- CheckBox --
    theme_res += "CheckBox/colors/font_color = " + fmt_color(color_text) + "\n";
    theme_res += "CheckBox/colors/font_hover_color = " + fmt_color(color_text) + "\n";
    theme_res += "CheckBox/colors/font_pressed_color = " + fmt_color(color_text) + "\n";
    theme_res += "CheckBox/styles/normal = SubResource(\"vb6_check_normal\")\n";
    theme_res += "CheckBox/styles/hover = SubResource(\"vb6_check_hover\")\n";
    theme_res += "CheckBox/styles/pressed = SubResource(\"vb6_check_pressed\")\n";
    theme_res += "CheckBox/styles/focus = SubResource(\"vb6_check_normal\")\n";

    // -- RadioButton (Option) --
    theme_res += "RadioButton/colors/font_color = " + fmt_color(color_text) + "\n";
    theme_res += "RadioButton/styles/normal = SubResource(\"vb6_radio_normal\")\n";
    theme_res += "RadioButton/styles/hover = SubResource(\"vb6_radio_hover\")\n";
    theme_res += "RadioButton/styles/pressed = SubResource(\"vb6_radio_pressed\")\n";
    theme_res += "RadioButton/styles/focus = SubResource(\"vb6_radio_normal\")\n";

    // -- OptionButton (ComboBox) --
    theme_res += "OptionButton/colors/font_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "OptionButton/styles/normal = SubResource(\"vb6_combo_normal\")\n";
    theme_res += "OptionButton/styles/hover = SubResource(\"vb6_combo_hover\")\n";
    theme_res += "OptionButton/styles/pressed = SubResource(\"vb6_combo_pressed\")\n";
    theme_res += "OptionButton/styles/focus = SubResource(\"vb6_combo_normal\")\n";

    // -- Panel (Frame / GroupBox) --
    theme_res += "Panel/styles/panel = SubResource(\"vb6_panel\")\n";

    // -- Label --
    theme_res += "Label/colors/font_color = " + fmt_color(color_text) + "\n";
    theme_res += "Label/styles/normal = SubResource(\"vb6_label_normal\")\n";

    // -- ItemList (ListBox) --
    theme_res += "ItemList/colors/font_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "ItemList/colors/font_selected_color = " + fmt_color(sys_title_text) + "\n";
    theme_res += "ItemList/colors/guide_color = " + fmt_color(Color(0.9f, 0.9f, 0.9f)) + "\n";
    theme_res += "ItemList/styles/panel = SubResource(\"vb6_itemlist_normal\")\n";
    theme_res += "ItemList/styles/focus = SubResource(\"vb6_itemlist_focus\")\n";

    // -- ProgressBar --
    theme_res += "ProgressBar/colors/font_color = " + fmt_color(color_text) + "\n";
    theme_res += "ProgressBar/styles/background = SubResource(\"vb6_progress_bg\")\n";
    theme_res += "ProgressBar/styles/fill = SubResource(\"vb6_progress_fill\")\n";

    // -- TabContainer --
    theme_res += "TabContainer/styles/panel = SubResource(\"vb6_tab_panel\")\n";
    theme_res += "TabContainer/styles/tab_selected = SubResource(\"vb6_tab_selected\")\n";
    theme_res += "TabContainer/styles/tab_unselected = SubResource(\"vb6_tab_unselected\")\n";
    theme_res += "TabContainer/styles/tab_hovered = SubResource(\"vb6_tab_hovered\")\n";

    // -- HScrollBar / VScrollBar --
    theme_res += "HScrollBar/styles/scroll = SubResource(\"vb6_scrollbar_scroll\")\n";
    theme_res += "HScrollBar/styles/grabber = SubResource(\"vb6_scrollbar_grabber\")\n";
    theme_res += "HScrollBar/styles/grabber_highlight = SubResource(\"vb6_scrollbar_grabber_hl\")\n";
    theme_res += "HScrollBar/styles/grabber_pressed = SubResource(\"vb6_scrollbar_grabber_pressed\")\n";
    theme_res += "VScrollBar/styles/scroll = SubResource(\"vb6_scrollbar_scroll\")\n";
    theme_res += "VScrollBar/styles/grabber = SubResource(\"vb6_scrollbar_grabber\")\n";
    theme_res += "VScrollBar/styles/grabber_highlight = SubResource(\"vb6_scrollbar_grabber_hl\")\n";
    theme_res += "VScrollBar/styles/grabber_pressed = SubResource(\"vb6_scrollbar_grabber_pressed\")\n";

    // -- HSlider / VSlider --
    theme_res += "HSlider/styles/slider = SubResource(\"vb6_scrollbar_scroll\")\n";
    theme_res += "HSlider/styles/grabber_area = SubResource(\"vb6_scrollbar_scroll\")\n";
    theme_res += "VSlider/styles/slider = SubResource(\"vb6_scrollbar_scroll\")\n";
    theme_res += "VSlider/styles/grabber_area = SubResource(\"vb6_scrollbar_scroll\")\n";

    // -- SpinBox (uses LineEdit + Button internally) --
    // SpinBox inherits from LineEdit+Button styles in the theme automatically.

    // -- Tree (TreeView) --
    theme_res += "Tree/colors/font_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "Tree/styles/panel = SubResource(\"vb6_tree_panel\")\n";
    theme_res += "Tree/styles/focus = SubResource(\"vb6_tree_focus\")\n";

    // -- RichTextLabel --
    theme_res += "RichTextLabel/colors/default_color = " + fmt_color(sys_window_text) + "\n";
    theme_res += "RichTextLabel/styles/normal = SubResource(\"vb6_edit_normal\")\n";
    theme_res += "RichTextLabel/styles/focus = SubResource(\"vb6_edit_focus\")\n";

    // -- MenuBar --
    theme_res += "MenuBar/styles/normal = SubResource(\"vb6_btn_normal\")\n";
    theme_res += "MenuBar/colors/font_color = " + fmt_color(color_text) + "\n";

    theme_res += "\n";

    // =========================================================================
    // Empty theme for custom controls — blocks VB6 theme inheritance
    // so custom controls keep their own scene-defined look
    // =========================================================================
    String empty_theme_res;
    if (has_custom_controls) {
        empty_theme_res += "[sub_resource type=\"Theme\" id=\"vb6_empty_theme\"]\n\n";
    }

    // =========================================================================
    // Per-control sub_resources: Font overrides + BackColor/BorderStyle StyleBoxes
    // =========================================================================
    String per_ctrl_sub_resources;
    // Track which controls need font/style sub_resource references in the node section
    HashMap<String, String> ctrl_font_ids;   // ctrl name → sub_resource id
    HashMap<String, String> ctrl_style_ids;  // ctrl name → sub_resource id for "normal"

    for (int ci = 0; ci < controls.size(); ci++) {
        const FormControlItem &ctrl = controls[ci];
        const Dictionary &props = ctrl.properties;

        // ── Per-control SystemFont for FontName / FontBold / FontItalic ──
        String font_name = props.has("FontName") ? String(props["FontName"]) : "";
        bool font_bold = props.has("FontBold") ? (bool)(props["FontBold"]) : false;
        bool font_italic = props.has("FontItalic") ? (bool)(props["FontItalic"]) : false;

        // Only generate a font sub_resource if non-default
        bool need_font = (!font_name.is_empty() && font_name != "MS Sans Serif") ||
                         font_bold || font_italic;

        if (need_font) {
            String fid = "ctrl_font_" + ctrl.name;
            per_ctrl_sub_resources += "[sub_resource type=\"SystemFont\" id=\"" + fid + "\"]\n";
            if (!font_name.is_empty() && font_name != "MS Sans Serif") {
                per_ctrl_sub_resources += "font_names = PackedStringArray(\"" + font_name + "\")\n";
            }
            if (font_bold) {
                per_ctrl_sub_resources += "font_weight = 700\n";
            }
            if (font_italic) {
                per_ctrl_sub_resources += "font_italic = true\n";
            }
            per_ctrl_sub_resources += "\n";
            ctrl_font_ids[ctrl.name] = fid;
        }

        // ── Per-control StyleBoxFlat for BackColor / BorderStyle ──
        bool has_back_color = props.has("BackColor") && props["BackColor"].get_type() == Variant::COLOR;
        int border_style = props.has("BorderStyle") ? int(props["BorderStyle"]) : -1;

        // Only generate a stylebox sub_resource if non-default
        if (has_back_color || border_style == 1) {
            String sid = "ctrl_bg_" + ctrl.name;
            per_ctrl_sub_resources += "[sub_resource type=\"StyleBoxFlat\" id=\"" + sid + "\"]\n";

            if (has_back_color) {
                Color bc = Color(props["BackColor"]);
                per_ctrl_sub_resources += "bg_color = " + fmt_color(bc) + "\n";
            } else {
                // Use the VB6 theme default: sys_window for edits, sys_button_face for buttons
                bool is_edit = ctrl.type == "LineEdit" || ctrl.type == "TextEdit" ||
                               ctrl.type == "RichTextLabel" || ctrl.type == "SpinBox";
                per_ctrl_sub_resources += "bg_color = " + fmt_color(is_edit ? sys_window : sys_button_face) + "\n";
            }

            if (border_style == 1) {
                // Fixed Single border: 1px solid dark border
                per_ctrl_sub_resources += "border_width_top = 1\n";
                per_ctrl_sub_resources += "border_width_right = 1\n";
                per_ctrl_sub_resources += "border_width_bottom = 1\n";
                per_ctrl_sub_resources += "border_width_left = 1\n";
                per_ctrl_sub_resources += "border_color = " + fmt_color(sys_button_shadow) + "\n";
            } else if (border_style == 0) {
                // No border
                per_ctrl_sub_resources += "border_width_top = 0\n";
                per_ctrl_sub_resources += "border_width_right = 0\n";
                per_ctrl_sub_resources += "border_width_bottom = 0\n";
                per_ctrl_sub_resources += "border_width_left = 0\n";
            }

            per_ctrl_sub_resources += "content_margin_left = 4.0\n";
            per_ctrl_sub_resources += "content_margin_top = 4.0\n";
            per_ctrl_sub_resources += "content_margin_right = 4.0\n";
            per_ctrl_sub_resources += "content_margin_bottom = 4.0\n";
            per_ctrl_sub_resources += "\n";
            ctrl_style_ids[ctrl.name] = sid;
        }
    }

    // =========================================================================
    // Count sub_resources for load_steps header
    // =========================================================================
    // Count the [sub_resource] blocks we're about to emit
    // Quick count: search for "[sub_resource" occurrences
    int sub_res_count = 0;
    {
        int pos = 0;
        while ((pos = sub_resources.find("[sub_resource", pos)) >= 0) {
            sub_res_count++;
            pos++;
        }
        // Per-control font + style sub_resources
        pos = 0;
        while ((pos = per_ctrl_sub_resources.find("[sub_resource", pos)) >= 0) {
            sub_res_count++;
            pos++;
        }
        // theme_res has 1 Theme
        sub_res_count += 1;
        // empty theme if needed
        if (has_custom_controls) sub_res_count += 1;
    }

    // Build the .tscn text
    String out;
    int load_steps = ext_resources.size() + sub_res_count + 1;
    out += "[gd_scene load_steps=" + String::num_int64(load_steps) + " format=3]\n\n";

    // ext_resources
    for (int i = 0; i < ext_resources.size(); i++) {
        out += "[ext_resource type=\"" + ext_resources[i].type + "\"";
        if (!ext_resources[i].uid.is_empty()) {
            out += " uid=\"" + ext_resources[i].uid + "\"";
        }
        out += " path=\"" + ext_resources[i].path + "\" id=\"" + String::num_int64(i + 1) + "\"]\n";
    }
    out += "\n";

    // Sub-resources (StyleBoxes + Themes + per-control font/style overrides)
    out += sub_resources;
    out += per_ctrl_sub_resources;
    out += theme_res;
    out += empty_theme_res;

    // Root node — Game UI mode uses CanvasLayer → Control, VB6 mode uses Window
    if (game_ui_mode) {
        // Game UI: CanvasLayer root with a full-rect Control child
        out += "[node name=\"" + form_name + "\" type=\"CanvasLayer\"]\n";
        out += "layer = 10\n";  // Render above game world
        out += "\n";
        // Main UI container (anchored full-rect)
        out += "[node name=\"UI\" type=\"Control\" parent=\".\"]\n";
        out += "layout_mode = 1\n";  // Full Rect
        out += "anchors_preset = 15\n";  // PRESET_FULL_RECT
        out += "anchor_right = 1.0\n";
        out += "anchor_bottom = 1.0\n";
        out += "grow_horizontal = 2\n";
        out += "grow_vertical = 2\n";
        out += "theme = SubResource(\"vb6_theme\")\n";
        out += "script = ExtResource(\"" + String::num_int64(path_to_idx[vg_script_path]) + "\")\n";
        out += "\n";
    } else {
        // VB6 Classic: Window root with VB6 Classic Theme
        out += "[node name=\"" + form_name + "\" type=\"Window\"]\n";
        out += "title = \"" + form_name + "\"\n";
        out += "position = Vector2i(10, 36)\n";
        out += "size = Vector2i(" + String::num_int64(form_size.x) + ", " + String::num_int64(form_size.y) + ")\n";
        out += "theme = SubResource(\"vb6_theme\")\n";
        out += "script = ExtResource(\"" + String::num_int64(path_to_idx[vg_script_path]) + "\")\n";
        out += "\n";
    }

    // _FormBackground panel
    String parent_path = game_ui_mode ? "UI" : ".";
    out += "[node name=\"_FormBackground\" type=\"Panel\" parent=\"" + parent_path + "\"]\n";
    out += "offset_right = " + String::num_int64(form_size.x) + ".0\n";
    out += "offset_bottom = " + String::num_int64(form_size.y) + ".0\n";
    out += "mouse_filter = 2\n";  // MOUSE_FILTER_PASS
    out += "script = ExtResource(\"" + String::num_int64(path_to_idx[helper_path]) + "\")\n";
    out += "\n";

    // MenuBar (only if form was created with menu)
    if (has_menu_bar) {
        out += "[node name=\"MainMenu\" type=\"MenuBar\" parent=\".\"]\n";
        out += "offset_right = " + String::num_int64(form_size.x) + ".0\n";
        out += "offset_bottom = 30.0\n";
        out += "mouse_filter = 2\n";  // IGNORE in editor
        out += "script = ExtResource(\"" + String::num_int64(path_to_idx[menubar_helper_path]) + "\")\n";
        out += "\n";

        // Re-emit PopupMenu children from parsed data, or defaults for brand-new forms
        if (menu_child_raw_blocks.size() > 0) {
            for (int m = 0; m < menu_child_raw_blocks.size(); m++) {
                String block = menu_child_raw_blocks[m];
                // Fix parent reference if the original MenuBar had a different name
                if (!menu_bar_node_name.is_empty() && menu_bar_node_name != "MainMenu") {
                    block = block.replace("parent=\"" + menu_bar_node_name + "\"", "parent=\"MainMenu\"");
                }
                out += block + "\n";
            }
        } else {
            // Default menus for brand-new forms
            out += "[node name=\"mnuFile\" type=\"PopupMenu\" parent=\"MainMenu\"]\n\n";
            out += "[node name=\"mnuEdit\" type=\"PopupMenu\" parent=\"MainMenu\"]\n\n";
        }
    }

    // User controls
    for (int i = 0; i < controls.size(); i++) {
        const FormControlItem &ctrl = controls[i];
        String sp = ctrl.scene_path;

        if (!sp.is_empty() && path_to_idx.has(sp)) {
            // Instance from prototype scene
            out += "[node name=\"" + ctrl.name + "\" parent=\"" + parent_path + "\" instance=ExtResource(\"" + String::num_int64(path_to_idx[sp]) + "\")]\n";
        } else {
            // Fallback: bare type node
            out += "[node name=\"" + ctrl.name + "\" type=\"" + ctrl.type + "\" parent=\"" + parent_path + "\"]\n";
        }

        out += "offset_left = " + String::num_int64((int)ctrl.rect.position.x) + ".0\n";
        out += "offset_top = " + String::num_int64((int)ctrl.rect.position.y) + ".0\n";
        out += "offset_right = " + String::num_int64((int)(ctrl.rect.position.x + ctrl.rect.size.x)) + ".0\n";
        out += "offset_bottom = " + String::num_int64((int)(ctrl.rect.position.y + ctrl.rect.size.y)) + ".0\n";

        // Custom controls (scene_path NOT under prototypes/) get an empty Theme
        // to block VB6 theme inheritance, preserving their own scene-defined look
        if (has_custom_controls && !sp.is_empty() && !sp.begins_with(proto_prefix)) {
            out += "theme = SubResource(\"vb6_empty_theme\")\n";
        }

        if (!ctrl.text.is_empty()) {
            out += "text = \"" + ctrl.text + "\"\n";
        }

        // VB6 control array index (persisted as metadata)
        if (ctrl.control_array_index >= 0) {
            out += "metadata/vb6_control_array_index = " + String::num_int64(ctrl.control_array_index) + "\n";
        }

        // Tag RadioButton controls so form_editor_helper.gd can apply circle
        // icons at runtime (Godot has no native RadioButton node — they use
        // CheckBox with custom icons).
        if (ctrl.type == "RadioButton") {
            out += "metadata/vb6_type = \"RadioButton\"\n";
        }

        // Per-control font size override: convert VB6 pt → Godot px
        // Only emit when FontSize differs from the VB6 default (8pt = 12px)
        if (ctrl.properties.has("FontSize")) {
            int vb6_pt = int(ctrl.properties["FontSize"]);
            if (vb6_pt != 8) {
                int godot_px = vb6_pt_to_px(vb6_pt);
                out += "theme_override_font_sizes/font_size = " + String::num_int64(godot_px) + "\n";
            }
        }

        // Per-control font override: FontName / FontBold / FontItalic → SystemFont sub_resource
        if (ctrl_font_ids.has(ctrl.name)) {
            out += "theme_override_fonts/font = SubResource(\"" + ctrl_font_ids[ctrl.name] + "\")\n";
        }

        // Per-control ForeColor → theme_override_colors/font_color
        if (ctrl.properties.has("ForeColor") && ctrl.properties["ForeColor"].get_type() == Variant::COLOR) {
            Color fc = Color(ctrl.properties["ForeColor"]);
            out += "theme_override_colors/font_color = " + fmt_color(fc) + "\n";
        }

        // Per-control ShapeColor → color (for ColorRect)
        if (ctrl.properties.has("ShapeColor") && ctrl.type == "ColorRect") {
            Variant sv = ctrl.properties["ShapeColor"];
            if (sv.get_type() == Variant::COLOR) {
                Color sc = Color(sv);
                out += "color = " + fmt_color(sc) + "\n";
            }
        }

        // Per-control BackColor / BorderStyle → StyleBoxFlat sub_resource
        if (ctrl_style_ids.has(ctrl.name)) {
            // Apply to "normal" style slot (works for LineEdit, TextEdit, Button, etc.)
            out += "theme_override_styles/normal = SubResource(\"" + ctrl_style_ids[ctrl.name] + "\")\n";
        }

        // Write extra properties (VB6 properties stored in the form designer)
        // Translate known VB6 property names → Godot property names so the
        // scene loader applies them at runtime.  Unknown VB6 props are kept
        // as-is (stored as node meta / ignored by Godot, but preserved for
        // round-tripping).
        Array keys = ctrl.properties.keys();
        for (int k = 0; k < keys.size(); k++) {
            String key = keys[k];
            Variant val = ctrl.properties[key];

            // ── VB6 → Godot property translation ──
            String godot_key = key;
            bool skip = false;
            // FontSize already emitted above as theme_override_font_sizes
            if (key == "FontSize") { skip = true; }
            else if (key == "Text" || key == "Caption") { godot_key = "text"; }
            else if (key == "ToolTipText") { godot_key = "tooltip_text"; }
            else if (key == "Visible")     { godot_key = "visible"; }
            else if (key == "MaxLength")   { godot_key = "max_length"; }
            else if (key == "Locked") {
                // Locked=True → editable=false
                godot_key = "editable";
                val = !(bool)val;
            }
            else if (key == "TabStop") {
                // TabStop=True → focus_mode=2 (FOCUS_ALL), False → 0 (FOCUS_NONE)
                godot_key = "focus_mode";
                val = (bool)val ? 2 : 0;
            }
            else if (key == "Alignment") {
                godot_key = "horizontal_alignment";
            }
            else if (key == "WordWrap") {
                // True → AUTOWRAP_WORD_SMART=3, False → OFF=0
                godot_key = "autowrap_mode";
                val = (bool)val ? 3 : 0;
            }
            else if (key == "Enabled") {
                // Enabled=False → disabled=true  (skip if default True)
                if (!(bool)val) {
                    godot_key = "disabled";
                    val = true;
                } else {
                    skip = true;  // default is enabled
                }
            }
            else if (key == "MousePointer") {
                godot_key = "mouse_default_cursor_shape";
            }
            // ── Simple 1:1 PascalCase → snake_case renames ──
            else if (key == "Flat")                    { godot_key = "flat"; }
            else if (key == "ClipText")                { godot_key = "clip_text"; }
            else if (key == "PlaceholderText")         { godot_key = "placeholder_text"; }
            else if (key == "ClearButton")             { godot_key = "clear_button_enabled"; }
            else if (key == "SelectAllOnFocus")        { godot_key = "select_all_on_focus"; }
            else if (key == "Prefix")                  { godot_key = "prefix"; }
            else if (key == "Suffix")                  { godot_key = "suffix"; }
            else if (key == "Editable")                { godot_key = "editable"; }
            else if (key == "ShowPercentage")          { godot_key = "show_percentage"; }
            else if (key == "Indeterminate")           { godot_key = "indeterminate"; }
            else if (key == "FillMode")                { godot_key = "fill_mode"; }
            else if (key == "TickCount")               { godot_key = "tick_count"; }
            else if (key == "TicksOnBorders")          { godot_key = "ticks_on_borders"; }
            else if (key == "Scrollable")              { godot_key = "scrollable"; }
            else if (key == "HideRoot")                { godot_key = "hide_root"; }
            else if (key == "HideFolding")             { godot_key = "hide_folding"; }
            else if (key == "AllowReselect")           { godot_key = "allow_reselect"; }
            else if (key == "AllowRmbSelect")          { godot_key = "allow_rmb_select"; }
            else if (key == "SelectMode")              { godot_key = "select_mode"; }
            else if (key == "Columns")                 { godot_key = "columns"; }
            else if (key == "ColumnTitlesVisible")     { godot_key = "column_titles_visible"; }
            else if (key == "ScrollHorizontalEnabled") { godot_key = "scroll_horizontal_enabled"; }
            else if (key == "ScrollVerticalEnabled")   { godot_key = "scroll_vertical_enabled"; }
            else if (key == "ClipTabs")                { godot_key = "clip_tabs"; }
            else if (key == "DragToRearrangeEnabled")  { godot_key = "drag_to_rearrange_enabled"; }
            else if (key == "TabAlignment")            { godot_key = "tab_alignment"; }
            else if (key == "FitToLongestItem")        { godot_key = "fit_to_longest_item"; }
            else if (key == "AutoHeight")              { godot_key = "auto_height"; }
            else if (key == "SameColumnWidth")         { godot_key = "same_column_width"; }
            else if (key == "MaxColumns")              { godot_key = "max_columns"; }
            else if (key == "FixedColumnWidth")        { godot_key = "fixed_column_width"; }
            else if (key == "BbcodeEnabled")           { godot_key = "bbcode_enabled"; }
            else if (key == "FitContent")              { godot_key = "fit_content"; }
            else if (key == "ScrollActive")            { godot_key = "scroll_active"; }
            else if (key == "SelectionEnabled")        { godot_key = "selection_enabled"; }
            else if (key == "FlipH")                   { godot_key = "flip_h"; }
            else if (key == "FlipV")                   { godot_key = "flip_v"; }
            else if (key == "StretchMode")             { godot_key = "stretch_mode"; }
            else if (key == "IgnoreTextureSize")       { godot_key = "ignore_texture_size"; }
            else if (key == "SwitchOnHover")           { godot_key = "switch_on_hover"; }
            else if (key == "PreferGlobalMenu")        { godot_key = "prefer_global_menu"; }
            else if (key == "VerticalAlignment")       { godot_key = "vertical_alignment"; }
            else if (key == "ClipContents")            { godot_key = "clip_contents"; }
            else if (key == "SizeFlagsHorizontal")     { godot_key = "size_flags_horizontal"; }
            else if (key == "SizeFlagsVertical")       { godot_key = "size_flags_vertical"; }
            else if (key == "GrowHorizontal")          { godot_key = "grow_horizontal"; }
            else if (key == "GrowVertical")            { godot_key = "grow_vertical"; }
            else if (key == "LayoutDirection")         { godot_key = "layout_direction"; }
            else if (key == "VirtualKeyboardEnabled")  { godot_key = "virtual_keyboard_enabled"; }
            else if (key == "KeepPressedOutside")      { godot_key = "keep_pressed_outside"; }
            else if (key == "ActionMode")              { godot_key = "action_mode"; }
            else if (key == "UpdateOnTextChanged")     { godot_key = "update_on_text_changed"; }
            else if (key == "TextOverrunBehavior")     { godot_key = "text_overrun_behavior"; }
            else if (key == "MaxLinesVisible")         { godot_key = "max_lines_visible"; }
            else if (key == "CurrentTab")              { godot_key = "current_tab"; }
            else if (key == "Page")                    { godot_key = "page"; }
            else if (key == "CustomStep")              { godot_key = "custom_step"; }
            else if (key == "ShowBehindParent")        { godot_key = "show_behind_parent"; }
            else if (key == "Min")                     { godot_key = "min_value"; }
            else if (key == "Max")                     { godot_key = "max_value"; }
            else if (key == "Step")                    { godot_key = "step"; }
            else if (key == "AllowGreater")            { godot_key = "allow_greater"; }
            else if (key == "AllowLesser")             { godot_key = "allow_lesser"; }
            else if (key == "Rounded")                 { godot_key = "rounded"; }
            // ── Value: context-dependent ──
            else if (key == "Value") {
                // For CheckBox/CheckButton/RadioButton → button_pressed
                // For Range controls (Slider/ProgressBar/SpinBox/ScrollBar) → value
                if (ctrl.type == "CheckBox" || ctrl.type == "CheckButton" || ctrl.type == "RadioButton") {
                    godot_key = "button_pressed";
                } else {
                    godot_key = "value";
                }
            }
            // ── MultiSelect (ItemList): 0=single, 1+=multi ──
            else if (key == "MultiSelect") {
                godot_key = "select_mode";  // ItemList select_mode enum
            }
            else if (key == "IconMode")                { godot_key = "icon_mode"; }
            // ── Rotation → rotation_degrees ──
            else if (key == "Rotation")                { godot_key = "rotation_degrees"; }
            // ── RightToLeft → text_direction (1=RTL, 0=LTR) ──
            else if (key == "RightToLeft") {
                godot_key = "text_direction";
                val = (bool)val ? 2 : 0;  // TEXT_DIRECTION_RTL=2, AUTO=0
            }
            // ── Tag → metadata/Tag (preserved as node metadata) ──
            else if (key == "Tag") {
                godot_key = "metadata/Tag";
            }
            // ── PasswordChar → secret + secret_character ──
            else if (key == "PasswordChar") {
                String pc = val;
                if (!pc.is_empty()) {
                    out += "secret = true\n";
                    out += "secret_character = \"" + pc + "\"\n";
                }
                skip = true;
            }
            // ── Opacity → modulate alpha ──
            else if (key == "Opacity") {
                int pct = val;
                if (pct < 100) {
                    float alpha = float(pct) / 100.0f;
                    out += "modulate = Color(1.0000, 1.0000, 1.0000, " + String::num(alpha, 4) + ")\n";
                }
                skip = true;
            }
            // ── ScaleX/ScaleY → scale (Vector2) — handle as pair ──
            else if (key == "ScaleX" || key == "ScaleY") {
                // Only emit once (when we hit ScaleX), combine both
                if (key == "ScaleX") {
                    float sx = float(val);
                    float sy = ctrl.properties.has("ScaleY") ? float(ctrl.properties["ScaleY"]) : 1.0f;
                    if (sx != 1.0f || sy != 1.0f) {
                        out += "scale = Vector2(" + String::num(sx, 4) + ", " + String::num(sy, 4) + ")\n";
                    }
                }
                skip = true;
            }
            // ── PivotOffsetX/Y → pivot_offset (Vector2) ──
            else if (key == "PivotOffsetX" || key == "PivotOffsetY") {
                if (key == "PivotOffsetX") {
                    float px = float(val);
                    float py = ctrl.properties.has("PivotOffsetY") ? float(ctrl.properties["PivotOffsetY"]) : 0.0f;
                    if (px != 0.0f || py != 0.0f) {
                        out += "pivot_offset = Vector2(" + String::num(px, 4) + ", " + String::num(py, 4) + ")\n";
                    }
                }
                skip = true;
            }
            // ── MinWidth/MinHeight → custom_minimum_size (Vector2) ──
            else if (key == "MinWidth" || key == "MinHeight") {
                if (key == "MinWidth") {
                    float mw = float(int(val));
                    float mh = ctrl.properties.has("MinHeight") ? float(int(ctrl.properties["MinHeight"])) : 0.0f;
                    if (mw > 0.0f || mh > 0.0f) {
                        out += "custom_minimum_size = Vector2(" + String::num(mw, 1) + ", " + String::num(mh, 1) + ")\n";
                    }
                }
                skip = true;
            }
            // ── VB6-only / non-translatable — skip to avoid invalid .tscn keys ──
            else if (key == "FontName" || key == "FontBold" || key == "FontItalic" ||
                     key == "FontUnderline" || key == "FontStrikethrough" ||
                     key == "Appearance" || key == "BorderStyle" || key == "BackStyle" ||
                     key == "Style" || key == "ComboStyle" || key == "ListStyle" ||
                     key == "CausesValidation" || key == "Default" || key == "Cancel" ||
                     key == "DisabledFocusMode" || key == "TabIndex" ||
                     key == "FocusMode" || key == "MouseFilter" ||
                     key == "SelfModulate" || key == "Sorted" ||
                     key == "LargeChange" || key == "Wrap" ||
                     key == "BackColor" || key == "ForeColor" ||
                     key == "ShapeColor" || key == "IconAlignment" ||
                     key == "Icon" || key == "ExpandIcon" || key == "Picture" ||
                     key == "RightToLeft" || key == "MultiLine" ||
                     key == "ScrollBars" || key == "Tabs" || key == "TabCount" ||
                     key == "List" || key == "ListItems" || key == "Selected" ||
                     key == "FixedIconSize" || key == "AutoSize") {
                skip = true;  // VB6 metadata — no direct Godot .tscn property
            }

            if (skip) continue;

            if (val.get_type() == Variant::STRING) {
                out += godot_key + " = \"" + String(val) + "\"\n";
            } else if (val.get_type() == Variant::PACKED_STRING_ARRAY) {
                // Serialize PackedStringArray as a comma-separated quoted string
                PackedStringArray arr = val;
                out += godot_key + " = \"" + String(",").join(arr) + "\"\n";
            } else if (val.get_type() == Variant::COLOR) {
                // Godot .tscn requires Color(r, g, b, a) format
                Color c = val;
                out += godot_key + " = Color(" + String::num(c.r, 4) + ", " + String::num(c.g, 4) + ", " + String::num(c.b, 4) + ", " + String::num(c.a, 4) + ")\n";
            } else if (val.get_type() == Variant::VECTOR2) {
                Vector2 v = val;
                out += godot_key + " = Vector2(" + String::num(v.x, 4) + ", " + String::num(v.y, 4) + ")\n";
            } else if (val.get_type() == Variant::VECTOR2I) {
                Vector2i v = val;
                out += godot_key + " = Vector2i(" + String::num_int64(v.x) + ", " + String::num_int64(v.y) + ")\n";
            } else {
                out += godot_key + " = " + String(val) + "\n";
            }
        }
        out += "\n";
    }

    return out;
}

// =============================================================================
// .tscn parser (load existing forms)
// =============================================================================

bool VisualGasicFormDesigner::_parse_tscn(const String &p_text) {
    controls.clear();
    has_menu_bar = false;
    menu_bar_node_name = "";
    menu_child_raw_blocks.clear();
    menu_titles.clear();

    // Parse ext_resource entries to build id → path map
    HashMap<String, String> ext_id_to_path;  // "3" → "res://addons/..."
    HashMap<String, String> ext_id_to_type;  // "3" → "PackedScene" or "Script"

    PackedStringArray lines = p_text.split("\n");
    int i = 0;

    // Parse ext_resource lines
    while (i < lines.size()) {
        String line = lines[i].strip_edges();
        if (line.begins_with("[ext_resource")) {
            // Extract id, path, type
            String id, path, type;
            int id_start = line.find("id=\"");
            if (id_start >= 0) {
                id_start += 4;
                int id_end = line.find("\"", id_start);
                id = line.substr(id_start, id_end - id_start);
            }
            int path_start = line.find("path=\"");
            if (path_start >= 0) {
                path_start += 6;
                int path_end = line.find("\"", path_start);
                path = line.substr(path_start, path_end - path_start);
            }
            int type_start = line.find("type=\"");
            if (type_start >= 0) {
                type_start += 6;
                int type_end = line.find("\"", type_start);
                type = line.substr(type_start, type_end - type_start);
            }
            if (!id.is_empty()) {
                ext_id_to_path[id] = path;
                ext_id_to_type[id] = type;
            }
        }
        i++;
    }

    // Second pass: parse per-control sub_resources (SystemFont, StyleBoxFlat)
    // We only care about sub_resources with our ctrl_font_ / ctrl_bg_ id prefixes
    HashMap<String, Dictionary> sub_resource_props;  // id → { "font_names": ..., "font_weight": ..., etc. }
    i = 0;
    {
        String current_sub_id;
        bool in_sub = false;
        while (i < lines.size()) {
            String line = lines[i].strip_edges();
            if (line.begins_with("[sub_resource ")) {
                // Extract id
                int id_start = line.find("id=\"");
                if (id_start >= 0) {
                    id_start += 4;
                    int id_end = line.find("\"", id_start);
                    current_sub_id = line.substr(id_start, id_end - id_start);
                    if (current_sub_id.begins_with("ctrl_font_") || current_sub_id.begins_with("ctrl_bg_")) {
                        in_sub = true;
                        sub_resource_props[current_sub_id] = Dictionary();
                    } else {
                        in_sub = false;
                    }
                }
            } else if (line.begins_with("[")) {
                in_sub = false;
            } else if (in_sub && line.contains("=")) {
                int eq = line.find("=");
                String key = line.substr(0, eq).strip_edges();
                String val = line.substr(eq + 1).strip_edges();
                sub_resource_props[current_sub_id][key] = val;
            }
            i++;
        }
    }

    // Third pass: parse nodes
    i = 0;
    String current_node_name;
    String current_node_type;
    String current_node_parent;
    String current_instance_id;
    bool in_node = false;
    bool is_root_node = false;  // True for root Window node — parse properties but don't add as control
    FormControlItem current_item;
    String current_raw_block;  // accumulates raw lines for MenuBar child storage

    while (i < lines.size()) {
        String line = lines[i].strip_edges();

        if (line.begins_with("[node ")) {
            // Commit previous node (skip root node — it's not a control)
            if (in_node && !is_root_node) {
                if (!current_node_name.begins_with("_") && current_node_parent == ".") {
                    // Direct child of root Window
                    if (current_node_type == "MenuBar" || current_node_name == "MainMenu") {
                        has_menu_bar = true;
                        menu_bar_node_name = current_node_name;
                    } else {
                        controls.push_back(current_item);
                    }
                } else if (!menu_bar_node_name.is_empty() && current_node_parent == menu_bar_node_name) {
                    // Child of the MenuBar (PopupMenu) → store raw block + extract title
                    menu_child_raw_blocks.push_back(current_raw_block);
                    // Derive display title from node name: "mnuFile" → "File", "Edit" → "Edit"
                    String title = current_node_name;
                    if (title.begins_with("mnu") && title.length() > 3) {
                        title = title.substr(3);
                    }
                    menu_titles.push_back(title);
                }
            }

            // Parse new node header
            current_item = FormControlItem();
            in_node = true;
            current_node_parent = "";
            current_instance_id = "";

            // Extract name
            int name_start = line.find("name=\"");
            if (name_start >= 0) {
                name_start += 6;
                int name_end = line.find("\"", name_start);
                current_node_name = line.substr(name_start, name_end - name_start);
                current_item.name = current_node_name;
            }

            // Extract type
            int type_start = line.find("type=\"");
            if (type_start >= 0) {
                type_start += 6;
                int type_end = line.find("\"", type_start);
                current_node_type = line.substr(type_start, type_end - type_start);
                current_item.type = current_node_type;
            }

            // Extract parent
            int parent_start = line.find("parent=\"");
            if (parent_start >= 0) {
                parent_start += 8;
                int parent_end = line.find("\"", parent_start);
                current_node_parent = line.substr(parent_start, parent_end - parent_start);
            }

            // Check for instance=ExtResource("N")
            int inst_start = line.find("instance=ExtResource(\"");
            if (inst_start >= 0) {
                inst_start += 22;
                int inst_end = line.find("\"", inst_start);
                current_instance_id = line.substr(inst_start, inst_end - inst_start);
                // Resolve scene path
                if (ext_id_to_path.has(current_instance_id)) {
                    current_item.scene_path = ext_id_to_path[current_instance_id];
                    // Infer type from scene filename
                    String basename = current_item.scene_path.get_file().get_basename();
                    current_item.type = basename;
                }
            }

            // Root node (no parent) — extract form metadata.
            // Keep in_node=true so we still parse root properties (size, title,
            // BackColor, etc.) but mark is_root_node so the flush logic below
            // doesn't add it as a control.
            if (current_node_parent.is_empty() && !line.contains("parent=")) {
                form_name = current_node_name;
                is_root_node = true;
                // Auto-detect Game UI mode: CanvasLayer root → game_ui_mode
                if (current_node_type == "CanvasLayer") {
                    set_game_ui_mode(true);
                } else {
                    set_game_ui_mode(false);
                }
            } else {
                is_root_node = false;
            }

            // Start accumulating raw block for potential MenuBar child storage
            current_raw_block = line + "\n";
        } else if (in_node && !line.is_empty() && !line.begins_with("[")) {
            // Accumulate raw text for MenuBar child round-trip
            current_raw_block += line + "\n";
            // Parse property lines: key = value
            int eq_pos = line.find(" = ");
            if (eq_pos > 0) {
                String key = line.substr(0, eq_pos).strip_edges();
                String val = line.substr(eq_pos + 3).strip_edges();

                if (key == "offset_left" || key == "offset_left") {
                    current_item.rect.position.x = val.to_float();
                } else if (key == "offset_top") {
                    current_item.rect.position.y = val.to_float();
                } else if (key == "offset_right") {
                    float right = val.to_float();
                    current_item.rect.size.x = right - current_item.rect.position.x;
                } else if (key == "offset_bottom") {
                    float bottom = val.to_float();
                    current_item.rect.size.y = bottom - current_item.rect.position.y;
                } else if (key == "text") {
                    // Strip quotes
                    if (val.begins_with("\"") && val.ends_with("\"")) {
                        val = val.substr(1, val.length() - 2);
                    }
                    current_item.text = val;
                } else if (key == "size") {
                    // Root Window size: Vector2i(600, 400)
                    if (current_node_parent.is_empty()) {
                        int paren = val.find("(");
                        if (paren >= 0) {
                            String inner = val.substr(paren + 1, val.length() - paren - 2);
                            PackedStringArray parts = inner.split(",");
                            if (parts.size() >= 2) {
                                form_size.x = parts[0].strip_edges().to_int();
                                form_size.y = parts[1].strip_edges().to_int();
                                UtilityFunctions::print("FormDesigner: Parsed form_size = ", form_size, " from .tscn");
                            }
                        }
                    }
                } else if (key == "title") {
                    // Skip, we already have form_name from node name
                } else if (key == "script" || key == "mouse_filter" || key == "theme") {
                    // Internal / theme managed by serializer, skip
                } else if (key == "theme_override_font_sizes/font_size") {
                    // Reverse-map back to VB6 FontSize (Godot px → VB6 pt)
                    int godot_px = val.to_int();
                    int vb6_pt = (godot_px > 0) ? (int)round(godot_px * 72.0 / 96.0) : 8;
                    current_item.properties["FontSize"] = vb6_pt;
                } else if (key == "theme_override_fonts/font") {
                    // Reverse-map SystemFont sub_resource → FontName/FontBold/FontItalic
                    // val = SubResource("ctrl_font_XXX")
                    if (val.begins_with("SubResource(\"") && val.ends_with("\")")) {
                        String sub_id = val.substr(13, val.length() - 15);
                        if (sub_resource_props.has(sub_id)) {
                            Dictionary sp = sub_resource_props[sub_id];
                            if (sp.has("font_names")) {
                                // PackedStringArray("Arial") → extract "Arial"
                                String fn = String(sp["font_names"]);
                                int q1 = fn.find("\"");
                                int q2 = fn.find("\"", q1 + 1);
                                if (q1 >= 0 && q2 > q1) {
                                    current_item.properties["FontName"] = fn.substr(q1 + 1, q2 - q1 - 1);
                                }
                            }
                            if (sp.has("font_weight")) {
                                int fw = String(sp["font_weight"]).to_int();
                                current_item.properties["FontBold"] = (fw >= 700);
                            }
                            if (sp.has("font_italic")) {
                                current_item.properties["FontItalic"] = (String(sp["font_italic"]) == "true");
                            }
                        }
                    }
                } else if (key == "theme_override_colors/font_color") {
                    // Reverse-map → VB6 ForeColor
                    if (val.begins_with("Color(") && val.ends_with(")")) {
                        String inner = val.substr(6, val.length() - 7);
                        PackedStringArray parts = inner.split(",");
                        if (parts.size() >= 3) {
                            float a = (parts.size() >= 4) ? parts[3].strip_edges().to_float() : 1.0f;
                            Color c(parts[0].strip_edges().to_float(),
                                    parts[1].strip_edges().to_float(),
                                    parts[2].strip_edges().to_float(), a);
                            current_item.properties["ForeColor"] = c;
                        }
                    }
                } else if (key == "theme_override_styles/normal") {
                    // Reverse-map per-control StyleBoxFlat → BackColor + BorderStyle
                    if (val.begins_with("SubResource(\"") && val.ends_with("\")")) {
                        String sub_id = val.substr(13, val.length() - 15);
                        if (sub_resource_props.has(sub_id) && sub_id.begins_with("ctrl_bg_")) {
                            Dictionary sp = sub_resource_props[sub_id];
                            if (sp.has("bg_color")) {
                                String bc_str = String(sp["bg_color"]);
                                if (bc_str.begins_with("Color(") && bc_str.ends_with(")")) {
                                    String inner = bc_str.substr(6, bc_str.length() - 7);
                                    PackedStringArray parts = inner.split(",");
                                    if (parts.size() >= 3) {
                                        float a = (parts.size() >= 4) ? parts[3].strip_edges().to_float() : 1.0f;
                                        Color c(parts[0].strip_edges().to_float(),
                                                parts[1].strip_edges().to_float(),
                                                parts[2].strip_edges().to_float(), a);
                                        current_item.properties["BackColor"] = c;
                                    }
                                }
                            }
                            // Check border_width to determine BorderStyle
                            if (sp.has("border_width_top")) {
                                int bw = String(sp["border_width_top"]).to_int();
                                current_item.properties["BorderStyle"] = (bw > 0) ? 1 : 0;
                            }
                        }
                    }
                } else if (key == "color" && current_node_type == "ColorRect") {
                    // ColorRect color → ShapeColor
                    if (val.begins_with("Color(") && val.ends_with(")")) {
                        String inner = val.substr(6, val.length() - 7);
                        PackedStringArray parts = inner.split(",");
                        if (parts.size() >= 3) {
                            float a = (parts.size() >= 4) ? parts[3].strip_edges().to_float() : 1.0f;
                            Color c(parts[0].strip_edges().to_float(),
                                    parts[1].strip_edges().to_float(),
                                    parts[2].strip_edges().to_float(), a);
                            current_item.properties["ShapeColor"] = c;
                        }
                    }
                } else if (key == "metadata/vb6_control_array_index") {
                    // Restore VB6 control array index
                    current_item.control_array_index = val.to_int();
                } else {
                    // Generic property — parse typed values back into proper Variants
                    // so _serialize_to_tscn writes them with the correct format.
                    //
                    // Reverse-translate Godot property names → VB6 names so the
                    // Properties panel shows VB6-style labels.
                    String vb6_key = key;
                    Variant parsed_val;
                    bool transform_val = false;
                    bool skip = false;
                    if (key == "tooltip_text")                { vb6_key = "ToolTipText"; }
                    else if (key == "focus_mode") {
                        vb6_key = "TabStop";
                        // focus_mode 2 (FOCUS_ALL) → TabStop=True, 0 → False
                        transform_val = true;
                        parsed_val = (val.to_int() != 0);
                    }
                    else if (key == "max_length")             { vb6_key = "MaxLength"; }
                    else if (key == "horizontal_alignment")   { vb6_key = "Alignment"; }
                    else if (key == "mouse_default_cursor_shape") { vb6_key = "MousePointer"; }
                    else if (key == "autowrap_mode") {
                        vb6_key = "WordWrap";
                        transform_val = true;
                        parsed_val = (val.to_int() != 0);
                    }
                    else if (key == "editable") {
                        vb6_key = "Locked";
                        transform_val = true;
                        parsed_val = !(val == "true");
                    }
                    else if (key == "disabled") {
                        vb6_key = "Enabled";
                        transform_val = true;
                        parsed_val = !(val == "true");
                    }
                    // ── Simple snake_case → PascalCase reverse mappings ──
                    else if (key == "flat")                         { vb6_key = "Flat"; }
                    else if (key == "clip_text")                    { vb6_key = "ClipText"; }
                    else if (key == "placeholder_text")             { vb6_key = "PlaceholderText"; }
                    else if (key == "clear_button_enabled")         { vb6_key = "ClearButton"; }
                    else if (key == "select_all_on_focus")          { vb6_key = "SelectAllOnFocus"; }
                    else if (key == "prefix")                       { vb6_key = "Prefix"; }
                    else if (key == "suffix")                       { vb6_key = "Suffix"; }
                    else if (key == "show_percentage")              { vb6_key = "ShowPercentage"; }
                    else if (key == "indeterminate")                { vb6_key = "Indeterminate"; }
                    else if (key == "fill_mode")                    { vb6_key = "FillMode"; }
                    else if (key == "tick_count")                   { vb6_key = "TickCount"; }
                    else if (key == "ticks_on_borders")             { vb6_key = "TicksOnBorders"; }
                    else if (key == "scrollable")                   { vb6_key = "Scrollable"; }
                    else if (key == "hide_root")                    { vb6_key = "HideRoot"; }
                    else if (key == "hide_folding")                 { vb6_key = "HideFolding"; }
                    else if (key == "allow_reselect")               { vb6_key = "AllowReselect"; }
                    else if (key == "allow_rmb_select")             { vb6_key = "AllowRmbSelect"; }
                    else if (key == "select_mode")                  { vb6_key = "SelectMode"; }
                    else if (key == "column_titles_visible")        { vb6_key = "ColumnTitlesVisible"; }
                    else if (key == "scroll_horizontal_enabled")    { vb6_key = "ScrollHorizontalEnabled"; }
                    else if (key == "scroll_vertical_enabled")      { vb6_key = "ScrollVerticalEnabled"; }
                    else if (key == "clip_tabs")                    { vb6_key = "ClipTabs"; }
                    else if (key == "drag_to_rearrange_enabled")    { vb6_key = "DragToRearrangeEnabled"; }
                    else if (key == "tab_alignment")                { vb6_key = "TabAlignment"; }
                    else if (key == "fit_to_longest_item")          { vb6_key = "FitToLongestItem"; }
                    else if (key == "auto_height")                  { vb6_key = "AutoHeight"; }
                    else if (key == "same_column_width")            { vb6_key = "SameColumnWidth"; }
                    else if (key == "max_columns")                  { vb6_key = "MaxColumns"; }
                    else if (key == "fixed_column_width")           { vb6_key = "FixedColumnWidth"; }
                    else if (key == "bbcode_enabled")               { vb6_key = "BbcodeEnabled"; }
                    else if (key == "fit_content")                  { vb6_key = "FitContent"; }
                    else if (key == "scroll_active")                { vb6_key = "ScrollActive"; }
                    else if (key == "selection_enabled")            { vb6_key = "SelectionEnabled"; }
                    else if (key == "flip_h")                       { vb6_key = "FlipH"; }
                    else if (key == "flip_v")                       { vb6_key = "FlipV"; }
                    else if (key == "stretch_mode")                 { vb6_key = "StretchMode"; }
                    else if (key == "ignore_texture_size")          { vb6_key = "IgnoreTextureSize"; }
                    else if (key == "switch_on_hover")              { vb6_key = "SwitchOnHover"; }
                    else if (key == "prefer_global_menu")           { vb6_key = "PreferGlobalMenu"; }
                    else if (key == "vertical_alignment")           { vb6_key = "VerticalAlignment"; }
                    else if (key == "clip_contents")                { vb6_key = "ClipContents"; }
                    else if (key == "size_flags_horizontal")        { vb6_key = "SizeFlagsHorizontal"; }
                    else if (key == "size_flags_vertical")          { vb6_key = "SizeFlagsVertical"; }
                    else if (key == "layout_direction")             { vb6_key = "LayoutDirection"; }
                    else if (key == "virtual_keyboard_enabled")     { vb6_key = "VirtualKeyboardEnabled"; }
                    else if (key == "keep_pressed_outside")         { vb6_key = "KeepPressedOutside"; }
                    else if (key == "action_mode")                  { vb6_key = "ActionMode"; }
                    else if (key == "update_on_text_changed")       { vb6_key = "UpdateOnTextChanged"; }
                    else if (key == "text_overrun_behavior")        { vb6_key = "TextOverrunBehavior"; }
                    else if (key == "max_lines_visible")            { vb6_key = "MaxLinesVisible"; }
                    else if (key == "current_tab")                  { vb6_key = "CurrentTab"; }
                    else if (key == "page")                         { vb6_key = "Page"; }
                    else if (key == "custom_step")                  { vb6_key = "CustomStep"; }
                    else if (key == "show_behind_parent")           { vb6_key = "ShowBehindParent"; }
                    else if (key == "min_value")                    { vb6_key = "Min"; }
                    else if (key == "max_value")                    { vb6_key = "Max"; }
                    else if (key == "step")                         { vb6_key = "Step"; }
                    else if (key == "allow_greater")                { vb6_key = "AllowGreater"; }
                    else if (key == "allow_lesser")                 { vb6_key = "AllowLesser"; }
                    else if (key == "rounded")                      { vb6_key = "Rounded"; }
                    else if (key == "button_pressed")               { vb6_key = "Value"; }
                    else if (key == "value")                        { vb6_key = "Value"; }
                    else if (key == "icon_mode")                    { vb6_key = "IconMode"; }
                    else if (key == "rotation_degrees")             { vb6_key = "Rotation"; }
                    else if (key == "columns")                      { vb6_key = "Columns"; }
                    else if (key == "grow_horizontal")              { vb6_key = "GrowHorizontal"; }
                    else if (key == "grow_vertical")                { vb6_key = "GrowVertical"; }
                    else if (key == "text_direction") {
                        vb6_key = "RightToLeft";
                        transform_val = true;
                        parsed_val = (val.to_int() == 2);  // TEXT_DIRECTION_RTL=2
                    }
                    else if (key == "secret") { skip = true; }  // Handled with secret_character → PasswordChar
                    else if (key == "secret_character") {
                        vb6_key = "PasswordChar";
                    }
                    else if (key == "visible") {
                        // visible is handled as item.visible, not as a property
                        current_item.visible = (val == "true");
                        skip = true;
                    }
                    // ── Vector2 composites: scale, pivot_offset, custom_minimum_size, modulate ──
                    else if (key == "scale") {
                        // Parse Vector2(sx, sy) → ScaleX, ScaleY
                        if (val.begins_with("Vector2(")) {
                            String inner = val.substr(8, val.length() - 9);
                            PackedStringArray parts = inner.split(",");
                            if (parts.size() >= 2) {
                                current_item.properties["ScaleX"] = parts[0].strip_edges().to_float();
                                current_item.properties["ScaleY"] = parts[1].strip_edges().to_float();
                            }
                        }
                        skip = true;
                    }
                    else if (key == "pivot_offset") {
                        if (val.begins_with("Vector2(")) {
                            String inner = val.substr(8, val.length() - 9);
                            PackedStringArray parts = inner.split(",");
                            if (parts.size() >= 2) {
                                current_item.properties["PivotOffsetX"] = parts[0].strip_edges().to_float();
                                current_item.properties["PivotOffsetY"] = parts[1].strip_edges().to_float();
                            }
                        }
                        skip = true;
                    }
                    else if (key == "custom_minimum_size") {
                        if (val.begins_with("Vector2(")) {
                            String inner = val.substr(8, val.length() - 9);
                            PackedStringArray parts = inner.split(",");
                            if (parts.size() >= 2) {
                                current_item.properties["MinWidth"] = parts[0].strip_edges().to_int();
                                current_item.properties["MinHeight"] = parts[1].strip_edges().to_int();
                            }
                        }
                        skip = true;
                    }
                    else if (key == "modulate") {
                        // modulate alpha → Opacity
                        if (val.begins_with("Color(")) {
                            String inner = val.substr(6, val.length() - 7);
                            PackedStringArray parts = inner.split(",");
                            if (parts.size() >= 4) {
                                float alpha = parts[3].strip_edges().to_float();
                                current_item.properties["Opacity"] = (int)(alpha * 100.0f);
                            }
                        }
                        skip = true;
                    }
                    // anchors/offsets/grow — already parsed above, skip
                    else if (key.begins_with("anchors_") || key.begins_with("anchor_") ||
                             key.begins_with("offset_") ||
                             key.begins_with("metadata/")) {
                        // Already handled or kept as-is
                        if (key.begins_with("metadata/")) {
                            // Store metadata keys without the metadata/ prefix
                            String meta_key = key.substr(9);
                            if (meta_key == "Tag") {
                                vb6_key = "Tag";
                            }
                        } else {
                            skip = true;
                        }
                    }
                    // theme_override_font_sizes/font_size already parsed above as FontSize

                    if (skip) {
                        // Property already handled above (composites, visible, etc.)
                    } else if (transform_val) {
                        current_item.properties[vb6_key] = parsed_val;
                    } else if (val.begins_with("\"") && val.ends_with("\"")) {
                        // Quoted string
                        val = val.substr(1, val.length() - 2);
                        // Strip PackedStringArray(...) wrapper if present (corrupted save)
                        if (val.begins_with("PackedStringArray(") && val.ends_with(")")) {
                            val = val.substr(18, val.length() - 19);
                            val = val.replace("\"", "");
                        }
                        current_item.properties[vb6_key] = val;
                    } else if (val.begins_with("Color(") && val.ends_with(")")) {
                        // Color(r, g, b, a)
                        String inner = val.substr(6, val.length() - 7);
                        PackedStringArray parts = inner.split(",");
                        if (parts.size() >= 4) {
                            Color c(parts[0].strip_edges().to_float(),
                                    parts[1].strip_edges().to_float(),
                                    parts[2].strip_edges().to_float(),
                                    parts[3].strip_edges().to_float());
                            current_item.properties[vb6_key] = c;
                        } else if (parts.size() >= 3) {
                            Color c(parts[0].strip_edges().to_float(),
                                    parts[1].strip_edges().to_float(),
                                    parts[2].strip_edges().to_float());
                            current_item.properties[vb6_key] = c;
                        } else {
                            current_item.properties[vb6_key] = val;
                        }
                    } else if (val.begins_with("Vector2(") && val.ends_with(")")) {
                        String inner = val.substr(8, val.length() - 9);
                        PackedStringArray parts = inner.split(",");
                        if (parts.size() >= 2) {
                            Vector2 v(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float());
                            current_item.properties[vb6_key] = v;
                        } else {
                            current_item.properties[vb6_key] = val;
                        }
                    } else if (val.begins_with("Vector2i(") && val.ends_with(")")) {
                        String inner = val.substr(9, val.length() - 10);
                        PackedStringArray parts = inner.split(",");
                        if (parts.size() >= 2) {
                            Vector2i v(parts[0].strip_edges().to_int(), parts[1].strip_edges().to_int());
                            current_item.properties[vb6_key] = v;
                        } else {
                            current_item.properties[vb6_key] = val;
                        }
                    } else if (val == "true") {
                        current_item.properties[vb6_key] = true;
                    } else if (val == "false") {
                        current_item.properties[vb6_key] = false;
                    } else if (val.is_valid_int()) {
                        current_item.properties[vb6_key] = val.to_int();
                    } else if (val.is_valid_float()) {
                        current_item.properties[vb6_key] = val.to_float();
                    } else {
                        current_item.properties[vb6_key] = val;
                    }
                }
            }
        }

        i++;
    }

    // Commit last node (skip root node — it's not a control)
    if (in_node && !is_root_node) {
        if (!current_node_name.begins_with("_") && current_node_parent == ".") {
            if (current_node_type == "MenuBar" || current_node_name == "MainMenu") {
                has_menu_bar = true;
                menu_bar_node_name = current_node_name;
            } else {
                controls.push_back(current_item);
            }
        } else if (!menu_bar_node_name.is_empty() && current_node_parent == menu_bar_node_name) {
            // Child of the MenuBar (PopupMenu) → store raw block + extract title
            menu_child_raw_blocks.push_back(current_raw_block);
            String title = current_node_name;
            if (title.begins_with("mnu") && title.length() > 3) {
                title = title.substr(3);
            }
            menu_titles.push_back(title);
        }
    }

    // Fix up controls with zero size
    for (int c = 0; c < controls.size(); c++) {
        if (controls[c].rect.size.x <= 0 || controls[c].rect.size.y <= 0) {
            controls.write[c].rect.size = _default_size_for_type(controls[c].type);
        }
    }

    return true;
}

// =============================================================================
// File I/O
// =============================================================================

bool VisualGasicFormDesigner::open_form(const String &p_tscn_path) {
    Ref<FileAccess> file = FileAccess::open(p_tscn_path, FileAccess::READ);
    if (!file.is_valid()) {
        UtilityFunctions::printerr("FormDesigner: Could not open: ", p_tscn_path);
        return false;
    }

    String text = file->get_as_text();
    file.unref();

    form_path = p_tscn_path;
    if (!_parse_tscn(text)) {
        UtilityFunctions::printerr("FormDesigner: Failed to parse: ", p_tscn_path);
        return false;
    }

    dirty = false;
    undo_stack.clear();
    redo_stack.clear();
    _update_min_size();
    _rebuild_all_live_previews();
    queue_redraw();
    UtilityFunctions::print("FormDesigner: Opened '", form_name, "' with ", controls.size(), " controls");

    // Auto-inject VB6 Classic Theme if the .tscn was saved before the theme
    // feature existed.  Only writes once; subsequent opens find the marker and skip.
    if (text.find("vb6_theme") < 0) {
        save_form_as(p_tscn_path);
        UtilityFunctions::print("FormDesigner: Auto-injected VB6 Classic Theme into ", p_tscn_path);
    }

    return true;
}

bool VisualGasicFormDesigner::save_form() {
    if (form_path.is_empty()) {
        UtilityFunctions::printerr("FormDesigner: No path set. Use save_form_as().");
        return false;
    }
    return save_form_as(form_path);
}

bool VisualGasicFormDesigner::save_form_as(const String &p_tscn_path) {
    form_path = p_tscn_path;

    // Validate scene paths — fall back to prototype if custom file was deleted
    _validate_scene_paths();

    // Ensure VG script file exists
    String vg_path = form_path.get_basename() + ".vg";
    if (!FileAccess::file_exists(vg_path)) {
        Ref<FileAccess> vg_file = FileAccess::open(vg_path, FileAccess::WRITE);
        if (vg_file.is_valid()) {
            vg_file->store_string("' " + form_name + " - VisualGasic Form\n\nPrivate Sub Form_Load()\n    ' Initialization code here\nEnd Sub\n");
            vg_file.unref();
        }
    }

    String tscn_text = _serialize_to_tscn();

    Ref<FileAccess> file = FileAccess::open(p_tscn_path, FileAccess::WRITE);
    if (!file.is_valid()) {
        UtilityFunctions::printerr("FormDesigner: Could not write: ", p_tscn_path);
        return false;
    }

    file->store_string(tscn_text);
    file.unref();

    dirty = false;
    UtilityFunctions::print("FormDesigner: Saved '", form_name, "' to ", p_tscn_path);
    return true;
}

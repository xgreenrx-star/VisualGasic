#include "visual_gasic_form_designer.h"

#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/editor_interface.hpp>

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

    // Properties
    ADD_PROPERTY(PropertyInfo(Variant::INT, "grid_size"), "set_grid_size", "get_grid_size");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "grid_visible"), "set_grid_visible", "get_grid_visible");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "snap_enabled"), "set_snap_enabled", "get_snap_enabled");

    // Signals
    ADD_SIGNAL(MethodInfo("control_selected", PropertyInfo(Variant::INT, "index")));
    ADD_SIGNAL(MethodInfo("control_deselected"));
    ADD_SIGNAL(MethodInfo("form_modified"));
    ADD_SIGNAL(MethodInfo("control_double_clicked", PropertyInfo(Variant::INT, "index")));
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
    set_custom_minimum_size(Vector2(200, 200));
}

void VisualGasicFormDesigner::_process(double p_delta) {
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
    _draw_form_background();
    _draw_grid();

    // Draw controls back-to-front
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].visible) {
            _draw_control(controls[i], i);
        }
    }

    // Draw selection handles on top for selected controls
    for (int i = 0; i < controls.size(); i++) {
        if (controls[i].selected) {
            _draw_selection_handles(controls[i].rect);
        }
    }

    _draw_rubber_band();
    _draw_toolbox_preview();
}

void VisualGasicFormDesigner::_draw_form_background() {
    // Classic VB6 form background
    Rect2 bg = Rect2(Vector2(), Vector2(form_size));
    draw_rect(bg, color_form_bg);
    // Border
    draw_rect(bg, Color(0.4, 0.4, 0.4), false, 1.0);
    // Title bar simulation
    Rect2 title_bar(Vector2(0, -24), Vector2(form_size.x, 24));
    draw_rect(title_bar, Color(0.0, 0.0, 0.5)); // VB6 dark blue title bar
    // Title text
    Ref<Font> font = get_theme_default_font();
    if (font.is_valid()) {
        int font_size = get_theme_default_font_size();
        draw_string(font, Vector2(4, -8), form_name, HORIZONTAL_ALIGNMENT_LEFT, form_size.x - 8, font_size, Color(1, 1, 1));
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
    Color bg = _design_color_for_type(item.type);
    Color border = item.selected ? color_selected : color_control_border;
    float border_width = item.selected ? 2.0f : 1.0f;

    // Fill
    draw_rect(r, bg);
    // Border
    draw_rect(r, border, false, border_width);

    // Type icon / label in top-left
    Ref<Font> font = get_theme_default_font();
    if (font.is_valid()) {
        int font_size = get_theme_default_font_size();
        String label = item.text.is_empty() ? item.name : item.text;
        // Clamp text inside control rect
        float max_w = r.size.x - 4;
        if (max_w > 10) {
            draw_string(font, r.position + Vector2(3, font_size + 2), label, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, color_text);
        }
        // Type indicator (small text, top-right)
        String type_label = _display_label_for_type(item.type);
        draw_string(font, r.position + Vector2(r.size.x - 3, 10), type_label, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6, 9, Color(0.4, 0.4, 0.4));
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
    if (!show_preview) return;

    Vector2 sz = _default_size_for_type(preview_type);
    Rect2 preview_rect(preview_pos - sz * 0.5, sz);
    Color preview_color = _design_color_for_type(preview_type);
    preview_color.a = 0.5;

    draw_rect(preview_rect, preview_color);
    draw_rect(preview_rect, Color(0, 0, 0.6, 0.7), false, 1.0);

    Ref<Font> font = get_theme_default_font();
    if (font.is_valid()) {
        draw_string(font, preview_rect.position + Vector2(3, 14), preview_type, HORIZONTAL_ALIGNMENT_LEFT, preview_rect.size.x - 6, 12, Color(0, 0, 0, 0.7));
    }
}

// =============================================================================
// Hit testing
// =============================================================================

int VisualGasicFormDesigner::_hit_test(const Vector2 &p_pos) const {
    // Back-to-front (topmost first)
    for (int i = controls.size() - 1; i >= 0; i--) {
        if (controls[i].visible && controls[i].rect.has_point(p_pos)) {
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
// Mouse input
// =============================================================================

void VisualGasicFormDesigner::_gui_input(const Ref<InputEvent> &p_event) {
    Ref<InputEventMouseButton> mb = p_event;
    Ref<InputEventMouseMotion> mm = p_event;
    Ref<InputEventKey> key = p_event;

    if (mb.is_valid()) {
        if (mb->is_pressed()) {
            _on_mouse_down(mb);
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

    Vector2 pos = p_event->get_position();
    mouse_down_pos = pos;
    mouse_current_pos = pos;

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
        queue_redraw();
        accept_event();
    }
}

void VisualGasicFormDesigner::_on_mouse_up(const Ref<InputEventMouseButton> &p_event) {
    if (p_event->get_button_index() != MOUSE_BUTTON_LEFT) return;

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
    mouse_current_pos = p_event->get_position();

    // Update toolbox preview position
    if (show_preview) {
        preview_pos = mouse_current_pos;
        queue_redraw();
    }

    if (mode == MODE_SELECTING) {
        rubber_band_rect = Rect2(mouse_down_pos, mouse_current_pos - mouse_down_pos);
        queue_redraw();
        return;
    }

    if (mode == MODE_MOVING) {
        Vector2 delta = _snap(mouse_current_pos - drag_offset) - controls[drag_control_index].rect.position;
        // Move all selected controls by the same delta
        for (int i = 0; i < controls.size(); i++) {
            if (controls[i].selected) {
                controls.write[i].rect.position += delta;
            }
        }
        _mark_dirty();
        queue_redraw();
        return;
    }

    if (mode == MODE_RESIZING && drag_control_index >= 0) {
        Vector2 snapped = _snap(mouse_current_pos);
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
        _mark_dirty();
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
    }
    return false;
}

void VisualGasicFormDesigner::_drop_data(const Vector2 &p_point, const Variant &p_data) {
    Dictionary data = p_data;
    String type = data.get("class_name", "Control");
    String scene_path = data.get("scene_path", "");

    Vector2 sz = _default_size_for_type(type);
    Vector2 pos = _snap(p_point - sz * 0.5);

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
    item.type = p_type;
    item.scene_path = p_scene_path;
    item.name = _make_unique_name(p_type);
    item.rect.position = p_position;
    item.rect.size = (p_size.x > 0 && p_size.y > 0) ? p_size : _default_size_for_type(p_type);

    // Set default text for text-bearing controls
    if (p_type == "Button" || p_type == "Label" || p_type == "CheckBox" || p_type == "OptionButton") {
        item.text = item.name;
    }

    controls.push_back(item);
    int idx = controls.size() - 1;

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
    } else {
        // Store in generic property bag
        controls.write[p_index].properties[p_key] = p_value;
    }

    action.after_state = controls[p_index];
    _push_undo(action);

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
        item.name = _make_unique_name(item.type);
        item.rect.position += offset;
        item.selected = true;
        if (!item.text.is_empty()) {
            item.text = item.name;
        }
        controls.push_back(item);
    }

    _mark_dirty();
    queue_redraw();
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
    if (p_type == "Control")      return Vector2(150, 28); // VGComboBox
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
    dirty = false;
    queue_redraw();
    UtilityFunctions::print("FormDesigner: New form '", p_name, "'");
}

// =============================================================================
// .tscn serializer
// =============================================================================

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

    // Menu bar helper
    String menubar_helper_path = "res://addons/visual_gasic/menu_bar_helper.gd";
    {
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
    int next_id = 4;
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

    // Build the .tscn text
    String out;
    int load_steps = ext_resources.size() + 1;
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

    // Root node (Window)
    out += "[node name=\"" + form_name + "\" type=\"Window\"]\n";
    out += "title = \"" + form_name + "\"\n";
    out += "position = Vector2i(10, 36)\n";
    out += "size = Vector2i(" + String::num_int64(form_size.x) + ", " + String::num_int64(form_size.y) + ")\n";
    out += "script = ExtResource(\"" + String::num_int64(path_to_idx[vg_script_path]) + "\")\n";
    out += "\n";

    // _FormBackground panel
    out += "[node name=\"_FormBackground\" type=\"Panel\" parent=\".\"]\n";
    out += "offset_right = " + String::num_int64(form_size.x) + ".0\n";
    out += "offset_bottom = " + String::num_int64(form_size.y) + ".0\n";
    out += "mouse_filter = 2\n";  // MOUSE_FILTER_PASS
    out += "script = ExtResource(\"" + String::num_int64(path_to_idx[helper_path]) + "\")\n";
    out += "\n";

    // MenuBar
    out += "[node name=\"MainMenu\" type=\"MenuBar\" parent=\".\"]\n";
    out += "offset_right = " + String::num_int64(form_size.x) + ".0\n";
    out += "offset_bottom = 30.0\n";
    out += "mouse_filter = 2\n";  // IGNORE in editor
    out += "script = ExtResource(\"" + String::num_int64(path_to_idx[menubar_helper_path]) + "\")\n";
    out += "\n";

    // Default menus
    out += "[node name=\"mnuFile\" type=\"PopupMenu\" parent=\"MainMenu\"]\n\n";
    out += "[node name=\"mnuEdit\" type=\"PopupMenu\" parent=\"MainMenu\"]\n\n";

    // User controls
    for (int i = 0; i < controls.size(); i++) {
        const FormControlItem &ctrl = controls[i];
        String sp = ctrl.scene_path;

        if (!sp.is_empty() && path_to_idx.has(sp)) {
            // Instance from prototype scene
            out += "[node name=\"" + ctrl.name + "\" parent=\".\" instance=ExtResource(\"" + String::num_int64(path_to_idx[sp]) + "\")]\n";
        } else {
            // Fallback: bare type node
            out += "[node name=\"" + ctrl.name + "\" type=\"" + ctrl.type + "\" parent=\".\"]\n";
        }

        out += "offset_left = " + String::num_int64((int)ctrl.rect.position.x) + ".0\n";
        out += "offset_top = " + String::num_int64((int)ctrl.rect.position.y) + ".0\n";
        out += "offset_right = " + String::num_int64((int)(ctrl.rect.position.x + ctrl.rect.size.x)) + ".0\n";
        out += "offset_bottom = " + String::num_int64((int)(ctrl.rect.position.y + ctrl.rect.size.y)) + ".0\n";

        if (!ctrl.text.is_empty()) {
            out += "text = \"" + ctrl.text + "\"\n";
        }

        // Write extra properties
        Array keys = ctrl.properties.keys();
        for (int k = 0; k < keys.size(); k++) {
            String key = keys[k];
            Variant val = ctrl.properties[key];
            if (val.get_type() == Variant::STRING) {
                out += key + " = \"" + String(val) + "\"\n";
            } else {
                out += key + " = " + String(val) + "\n";
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

    // Second pass: parse nodes
    i = 0;
    String current_node_name;
    String current_node_type;
    String current_node_parent;
    String current_instance_id;
    bool in_node = false;
    FormControlItem current_item;

    while (i < lines.size()) {
        String line = lines[i].strip_edges();

        if (line.begins_with("[node ")) {
            // Commit previous node if it was a user control
            if (in_node && !current_node_name.begins_with("_") && current_node_parent == ".") {
                // Skip internal nodes (MenuBar, PopupMenu, _FormBackground)
                if (current_node_name != "MainMenu" && current_node_name != "mnuFile" && current_node_name != "mnuEdit") {
                    controls.push_back(current_item);
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

            // Root node (no parent) — extract form metadata
            if (current_node_parent.is_empty() && !line.contains("parent=")) {
                form_name = current_node_name;
                in_node = false; // Don't add root as a control
            }
        } else if (in_node && !line.is_empty() && !line.begins_with("[")) {
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
                            }
                        }
                    }
                } else if (key == "title") {
                    // Skip, we already have form_name from node name
                } else if (key == "script" || key == "mouse_filter") {
                    // Internal, skip
                } else {
                    // Generic property
                    if (val.begins_with("\"") && val.ends_with("\"")) {
                        val = val.substr(1, val.length() - 2);
                    }
                    current_item.properties[key] = val;
                }
            }
        }

        i++;
    }

    // Commit last node
    if (in_node && !current_node_name.begins_with("_") && current_node_parent == ".") {
        if (current_node_name != "MainMenu" && current_node_name != "mnuFile" && current_node_name != "mnuEdit") {
            controls.push_back(current_item);
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
    queue_redraw();
    UtilityFunctions::print("FormDesigner: Opened '", form_name, "' with ", controls.size(), " controls");
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

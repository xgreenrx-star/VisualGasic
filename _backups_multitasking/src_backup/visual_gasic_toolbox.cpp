#include "visual_gasic_toolbox.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/editor_selection.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void VisualGasicToolButton::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_create_class", "p_class"), &VisualGasicToolButton::set_create_class);
    ClassDB::bind_method(D_METHOD("get_create_class"), &VisualGasicToolButton::get_create_class);
    ClassDB::bind_method(D_METHOD("set_icon_name", "p_icon"), &VisualGasicToolButton::set_icon_name);
    ClassDB::bind_method(D_METHOD("set_scene_path", "p_path"), &VisualGasicToolButton::set_scene_path);
    ClassDB::bind_method(D_METHOD("get_scene_path"), &VisualGasicToolButton::get_scene_path);
    
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "create_class"), "set_create_class", "get_create_class");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "scene_path"), "set_scene_path", "get_scene_path");
}

void VisualGasicToolButton::set_create_class(const String &p_class) {
    create_class_name = p_class;
}

String VisualGasicToolButton::get_create_class() const {
    return create_class_name;
}

void VisualGasicToolButton::set_icon_name(const String &p_icon) {
    icon_name = p_icon;
}

void VisualGasicToolButton::set_scene_path(const String &p_path) {
    scene_path = p_path;
}

String VisualGasicToolButton::get_scene_path() const {
    return scene_path;
}

void VisualGasicToolButton::_notification(int p_what) {
    if (p_what == NOTIFICATION_THEME_CHANGED || p_what == NOTIFICATION_ENTER_TREE) {
        if (!icon_name.is_empty()) {
             // Access editor theme if available
             Control *base = EditorInterface::get_singleton()->get_base_control();
             if (base) {
                 Ref<Texture2D> icon = base->get_theme_icon(icon_name, "EditorIcons");
                 set_button_icon(icon);
             }
        }
    }
}

Variant VisualGasicToolButton::_get_drag_data(const Vector2 &at_position) {
    if (create_class_name.is_empty() && scene_path.is_empty()) return Variant();

    // Check for valid Scene Root
    EditorInterface *editor = EditorInterface::get_singleton();
    if (editor) {
        Node *root = editor->get_edited_scene_root();
        if (!root) {
            UtilityFunctions::printerr("VisualGasic: Cannot place control. Please create a Scene Root (User Interface / 2D Scene) first.");
            // Optional: You could show a Toast/OS::alert here if desired, but printerr is safe.
            return Variant(); 
        }
    }

    // Create preview
    TextureRect *preview = memnew(TextureRect);
    preview->set_texture(get_button_icon());
    preview->set_size(Vector2(32, 32));
    preview->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
    preview->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
    
    Control* c_preview = memnew(Control);
    c_preview->add_child(preview);
    preview->set_position(Vector2(-16, -16));
    
    set_drag_preview(c_preview);

    // Prepare Drag Data using FILES (Scenes)
    Dictionary data;
    data["type"] = "files";
    
    // Using PackedStringArray is the strictest, most correct way to pass file paths in Godot
    PackedStringArray files;
    String path;
    
    if (!scene_path.is_empty()) {
        path = scene_path;
    } else {
        path = "res://addons/visual_gasic/prototypes/" + create_class_name + ".tscn";
    }
    
    files.push_back(path);
    data["files"] = files;
    
    UtilityFunctions::print("VisualGasic Drag (PackedStringArray): ", path);

    return data;
}


// TOOLBOX

void VisualGasicToolbox::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_tool", "name", "godot_class", "icon_name", "scene_path", "category"), &VisualGasicToolbox::add_tool, DEFVAL(""), DEFVAL("2D"));
}

VisualGasicToolbox::VisualGasicToolbox() {
    set_name("Toolbox");
    
    set_h_size_flags(Control::SIZE_EXPAND_FILL);
    set_v_size_flags(Control::SIZE_EXPAND_FILL);
    set_custom_minimum_size(Vector2(240, 300));

    // Create Tabs
    tabs = memnew(TabContainer); 
    tabs->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    tabs->set_v_size_flags(Control::SIZE_EXPAND_FILL);
    add_child(tabs);

    // 2D Grid
    grid_2d = memnew(GridContainer);
    grid_2d->set_name("2D Tools");
    grid_2d->set_columns(2);
    grid_2d->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    grid_2d->set_v_size_flags(Control::SIZE_EXPAND_FILL);
    tabs->add_child(grid_2d);

    // 3D Grid
    grid_3d = memnew(GridContainer);
    grid_3d->set_name("3D Tools");
    grid_3d->set_columns(2);
    grid_3d->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    grid_3d->set_v_size_flags(Control::SIZE_EXPAND_FILL);
    tabs->add_child(grid_3d);

    // Add default tools (using standard class mapping)
    // 2D
    add_tool("Pointer", "", "ToolSelect"); 
    add_tool("Picture", "TextureRect", "TextureRect", "res://addons/visual_gasic/prototypes/TextureRect.tscn");
    add_tool("Label", "Label", "Label", "res://addons/visual_gasic/prototypes/Label.tscn"); 
    add_tool("TextBox", "LineEdit", "LineEdit", "res://addons/visual_gasic/prototypes/LineEdit.tscn");
    add_tool("Button", "Button", "Button", "res://addons/visual_gasic/prototypes/Button.tscn");
    add_tool("CheckBox", "CheckBox", "CheckBox", "res://addons/visual_gasic/prototypes/CheckBox.tscn");
    add_tool("ComboBox", "OptionButton", "OptionButton", "res://addons/visual_gasic/prototypes/OptionButton.tscn");
    add_tool("Frame", "Panel", "Panel", "res://addons/visual_gasic/prototypes/Panel.tscn");
    add_tool("CommandButton", "Button", "Button", "res://addons/visual_gasic/prototypes/Button.tscn"); 
    add_tool("ListBox", "ItemList", "ItemList", "res://addons/visual_gasic/prototypes/ItemList.tscn");
    add_tool("HScroll", "HScrollBar", "HScrollBar", "res://addons/visual_gasic/prototypes/HScrollBar.tscn");
    add_tool("VScroll", "VScrollBar", "VScrollBar", "res://addons/visual_gasic/prototypes/VScrollBar.tscn");
    add_tool("Timer", "Timer", "Timer", "res://addons/visual_gasic/prototypes/Timer.tscn");
    add_tool("Files", "FileDialog", "FileDialog", "res://addons/visual_gasic/prototypes/FileDialog.tscn"); 
}

VisualGasicToolbox::~VisualGasicToolbox() {
}

void VisualGasicToolbox::_notification(int p_what) {
}

void VisualGasicToolbox::add_tool(const String &p_name, const String &p_godot_class, const String &p_icon_name, const String &p_scene_path, const String &p_category) {
    VisualGasicToolButton *btn = memnew(VisualGasicToolButton);
    btn->set_tooltip_text(p_name); // Show name on hover only
    btn->set_create_class(p_godot_class);
    btn->set_icon_name(p_icon_name);
    if (!p_scene_path.is_empty()) {
        btn->set_scene_path(p_scene_path);
    }
    
    // Icon layout
    btn->set_custom_minimum_size(Vector2(32, 32));
    btn->set_icon_alignment(HORIZONTAL_ALIGNMENT_CENTER);
    btn->set_expand_icon(true);
    
    btn->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    btn->set_focus_mode(FOCUS_NONE); // Prevent stealing focus from Editor, which can mess up drag coordinates
    
    if (p_category == "3D") {
        grid_3d->add_child(btn);
    } else {
        grid_2d->add_child(btn);
    }
}

/*
void VisualGasicToolbox::add_tool(const String &p_name, const String &p_godot_class) {
    // Deprecated implementation
}
*/

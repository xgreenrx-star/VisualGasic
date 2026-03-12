#include "visual_gasic_toolbox.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/editor_selection.hpp>
#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/engine.hpp>
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
    // Only set the editor-theme icon once, when the button first enters the
    // tree.  The GDScript restyler (_restyle_toolbox_buttons) replaces every
    // icon with a custom SVG shortly after.  Reacting to THEME_CHANGED here
    // would overwrite those SVG icons every time a theme override is added.
    if (p_what == NOTIFICATION_ENTER_TREE) {
        if (!icon_name.is_empty()) {
             Control *base = EditorInterface::get_singleton()->get_base_control();
             if (base) {
                 Ref<Texture2D> icon = base->get_theme_icon(icon_name, "EditorIcons");
                 set_button_icon(icon);
             }
        }
    }
}

Object *VisualGasicToolButton::_make_custom_tooltip(const String &p_text) const {
    if (p_text.is_empty()) {
        return nullptr;
    }

    // Classic VB6 light-yellow tooltip with black text and 1px black border
    PanelContainer *panel = memnew(PanelContainer);
    Ref<StyleBoxFlat> sb;
    sb.instantiate();
    sb->set_bg_color(Color(1.0, 1.0, 0.94));   // Light yellow
    sb->set_border_color(Color(0.0, 0.0, 0.0)); // Black border
    sb->set_border_width_all(1);
    sb->set_content_margin_all(4);
    panel->add_theme_stylebox_override("panel", sb);

    Label *lbl = memnew(Label);
    lbl->set_text(p_text);
    lbl->add_theme_color_override("font_color", Color(0.0, 0.0, 0.0)); // Black text
    panel->add_child(lbl);

    return panel;
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

    // Use custom "vg_control" drag type - Godot's editor will IGNORE this type,
    // so it won't try to instance the scene itself. Instead, our GDScript plugin
    // handles the drop via _forward_canvas_gui_input mouse release.
    Dictionary data;
    data["type"] = "vg_control";
    String path = scene_path.is_empty() 
        ? "res://addons/visual_gasic/prototypes/" + create_class_name + ".tscn"
        : scene_path;
    data["scene_path"] = path;
    data["class_name"] = create_class_name;
    
    UtilityFunctions::print("VisualGasic Drag: ", path);
    
    // Store drag data in Engine singleton metadata so GDScript plugin can access it
    Engine::get_singleton()->set_meta("_vg_active_drag", data);

    return data;
}


// TOOLBOX

void VisualGasicToolbox::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_tool", "name", "godot_class", "icon_name", "scene_path", "category"), &VisualGasicToolbox::add_tool, DEFVAL(""), DEFVAL("2D"));
    ClassDB::bind_method(D_METHOD("remove_tool", "name"), &VisualGasicToolbox::remove_tool);
    ClassDB::bind_method(D_METHOD("clear_custom_tools"), &VisualGasicToolbox::clear_custom_tools);
    ClassDB::bind_method(D_METHOD("mark_defaults"), &VisualGasicToolbox::mark_defaults);
    ClassDB::bind_method(D_METHOD("get_active_tool_class"), &VisualGasicToolbox::get_active_tool_class);
    ClassDB::bind_method(D_METHOD("get_active_tool_scene"), &VisualGasicToolbox::get_active_tool_scene);
    ClassDB::bind_method(D_METHOD("reset_to_pointer"), &VisualGasicToolbox::reset_to_pointer);

    ADD_SIGNAL(MethodInfo("tool_selected",
        PropertyInfo(Variant::STRING, "class_name"),
        PropertyInfo(Variant::STRING, "scene_path")));
}

VisualGasicToolbox::VisualGasicToolbox() {
    set_name("Toolbox");
    
    set_h_size_flags(Control::SIZE_EXPAND_FILL);
    set_v_size_flags(Control::SIZE_EXPAND_FILL);
    set_custom_minimum_size(Vector2(100, 200));

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

    // Game UI Grid
    grid_game_ui = memnew(GridContainer);
    grid_game_ui->set_name("Game UI");
    grid_game_ui->set_columns(2);
    grid_game_ui->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    grid_game_ui->set_v_size_flags(Control::SIZE_EXPAND_FILL);
    tabs->add_child(grid_game_ui);

    // Add default tools organized by type (alphabetical within groups)
    // ── Pointer ──
    add_tool("Pointer", "", "ToolSelect"); 
    
    // ── Basic Controls ── (alphabetical)
    add_tool("Button", "Button", "Button", "res://addons/visual_gasic/prototypes/Button.tscn");
    add_tool("CheckBox", "CheckBox", "CheckBox", "res://addons/visual_gasic/prototypes/CheckBox.tscn");
    add_tool("ComboBox", "OptionButton", "OptionButton", "res://addons/visual_gasic/prototypes/OptionButton.tscn");
    add_tool("Label", "Label", "Label", "res://addons/visual_gasic/prototypes/Label.tscn"); 
    add_tool("RadioButton", "CheckBox", "CheckBox", "res://addons/visual_gasic/prototypes/RadioButton.tscn");
    add_tool("TextBox", "LineEdit", "LineEdit", "res://addons/visual_gasic/prototypes/LineEdit.tscn");
    
    // ── Container Controls ── (alphabetical)
    add_tool("Frame", "Panel", "Panel", "res://addons/visual_gasic/prototypes/Panel.tscn");
    add_tool("GroupBox", "Panel", "Panel", "res://addons/visual_gasic/prototypes/GroupBox.tscn");
    add_tool("TabStrip", "TabContainer", "TabContainer", "res://addons/visual_gasic/prototypes/TabContainer.tscn");

    // ── List Controls ── (alphabetical)
    add_tool("ListBox", "ItemList", "ItemList", "res://addons/visual_gasic/prototypes/ItemList.tscn");
    add_tool("ListView", "ItemList", "ItemList", "res://addons/visual_gasic/prototypes/ListView.tscn");
    add_tool("TreeView", "Tree", "Tree", "res://addons/visual_gasic/prototypes/Tree.tscn");
    
    // ── Text Controls ── (alphabetical)
    add_tool("RichText", "RichTextLabel", "RichTextLabel", "res://addons/visual_gasic/prototypes/RichTextLabel.tscn");
    add_tool("TextArea", "TextEdit", "TextEdit", "res://addons/visual_gasic/prototypes/TextEdit.tscn");

    // ── Display Controls ── (alphabetical)
    add_tool("Picture", "TextureRect", "TextureRect", "res://addons/visual_gasic/prototypes/TextureRect.tscn");
    add_tool("ProgressBar", "ProgressBar", "ProgressBar", "res://addons/visual_gasic/prototypes/ProgressBar.tscn");
    add_tool("Shape", "ColorRect", "ColorRect", "res://addons/visual_gasic/prototypes/ColorRect.tscn");
    
    // ── Menu / Bar Controls ── (alphabetical)
    add_tool("MenuBar", "MenuBar", "MenuBar", "res://addons/visual_gasic/prototypes/MenuBar.tscn");
    add_tool("StatusBar", "PanelContainer", "PanelContainer", "res://addons/visual_gasic/prototypes/StatusBar.tscn");
    add_tool("Toolbar", "PanelContainer", "HBoxContainer", "res://addons/visual_gasic/prototypes/Toolbar.tscn");

    // ── Line / Separator Controls ── (alphabetical)
    add_tool("HLine", "HSeparator", "HSeparator", "res://addons/visual_gasic/prototypes/HSeparator.tscn");
    add_tool("VLine", "VSeparator", "VSeparator", "res://addons/visual_gasic/prototypes/VSeparator.tscn");
    
    // ── Scroll / Slider Controls ── (alphabetical)
    add_tool("HScroll", "HScrollBar", "HScrollBar", "res://addons/visual_gasic/prototypes/HScrollBar.tscn");
    add_tool("HSlider", "HSlider", "HSlider", "res://addons/visual_gasic/prototypes/HSlider.tscn");
    add_tool("SpinBox", "SpinBox", "SpinBox", "res://addons/visual_gasic/prototypes/SpinBox.tscn");
    add_tool("VScroll", "VScrollBar", "VScrollBar", "res://addons/visual_gasic/prototypes/VScrollBar.tscn");
    add_tool("VSlider", "VSlider", "VSlider", "res://addons/visual_gasic/prototypes/VSlider.tscn");
    
    // ── Non-Visual Controls ── (alphabetical)
    add_tool("Files", "FileDialog", "FileDialog", "res://addons/visual_gasic/prototypes/FileDialog.tscn"); 
    add_tool("Timer", "Timer", "Timer", "res://addons/visual_gasic/prototypes/Timer.tscn"); 

    // ── Game UI Controls ── (for Game UI Mode)
    add_tool("Pointer",           "",              "ToolSelect",    "",                                                                         "Game UI");
    // Tier 1 — dedicated animated prototypes (v4.0)
    add_tool("DialogPanel",       "PanelContainer","RichTextLabel", "res://addons/visual_gasic/prototypes/game_ui/DialogPanel.tscn",             "Game UI");
    add_tool("InventoryGrid",     "PanelContainer","GridContainer", "res://addons/visual_gasic/prototypes/game_ui/InventoryGrid.tscn",           "Game UI");
    add_tool("StatBar",           "Control",       "ProgressBar",   "res://addons/visual_gasic/prototypes/game_ui/StatBar.tscn",                 "Game UI");
    add_tool("HUDCounter",        "HBoxContainer", "Label",         "res://addons/visual_gasic/prototypes/game_ui/HUDCounter.tscn",              "Game UI");
    add_tool("CooldownButton",    "TextureButton", "TextureButton", "res://addons/visual_gasic/prototypes/game_ui/CooldownButton.tscn",          "Game UI");
    add_tool("NotificationToast", "PanelContainer","PopupPanel",    "res://addons/visual_gasic/prototypes/game_ui/NotificationToast.tscn",       "Game UI");
    add_tool("GameMenu",          "ColorRect",     "ColorRect",     "res://addons/visual_gasic/prototypes/game_ui/GameMenu.tscn",                "Game UI");
    // Tier 2 — additional animated prototypes (v4.1)
    add_tool("Tooltip",           "PanelContainer","PopupPanel",    "res://addons/visual_gasic/prototypes/game_ui/Tooltip.tscn",                 "Game UI");
    add_tool("RadialMenu",        "Control",       "GraphEdit",     "res://addons/visual_gasic/prototypes/game_ui/RadialMenu.tscn",              "Game UI");
    add_tool("MiniMap",           "PanelContainer","SubViewport",   "res://addons/visual_gasic/prototypes/game_ui/MiniMap.tscn",                 "Game UI");
    add_tool("QuestTracker",      "PanelContainer","RichTextLabel", "res://addons/visual_gasic/prototypes/game_ui/QuestTracker.tscn",            "Game UI");
    add_tool("SettingsPanel",     "PanelContainer","VBoxContainer", "res://addons/visual_gasic/prototypes/game_ui/SettingsPanel.tscn",           "Game UI");
    add_tool("ConfirmDialog",     "PanelContainer","AcceptDialog",  "res://addons/visual_gasic/prototypes/game_ui/ConfirmDialog.tscn",           "Game UI");
    add_tool("LoadingScreen",     "ColorRect",     "ColorRect",     "res://addons/visual_gasic/prototypes/game_ui/LoadingScreen.tscn",           "Game UI");
    add_tool("DamageNumber",      "Label",         "Label",         "res://addons/visual_gasic/prototypes/game_ui/DamageNumber.tscn",            "Game UI");
    // Tier 3 — advanced game UI prototypes (v4.1)
    add_tool("SkillTree",         "Control",       "GraphEdit",     "res://addons/visual_gasic/prototypes/game_ui/SkillTree.tscn",               "Game UI");
    add_tool("ChatBox",           "PanelContainer","RichTextLabel", "res://addons/visual_gasic/prototypes/game_ui/ChatBox.tscn",                 "Game UI");
    add_tool("ItemSlot",          "PanelContainer","GridContainer", "res://addons/visual_gasic/prototypes/game_ui/ItemSlot.tscn",                "Game UI");
    add_tool("TabPanel",          "PanelContainer","TabContainer",  "res://addons/visual_gasic/prototypes/game_ui/TabPanel.tscn",                "Game UI");
    add_tool("GamePopup",         "PanelContainer","PopupPanel",    "res://addons/visual_gasic/prototypes/game_ui/GamePopup.tscn",               "Game UI");
    add_tool("Compass",           "Control",       "Control",       "res://addons/visual_gasic/prototypes/game_ui/Compass.tscn",                 "Game UI");
    add_tool("AmmoCounter",       "HBoxContainer", "Label",         "res://addons/visual_gasic/prototypes/game_ui/AmmoCounter.tscn",             "Game UI");
    add_tool("XPBar",             "Control",       "ProgressBar",   "res://addons/visual_gasic/prototypes/game_ui/XPBar.tscn",                   "Game UI");
    // Legacy aliases (kept for backward compatibility)
    add_tool("HealthBar",    "ProgressBar",  "ProgressBar",  "res://addons/visual_gasic/prototypes/ProgressBar.tscn",  "Game UI");
    add_tool("ScoreLabel",   "Label",         "Label",         "res://addons/visual_gasic/prototypes/Label.tscn",         "Game UI");
    add_tool("ActionButton", "Button",        "Button",        "res://addons/visual_gasic/prototypes/Button.tscn",        "Game UI");
    add_tool("Crosshair",    "TextureRect",   "TextureRect",   "res://addons/visual_gasic/prototypes/TextureRect.tscn",   "Game UI");
    
    // Mark these as default tools (won't be removed by clear_custom_tools)
    mark_defaults();
}

VisualGasicToolbox::~VisualGasicToolbox() {
}

void VisualGasicToolbox::_notification(int p_what) {
}

void VisualGasicToolbox::add_tool(const String &p_name, const String &p_godot_class, const String &p_icon_name, const String &p_scene_path, const String &p_category) {
    VisualGasicToolButton *btn = memnew(VisualGasicToolButton);
    btn->set_tooltip_text(p_name); // Show name on hover only
    btn->set_name(p_name); // Set node name for lookup
    btn->set_create_class(p_godot_class);
    btn->set_icon_name(p_icon_name);
    if (!p_scene_path.is_empty()) {
        btn->set_scene_path(p_scene_path);
    }
    
    // Icon layout
    btn->set_custom_minimum_size(Vector2(32, 32));
    btn->set_icon_alignment(HORIZONTAL_ALIGNMENT_CENTER);
    btn->set_expand_icon(true);

    // Toggle mode — clicking selects the active tool (VB6 style)
    btn->set_toggle_mode(true);
    btn->set_pressed(false);
    btn->connect("pressed", callable_mp(this, &VisualGasicToolbox::_on_tool_button_pressed).bind(btn));
    
    btn->set_h_size_flags(Control::SIZE_EXPAND_FILL);
    btn->set_focus_mode(FOCUS_NONE); // Prevent stealing focus from Editor, which can mess up drag coordinates
    
    if (p_category == "3D") {
        grid_3d->add_child(btn);
    } else if (p_category == "Game UI") {
        grid_game_ui->add_child(btn);
    } else {
        grid_2d->add_child(btn);
    }
}

void VisualGasicToolbox::remove_tool(const String &p_name) {
    // Search in 2D grid
    for (int i = 0; i < grid_2d->get_child_count(); i++) {
        Node *child = grid_2d->get_child(i);
        if (child->get_name() == p_name) {
            grid_2d->remove_child(child);
            child->queue_free();
            return;
        }
    }
    // Search in 3D grid
    for (int i = 0; i < grid_3d->get_child_count(); i++) {
        Node *child = grid_3d->get_child(i);
        if (child->get_name() == p_name) {
            grid_3d->remove_child(child);
            child->queue_free();
            return;
        }
    }
    // Search in Game UI grid
    for (int i = 0; i < grid_game_ui->get_child_count(); i++) {
        Node *child = grid_game_ui->get_child(i);
        if (child->get_name() == p_name) {
            grid_game_ui->remove_child(child);
            child->queue_free();
            return;
        }
    }
}

void VisualGasicToolbox::clear_custom_tools() {
    // Remove tools added after mark_defaults() was called
    // 2D grid
    while (grid_2d->get_child_count() > default_tool_count_2d) {
        Node *child = grid_2d->get_child(grid_2d->get_child_count() - 1);
        grid_2d->remove_child(child);
        child->queue_free();
    }
    // 3D grid
    while (grid_3d->get_child_count() > default_tool_count_3d) {
        Node *child = grid_3d->get_child(grid_3d->get_child_count() - 1);
        grid_3d->remove_child(child);
        child->queue_free();
    }
    // Game UI grid
    while (grid_game_ui->get_child_count() > default_tool_count_game_ui) {
        Node *child = grid_game_ui->get_child(grid_game_ui->get_child_count() - 1);
        grid_game_ui->remove_child(child);
        child->queue_free();
    }
}

void VisualGasicToolbox::mark_defaults() {
    default_tool_count_2d = grid_2d->get_child_count();
    default_tool_count_3d = grid_3d->get_child_count();
    default_tool_count_game_ui = grid_game_ui->get_child_count();
}

// =============================================================================
// Active tool state (click-to-place mode)
// =============================================================================

void VisualGasicToolbox::_on_tool_button_pressed(VisualGasicToolButton *p_btn) {
    if (!p_btn) return;

    String cls = p_btn->get_create_class();
    String scene = p_btn->get_scene_path();

    // If this button is already the active tool, toggle back to Pointer
    if (p_btn == active_tool_button) {
        reset_to_pointer();
        return;
    }

    // If the Pointer button was clicked (empty class), just reset
    if (cls.is_empty() && scene.is_empty()) {
        reset_to_pointer();
        return;
    }

    active_tool_class = cls;
    active_tool_scene_path = scene;
    active_tool_button = p_btn;
    _update_button_states();

    emit_signal("tool_selected", active_tool_class, active_tool_scene_path);
    UtilityFunctions::print("Toolbox: Active tool = ", cls, " (", scene, ")");
}

void VisualGasicToolbox::_update_button_states() {
    // Depress all buttons except the active one
    auto _depress = [&](GridContainer *grid) {
        for (int i = 0; i < grid->get_child_count(); i++) {
            VisualGasicToolButton *btn = Object::cast_to<VisualGasicToolButton>(grid->get_child(i));
            if (btn) {
                btn->set_pressed(btn == active_tool_button);
            }
        }
    };
    _depress(grid_2d);
    _depress(grid_3d);
    _depress(grid_game_ui);
}

String VisualGasicToolbox::get_active_tool_class() const {
    return active_tool_class;
}

String VisualGasicToolbox::get_active_tool_scene() const {
    return active_tool_scene_path;
}

void VisualGasicToolbox::reset_to_pointer() {
    active_tool_class = "";
    active_tool_scene_path = "";
    active_tool_button = nullptr;
    _update_button_states();
    emit_signal("tool_selected", String(""), String(""));
    UtilityFunctions::print("Toolbox: Reset to Pointer");
}

/*
void VisualGasicToolbox::add_tool(const String &p_name, const String &p_godot_class) {
    // Deprecated implementation
}
*/

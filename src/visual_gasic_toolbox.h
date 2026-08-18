#ifndef VISUAL_GASIC_TOOLBOX_H
#define VISUAL_GASIC_TOOLBOX_H

#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/grid_container.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

class VisualGasicToolButton : public Button {
    GDCLASS(VisualGasicToolButton, Button);
    
    String create_class_name;
    String icon_name;
    String scene_path; // Path to the .tscn file to drag
    String tool_category; // "2D", "Godot 2D", "Godot 3D", "Game UI"

protected:
    static void _bind_methods();
    void _notification(int p_what);

public:
    void set_create_class(const String &p_class);
    String get_create_class() const;
    void set_icon_name(const String &p_icon); 
    void set_scene_path(const String &p_path);
    String get_scene_path() const;
    void set_tool_category(const String &p_category);
    
    virtual Variant _get_drag_data(const Vector2 &at_position) override;
    virtual Object *_make_custom_tooltip(const String &p_text) const override;
};

class VisualGasicToolbox : public PanelContainer {
    GDCLASS(VisualGasicToolbox, PanelContainer);
    
    Control *tabs; // Using generic Control to avoid header dependency hell if TabContainer isn't included, but we'll include it.
    GridContainer *grid_2d;
    TabContainer *tabs_godot_2d;   // Native Godot 2D — sub-tabs (Node2D, Controls, …)
    TabContainer *tabs_godot_3d;   // Native Godot 3D — sub-tabs (Meshes, Lights, …)
    GridContainer *grid_game_ui;  // Game UI controls tab
    
    Vector<GridContainer *> godot_2d_subgrids;
    Vector<GridContainer *> godot_3d_subgrids;
    
    // Track which tools are "default" vs "custom" for selective removal
    int default_tool_count_2d = 0;
    Vector<int> default_tool_count_godot_2d_sub;
    Vector<int> default_tool_count_godot_3d_sub;
    int default_tool_count_game_ui = 0;

    // Active tool state (for click-to-place mode)
    String active_tool_class;       // e.g. "Button", "Label" — empty = Pointer
    String active_tool_scene_path;  // e.g. "res://addons/visual_gasic/prototypes/Button.tscn"
    VisualGasicToolButton *active_tool_button = nullptr; // Currently pressed button

    GridContainer *_get_godot_2d_subgrid(const String &p_subcategory) const;
    GridContainer *_get_godot_3d_subgrid(const String &p_subcategory) const;
    void _depress_grid(GridContainer *p_grid);
    void _depress_all_tool_grids();
    void _remove_from_grids(Vector<GridContainer *> p_grids, const String &p_name);
    void _clear_custom_from_grids(Vector<GridContainer *> p_grids, Vector<int> &p_default_counts);
    GridContainer *_make_subgrid(TabContainer *p_tabs, const String &p_name);

    void _on_tool_button_pressed(VisualGasicToolButton *p_btn);
    void _update_button_states();

protected:
    static void _bind_methods();
    void _notification(int p_what);

public:
    VisualGasicToolbox();
    ~VisualGasicToolbox();
    
    // Updated add_tool to optionally take a scene path, category, and subcategory
    void add_tool(const String &p_name, const String &p_godot_class, const String &p_icon_name, const String &p_scene_path = "", const String &p_category = "2D", const String &p_subcategory = "");
    
    // Remove a specific tool by name
    void remove_tool(const String &p_name);
    
    // Clear all custom (non-default) tools
    void clear_custom_tools();
    
    // Mark current tools as "default" (called after initial setup)
    void mark_defaults();

    // Active tool access
    String get_active_tool_class() const;
    String get_active_tool_scene() const;
    void reset_to_pointer();

    // Signals:
    // "tool_selected" (class_name: String, scene_path: String)
};

#endif // VISUAL_GASIC_TOOLBOX_H

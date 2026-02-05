#ifndef VISUAL_GASIC_TOOLBOX_H
#define VISUAL_GASIC_TOOLBOX_H

#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/grid_container.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/texture_rect.hpp>

using namespace godot;

class VisualGasicToolButton : public Button {
    GDCLASS(VisualGasicToolButton, Button);
    
    String create_class_name;
    String icon_name;
    String scene_path; // Path to the .tscn file to drag

protected:
    static void _bind_methods();
    void _notification(int p_what);

public:
    void set_create_class(const String &p_class);
    String get_create_class() const;
    void set_icon_name(const String &p_icon); 
    void set_scene_path(const String &p_path);
    String get_scene_path() const;
    
    virtual Variant _get_drag_data(const Vector2 &at_position) override;
};

class VisualGasicToolbox : public PanelContainer {
    GDCLASS(VisualGasicToolbox, PanelContainer);
    
    Control *tabs; // Using generic Control to avoid header dependency hell if TabContainer isn't included, but we'll include it.
    GridContainer *grid_2d;
    GridContainer *grid_3d;
    
    // Track which tools are "default" vs "custom" for selective removal
    int default_tool_count_2d = 0;
    int default_tool_count_3d = 0;

protected:
    static void _bind_methods();
    void _notification(int p_what);

public:
    VisualGasicToolbox();
    ~VisualGasicToolbox();
    
    // Updated add_tool to optionally take a scene path and category
    void add_tool(const String &p_name, const String &p_godot_class, const String &p_icon_name, const String &p_scene_path = "", const String &p_category = "2D");
    
    // Remove a specific tool by name
    void remove_tool(const String &p_name);
    
    // Clear all custom (non-default) tools
    void clear_custom_tools();
    
    // Mark current tools as "default" (called after initial setup)
    void mark_defaults();
};

#endif // VISUAL_GASIC_TOOLBOX_H

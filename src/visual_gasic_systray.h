#ifndef VISUAL_GASIC_SYSTRAY_H
#define VISUAL_GASIC_SYSTRAY_H

// VGSysTray — System tray icon support
// Usage in VisualGasic:
//   Dim tray As New SysTray
//   tray.Icon = "res://icon.png"
//   tray.Tooltip = "My Application"
//   tray.Visible = True
//   tray.AddMenuItem "Show", "show_window"
//   tray.AddMenuItem "Exit", "exit_app"
//
// On Linux: Uses DBus StatusNotifierItem protocol
// On Windows: Shell_NotifyIcon (future)
// Fallback: Godot's native tray if available (4.x+)

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGSysTray : public RefCounted {
    GDCLASS(VGSysTray, RefCounted);

    String icon_path;
    String tooltip;
    bool visible;
    Array menu_items;  // Array of Dictionary { "label": String, "id": String, "enabled": bool }
    String last_clicked_id;

    // Platform handle
    void *tray_handle;

    void create_tray();
    void destroy_tray();
    void update_tray();

protected:
    static void _bind_methods();

public:
    VGSysTray();
    ~VGSysTray();

    // Properties
    void set_icon(const String &p_path);
    String get_icon() const { return icon_path; }
    void set_tooltip(const String &p_tooltip);
    String get_tooltip() const { return tooltip; }
    void set_visible(bool p_visible);
    bool get_visible() const { return visible; }

    // Menu management
    void add_menu_item(const String &p_label, const String &p_id);
    void add_separator();
    void remove_menu_item(const String &p_id);
    void clear_menu();
    void set_menu_item_enabled(const String &p_id, bool p_enabled);
    void set_menu_item_checked(const String &p_id, bool p_checked);

    // Event polling
    String poll_click();  // Returns menu item ID if clicked, "" otherwise
    bool has_click() const;

    // Balloon/notification
    void show_balloon(const String &p_title, const String &p_message, int p_timeout_ms = 5000);
};

#endif // VISUAL_GASIC_SYSTRAY_H

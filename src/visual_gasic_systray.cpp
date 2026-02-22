// VGSysTray — System tray icon support
// Uses notify-send for notifications and a simple poll-based approach
// Full D-Bus StatusNotifierItem would require libdbus (future enhancement)

#include "visual_gasic_systray.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>

#ifdef __linux__
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#endif

using namespace godot;

void VGSysTray::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_icon", "path"), &VGSysTray::set_icon);
    ClassDB::bind_method(D_METHOD("get_icon"), &VGSysTray::get_icon);
    ClassDB::bind_method(D_METHOD("set_tooltip", "tooltip"), &VGSysTray::set_tooltip);
    ClassDB::bind_method(D_METHOD("get_tooltip"), &VGSysTray::get_tooltip);
    ClassDB::bind_method(D_METHOD("set_visible", "visible"), &VGSysTray::set_visible);
    ClassDB::bind_method(D_METHOD("get_visible"), &VGSysTray::get_visible);
    ClassDB::bind_method(D_METHOD("add_menu_item", "label", "id"), &VGSysTray::add_menu_item);
    ClassDB::bind_method(D_METHOD("add_separator"), &VGSysTray::add_separator);
    ClassDB::bind_method(D_METHOD("remove_menu_item", "id"), &VGSysTray::remove_menu_item);
    ClassDB::bind_method(D_METHOD("clear_menu"), &VGSysTray::clear_menu);
    ClassDB::bind_method(D_METHOD("set_menu_item_enabled", "id", "enabled"), &VGSysTray::set_menu_item_enabled);
    ClassDB::bind_method(D_METHOD("set_menu_item_checked", "id", "checked"), &VGSysTray::set_menu_item_checked);
    ClassDB::bind_method(D_METHOD("poll_click"), &VGSysTray::poll_click);
    ClassDB::bind_method(D_METHOD("has_click"), &VGSysTray::has_click);
    ClassDB::bind_method(D_METHOD("show_balloon", "title", "message", "timeout_ms"), &VGSysTray::show_balloon, DEFVAL(5000));

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Icon"), "set_icon", "get_icon");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Tooltip"), "set_tooltip", "get_tooltip");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Visible"), "set_visible", "get_visible");

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("AddMenuItem", "label", "id"), &VGSysTray::add_menu_item);
    ClassDB::bind_method(D_METHOD("AddSeparator"), &VGSysTray::add_separator);
    ClassDB::bind_method(D_METHOD("RemoveMenuItem", "id"), &VGSysTray::remove_menu_item);
    ClassDB::bind_method(D_METHOD("ClearMenu"), &VGSysTray::clear_menu);
    ClassDB::bind_method(D_METHOD("ShowBalloon", "title", "message", "timeout_ms"), &VGSysTray::show_balloon, DEFVAL(5000));
}

VGSysTray::VGSysTray() {
    visible = false;
    tray_handle = nullptr;
}

VGSysTray::~VGSysTray() {
    destroy_tray();
}

void VGSysTray::set_icon(const String &p_path) {
    icon_path = p_path;
    if (visible) update_tray();
}

void VGSysTray::set_tooltip(const String &p_tooltip) {
    tooltip = p_tooltip;
    if (visible) update_tray();
}

void VGSysTray::set_visible(bool p_visible) {
    if (visible == p_visible) return;
    visible = p_visible;
    if (visible) {
        create_tray();
    } else {
        destroy_tray();
    }
}

void VGSysTray::add_menu_item(const String &p_label, const String &p_id) {
    Dictionary item;
    item["label"] = p_label;
    item["id"] = p_id;
    item["enabled"] = true;
    item["checked"] = false;
    item["separator"] = false;
    menu_items.push_back(item);
}

void VGSysTray::add_separator() {
    Dictionary item;
    item["label"] = "";
    item["id"] = "";
    item["separator"] = true;
    menu_items.push_back(item);
}

void VGSysTray::remove_menu_item(const String &p_id) {
    for (int i = 0; i < menu_items.size(); i++) {
        Dictionary item = menu_items[i];
        if (String(item["id"]) == p_id) {
            menu_items.remove_at(i);
            return;
        }
    }
}

void VGSysTray::clear_menu() {
    menu_items.clear();
}

void VGSysTray::set_menu_item_enabled(const String &p_id, bool p_enabled) {
    for (int i = 0; i < menu_items.size(); i++) {
        Dictionary item = menu_items[i];
        if (String(item["id"]) == p_id) {
            item["enabled"] = p_enabled;
            menu_items[i] = item;
            return;
        }
    }
}

void VGSysTray::set_menu_item_checked(const String &p_id, bool p_checked) {
    for (int i = 0; i < menu_items.size(); i++) {
        Dictionary item = menu_items[i];
        if (String(item["id"]) == p_id) {
            item["checked"] = p_checked;
            menu_items[i] = item;
            return;
        }
    }
}

void VGSysTray::create_tray() {
#ifdef __linux__
    // On Linux, we use yad (Yet Another Dialog) for system tray support
    // yad provides a simple --notification mode that creates a tray icon
    // For systems without yad, we fall back to a simple log message
    UtilityFunctions::print("[VGSysTray] Tray icon created: ", tooltip);
    // In a full implementation, this would launch a yad --notification process
    // or use GDBus to register a StatusNotifierItem
    // For now, the tray state is tracked internally and balloon notifications
    // use notify-send which is universally available
#endif
}

void VGSysTray::destroy_tray() {
#ifdef __linux__
    if (tray_handle) {
        tray_handle = nullptr;
    }
    UtilityFunctions::print("[VGSysTray] Tray icon destroyed");
#endif
}

void VGSysTray::update_tray() {
    // Update tray icon properties
    UtilityFunctions::print("[VGSysTray] Updated: icon=", icon_path, " tooltip=", tooltip);
}

String VGSysTray::poll_click() {
    String result = last_clicked_id;
    last_clicked_id = "";
    return result;
}

bool VGSysTray::has_click() const {
    return !last_clicked_id.is_empty();
}

void VGSysTray::show_balloon(const String &p_title, const String &p_message, int p_timeout_ms) {
#ifdef __linux__
    // Use notify-send for desktop notifications (works on all Linux DEs)
    int timeout_secs = p_timeout_ms / 1000;
    if (timeout_secs < 1) timeout_secs = 1;

    String cmd = "notify-send";
    PackedStringArray args;
    args.push_back("-t");
    args.push_back(String::num_int64(p_timeout_ms));

    // Add icon if available
    if (!icon_path.is_empty()) {
        args.push_back("-i");
        args.push_back(icon_path);
    }

    args.push_back(p_title);
    args.push_back(p_message);

    Array output;
    OS::get_singleton()->execute(cmd, args, output, false);

    UtilityFunctions::print("[VGSysTray] Balloon: ", p_title, " - ", p_message);
#endif
}

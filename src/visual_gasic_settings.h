#ifndef VISUAL_GASIC_SETTINGS_H
#define VISUAL_GASIC_SETTINGS_H

// VGSettings — VB6-style GetSetting/SaveSetting/DeleteSetting
// Usage in VisualGasic:
//   SaveSetting "MyApp", "Preferences", "Theme", "Dark"
//   Dim theme As String
//   theme = GetSetting("MyApp", "Preferences", "Theme", "Light")
//   DeleteSetting "MyApp", "Preferences", "Theme"
//   GetAllSettings "MyApp", "Preferences"
//
// Storage: INI-style files in user://settings/<AppName>.ini
// On Linux: ~/.local/share/godot/app_userdata/<project>/settings/
// Compatible with VB6's SaveSetting/GetSetting which uses Windows Registry

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGSettings : public RefCounted {
    GDCLASS(VGSettings, RefCounted);

    // Cached settings in memory (app_name -> section -> key -> value)
    static Dictionary *settings_cache;
    static bool cache_dirty;
    static Dictionary &get_cache();

    static String get_settings_dir();
    static String get_ini_path(const String &p_app_name);
    static void ensure_loaded(const String &p_app_name);
    static void flush_to_disk(const String &p_app_name);
    static Dictionary parse_ini_file(const String &p_path);
    static void write_ini_file(const String &p_path, const Dictionary &p_data);

protected:
    static void _bind_methods();

public:
    VGSettings();
    ~VGSettings();

    // VB6-compatible API (static methods callable as built-in functions)
    static void save_setting(const String &p_app_name, const String &p_section,
                             const String &p_key, const String &p_value);
    static String get_setting(const String &p_app_name, const String &p_section,
                              const String &p_key, const String &p_default = "");
    static void delete_setting(const String &p_app_name, const String &p_section = "",
                               const String &p_key = "");
    static Array get_all_settings(const String &p_app_name, const String &p_section);

    // Modern API
    static Dictionary get_section(const String &p_app_name, const String &p_section);
    static Array get_sections(const String &p_app_name);
    static bool has_setting(const String &p_app_name, const String &p_section, const String &p_key);

    // Flush all cached data to disk
    static void flush();
};

#endif // VISUAL_GASIC_SETTINGS_H

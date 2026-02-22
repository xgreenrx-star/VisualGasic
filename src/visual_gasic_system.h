#ifndef VISUAL_GASIC_SYSTEM_H
#define VISUAL_GASIC_SYSTEM_H

// VGSystem — Cross-platform system information queries
// Exposes hostname, CPU count, RAM, disk space, OS info, uptime, etc.
//
// Usage in VisualGasic:
//   Print VGSystem.Hostname
//   Print "CPUs: " & CStr(VGSystem.CpuCount)
//   Print "RAM: " & CStr(VGSystem.TotalMemory) & " bytes"
//   Print "Free RAM: " & CStr(VGSystem.FreeMemory) & " bytes"
//   Print "OS: " & VGSystem.OsName & " " & VGSystem.OsVersion
//   Print "Uptime: " & CStr(VGSystem.Uptime) & " seconds"
//   Print "Disk free: " & CStr(VGSystem.FreeDiskSpace("/")) & " bytes"
//   Print "Username: " & VGSystem.Username
//   Print "Arch: " & VGSystem.Architecture
//   Print "Endian: " & VGSystem.Endianness
//   Print "PID: " & CStr(VGSystem.ProcessId)

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class VGSystem : public RefCounted {
    GDCLASS(VGSystem, RefCounted);

protected:
    static void _bind_methods();

public:
    VGSystem();
    ~VGSystem();

    // --- Host Info ---
    static String get_hostname();
    static String get_username();
    static int get_process_id();

    // --- CPU ---
    static int get_cpu_count();
    static String get_cpu_name();
    static String get_architecture();

    // --- Memory (bytes) ---
    static int64_t get_total_memory();
    static int64_t get_free_memory();
    static int64_t get_used_memory();
    static double get_memory_usage_percent();

    // --- Disk (bytes) ---
    static int64_t get_free_disk_space(const String &p_path);
    static int64_t get_total_disk_space(const String &p_path);
    static double get_disk_usage_percent(const String &p_path);

    // --- OS ---
    static String get_os_name();
    static String get_os_version();
    static String get_os_full();
    static String get_endianness();
    static double get_uptime();

    // --- Environment ---
    static String get_env(const String &p_name);
    static void set_env(const String &p_name, const String &p_value);
    static bool has_env(const String &p_name);
    static Dictionary get_all_env();

    // --- Locale ---
    static String get_locale();
    static String get_language();
    static String get_timezone();
    static int get_timezone_offset();

    // --- Aggregate ---
    static Dictionary get_system_info();
};

#endif // VISUAL_GASIC_SYSTEM_H

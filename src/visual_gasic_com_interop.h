#ifndef VISUAL_GASIC_COM_INTEROP_H
#define VISUAL_GASIC_COM_INTEROP_H

// VGComInterop — VB6 CreateObject / COM compatibility layer
// Usage in VisualGasic:
//   Dim fso As Object
//   Set fso = CreateObject("Scripting.FileSystemObject")
//   If fso.FileExists("C:\test.txt") Then
//       Print "File exists"
//   End If
//
//   Dim dict As Object
//   Set dict = CreateObject("Scripting.Dictionary")
//   dict.Add "key1", "value1"
//
//   Dim shell As Object
//   Set shell = CreateObject("WScript.Shell")
//   shell.Run "notepad.exe"
//
// On Linux: Maps common COM ProgIDs to native equivalents
// On Windows: Could use CoCreateInstance (future)

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

// Base class for COM-like objects
class VGComObject : public RefCounted {
    GDCLASS(VGComObject, RefCounted);

    String prog_id;
    Dictionary properties;

protected:
    static void _bind_methods();

public:
    VGComObject();
    ~VGComObject();

    void set_prog_id(const String &p_id) { prog_id = p_id; }
    String get_prog_id() const { return prog_id; }

    // Late-bound method invocation (like VB6 late binding)
    Variant invoke(const String &p_method, const Array &p_args);
    void set_property(const String &p_name, const Variant &p_value);
    Variant get_property(const String &p_name);
};

// Scripting.FileSystemObject emulation
class VGFileSystemObject : public VGComObject {
    GDCLASS(VGFileSystemObject, VGComObject);

protected:
    static void _bind_methods();

public:
    VGFileSystemObject();

    bool file_exists(const String &p_path);
    bool folder_exists(const String &p_path);
    String get_file_name(const String &p_path);
    String get_base_name(const String &p_path);
    String get_extension_name(const String &p_path);
    String get_parent_folder_name(const String &p_path);
    String get_temp_name();
    bool copy_file(const String &p_source, const String &p_dest, bool p_overwrite = true);
    bool delete_file(const String &p_path, bool p_force = false);
    bool create_folder(const String &p_path);
    bool delete_folder(const String &p_path, bool p_force = false);
    bool move_file(const String &p_source, const String &p_dest);
    Dictionary get_file(const String &p_path);  // Returns file info dict
    int64_t get_file_size(const String &p_path);
    String read_all(const String &p_path);
    void write_all(const String &p_path, const String &p_content);
};

// Scripting.Dictionary emulation (VB6's Dictionary object)
class VGScriptingDict : public VGComObject {
    GDCLASS(VGScriptingDict, VGComObject);

    Dictionary dict;
    int compare_mode;

protected:
    static void _bind_methods();

public:
    VGScriptingDict();

    void add(const String &p_key, const Variant &p_item);
    bool exists(const String &p_key);
    Variant get_item(const String &p_key);
    void set_item(const String &p_key, const Variant &p_value);
    void remove(const String &p_key);
    void remove_all();
    int get_count();
    Array keys();
    Array items();

    void set_compare_mode(int p_mode) { compare_mode = p_mode; }
    int get_compare_mode() const { return compare_mode; }
};

// WScript.Shell emulation
class VGWScriptShell : public VGComObject {
    GDCLASS(VGWScriptShell, VGComObject);

protected:
    static void _bind_methods();

public:
    VGWScriptShell();

    int run(const String &p_command, int p_window_style = 1, bool p_wait = false);
    String expand_environment_strings(const String &p_str);
    Variant reg_read(const String &p_key);
    void reg_write(const String &p_key, const Variant &p_value, const String &p_type = "REG_SZ");
    String get_current_directory();
    Dictionary get_environment();
};

// Factory: CreateObject() dispatcher
class VGComInterop : public RefCounted {
    GDCLASS(VGComInterop, RefCounted);

protected:
    static void _bind_methods();

public:
    VGComInterop();

    // CreateObject("ProgID") — returns appropriate emulation object
    static Variant create_object(const String &p_prog_id);

    // Check if a ProgID is supported
    static bool is_supported(const String &p_prog_id);

    // List all supported ProgIDs
    static Array get_supported_prog_ids();
};

#endif // VISUAL_GASIC_COM_INTEROP_H

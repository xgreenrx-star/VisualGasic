// VGComInterop — VB6 CreateObject / COM compatibility layer
// Maps common COM ProgIDs to native Linux equivalents

#include "visual_gasic_com_interop.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/time.hpp>

using namespace godot;

// ===========================================================================
// VGComObject — Base class for COM-like late-bound objects
// ===========================================================================

void VGComObject::_bind_methods() {
    ClassDB::bind_method(D_METHOD("invoke", "method", "args"), &VGComObject::invoke);
    ClassDB::bind_method(D_METHOD("set_property", "name", "value"), &VGComObject::set_property);
    ClassDB::bind_method(D_METHOD("get_property", "name"), &VGComObject::get_property);
    ClassDB::bind_method(D_METHOD("set_prog_id", "id"), &VGComObject::set_prog_id);
    ClassDB::bind_method(D_METHOD("get_prog_id"), &VGComObject::get_prog_id);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "ProgID"), "set_prog_id", "get_prog_id");
}

VGComObject::VGComObject() {}
VGComObject::~VGComObject() {}

Variant VGComObject::invoke(const String &p_method, const Array &p_args) {
    UtilityFunctions::printerr("[VGComObject] Unknown method '", p_method, "' on ", prog_id);
    return Variant();
}

void VGComObject::set_property(const String &p_name, const Variant &p_value) {
    properties[p_name] = p_value;
}

Variant VGComObject::get_property(const String &p_name) {
    if (properties.has(p_name)) return properties[p_name];
    return Variant();
}

// ===========================================================================
// VGFileSystemObject — Scripting.FileSystemObject emulation
// ===========================================================================

void VGFileSystemObject::_bind_methods() {
    ClassDB::bind_method(D_METHOD("file_exists", "path"), &VGFileSystemObject::file_exists);
    ClassDB::bind_method(D_METHOD("folder_exists", "path"), &VGFileSystemObject::folder_exists);
    ClassDB::bind_method(D_METHOD("get_file_name", "path"), &VGFileSystemObject::get_file_name);
    ClassDB::bind_method(D_METHOD("get_base_name", "path"), &VGFileSystemObject::get_base_name);
    ClassDB::bind_method(D_METHOD("get_extension_name", "path"), &VGFileSystemObject::get_extension_name);
    ClassDB::bind_method(D_METHOD("get_parent_folder_name", "path"), &VGFileSystemObject::get_parent_folder_name);
    ClassDB::bind_method(D_METHOD("get_temp_name"), &VGFileSystemObject::get_temp_name);
    ClassDB::bind_method(D_METHOD("copy_file", "source", "dest", "overwrite"), &VGFileSystemObject::copy_file, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("delete_file", "path", "force"), &VGFileSystemObject::delete_file, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("create_folder", "path"), &VGFileSystemObject::create_folder);
    ClassDB::bind_method(D_METHOD("delete_folder", "path", "force"), &VGFileSystemObject::delete_folder, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("move_file", "source", "dest"), &VGFileSystemObject::move_file);
    ClassDB::bind_method(D_METHOD("get_file", "path"), &VGFileSystemObject::get_file);
    ClassDB::bind_method(D_METHOD("get_file_size", "path"), &VGFileSystemObject::get_file_size);
    ClassDB::bind_method(D_METHOD("read_all", "path"), &VGFileSystemObject::read_all);
    ClassDB::bind_method(D_METHOD("write_all", "path", "content"), &VGFileSystemObject::write_all);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("FileExists", "path"), &VGFileSystemObject::file_exists);
    ClassDB::bind_method(D_METHOD("FolderExists", "path"), &VGFileSystemObject::folder_exists);
    ClassDB::bind_method(D_METHOD("GetFileName", "path"), &VGFileSystemObject::get_file_name);
    ClassDB::bind_method(D_METHOD("GetBaseName", "path"), &VGFileSystemObject::get_base_name);
    ClassDB::bind_method(D_METHOD("GetExtensionName", "path"), &VGFileSystemObject::get_extension_name);
    ClassDB::bind_method(D_METHOD("GetParentFolderName", "path"), &VGFileSystemObject::get_parent_folder_name);
    ClassDB::bind_method(D_METHOD("GetTempName"), &VGFileSystemObject::get_temp_name);
    ClassDB::bind_method(D_METHOD("CopyFile", "source", "dest", "overwrite"), &VGFileSystemObject::copy_file, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("DeleteFile", "path", "force"), &VGFileSystemObject::delete_file, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("CreateFolder", "path"), &VGFileSystemObject::create_folder);
    ClassDB::bind_method(D_METHOD("DeleteFolder", "path", "force"), &VGFileSystemObject::delete_folder, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("MoveFile", "source", "dest"), &VGFileSystemObject::move_file);
    ClassDB::bind_method(D_METHOD("GetFile", "path"), &VGFileSystemObject::get_file);
    ClassDB::bind_method(D_METHOD("GetFileSize", "path"), &VGFileSystemObject::get_file_size);
    ClassDB::bind_method(D_METHOD("ReadAll", "path"), &VGFileSystemObject::read_all);
    ClassDB::bind_method(D_METHOD("WriteAll", "path", "content"), &VGFileSystemObject::write_all);
}

VGFileSystemObject::VGFileSystemObject() {
    set_prog_id("Scripting.FileSystemObject");
}

bool VGFileSystemObject::file_exists(const String &p_path) {
    return FileAccess::file_exists(p_path);
}

bool VGFileSystemObject::folder_exists(const String &p_path) {
    return DirAccess::dir_exists_absolute(p_path);
}

String VGFileSystemObject::get_file_name(const String &p_path) {
    return p_path.get_file();
}

String VGFileSystemObject::get_base_name(const String &p_path) {
    return p_path.get_file().get_basename();
}

String VGFileSystemObject::get_extension_name(const String &p_path) {
    return p_path.get_extension();
}

String VGFileSystemObject::get_parent_folder_name(const String &p_path) {
    return p_path.get_base_dir();
}

String VGFileSystemObject::get_temp_name() {
    return OS::get_singleton()->get_cache_dir() + "/vg_tmp_" +
           String::num_int64(Time::get_singleton()->get_ticks_msec()) + ".tmp";
}

bool VGFileSystemObject::copy_file(const String &p_source, const String &p_dest, bool p_overwrite) {
    if (!p_overwrite && FileAccess::file_exists(p_dest)) return false;
    Ref<DirAccess> dir = DirAccess::open(p_source.get_base_dir());
    if (!dir.is_valid()) return false;
    return dir->copy(p_source, p_dest) == OK;
}

bool VGFileSystemObject::delete_file(const String &p_path, bool p_force) {
    Ref<DirAccess> dir = DirAccess::open(p_path.get_base_dir());
    if (!dir.is_valid()) return false;
    return dir->remove(p_path.get_file()) == OK;
}

bool VGFileSystemObject::create_folder(const String &p_path) {
    return DirAccess::make_dir_recursive_absolute(p_path) == OK;
}

bool VGFileSystemObject::delete_folder(const String &p_path, bool p_force) {
    Ref<DirAccess> dir = DirAccess::open(p_path.get_base_dir());
    if (!dir.is_valid()) return false;
    return dir->remove(p_path.get_file()) == OK;
}

bool VGFileSystemObject::move_file(const String &p_source, const String &p_dest) {
    Ref<DirAccess> dir = DirAccess::open(p_source.get_base_dir());
    if (!dir.is_valid()) return false;
    return dir->rename(p_source, p_dest) == OK;
}

Dictionary VGFileSystemObject::get_file(const String &p_path) {
    Dictionary info;
    info["Name"] = p_path.get_file();
    info["Path"] = p_path;
    info["ParentFolder"] = p_path.get_base_dir();
    info["Size"] = get_file_size(p_path);
    info["Type"] = p_path.get_extension();
    return info;
}

int64_t VGFileSystemObject::get_file_size(const String &p_path) {
    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::READ);
    if (!f.is_valid()) return -1;
    return f->get_length();
}

String VGFileSystemObject::read_all(const String &p_path) {
    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::READ);
    if (!f.is_valid()) return "";
    return f->get_as_text();
}

void VGFileSystemObject::write_all(const String &p_path, const String &p_content) {
    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::WRITE);
    if (!f.is_valid()) return;
    f->store_string(p_content);
}

// ===========================================================================
// VGScriptingDict — Scripting.Dictionary emulation
// ===========================================================================

void VGScriptingDict::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add", "key", "item"), &VGScriptingDict::add);
    ClassDB::bind_method(D_METHOD("exists", "key"), &VGScriptingDict::exists);
    ClassDB::bind_method(D_METHOD("get_item", "key"), &VGScriptingDict::get_item);
    ClassDB::bind_method(D_METHOD("set_item", "key", "value"), &VGScriptingDict::set_item);
    ClassDB::bind_method(D_METHOD("remove", "key"), &VGScriptingDict::remove);
    ClassDB::bind_method(D_METHOD("remove_all"), &VGScriptingDict::remove_all);
    ClassDB::bind_method(D_METHOD("get_count"), &VGScriptingDict::get_count);
    ClassDB::bind_method(D_METHOD("keys"), &VGScriptingDict::keys);
    ClassDB::bind_method(D_METHOD("items"), &VGScriptingDict::items);
    ClassDB::bind_method(D_METHOD("set_compare_mode", "mode"), &VGScriptingDict::set_compare_mode);
    ClassDB::bind_method(D_METHOD("get_compare_mode"), &VGScriptingDict::get_compare_mode);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Item", "key"), &VGScriptingDict::get_item);
    ClassDB::bind_method(D_METHOD("Add", "key", "item"), &VGScriptingDict::add);
    ClassDB::bind_method(D_METHOD("Exists", "key"), &VGScriptingDict::exists);
    ClassDB::bind_method(D_METHOD("Remove", "key"), &VGScriptingDict::remove);
    ClassDB::bind_method(D_METHOD("RemoveAll"), &VGScriptingDict::remove_all);
    ClassDB::bind_method(D_METHOD("Keys"), &VGScriptingDict::keys);
    ClassDB::bind_method(D_METHOD("Items"), &VGScriptingDict::items);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "Count"), "", "get_count");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "CompareMode"), "set_compare_mode", "get_compare_mode");
}

VGScriptingDict::VGScriptingDict() {
    set_prog_id("Scripting.Dictionary");
    compare_mode = 0; // 0 = Binary (case-sensitive), 1 = Text (case-insensitive)
}

void VGScriptingDict::add(const String &p_key, const Variant &p_item) {
    String key = (compare_mode == 1) ? p_key.to_lower() : p_key;
    if (dict.has(key)) {
        UtilityFunctions::printerr("[VGScriptingDict] Key already exists: ", p_key);
        return;
    }
    dict[key] = p_item;
}

bool VGScriptingDict::exists(const String &p_key) {
    String key = (compare_mode == 1) ? p_key.to_lower() : p_key;
    return dict.has(key);
}

Variant VGScriptingDict::get_item(const String &p_key) {
    String key = (compare_mode == 1) ? p_key.to_lower() : p_key;
    if (dict.has(key)) return dict[key];
    return Variant();
}

void VGScriptingDict::set_item(const String &p_key, const Variant &p_value) {
    String key = (compare_mode == 1) ? p_key.to_lower() : p_key;
    dict[key] = p_value;
}

void VGScriptingDict::remove(const String &p_key) {
    String key = (compare_mode == 1) ? p_key.to_lower() : p_key;
    dict.erase(key);
}

void VGScriptingDict::remove_all() {
    dict.clear();
}

int VGScriptingDict::get_count() {
    return dict.size();
}

Array VGScriptingDict::keys() {
    return dict.keys();
}

Array VGScriptingDict::items() {
    return dict.values();
}

// ===========================================================================
// VGWScriptShell — WScript.Shell emulation
// ===========================================================================

void VGWScriptShell::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run", "command", "window_style", "wait"), &VGWScriptShell::run, DEFVAL(1), DEFVAL(false));
    ClassDB::bind_method(D_METHOD("expand_environment_strings", "str"), &VGWScriptShell::expand_environment_strings);
    ClassDB::bind_method(D_METHOD("get_current_directory"), &VGWScriptShell::get_current_directory);
    ClassDB::bind_method(D_METHOD("get_environment"), &VGWScriptShell::get_environment);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Run", "command", "window_style", "wait"), &VGWScriptShell::run, DEFVAL(1), DEFVAL(false));
    ClassDB::bind_method(D_METHOD("ExpandEnvironmentStrings", "str"), &VGWScriptShell::expand_environment_strings);
    ClassDB::bind_method(D_METHOD("CurrentDirectory"), &VGWScriptShell::get_current_directory);
    ClassDB::bind_method(D_METHOD("Environment"), &VGWScriptShell::get_environment);
}

VGWScriptShell::VGWScriptShell() {
    set_prog_id("WScript.Shell");
}

int VGWScriptShell::run(const String &p_command, int p_window_style, bool p_wait) {
#ifdef __linux__
    if (p_wait) {
        Array output;
        return OS::get_singleton()->execute("sh", PackedStringArray({"-c", p_command}), output, true);
    } else {
        int pid = OS::get_singleton()->create_process("sh", PackedStringArray({"-c", p_command}));
        return pid >= 0 ? 0 : -1;
    }
#else
    return -1;
#endif
}

String VGWScriptShell::expand_environment_strings(const String &p_str) {
    String result = p_str;
    // Replace %VAR% patterns with environment variable values
    int pos = 0;
    while (pos < result.length()) {
        int start = result.find("%", pos);
        if (start < 0) break;
        int end = result.find("%", start + 1);
        if (end < 0) break;

        String var_name = result.substr(start + 1, end - start - 1);
        if (OS::get_singleton()->has_environment(var_name)) {
            String value = OS::get_singleton()->get_environment(var_name);
            result = result.substr(0, start) + value + result.substr(end + 1);
            pos = start + value.length();
        } else {
            pos = end + 1;
        }
    }
    return result;
}

Variant VGWScriptShell::reg_read(const String &p_key) {
    // On Linux, map registry-style keys to environment variables or config files
    UtilityFunctions::print("[VGWScriptShell] RegRead not available on Linux: ", p_key);
    return Variant();
}

void VGWScriptShell::reg_write(const String &p_key, const Variant &p_value, const String &p_type) {
    UtilityFunctions::print("[VGWScriptShell] RegWrite not available on Linux: ", p_key);
}

String VGWScriptShell::get_current_directory() {
    return OS::get_singleton()->get_executable_path().get_base_dir();
}

Dictionary VGWScriptShell::get_environment() {
    // Return a selection of common environment variables
    Dictionary env;
    Array var_names;
    var_names.push_back("HOME"); var_names.push_back("USER");
    var_names.push_back("PATH"); var_names.push_back("SHELL");
    var_names.push_back("DISPLAY"); var_names.push_back("LANG");
    var_names.push_back("TERM"); var_names.push_back("PWD");
    var_names.push_back("HOSTNAME"); var_names.push_back("XDG_DATA_HOME");
    var_names.push_back("XDG_CONFIG_HOME"); var_names.push_back("TEMP");
    var_names.push_back("TMP");

    for (int i = 0; i < var_names.size(); i++) {
        String name = var_names[i];
        if (OS::get_singleton()->has_environment(name)) {
            env[name] = OS::get_singleton()->get_environment(name);
        }
    }
    return env;
}

// ===========================================================================
// VGComInterop — Factory: CreateObject() dispatcher
// ===========================================================================

void VGComInterop::_bind_methods() {
    ClassDB::bind_static_method("VGComInterop", D_METHOD("create_object", "prog_id"), &VGComInterop::create_object);
    ClassDB::bind_static_method("VGComInterop", D_METHOD("is_supported", "prog_id"), &VGComInterop::is_supported);
    ClassDB::bind_static_method("VGComInterop", D_METHOD("get_supported_prog_ids"), &VGComInterop::get_supported_prog_ids);
}

VGComInterop::VGComInterop() {}

Variant VGComInterop::create_object(const String &p_prog_id) {
    String id = p_prog_id.to_lower();

    if (id == "scripting.filesystemobject") {
        Ref<VGFileSystemObject> fso;
        fso.instantiate();
        UtilityFunctions::print("[VG] CreateObject: Scripting.FileSystemObject");
        return fso;
    }

    if (id == "scripting.dictionary") {
        Ref<VGScriptingDict> dict;
        dict.instantiate();
        UtilityFunctions::print("[VG] CreateObject: Scripting.Dictionary");
        return dict;
    }

    if (id == "wscript.shell") {
        Ref<VGWScriptShell> shell;
        shell.instantiate();
        UtilityFunctions::print("[VG] CreateObject: WScript.Shell");
        return shell;
    }

    UtilityFunctions::printerr("[VG] CreateObject: Unsupported ProgID '", p_prog_id, "'");
    UtilityFunctions::print("[VG] Supported: ", get_supported_prog_ids());
    return Variant();
}

bool VGComInterop::is_supported(const String &p_prog_id) {
    String id = p_prog_id.to_lower();
    return id == "scripting.filesystemobject" ||
           id == "scripting.dictionary" ||
           id == "wscript.shell";
}

Array VGComInterop::get_supported_prog_ids() {
    Array ids;
    ids.push_back("Scripting.FileSystemObject");
    ids.push_back("Scripting.Dictionary");
    ids.push_back("WScript.Shell");
    return ids;
}

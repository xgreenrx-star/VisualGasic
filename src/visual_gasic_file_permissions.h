#ifndef VISUAL_GASIC_FILE_PERMISSIONS_H
#define VISUAL_GASIC_FILE_PERMISSIONS_H

// VGFilePermissions — File permission, ownership, symlinks, and locking
//
// Usage in VisualGasic:
//   Dim fp As New VGFilePermissions
//   fp.Chmod "/tmp/data.txt", &o644
//   fp.Chown "/tmp/data.txt", "www-data", "www-data"
//   fp.CreateSymlink "/tmp/link", "/tmp/data.txt"
//   fp.Lock "/tmp/data.txt"
//   ' ... do work ...
//   fp.Unlock "/tmp/data.txt"
//
//   ' File attributes (VB6-style)
//   Dim attr As Integer = fp.GetAttr("/tmp/data.txt")
//   fp.SetAttr "/tmp/data.txt", vbReadOnly

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class VGFilePermissions : public RefCounted {
    GDCLASS(VGFilePermissions, RefCounted);

    String last_error;

    // Active file locks: path → fd
    Dictionary locked_files;

protected:
    static void _bind_methods();

public:
    VGFilePermissions();
    ~VGFilePermissions();

    // --- Permissions (chmod) ---
    bool chmod_file(const String &p_path, int p_mode);
    int get_permissions(const String &p_path);
    String get_permissions_string(const String &p_path);
    bool is_readable(const String &p_path);
    bool is_writable(const String &p_path);
    bool is_executable(const String &p_path);

    // --- Ownership (chown) ---
    bool chown_file(const String &p_path, const String &p_owner, const String &p_group);
    String get_owner(const String &p_path);
    String get_group(const String &p_path);

    // --- Symlinks ---
    bool create_symlink(const String &p_link_path, const String &p_target_path);
    bool create_hardlink(const String &p_link_path, const String &p_target_path);
    bool is_symlink(const String &p_path);
    String read_symlink(const String &p_path);

    // --- File Locking ---
    bool lock_file(const String &p_path);
    bool try_lock_file(const String &p_path);
    bool unlock_file(const String &p_path);
    bool is_locked(const String &p_path);

    // --- VB6-style attributes ---
    // Bit flags: 1=ReadOnly, 2=Hidden, 4=System, 16=Directory, 32=Archive
    int get_attr(const String &p_path);
    bool set_attr(const String &p_path, int p_attr);

    // --- File info ---
    Dictionary get_file_info(const String &p_path);
    int64_t get_file_size(const String &p_path);
    String get_file_type(const String &p_path);  // "file", "directory", "symlink", "pipe", "socket", etc.

    // Error
    String get_last_error() const { return last_error; }
};

#endif // VISUAL_GASIC_FILE_PERMISSIONS_H

// VGZip — VB6-style ZIP archive handling
// Wraps Godot's ZIPReader and ZIPPacker for reading/writing ZIP archives
//
// Usage in VisualGasic:
//   ' Read a ZIP archive
//   Dim z As New ZipArchive
//   z.OpenRead "res://data/archive.zip"
//   Dim files As Array
//   files = z.ListFiles()
//   Dim content As String
//   content = z.ReadText("readme.txt")
//   z.Close
//
//   ' Create a ZIP archive
//   Dim z As New ZipArchive
//   z.OpenWrite "user://output.zip"
//   z.AddText "hello.txt", "Hello World!"
//   z.AddFile "data.bin", myBytes
//   z.Close
//
//   ' Static helpers
//   ZipArchive.Compress "res://my_folder", "user://backup.zip"
//   ZipArchive.Decompress "user://backup.zip", "user://restored"

#ifndef VISUAL_GASIC_ZIP_H
#define VISUAL_GASIC_ZIP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class VGZip : public RefCounted {
    GDCLASS(VGZip, RefCounted);

    String archive_path;
    String last_error;
    void *zip_handle;  // Holds Ref internally cast to void*
    bool is_writing;
    bool is_open;

protected:
    static void _bind_methods();

public:
    VGZip();
    ~VGZip();

    // Open/Close
    bool open_read(const String &p_path);
    bool open_write(const String &p_path);
    void close();

    // Read operations
    Array list_files();
    PackedByteArray read_file(const String &p_name);
    String read_text(const String &p_name);
    bool extract_to(const String &p_dest_dir);
    bool extract_file(const String &p_name, const String &p_dest_path);
    bool file_exists(const String &p_name);

    // Write operations
    bool add_file(const String &p_name, const PackedByteArray &p_data);
    bool add_text(const String &p_name, const String &p_text);
    bool add_directory_recursive(const String &p_base_dir, const String &p_prefix = "");

    // Utility
    String get_last_error() const;
    String get_archive_path() const;
    bool get_is_open() const;
    int get_file_count();

    // Static helpers
    static bool compress(const String &p_source_dir, const String &p_dest_zip);
    static bool decompress(const String &p_zip_path, const String &p_dest_dir);
};

#endif // VISUAL_GASIC_ZIP_H

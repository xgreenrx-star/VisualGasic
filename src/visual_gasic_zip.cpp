// VGZip — VB6-style ZIP archive handling
// Uses Godot's ZIPReader and ZIPPacker classes

#include "visual_gasic_zip.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/zip_reader.hpp>
#include <godot_cpp/classes/zip_packer.hpp>

using namespace godot;

void VGZip::_bind_methods() {
    // Core methods
    ClassDB::bind_method(D_METHOD("open_read", "path"), &VGZip::open_read);
    ClassDB::bind_method(D_METHOD("open_write", "path"), &VGZip::open_write);
    ClassDB::bind_method(D_METHOD("close"), &VGZip::close);
    ClassDB::bind_method(D_METHOD("list_files"), &VGZip::list_files);
    ClassDB::bind_method(D_METHOD("read_file", "name"), &VGZip::read_file);
    ClassDB::bind_method(D_METHOD("read_text", "name"), &VGZip::read_text);
    ClassDB::bind_method(D_METHOD("extract_to", "dest_dir"), &VGZip::extract_to);
    ClassDB::bind_method(D_METHOD("extract_file", "name", "dest_path"), &VGZip::extract_file);
    ClassDB::bind_method(D_METHOD("file_exists", "name"), &VGZip::file_exists);
    ClassDB::bind_method(D_METHOD("add_file", "name", "data"), &VGZip::add_file);
    ClassDB::bind_method(D_METHOD("add_text", "name", "text"), &VGZip::add_text);
    ClassDB::bind_method(D_METHOD("add_directory_recursive", "base_dir", "prefix"), &VGZip::add_directory_recursive, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGZip::get_last_error);
    ClassDB::bind_method(D_METHOD("get_archive_path"), &VGZip::get_archive_path);
    ClassDB::bind_method(D_METHOD("get_is_open"), &VGZip::get_is_open);
    ClassDB::bind_method(D_METHOD("get_file_count"), &VGZip::get_file_count);
    ClassDB::bind_static_method("VGZip", D_METHOD("compress", "source_dir", "dest_zip"), &VGZip::compress);
    ClassDB::bind_static_method("VGZip", D_METHOD("decompress", "zip_path", "dest_dir"), &VGZip::decompress);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("OpenRead", "path"), &VGZip::open_read);
    ClassDB::bind_method(D_METHOD("OpenWrite", "path"), &VGZip::open_write);
    ClassDB::bind_method(D_METHOD("Close"), &VGZip::close);
    ClassDB::bind_method(D_METHOD("ListFiles"), &VGZip::list_files);
    ClassDB::bind_method(D_METHOD("ReadFile", "name"), &VGZip::read_file);
    ClassDB::bind_method(D_METHOD("ReadText", "name"), &VGZip::read_text);
    ClassDB::bind_method(D_METHOD("ExtractTo", "dest_dir"), &VGZip::extract_to);
    ClassDB::bind_method(D_METHOD("ExtractFile", "name", "dest_path"), &VGZip::extract_file);
    ClassDB::bind_method(D_METHOD("FileExists", "name"), &VGZip::file_exists);
    ClassDB::bind_method(D_METHOD("AddFile", "name", "data"), &VGZip::add_file);
    ClassDB::bind_method(D_METHOD("AddText", "name", "text"), &VGZip::add_text);
    ClassDB::bind_method(D_METHOD("AddDirectoryRecursive", "base_dir", "prefix"), &VGZip::add_directory_recursive, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("GetFileCount"), &VGZip::get_file_count);
    ClassDB::bind_static_method("VGZip", D_METHOD("Compress", "source_dir", "dest_zip"), &VGZip::compress);
    ClassDB::bind_static_method("VGZip", D_METHOD("Decompress", "zip_path", "dest_dir"), &VGZip::decompress);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "ArchivePath"), "", "get_archive_path");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsOpen"), "", "get_is_open");
}

VGZip::VGZip() {
    zip_handle = nullptr;
    is_writing = false;
    is_open = false;
}

VGZip::~VGZip() {
    close();
}

// ---------------------------------------------------------------------------
// Open / Close
// ---------------------------------------------------------------------------

bool VGZip::open_read(const String &p_path) {
    close();

    Ref<ZIPReader> *reader = memnew(Ref<ZIPReader>);
    reader->instantiate();
    Error err = (*reader)->open(p_path);
    if (err != OK) {
        last_error = "Failed to open ZIP for reading: " + p_path;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        memdelete(reader);
        return false;
    }

    zip_handle = (void *)reader;
    archive_path = p_path;
    is_writing = false;
    is_open = true;
    last_error = "";
    return true;
}

bool VGZip::open_write(const String &p_path) {
    close();

    Ref<ZIPPacker> *packer = memnew(Ref<ZIPPacker>);
    packer->instantiate();
    Error err = (*packer)->open(p_path);
    if (err != OK) {
        last_error = "Failed to open ZIP for writing: " + p_path;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        memdelete(packer);
        return false;
    }

    zip_handle = (void *)packer;
    archive_path = p_path;
    is_writing = true;
    is_open = true;
    last_error = "";
    return true;
}

void VGZip::close() {
    if (!is_open || !zip_handle) return;

    if (is_writing) {
        Ref<ZIPPacker> *packer = (Ref<ZIPPacker> *)zip_handle;
        (*packer)->close();
        memdelete(packer);
    } else {
        Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
        (*reader)->close();
        memdelete(reader);
    }

    zip_handle = nullptr;
    is_open = false;
}

// ---------------------------------------------------------------------------
// Read operations
// ---------------------------------------------------------------------------

Array VGZip::list_files() {
    Array result;
    if (!is_open || is_writing || !zip_handle) {
        last_error = "ZIP not opened for reading";
        return result;
    }

    Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
    PackedStringArray files = (*reader)->get_files();
    for (int i = 0; i < files.size(); i++) {
        result.push_back(files[i]);
    }
    return result;
}

PackedByteArray VGZip::read_file(const String &p_name) {
    if (!is_open || is_writing || !zip_handle) {
        last_error = "ZIP not opened for reading";
        return PackedByteArray();
    }

    Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
    PackedByteArray data = (*reader)->read_file(p_name);
    return data;
}

String VGZip::read_text(const String &p_name) {
    PackedByteArray data = read_file(p_name);
    if (data.size() == 0) return "";
    return String::utf8((const char *)data.ptr(), data.size());
}

bool VGZip::extract_to(const String &p_dest_dir) {
    if (!is_open || is_writing || !zip_handle) {
        last_error = "ZIP not opened for reading";
        return false;
    }

    Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
    PackedStringArray files = (*reader)->get_files();

    // Ensure destination directory exists
    Ref<DirAccess> dir = DirAccess::open("res://");
    if (dir.is_valid()) {
        dir->make_dir_recursive(p_dest_dir);
    }

    for (int i = 0; i < files.size(); i++) {
        String file_name = files[i];
        String dest_path = p_dest_dir.path_join(file_name);

        // Create subdirectories if needed
        String dir_path = dest_path.get_base_dir();
        if (!dir_path.is_empty()) {
            Ref<DirAccess> sub_dir = DirAccess::open("res://");
            if (sub_dir.is_valid()) {
                sub_dir->make_dir_recursive(dir_path);
            }
        }

        // Skip directory entries
        if (file_name.ends_with("/")) continue;

        PackedByteArray data = (*reader)->read_file(file_name);
        Ref<FileAccess> f = FileAccess::open(dest_path, FileAccess::WRITE);
        if (!f.is_valid()) {
            last_error = "Cannot write: " + dest_path;
            UtilityFunctions::printerr("[VGZip] ", last_error);
            return false;
        }
        f->store_buffer(data);
    }

    return true;
}

bool VGZip::extract_file(const String &p_name, const String &p_dest_path) {
    PackedByteArray data = read_file(p_name);
    if (data.size() == 0 && !last_error.is_empty()) return false;

    // Ensure directory exists
    String dir_path = p_dest_path.get_base_dir();
    if (!dir_path.is_empty()) {
        Ref<DirAccess> dir = DirAccess::open("res://");
        if (dir.is_valid()) {
            dir->make_dir_recursive(dir_path);
        }
    }

    Ref<FileAccess> f = FileAccess::open(p_dest_path, FileAccess::WRITE);
    if (!f.is_valid()) {
        last_error = "Cannot write: " + p_dest_path;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        return false;
    }
    f->store_buffer(data);
    return true;
}

bool VGZip::file_exists(const String &p_name) {
    if (!is_open || is_writing || !zip_handle) return false;

    Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
    PackedStringArray files = (*reader)->get_files();
    for (int i = 0; i < files.size(); i++) {
        if (files[i] == p_name) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Write operations
// ---------------------------------------------------------------------------

bool VGZip::add_file(const String &p_name, const PackedByteArray &p_data) {
    if (!is_open || !is_writing || !zip_handle) {
        last_error = "ZIP not opened for writing";
        return false;
    }

    Ref<ZIPPacker> *packer = (Ref<ZIPPacker> *)zip_handle;
    Error err = (*packer)->start_file(p_name);
    if (err != OK) {
        last_error = "Failed to start file entry: " + p_name;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        return false;
    }

    err = (*packer)->write_file(p_data);
    if (err != OK) {
        last_error = "Failed to write file data: " + p_name;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        (*packer)->close_file();
        return false;
    }

    (*packer)->close_file();
    return true;
}

bool VGZip::add_text(const String &p_name, const String &p_text) {
    return add_file(p_name, p_text.to_utf8_buffer());
}

bool VGZip::add_directory_recursive(const String &p_base_dir, const String &p_prefix) {
    if (!is_open || !is_writing || !zip_handle) {
        last_error = "ZIP not opened for writing";
        return false;
    }

    Ref<DirAccess> dir = DirAccess::open(p_base_dir);
    if (!dir.is_valid()) {
        last_error = "Cannot open directory: " + p_base_dir;
        UtilityFunctions::printerr("[VGZip] ", last_error);
        return false;
    }

    dir->list_dir_begin();
    String item = dir->get_next();
    while (!item.is_empty()) {
        if (item == "." || item == "..") {
            item = dir->get_next();
            continue;
        }

        String full_path = p_base_dir.path_join(item);
        String zip_path = p_prefix.is_empty() ? item : p_prefix.path_join(item);

        if (dir->current_is_dir()) {
            // Recurse into subdirectory
            if (!add_directory_recursive(full_path, zip_path)) {
                dir->list_dir_end();
                return false;
            }
        } else {
            // Read file and add to zip
            Ref<FileAccess> f = FileAccess::open(full_path, FileAccess::READ);
            if (f.is_valid()) {
                PackedByteArray data;
                int64_t len = f->get_length();
                if (len > 0) {
                    data = f->get_buffer(len);
                }
                if (!add_file(zip_path, data)) {
                    dir->list_dir_end();
                    return false;
                }
            } else {
                UtilityFunctions::printerr("[VGZip] Cannot read: ", full_path);
            }
        }

        item = dir->get_next();
    }
    dir->list_dir_end();
    return true;
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

String VGZip::get_last_error() const {
    return last_error;
}

String VGZip::get_archive_path() const {
    return archive_path;
}

bool VGZip::get_is_open() const {
    return is_open;
}

int VGZip::get_file_count() {
    if (!is_open || is_writing || !zip_handle) return 0;
    Ref<ZIPReader> *reader = (Ref<ZIPReader> *)zip_handle;
    return (*reader)->get_files().size();
}

// ---------------------------------------------------------------------------
// Static helpers
// ---------------------------------------------------------------------------

bool VGZip::compress(const String &p_source_dir, const String &p_dest_zip) {
    Ref<VGZip> zip;
    zip.instantiate();
    if (!zip->open_write(p_dest_zip)) return false;
    bool ok = zip->add_directory_recursive(p_source_dir);
    zip->close();
    return ok;
}

bool VGZip::decompress(const String &p_zip_path, const String &p_dest_dir) {
    Ref<VGZip> zip;
    zip.instantiate();
    if (!zip->open_read(p_zip_path)) return false;
    bool ok = zip->extract_to(p_dest_dir);
    zip->close();
    return ok;
}

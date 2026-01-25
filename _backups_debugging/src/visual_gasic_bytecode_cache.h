#ifndef VISUAL_GASIC_BYTECODE_CACHE_H
#define VISUAL_GASIC_BYTECODE_CACHE_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// Simple hash of source code for cache validation
class SourceHash {
public:
    static uint64_t compute(const String& source) {
        uint64_t hash = 5381;
        for (int i = 0; i < source.length(); i++) {
            hash = ((hash << 5) + hash) + source[i];
        }
        return hash;
    }
};

class BytecodeCache {
private:
    String cache_dir;
    HashMap<String, uint64_t> source_hashes; // filename -> source hash

public:
    BytecodeCache(const String& p_cache_dir = "user://visualgasic_cache/") 
        : cache_dir(p_cache_dir) {
        // Create cache directory if it doesn't exist
        Ref<DirAccess> dir = DirAccess::open(p_cache_dir.get_basename());
        if (dir.is_valid() && !dir->dir_exists(p_cache_dir)) {
            dir->make_dir(p_cache_dir);
        }
    }

    // Generate cache filename from source filename
    String get_cache_filename(const String& source_file) {
        String filename = source_file.get_file();
        return cache_dir + filename + ".vgc"; // VisualGasic Compiled
    }

    // Check if cached bytecode is valid
    bool is_cached_valid(const String& source_file, const String& source_code) {
        String cache_file = get_cache_filename(source_file);
        
        Ref<FileAccess> file = FileAccess::open(cache_file, FileAccess::READ);
        if (!file.is_valid()) {
            return false; // No cache file
        }

        // Read stored hash from file (first 8 bytes)
        uint64_t stored_hash = file->get_64();
        uint64_t current_hash = SourceHash::compute(source_code);

        return stored_hash == current_hash;
    }

    // Save bytecode to cache
    bool save_bytecode(const String& source_file, const String& source_code, 
                       const Vector<uint8_t>& bytecode) {
        String cache_file = get_cache_filename(source_file);

        Ref<FileAccess> file = FileAccess::open(cache_file, FileAccess::WRITE);
        if (!file.is_valid()) {
            UtilityFunctions::printerr("Failed to open cache file: ", cache_file);
            return false;
        }

        // Write source hash
        uint64_t hash = SourceHash::compute(source_code);
        file->store_64(hash);

        // Write bytecode length
        file->store_32(bytecode.size());

        // Write bytecode
        // Convert Vector<uint8_t> to PackedByteArray
        PackedByteArray pba;
        pba.resize(bytecode.size());
        for (int i = 0; i < bytecode.size(); i++) {
            pba[i] = bytecode[i];
        }
        file->store_buffer(pba);

        return true;
    }

    // Load bytecode from cache
    bool load_bytecode(const String& source_file, Vector<uint8_t>& out_bytecode) {
        String cache_file = get_cache_filename(source_file);

        Ref<FileAccess> file = FileAccess::open(cache_file, FileAccess::READ);
        if (!file.is_valid()) {
            return false;
        }

        // Skip hash (already validated)
        file->get_64();

        // Read bytecode length
        uint32_t length = file->get_32();

        // Read bytecode
        PackedByteArray pba = file->get_buffer(length);
        out_bytecode.clear();
        for (int i = 0; i < pba.size(); i++) {
            out_bytecode.push_back(pba[i]);
        }

        return true;
    }

    // Clear cache for a specific file
    void clear_cache(const String& source_file) {
        String cache_file = get_cache_filename(source_file);
        Ref<DirAccess> dir = DirAccess::open(cache_dir);
        
        if (dir.is_valid() && dir->file_exists(cache_file)) {
            dir->remove(cache_file);
        }
    }

    // Clear entire cache directory
    void clear_all() {
        Ref<DirAccess> dir = DirAccess::open(cache_dir);
        
        if (dir.is_valid()) {
            dir->list_dir_begin();
            String file = dir->get_next();
            while (file != "") {
                if (file.ends_with(".vgc")) {
                    dir->remove(cache_dir + file);
                }
                file = dir->get_next();
            }
        }
    }

    void set_cache_dir(const String& p_dir) {
        cache_dir = p_dir;
        // Ensure trailing slash
        if (!cache_dir.ends_with("/")) {
            cache_dir += "/";
        }
    }

    String get_cache_dir() const {
        return cache_dir;
    }
};

#endif // VISUAL_GASIC_BYTECODE_CACHE_H

#ifndef VISUAL_GASIC_MEMORY_BUFFER_H
#define VISUAL_GASIC_MEMORY_BUFFER_H

// VGMemoryBuffer — Raw memory buffer for system-level programming
// Provides Peek/Poke byte-level access, CopyMemory, memory-mapped files.
//
// Usage in VisualGasic:
//   Dim buf As New VGMemoryBuffer
//   buf.Allocate 1024
//   buf.PokeByte 0, &hFF
//   buf.PokeInt32 4, 42
//   Print buf.PeekByte(0)    ' 255
//   Print buf.PeekInt32(4)   ' 42
//
//   ' Copy between buffers
//   Dim buf2 As New VGMemoryBuffer
//   buf2.Allocate 512
//   buf.CopyTo buf2, 0, 0, 256
//
//   ' Convert to/from PackedByteArray
//   Dim arr As PackedByteArray = buf.ToByteArray()
//   buf.FromByteArray arr

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <cstdint>
#include <cstring>

using namespace godot;

class VGMemoryBuffer : public RefCounted {
    GDCLASS(VGMemoryBuffer, RefCounted);

    uint8_t *data;
    int64_t capacity;
    String last_error;

    bool check_bounds(int64_t offset, int64_t size) const;

protected:
    static void _bind_methods();

public:
    VGMemoryBuffer();
    ~VGMemoryBuffer();

    // --- Allocation ---
    bool allocate(int64_t p_size);
    bool resize(int64_t p_new_size);
    void free_memory();
    bool is_allocated() const { return data != nullptr; }
    int64_t get_size() const { return capacity; }

    // --- Fill / Clear ---
    void fill(uint8_t p_value);
    void fill_range(int64_t p_offset, int64_t p_length, uint8_t p_value);
    void clear();

    // --- Peek (Read) ---
    int peek_byte(int64_t p_offset) const;
    int peek_int16(int64_t p_offset) const;
    int peek_uint16(int64_t p_offset) const;
    int peek_int32(int64_t p_offset) const;
    int64_t peek_int64(int64_t p_offset) const;
    double peek_float(int64_t p_offset) const;
    double peek_double(int64_t p_offset) const;
    String peek_string(int64_t p_offset, int64_t p_length) const;

    // --- Poke (Write) ---
    void poke_byte(int64_t p_offset, int p_value);
    void poke_int16(int64_t p_offset, int p_value);
    void poke_uint16(int64_t p_offset, int p_value);
    void poke_int32(int64_t p_offset, int p_value);
    void poke_int64(int64_t p_offset, int64_t p_value);
    void poke_float(int64_t p_offset, double p_value);
    void poke_double(int64_t p_offset, double p_value);
    void poke_string(int64_t p_offset, const String &p_value);

    // --- Copy ---
    void copy_to(Ref<VGMemoryBuffer> p_dest, int64_t p_src_offset, int64_t p_dst_offset, int64_t p_length);
    void copy_from(const Ref<VGMemoryBuffer> &p_src, int64_t p_src_offset, int64_t p_dst_offset, int64_t p_length);

    // --- Conversion ---
    PackedByteArray to_byte_array() const;
    PackedByteArray to_byte_array_range(int64_t p_offset, int64_t p_length) const;
    void from_byte_array(const PackedByteArray &p_array);

    // --- Search ---
    int64_t find_byte(uint8_t p_value, int64_t p_start = 0) const;
    int64_t find_pattern(const PackedByteArray &p_pattern, int64_t p_start = 0) const;

    // --- Hex Dump ---
    String hex_dump(int64_t p_offset, int64_t p_length) const;

    // --- Pointer (for FFI interop) ---
    int64_t get_pointer() const { return (int64_t)(uintptr_t)data; }

    // Error
    String get_last_error() const { return last_error; }
};

#endif // VISUAL_GASIC_MEMORY_BUFFER_H

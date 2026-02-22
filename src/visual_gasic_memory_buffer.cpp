// ============================================================================
// VGMemoryBuffer — Raw memory buffer with Peek/Poke byte-level access
// ============================================================================
#include "visual_gasic_memory_buffer.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <cstdlib>
#include <cstdio>
#include <algorithm>

using namespace godot;

VGMemoryBuffer::VGMemoryBuffer() : data(nullptr), capacity(0) {}

VGMemoryBuffer::~VGMemoryBuffer() {
    free_memory();
}

bool VGMemoryBuffer::check_bounds(int64_t offset, int64_t size) const {
    if (!data) {
        return false;
    }
    if (offset < 0 || offset + size > capacity) {
        return false;
    }
    return true;
}

// ─── Allocation ────────────────────────────────────────────────────────────

bool VGMemoryBuffer::allocate(int64_t p_size) {
    if (p_size <= 0) {
        last_error = "Size must be positive";
        return false;
    }
    free_memory();
    data = (uint8_t *)std::calloc((size_t)p_size, 1);
    if (!data) {
        last_error = "Allocation failed";
        return false;
    }
    capacity = p_size;
    return true;
}

bool VGMemoryBuffer::resize(int64_t p_new_size) {
    if (p_new_size <= 0) {
        last_error = "Size must be positive";
        return false;
    }
    uint8_t *new_data = (uint8_t *)std::realloc(data, (size_t)p_new_size);
    if (!new_data) {
        last_error = "Reallocation failed";
        return false;
    }
    // Zero new memory if growing
    if (p_new_size > capacity) {
        std::memset(new_data + capacity, 0, (size_t)(p_new_size - capacity));
    }
    data = new_data;
    capacity = p_new_size;
    return true;
}

void VGMemoryBuffer::free_memory() {
    if (data) {
        std::free(data);
        data = nullptr;
        capacity = 0;
    }
}

// ─── Fill / Clear ──────────────────────────────────────────────────────────

void VGMemoryBuffer::fill(uint8_t p_value) {
    if (data) std::memset(data, p_value, (size_t)capacity);
}

void VGMemoryBuffer::fill_range(int64_t p_offset, int64_t p_length, uint8_t p_value) {
    if (check_bounds(p_offset, p_length))
        std::memset(data + p_offset, p_value, (size_t)p_length);
}

void VGMemoryBuffer::clear() {
    fill(0);
}

// ─── Peek (Read) ───────────────────────────────────────────────────────────

int VGMemoryBuffer::peek_byte(int64_t p_offset) const {
    if (!check_bounds(p_offset, 1)) return -1;
    return data[p_offset];
}

int VGMemoryBuffer::peek_int16(int64_t p_offset) const {
    if (!check_bounds(p_offset, 2)) return 0;
    int16_t val;
    std::memcpy(&val, data + p_offset, 2);
    return val;
}

int VGMemoryBuffer::peek_uint16(int64_t p_offset) const {
    if (!check_bounds(p_offset, 2)) return 0;
    uint16_t val;
    std::memcpy(&val, data + p_offset, 2);
    return val;
}

int VGMemoryBuffer::peek_int32(int64_t p_offset) const {
    if (!check_bounds(p_offset, 4)) return 0;
    int32_t val;
    std::memcpy(&val, data + p_offset, 4);
    return val;
}

int64_t VGMemoryBuffer::peek_int64(int64_t p_offset) const {
    if (!check_bounds(p_offset, 8)) return 0;
    int64_t val;
    std::memcpy(&val, data + p_offset, 8);
    return val;
}

double VGMemoryBuffer::peek_float(int64_t p_offset) const {
    if (!check_bounds(p_offset, 4)) return 0.0;
    float val;
    std::memcpy(&val, data + p_offset, 4);
    return (double)val;
}

double VGMemoryBuffer::peek_double(int64_t p_offset) const {
    if (!check_bounds(p_offset, 8)) return 0.0;
    double val;
    std::memcpy(&val, data + p_offset, 8);
    return val;
}

String VGMemoryBuffer::peek_string(int64_t p_offset, int64_t p_length) const {
    if (!check_bounds(p_offset, p_length)) return "";
    // Find null terminator within range
    int64_t actual_len = 0;
    while (actual_len < p_length && data[p_offset + actual_len] != 0) actual_len++;
    return String::utf8((const char *)(data + p_offset), (int)actual_len);
}

// ─── Poke (Write) ──────────────────────────────────────────────────────────

void VGMemoryBuffer::poke_byte(int64_t p_offset, int p_value) {
    if (check_bounds(p_offset, 1)) data[p_offset] = (uint8_t)(p_value & 0xFF);
}

void VGMemoryBuffer::poke_int16(int64_t p_offset, int p_value) {
    if (check_bounds(p_offset, 2)) {
        int16_t val = (int16_t)p_value;
        std::memcpy(data + p_offset, &val, 2);
    }
}

void VGMemoryBuffer::poke_uint16(int64_t p_offset, int p_value) {
    if (check_bounds(p_offset, 2)) {
        uint16_t val = (uint16_t)p_value;
        std::memcpy(data + p_offset, &val, 2);
    }
}

void VGMemoryBuffer::poke_int32(int64_t p_offset, int p_value) {
    if (check_bounds(p_offset, 4)) {
        int32_t val = (int32_t)p_value;
        std::memcpy(data + p_offset, &val, 4);
    }
}

void VGMemoryBuffer::poke_int64(int64_t p_offset, int64_t p_value) {
    if (check_bounds(p_offset, 8)) {
        std::memcpy(data + p_offset, &p_value, 8);
    }
}

void VGMemoryBuffer::poke_float(int64_t p_offset, double p_value) {
    if (check_bounds(p_offset, 4)) {
        float val = (float)p_value;
        std::memcpy(data + p_offset, &val, 4);
    }
}

void VGMemoryBuffer::poke_double(int64_t p_offset, double p_value) {
    if (check_bounds(p_offset, 8)) {
        std::memcpy(data + p_offset, &p_value, 8);
    }
}

void VGMemoryBuffer::poke_string(int64_t p_offset, const String &p_value) {
    CharString utf8 = p_value.utf8();
    int64_t len = utf8.length() + 1;  // +1 for null terminator
    if (check_bounds(p_offset, len)) {
        std::memcpy(data + p_offset, utf8.get_data(), (size_t)len);
    }
}

// ─── Copy ──────────────────────────────────────────────────────────────────

void VGMemoryBuffer::copy_to(Ref<VGMemoryBuffer> p_dest, int64_t p_src_offset, int64_t p_dst_offset, int64_t p_length) {
    if (p_dest.is_null() || !p_dest->data) {
        last_error = "Destination buffer is null";
        return;
    }
    if (!check_bounds(p_src_offset, p_length)) {
        last_error = "Source range out of bounds";
        return;
    }
    if (!p_dest->check_bounds(p_dst_offset, p_length)) {
        last_error = "Destination range out of bounds";
        return;
    }
    std::memmove(p_dest->data + p_dst_offset, data + p_src_offset, (size_t)p_length);
}

void VGMemoryBuffer::copy_from(const Ref<VGMemoryBuffer> &p_src, int64_t p_src_offset, int64_t p_dst_offset, int64_t p_length) {
    if (p_src.is_null() || !p_src->data) {
        last_error = "Source buffer is null";
        return;
    }
    if (!p_src->check_bounds(p_src_offset, p_length)) {
        last_error = "Source range out of bounds";
        return;
    }
    if (!check_bounds(p_dst_offset, p_length)) {
        last_error = "Destination range out of bounds";
        return;
    }
    std::memmove(data + p_dst_offset, p_src->data + p_src_offset, (size_t)p_length);
}

// ─── Conversion ────────────────────────────────────────────────────────────

PackedByteArray VGMemoryBuffer::to_byte_array() const {
    PackedByteArray arr;
    if (data && capacity > 0) {
        arr.resize((int64_t)capacity);
        std::memcpy(arr.ptrw(), data, (size_t)capacity);
    }
    return arr;
}

PackedByteArray VGMemoryBuffer::to_byte_array_range(int64_t p_offset, int64_t p_length) const {
    PackedByteArray arr;
    if (check_bounds(p_offset, p_length)) {
        arr.resize(p_length);
        std::memcpy(arr.ptrw(), data + p_offset, (size_t)p_length);
    }
    return arr;
}

void VGMemoryBuffer::from_byte_array(const PackedByteArray &p_array) {
    int64_t sz = p_array.size();
    if (sz <= 0) return;
    if (!allocate(sz)) return;
    std::memcpy(data, p_array.ptr(), (size_t)sz);
}

// ─── Search ────────────────────────────────────────────────────────────────

int64_t VGMemoryBuffer::find_byte(uint8_t p_value, int64_t p_start) const {
    if (!data || p_start < 0 || p_start >= capacity) return -1;
    for (int64_t i = p_start; i < capacity; i++) {
        if (data[i] == p_value) return i;
    }
    return -1;
}

int64_t VGMemoryBuffer::find_pattern(const PackedByteArray &p_pattern, int64_t p_start) const {
    if (!data || p_pattern.size() == 0) return -1;
    int64_t pat_len = p_pattern.size();
    const uint8_t *pat = p_pattern.ptr();
    for (int64_t i = p_start; i <= capacity - pat_len; i++) {
        if (std::memcmp(data + i, pat, (size_t)pat_len) == 0) return i;
    }
    return -1;
}

// ─── Hex Dump ──────────────────────────────────────────────────────────────

String VGMemoryBuffer::hex_dump(int64_t p_offset, int64_t p_length) const {
    if (!check_bounds(p_offset, p_length)) return "Invalid range";
    String result;
    for (int64_t i = 0; i < p_length; i++) {
        if (i > 0 && i % 16 == 0) result += "\n";
        else if (i > 0) result += " ";
        char hex[4];
        snprintf(hex, sizeof(hex), "%02X", data[p_offset + i]);
        result += hex;
    }
    return result;
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGMemoryBuffer::_bind_methods() {
    // Allocation
    ClassDB::bind_method(D_METHOD("Allocate", "size"),    &VGMemoryBuffer::allocate);
    ClassDB::bind_method(D_METHOD("Resize", "new_size"),  &VGMemoryBuffer::resize);
    ClassDB::bind_method(D_METHOD("Free"),                &VGMemoryBuffer::free_memory);
    ClassDB::bind_method(D_METHOD("get_is_allocated"),    &VGMemoryBuffer::is_allocated);
    ClassDB::bind_method(D_METHOD("get_size"),            &VGMemoryBuffer::get_size);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsAllocated"), "", "get_is_allocated");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Size"), "", "get_size");

    // Fill
    ClassDB::bind_method(D_METHOD("Fill", "value"),                         &VGMemoryBuffer::fill);
    ClassDB::bind_method(D_METHOD("FillRange", "offset", "length", "value"), &VGMemoryBuffer::fill_range);
    ClassDB::bind_method(D_METHOD("Clear"),                                 &VGMemoryBuffer::clear);

    // Peek
    ClassDB::bind_method(D_METHOD("PeekByte", "offset"),            &VGMemoryBuffer::peek_byte);
    ClassDB::bind_method(D_METHOD("PeekInt16", "offset"),           &VGMemoryBuffer::peek_int16);
    ClassDB::bind_method(D_METHOD("PeekUInt16", "offset"),          &VGMemoryBuffer::peek_uint16);
    ClassDB::bind_method(D_METHOD("PeekInt32", "offset"),           &VGMemoryBuffer::peek_int32);
    ClassDB::bind_method(D_METHOD("PeekInt64", "offset"),           &VGMemoryBuffer::peek_int64);
    ClassDB::bind_method(D_METHOD("PeekFloat", "offset"),           &VGMemoryBuffer::peek_float);
    ClassDB::bind_method(D_METHOD("PeekDouble", "offset"),          &VGMemoryBuffer::peek_double);
    ClassDB::bind_method(D_METHOD("PeekString", "offset", "length"), &VGMemoryBuffer::peek_string);

    // Poke
    ClassDB::bind_method(D_METHOD("PokeByte", "offset", "value"),   &VGMemoryBuffer::poke_byte);
    ClassDB::bind_method(D_METHOD("PokeInt16", "offset", "value"),  &VGMemoryBuffer::poke_int16);
    ClassDB::bind_method(D_METHOD("PokeUInt16", "offset", "value"), &VGMemoryBuffer::poke_uint16);
    ClassDB::bind_method(D_METHOD("PokeInt32", "offset", "value"),  &VGMemoryBuffer::poke_int32);
    ClassDB::bind_method(D_METHOD("PokeInt64", "offset", "value"),  &VGMemoryBuffer::poke_int64);
    ClassDB::bind_method(D_METHOD("PokeFloat", "offset", "value"),  &VGMemoryBuffer::poke_float);
    ClassDB::bind_method(D_METHOD("PokeDouble", "offset", "value"), &VGMemoryBuffer::poke_double);
    ClassDB::bind_method(D_METHOD("PokeString", "offset", "value"), &VGMemoryBuffer::poke_string);

    // Copy
    ClassDB::bind_method(D_METHOD("CopyTo", "dest", "src_offset", "dst_offset", "length"),   &VGMemoryBuffer::copy_to);
    ClassDB::bind_method(D_METHOD("CopyFrom", "src", "src_offset", "dst_offset", "length"),   &VGMemoryBuffer::copy_from);

    // Conversion
    ClassDB::bind_method(D_METHOD("ToByteArray"),                         &VGMemoryBuffer::to_byte_array);
    ClassDB::bind_method(D_METHOD("ToByteArrayRange", "offset", "length"), &VGMemoryBuffer::to_byte_array_range);
    ClassDB::bind_method(D_METHOD("FromByteArray", "array"),              &VGMemoryBuffer::from_byte_array);

    // Search
    ClassDB::bind_method(D_METHOD("FindByte", "value", "start"),     &VGMemoryBuffer::find_byte);
    ClassDB::bind_method(D_METHOD("FindPattern", "pattern", "start"), &VGMemoryBuffer::find_pattern);

    // Hex dump
    ClassDB::bind_method(D_METHOD("HexDump", "offset", "length"), &VGMemoryBuffer::hex_dump);

    // Pointer (for FFI interop)
    ClassDB::bind_method(D_METHOD("get_pointer"), &VGMemoryBuffer::get_pointer);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Pointer"), "", "get_pointer");

    // Error
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGMemoryBuffer::get_last_error);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
}

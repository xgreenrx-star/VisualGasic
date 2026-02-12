#ifndef VG_FAST_DICT_H
#define VG_FAST_DICT_H

/*  VGFastStringDict – A dedicated string-keyed hash map that bypasses
 *  Godot's Variant Dictionary entirely for VG-internal dictionary ops.
 *
 *  Design goals (in priority order):
 *    1. Zero Variant boxing overhead for keys (keys are always String)
 *    2. No copy-on-write: uniquely owned, never copied
 *    3. Pre-hashed key storage: each slot stores hash alongside key
 *    4. Inline cache for the last-accessed key (pointer-based)
 *    5. Open-addressing hash table with power-of-2 sizing
 */

#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

struct VGFastStringDict {
    // ── Open-addressing hash table ───────────────────────────────────
    struct Entry {
        String  key;
        Variant value;
        uint32_t hash = 0;
        bool occupied = false;
    };

    Entry *table = nullptr;
    uint32_t capacity = 0;   // always power-of-2
    uint32_t count = 0;
    uint32_t mask = 0;        // capacity - 1

    // ── 1-entry inline cache ─────────────────────────────────────────
    mutable uint32_t cache_hash = 0;
    mutable int      cache_idx = -1;  // index into table[]

    // ── Construction ─────────────────────────────────────────────────
    VGFastStringDict() = default;  // lazy init — table allocated on first use
    ~VGFastStringDict() { _free(); }

    // Move-only
    VGFastStringDict(const VGFastStringDict &) = delete;
    VGFastStringDict &operator=(const VGFastStringDict &) = delete;
    VGFastStringDict(VGFastStringDict &&other) noexcept {
        table = other.table; capacity = other.capacity;
        count = other.count; mask = other.mask;
        cache_hash = 0; cache_idx = -1;
        other.table = nullptr; other.capacity = 0;
        other.count = 0; other.mask = 0;
    }
    VGFastStringDict &operator=(VGFastStringDict &&other) noexcept {
        _free();
        table = other.table; capacity = other.capacity;
        count = other.count; mask = other.mask;
        cache_hash = 0; cache_idx = -1;
        other.table = nullptr; other.capacity = 0;
        other.count = 0; other.mask = 0;
        return *this;
    }

    // ── Hash helper ──────────────────────────────────────────────────
    static _FORCE_INLINE_ uint32_t _hash_string(const String &s) {
        // Use Godot's built-in String hash (FNV-like, cached internally)
        return s.hash();
    }

    // ── Allocation ───────────────────────────────────────────────────
    void _alloc(uint32_t new_cap) {
        table = memnew_arr(Entry, new_cap);
        capacity = new_cap;
        mask = new_cap - 1;
    }

    void _free() {
        if (table) {
            memdelete_arr(table);
            table = nullptr;
        }
        capacity = 0; count = 0; mask = 0;
        cache_idx = -1;
    }

    void _grow() {
        uint32_t old_cap = capacity;
        Entry *old_table = table;
        uint32_t new_cap = old_cap * 2;
        _alloc(new_cap);
        count = 0;
        cache_idx = -1;
        for (uint32_t i = 0; i < old_cap; i++) {
            if (old_table[i].occupied) {
                _insert_no_grow(old_table[i].hash, old_table[i].key, old_table[i].value);
            }
        }
        memdelete_arr(old_table);
    }

    void _insert_no_grow(uint32_t h, const String &key, const Variant &value) {
        uint32_t idx = h & mask;
        while (table[idx].occupied) {
            idx = (idx + 1) & mask;
        }
        table[idx].key = key;
        table[idx].value = value;
        table[idx].hash = h;
        table[idx].occupied = true;
        count++;
    }

    // ── Find slot by key (returns index or -1) ───────────────────────
    _FORCE_INLINE_ int _find(uint32_t h, const String &key) const {
        // Inline cache check
        if (cache_idx >= 0 && cache_hash == h) {
            if (table[cache_idx].occupied && table[cache_idx].key == key) {
                return cache_idx;
            }
        }
        uint32_t idx = h & mask;
        uint32_t start = idx;
        while (table[idx].occupied) {
            if (table[idx].hash == h && table[idx].key == key) {
                cache_hash = h;
                cache_idx = (int)idx;
                return (int)idx;
            }
            idx = (idx + 1) & mask;
            if (idx == start) break;  // full wrap — shouldn't happen with load < 0.75
        }
        return -1;
    }

    // ── Primary API ──────────────────────────────────────────────────

    _FORCE_INLINE_ Variant get(const String &key, const Variant &p_default = Variant()) const {
        if (!table || count == 0) return p_default;
        uint32_t h = _hash_string(key);
        int idx = _find(h, key);
        if (idx >= 0) return table[idx].value;
        return p_default;
    }

    _FORCE_INLINE_ Variant *getptr(const String &key) const {
        if (!table || count == 0) return nullptr;
        uint32_t h = _hash_string(key);
        int idx = _find(h, key);
        if (idx >= 0) return const_cast<Variant*>(&table[idx].value);
        return nullptr;
    }

    _FORCE_INLINE_ void set(const String &key, const Variant &value) {
        // Lazy init
        if (!table) { _alloc(64); }
        uint32_t h = _hash_string(key);
        // Try inline cache first
        if (cache_idx >= 0 && cache_hash == h) {
            Entry &e = table[cache_idx];
            if (e.occupied && e.key == key) {
                e.value = value;
                return;
            }
        }
        // Try to find existing key
        if (table && count > 0) {
            uint32_t idx = h & mask;
            uint32_t start = idx;
            while (table[idx].occupied) {
                if (table[idx].hash == h && table[idx].key == key) {
                    table[idx].value = value;
                    cache_hash = h; cache_idx = (int)idx;
                    return;
                }
                idx = (idx + 1) & mask;
                if (idx == start) break;
            }
        }
        // New key — check load factor
        if (count * 4 >= capacity * 3) {  // 75% load
            _grow();
        }
        // Insert
        uint32_t idx = h & mask;
        while (table[idx].occupied) {
            idx = (idx + 1) & mask;
        }
        table[idx].key = key;
        table[idx].value = value;
        table[idx].hash = h;
        table[idx].occupied = true;
        cache_hash = h; cache_idx = (int)idx;
        count++;
    }

    _FORCE_INLINE_ bool has(const String &key) const {
        if (!table || count == 0) return false;
        uint32_t h = _hash_string(key);
        return _find(h, key) >= 0;
    }

    _FORCE_INLINE_ int size() const { return (int)count; }

    bool erase(const String &key) {
        if (!table || count == 0) return false;
        uint32_t h = _hash_string(key);
        int idx = _find(h, key);
        if (idx < 0) return false;
        // Mark as deleted and re-insert displaced entries (Robin Hood style)
        table[idx].occupied = false;
        table[idx].key = String();
        table[idx].value = Variant();
        table[idx].hash = 0;
        cache_idx = -1;
        count--;
        // Re-probe and re-insert any entries that were displaced
        uint32_t next = ((uint32_t)idx + 1) & mask;
        while (table[next].occupied) {
            Entry displaced = table[next];
            table[next].occupied = false;
            table[next].key = String();
            table[next].value = Variant();
            table[next].hash = 0;
            count--;
            _insert_no_grow(displaced.hash, displaced.key, displaced.value);
            next = (next + 1) & mask;
        }
        return true;
    }

    void clear() {
        if (table) {
            memdelete_arr(table);
            table = nullptr;
        }
        capacity = 0; count = 0; mask = 0;
        cache_idx = -1;
    }

    Array keys() const {
        Array result;
        result.resize((int)count);
        int j = 0;
        if (table) {
            for (uint32_t i = 0; i < capacity && j < (int)count; i++) {
                if (table[i].occupied) {
                    result[j++] = table[i].key;
                }
            }
        }
        return result;
    }

    Array values() const {
        Array result;
        result.resize((int)count);
        int j = 0;
        if (table) {
            for (uint32_t i = 0; i < capacity && j < (int)count; i++) {
                if (table[i].occupied) {
                    result[j++] = table[i].value;
                }
            }
        }
        return result;
    }

    Dictionary to_godot_dict() const {
        Dictionary d;
        if (table) {
            for (uint32_t i = 0; i < capacity; i++) {
                if (table[i].occupied) {
                    d[table[i].key] = table[i].value;
                }
            }
        }
        return d;
    }
};

#endif // VG_FAST_DICT_H

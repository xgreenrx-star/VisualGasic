// VGCollection — VB6 Collection object emulation
// Ordered collection with Add/Remove/Item(index)/Count + optional string keys

#ifndef VISUAL_GASIC_COLLECTION_H
#define VISUAL_GASIC_COLLECTION_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class VGCollection : public RefCounted {
    GDCLASS(VGCollection, RefCounted)

protected:
    static void _bind_methods();

public:
    VGCollection();
    ~VGCollection();

    // VB6 Collection API
    void add(const Variant &p_item, const String &p_key = "", int p_before = -1, int p_after = -1);
    void remove(const Variant &p_index); // Can be int (1-based) or String key
    Variant item(const Variant &p_index) const; // 1-based index or string key
    int get_count() const;

    // Extended API
    bool has_key(const String &p_key) const;
    Array get_items() const;
    Array get_keys() const;
    void clear();

    // For Each support
    Array to_array() const;

    // Generics Phase 1: Collection(Of T) type constraint
    void set_element_type(const String &p_type);
    String get_element_type() const;

    // VB6-style aliases
    // Add, Remove, Item, Count — bound in _bind_methods

private:
    Array items_array;           // Ordered items
    Array keys_array;            // Parallel array of String keys ("" if no key)
    Dictionary key_to_index;     // key → index in items_array (for fast lookup)
    String element_type;         // Generic constraint: "" = any, "Integer"/"String"/"Sprite" etc.
};

} // namespace godot

#endif // VISUAL_GASIC_COLLECTION_H

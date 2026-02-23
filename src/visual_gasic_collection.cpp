// VGCollection — VB6 Collection object emulation
// Ordered collection with Add/Remove/Item(index)/Count + optional string keys

#include "visual_gasic_collection.h"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void VGCollection::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add", "item", "key", "before", "after"), &VGCollection::add, DEFVAL(""), DEFVAL(-1), DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("remove", "index"), &VGCollection::remove);
    ClassDB::bind_method(D_METHOD("item", "index"), &VGCollection::item);
    ClassDB::bind_method(D_METHOD("get_count"), &VGCollection::get_count);
    ClassDB::bind_method(D_METHOD("has_key", "key"), &VGCollection::has_key);
    ClassDB::bind_method(D_METHOD("get_items"), &VGCollection::get_items);
    ClassDB::bind_method(D_METHOD("get_keys"), &VGCollection::get_keys);
    ClassDB::bind_method(D_METHOD("clear"), &VGCollection::clear);
    ClassDB::bind_method(D_METHOD("to_array"), &VGCollection::to_array);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("Add", "item", "key", "before", "after"), &VGCollection::add, DEFVAL(""), DEFVAL(-1), DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("Remove", "index"), &VGCollection::remove);
    ClassDB::bind_method(D_METHOD("Item", "index"), &VGCollection::item);
    ClassDB::bind_method(D_METHOD("HasKey", "key"), &VGCollection::has_key);
    ClassDB::bind_method(D_METHOD("Clear"), &VGCollection::clear);
    ClassDB::bind_method(D_METHOD("Items"), &VGCollection::get_items);
    ClassDB::bind_method(D_METHOD("Keys"), &VGCollection::get_keys);
    ClassDB::bind_method(D_METHOD("Count"), &VGCollection::get_count);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "Count"), "", "get_count");
}

VGCollection::VGCollection() {}
VGCollection::~VGCollection() {}

void VGCollection::add(const Variant &p_item, const String &p_key, int p_before, int p_after) {
    // Check for duplicate key
    if (!p_key.is_empty()) {
        if (key_to_index.has(p_key)) {
            UtilityFunctions::printerr("[VGCollection] Key already exists: ", p_key);
            return;
        }
    }

    int insert_pos = items_array.size(); // Default: append

    if (p_before >= 1 && p_before <= items_array.size()) {
        insert_pos = p_before - 1; // VB6 is 1-based
    } else if (p_after >= 1 && p_after <= items_array.size()) {
        insert_pos = p_after; // After = index (0-based after conversion)
    }

    // Insert at position
    items_array.insert(insert_pos, p_item);
    keys_array.insert(insert_pos, p_key);

    // Rebuild key_to_index map for all items at and after insert point
    for (int i = insert_pos; i < items_array.size(); i++) {
        String k = keys_array[i];
        if (!k.is_empty()) {
            key_to_index[k] = i;
        }
    }
}

void VGCollection::remove(const Variant &p_index) {
    int idx = -1;

    if (p_index.get_type() == Variant::STRING) {
        // Remove by key
        String key = p_index;
        if (!key_to_index.has(key)) {
            UtilityFunctions::printerr("[VGCollection] Key not found: ", key);
            return;
        }
        idx = key_to_index[key];
    } else {
        // Remove by 1-based index
        idx = (int)p_index - 1;
    }

    if (idx < 0 || idx >= items_array.size()) {
        UtilityFunctions::printerr("[VGCollection] Index out of range: ", p_index);
        return;
    }

    // Remove the key mapping
    String old_key = keys_array[idx];
    if (!old_key.is_empty()) {
        key_to_index.erase(old_key);
    }

    items_array.remove_at(idx);
    keys_array.remove_at(idx);

    // Rebuild key_to_index for shifted items
    for (int i = idx; i < items_array.size(); i++) {
        String k = keys_array[i];
        if (!k.is_empty()) {
            key_to_index[k] = i;
        }
    }
}

Variant VGCollection::item(const Variant &p_index) const {
    if (p_index.get_type() == Variant::STRING) {
        // Lookup by key
        String key = p_index;
        if (!key_to_index.has(key)) {
            UtilityFunctions::printerr("[VGCollection] Key not found: ", key);
            return Variant();
        }
        int idx = key_to_index[key];
        return items_array[idx];
    }

    // Lookup by 1-based index
    int idx = (int)p_index - 1;
    if (idx < 0 || idx >= items_array.size()) {
        UtilityFunctions::printerr("[VGCollection] Index out of range: ", p_index);
        return Variant();
    }
    return items_array[idx];
}

int VGCollection::get_count() const {
    return items_array.size();
}

bool VGCollection::has_key(const String &p_key) const {
    return key_to_index.has(p_key);
}

Array VGCollection::get_items() const {
    return items_array;
}

Array VGCollection::get_keys() const {
    return keys_array;
}

void VGCollection::clear() {
    items_array.clear();
    keys_array.clear();
    key_to_index.clear();
}

Array VGCollection::to_array() const {
    return items_array;
}

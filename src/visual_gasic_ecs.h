#ifndef VISUAL_GASIC_ECS_H
#define VISUAL_GASIC_ECS_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <vector>
#include <unordered_map>
#include <unordered_set>

using namespace godot;

/**
 * VGEcs — Entity-Component-System for VisualGasic
 *
 * Lightweight, Dictionary-based ECS designed for VB6-style scripts.
 * Components are simply Dictionaries keyed by a string type name.
 *
 * VB6-style API:
 *   Dim ecs As New VGEcs
 *   ecs.RegisterComponentType "Transform"
 *   Dim e As Long
 *   e = ecs.CreateEntity()
 *   ecs.AddComponent e, "Transform", CreateObject("Dictionary")  ' {x:0,y:0}
 *   ecs.Update 0.016
 */
class VisualGasicECS : public RefCounted {
    GDCLASS(VisualGasicECS, RefCounted)

public:
    using EntityId = uint32_t;
    static constexpr EntityId INVALID_ENTITY = 0;

private:
    // ── Entity bookkeeping ────────────────────────────
    uint32_t next_entity_id = 1;
    std::vector<uint32_t> free_ids;
    std::unordered_set<uint32_t> alive;

    // ── Component storage ─────────────────────────────
    // registered type names (lower-case canonical)
    std::unordered_set<std::string> registered_types;

    // entity → { type_name → Dictionary }
    std::unordered_map<uint32_t, std::unordered_map<std::string, Dictionary>> components;

    // ── Performance ───────────────────────────────────
    bool profiling_enabled = false;
    int total_updates = 0;

public:
    VisualGasicECS();
    ~VisualGasicECS();

    // ── Component type registration ───────────────────
    void register_component_type(const String &type_name);
    bool has_component_type(const String &type_name) const;
    Array get_component_types() const;

    // ── Entity lifecycle ──────────────────────────────
    int create_entity();
    void destroy_entity(int entity);
    bool is_entity_valid(int entity) const;
    int get_entity_count() const;
    Array get_all_entities() const;

    // ── Component CRUD ────────────────────────────────
    void add_component(int entity, const String &type_name, const Dictionary &data);
    Dictionary get_component(int entity, const String &type_name) const;
    bool has_component(int entity, const String &type_name) const;
    void remove_component(int entity, const String &type_name);
    void set_component(int entity, const String &type_name, const Dictionary &data);

    // ── Queries ───────────────────────────────────────
    Array query(const Array &required);
    Array query_exclude(const Array &required, const Array &excluded);

    // ── Lifecycle / simulation step ───────────────────
    void update(double delta);
    void clear();

    // ── Serialization ─────────────────────────────────
    Dictionary serialize() const;
    void deserialize(const Dictionary &data);

    // ── Debugging ─────────────────────────────────────
    void enable_profiling(bool enabled);
    Dictionary get_debug_info() const;
    Dictionary get_entity_info(int entity) const;

protected:
    static void _bind_methods();

private:
    std::string canonical(const String &s) const;
};

#endif // VISUAL_GASIC_ECS_H
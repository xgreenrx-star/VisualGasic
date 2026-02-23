#include "visual_gasic_ecs.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

// ═══════════════════════════════════════════════════════════════════
// VGEcs — Dictionary-based Entity-Component-System for VG scripts
// ═══════════════════════════════════════════════════════════════════

// ── Helper: canonical lower-case std::string from Godot String ────

std::string VisualGasicECS::canonical(const String &s) const {
    return std::string(s.to_lower().utf8().get_data());
}

// ── Constructor / Destructor ──────────────────────────────────────

VisualGasicECS::VisualGasicECS() {}

VisualGasicECS::~VisualGasicECS() {
    clear();
}

// ── Component-type registration ───────────────────────────────────

void VisualGasicECS::register_component_type(const String &type_name) {
    ERR_FAIL_COND_MSG(type_name.is_empty(), "VGEcs.RegisterComponentType: empty type name");
    registered_types.insert(canonical(type_name));
}

bool VisualGasicECS::has_component_type(const String &type_name) const {
    return registered_types.count(canonical(type_name)) > 0;
}

Array VisualGasicECS::get_component_types() const {
    Array arr;
    for (const auto &t : registered_types) {
        arr.push_back(String(t.c_str()));
    }
    return arr;
}

// ── Entity lifecycle ──────────────────────────────────────────────

int VisualGasicECS::create_entity() {
    uint32_t id;
    if (!free_ids.empty()) {
        id = free_ids.back();
        free_ids.pop_back();
    } else {
        id = next_entity_id++;
    }
    alive.insert(id);
    return (int)id;
}

void VisualGasicECS::destroy_entity(int entity) {
    uint32_t eid = (uint32_t)entity;
    ERR_FAIL_COND_MSG(alive.count(eid) == 0,
        "VGEcs.DestroyEntity: entity " + itos(entity) + " does not exist");

    components.erase(eid);
    alive.erase(eid);
    free_ids.push_back(eid);
}

bool VisualGasicECS::is_entity_valid(int entity) const {
    return alive.count((uint32_t)entity) > 0;
}

int VisualGasicECS::get_entity_count() const {
    return (int)alive.size();
}

Array VisualGasicECS::get_all_entities() const {
    Array arr;
    for (uint32_t id : alive) {
        arr.push_back((int)id);
    }
    return arr;
}

// ── Component CRUD ────────────────────────────────────────────────

void VisualGasicECS::add_component(int entity, const String &type_name,
                                   const Dictionary &data) {
    uint32_t eid = (uint32_t)entity;
    ERR_FAIL_COND_MSG(alive.count(eid) == 0,
        "VGEcs.AddComponent: entity " + itos(entity) + " does not exist");

    std::string key = canonical(type_name);

    // Auto-register the type if it hasn't been registered yet
    if (registered_types.count(key) == 0) {
        registered_types.insert(key);
    }

    components[eid][key] = data.duplicate();
}

Dictionary VisualGasicECS::get_component(int entity, const String &type_name) const {
    uint32_t eid = (uint32_t)entity;
    ERR_FAIL_COND_V_MSG(alive.count(eid) == 0, Dictionary(),
        "VGEcs.GetComponent: entity " + itos(entity) + " does not exist");

    std::string key = canonical(type_name);
    auto eit = components.find(eid);
    if (eit == components.end()) return Dictionary();

    auto cit = eit->second.find(key);
    if (cit == eit->second.end()) return Dictionary();

    return cit->second;
}

bool VisualGasicECS::has_component(int entity, const String &type_name) const {
    uint32_t eid = (uint32_t)entity;
    if (alive.count(eid) == 0) return false;

    auto eit = components.find(eid);
    if (eit == components.end()) return false;

    return eit->second.count(canonical(type_name)) > 0;
}

void VisualGasicECS::remove_component(int entity, const String &type_name) {
    uint32_t eid = (uint32_t)entity;
    ERR_FAIL_COND_MSG(alive.count(eid) == 0,
        "VGEcs.RemoveComponent: entity " + itos(entity) + " does not exist");

    auto eit = components.find(eid);
    if (eit != components.end()) {
        eit->second.erase(canonical(type_name));
    }
}

void VisualGasicECS::set_component(int entity, const String &type_name,
                                   const Dictionary &data) {
    // SetComponent = AddComponent (overwrites)
    add_component(entity, type_name, data);
}

// ── Queries ───────────────────────────────────────────────────────

Array VisualGasicECS::query(const Array &required) {
    // Build canonical required list
    std::vector<std::string> req;
    for (int i = 0; i < required.size(); i++) {
        req.push_back(canonical(String(required[i])));
    }

    Array result;
    for (uint32_t eid : alive) {
        auto eit = components.find(eid);
        bool match = true;
        for (const auto &r : req) {
            if (eit == components.end() || eit->second.count(r) == 0) {
                match = false;
                break;
            }
        }
        if (match) result.push_back((int)eid);
    }
    return result;
}

Array VisualGasicECS::query_exclude(const Array &required, const Array &excluded) {
    std::vector<std::string> req, exc;
    for (int i = 0; i < required.size(); i++) {
        req.push_back(canonical(String(required[i])));
    }
    for (int i = 0; i < excluded.size(); i++) {
        exc.push_back(canonical(String(excluded[i])));
    }

    Array result;
    for (uint32_t eid : alive) {
        auto eit = components.find(eid);

        bool has_all = true;
        for (const auto &r : req) {
            if (eit == components.end() || eit->second.count(r) == 0) {
                has_all = false;
                break;
            }
        }
        if (!has_all) continue;

        bool has_exc = false;
        if (eit != components.end()) {
            for (const auto &e : exc) {
                if (eit->second.count(e) > 0) {
                    has_exc = true;
                    break;
                }
            }
        }
        if (!has_exc) result.push_back((int)eid);
    }
    return result;
}

// ── Lifecycle ─────────────────────────────────────────────────────

void VisualGasicECS::update(double delta) {
    total_updates++;
    // ECS update tick — the VG script can iterate query results itself.
    // This method exists so systems written in VG can call ecs.Update(dt)
    // as a convention tick, e.g. to count frames.
}

void VisualGasicECS::clear() {
    components.clear();
    alive.clear();
    free_ids.clear();
    next_entity_id = 1;
    total_updates = 0;
}

// ── Serialization ─────────────────────────────────────────────────

Dictionary VisualGasicECS::serialize() const {
    Dictionary root;
    Array entities_arr;

    for (uint32_t eid : alive) {
        Dictionary ed;
        ed["id"] = (int)eid;

        Dictionary comps;
        auto eit = components.find(eid);
        if (eit != components.end()) {
            for (const auto &pair : eit->second) {
                comps[String(pair.first.c_str())] = pair.second;
            }
        }
        ed["components"] = comps;
        entities_arr.push_back(ed);
    }

    root["entities"] = entities_arr;

    Array types_arr;
    for (const auto &t : registered_types) {
        types_arr.push_back(String(t.c_str()));
    }
    root["component_types"] = types_arr;

    return root;
}

void VisualGasicECS::deserialize(const Dictionary &data) {
    clear();

    // Restore types
    if (data.has("component_types")) {
        Array types_arr = data["component_types"];
        for (int i = 0; i < types_arr.size(); i++) {
            register_component_type(String(types_arr[i]));
        }
    }

    // Restore entities
    if (data.has("entities")) {
        Array entities_arr = data["entities"];
        for (int i = 0; i < entities_arr.size(); i++) {
            Dictionary ed = entities_arr[i];
            uint32_t eid = (uint32_t)(int)ed["id"];

            // Ensure id generator stays ahead
            if (eid >= next_entity_id) next_entity_id = eid + 1;
            alive.insert(eid);

            if (ed.has("components")) {
                Dictionary comps = ed["components"];
                Array keys = comps.keys();
                for (int k = 0; k < keys.size(); k++) {
                    String key = keys[k];
                    Dictionary comp_data = comps[key];
                    components[eid][canonical(key)] = comp_data.duplicate();
                }
            }
        }
    }
}

// ── Debugging ─────────────────────────────────────────────────────

void VisualGasicECS::enable_profiling(bool enabled) {
    profiling_enabled = enabled;
}

Dictionary VisualGasicECS::get_debug_info() const {
    Dictionary d;
    d["entity_count"] = (int)alive.size();
    d["registered_types"] = (int)registered_types.size();
    d["total_updates"] = total_updates;
    d["next_entity_id"] = (int)next_entity_id;
    d["free_id_pool_size"] = (int)free_ids.size();

    // Count total components
    int total_comps = 0;
    for (const auto &pair : components) {
        total_comps += (int)pair.second.size();
    }
    d["total_components"] = total_comps;

    return d;
}

Dictionary VisualGasicECS::get_entity_info(int entity) const {
    Dictionary d;
    uint32_t eid = (uint32_t)entity;
    d["id"] = entity;
    d["valid"] = alive.count(eid) > 0;

    Array comp_types;
    auto eit = components.find(eid);
    if (eit != components.end()) {
        for (const auto &pair : eit->second) {
            comp_types.push_back(String(pair.first.c_str()));
        }
    }
    d["component_types"] = comp_types;
    d["component_count"] = comp_types.size();
    return d;
}

// ── ClassDB Bindings ──────────────────────────────────────────────

void VisualGasicECS::_bind_methods() {
    // Component type registration
    ClassDB::bind_method(D_METHOD("RegisterComponentType", "type_name"),
                         &VisualGasicECS::register_component_type);
    ClassDB::bind_method(D_METHOD("HasComponentType", "type_name"),
                         &VisualGasicECS::has_component_type);
    ClassDB::bind_method(D_METHOD("GetComponentTypes"),
                         &VisualGasicECS::get_component_types);

    // Entity lifecycle
    ClassDB::bind_method(D_METHOD("CreateEntity"), &VisualGasicECS::create_entity);
    ClassDB::bind_method(D_METHOD("DestroyEntity", "entity"),
                         &VisualGasicECS::destroy_entity);
    ClassDB::bind_method(D_METHOD("IsEntityValid", "entity"),
                         &VisualGasicECS::is_entity_valid);
    ClassDB::bind_method(D_METHOD("GetEntityCount"),
                         &VisualGasicECS::get_entity_count);
    ClassDB::bind_method(D_METHOD("GetAllEntities"),
                         &VisualGasicECS::get_all_entities);

    // Component CRUD
    ClassDB::bind_method(D_METHOD("AddComponent", "entity", "type_name", "data"),
                         &VisualGasicECS::add_component);
    ClassDB::bind_method(D_METHOD("GetComponent", "entity", "type_name"),
                         &VisualGasicECS::get_component);
    ClassDB::bind_method(D_METHOD("HasComponent", "entity", "type_name"),
                         &VisualGasicECS::has_component);
    ClassDB::bind_method(D_METHOD("RemoveComponent", "entity", "type_name"),
                         &VisualGasicECS::remove_component);
    ClassDB::bind_method(D_METHOD("SetComponent", "entity", "type_name", "data"),
                         &VisualGasicECS::set_component);

    // Queries
    ClassDB::bind_method(D_METHOD("Query", "required"),
                         &VisualGasicECS::query);
    ClassDB::bind_method(D_METHOD("QueryExclude", "required", "excluded"),
                         &VisualGasicECS::query_exclude);

    // Lifecycle
    ClassDB::bind_method(D_METHOD("Update", "delta"), &VisualGasicECS::update);
    ClassDB::bind_method(D_METHOD("Clear"), &VisualGasicECS::clear);

    // Serialization
    ClassDB::bind_method(D_METHOD("Serialize"), &VisualGasicECS::serialize);
    ClassDB::bind_method(D_METHOD("Deserialize", "data"),
                         &VisualGasicECS::deserialize);

    // Debugging
    ClassDB::bind_method(D_METHOD("EnableProfiling", "enabled"),
                         &VisualGasicECS::enable_profiling);
    ClassDB::bind_method(D_METHOD("GetDebugInfo"),
                         &VisualGasicECS::get_debug_info);
    ClassDB::bind_method(D_METHOD("GetEntityInfo", "entity"),
                         &VisualGasicECS::get_entity_info);
}

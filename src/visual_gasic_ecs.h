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
#include <memory>
#include <typeindex>
#include <functional>

using namespace godot;

/**
 * VisualGasic Entity Component System
 * 
 * High-performance ECS implementation for game development:
 * - Memory-efficient component storage
 * - Fast entity queries and iteration
 * - System scheduling and execution
 * - Integration with Godot scene system
 * - Reactive component updates
 */
class VisualGasicECS : public RefCounted {
    GDCLASS(VisualGasicECS, RefCounted)

public:
    // Core ECS Types
    using EntityId = uint32_t;
    using ComponentTypeId = uint32_t;
    using SystemId = uint32_t;
    
    static constexpr EntityId INVALID_ENTITY = 0;
    static constexpr ComponentTypeId INVALID_COMPONENT_TYPE = 0;
    static constexpr SystemId INVALID_SYSTEM = 0;

    // Component Interface
    class IComponent {
    public:
        virtual ~IComponent() = default;
        virtual ComponentTypeId get_type_id() const = 0;
        virtual Dictionary to_dictionary() const = 0;
        virtual void from_dictionary(const Dictionary& data) = 0;
        virtual Ref<IComponent> clone() const = 0;
    };
    
    // Component Storage
    class ComponentStorage {
    public:
        virtual ~ComponentStorage() = default;
        virtual void remove_component(EntityId entity) = 0;
        virtual bool has_component(EntityId entity) const = 0;
        virtual void clear() = 0;
        virtual size_t size() const = 0;
    };
    
    template<typename T>
    class TypedComponentStorage : public ComponentStorage {
    private:
        std::unordered_map<EntityId, std::unique_ptr<T>> components;
        
    public:
        T* add_component(EntityId entity, std::unique_ptr<T> component) {
            T* raw_ptr = component.get();
            components[entity] = std::move(component);
            return raw_ptr;
        }
        
        T* get_component(EntityId entity) {
            auto it = components.find(entity);
            return it != components.end() ? it->second.get() : nullptr;
        }
        
        void remove_component(EntityId entity) override {
            components.erase(entity);
        }
        
        bool has_component(EntityId entity) const override {
            return components.find(entity) != components.end();
        }
        
        void clear() override {
            components.clear();
        }
        
        size_t size() const override {
            return components.size();
        }
        
        // Iteration support
        auto begin() { return components.begin(); }
        auto end() { return components.end(); }
        auto begin() const { return components.begin(); }
        auto end() const { return components.end(); }
    };
    
    // System Interface
    class ISystem {
    public:
        virtual ~ISystem() = default;
        virtual void initialize(VisualGasicECS* ecs) = 0;
        virtual void update(double delta_time) = 0;
        virtual void shutdown() = 0;
        virtual String get_name() const = 0;
        virtual int get_priority() const { return 0; }
        virtual bool is_enabled() const { return true; }
        virtual Array get_required_components() const = 0;
    };
    
    // Query System
    class Query {
    private:
        VisualGasicECS* ecs;
        std::vector<ComponentTypeId> required_types;
        std::vector<ComponentTypeId> excluded_types;
        mutable std::vector<EntityId> cached_entities;
        mutable bool cache_valid = false;
        
    public:
        Query(VisualGasicECS* ecs_instance) : ecs(ecs_instance) {}
        
        Query& with_component(ComponentTypeId type_id) {
            required_types.push_back(type_id);
            cache_valid = false;
            return *this;
        }
        
        Query& without_component(ComponentTypeId type_id) {
            excluded_types.push_back(type_id);
            cache_valid = false;
            return *this;
        }
        
        const std::vector<EntityId>& get_entities() const;
        size_t count() const { return get_entities().size(); }
        void invalidate_cache() { cache_valid = false; }
    };
    
    // Archetype System for Performance
    struct Archetype {
        std::vector<ComponentTypeId> component_types;
        std::unordered_set<EntityId> entities;
        
        bool matches_query(const Query& query) const;
        size_t get_hash() const;
    };

private:
    // ECS State
    std::unordered_map<EntityId, std::unordered_set<ComponentTypeId>> entity_components;
    std::unordered_map<ComponentTypeId, std::unique_ptr<ComponentStorage>> component_storages;
    std::unordered_map<SystemId, std::unique_ptr<ISystem>> systems;
    std::vector<SystemId> system_execution_order;
    
    // Entity Management
    EntityId next_entity_id = 1;
    std::vector<EntityId> free_entity_ids;
    
    // Component Type Management
    ComponentTypeId next_component_type_id = 1;
    std::unordered_map<std::type_index, ComponentTypeId> type_to_id;
    std::unordered_map<ComponentTypeId, std::type_index> id_to_type;
    
    // System Management
    SystemId next_system_id = 1;
    bool systems_initialized = false;
    
    // Query Cache
    mutable std::vector<std::unique_ptr<Query>> active_queries;
    
    // Archetype System
    std::vector<std::unique_ptr<Archetype>> archetypes;
    std::unordered_map<EntityId, size_t> entity_archetype_map;
    
    // Performance Tracking
    Dictionary performance_stats;
    bool profiling_enabled = false;

public:
    VisualGasicECS();
    ~VisualGasicECS();
    
    // Entity Management
    EntityId create_entity();
    void destroy_entity(EntityId entity);
    bool is_entity_valid(EntityId entity) const;
    Array get_all_entities() const;
    Dictionary get_entity_info(EntityId entity) const;
    
    // Component Management
    template<typename T>
    ComponentTypeId register_component_type() {
        std::type_index type_index(typeid(T));
        auto it = type_to_id.find(type_index);
        if (it != type_to_id.end()) {
            return it->second;
        }
        
        ComponentTypeId type_id = next_component_type_id++;
        type_to_id[type_index] = type_id;
        id_to_type[type_id] = type_index;
        
        component_storages[type_id] = std::make_unique<TypedComponentStorage<T>>();
        
        return type_id;
    }
    
    template<typename T>
    T* add_component(EntityId entity, const T& component) {
        ComponentTypeId type_id = register_component_type<T>();
        
        auto storage = static_cast<TypedComponentStorage<T>*>(component_storages[type_id].get());
        T* comp = storage->add_component(entity, std::make_unique<T>(component));
        
        entity_components[entity].insert(type_id);
        update_entity_archetype(entity);
        invalidate_queries();
        
        return comp;
    }
    
    template<typename T>
    T* get_component(EntityId entity) {
        ComponentTypeId type_id = get_component_type_id<T>();
        if (type_id == INVALID_COMPONENT_TYPE) {
            return nullptr;
        }
        
        auto storage = static_cast<TypedComponentStorage<T>*>(component_storages[type_id].get());
        return storage->get_component(entity);
    }
    
    template<typename T>
    bool has_component(EntityId entity) const {
        ComponentTypeId type_id = get_component_type_id<T>();
        if (type_id == INVALID_COMPONENT_TYPE) {
            return false;
        }
        
        auto it = entity_components.find(entity);
        if (it == entity_components.end()) {
            return false;
        }
        
        return it->second.find(type_id) != it->second.end();
    }
    
    template<typename T>
    void remove_component(EntityId entity) {
        ComponentTypeId type_id = get_component_type_id<T>();
        if (type_id == INVALID_COMPONENT_TYPE) {
            return;
        }
        
        auto storage = component_storages[type_id].get();
        storage->remove_component(entity);
        
        entity_components[entity].erase(type_id);
        update_entity_archetype(entity);
        invalidate_queries();
    }
    
    // System Management
    template<typename T>
    SystemId add_system(std::unique_ptr<T> system) {
        SystemId system_id = next_system_id++;
        systems[system_id] = std::move(system);
        
        resort_systems();
        
        if (systems_initialized) {
            systems[system_id]->initialize(this);
        }
        
        return system_id;
    }
    
    void remove_system(SystemId system_id);
    void enable_system(SystemId system_id, bool enabled);
    Array get_systems() const;
    Dictionary get_system_info(SystemId system_id) const;
    
    // Query System
    std::unique_ptr<Query> create_query();
    Array query_entities(const Array& required_components, const Array& excluded_components = Array()) const;
    
    // Lifecycle
    void initialize();
    void update(double delta_time);
    void shutdown();
    
    // Serialization
    Dictionary serialize() const;
    void deserialize(const Dictionary& data);
    Dictionary serialize_entity(EntityId entity) const;
    EntityId deserialize_entity(const Dictionary& data);
    
    // Performance and Debugging
    void enable_profiling(bool enabled);
    Dictionary get_performance_stats() const;
    void clear_performance_stats();
    Dictionary get_debug_info() const;
    
    // Integration with Godot
    void sync_with_scene_tree(Node* root);
    EntityId create_entity_from_node(Node* node);
    void update_node_from_entity(EntityId entity, Node* node);

protected:
    static void _bind_methods();

private:
    // Internal Helper Methods
    template<typename T>
    ComponentTypeId get_component_type_id() const {
        std::type_index type_index(typeid(T));
        auto it = type_to_id.find(type_index);
        return it != type_to_id.end() ? it->second : INVALID_COMPONENT_TYPE;
    }
    
    void update_entity_archetype(EntityId entity);
    void invalidate_queries();
    void resort_systems();
    bool entity_matches_archetype(EntityId entity, const Archetype& archetype) const;
    
    // Performance Tracking
    void start_profiling_section(const String& section);
    void end_profiling_section(const String& section);
};

// Built-in Components
class TransformComponent : public VisualGasicECS::IComponent {
public:
    Vector3 position = Vector3::ZERO;
    Vector3 rotation = Vector3::ZERO;
    Vector3 scale = Vector3::ONE;
    
    ComponentTypeId get_type_id() const override;
    Dictionary to_dictionary() const override;
    void from_dictionary(const Dictionary& data) override;
    Ref<IComponent> clone() const override;
};

class VelocityComponent : public VisualGasicECS::IComponent {
public:
    Vector3 linear_velocity = Vector3::ZERO;
    Vector3 angular_velocity = Vector3::ZERO;
    
    ComponentTypeId get_type_id() const override;
    Dictionary to_dictionary() const override;
    void from_dictionary(const Dictionary& data) override;
    Ref<IComponent> clone() const override;
};

class RenderComponent : public VisualGasicECS::IComponent {
public:
    String mesh_path;
    String material_path;
    bool visible = true;
    int render_layer = 1;
    
    ComponentTypeId get_type_id() const override;
    Dictionary to_dictionary() const override;
    void from_dictionary(const Dictionary& data) override;
    Ref<IComponent> clone() const override;
};

// Built-in Systems
class MovementSystem : public VisualGasicECS::ISystem {
public:
    void initialize(VisualGasicECS* ecs) override;
    void update(double delta_time) override;
    void shutdown() override;
    String get_name() const override { return "MovementSystem"; }
    int get_priority() const override { return 100; }
    Array get_required_components() const override;

private:
    VisualGasicECS* ecs_instance = nullptr;
};

class RenderSystem : public VisualGasicECS::ISystem {
public:
    void initialize(VisualGasicECS* ecs) override;
    void update(double delta_time) override;
    void shutdown() override;
    String get_name() const override { return "RenderSystem"; }
    int get_priority() const override { return 200; }
    Array get_required_components() const override;

private:
    VisualGasicECS* ecs_instance = nullptr;
};

#endif // VISUAL_GASIC_ECS_H
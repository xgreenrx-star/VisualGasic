#include <godot_cpp/classes/file_dialog.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <cstdlib>
#ifdef _MSC_VER
#include <intrin.h>
#endif
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/area2d.hpp>
#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>
#include <godot_cpp/classes/circle_shape2d.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/menu_button.hpp>
#include <godot_cpp/classes/popup_menu.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/base_button.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/variant/variant_internal.hpp>

#include "visual_gasic_instance.h"
#include "visual_gasic_language.h"
#include "visual_gasic_parser.h"
#include "visual_gasic_builtins.h"
#include "visual_gasic_debugger.h"
#include "visual_gasic_profiler.h"
#include "visual_gasic_timer.h"
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/config_file.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/system_font.hpp>
#include <godot_cpp/classes/font_variation.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/style_box_empty.hpp>
#include <godot_cpp/classes/gpu_particles2d.hpp>
#include <godot_cpp/classes/gpu_particles3d.hpp>
#include <godot_cpp/classes/particle_process_material.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/sprite3d.hpp>
#include <godot_cpp/classes/texture3d.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/check_box.hpp>
#include <godot_cpp/classes/check_button.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <godot_cpp/classes/spin_box.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/menu_bar.hpp>
#include <godot_cpp/classes/color_rect.hpp>
#include <godot_cpp/classes/panel.hpp>
#include <godot_cpp/classes/rich_text_label.hpp>
#include "gasic_ai_controller.h"
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/kinematic_collision2d.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/sphere_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/property_tweener.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/h_slider.hpp>
#include <godot_cpp/classes/v_slider.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include "visual_gasic_comm.h"
#include <limits>
#include <utility>
#include <mutex>
#include <set>

// JIT compilation support
#ifdef __linux__
#include <sys/mman.h>
#include <unistd.h>
#endif
// POSIX unlink for STMT_KILL symlink fallback
#if defined(__APPLE__) || defined(__unix__)
#include <unistd.h>
#endif
#if defined(_WIN32)
#include <windows.h>
#endif

// === IMMEDIATE WINDOW SUPPORT ===
// Global registry of active VisualGasic instances for debugging/immediate window
// Must be outside anonymous namespace for external linkage
static std::mutex vg_debug_instance_registry_mutex;
static std::set<VisualGasicInstance*> vg_debug_active_instances;

// Thread-local import stack for circular import detection (v4.3.0)
thread_local Vector<String> VisualGasicInstance::import_stack;

namespace VisualGasicDebug {

void register_instance(VisualGasicInstance* instance) {
    std::lock_guard<std::mutex> lock(vg_debug_instance_registry_mutex);
    vg_debug_active_instances.insert(instance);
}

void unregister_instance(VisualGasicInstance* instance) {
    std::lock_guard<std::mutex> lock(vg_debug_instance_registry_mutex);
    vg_debug_active_instances.erase(instance);
}

Array get_all_instances() {
    std::lock_guard<std::mutex> lock(vg_debug_instance_registry_mutex);
    Array result;
    for (auto* inst : vg_debug_active_instances) {
        if (inst && inst->get_owner()) {
            Dictionary info;
            info["instance_ptr"] = (int64_t)inst;
            Object* owner = inst->get_owner();
            if (owner) {
                info["owner_id"] = owner->get_instance_id();
                Node* node = Object::cast_to<Node>(owner);
                if (node) {
                    info["node_name"] = node->get_name();
                    info["node_path"] = node->get_path();
                }
            }
            Ref<Script> scr = inst->get_script();
            if (scr.is_valid()) {
                info["script_path"] = scr->get_path();
            }
            result.push_back(info);
        }
    }
    return result;
}

VisualGasicInstance* get_instance_by_index(int index) {
    std::lock_guard<std::mutex> lock(vg_debug_instance_registry_mutex);
    if (index < 0) {
        return nullptr;
    }
    // Must apply the same owner-check filter as get_all_instances(),
    // because the editor receives dense 0-based IDs from the filtered list.
    int valid_count = 0;
    for (auto* inst : vg_debug_active_instances) {
        if (inst && inst->get_owner()) {
            if (valid_count == index) {
                return inst;
            }
            valid_count++;
        }
    }
    return nullptr;
}

String get_debug_registry_info() {
    std::lock_guard<std::mutex> lock(vg_debug_instance_registry_mutex);
    int total = (int)vg_debug_active_instances.size();
    int valid = 0;
    for (auto* inst : vg_debug_active_instances) {
        if (inst && inst->get_owner()) valid++;
    }
    return String("set_size=") + String::num_int64(total) + " valid=" + String::num_int64(valid);
}

Dictionary get_instance_variables(int index) {
    VisualGasicInstance* inst = get_instance_by_index(index);
    if (!inst) {
        return Dictionary();
    }
    
    // Get all variables from the instance (globals + bytecode locals)
    Dictionary raw_vars = inst->get_debug_globals();
    
    // Merge in bytecode locals (if the VM is paused mid-execution).
    // Locals shadow globals of the same name, which is correct.
    Dictionary bc_locals = inst->get_debug_locals();
    Array local_keys = bc_locals.keys();
    for (int i = 0; i < local_keys.size(); i++) {
        raw_vars[local_keys[i]] = bc_locals[local_keys[i]];
    }
    
    // Filter and convert to serializable types for debugger protocol
    Dictionary result;
    Array keys = raw_vars.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        
        // Skip builtin constants (vbCrLf, vbGreen, vbKeyEscape, etc.) and Err object
        if (key == "Err" || inst->is_builtin_constant(key)) {
            continue;
        }
        
        Variant val = raw_vars[key];
        Variant::Type t = val.get_type();
        
        // Convert non-serializable types to string representation
        if (t == Variant::OBJECT) {
            Object* obj = val;
            if (obj) {
                // Convert to descriptive string
                Node* node = Object::cast_to<Node>(obj);
                if (node) {
                    result[key] = String("<Node: ") + node->get_name() + String(">");
                } else {
                    result[key] = String("<") + obj->get_class() + String(">");
                }
            } else {
                result[key] = "Nothing";
            }
        } else if (t == Variant::CALLABLE || t == Variant::SIGNAL || t == Variant::RID) {
            // These types cannot be serialized - skip or convert to string
            result[key] = String("<") + Variant::get_type_name(t) + String(">");
        } else {
            // Primitive types, Vector2, Vector3, Color, Array, Dictionary - these are safe
            result[key] = val;
        }
    }
    
    return result;
}

Array get_whenever_sections(int index) {
    VisualGasicInstance* inst = get_instance_by_index(index);
    if (!inst) {
        return Array();
    }
    
    // Use the public accessor method
    return inst->get_debug_whenever_sections();
}

void set_whenever_active(int index, const String& section_name, bool active) {
    VisualGasicInstance* inst = get_instance_by_index(index);
    if (!inst) {
        return;
    }
    
    // Use the public setter method
    inst->set_whenever_section_active(section_name, active);
}

} // namespace VisualGasicDebug
// === END IMMEDIATE WINDOW SUPPORT ===

namespace {

// Portable count-trailing-zeros for 64-bit values
static inline int vg_ctz64(uint64_t v) {
#ifdef _MSC_VER
    unsigned long idx;
    _BitScanForward64(&idx, v);
    return static_cast<int>(idx);
#else
    return __builtin_ctzll(v);
#endif
}

// Variant pool for reducing allocation overhead
struct VariantPool {
    static constexpr size_t POOL_SIZE = 64;
    Variant pool[POOL_SIZE];
    uint64_t free_mask = ~0ULL; // All slots initially free
    uint64_t alloc_count = 0;
    uint64_t reuse_count = 0;
    
    Variant* acquire() {
        if (free_mask == 0) {
            alloc_count++;
            return nullptr; // Pool exhausted, caller must allocate
        }
        // Find first free slot (rightmost 1-bit)
        int slot = vg_ctz64(free_mask);
        free_mask &= ~(1ULL << slot);
        reuse_count++;
        return &pool[slot];
    }
    
    void release(Variant* v) {
        if (v < pool || v >= pool + POOL_SIZE) {
            return; // Not from pool
        }
        int slot = v - pool;
        free_mask |= (1ULL << slot);
        // Clear the variant to NIL to release any references
        *v = Variant();
    }
    
    void reset() {
        for (size_t i = 0; i < POOL_SIZE; i++) {
            pool[i] = Variant();
        }
        free_mask = ~0ULL;
    }
};

thread_local VariantPool vg_variant_pool;

class VariantPoolScope {
    Variant* ptr;
public:
    explicit VariantPoolScope(Variant&& value) {
        ptr = vg_variant_pool.acquire();
        if (ptr) {
            *ptr = std::move(value);
        } else {
            ptr = nullptr;
        }
    }
    
    ~VariantPoolScope() {
        if (ptr) {
            vg_variant_pool.release(ptr);
        }
    }
    
    bool valid() const { return ptr != nullptr; }
    Variant& get() { return *ptr; }
    const Variant& get() const { return *ptr; }
};

// Script instance cache for reducing construction/destruction overhead
struct ScriptInstanceCache {
    static constexpr size_t MAX_CACHED = 32;
    
    struct Entry {
        Object* instance = nullptr;
        String class_name;
        uint64_t last_use_tick = 0;
    };
    
    Entry cache[MAX_CACHED];
    size_t size = 0;
    uint64_t current_tick = 0;
    uint64_t hits = 0;
    uint64_t misses = 0;
    
    Object* acquire(const String& p_class_name) {
        current_tick++;
        
        // Search for matching cached instance
        for (size_t i = 0; i < size; i++) {
            if (cache[i].class_name == p_class_name && cache[i].instance) {
                Object* obj = cache[i].instance;
                cache[i].last_use_tick = current_tick;
                hits++;
                return obj;
            }
        }
        
        misses++;
        return nullptr; // Not found, caller must create
    }
    
    void release(Object* p_instance, const String& p_class_name) {
        if (!p_instance) return;
        
        current_tick++;
        
        // Try to add to cache
        if (size < MAX_CACHED) {
            cache[size].instance = p_instance;
            cache[size].class_name = p_class_name;
            cache[size].last_use_tick = current_tick;
            size++;
            return;
        }
        
        // Cache full, evict LRU
        size_t lru_idx = 0;
        uint64_t min_tick = cache[0].last_use_tick;
        for (size_t i = 1; i < MAX_CACHED; i++) {
            if (cache[i].last_use_tick < min_tick) {
                min_tick = cache[i].last_use_tick;
                lru_idx = i;
            }
        }
        
        // Free evicted instance
        if (cache[lru_idx].instance) {
            memdelete(cache[lru_idx].instance);
        }
        
        cache[lru_idx].instance = p_instance;
        cache[lru_idx].class_name = p_class_name;
        cache[lru_idx].last_use_tick = current_tick;
    }
    
    void clear() {
        for (size_t i = 0; i < size; i++) {
            if (cache[i].instance) {
                memdelete(cache[i].instance);
                cache[i].instance = nullptr;
            }
        }
        size = 0;
    }
    
    ~ScriptInstanceCache() {
        clear();
    }
};

thread_local ScriptInstanceCache vg_script_instance_cache;

struct VgDictKeyedOps {
    GDExtensionPtrKeyedGetter getter = nullptr;
    GDExtensionPtrKeyedSetter setter = nullptr;
    GDExtensionPtrKeyedChecker checker = nullptr;
};

// No cached operations needed - direct pointer access is fastest

Dictionary &vg_pooled_dict_wrapper() {
    thread_local Dictionary dict_wrapper;
    return dict_wrapper;
}

const Variant &vg_default_nil_variant() {
    static Variant nil_variant;
    return nil_variant;
}

#include "visual_gasic_instance_internal.h"

// ======= JIT Compilation Framework =======

struct JitCompiledLoop {
    typedef int64_t (*JitFunction)(int64_t start, int64_t end, int64_t step);
    
    void* code_buffer = nullptr;
    size_t code_size = 0;
    JitFunction function = nullptr;
    uint64_t hit_count = 0;
    uint64_t exec_count = 0;
    
    ~JitCompiledLoop() {
        if (code_buffer) {
            #ifdef __linux__
            munmap(code_buffer, code_size);
            #endif
        }
    }
};

struct JitHotLoop {
    int loop_start_ip = -1;
    int loop_end_ip = -1;
    uint64_t execution_count = 0;
    uint64_t threshold = 100; // JIT after 100 iterations
    JitCompiledLoop* compiled = nullptr;
    
    bool should_compile() const {
        return !compiled && execution_count >= threshold;
    }
};

struct JitCompiler {
    static constexpr size_t MAX_HOT_LOOPS = 16;
    JitHotLoop hot_loops[MAX_HOT_LOOPS];
    size_t hot_loop_count = 0;
    bool enabled = false;
    
    JitCompiler() {
        const char* env = std::getenv("VG_JIT");
        enabled = env && env[0] != '\0' && env[0] != '0';
    }
    
    JitHotLoop* find_or_create_loop(int start_ip, int end_ip) {
        if (!enabled) return nullptr;
        
        // Find existing
        for (size_t i = 0; i < hot_loop_count; i++) {
            if (hot_loops[i].loop_start_ip == start_ip && hot_loops[i].loop_end_ip == end_ip) {
                return &hot_loops[i];
            }
        }
        
        // Create new
        if (hot_loop_count < MAX_HOT_LOOPS) {
            JitHotLoop& loop = hot_loops[hot_loop_count++];
            loop.loop_start_ip = start_ip;
            loop.loop_end_ip = end_ip;
            loop.execution_count = 0;
            loop.compiled = nullptr;
            return &loop;
        }
        
        return nullptr;
    }
    
    bool compile_simple_i64_loop(JitHotLoop* loop, const uint8_t* bytecode, int bytecode_size) {
        if (!enabled || !loop || loop->compiled) return false;
        
        #ifdef __linux__
        // Allocate executable memory for JIT code
        size_t code_size = 4096; // 1 page
        void* code_buffer = mmap(nullptr, code_size, PROT_READ | PROT_WRITE, 
                                  MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (code_buffer == MAP_FAILED) {
            return false;
        }
        
        // Generate simple x86-64 code for: for(i=start; i<=end; i+=step) sum+=i
        // This is a proof-of-concept - real JIT would analyze the bytecode
        uint8_t* code = (uint8_t*)code_buffer;
        int pos = 0;
        
        // Function prologue: push rbp; mov rbp, rsp
        code[pos++] = 0x55;
        code[pos++] = 0x48; code[pos++] = 0x89; code[pos++] = 0xe5;
        
        // Parameters: rdi=start, rsi=end, rdx=step
        // rax will hold sum
        code[pos++] = 0x48; code[pos++] = 0x31; code[pos++] = 0xc0; // xor rax, rax (sum=0)
        code[pos++] = 0x48; code[pos++] = 0x89; code[pos++] = 0xf9; // mov rcx, rdi (i=start)
        
        // Loop: .loop_start
        int loop_start = pos;
        
        // cmp rcx, rsi (i vs end)
        code[pos++] = 0x48; code[pos++] = 0x39; code[pos++] = 0xf1;
        
        // jg .loop_end (if i > end, exit)
        code[pos++] = 0x7f; code[pos++] = 0x08; // Will fixup offset
        int jmp_fixup = pos - 1;
        
        // add rax, rcx (sum += i)
        code[pos++] = 0x48; code[pos++] = 0x01; code[pos++] = 0xc8;
        
        // add rcx, rdx (i += step)
        code[pos++] = 0x48; code[pos++] = 0x01; code[pos++] = 0xd1;
        
        // jmp .loop_start
        int jmp_offset = loop_start - (pos + 2);
        code[pos++] = 0xeb; code[pos++] = (uint8_t)jmp_offset;
        
        // .loop_end:
        int loop_end = pos;
        code[jmp_fixup] = (uint8_t)(loop_end - (jmp_fixup + 1));
        
        // Function epilogue: pop rbp; ret
        code[pos++] = 0x5d;
        code[pos++] = 0xc3;
        
        // Make memory executable
        if (mprotect(code_buffer, code_size, PROT_READ | PROT_EXEC) != 0) {
            munmap(code_buffer, code_size);
            return false;
        }
        
        // Create compiled loop object
        JitCompiledLoop* compiled = new JitCompiledLoop();
        compiled->code_buffer = code_buffer;
        compiled->code_size = code_size;
        compiled->function = (JitCompiledLoop::JitFunction)code_buffer;
        
        loop->compiled = compiled;
        
        UtilityFunctions::print("[VG_JIT] Compiled loop at IP ", loop->loop_start_ip, 
                                 " to native x86-64 (", pos, " bytes)");
        return true;
        #else
        return false; // JIT only on Linux for now
        #endif
    }
    
    ~JitCompiler() {
        for (size_t i = 0; i < hot_loop_count; i++) {
            if (hot_loops[i].compiled) {
                delete hot_loops[i].compiled;
            }
        }
    }
};

thread_local JitCompiler vg_jit_compiler;

}




// Helper to access protected _owner of Object
class AccessObject : public Object {
public:
    static GDExtensionObjectPtr get_internal_ptr(Object *obj) {
        return obj ? ((AccessObject*)obj)->_owner : nullptr;
    }
};

Variant *VisualGasicInstance::get_cached_fast_dict_key(const Variant &key_source) {
    if (key_source.get_type() != Variant::STRING) {
        fast_dict_last_key_name = StringName();
        fast_dict_last_key_hits = 0;
        return nullptr;
    }

    String key_string = key_source;
    StringName key_name = key_string;
    FastKeyCacheEntry *entry = fast_dict_key_cache.getptr(key_name);
    if (entry) {
        entry->hit_count++;
        entry->last_used = ++fast_dict_key_cache_generation;
        fast_dict_last_key_name = key_name;
        fast_dict_last_key_hits = entry->hit_count;
        return &entry->variant;
    }

    if (key_name == fast_dict_last_key_name) {
        fast_dict_last_key_hits++;
    } else {
        fast_dict_last_key_name = key_name;
        fast_dict_last_key_hits = 1;
    }

    if (fast_dict_last_key_hits >= VisualGasicInstance::FAST_DICT_CACHE_TRIGGER) {
        Variant *cached = insert_fast_dict_key_entry(key_name, key_source, fast_dict_last_key_hits);
        return cached;
    }

    return nullptr;
}

Variant *VisualGasicInstance::insert_fast_dict_key_entry(const StringName &key_name, const Variant &key_source, uint32_t initial_hits) {
    prune_fast_dict_cache_if_needed();
    FastKeyCacheEntry new_entry;
    new_entry.variant = key_source;
    new_entry.hit_count = initial_hits;
    new_entry.last_used = ++fast_dict_key_cache_generation;
    HashMap<StringName, FastKeyCacheEntry>::Iterator inserted = fast_dict_key_cache.insert(key_name, new_entry);
    if (inserted == fast_dict_key_cache.end()) {
        return nullptr;
    }
    return &inserted->value.variant;
}

void VisualGasicInstance::prune_fast_dict_cache_if_needed() {
    if (fast_dict_key_cache.size() < VisualGasicInstance::FAST_DICT_CACHE_MAX_ENTRIES) {
        return;
    }

    uint32_t oldest_generation = std::numeric_limits<uint32_t>::max();
    StringName victim_key;
    for (KeyValue<StringName, FastKeyCacheEntry> &kv : fast_dict_key_cache) {
        if (kv.value.last_used < oldest_generation) {
            oldest_generation = kv.value.last_used;
            victim_key = kv.key;
        }
    }

    if (oldest_generation == std::numeric_limits<uint32_t>::max()) {
        return;
    }

    fast_dict_key_cache.erase(victim_key);
    if (victim_key == fast_dict_last_key_name) {
        fast_dict_last_key_hits = 0;
        fast_dict_last_key_name = StringName();
    }
}

Dictionary &VisualGasicInstance::get_global_scope() {
    // Godot's Dictionary is ref-counted internally; a single static instance
    // here is transparently shared by every VisualGasicInstance in the
    // process for the lifetime of the engine (v4.4.0 "Global Const"/"Global Dim").
    static Dictionary global_scope;
    return global_scope;
}

VisualGasicInstance::VisualGasicInstance(Ref<VisualGasicScript> p_script, Object *p_owner) {
    script = p_script;
    owner = p_owner;
    cached_ast_root = nullptr;
    error_state.mode = ErrorState::NONE;
    error_state.has_error = false;
    current_sub = nullptr;
    jump_target = -1;
    data_pointer = 0;
    
    // Register with debug system for Immediate Window access (in-process)
    VisualGasicDebug::register_instance(this);
    
    // Note: Remote debug handler registration happens in notification(NOTIFICATION_READY)
    // because the node is not in the scene tree during construction
    
    option_compare_text = false;
    if (script.is_valid() && script->ast_root) {
        option_compare_text = script->ast_root->option_compare_text;
    }

    // Initialize Err Object
    Dictionary err_obj;
    err_obj["Number"] = 0;
    err_obj["Description"] = "";
    err_obj["Source"] = "";
    variables["Err"] = err_obj;

    // --- Global Constants (VB6 Style) ---
    // Stored in builtin_constants (separate from user variables) so the
    // debugger Variables panel only shows user-defined variables.
    // Variable reads fall back to builtin_constants automatically.
    // Colors
    builtin_constants["vbRed"] = Color(1, 0, 0);
    builtin_constants["vbGreen"] = Color(0, 1, 0);
    builtin_constants["vbBlue"] = Color(0, 0, 1);
    builtin_constants["vbBlack"] = Color(0, 0, 0);
    builtin_constants["vbWhite"] = Color(1, 1, 1);
    builtin_constants["vbYellow"] = Color(1, 1, 0);
    builtin_constants["vbCyan"] = Color(0, 1, 1);
    builtin_constants["vbMagenta"] = Color(1, 0, 1);
    
    // Keys (Mapped to Godot Key Enum values roughly)
    builtin_constants["vbKeyReturn"] = (int)Key::KEY_ENTER;
    builtin_constants["vbKeyEnter"] = (int)Key::KEY_ENTER;
    builtin_constants["vbKeySpace"] = (int)Key::KEY_SPACE;
    builtin_constants["vbKeyEscape"] = (int)Key::KEY_ESCAPE;
    builtin_constants["vbKeyUp"] = (int)Key::KEY_UP;
    builtin_constants["vbKeyDown"] = (int)Key::KEY_DOWN;
    builtin_constants["vbKeyLeft"] = (int)Key::KEY_LEFT;
    builtin_constants["vbKeyRight"] = (int)Key::KEY_RIGHT;
    builtin_constants["vbKeyBack"] = (int)Key::KEY_BACKSPACE;
    builtin_constants["vbKeyTab"] = (int)Key::KEY_TAB;
    builtin_constants["vbKeyDelete"] = (int)Key::KEY_DELETE;
    builtin_constants["vbKeyInsert"] = (int)Key::KEY_INSERT;
    builtin_constants["vbKeyHome"] = (int)Key::KEY_HOME;
    builtin_constants["vbKeyEnd"] = (int)Key::KEY_END;
    builtin_constants["vbKeyPageUp"] = (int)Key::KEY_PAGEUP;
    builtin_constants["vbKeyPageDown"] = (int)Key::KEY_PAGEDOWN;
    builtin_constants["vbKeyShift"] = (int)Key::KEY_SHIFT;
    builtin_constants["vbKeyControl"] = (int)Key::KEY_CTRL;
    builtin_constants["vbKeyMenu"] = (int)Key::KEY_ALT;
    builtin_constants["vbKeyF1"] = (int)Key::KEY_F1;
    builtin_constants["vbKeyF2"] = (int)Key::KEY_F2;
    builtin_constants["vbKeyF3"] = (int)Key::KEY_F3;
    builtin_constants["vbKeyF4"] = (int)Key::KEY_F4;
    builtin_constants["vbKeyF5"] = (int)Key::KEY_F5;
    builtin_constants["vbKeyF6"] = (int)Key::KEY_F6;
    builtin_constants["vbKeyF7"] = (int)Key::KEY_F7;
    builtin_constants["vbKeyF8"] = (int)Key::KEY_F8;
    builtin_constants["vbKeyF9"] = (int)Key::KEY_F9;
    builtin_constants["vbKeyF10"] = (int)Key::KEY_F10;
    builtin_constants["vbKeyF11"] = (int)Key::KEY_F11;
    builtin_constants["vbKeyF12"] = (int)Key::KEY_F12;
    // VB6 letter key constants (A-Z)
    builtin_constants["vbKeyA"] = (int)Key::KEY_A;
    builtin_constants["vbKeyB"] = (int)Key::KEY_B;
    builtin_constants["vbKeyC"] = (int)Key::KEY_C;
    builtin_constants["vbKeyD"] = (int)Key::KEY_D;
    builtin_constants["vbKeyE"] = (int)Key::KEY_E;
    builtin_constants["vbKeyF"] = (int)Key::KEY_F;
    builtin_constants["vbKeyG"] = (int)Key::KEY_G;
    builtin_constants["vbKeyH"] = (int)Key::KEY_H;
    builtin_constants["vbKeyI"] = (int)Key::KEY_I;
    builtin_constants["vbKeyJ"] = (int)Key::KEY_J;
    builtin_constants["vbKeyK"] = (int)Key::KEY_K;
    builtin_constants["vbKeyL"] = (int)Key::KEY_L;
    builtin_constants["vbKeyM"] = (int)Key::KEY_M;
    builtin_constants["vbKeyN"] = (int)Key::KEY_N;
    builtin_constants["vbKeyO"] = (int)Key::KEY_O;
    builtin_constants["vbKeyP"] = (int)Key::KEY_P;
    builtin_constants["vbKeyQ"] = (int)Key::KEY_Q;
    builtin_constants["vbKeyR"] = (int)Key::KEY_R;
    builtin_constants["vbKeyS"] = (int)Key::KEY_S;
    builtin_constants["vbKeyT"] = (int)Key::KEY_T;
    builtin_constants["vbKeyU"] = (int)Key::KEY_U;
    builtin_constants["vbKeyV"] = (int)Key::KEY_V;
    builtin_constants["vbKeyW"] = (int)Key::KEY_W;
    builtin_constants["vbKeyX"] = (int)Key::KEY_X;
    builtin_constants["vbKeyY"] = (int)Key::KEY_Y;
    builtin_constants["vbKeyZ"] = (int)Key::KEY_Z;
    // VB6 digit key constants (0-9)
    builtin_constants["vbKey0"] = (int)Key::KEY_0;
    builtin_constants["vbKey1"] = (int)Key::KEY_1;
    builtin_constants["vbKey2"] = (int)Key::KEY_2;
    builtin_constants["vbKey3"] = (int)Key::KEY_3;
    builtin_constants["vbKey4"] = (int)Key::KEY_4;
    builtin_constants["vbKey5"] = (int)Key::KEY_5;
    builtin_constants["vbKey6"] = (int)Key::KEY_6;
    builtin_constants["vbKey7"] = (int)Key::KEY_7;
    builtin_constants["vbKey8"] = (int)Key::KEY_8;
    builtin_constants["vbKey9"] = (int)Key::KEY_9;
    // VB6 numpad key constants
    builtin_constants["vbKeyNumpad0"] = (int)Key::KEY_KP_0;
    builtin_constants["vbKeyNumpad1"] = (int)Key::KEY_KP_1;
    builtin_constants["vbKeyNumpad2"] = (int)Key::KEY_KP_2;
    builtin_constants["vbKeyNumpad3"] = (int)Key::KEY_KP_3;
    builtin_constants["vbKeyNumpad4"] = (int)Key::KEY_KP_4;
    builtin_constants["vbKeyNumpad5"] = (int)Key::KEY_KP_5;
    builtin_constants["vbKeyNumpad6"] = (int)Key::KEY_KP_6;
    builtin_constants["vbKeyNumpad7"] = (int)Key::KEY_KP_7;
    builtin_constants["vbKeyNumpad8"] = (int)Key::KEY_KP_8;
    builtin_constants["vbKeyNumpad9"] = (int)Key::KEY_KP_9;
    builtin_constants["vbKeyMultiply"] = (int)Key::KEY_KP_MULTIPLY;
    builtin_constants["vbKeyAdd"] = (int)Key::KEY_KP_ADD;
    builtin_constants["vbKeySubtract"] = (int)Key::KEY_KP_SUBTRACT;
    builtin_constants["vbKeyDecimal"] = (int)Key::KEY_KP_PERIOD;
    builtin_constants["vbKeyDivide"] = (int)Key::KEY_KP_DIVIDE;
    // VB6 lock / special keys
    builtin_constants["vbKeyCapital"] = (int)Key::KEY_CAPSLOCK;
    builtin_constants["vbKeyNumlock"] = (int)Key::KEY_NUMLOCK;
    builtin_constants["vbKeyScrollLock"] = (int)Key::KEY_SCROLLLOCK;
    builtin_constants["vbKeyPause"] = (int)Key::KEY_PAUSE;
    builtin_constants["vbKeySnapshot"] = (int)Key::KEY_PRINT;
    
    // Godot-style Key Constants (for Input.IsKeyPressed)
    builtin_constants["KEY_NONE"] = (int)Key::KEY_NONE;
    builtin_constants["KEY_SPACE"] = (int)Key::KEY_SPACE;
    builtin_constants["KEY_ENTER"] = (int)Key::KEY_ENTER;
    builtin_constants["KEY_ESCAPE"] = (int)Key::KEY_ESCAPE;
    builtin_constants["KEY_TAB"] = (int)Key::KEY_TAB;
    builtin_constants["KEY_BACKSPACE"] = (int)Key::KEY_BACKSPACE;
    builtin_constants["KEY_DELETE"] = (int)Key::KEY_DELETE;
    builtin_constants["KEY_INSERT"] = (int)Key::KEY_INSERT;
    builtin_constants["KEY_HOME"] = (int)Key::KEY_HOME;
    builtin_constants["KEY_END"] = (int)Key::KEY_END;
    builtin_constants["KEY_PAGEUP"] = (int)Key::KEY_PAGEUP;
    builtin_constants["KEY_PAGEDOWN"] = (int)Key::KEY_PAGEDOWN;
    builtin_constants["KEY_UP"] = (int)Key::KEY_UP;
    builtin_constants["KEY_DOWN"] = (int)Key::KEY_DOWN;
    builtin_constants["KEY_LEFT"] = (int)Key::KEY_LEFT;
    builtin_constants["KEY_RIGHT"] = (int)Key::KEY_RIGHT;
    builtin_constants["KEY_SHIFT"] = (int)Key::KEY_SHIFT;
    builtin_constants["KEY_CTRL"] = (int)Key::KEY_CTRL;
    builtin_constants["KEY_ALT"] = (int)Key::KEY_ALT;
    builtin_constants["KEY_CAPSLOCK"] = (int)Key::KEY_CAPSLOCK;
    // Letter keys A-Z
    builtin_constants["KEY_A"] = (int)Key::KEY_A;
    builtin_constants["KEY_B"] = (int)Key::KEY_B;
    builtin_constants["KEY_C"] = (int)Key::KEY_C;
    builtin_constants["KEY_D"] = (int)Key::KEY_D;
    builtin_constants["KEY_E"] = (int)Key::KEY_E;
    builtin_constants["KEY_F"] = (int)Key::KEY_F;
    builtin_constants["KEY_G"] = (int)Key::KEY_G;
    builtin_constants["KEY_H"] = (int)Key::KEY_H;
    builtin_constants["KEY_I"] = (int)Key::KEY_I;
    builtin_constants["KEY_J"] = (int)Key::KEY_J;
    builtin_constants["KEY_K"] = (int)Key::KEY_K;
    builtin_constants["KEY_L"] = (int)Key::KEY_L;
    builtin_constants["KEY_M"] = (int)Key::KEY_M;
    builtin_constants["KEY_N"] = (int)Key::KEY_N;
    builtin_constants["KEY_O"] = (int)Key::KEY_O;
    builtin_constants["KEY_P"] = (int)Key::KEY_P;
    builtin_constants["KEY_Q"] = (int)Key::KEY_Q;
    builtin_constants["KEY_R"] = (int)Key::KEY_R;
    builtin_constants["KEY_S"] = (int)Key::KEY_S;
    builtin_constants["KEY_T"] = (int)Key::KEY_T;
    builtin_constants["KEY_U"] = (int)Key::KEY_U;
    builtin_constants["KEY_V"] = (int)Key::KEY_V;
    builtin_constants["KEY_W"] = (int)Key::KEY_W;
    builtin_constants["KEY_X"] = (int)Key::KEY_X;
    builtin_constants["KEY_Y"] = (int)Key::KEY_Y;
    builtin_constants["KEY_Z"] = (int)Key::KEY_Z;
    // Number keys 0-9
    builtin_constants["KEY_0"] = (int)Key::KEY_0;
    builtin_constants["KEY_1"] = (int)Key::KEY_1;
    builtin_constants["KEY_2"] = (int)Key::KEY_2;
    builtin_constants["KEY_3"] = (int)Key::KEY_3;
    builtin_constants["KEY_4"] = (int)Key::KEY_4;
    builtin_constants["KEY_5"] = (int)Key::KEY_5;
    builtin_constants["KEY_6"] = (int)Key::KEY_6;
    builtin_constants["KEY_7"] = (int)Key::KEY_7;
    builtin_constants["KEY_8"] = (int)Key::KEY_8;
    builtin_constants["KEY_9"] = (int)Key::KEY_9;
    // Function keys F1-F12
    builtin_constants["KEY_F1"] = (int)Key::KEY_F1;
    builtin_constants["KEY_F2"] = (int)Key::KEY_F2;
    builtin_constants["KEY_F3"] = (int)Key::KEY_F3;
    builtin_constants["KEY_F4"] = (int)Key::KEY_F4;
    builtin_constants["KEY_F5"] = (int)Key::KEY_F5;
    builtin_constants["KEY_F6"] = (int)Key::KEY_F6;
    builtin_constants["KEY_F7"] = (int)Key::KEY_F7;
    builtin_constants["KEY_F8"] = (int)Key::KEY_F8;
    builtin_constants["KEY_F9"] = (int)Key::KEY_F9;
    builtin_constants["KEY_F10"] = (int)Key::KEY_F10;
    builtin_constants["KEY_F11"] = (int)Key::KEY_F11;
    builtin_constants["KEY_F12"] = (int)Key::KEY_F12;
    // Symbol / punctuation keys
    builtin_constants["KEY_PLUS"] = (int)Key::KEY_PLUS;
    builtin_constants["KEY_MINUS"] = (int)Key::KEY_MINUS;
    builtin_constants["KEY_ASTERISK"] = (int)Key::KEY_ASTERISK;
    builtin_constants["KEY_SLASH"] = (int)Key::KEY_SLASH;
    builtin_constants["KEY_PERIOD"] = (int)Key::KEY_PERIOD;
    builtin_constants["KEY_EQUAL"] = (int)Key::KEY_EQUAL;
    builtin_constants["KEY_PERCENT"] = (int)Key::KEY_PERCENT;
    // Numeric keypad keys
    builtin_constants["KEY_KP_0"] = (int)Key::KEY_KP_0;
    builtin_constants["KEY_KP_1"] = (int)Key::KEY_KP_1;
    builtin_constants["KEY_KP_2"] = (int)Key::KEY_KP_2;
    builtin_constants["KEY_KP_3"] = (int)Key::KEY_KP_3;
    builtin_constants["KEY_KP_4"] = (int)Key::KEY_KP_4;
    builtin_constants["KEY_KP_5"] = (int)Key::KEY_KP_5;
    builtin_constants["KEY_KP_6"] = (int)Key::KEY_KP_6;
    builtin_constants["KEY_KP_7"] = (int)Key::KEY_KP_7;
    builtin_constants["KEY_KP_8"] = (int)Key::KEY_KP_8;
    builtin_constants["KEY_KP_9"] = (int)Key::KEY_KP_9;
    builtin_constants["KEY_KP_ENTER"] = (int)Key::KEY_KP_ENTER;
    builtin_constants["KEY_KP_ADD"] = (int)Key::KEY_KP_ADD;
    builtin_constants["KEY_KP_SUBTRACT"] = (int)Key::KEY_KP_SUBTRACT;
    builtin_constants["KEY_KP_MULTIPLY"] = (int)Key::KEY_KP_MULTIPLY;
    builtin_constants["KEY_KP_DIVIDE"] = (int)Key::KEY_KP_DIVIDE;
    builtin_constants["KEY_KP_PERIOD"] = (int)Key::KEY_KP_PERIOD;
    // Lock / special function keys
    builtin_constants["KEY_NUMLOCK"] = (int)Key::KEY_NUMLOCK;
    builtin_constants["KEY_SCROLLLOCK"] = (int)Key::KEY_SCROLLLOCK;
    builtin_constants["KEY_PAUSE"] = (int)Key::KEY_PAUSE;
    builtin_constants["KEY_PRINT"] = (int)Key::KEY_PRINT;
    builtin_constants["KEY_SYSREQ"] = (int)Key::KEY_SYSREQ;
    // Punctuation keys
    builtin_constants["KEY_COMMA"] = (int)Key::KEY_COMMA;
    builtin_constants["KEY_SEMICOLON"] = (int)Key::KEY_SEMICOLON;
    builtin_constants["KEY_COLON"] = (int)Key::KEY_COLON;
    builtin_constants["KEY_APOSTROPHE"] = (int)Key::KEY_APOSTROPHE;
    builtin_constants["KEY_QUOTELEFT"] = (int)Key::KEY_QUOTELEFT;
    builtin_constants["KEY_QUOTEDBL"] = (int)Key::KEY_QUOTEDBL;
    builtin_constants["KEY_BRACKETLEFT"] = (int)Key::KEY_BRACKETLEFT;
    builtin_constants["KEY_BRACKETRIGHT"] = (int)Key::KEY_BRACKETRIGHT;
    builtin_constants["KEY_BACKSLASH"] = (int)Key::KEY_BACKSLASH;
    // Mouse button constants
    builtin_constants["MOUSE_BUTTON_LEFT"] = (int)MouseButton::MOUSE_BUTTON_LEFT;
    builtin_constants["MOUSE_BUTTON_RIGHT"] = (int)MouseButton::MOUSE_BUTTON_RIGHT;
    builtin_constants["MOUSE_BUTTON_MIDDLE"] = (int)MouseButton::MOUSE_BUTTON_MIDDLE;
    builtin_constants["MOUSE_BUTTON_WHEEL_UP"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_UP;
    builtin_constants["MOUSE_BUTTON_WHEEL_DOWN"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_DOWN;
    builtin_constants["MOUSE_BUTTON_WHEEL_LEFT"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_LEFT;
    builtin_constants["MOUSE_BUTTON_WHEEL_RIGHT"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_RIGHT;
    builtin_constants["MOUSE_BUTTON_XBUTTON1"] = (int)MouseButton::MOUSE_BUTTON_XBUTTON1;
    builtin_constants["MOUSE_BUTTON_XBUTTON2"] = (int)MouseButton::MOUSE_BUTTON_XBUTTON2;
    // Input mouse mode constants (also accessible via Input.MOUSE_MODE_xxx)
    builtin_constants["MOUSE_MODE_VISIBLE"] = (int)Input::MOUSE_MODE_VISIBLE;
    builtin_constants["MOUSE_MODE_HIDDEN"] = (int)Input::MOUSE_MODE_HIDDEN;
    builtin_constants["MOUSE_MODE_CAPTURED"] = (int)Input::MOUSE_MODE_CAPTURED;
    builtin_constants["MOUSE_MODE_CONFINED"] = (int)Input::MOUSE_MODE_CONFINED;
    builtin_constants["MOUSE_MODE_CONFINED_HIDDEN"] = (int)Input::MOUSE_MODE_CONFINED_HIDDEN;
    
    // MsgBox Button Constants (VB6-style)
    builtin_constants["vbOKOnly"] = 0;
    builtin_constants["vbOKCancel"] = 1;
    builtin_constants["vbAbortRetryIgnore"] = 2;
    builtin_constants["vbYesNoCancel"] = 3;
    builtin_constants["vbYesNo"] = 4;
    builtin_constants["vbRetryCancel"] = 5;
    
    // MsgBox Icon Constants
    builtin_constants["vbCritical"] = 16;
    builtin_constants["vbQuestion"] = 32;
    builtin_constants["vbExclamation"] = 48;
    builtin_constants["vbInformation"] = 64;
    
    // MsgBox Return Values
    builtin_constants["vbOK"] = 1;
    builtin_constants["vbCancel"] = 2;
    builtin_constants["vbAbort"] = 3;
    builtin_constants["vbRetry"] = 4;
    builtin_constants["vbIgnore"] = 5;
    builtin_constants["vbYes"] = 6;
    builtin_constants["vbNo"] = 7;
    // MsgBox default button / modal modifiers
    builtin_constants["vbDefaultButton1"] = 0;
    builtin_constants["vbDefaultButton2"] = 256;
    builtin_constants["vbDefaultButton3"] = 512;
    builtin_constants["vbApplicationModal"] = 0;
    builtin_constants["vbSystemModal"] = 4096;

    // VarType Constants
    builtin_constants["vbEmpty"] = 0;
    builtin_constants["vbNull"] = 1;
    builtin_constants["vbInteger"] = 2;
    builtin_constants["vbLong"] = 3;
    builtin_constants["vbSingle"] = 4;
    builtin_constants["vbDouble"] = 5;
    builtin_constants["vbCurrency"] = 6;
    builtin_constants["vbDate"] = 7;
    builtin_constants["vbString"] = 8;
    builtin_constants["vbObject"] = 9;
    builtin_constants["vbError"] = 10;
    builtin_constants["vbBoolean"] = 11;
    builtin_constants["vbVariant"] = 12;
    builtin_constants["vbDataObject"] = 13;
    builtin_constants["vbDecimal"] = 14;
    builtin_constants["vbByte"] = 17;
    builtin_constants["vbArray"] = 8192;

    // String Comparison Constants
    builtin_constants["vbBinaryCompare"] = 0;
    builtin_constants["vbTextCompare"] = 1;
    builtin_constants["vbDatabaseCompare"] = 2;

    // Weekday Constants
    builtin_constants["vbSunday"] = 1;
    builtin_constants["vbMonday"] = 2;
    builtin_constants["vbTuesday"] = 3;
    builtin_constants["vbWednesday"] = 4;
    builtin_constants["vbThursday"] = 5;
    builtin_constants["vbFriday"] = 6;
    builtin_constants["vbSaturday"] = 7;
    // First week of year constants
    builtin_constants["vbUseSystem"] = 0;
    builtin_constants["vbFirstJan1"] = 1;
    builtin_constants["vbFirstFourDays"] = 2;
    builtin_constants["vbFirstFullWeek"] = 3;

    // File Attribute Constants
    builtin_constants["vbNormal"] = 0;
    builtin_constants["vbReadOnly"] = 1;
    builtin_constants["vbHidden"] = 2;
    builtin_constants["vbSystem"] = 4;
    builtin_constants["vbVolume"] = 8;
    builtin_constants["vbDirectory"] = 16;
    builtin_constants["vbArchive"] = 32;
    builtin_constants["vbAlias"] = 64;

    // Shell Window Style Constants
    builtin_constants["vbHide"] = 0;
    builtin_constants["vbNormalFocus"] = 1;
    builtin_constants["vbMinimizedFocus"] = 2;
    builtin_constants["vbMaximizedFocus"] = 3;
    builtin_constants["vbNormalNoFocus"] = 4;
    builtin_constants["vbMinimizedNoFocus"] = 6;

    // Strings
    builtin_constants["vbTab"] = "\t";
    builtin_constants["vbCr"] = "\r";
    builtin_constants["vbLf"] = "\n";
    builtin_constants["vbCrLf"] = "\r\n";
    builtin_constants["vbNewLine"] = "\n";
    builtin_constants["vbNullChar"] = "\0";
    builtin_constants["vbBack"] = "\b";
    builtin_constants["vbFormFeed"] = "\f";
    builtin_constants["vbVerticalTab"] = "\v";
    builtin_constants["vbNullString"] = "";
    builtin_constants["vbQuote"] = "\"";
    builtin_constants["vbSpace"] = " ";
    builtin_constants["vbComma"] = ",";
    builtin_constants["vbPipe"] = "|";

    // MSComm Constants
    builtin_constants["comNone"] = 0;
    builtin_constants["comXOnXOff"] = 1;
    builtin_constants["comRTS"] = 2;
    builtin_constants["comRTSXOnXOff"] = 3;

    // StrConv Constants (v4.2.0)
    builtin_constants["vbUpperCase"] = 1;
    builtin_constants["vbLowerCase"] = 2;
    builtin_constants["vbProperCase"] = 3;
    builtin_constants["vbUnicode"] = 64;
    builtin_constants["vbFromUnicode"] = 128;

    // CallByName CallType Constants (v4.2.0)
    builtin_constants["vbMethod"] = 1;
    builtin_constants["vbGet"] = 2;
    builtin_constants["vbLet"] = 4;
    builtin_constants["vbSet"] = 8;

    // Initialize Global Variables from Script
    if (script.is_valid()) {
        VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
        if (vs && vs->ast_root) {
            cached_ast_root = vs->ast_root;
            // Module-level Variables
            // Note: Parser stores module level Dims in 'variables' (VariableDefinition) 
            // BUT parser.h says parse_program calls parse_statement... 
            // If they are Dims, they might be in global_statements as DimStatement?
            // Let's check ModuleNode struct again.
            // struct ModuleNode { Vector<VariableDefinition*> variables; ... }
            
            // If the parser separates Declared vars into 'variables', use that.
            // If it keeps them as STMT_DIM in global_statements, execute those.
            
            // Assuming Parser populates `variables` for explicit definitons:
            // (Current Parser implementation detail: It might put them in global_statements if not strictly separated)
            // But let's check AST if variables is used.
            // For now, let's try to Execute Global Statements (which includes DIMs).
            
            for(int i=0; i<vs->ast_root->variables.size(); i++) {
                 VariableDefinition *v = vs->ast_root->variables[i];
                 
                 // Skip array declarations — they are handled by the
                 // DimStatement in global_statements which correctly evaluates
                 // constant expressions like MAX_PARTICLES for array sizes.
                 if (v->array_sizes.size() > 0) {
                     continue;
                 }
                 
                 // Initialize to Correct Type
                 String t = v->type.to_lower();
                 if (t == "integer" || t == "long") variables[v->name] = (int)0;
                 else if (t == "single" || t == "double") variables[v->name] = (float)0.0;
                 else if (t == "string") variables[v->name] = "";
                 else if (t == "boolean") variables[v->name] = false;
                 else variables[v->name] = Variant(); // Init to Empty (Nil)
                 
                 // Track WithEvents variables for signal auto-wiring (v3.5.0)
                 if (v->is_with_events) {
                     with_events_vars[v->name] = true;
                 }

                 // Publish "Global Dim" default to the process-wide shared
                 // registry (v4.4.0) so other scripts can read it by bare
                 // name without an Import. First script to declare it wins
                 // the initial value; later assignments stay local per-script.
                 if (v->is_global && !get_global_scope().has(v->name)) {
                     get_global_scope()[v->name] = variables[v->name];
                 }
                 
                 UtilityFunctions::print("Initialized Global Var: ", v->name);
            }
            
            // Initialize constants FIRST so that array Dim sizes
            // (e.g. Dim arr(MAX_PARTICLES)) can reference them
            for(int ci=0; ci<vs->ast_root->constants.size(); ci++) {
                ConstStatement* c = vs->ast_root->constants[ci];
                Variant val = evaluate_expression(c->value);
                variables[c->name] = val;
                // "Global Const" (v4.4.0) — publish to the shared, process-wide
                // registry so any script in the project can read it by bare name.
                if (c->is_global) {
                    get_global_scope()[c->name] = val;
                }
            }
            // Initialize enums early too (they are effectively constants)
            for(int ei=0; ei<vs->ast_root->enums.size(); ei++) {
                EnumDefinition* ed = vs->ast_root->enums[ei];
                for(int em=0; em<ed->values.size(); em++) {
                    variables[ed->values[em].name] = ed->values[em].value;
                }
            }
            
            // Build struct prototypes BEFORE global Dims so that
            // `Dim particles(N) As Particle` can find the prototype.
            {
                struct ProtoBuilder {
                     ModuleNode* module;
                     Dictionary cache;
                     Vector<String> processing;
                     String struct_type_key;
                     
                     Variant get_proto(String name) {
                         if (cache.has(name)) return cache[name];
                         
                         StructDefinition* def = nullptr;
                         for(int i=0; i<module->structs.size(); i++) {
                             if (module->structs[i]->name.nocasecmp_to(name) == 0) {
                                 def = module->structs[i];
                                 break;
                             }
                         }
                         
                         if (!def) return Variant(); 
                         
                         if (processing.has(name)) {
                              UtilityFunctions::print("Error: Recursive struct definition in ", name);
                              return Variant();
                         }
                         
                         processing.push_back(name);
                         
                         Dictionary dict;
                         // Tag the dictionary with its struct type for strict member checking
                         dict[struct_type_key] = name;
                         
                         for(int i=0; i<def->members.size(); i++) {
                             String mname = def->members[i].name;
                             String mtype = def->members[i].type;
                             int fixed_len = def->members[i].fixed_length;

                             if (mtype.nocasecmp_to("Integer") == 0 || mtype.nocasecmp_to("Long") == 0) dict[mname] = 0;
                             else if (mtype.nocasecmp_to("String") == 0) {
                                 // Fixed-length string: initialize with spaces padded to length
                                 if (fixed_len > 0) {
                                     String s;
                                     s = String(" ").repeat(fixed_len);
                                     dict[mname] = s;
                                 } else {
                                     dict[mname] = "";
                                 }
                             }
                             else if (mtype.nocasecmp_to("Single") == 0 || mtype.nocasecmp_to("Double") == 0) dict[mname] = 0.0;
                             else if (mtype.nocasecmp_to("Boolean") == 0) dict[mname] = false;
                             else if (mtype.nocasecmp_to("Variant") == 0) dict[mname] = Variant();
                             else {
                                 Variant sub = get_proto(mtype);
                                 if (sub.get_type() == Variant::DICTIONARY) {
                                     dict[mname] = ((Dictionary)sub).duplicate(true);
                                 } else {
                                     dict[mname] = Variant(); 
                                 }
                             }
                         }
                         
                         processing.erase(name);
                         cache[name] = dict;
                         return dict;
                     }
                };
                
                ProtoBuilder builder;
                builder.module = vs->ast_root;
                builder.struct_type_key = STRUCT_TYPE_KEY_CSTR;
                
                for(int si=0; si<vs->ast_root->structs.size(); si++) {
                     String name = vs->ast_root->structs[si]->name;
                     struct_prototypes[name] = builder.get_proto(name);
                }
            }

            // Also execute global statements (like Dims not captured in definitions, or Options)
            // Warning: Don't execute imperative code here if untrusted? 
            // Basic usually has static declarative section.
            // Suppress Whenever triggers during module init to prevent
            // false callback fires before _Ready has run.
            whenever_init_suppress = true;
            for(int i=0; i<vs->ast_root->global_statements.size(); i++) {
                Statement *stmt = vs->ast_root->global_statements[i];
                if (stmt->type == STMT_DIM) {
                     execute_statement(stmt);
                }
                else if (stmt->type == STMT_CONST) {
                     execute_statement(stmt);
                }
                else if (stmt->type == STMT_WHENEVER_SECTION) {
                     execute_statement(stmt);
                }
            }
            whenever_init_suppress = false;
            
            // Resolve Import statements (v4.3.0) — load imported modules,
            // store full ASTs for cross-module function calls, and register
            // public variables/constants in module_registry for dot-access.
            // Circular import detection via thread-local import_stack.
            String this_path = vs->get_path();
            import_stack.push_back(this_path);
            
            for (int ii = 0; ii < vs->ast_root->imports.size(); ii++) {
                String import_path = vs->ast_root->imports[ii];
                // Resolve relative to current script directory
                String script_dir = vs->get_path().get_base_dir();
                String full_path = import_path;
                if (!import_path.begins_with("res://") && !import_path.begins_with("/")) {
                    full_path = script_dir.path_join(import_path);
                }
                
                // Circular import detection
                bool is_circular = false;
                for (int ci = 0; ci < import_stack.size() - 1; ci++) {
                    if (import_stack[ci] == full_path) {
                        is_circular = true;
                        break;
                    }
                }
                if (is_circular) {
                    UtilityFunctions::print("[VG] Import Warning: Circular import detected for: ", full_path, " — skipping");
                    continue;
                }
                
                if (FileAccess::file_exists(full_path)) {
                    // Allocate on heap so AST nodes survive past this scope
                    VisualGasicTokenizer* import_tok = new VisualGasicTokenizer();
                    Vector<VisualGasicTokenizer::Token> import_tokens = import_tok->tokenize(
                        FileAccess::get_file_as_string(full_path));
                    VisualGasicParser* import_parser = new VisualGasicParser();
                    ModuleNode* import_ast = import_parser->parse(import_tokens);
                    
                    if (import_ast && import_parser->errors.size() == 0) {
                        String mod_name = full_path.get_file().get_basename();

                        // Scan Labels — imported files are parsed independently
                        // (never routed through VisualGasicScript::reload()), so
                        // GoTo/GoSub/Label targets in module-level Subs AND in
                        // Class methods defined in an imported .vg file must be
                        // resolved here too, or every GoTo inside them fails at
                        // runtime with "Label not found".
                        for (int si2 = 0; si2 < import_ast->subs.size(); si2++) {
                            SubDefinition* sub2 = import_ast->subs[si2];
                            for (int j2 = 0; j2 < sub2->statements.size(); j2++) {
                                if (sub2->statements[j2]->type == STMT_LABEL) {
                                    LabelStatement* lbl2 = (LabelStatement*)sub2->statements[j2];
                                    sub2->label_map[lbl2->name] = j2;
                                }
                            }
                        }
                        for (int cdi2 = 0; cdi2 < import_ast->class_defs.size(); cdi2++) {
                            ClassDefinition* cls2 = import_ast->class_defs[cdi2];
                            if (!cls2) continue;
                            for (int mi2 = 0; mi2 < cls2->methods.size(); mi2++) {
                                SubDefinition* sub2 = cls2->methods[mi2];
                                if (!sub2) continue;
                                for (int j2 = 0; j2 < sub2->statements.size(); j2++) {
                                    if (sub2->statements[j2]->type == STMT_LABEL) {
                                        LabelStatement* lbl2 = (LabelStatement*)sub2->statements[j2];
                                        sub2->label_map[lbl2->name] = j2;
                                    }
                                }
                            }
                        }

                        // Initialize the imported module's own module-level
                        // globals/consts/array-Dims into THIS instance's shared
                        // `variables` map — mirroring the main script's own
                        // global-init block above. Previously this was skipped
                        // entirely for imported files: only a separate
                        // `mod_dict`/`module_registry` snapshot (for qualified
                        // ModuleName.Variable dot-access) was built below, using
                        // bare scalar defaults and NEVER executing the actual
                        // STMT_DIM statements — so any array-sized module-level
                        // Dim in an imported file (e.g. `Dim g_c64Pal(15) As
                        // Variant`) never got created in `variables` at all,
                        // causing "Expected Array for index access" the first
                        // time a Sub in that module tried to index into it.
                        for (int vi3 = 0; vi3 < import_ast->variables.size(); vi3++) {
                            VariableDefinition* v3 = import_ast->variables[vi3];
                            if (v3->array_sizes.size() > 0) continue; // handled by STMT_DIM below
                            if (variables.has(v3->name)) continue;
                            String t3 = v3->type.to_lower();
                            if (t3 == "integer" || t3 == "long") variables[v3->name] = (int)0;
                            else if (t3 == "single" || t3 == "double") variables[v3->name] = (float)0.0;
                            else if (t3 == "string") variables[v3->name] = "";
                            else if (t3 == "boolean") variables[v3->name] = false;
                            else variables[v3->name] = Variant();
                        }
                        for (int ci3 = 0; ci3 < import_ast->constants.size(); ci3++) {
                            ConstStatement* c3 = import_ast->constants[ci3];
                            if (c3->value && !variables.has(c3->name)) {
                                variables[c3->name] = evaluate_expression(c3->value);
                            }
                        }
                        {
                            bool prev_whenever_suppress = whenever_init_suppress;
                            whenever_init_suppress = true;
                            for (int gi3 = 0; gi3 < import_ast->global_statements.size(); gi3++) {
                                Statement* stmt3 = import_ast->global_statements[gi3];
                                if (stmt3->type == STMT_DIM || stmt3->type == STMT_CONST || stmt3->type == STMT_WHENEVER_SECTION) {
                                    execute_statement(stmt3);
                                }
                            }
                            whenever_init_suppress = prev_whenever_suppress;
                        }

                        // Store the full AST for cross-module function calls
                        ImportedModule im;
                        im.module_name = mod_name;
                        im.full_path = full_path;
                        im.ast = import_ast;
                        im.parser = import_parser;
                        im.tokenizer = import_tok;
                        imported_modules.push_back(im);
                        
                        // Also populate module_registry for backward compat
                        // and ModuleName.Variable dot-access
                        Dictionary mod_dict;
                        for (int vi = 0; vi < import_ast->variables.size(); vi++) {
                            VariableDefinition* mv = import_ast->variables[vi];
                            if (mv->visibility == VIS_PUBLIC) {
                                String t = mv->type.to_lower();
                                if (t == "integer" || t == "long") mod_dict[mv->name] = 0;
                                else if (t == "single" || t == "double") mod_dict[mv->name] = 0.0;
                                else if (t == "string") mod_dict[mv->name] = "";
                                else if (t == "boolean") mod_dict[mv->name] = false;
                                else mod_dict[mv->name] = Variant();
                            }
                        }
                        for (int ci = 0; ci < import_ast->constants.size(); ci++) {
                            ConstStatement* mc = import_ast->constants[ci];
                            if (mc->value && mc->value->type == ExpressionNode::LITERAL) {
                                mod_dict[mc->name] = static_cast<LiteralNode*>(mc->value)->value;
                            }
                            // "Global Const" declared in an imported file (v4.4.0) —
                            // publish to the shared project-wide registry too, so
                            // it's reachable by bare name from ANY script, not just
                            // via qualified ModuleName.Symbol dot-access.
                            if (mc->is_global && mc->value && !get_global_scope().has(mc->name)) {
                                get_global_scope()[mc->name] = evaluate_expression(mc->value);
                            }
                        }
                        // "Global Dim/Public/Private" declared in an imported file
                        // (v4.4.0) — publish default value too.
                        for (int vi2 = 0; vi2 < import_ast->variables.size(); vi2++) {
                            VariableDefinition* mv2 = import_ast->variables[vi2];
                            if (mv2->is_global && !get_global_scope().has(mv2->name)) {
                                String t2 = mv2->type.to_lower();
                                if (t2 == "integer" || t2 == "long") get_global_scope()[mv2->name] = (int)0;
                                else if (t2 == "single" || t2 == "double") get_global_scope()[mv2->name] = (float)0.0;
                                else if (t2 == "string") get_global_scope()[mv2->name] = "";
                                else if (t2 == "boolean") get_global_scope()[mv2->name] = false;
                                else get_global_scope()[mv2->name] = Variant();
                            }
                        }
                        // Register sub/function names for IntelliSense hints
                        // (all module-level subs are public by default in VB6)
                        for (int si = 0; si < import_ast->subs.size(); si++) {
                            SubDefinition* sd = import_ast->subs[si];
                            mod_dict[String("__sub__") + sd->name] = sd->parameters.size();
                        }
                        
                        module_registry[mod_name] = mod_dict;
                        UtilityFunctions::print("[VG] Imported module: ", mod_name, " (", 
                            import_ast->subs.size(), " subs, ",
                            import_ast->variables.size(), " vars) from ", full_path);

                        // Register the imported module's Class definitions (v4.4.0)
                        // so `New ClassName` works for classes defined in a
                        // separate imported .vg file, not just classes defined
                        // in this script's own file.
                        for (int cdi = 0; cdi < import_ast->class_defs.size(); cdi++) {
                            register_class(import_ast->class_defs[cdi]);
                        }
                    } else {
                        // Parse failed — clean up
                        delete import_parser;
                        delete import_tok;
                    }
                } else {
                    UtilityFunctions::print("[VG] Import Error: File not found: ", full_path);
                }
            }
            
            // Pop import stack
            if (import_stack.size() > 0) {
                import_stack.remove_at(import_stack.size() - 1);
            }
        }
    }

    // Auto-Enable Processing (but NOT in editor mode!)
    bool in_editor = Engine::get_singleton()->is_editor_hint();
    if (owner && script.is_valid() && !in_editor) {
        Node* node = Object::cast_to<Node>(owner);
        if (node) {
            // UtilityFunctions::print("Checking process for node: ", node->get_name());
             
             // Check via AST directly to avoid has_method virtual dispatch issues
             bool has_process = false;
             bool has_physics = false;
             bool has_input = false;
             bool has_unhandled_input = false;
             
             VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
             if (vs && vs->ast_root) {
                 for(int i=0; i<vs->ast_root->subs.size(); i++) {
                     String n = vs->ast_root->subs[i]->name;
                     if (n.nocasecmp_to("_Process") == 0) has_process = true;
                     if (n.nocasecmp_to("_PhysicsProcess") == 0) has_physics = true;
                     if (n.nocasecmp_to("_Input") == 0) has_input = true;
                     if (n.nocasecmp_to("_UnhandledInput") == 0) has_unhandled_input = true;
                 }
             }

             if (has_process) {
                 UtilityFunctions::print("VisualGasic: Enabling Process for ", node->get_name());
                 node->set_process(true);
             }
             
             if (has_physics) node->set_physics_process(true);
             if (has_input) node->set_process_input(true);
             if (has_unhandled_input) node->set_process_unhandled_input(true);
        } else {
             UtilityFunctions::print("VisualGasic: Owner is NOT a Node");
        }
    }

    // Initialize remaining script resources (classes, data segments)
    // Note: Struct prototypes, constants, and enums are already initialized
    // in the first block above (before global Dims execute).
    if (script.is_valid() && script->ast_root != nullptr) {

        // Register Class definitions
        for(int i=0; i<script->ast_root->class_defs.size(); i++) {
            register_class(script->ast_root->class_defs[i]);
        }

        // Implements verification (v3.5.0)
        // For each Implements InterfaceName, check that every Sub/Function
        // in the interface module has a matching InterfaceName_MethodName in
        // this module. VB6 convention: implementing IFoo requires IFoo_Bar
        // for every method Bar defined in IFoo.
        for (int ii = 0; ii < script->ast_root->implements_list.size(); ii++) {
            String iface = script->ast_root->implements_list[ii];
            // Look up the interface script by name among loaded scripts
            // For now, we verify that _some_ prefixed subs exist.
            // A proper implementation would load the interface .vg file
            // and compare method lists. Emit a warning if no subs match.
            String prefix = iface + "_";
            bool found_any = false;
            for (int si = 0; si < script->ast_root->subs.size(); si++) {
                if (script->ast_root->subs[si]->name.begins_with(prefix)) {
                    found_any = true;
                    break;
                }
            }
            if (!found_any) {
                UtilityFunctions::print("VisualGasic Warning: Module 'Implements ", iface,
                    "' but contains no '", prefix, "...' methods. "
                    "VB6 convention requires InterfaceName_MethodName for each interface method.");
            }
        }

        // Initialize Data Segments
        scan_data_sections(script->ast_root);
    }
}

void VisualGasicInstance::scan_data_sections(ModuleNode* root) {
    if (!root) return;

    data_segments.clear();
    label_to_data_index.clear();

    // Scan Global Statements first (module-level Data/Labels appear before Subs in source)
    collect_data_from_block(root->global_statements);

    // Then scan Subs in declaration order
    for(int i=0; i<root->subs.size(); i++) {
        collect_data_from_block(root->subs[i]->statements);
    }
}

int VisualGasicInstance::get_section_end(int section_start) const {
    // Find the next label boundary after section_start
    Array keys = label_to_data_index.keys();
    int nearest = data_segments.size();
    for (int i = 0; i < keys.size(); i++) {
        int idx = (int)label_to_data_index[keys[i]];
        if (idx > section_start && idx < nearest) {
            nearest = idx;
        }
    }
    return nearest;
}

int VisualGasicInstance::get_current_section_start() const {
    // Find the label boundary at or before data_pointer
    Array keys = label_to_data_index.keys();
    int best = 0;
    for (int i = 0; i < keys.size(); i++) {
        int idx = (int)label_to_data_index[keys[i]];
        if (idx <= data_pointer && idx > best) {
            best = idx;
        }
    }
    return best;
}

void VisualGasicInstance::clear_data_tape() {
    // Free runtime-loaded nodes
    for (int i = 0; i < runtime_data_nodes.size(); i++) {
        if (runtime_data_nodes[i]) delete runtime_data_nodes[i];
    }
    runtime_data_nodes.clear();
    data_segments.clear();
    label_to_data_index.clear();
    data_pointer = 0;
}

Variant VisualGasicInstance::coerce_to_type(const Variant &val, const String &type_name) {
    String tl = type_name.to_lower();
    if (tl == "integer" || tl == "int" || tl == "long" || tl == "int32" || tl == "int64") {
        return Variant((int64_t)val);
    } else if (tl == "single" || tl == "float" || tl == "double" || tl == "float32" || tl == "float64") {
        return Variant((double)val);
    } else if (tl == "string") {
        return Variant(String(val));
    } else if (tl == "boolean" || tl == "bool") {
        return Variant(val.booleanize());
    }
    return val; // unknown type, pass through
}

StructDefinition* VisualGasicInstance::find_struct_definition(const String &name) const {
    if (!script.is_valid()) return nullptr;
    VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
    if (!vs || !vs->ast_root) return nullptr;
    for (int i = 0; i < vs->ast_root->structs.size(); i++) {
        if (vs->ast_root->structs[i]->name.nocasecmp_to(name) == 0) {
            return vs->ast_root->structs[i];
        }
    }
    return nullptr;
}

Variant VisualGasicInstance::coerce_struct_member(const String &struct_type, const String &member_name, const Variant &val) {
    StructDefinition *def = find_struct_definition(struct_type);
    if (!def) return val;
    
    for (int i = 0; i < def->members.size(); i++) {
        if (def->members[i].name.nocasecmp_to(member_name) == 0) {
            String mtype = def->members[i].type;
            int fixed_len = def->members[i].fixed_length;
            
            // Coerce to declared type
            Variant coerced = coerce_to_type(val, mtype);
            
            // Fixed-length string: pad or truncate
            if (mtype.nocasecmp_to("String") == 0 && fixed_len > 0) {
                String s = String(coerced);
                if (s.length() > fixed_len) {
                    s = s.substr(0, fixed_len);
                } else {
                    while (s.length() < fixed_len) s += " ";
                }
                return s;
            }
            return coerced;
        }
    }
    return val; // Member not in definition (shouldn't happen)
}

void VisualGasicInstance::collect_data_from_block(const Vector<Statement*>& block) {
    for(int i=0; i<block.size(); i++) {
        Statement* s = block[i];
        if (s->type == STMT_DATA) {
            DataStatement* data = (DataStatement*)s;
            for(int k=0; k<data->values.size(); k++) {
                data_segments.push_back(data->values[k]);
            }
        }
        if (s->type == STMT_LABEL) {
            LabelStatement* label = (LabelStatement*)s;
            label_to_data_index[label->name.to_lower()] = data_segments.size();
        }
        
        // Recursive blocks (If, Do, Loop, For, Select, With)
        if (s->type == STMT_IF) {
            IfStatement* ifs = (IfStatement*)s;
            collect_data_from_block(ifs->then_branch);
            collect_data_from_block(ifs->else_branch);
        }
        if (s->type == STMT_FOR) collect_data_from_block(((ForStatement*)s)->body);
        if (s->type == STMT_WHILE) collect_data_from_block(((WhileStatement*)s)->body);
        if (s->type == STMT_DO) collect_data_from_block(((DoStatement*)s)->body);
        if (s->type == STMT_OSCILLATE) collect_data_from_block(((OscillateStatement*)s)->body);
        if (s->type == STMT_REPEAT) collect_data_from_block(((RepeatStatement*)s)->body);
        if (s->type == STMT_CYCLE) collect_data_from_block(((CycleStatement*)s)->body);
        if (s->type == STMT_EVERY) collect_data_from_block(((EveryStatement*)s)->body);
        if (s->type == STMT_WITH) collect_data_from_block(((WithStatement*)s)->body);
        if (s->type == STMT_SELECT) {
            SelectStatement* sel = (SelectStatement*)s;
            for(int c=0; c<sel->cases.size(); c++) {
                collect_data_from_block(sel->cases[c]->body);
            }
        }
    }
}

VisualGasicInstance::~VisualGasicInstance() {
    // Unregister from debug system
    VisualGasicDebug::unregister_instance(this);
    
    for(int i=0; i<runtime_data_nodes.size(); i++) {
        if (runtime_data_nodes[i]) delete runtime_data_nodes[i];
    }
    
    // Clean up imported module ASTs (v4.3.0)
    for (int i = 0; i < imported_modules.size(); i++) {
        if (imported_modules[i].parser) delete imported_modules[i].parser;
        if (imported_modules[i].tokenizer) delete imported_modules[i].tokenizer;
    }
    imported_modules.clear();
}

// ── Multi-Module: find a Sub/Function across all imported modules (v4.3.0) ──
SubDefinition* VisualGasicInstance::find_imported_sub(const String& name, int arg_count, String* r_module_name) {
    for (int m = 0; m < imported_modules.size(); m++) {
        ModuleNode* ast = imported_modules[m].ast;
        if (!ast) continue;
        SubDefinition* first_match = nullptr;
        for (int s = 0; s < ast->subs.size(); s++) {
            SubDefinition* sd = ast->subs[s];
            if (sd->name.nocasecmp_to(name) == 0) {
                if (!first_match) first_match = sd;
                if (arg_count < 0) { // No arity filter
                    if (r_module_name) *r_module_name = imported_modules[m].module_name;
                    return sd;
                }
                int param_count = sd->parameters.size();
                if (param_count == arg_count) {
                    if (r_module_name) *r_module_name = imported_modules[m].module_name;
                    return sd;
                }
                // Optional params
                int required = 0;
                for (int j = 0; j < param_count; j++) {
                    if (!sd->parameters[j].is_optional && !sd->parameters[j].is_param_array) required++;
                }
                bool has_param_array = param_count > 0 && sd->parameters[param_count - 1].is_param_array;
                if (has_param_array ? (arg_count >= required) : (arg_count >= required && arg_count <= param_count)) {
                    if (r_module_name) *r_module_name = imported_modules[m].module_name;
                    return sd;
                }
            }
        }
        if (first_match) {
            if (r_module_name) *r_module_name = imported_modules[m].module_name;
            return first_match;
        }
    }
    return nullptr;
}

// ── Multi-Module: find Sub/Function in a specific module by name (v4.3.0) ──
SubDefinition* VisualGasicInstance::find_sub_in_module(const String& module_name, const String& sub_name, int arg_count) {
    for (int m = 0; m < imported_modules.size(); m++) {
        if (imported_modules[m].module_name.nocasecmp_to(module_name) != 0) continue;
        ModuleNode* ast = imported_modules[m].ast;
        if (!ast) continue;
        SubDefinition* first_match = nullptr;
        for (int s = 0; s < ast->subs.size(); s++) {
            SubDefinition* sd = ast->subs[s];
            if (sd->name.nocasecmp_to(sub_name) == 0) {
                if (!first_match) first_match = sd;
                if (arg_count < 0) return sd;
                int param_count = sd->parameters.size();
                if (param_count == arg_count) return sd;
                int required = 0;
                for (int j = 0; j < param_count; j++) {
                    if (!sd->parameters[j].is_optional && !sd->parameters[j].is_param_array) required++;
                }
                bool has_param_array = param_count > 0 && sd->parameters[param_count - 1].is_param_array;
                if (has_param_array ? (arg_count >= required) : (arg_count >= required && arg_count <= param_count)) return sd;
            }
        }
        return first_match;
    }
    return nullptr;
}

Variant VisualGasicInstance::evaluate_expression_for_builtins(ExpressionNode* expr) {
    return _evaluate_expression_impl(expr);
}

Variant VisualGasicInstance::evaluate_expression_full(ExpressionNode* expr) {
    return evaluate_expression(expr);
}

Variant VisualGasicInstance::file_lof(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->get_length();
    }
    return 0;
}

Variant VisualGasicInstance::file_loc(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->get_position();
    }
    return 0;
}

Variant VisualGasicInstance::file_eof(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->get_position() >= fa->get_length();
    }
    return true;
}

int VisualGasicInstance::file_free(int range) {
    int start = 1;
    if (range == 1) start = 256;
    for (int i = start; i < start + 255; i++) {
        if (!open_files.has(i)) return i;
    }
    raise_error("Too many files open");
    return 0;
}

Variant VisualGasicInstance::file_len(const String &path) {
    Ref<FileAccess> fa = FileAccess::open(path, FileAccess::READ);
    if (fa.is_valid()) return fa->get_length();
    return 0;
}

Variant VisualGasicInstance::file_dir(const Array &args) {
    if (args.size() >= 1) {
        String path = args[0];
        String folder = path.get_base_dir();
        if (folder.is_empty()) folder = "res://";
        dir_pattern = path.get_file();
        if (dir_pattern.is_empty()) dir_pattern = "*";
        current_dir = DirAccess::open(folder);
        if (current_dir.is_valid()) {
            current_dir->list_dir_begin();
            String f = current_dir->get_next();
            while (!f.is_empty()) {
                if (f != "." && f != ".." && f.matchn(dir_pattern)) return f;
                f = current_dir->get_next();
            }
        }
        return String();
    } else {
        if (current_dir.is_valid()) {
            String f = current_dir->get_next();
            while (!f.is_empty()) {
                if (f != "." && f != ".." && f.matchn(dir_pattern)) return f;
                f = current_dir->get_next();
            }
        }
        return String();
    }
}

void VisualGasicInstance::randomize_seed() {
    UtilityFunctions::randomize();
}

void VisualGasicInstance::raise_runtime_error(const String &p_msg, int p_code, const String &p_source) {
    raise_error(p_msg, p_code, p_source);
}

bool VisualGasicInstance::set(const StringName &p_name, const Variant &p_value) {
    if (variables.has(p_name)) {
        variables[p_name] = p_value;
        return true;
    }
    // Check if it is a public variable defined in script, but not yet initialized in variables map
    // (Though we should init them in constructor)
    
    if (script.is_valid() && script->ast_root) {
        for(int i=0; i<script->ast_root->variables.size(); i++) {
            if (script->ast_root->variables[i]->name == p_name) {
                 variables[p_name] = p_value;
                 return true;
            }
        }
    }
    return false;
}

bool VisualGasicInstance::get(const StringName &p_name, Variant &r_ret) {
    if (variables.has(p_name)) {
        r_ret = variables[p_name];
        return true;
    }
    // Fallback to built-in constants (separated so debugger only shows user vars)
    if (builtin_constants.has(p_name)) {
        r_ret = builtin_constants[p_name];
        return true;
    }
    return false;
}

// Retrieve a variable by name into r_ret. Returns true if found.
// Falls back to builtin_constants for VB6/Godot constants.
bool VisualGasicInstance::get_variable(const String &p_name, Variant &r_ret) {
    if (variables.has(p_name)) {
        r_ret = variables[p_name];
        return true;
    }
    if (builtin_constants.has(p_name)) {
        r_ret = builtin_constants[p_name];
        return true;
    }
    return false;
}

// Wrapper that forwards statement-level builtin calls to the centralized builtins module.
void VisualGasicInstance::dispatch_builtin_call(const String &p_method, const Array &p_args, bool &r_found) {
    r_found = false;
    Variant dummy_ret;
    bool handled = false;
    if (VisualGasicBuiltins::call_builtin(this, p_method, p_args, dummy_ret, handled)) {
        r_found = handled;
        return;
    }
    
    // Drawing commands — require owner to be a CanvasItem
    if (owner) {
        CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
        if (ci) {
            // DrawString — VG style: DrawString text, x, y, color[, fontSize]
            //              Godot style: DrawString font, Vector2(x, y), text, color[, fontSize]
            if (p_method.nocasecmp_to("DrawString") == 0 && p_args.size() >= 4) {
                Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
                int font_size = 16;
                // Godot style: first arg is Font (Object), second is Vector2
                if (p_args[0].get_type() == Variant::OBJECT && p_args.size() >= 4) {
                    Vector2 pos = p_args[1];
                    String text = p_args[2];
                    Color col = Color(1,1,1,1);
                    if (p_args.size() > 3) col = p_args[3];
                    if (p_args.size() > 4) font_size = (int)p_args[4];
                    ci->draw_string(font, pos, text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col);
                } else {
                    // VG style: DrawString text, x, y, color
                    String text = p_args[0];
                    float x = p_args[1];
                    float y = p_args[2];
                    Color col = p_args[3];
                    if (p_args.size() > 4) font_size = (int)p_args[4];
                    ci->draw_string(font, Vector2(x, y + font_size), text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col);
                }
                r_found = true;
                return;
            }
            // DrawText — DrawText Vector2(x, y), text[, color]
            if (p_method.nocasecmp_to("DrawText") == 0 && p_args.size() >= 2) {
                Vector2 pos = p_args[0];
                String text = p_args[1];
                Color col = Color(1,1,1,1);
                if (p_args.size() > 2) col = p_args[2];
                Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
                ci->draw_string(font, pos, text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col);
                r_found = true;
                return;
            }
            // DrawLine — VG style: DrawLine x1, y1, x2, y2[, color][, width]
            //            Godot style: DrawLine Vector2(x1,y1), Vector2(x2,y2)[, color][, width]
            if (p_method.nocasecmp_to("DrawLine") == 0 && p_args.size() >= 2) {
                Color col = Color(1,1,1,1);
                float width = 1.0;
                if (p_args[0].get_type() == Variant::VECTOR2 && p_args.size() >= 2) {
                    // Godot style: Vector2, Vector2[, Color][, width]
                    Vector2 from = p_args[0];
                    Vector2 to = p_args[1];
                    if (p_args.size() > 2) col = p_args[2];
                    if (p_args.size() > 3) width = p_args[3];
                    ci->draw_line(from, to, col, width);
                } else if (p_args.size() >= 4) {
                    // VG style: x1, y1, x2, y2[, Color][, width]
                    float x1 = p_args[0], y1 = p_args[1], x2 = p_args[2], y2 = p_args[3];
                    if (p_args.size() > 4) col = p_args[4];
                    if (p_args.size() > 5) width = p_args[5];
                    ci->draw_line(Vector2(x1, y1), Vector2(x2, y2), col, width);
                }
                r_found = true;
                return;
            }
            // DrawRect — VG style: DrawRect x, y, w, h[, color][, filled]
            //            Godot style: DrawRect Rect2(x,y,w,h)[, color][, filled]
            if (p_method.nocasecmp_to("DrawRect") == 0 && p_args.size() >= 1) {
                Color col = Color(1,1,1,1);
                bool filled = true;
                if (p_args[0].get_type() == Variant::RECT2) {
                    // Godot style: Rect2[, Color][, filled]
                    Rect2 rect = p_args[0];
                    if (p_args.size() > 1) col = p_args[1];
                    if (p_args.size() > 2) filled = (bool)p_args[2];
                    ci->draw_rect(rect, col, filled);
                } else if (p_args.size() >= 4) {
                    // VG style: x, y, w, h[, Color][, filled]
                    float x = p_args[0], y = p_args[1], w = p_args[2], h = p_args[3];
                    if (p_args.size() > 4) col = p_args[4];
                    if (p_args.size() > 5) filled = (bool)p_args[5];
                    ci->draw_rect(Rect2(x, y, w, h), col, filled);
                }
                r_found = true;
                return;
            }
            // DrawCircle — VG style: DrawCircle x, y, radius[, color]
            //              Godot style: DrawCircle Vector2(x,y), radius[, color]
            if (p_method.nocasecmp_to("DrawCircle") == 0 && p_args.size() >= 2) {
                Color col = Color(1,1,1,1);
                if (p_args[0].get_type() == Variant::VECTOR2 && p_args.size() >= 2) {
                    // Godot style: Vector2, radius[, Color]
                    Vector2 pos = p_args[0];
                    float radius = p_args[1];
                    if (p_args.size() > 2) col = p_args[2];
                    ci->draw_circle(pos, radius, col);
                } else if (p_args.size() >= 3) {
                    // VG style: x, y, radius[, Color]
                    float x = p_args[0], y = p_args[1], radius = p_args[2];
                    if (p_args.size() > 3) col = p_args[3];
                    ci->draw_circle(Vector2(x, y), radius, col);
                }
                r_found = true;
                return;
            }
            // DrawPixel / PSet — PSet x, y, color
            if ((p_method.nocasecmp_to("DrawPixel") == 0 || p_method.nocasecmp_to("PSet") == 0) && p_args.size() >= 3) {
                float x = p_args[0], y = p_args[1];
                Color col = p_args[2];
                ci->draw_rect(Rect2(x, y, 1, 1), col, true);
                r_found = true;
                return;
            }
            // DrawTexture — VG style: DrawTexture texture, x, y[, color]
            //               Godot style: DrawTexture texture, Vector2[, color]
            if (p_method.nocasecmp_to("DrawTexture") == 0 && p_args.size() >= 2) {
                Ref<Texture2D> tex;
                if (p_args[0].get_type() == Variant::OBJECT) {
                    tex = p_args[0];
                }
                if (tex.is_valid()) {
                    Color modulate = Color(1,1,1,1);
                    if (p_args[1].get_type() == Variant::VECTOR2) {
                        // Godot style: texture, Vector2[, color]
                        Vector2 pos = p_args[1];
                        if (p_args.size() > 2) modulate = p_args[2];
                        ci->draw_texture(tex, pos, modulate);
                    } else if (p_args.size() >= 3) {
                        // VG style: texture, x, y[, color]
                        float x = p_args[1], y = p_args[2];
                        if (p_args.size() > 3) modulate = p_args[3];
                        ci->draw_texture(tex, Vector2(x, y), modulate);
                    }
                }
                r_found = true;
                return;
            }
            // DrawTextureRect — DrawTextureRect texture, Rect2[, tile][, color]
            //                   DrawTextureRect texture, x, y, w, h[, tile][, color]
            if (p_method.nocasecmp_to("DrawTextureRect") == 0 && p_args.size() >= 2) {
                Ref<Texture2D> tex;
                if (p_args[0].get_type() == Variant::OBJECT) {
                    tex = p_args[0];
                }
                if (tex.is_valid()) {
                    bool tile = false;
                    Color modulate = Color(1,1,1,1);
                    if (p_args[1].get_type() == Variant::RECT2) {
                        // Godot style: texture, Rect2[, tile][, color]
                        Rect2 rect = p_args[1];
                        if (p_args.size() > 2) tile = (bool)p_args[2];
                        if (p_args.size() > 3) modulate = p_args[3];
                        ci->draw_texture_rect(tex, rect, tile, modulate);
                    } else if (p_args.size() >= 5) {
                        // VG style: texture, x, y, w, h[, tile][, color]
                        float x = p_args[1], y = p_args[2], w = p_args[3], h = p_args[4];
                        if (p_args.size() > 5) tile = (bool)p_args[5];
                        if (p_args.size() > 6) modulate = p_args[6];
                        ci->draw_texture_rect(tex, Rect2(x, y, w, h), tile, modulate);
                    }
                }
                r_found = true;
                return;
            }
            // DrawArc — DrawArc x, y, radius, startAngle, endAngle[, pointCount][, color][, width]
            //           DrawArc Vector2, radius, startAngle, endAngle[, pointCount][, color][, width]
            if (p_method.nocasecmp_to("DrawArc") == 0 && p_args.size() >= 4) {
                Color col = Color(1,1,1,1);
                float width = 1.0;
                int point_count = 32;
                if (p_args[0].get_type() == Variant::VECTOR2 && p_args.size() >= 4) {
                    // Godot style: center, radius, startAngle, endAngle[, pointCount][, color][, width]
                    Vector2 center = p_args[0];
                    float radius = p_args[1];
                    float start = p_args[2];
                    float end = p_args[3];
                    if (p_args.size() > 4) point_count = (int)p_args[4];
                    if (p_args.size() > 5) col = p_args[5];
                    if (p_args.size() > 6) width = p_args[6];
                    ci->draw_arc(center, radius, start, end, point_count, col, width);
                } else if (p_args.size() >= 5) {
                    // VG style: x, y, radius, startAngle, endAngle[, pointCount][, color][, width]
                    float x = p_args[0], y = p_args[1], radius = p_args[2];
                    float start = p_args[3], end = p_args[4];
                    if (p_args.size() > 5) point_count = (int)p_args[5];
                    if (p_args.size() > 6) col = p_args[6];
                    if (p_args.size() > 7) width = p_args[7];
                    ci->draw_arc(Vector2(x, y), radius, start, end, point_count, col, width);
                }
                r_found = true;
                return;
            }
            // DrawPolygon — DrawPolygon points, color
            //               (points is a PackedVector2Array or Array of Vector2)
            if (p_method.nocasecmp_to("DrawPolygon") == 0 && p_args.size() >= 2) {
                PackedVector2Array pts;
                if (p_args[0].get_type() == Variant::PACKED_VECTOR2_ARRAY) {
                    pts = p_args[0];
                } else if (p_args[0].get_type() == Variant::ARRAY) {
                    Array arr = p_args[0];
                    for (int i = 0; i < arr.size(); i++) pts.push_back(arr[i]);
                }
                if (pts.size() >= 3) {
                    Color col = p_args[1];
                    PackedColorArray colors;
                    colors.push_back(col);
                    ci->draw_polygon(pts, colors);
                }
                r_found = true;
                return;
            }
            // DrawPolyline — DrawPolyline points, color[, width]
            if (p_method.nocasecmp_to("DrawPolyline") == 0 && p_args.size() >= 2) {
                PackedVector2Array pts;
                if (p_args[0].get_type() == Variant::PACKED_VECTOR2_ARRAY) {
                    pts = p_args[0];
                } else if (p_args[0].get_type() == Variant::ARRAY) {
                    Array arr = p_args[0];
                    for (int i = 0; i < arr.size(); i++) pts.push_back(arr[i]);
                }
                if (pts.size() >= 2) {
                    Color col = p_args[1];
                    float width = 1.0;
                    if (p_args.size() > 2) width = p_args[2];
                    ci->draw_polyline(pts, col, width);
                }
                r_found = true;
                return;
            }
            // SetDrawTransform — SetDrawTransform x, y[, rotation][, scaleX, scaleY]
            if (p_method.nocasecmp_to("SetDrawTransform") == 0 && p_args.size() >= 2) {
                float x = p_args[0], y = p_args[1];
                float rot = 0.0;
                Vector2 sc = Vector2(1, 1);
                if (p_args.size() > 2) rot = p_args[2];
                if (p_args.size() > 4) { sc.x = p_args[3]; sc.y = p_args[4]; }
                Transform2D xform;
                xform.set_rotation_and_scale(rot, sc);
                xform.set_origin(Vector2(x, y));
                ci->draw_set_transform_matrix(xform);
                r_found = true;
                return;
            }
            // ResetDrawTransform — reset to identity
            if (p_method.nocasecmp_to("ResetDrawTransform") == 0) {
                ci->draw_set_transform_matrix(Transform2D());
                r_found = true;
                return;
            }
            // QueueRedraw — force a redraw next frame
            if (p_method.nocasecmp_to("QueueRedraw") == 0) {
                ci->queue_redraw();
                r_found = true;
                return;
            }
            // CLS / ClearScreen — clear the canvas and queue redraw
            if (p_method.nocasecmp_to("CLS") == 0 || p_method.nocasecmp_to("ClearScreen") == 0) {
                ci->queue_redraw();
                r_found = true;
                return;
            }
            // SetImagePixel — SetImagePixel image, x, y, color
            if (p_method.nocasecmp_to("SetImagePixel") == 0 && p_args.size() >= 4) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int x = (int)p_args[1], y = (int)p_args[2];
                        Color col = p_args[3];
                        if (x >= 0 && x < img->get_width() && y >= 0 && y < img->get_height()) {
                            img->set_pixel(x, y, col);
                        }
                    }
                }
                r_found = true;
                return;
            }
            // UpdateTexture — UpdateTexture texture, image
            // Updates an ImageTexture with modified Image data
            if (p_method.nocasecmp_to("UpdateTexture") == 0 && p_args.size() >= 2) {
                if (p_args[0].get_type() == Variant::OBJECT && p_args[1].get_type() == Variant::OBJECT) {
                    Ref<ImageTexture> tex = p_args[0];
                    Ref<Image> img = p_args[1];
                    if (tex.is_valid() && img.is_valid()) {
                        tex->update(img);
                    }
                }
                r_found = true;
                return;
            }
            // FillImage — FillImage image, color
            // Fills the entire image with a single color
            if (p_method.nocasecmp_to("FillImage") == 0 && p_args.size() >= 2) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        Color col = p_args[1];
                        img->fill(col);
                    }
                }
                r_found = true;
                return;
            }
            // FillImageRect — FillImageRect image, x, y, w, h, color
            //                 FillImageRect image, Rect2i, color
            if (p_method.nocasecmp_to("FillImageRect") == 0 && p_args.size() >= 3) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        if (p_args[1].get_type() == Variant::RECT2I && p_args.size() >= 3) {
                            Rect2i rect = p_args[1];
                            Color col = p_args[2];
                            img->fill_rect(rect, col);
                        } else if (p_args.size() >= 6) {
                            int x = (int)p_args[1], y = (int)p_args[2], w = (int)p_args[3], h = (int)p_args[4];
                            Color col = p_args[5];
                            img->fill_rect(Rect2i(x, y, w, h), col);
                        }
                    }
                }
                r_found = true;
                return;
            }
            // BlitImage — BlitImage destImage, srcImage, srcRect, destPos
            //             Copies a rectangular region from one image to another (like BitBlt / PaintPicture)
            if (p_method.nocasecmp_to("BlitImage") == 0 && p_args.size() >= 4) {
                if (p_args[0].get_type() == Variant::OBJECT && p_args[1].get_type() == Variant::OBJECT) {
                    Ref<Image> dst = p_args[0];
                    Ref<Image> src = p_args[1];
                    if (dst.is_valid() && src.is_valid()) {
                        Rect2i src_rect;
                        Vector2i dst_pos;
                        if (p_args[2].get_type() == Variant::RECT2I) {
                            src_rect = p_args[2];
                            dst_pos = p_args[3];
                        } else if (p_args.size() >= 8) {
                            // BlitImage dst, src, sx, sy, sw, sh, dx, dy
                            src_rect = Rect2i((int)p_args[2], (int)p_args[3], (int)p_args[4], (int)p_args[5]);
                            dst_pos = Vector2i((int)p_args[6], (int)p_args[7]);
                        }
                        dst->blit_rect(src, src_rect, dst_pos);
                    }
                }
                r_found = true;
                return;
            }
            // ── Native Image Drawing Builtins ─────────────────────────────────
            // These do pixel loops entirely in C++ for maximum speed.

            // DrawImageLine / Line — image, x1, y1, x2, y2, color[, width]
            // Bresenham line directly on an Image.
            //   "Line" is the VB6-style alias for "DrawImageLine".
            //   width=1 (default): single-pixel set_pixel per step
            //   width>1: stamps a filled rectangle (brush) centered on each step
            if ((p_method.nocasecmp_to("DrawImageLine") == 0 || p_method.nocasecmp_to("Line") == 0) && p_args.size() >= 6) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int x1 = (int)p_args[1], y1 = (int)p_args[2];
                        int x2 = (int)p_args[3], y2 = (int)p_args[4];
                        Color col = p_args[5];
                        int brush = (p_args.size() >= 7) ? (int)p_args[6] : 1;
                        if (brush < 1) brush = 1;
                        int w = img->get_width(), h = img->get_height();
                        int dx = abs(x2 - x1), dy = abs(y2 - y1);
                        int sx = (x1 < x2) ? 1 : -1;
                        int sy = (y1 < y2) ? 1 : -1;
                        int err = dx - dy;
                        int max_steps = dx + dy + 2;
                        int cx = x1, cy = y1;
                        while (max_steps-- > 0) {
                            if (brush <= 1) {
                                // Single-pixel line
                                if (cx >= 0 && cx < w && cy >= 0 && cy < h)
                                    img->set_pixel(cx, cy, col);
                            } else {
                                // Thick line: stamp a filled square (brush) at each point
                                int half = brush / 2;
                                int bx = cx - half, by = cy - half;
                                int bw = brush, bh = brush;
                                if (bx < 0) { bw += bx; bx = 0; }
                                if (by < 0) { bh += by; by = 0; }
                                if (bx + bw > w) bw = w - bx;
                                if (by + bh > h) bh = h - by;
                                if (bw > 0 && bh > 0)
                                    img->fill_rect(Rect2i(bx, by, bw, bh), col);
                            }
                            if (cx == x2 && cy == y2) break;
                            int e2 = 2 * err;
                            if (e2 > -dy) { err -= dy; cx += sx; }
                            if (e2 < dx)  { err += dx; cy += sy; }
                        }
                    }
                }
                r_found = true;
                return;
            }
            // DrawImageRect image, x1, y1, x2, y2, color
            // Draws a 1px outline rectangle on the Image using fill_rect for each edge
            if (p_method.nocasecmp_to("DrawImageRect") == 0 && p_args.size() >= 6) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int x1 = (int)p_args[1], y1 = (int)p_args[2];
                        int x2 = (int)p_args[3], y2 = (int)p_args[4];
                        Color col = p_args[5];
                        // Normalize
                        int lx = MIN(x1, x2), ly = MIN(y1, y2);
                        int rx = MAX(x1, x2), ry = MAX(y1, y2);
                        int iw = img->get_width(), ih = img->get_height();
                        // Clamp to image bounds
                        lx = CLAMP(lx, 0, iw - 1); rx = CLAMP(rx, 0, iw - 1);
                        ly = CLAMP(ly, 0, ih - 1); ry = CLAMP(ry, 0, ih - 1);
                        int rw = rx - lx + 1, rh = ry - ly + 1;
                        if (rw > 0 && rh > 0) {
                            img->fill_rect(Rect2i(lx, ly, rw, 1), col); // Top
                            img->fill_rect(Rect2i(lx, ry, rw, 1), col); // Bottom
                            img->fill_rect(Rect2i(lx, ly, 1, rh), col); // Left
                            img->fill_rect(Rect2i(rx, ly, 1, rh), col); // Right
                        }
                    }
                }
                r_found = true;
                return;
            }
            // DrawImageEllipse image, cx, cy, rx, ry, color
            // Midpoint ellipse algorithm entirely in C++
            if (p_method.nocasecmp_to("DrawImageEllipse") == 0 && p_args.size() >= 6) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int ecx = (int)p_args[1], ecy = (int)p_args[2];
                        int erx = (int)p_args[3], ery = (int)p_args[4];
                        Color col = p_args[5];
                        int iw = img->get_width(), ih = img->get_height();
                        if (erx < 1) erx = 1;
                        if (ery < 1) ery = 1;
                        auto set_px = [&](int px, int py) {
                            if (px >= 0 && px < iw && py >= 0 && py < ih)
                                img->set_pixel(px, py, col);
                        };
                        // Midpoint ellipse
                        int64_t rx2 = (int64_t)erx * erx, ry2 = (int64_t)ery * ery;
                        int64_t two_rx2 = 2 * rx2, two_ry2 = 2 * ry2;
                        int x = 0, y = ery;
                        int64_t px = 0, py = two_rx2 * y;
                        // Region 1
                        int64_t p1 = ry2 - rx2 * ery + rx2 / 4;
                        while (px < py) {
                            set_px(ecx + x, ecy + y); set_px(ecx - x, ecy + y);
                            set_px(ecx + x, ecy - y); set_px(ecx - x, ecy - y);
                            x++; px += two_ry2;
                            if (p1 < 0) { p1 += ry2 + px; }
                            else { y--; py -= two_rx2; p1 += ry2 + px - py; }
                        }
                        // Region 2
                        int64_t p2 = ry2 * ((int64_t)x * x + x) + ry2 / 4 + rx2 * ((int64_t)y - 1) * ((int64_t)y - 1) - rx2 * ry2;
                        while (y >= 0) {
                            set_px(ecx + x, ecy + y); set_px(ecx - x, ecy + y);
                            set_px(ecx + x, ecy - y); set_px(ecx - x, ecy - y);
                            y--; py -= two_rx2;
                            if (p2 > 0) { p2 += rx2 - py; }
                            else { x++; px += two_ry2; p2 += rx2 - py + px; }
                        }
                    }
                }
                r_found = true;
                return;
            }
            // DrawImageCircle / Circle — image, cx, cy, radius, color
            // "Circle" is the VB6-style alias for "DrawImageCircle".
            // Filled circle on an Image using scanlines
            if ((p_method.nocasecmp_to("DrawImageCircle") == 0 || p_method.nocasecmp_to("Circle") == 0) && p_args.size() >= 5) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int ccx = (int)p_args[1], ccy = (int)p_args[2], rad = (int)p_args[3];
                        Color col = p_args[4];
                        int iw = img->get_width(), ih = img->get_height();
                        for (int dy2 = -rad; dy2 <= rad; dy2++) {
                            int py2 = ccy + dy2;
                            if (py2 < 0 || py2 >= ih) continue;
                            int half_w = (int)Math::sqrt((double)(rad * rad - dy2 * dy2));
                            int x_start = MAX(0, ccx - half_w);
                            int x_end = MIN(iw - 1, ccx + half_w);
                            if (x_start <= x_end) {
                                img->fill_rect(Rect2i(x_start, py2, x_end - x_start + 1, 1), col);
                            }
                        }
                    }
                }
                r_found = true;
                return;
            }
            // DrawImageText image, x, y, text, color[, scale]
            // Renders text onto an Image using a built-in 5x7 bitmap font.
            // Each character is 5 pixels wide × 7 pixels tall with 1px spacing.
            // Optional scale parameter (default 1) for larger text.
            if (p_method.nocasecmp_to("DrawImageText") == 0 && p_args.size() >= 5) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int tx = (int)p_args[1], ty = (int)p_args[2];
                        String text = p_args[3];
                        Color col = p_args[4];
                        int scale = (p_args.size() >= 6) ? MAX(1, (int)p_args[5]) : 1;
                        int iw = img->get_width(), ih = img->get_height();
                        // Standard 5x7 bitmap font (ASCII 32-126), column-major, LSB = top row.
                        // Each character is 5 bytes (columns); each byte has 7 bits (rows).
                        static const uint8_t font5x7[][5] = {
                            {0x00,0x00,0x00,0x00,0x00}, // 32 space
                            {0x00,0x00,0x5F,0x00,0x00}, // 33 !
                            {0x00,0x07,0x00,0x07,0x00}, // 34 "
                            {0x14,0x7F,0x14,0x7F,0x14}, // 35 #
                            {0x24,0x2A,0x7F,0x2A,0x12}, // 36 $
                            {0x23,0x13,0x08,0x64,0x62}, // 37 %
                            {0x36,0x49,0x55,0x22,0x50}, // 38 &
                            {0x00,0x05,0x03,0x00,0x00}, // 39 '
                            {0x00,0x1C,0x22,0x41,0x00}, // 40 (
                            {0x00,0x41,0x22,0x1C,0x00}, // 41 )
                            {0x08,0x2A,0x1C,0x2A,0x08}, // 42 *
                            {0x08,0x08,0x3E,0x08,0x08}, // 43 +
                            {0x00,0x50,0x30,0x00,0x00}, // 44 ,
                            {0x08,0x08,0x08,0x08,0x08}, // 45 -
                            {0x00,0x60,0x60,0x00,0x00}, // 46 .
                            {0x20,0x10,0x08,0x04,0x02}, // 47 /
                            {0x3E,0x51,0x49,0x45,0x3E}, // 48 0
                            {0x00,0x42,0x7F,0x40,0x00}, // 49 1
                            {0x42,0x61,0x51,0x49,0x46}, // 50 2
                            {0x21,0x41,0x45,0x4B,0x31}, // 51 3
                            {0x18,0x14,0x12,0x7F,0x10}, // 52 4
                            {0x27,0x45,0x45,0x45,0x39}, // 53 5
                            {0x3C,0x4A,0x49,0x49,0x30}, // 54 6
                            {0x01,0x71,0x09,0x05,0x03}, // 55 7
                            {0x36,0x49,0x49,0x49,0x36}, // 56 8
                            {0x06,0x49,0x49,0x29,0x1E}, // 57 9
                            {0x00,0x36,0x36,0x00,0x00}, // 58 :
                            {0x00,0x56,0x36,0x00,0x00}, // 59 ;
                            {0x00,0x08,0x14,0x22,0x41}, // 60 <
                            {0x14,0x14,0x14,0x14,0x14}, // 61 =
                            {0x41,0x22,0x14,0x08,0x00}, // 62 >
                            {0x02,0x01,0x51,0x09,0x06}, // 63 ?
                            {0x32,0x49,0x79,0x41,0x3E}, // 64 @
                            {0x7E,0x11,0x11,0x11,0x7E}, // 65 A
                            {0x7F,0x49,0x49,0x49,0x36}, // 66 B
                            {0x3E,0x41,0x41,0x41,0x22}, // 67 C
                            {0x7F,0x41,0x41,0x22,0x1C}, // 68 D
                            {0x7F,0x49,0x49,0x49,0x41}, // 69 E
                            {0x7F,0x09,0x09,0x01,0x01}, // 70 F
                            {0x3E,0x41,0x41,0x51,0x32}, // 71 G
                            {0x7F,0x08,0x08,0x08,0x7F}, // 72 H
                            {0x00,0x41,0x7F,0x41,0x00}, // 73 I
                            {0x20,0x40,0x41,0x3F,0x01}, // 74 J
                            {0x7F,0x08,0x14,0x22,0x41}, // 75 K
                            {0x7F,0x40,0x40,0x40,0x40}, // 76 L
                            {0x7F,0x02,0x04,0x02,0x7F}, // 77 M
                            {0x7F,0x04,0x08,0x10,0x7F}, // 78 N
                            {0x3E,0x41,0x41,0x41,0x3E}, // 79 O
                            {0x7F,0x09,0x09,0x09,0x06}, // 80 P
                            {0x3E,0x41,0x51,0x21,0x5E}, // 81 Q
                            {0x7F,0x09,0x19,0x29,0x46}, // 82 R
                            {0x46,0x49,0x49,0x49,0x31}, // 83 S
                            {0x01,0x01,0x7F,0x01,0x01}, // 84 T
                            {0x3F,0x40,0x40,0x40,0x3F}, // 85 U
                            {0x1F,0x20,0x40,0x20,0x1F}, // 86 V
                            {0x7F,0x20,0x18,0x20,0x7F}, // 87 W
                            {0x63,0x14,0x08,0x14,0x63}, // 88 X
                            {0x03,0x04,0x78,0x04,0x03}, // 89 Y
                            {0x61,0x51,0x49,0x45,0x43}, // 90 Z
                            {0x00,0x00,0x7F,0x41,0x41}, // 91 [
                            {0x02,0x04,0x08,0x10,0x20}, // 92 backslash
                            {0x41,0x41,0x7F,0x00,0x00}, // 93 ]
                            {0x04,0x02,0x01,0x02,0x04}, // 94 ^
                            {0x40,0x40,0x40,0x40,0x40}, // 95 _
                            {0x00,0x01,0x02,0x04,0x00}, // 96 `
                            {0x20,0x54,0x54,0x54,0x78}, // 97 a
                            {0x7F,0x48,0x44,0x44,0x38}, // 98 b
                            {0x38,0x44,0x44,0x44,0x20}, // 99 c
                            {0x38,0x44,0x44,0x48,0x7F}, // 100 d
                            {0x38,0x54,0x54,0x54,0x18}, // 101 e
                            {0x08,0x7E,0x09,0x01,0x02}, // 102 f
                            {0x08,0x14,0x54,0x54,0x3C}, // 103 g
                            {0x7F,0x08,0x04,0x04,0x78}, // 104 h
                            {0x00,0x44,0x7D,0x40,0x00}, // 105 i
                            {0x20,0x40,0x44,0x3D,0x00}, // 106 j
                            {0x00,0x7F,0x10,0x28,0x44}, // 107 k
                            {0x00,0x41,0x7F,0x40,0x00}, // 108 l
                            {0x7C,0x04,0x18,0x04,0x78}, // 109 m
                            {0x7C,0x08,0x04,0x04,0x78}, // 110 n
                            {0x38,0x44,0x44,0x44,0x38}, // 111 o
                            {0x7C,0x14,0x14,0x14,0x08}, // 112 p
                            {0x08,0x14,0x14,0x18,0x7C}, // 113 q
                            {0x7C,0x08,0x04,0x04,0x08}, // 114 r
                            {0x48,0x54,0x54,0x54,0x20}, // 115 s
                            {0x04,0x3F,0x44,0x40,0x20}, // 116 t
                            {0x3C,0x40,0x40,0x20,0x7C}, // 117 u
                            {0x1C,0x20,0x40,0x20,0x1C}, // 118 v
                            {0x3C,0x40,0x30,0x40,0x3C}, // 119 w
                            {0x44,0x28,0x10,0x28,0x44}, // 120 x
                            {0x0C,0x50,0x50,0x50,0x3C}, // 121 y
                            {0x44,0x64,0x54,0x4C,0x44}, // 122 z
                            {0x00,0x08,0x36,0x41,0x00}, // 123 {
                            {0x00,0x00,0x7F,0x00,0x00}, // 124 |
                            {0x00,0x41,0x36,0x08,0x00}, // 125 }
                            {0x02,0x01,0x02,0x04,0x02}, // 126 ~
                        };
                        for (int ci = 0; ci < text.length(); ci++) {
                            char32_t ch = text[ci];
                            if (ch < 32 || ch > 126) ch = '?'; // Unmapped → '?'
                            int idx = (int)(ch - 32);
                            int char_x = tx + ci * 6 * scale; // 5px char + 1px gap
                            for (int col_i = 0; col_i < 5; col_i++) {
                                uint8_t column = font5x7[idx][col_i];
                                for (int row = 0; row < 7; row++) {
                                    if (column & (1 << row)) {
                                        // Pixel is set — draw it (with scaling)
                                        for (int sy = 0; sy < scale; sy++) {
                                            for (int sx = 0; sx < scale; sx++) {
                                                int px = char_x + col_i * scale + sx;
                                                int py = ty + row * scale + sy;
                                                if (px >= 0 && px < iw && py >= 0 && py < ih) {
                                                    img->set_pixel(px, py, col);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                r_found = true;
                return;
            }
            // FloodFillImage image, x, y, color
            // Stack-based flood fill entirely in C++ for maximum speed.
            // Replaces all connected pixels of the target color with the fill color.
            if (p_method.nocasecmp_to("FloodFillImage") == 0 && p_args.size() >= 4) {
                if (p_args[0].get_type() == Variant::OBJECT) {
                    Ref<Image> img = p_args[0];
                    if (img.is_valid()) {
                        int sx = (int)p_args[1], sy = (int)p_args[2];
                        Color fill_col = p_args[3];
                        int iw = img->get_width(), ih = img->get_height();
                        if (sx >= 0 && sx < iw && sy >= 0 && sy < ih) {
                            Color target_col = img->get_pixel(sx, sy);
                            // Don't fill if target == fill (avoid infinite loop)
                            if (!target_col.is_equal_approx(fill_col)) {
                                // Stack-based 4-connected flood fill
                                // Use a vector as a stack (much faster than script arrays)
                                struct Pt { int x, y; };
                                Vector<Pt> stack;
                                stack.push_back({sx, sy});
                                // Tolerance for color comparison (avoids float precision issues)
                                const float tol = 1.0f / 512.0f;
                                int max_iterations = iw * ih; // absolute safety limit
                                while (stack.size() > 0 && max_iterations-- > 0) {
                                    Pt p = stack[stack.size() - 1];
                                    stack.resize(stack.size() - 1);
                                    if (p.x < 0 || p.x >= iw || p.y < 0 || p.y >= ih) continue;
                                    Color pc = img->get_pixel(p.x, p.y);
                                    if (Math::abs(pc.r - target_col.r) > tol ||
                                        Math::abs(pc.g - target_col.g) > tol ||
                                        Math::abs(pc.b - target_col.b) > tol ||
                                        Math::abs(pc.a - target_col.a) > tol) continue;
                                    img->set_pixel(p.x, p.y, fill_col);
                                    stack.push_back({p.x + 1, p.y});
                                    stack.push_back({p.x - 1, p.y});
                                    stack.push_back({p.x, p.y + 1});
                                    stack.push_back({p.x, p.y - 1});
                                }
                            }
                        }
                    }
                }
                r_found = true;
                return;
            }
        }
    }
    if (owner) {
        Node *n = Object::cast_to<Node>(owner);
        if (n) {
            if (p_method.nocasecmp_to("PlaySound") == 0 && p_args.size() >= 1) {
                String path = p_args[0];
                Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                if (stream.is_valid()) {
                    AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                    p->set_stream(stream);
                    p->set_autoplay(true);
                    // Optional volume parameter (0-100 percent, default 100)
                    if (p_args.size() >= 2) {
                        double vol_pct = (double)p_args[1];
                        if (vol_pct <= 0.0) {
                            p->set_volume_db(-60.0);
                        } else {
                            p->set_volume_db(20.0 * log10(vol_pct / 100.0));
                        }
                    }
                    p->connect("finished", Callable(p, "queue_free"));
                    n->add_child(p);
                }
                r_found = true;
                return;
            }

            if (p_method.nocasecmp_to("PlayTone") == 0 && p_args.size() >= 2) {
                double freq = (double)p_args[0];
                double dur_ms = (double)p_args[1];
                int waveform = 0; // Sine default
                if (p_args.size() >= 3) waveform = (int)p_args[2];

                Ref<AudioStreamWAV> stream;
                stream.instantiate();

                int mix_rate = 44100;
                stream->set_mix_rate(mix_rate);
                stream->set_format(AudioStreamWAV::FORMAT_16_BITS);
                stream->set_stereo(false);

                int samples = (int)(dur_ms * mix_rate / 1000.0);
                if (samples > 0) {
                    PackedByteArray data;
                    data.resize(samples * 2);

                    // Envelope: 5ms fade-in, 30ms fade-out to prevent click/pop
                    int fade_in_samples = (int)(0.005 * mix_rate);
                    int fade_out_samples = (int)(0.030 * mix_rate);
                    if (fade_in_samples > samples / 2) fade_in_samples = samples / 2;
                    if (fade_out_samples > samples / 2) fade_out_samples = samples / 2;

                    for (int i = 0; i < samples; ++i) {
                        double t = (double)i / mix_rate;
                        double val = 0.0;
                        const double PI = 3.14159265358979323846;

                        switch (waveform) {
                            case 1: val = (sin(2.0 * PI * freq * t) > 0) ? 1.0 : -1.0; break;
                            case 2: val = 2.0 * (t * freq - floor(t * freq + 0.5)); break;
                            case 3: val = ((double)rand() / RAND_MAX) * 2.0 - 1.0; break;
                            default: val = sin(2.0 * PI * freq * t); break;
                        }

                        // Apply envelope
                        double envelope = 1.0;
                        if (i < fade_in_samples) {
                            envelope = (double)i / fade_in_samples;
                        } else if (i >= samples - fade_out_samples) {
                            envelope = (double)(samples - 1 - i) / fade_out_samples;
                        }
                        val *= 0.2 * envelope;
                        int16_t sample_int = (int16_t)(val * 32767.0);
                        data[i * 2] = (uint8_t)(sample_int & 0xFF);
                        data[i * 2 + 1] = (uint8_t)((sample_int >> 8) & 0xFF);
                    }
                    stream->set_data(data);
                }

                // Polyphony limiter: stop oldest PlayTone players if too many active
                const int MAX_TONE_VOICES = 4;
                Vector<AudioStreamPlayer *> active_tones;
                for (int ci = 0; ci < n->get_child_count(); ci++) {
                    AudioStreamPlayer *asp = Object::cast_to<AudioStreamPlayer>(n->get_child(ci));
                    if (asp && asp->has_meta("__playtone__")) {
                        active_tones.push_back(asp);
                    }
                }
                while (active_tones.size() >= MAX_TONE_VOICES) {
                    active_tones[0]->stop();
                    active_tones[0]->queue_free();
                    active_tones.remove_at(0);
                }

                AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                p->set_stream(stream);
                p->set_autoplay(true);
                p->set_meta("__playtone__", true);
                p->connect("finished", Callable(p, "queue_free"));
                n->add_child(p);

                r_found = true;
                return;
            }
        }
    }

    r_found = false;
}

const GDExtensionPropertyInfo *VisualGasicInstance::get_property_list(uint32_t *r_count) {
    if (!script.is_valid() || !script->ast_root) {
        *r_count = 0;
        return nullptr;
    }
    
    // We only list PUBLIC variables here
    Vector<VariableDefinition*> public_vars;
    for(int i=0; i<script->ast_root->variables.size(); i++) {
        if (script->ast_root->variables[i]->visibility == VIS_PUBLIC) {
            public_vars.push_back(script->ast_root->variables[i]);
        }
    }
    
    *r_count = public_vars.size();
    if (*r_count == 0) return nullptr;
    
    GDExtensionPropertyInfo *list = (GDExtensionPropertyInfo *)memalloc(sizeof(GDExtensionPropertyInfo) * (*r_count));
    ERR_FAIL_NULL_V_MSG(list, nullptr, "VisualGasic: memalloc failed in get_property_list");
    
    for(uint32_t i=0; i<*r_count; i++) {
        VariableDefinition* v = public_vars[i];
        String name = v->name;
        String type = v->type.to_lower();
        
        list[i].name = memnew(StringName(name)); // StringName* ? No, structure has void* name
        // Wait, GDExtensionPropertyInfo structure:
        // GDExtensionStringNamePtr name;
        // GDExtensionVariantType type;
        // GDExtensionStringNamePtr class_name;
        // GDExtensionPropertyHint hint;
        // GDExtensionStringPtr hint_string;
        // uint32_t usage;
        
        // This memory management is tricky. We need to allocate StringNames that persist?
        // Actually, usually we return a C array.
        // Godot explicitly calls free_property_list.
        
        // The GDExtension C API expects pointers to opaque types.
        // We must construct them.
        
        // name
        StringName *sn = memnew(StringName(name));
        list[i].name = sn;
        
        // type
        if (type == "integer") list[i].type = GDEXTENSION_VARIANT_TYPE_INT;
        else if (type == "single" || type == "double") list[i].type = GDEXTENSION_VARIANT_TYPE_FLOAT;
        else if (type == "string") list[i].type = GDEXTENSION_VARIANT_TYPE_STRING;
        else if (type == "boolean") list[i].type = GDEXTENSION_VARIANT_TYPE_BOOL;
        else list[i].type = GDEXTENSION_VARIANT_TYPE_NIL;
        
        // class_name
        list[i].class_name = memnew(StringName());
        
        // hint
        list[i].hint = PROPERTY_HINT_NONE;
        
        // hint_string
        list[i].hint_string = memnew(String());
        
        // usage
        list[i].usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE;
    }
    
    return list;
}

void VisualGasicInstance::free_property_list(const GDExtensionPropertyInfo *p_list, uint32_t p_count) {
    if (p_list) {
        for(uint32_t i=0; i<p_count; i++) {
             memdelete((StringName*)p_list[i].name);
             memdelete((StringName*)p_list[i].class_name);
             memdelete((String*)p_list[i].hint_string);
        }
        memfree((void*)p_list);
    }
}

Variant::Type VisualGasicInstance::get_property_type(const StringName &p_name, bool *r_is_valid) {
    *r_is_valid = false;
    return Variant::NIL;
}

bool VisualGasicInstance::validate_property(GDExtensionPropertyInfo *p_property) {
    return false;
}

bool VisualGasicInstance::property_can_revert(const StringName &p_name) {
    return false;
}

bool VisualGasicInstance::property_get_revert(const StringName &p_name, Variant &r_ret) {
    return false;
}

Object *VisualGasicInstance::get_owner() {
    return owner;
}

Ref<Script> VisualGasicInstance::get_script() {
    return script;
}

bool VisualGasicInstance::is_placeholder() {
    if (!script.is_valid()) return true;
    return script->has_reload_errors();
}

// ============================================================================
// VB6-style Variant formatting for Immediate Window output.
// - Whole floats → integer string (100.0 → "100")
// - Booleans → "True" / "False"
// - Integers → no trailing ".0"
// ============================================================================
static String _vb6_format_variant(const Variant &val) {
    switch (val.get_type()) {
        case Variant::BOOL:
            return (bool)val ? "True" : "False";
        case Variant::FLOAT: {
            double d = (double)val;
            if (Math::is_finite(d) && d == Math::floor(d)) {
                return String::num_int64((int64_t)d);
            }
            return String::num(d);
        }
        case Variant::INT:
            return String::num_int64((int64_t)val);
        default:
            return String(val);
    }
}

// ============================================================================
// Immediate Window evaluation — parse & execute a VB snippet on this instance
// ============================================================================
Dictionary VisualGasicInstance::evaluate_immediate(const String &p_code) {
    Dictionary result;
    result["success"] = false;
    result["result"] = "";

    String trimmed = p_code.strip_edges();
    if (trimmed.is_empty()) {
        result["success"] = true;
        return result;
    }

    String upper = trimmed.to_upper();

    // ---- Normalize commands with no space before arguments --------------------
    // VB6 allows e.g. msgbox"test" or print"hello" (no space).  Insert a space
    // after the keyword so the tokenizer/parser can handle it correctly.
    static const char* keyword_cmds[] = {
        "PRINT", "MSGBOX", "DEBUG.PRINT", "INPUT", "OPEN", nullptr
    };
    for (int k = 0; keyword_cmds[k]; k++) {
        String kw = keyword_cmds[k];
        if (upper.begins_with(kw) && trimmed.length() > kw.length()) {
            char32_t next_ch = trimmed[kw.length()];
            if (next_ch != ' ' && next_ch != '\t' && next_ch != '(') {
                // Insert space: "msgbox"test"" → "msgbox "test""
                trimmed = trimmed.substr(0, kw.length()) + " " + trimmed.substr(kw.length());
                upper = trimmed.to_upper();
                break;
            }
        }
    }

    // ---- Print / ? — variable or expression ----------------------------------
    bool is_print = upper.begins_with("PRINT ") || trimmed.begins_with("? ");
    if (is_print) {
        String arg = trimmed.begins_with("? ") ? trimmed.substr(2).strip_edges()
                                                 : trimmed.substr(6).strip_edges();
        // String literal
        if ((arg.begins_with("\"") && arg.ends_with("\"")) ||
            (arg.begins_with("'") && arg.ends_with("'"))) {
            result["success"] = true;
            result["result"] = arg.substr(1, arg.length() - 2);
            return result;
        }
        // Direct variable lookup
        Variant val;
        if (get_variable(arg, val)) {
            result["success"] = true;
            result["result"] = _vb6_format_variant(val);
            return result;
        }
        // Array indexing: e.g. filtered(1), Objects("key")
        if (arg.contains("(") && arg.ends_with(")")) {
            int paren_pos = arg.find("(");
            String base_name = arg.substr(0, paren_pos);
            String index_str = arg.substr(paren_pos + 1, arg.length() - paren_pos - 2).strip_edges();
            Variant base_val;
            if (get_variable(base_name, base_val)) {
                if (base_val.get_type() == Variant::ARRAY && index_str.is_valid_int()) {
                    Array arr = base_val;
                    int idx = index_str.to_int();
                    if (idx >= 0 && idx < arr.size()) {
                        result["success"] = true;
                        result["result"] = _vb6_format_variant(arr[idx]);
                        return result;
                    } else {
                        result["success"] = false;
                        result["result"] = "Subscript out of range: " + String::num_int64(idx);
                        return result;
                    }
                } else if (base_val.get_type() == Variant::DICTIONARY) {
                    Dictionary dict = base_val;
                    // Try string key (strip quotes) or numeric key
                    Variant key;
                    if ((index_str.begins_with("\"") && index_str.ends_with("\"")) ||
                        (index_str.begins_with("'") && index_str.ends_with("'"))) {
                        key = index_str.substr(1, index_str.length() - 2);
                    } else if (index_str.is_valid_int()) {
                        key = index_str.to_int();
                    } else {
                        key = index_str;
                    }
                    if (dict.has(key)) {
                        result["success"] = true;
                        result["result"] = _vb6_format_variant(dict[key]);
                        return result;
                    }
                }
            }
        }
        // Try evaluating as a numeric literal or simple expression
        // For numeric literals, return directly
        if (arg.is_valid_int()) {
            result["success"] = true;
            result["result"] = arg;
            return result;
        }
        if (arg.is_valid_float()) {
            result["success"] = true;
            result["result"] = arg;
            return result;
        }
        // For complex expressions (e.g. 1+2, Len(x)), use temp variable trick
        // Wrap in a Sub so the parser handles assignments, member access, etc.
        {
            VisualGasicTokenizer et;
            VisualGasicParser ep;
            String eval_code = "Sub __imm_eval__\n__imm_result__ = " + arg + "\nEnd Sub";
            Vector<VisualGasicTokenizer::Token> et_tokens = et.tokenize(eval_code);
            ModuleNode* em = ep.parse(et_tokens);
            SubDefinition* eval_sub = nullptr;
            if (em) {
                for (int i = 0; i < em->subs.size(); i++) {
                    if (em->subs[i]->name.nocasecmp_to("__imm_eval__") == 0) {
                        eval_sub = em->subs[i];
                        break;
                    }
                }
            }
            if (eval_sub && ep.errors.size() == 0 && eval_sub->statements.size() > 0) {
                for (int i = 0; i < eval_sub->statements.size(); i++) {
                    execute_statement(eval_sub->statements[i]);
                }
                Variant tmp_val;
                if (get_variable("__imm_result__", tmp_val)) {
                    result["success"] = true;
                    result["result"] = _vb6_format_variant(tmp_val);
                    delete em;
                    return result;
                }
            }
            if (em) delete em;
        }
        // Fall through to general parse+execute below
    }

    // ---- General: tokenize → parse → execute ---------------------------------
    // Wrap in a dummy Sub so the parser treats the code as statement-level
    // (module-level only allows declarations, not executable statements like MsgBox).
    String wrapped = "Sub __imm__\n" + trimmed + "\nEnd Sub";
    VisualGasicTokenizer tokenizer;
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(wrapped);
    VisualGasicParser parser;
    ModuleNode* mod = parser.parse(tokens);

    // Find the dummy sub and execute its body statements
    SubDefinition* imm_sub = nullptr;
    if (mod) {
        for (int i = 0; i < mod->subs.size(); i++) {
            if (mod->subs[i]->name.nocasecmp_to("__imm__") == 0) {
                imm_sub = mod->subs[i];
                break;
            }
        }
    }

    if (imm_sub && parser.errors.size() == 0 && imm_sub->statements.size() > 0) {
        for (int i = 0; i < imm_sub->statements.size(); i++) {
            execute_statement(imm_sub->statements[i]);
        }
        result["success"] = true;
        result["result"] = "OK";
    } else if (mod && parser.errors.size() > 0) {
        // Parse failed — maybe it's a bare variable name
        Variant val;
        if (get_variable(trimmed, val)) {
            result["success"] = true;
            result["result"] = _vb6_format_variant(val);
        } else {
            result["success"] = false;
            result["result"] = "Parse error: " + parser.errors[0].message;
        }
    } else {
        Variant val;
        if (get_variable(trimmed, val)) {
            result["success"] = true;
            result["result"] = _vb6_format_variant(val);
        } else {
            result["success"] = false;
            result["result"] = "Cannot evaluate: " + trimmed;
        }
    }

    if (mod) delete mod;
    return result;
}


// ============================================================================
// Shared VB6 Property Alias Helpers
// Called from both AST interpreter (evaluate.inc / call.inc) and bytecode VM.
// ============================================================================

// ============================================================================
// StringName-hashed property dispatch — O(1) lookup via HashMap
// ============================================================================
static int _vb6_prop_id(const String& name) {
    static HashMap<StringName, int> map;
    if (map.is_empty()) {
        // Build once — StringName keys are interned for O(1) comparison
        const struct { const char* name; int id; } entries[] = {
            {"Text",1}, {"Caption",1}, {"Visible",2}, {"Enabled",3},
            {"Left",4}, {"Top",5}, {"Width",6}, {"Height",7},
            {"Value",8}, {"ToolTipText",9}, {"TabStop",10}, {"Opacity",11},
            {"MousePointer",12}, {"Locked",13}, {"MaxLength",14},
            {"Alignment",15}, {"WordWrap",16}, {"FontSize",17},
            {"ForeColor",18}, {"BackColor",19}, {"FontBold",20},
            {"FontItalic",21}, {"FontName",22}, {"FontUnderline",23},
            {"FontStrikethrough",24}, {"BorderStyle",25}, {"Style",26},
            {"Flat",26}, {"MultiLine",27}, {"ScrollBars",28},
            {"PasswordChar",29}, {"PlaceholderText",30}, {"Editable",31},
            {"SelStart",32}, {"SelLength",33}, {"SelText",34},
            {"Picture",35}, {"Icon",36}, {"Tag",37}, {"Interval",38},
            {"OneShot",39}, {"Autostart",40}, {"ListCount",41},
            {"ListIndex",42}, {"Sorted",43}, {"AutoSize",44},
            {"ClipText",45}, {"WindowState",46}, {"ShowInTaskbar",47},
            {"Moveable",48}, {"MinButton",49}, {"MaxButton",50},
            {"ControlBox",51}, {"ZOrder",52}, {"Rotation",53},
            {"hWnd",54}, {"Name",55},
            // New properties (v4.4.0)
            {"BackStyle",56}, {"Appearance",57}, {"TabIndex",58},
            {"Parent",59}, {"Container",60}, {"Index",61}, {"DragMode",62},
        };
        for (const auto& e : entries) {
            map[StringName(e.name)] = e.id;
        }
    }
    const int* p = map.getptr(StringName(name));
    return p ? *p : -1;
}

// VB6 property READ alias resolution.
// Returns true if the property was handled; result is set to the value.
static bool _vb6_read_property(Object* obj, const String& prop_name, Variant& result) {
    if (!obj) return false;
    // O(1) fast-reject for unknown property names
    if (_vb6_prop_id(prop_name) < 0) return false;

    // Text / Caption
    if (prop_name == "Text" || prop_name == "Caption") {
        result = obj->get("text");
        return true;
    }
    // Visible
    if (prop_name == "Visible") {
        result = obj->get("visible");
        return true;
    }
    // Enabled (invert disabled; fallback editable)
    if (prop_name == "Enabled") {
        if (Object::cast_to<Timer>(obj)) {
            return false; // Timer.Enabled handled separately by AST
        }
        Variant disabled_val = obj->get(StringName("disabled"));
        if (disabled_val.get_type() == Variant::BOOL) { result = !(bool)disabled_val; return true; }
        Variant editable_val = obj->get(StringName("editable"));
        if (editable_val.get_type() == Variant::BOOL) { result = (bool)editable_val; return true; }
        result = true;
        return true;
    }
    // Position
    if (prop_name == "Left") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_position().x; return true; }
        Node2D* n2d = Object::cast_to<Node2D>(obj);
        if (n2d) { result = n2d->get_position().x; return true; }
    }
    if (prop_name == "Top") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_position().y; return true; }
        Node2D* n2d = Object::cast_to<Node2D>(obj);
        if (n2d) { result = n2d->get_position().y; return true; }
    }
    // Size
    if (prop_name == "Width") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_size().x; return true; }
    }
    if (prop_name == "Height") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_size().y; return true; }
    }
    // Value
    if (prop_name == "Value") {
        result = obj->get("value");
        return true;
    }
    // ToolTipText
    if (prop_name == "ToolTipText") {
        result = obj->get("tooltip_text");
        return true;
    }
    // TabStop → focus_mode
    if (prop_name == "TabStop") {
        int fm = (int)obj->get("focus_mode");
        result = (fm != 0);
        return true;
    }
    // Opacity → modulate.a (0-100)
    if (prop_name == "Opacity") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = (int)(ctrl->get_modulate().a * 100.0f); return true; }
    }
    // MousePointer
    if (prop_name == "MousePointer") {
        result = obj->get("mouse_default_cursor_shape");
        return true;
    }
    // Locked → !editable
    if (prop_name == "Locked") {
        Variant ed = obj->get("editable");
        if (ed.get_type() == Variant::BOOL) { result = !(bool)ed; } else { result = false; }
        return true;
    }
    // MaxLength
    if (prop_name == "MaxLength") {
        result = obj->get("max_length");
        return true;
    }
    // Alignment
    if (prop_name == "Alignment") {
        result = obj->get("horizontal_alignment");
        return true;
    }
    // WordWrap
    if (prop_name == "WordWrap") {
        int mode = (int)obj->get("autowrap_mode");
        result = (mode != 0);
        return true;
    }
    // FontSize
    if (prop_name == "FontSize") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_theme_font_size("font_size"); return true; }
    }
    // ForeColor
    if (prop_name == "ForeColor") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = ctrl->get_theme_color("font_color"); return true; }
    }
    // BackColor
    if (prop_name == "BackColor") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (!ctrl) {
            Window* win = Object::cast_to<Window>(obj);
            if (win) {
                Node* bg = win->find_child("_FormBackground", false, false);
                if (bg) ctrl = Object::cast_to<Control>(bg);
            }
        }
        if (ctrl) {
            String sb_name = (ctrl->get_class() == "Panel") ? "panel" : "normal";
            Ref<StyleBox> sb = ctrl->get_theme_stylebox(sb_name);
            if (sb.is_valid()) {
                Ref<StyleBoxFlat> sbf = sb;
                if (sbf.is_valid()) { result = sbf->get_bg_color(); return true; }
            }
            result = ctrl->get_self_modulate();
            return true;
        }
    }
    // FontBold
    if (prop_name == "FontBold") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            if (fnt.is_valid()) {
                Ref<FontVariation> fv = fnt;
                if (fv.is_valid()) { result = fv->get_variation_embolden() > 0.0f; return true; }
                Ref<SystemFont> sf = fnt;
                if (sf.is_valid()) {
                    PackedStringArray names = sf->get_font_names();
                    result = false;
                    for (int fi = 0; fi < names.size(); fi++) {
                        if (String(names[fi]).findn("Bold") >= 0) { result = true; break; }
                    }
                    return true;
                }
            }
            result = false;
            return true;
        }
    }
    // FontItalic
    if (prop_name == "FontItalic") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            if (fnt.is_valid()) {
                Ref<FontVariation> fv = fnt;
                if (fv.is_valid()) {
                    Transform2D t = fv->get_variation_transform();
                    result = (t[0][1] != 0.0f);
                    return true;
                }
                Ref<SystemFont> sf = fnt;
                if (sf.is_valid()) { result = sf->get_font_italic(); return true; }
            }
            result = false;
            return true;
        }
    }
    // FontName
    if (prop_name == "FontName") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            if (fnt.is_valid()) {
                Ref<FontVariation> fv = fnt;
                if (fv.is_valid()) {
                    Ref<Font> base = fv->get_base_font();
                    Ref<SystemFont> sf = base;
                    if (sf.is_valid()) {
                        PackedStringArray names = sf->get_font_names();
                        result = names.size() > 0 ? String(names[0]) : String("");
                        return true;
                    }
                } else {
                    Ref<SystemFont> sf = fnt;
                    if (sf.is_valid()) {
                        PackedStringArray names = sf->get_font_names();
                        result = names.size() > 0 ? String(names[0]) : String("");
                        return true;
                    }
                }
            }
            result = String("");
            return true;
        }
    }
    // FontUnderline / FontStrikethrough (meta)
    if (prop_name == "FontUnderline") {
        result = obj->has_meta("vg_font_underline") ? (bool)obj->get_meta("vg_font_underline") : false;
        return true;
    }
    if (prop_name == "FontStrikethrough") {
        result = obj->has_meta("vg_font_strikethrough") ? (bool)obj->get_meta("vg_font_strikethrough") : false;
        return true;
    }
    // BorderStyle
    if (prop_name == "BorderStyle") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<StyleBox> sb = ctrl->get_theme_stylebox("normal");
            Ref<StyleBoxFlat> sbf = sb;
            if (sbf.is_valid()) {
                result = (sbf->get_border_width(SIDE_LEFT) > 0 || sbf->get_border_width(SIDE_TOP) > 0 ||
                          sbf->get_border_width(SIDE_RIGHT) > 0 || sbf->get_border_width(SIDE_BOTTOM) > 0) ? 1 : 0;
            } else { result = 0; }
            return true;
        }
    }
    // Style / Flat (Button)
    if (prop_name == "Style" || prop_name == "Flat") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) { result = btn->is_flat(); return true; }
    }
    // MultiLine
    if (prop_name == "MultiLine") {
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        result = (te != nullptr);
        return true;
    }
    // ScrollBars (TextEdit meta)
    if (prop_name == "ScrollBars") {
        if (obj->has_meta("vg_scrollbars")) {
            result = (int)obj->get_meta("vg_scrollbars");
        } else {
            result = 2; // default vertical
        }
        return true;
    }
    // PasswordChar
    if (prop_name == "PasswordChar") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) {
            if (le->is_secret()) {
                result = String(le->get("secret_character"));
            } else { result = String(""); }
            return true;
        }
    }
    // PlaceholderText
    if (prop_name == "PlaceholderText") {
        result = obj->get("placeholder_text");
        return true;
    }
    // Editable
    if (prop_name == "Editable") {
        Variant ed = obj->get("editable");
        if (ed.get_type() == Variant::BOOL) { result = ed; } else { result = true; }
        return true;
    }
    // SelStart
    if (prop_name == "SelStart") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) { result = le->get_caret_column(); return true; }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) { result = te->get_caret_column(); return true; }
    }
    // SelLength
    if (prop_name == "SelLength") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) { result = le->has_selection() ? (int)le->get_selected_text().length() : 0; return true; }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) { result = (int)te->get_selected_text().length(); return true; }
    }
    // SelText
    if (prop_name == "SelText") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) { result = le->get_selected_text(); return true; }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) { result = te->get_selected_text(); return true; }
    }
    // Picture
    if (prop_name == "Picture") {
        TextureRect* tr = Object::cast_to<TextureRect>(obj);
        if (tr) { result = Variant(tr->get_texture()); return true; }
        if (obj->has_meta("vg_picture_path")) { result = obj->get_meta("vg_picture_path"); return true; }
    }
    // Icon
    if (prop_name == "Icon") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) { result = Variant(btn->get_button_icon()); return true; }
    }
    // Tag
    if (prop_name == "Tag") {
        result = obj->has_meta("vg_tag") ? obj->get_meta("vg_tag") : Variant();
        return true;
    }
    // Timer: Interval (ms), OneShot, Autostart
    if (prop_name == "Interval") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { result = (int)(tmr->get_wait_time() * 1000.0); return true; }
    }
    if (prop_name == "OneShot") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { result = tmr->is_one_shot(); return true; }
    }
    if (prop_name == "Autostart") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { result = tmr->has_autostart(); return true; }
    }
    // ListCount
    if (prop_name == "ListCount") {
        ItemList* il = Object::cast_to<ItemList>(obj);
        if (il) { result = il->get_item_count(); return true; }
        OptionButton* ob = Object::cast_to<OptionButton>(obj);
        if (ob) { result = ob->get_item_count(); return true; }
    }
    // ListIndex
    if (prop_name == "ListIndex") {
        ItemList* il = Object::cast_to<ItemList>(obj);
        if (il) {
            PackedInt32Array sel = il->get_selected_items();
            result = sel.size() > 0 ? (int)sel[0] : -1;
            return true;
        }
        OptionButton* ob = Object::cast_to<OptionButton>(obj);
        if (ob) { result = ob->get_selected(); return true; }
    }
    // Sorted
    if (prop_name == "Sorted") {
        result = obj->has_meta("vg_sorted") ? (bool)obj->get_meta("vg_sorted") : false;
        return true;
    }
    // AutoSize (Label)
    if (prop_name == "AutoSize") {
        Label* lbl = Object::cast_to<Label>(obj);
        if (lbl) {
            result = (lbl->get_autowrap_mode() == TextServer::AUTOWRAP_OFF && !lbl->is_clipping_text());
            return true;
        }
    }
    // ClipText (Button)
    if (prop_name == "ClipText") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) { result = btn->get_clip_text(); return true; }
    }
    // Window properties
    if (prop_name == "WindowState") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) {
            if (win->get_mode() == Window::MODE_MINIMIZED) result = 1;
            else if (win->get_mode() == Window::MODE_MAXIMIZED) result = 2;
            else result = 0;
            return true;
        }
    }
    if (prop_name == "ShowInTaskbar") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { result = !win->get_flag(Window::FLAG_NO_FOCUS); return true; }
    }
    if (prop_name == "Moveable") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { result = !win->get_flag(Window::FLAG_RESIZE_DISABLED); return true; }
    }
    if (prop_name == "MinButton" || prop_name == "MaxButton") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { result = !win->get_flag(Window::FLAG_RESIZE_DISABLED); return true; }
    }
    if (prop_name == "ControlBox") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { result = !win->get_flag(Window::FLAG_BORDERLESS); return true; }
    }
    // ZOrder
    if (prop_name == "ZOrder") {
        result = obj->get("z_index");
        return true;
    }
    // Rotation (degrees)
    if (prop_name == "Rotation") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { result = Math::rad_to_deg(ctrl->get_rotation()); return true; }
    }
    // hWnd
    if (prop_name == "hWnd") {
        result = (int64_t)obj->get_instance_id();
        return true;
    }
    // Name
    if (prop_name == "Name") {
        Node* node = Object::cast_to<Node>(obj);
        if (node) { result = node->get_name(); return true; }
    }
    // ---- New properties (v4.4.0) ----
    // BackStyle: 0 = Transparent, 1 = Opaque
    if (prop_name == "BackStyle") {
        result = obj->has_meta("vg_backstyle") ? (int)obj->get_meta("vg_backstyle") : 1;
        return true;
    }
    // Appearance: 0 = Flat, 1 = 3D
    if (prop_name == "Appearance") {
        result = obj->has_meta("vg_appearance") ? (int)obj->get_meta("vg_appearance") : 1;
        return true;
    }
    // TabIndex
    if (prop_name == "TabIndex") {
        result = obj->has_meta("vg_tabindex") ? (int)obj->get_meta("vg_tabindex") : 0;
        return true;
    }
    // Parent — returns the parent Node
    if (prop_name == "Parent") {
        Node* node = Object::cast_to<Node>(obj);
        if (node && node->get_parent()) { result = Variant(node->get_parent()); return true; }
        result = Variant();
        return true;
    }
    // Container — returns the parent container
    if (prop_name == "Container") {
        Node* node = Object::cast_to<Node>(obj);
        if (node && node->get_parent()) { result = Variant(node->get_parent()); return true; }
        result = Variant();
        return true;
    }
    // Index (control array index)
    if (prop_name == "Index") {
        result = obj->has_meta("vg_index") ? (int)obj->get_meta("vg_index") : -1;
        return true;
    }
    // DragMode: 0 = Manual, 1 = Automatic
    if (prop_name == "DragMode") {
        result = obj->has_meta("vg_dragmode") ? (int)obj->get_meta("vg_dragmode") : 0;
        return true;
    }

    return false; // Not a VB6 alias
}

// VB6 property WRITE alias resolution.
// Returns true if the property was handled.
static bool _vb6_write_property(Object* obj, const String& prop_name, const Variant& value) {
    if (!obj) return false;
    // O(1) fast-reject for unknown property names
    if (_vb6_prop_id(prop_name) < 0) return false;

    // Text / Caption
    if (prop_name == "Text" || prop_name == "Caption") {
        obj->set("text", value);
        return true;
    }
    // Visible
    if (prop_name == "Visible") {
        obj->set("visible", value);
        return true;
    }
    // Enabled
    if (prop_name == "Enabled") {
        if (Object::cast_to<Timer>(obj)) {
            if ((bool)value) obj->call("start"); else obj->call("stop");
            return true;
        }
        Variant test_disabled = obj->get("disabled");
        if (test_disabled.get_type() == Variant::BOOL) { obj->set("disabled", !(bool)value); return true; }
        Variant test_editable = obj->get("editable");
        if (test_editable.get_type() == Variant::BOOL) { obj->set("editable", (bool)value); return true; }
    }
    // Position
    if (prop_name == "Left") {
        Control* c = Object::cast_to<Control>(obj);
        if (c) { c->set_position(Vector2((double)value, c->get_position().y)); return true; }
        Node2D* n = Object::cast_to<Node2D>(obj);
        if (n) { n->set_position(Vector2((double)value, n->get_position().y)); return true; }
    }
    if (prop_name == "Top") {
        Control* c = Object::cast_to<Control>(obj);
        if (c) { c->set_position(Vector2(c->get_position().x, (double)value)); return true; }
        Node2D* n = Object::cast_to<Node2D>(obj);
        if (n) { n->set_position(Vector2(n->get_position().x, (double)value)); return true; }
    }
    // Size
    if (prop_name == "Width") {
        Control* c = Object::cast_to<Control>(obj);
        if (c) { c->set_size(Vector2((double)value, c->get_size().y)); return true; }
    }
    if (prop_name == "Height") {
        Control* c = Object::cast_to<Control>(obj);
        if (c) { c->set_size(Vector2(c->get_size().x, (double)value)); return true; }
    }
    // Value
    if (prop_name == "Value") {
        obj->set("value", value);
        return true;
    }
    // ToolTipText
    if (prop_name == "ToolTipText") {
        obj->set("tooltip_text", value);
        return true;
    }
    // TabStop
    if (prop_name == "TabStop") {
        obj->set("focus_mode", (bool)value ? 2 : 0); // FOCUS_ALL=2, FOCUS_NONE=0
        return true;
    }
    // Opacity
    if (prop_name == "Opacity") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Color m = ctrl->get_modulate();
            m.a = (float)((double)value / 100.0);
            ctrl->set_modulate(m);
            return true;
        }
    }
    // MousePointer
    if (prop_name == "MousePointer") {
        obj->set("mouse_default_cursor_shape", value);
        return true;
    }
    // Locked
    if (prop_name == "Locked") {
        Variant ed = obj->get("editable");
        if (ed.get_type() == Variant::BOOL) { obj->set("editable", !(bool)value); return true; }
    }
    // MaxLength
    if (prop_name == "MaxLength") {
        obj->set("max_length", value);
        return true;
    }
    // Alignment
    if (prop_name == "Alignment") {
        obj->set("horizontal_alignment", value);
        return true;
    }
    // WordWrap
    if (prop_name == "WordWrap") {
        obj->set("autowrap_mode", (bool)value ? 3 : 0); // WORD_SMART=3
        return true;
    }
    // FontSize
    if (prop_name == "FontSize") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { ctrl->add_theme_font_size_override("font_size", (int)value); return true; }
    }
    // ForeColor
    if (prop_name == "ForeColor") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Color c = value;
            ctrl->add_theme_color_override("font_color", c);
            return true;
        }
    }
    // BackColor
    if (prop_name == "BackColor") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (!ctrl) {
            Window* win = Object::cast_to<Window>(obj);
            if (win) {
                Node* bg = win->find_child("_FormBackground", false, false);
                if (bg) ctrl = Object::cast_to<Control>(bg);
            }
        }
        if (ctrl) {
            Color c = value;
            String sb_name = (ctrl->get_class() == "Panel") ? "panel" : "normal";
            Ref<StyleBox> existing = ctrl->get_theme_stylebox(sb_name);
            Ref<StyleBoxFlat> sbf;
            if (existing.is_valid()) {
                sbf = existing->duplicate();
            }
            if (!sbf.is_valid()) sbf.instantiate();
            sbf->set_bg_color(c);
            ctrl->add_theme_stylebox_override(sb_name, sbf);
            return true;
        }
    }
    // FontBold
    if (prop_name == "FontBold") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            Ref<FontVariation> fv;
            if (fnt.is_valid()) { fv = fnt; }
            if (!fv.is_valid()) {
                fv.instantiate();
                Ref<SystemFont> sf;
                sf.instantiate();
                sf->set_font_names(PackedStringArray());
                fv->set_base_font(sf);
            }
            fv->set_variation_embolden((bool)value ? 1.2f : 0.0f);
            ctrl->add_theme_font_override("font", fv);
            return true;
        }
    }
    // FontItalic
    if (prop_name == "FontItalic") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            Ref<FontVariation> fv;
            if (fnt.is_valid()) { fv = fnt; }
            if (!fv.is_valid()) {
                fv.instantiate();
                Ref<SystemFont> sf;
                sf.instantiate();
                sf->set_font_names(PackedStringArray());
                fv->set_base_font(sf);
            }
            Transform2D t = fv->get_variation_transform();
            t[0][1] = (bool)value ? 0.2f : 0.0f;
            fv->set_variation_transform(t);
            ctrl->add_theme_font_override("font", fv);
            return true;
        }
    }
    // FontName
    if (prop_name == "FontName") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<Font> fnt = ctrl->get_theme_font("font");
            Ref<FontVariation> fv;
            if (fnt.is_valid()) { fv = fnt; }
            if (!fv.is_valid()) {
                fv.instantiate();
            }
            Ref<SystemFont> sf;
            Ref<Font> base = fv->get_base_font();
            if (base.is_valid()) { sf = base; }
            if (!sf.is_valid()) { sf.instantiate(); }
            PackedStringArray names;
            names.push_back(String(value));
            sf->set_font_names(names);
            fv->set_base_font(sf);
            ctrl->add_theme_font_override("font", fv);
            return true;
        }
    }
    // FontUnderline / FontStrikethrough
    if (prop_name == "FontUnderline") {
        obj->set_meta("vg_font_underline", (bool)value);
        return true;
    }
    if (prop_name == "FontStrikethrough") {
        obj->set_meta("vg_font_strikethrough", (bool)value);
        return true;
    }
    // BorderStyle
    if (prop_name == "BorderStyle") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            Ref<StyleBox> existing = ctrl->get_theme_stylebox("normal");
            if ((int)value == 0) {
                Ref<StyleBoxEmpty> sbe;
                sbe.instantiate();
                ctrl->add_theme_stylebox_override("normal", sbe);
            } else {
                Ref<StyleBoxFlat> sbf;
                if (existing.is_valid()) sbf = existing->duplicate();
                if (!sbf.is_valid()) sbf.instantiate();
                sbf->set_border_width_all(1);
                sbf->set_border_color(Color(0, 0, 0));
                ctrl->add_theme_stylebox_override("normal", sbf);
            }
            return true;
        }
    }
    // Style / Flat
    if (prop_name == "Style" || prop_name == "Flat") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) { btn->set_flat((bool)value); return true; }
    }
    // ScrollBars (meta)
    if (prop_name == "ScrollBars") {
        obj->set_meta("vg_scrollbars", (int)value);
        return true;
    }
    // PasswordChar
    if (prop_name == "PasswordChar") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) {
            String ch = String(value);
            if (ch.length() > 0) {
                le->set_secret(true);
                le->set("secret_character", String(String::chr(ch[0])));
            } else {
                le->set_secret(false);
            }
            return true;
        }
    }
    // PlaceholderText
    if (prop_name == "PlaceholderText") {
        obj->set("placeholder_text", value);
        return true;
    }
    // Editable
    if (prop_name == "Editable") {
        obj->set("editable", value);
        return true;
    }
    // SelStart
    if (prop_name == "SelStart") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) { le->set_caret_column((int)value); return true; }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) { te->set_caret_column((int)value); return true; }
    }
    // SelLength
    if (prop_name == "SelLength") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) {
            int start = le->get_caret_column();
            le->select(start, start + (int)value);
            return true;
        }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) {
            int col = te->get_caret_column();
            int line = te->get_caret_line();
            te->select(line, col, line, col + (int)value);
            return true;
        }
    }
    // SelText
    if (prop_name == "SelText") {
        LineEdit* le = Object::cast_to<LineEdit>(obj);
        if (le) {
            if (le->has_selection()) le->delete_text(le->get_selection_from_column(), le->get_selection_to_column());
            le->insert_text_at_caret(String(value));
            return true;
        }
        TextEdit* te = Object::cast_to<TextEdit>(obj);
        if (te) { te->insert_text_at_caret(String(value)); return true; }
    }
    // Picture
    if (prop_name == "Picture") {
        TextureRect* tr = Object::cast_to<TextureRect>(obj);
        if (tr) {
            if (value.get_type() == Variant::OBJECT) { tr->set_texture(value); }
            else if (value.get_type() == Variant::STRING) {
                Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(String(value));
                if (tex.is_valid()) tr->set_texture(tex);
                obj->set_meta("vg_picture_path", value);
            }
            return true;
        }
    }
    // Icon
    if (prop_name == "Icon") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) {
            if (value.get_type() == Variant::OBJECT) { btn->set_button_icon(value); }
            else if (value.get_type() == Variant::STRING) {
                Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(String(value));
                if (tex.is_valid()) btn->set_button_icon(tex);
            }
            return true;
        }
    }
    // Tag (meta)
    if (prop_name == "Tag") {
        obj->set_meta("vg_tag", value);
        return true;
    }
    // Timer properties
    if (prop_name == "Interval") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { tmr->set_wait_time((double)value / 1000.0); return true; }
    }
    if (prop_name == "OneShot") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { tmr->set_one_shot((bool)value); return true; }
    }
    if (prop_name == "Autostart") {
        Timer* tmr = Object::cast_to<Timer>(obj);
        if (tmr) { tmr->set_autostart((bool)value); return true; }
    }
    // ListIndex
    if (prop_name == "ListIndex") {
        ItemList* il = Object::cast_to<ItemList>(obj);
        if (il) { il->select((int)value); return true; }
        OptionButton* ob = Object::cast_to<OptionButton>(obj);
        if (ob) { ob->select((int)value); return true; }
    }
    // Sorted (meta)
    if (prop_name == "Sorted") {
        obj->set_meta("vg_sorted", (bool)value);
        if ((bool)value) {
            ItemList* il = Object::cast_to<ItemList>(obj);
            if (il) il->sort_items_by_text();
        }
        return true;
    }
    // AutoSize (Label)
    if (prop_name == "AutoSize") {
        Label* lbl = Object::cast_to<Label>(obj);
        if (lbl) {
            if ((bool)value) {
                lbl->set_autowrap_mode(TextServer::AUTOWRAP_OFF);
                lbl->set_clip_text(false);
            } else {
                lbl->set_clip_text(true);
            }
            return true;
        }
    }
    // ClipText (Button)
    if (prop_name == "ClipText") {
        Button* btn = Object::cast_to<Button>(obj);
        if (btn) { btn->set_clip_text((bool)value); return true; }
    }
    // Window properties
    if (prop_name == "WindowState") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) {
            int s = (int)value;
            if (s == 1) win->set_mode(Window::MODE_MINIMIZED);
            else if (s == 2) win->set_mode(Window::MODE_MAXIMIZED);
            else win->set_mode(Window::MODE_WINDOWED);
            return true;
        }
    }
    if (prop_name == "ShowInTaskbar") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { win->set_flag(Window::FLAG_NO_FOCUS, !(bool)value); return true; }
    }
    if (prop_name == "Moveable") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { win->set_flag(Window::FLAG_RESIZE_DISABLED, !(bool)value); return true; }
    }
    if (prop_name == "ControlBox") {
        Window* win = Object::cast_to<Window>(obj);
        if (win) { win->set_flag(Window::FLAG_BORDERLESS, !(bool)value); return true; }
    }
    // ZOrder
    if (prop_name == "ZOrder") {
        obj->set("z_index", value);
        return true;
    }
    // Rotation
    if (prop_name == "Rotation") {
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) { ctrl->set_rotation(Math::deg_to_rad((double)value)); return true; }
    }
    // Name
    if (prop_name == "Name") {
        Node* node = Object::cast_to<Node>(obj);
        if (node) { node->set_name(String(value)); return true; }
    }
    // ---- New properties (v4.4.0) ----
    // BackStyle: 0 = Transparent, 1 = Opaque
    if (prop_name == "BackStyle") {
        obj->set_meta("vg_backstyle", (int)value);
        Control* ctrl = Object::cast_to<Control>(obj);
        if (ctrl) {
            if ((int)value == 0) {
                ctrl->set_self_modulate(Color(1, 1, 1, 0)); // Transparent
            } else {
                ctrl->set_self_modulate(Color(1, 1, 1, 1)); // Opaque
            }
        }
        return true;
    }
    // Appearance: 0 = Flat, 1 = 3D
    if (prop_name == "Appearance") {
        obj->set_meta("vg_appearance", (int)value);
        return true;
    }
    // TabIndex
    if (prop_name == "TabIndex") {
        obj->set_meta("vg_tabindex", (int)value);
        return true;
    }
    // Index (control array index)
    if (prop_name == "Index") {
        obj->set_meta("vg_index", (int)value);
        return true;
    }
    // DragMode: 0 = Manual, 1 = Automatic
    if (prop_name == "DragMode") {
        obj->set_meta("vg_dragmode", (int)value);
        return true;
    }

    return false; // Not a VB6 alias
}


// ============================================================================
// Expression evaluation (evaluate_expression + helpers)
// Extracted for maintainability — 2537 lines
// ============================================================================
#include "visual_gasic_instance_evaluate.inc"

// ============================================================================
// Statement execution (execute_statement + helpers)
// Extracted for maintainability — 2435 lines
// ============================================================================
#include "visual_gasic_instance_execute.inc"

// ============================================================================
// Method call dispatch (call_internal, call, notification, debug, etc.)
// Extracted for maintainability — 1730 lines
// ============================================================================
#include "visual_gasic_instance_call.inc"

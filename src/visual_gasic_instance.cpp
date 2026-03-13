#include <godot_cpp/classes/file_dialog.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <cstdlib>
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
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/theme.hpp>
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

// === IMMEDIATE WINDOW SUPPORT ===
// Global registry of active VisualGasic instances for debugging/immediate window
// Must be outside anonymous namespace for external linkage
static std::mutex vg_debug_instance_registry_mutex;
static std::set<VisualGasicInstance*> vg_debug_active_instances;

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
    if (index < 0 || index >= (int)vg_debug_active_instances.size()) {
        return nullptr;
    }
    auto it = vg_debug_active_instances.begin();
    std::advance(it, index);
    return *it;
}

Dictionary get_instance_variables(int index) {
    VisualGasicInstance* inst = get_instance_by_index(index);
    if (!inst) {
        return Dictionary();
    }
    
    // Get all variables from the instance
    Dictionary raw_vars = inst->get_debug_globals();
    
    // Filter and convert to serializable types for debugger protocol
    Dictionary result;
    Array keys = raw_vars.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        
        // Skip internal VB constants (vbCrLf, vbNewLine, etc.) and Err object
        if (key.begins_with("vb") || key == "Err") {
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
        int slot = __builtin_ctzll(free_mask);
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
    // Colors
    variables["vbRed"] = Color(1, 0, 0);
    variables["vbGreen"] = Color(0, 1, 0);
    variables["vbBlue"] = Color(0, 0, 1);
    variables["vbBlack"] = Color(0, 0, 0);
    variables["vbWhite"] = Color(1, 1, 1);
    variables["vbYellow"] = Color(1, 1, 0);
    variables["vbCyan"] = Color(0, 1, 1);
    variables["vbMagenta"] = Color(1, 0, 1);
    
    // Keys (Mapped to Godot Key Enum values roughly)
    variables["vbKeyReturn"] = (int)Key::KEY_ENTER;
    variables["vbKeyEnter"] = (int)Key::KEY_ENTER;
    variables["vbKeySpace"] = (int)Key::KEY_SPACE;
    variables["vbKeyEscape"] = (int)Key::KEY_ESCAPE;
    variables["vbKeyUp"] = (int)Key::KEY_UP;
    variables["vbKeyDown"] = (int)Key::KEY_DOWN;
    variables["vbKeyLeft"] = (int)Key::KEY_LEFT;
    variables["vbKeyRight"] = (int)Key::KEY_RIGHT;
    
    // Godot-style Key Constants (for Input.IsKeyPressed)
    variables["KEY_NONE"] = (int)Key::KEY_NONE;
    variables["KEY_SPACE"] = (int)Key::KEY_SPACE;
    variables["KEY_ENTER"] = (int)Key::KEY_ENTER;
    variables["KEY_ESCAPE"] = (int)Key::KEY_ESCAPE;
    variables["KEY_TAB"] = (int)Key::KEY_TAB;
    variables["KEY_BACKSPACE"] = (int)Key::KEY_BACKSPACE;
    variables["KEY_DELETE"] = (int)Key::KEY_DELETE;
    variables["KEY_INSERT"] = (int)Key::KEY_INSERT;
    variables["KEY_HOME"] = (int)Key::KEY_HOME;
    variables["KEY_END"] = (int)Key::KEY_END;
    variables["KEY_PAGEUP"] = (int)Key::KEY_PAGEUP;
    variables["KEY_PAGEDOWN"] = (int)Key::KEY_PAGEDOWN;
    variables["KEY_UP"] = (int)Key::KEY_UP;
    variables["KEY_DOWN"] = (int)Key::KEY_DOWN;
    variables["KEY_LEFT"] = (int)Key::KEY_LEFT;
    variables["KEY_RIGHT"] = (int)Key::KEY_RIGHT;
    variables["KEY_SHIFT"] = (int)Key::KEY_SHIFT;
    variables["KEY_CTRL"] = (int)Key::KEY_CTRL;
    variables["KEY_ALT"] = (int)Key::KEY_ALT;
    variables["KEY_CAPSLOCK"] = (int)Key::KEY_CAPSLOCK;
    // Letter keys A-Z
    variables["KEY_A"] = (int)Key::KEY_A;
    variables["KEY_B"] = (int)Key::KEY_B;
    variables["KEY_C"] = (int)Key::KEY_C;
    variables["KEY_D"] = (int)Key::KEY_D;
    variables["KEY_E"] = (int)Key::KEY_E;
    variables["KEY_F"] = (int)Key::KEY_F;
    variables["KEY_G"] = (int)Key::KEY_G;
    variables["KEY_H"] = (int)Key::KEY_H;
    variables["KEY_I"] = (int)Key::KEY_I;
    variables["KEY_J"] = (int)Key::KEY_J;
    variables["KEY_K"] = (int)Key::KEY_K;
    variables["KEY_L"] = (int)Key::KEY_L;
    variables["KEY_M"] = (int)Key::KEY_M;
    variables["KEY_N"] = (int)Key::KEY_N;
    variables["KEY_O"] = (int)Key::KEY_O;
    variables["KEY_P"] = (int)Key::KEY_P;
    variables["KEY_Q"] = (int)Key::KEY_Q;
    variables["KEY_R"] = (int)Key::KEY_R;
    variables["KEY_S"] = (int)Key::KEY_S;
    variables["KEY_T"] = (int)Key::KEY_T;
    variables["KEY_U"] = (int)Key::KEY_U;
    variables["KEY_V"] = (int)Key::KEY_V;
    variables["KEY_W"] = (int)Key::KEY_W;
    variables["KEY_X"] = (int)Key::KEY_X;
    variables["KEY_Y"] = (int)Key::KEY_Y;
    variables["KEY_Z"] = (int)Key::KEY_Z;
    // Number keys 0-9
    variables["KEY_0"] = (int)Key::KEY_0;
    variables["KEY_1"] = (int)Key::KEY_1;
    variables["KEY_2"] = (int)Key::KEY_2;
    variables["KEY_3"] = (int)Key::KEY_3;
    variables["KEY_4"] = (int)Key::KEY_4;
    variables["KEY_5"] = (int)Key::KEY_5;
    variables["KEY_6"] = (int)Key::KEY_6;
    variables["KEY_7"] = (int)Key::KEY_7;
    variables["KEY_8"] = (int)Key::KEY_8;
    variables["KEY_9"] = (int)Key::KEY_9;
    // Function keys F1-F12
    variables["KEY_F1"] = (int)Key::KEY_F1;
    variables["KEY_F2"] = (int)Key::KEY_F2;
    variables["KEY_F3"] = (int)Key::KEY_F3;
    variables["KEY_F4"] = (int)Key::KEY_F4;
    variables["KEY_F5"] = (int)Key::KEY_F5;
    variables["KEY_F6"] = (int)Key::KEY_F6;
    variables["KEY_F7"] = (int)Key::KEY_F7;
    variables["KEY_F8"] = (int)Key::KEY_F8;
    variables["KEY_F9"] = (int)Key::KEY_F9;
    variables["KEY_F10"] = (int)Key::KEY_F10;
    variables["KEY_F11"] = (int)Key::KEY_F11;
    variables["KEY_F12"] = (int)Key::KEY_F12;
    // Symbol / punctuation keys
    variables["KEY_PLUS"] = (int)Key::KEY_PLUS;
    variables["KEY_MINUS"] = (int)Key::KEY_MINUS;
    variables["KEY_ASTERISK"] = (int)Key::KEY_ASTERISK;
    variables["KEY_SLASH"] = (int)Key::KEY_SLASH;
    variables["KEY_PERIOD"] = (int)Key::KEY_PERIOD;
    variables["KEY_EQUAL"] = (int)Key::KEY_EQUAL;
    variables["KEY_PERCENT"] = (int)Key::KEY_PERCENT;
    // Numeric keypad keys
    variables["KEY_KP_0"] = (int)Key::KEY_KP_0;
    variables["KEY_KP_1"] = (int)Key::KEY_KP_1;
    variables["KEY_KP_2"] = (int)Key::KEY_KP_2;
    variables["KEY_KP_3"] = (int)Key::KEY_KP_3;
    variables["KEY_KP_4"] = (int)Key::KEY_KP_4;
    variables["KEY_KP_5"] = (int)Key::KEY_KP_5;
    variables["KEY_KP_6"] = (int)Key::KEY_KP_6;
    variables["KEY_KP_7"] = (int)Key::KEY_KP_7;
    variables["KEY_KP_8"] = (int)Key::KEY_KP_8;
    variables["KEY_KP_9"] = (int)Key::KEY_KP_9;
    variables["KEY_KP_ENTER"] = (int)Key::KEY_KP_ENTER;
    variables["KEY_KP_ADD"] = (int)Key::KEY_KP_ADD;
    variables["KEY_KP_SUBTRACT"] = (int)Key::KEY_KP_SUBTRACT;
    variables["KEY_KP_MULTIPLY"] = (int)Key::KEY_KP_MULTIPLY;
    variables["KEY_KP_DIVIDE"] = (int)Key::KEY_KP_DIVIDE;
    variables["KEY_KP_PERIOD"] = (int)Key::KEY_KP_PERIOD;
    // Mouse button constants
    variables["MOUSE_BUTTON_LEFT"] = (int)MouseButton::MOUSE_BUTTON_LEFT;
    variables["MOUSE_BUTTON_RIGHT"] = (int)MouseButton::MOUSE_BUTTON_RIGHT;
    variables["MOUSE_BUTTON_MIDDLE"] = (int)MouseButton::MOUSE_BUTTON_MIDDLE;
    variables["MOUSE_BUTTON_WHEEL_UP"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_UP;
    variables["MOUSE_BUTTON_WHEEL_DOWN"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_DOWN;
    variables["MOUSE_BUTTON_WHEEL_LEFT"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_LEFT;
    variables["MOUSE_BUTTON_WHEEL_RIGHT"] = (int)MouseButton::MOUSE_BUTTON_WHEEL_RIGHT;
    variables["MOUSE_BUTTON_XBUTTON1"] = (int)MouseButton::MOUSE_BUTTON_XBUTTON1;
    variables["MOUSE_BUTTON_XBUTTON2"] = (int)MouseButton::MOUSE_BUTTON_XBUTTON2;
    // Input mouse mode constants (also accessible via Input.MOUSE_MODE_xxx)
    variables["MOUSE_MODE_VISIBLE"] = (int)Input::MOUSE_MODE_VISIBLE;
    variables["MOUSE_MODE_HIDDEN"] = (int)Input::MOUSE_MODE_HIDDEN;
    variables["MOUSE_MODE_CAPTURED"] = (int)Input::MOUSE_MODE_CAPTURED;
    variables["MOUSE_MODE_CONFINED"] = (int)Input::MOUSE_MODE_CONFINED;
    variables["MOUSE_MODE_CONFINED_HIDDEN"] = (int)Input::MOUSE_MODE_CONFINED_HIDDEN;
    
    // MsgBox Button Constants (VB6-style)
    variables["vbOKOnly"] = 0;
    variables["vbOKCancel"] = 1;
    variables["vbAbortRetryIgnore"] = 2;
    variables["vbYesNoCancel"] = 3;
    variables["vbYesNo"] = 4;
    variables["vbRetryCancel"] = 5;
    
    // MsgBox Icon Constants
    variables["vbCritical"] = 16;
    variables["vbQuestion"] = 32;
    variables["vbExclamation"] = 48;
    variables["vbInformation"] = 64;
    
    // MsgBox Return Values
    variables["vbOK"] = 1;
    variables["vbCancel"] = 2;
    variables["vbAbort"] = 3;
    variables["vbRetry"] = 4;
    variables["vbIgnore"] = 5;
    variables["vbYes"] = 6;
    variables["vbNo"] = 7;
    
    // Strings
    variables["vbTab"] = "\t";
    variables["vbCr"] = "\r";
    variables["vbLf"] = "\n";
    variables["vbCrLf"] = "\r\n";
    variables["vbNullString"] = "";

    // MSComm Constants
    variables["comNone"] = 0;
    variables["comXOnXOff"] = 1;
    variables["comRTS"] = 2;
    variables["comRTSXOnXOff"] = 3;

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
                 
                 UtilityFunctions::print("Initialized Global Var: ", v->name);
            }
            
            // Initialize constants FIRST so that array Dim sizes
            // (e.g. Dim arr(MAX_PARTICLES)) can reference them
            for(int ci=0; ci<vs->ast_root->constants.size(); ci++) {
                ConstStatement* c = vs->ast_root->constants[ci];
                Variant val = evaluate_expression(c->value);
                variables[c->name] = val;
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
                         for(int i=0; i<def->members.size(); i++) {
                             String mname = def->members[i].name;
                             String mtype = def->members[i].type;

                             if (mtype.nocasecmp_to("Integer") == 0 || mtype.nocasecmp_to("Long") == 0) dict[mname] = 0;
                             else if (mtype.nocasecmp_to("String") == 0) dict[mname] = "";
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
            
            // Resolve Import statements (v4.2.0) — load imported modules
            // and register their Public subs/variables in module_registry.
            for (int ii = 0; ii < vs->ast_root->imports.size(); ii++) {
                String import_path = vs->ast_root->imports[ii];
                // Resolve relative to current script directory
                String script_dir = vs->get_path().get_base_dir();
                String full_path = import_path;
                if (!import_path.begins_with("res://") && !import_path.begins_with("/")) {
                    full_path = script_dir.path_join(import_path);
                }
                
                if (FileAccess::file_exists(full_path)) {
                    String import_source = FileAccess::get_file_as_string(full_path);
                    VisualGasicTokenizer import_tok;
                    Vector<VisualGasicTokenizer::Token> import_tokens = import_tok.tokenize(import_source);
                    VisualGasicParser import_parser;
                    ModuleNode* import_ast = import_parser.parse(import_tokens);
                    
                    if (import_ast && import_parser.errors.size() == 0) {
                        // Extract module name from filename
                        String mod_name = full_path.get_file().get_basename();
                        
                        Dictionary mod_dict;
                        // Register public variables
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
                        // Register public constants
                        for (int ci = 0; ci < import_ast->constants.size(); ci++) {
                            ConstStatement* mc = import_ast->constants[ci];
                            if (mc->value && mc->value->type == ExpressionNode::LITERAL) {
                                mod_dict[mc->name] = static_cast<LiteralNode*>(mc->value)->value;
                            }
                        }
                        
                        module_registry[mod_name] = mod_dict;
                        UtilityFunctions::print("[VG] Imported module: ", mod_name, " from ", full_path);
                    }
                    // Note: import_ast ownership — parser tracks nodes, will clean up
                } else {
                    UtilityFunctions::print("[VG] Import Error: File not found: ", full_path);
                }
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
    return false;
}

// Retrieve a variable by name into r_ret. Returns true if found.
bool VisualGasicInstance::get_variable(const String &p_name, Variant &r_ret) {
    if (variables.has(p_name)) {
        r_ret = variables[p_name];
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
            if (p_method.nocasecmp_to("DrawString") == 0 && p_args.size() >= 4) {
                String text = p_args[0];
                float x = p_args[1];
                float y = p_args[2];
                Color col = p_args[3];
                int font_size = 16;
                if (p_args.size() > 4) font_size = (int)p_args[4];
                Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
                ci->draw_string(font, Vector2(x, y + font_size), text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col);
                r_found = true;
                return;
            }
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
            if (p_method.nocasecmp_to("DrawLine") == 0 && p_args.size() >= 4) {
                float x1 = p_args[0], y1 = p_args[1], x2 = p_args[2], y2 = p_args[3];
                Color col = Color(1,1,1,1);
                float width = 1.0;
                if (p_args.size() > 4) col = p_args[4];
                if (p_args.size() > 5) width = p_args[5];
                ci->draw_line(Vector2(x1, y1), Vector2(x2, y2), col, width);
                r_found = true;
                return;
            }
            if (p_method.nocasecmp_to("DrawRect") == 0 && p_args.size() >= 4) {
                float x = p_args[0], y = p_args[1], w = p_args[2], h = p_args[3];
                Color col = Color(1,1,1,1);
                bool filled = true;
                if (p_args.size() > 4) col = p_args[4];
                if (p_args.size() > 5) filled = (bool)p_args[5];
                ci->draw_rect(Rect2(x, y, w, h), col, filled);
                r_found = true;
                return;
            }
            if (p_method.nocasecmp_to("DrawCircle") == 0 && p_args.size() >= 3) {
                float x = p_args[0], y = p_args[1], radius = p_args[2];
                Color col = Color(1,1,1,1);
                if (p_args.size() > 3) col = p_args[3];
                ci->draw_circle(Vector2(x, y), radius, col);
                r_found = true;
                return;
            }
        }
    }

    // Audio commands — require owner to be a Node
    if (owner) {
        Node *n = Object::cast_to<Node>(owner);
        if (n) {
            if (p_method.nocasecmp_to("PlaySound") == 0 && p_args.size() == 1) {
                String path = p_args[0];
                Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                if (stream.is_valid()) {
                    AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                    p->set_stream(stream);
                    p->set_autoplay(true);
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

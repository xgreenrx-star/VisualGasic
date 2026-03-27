#ifndef VISUAL_GASIC_INSTANCE_H
#define VISUAL_GASIC_INSTANCE_H

#include "visual_gasic_script.h"
#include "visual_gasic_bytecode.h"
#include "visual_gasic_ast.h"
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include "vg_fast_dict.h"
#include <mutex>

using namespace godot;
using namespace VisualGasic;

class VisualGasicInstance {
    Ref<VisualGasicScript> script;
    Object *owner;
    ModuleNode* cached_ast_root = nullptr; // Cached for enum/struct lookups
    Dictionary variables; // Variable storage
    Dictionary open_files; // Map<int, Ref<FileAccess>>
    Dictionary static_variables; // Persist across calls (Static keyword)
    Dictionary module_registry; // Module name -> Dictionary of module variables

    // Multi-module compilation (v4.3.0) — imported module ASTs for cross-file calls
    struct ImportedModule {
        String module_name;         // Base filename without extension
        String full_path;           // Resolved absolute path
        ModuleNode* ast = nullptr;  // Parsed AST (owned by parser, cleaned up below)
        VisualGasicParser* parser = nullptr; // Keep alive so AST nodes aren't freed
        VisualGasicTokenizer* tokenizer = nullptr;
    };
    Vector<ImportedModule> imported_modules;
    static thread_local Vector<String> import_stack; // Circular import detection

    Ref<DirAccess> current_dir; // For Dir() iteration
    String dir_pattern; 
    bool option_compare_text;

    // Guard against double _Ready in GDExtension lifecycle
    bool ready_executed = false;

    // Suppress Whenever triggers during module-level initialization
    bool whenever_init_suppress = false;

    // Re-entrancy guard: prevent Whenever callbacks from recursively triggering more Whenever checks
    bool whenever_evaluating = false;

    // VM State
    VMState vm;
    Vector<Variant> with_stack;
    Vector<int> gosub_return_stack; // GoSub return addresses (statement indices)

    // DATA / READ Support
    Vector<ExpressionNode*> data_segments; 
    Vector<ExpressionNode*> runtime_data_nodes; // Nodes created at execution time (LoadData)
    int data_pointer;
    Dictionary label_to_data_index; 
    
    // Dynamic Nodes Tracking (for CLS)
    Vector<uint64_t> dynamic_nodes;

    void scan_data_sections(ModuleNode* root);
    void collect_data_from_block(const Vector<Statement*>& block);

    // Data introspection helpers
    int get_section_end(int section_start) const;
    int get_current_section_start() const;
    void clear_data_tape();
    static Variant coerce_to_type(const Variant &val, const String &type_name);

    // Struct/Type system
    Dictionary struct_prototypes;  // Name -> Dictionary(default prototype)
    // Hidden key stored in each struct dictionary instance to track its type
    static constexpr const char* STRUCT_TYPE_KEY_CSTR = "__vg_type__";
    // Look up a StructDefinition by name from the current script AST
    StructDefinition* find_struct_definition(const String &name) const;
    // Coerce a value for strict struct member assignment; returns coerced value
    Variant coerce_struct_member(const String &struct_type, const String &member_name, const Variant &val);
    
    // Class system storage
    struct FastKeyCacheEntry {
        Variant variant;
        uint32_t hit_count = 0;
        uint32_t last_used = 0;
    };

    static constexpr uint32_t FAST_DICT_CACHE_TRIGGER = 3;
    static constexpr uint32_t FAST_DICT_CACHE_MAX_ENTRIES = 256;

    Dictionary class_registry;       // class_name -> ClassDefinition* (as int64_t)
    Dictionary object_instances;     // object_id -> Dictionary of member values
    int next_object_id = 1;         // For unique object IDs
    Dictionary loaded_libraries;     // lib_name -> handle (as int64_t)
    Dictionary declared_functions;   // function_name -> DeclareStatement* (as int64_t)
    Dictionary with_events_vars;     // WithEvents variable names → true (v3.5.0)
    HashMap<StringName, FastKeyCacheEntry> fast_dict_key_cache;
    uint32_t fast_dict_key_cache_generation = 0;
    StringName fast_dict_last_key_name;
    uint32_t fast_dict_last_key_hits = 0;

    // Sole-owner VGFastStringDict pool (indexed by local slot)
    // When the compiler proves a dictionary has sole ownership, it uses
    // this pool instead of Godot's Dictionary.  Max 16 per function call.
    static constexpr int VGDICT_POOL_MAX = 16;
    VGFastStringDict vgdict_pool[VGDICT_POOL_MAX];
    bool vgdict_slot_active[VGDICT_POOL_MAX] = {};

    // Whenever system tracking
    struct WheneverSection {
        String section_name;
        String variable_name;
        String comparison_operator;
        Variant comparison_value;
        Variant comparison_value2;  // For "Between" operator
        ExpressionNode* condition_expression;  // For complex conditions
        Vector<String> callback_procedures;  // Support multiple callbacks
        Variant last_value;  // For tracking changes
        bool is_active;
        uint64_t last_trigger_time;  // For debouncing
        uint64_t debounce_ms;       // Minimum time between triggers
        String scope_type;          // "global", "local", "member"
        String scope_context;       // Sub/Function name or Class name
        bool last_condition_result;  // For edge detection on expression conditions and Exceeds/Below
        
        WheneverSection() : condition_expression(nullptr), is_active(true), last_trigger_time(0), debounce_ms(0), scope_type("global"), last_condition_result(false) {}
        
        ~WheneverSection() {
            // Note: condition_expression will be cleaned up by AST, don't delete here
        }
    };
    Vector<WheneverSection> whenever_sections;
    Vector<String> scope_stack;  // Track current scope hierarchy

    // Fast-path flag: when false, bytecode GET_LOCAL/SET_LOCAL skip the
    // variables[] Dictionary sync entirely.  Set to true only when
    // whenever_sections is non-empty (callbacks need the Dictionary).
    bool needs_var_sync = false;

    // Multitasking system
    struct TaskInfo {
        String task_name;
        int64_t task_id;  // Godot WorkerThreadPool task ID
        bool is_completed;
        bool is_background;
        Variant result;
        Vector<Statement*> task_body;
        
        TaskInfo() : task_id(-1), is_completed(false), is_background(true) {}
    };
    Vector<TaskInfo> active_tasks;
    Dictionary task_results; // Task name -> result

    // Per-instance recursive mutex for Lock / Unlock statements.
    // Recursive so Lock inside an already-locked Parallel For body won't deadlock.
    // Used by Parallel For / Task Run / Parallel Section worker threads
    // to protect shared variable access.
    std::recursive_mutex instance_mutex_;
    
    struct CoroutineState {
        String function_name;
        Vector<Statement*> remaining_statements;
        int instruction_pointer;
        Dictionary local_variables;
        bool is_awaiting;
        Variant await_result;
        
        CoroutineState() : instruction_pointer(0), is_awaiting(false) {}
    };
    Vector<CoroutineState> coroutine_stack;

    struct ErrorState {
        enum Mode { NONE, RESUME_NEXT, GOTO_LABEL, EXIT_SUB, EXIT_FOR, EXIT_DO, CONTINUE_FOR, CONTINUE_DO, CONTINUE_WHILE };
        Mode mode;
        String label;
        bool has_error;
        String message;
        int code; // Added
        int error_line = 0; // Line number where error occurred (Erl)
    } error_state;
    
    // Debug state for breakpoint support
    struct DebugState {
        int current_line = 0;
        String current_file;
        bool debug_paused = false;
        enum StepMode { STEP_NONE, STEP_INTO, STEP_OVER, STEP_OUT } step_mode = STEP_NONE;
        int step_depth = 0;  // For step over/out tracking
    } debug_state;
    
    SubDefinition* current_sub;
    int jump_target;
    
    Variant call_internal(const String& p_method, const Array& p_args, bool &r_found);

    // Small helper declarations used by statement execution implementation.
    // `dispatch_builtin_call` dispatches built-in method calls (returns via found flag).
    void dispatch_builtin_call(const String &p_method, const Array &p_args, bool &r_found);

    // Retrieve a variable by name into r_ret. Returns true if found.
    bool get_variable(const String &p_name, Variant &r_ret);

    void assign_to_target(ExpressionNode* target, Variant val);
    void assign_variable(const String& name, Variant val);
    void check_whenever_conditions(const String& variable_name, const Variant& new_value);
    void check_expression_conditions();  // For complex expression monitoring

    void execute_statement(Statement* stmt);
    Variant evaluate_expression(ExpressionNode* expr);
    // Internal helper implementations moved out into separate translation units
    Variant _evaluate_expression_impl(ExpressionNode* expr);
    void _execute_statement_impl(Statement* stmt);
    void raise_error(String msg, int code = 5, const String &source = "");
    Variant *get_cached_fast_dict_key(const Variant &key_source);
    Variant *insert_fast_dict_key_entry(const StringName &key_name, const Variant &key_source, uint32_t initial_hits);
    void prune_fast_dict_cache_if_needed();

public:
    VisualGasicInstance(Ref<VisualGasicScript> p_script, Object *p_owner);
    ~VisualGasicInstance();

    // Public helper for other modules (builtins) to evaluate expression nodes
    Variant evaluate_expression_for_builtins(ExpressionNode* expr);

    // Full expression evaluation including builtins (for fallback from lightweight evaluator)
    Variant evaluate_expression_full(ExpressionNode* expr);

    // File/Directory helpers exposed for builtins (refined names)
    Variant file_lof(int file_num);
    Variant file_loc(int file_num);
    Variant file_eof(int file_num);
    int file_free(int range);
    Variant file_len(const String &path);
    Variant file_dir(const Array &args);
    void randomize_seed();
    // Allow builtins to raise runtime errors via instance wrapper
    void raise_runtime_error(const String &p_msg, int p_code = 5, const String &p_source = "");

    // Data introspection accessors for builtins
    int get_data_count() const { return data_segments.size(); }
    int get_data_pointer() const { return data_pointer; }
    void set_data_pointer(int p) { data_pointer = p < 0 ? 0 : (p > data_segments.size() ? data_segments.size() : p); }
    int get_data_section_end(int section_start) const { return get_section_end(section_start); }
    int get_data_section_start() const { return get_current_section_start(); }
    const Dictionary &get_label_to_data_index() const { return label_to_data_index; }
    ExpressionNode* get_data_segment_at(int index) const { return (index >= 0 && index < data_segments.size()) ? data_segments[index] : nullptr; }
    String get_data_section_name() const {
        int ptr = data_pointer;
        String found;
        Array keys = label_to_data_index.keys();
        for (int i = 0; i < keys.size(); i++) {
            int idx = (int)label_to_data_index[keys[i]];
            if (idx <= ptr && (found.is_empty() || idx > (int)label_to_data_index[found])) {
                found = keys[i];
            }
        }
        return found;
    }

    // Accessors for builtins module (Err.Clear etc.)
    Dictionary &get_variables() { return variables; }
    Dictionary &get_open_files() { return open_files; }
    int get_error_line() const { return error_state.error_line; }
    Variant call_method_by_name(const String &p_name, const Array &p_args);

    // Immediate Window: parse and execute a single VB statement on this instance
    Dictionary evaluate_immediate(const String &p_code);
    
    void clear_error_state() {
        error_state.has_error = false;
        error_state.message = "";
        error_state.code = 0;
        error_state.error_line = 0;
        error_state.mode = ErrorState::NONE;
    }
    
    // Whenever system utilities
    String get_whenever_status() const;
    void clear_whenever_sections();
    int get_active_whenever_count() const;
    void cleanup_scoped_whenever(const String& scope_type, const String& scope_context);
    void enter_scope(const String& scope_name);
    void exit_scope(const String& scope_name);
    
    // Multitasking utilities
    void execute_async_function(AsyncFunctionStatement* async_func);
    Variant execute_await(ExpressionNode* expr);
    void execute_task_run(TaskRunStatement* task);
    void execute_task_wait(TaskWaitStatement* wait_stmt);
    void execute_parallel_for(ParallelForStatement* par_for);
    void execute_parallel_section(ParallelSectionStatement* par_section);
    void update_tasks(); // Check task completion
    void _resume_coroutine(); // Resume suspended coroutine after await (v4.2.0)
    static void _task_worker_function(void* user_data);
    static void _parallel_worker_function(void* user_data, uint32_t index);
    static void _pfor_bytecode_worker(void* user_data, uint32_t index);
    static void _task_run_bc_worker(void* user_data);
    
    // Advanced type system utilities
    void execute_pattern_match(PatternMatchStatement* match_stmt);
    bool pattern_matches(Pattern* pattern, const Variant& value, Dictionary& captured_vars);
    AdvancedType* infer_type(const Variant& value);
    bool is_type_compatible(const AdvancedType* expected, const AdvancedType* actual);

    bool execute_bytecode(BytecodeChunk* chunk, SubDefinition* func, Variant &r_ret,
                          int p_ip_start = 0, int p_ip_end = -1,
                          const Vector<Variant>* p_initial_locals = nullptr);

    bool set(const StringName &p_name, const Variant &p_value);
    bool get(const StringName &p_name, Variant &r_ret);
    const GDExtensionPropertyInfo *get_property_list(uint32_t *r_count);
    void free_property_list(const GDExtensionPropertyInfo *p_list, uint32_t p_count);
    Variant::Type get_property_type(const StringName &p_name, bool *r_is_valid);
    bool validate_property(GDExtensionPropertyInfo *p_property);
    
    bool property_can_revert(const StringName &p_name);
    bool property_get_revert(const StringName &p_name, Variant &r_ret);

    Object *get_owner();
    Ref<Script> get_script();
    bool is_placeholder();

    void call(const StringName &p_method, const Variant *const *p_args, GDExtensionInt p_argcount, Variant *r_return, GDExtensionCallError *r_error);
    void notification(int32_t p_what);
    void to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out);

    // Class Management Methods
    Variant instantiate_class(const String& class_name, const Array& args);
    bool get_object_member(int obj_id, const String& member_name, Variant &r_ret);
    void set_object_member(int obj_id, const String& member_name, const Variant& value);
    Variant call_object_method(int obj_id, const String& method_name, const Array& args);
    void register_class(ClassDefinition* cls);
    void execute_class_method(ClassDefinition* cls, SubDefinition* method, int obj_id, const Array& args, Variant& r_ret);
    bool is_property_accessor(const String& prop_name, PropertyDefinition::PropertyType& type);
    Variant call_property_get(const String& prop_name, const Array& args);
    void call_property_let(const String& prop_name, const Array& args, const Variant& value);
    void call_property_set(const String& prop_name, const Array& args, const Variant& value);
    
    // Inheritance helpers
    ClassDefinition* get_class_def(const String& class_name);
    void collect_class_hierarchy(ClassDefinition* cls, Vector<ClassDefinition*>& chain);
    SubDefinition* find_method_in_hierarchy(ClassDefinition* cls, const String& method_name, int p_arg_count = -1);
    PropertyDefinition* find_property_in_hierarchy(ClassDefinition* cls, const String& prop_name, PropertyDefinition::PropertyType ptype);
    void init_members_from_hierarchy(ClassDefinition* cls, Dictionary& obj_data);
    
    // FFI/DLL Support
    void* load_library(const String& lib_name);
    void* get_function_address(void* lib_handle, const String& func_name);
    Variant call_ffi_function(DeclareStatement* decl, const Array& args);
    void register_declare(DeclareStatement* decl);
    
    // Debug support methods
    int get_debug_line() const { return debug_state.current_line; }
    String get_debug_file() const { return debug_state.current_file; }
    bool is_debug_paused() const { return debug_state.debug_paused; }
    void set_debug_paused(bool p_paused) { debug_state.debug_paused = p_paused; }
    void set_step_mode(DebugState::StepMode mode) { debug_state.step_mode = mode; }
    DebugState::StepMode get_step_mode() const { return debug_state.step_mode; }
    Dictionary get_debug_locals() const;
    Dictionary get_debug_globals() const { return variables; }
    SubDefinition* get_current_sub() const { return current_sub; }
    void _send_variables_to_debugger(EngineDebugger* debugger);
    void _send_call_stack_to_debugger(EngineDebugger* debugger);
    
    // Whenever section accessors for debugging
    Array get_debug_whenever_sections() const;
    void set_whenever_section_active(const String& section_name, bool active);

    // Lambda invocation helper (used by builtins for Map/Filter/Reduce etc.)
    Variant invoke_lambda(const Dictionary& lambda_dict, const Array& args);

    // Multi-module: find a Sub/Function across imported modules
    SubDefinition* find_imported_sub(const String& name, int arg_count = -1, String* r_module_name = nullptr);
    // Multi-module: find a Sub/Function in a specific imported module
    SubDefinition* find_sub_in_module(const String& module_name, const String& sub_name, int arg_count = -1);

    static const GDExtensionScriptInstanceInfo3 *get_script_instance_info();
};

// Debug registry for Immediate Window runtime access
namespace VisualGasicDebug {
    Array get_all_instances();
    VisualGasicInstance* get_instance_by_index(int index);
    String get_debug_registry_info();
    Dictionary get_instance_variables(int index);
    Array get_whenever_sections(int index);
    void set_whenever_active(int index, const String& section_name, bool active);
    void register_instance(VisualGasicInstance* instance);
    void unregister_instance(VisualGasicInstance* instance);
}

#endif // VISUAL_GASIC_INSTANCE_H

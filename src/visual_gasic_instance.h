#ifndef VISUAL_GASIC_INSTANCE_H
#define VISUAL_GASIC_INSTANCE_H

#include "visual_gasic_script.h"
#include "visual_gasic_bytecode.h"
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/os.hpp>

using namespace godot;

class VisualGasicInstance {
    Ref<VisualGasicScript> script;
    Object *owner;
    Dictionary variables; // Variable storage
    Dictionary open_files; // Map<int, Ref<FileAccess>>

    Ref<DirAccess> current_dir; // For Dir() iteration
    String dir_pattern; 
    bool option_compare_text;

    // VM State
    VMState vm;
    Vector<Variant> with_stack;

    // DATA / READ Support
    Vector<ExpressionNode*> data_segments; 
    Vector<ExpressionNode*> runtime_data_nodes; // Nodes created at execution time (LoadData)
    int data_pointer;
    Dictionary label_to_data_index; 
    
    // Dynamic Nodes Tracking (for CLS)
    Vector<uint64_t> dynamic_nodes;

    void scan_data_sections(ModuleNode* root);
    void collect_data_from_block(const Vector<Statement*>& block);

    Dictionary defined_structs; // Name -> StructDefinition* (wrapped or pointer?)
    // Storing pointers in Variant Dictionary is unsafe if not RefCounted.
    // StructDefinition is not RefCounted.
    // We can store a map: HashMap<String, StructDefinition*> struct_map;
    // But godot::HashMap is header internal?
    // Let's use std::map or just iterate script structs if number is low.
    // Or we can construct a Dictionary of Default Values for each struct eagerly.
    // Name -> Dictionary(default object).
    Dictionary struct_prototypes; 

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
        
        WheneverSection() : condition_expression(nullptr), is_active(true), last_trigger_time(0), debounce_ms(0), scope_type("global") {}
        
        ~WheneverSection() {
            // Note: condition_expression will be cleaned up by AST, don't delete here
        }
    };
    Vector<WheneverSection> whenever_sections;
    Vector<String> scope_stack;  // Track current scope hierarchy

    struct ErrorState {
        enum Mode { NONE, RESUME_NEXT, GOTO_LABEL, EXIT_SUB, EXIT_FOR, EXIT_DO, CONTINUE_FOR, CONTINUE_DO, CONTINUE_WHILE };
        Mode mode;
        String label;
        bool has_error;
        String message;
        int code; // Added
    } error_state;
    
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
    void raise_error(String msg, int code = 5);

public:
    VisualGasicInstance(Ref<VisualGasicScript> p_script, Object *p_owner);
    ~VisualGasicInstance();

    // Public helper for other modules (builtins) to evaluate expression nodes
    Variant evaluate_expression_for_builtins(ExpressionNode* expr);

    // File/Directory helpers exposed for builtins (refined names)
    Variant file_lof(int file_num);
    Variant file_loc(int file_num);
    Variant file_eof(int file_num);
    int file_free(int range);
    Variant file_len(const String &path);
    Variant file_dir(const Array &args);
    void randomize_seed();
    // Allow builtins to raise runtime errors via instance wrapper
    void raise_runtime_error(const String &p_msg, int p_code = 5);
    
    // Whenever system utilities
    String get_whenever_status() const;
    void clear_whenever_sections();
    int get_active_whenever_count() const;
    void cleanup_scoped_whenever(const String& scope_type, const String& scope_context);
    void enter_scope(const String& scope_name);
    void exit_scope(const String& scope_name);

    void execute_bytecode(BytecodeChunk* chunk);

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

    static const GDExtensionScriptInstanceInfo3 *get_script_instance_info();
};

#endif // VISUAL_GASIC_INSTANCE_H

#ifndef VISUAL_GASIC_INSTANCE_H
#define VISUAL_GASIC_INSTANCE_H

#include "visual_gasic_script.h"
#include "visual_gasic_bytecode.h"
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>

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

    void assign_to_target(ExpressionNode* target, Variant val);
    void assign_variable(const String& name, Variant val);

    void execute_statement(Statement* stmt);
    Variant evaluate_expression(ExpressionNode* expr);
    void raise_error(String msg, int code = 5);

public:
    VisualGasicInstance(Ref<VisualGasicScript> p_script, Object *p_owner);
    ~VisualGasicInstance();

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

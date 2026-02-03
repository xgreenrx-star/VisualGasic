#ifndef VISUAL_GASIC_IMMEDIATE_H
#define VISUAL_GASIC_IMMEDIATE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include "visual_gasic_parser.h"
#include "visual_gasic_script.h"

using namespace godot;

// Forward declare for runtime instance access
class VisualGasicInstance;

// GDScript-accessible REPL for the Immediate Window
class VisualGasicImmediate : public RefCounted {
    GDCLASS(VisualGasicImmediate, RefCounted);

    VisualGasicParser parser;
    Ref<VisualGasicScript> repl_script;
    Dictionary variables;  // Persistent variables across evaluations
    Array history;
    String accumulated_code;  // For multi-line statements
    int64_t connected_instance_ptr = 0;  // Currently connected game instance
    
    // Internal helpers
    String build_wrapper_script(const String& code);
    bool is_complete_statement(const String& code);

protected:
    static void _bind_methods();
    
public:
    VisualGasicImmediate();
    ~VisualGasicImmediate();
    
    // Core API exposed to GDScript
    Dictionary evaluate(const String& code);  // Returns {success: bool, result: String, type: String}
    void reset();
    Dictionary get_variables() const;
    void set_variable(const String& name, const Variant& value);
    Variant get_variable(const String& name) const;
    Array get_history() const;
    void clear_history();
    
    // Utility methods
    Array get_completions(const String& partial) const;
    String get_help() const;
    
    // === Runtime Instance Access ===
    // Get list of all active VisualGasic script instances
    Array get_running_instances() const;
    
    // Connect to a specific running instance for variable access
    bool connect_to_instance(int64_t instance_ptr);
    void disconnect_instance();
    bool is_instance_connected() const;
    
    // Get variables from the connected running instance
    Dictionary get_connected_instance_variables() const;
    
    // Get a specific variable from connected instance
    Variant get_runtime_variable(const String& name) const;
    
    // Set a variable in the connected instance (for debugging)
    bool set_runtime_variable(const String& name, const Variant& value);
    
    // Evaluate an expression in the context of the connected instance
    Dictionary evaluate_in_context(const String& code);
    
    // === Step Debugging Control ===
    // These methods control the step debugger state (call global language state)
    void debug_continue();
    void debug_step_into();
    void debug_step_over();
    void debug_step_out();
    int get_step_mode();
    int get_current_debug_line();
    String get_current_debug_file();
};

#endif // VISUAL_GASIC_IMMEDIATE_H

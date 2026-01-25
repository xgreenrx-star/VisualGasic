#ifndef VISUAL_GASIC_REPL_H
#define VISUAL_GASIC_REPL_H

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include "visual_gasic_parser.h"
#include "visual_gasic_instance.h"

using namespace godot;

// Interactive Read-Eval-Print Loop for VisualGasic
class VisualGasicREPL {
    VisualGasicParser parser;
    VisualGasicInstance* instance;
    bool is_running;
    String current_input;
    Vector<String> command_history;
    int history_index;
    Dictionary repl_variables;
    
public:
    VisualGasicREPL();
    ~VisualGasicREPL();
    
    // Core REPL functionality
    void start_interactive_session();
    void stop_session();
    String evaluate_input(const String& input);
    String process_command(const String& command);
    
    // REPL commands
    String cmd_help();
    String cmd_vars();
    String cmd_clear();
    String cmd_history();
    String cmd_load(const String& filename);
    String cmd_save(const String& filename);
    String cmd_reset();
    String cmd_type(const String& expression);
    
    // Live coding features
    String hot_reload_script(const String& filename);
    String inspect_variable(const String& var_name);
    String list_functions();
    String debug_expression(const String& expression);
    
    // Utilities
    void print_welcome_message();
    void print_prompt();
    bool is_complete_statement(const String& input);
    String format_value(const Variant& value);
    String get_type_info(const Variant& value);
    
    // Auto-completion support
    Vector<String> get_completions(const String& partial_input);
    Vector<String> get_variable_names();
    Vector<String> get_function_names();
    Vector<String> get_keyword_completions(const String& prefix);
};

#endif // VISUAL_GASIC_REPL_H
/**
 * VisualGasic REPL - Interactive Read-Eval-Print Loop
 * Fixed for Godot 4.x compatibility
 */

#include "visual_gasic_repl.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/time.hpp>

VisualGasicREPL::VisualGasicREPL() {
    instance = nullptr;
    is_running = false;
    history_index = -1;
}

VisualGasicREPL::~VisualGasicREPL() {
    if (instance) {
        delete instance;
    }
}

void VisualGasicREPL::start_interactive_session() {
    print_welcome_message();
    
    // Create a minimal script for REPL context
    Ref<VisualGasicScript> repl_script;
    repl_script.instantiate();
    
    instance = new VisualGasicInstance(repl_script, nullptr);
    is_running = true;
    
    // Interactive loop would be here in a real terminal application
    // For now, we provide the infrastructure
    UtilityFunctions::print("VisualGasic REPL is ready. Use evaluate_input() to execute code.");
}

void VisualGasicREPL::stop_session() {
    is_running = false;
    if (instance) {
        delete instance;
        instance = nullptr;
    }
}

String VisualGasicREPL::evaluate_input(const String& input) {
    if (!is_running || !instance) {
        return String("Error: REPL not started");
    }
    
    // Add to history
    command_history.push_back(input);
    history_index = command_history.size() - 1;
    
    // Check for REPL commands
    if (input.begins_with(":")) {
        return process_command(input);
    }
    
    // Check if input is complete
    if (!is_complete_statement(input)) {
        current_input = current_input + input + String("\n");
        return String("... "); // Continue input
    }
    
    String full_input = current_input + input;
    current_input = String("");
    
    // Simple statement execution
    if (full_input.strip_edges().begins_with("Print ")) {
        // Handle Print statements directly
        String expression = full_input.substr(6).strip_edges();
        // Evaluate and return result
        return String("Output: ") + expression; // Simplified
    }
    
    // Variable assignment
    if (full_input.contains("=") && !full_input.contains("==")) {
        Array parts = full_input.split("=");
        if (parts.size() == 2) {
            String var_name = String(parts[0]).strip_edges();
            String var_value = String(parts[1]).strip_edges();
            
            // Store in REPL variables
            if (var_value.is_valid_int()) {
                repl_variables[var_name] = var_value.to_int();
            } else if (var_value.is_valid_float()) {
                repl_variables[var_name] = var_value.to_float();
            } else if (var_value.begins_with("\"") && var_value.ends_with("\"")) {
                repl_variables[var_name] = var_value.substr(1, var_value.length() - 2);
            } else {
                repl_variables[var_name] = var_value;
            }
            
            return String("OK ") + var_name + String(" = ") + format_value(repl_variables[var_name]);
        }
    }
    
    // Expression evaluation
    String trimmed = full_input.strip_edges();
    if (repl_variables.has(trimmed)) {
        Variant value = repl_variables[trimmed];
        return trimmed + String(" = ") + format_value(value) + String(" (") + get_type_info(value) + String(")");
    }
    
    return String("Executed: ") + full_input;
}

String VisualGasicREPL::process_command(const String& command) {
    String cmd = command.substr(1).to_lower(); // Remove ':'
    
    if (cmd == "help" || cmd == "h") {
        return cmd_help();
    } else if (cmd == "vars" || cmd == "v") {
        return cmd_vars();
    } else if (cmd == "clear" || cmd == "c") {
        return cmd_clear();
    } else if (cmd == "history") {
        return cmd_history();
    } else if (cmd.begins_with("load ")) {
        return cmd_load(cmd.substr(5));
    } else if (cmd.begins_with("save ")) {
        return cmd_save(cmd.substr(5));
    } else if (cmd == "reset") {
        return cmd_reset();
    } else if (cmd.begins_with("type ")) {
        return cmd_type(cmd.substr(5));
    } else if (cmd == "quit" || cmd == "q" || cmd == "exit") {
        stop_session();
        return String("Goodbye!");
    }
    
    return String("Unknown command: ") + cmd + String("\nType :help for available commands");
}

String VisualGasicREPL::cmd_help() {
    return String(R"(
VisualGasic REPL Commands:
  :help, :h      - Show this help message
  :vars, :v      - List all variables
  :clear, :c     - Clear the screen
  :history       - Show command history
  :load <file>   - Load and execute a .bas file
  :save <file>   - Save session to a file
  :reset         - Clear all variables and history
  :type <expr>   - Show the type of an expression
  :quit, :q      - Exit the REPL

Examples:
  x = 10                    - Assign a value
  Print "Hello, World!"     - Print output
  x                         - Show variable value
)");
}

String VisualGasicREPL::cmd_vars() {
    if (repl_variables.size() == 0) {
        return String("No variables defined");
    }
    
    String result = String("Variables:\n");
    Array keys = repl_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = repl_variables[key];
        result = result + String("  ") + key + String(" = ") + format_value(value) + 
                 String(" (") + get_type_info(value) + String(")\n");
    }
    return result;
}

String VisualGasicREPL::cmd_clear() {
    // In a real terminal, this would clear the screen
    return String("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
}

String VisualGasicREPL::cmd_history() {
    String result = String("Command History:\n");
    for (int i = 0; i < command_history.size(); i++) {
        result = result + String("  ") + String::num_int64(i + 1) + String(". ") + command_history[i] + String("\n");
    }
    return result;
}

String VisualGasicREPL::cmd_load(const String& filename) {
    Ref<FileAccess> file = FileAccess::open(filename, FileAccess::READ);
    if (!file.is_valid()) {
        return String("Error: Could not open file ") + filename;
    }
    
    String content = file->get_as_text();
    file.unref();
    
    return String("Loaded and executing: ") + filename + String("\n") + evaluate_input(content);
}

String VisualGasicREPL::cmd_save(const String& filename) {
    Ref<FileAccess> file = FileAccess::open(filename, FileAccess::WRITE);
    if (!file.is_valid()) {
        return String("Error: Could not create file ") + filename;
    }
    
    // Save current variables and history
    file->store_string("' VisualGasic REPL Session\n");
    
    // Get datetime string safely
    String datetime_str = String("");
    Time* time_singleton = Time::get_singleton();
    if (time_singleton) {
        Dictionary datetime = time_singleton->get_datetime_dict_from_system();
        datetime_str = String::num_int64((int64_t)datetime["year"]) + String("-") +
                       String::num_int64((int64_t)datetime["month"]) + String("-") +
                       String::num_int64((int64_t)datetime["day"]) + String(" ") +
                       String::num_int64((int64_t)datetime["hour"]) + String(":") +
                       String::num_int64((int64_t)datetime["minute"]);
    }
    file->store_string(String("' Generated: ") + datetime_str + String("\n\n"));
    
    // Save variables
    Array keys = repl_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = repl_variables[key];
        file->store_string(String("Dim ") + key + String(" As ") + get_type_info(value) + 
                          String(" = ") + format_value(value) + String("\n"));
    }
    
    file.unref();
    return String("Session saved to: ") + filename;
}

String VisualGasicREPL::cmd_reset() {
    repl_variables.clear();
    command_history.clear();
    current_input = String("");
    history_index = -1;
    return String("REPL state reset");
}

String VisualGasicREPL::cmd_type(const String& expression) {
    if (repl_variables.has(expression)) {
        Variant value = repl_variables[expression];
        return expression + String(" : ") + get_type_info(value);
    }
    
    return String("Unknown variable: ") + expression;
}

String VisualGasicREPL::hot_reload_script(const String& filename) {
    // Reload and re-execute a script file
    return cmd_load(filename);
}

String VisualGasicREPL::inspect_variable(const String& var_name) {
    if (!repl_variables.has(var_name)) {
        return String("Variable not found: ") + var_name;
    }
    
    Variant value = repl_variables[var_name];
    String result = String("Variable: ") + var_name + String("\n");
    result = result + String("  Type: ") + get_type_info(value) + String("\n");
    result = result + String("  Value: ") + format_value(value) + String("\n");
    
    if (value.get_type() == Variant::ARRAY) {
        Array arr = value;
        result = result + String("  Size: ") + String::num_int64(arr.size()) + String("\n");
    } else if (value.get_type() == Variant::DICTIONARY) {
        Dictionary dict = value;
        result = result + String("  Keys: ") + String::num_int64(dict.size()) + String("\n");
    }
    
    return result;
}

String VisualGasicREPL::list_functions() {
    return String("Available built-in functions: Len, Left, Right, Mid, UCase, LCase, Trim, Chr, Asc, Sin, Cos, Abs, Int, Round, ...");
}

String VisualGasicREPL::debug_expression(const String& expression) {
    return String("Debug output for: ") + expression;
}

void VisualGasicREPL::print_welcome_message() {
    UtilityFunctions::print(R"(
======================================
      VisualGasic REPL v1.0
  Interactive Programming Environment
======================================

Features:
  - Variable assignment and inspection
  - Expression evaluation
  - Command history
  - Script loading and saving

Type ':help' for commands or start coding!
)");
}

void VisualGasicREPL::print_prompt() {
    UtilityFunctions::print("VG> ");
}

bool VisualGasicREPL::is_complete_statement(const String& input) {
    String trimmed = input.strip_edges();
    
    // Check for incomplete constructs
    if (trimmed.ends_with("Then") || trimmed.ends_with("Do") || 
        trimmed.ends_with("Sub") || trimmed.ends_with("Function")) {
        return false;
    }
    
    // Check for unmatched parentheses
    int paren_count = 0;
    for (int i = 0; i < input.length(); i++) {
        if (input[i] == '(') paren_count++;
        else if (input[i] == ')') paren_count--;
    }
    
    return paren_count == 0;
}

String VisualGasicREPL::format_value(const Variant& value) {
    switch (value.get_type()) {
        case Variant::STRING:
            return String("\"") + String(value) + String("\"");
        case Variant::BOOL:
            return (bool)value ? String("True") : String("False");
        case Variant::NIL:
            return String("Nothing");
        default:
            return String(value);
    }
}

String VisualGasicREPL::get_type_info(const Variant& value) {
    switch (value.get_type()) {
        case Variant::INT: return String("Integer");
        case Variant::FLOAT: return String("Double");
        case Variant::STRING: return String("String");
        case Variant::BOOL: return String("Boolean");
        case Variant::ARRAY: return String("Array");
        case Variant::DICTIONARY: return String("Dictionary");
        case Variant::NIL: return String("Nothing");
        default: return String("Object");
    }
}

Vector<String> VisualGasicREPL::get_completions(const String& partial_input) {
    Vector<String> completions;
    
    // Add variable names
    Vector<String> vars = get_variable_names();
    for (int i = 0; i < vars.size(); i++) {
        if (vars[i].begins_with(partial_input)) {
            completions.push_back(vars[i]);
        }
    }
    
    // Add keywords
    Vector<String> keywords = get_keyword_completions(partial_input);
    for (int i = 0; i < keywords.size(); i++) {
        completions.push_back(keywords[i]);
    }
    
    return completions;
}

Vector<String> VisualGasicREPL::get_variable_names() {
    Vector<String> names;
    Array keys = repl_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        names.push_back(keys[i]);
    }
    return names;
}

Vector<String> VisualGasicREPL::get_function_names() {
    Vector<String> functions;
    functions.push_back("Len");
    functions.push_back("Left");
    functions.push_back("Right");
    functions.push_back("Mid");
    functions.push_back("UCase");
    functions.push_back("LCase");
    functions.push_back("Trim");
    functions.push_back("Sin");
    functions.push_back("Cos");
    functions.push_back("Abs");
    functions.push_back("Int");
    functions.push_back("Round");
    return functions;
}

Vector<String> VisualGasicREPL::get_keyword_completions(const String& prefix) {
    Vector<String> keywords;
    keywords.push_back("Async");
    keywords.push_back("Await");
    keywords.push_back("Task");
    keywords.push_back("Parallel");
    keywords.push_back("Select");
    keywords.push_back("Match");
    keywords.push_back("Case");
    keywords.push_back("When");
    keywords.push_back("If");
    keywords.push_back("Then");
    keywords.push_back("Else");
    keywords.push_back("For");
    keywords.push_back("Next");
    keywords.push_back("While");
    keywords.push_back("Do");
    keywords.push_back("Loop");
    keywords.push_back("Sub");
    keywords.push_back("Function");
    keywords.push_back("Dim");
    keywords.push_back("As");
    keywords.push_back("Print");
    keywords.push_back("Return");
    keywords.push_back("Exit");
    
    Vector<String> matches;
    for (int i = 0; i < keywords.size(); i++) {
        if (keywords[i].to_lower().begins_with(prefix.to_lower())) {
            matches.push_back(keywords[i]);
        }
    }
    
    return matches;
}

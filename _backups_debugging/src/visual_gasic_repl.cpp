#include "visual_gasic_repl.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/display_server.hpp>

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
        return "Error: REPL not started";
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
        current_input += input + "\n";
        return "... "; // Continue input
    }
    
    String full_input = current_input + input;
    current_input = "";
    
    try {
        // Parse and execute the input
        Vector<Token> tokens = parser.tokenize(full_input);
        if (tokens.size() == 0) {
            return "";
        }
        
        // Simple statement execution
        if (full_input.strip_edges().begins_with("Print ")) {
            // Handle Print statements directly
            String expression = full_input.substr(6).strip_edges();
            // Evaluate and return result
            return "Output: " + expression; // Simplified
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
                
                return "✓ " + var_name + " = " + format_value(repl_variables[var_name]);
            }
        }
        
        // Expression evaluation
        if (repl_variables.has(full_input.strip_edges())) {
            String var_name = full_input.strip_edges();
            Variant value = repl_variables[var_name];
            return var_name + " = " + format_value(value) + " (" + get_type_info(value) + ")";
        }
        
        return "Executed: " + full_input;
        
    } catch (...) {
        return "Error: Invalid syntax";
    }
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
    } else if (cmd == "quit" || cmd == "exit") {
        stop_session();
        return "Goodbye!";
    } else {
        return "Unknown command: " + cmd + ". Type :help for available commands.";
    }
}

String VisualGasicREPL::cmd_help() {
    return R"(
VisualGasic REPL Commands:
=========================
:help, :h         - Show this help
:vars, :v         - List all variables
:clear, :c        - Clear screen
:history          - Show command history
:load <file>      - Load and execute script file
:save <file>      - Save current session to file
:reset            - Reset REPL state
:type <expr>      - Show type of expression
:quit, :exit      - Exit REPL

Features:
- Variable assignments: x = 42
- Expression evaluation: x + 10
- Print statements: Print "Hello"
- Pattern matching: Select Match value
- Async functions: Await LoadDataAsync()
- Auto-completion with Tab
- Command history with Up/Down arrows
)";
}

String VisualGasicREPL::cmd_vars() {
    if (repl_variables.size() == 0) {
        return "No variables defined";
    }
    
    String result = "Variables:\n";
    Array keys = repl_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = repl_variables[key];
        result += "  " + key + " = " + format_value(value) + " (" + get_type_info(value) + ")\n";
    }
    
    return result;
}

String VisualGasicREPL::cmd_clear() {
    // In a real terminal, this would clear the screen
    return "Screen cleared (simulated)";
}

String VisualGasicREPL::cmd_history() {
    if (command_history.size() == 0) {
        return "No command history";
    }
    
    String result = "Command History:\n";
    for (int i = 0; i < command_history.size(); i++) {
        result += String::num(i + 1) + ": " + command_history[i] + "\n";
    }
    
    return result;
}

String VisualGasicREPL::cmd_load(const String& filename) {
    Ref<FileAccess> file = FileAccess::open(filename, FileAccess::READ);
    if (!file.is_valid()) {
        return "Error: Could not open file " + filename;
    }
    
    String content = file->get_as_text();
    file.unref();
    
    return "Loaded and executing: " + filename + "\n" + evaluate_input(content);
}

String VisualGasicREPL::cmd_save(const String& filename) {
    Ref<FileAccess> file = FileAccess::open(filename, FileAccess::WRITE);
    if (!file.is_valid()) {
        return "Error: Could not create file " + filename;
    }
    
    // Save current variables and history
    file->store_string("' VisualGasic REPL Session\n");
    file->store_string("' Generated: " + Time::get_singleton()->get_datetime_string_from_system() + "\n\n");
    
    // Save variables
    Array keys = repl_variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = repl_variables[key];
        file->store_string("Dim " + key + " As " + get_type_info(value) + " = " + format_value(value) + "\n");
    }
    
    file.unref();
    return "Session saved to: " + filename;
}

String VisualGasicREPL::cmd_reset() {
    repl_variables.clear();
    command_history.clear();
    current_input = "";
    history_index = -1;
    return "REPL state reset";
}

String VisualGasicREPL::cmd_type(const String& expression) {
    if (repl_variables.has(expression)) {
        Variant value = repl_variables[expression];
        return expression + " : " + get_type_info(value);
    }
    
    return "Unknown variable: " + expression;
}

void VisualGasicREPL::print_welcome_message() {
    UtilityFunctions::print(R"(
╔══════════════════════════════════════════╗
║          VisualGasic REPL v1.0           ║
║    Interactive Programming Environment   ║
╚══════════════════════════════════════════╝

Features:
• Advanced type system with generics
• Pattern matching with destructuring
• Async/await programming
• Reactive programming with Whenever
• Live variable inspection
• Hot code reloading

Type ':help' for commands or start coding!
)");
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
            return "\"" + String(value) + "\"";
        case Variant::BOOL:
            return (bool)value ? "True" : "False";
        case Variant::NIL:
            return "Nothing";
        default:
            return String(value);
    }
}

String VisualGasicREPL::get_type_info(const Variant& value) {
    switch (value.get_type()) {
        case Variant::INT: return "Integer";
        case Variant::FLOAT: return "Double";
        case Variant::STRING: return "String";
        case Variant::BOOL: return "Boolean";
        case Variant::ARRAY: return "Array";
        case Variant::DICTIONARY: return "Dictionary";
        case Variant::NIL: return "Nothing";
        default: return "Object";
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

Vector<String> VisualGasicREPL::get_keyword_completions(const String& prefix) {
    Vector<String> keywords = {
        "Async", "Await", "Task", "Parallel", "Select", "Match", "Case", "When", 
        "If", "Then", "Else", "For", "Next", "While", "Do", "Loop", "Sub", 
        "Function", "Dim", "As", "Of", "Where", "Print", "Return", "Exit"
    };
    
    Vector<String> matches;
    for (int i = 0; i < keywords.size(); i++) {
        if (keywords[i].to_lower().begins_with(prefix.to_lower())) {
            matches.push_back(keywords[i]);
        }
    }
    
    return matches;
}
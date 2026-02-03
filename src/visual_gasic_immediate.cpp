#include "visual_gasic_immediate.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_language.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/object.hpp>

using namespace godot;

// VisualGasicDebug namespace is declared in visual_gasic_instance.h

void VisualGasicImmediate::_bind_methods() {
    ClassDB::bind_method(D_METHOD("evaluate", "code"), &VisualGasicImmediate::evaluate);
    ClassDB::bind_method(D_METHOD("reset"), &VisualGasicImmediate::reset);
    ClassDB::bind_method(D_METHOD("get_variables"), &VisualGasicImmediate::get_variables);
    ClassDB::bind_method(D_METHOD("set_variable", "name", "value"), &VisualGasicImmediate::set_variable);
    ClassDB::bind_method(D_METHOD("get_variable", "name"), &VisualGasicImmediate::get_variable);
    ClassDB::bind_method(D_METHOD("get_history"), &VisualGasicImmediate::get_history);
    ClassDB::bind_method(D_METHOD("clear_history"), &VisualGasicImmediate::clear_history);
    ClassDB::bind_method(D_METHOD("get_completions", "partial"), &VisualGasicImmediate::get_completions);
    ClassDB::bind_method(D_METHOD("get_help"), &VisualGasicImmediate::get_help);
    
    // Runtime instance access methods
    ClassDB::bind_method(D_METHOD("get_running_instances"), &VisualGasicImmediate::get_running_instances);
    ClassDB::bind_method(D_METHOD("connect_to_instance", "instance_ptr"), &VisualGasicImmediate::connect_to_instance);
    ClassDB::bind_method(D_METHOD("disconnect_instance"), &VisualGasicImmediate::disconnect_instance);
    ClassDB::bind_method(D_METHOD("is_instance_connected"), &VisualGasicImmediate::is_instance_connected);
    ClassDB::bind_method(D_METHOD("get_connected_instance_variables"), &VisualGasicImmediate::get_connected_instance_variables);
    ClassDB::bind_method(D_METHOD("get_runtime_variable", "name"), &VisualGasicImmediate::get_runtime_variable);
    ClassDB::bind_method(D_METHOD("set_runtime_variable", "name", "value"), &VisualGasicImmediate::set_runtime_variable);
    ClassDB::bind_method(D_METHOD("evaluate_in_context", "code"), &VisualGasicImmediate::evaluate_in_context);
    
    // Step debugging methods - bound as instance methods that access global state
    ClassDB::bind_method(D_METHOD("debug_continue"), &VisualGasicImmediate::debug_continue);
    ClassDB::bind_method(D_METHOD("debug_step_into"), &VisualGasicImmediate::debug_step_into);
    ClassDB::bind_method(D_METHOD("debug_step_over"), &VisualGasicImmediate::debug_step_over);
    ClassDB::bind_method(D_METHOD("debug_step_out"), &VisualGasicImmediate::debug_step_out);
    ClassDB::bind_method(D_METHOD("get_step_mode"), &VisualGasicImmediate::get_step_mode);
    ClassDB::bind_method(D_METHOD("get_current_debug_line"), &VisualGasicImmediate::get_current_debug_line);
    ClassDB::bind_method(D_METHOD("get_current_debug_file"), &VisualGasicImmediate::get_current_debug_file);
}

VisualGasicImmediate::VisualGasicImmediate() {
    repl_script.instantiate();
    connected_instance_ptr = 0;
}

VisualGasicImmediate::~VisualGasicImmediate() {
}

bool VisualGasicImmediate::is_complete_statement(const String& code) {
    String trimmed = code.strip_edges();
    
    // Check for incomplete block statements
    String upper = trimmed.to_upper();
    
    // Count open/close pairs
    int if_count = 0, for_count = 0, while_count = 0, do_count = 0, sub_count = 0, func_count = 0;
    
    PackedStringArray lines = trimmed.split("\n");
    for (int i = 0; i < lines.size(); i++) {
        String line = lines[i].strip_edges().to_upper();
        
        // Skip comments and blank lines
        if (line.begins_with("'") || line.is_empty()) continue;
        
        if (line.begins_with("IF ") && !line.contains(" THEN ") && !line.ends_with(" THEN")) if_count++;
        else if (line.begins_with("IF ") && line.contains(" THEN ") && !line.contains(" ELSE ")) ; // Single-line If
        else if (line.begins_with("IF ")) if_count++;
        if (line == "END IF" || line == "ENDIF") if_count--;
        
        if (line.begins_with("FOR ")) for_count++;
        if (line.begins_with("NEXT")) for_count--;
        
        if (line.begins_with("WHILE ")) while_count++;
        if (line == "WEND") while_count--;
        
        if (line.begins_with("DO")) do_count++;
        if (line.begins_with("LOOP")) do_count--;
        
        if (line.begins_with("SUB ")) sub_count++;
        if (line == "END SUB") sub_count--;
        
        if (line.begins_with("FUNCTION ")) func_count++;
        if (line == "END FUNCTION") func_count--;
    }
    
    return (if_count <= 0 && for_count <= 0 && while_count <= 0 && 
            do_count <= 0 && sub_count <= 0 && func_count <= 0);
}

String VisualGasicImmediate::build_wrapper_script(const String& code) {
    // Build a script that includes persistent variables and the code to evaluate
    String script = "";
    
    // Declare persistent variables
    Array keys = variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String name = keys[i];
        Variant value = variables[name];
        
        String type_str = "Variant";
        switch (value.get_type()) {
            case Variant::INT: type_str = "Integer"; break;
            case Variant::FLOAT: type_str = "Single"; break;
            case Variant::STRING: type_str = "String"; break;
            case Variant::BOOL: type_str = "Boolean"; break;
            default: type_str = "Variant"; break;
        }
        
        // Format value as literal
        String value_str;
        if (value.get_type() == Variant::STRING) {
            value_str = "\"" + String(value).replace("\"", "\"\"") + "\"";
        } else if (value.get_type() == Variant::BOOL) {
            value_str = value.booleanize() ? "True" : "False";
        } else {
            value_str = String(value);
        }
        
        script += "Dim " + name + " As " + type_str + " = " + value_str + "\n";
    }
    
    script += String("\n' User code:\n");
    script += code;
    script += String("\n");
    
    return script;
}

Dictionary VisualGasicImmediate::evaluate(const String& code) {
    Dictionary result;
    result["success"] = false;
    result["result"] = "";
    result["type"] = "";
    result["output"] = "";
    
    String trimmed = code.strip_edges();
    if (trimmed.is_empty()) {
        result["success"] = true;
        return result;
    }
    
    // Add to history
    history.push_back(code);
    
    // Accumulate multi-line input
    accumulated_code += code;
    accumulated_code += String("\n");
    
    if (!is_complete_statement(accumulated_code)) {
        result["success"] = true;
        result["result"] = "...";
        result["continue"] = true;
        return result;
    }
    
    String full_code = accumulated_code.strip_edges();
    accumulated_code = "";
    
    // Special handling for expression-only input (evaluate and return result)
    bool is_expression = false;
    String upper = full_code.to_upper();
    
    // Check if it's just an expression (not a statement)
    if (!upper.begins_with("DIM ") && !upper.begins_with("PRINT ") && 
        !upper.begins_with("IF ") && !upper.begins_with("FOR ") &&
        !upper.begins_with("WHILE ") && !upper.begins_with("DO ") &&
        !upper.begins_with("SUB ") && !upper.begins_with("FUNCTION ") &&
        !upper.begins_with("CALL ") && !upper.begins_with("SET ") &&
        !upper.begins_with("LET ") && !upper.contains("\n")) {
        
        // Check if it's an assignment
        if (full_code.contains("=") && !full_code.contains("==") && 
            !full_code.contains("<=") && !full_code.contains(">=") &&
            !full_code.contains("<>")) {
            // It's an assignment - let it through as-is
        } else {
            // It's an expression - wrap in PRINT for output capture
            is_expression = true;
        }
    }
    
    // Build the wrapper script
    String wrapper_code;
    if (is_expression) {
        // Wrap expression to capture result
        wrapper_code = build_wrapper_script("Dim __result__ As Variant = " + full_code + "\nPrint __result__");
    } else if (upper.begins_with("PRINT ")) {
        wrapper_code = build_wrapper_script(full_code);
    } else {
        wrapper_code = build_wrapper_script(full_code);
    }
    
    // Parse and execute
    repl_script.instantiate();
    repl_script->set_source_code(wrapper_code);
    repl_script->reload(false);
    
    // Check for parse errors - if ast_root is null, parsing failed
    if (repl_script->ast_root == nullptr) {
        result["success"] = false;
        result["result"] = String("Parse Error: Failed to parse code");
        return result;
    }
    
    // Create a temporary node to run the script
    Node* temp_node = memnew(Node);
    temp_node->set_script(repl_script);
    
    // The script should execute on _ready or we need to call Form_Load
    // For immediate execution, we'll trigger notification
    temp_node->notification(Node::NOTIFICATION_READY);
    
    // Try to extract result and output
    // The instance should have updated variables
    // For now, we'll just report success
    
    result["success"] = true;
    result["result"] = "OK";
    
    // Check if we can get any output or return value
    // This requires the instance to expose its state
    
    // Clean up
    memdelete(temp_node);
    
    return result;
}

void VisualGasicImmediate::reset() {
    variables.clear();
    accumulated_code = "";
    repl_script.instantiate();
}

Dictionary VisualGasicImmediate::get_variables() const {
    return variables;
}

void VisualGasicImmediate::set_variable(const String& name, const Variant& value) {
    variables[name] = value;
}

Variant VisualGasicImmediate::get_variable(const String& name) const {
    if (variables.has(name)) {
        return variables[name];
    }
    return Variant();
}

Array VisualGasicImmediate::get_history() const {
    return history;
}

void VisualGasicImmediate::clear_history() {
    history.clear();
}

Array VisualGasicImmediate::get_completions(const String& partial) const {
    Array completions;
    String upper = partial.to_upper();
    
    // Keywords
    static const char* keywords[] = {
        "Dim", "As", "Integer", "String", "Single", "Double", "Boolean", "Variant",
        "If", "Then", "Else", "ElseIf", "End If", "For", "To", "Step", "Next",
        "While", "Wend", "Do", "Loop", "Until", "Sub", "Function", "End Sub", "End Function",
        "Print", "Debug.Print", "MsgBox", "InputBox", "Call", "Set", "Let",
        "And", "Or", "Not", "Mod", "True", "False", "Nothing", "Null",
        "Exit Sub", "Exit Function", "Exit For", "Exit Do", "Exit While",
        nullptr
    };
    
    for (int i = 0; keywords[i] != nullptr; i++) {
        String kw = keywords[i];
        if (kw.to_upper().begins_with(upper)) {
            completions.push_back(kw);
        }
    }
    
    // Builtin functions
    static const char* builtins[] = {
        "Len", "Left", "Right", "Mid", "InStr", "InStrRev", "Replace", "Split", "Join",
        "Trim", "LTrim", "RTrim", "UCase", "LCase", "StrComp", "String", "Space",
        "Chr", "Asc", "Val", "Str", "CStr", "CInt", "CLng", "CSng", "CDbl", "CBool",
        "Abs", "Sgn", "Int", "Fix", "Round", "Sqr", "Exp", "Log", "Sin", "Cos", "Tan",
        "Atn", "Rnd", "Randomize", "Timer", "Now", "Date", "Time", "Year", "Month", "Day",
        "Hour", "Minute", "Second", "DateAdd", "DateDiff", "DatePart", "Format",
        "Array", "UBound", "LBound", "IsArray", "IsNumeric", "IsDate", "IsEmpty", "IsNull",
        "IIf", "Choose", "Switch", "TypeName", "VarType",
        nullptr
    };
    
    for (int i = 0; builtins[i] != nullptr; i++) {
        String fn = builtins[i];
        if (fn.to_upper().begins_with(upper)) {
            completions.push_back(fn);
        }
    }
    
    // Session variables
    Array keys = variables.keys();
    for (int i = 0; i < keys.size(); i++) {
        String name = keys[i];
        if (name.to_upper().begins_with(upper)) {
            completions.push_back(name);
        }
    }
    
    return completions;
}

String VisualGasicImmediate::get_help() const {
    return R"(
VisualGasic Immediate Window - Help

EXPRESSIONS:
  2 + 2                   Evaluate expression and show result
  Len("Hello")            Call functions
  x * 10                  Use variables in expressions

STATEMENTS:
  Dim x As Integer = 42   Declare variables
  x = x + 1               Assign to variables
  Print x                 Print output

BUILTIN FUNCTIONS:
  String: Len, Left, Right, Mid, InStr, Replace, Trim, UCase, LCase
  Math: Abs, Sqr, Sin, Cos, Round, Rnd, Int
  Conversion: CStr, CInt, Val, Chr, Asc
  Date/Time: Now, Timer, Year, Month, Day

COMMANDS:
  :help       Show this help
  :vars       List all variables
  :clear      Clear output
  :reset      Reset session (clear variables)
  :instances  List running VisualGasic instances
  :connect N  Connect to instance N for live debugging
  :disconnect Disconnect from running instance

RUNTIME DEBUGGING:
  Print Ball_x            Print variable from connected instance
  ? player.position       Shortcut for Print
  Ball_x = 100            Modify variable in running game

TIPS:
  - Variables persist across evaluations
  - Use Shift+Enter for multi-line input
  - Press Enter to execute
  - Connect to a running game to access its variables
)";
}

// === Runtime Instance Access Implementation ===

Array VisualGasicImmediate::get_running_instances() const {
    return VisualGasicDebug::get_all_instances();
}

bool VisualGasicImmediate::connect_to_instance(int64_t instance_ptr) {
    // Validate that the instance exists in our registry
    Array instances = VisualGasicDebug::get_all_instances();
    for (int i = 0; i < instances.size(); i++) {
        Dictionary info = instances[i];
        if ((int64_t)info.get("instance_ptr", 0) == instance_ptr) {
            connected_instance_ptr = instance_ptr;
            return true;
        }
    }
    return false;
}

void VisualGasicImmediate::disconnect_instance() {
    connected_instance_ptr = 0;
}

bool VisualGasicImmediate::is_instance_connected() const {
    if (connected_instance_ptr == 0) return false;
    
    // Verify the instance is still valid
    Array instances = VisualGasicDebug::get_all_instances();
    for (int i = 0; i < instances.size(); i++) {
        Dictionary info = instances[i];
        if ((int64_t)info.get("instance_ptr", 0) == connected_instance_ptr) {
            return true;
        }
    }
    // Instance no longer exists
    return false;
}

Dictionary VisualGasicImmediate::get_connected_instance_variables() const {
    Dictionary result;
    
    if (!is_instance_connected()) {
        return result;
    }
    
    VisualGasicInstance* inst = reinterpret_cast<VisualGasicInstance*>(connected_instance_ptr);
    if (!inst) return result;
    
    // Get all known variable names by iterating through properties
    // We use the public get() method which is safe
    // Note: This is a simplified implementation - a full one would
    // query the script's declared variables from the AST
    
    // For now, we'll try to get commonly used game variables
    static const char* common_vars[] = {
        "Ball", "Paddle1", "Paddle2", "Score1", "Score2",
        "Ball_x", "Ball_y", "BallVelX", "BallVelY",
        "player", "enemy", "score", "health", "lives",
        "x", "y", "speed", "direction",
        nullptr
    };
    
    for (int i = 0; common_vars[i] != nullptr; i++) {
        Variant val;
        if (inst->get(StringName(common_vars[i]), val)) {
            result[common_vars[i]] = val;
        }
    }
    
    return result;
}

Variant VisualGasicImmediate::get_runtime_variable(const String& name) const {
    if (!is_instance_connected()) {
        return Variant();
    }
    
    VisualGasicInstance* inst = reinterpret_cast<VisualGasicInstance*>(connected_instance_ptr);
    if (!inst) return Variant();
    
    Variant result;
    if (inst->get(StringName(name), result)) {
        return result;
    }
    return Variant();
}

bool VisualGasicImmediate::set_runtime_variable(const String& name, const Variant& value) {
    if (!is_instance_connected()) {
        return false;
    }
    
    VisualGasicInstance* inst = reinterpret_cast<VisualGasicInstance*>(connected_instance_ptr);
    if (!inst) return false;
    
    return inst->set(StringName(name), value);
}

Dictionary VisualGasicImmediate::evaluate_in_context(const String& code) {
    Dictionary result;
    result["success"] = false;
    result["result"] = "";
    
    String trimmed = code.strip_edges();
    if (trimmed.is_empty()) {
        result["success"] = true;
        return result;
    }
    
    // Check if it's a Print or ? query for a runtime variable
    String upper = trimmed.to_upper();
    bool is_print = upper.begins_with("PRINT ") || trimmed.begins_with("? ");
    
    if (is_print && is_instance_connected()) {
        String var_name;
        if (trimmed.begins_with("? ")) {
            var_name = trimmed.substr(2).strip_edges();
        } else {
            var_name = trimmed.substr(6).strip_edges();
        }
        
        // Try to get from connected instance first
        Variant val = get_runtime_variable(var_name);
        if (val.get_type() != Variant::NIL) {
            result["success"] = true;
            result["result"] = String(val);
            result["from_runtime"] = true;
            return result;
        }
        
        // Fall back to local variables
        if (variables.has(var_name)) {
            result["success"] = true;
            result["result"] = String(variables[var_name]);
            return result;
        }
        
        result["success"] = false;
        result["result"] = "Variable not found: " + var_name;
        return result;
    }
    
    // Check for assignment to runtime variable
    if (trimmed.contains("=") && !trimmed.contains("==") && is_instance_connected()) {
        int eq_pos = trimmed.find("=");
        String var_name = trimmed.substr(0, eq_pos).strip_edges();
        String val_str = trimmed.substr(eq_pos + 1).strip_edges();
        
        // Try to parse the value
        Variant new_val;
        if (val_str.is_valid_int()) {
            new_val = val_str.to_int();
        } else if (val_str.is_valid_float()) {
            new_val = val_str.to_float();
        } else if ((val_str.begins_with("\"") && val_str.ends_with("\"")) ||
                   (val_str.begins_with("'") && val_str.ends_with("'"))) {
            new_val = val_str.substr(1, val_str.length() - 2);
        } else if (val_str.to_upper() == "TRUE") {
            new_val = true;
        } else if (val_str.to_upper() == "FALSE") {
            new_val = false;
        } else {
            // Try to get from another variable
            Variant other = get_runtime_variable(val_str);
            if (other.get_type() != Variant::NIL) {
                new_val = other;
            } else {
                new_val = val_str; // String fallback
            }
        }
        
        if (set_runtime_variable(var_name, new_val)) {
            result["success"] = true;
            result["result"] = var_name + " = " + String(new_val);
            result["modified_runtime"] = true;
            return result;
        }
    }
    
    // Fall back to regular evaluation
    return evaluate(code);
}

// === Step Debugging Control ===

void VisualGasicImmediate::debug_continue() {
    VisualGasicLanguage::debug_continue();
}

void VisualGasicImmediate::debug_step_into() {
    VisualGasicLanguage::debug_step_into();
}

void VisualGasicImmediate::debug_step_over() {
    VisualGasicLanguage::debug_step_over();
}

void VisualGasicImmediate::debug_step_out() {
    VisualGasicLanguage::debug_step_out();
}

int VisualGasicImmediate::get_step_mode() {
    return static_cast<int>(VisualGasicLanguage::get_step_mode());
}

int VisualGasicImmediate::get_current_debug_line() {
    return VisualGasicLanguage::get_current_debug_line();
}

String VisualGasicImmediate::get_current_debug_file() {
    return VisualGasicLanguage::get_current_debug_file();
}

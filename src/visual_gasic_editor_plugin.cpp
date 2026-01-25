#include "visual_gasic_editor_plugin.h"
#include <godot_cpp/classes/reg_ex_match.hpp>
#include <godot_cpp/classes/reg_ex.hpp>
#include "visual_gasic_tokenizer.h"
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/reg_ex.hpp>

void VisualGasicSyntaxHighlighter::_bind_methods() {
}

Dictionary VisualGasicSyntaxHighlighter::_get_line_syntax_highlighting(int32_t p_line) const {
    Dictionary color_map;
    
    TextEdit* te = get_text_edit();
    if (!te) return color_map;

    String line = te->get_line(p_line);
    
    VisualGasicTokenizer tokenizer;
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(line);
    
    // Color definitions
    Color keyword_color = Color(1.0, 0.44, 0.52); // Pinkish red
    Color string_color = Color(1.0, 0.93, 0.5); // Yellowish
    Color comment_color = Color(0.4, 0.8, 0.4); // Greenish
    Color number_color = Color(0.6, 0.8, 1.0); // Cyanish
    Color symbol_color = Color(0.8, 0.8, 1.0); // White-ish blue
    Color type_color = Color(0.5, 1.0, 0.8); // Teal
    
    for(int i=0; i<tokens.size(); i++) {
        VisualGasicTokenizer::Token t = tokens[i];
        if (t.type == VisualGasicTokenizer::TOKEN_EOF || t.type == VisualGasicTokenizer::TOKEN_NEWLINE) continue;
        
        Color c = Color(1,1,1);
        bool set = false;
        
        switch(t.type) {
            case VisualGasicTokenizer::TOKEN_KEYWORD: c = keyword_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_LITERAL_STRING: c = string_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_COMMENT: c = comment_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_LITERAL_INTEGER:
            case VisualGasicTokenizer::TOKEN_LITERAL_FLOAT: c = number_color; set=true; break;
            case VisualGasicTokenizer::TOKEN_IDENTIFIER: 
                 c = symbol_color; set=true; 
                 break; 
            default: break;
        }
        
        if (set && t.column > 0) {
            color_map[t.column - 1] = c;
        }
    }
    
    return color_map;
}

void VisualGasicEditorPlugin::_bind_methods() {
}

VisualGasicEditorPlugin::VisualGasicEditorPlugin() {
    toolbox = nullptr;
    current_editor = nullptr;
}

VisualGasicEditorPlugin::~VisualGasicEditorPlugin() {}

bool VisualGasicEditorPlugin::_handles(Object *p_object) const {
    // Handle VisualGasic script files (.bas extension)
    if (Script* script = Object::cast_to<Script>(p_object)) {
        String path = script->get_path();
        return path.ends_with(".bas");
    }
    return false;
}

void VisualGasicEditorPlugin::_edit(Object *p_object) {
    // When editing a VisualGasic script, connect to text editor if available
    // This would need more complex integration with Godot's script editor
    // For now, we'll implement the basic structure
}

void VisualGasicEditorPlugin::on_text_changed(int line) {
    if (!current_editor) return;
    transform_shortcuts(current_editor, line);
}

void VisualGasicEditorPlugin::transform_shortcuts(TextEdit* editor, int line) {
    if (!editor) return;
    
    String line_text = editor->get_line(line);
    
    // Type inference for Dim declarations with assignment
    if (line_text.strip_edges().begins_with("Dim ") && line_text.contains(" = ") && !line_text.contains(" As ")) {
        add_type_inference(editor, line);
        return; // Don't process other transformations if we did type inference
    }
    
    // Handle incomplete Dim declarations (no As Type, no assignment)
    if (line_text.strip_edges().begins_with("Dim ") && !line_text.contains(" As ") && !line_text.contains(" = ")) {
        handle_incomplete_dim(editor, line);
        return;
    }
    
    // Function declaration auto-completion
    if (line_text.strip_edges().begins_with("func ") && !line_text.contains("(") && !is_in_string_context(line_text, 0)) {
        handle_incomplete_function(editor, line, "func ", "Function");
        return;
    }
    if (line_text.strip_edges().begins_with("def ") && !line_text.contains("(") && !is_in_string_context(line_text, 0)) {
        handle_incomplete_function(editor, line, "def ", "Function");
        return;
    }
    if (line_text.strip_edges().begins_with("void ") && !line_text.contains("(") && !is_in_string_context(line_text, 0)) {
        handle_incomplete_function(editor, line, "void ", "Sub");
        return;
    }
    
    // String interpolation conversion
    if (line_text.contains("`") && line_text.contains("${") && !is_in_string_context(line_text, line_text.find("`"))) {
        convert_template_literal(editor, line);
        return;
    }
    if (line_text.contains("f\"") && line_text.contains("{") && !is_in_string_context(line_text, line_text.find("f\""))) {
        convert_f_string(editor, line);
        return;
    }
    if (line_text.contains("$\"") && line_text.contains("{") && !is_in_string_context(line_text, line_text.find("$\""))) {
        convert_interpolated_string(editor, line);
        return;
    }
    
    // Ternary operator conversion
    if (line_text.contains("?") && line_text.contains(":") && !is_in_string_context(line_text, line_text.find("?"))) {
        convert_ternary_operator(editor, line);
        return;
    }
    
    // Loop pattern shortcuts
    if (line_text.contains("for(") && line_text.contains(";") && !is_in_string_context(line_text, line_text.find("for("))) {
        convert_c_style_for_loop(editor, line);
        return;
    }
    if (line_text.contains("for ") && line_text.contains(" in range(") && !is_in_string_context(line_text, line_text.find("for "))) {
        convert_python_range_loop(editor, line);
        return;
    }
    if (line_text.contains("while(") && !is_in_string_context(line_text, line_text.find("while("))) {
        convert_c_style_while(editor, line);
        return;
    }
    
    // Array access normalization
    if (line_text.contains("[") && line_text.contains("]") && !is_in_string_context(line_text, line_text.find("]["))) {
        convert_array_brackets(editor, line);
    }
    
    // Incomplete control structure completion
    if ((line_text.strip_edges().begins_with("if ") && !line_text.contains(" Then")) || 
        (line_text.strip_edges().begins_with("for ") && !line_text.contains("=") && !line_text.contains("in")) ||
        (line_text.strip_edges() == "while" || line_text.strip_edges().begins_with("while ") && line_text.strip_edges().length() < 10)) {
        complete_control_structure(editor, line);
        return;
    }
    
    // Property/Method chaining assistance
    if (line_text.strip_edges().begins_with(".") || line_text.contains("..")) {
        fix_method_chaining(editor, line);
    }
    
    // Import/Using statement conversion (SAFE - only foreign patterns)
    if (line_text.strip_edges().begins_with("from ") ||
        line_text.strip_edges().begins_with("#include") ||
        (line_text.strip_edges().begins_with("using ") && 
         (line_text.contains("System.") || line_text.contains("Microsoft."))) ||
        (line_text.strip_edges().begins_with("import ") && 
         is_known_foreign_library(line_text))) {
        convert_import_statements(editor, line);
        return;
    }
    
    // Check for :_ pattern (Case Else shortcut)
    if (line_text.strip_edges().ends_with(":_") && is_in_case_context(editor, line)) {
        if (!is_in_string_context(line_text, line_text.length() - 2)) {
            replace_pattern(editor, line, ":_", "Case Else");
        }
    }
    
    // Variable declaration shortcuts
    if (line_text.strip_edges().begins_with("let ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "let ", "Dim ");
    }
    if (line_text.strip_edges().begins_with("var ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "var ", "Dim ");
    }
    
    // Function declaration shortcuts
    if (line_text.strip_edges().begins_with("func ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "func ", "Function ");
    }
    if (line_text.strip_edges().begins_with("def ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "def ", "Function ");
    }
    if (line_text.strip_edges().begins_with("void ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "void ", "Sub ");
    }
    
    // Control flow shortcuts
    if (line_text.strip_edges().begins_with("elif ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "elif ", "ElseIf ");
    }
    if (line_text.contains("else if ") && !is_in_string_context(line_text, line_text.find("else if "))) {
        replace_pattern(editor, line, "else if ", "ElseIf ");
    }
    if (line_text.strip_edges().begins_with("switch ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "switch ", "Select Case ");
    }
    if (line_text.strip_edges().begins_with("foreach ") && !is_in_string_context(line_text, 0)) {
        replace_pattern(editor, line, "foreach ", "For Each ");
    }
    
    // Null/None shortcuts
    if (line_text.contains("null") && !is_in_string_context(line_text, line_text.find("null"))) {
        replace_pattern(editor, line, "null", "Nothing");
    }
    if (line_text.contains("None") && !is_in_string_context(line_text, line_text.find("None"))) {
        replace_pattern(editor, line, "None", "Nothing");
    }
    if (line_text.contains("undefined") && !is_in_string_context(line_text, line_text.find("undefined"))) {
        replace_pattern(editor, line, "undefined", "Nothing");
    }
    
    // Boolean shortcuts
    if (line_text.contains("true") && !is_in_string_context(line_text, line_text.find("true"))) {
        replace_pattern(editor, line, "true", "True");
    }
    if (line_text.contains("false") && !is_in_string_context(line_text, line_text.find("false"))) {
        replace_pattern(editor, line, "false", "False");
    }
    
    // Comment shortcuts
    if (line_text.strip_edges().begins_with("// ")) {
        replace_pattern(editor, line, "// ", "' ");
    }
    if (line_text.strip_edges().begins_with("# ")) {
        replace_pattern(editor, line, "# ", "' ");
    }
    
    // Assignment and comparison operators
    if (line_text.contains("->") && !is_in_string_context(line_text, line_text.find("->", 0))) {
        replace_pattern(editor, line, "->", " = ");
    }
    if (line_text.contains("===") && !is_in_string_context(line_text, line_text.find("===", 0))) {
        replace_pattern(editor, line, "===", " = ");
    }
    if (line_text.contains("==") && !is_in_string_context(line_text, line_text.find("==", 0))) {
        replace_pattern(editor, line, "==", " = ");
    }
    if (line_text.contains("!==") && !is_in_string_context(line_text, line_text.find("!==", 0))) {
        replace_pattern(editor, line, "!==", " <> ");
    }
    
    // Logical operators
    if (line_text.contains("&&") && !is_in_string_context(line_text, line_text.find("&&", 0))) {
        replace_pattern(editor, line, "&&", " And ");
    }
    if (line_text.contains("||") && !is_in_string_context(line_text, line_text.find("||", 0))) {
        replace_pattern(editor, line, "||", " Or ");
    }
    if (line_text.contains("!") && !line_text.contains("!=") && !line_text.contains("!==") && !is_in_string_context(line_text, line_text.find("!", 0))) {
        replace_pattern(editor, line, "!", " Not ");
    }
}

bool VisualGasicEditorPlugin::is_in_string_context(const String& line, int position) {
    bool in_string = false;
    for (int i = 0; i < position && i < line.length(); i++) {
        if (line[i] == '"' && (i == 0 || line[i-1] != '\\')) {
            in_string = !in_string;
        }
    }
    return in_string;
}

bool VisualGasicEditorPlugin::is_in_case_context(TextEdit* editor, int line) {
    // Look backwards to find Select Case or Match statement
    for (int i = line - 1; i >= 0; i--) {
        String check_line = editor->get_line(i).strip_edges().to_lower();
        if (check_line.begins_with("select case") || check_line.begins_with("match ")) {
            return true;
        }
        if (check_line.begins_with("end select") || check_line.begins_with("end match")) {
            return false;
        }
        // If we hit another control structure, we're not in case context
        if (check_line.begins_with("if ") || check_line.begins_with("for ") || 
            check_line.begins_with("while ") || check_line.begins_with("do ")) {
            return false;
        }
    }
    return false;
}

void VisualGasicEditorPlugin::replace_pattern(TextEdit* editor, int line, const String& pattern, const String& replacement) {
    String line_text = editor->get_line(line);
    int pos = line_text.find(pattern);
    if (pos != -1) {
        String new_text = line_text.substr(0, pos) + replacement + line_text.substr(pos + pattern.length());
        editor->set_line(line, new_text);
        
        // Position cursor after replacement
        editor->set_caret_line(line);
        editor->set_caret_column(pos + replacement.length());
    }
}

void VisualGasicEditorPlugin::add_type_inference(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    
    // Parse: Dim variableName = value
    RegEx regex;
    regex.compile("^(\\s*Dim\\s+)([a-zA-Z_][a-zA-Z0-9_]*)\\s*=\\s*(.+)$");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid() && result->get_group_count() >= 3) {
        String prefix = result->get_string(1);  // "Dim "
        String var_name = result->get_string(2); // variable name
        String value = result->get_string(3).strip_edges(); // assigned value
        
        // Remove any trailing comment
        int comment_pos = value.find("'");
        String comment = "";
        if (comment_pos != -1) {
            comment = value.substr(comment_pos);
            value = value.substr(0, comment_pos).strip_edges();
        }
        
        String inferred_type = infer_type_from_value(value);
        String new_line = prefix + var_name + " As " + inferred_type + " = " + value;
        if (comment != "") {
            new_line += " " + comment;
        }
        editor->set_line(line, new_line);
    }
}

String VisualGasicEditorPlugin::infer_type_from_value(const String& value) {
    String val = value.strip_edges();
    
    // String literals
    if ((val.begins_with("\"") && val.ends_with("\""))) {
        return "String";
    }
    
    // Boolean literals
    if (val.to_lower() == "true" || val.to_lower() == "false") {
        return "Boolean";
    }
    
    // Vector constructors
    if (val.begins_with("Vector2(")) return "Vector2";
    if (val.begins_with("Vector3(")) return "Vector3";
    if (val.begins_with("Vector4(")) return "Vector4";
    if (val.begins_with("Color(")) return "Color";
    
    // Array constructor
    if (val.to_lower().begins_with("array(") || val.begins_with("[")) {
        return "Array";
    }
    
    // Floating point numbers
    if (val.is_valid_float() && val.contains(".")) {
        return "Double";
    }
    
    // Integer numbers
    if (val.is_valid_int()) {
        return "Integer";
    }
    
    // Object constructors or function calls
    if (val.contains("(") && (val.begins_with("Create") || val.contains("New ") || val.find("(") > 0)) {
        return "Object";
    }
    
    // If we can't infer a specific type, use Variant as fallback
    return "Variant";
}

void VisualGasicEditorPlugin::handle_incomplete_dim(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    
    // Parse: Dim variableName (possibly with comment)
    RegEx regex;
    regex.compile("^(\\s*Dim\\s+)([a-zA-Z_][a-zA-Z0-9_]*)(\\s*'.*)?$");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid() && result->get_group_count() >= 2) {
        String prefix = result->get_string(1);  // "Dim "
        String var_name = result->get_string(2); // variable name
        String comment = "";
        if (result->get_group_count() >= 3 && result->get_string(3) != "") {
            comment = result->get_string(3); // comment if exists
        }
        
        String new_line = prefix + var_name + " As Variant" + comment;
        editor->set_line(line, new_line);
    }
}

void VisualGasicEditorPlugin::handle_incomplete_function(TextEdit* editor, int line, const String& pattern, const String& replacement) {
    String line_text = editor->get_line(line);
    String func_name = line_text.strip_edges().substr(pattern.length()).strip_edges();
    
    if (replacement == "Sub") {
        String new_line = replacement + String(" ") + func_name + String("()");
        editor->set_line(line, new_line);
    } else {
        String new_line = replacement + String(" ") + func_name + String("() As Variant");
        editor->set_line(line, new_line);
    }
}

void VisualGasicEditorPlugin::convert_template_literal(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert `Hello ${name}` to "Hello " + name
    RegEx regex;
    regex.compile("`([^`]*?)\\$\\{([^}]+)\\}([^`]*?)`");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String before = result->get_string(1);
        String variable = result->get_string(2);
        String after = result->get_string(3);
        
        String replacement = "\"" + before + "\" + " + variable;
        if (after.length() > 0) {
            replacement += " + \"" + after + "\"";
        }
        
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_f_string(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert f"Score: {score}" to "Score: " + CStr(score)
    RegEx regex;
    regex.compile("f\"([^\"]*?)\\{([^}]+)\\}([^\"]*?)\"");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String before = result->get_string(1);
        String variable = result->get_string(2);
        String after = result->get_string(3);
        
        String replacement = "\"" + before + "\" + CStr(" + variable + ")";
        if (after.length() > 0) {
            replacement += " + \"" + after + "\"";
        }
        
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_interpolated_string(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert $"Player {id}" to "Player " + CStr(id)
    RegEx regex;
    regex.compile("\\$\"([^\"]*?)\\{([^}]+)\\}([^\"]*?)\"");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String before = result->get_string(1);
        String variable = result->get_string(2);
        String after = result->get_string(3);
        
        String replacement = "\"" + before + "\" + CStr(" + variable + ")";
        if (after.length() > 0) {
            replacement += " + \"" + after + "\"";
        }
        
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_ternary_operator(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert condition ? a : b to If(condition, a, b)
    RegEx regex;
    regex.compile("([^?]+)\\?([^:]+):([^;\\n]+)");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String condition = result->get_string(1).strip_edges();
        String true_value = result->get_string(2).strip_edges();
        String false_value = result->get_string(3).strip_edges();
        
        String replacement = "If(" + condition + ", " + true_value + ", " + false_value + ")";
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_c_style_for_loop(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert for(i=0; i<10; i++) to For i = 0 To 9
    RegEx regex;
    regex.compile("for\\(([^=]+)=([^;]+);[^<]*<([^;]+);[^\\)]*\\)");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String var_name = result->get_string(1).strip_edges();
        String start_val = result->get_string(2).strip_edges();
        String end_val = result->get_string(3).strip_edges();
        
        // Convert to VB-style (0-based to end-1)
        String replacement = "For " + var_name + " = " + start_val + " To " + end_val + " - 1";
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_python_range_loop(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert for i in range(10) to For i = 0 To 9
    RegEx regex;
    regex.compile("for ([^\\s]+) in range\\(([^\\)]+)\\)");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String var_name = result->get_string(1);
        String range_val = result->get_string(2);
        
        String replacement = "For " + var_name + " = 0 To " + range_val + " - 1";
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_c_style_while(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert while(condition) to While condition
    RegEx regex;
    regex.compile("while\\(([^\\)]+)\\)");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String condition = result->get_string(1);
        String replacement = "While " + condition;
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_array_brackets(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    // Convert arr[index] to arr(index) - but avoid string literals
    if (is_in_string_context(line_text, line_text.find("]"))) return;
    
    RegEx regex;
    regex.compile("([a-zA-Z_][a-zA-Z0-9_]*)\\[([^\\]]+)\\]");
    Ref<RegExMatch> result = regex.search(line_text);
    
    if (result.is_valid()) {
        String array_name = result->get_string(1);
        String index = result->get_string(2);
        String replacement = array_name + "(" + index + ")";
        String new_text = line_text.replace(result->get_string(0), replacement);
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::complete_control_structure(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    String stripped = line_text.strip_edges();
    
    if (stripped.begins_with("if ") && !stripped.contains(" Then")) {
        // Add Then to if statements
        String new_text = line_text.replace(stripped, stripped + " Then");
        editor->set_line(line, new_text);
    }
    else if (stripped.begins_with("for ") && !stripped.contains("=") && !stripped.contains("in")) {
        // Add default range to incomplete for loops
        String var_name = stripped.substr(4).strip_edges();
        if (var_name.length() == 0) var_name = "i";
        String replacement = "For " + var_name + " = 0 To 9";
        editor->set_line(line, line_text.replace(stripped, replacement));
    }
    else if (stripped == "while" || (stripped.begins_with("while ") && stripped.length() < 10)) {
        // Add default condition to incomplete while loops
        String replacement = "While True";
        editor->set_line(line, line_text.replace(stripped, replacement));
    }
}

void VisualGasicEditorPlugin::fix_method_chaining(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    
    if (line_text.strip_edges().begins_with(".")) {
        // Add default object reference for methods starting with dot
        String replacement = "obj" + line_text.strip_edges();
        editor->set_line(line, line_text.replace(line_text.strip_edges(), replacement));
    }
    else if (line_text.contains("..")) {
        // Fix double dots to single dots
        String new_text = line_text.replace("..", ".");
        editor->set_line(line, new_text);
    }
}

void VisualGasicEditorPlugin::convert_import_statements(TextEdit* editor, int line) {
    String line_text = editor->get_line(line);
    String stripped = line_text.strip_edges();
    String replacement = "";
    
    // Python imports
    if (stripped.begins_with("import ")) {
        String module = stripped.substr(7).strip_edges();
        String equivalent = get_visualgasic_equivalent(module);
        if (equivalent != "") {
            replacement = "' Import: " + module + " → " + equivalent;
        } else {
            replacement = "' Import: " + module + " (check VisualGasic equivalent)";
        }
    }
    // Python from imports
    else if (stripped.begins_with("from ")) {
        RegEx regex;
        regex.compile("from ([^\\s]+) import ([^\\n]+)");
        Ref<RegExMatch> result = regex.search(stripped);
        if (result.is_valid()) {
            String module = result->get_string(1);
            String items = result->get_string(2);
            String equivalent = get_visualgasic_equivalent(module);
            if (equivalent != "") {
                replacement = "' From " + module + " import " + items + " → " + equivalent;
            } else {
                replacement = "' From " + module + " import " + items + " (check VisualGasic equivalent)";
            }
        }
    }
    // C# using statements
    else if (stripped.begins_with("using ")) {
        String namespace_name = stripped.substr(6).replace(";", "").strip_edges();
        String equivalent = get_visualgasic_equivalent(namespace_name);
        if (equivalent != "") {
            replacement = "' Using: " + namespace_name + " → " + equivalent;
        } else {
            replacement = "' Using: " + namespace_name + " (check VisualGasic equivalent)";
        }
    }
    // C++ includes
    else if (stripped.begins_with("#include")) {
        RegEx regex;
        regex.compile("#include\\s*[<\"](.*?)[>\"]");
        Ref<RegExMatch> result = regex.search(stripped);
        if (result.is_valid()) {
            String header = result->get_string(1);
            String equivalent = get_visualgasic_equivalent(header);
            if (equivalent != "") {
                replacement = "' Include: " + header + " → " + equivalent;
            } else {
                replacement = "' Include: " + header + " (check VisualGasic equivalent)";
            }
        }
    }
    
    if (replacement != "") {
        editor->set_line(line, replacement);
    }
}

String VisualGasicEditorPlugin::get_visualgasic_equivalent(const String& import_name) {
    // Smart mappings for common imports with VisualGasic equivalents
    
    // Math libraries
    if (import_name == "math" || import_name == "cmath") {
        return "Built-in functions: Sin, Cos, Tan, Sqrt, Abs, etc.";
    }
    if (import_name == "random") {
        return "Built-in: Randomize, Rnd(), RandomRange()";
    }
    
    // System/OS libraries  
    if (import_name == "System" || import_name == "os" || import_name == "sys") {
        return "Built-in system functions and Godot OS class";
    }
    if (import_name == "time" || import_name == "datetime") {
        return "Built-in: Sleep(), Timer, Time class";
    }
    
    // Data structures
    if (import_name == "json") {
        return "Godot's JSON class";
    }
    if (import_name == "collections") {
        return "Built-in: Array, Dictionary";
    }
    
    // C++ standard library
    if (import_name == "iostream") {
        return "Built-in: Print, Input functions";
    }
    if (import_name == "vector") {
        return "Built-in: Array type";
    }
    if (import_name == "string") {
        return "Built-in: String type";
    }
    if (import_name == "algorithm") {
        return "Built-in array methods: sort, reverse, etc.";
    }
    
    // .NET/C# common namespaces
    if (import_name == "System.Collections") {
        return "Built-in: Array, Dictionary";
    }
    if (import_name == "System.IO") {
        return "Built-in file I/O and Godot FileAccess";
    }
    if (import_name == "System.Text") {
        return "Built-in String manipulation functions";
    }
    
    // JavaScript/Node.js
    if (import_name == "fs") {
        return "Built-in file operations and Godot FileAccess";
    }
    if (import_name == "path") {
        return "Built-in path functions";
    }
    
    // Return empty string if no equivalent found (will use comment approach)
    return "";
}

bool VisualGasicEditorPlugin::is_known_foreign_library(const String& line_text) {
    String stripped = line_text.strip_edges();
    if (!stripped.begins_with("import ")) return false;
    
    String module = stripped.substr(7).strip_edges();
    
    // Known Python standard library modules
    if (module == "math" || module == "cmath" || module == "random" ||
        module == "os" || module == "sys" || module == "time" ||
        module == "datetime" || module == "json" || module == "csv" ||
        module == "urllib" || module == "sqlite3" || module == "collections" ||
        module == "itertools" || module == "functools" || module == "re") {
        return true;
    }
    
    // Known Python third-party libraries
    if (module == "numpy" || module == "scipy" || module == "pandas" ||
        module == "matplotlib" || module == "requests" || module == "flask" ||
        module == "django" || module == "tensorflow" || module == "torch" ||
        module == "sklearn" || module == "cv2" || module == "PIL") {
        return true;
    }
    
    // Known JavaScript/Node.js modules (if someone puts them in import statement)
    if (module == "fs" || module == "path" || module == "http" ||
        module == "crypto" || module == "express" || module == "react" ||
        module == "lodash" || module == "axios" || module == "moment") {
        return true;
    }
    
    // Check if it contains obvious foreign patterns
    if (module.contains(".") && (module.begins_with("java.") || 
        module.begins_with("android.") || module.begins_with("com."))) {
        return true; // Java packages
    }
    
    // If not in known foreign library list, assume it might be VisualGasic
    return false;
}

void VisualGasicEditorPlugin::_enter_tree() {
    UtilityFunctions::print("VisualGasicEditorPlugin: Entering tree");
    toolbox = memnew(VisualGasicToolbox);
    toolbox->set_name("Toolbox");
    // Switch to bottom panel to ensure visibility
    add_control_to_bottom_panel(toolbox, "Visual Gasic");
    UtilityFunctions::print("VisualGasicEditorPlugin: Toolbox added with auto-replacement features");
}

void VisualGasicEditorPlugin::_exit_tree() {
    if (toolbox) {
        remove_control_from_docks(toolbox);
        memdelete(toolbox);
        toolbox = nullptr;
    }
    current_editor = nullptr;
}

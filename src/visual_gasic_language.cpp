#include "visual_gasic_language.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

// Helper for Completion
static Dictionary create_completion_option(String display, int kind, String desc) {
    Dictionary d;
    d["display"] = display;
    d["kind"] = kind;
    d["insert_text"] = display;
    d["location"] = 0; // LOCATION_LOCAL
    return d;
}

VisualGasicLanguage *VisualGasicLanguage::singleton = nullptr;

VisualGasicLanguage *VisualGasicLanguage::get_singleton() {
    return singleton;
}

VisualGasicLanguage::VisualGasicLanguage() {
    singleton = this;
}

VisualGasicLanguage::~VisualGasicLanguage() {
    if (singleton == this) {
        singleton = nullptr;
    }
}

// _bind_methods definition moved below

String VisualGasicLanguage::_get_name() const {
    return "VisualGasic";
}

void VisualGasicLanguage::_init() {
    // Initialization logic
}

String VisualGasicLanguage::_get_type() const {
    return "VisualGasic";
}

String VisualGasicLanguage::_get_extension() const {
    return "bas";
}

void VisualGasicLanguage::_finish() {
    // Cleanup logic
}

PackedStringArray VisualGasicLanguage::_get_reserved_words() const {
    PackedStringArray words;
    words.push_back("Dim");
    words.push_back("Sub");
    words.push_back("End");
    words.push_back("Function");
    words.push_back("If");
    words.push_back("Then");
    words.push_back("Else");
    words.push_back("For");
    words.push_back("To");
    words.push_back("Next");
    words.push_back("Step");
    words.push_back("While");
    words.push_back("Wend");
    words.push_back("Do");
    words.push_back("Loop");
    words.push_back("Print");
    words.push_back("Call");
    words.push_back("And");
    words.push_back("Or");
    words.push_back("Not");
    words.push_back("Xor");
    words.push_back("On");
    words.push_back("Error");
    words.push_back("Resume");
    words.push_back("Goto");
    words.push_back("select");
    words.push_back("case");
    words.push_back("Open");
    words.push_back("Close");
    words.push_back("Input");
    words.push_back("Output");
    words.push_back("Append");
    words.push_back("Line");
    words.push_back("Exit");
    words.push_back("Public");
    words.push_back("Private");
    words.push_back("Redim");
    words.push_back("Preserve");
    words.push_back("Set");
    words.push_back("Nothing");
    words.push_back("True");
    words.push_back("False");
    words.push_back("Whenever");
    words.push_back("Section");
    words.push_back("Changes");
    words.push_back("Becomes");
    words.push_back("Exceeds");
    words.push_back("Below");
    words.push_back("Between");
    words.push_back("Contains");
    words.push_back("Local");
    words.push_back("Suspend");
    words.push_back("Resume");
    words.push_back("Async");
    words.push_back("Await");
    words.push_back("Task");
    words.push_back("Parallel");
    return words;
}

bool VisualGasicLanguage::_is_control_flow_keyword(const String &p_keyword) const {
    return p_keyword == "If" || p_keyword == "Else" || p_keyword == "For" || p_keyword == "While";
}

PackedStringArray VisualGasicLanguage::_get_comment_delimiters() const {
    PackedStringArray delimiters;
    delimiters.push_back("'");
    return delimiters;
}

PackedStringArray VisualGasicLanguage::_get_string_delimiters() const {
    PackedStringArray delimiters;
    delimiters.push_back("\" \"");
    return delimiters;
}


Ref<Script> VisualGasicLanguage::_make_template(const String &p_template, const String &p_class_name, const String &p_base_class_name) const {
    Ref<VisualGasicScript> script;
    script.instantiate();
    String code = "' VisualGasic Script\n";
    code += "' Class: " + p_class_name + "\n";
    code += "' Inherits: " + p_base_class_name + "\n\n";
    code += "Sub _Ready()\n    ' Initialize here\nEnd Sub\n";
    script->set_source_code(code);
    return script;
}


TypedArray<Dictionary> VisualGasicLanguage::_get_built_in_templates(const StringName &p_object) const {
    return TypedArray<Dictionary>();
}

bool VisualGasicLanguage::_is_using_templates() {
    return true;
}

Dictionary VisualGasicLanguage::_validate(const String &p_script, const String &p_path, bool p_validate_functions, bool p_validate_errors, bool p_validate_warnings, bool p_validate_safe_lines) const {
    Dictionary result;
    result["valid"] = true;
    result["errors"] = Array();
    result["warnings"] = Array();
    result["safe_lines"] = PackedInt32Array();
    result["functions"] = Array();
    
    if (p_validate_errors) {
        VisualGasicTokenizer tokenizer;
        Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(p_script);
        if (tokenizer.has_error) {
             Dictionary err;
             err["line"] = tokenizer.error_line;
             err["column"] = tokenizer.error_column; 
             err["message"] = tokenizer.error_message;
             err["code"] = 1; // ERR_PARSE_ERROR
             ((Array)result["errors"]).push_back(err);
             result["valid"] = false;
        } else {
             VisualGasicParser parser;
             ModuleNode* root = parser.parse(tokens);
             if (parser.errors.size() > 0) {
                 for(int i=0; i<parser.errors.size(); i++) {
                     VisualGasicParser::ParsingError pe = parser.errors[i];
                     Dictionary err;
                     err["line"] = pe.line;
                     err["column"] = pe.column;
                     err["message"] = pe.message;
                     err["code"] = 1; 
                     ((Array)result["errors"]).push_back(err);
                 }
                 result["valid"] = false;
             }
             if (root) delete root;
        }
    }
    return result;
}


String VisualGasicLanguage::_validate_path(const String &p_path) const {
    return "";
}

Object *VisualGasicLanguage::_create_script() const {
    return memnew(VisualGasicScript);
}

bool VisualGasicLanguage::_has_named_classes() const {
    return false;
}

bool VisualGasicLanguage::_supports_builtin_mode() const {
    return true;
}

bool VisualGasicLanguage::_can_inherit_from_file() const {
    return true;
}

int32_t VisualGasicLanguage::_find_function(const String &p_class_name, const String &p_function_name) const {
    return -1;
}

String VisualGasicLanguage::_make_function(const String &p_class_name, const String &p_function_name, const PackedStringArray &p_function_args) const {
    String s = "Sub " + p_function_name + "(";
    for (int i = 0; i < p_function_args.size(); i++) {
        if (i > 0) s += ", ";
        s += p_function_args[i];
    }
    s += ")\n    \nEnd Sub";
    return s;
}

Error VisualGasicLanguage::_open_in_external_editor(const Ref<Script> &p_script, int32_t p_line, int32_t p_col) {
    return ERR_UNAVAILABLE;
}

bool VisualGasicLanguage::_overrides_external_editor() {
    return false;
}

Dictionary VisualGasicLanguage::_complete_code(const String &p_code, const String &p_path, Object *p_owner) const {
    Dictionary result;
    result["result"] = OK;
    
    // We should parse current token or use Godot's cursor info?
    // Godot doesn't pass cursor pos in this call signature (in 3.x/4.0), 
    // Wait, 4.x GDExtension signature of _complete_code is (code, path, owner).
    // It assumes we complete at the end of code? 
    // Or it expects us to parse invalid code. The p_code usually contains incomplete code marker?
    // Actually, usually Editors pass the whole code, but we don't have cursor column/row.
    // However, ScriptLanguage::complete_code has (code, path, owner, custom_options, force, call_hint).
    // GDExtension might differ. 
    // Let's assume p_code is the Full Source and we have to guess context?
    // Actually, Godot's TextEdit usually sends the code *up to* the cursor if called improperly,
    // BUT the standard API takes the full source code.
    // The C++ API for complete_code in Godot 4 seems to omit cursor pos in this virtual function in extension_api sometimes?
    // Let's check header again in `godot-cpp`.
    // ScriptLanguageExtension::_complete_code(p_code, p_path, p_owner).
    
    // Without cursor position, we can only return ALL possibilities or guess based on end of string?
    // Usually Godot calls this when Ctrl+Space is pressed.
    // If we assume p_code is truncated to cursor (some editors do this), we check the last word.
    // But usually it's full code. This API seems impossible to use without cursor pos unless Godot sets it on the instance?
    // Actually, look at GDScript: it uses `code_completion` on parser.
    // In GDExtension, `_code_complete` might not be enough.
    // There is no `_lookup_code` or `_complete_code` with cursor in `ScriptLanguageExtension`?
    // Wait, let's look at `_complete_code` signature carefully in my file. 
    // Dictionary VisualGasicLanguage::_complete_code(const String &p_code, const String &p_path, Object *p_owner) const
    
    // If I can't know where the cursor is, I can't provide context-sensitive completion.
    // However, maybe p_code *IS* the code up to the cursor?
    // Let's assume p_code is what we analyze.
    // Let's scan the last token in p_code.
    
    // 1. Get List of Keywords
    PackedStringArray keywords = _get_reserved_words();
    
    // 2. Add Built-in Functions
    keywords.push_back("CreateActor2D");
    keywords.push_back("AI_Chase");
    keywords.push_back("LoadForm");

    Array options;
    String clean_code = p_code.strip_edges(false, true); 
    if (clean_code.ends_with(".")) {
         options.push_back(create_completion_option("text", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Text Property"));
         options.push_back(create_completion_option("visible", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Visible Property"));
         options.push_back(create_completion_option("show", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Show()"));
         result["options"] = options;
         result["forced"] = false;
         result["result"] = OK;
         return result;
    }

    keywords.push_back("AI_Wander");
    keywords.push_back("AI_Patrol");
    keywords.push_back("AI_Stop");
    keywords.push_back("HasCollided");
    keywords.push_back("GetCollider");
    keywords.push_back("IsKeyPressed");
    keywords.push_back("IsActionPressed");
    keywords.push_back("DrawText");
    keywords.push_back("DrawLine");
    keywords.push_back("DrawRect");
    keywords.push_back("DrawCircle");
    keywords.push_back("PlaySound");
    keywords.push_back("PlayTone");
    keywords.push_back("SetTitle");
    keywords.push_back("SetScreenSize");
    keywords.push_back("ChangeScene");
    keywords.push_back("Shell");
    keywords.push_back("Sleep");
    keywords.push_back("Randomize");
    keywords.push_back("MkDir");
    keywords.push_back("MsgBox");
    keywords.push_back("SaveSetting");
    keywords.push_back("GetSetting");
    keywords.push_back("OpenDatabase");
    keywords.push_back("SaveDatabase");
    keywords.push_back("LoadPicture");
    keywords.push_back("Format");
    keywords.push_back("Int");
    keywords.push_back("Abs");
    keywords.push_back("Rnd");
    keywords.push_back("RandRange");
    keywords.push_back("Round");
    keywords.push_back("Lerp");
    keywords.push_back("Clamp");
    keywords.push_back("TypeName");
    keywords.push_back("Set");
    
    // 3. Build Options
    // Array options; // Already declared above
    options.clear();
    
    // If we want to filter by prefix, we need the last word.
    // Simple scanner for last word:
    int len = p_code.length();
    String prefix = "";
    for(int i=len-1; i>=0; i--) {
        char32_t c = p_code[i];
        if ( (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' ) {
            prefix = String::chr(c) + prefix;
        } else {
            break;
        }
    }
    
    // If prefix is empty, return all? Or none? Usually none if invoked without trigger.
    // But if invoked explicitly (Ctrl+Space), return all.
    
    for(int i=0; i<keywords.size(); i++) {
        String k = keywords[i];
        if (prefix.is_empty() || k.begins_with(prefix) || k.to_lower().begins_with(prefix.to_lower())) {
             Dictionary opt;
             opt["kind"] = 1; // Script.KIND_KEYWORD (Constants not available easily, assume 0 or 1)
             // KIND values: CLASS=0, FUNCTION=1, VAIABLE=2, CONSTANT=3 ...
             // Let's use FUNCTION(1) for all for now, or PLAIN_TEXT.
             opt["display"] = k;
             opt["insert_text"] = k;
             opt["completion_text"] = k;
             opt["location"] = 0; // LOCAL?
             options.push_back(opt);
        }
    }
    
    result["options"] = options;
    return result;
}

Dictionary VisualGasicLanguage::_lookup_code(const String &p_code, const String &p_symbol, const String &p_path, Object *p_owner) const {
    Dictionary result;
    
    // Ctrl+Click sends the symbol (word) under cursor.
    // We should look for "Sub <p_symbol>" or "Function <p_symbol>" or "<p_symbol>:" (Label) in p_code.
    
    String symbol_lower = p_symbol.to_lower();
    PackedStringArray lines = p_code.split("\n");
    
    for (int i = 0; i < lines.size(); i++) {
        String line = lines[i].strip_edges().to_lower();
        
        // Check for Sub/Function Definition
        if (line.begins_with("sub " + symbol_lower) || 
            (line.begins_with("function " + symbol_lower) && (line.length() == 9 + symbol_lower.length() || line[9+symbol_lower.length()] == '(')) ||
            (line.begins_with("sub ") && line.contains(" " + symbol_lower + "(")) ) { // Handle "Sub Foo("
            
            // Check exact match for Subs
            int name_start = -1;
            if (line.begins_with("sub ")) name_start = 4;
            if (line.begins_with("function ")) name_start = 9;
            
            if (name_start != -1) {
                // Verify it's actually the symbol
                // Simple check: does line contain the symbol properly?
                // The p_symbol is usually exact.
                
                result["type"] = 1; // SCRIPT_LOCATION_LOCAL (0=OTHER, 1=LOCAL, 2=MEMBER)
                result["line"] = i;
                result["column"] = 0;
                return result;
            }
        }
        
        // Check for Label Definition "Label:"
        if (line.begins_with(symbol_lower + ":")) {
             result["type"] = 1;
             result["line"] = i;
             result["column"] = 0;
             return result;
        }
    }

    return Dictionary();
}


void VisualGasicLanguage::_bind_methods() {
    ClassDB::bind_method(D_METHOD("format_source_code", "code"), &VisualGasicLanguage::format_source_code);
}

String VisualGasicLanguage::format_source_code(const String &p_code) const {
    String indented_code;
    PackedStringArray lines = p_code.split("\n");
    int current_indent = 0;
    
    for (int i = 0; i < lines.size(); i++) {
        String line = lines[i].strip_edges();
        String line_lower = line.to_lower();
        
        // Indent Check for NEXT line
        bool is_single_line_if = false;
        if (line_lower.begins_with("if") && line_lower.contains(" then ")) {
            int then_pos = line_lower.find(" then ");
            String after_then = line_lower.substr(then_pos + 6).strip_edges();
            if (!after_then.is_empty() && !after_then.begins_with("'")) {
                 is_single_line_if = true;
            }
        }
        
        if (!is_single_line_if) {
            if (line_lower.begins_with("sub ") ||
                line_lower.begins_with("function ") ||
                line_lower.begins_with("for ") ||
                line_lower.begins_with("while ") ||
                line_lower.begins_with("do") || 
                line_lower.begins_with("select case ") ||
                line_lower.begins_with("with ") ||
                (line_lower.begins_with("if ") && line_lower.ends_with(" then")) ||
                line_lower.begins_with("else") ||
                line_lower.begins_with("elseif") ||
                line_lower.begins_with("case ")) {
                
                if (line_lower.begins_with("do")) {
                    current_indent++;
                }
                else if (line_lower.begins_with("loop")) {
                    // no-op
                } 
                else {
                    current_indent++;
                }
            }
        }
    }
    return indented_code.strip_edges(false, true);
}

String VisualGasicLanguage::_auto_indent_code(const String &p_code, int32_t p_from_line, int32_t p_to_line) const {
    return format_source_code(p_code); 
}

void VisualGasicLanguage::_add_global_constant(const StringName &p_name, const Variant &p_value) {
}

void VisualGasicLanguage::_add_named_global_constant(const StringName &p_name, const Variant &p_value) {
}

void VisualGasicLanguage::_remove_named_global_constant(const StringName &p_name) {
}

void VisualGasicLanguage::_thread_enter() {
}

void VisualGasicLanguage::_thread_exit() {
}

String VisualGasicLanguage::_debug_get_error() const {
    return "";
}

int32_t VisualGasicLanguage::_debug_get_stack_level_count() const {
    return 0;
}

int32_t VisualGasicLanguage::_debug_get_stack_level_line(int32_t p_level) const {
    return -1;
}

String VisualGasicLanguage::_debug_get_stack_level_function(int32_t p_level) const {
    return "";
}

Dictionary VisualGasicLanguage::_debug_get_stack_level_locals(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) {
    return Dictionary();
}

Dictionary VisualGasicLanguage::_debug_get_stack_level_members(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) {
    return Dictionary();
}

void *VisualGasicLanguage::_debug_get_stack_level_instance(int32_t p_level) {
    return nullptr;
}

TypedArray<Dictionary> VisualGasicLanguage::_debug_get_current_stack_info() {
    return TypedArray<Dictionary>();
}

void VisualGasicLanguage::_frame() {
    // Called every frame
}

Dictionary VisualGasicLanguage::_debug_get_globals(int32_t p_max_subitems, int32_t p_max_depth) {
    return Dictionary();
}

String VisualGasicLanguage::_debug_parse_stack_level_expression(int32_t p_level, const String &p_expression, int32_t p_max_subitems, int32_t p_max_depth) {
    return "";
}

void VisualGasicLanguage::_reload_all_scripts() {
}

void VisualGasicLanguage::_reload_tool_script(const Ref<Script> &p_script, bool p_soft_reload) {
}

String VisualGasicLanguage::_debug_get_stack_level_source(int32_t p_level) const {
    return "";
}

PackedStringArray VisualGasicLanguage::_get_doc_comment_delimiters() const {
    PackedStringArray delimiters;
    delimiters.push_back("''"); // Tooltip delimiter
    return delimiters;
}

PackedStringArray VisualGasicLanguage::_get_recognized_extensions() const {
    PackedStringArray exts;
    exts.push_back("bas");
    return exts;
}

TypedArray<Dictionary> VisualGasicLanguage::_get_public_functions() const {
    return TypedArray<Dictionary>();
}

Dictionary VisualGasicLanguage::_get_public_constants() const {
    return Dictionary();
}

TypedArray<Dictionary> VisualGasicLanguage::_get_public_annotations() const {
    return TypedArray<Dictionary>();
}

void VisualGasicLanguage::_profiling_start() {
}

void VisualGasicLanguage::_profiling_stop() {
}


Dictionary VisualGasicLanguage::_get_global_class_name(const String &p_path) const {
    return Dictionary();
}

bool VisualGasicLanguage::_handles_global_class_type(const String &p_type) const {
    return p_type == "VisualGasic";
}

bool VisualGasicLanguage::_supports_documentation() const {
    return false;
}

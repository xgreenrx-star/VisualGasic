#include "visual_gasic_language.h"
#include "visual_gasic_bracket_completion.h"
#include "visual_gasic_snippets.h"
#include "visual_gasic_cbm_completion.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_debugger.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/callable_method_pointer.hpp>
#include <map>

using namespace godot;

// Static members for debug call stack (pointer initialized at runtime to avoid static init issues)
std::vector<VGDebugStackFrame>* VisualGasicLanguage::debug_call_stack = nullptr;
std::string VisualGasicLanguage::debug_error;

// Step debugging state
VGStepMode VisualGasicLanguage::step_mode = VG_STEP_NONE;
int VisualGasicLanguage::step_target_depth = 0;
bool VisualGasicLanguage::waiting_for_continue = false;

// Current breakpoint location (set before script_debug blocks)
std::string VisualGasicLanguage::current_break_file;
int VisualGasicLanguage::current_break_line = 0;

// Breakpoints storage (loaded from JSON, checked in C++ to avoid GDScript calls during debug)
std::map<std::string, std::vector<int>> VisualGasicLanguage::breakpoints;
bool VisualGasicLanguage::breakpoints_loaded = false;

// Lazy initialization of debug stack
std::vector<VGDebugStackFrame>& VisualGasicLanguage::get_debug_stack() {
    if (!debug_call_stack) {
        debug_call_stack = new std::vector<VGDebugStackFrame>();
    }
    return *debug_call_stack;
}

// Helper to check if a character is valid in an identifier
static bool is_identifier_char(char32_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
}

// Helper for Completion
static Dictionary create_completion_option(String display, int kind, String desc) {
    Dictionary d;
    d["display"] = display;
    d["kind"] = kind;
    d["insert_text"] = display;
    d["location"] = 0; // LOCATION_LOCAL
    d["font_color"] = Color(1, 1, 1, 1); // White color for completion text
    d["icon"] = Variant(); // Required by Godot 4.5.1 ScriptLanguageExtension
    d["default_value"] = Variant(); // Required by Godot 4.5.1
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

// Forward a message to the GDScript VGDebugHandler autoload
static bool forward_to_gdscript_handler(const String& p_message, const Array& p_data) {
    // Handle get_instances directly using C++ registry
    if (p_message == "get_instances") {
        // Get instances from C++ registry and send directly
        Array instances = VisualGasicDebug::get_all_instances();
        
        // Transform to format expected by editor
        Array result;
        for (int i = 0; i < instances.size(); i++) {
            Dictionary info = instances[i];
            Dictionary formatted;
            formatted["id"] = i;  // Use index as ID
            formatted["script_path"] = info.get("script_path", "");
            formatted["node_name"] = info.get("node_name", "Instance");
            formatted["node_path"] = info.get("node_path", "");
            result.push_back(formatted);
        }
        
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            Array msg_data;
            msg_data.push_back(result);
            debugger->send_message("visualgasic:instances", msg_data);
        }
        return true;
    }
    
    // Handle get_all_variables directly using C++ registry
    if (p_message == "get_all_variables" && p_data.size() >= 1) {
        int instance_id = p_data[0];
        Dictionary vars = VisualGasicDebug::get_instance_variables(instance_id);
        
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            Array msg_data;
            msg_data.push_back(vars);
            debugger->send_message("visualgasic:variables_list", msg_data);
        }
        return true;
    }
    
    // Handle get_whenever_sections directly using C++ registry
    if (p_message == "get_whenever_sections" && p_data.size() >= 1) {
        int instance_id = p_data[0];
        Array sections = VisualGasicDebug::get_whenever_sections(instance_id);
        
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            Array msg_data;
            msg_data.push_back(sections);
            debugger->send_message("visualgasic:whenever_sections", msg_data);
        }
        return true;
    }
    
    // Handle set_whenever_active directly using C++ registry
    if (p_message == "set_whenever_active" && p_data.size() >= 3) {
        int instance_id = p_data[0];
        String section_name = p_data[1];
        bool active = p_data[2];
        
        VisualGasicDebug::set_whenever_active(instance_id, section_name, active);
        
        // Send updated sections list
        Array sections = VisualGasicDebug::get_whenever_sections(instance_id);
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            Array msg_data;
            msg_data.push_back(sections);
            debugger->send_message("visualgasic:whenever_sections", msg_data);
        }
        return true;
    }
    
    // For other messages, forward to GDScript handler
    SceneTree* tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
    if (!tree) return false;
    
    Window* root = tree->get_root();
    if (!root) return false;
    
    Node* handler = root->get_node_or_null(NodePath("VGDebugHandler"));
    if (!handler) return false;
    
    // Call the appropriate method based on message
    if (p_message == "get_variable" && p_data.size() >= 2) {
        handler->call("_send_variable", p_data[0], p_data[1]);
        return true;
    }
    else if (p_message == "set_variable" && p_data.size() >= 3) {
        handler->call("_set_variable", p_data[0], p_data[1], p_data[2]);
        return true;
    }
    else if (p_message == "evaluate" && p_data.size() >= 3) {
        handler->call("_evaluate_code", p_data[0], p_data[1], p_data[2]);
        return true;
    }
    else if (p_message == "get_debug_state") {
        handler->call("_send_debug_state");
        return true;
    }
    else if (p_message == "set_breakpoints" && p_data.size() >= 1) {
        handler->call("_set_breakpoints", p_data[0]);
        return true;
    }
    
    return false;
}

// C++ message capture handler for debug commands
// This handles step/continue commands without going through GDScript
// to avoid triggering Godot's debugger to break in GDScript code
static bool vg_debug_message_handler(const String& p_message, const Array& p_data) {
    if (p_message == "debug_continue") {
        VisualGasicLanguage::debug_continue();
        return true;
    }
    else if (p_message == "debug_step_into") {
        VisualGasicLanguage::debug_step_into();
        return true;
    }
    else if (p_message == "debug_step_over") {
        VisualGasicLanguage::debug_step_over();
        return true;
    }
    else if (p_message == "debug_step_out") {
        VisualGasicLanguage::debug_step_out();
        return true;
    }
    else if (p_message == "set_breakpoints") {
        // Forward to GDScript handler to update its breakpoint storage
        forward_to_gdscript_handler(p_message, p_data);
        return true;
    }
    
    // Forward unhandled messages to GDScript handler
    return forward_to_gdscript_handler(p_message, p_data);
}

// Handler for Godot's built-in debug messages (step_into, continue, etc.)
// These are sent with the "debug" prefix by Godot's editor
static bool vg_godot_debug_handler(const String& p_message, const Array& p_data) {
    // Intercept step commands from Godot's debugger
    if (p_message == "step_into") {
        VisualGasicLanguage::debug_step_into();
        return true;  // We handled it
    }
    else if (p_message == "next") {  // Godot's step_over
        VisualGasicLanguage::debug_step_over();
        return true;
    }
    else if (p_message == "continue") {
        VisualGasicLanguage::debug_continue();
        return true;
    }
    
    return false;  // Let Godot handle other messages
}

// Flag to track if we've registered the message capture
static bool vg_message_capture_registered = false;

// Helper to ensure message capture is registered
static void ensure_message_capture_registered() {
    if (vg_message_capture_registered) return;
    
    EngineDebugger* debugger = EngineDebugger::get_singleton();
    if (debugger) {
        // Register our custom message handler for "visualgasic:" prefixed messages
        Callable handler = create_custom_callable_static_function_pointer(&vg_debug_message_handler);
        debugger->register_message_capture("visualgasic", handler);
        
        // Also register to intercept Godot's built-in debug messages
        // This allows us to handle step_into, continue, etc. directly
        Callable godot_handler = create_custom_callable_static_function_pointer(&vg_godot_debug_handler);
        debugger->register_message_capture("debug", godot_handler);
        
        vg_message_capture_registered = true;
        UtilityFunctions::print("[VisualGasic] C++ debug message capture registered (visualgasic + debug)");
    }
}

void VisualGasicLanguage::_init() {
    // Try to register message capture now, but it may fail if debugger isn't ready
    ensure_message_capture_registered();
}

String VisualGasicLanguage::_get_type() const {
    return "VisualGasic";
}

String VisualGasicLanguage::_get_extension() const {
    return "vg";
}

void VisualGasicLanguage::_finish() {
    // Unregister message captures
    if (vg_message_capture_registered) {
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            debugger->unregister_message_capture("visualgasic");
            debugger->unregister_message_capture("debug");
        }
        vg_message_capture_registered = false;
    }
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
    words.push_back("Of");
    words.push_back("Where");
    words.push_back("Match");
    words.push_back("When");
    words.push_back("Is");
    words.push_back("IsNot");
    words.push_back("TypeOf");
    words.push_back("HasValue");
    words.push_back("Value");
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
    Array options;
    
    // DEBUG: Print when completion is called
    print_line("[VG COMPLETION] _complete_code called, code length: " + itos(p_code.length()) + ", owner: " + (p_owner ? p_owner->get_class() : "null"));
    
    String clean_code = p_code.strip_edges(false, true);
    
    // DEBUG: Print last few chars
    if (clean_code.length() > 0) {
        int start = MAX(0, (int)clean_code.length() - 10);
        print_line("[VG COMPLETION] Last 10 chars: '" + clean_code.substr(start) + "'");
    }
    
    if (!clean_code.is_empty()) {
        char32_t last_char = clean_code[clean_code.length() - 1];
        
        // 0. CBM-STYLE COMPLETION: Check for two-letter abbreviations
        if (clean_code.length() >= 2) {
            String last_two = clean_code.substr(clean_code.length() - 2, 2);
            
            // Check if this could be a CBM abbreviation
            if (CBMCompletionHelper::should_trigger_cbm_completion(clean_code, last_two)) {
                Array cbm_completions = CBMCompletionHelper::get_cbm_completions(last_two);
                
                if (cbm_completions.size() > 0) {
                    // If unambiguous, auto-expand immediately
                    if (cbm_completions.size() == 1) {
                        Dictionary opt;
                        opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
                        opt["display"] = String(cbm_completions[0]) + " (CBM: " + last_two.to_upper() + ")";
                        opt["insert_text"] = "\b\b" + String(cbm_completions[0]); // Delete 2 chars, insert expansion
                        opt["location"] = 0;
                        opt["font_color"] = Color(1, 1, 1, 1);
                        opt["icon"] = Variant();
                        opt["default_value"] = Variant();
                        options.push_back(opt);
                        
                        result["options"] = options;
                        result["force"] = true;
                        result["call_hint"] = "";
                        result["result"] = OK;
                        return result;
                    }
                    
                    // If ambiguous, show all options
                    for (int i = 0; i < cbm_completions.size(); i++) {
                        Dictionary opt;
                        opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
                        opt["display"] = String(cbm_completions[i]) + " (CBM: " + last_two.to_upper() + ")";
                        opt["insert_text"] = "\b\b" + String(cbm_completions[i]);
                        opt["location"] = 0;
                        opt["font_color"] = Color(1, 1, 1, 1);
                        opt["icon"] = Variant();
                        opt["default_value"] = Variant();
                        options.push_back(opt);
                    }
                    
                    result["options"] = options;
                    result["force"] = true;
                    result["call_hint"] = "";
                    result["result"] = OK;
                    return result;
                }
            }
        }
        
        // 1. SMART BRACE COMPLETION: "{" fills in "Then", "To", etc.
        if (last_char == '{') {
            // Get the current line
            PackedStringArray lines = p_code.split("\n");
            String current_line = lines.size() > 0 ? lines[lines.size() - 1] : "";
            
            String completion = SnippetHelper::detect_brace_keyword_completion(current_line);
            if (!completion.is_empty()) {
                Dictionary opt;
                opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
                opt["display"] = completion;
                opt["insert_text"] = "\b" + completion; // \b to delete the {
                opt["location"] = 0;
                opt["font_color"] = Color(1, 1, 1, 1);
                opt["icon"] = Variant();
                opt["default_value"] = Variant();
                options.push_back(opt);
                
                result["options"] = options;
                result["force"] = true;
                result["call_hint"] = "";
                result["result"] = OK;
                return result;
            }
        }
        
        // 2. BRACKET COMPLETION: "}" fills in "Next", "End If", etc.
        if (BracketCompletionHelper::is_trigger_char(last_char)) {
            int line_count = p_code.count("\n");
            String closing_keyword = BracketCompletionHelper::detect_closing_keyword(p_code, line_count);
            
            if (!closing_keyword.is_empty()) {
                Dictionary opt;
                opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
                opt["display"] = closing_keyword;
                opt["insert_text"] = "\b" + closing_keyword;
                opt["location"] = 0;
                opt["font_color"] = Color(1, 1, 1, 1);
                opt["icon"] = Variant();
                opt["default_value"] = Variant();
                options.push_back(opt);
                
                result["options"] = options;
                result["force"] = true;
                result["call_hint"] = "";
                result["result"] = OK;
                return result;
            }
        }
        
        // 3. PARAMETER HINTS: "(" shows function signature
        if (last_char == '(') {
            PackedStringArray lines = p_code.split("\n");
            String current_line = lines.size() > 0 ? lines[lines.size() - 1] : "";
            String func_name = SnippetHelper::extract_function_name(current_line);
            
            if (!func_name.is_empty()) {
                Dictionary hint = SnippetHelper::get_parameter_hint(func_name);
                if (hint.get("found", false)) {
                    Dictionary opt;
                    opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION;
                    opt["display"] = String(hint["signature"]);
                    opt["insert_text"] = "";  // Don't insert, just show hint
                    opt["location"] = 0;
                    opt["font_color"] = Color(1, 1, 1, 1);
                    opt["icon"] = Variant();
                    opt["default_value"] = Variant();
                    options.push_back(opt);
                    
                    result["options"] = options;
                    result["force"] = true;
                    result["call_hint"] = String(hint["signature"]);
                    result["result"] = OK;
                    return result;
                }
            }
        }
    }
    
    // 4. MEMBER ACCESS COMPLETION
    if (clean_code.ends_with(".")) {
         print_line("[VG COMPLETION] Detected '.' - checking for Me.");
         // Check if it's "Me." - if so, show form controls
         String lower = clean_code.to_lower();
         bool is_me_dot = false;
         
         // Check if it ends with "me." - but make sure "me" is a complete word/identifier
         if (lower.ends_with("me.")) {
              // Make sure it's not part of a longer identifier like "SomeVariable."
              // Check if there's nothing before "me" or if what's before is not alphanumeric
              int me_start = lower.length() - 3; // Position of 'm' in "me."
              if (me_start == 0 || !is_identifier_char(lower[me_start - 1])) {
                   is_me_dot = true;
                   print_line("[VG COMPLETION] IS Me. completion!");
              }
         }
         
         if (is_me_dot) {
              // Show form controls/children from owner node
              print_line("[VG COMPLETION] p_owner: " + String(p_owner ? p_owner->get_class() : "null"));
              if (p_owner) {
                   Node *owner_node = Object::cast_to<Node>(p_owner);
                   print_line("[VG COMPLETION] owner_node: " + String(owner_node ? "valid" : "null"));
                   if (owner_node) {
                        // Get all child nodes
                        TypedArray<Node> children = owner_node->get_children();
                        for (int i = 0; i < children.size(); i++) {
                             Node *child = Object::cast_to<Node>(children[i]);
                             if (child) {
                                  String child_name = child->get_name();
                                  String child_type = child->get_class();
                                  
                                  Dictionary opt;
                                  opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER;
                                  opt["display"] = child_name + " : " + child_type;
                                  opt["insert_text"] = child_name;
                                  opt["location"] = 0;
                                  opt["font_color"] = Color(1, 1, 1, 1);
                                  opt["icon"] = Variant();
                                  opt["default_value"] = Variant();
                                  options.push_back(opt);
                             }
                        }
                   }
              }
              
              // Also show common form properties/methods
              options.push_back(create_completion_option("Text", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form title"));
              options.push_back(create_completion_option("size", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form size"));
              options.push_back(create_completion_option("position", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form position"));
              options.push_back(create_completion_option("Close", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Close()"));
              options.push_back(create_completion_option("Show", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Show()"));
              options.push_back(create_completion_option("Hide", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Hide()"));
              options.push_back(create_completion_option("add_child", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "add_child(node)"));
              options.push_back(create_completion_option("find_child", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "find_child(name)"));
              options.push_back(create_completion_option("get_node", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "get_node(path)"));
         } else {
              // Generic member access - show common properties
              options.push_back(create_completion_option("text", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Text Property"));
              options.push_back(create_completion_option("visible", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Visible Property"));
              options.push_back(create_completion_option("position", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Position Property"));
              options.push_back(create_completion_option("size", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Size Property"));
              options.push_back(create_completion_option("name", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Name Property"));
              options.push_back(create_completion_option("show", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "show()"));
              options.push_back(create_completion_option("hide", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "hide()"));
         }
         
         result["options"] = options;
         result["force"] = true;
         result["call_hint"] = "";
         result["result"] = OK;
         return result;
    }
    
    // 5. SNIPPET COMPLETION
    // Check if user typed a snippet trigger
    int len = p_code.length();
    String last_word = "";
    for(int i = len - 1; i >= 0; i--) {
        char32_t c = p_code[i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_') {
            last_word = String::chr(c) + last_word;
        } else {
            break;
        }
    }
    
    // Check if it's a snippet trigger
    if (!last_word.is_empty()) {
        Dictionary snippet = SnippetHelper::get_snippet(last_word.to_lower());
        if (!snippet.is_empty()) {
            Dictionary opt;
            opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
            opt["display"] = String(snippet["trigger"]) + " - " + String(snippet["description"]);
            opt["insert_text"] = String(snippet["insert_text"]);
            opt["location"] = 0;
            opt["font_color"] = Color(1, 1, 1, 1);
            opt["icon"] = Variant();
            opt["default_value"] = Variant();
            options.push_back(opt);
        }
    }
    
    // Also show all available snippets as suggestions
    Array all_snippets = SnippetHelper::get_all_snippets();
    for (int i = 0; i < all_snippets.size(); i++) {
        Dictionary snip = all_snippets[i];
        String trigger = snip["trigger"];
        
        // Filter by prefix if we have one
        if (last_word.is_empty() || trigger.begins_with(last_word.to_lower())) {
            Dictionary opt;
            opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_PLAIN_TEXT;
            opt["display"] = trigger + " - " + String(snip["description"]);
            opt["insert_text"] = String(snip["insert_text"]);
            opt["location"] = 0;
            opt["font_color"] = Color(1, 1, 1, 1);
            opt["icon"] = Variant();
            opt["default_value"] = Variant();
            options.push_back(opt);
        }
    }
    
    // 6. KEYWORD AND FUNCTION COMPLETION
    PackedStringArray keywords = _get_reserved_words();
    
    // Add Built-in Functions
    keywords.push_back("CreateActor2D");
    keywords.push_back("AI_Chase");
    keywords.push_back("LoadForm");
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
    
    // Build keyword completion options
    // Use last_word from snippet section above as prefix filter
    
    for(int i=0; i<keywords.size(); i++) {
        String k = keywords[i];
        if (last_word.is_empty() || k.begins_with(last_word) || k.to_lower().begins_with(last_word.to_lower())) {
             Dictionary opt;
             opt["kind"] = 1;
             opt["display"] = k;
             opt["insert_text"] = k;
             opt["completion_text"] = k;
             opt["location"] = 0; // LOCAL?
             opt["font_color"] = Color(1, 1, 1, 1);
             opt["icon"] = Variant();
             opt["default_value"] = Variant();
             options.push_back(opt);
        }
    }
    
    print_line("[VG COMPLETION] Returning " + itos(options.size()) + " options");
    result["options"] = options;
    result["force"] = false;
    result["call_hint"] = "";
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
    
    // Step debugging methods - these are instance methods that delegate to static methods
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_debug_continue"), &VisualGasicLanguage::debug_continue);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_debug_step_into"), &VisualGasicLanguage::debug_step_into);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_debug_step_over"), &VisualGasicLanguage::debug_step_over);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_debug_step_out"), &VisualGasicLanguage::debug_step_out);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_step_mode"), &VisualGasicLanguage::get_step_mode_int);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_current_debug_line"), &VisualGasicLanguage::get_current_debug_line);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_current_debug_file"), &VisualGasicLanguage::get_current_debug_file);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_break_file"), &VisualGasicLanguage::get_break_file);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_break_line"), &VisualGasicLanguage::get_break_line);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_clear_breakpoints"), &VisualGasicLanguage::clear_breakpoints);
    
    // Watchpoint (data breakpoint) methods
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_add_watchpoint", "variable_name"), &VisualGasicLanguage::add_watchpoint);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_remove_watchpoint", "variable_name"), &VisualGasicLanguage::remove_watchpoint);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_clear_watchpoints"), &VisualGasicLanguage::clear_watchpoints);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_watchpoints"), &VisualGasicLanguage::get_watchpoints);
    
    // Expression evaluation in debug context
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_evaluate_expression", "expression"), &VisualGasicLanguage::evaluate_expression_in_context);
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
    return String(debug_error.c_str());
}

int32_t VisualGasicLanguage::_debug_get_stack_level_count() const {
    auto& stack = get_debug_stack();
    return (int32_t)stack.size();
}

int32_t VisualGasicLanguage::_debug_get_stack_level_line(int32_t p_level) const {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        // Stack is stored with most recent at end, but Godot expects level 0 = top
        int idx = stack.size() - 1 - p_level;
        // For the top frame (level 0), use stored breakpoint line if available (more accurate during debug breaks)
        if (p_level == 0 && current_break_line > 0) {
            return current_break_line;
        }
        return stack[idx].line;
    }
    return -1;
}

String VisualGasicLanguage::_debug_get_stack_level_function(int32_t p_level) const {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        int idx = stack.size() - 1 - p_level;
        return String(stack[idx].function.c_str());
    }
    return "";
}

Dictionary VisualGasicLanguage::_debug_get_stack_level_locals(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        int idx = stack.size() - 1 - p_level;
        VisualGasicInstance* instance = stack[idx].instance;
        if (instance) {
            return instance->get_debug_locals();
        }
    }
    return Dictionary();
}

Dictionary VisualGasicLanguage::_debug_get_stack_level_members(int32_t p_level, int32_t p_max_subitems, int32_t p_max_depth) {
    // For VB6-style scripts, members are typically the same as globals
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        int idx = stack.size() - 1 - p_level;
        VisualGasicInstance* instance = stack[idx].instance;
        if (instance) {
            return instance->get_debug_globals();
        }
    }
    return Dictionary();
}

void *VisualGasicLanguage::_debug_get_stack_level_instance(int32_t p_level) {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        int idx = stack.size() - 1 - p_level;
        VisualGasicInstance* instance = stack[idx].instance;
        if (instance) {
            return instance->get_owner();
        }
    }
    return nullptr;
}

TypedArray<Dictionary> VisualGasicLanguage::_debug_get_current_stack_info() {
    auto& stack = get_debug_stack();
    TypedArray<Dictionary> stack_info;
    // Iterate from top (most recent) to bottom
    for (int i = stack.size() - 1; i >= 0; i--) {
        Dictionary frame;
        frame["file"] = String(stack[i].file.c_str());
        frame["func"] = String(stack[i].function.c_str());
        // For the top frame, use the stored breakpoint line if available (more accurate during debug breaks)
        if (i == (int)stack.size() - 1 && current_break_line > 0) {
            frame["line"] = current_break_line;
        } else {
            frame["line"] = stack[i].line;
        }
        stack_info.push_back(frame);
    }
    return stack_info;
}

void VisualGasicLanguage::_frame() {
    // Called every frame
}

Dictionary VisualGasicLanguage::_debug_get_globals(int32_t p_max_subitems, int32_t p_max_depth) {
    // Return globals from the most recent stack frame's instance
    auto& stack = get_debug_stack();
    if (!stack.empty()) {
        VisualGasicInstance* instance = stack.back().instance;
        if (instance) {
            return instance->get_debug_globals();
        }
    }
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
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        // For the top frame (level 0), use stored breakpoint file if available
        if (p_level == 0 && !current_break_file.empty()) {
            return String(current_break_file.c_str());
        }
        int idx = stack.size() - 1 - p_level;
        return String(stack[idx].file.c_str());
    }
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
// === Debug Call Stack Management ===

void VisualGasicLanguage::push_stack_frame(const String& file, const String& function, int line, VisualGasicInstance* instance) {
    VGDebugStackFrame frame;
    frame.file = file.utf8().get_data();
    frame.function = function.utf8().get_data();
    frame.line = line;
    frame.instance = instance;
    get_debug_stack().push_back(frame);
}

void VisualGasicLanguage::pop_stack_frame() {
    auto& stack = get_debug_stack();
    if (!stack.empty()) {
        stack.pop_back();
    }
}

void VisualGasicLanguage::update_stack_frame_line(int line) {
    auto& stack = get_debug_stack();
    if (!stack.empty()) {
        stack.back().line = line;
    }
}

void VisualGasicLanguage::set_debug_error(const String& error) {
    debug_error = error.utf8().get_data();
}

void VisualGasicLanguage::clear_debug_error() {
    debug_error = "";
}

// === Step Debugging Control ===

void VisualGasicLanguage::set_step_mode(VGStepMode mode) {
    step_mode = mode;
}

int VisualGasicLanguage::get_current_stack_depth() {
    return static_cast<int>(get_debug_stack().size());
}

void VisualGasicLanguage::debug_continue() {
    step_mode = VG_STEP_NONE;
    step_target_depth = 0;
    waiting_for_continue = false;  // Signal wait loop to exit
    // Clear breakpoint location so stack info returns normal line
    current_break_file.clear();
    current_break_line = 0;
}

void VisualGasicLanguage::debug_step_into() {
    step_mode = VG_STEP_INTO;
    step_target_depth = 0;  // Not used for step into
    waiting_for_continue = false;  // Signal wait loop to exit
}

void VisualGasicLanguage::debug_step_over() {
    step_mode = VG_STEP_OVER;
    step_target_depth = get_current_stack_depth();  // Break at same or shallower depth
    waiting_for_continue = false;  // Signal wait loop to exit
}

void VisualGasicLanguage::debug_step_out() {
    step_mode = VG_STEP_OUT;
    step_target_depth = get_current_stack_depth() - 1;  // Break when we return to parent
    if (step_target_depth < 0) step_target_depth = 0;
    waiting_for_continue = false;  // Signal wait loop to exit
}

// Custom debug wait loop - uses Godot's script_debug which handles the pause properly
// The step buttons in Godot's debugger panel will work, but our custom Immediate Window
// buttons need to trigger Godot's internal mechanisms
void VisualGasicLanguage::wait_for_debug_command() {
    EngineDebugger* debugger = EngineDebugger::get_singleton();
    if (!debugger) {
        UtilityFunctions::printerr("[VisualGasic] No debugger available, continuing execution");
        return;
    }
    
    // Ensure message capture is registered
    ensure_message_capture_registered();
    
    // Reset waiting flag
    waiting_for_continue = true;
    
    // Custom wait loop that polls for file-based commands
    // This is necessary because EditorDebuggerSession.send_message() doesn't reach
    // EngineDebugger::register_message_capture() handlers
    int poll_count = 0;
    while (waiting_for_continue && debugger->is_active()) {
        // Poll debugger (may process some messages)
        debugger->line_poll();
        
        // Check for file-based debug command (primary mechanism)
        String cmd_path = "res://.vg_debug_cmd";
        Ref<FileAccess> f = FileAccess::open(cmd_path, FileAccess::READ);
        if (f.is_valid()) {
            String cmd = f->get_as_text().strip_edges();
            f.unref();
            
            // Delete the file immediately to avoid re-processing
            Ref<DirAccess> dir = DirAccess::open("res://");
            if (dir.is_valid()) {
                dir->remove(".vg_debug_cmd");
            }
            
            // Process the command
            if (cmd == "step_into") {
                debug_step_into();
            } else if (cmd == "step_over") {
                debug_step_over();
            } else if (cmd == "step_out") {
                debug_step_out();
            } else if (cmd == "continue") {
                debug_continue();
            }
        }
        
        // Small delay to avoid spinning CPU  
        OS::get_singleton()->delay_usec(16000);  // ~60fps
    }
}

// Wrapper methods for GDScript binding (returns int for enum)
int VisualGasicLanguage::get_step_mode_int() {
    return static_cast<int>(step_mode);
}

String VisualGasicLanguage::get_current_debug_file() {
    auto& stack = get_debug_stack();
    if (!stack.empty()) {
        return String(stack.back().file.c_str());
    }
    return String();
}

int VisualGasicLanguage::get_current_debug_line() {
    auto& stack = get_debug_stack();
    if (!stack.empty()) {
        return stack.back().line;
    }
    return 0;
}

Array VisualGasicLanguage::get_call_stack_array() {
    Array result;
    auto& stack = get_debug_stack();
    
    // Return stack from top (most recent) to bottom (oldest)
    for (int i = static_cast<int>(stack.size()) - 1; i >= 0; i--) {
        Dictionary frame;
        frame["function"] = String(stack[i].function.c_str());
        frame["file"] = String(stack[i].file.c_str());
        frame["line"] = stack[i].line;
        result.push_back(frame);
    }
    
    return result;
}

// Set/get current breakpoint location (for editor navigation)
void VisualGasicLanguage::set_current_break_location(const String& file, int line) {
    current_break_file = file.utf8().get_data();
    current_break_line = line;
}

String VisualGasicLanguage::get_break_file() {
    return String(current_break_file.c_str());
}

int VisualGasicLanguage::get_break_line() {
    return current_break_line;
}

// Breakpoint management (C++ side - avoid GDScript calls during debug)
void VisualGasicLanguage::load_breakpoints_from_file() {
    breakpoints.clear();
    breakpoints_loaded = true;  // Mark as loaded even if file doesn't exist
    
    String bp_file = "res://.vg_breakpoints.json";
    if (!FileAccess::file_exists(bp_file)) {
        return;
    }
    
    Ref<FileAccess> f = FileAccess::open(bp_file, FileAccess::READ);
    if (!f.is_valid()) {
        return;
    }
    
    String content = f->get_as_text();
    f->close();
    
    Ref<JSON> json;
    json.instantiate();
    Error err = json->parse(content);
    if (err != OK) {
        return;
    }
    
    Variant data = json->get_data();
    if (data.get_type() != Variant::DICTIONARY) {
        return;
    }
    
    Dictionary dict = data;
    Array keys = dict.keys();
    for (int i = 0; i < keys.size(); i++) {
        String script_path = keys[i];
        Variant lines_var = dict[script_path];
        if (lines_var.get_type() != Variant::ARRAY) {
            continue;
        }
        
        Array lines_arr = lines_var;
        std::vector<int> lines;
        for (int j = 0; j < lines_arr.size(); j++) {
            lines.push_back((int)lines_arr[j]);
        }
        
        std::string key = script_path.utf8().get_data();
        breakpoints[key] = lines;
    }
}

bool VisualGasicLanguage::has_breakpoint(const String& script_path, int line) {
    // Load breakpoints on first check
    if (!breakpoints_loaded) {
        UtilityFunctions::print("[VG Debug] Loading breakpoints from file...");
        load_breakpoints_from_file();
        UtilityFunctions::print("[VG Debug] Loaded breakpoints for ", (int)breakpoints.size(), " scripts");
        for (auto& kv : breakpoints) {
            String msg = String("[VG Debug]   Script: ") + kv.first.c_str() + " has " + String::num_int64(kv.second.size()) + " breakpoints: ";
            for (int bp : kv.second) {
                msg += String::num_int64(bp) + " ";
            }
            UtilityFunctions::print(msg);
        }
    }
    
    std::string key = script_path.utf8().get_data();
    auto it = breakpoints.find(key);
    if (it == breakpoints.end()) {
        return false;
    }
    
    for (int bp_line : it->second) {
        if (bp_line == line) {
            UtilityFunctions::print("[VG Debug] *** BREAKPOINT MATCH at ", script_path, ":", line);
            return true;
        }
    }
    return false;
}

void VisualGasicLanguage::clear_breakpoints() {
    breakpoints.clear();
    breakpoints_loaded = false;
}

// ============================================================================
// DATA BREAKPOINTS (WATCHPOINTS)
// ============================================================================

// Static storage for watchpoints
std::map<std::string, VisualGasicLanguage::Watchpoint> VisualGasicLanguage::watchpoints;

void VisualGasicLanguage::add_watchpoint(const String& variable_name) {
    std::string key = variable_name.utf8().get_data();
    if (watchpoints.find(key) == watchpoints.end()) {
        Watchpoint wp;
        wp.variable_name = key;
        wp.has_value = false;
        watchpoints[key] = wp;
        UtilityFunctions::print("[VG Debug] Added watchpoint: ", variable_name);
    }
}

void VisualGasicLanguage::remove_watchpoint(const String& variable_name) {
    std::string key = variable_name.utf8().get_data();
    auto it = watchpoints.find(key);
    if (it != watchpoints.end()) {
        watchpoints.erase(it);
        UtilityFunctions::print("[VG Debug] Removed watchpoint: ", variable_name);
    }
}

void VisualGasicLanguage::clear_watchpoints() {
    watchpoints.clear();
    UtilityFunctions::print("[VG Debug] Cleared all watchpoints");
}

Array VisualGasicLanguage::get_watchpoints() {
    Array result;
    for (auto& kv : watchpoints) {
        Dictionary wp_info;
        wp_info["name"] = String(kv.first.c_str());
        wp_info["has_value"] = kv.second.has_value;
        if (kv.second.has_value) {
            wp_info["last_value"] = kv.second.last_value;
        }
        result.push_back(wp_info);
    }
    return result;
}

bool VisualGasicLanguage::check_watchpoint(const String& variable_name, const Variant& new_value) {
    std::string key = variable_name.utf8().get_data();
    auto it = watchpoints.find(key);
    if (it == watchpoints.end()) {
        return false;  // Not a watched variable
    }
    
    Watchpoint& wp = it->second;
    if (!wp.has_value) {
        // First time seeing this variable - store value but don't break
        wp.last_value = new_value;
        wp.has_value = true;
        return false;
    }
    
    // Check if value changed
    if (wp.last_value != new_value) {
        UtilityFunctions::print("[VG Debug] WATCHPOINT HIT: ", variable_name, " changed from ", 
                                String(wp.last_value), " to ", String(new_value));
        wp.last_value = new_value;
        return true;  // Value changed, trigger break
    }
    
    return false;
}

// ============================================================================
// EXPRESSION EVALUATION IN DEBUG CONTEXT
// ============================================================================

String VisualGasicLanguage::evaluate_expression_in_context(const String& expression) {
    // Get the current debug instance (top of stack)
    auto& stack = get_debug_stack();
    if (stack.empty()) {
        return "[Error: No debug context - not paused at a breakpoint]";
    }
    
    VGDebugStackFrame& top_frame = stack.back();
    VisualGasicInstance* instance = top_frame.instance;
    if (!instance) {
        return "[Error: No active instance in debug context]";
    }
    
    // Get the expression result from the instance
    String trimmed = expression.strip_edges();
    
    // Try to get a variable value first (simple case)
    Variant result;
    if (instance->get(StringName(trimmed), result)) {
        return String(result);
    }
    
    // For more complex expressions, we'd need to parse and evaluate
    // For now, try common patterns
    
    // Check for member access (e.g., obj.property)
    if (trimmed.contains(".")) {
        PackedStringArray parts = trimmed.split(".", true, 1);
        String base_name = parts[0];
        String member = parts[1];
        
        Variant base_value;
        if (instance->get(StringName(base_name), base_value)) {
            if (base_value.get_type() == Variant::OBJECT) {
                Object* obj = base_value;
                if (obj) {
                    Variant member_value = obj->get(StringName(member));
                    return String(member_value);
                }
            } else if (base_value.get_type() == Variant::VECTOR2) {
                Vector2 v = base_value;
                if (member == "x") return String::num(v.x);
                if (member == "y") return String::num(v.y);
            } else if (base_value.get_type() == Variant::VECTOR3) {
                Vector3 v = base_value;
                if (member == "x") return String::num(v.x);
                if (member == "y") return String::num(v.y);
                if (member == "z") return String::num(v.z);
            }
        }
    }
    
    return "[Cannot evaluate: " + trimmed + "]";
}
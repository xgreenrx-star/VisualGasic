#include "visual_gasic_language.h"
#include "visual_gasic_causal_graph.h"
#include "visual_gasic_bracket_completion.h"
#include "visual_gasic_snippets.h"
#include "visual_gasic_cbm_completion.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_debugger.h"
#include "visual_gasic_linter.h"
#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h"
#include "visual_gasic_profiler.h"
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
#include <functional>

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

// Exception Assistant: break on unhandled errors (VB6-style, defaults ON)
bool VisualGasicLanguage::break_on_unhandled_error = true;

// Set Next Statement state
bool VisualGasicLanguage::next_statement_requested = false;
int VisualGasicLanguage::next_statement_line = 0;

// Edit & Continue state
bool VisualGasicLanguage::edit_and_continue_pending = false;
std::string VisualGasicLanguage::edit_and_continue_source;
std::string VisualGasicLanguage::edit_and_continue_path;

// Hot Reload infrastructure
std::set<VisualGasicScript*> VisualGasicLanguage::live_scripts;
std::mutex VisualGasicLanguage::live_scripts_mutex;
std::vector<VisualGasicScript*> VisualGasicLanguage::pending_reloads;

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

Dictionary VisualGasicLanguage::vg_validate_code(const String &p_code, const String &p_path) {
    VisualGasicLanguage *lang = get_singleton();
    if (!lang) {
        Dictionary result;
        result["valid"] = false;
        Array errors;
        Dictionary err;
        err["line"] = 1;
        err["column"] = 0;
        err["message"] = "VisualGasic language not loaded";
        errors.push_back(err);
        result["errors"] = errors;
        result["warnings"] = Array();
        return result;
    }
    return lang->_validate(p_code, p_path, true, true, true, false);
}

Dictionary VisualGasicLanguage::vg_analyze_causal_graph(const String &p_code, const Array &p_roots) {
    return ::godot::vg_analyze_causal_graph(p_code, p_roots);
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
    
    // Handle evaluate directly using C++ registry — the GDScript handler
    // cannot resolve instances because C++ manages its own registry.
    if (p_message == "evaluate" && p_data.size() >= 3) {
        int instance_id = p_data[0];
        String code = p_data[1];
        int request_id = p_data[2];
        
        Dictionary result = VisualGasicLanguage::evaluate_immediate_by_index(instance_id, code);
        
        EngineDebugger* debugger = EngineDebugger::get_singleton();
        if (debugger) {
            Array msg_data;
            msg_data.push_back(request_id);
            msg_data.push_back(result);
            debugger->send_message("visualgasic:eval_result", msg_data);
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
    else if (p_message == "set_next_statement" && p_data.size() >= 1) {
        int line = p_data[0];
        VisualGasicLanguage::set_next_statement(line);
        UtilityFunctions::print("[VG Debug] C++ set_next_statement → line ", line);
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
    words.push_back("Thread");
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

             // Run linter for warnings (only if parse succeeded and warnings requested)
             if (p_validate_warnings && parser.errors.size() == 0 && root) {
                 VisualGasicLinter linter;
                 Array lint_warnings = linter.analyze(root);
                 for (int i = 0; i < lint_warnings.size(); i++) {
                     ((Array)result["warnings"]).push_back(lint_warnings[i]);
                 }
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

// Helper: Recursively find a control by name (case-insensitive)
Node* VisualGasicLanguage::_find_control_recursive(Node* node, const String& name) const {
    if (!node) return nullptr;
    
    for (int i = 0; i < node->get_child_count(); i++) {
        Node *child = node->get_child(i);
        if (child->get_name().to_lower() == name.to_lower()) {
            return child;
        }
        Node *result = _find_control_recursive(child, name);
        if (result) return result;
    }
    return nullptr;
}

// Helper: Add child controls to completion options
void VisualGasicLanguage::_add_child_controls_to_completion(Node* owner, Array& options, const String& filter) const {
    if (!owner) return;
    
    std::function<void(Node*)> add_children = [&](Node* node) {
        for (int i = 0; i < node->get_child_count(); i++) {
            Node *child = node->get_child(i);
            String child_name = child->get_name();
            String child_type = child->get_class();
            
            // Skip internal nodes
            if (child_name.begins_with("_")) continue;
            
            // Filter by prefix if provided
            if (!filter.is_empty() && !child_name.to_lower().begins_with(filter.to_lower())) continue;
            
            Dictionary opt;
            opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER;
            opt["display"] = child_name + " : " + child_type;
            opt["insert_text"] = child_name;
            opt["location"] = 0;
            opt["font_color"] = Color(1, 1, 1, 1);
            opt["icon"] = Variant();
            opt["default_value"] = Variant();
            options.push_back(opt);
            
            // Recurse into children
            add_children(child);
        }
    };
    add_children(owner);
}

// Helper: Add form properties to completion
void VisualGasicLanguage::_add_form_properties_to_completion(Array& options, const String& filter) const {
    auto add_opt = [&](const String& name, int kind, const String& hint) {
        if (!filter.is_empty() && !name.to_lower().begins_with(filter.to_lower())) return;
        options.push_back(create_completion_option(name, kind, hint));
    };
    
    add_opt("Text", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form title");
    add_opt("Size", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form size");
    add_opt("Position", ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER, "Form position");
    add_opt("Close", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Close()");
    add_opt("Show", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Show()");
    add_opt("Hide", ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION, "Hide()");
}

// Helper: Add control-specific properties to completion
// Provides all 62 VB6 property aliases plus type-specific methods.
void VisualGasicLanguage::_add_control_properties_to_completion(const String& control_class, Array& options, const String& filter) const {
    auto add_opt = [&](const String& name, int kind, const String& hint) {
        if (!filter.is_empty() && !name.to_lower().begins_with(filter.to_lower())) return;
        options.push_back(create_completion_option(name, kind, hint));
    };
    const int M = ScriptLanguageExtension::CODE_COMPLETION_KIND_MEMBER;
    const int F = ScriptLanguageExtension::CODE_COMPLETION_KIND_FUNCTION;

    // ── Common VB6 properties (all controls) ────────────────────────────
    add_opt("Name", M, "Control name");
    add_opt("Caption", M, "Text / caption (alias for Text)");
    add_opt("Text", M, "Text content");
    add_opt("Visible", M, "Show/hide control");
    add_opt("Enabled", M, "Enable/disable control");
    add_opt("Left", M, "X position (pixels)");
    add_opt("Top", M, "Y position (pixels)");
    add_opt("Width", M, "Width (pixels)");
    add_opt("Height", M, "Height (pixels)");
    add_opt("Tag", M, "User-defined tag (Variant)");
    add_opt("ToolTipText", M, "Tooltip on hover");
    add_opt("TabStop", M, "Include in tab order (Boolean)");
    add_opt("TabIndex", M, "Tab order index (Integer)");
    add_opt("MousePointer", M, "Cursor shape (Integer)");
    add_opt("BackColor", M, "Background color");
    add_opt("ForeColor", M, "Foreground / font color");
    add_opt("FontName", M, "Font family name (String)");
    add_opt("FontSize", M, "Font size (Integer)");
    add_opt("FontBold", M, "Bold font (Boolean)");
    add_opt("FontItalic", M, "Italic font (Boolean)");
    add_opt("FontUnderline", M, "Underline font (Boolean)");
    add_opt("FontStrikethrough", M, "Strikethrough font (Boolean)");
    add_opt("BorderStyle", M, "Border style (0=None, 1=Solid)");
    add_opt("Opacity", M, "Opacity 0-100");
    add_opt("ZOrder", M, "Z-index / draw order (alias: ZIndex)");
    add_opt("ZIndex", M, "Z-index / draw order (alias: ZOrder)");
    add_opt("Rotation", M, "Rotation in degrees");
    add_opt("hWnd", M, "Instance ID / handle");
    add_opt("BackStyle", M, "0=Transparent, 1=Opaque");
    add_opt("Appearance", M, "0=Flat, 1=3D");
    add_opt("Parent", M, "Parent node (read-only)");
    add_opt("Container", M, "Parent container (read-only)");
    add_opt("Index", M, "Control array index");
    add_opt("DragMode", M, "0=Manual, 1=Automatic");

    // ── Type-specific properties ────────────────────────────────────────
    if (control_class == "LineEdit") {
        add_opt("MaxLength", M, "Maximum characters");
        add_opt("PlaceholderText", M, "Placeholder text");
        add_opt("PasswordChar", M, "Password mask character");
        add_opt("Locked", M, "Read-only (Boolean)");
        add_opt("Editable", M, "Editable (Boolean)");
        add_opt("SelStart", M, "Selection start position");
        add_opt("SelLength", M, "Selection length");
        add_opt("SelText", M, "Selected text");
        add_opt("Alignment", M, "Text alignment");
        add_opt("SelectAll", F, "Select all text");
        add_opt("Clear", F, "Clear text");
    } else if (control_class == "Button") {
        add_opt("Flat", M, "Flat style (Boolean)");
        add_opt("Style", M, "Button style (alias for Flat)");
        add_opt("ClipText", M, "Clip long text (Boolean)");
        add_opt("Icon", M, "Button icon (Texture)");
    } else if (control_class == "Label") {
        add_opt("WordWrap", M, "Word wrap (Boolean)");
        add_opt("AutoSize", M, "Auto-size to content (Boolean)");
        add_opt("Alignment", M, "Text alignment");
    } else if (control_class == "CheckBox" || control_class == "CheckButton") {
        add_opt("Value", M, "Checked state (Boolean)");
        add_opt("Flat", M, "Flat style");
    } else if (control_class == "OptionButton") {
        add_opt("ListCount", M, "Number of items");
        add_opt("ListIndex", M, "Selected item index");
        add_opt("Sorted", M, "Items sorted (Boolean)");
        add_opt("AddItem", F, "Add item");
        add_opt("Clear", F, "Clear all items");
    } else if (control_class == "TextEdit") {
        add_opt("MultiLine", M, "Multi-line mode (always True)");
        add_opt("ScrollBars", M, "Scrollbar mode (0-3)");
        add_opt("Locked", M, "Read-only (Boolean)");
        add_opt("Editable", M, "Editable (Boolean)");
        add_opt("SelStart", M, "Selection start");
        add_opt("SelLength", M, "Selection length");
        add_opt("SelText", M, "Selected text");
        add_opt("WordWrap", M, "Word wrap (Boolean)");
        add_opt("SelectAll", F, "Select all text");
        add_opt("Clear", F, "Clear text");
    } else if (control_class == "ProgressBar" || control_class == "HSlider" || control_class == "VSlider"
               || control_class == "SpinBox" || control_class == "Range") {
        add_opt("Value", M, "Current value");
        add_opt("MinValue", M, "Minimum value");
        add_opt("MaxValue", M, "Maximum value");
    } else if (control_class == "Timer") {
        add_opt("Interval", M, "Timer interval (ms)");
        add_opt("OneShot", M, "Fire once (Boolean)");
        add_opt("Autostart", M, "Auto-start (Boolean)");
        add_opt("Start", F, "Start timer");
        add_opt("Stop", F, "Stop timer");
    } else if (control_class == "ItemList") {
        add_opt("ListCount", M, "Number of items");
        add_opt("ListIndex", M, "Selected item index");
        add_opt("Sorted", M, "Items sorted (Boolean)");
        add_opt("AddItem", F, "Add item");
        add_opt("Clear", F, "Clear all items");
    } else if (control_class == "TextureRect") {
        add_opt("Picture", M, "Image texture");
    } else if (control_class == "Window") {
        add_opt("WindowState", M, "0=Normal, 1=Minimized, 2=Maximized");
        add_opt("ShowInTaskbar", M, "Show in taskbar (Boolean)");
        add_opt("Moveable", M, "Window moveable (Boolean)");
        add_opt("MinButton", M, "Show minimize button (Boolean)");
        add_opt("MaxButton", M, "Show maximize button (Boolean)");
        add_opt("ControlBox", M, "Show title bar (Boolean)");
    }

    // Methods available on all controls
    add_opt("Show", F, "Show()");
    add_opt("Hide", F, "Hide()");
    add_opt("Move", F, "Move(Left, Top, [Width], [Height])");
    add_opt("SetFocus", F, "SetFocus()");
    add_opt("Refresh", F, "Refresh()");
}

Dictionary VisualGasicLanguage::_complete_code(const String &p_code, const String &p_path, Object *p_owner) const {
    Dictionary result;
    result["result"] = OK;
    Array options;
    
    // Find the last dot in the code - that's likely where completion was triggered
    int last_dot = p_code.rfind(".");
    
    if (last_dot != -1) {
        // Extract the identifier before the dot
        String identifier = "";
        for (int i = last_dot - 1; i >= 0; i--) {
            char32_t c = p_code[i];
            if (is_identifier_char(c)) {
                identifier = String::chr(c) + identifier;
            } else {
                break;
            }
        }
        
        // Check what's after the dot (partial property name being typed)
        String after_dot = "";
        for (int i = last_dot + 1; i < p_code.length(); i++) {
            char32_t c = p_code[i];
            if (is_identifier_char(c)) {
                after_dot += String::chr(c);
            } else {
                break;
            }
        }
        
        // Check if it's Me.
        if (identifier.to_lower() == "me") {
            // Show form controls
            if (p_owner) {
                Node *owner_node = Object::cast_to<Node>(p_owner);
                if (owner_node) {
                    _add_child_controls_to_completion(owner_node, options, after_dot);
                }
            }
            // Add common form properties
            _add_form_properties_to_completion(options, after_dot);
        } else if (!identifier.is_empty()) {
            // --- Struct/Type member IntelliSense ---
            // Scan code for "Dim <identifier> As <TypeName>" to resolve struct type
            String struct_type = "";
            {
                // Search for patterns like: Dim identifier As TypeName
                // Case-insensitive search through the full code
                PackedStringArray lines = p_code.split("\n");
                for (int li = 0; li < lines.size(); li++) {
                    String line = lines[li].strip_edges();
                    // Match: [Dim|Private|Public] identifier As TypeName
                    String line_lower = line.to_lower();
                    int dim_pos = -1;
                    if (line_lower.begins_with("dim ")) dim_pos = 4;
                    else if (line_lower.begins_with("private ")) dim_pos = 8;
                    else if (line_lower.begins_with("public ")) dim_pos = 7;
                    else if (line_lower.begins_with("static ")) dim_pos = 7;
                    if (dim_pos < 0) continue;
                    
                    String rest = line.substr(dim_pos).strip_edges();
                    // Extract variable name
                    String var_name = "";
                    int ri = 0;
                    while (ri < rest.length() && is_identifier_char(rest[ri])) {
                        var_name += String::chr(rest[ri]);
                        ri++;
                    }
                    if (var_name.nocasecmp_to(identifier) != 0) continue;
                    
                    // Look for "As"
                    String after_var = rest.substr(ri).strip_edges();
                    if (after_var.to_lower().begins_with("as ")) {
                        String type_part = after_var.substr(3).strip_edges();
                        // Skip "New" keyword if present
                        if (type_part.to_lower().begins_with("new ")) {
                            type_part = type_part.substr(4).strip_edges();
                        }
                        // Extract type name
                        String tname = "";
                        for (int ti = 0; ti < type_part.length(); ti++) {
                            if (is_identifier_char(type_part[ti])) {
                                tname += String::chr(type_part[ti]);
                            } else break;
                        }
                        if (!tname.is_empty()) {
                            struct_type = tname;
                            break;
                        }
                    }
                }
            }
            
            // If we found a struct type, look for its Type definition in the code
            if (!struct_type.is_empty()) {
                PackedStringArray lines = p_code.split("\n");
                bool in_struct = false;
                for (int li = 0; li < lines.size(); li++) {
                    String line = lines[li].strip_edges();
                    String line_lower = line.to_lower();
                    
                    if (!in_struct) {
                        // Look for "Type StructName"
                        if (line_lower.begins_with("type ")) {
                            String tname = line.substr(5).strip_edges();
                            // Extract just the name
                            String name_only = "";
                            for (int ci = 0; ci < tname.length(); ci++) {
                                if (is_identifier_char(tname[ci])) name_only += String::chr(tname[ci]);
                                else break;
                            }
                            if (name_only.nocasecmp_to(struct_type) == 0) {
                                in_struct = true;
                            }
                        }
                    } else {
                        // Inside the struct definition
                        if (line_lower.begins_with("end type")) {
                            break; // Done
                        }
                        // Parse member: MemberName As Type [* N]
                        if (!line.is_empty()) {
                            String mem_name = "";
                            int mi = 0;
                            while (mi < line.length() && is_identifier_char(line[mi])) {
                                mem_name += String::chr(line[mi]);
                                mi++;
                            }
                            if (!mem_name.is_empty() && mem_name.to_lower() != "end") {
                                // Extract type info for display
                                String mem_type = "Variant";
                                String after_mem = line.substr(mi).strip_edges();
                                if (after_mem.to_lower().begins_with("as ")) {
                                    mem_type = after_mem.substr(3).strip_edges();
                                }
                                
                                // Filter by what user has typed after dot
                                if (after_dot.is_empty() || mem_name.to_lower().begins_with(after_dot.to_lower())) {
                                    Dictionary opt;
                                    opt["kind"] = 5; // Field
                                    opt["label"] = mem_name;
                                    opt["insert_text"] = mem_name;
                                    opt["display"] = mem_name + " As " + mem_type;
                                    options.push_back(opt);
                                }
                            }
                        }
                    }
                }
            }
            
            // Try to find this control in the form (existing logic)
            if (options.size() == 0) {
                String control_class = "";
                if (p_owner) {
                    Node *owner_node = Object::cast_to<Node>(p_owner);
                    if (owner_node) {
                        Node *found = _find_control_recursive(owner_node, identifier);
                        if (found) {
                            control_class = found->get_class();
                        }
                    }
                }
                
                // Add control-specific or generic properties
                _add_control_properties_to_completion(control_class, options, after_dot);
            }
        }
        
        if (options.size() > 0) {
            result["options"] = options;
            result["force"] = true;
            result["call_hint"] = "";
            return result;
        }
    }
    
    // Fall through to general completion
    String clean_code = p_code.strip_edges(false, true);
    
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
                        // Godot's completion system replaces the typed prefix automatically;
                        // do NOT use "\b\b" — it gets inserted literally.
                        opt["insert_text"] = String(cbm_completions[0]);
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
                        opt["insert_text"] = String(cbm_completions[i]);
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
                
                // Fallback: scan script for user-defined Sub/Function declarations
                if (!hint.get("found", false)) {
                    PackedStringArray code_lines = p_code.split("\n");
                    for (int li = 0; li < code_lines.size(); li++) {
                        String sline = code_lines[li].strip_edges();
                        String sline_lower = sline.to_lower();
                        // Match: [Public|Private] Sub/Function FuncName(...)
                        int name_start = -1;
                        bool is_function = false;
                        if (sline_lower.begins_with("sub ")) { name_start = 4; }
                        else if (sline_lower.begins_with("function ")) { name_start = 9; is_function = true; }
                        else if (sline_lower.begins_with("public sub ")) { name_start = 11; }
                        else if (sline_lower.begins_with("private sub ")) { name_start = 12; }
                        else if (sline_lower.begins_with("public function ")) { name_start = 16; is_function = true; }
                        else if (sline_lower.begins_with("private function ")) { name_start = 17; is_function = true; }
                        if (name_start < 0) continue;
                        
                        // Extract the procedure name
                        String proc_name = "";
                        int pi = name_start;
                        while (pi < sline.length() && is_identifier_char(sline[pi])) {
                            proc_name += String::chr(sline[pi]);
                            pi++;
                        }
                        if (proc_name.nocasecmp_to(func_name) != 0) continue;
                        
                        // Found it — extract the full signature from the source line
                        // Build: "FuncName(params) [As ReturnType]"
                        String sig = sline.substr(name_start).strip_edges();
                        // Remove trailing comments
                        int comment_pos = sig.find("'");
                        if (comment_pos >= 0) sig = sig.substr(0, comment_pos).strip_edges();
                        
                        hint["signature"] = sig;
                        hint["found"] = true;
                        break;
                    }
                }
                
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
    keywords.push_back("DrawString");
    keywords.push_back("DrawLine");
    keywords.push_back("DrawRect");
    keywords.push_back("DrawCircle");
    keywords.push_back("DrawPixel");
    keywords.push_back("PSet");
    keywords.push_back("DrawTexture");
    keywords.push_back("DrawTextureRect");
    keywords.push_back("DrawArc");
    keywords.push_back("DrawPolygon");
    keywords.push_back("DrawPolyline");
    keywords.push_back("SetDrawTransform");
    keywords.push_back("ResetDrawTransform");
    keywords.push_back("QueueRedraw");
    keywords.push_back("CLS");
    keywords.push_back("CreateImage");
    keywords.push_back("CreateTexture");
    keywords.push_back("ImageToTexture");
    keywords.push_back("SetImagePixel");
    keywords.push_back("GetImagePixel");
    keywords.push_back("FillImage");
    keywords.push_back("FillImageRect");
    keywords.push_back("BlitImage");
    keywords.push_back("DrawImageLine");
    keywords.push_back("DrawImageRect");
    keywords.push_back("DrawImageEllipse");
    keywords.push_back("DrawImageCircle");
    keywords.push_back("FloodFillImage");
    keywords.push_back("DrawImageText");
    keywords.push_back("UpdateTexture");
    keywords.push_back("ImageWidth");
    keywords.push_back("ImageHeight");
    keywords.push_back("TextureWidth");
    keywords.push_back("TextureHeight");
    keywords.push_back("LoadImage");
    keywords.push_back("SaveImage");
    keywords.push_back("GetTextureImage");
    keywords.push_back("LoadTexture");
    // VB6 compatibility additions (v4.2.0)
    keywords.push_back("Circle");
    keywords.push_back("Point");
    keywords.push_back("SavePicture");
    keywords.push_back("Error");
    keywords.push_back("Reset");
    keywords.push_back("IsMissing");
    keywords.push_back("Erl");
    keywords.push_back("LSet");
    keywords.push_back("RSet");
    keywords.push_back("ChrW");
    keywords.push_back("AscW");
    keywords.push_back("DateValue");
    keywords.push_back("TimeValue");
    keywords.push_back("StrConv");
    keywords.push_back("FormatNumber");
    keywords.push_back("FormatCurrency");
    keywords.push_back("FormatPercent");
    keywords.push_back("FileDateTime");
    keywords.push_back("TextWidth");
    keywords.push_back("TextHeight");
    keywords.push_back("CallByName");
    keywords.push_back("Eqv");
    keywords.push_back("Imp");
    // Financial Functions
    keywords.push_back("Pmt");
    keywords.push_back("FV");
    keywords.push_back("PV");
    keywords.push_back("NPV");
    keywords.push_back("IRR");
    keywords.push_back("Rate");
    keywords.push_back("NPER");
    keywords.push_back("SLN");
    keywords.push_back("SYD");
    keywords.push_back("DDB");
    keywords.push_back("IPmt");
    keywords.push_back("PPmt");
    keywords.push_back("MIRR");
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
    
    // 7. USER-DECLARED VARIABLES with types + CONST values
    // Scan the current script for Dim/Private/Public/Static and Const declarations
    {
        PackedStringArray code_lines = p_code.split("\n");
        // Track names we've already added to avoid duplicates
        PackedStringArray added_vars;
        
        for (int li = 0; li < code_lines.size(); li++) {
            String sline = code_lines[li].strip_edges();
            String sline_lower = sline.to_lower();
            
            // --- Const declarations: "Const NAME = value" or "Public Const ..." ---
            {
                int const_pos = -1;
                if (sline_lower.begins_with("const ")) const_pos = 6;
                else if (sline_lower.begins_with("public const ")) const_pos = 14;
                else if (sline_lower.begins_with("private const ")) const_pos = 15;
                
                if (const_pos >= 0) {
                    String rest = sline.substr(const_pos).strip_edges();
                    // Extract name
                    String cname = "";
                    int ci = 0;
                    while (ci < rest.length() && is_identifier_char(rest[ci])) {
                        cname += String::chr(rest[ci]);
                        ci++;
                    }
                    if (!cname.is_empty()) {
                        // Extract everything after name for display (type + value)
                        String after_name = rest.substr(ci).strip_edges();
                        // Remove comment
                        int cmt = after_name.find("'");
                        if (cmt >= 0) after_name = after_name.substr(0, cmt).strip_edges();
                        
                        String display_text = cname;
                        if (!after_name.is_empty()) {
                            display_text += " " + after_name;
                        }
                        display_text += "  (Const)";
                        
                        // Filter by prefix
                        if (last_word.is_empty() || cname.to_lower().begins_with(last_word.to_lower())) {
                            bool already = false;
                            for (int ai = 0; ai < added_vars.size(); ai++) {
                                if (added_vars[ai].nocasecmp_to(cname) == 0) { already = true; break; }
                            }
                            if (!already) {
                                Dictionary opt;
                                opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_CONSTANT;
                                opt["display"] = display_text;
                                opt["insert_text"] = cname;
                                opt["location"] = 0;
                                opt["font_color"] = Color(0.6, 0.9, 1.0, 1);
                                opt["icon"] = Variant();
                                opt["default_value"] = Variant();
                                options.push_back(opt);
                                added_vars.push_back(cname);
                            }
                        }
                    }
                    continue; // Done with this line
                }
            }
            
            // --- Variable declarations: Dim/Private/Public/Static x As Type ---
            {
                int dim_pos = -1;
                if (sline_lower.begins_with("dim ")) dim_pos = 4;
                else if (sline_lower.begins_with("private ") && !sline_lower.begins_with("private sub ") && !sline_lower.begins_with("private function ") && !sline_lower.begins_with("private const ")) dim_pos = 8;
                else if (sline_lower.begins_with("public ") && !sline_lower.begins_with("public sub ") && !sline_lower.begins_with("public function ") && !sline_lower.begins_with("public const ")) dim_pos = 7;
                else if (sline_lower.begins_with("static ")) dim_pos = 7;
                
                if (dim_pos < 0) continue;
                
                String rest = sline.substr(dim_pos).strip_edges();
                // Extract variable name
                String vname = "";
                int vi = 0;
                while (vi < rest.length() && is_identifier_char(rest[vi])) {
                    vname += String::chr(rest[vi]);
                    vi++;
                }
                if (vname.is_empty()) continue;
                
                // Extract type: look for "As TypeName"
                String vtype = "Variant";
                String after_var = rest.substr(vi).strip_edges();
                // Handle array parens: Dim arr(10) As Integer
                if (after_var.begins_with("(")) {
                    int close = after_var.find(")");
                    if (close >= 0) {
                        after_var = after_var.substr(close + 1).strip_edges();
                        vtype = "Array";
                    }
                }
                if (after_var.to_lower().begins_with("as ")) {
                    String type_part = after_var.substr(3).strip_edges();
                    // Skip "New" keyword
                    if (type_part.to_lower().begins_with("new ")) {
                        type_part = type_part.substr(4).strip_edges();
                    }
                    // Extract type name (may include * N for fixed-length strings)
                    String tname = "";
                    for (int ti = 0; ti < type_part.length(); ti++) {
                        char32_t tc = type_part[ti];
                        if (is_identifier_char(tc) || tc == '*' || tc == ' ') {
                            tname += String::chr(tc);
                        } else break;
                    }
                    tname = tname.strip_edges();
                    if (!tname.is_empty()) vtype = tname;
                }
                
                String display_text = vname + "  As " + vtype;
                
                // Filter by prefix
                if (last_word.is_empty() || vname.to_lower().begins_with(last_word.to_lower())) {
                    bool already = false;
                    for (int ai = 0; ai < added_vars.size(); ai++) {
                        if (added_vars[ai].nocasecmp_to(vname) == 0) { already = true; break; }
                    }
                    if (!already) {
                        Dictionary opt;
                        opt["kind"] = ScriptLanguageExtension::CODE_COMPLETION_KIND_VARIABLE;
                        opt["display"] = display_text;
                        opt["insert_text"] = vname;
                        opt["location"] = 0;
                        opt["font_color"] = Color(0.8, 1.0, 0.8, 1);
                        opt["icon"] = Variant();
                        opt["default_value"] = Variant();
                        options.push_back(opt);
                        added_vars.push_back(vname);
                    }
                }
            }
        }
    }
    
    result["options"] = options;
    result["force"] = false;
    result["call_hint"] = "";
    result["result"] = OK;  // Required by Godot API
    return result;
}

// Hover / lookup documentation table for VisualGasic keywords and built-in
// functions. Names are lowercase (VG is case-insensitive). Doc strings use
// Godot's BBCode subset rendered by EditorHelpBit: [b], [i], [code],
// [codeblock lang=vgbasic], [br], [color=...]. A bare \n between plain-text
// regions renders as a paragraph break (blank line).
struct VGBuiltinDoc {
    const char *name;
    const char *doc;
};

static const VGBuiltinDoc VG_BUILTIN_DOCS[] = {
    // ── String functions ──────────────────────────────────────────────────
    { "left",
      "[b]Syntax[/b]\nLeft(str, length)\n\n"
      "[b]Description[/b]\n"
      "Returns the leftmost [i]length[/i] characters of [i]str[/i]. "
      "If [i]length[/i] is 0, an empty string is returned. "
      "If [i]length[/i] exceeds the string length, the entire string is returned.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Left(\"Hello World\", 5)  ' s = \"Hello\"\n"
      "Print Left(\"ABCDE\", 3)        ' Prints \"ABC\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRight, Mid, Len, InStr\n\n[url=ref:left]📖 VG Language Reference[/url]" },

    { "right",
      "[b]Syntax[/b]\nRight(str, length)\n\n"
      "[b]Description[/b]\n"
      "Returns the rightmost [i]length[/i] characters of [i]str[/i]. "
      "If [i]length[/i] is 0, an empty string is returned. "
      "If [i]length[/i] exceeds the string length, the entire string is returned.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Right(\"Hello World\", 5)  ' s = \"World\"\n"
      "Print Right(\"ABCDE\", 2)        ' Prints \"DE\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLeft, Mid, Len, InStr\n\n[url=ref:right]📖 VG Language Reference[/url]" },

    { "mid",
      "[b]Syntax[/b]\nMid(str, start [, length])\n\n"
      "[b]Description[/b]\n"
      "Returns a substring of [i]str[/i] starting at [i]start[/i] (1-based). "
      "If [i]length[/i] is omitted, all characters to the end of the string are returned.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String = \"Hello World\"\n"
      "Print Mid(s, 7)      ' \"World\"\n"
      "Print Mid(s, 1, 5)   ' \"Hello\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLeft, Right, Len, InStr\n\n[url=ref:mid]📖 VG Language Reference[/url]" },

    { "len",
      "[b]Syntax[/b]\nLen(str)\n\n"
      "[b]Description[/b]\n"
      "Returns the number of characters in [i]str[/i]. Returns 0 for an empty string.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Integer\n"
      "n = Len(\"Hello\")      ' 5\n"
      "n = Len(\"\")           ' 0\n"
      "Print Len(\"VisualGasic\")  ' 11\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLeft, Right, Mid\n\n[url=ref:len]📖 VG Language Reference[/url]" },

    { "instr",
      "[b]Syntax[/b]\nInStr([start,] str, find)\n\n"
      "[b]Description[/b]\n"
      "Searches [i]str[/i] for the substring [i]find[/i] and returns its 1-based position. "
      "Returns 0 if not found. Optional [i]start[/i] specifies where to begin searching (default 1).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim pos As Integer\n"
      "pos = InStr(\"Hello World\", \"World\")  ' 7\n"
      "pos = InStr(\"Hello World\", \"xyz\")    ' 0\n"
      "pos = InStr(5, \"abcabc\", \"c\")        ' 6\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInStrRev, Left, Mid, Replace\n\n[url=ref:instr]📖 VG Language Reference[/url]" },

    { "instrrev",
      "[b]Syntax[/b]\nInStrRev(str, find [, start])\n\n"
      "[b]Description[/b]\n"
      "Searches [i]str[/i] from the end and returns the 1-based position of the last "
      "occurrence of [i]find[/i]. Returns 0 if not found.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim pos As Integer\n"
      "pos = InStrRev(\"abcabc\", \"c\")   ' 6\n"
      "pos = InStrRev(\"abcabc\", \"a\")   ' 4\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInStr, Left, Mid, Replace" },

    { "lcase",
      "[b]Syntax[/b]\nLCase(str)\n\n"
      "[b]Description[/b]\n"
      "Returns a copy of [i]str[/i] with all alphabetic characters converted to lowercase. "
      "Non-alphabetic characters are unchanged.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = LCase(\"Hello World\")  ' \"hello world\"\n"
      "s = LCase(\"ABCDE123\")     ' \"abcde123\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nUCase, Trim, Replace\n\n[url=ref:lcase]📖 VG Language Reference[/url]" },

    { "ucase",
      "[b]Syntax[/b]\nUCase(str)\n\n"
      "[b]Description[/b]\n"
      "Returns a copy of [i]str[/i] with all alphabetic characters converted to uppercase. "
      "Non-alphabetic characters are unchanged.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = UCase(\"Hello World\")  ' \"HELLO WORLD\"\n"
      "s = UCase(\"abcde123\")     ' \"ABCDE123\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLCase, Trim, Replace\n\n[url=ref:ucase]📖 VG Language Reference[/url]" },

    { "trim",
      "[b]Syntax[/b]\nTrim(str)\n\n"
      "[b]Description[/b]\n"
      "Removes all leading and trailing space characters from [i]str[/i]. "
      "Spaces within the string are not affected.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Trim(\"  Hello  \")    ' \"Hello\"\n"
      "s = Trim(\"  Hi There  \") ' \"Hi There\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLTrim, RTrim, Len\n\n[url=ref:trim]📖 VG Language Reference[/url]" },

    { "ltrim",
      "[b]Syntax[/b]\nLTrim(str)\n\n"
      "[b]Description[/b]\n"
      "Removes all leading (left-side) space characters from [i]str[/i]. "
      "Trailing spaces and interior spaces are not affected.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = LTrim(\"  Hello  \")  ' \"Hello  \"\n"
      "Print LTrim(\"   ABC\")    ' \"ABC\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRTrim, Trim, Len" },

    { "rtrim",
      "[b]Syntax[/b]\nRTrim(str)\n\n"
      "[b]Description[/b]\n"
      "Removes all trailing (right-side) space characters from [i]str[/i]. "
      "Leading spaces and interior spaces are not affected.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = RTrim(\"  Hello  \")  ' \"  Hello\"\n"
      "Print RTrim(\"ABC   \")    ' \"ABC\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLTrim, Trim, Len" },

    { "replace",
      "[b]Syntax[/b]\nReplace(str, find, replacement [, start [, count]])\n\n"
      "[b]Description[/b]\n"
      "Returns a copy of [i]str[/i] with every occurrence of [i]find[/i] replaced by "
      "[i]replacement[/i]. Optional [i]start[/i] (1-based) and maximum replacement [i]count[/i] "
      "can be specified.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Replace(\"Hello World\", \"World\", \"Earth\")  ' \"Hello Earth\"\n"
      "s = Replace(\"aabbcc\", \"b\", \"X\")               ' \"aaXXcc\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInStr, Left, Mid, Split\n\n[url=ref:replace]📖 VG Language Reference[/url]" },

    { "split",
      "[b]Syntax[/b]\nSplit(str [, delimiter [, limit]])\n\n"
      "[b]Description[/b]\n"
      "Splits [i]str[/i] into an array of substrings using [i]delimiter[/i] as the separator. "
      "If [i]delimiter[/i] is omitted, a space is used. "
      "Optional [i]limit[/i] restricts the number of substrings returned.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim parts() As String\n"
      "parts = Split(\"a,b,c\", \",\")  ' Array [\"a\",\"b\",\"c\"]\n"
      "For i = 0 To UBound(parts)\n"
      "    Print parts(i)\n"
      "Next\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nJoin, UBound, Replace, InStr\n\n[url=ref:split]📖 VG Language Reference[/url]" },

    { "stringformat",
      "[b]Syntax[/b]\nStringFormat(format, arg0 [, arg1, ...])\n\n"
      "[b]Description[/b]\n"
      "Returns a copy of [i]format[/i] with each [code]{0}[/code], [code]{1}[/code], ... "
      "placeholder replaced by the corresponding argument (converted to a string). "
      "A placeholder may be repeated more than once.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = StringFormat(\"{0} is {1} years old\", \"Alice\", 30)  ' \"Alice is 30 years old\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFormat, Join, Replace\n\n[url=ref:stringformat]📖 VG Language Reference[/url]" },

    { "join",
      "[b]Syntax[/b]\nJoin(array [, delimiter])\n\n"
      "[b]Description[/b]\n"
      "Joins all elements of an array into a single string, separated by [i]delimiter[/i]. "
      "If [i]delimiter[/i] is omitted, a space is used.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim parts(2) As String\n"
      "parts(0) = \"Hello\"\n"
      "parts(1) = \"World\"\n"
      "Dim s As String\n"
      "s = Join(parts, \", \")  ' \"Hello, World\"\n"
      "Print Join(parts, \" \")  ' \"Hello World\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSplit, UBound\n\n[url=ref:join]📖 VG Language Reference[/url]" },

    { "space",
      "[b]Syntax[/b]\nSpace(count)\n\n"
      "[b]Description[/b]\n"
      "Returns a string consisting of [i]count[/i] space characters. "
      "Useful for padding or aligning output.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = \"Name:\" & Space(5) & \"Value\"  ' \"Name:     Value\"\n"
      "Print Space(10) & \"Indented text\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLen, Trim, Chr" },

    { "strreverse",
      "[b]Syntax[/b]\nStrReverse(str)\n\n"
      "[b]Description[/b]\n"
      "Returns a copy of [i]str[/i] with its characters in reverse order.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = StrReverse(\"Hello\")    ' \"olleH\"\n"
      "s = StrReverse(\"12345\")    ' \"54321\"\n"
      "Print StrReverse(\"abcde\")  ' \"edcba\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLen, Mid, Left, Right" },

    { "chr",
      "[b]Syntax[/b]\nChr(code)\n\n"
      "[b]Description[/b]\n"
      "Returns the character corresponding to the given Unicode character code. "
      "[code]Chr(10)[/code] = line feed, [code]Chr(13)[/code] = carriage return, "
      "[code]Chr(9)[/code] = tab, [code]Chr(65)[/code] = 'A'.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Chr(65)                    ' \"A\"\n"
      "s = Chr(97)                    ' \"a\"\n"
      "Dim newline As String\n"
      "newline = Chr(13) & Chr(10)    ' Windows line ending\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAsc, Len, Mid" },

    { "asc",
      "[b]Syntax[/b]\nAsc(str)\n\n"
      "[b]Description[/b]\n"
      "Returns the Unicode character code of the first character of [i]str[/i]. "
      "Raises a runtime error if [i]str[/i] is empty.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim code As Integer\n"
      "code = Asc(\"A\")      ' 65\n"
      "code = Asc(\"a\")      ' 97\n"
      "code = Asc(\"Hello\")  ' 72  (code of 'H')\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nChr, Len, Mid" },

    { "str",
      "[b]Syntax[/b]\nStr(number)\n\n"
      "[b]Description[/b]\n"
      "Converts a numeric value to its string representation. "
      "For positive numbers, Str includes a leading space. "
      "To avoid the leading space, use CStr instead.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = Str(42)      ' \" 42\"  (note leading space)\n"
      "s = Str(-3.14)   ' \"-3.14\"\n"
      "s = CStr(42)     ' \"42\"   (no leading space)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCStr, Val, Format, CInt\n\n[url=ref:str]📖 VG Language Reference[/url]" },

    { "val",
      "[b]Syntax[/b]\nVal(str)\n\n"
      "[b]Description[/b]\n"
      "Converts the leading numeric part of [i]str[/i] to a number. "
      "Stops at the first character that cannot be part of a number. "
      "Returns 0 if [i]str[/i] does not begin with a numeric character.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Double\n"
      "n = Val(\"42\")          ' 42\n"
      "n = Val(\"3.14 extra\")  ' 3.14\n"
      "n = Val(\"hello\")       ' 0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nStr, CInt, CDbl, IsNumeric\n\n[url=ref:val]📖 VG Language Reference[/url]" },

    { "format",
      "[b]Syntax[/b]\nFormat(value, format)\n\n"
      "[b]Description[/b]\n"
      "Formats a numeric value according to a format string. "
      "Common codes: [code]0[/code] digit placeholder, [code]#[/code] optional digit, "
      "[code].[/code] decimal point, [code],[/code] thousands separator, "
      "[code]%[/code] percentage.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Format(3.14159, \"0.00\")    ' \"3.14\"\n"
      "Print Format(1234567, \"#,##0\")   ' \"1,234,567\"\n"
      "Print Format(0.5, \"0%\")          ' \"50%\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nStr, CStr, Val\n\n[url=ref:format]📖 VG Language Reference[/url]" },

    // ── Math functions ────────────────────────────────────────────────────
    { "abs",
      "[b]Syntax[/b]\nAbs(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the absolute (non-negative) value of a number. "
      "[code]Abs(-5)[/code] = 5, [code]Abs(5)[/code] = 5.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Abs(-10)    ' 10\n"
      "Print Abs(3.14)   ' 3.14\n"
      "Dim diff As Double\n"
      "diff = Abs(a - b)  ' Distance between a and b\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSgn, Sqr, Fix, Int\n\n[url=ref:abs]📖 VG Language Reference[/url]" },

    { "int",
      "[b]Syntax[/b]\nInt(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the largest integer less than or equal to [i]number[/i] (floor). "
      "For negative numbers, Int rounds away from zero: "
      "[code]Int(-2.9)[/code] = -3.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Int(3.7)   ' 3\n"
      "Print Int(-2.9)  ' -3\n"
      "Print Int(4.0)   ' 4\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFix, CInt, Round, Abs\n\n[url=ref:int]📖 VG Language Reference[/url]" },

    { "fix",
      "[b]Syntax[/b]\nFix(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the integer part of [i]number[/i], truncating toward zero. "
      "[code]Fix(-2.9)[/code] = -2 (unlike Int which gives -3).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Fix(3.7)   ' 3\n"
      "Print Fix(-2.9)  ' -2\n"
      "Print Fix(4.0)   ' 4\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInt, CInt, Round, Abs" },

    { "sgn",
      "[b]Syntax[/b]\nSgn(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the sign of a number: -1 if negative, 0 if zero, 1 if positive.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Sgn(-5)    ' -1\n"
      "Print Sgn(0)     ' 0\n"
      "Print Sgn(3.14)  ' 1\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAbs, Int, Fix" },

    { "sqr",
      "[b]Syntax[/b]\nSqr(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the square root of a non-negative number. "
      "Raises a runtime error if [i]number[/i] is negative.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Sqr(9)     ' 3\n"
      "Print Sqr(2.0)   ' 1.41421356...\n"
      "Print Sqr(0)     ' 0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAbs, Log, Exp, Round\n\n[url=ref:sqr]📖 VG Language Reference[/url]" },

    { "rnd",
      "[b]Syntax[/b]\nRnd()\n\n"
      "[b]Description[/b]\n"
      "Returns a pseudo-random Single in the range [0.0, 1.0). "
      "Use RandRange for integers or a specific range.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Double\n"
      "n = Rnd()               ' e.g. 0.7312...\n"
      "Dim die As Integer\n"
      "die = Int(Rnd() * 6) + 1  ' Random 1-6\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRandRange, Int\n\n[url=ref:rnd]📖 VG Language Reference[/url]" },

    { "round",
      "[b]Syntax[/b]\nRound(number [, digits])\n\n"
      "[b]Description[/b]\n"
      "Rounds [i]number[/i] to [i]digits[/i] decimal places using banker's rounding "
      "(round-half-to-even). If [i]digits[/i] is omitted, rounds to the nearest integer.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Round(3.456, 2)  ' 3.46\n"
      "Print Round(3.5)       ' 4\n"
      "Print Round(2.5)       ' 2   (banker's rounding)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInt, Fix, CInt, Format\n\n[url=ref:round]📖 VG Language Reference[/url]" },

    { "sin",
      "[b]Syntax[/b]\nSin(radians)\n\n"
      "[b]Description[/b]\n"
      "Returns the trigonometric sine of an angle in radians. "
      "To convert degrees to radians, multiply by PI/180.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Const PI As Double = 3.14159265358979\n"
      "Print Sin(PI / 2)              ' 1.0\n"
      "Print Sin(0)                   ' 0.0\n"
      "Dim s As Double\n"
      "s = Sin(45 * PI / 180)         ' Sin of 45 degrees\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCos, Tan, Atn, Exp\n\n[url=ref:sin]📖 VG Language Reference[/url]" },

    { "cos",
      "[b]Syntax[/b]\nCos(radians)\n\n"
      "[b]Description[/b]\n"
      "Returns the trigonometric cosine of an angle in radians. "
      "To convert degrees to radians, multiply by PI/180.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Const PI As Double = 3.14159265358979\n"
      "Print Cos(0)                   ' 1.0\n"
      "Print Cos(PI)                  ' -1.0\n"
      "Dim c As Double\n"
      "c = Cos(60 * PI / 180)         ' Cos of 60 degrees\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSin, Tan, Atn, Exp\n\n[url=ref:cos]📖 VG Language Reference[/url]" },

    { "tan",
      "[b]Syntax[/b]\nTan(radians)\n\n"
      "[b]Description[/b]\n"
      "Returns the trigonometric tangent of an angle in radians. "
      "Undefined at 90 degrees (PI/2 radians).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Const PI As Double = 3.14159265358979\n"
      "Print Tan(0)                    ' 0.0\n"
      "Print Tan(PI / 4)               ' 1.0\n"
      "Dim t As Double\n"
      "t = Tan(45 * PI / 180)          ' Tan of 45 degrees\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSin, Cos, Atn" },

    { "atn",
      "[b]Syntax[/b]\nAtn(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the arctangent of [i]number[/i] in radians (range -PI/2 to PI/2). "
      "The classic trick for computing PI is [code]4 * Atn(1)[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Const PI As Double = 4 * Atn(1)   ' Compute PI\n"
      "Dim angle As Double\n"
      "angle = Atn(1) * 180 / PI          ' 45 degrees\n"
      "Print Atn(0)                        ' 0.0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSin, Cos, Tan" },

    { "log",
      "[b]Syntax[/b]\nLog(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the natural logarithm (base e) of [i]number[/i]. "
      "[i]number[/i] must be greater than 0. "
      "Log base 10: [code]Log(x)/Log(10)[/code]. Log base 2: [code]Log(x)/Log(2)[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Log(1)              ' 0.0\n"
      "Print Log(Exp(1))         ' 1.0\n"
      "Dim log10 As Double\n"
      "log10 = Log(100) / Log(10)  ' 2.0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nExp, Sqr, Abs" },

    { "exp",
      "[b]Syntax[/b]\nExp(number)\n\n"
      "[b]Description[/b]\n"
      "Returns the mathematical constant e raised to the power of [i]number[/i]. "
      "[code]Exp(1)[/code] = 2.71828... (Euler's number). The inverse of Log.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Exp(0)    ' 1.0\n"
      "Print Exp(1)    ' 2.71828...\n"
      "Print Exp(2)    ' 7.38905...\n"
      "Dim e As Double\n"
      "e = Exp(1)      ' e itself\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLog, Sqr, Abs" },

    { "randrange",
      "[b]Syntax[/b]\nRandRange(min, max)\n\n"
      "[b]Description[/b]\n"
      "Returns a pseudo-random number in the range [min, max] (both inclusive for integers, "
      "or as a float interval). Uses the engine's random number generator.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Integer\n"
      "n = RandRange(1, 6)       ' Random 1 through 6 (die roll)\n"
      "Dim f As Double\n"
      "f = RandRange(0.0, 1.0)   ' Random float 0.0 to 1.0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRnd, Int, Abs\n\n[url=ref:randrange]📖 VG Language Reference[/url]" },

    { "lerp",
      "[b]Syntax[/b]\nLerp(a, b, t)\n\n"
      "[b]Description[/b]\n"
      "Returns a linear interpolation between [i]a[/i] and [i]b[/i] by factor [i]t[/i]. "
      "When t=0, returns a; when t=1, returns b; intermediate values return a point between them.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Lerp(0, 10, 0.5)   ' 5.0\n"
      "Print Lerp(0, 10, 0.25)  ' 2.5\n"
      "Print Lerp(10, 20, 1.0)  ' 20.0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nClamp, Abs, RandRange\n\n[url=ref:lerp]📖 VG Language Reference[/url]" },

    { "clamp",
      "[b]Syntax[/b]\nClamp(value, min, max)\n\n"
      "[b]Description[/b]\n"
      "Constrains [i]value[/i] to the range [min, max]. "
      "Returns [i]min[/i] if value < min, [i]max[/i] if value > max, "
      "otherwise returns [i]value[/i] unchanged.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print Clamp(5, 0, 10)    ' 5   (within range)\n"
      "Print Clamp(-3, 0, 10)   ' 0   (below min)\n"
      "Print Clamp(15, 0, 10)   ' 10  (above max)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLerp, Abs, Int\n\n[url=ref:clamp]📖 VG Language Reference[/url]" },

    // ── Array functions ───────────────────────────────────────────────────
    { "ubound",
      "[b]Syntax[/b]\nUBound(array [, dimension])\n\n"
      "[b]Description[/b]\n"
      "Returns the largest available subscript index for the specified dimension of an array. "
      "For a zero-based array of 5 elements, UBound returns 4. "
      "Use in For loops to iterate all elements safely.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim nums(4) As Integer  ' Indices 0 to 4\n"
      "For i = 0 To UBound(nums)\n"
      "    nums(i) = i * 2\n"
      "Next\n"
      "Print UBound(nums)  ' 4\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nLBound, ReDim, IsArray, Len\n\n[url=ref:ubound]📖 VG Language Reference[/url]" },

    { "lbound",
      "[b]Syntax[/b]\nLBound(array [, dimension])\n\n"
      "[b]Description[/b]\n"
      "Returns the smallest available subscript index for the specified dimension of an array. "
      "VisualGasic arrays are zero-based, so LBound typically returns 0.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim nums(9) As Integer   ' Indices 0 to 9\n"
      "Print LBound(nums)        ' 0\n"
      "For i = LBound(nums) To UBound(nums)\n"
      "    Print nums(i)\n"
      "Next\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nUBound, ReDim, IsArray\n\n[url=ref:lbound]📖 VG Language Reference[/url]" },

    { "array",
      "[b]Syntax[/b]\nArray(item1, item2, ...)\n\n"
      "[b]Description[/b]\n"
      "Creates and returns a new zero-based array containing the specified items. "
      "The type is inferred from the items passed.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim colors() As String\n"
      "colors = Array(\"Red\", \"Green\", \"Blue\")\n"
      "Print colors(0)            ' \"Red\"\n"
      "Print UBound(colors) + 1   ' 3 (element count)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nUBound, LBound, ReDim, IsArray\n\n[url=ref:array]📖 VG Language Reference[/url]" },

    { "isarray",
      "[b]Syntax[/b]\nIsArray(value)\n\n"
      "[b]Description[/b]\n"
      "Returns True if [i]value[/i] is an array, False otherwise. "
      "Useful for validating arguments before calling UBound or LBound.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim nums(3) As Integer\n"
      "Dim x As Integer = 5\n"
      "Print IsArray(nums)   ' True\n"
      "Print IsArray(x)      ' False\n"
      "Print IsArray(\"hi\")  ' False\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nUBound, LBound, Array, IsNumeric" },

    // ── Type conversion and checks ────────────────────────────────────────
    { "cint",
      "[b]Syntax[/b]\nCInt(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to an Integer (whole number). "
      "Rounds to the nearest integer using banker's rounding. "
      "Raises an overflow error if the value is outside the Integer range.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Integer\n"
      "n = CInt(3.7)    ' 4\n"
      "n = CInt(3.5)    ' 4   (rounds to even)\n"
      "n = CInt(\"42\")  ' 42\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCLng, CDbl, CStr, Int, Fix, Round\n\n[url=ref:cint]📖 VG Language Reference[/url]" },

    { "clng",
      "[b]Syntax[/b]\nCLng(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to a Long integer value. "
      "Similar to CInt but supports a wider numeric range for large integers.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Long\n"
      "n = CLng(3.7)        ' 4\n"
      "n = CLng(\"123456\")  ' 123456\n"
      "n = CLng(99.5)       ' 100\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCInt, CDbl, CStr, Int, Fix" },

    { "cdbl",
      "[b]Syntax[/b]\nCDbl(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to a Double-precision floating-point number. "
      "Preserves decimal precision.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim d As Double\n"
      "d = CDbl(\"3.14\")  ' 3.14\n"
      "d = CDbl(42)       ' 42.0\n"
      "d = CDbl(True)     ' 1.0\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCSng, CInt, CLng, CStr, Val" },

    { "csng",
      "[b]Syntax[/b]\nCSng(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to a Single-precision floating-point number. "
      "Less precise than Double but uses less memory.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As Single\n"
      "s = CSng(\"3.14\")   ' 3.14 (Single precision)\n"
      "s = CSng(42)        ' 42.0\n"
      "Dim d As Double = 3.14159265358979\n"
      "s = CSng(d)         ' Reduced precision\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCDbl, CInt, CLng, CStr" },

    { "cstr",
      "[b]Syntax[/b]\nCStr(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to a String. "
      "Numbers convert without a leading space (unlike Str). "
      "Booleans become \"True\" or \"False\".\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim s As String\n"
      "s = CStr(42)      ' \"42\"\n"
      "s = CStr(3.14)    ' \"3.14\"\n"
      "s = CStr(True)    ' \"True\"\n"
      "s = CStr(False)   ' \"False\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nStr, Val, CInt, CDbl, Format\n\n[url=ref:cstr]📖 VG Language Reference[/url]" },

    { "cbool",
      "[b]Syntax[/b]\nCBool(expr)\n\n"
      "[b]Description[/b]\n"
      "Converts an expression to a Boolean value. "
      "Zero (0) and empty string convert to False; all other values convert to True.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print CBool(0)       ' False\n"
      "Print CBool(1)       ' True\n"
      "Print CBool(-1)      ' True\n"
      "Print CBool(\"\")     ' False\n"
      "Print CBool(\"Yes\")  ' True\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nCInt, CStr, IsNumeric" },

    { "isnumeric",
      "[b]Syntax[/b]\nIsNumeric(expr)\n\n"
      "[b]Description[/b]\n"
      "Returns True if [i]expr[/i] can be evaluated as a number. "
      "Useful for validating user input before converting with Val or CInt.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print IsNumeric(42)        ' True\n"
      "Print IsNumeric(\"3.14\")   ' True\n"
      "Print IsNumeric(\"hello\")  ' False\n"
      "Print IsNumeric(\"\")       ' False\n"
      "Print IsNumeric(True)      ' True\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nVal, CInt, CDbl, IsNull, IsEmpty" },

    { "isnull",
      "[b]Syntax[/b]\nIsNull(expr)\n\n"
      "[b]Description[/b]\n"
      "Returns True if [i]expr[/i] evaluates to Null. "
      "Note: uninitialized variables are Empty, not Null. "
      "Null typically comes from database operations or an explicit Null assignment.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim v As Variant\n"
      "Print IsNull(v)     ' False  (v is Empty, not Null)\n"
      "v = Null\n"
      "Print IsNull(v)     ' True\n"
      "Print IsNull(\"\")   ' False\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIsEmpty, IsNumeric, IsObject, TypeName" },

    { "isempty",
      "[b]Syntax[/b]\nIsEmpty(expr)\n\n"
      "[b]Description[/b]\n"
      "Returns True if [i]expr[/i] has not been initialized (is in the Empty state). "
      "Variant variables start as Empty until they are assigned a value.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim v As Variant\n"
      "Print IsEmpty(v)    ' True  (not yet assigned)\n"
      "v = 0\n"
      "Print IsEmpty(v)    ' False (explicitly 0)\n"
      "v = \"\"\n"
      "Print IsEmpty(v)    ' False (explicitly empty string)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIsNull, IsNumeric, IsArray, TypeName" },

    { "isobject",
      "[b]Syntax[/b]\nIsObject(expr)\n\n"
      "[b]Description[/b]\n"
      "Returns True if [i]expr[/i] is an object reference (assigned with Set). "
      "Returns False for scalar values, arrays, or Nothing.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim btn As Object\n"
      "Set btn = GetNode(\"Button\")\n"
      "Print IsObject(btn)   ' True\n"
      "Set btn = Nothing\n"
      "Print IsObject(btn)   ' False\n"
      "Print IsObject(42)    ' False\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIsNull, IsEmpty, IsArray, TypeName, Set" },

    { "typename",
      "[b]Syntax[/b]\nTypeName(value)\n\n"
      "[b]Description[/b]\n"
      "Returns the name of the data type of [i]value[/i] as a string. "
      "Common results: \"Integer\", \"Double\", \"String\", \"Boolean\", "
      "\"Object\", \"Empty\", \"Null\".\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print TypeName(42)       ' \"Integer\"\n"
      "Print TypeName(3.14)     ' \"Double\"\n"
      "Print TypeName(\"Hi\")    ' \"String\"\n"
      "Print TypeName(True)     ' \"Boolean\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIsNumeric, IsNull, IsEmpty, IsObject, IsArray" },

    // ── Dialogs and console ───────────────────────────────────────────────
    { "msgbox",
      "[b]Syntax[/b]\nMsgBox(prompt [, buttons [, title]])\n\n"
      "[b]Description[/b]\n"
      "Displays a modal message box dialog and returns an integer indicating which button "
      "was clicked. [i]buttons[/i]: 0=OK only, 1=OK/Cancel, 2=Abort/Retry/Ignore, "
      "3=Yes/No/Cancel, 4=Yes/No, 5=Retry/Cancel. "
      "Return values: 1=OK, 2=Cancel, 3=Abort, 4=Retry, 5=Ignore, 6=Yes, 7=No.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "MsgBox \"Operation complete!\"\n"
      "Dim choice As Integer\n"
      "choice = MsgBox(\"Are you sure?\", 1, \"Confirm\")\n"
      "If choice = 1 Then\n"
      "    Call DoSomething()\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nInputBox, Print\n\n[url=ref:msgbox]📖 VG Language Reference[/url]" },

    { "inputbox",
      "[b]Syntax[/b]\nInputBox(prompt [, title [, default]])\n\n"
      "[b]Description[/b]\n"
      "Displays a dialog that prompts the user to enter text. "
      "Returns the string the user typed, or an empty string if cancelled. "
      "Optional [i]title[/i] sets the dialog title and [i]default[/i] pre-fills the input field.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim name As String\n"
      "name = InputBox(\"Enter your name:\", \"Name\", \"Player1\")\n"
      "If name <> \"\" Then\n"
      "    MsgBox \"Hello, \" & name & \"!\"\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nMsgBox, Print, Dim\n\n[url=ref:inputbox]📖 VG Language Reference[/url]" },

    { "print",
      "[b]Syntax[/b]\nPrint expr\nPrint expr1, expr2, ...\n\n"
      "[b]Description[/b]\n"
      "Outputs one or more values to the debug console. "
      "Multiple expressions can be separated by commas or semicolons. "
      "Use Print without arguments to output a blank line.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Print \"Hello, World!\"\n"
      "Print 42\n"
      "Print \"Score: \"; score\n"
      "Dim x As Integer = 10\n"
      "Print \"x = \"; x; \"  doubled = \"; x * 2\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nMsgBox, CStr, Format\n\n[url=ref:print]📖 VG Language Reference[/url]" },

    // ── Statement keywords ────────────────────────────────────────────────
    { "dim",
      "[b]Syntax[/b]\nDim variableName As DataType [= initialValue]\n"
      "Dim arr(size) As DataType\n\n"
      "[b]Description[/b]\n"
      "Declares a variable with an optional type and initial value. "
      "Variables declared with Dim are local to the Sub or Function they appear in. "
      "Use Public or Global for module-level variables.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim score As Integer = 0\n"
      "Dim playerName As String = \"Hero\"\n"
      "Dim items() As String\n"
      "Dim health As Single = 100.0\n"
      "Dim grid(9, 9) As Integer\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nPrivate, Public, Static, Const, ReDim\n\n[url=ref:dim]📖 VG Language Reference[/url]" },

    { "sub",
      "[b]Syntax[/b]\nSub name([parameters])\n"
      "    ' body\n"
      "End Sub\n\n"
      "[b]Description[/b]\n"
      "Defines a subroutine: a named block of code that performs an action but does "
      "not return a value. Invoke it with Call or by name alone. "
      "Parameters can be passed ByVal (copy) or ByRef (reference, the default).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub ShowGreeting(name As String)\n"
      "    MsgBox \"Hello, \" & name & \"!\"\n"
      "End Sub\n"
      "\n"
      "Sub _Ready()\n"
      "    Call ShowGreeting(\"World\")\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFunction, Call, Return, Dim\n\n[url=ref:sub]📖 VG Language Reference[/url]" },

    { "function",
      "[b]Syntax[/b]\nFunction name([parameters]) [As Type]\n"
      "    ' body\n"
      "    Return returnValue\n"
      "End Function\n\n"
      "[b]Description[/b]\n"
      "Defines a function: a named block of code that returns a value. "
      "Set the return value with Return or by assigning to the function name. "
      "The return type is declared with As.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Function Add(a As Integer, b As Integer) As Integer\n"
      "    Return a + b\n"
      "End Function\n"
      "\n"
      "Dim result As Integer\n"
      "result = Add(3, 4)  ' result = 7\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSub, Return, Dim\n\n[url=ref:function]📖 VG Language Reference[/url]" },

    { "if",
      "[b]Syntax[/b]\nIf condition Then\n"
      "    ' true branch\n"
      "[ElseIf condition Then\n"
      "    ' elseif branch]\n"
      "[Else\n"
      "    ' false branch]\n"
      "End If\n\n"
      "[b]Description[/b]\n"
      "Conditional execution. If [i]condition[/i] is True, the Then branch executes. "
      "ElseIf and Else branches are optional. "
      "[b]Note:[/b] single-line [code]If cond Then stmt[/code] terminates the block; "
      "ElseIf/Else cannot follow a single-line If.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If score > 100 Then\n"
      "    Print \"High score!\"\n"
      "ElseIf score > 50 Then\n"
      "    Print \"Good score\"\n"
      "Else\n"
      "    Print \"Keep trying\"\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSelect Case, While, Do\n\n[url=ref:if]📖 VG Language Reference[/url]" },

    { "for",
      "[b]Syntax[/b]\nFor counter = start To end [Step n]\n"
      "    ' body\n"
      "Next [counter]\n\n"
      "[b]Description[/b]\n"
      "Repeats a block of code for each value of [i]counter[/i] from [i]start[/i] to [i]end[/i]. "
      "Optional [i]Step[/i] controls the increment (default 1). "
      "Use a negative Step to count down.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "' Count up\n"
      "For i = 1 To 5\n"
      "    Print i\n"
      "Next\n"
      "\n"
      "' Count down by 2\n"
      "For i = 10 To 0 Step -2\n"
      "    Print i\n"
      "Next\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nWhile, Do, Exit For\n\n[url=ref:for-next-loop]📖 VG Language Reference[/url]" },

    { "while",
      "[b]Syntax[/b]\nWhile condition\n"
      "    ' body\n"
      "Wend\n\n"
      "[b]Description[/b]\n"
      "Repeats a block of code as long as [i]condition[/i] is True. "
      "The condition is tested before each iteration; if it is False on entry, "
      "the body never executes.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim i As Integer = 1\n"
      "While i <= 5\n"
      "    Print i\n"
      "    i = i + 1\n"
      "Wend\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDo, For, If\n\n[url=ref:while-wend-loop]📖 VG Language Reference[/url]" },

    { "do",
      "[b]Syntax[/b]\nDo [While/Until condition]\n"
      "    ' body\n"
      "    [Exit Do]\n"
      "Loop [While/Until condition]\n\n"
      "[b]Description[/b]\n"
      "Repeats a block of code. The condition can appear at the start (test-first) "
      "or at the end (test-last, always runs at least once). "
      "[code]Exit Do[/code] exits the loop immediately.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "' Test-first\n"
      "Do While i < 10\n"
      "    i = i + 1\n"
      "Loop\n"
      "\n"
      "' Test-last (runs at least once)\n"
      "Dim input As String\n"
      "Do\n"
      "    input = InputBox(\"Enter 0 to quit:\")\n"
      "Loop Until input = \"0\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nWhile, For, Exit Do\n\n[url=ref:do-loop]📖 VG Language Reference[/url]" },

    { "select",
      "[b]Syntax[/b]\nSelect Case expression\n"
      "    Case value1\n"
      "        ' ...\n"
      "    Case value2, value3\n"
      "        ' ...\n"
      "    Case Else\n"
      "        ' ...\n"
      "End Select\n\n"
      "[b]Description[/b]\n"
      "Branches execution based on the value of an expression. "
      "Each Case can specify one or more values (or ranges with Is). "
      "Case Else handles all unmatched values.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim day As Integer = 3\n"
      "Select Case day\n"
      "    Case 1\n"
      "        Print \"Monday\"\n"
      "    Case 2\n"
      "        Print \"Tuesday\"\n"
      "    Case 3, 4, 5\n"
      "        Print \"Midweek\"\n"
      "    Case Else\n"
      "        Print \"Weekend\"\n"
      "End Select\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIf, For, While\n\n[url=ref:screenheight-as-long]📖 VG Language Reference[/url]" },

    { "return",
      "[b]Syntax[/b]\nReturn [value]\n\n"
      "[b]Description[/b]\n"
      "Exits the current Sub or Function. "
      "In a Function, [code]Return value[/code] sets the return value and exits immediately. "
      "In a Sub, [code]Return[/code] (without a value) exits early.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Function IsPositive(n As Integer) As Boolean\n"
      "    If n > 0 Then\n"
      "        Return True\n"
      "    End If\n"
      "    Return False\n"
      "End Function\n"
      "\n"
      "Sub CheckAge(age As Integer)\n"
      "    If age < 0 Then Return  ' Early exit\n"
      "    Print \"Age: \" & age\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSub, Function, Exit\n\n[url=ref:return]📖 VG Language Reference[/url]" },

    { "call",
      "[b]Syntax[/b]\nCall subName([arguments])\n\n"
      "[b]Description[/b]\n"
      "Invokes a Sub or Function. The Call keyword is optional; you may call a Sub by name alone. "
      "When Call is used, parentheses around arguments are required.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub PrintLine(msg As String)\n"
      "    Print msg\n"
      "End Sub\n"
      "\n"
      "' These are equivalent:\n"
      "Call PrintLine(\"Hello\")\n"
      "PrintLine \"Hello\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSub, Function, Return\n\n[url=ref:call]📖 VG Language Reference[/url]" },

    { "set",
      "[b]Syntax[/b]\nSet objectVar = objectExpression\n"
      "Set objectVar = Nothing\n\n"
      "[b]Description[/b]\n"
      "Assigns an object reference to a variable. "
      "Use Set for all object assignments (not just =). "
      "[code]Set obj = Nothing[/code] releases the reference.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim btn As Object\n"
      "Set btn = GetNode(\"Button\")\n"
      "btn.Text = \"Click Me\"\n"
      "\n"
      "' Release the reference\n"
      "Set btn = Nothing\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nNew, Dim, IsObject, IsNull\n\n[url=ref:set]📖 VG Language Reference[/url]" },

    { "new",
      "[b]Syntax[/b]\nSet var = New ClassName\n"
      "Dim var As New ClassName\n\n"
      "[b]Description[/b]\n"
      "Creates a new instance of a class. "
      "Use with Set to assign the new object to a variable, "
      "or use [code]Dim var As New ClassName[/code] for automatic creation.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim p As Object\n"
      "Set p = New Process\n"
      "p.Start()\n"
      "\n"
      "Dim btn As New Button\n"
      "btn.Text = \"OK\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSet, Dim, Class, IsObject\n\n[url=ref:new]📖 VG Language Reference[/url]" },

    { "redim",
      "[b]Syntax[/b]\nReDim [Preserve] arrayName(newSize)\n\n"
      "[b]Description[/b]\n"
      "Resizes a dynamic array. Without Preserve, all existing data is lost. "
      "With Preserve, existing elements are kept (only the last dimension can be resized). "
      "Use ReDim to size an array declared with empty parentheses.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim items() As String\n"
      "ReDim items(9)           ' 10 elements (0-9)\n"
      "items(0) = \"first\"\n"
      "\n"
      "' Resize and keep existing data\n"
      "ReDim Preserve items(19)  ' Now 20 elements\n"
      "Print items(0)             ' Still \"first\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDim, UBound, LBound, IsArray\n\n[url=ref:redim]📖 VG Language Reference[/url]" },

    // ── Godot Node methods ──
    { "getnode",
      "[b]Syntax[/b]\n[code]GetNode(path As NodePath) As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the child node at the given NodePath relative to the current node. "
      "Raises an error at runtime if the node does not exist; use [code]GetNodeOrNull[/code] "
      "to avoid errors on optional nodes. "
      "Equivalent to Godot's [code]Node.get_node()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim lbl As Label = GetNode(\"HUD/ScoreLabel\")\n"
      "lbl.Text = \"Score: \" & CStr(score)\n"
      "\n"
      "Dim btn As Button = GetNode(\"/root/Main/StartButton\")\n"
      "btn.Disabled = True\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetNodeOrNull, FindChild, GetParent, GetChild, HasNode\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-node]Godot Docs ↗[/url]" },

    { "getnodeornull",
      "[b]Syntax[/b]\n[code]GetNodeOrNull(path As NodePath) As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the child node at the given NodePath, or [code]Nothing[/code] if it does not exist. "
      "Safer than [code]GetNode[/code] when a node might not be present. "
      "Equivalent to Godot's [code]Node.get_node_or_null()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim panel As Panel = GetNodeOrNull(\"HUD/DebugPanel\")\n"
      "If Not panel Is Nothing Then\n"
      "    panel.Visible = True\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetNode, HasNode, FindChild\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-node-or-null]Godot Docs ↗[/url]" },

    { "hasnode",
      "[b]Syntax[/b]\n[code]HasNode(path As NodePath) As Boolean[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns True if a node exists at the given NodePath relative to the current node. "
      "Use this to safely guard a [code]GetNode[/code] call. "
      "Equivalent to Godot's [code]Node.has_node()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If HasNode(\"HUD/MinimapPanel\") Then\n"
      "    Dim mm As Control = GetNode(\"HUD/MinimapPanel\")\n"
      "    mm.Visible = showMinimap\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetNode, GetNodeOrNull, FindChild\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-has-node]Godot Docs ↗[/url]" },

    { "addchild",
      "[b]Syntax[/b]\n[code]AddChild(node As Node [, forceReadableName As Boolean])[/code]\n\n"
      "[b]Description[/b]\n"
      "Adds [code]node[/code] as a child of the current node. "
      "The child is appended after all existing children. "
      "Pass [code]True[/code] for [code]forceReadableName[/code] to keep the node's original name "
      "instead of a numbered suffix. "
      "Equivalent to Godot's [code]Node.add_child()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim spr As Sprite2D = Sprite2D.new()\n"
      "spr.Texture = preload(\"res://icon.png\")\n"
      "AddChild spr\n"
      "\n"
      "' AddChild as a function call:\n"
      "AddChild(bullet)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRemoveChild, QueueFree, GetChildren, GetChildCount\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add-child]Godot Docs ↗[/url]" },

    { "removechild",
      "[b]Syntax[/b]\n[code]RemoveChild(node As Node)[/code]\n\n"
      "[b]Description[/b]\n"
      "Removes [code]node[/code] from this node's children without freeing it from memory. "
      "The removed node can be re-added elsewhere in the scene tree. "
      "To remove and free a node in one step use [code]QueueFree[/code] on the child. "
      "Equivalent to Godot's [code]Node.remove_child()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim old As Node = GetNode(\"TempEffect\")\n"
      "RemoveChild(old)\n"
      "old.QueueFree()\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAddChild, QueueFree, GetChildren\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-remove-child]Godot Docs ↗[/url]" },

    { "getparent",
      "[b]Syntax[/b]\n[code]GetParent() As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the parent node of the current node, or [code]Nothing[/code] if this node has no parent "
      "(e.g. it is the root). "
      "Equivalent to Godot's [code]Node.get_parent()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim p As Node = GetParent()\n"
      "If Not p Is Nothing Then\n"
      "    Print \"Parent: \" & p.Name\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetOwner, GetNode, GetChildren\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-parent]Godot Docs ↗[/url]" },

    { "getchildren",
      "[b]Syntax[/b]\n[code]GetChildren() As Array[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns an Array containing all immediate child nodes of the current node. "
      "The array order matches the child order in the scene tree. "
      "Equivalent to Godot's [code]Node.get_children()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim kids As Array = GetChildren()\n"
      "For Each child In kids\n"
      "    Print child.Name\n"
      "Next\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetChild, GetChildCount, AddChild, RemoveChild\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-children]Godot Docs ↗[/url]" },

    { "getchildcount",
      "[b]Syntax[/b]\n[code]GetChildCount() As Integer[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the number of immediate children of the current node. "
      "Equivalent to Godot's [code]Node.get_child_count()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim n As Integer = GetChildCount()\n"
      "Print \"Children: \" & CStr(n)\n"
      "\n"
      "Dim i As Integer\n"
      "For i = 0 To GetChildCount() - 1\n"
      "    Print GetChild(i).Name\n"
      "Next i\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetChild, GetChildren, AddChild\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-child-count]Godot Docs ↗[/url]" },

    { "getchild",
      "[b]Syntax[/b]\n[code]GetChild(index As Integer) As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the child node at zero-based [code]index[/code]. "
      "Raises an error if [code]index[/code] is out of range; check [code]GetChildCount()[/code] first. "
      "Equivalent to Godot's [code]Node.get_child()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim first As Node = GetChild(0)\n"
      "Dim last  As Node = GetChild(GetChildCount() - 1)\n"
      "Print first.Name & \" -> \" & last.Name\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetChildren, GetChildCount, GetNode\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-child]Godot Docs ↗[/url]" },

    { "findchild",
      "[b]Syntax[/b]\n[code]FindChild(pattern As String [, recursive As Boolean [, owned As Boolean]]) As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Searches the subtree for the first node whose name matches [code]pattern[/code] (supports [code]*[/code] wildcards). "
      "Returns [code]Nothing[/code] if no match is found. "
      "[code]recursive[/code] defaults to True; [code]owned[/code] defaults to True (restricts to nodes owned by the scene root). "
      "Equivalent to Godot's [code]Node.find_child()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim hp As ProgressBar = FindChild(\"HPBar\")\n"
      "If Not hp Is Nothing Then hp.Value = playerHealth\n"
      "\n"
      "' Wildcard search:\n"
      "Dim btn As Button = FindChild(\"btn_*\")\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetNode, GetNodeOrNull, HasNode\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-find-child]Godot Docs ↗[/url]" },

    { "getowner",
      "[b]Syntax[/b]\n[code]GetOwner() As Node[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the scene owner of this node — the root node of the scene it was saved in. "
      "Returns [code]Nothing[/code] for nodes created at runtime that have no owner. "
      "Equivalent to Godot's [code]Node.get_owner()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim owner As Node = GetOwner()\n"
      "If Not owner Is Nothing Then\n"
      "    Print \"Scene root: \" & owner.Name\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetParent, GetTree, GetNode\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-owner]Godot Docs ↗[/url]" },

    { "gettree",
      "[b]Syntax[/b]\n[code]GetTree() As SceneTree[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns the [code]SceneTree[/code] the current node belongs to. "
      "From the SceneTree you can call [code].Quit()[/code], access [code].Root[/code], "
      "change scenes, and manage groups. "
      "Equivalent to Godot's [code]Node.get_tree()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "' Quit the application:\n"
      "GetTree().Quit()\n"
      "\n"
      "' Change scene:\n"
      "GetTree().ChangeSceneToFile(\"res://scenes/GameOver.tscn\")\n"
      "\n"
      "' Get all nodes in a group:\n"
      "Dim enemies As Array = GetTree().GetNodesInGroup(\"enemies\")\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetParent, GetOwner, IsInsideTree\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-tree]Godot Docs ↗[/url]" },

    { "isinsidetree",
      "[b]Syntax[/b]\n[code]IsInsideTree() As Boolean[/code]\n\n"
      "[b]Description[/b]\n"
      "Returns True if the node is currently inside the active SceneTree. "
      "Always check this before calling [code]GetTree()[/code] from a node that may not yet be added to the scene. "
      "Equivalent to Godot's [code]Node.is_inside_tree()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If IsInsideTree() Then\n"
      "    GetTree().CallGroup(\"enemies\", \"Pause\")\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetTree, GetParent\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-is-inside-tree]Godot Docs ↗[/url]" },

    { "queuefree",
      "[b]Syntax[/b]\n[code]QueueFree()[/code]\n\n"
      "[b]Description[/b]\n"
      "Marks the node for deletion at the end of the current frame. "
      "The node is removed from the scene tree and freed from memory safely, "
      "even if called from within the node's own callbacks. "
      "Equivalent to Godot's [code]Node.queue_free()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "' Destroy this node after a hit:\n"
      "Sub OnHit()\n"
      "    PlayEffect \"explosion\"\n"
      "    QueueFree()\n"
      "End Sub\n"
      "\n"
      "' Destroy a child:\n"
      "GetNode(\"Bullet\").QueueFree()\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRemoveChild, AddChild, IsInsideTree\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-queue-free]Godot Docs ↗[/url]" },

    { "emitsignal",
      "[b]Syntax[/b]\n[code]EmitSignal(signalName As String [, args...])[/code]\n\n"
      "[b]Description[/b]\n"
      "Emits the named signal on the current node, passing optional arguments to all connected callbacks. "
      "The signal must be declared with [code]Event[/code] or exist as a built-in Godot signal on the node type. "
      "Equivalent to Godot's [code]Object.emit_signal()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Event PlayerDied()\n"
      "Event ScoreChanged(newScore As Integer)\n"
      "\n"
      "Sub TakeDamage(amount As Integer)\n"
      "    health = health - amount\n"
      "    If health <= 0 Then\n"
      "        EmitSignal(\"PlayerDied\")\n"
      "    End If\n"
      "    EmitSignal(\"ScoreChanged\", score)\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nConnect, Event\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-emit-signal]Godot Docs ↗[/url]" },

    { "connect",
      "[b]Syntax[/b]\n[code]Connect(sourceNode As Node, signalName As String, handlerMethod As String) As Integer[/code]\n\n"
      "[b]Description[/b]\n"
      "Connects [code]signalName[/code] on [code]sourceNode[/code] to a method named [code]handlerMethod[/code] "
      "on the current node. Returns [code]0[/code] (OK) on success or a non-zero error code. "
      "For connecting signals from other objects to this node's methods. "
      "Equivalent to Godot's [code]Object.connect()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim timer As Timer = GetNode(\"CountdownTimer\")\n"
      "Dim err As Integer = Connect(timer, \"timeout\", \"OnTimerDone\")\n"
      "If err <> 0 Then Print \"Connect failed: \" & CStr(err)\n"
      "\n"
      "Sub OnTimerDone()\n"
      "    Print \"Time's up!\"\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nEmitSignal, Event, Disconnect\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-connect]Godot Docs ↗[/url]" },

    { "disconnect",
      "[b]Syntax[/b]\n[code]Disconnect(sourceNode As Node, signalName As String, handlerMethod As String)[/code]\n\n"
      "[b]Description[/b]\n"
      "Disconnects a previously connected signal. "
      "Has no effect if the connection does not exist. "
      "Equivalent to Godot's [code]Object.disconnect()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Disconnect(timer, \"timeout\", \"OnTimerDone\")\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nConnect, EmitSignal\n\n"
      "[url=https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-disconnect]Godot Docs ↗[/url]" },

    // ── Group 1: Logical / Bitwise Operators ──────────────────────────────────
    { "and",
      "[b]Syntax[/b]\nresult = expression1 [b]And[/b] expression2\n\n"
      "[b]Description[/b]\n"
      "Boolean AND. Returns True only if [i]both[/i] operands are True. "
      "Also performs bitwise AND on integer operands.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If x > 0 And x < 100 Then Print \"In range\"\n"
      "Dim flags As Integer = 12 And 10  ' Result: 8\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nOr, Not, Xor\n\n[url=ref:and]📖 VG Language Reference[/url]" },

    { "or",
      "[b]Syntax[/b]\nresult = expression1 [b]Or[/b] expression2\n\n"
      "[b]Description[/b]\n"
      "Boolean OR. Returns True if [i]either[/i] operand is True. "
      "Also performs bitwise OR on integer operands.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If name = \"Admin\" Or level >= 10 Then\n"
      "    Print \"Access granted\"\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAnd, Not, Xor\n\n[url=ref:or]📖 VG Language Reference[/url]" },

    { "not",
      "[b]Syntax[/b]\nresult = [b]Not[/b] expression\n\n"
      "[b]Description[/b]\n"
      "Boolean NOT. Negates a Boolean: True→False, False→True. "
      "Also performs bitwise complement on integer operands.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If Not IsEmpty(list) Then Print \"Has items\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAnd, Or\n\n[url=ref:not]📖 VG Language Reference[/url]" },

    { "xor",
      "[b]Syntax[/b]\nresult = expression1 [b]Xor[/b] expression2\n\n"
      "[b]Description[/b]\n"
      "Exclusive OR. Returns True if [i]exactly one[/i] operand is True (not both). "
      "Also performs bitwise XOR on integers.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If hasSword Xor hasShield Then Print \"One item only\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAnd, Or, Not\n\n[url=ref:xor]📖 VG Language Reference[/url]" },

    { "is",
      "[b]Syntax[/b]\nresult = [b]TypeOf[/b] object [b]Is[/b] TypeName\n\n"
      "[b]Description[/b]\n"
      "Type-test operator. Returns True if [i]object[/i] is an instance of [i]TypeName[/i]. "
      "Checks the full inheritance chain.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If TypeOf node Is Sprite2D Then\n"
      "    Print \"It is a sprite\"\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIsNot, TypeOf, TypeName, IsObject\n\n[url=ref:and]📖 VG Language Reference[/url]" },

    { "isnot",
      "[b]Syntax[/b]\nresult = object [b]IsNot[/b] Nothing\n\n"
      "[b]Description[/b]\n"
      "Negative type or null test. Returns True if the object is [i]not[/i] the given value or type. "
      "Equivalent to [code]Not (TypeOf obj Is T)[/code] or [code]Not (obj Is Nothing)[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If node IsNot Nothing Then node.QueueFree()\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIs, TypeOf, Nothing\n\n[url=ref:and]📖 VG Language Reference[/url]" },

    { "eqv",
      "[b]Syntax[/b]\nresult = expression1 [b]Eqv[/b] expression2\n\n"
      "[b]Description[/b]\n"
      "Logical equivalence (VB6 compatibility). Returns True if both operands have the same Boolean value. "
      "Equivalent to [code]Not (a Xor b)[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Dim same As Boolean = (a > 0) Eqv (b > 0)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nXor, And, Or\n\n[url=ref:and]📖 VG Language Reference[/url]" },

    { "imp",
      "[b]Syntax[/b]\nresult = expression1 [b]Imp[/b] expression2\n\n"
      "[b]Description[/b]\n"
      "Logical implication (VB6 compatibility). Returns False only when the first expression is True and the second is False. "
      "Rarely needed; prefer [code]Not a Or b[/code] for clarity.\n\n"
      "[b]See Also[/b]\nAnd, Or, Not, Eqv\n\n[url=ref:and]📖 VG Language Reference[/url]" },

    // ── Group 2: Secondary Control-Flow Keywords ──────────────────────────────
    { "else",
      "[b]Syntax[/b]\n[code]If ... Then ... [b]Else[/b] ... End If[/code]\n\n"
      "[b]Description[/b]\n"
      "Introduces the false branch of an [code]If[/code] block. "
      "Executes when the condition is False and no earlier [code]ElseIf[/code] matched.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "If hp > 0 Then\n"
      "    Print \"Alive\"\n"
      "Else\n"
      "    Print \"Dead\"\n"
      "End If\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nIf, ElseIf, Then, End If\n\n[url=ref:else]📖 VG Language Reference[/url]" },

    { "end",
      "[b]Syntax[/b]\n[b]End[/b] Sub | Function | If | Class | Select | With | Property\n\n"
      "[b]Description[/b]\n"
      "Closes a block. Paired with its opener:\n"
      "[code]End Sub[/code], [code]End Function[/code], [code]End If[/code], [code]End Class[/code], "
      "[code]End Select[/code], [code]End With[/code], [code]End Property[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub Greet(name As String)\n"
      "    If name <> \"\" Then\n"
      "        Print \"Hello, \" & name\n"
      "    End If\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSub, Function, If, Select Case\n\n[url=ref:end]📖 VG Language Reference[/url]" },

    { "next",
      "[b]Syntax[/b]\n[b]Next[/b] [i]counter[/i]\n\n"
      "[b]Description[/b]\n"
      "Closes a [code]For[/code] loop. Increments the counter and re-evaluates the range. "
      "The variable name after [code]Next[/code] is optional but recommended.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "For i = 1 To 10\n"
      "    Print i\n"
      "Next i\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFor, Step, To\n\n[url=ref:next]📖 VG Language Reference[/url]" },

    { "wend",
      "[b]Syntax[/b]\n[b]Wend[/b]\n\n"
      "[b]Description[/b]\n"
      "Closes a [code]While[/code] loop (VB6 style). Control returns to the [code]While[/code] condition. "
      "[code]End While[/code] is also accepted in modern VG style.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "While hp > 0\n"
      "    hp -= damage\n"
      "Wend\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nWhile, Do, Loop\n\n[url=ref:wend]📖 VG Language Reference[/url]" },

    { "loop",
      "[b]Syntax[/b]\n[b]Loop[/b] [While|Until [i]condition[/i]]\n\n"
      "[b]Description[/b]\n"
      "Closes a [code]Do[/code] loop. Optionally rechecks a condition before repeating. "
      "[code]Loop While cond[/code] continues while true; [code]Loop Until cond[/code] continues until true.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Do\n"
      "    Dim n As Integer = Int(Rnd() * 6) + 1\n"
      "    Print n\n"
      "Loop Until n = 6\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDo, While, Wend, Exit\n\n[url=ref:loop]📖 VG Language Reference[/url]" },

    { "then",
      "[b]Syntax[/b]\nIf [i]condition[/i] [b]Then[/b]\n\n"
      "[b]Description[/b]\n"
      "Separates the condition from the body of an [code]If[/code] statement. "
      "Required for multi-line blocks. Also valid in single-line form: [code]If x > 0 Then Print x[/code].\n\n"
      "[b]See Also[/b]\nIf, Else, ElseIf, End If\n\n[url=ref:then]📖 VG Language Reference[/url]" },

    { "exit",
      "[b]Syntax[/b]\n[b]Exit[/b] Sub | Function | For | While | Do | Select\n\n"
      "[b]Description[/b]\n"
      "Immediately exits the enclosing block. "
      "[code]Exit Sub[/code] / [code]Exit Function[/code] returns from the current procedure. "
      "[code]Exit For[/code], [code]Exit While[/code], [code]Exit Do[/code] break out of the enclosing loop.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "For i = 1 To 100\n"
      "    If arr(i) = target Then Exit For\n"
      "Next i\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nReturn, Do, For, While\n\n[url=ref:exit]📖 VG Language Reference[/url]" },

    { "step",
      "[b]Syntax[/b]\nFor i = [i]start[/i] To [i]end[/i] [b]Step[/b] [i]increment[/i]\n\n"
      "[b]Description[/b]\n"
      "Optional [code]For[/code] modifier. Sets the amount added to the counter each iteration. "
      "Defaults to 1. Use a negative value to count down.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "For i = 10 To 1 Step -1\n"
      "    Print i\n"
      "Next i\n"
      "For x = 0.0 To 1.0 Step 0.25\n"
      "    Print x\n"
      "Next x\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFor, To, Next\n\n[url=ref:for]📖 VG Language Reference[/url]" },

    { "to",
      "[b]Syntax[/b]\nFor i = [i]start[/i] [b]To[/b] [i]end[/i]\n\n"
      "[b]Description[/b]\n"
      "Defines the upper bound of a [code]For[/code] loop range. "
      "The loop variable counts from [i]start[/i] to [i]end[/i] inclusive.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "For i = 1 To UBound(arr)\n"
      "    Print arr(i)\n"
      "Next i\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFor, Step, Next\n\n[url=ref:for]📖 VG Language Reference[/url]" },

    // ── Group 3: Async / Parallel ─────────────────────────────────────────────
    { "async",
      "[b]Syntax[/b]\n[b]Async[/b] Sub | Function ...\n\n"
      "[b]Description[/b]\n"
      "Declares a Sub or Function as asynchronous. "
      "Inside an [code]Async[/code] procedure you can use [code]Await[/code] to suspend execution until a task completes without blocking the game loop.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Async Sub LoadLevel(path As String)\n"
      "    Await Task.Delay(500)\n"
      "    ChangeScene(path)\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAwait, Task\n\n[url=ref:async]📖 VG Language Reference[/url]" },

    { "await",
      "[b]Syntax[/b]\n[b]Await[/b] taskExpression\n\n"
      "[b]Description[/b]\n"
      "Suspends the current [code]Async[/code] procedure until the awaited task completes. "
      "The Godot main loop keeps running while waiting — unlike [code]Sleep()[/code] which blocks it.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Async Sub FetchData()\n"
      "    Dim data As String = Await LoadFileAsync(\"data.json\")\n"
      "    Print data\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAsync, Task\n\n[url=ref:await]📖 VG Language Reference[/url]" },

    { "task",
      "[b]Syntax[/b]\nDim t As [b]Task[/b] = Task.Run(...)\n\n"
      "[b]Description[/b]\n"
      "Represents an asynchronous operation. "
      "[code]Task.Run(fn)[/code] starts work on a background thread. "
      "[code]Task.Delay(ms)[/code] waits asynchronously. "
      "Use [code]Await[/code] to wait for completion inside an [code]Async[/code] procedure.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Async Sub Crunch()\n"
      "    Dim t As Task = Task.Run(Function() HeavyCompute())\n"
      "    Await t\n"
      "    Print \"Done\"\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAsync, Await\n\n[url=ref:async]📖 VG Language Reference[/url]" },

    { "parallel",
      "[b]Syntax[/b]\n[b]Parallel[/b] For i = [i]start[/i] To [i]end[/i]\n\n"
      "[b]Description[/b]\n"
      "Runs a [code]For[/code] loop across multiple threads simultaneously. "
      "Each iteration is independent — do not share mutable state without synchronisation.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Parallel For i = 0 To UBound(data)\n"
      "    results(i) = Process(data(i))\n"
      "Next i\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nFor, Async, Await, Task\n\n[url=ref:async]📖 VG Language Reference[/url]" },

    { "suspend",
      "[b]Syntax[/b]\n[b]Suspend[/b]\n\n"
      "[b]Description[/b]\n"
      "Pauses execution of the current Causal Chain [code]Section[/code] block. "
      "Used inside [code]Whenever[/code] / [code]Section[/code] state-machine constructs to halt the current step.\n\n"
      "[b]See Also[/b]\nAsync, Await, Section, Whenever\n\n[url=ref:async]📖 VG Language Reference[/url]" },

    // ── Group 4: File I/O ─────────────────────────────────────────────────────
    { "open",
      "[b]Syntax[/b]\n[b]Open[/b] path [b]For[/b] mode [b]As[/b] #fileNum\n\n"
      "[b]Description[/b]\n"
      "Opens a file for reading or writing. "
      "[i]mode[/i]: [code]Input[/code] (read), [code]Output[/code] (write/create), [code]Append[/code] (write to end). "
      "[i]fileNum[/i] is an integer handle used in subsequent [code]Print #[/code], [code]Line Input #[/code], and [code]Close[/code] statements.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Open \"scores.txt\" For Output As #1\n"
      "Print #1, \"Player1: 1000\"\n"
      "Close #1\n"
      "\n"
      "Open \"scores.txt\" For Input As #2\n"
      "Dim line As String\n"
      "Line Input #2, line\n"
      "Close #2\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nClose, Print, Input, Append, Reset\n\n[url=ref:open]📖 VG Language Reference[/url]" },

    { "close",
      "[b]Syntax[/b]\n[b]Close[/b] #fileNum\n\n"
      "[b]Description[/b]\n"
      "Closes an open file and flushes any buffered writes. "
      "Always close files when done. Omitting [i]fileNum[/i] closes all open files (same as [code]Reset[/code]).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Open \"log.txt\" For Output As #1\n"
      "Print #1, \"Entry\"\n"
      "Close #1\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nOpen, Reset, Print\n\n[url=ref:close]📖 VG Language Reference[/url]" },

    { "append",
      "[b]Syntax[/b]\nOpen path [b]For Append[/b] As #fileNum\n\n"
      "[b]Description[/b]\n"
      "File-open mode that writes new content to the [i]end[/i] of an existing file without erasing it. "
      "If the file does not exist it is created.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Open \"log.txt\" For Append As #1\n"
      "Print #1, Now() & \" - Game started\"\n"
      "Close #1\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nOpen, Close, Output\n\n[url=ref:open]📖 VG Language Reference[/url]" },

    { "mkdir",
      "[b]Syntax[/b]\n[b]MkDir[/b] path\n\n"
      "[b]Description[/b]\n"
      "Creates a new directory at [i]path[/i]. The parent directory must already exist. "
      "Raises a runtime error if the directory already exists.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "MkDir \"user://saves\"\n"
      "Open \"user://saves/slot1.dat\" For Output As #1\n"
      "Close #1\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nOpen, Close\n\n[url=ref:open]📖 VG Language Reference[/url]" },

    { "reset",
      "[b]Syntax[/b]\n[b]Reset[/b]\n\n"
      "[b]Description[/b]\n"
      "Closes all currently open files and flushes their buffers. "
      "Equivalent to calling [code]Close[/code] with no arguments.\n\n"
      "[b]See Also[/b]\nClose, Open\n\n[url=ref:open]📖 VG Language Reference[/url]" },

    { "shell",
      "[b]Syntax[/b]\n[b]Shell[/b](command As String) As Integer\n\n"
      "[b]Description[/b]\n"
      "Executes an OS shell command and returns the process ID. "
      "The VG script does [i]not[/i] wait for the subprocess — it runs asynchronously in the background.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Shell \"open https://example.com\"\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nSleep, Open\n\n[url=ref:open]📖 VG Language Reference[/url]" },

    { "sleep",
      "[b]Syntax[/b]\n[b]Sleep[/b](milliseconds As Integer)\n\n"
      "[b]Description[/b]\n"
      "Pauses execution for [i]milliseconds[/i]. "
      "[b]Warning:[/b] blocks the Godot main thread and freezes the game. "
      "Prefer [code]Await Task.Delay(ms)[/code] inside an [code]Async Sub[/code] for non-blocking waits.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "' Non-blocking (preferred):\n"
      "Async Sub WaitAndFire()\n"
      "    Await Task.Delay(1000)\n"
      "    FireProjectile()\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nAsync, Await, Task\n\n[url=ref:async]📖 VG Language Reference[/url]" },

    // ── Group 5: Drawing ──────────────────────────────────────────────────────
    { "drawline",
      "[b]Syntax[/b]\n[b]DrawLine[/b](x1, y1, x2, y2, color[, width])\n\n"
      "[b]Description[/b]\n"
      "Draws a line from (x1,y1) to (x2,y2). Wraps Godot's [code]draw_line()[/code]. "
      "Call inside [code]_draw()[/code]. [i]width[/i] defaults to 1.0.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    DrawLine(0, 0, 100, 100, Color(1,0,0), 2.0)\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawRect, DrawCircle, DrawArc, QueueRedraw\n\n[url=ref:drawline]📖 VG Language Reference[/url]" },

    { "drawcircle",
      "[b]Syntax[/b]\n[b]DrawCircle[/b](x, y, radius, color)\n\n"
      "[b]Description[/b]\n"
      "Draws a filled circle centred at (x,y). Wraps Godot's [code]draw_circle()[/code]. "
      "Call inside [code]_draw()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    DrawCircle(200, 150, 50, Color(0,1,0))\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawLine, DrawRect, DrawArc\n\n[url=ref:drawcircle]📖 VG Language Reference[/url]" },

    { "drawrect",
      "[b]Syntax[/b]\n[b]DrawRect[/b](x, y, width, height, color[, filled])\n\n"
      "[b]Description[/b]\n"
      "Draws a rectangle. [i]filled[/i] is True (default) for solid fill, False for outline only. "
      "Wraps Godot's [code]draw_rect()[/code]. Call inside [code]_draw()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    DrawRect(10, 10, 200, 100, Color(0,0,1))         ' Filled\n"
      "    DrawRect(10, 10, 200, 100, Color(1,1,0), False)  ' Outline\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawLine, DrawCircle, DrawArc\n\n[url=ref:drawrect]📖 VG Language Reference[/url]" },

    { "drawstring",
      "[b]Syntax[/b]\n[b]DrawString[/b](text, x, y, color[, fontSize])\n\n"
      "[b]Description[/b]\n"
      "Draws text at (x,y) using the default font. Wraps Godot's [code]draw_string()[/code]. "
      "Call inside [code]_draw()[/code]. [code]DrawText[/code] is an alias.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    DrawString(\"Score: \" & score, 10, 30, Color(1,1,1), 20)\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawLine, DrawRect, TextWidth, TextHeight\n\n[url=ref:drawstring]📖 VG Language Reference[/url]" },

    { "drawtext",
      "[b]Syntax[/b]\n[b]DrawText[/b](text, x, y, color[, fontSize])\n\n"
      "[b]Description[/b]\n"
      "Alias for [code]DrawString[/code]. Draws text at (x,y) using the default font. "
      "Call inside [code]_draw()[/code].\n\n"
      "[b]See Also[/b]\nDrawString, DrawLine, DrawRect\n\n[url=ref:drawstring]📖 VG Language Reference[/url]" },

    { "drawarc",
      "[b]Syntax[/b]\n[b]DrawArc[/b](x, y, radius, startAngle, endAngle[, pointCount][, color][, width])\n\n"
      "[b]Description[/b]\n"
      "Draws an arc (partial circle outline) centred at (x,y). Angles are in [b]radians[/b]. "
      "Wraps Godot's [code]draw_arc()[/code]. Call inside [code]_draw()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    DrawArc(100, 100, 60, 0, PI, 32, Color(1, 0.5, 0), 2.0)\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawCircle, DrawLine\n\n[url=ref:drawarc]📖 VG Language Reference[/url]" },

    { "drawpolygon",
      "[b]Syntax[/b]\n[b]DrawPolygon[/b](points As Array, color)\n\n"
      "[b]Description[/b]\n"
      "Draws a filled polygon from an array of [code]Vector2[/code] points. "
      "Wraps Godot's [code]draw_polygon()[/code]. Call inside [code]_draw()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    Dim pts = Array(Vector2(0,0), Vector2(100,0), Vector2(50,80))\n"
      "    DrawPolygon(pts, Color(1,0,1))\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawPolyline, DrawRect, DrawLine\n\n[url=ref:drawpolygon]📖 VG Language Reference[/url]" },

    { "drawpolyline",
      "[b]Syntax[/b]\n[b]DrawPolyline[/b](points As Array, color[, width])\n\n"
      "[b]Description[/b]\n"
      "Draws an open polyline connecting an array of [code]Vector2[/code] points. "
      "Unlike [code]DrawPolygon[/code], the last point is [i]not[/i] connected back to the first. "
      "Wraps Godot's [code]draw_polyline()[/code]. Call inside [code]_draw()[/code].\n\n"
      "[b]See Also[/b]\nDrawPolygon, DrawLine\n\n[url=ref:drawpolyline]📖 VG Language Reference[/url]" },

    { "cls",
      "[b]Syntax[/b]\n[b]CLS[/b]()\n\n"
      "[b]Description[/b]\n"
      "Clears the canvas. Resets all drawn content so the next [code]_draw()[/code] call starts with a blank frame. "
      "Equivalent to calling [code]QueueRedraw()[/code] and issuing no draw calls.\n\n"
      "[b]See Also[/b]\nQueueRedraw, DrawLine, DrawRect\n\n[url=ref:cls]📖 VG Language Reference[/url]" },

    { "pset",
      "[b]Syntax[/b]\n[b]PSet[/b](x, y, color)\n\n"
      "[b]Description[/b]\n"
      "Draws a single pixel at (x,y). VB6-compatible alias for [code]DrawPixel[/code]. "
      "Call inside [code]_draw()[/code] for on-screen output.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _draw()\n"
      "    PSet(50, 50, Color(1, 1, 0))\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawLine, DrawPixel\n\n[url=ref:pset]📖 VG Language Reference[/url]" },

    { "queueredraw",
      "[b]Syntax[/b]\n[b]QueueRedraw[/b]()\n\n"
      "[b]Description[/b]\n"
      "Schedules [code]_draw()[/code] to be called on the next frame. "
      "Call this whenever a value that affects the canvas changes. "
      "Wraps Godot's [code]Node2D.queue_redraw()[/code].\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub UpdateScore(newScore As Integer)\n"
      "    score = newScore\n"
      "    QueueRedraw()\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nDrawLine, DrawRect, CLS\n\n[url=ref:queueredraw]📖 VG Language Reference[/url]" },

    // ── Bonus: Godot/system helpers ───────────────────────────────────────────
    { "changescene",
      "[b]Syntax[/b]\n[b]ChangeScene[/b](scenePath As String)\n\n"
      "[b]Description[/b]\n"
      "Transitions to a different Godot scene. "
      "Wraps [code]get_tree().change_scene_to_file()[/code]. "
      "The current scene is freed and the new one is loaded.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub OnPlayButton_Click()\n"
      "    ChangeScene(\"res://scenes/Level1.tscn\")\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nGetTree, QueueFree\n\n[url=ref:changescene]📖 VG Language Reference[/url]" },

    { "playsound",
      "[b]Syntax[/b]\n[b]PlaySound[/b](soundPath As String, volume As Double)\n\n"
      "[b]Description[/b]\n"
      "Plays an audio file once at the given volume (0.0–1.0). "
      "The path is a Godot resource path (e.g. [code]\"res://audio/jump.wav\"[/code]).\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "PlaySound(\"res://audio/explosion.wav\", 0.8)\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nPlayTone\n\n[url=ref:playsound]📖 VG Language Reference[/url]" },

    { "randomize",
      "[b]Syntax[/b]\n[b]Randomize[/b]()\n\n"
      "[b]Description[/b]\n"
      "Seeds the random number generator with a time-based value so that [code]Rnd()[/code] produces a unique sequence each run. "
      "Call once at startup. Without [code]Randomize[/code], [code]Rnd()[/code] always produces the same sequence.\n\n"
      "[b]Example[/b]\n"
      "[codeblock lang=vgbasic]"
      "Sub _ready()\n"
      "    Randomize()\n"
      "End Sub\n"
      "[/codeblock]\n"
      "[b]See Also[/b]\nRnd, RandRange\n\n[url=ref:randomize]📖 VG Language Reference[/url]" },

    { nullptr, nullptr }
};

Dictionary VisualGasicLanguage::_lookup_code(const String &p_code, const String &p_symbol, const String &p_path, Object *p_owner) const {
    // 1) Built-in keyword / function documentation -> hover tooltip.
    // Godot's ScriptTextEditor::_show_symbol_tooltip only renders an arbitrary
    // description for LOOKUP_RESULT_LOCAL_VARIABLE / LOCAL_CONSTANT results
    // (it reads result.description directly, without requiring the symbol to
    // exist in the engine's documentation database).
    {
        String sym = p_symbol.to_lower();
        for (int i = 0; VG_BUILTIN_DOCS[i].name != nullptr; i++) {
            if (sym == VG_BUILTIN_DOCS[i].name) {
                Dictionary result;
                result["result"] = OK;
                result["type"] = ScriptLanguageExtension::LOOKUP_RESULT_LOCAL_VARIABLE;
                result["description"] = String(VG_BUILTIN_DOCS[i].doc);
                return result;
            }
        }
    }

    // 2) User-defined Sub / Function / Property / Label -> jump to definition.
    // Ctrl+Click sends the symbol (word) under the cursor. Godot navigates to
    // result.location - 1, so location must be the 1-based line number.
    String symbol_lower = p_symbol.to_lower();
    PackedStringArray lines = p_code.split("\n");
    static const char *MODIFIERS[] = { "public ", "private ", "friend ", "static ", nullptr };

    for (int i = 0; i < lines.size(); i++) {
        String line = lines[i].strip_edges().to_lower();

        // Strip any leading access / scope modifiers.
        bool changed = true;
        while (changed) {
            changed = false;
            for (int m = 0; MODIFIERS[m] != nullptr; m++) {
                if (line.begins_with(MODIFIERS[m])) {
                    line = line.substr(String(MODIFIERS[m]).length()).strip_edges();
                    changed = true;
                }
            }
        }

        bool is_definition = false;

        if (line.begins_with("sub " + symbol_lower) || line.begins_with("function " + symbol_lower)) {
            // Ensure the match ends at the name boundary, not a longer name.
            int name_end = (line.begins_with("sub ") ? 4 : 9) + symbol_lower.length();
            if (name_end >= line.length() || line[name_end] == '(' || line[name_end] == ' ' || line[name_end] == '\t') {
                is_definition = true;
            }
        } else if (line.begins_with("property get " + symbol_lower) ||
                   line.begins_with("property let " + symbol_lower) ||
                   line.begins_with("property set " + symbol_lower)) {
            is_definition = true;
        } else if (line.begins_with(symbol_lower + ":")) {
            is_definition = true; // Label.
        }

        if (is_definition) {
            Dictionary result;
            result["result"] = OK;
            result["type"] = ScriptLanguageExtension::LOOKUP_RESULT_SCRIPT_LOCATION;
            result["location"] = i + 1; // 1-based; editor navigates to location - 1.
            return result;
        }
    }

    // Nothing found: return {result, type} so Godot suppresses both
    // ERR_FAIL_COND checks at script_language_extension.h:449 and :452.
    Dictionary not_found;
    not_found["result"] = (int)ERR_UNAVAILABLE;
    not_found["type"] = (int)ScriptLanguageExtension::LOOKUP_RESULT_MAX;
    return not_found;
}

// ── Profiler bridge (static wrappers around VisualGasicProfiler singleton) ──
// The editor's Profiler panel drives these via ClassDB.class_call_static().
// Using a static bridge avoids the previous design that required every VG
// script instance to carry its own _vg_profiler_* methods — the profiler is
// inherently global (single shared counter/timing map), so it belongs here.

void VisualGasicLanguage::vg_profiler_enable(bool p_enabled) {
    VisualGasicProfiler::getInstance().enable_profiling(p_enabled);
}

bool VisualGasicLanguage::vg_profiler_is_enabled() {
    return VisualGasicProfiler::getInstance().is_profiling_enabled();
}

Dictionary VisualGasicLanguage::vg_profiler_get_report() {
    return VisualGasicProfiler::getInstance().get_performance_report();
}

void VisualGasicLanguage::vg_profiler_clear() {
    VisualGasicProfiler::getInstance().clear_all();
}


void VisualGasicLanguage::_bind_methods() {
    ClassDB::bind_method(D_METHOD("format_source_code", "code"), &VisualGasicLanguage::format_source_code);

    // Code validation — callable from GDScript as VisualGasicLanguage.vg_validate_code(source, path)
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_validate_code", "code", "path"), &VisualGasicLanguage::vg_validate_code);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_analyze_causal_graph", "code", "roots"), &VisualGasicLanguage::vg_analyze_causal_graph);
    
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
    
    // Set Next Statement (yellow-arrow drag)
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_set_next_statement", "line"), &VisualGasicLanguage::set_next_statement);
    
    // Pause / Break request
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_request_break"), &VisualGasicLanguage::request_break);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_is_break_requested"), &VisualGasicLanguage::is_break_requested);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_clear_break_request"), &VisualGasicLanguage::clear_break_request);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_idle_break"), &VisualGasicLanguage::idle_break);
    
    // Expression evaluation in debug context
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_evaluate_expression", "expression"), &VisualGasicLanguage::evaluate_expression_in_context);
    
    // Immediate Window evaluate — callable from GDScript when C++ manages the instance registry
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_evaluate_immediate", "instance_index", "code"), &VisualGasicLanguage::evaluate_immediate_by_index);
    
    // Hot Reload
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_get_live_script_count"), &VisualGasicLanguage::get_live_script_count);

    // Profiler bridge — backs the editor's Profiler panel via the debug protocol.
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_profiler_enable", "enabled"), &VisualGasicLanguage::vg_profiler_enable);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_profiler_is_enabled"), &VisualGasicLanguage::vg_profiler_is_enabled);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_profiler_get_report"), &VisualGasicLanguage::vg_profiler_get_report);
    ClassDB::bind_static_method("VisualGasicLanguage", D_METHOD("vg_profiler_clear"), &VisualGasicLanguage::vg_profiler_clear);
}

// Helper: strip a leading access modifier (public/private/static/friend) from
// a lowercased line and return the remainder, so "public sub foo()" -> "sub foo()".
static String strip_access_modifier(const String &line_lower) {
    static const char *modifiers[] = { "public ", "private ", "static ", "friend ", nullptr };
    for (int i = 0; modifiers[i]; i++) {
        if (line_lower.begins_with(modifiers[i])) {
            return line_lower.substr(String(modifiers[i]).length());
        }
    }
    return line_lower;
}

String VisualGasicLanguage::format_source_code(const String &p_code) const {
    String indented_code;
    PackedStringArray lines = p_code.split("\n");
    int current_indent = 0;
    
    for (int i = 0; i < lines.size(); i++) {
        String line = lines[i].strip_edges();
        String line_lower = line.to_lower();
        // Also check the line with access modifier stripped
        String core = strip_access_modifier(line_lower);
        
        // Skip empty lines (preserve them without indentation)
        if (line.is_empty()) {
            if (i > 0) indented_code += "\n";
            continue;
        }
        
        // --- DEDENT BEFORE writing the line ---
        // "Else", "ElseIf", "Case" dedent then re-indent
        if (line_lower.begins_with("else") ||
            line_lower.begins_with("elseif") ||
            line_lower.begins_with("case ") ||
            line_lower == "case else") {
            if (current_indent > 0) current_indent--;
        }
        
        // Closing keywords dedent
        if (line_lower.begins_with("end sub") ||
            line_lower.begins_with("end function") ||
            line_lower.begins_with("end property") ||
            line_lower.begins_with("end class") ||
            line_lower.begins_with("end if") ||
            line_lower.begins_with("end select") ||
            line_lower.begins_with("end type") ||
            line_lower.begins_with("end enum") ||
            line_lower.begins_with("end with") ||
            line_lower.begins_with("end whenever") ||
            line_lower.begins_with("end try") ||
            line_lower == "next" || line_lower.begins_with("next ") ||
            line_lower == "wend" ||
            line_lower == "loop" || line_lower.begins_with("loop ")) {
            if (current_indent > 0) current_indent--;
        }
        
        // --- Write the indented line ---
        if (i > 0) indented_code += "\n";
        for (int t = 0; t < current_indent; t++) {
            indented_code += "\t";
        }
        indented_code += line;
        
        // --- INDENT AFTER writing the line (for the next line) ---
        // Detect single-line If (If x Then y — no indent)
        bool is_single_line_if = false;
        if (line_lower.begins_with("if ") && line_lower.contains(" then ")) {
            int then_pos = line_lower.find(" then ");
            String after_then = line_lower.substr(then_pos + 6).strip_edges();
            if (!after_then.is_empty() && !after_then.begins_with("'")) {
                is_single_line_if = true;
            }
        }
        
        if (!is_single_line_if) {
            // Check both original line and access-modifier-stripped version
            if (core.begins_with("sub ") || core == "sub" ||
                core.begins_with("function ") || core == "function" ||
                core.begins_with("property ") ||
                core.begins_with("class ") || core == "class" ||
                line_lower.begins_with("for ") ||
                line_lower.begins_with("while ") ||
                (line_lower.begins_with("do") && (line_lower == "do" || line_lower[2] == ' ' || line_lower[2] == '\n')) ||
                line_lower.begins_with("select case ") ||
                line_lower.begins_with("with ") ||
                core.begins_with("type ") || core == "type" ||
                core.begins_with("enum ") || core == "enum" ||
                line_lower.begins_with("whenever ") ||
                line_lower == "try" || line_lower.begins_with("try ") ||
                (line_lower.begins_with("if ") && line_lower.ends_with(" then")) ||
                line_lower == "else" || line_lower.begins_with("else ") ||
                line_lower.begins_with("elseif ") ||
                line_lower.begins_with("case ") ||
                line_lower == "case else") {
                current_indent++;
            }
        }
    }
    return indented_code;
}

String VisualGasicLanguage::_auto_indent_code(const String &p_code, int32_t p_from_line, int32_t p_to_line) const {
    // Godot calls this when the user presses Enter.  It expects the returned
    // code to have only the affected region reindented — NOT the entire file.
    // We reformat the full document to compute correct indent levels, then
    // splice only the changed region back into the original code.
    String formatted = format_source_code(p_code);
    
    // If from/to cover the whole file (or are -1), return the full result
    PackedStringArray orig_lines = p_code.split("\n");
    PackedStringArray fmt_lines  = formatted.split("\n");
    
    if (p_from_line < 0) p_from_line = 0;
    if (p_to_line < 0 || p_to_line >= orig_lines.size()) p_to_line = orig_lines.size() - 1;
    
    // If the line counts match, splice only the requested range
    if (orig_lines.size() == fmt_lines.size()) {
        PackedStringArray result;
        for (int i = 0; i < orig_lines.size(); i++) {
            if (i >= p_from_line && i <= p_to_line) {
                result.push_back(fmt_lines[i]);
            } else {
                result.push_back(orig_lines[i]);
            }
        }
        return String("\n").join(result);
    }
    
    // Line counts differ (e.g. user just inserted a line) — return full format
    return formatted;
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
        int result;
        if (p_level == 0 && current_break_line > 0) {
            result = current_break_line;
        } else {
            result = stack[idx].line;
        }
        // Godot expects 1-based lines here; _text_editor_stack_goto does -1 internally
        return result;
    }
    return -1;
}

String VisualGasicLanguage::_debug_get_stack_level_function(int32_t p_level) const {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        int idx = stack.size() - 1 - p_level;
        return stack[idx].function;
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
        frame["file"] = stack[i].file;
        frame["func"] = stack[i].function;
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
    // Process pending hot reloads (queued from resource_saved or _reload_tool_script)
    if (!pending_reloads.empty()) {
        std::lock_guard<std::mutex> lock(live_scripts_mutex);
        for (VisualGasicScript* script : pending_reloads) {
            if (live_scripts.count(script) && script->_has_source_code()) {
                String path = script->get_path();
                
                // Re-read source from disk if the file exists
                if (!path.is_empty() && FileAccess::file_exists(path)) {
                    Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
                    if (f.is_valid()) {
                        String new_source = f->get_as_text();
                        f->close();
                        
                        // Only reload if source actually changed
                        if (new_source != script->_get_source_code()) {
                            script->_set_source_code(new_source);
                            Error err = script->_reload(true);
                            if (err == OK) {
                                UtilityFunctions::print_rich("[color=lime][VG Hot Reload] Reloaded: ", path, "[/color]");
                            } else {
                                UtilityFunctions::print_rich("[color=red][VG Hot Reload] Failed to reload: ", path, "[/color]");
                            }
                        }
                    }
                }
            }
        }
        pending_reloads.clear();
    }
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
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    int count = 0;
    for (VisualGasicScript* script : live_scripts) {
        String path = script->get_path();
        if (path.is_empty()) continue;
        if (!FileAccess::file_exists(path)) continue;
        
        Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
        if (f.is_valid()) {
            String new_source = f->get_as_text();
            f->close();
            script->_set_source_code(new_source);
            Error err = script->_reload(true);
            if (err == OK) {
                count++;
            } else {
                UtilityFunctions::print_rich("[color=red][VG Hot Reload] Failed: ", path, "[/color]");
            }
        }
    }
    if (count > 0) {
        UtilityFunctions::print_rich("[color=lime][VG Hot Reload] Reloaded ", count, " script(s)[/color]");
    }
}

void VisualGasicLanguage::_reload_tool_script(const Ref<Script> &p_script, bool p_soft_reload) {
    if (p_script.is_null()) return;
    
    VisualGasicScript* vg_script = Object::cast_to<VisualGasicScript>(p_script.ptr());
    if (!vg_script) return;
    
    // Queue for processing in _frame() to avoid re-entrancy issues
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    // Avoid duplicates in pending queue
    for (VisualGasicScript* s : pending_reloads) {
        if (s == vg_script) return;
    }
    pending_reloads.push_back(vg_script);
}

String VisualGasicLanguage::_debug_get_stack_level_source(int32_t p_level) const {
    auto& stack = get_debug_stack();
    if (p_level >= 0 && p_level < (int32_t)stack.size()) {
        // For the top frame (level 0), use stored breakpoint file if available
        if (p_level == 0 && !current_break_file.empty()) {
            return String(current_break_file.c_str());
        }
        int idx = stack.size() - 1 - p_level;
        return stack[idx].file;
    }
    return "";
}

PackedStringArray VisualGasicLanguage::_get_doc_comment_delimiters() const {
    PackedStringArray delimiters;
    delimiters.push_back("''"); // Tooltip delimiter
    return delimiters;
}

PackedStringArray VisualGasicLanguage::_get_code_region_tags() const {
    PackedStringArray tags;
    // VB6-style code region markers: '#Region "name"' and '#End Region'
    tags.push_back("#Region");
    tags.push_back("#End Region");
    return tags;
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
    frame.file = file;
    frame.function = function;
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

// DEPRECATED: This function is no longer used since Phase 3 implementation.
// We now use Godot's built-in EngineDebugger::script_debug() which properly integrates
// with the editor's debugger panel (Continue, Step Into, Step Over, Step Out buttons).
// Keeping this for reference in case we need fallback file-based debugging.
void VisualGasicLanguage::wait_for_debug_command() {
    EngineDebugger* debugger = EngineDebugger::get_singleton();
    if (!debugger) {
        UtilityFunctions::printerr("[VisualGasic] No debugger available, continuing execution");
        return;
    }
    
    // NOTE: This is now deprecated. Use script_debug() instead.
    // Keeping for backwards compatibility with file-based debug commands.
    
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
        return stack.back().file;
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
        frame["function"] = stack[i].function;
        frame["file"] = stack[i].file;
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
// PAUSE / BREAK REQUEST
// ============================================================================

bool VisualGasicLanguage::break_requested = false;

void VisualGasicLanguage::request_break() {
    break_requested = true;
    UtilityFunctions::print("[VG Debug] Break requested - will pause at next statement");
}

bool VisualGasicLanguage::is_break_requested() {
    return break_requested;
}

void VisualGasicLanguage::clear_break_request() {
    break_requested = false;
}

void VisualGasicLanguage::idle_break() {
    if (!break_requested) return;
    break_requested = false;

    EngineDebugger* debugger = EngineDebugger::get_singleton();
    if (!debugger || !debugger->is_active()) return;

    // Find the first active instance via the C++ registry
    Array instances = VisualGasicDebug::get_all_instances();
    String script_path;
    int line = 1;

    if (!instances.is_empty()) {
        Dictionary info = instances[0];
        script_path = info.get("script_path", "");
    }

    if (script_path.is_empty()) {
        UtilityFunctions::print("[VG Debug] Break requested but no VG instances found");
        return;
    }

    set_current_break_location(script_path, line);

    // Notify editor of break
    Array break_data;
    break_data.push_back(script_path);
    break_data.push_back(line);
    debugger->send_message("visualgasic:break_hit", break_data);

    // Send variables for the first instance
    Dictionary vars = VisualGasicDebug::get_instance_variables(0);
    Array var_data;
    var_data.push_back(vars);
    debugger->send_message("visualgasic:variables_list", var_data);

    // Send empty call stack (idle — no subs on the stack)
    Array stack_data;
    stack_data.push_back(Array());
    debugger->send_message("visualgasic:call_stack", stack_data);

    debugger->line_poll();

    UtilityFunctions::print("[VG Debug] Idle break at ", script_path, ":", line);
    vg_debug_wait();
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
    
    // Check for array/dictionary indexing (e.g., filtered(1), Objects("key"))
    if (trimmed.contains("(") && trimmed.ends_with(")")) {
        int paren_pos = trimmed.find("(");
        String base_name = trimmed.substr(0, paren_pos);
        String index_str = trimmed.substr(paren_pos + 1, trimmed.length() - paren_pos - 2).strip_edges();
        
        Variant base_value;
        if (instance->get(StringName(base_name), base_value)) {
            if (base_value.get_type() == Variant::ARRAY && index_str.is_valid_int()) {
                Array arr = base_value;
                int idx = index_str.to_int();
                if (idx >= 0 && idx < arr.size()) {
                    return String(arr[idx]);
                }
            } else if (base_value.get_type() == Variant::DICTIONARY) {
                Dictionary dict = base_value;
                Variant key;
                if ((index_str.begins_with("\"") && index_str.ends_with("\"")) ||
                    (index_str.begins_with("'") && index_str.ends_with("'"))) {
                    key = index_str.substr(1, index_str.length() - 2);
                } else if (index_str.is_valid_int()) {
                    key = index_str.to_int();
                } else {
                    key = index_str;
                }
                if (dict.has(key)) {
                    return String(dict[key]);
                }
            }
        }
    }
    
    return "[Cannot evaluate: " + trimmed + "]";
}

// ============================================================================
// IMMEDIATE WINDOW EVALUATE — GDScript-callable static method
// ============================================================================

Dictionary VisualGasicLanguage::evaluate_immediate_by_index(int instance_index, const String& code) {
    Dictionary result;
    result["success"] = false;
    result["result"] = "Instance not found";

    VisualGasicInstance* inst = VisualGasicDebug::get_instance_by_index(instance_index);
    if (inst) {
        result = inst->evaluate_immediate(code);
    }

    return result;
}

// ============================================================================
// HOT RELOAD — SCRIPT REGISTRY
// ============================================================================

void VisualGasicLanguage::register_script(VisualGasicScript* script) {
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    live_scripts.insert(script);
}

void VisualGasicLanguage::unregister_script(VisualGasicScript* script) {
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    live_scripts.erase(script);
    // Remove from pending queue too
    for (auto it = pending_reloads.begin(); it != pending_reloads.end(); ) {
        if (*it == script) {
            it = pending_reloads.erase(it);
        } else {
            ++it;
        }
    }
}

void VisualGasicLanguage::queue_hot_reload(VisualGasicScript* script) {
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    if (live_scripts.count(script)) {
        // Avoid duplicates
        for (VisualGasicScript* s : pending_reloads) {
            if (s == script) return;
        }
        pending_reloads.push_back(script);
    }
}

int VisualGasicLanguage::get_live_script_count() {
    std::lock_guard<std::mutex> lock(live_scripts_mutex);
    return (int)live_scripts.size();
}

// ============================================================================
// DEBUG WAIT — enters Godot's EngineDebugger::script_debug() loop
// ============================================================================

void VisualGasicLanguage::vg_debug_wait() {
    VisualGasicLanguage *lang = get_singleton();
    if (!lang) return;
    
    EngineDebugger *debugger = EngineDebugger::get_singleton();
    if (!debugger || !debugger->is_active()) return;
    
    // Enter Godot's standard debug loop — this blocks until the user
    // presses Continue / Step / etc. in the editor's debugger panel.
    debugger->script_debug(lang, true, false);
    
    // Flush any messages that arrived during or just after script_debug().
    // This is critical for Set Next Statement: the editor sends the
    // set_next_statement message while we're blocked, and it may not be
    // dispatched until we poll here.
    if (debugger->is_active()) {
        debugger->line_poll();
    }
}

// ============================================================================
// EXCEPTION ASSISTANT — break on unhandled error (VB6-style)
// ============================================================================

bool VisualGasicLanguage::get_break_on_error() {
    return break_on_unhandled_error;
}

void VisualGasicLanguage::set_break_on_error(bool enabled) {
    break_on_unhandled_error = enabled;
}

// ============================================================================
// SET NEXT STATEMENT (yellow-arrow drag)
// ============================================================================

void VisualGasicLanguage::set_next_statement(int line) {
    next_statement_requested = true;
    next_statement_line = line;
}

bool VisualGasicLanguage::is_next_statement_requested() {
    return next_statement_requested;
}

int VisualGasicLanguage::get_next_statement_line() {
    return next_statement_line;
}

void VisualGasicLanguage::clear_next_statement() {
    next_statement_requested = false;
    next_statement_line = 0;
}

// ============================================================================
// EDIT & CONTINUE
// ============================================================================

bool VisualGasicLanguage::apply_edit_and_continue(const String& script_path, const String& new_source) {
    // Store the pending edit — the bytecode VM will pick it up on next iteration
    edit_and_continue_pending = true;
    edit_and_continue_source = new_source.utf8().get_data();
    edit_and_continue_path = script_path.utf8().get_data();
    return true;
}

// ============================================================================
// STACK LOCALS BY LEVEL (for debug message handler)
// ============================================================================

Dictionary VisualGasicLanguage::get_stack_locals_by_level(int level) {
    // Delegate to the standard debug_get_stack_level_locals
    VisualGasicLanguage *lang = get_singleton();
    if (!lang) return Dictionary();
    return lang->_debug_get_stack_level_locals(level, 100, 2);
}
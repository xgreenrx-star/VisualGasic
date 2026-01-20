#include "visual_gasic_script.h"
#include "visual_gasic_language.h"
#include "visual_gasic_instance.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void VisualGasicScript::_bind_methods() {
    // Bindings
}

bool VisualGasicScript::_can_instantiate() const {
    // Typically true if the script is valid
    return true; 
}

Ref<Script> VisualGasicScript::_get_base_script() const {
    return base_script;
}

StringName VisualGasicScript::_get_global_name() const {
    return StringName();
}

bool VisualGasicScript::_inherits_script(const Ref<Script> &p_script) const {
    return false;
}

StringName VisualGasicScript::_get_instance_base_type() const {
    if (base_script.is_valid()) {
        return base_script->get_instance_base_type();
    }
    if (ast_root && !ast_root->inherits_path.is_empty()) {
        // If it's not a path (doesn't contain / or .), assume native type
        if (ast_root->inherits_path.find("/") == -1 && ast_root->inherits_path.find(".") == -1) {
            return StringName(ast_root->inherits_path);
        }
    }
    return "Node"; // Default
}

void *VisualGasicScript::_instance_create(Object *p_for_object) const {
    VisualGasicInstance *instance = memnew(VisualGasicInstance(Ref<VisualGasicScript>(this), p_for_object));
    return internal::gdextension_interface_script_instance_create3(VisualGasicInstance::get_script_instance_info(), instance);
}

bool VisualGasicScript::_instance_has(Object *p_object) const {
    // This is hard to check without tracking instances. 
    // Usually, strict tracking is needed, but for now we return false or check script attachment.
    // However, the Engine often calls this.
    return false; 
}

bool VisualGasicScript::_has_source_code() const {
    return true;
}

String VisualGasicScript::_get_source_code() const {
    return source_code;
}

#include <godot_cpp/classes/file_access.hpp>

// Helper to resolve includes
String resolve_includes(const String& path, const String& code, int depth = 0) {
    if (depth > 10) return code; // Prevent infinite recursion

    String result = "";
    PackedStringArray lines = code.split("\n");
    
    for(int i=0; i<lines.size(); i++) {
        String line = lines[i].strip_edges();
        if (line.begins_with("Include ")) {
             String file_name = line.substr(8).strip_edges().replace("\"", "");
             UtilityFunctions::print("Including file: ", file_name);
             
             // Check if path is absolute or relative
             String full_path = file_name;
             if (!full_path.contains("://")) {
                  // Relative to current script path
                  // We need the path of the script being loaded?
                  // path arg should be the directory of the current file being processed?
                  // But 'path' passed to us is... ?
             }
             
             if (FileAccess::file_exists(full_path)) {
                 String content = FileAccess::get_file_as_string(full_path);
                 result += resolve_includes(full_path, content, depth + 1) + "\n";
             } else {
                 UtilityFunctions::print("Include Error: File not found ", full_path);
                 result += "' Missing Include: " + full_path + "\n";
             }
        } else {
             result += lines[i] + "\n";
        }
    }
    return result;
}

void VisualGasicScript::_set_source_code(const String &p_code) {
    source_code = p_code;
    
    // Auto-Format
    // Since _set_source_code is called by Editor when typing or saving,
    // we can trigger format here.
    // However, triggering it on every keystroke is bad.
    // Godot Editor usually sets source code on save/focus lost?
    // Actually, TextEdit updates it frequently.
    // Let's only do it if explicitly requested via a Manual Tool or On Save hook.
    // But since we don't have On Save hook easily without editor plugin magic,
    // we will check formatting in the reload() which happens on save.
}

#include <godot_cpp/classes/project_settings.hpp>

Error VisualGasicScript::_reload(bool p_keep_state) {
    // Apply Formatting just before successful reload?
    format_source_code();
    
    // Reload logic: Validate tokens
    String processed_code = resolve_includes("", source_code);
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(processed_code);
    if (tokens.size() > 0 && tokens[tokens.size()-1].type == VisualGasicTokenizer::TOKEN_ERROR) {
        String err_msg = tokens[tokens.size()-1].value;
        UtilityFunctions::print("Script Reload Error (Token): ", err_msg);
        return ERR_PARSE_ERROR;
    }
    
    // Re-parse
    if (ast_root) delete ast_root;
    ast_root = parser.parse(tokens);
    if (parser.errors.size() > 0) {
         UtilityFunctions::print("Script Reload Error (Parse): ", parser.errors[0].message);
    }

    // Handle Inheritance
    base_script.unref();
    if (ast_root && !ast_root->inherits_path.is_empty()) {
        if (ast_root->inherits_path.find("/") != -1 || ast_root->inherits_path.find(".") != -1) {
            // It is a path to a script
            base_script = ResourceLoader::get_singleton()->load(ast_root->inherits_path);
        }
    }
    
    // Scan Labels
    if (ast_root) {
        for(int i=0; i<ast_root->subs.size(); i++) {
            SubDefinition* sub = ast_root->subs[i];
            for(int j=0; j<sub->statements.size(); j++) {
                if (sub->statements[j]->type == STMT_LABEL) {
                    LabelStatement* lbl = (LabelStatement*)sub->statements[j];
                    sub->label_map[lbl->name] = j;
                }
            }
        }
    }
    
    return OK;
}

bool VisualGasicScript::_has_method(const StringName &p_method) const {
    if (p_method == StringName("_OnSignal")) return true;
    if (!ast_root) return false;
    for(int i=0; i<ast_root->subs.size(); i++) {
        // UtilityFunctions::print("HasMethod Check: ", ast_root->subs[i]->name, " vs ", p_method);
        if (ast_root->subs[i]->name.nocasecmp_to(String(p_method)) == 0) return true;
    }
    return false;
}

Dictionary VisualGasicScript::_get_method_info(const StringName &p_method) const {
    return Dictionary();
}

bool VisualGasicScript::_is_tool() const {
    return false;
}

bool VisualGasicScript::_is_valid() const {
    return true;
}

ScriptLanguage *VisualGasicScript::_get_language() const {
    return VisualGasicLanguage::get_singleton();
}

bool VisualGasicScript::_has_script_signal(const StringName &p_signal) const {
    if (!ast_root) return false;
    for(int i=0; i<ast_root->events.size(); i++) {
        if (ast_root->events[i]->name == p_signal) return true;
    }
    return false;
}

TypedArray<Dictionary> VisualGasicScript::_get_script_signal_list() const {
    TypedArray<Dictionary> signals;
    if (!ast_root) return signals;
    
    for(int i=0; i<ast_root->events.size(); i++) {
        Dictionary sig;
        sig["name"] = ast_root->events[i]->name;
        
        TypedArray<Dictionary> args;
        for(int j=0; j<ast_root->events[i]->arguments.size(); j++) {
            Dictionary arg;
            arg["name"] = ast_root->events[i]->arguments[j];
            arg["type"] = Variant::NIL; // Dynamic for now
            args.push_back(arg);
        }
        sig["args"] = args;
        signals.push_back(sig);
    }
    return signals;
}

bool VisualGasicScript::_has_property_default_value(const StringName &p_property) const {
    return false;
}

Variant VisualGasicScript::_get_property_default_value(const StringName &p_property) const {
    return Variant();
}

void VisualGasicScript::_update_exports() {
}

TypedArray<Dictionary> VisualGasicScript::_get_script_method_list() const {
    return TypedArray<Dictionary>();
}

TypedArray<Dictionary> VisualGasicScript::_get_script_property_list() const {
    TypedArray<Dictionary> properties;
    if (!ast_root) return properties;

    for (int i = 0; i < ast_root->variables.size(); i++) {
        VariableDefinition* v = ast_root->variables[i];
        if (v->visibility == VIS_PUBLIC) {
            Dictionary prop;
            prop["name"] = v->name;
            int usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE;
            prop["usage"] = usage;
            
            // Map VB Types to Godot Types
            String t = v->type.to_lower();
            if (t == "integer" || t == "long") prop["type"] = Variant::INT;
            else if (t == "single" || t == "double") prop["type"] = Variant::FLOAT;
            else if (t == "string") prop["type"] = Variant::STRING;
            else if (t == "boolean") prop["type"] = Variant::BOOL;
            else prop["type"] = Variant::NIL; // Variant
            
            properties.push_back(prop);
        }
    }
    return properties;
}

int32_t VisualGasicScript::_get_member_line(const StringName &p_member) const {
    return -1;
}

Dictionary VisualGasicScript::_get_constants() const {
    return Dictionary();
}

TypedArray<StringName> VisualGasicScript::_get_members() const {
    return TypedArray<StringName>();
}

bool VisualGasicScript::_is_placeholder_fallback_enabled() const {
    return false;
}

Variant VisualGasicScript::_get_rpc_config() const {
    return Variant();
}

bool VisualGasicScript::_has_static_method(const StringName &p_method) const {
    return false;
}

TypedArray<Dictionary> VisualGasicScript::_get_documentation() const {
    return TypedArray<Dictionary>();
}

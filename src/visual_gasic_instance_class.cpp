#include "visual_gasic_instance.h"
#include "visual_gasic_language.h"
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h> // For dynamic library loading on Linux/macOS
#endif

using namespace VisualGasic;

// Class instantiation and management

// --- Inheritance helpers ---

ClassDefinition* VisualGasicInstance::get_class_def(const String& class_name) {
    if (class_registry.has(class_name)) {
        Variant v = class_registry[class_name];
        ERR_FAIL_COND_V_MSG(v.get_type() != Variant::INT, nullptr,
            "VisualGasic: corrupted class registry entry for '" + class_name + "'");
        return (ClassDefinition*)((int64_t)v);
    }
    return nullptr;
}

// Build the inheritance chain: [Derived, Parent, Grandparent, ...]
void VisualGasicInstance::collect_class_hierarchy(ClassDefinition* cls, Vector<ClassDefinition*>& chain) {
    ClassDefinition* cur = cls;
    int guard = 0;
    while (cur && guard < 20) { // Limit depth to avoid infinite loops
        chain.push_back(cur);
        if (!cur->base_class.is_empty()) {
            cur = get_class_def(cur->base_class);
        } else {
            cur = nullptr;
        }
        guard++;
    }
}

// Walk inheritance chain (derived first) to find a method
SubDefinition* VisualGasicInstance::find_method_in_hierarchy(ClassDefinition* cls, const String& method_name, int p_arg_count) {
    Vector<ClassDefinition*> chain;
    collect_class_hierarchy(cls, chain);

    // If p_arg_count >= 0, do arity-aware overload resolution (same algorithm as call_internal)
    if (p_arg_count >= 0) {
        SubDefinition* best = nullptr;
        for (int c = 0; c < chain.size(); c++) {
            for (int i = 0; i < chain[c]->methods.size(); i++) {
                SubDefinition* m = chain[c]->methods[i];
                if (m->name.nocasecmp_to(method_name) != 0) continue;

                // Count required / total / has_paramarray
                int required = 0, total = m->parameters.size();
                bool has_pa = false;
                for (int p = 0; p < total; p++) {
                    if (m->parameters[p].is_param_array) { has_pa = true; break; }
                    if (!m->parameters[p].is_optional) required++;
                }
                if (has_pa) {
                    if (p_arg_count >= required) return m; // ParamArray accepts any extra
                }
                if (p_arg_count >= required && p_arg_count <= total) {
                    if (p_arg_count == total) return m; // exact match — best possible
                    if (!best) best = m;
                }
            }
        }
        if (best) return best;
    }

    // Fallback: first name match (backward compat / -1 sentinel)
    for (int c = 0; c < chain.size(); c++) {
        for (int i = 0; i < chain[c]->methods.size(); i++) {
            if (chain[c]->methods[i]->name.nocasecmp_to(method_name) == 0) {
                return chain[c]->methods[i];
            }
        }
    }
    return nullptr;
}

// Walk inheritance chain to find a property accessor
PropertyDefinition* VisualGasicInstance::find_property_in_hierarchy(ClassDefinition* cls, const String& prop_name, PropertyDefinition::PropertyType ptype) {
    Vector<ClassDefinition*> chain;
    collect_class_hierarchy(cls, chain);
    for (int c = 0; c < chain.size(); c++) {
        for (int i = 0; i < chain[c]->properties.size(); i++) {
            PropertyDefinition* p = chain[c]->properties[i];
            if (p && p->name.nocasecmp_to(prop_name) == 0 && p->property_type == ptype) {
                return p;
            }
        }
    }
    return nullptr;
}

// Initialize members from entire hierarchy (base first, then derived overrides)
void VisualGasicInstance::init_members_from_hierarchy(ClassDefinition* cls, Dictionary& obj_data) {
    Vector<ClassDefinition*> chain;
    collect_class_hierarchy(cls, chain);
    // Walk bottom-up (base class first) so all members get created
    for (int c = chain.size() - 1; c >= 0; c--) {
        ClassDefinition* cur = chain[c];
        for (int i = 0; i < cur->members.size(); i++) {
            VariableDefinition* member = cur->members[i];
            if (member->default_value) {
                obj_data[member->name] = evaluate_expression(member->default_value);
            } else {
                if (member->type.nocasecmp_to("Integer") == 0 || member->type.nocasecmp_to("Long") == 0) {
                    obj_data[member->name] = 0;
                } else if (member->type.nocasecmp_to("String") == 0) {
                    obj_data[member->name] = "";
                } else if (member->type.nocasecmp_to("Boolean") == 0) {
                    obj_data[member->name] = false;
                } else {
                    obj_data[member->name] = Variant();
                }
            }
        }
    }
}

Variant VisualGasicInstance::instantiate_class(const String& class_name, const Array& args) {
    if (!class_registry.has(class_name)) {
        UtilityFunctions::print("Error: Class '", class_name, "' not defined");
        return Variant();
    }
    
    ClassDefinition* cls = get_class_def(class_name);
    ERR_FAIL_NULL_V_MSG(cls, Variant(), "VisualGasic: failed to retrieve class definition for '" + class_name + "'");
    
    // Create new object instance
    int obj_id = next_object_id++;
    Dictionary obj_data;
    obj_data["__class__"] = class_name;
    obj_data["__id__"] = obj_id;
    
    // Initialize member variables from entire hierarchy (base → derived)
    init_members_from_hierarchy(cls, obj_data);
    
    object_instances[obj_id] = obj_data;
    
    // Call Class_Initialize chain: base first, derived last
    Vector<ClassDefinition*> chain;
    collect_class_hierarchy(cls, chain);
    for (int c = chain.size() - 1; c >= 0; c--) {
        if (chain[c]->class_initialize) {
            // Only pass args to the most-derived Class_Initialize
            Array init_args = (c == 0) ? args : Array();
            Variant ret;
            execute_class_method(chain[c], chain[c]->class_initialize, obj_id, init_args, ret);
        }
    }
    
    // Return object ID wrapped in Variant
    return obj_id;
}

bool VisualGasicInstance::get_object_member(int obj_id, const String& member_name, Variant &r_ret) {
    if (!object_instances.has(obj_id)) {
        return false;
    }
    
    Dictionary obj_data = object_instances[obj_id];
    
    // Direct member lookup (covers own + inherited members since init_members_from_hierarchy merges them)
    if (obj_data.has(member_name)) {
        r_ret = obj_data[member_name];
        return true;
    }
    
    // Check for class-scoped Property Get (with inheritance)
    String class_name = obj_data.get("__class__", "");
    ClassDefinition* cls = get_class_def(class_name);
    if (cls) {
        PropertyDefinition* prop = find_property_in_hierarchy(cls, member_name, PropertyDefinition::PROP_GET);
        if (prop) {
            // Execute property getter in object context
            Dictionary saved_vars = variables.duplicate();
            
            // Load object members into scope
            Array keys = obj_data.keys();
            for (int i = 0; i < keys.size(); i++) {
                String key = keys[i];
                if (!key.begins_with("__")) {
                    variables[key] = obj_data[key];
                }
            }
            
            // Execute property body
            for (int i = 0; i < prop->body.size(); i++) {
                execute_statement(prop->body[i]);
                if (error_state.mode == ErrorState::EXIT_SUB) {
                    error_state.mode = ErrorState::NONE;
                    break;
                }
            }
            
            // Get return value
            if (variables.has(member_name)) {
                r_ret = variables[member_name];
            }
            
            // Write back modified members
            if (cls) {
                Vector<ClassDefinition*> chain;
                collect_class_hierarchy(cls, chain);
                for (int c = 0; c < chain.size(); c++) {
                    for (int m = 0; m < chain[c]->members.size(); m++) {
                        String mname = chain[c]->members[m]->name;
                        if (variables.has(mname)) {
                            obj_data[mname] = variables[mname];
                        }
                    }
                }
                object_instances[obj_id] = obj_data;
            }
            
            variables = saved_vars;
            return true;
        }
    }
    
    // Fallback: module-level property
    PropertyDefinition::PropertyType prop_type;
    if (is_property_accessor(member_name, prop_type)) {
        if (prop_type == PropertyDefinition::PROP_GET) {
            r_ret = call_property_get(member_name, Array());
            return true;
        }
    }
    
    return false;
}

void VisualGasicInstance::set_object_member(int obj_id, const String& member_name, const Variant& value) {
    if (!object_instances.has(obj_id)) {
        UtilityFunctions::print("Error: Invalid object ID ", obj_id);
        return;
    }
    
    Dictionary obj_data = object_instances[obj_id];
    
    // Check for class-scoped Property Let/Set (with inheritance)
    String class_name = obj_data.get("__class__", "");
    ClassDefinition* cls = get_class_def(class_name);
    if (cls) {
        PropertyDefinition* prop = find_property_in_hierarchy(cls, member_name, PropertyDefinition::PROP_LET);
        if (!prop) {
            prop = find_property_in_hierarchy(cls, member_name, PropertyDefinition::PROP_SET);
        }
        if (prop) {
            // Execute property setter in object context
            Dictionary saved_vars = variables.duplicate();
            
            // Load object members into scope
            Array keys = obj_data.keys();
            for (int i = 0; i < keys.size(); i++) {
                String key = keys[i];
                if (!key.begins_with("__")) {
                    variables[key] = obj_data[key];
                }
            }
            
            // Set the value parameter (last parameter in Property Let/Set)
            if (prop->parameters.size() > 0) {
                variables[prop->parameters[prop->parameters.size() - 1].name] = value;
            }
            
            // Execute property body
            for (int i = 0; i < prop->body.size(); i++) {
                execute_statement(prop->body[i]);
                if (error_state.mode == ErrorState::EXIT_SUB) {
                    error_state.mode = ErrorState::NONE;
                    break;
                }
            }
            
            // Write back modified members from hierarchy
            Vector<ClassDefinition*> chain;
            collect_class_hierarchy(cls, chain);
            for (int c = 0; c < chain.size(); c++) {
                for (int m = 0; m < chain[c]->members.size(); m++) {
                    String mname = chain[c]->members[m]->name;
                    if (variables.has(mname)) {
                        obj_data[mname] = variables[mname];
                    }
                }
            }
            object_instances[obj_id] = obj_data;
            
            variables = saved_vars;
            return;
        }
    }
    
    // Fallback: module-level property
    PropertyDefinition::PropertyType prop_type;
    if (is_property_accessor(member_name, prop_type)) {
        if (prop_type == PropertyDefinition::PROP_LET || prop_type == PropertyDefinition::PROP_SET) {
            call_property_let(member_name, Array(), value);
            return;
        }
    }
    
    // Direct member assignment
    obj_data[member_name] = value;
    object_instances[obj_id] = obj_data;
}

Variant VisualGasicInstance::call_object_method(int obj_id, const String& method_name, const Array& args) {
    if (!object_instances.has(obj_id)) {
        UtilityFunctions::print("Error: Invalid object ID ", obj_id);
        return Variant();
    }
    
    Dictionary obj_data = object_instances[obj_id];
    String class_name = obj_data["__class__"];
    
    if (!class_registry.has(class_name)) {
        return Variant();
    }
    
    ClassDefinition* cls = get_class_def(class_name);
    ERR_FAIL_NULL_V_MSG(cls, Variant(), "VisualGasic: class '" + class_name + "' not found in registry");
    
    // Find method in class hierarchy (derived-first for polymorphism, arity-aware)
    SubDefinition* method = find_method_in_hierarchy(cls, method_name, args.size());
    if (method) {
        Variant ret;
        execute_class_method(cls, method, obj_id, args, ret);
        return ret;
    }
    
    UtilityFunctions::print("Error: Method '", method_name, "' not found in class '", class_name, "' hierarchy");
    return Variant();
}

void VisualGasicInstance::register_class(ClassDefinition* cls) {
    if (cls && !cls->name.is_empty()) {
        class_registry[cls->name] = (int64_t)cls; // Store pointer as int64
        UtilityFunctions::print("Registered class: ", cls->name);
    }
}

void VisualGasicInstance::execute_class_method(ClassDefinition* cls, SubDefinition* method, int obj_id, const Array& args, Variant& r_ret) {
    // Save current object context
    Dictionary saved_vars = variables.duplicate();
    
    // Load object members into variable scope
    if (object_instances.has(obj_id)) {
        Dictionary obj_data = object_instances[obj_id];
        Array keys = obj_data.keys();
        for (int i = 0; i < keys.size(); i++) {
            String key = keys[i];
            if (!key.begins_with("__")) { // Skip internal fields
                variables[key] = obj_data[key];
            }
        }
    }
    
    // Set up method parameters
    for (int i = 0; i < method->parameters.size() && i < args.size(); i++) {
        variables[method->parameters[i].name] = args[i];
    }
    
    // Execute method body
    SubDefinition* saved_sub = current_sub;
    current_sub = method;
    int saved_object_id = current_object_id;
    current_object_id = obj_id;
    
    // Push call stack frame for debugger
    String file_path = script.is_valid() ? script->get_path() : "";
    String full_method_name = cls->name + "." + method->name;
    int start_line = method->statements.size() > 0 ? method->statements[0]->line : 0;
    VisualGasicLanguage::push_stack_frame(file_path, full_method_name, start_line, this);
    
    for (int i = 0; i < method->statements.size(); i++) {
        execute_statement(method->statements[i]);
        
        // Check for early exit
        if (error_state.mode == ErrorState::EXIT_SUB) {
            error_state.mode = ErrorState::NONE;
            break;
        }
    }
    
    // Get return value for functions
    if (method->type == SubDefinition::TYPE_FUNCTION) {
        if (variables.has(method->name)) {
            r_ret = variables[method->name];
        }
    }
    
    // Pop call stack frame for debugger
    VisualGasicLanguage::pop_stack_frame();
    
    current_sub = saved_sub;
    current_object_id = saved_object_id;
    
    // Save modified members back to object (entire inheritance hierarchy)
    if (object_instances.has(obj_id)) {
        Dictionary obj_data = object_instances[obj_id];
        String class_name = obj_data["__class__"];
        
        if (class_registry.has(class_name)) {
            ClassDefinition* cls_def = get_class_def(class_name);
            ERR_FAIL_NULL(cls_def);
            
            Vector<ClassDefinition*> chain;
            collect_class_hierarchy(cls_def, chain);
            for (int c = 0; c < chain.size(); c++) {
                for (int i = 0; i < chain[c]->members.size(); i++) {
                    String member_name = chain[c]->members[i]->name;
                    if (variables.has(member_name)) {
                        obj_data[member_name] = variables[member_name];
                    }
                }
            }
            
            object_instances[obj_id] = obj_data;
        }
    }
    
    // Restore variable scope
    variables = saved_vars;
}

// Property accessors
bool VisualGasicInstance::is_property_accessor(const String& prop_name, PropertyDefinition::PropertyType& type) {
    ModuleNode* root = script->ast_root;
    if (!root) return false;
    
    // Check module-level properties
    for (int i = 0; i < root->properties.size(); i++) {
        PropertyDefinition* prop = root->properties[i];
        if (prop && prop->name.nocasecmp_to(prop_name) == 0) {
            type = prop->property_type;
            return true;
        }
    }
    
    // Also check class definitions if we're in a class context
    // (For now, module-level only)
    
    return false;
}

Variant VisualGasicInstance::call_property_get(const String& prop_name, const Array& args) {
    ModuleNode* root = script->ast_root;
    if (!root) return Variant();
    
    // Find the Property Get definition
    PropertyDefinition* prop_def = nullptr;
    for (int i = 0; i < root->properties.size(); i++) {
        PropertyDefinition* prop = root->properties[i];
        if (prop && prop->name.nocasecmp_to(prop_name) == 0 && 
            prop->property_type == PropertyDefinition::PROP_GET) {
            prop_def = prop;
            break;
        }
    }
    
    if (!prop_def) {
        UtilityFunctions::print("Property Get '", prop_name, "' not found");
        return Variant();
    }
    
    // Save current variable state
    Dictionary saved_vars = variables.duplicate();
    
    // Set up property parameters (for indexed properties)
    for (int i = 0; i < prop_def->parameters.size() && i < args.size(); i++) {
        variables[prop_def->parameters[i].name] = args[i];
    }
    
    // Execute property body
    for (int i = 0; i < prop_def->body.size(); i++) {
        execute_statement(prop_def->body[i]);
        
        if (error_state.mode == ErrorState::EXIT_SUB) {
            error_state.mode = ErrorState::NONE;
            break;
        }
    }
    
    // Get return value (property name is the return variable in VB)
    Variant result;
    if (variables.has(prop_name)) {
        result = variables[prop_name];
    }
    
    // Restore variables
    variables = saved_vars;
    
    return result;
}

void VisualGasicInstance::call_property_let(const String& prop_name, const Array& args, const Variant& value) {
    ModuleNode* root = script->ast_root;
    if (!root) return;
    
    // Find the Property Let definition
    PropertyDefinition* prop_def = nullptr;
    for (int i = 0; i < root->properties.size(); i++) {
        PropertyDefinition* prop = root->properties[i];
        if (prop && prop->name.nocasecmp_to(prop_name) == 0 && 
            prop->property_type == PropertyDefinition::PROP_LET) {
            prop_def = prop;
            break;
        }
    }
    
    if (!prop_def) {
        UtilityFunctions::print("Property Let '", prop_name, "' not found");
        return;
    }
    
    // Save current variable state
    Dictionary saved_vars = variables.duplicate();
    
    // Set up property parameters
    // First parameters are index parameters, last parameter is the value
    for (int i = 0; i < prop_def->parameters.size() - 1 && i < args.size(); i++) {
        variables[prop_def->parameters[i].name] = args[i];
    }
    
    // Set the value parameter (last parameter in Property Let)
    if (prop_def->parameters.size() > 0) {
        variables[prop_def->parameters[prop_def->parameters.size() - 1].name] = value;
    }
    
    // Execute property body
    for (int i = 0; i < prop_def->body.size(); i++) {
        execute_statement(prop_def->body[i]);
        
        if (error_state.mode == ErrorState::EXIT_SUB) {
            error_state.mode = ErrorState::NONE;
            break;
        }
    }
    
    // Restore variables
    variables = saved_vars;
}

void VisualGasicInstance::call_property_set(const String& prop_name, const Array& args, const Variant& value) {
    ModuleNode* root = script->ast_root;
    if (!root) return;
    
    // Find the Property Set definition (for object assignment)
    PropertyDefinition* prop_def = nullptr;
    for (int i = 0; i < root->properties.size(); i++) {
        PropertyDefinition* prop = root->properties[i];
        if (prop && prop->name.nocasecmp_to(prop_name) == 0 && 
            prop->property_type == PropertyDefinition::PROP_SET) {
            prop_def = prop;
            break;
        }
    }
    
    if (!prop_def) {
        UtilityFunctions::print("Property Set '", prop_name, "' not found");
        return;
    }
    
    // Save current variable state
    Dictionary saved_vars = variables.duplicate();
    
    // Set up property parameters (same as Let, last param is the object value)
    for (int i = 0; i < prop_def->parameters.size() - 1 && i < args.size(); i++) {
        variables[prop_def->parameters[i].name] = args[i];
    }
    
    // Set the object value parameter
    if (prop_def->parameters.size() > 0) {
        variables[prop_def->parameters[prop_def->parameters.size() - 1].name] = value;
    }
    
    // Execute property body
    for (int i = 0; i < prop_def->body.size(); i++) {
        execute_statement(prop_def->body[i]);
        
        if (error_state.mode == ErrorState::EXIT_SUB) {
            error_state.mode = ErrorState::NONE;
            break;
        }
    }
    
    // Restore variables
    variables = saved_vars;
}

// FFI / DLL Support
void* VisualGasicInstance::load_library(const String& lib_name) {
    // Check if already loaded
    if (loaded_libraries.has(lib_name)) {
        return (void*)((int64_t)loaded_libraries[lib_name]);
    }
    
    // Try to load the library
    String lib_path = lib_name;
    
    // On Linux, add .so extension if not present
    #ifdef __linux__
        if (!lib_path.ends_with(".so") && !lib_path.ends_with(".so.0")) {
            // Try common patterns
            if (!lib_path.begins_with("lib")) {
                lib_path = "lib" + lib_path;
            }
            lib_path += ".so";
        }
    #elif defined(_WIN32)
        if (!lib_path.ends_with(".dll")) {
            lib_path += ".dll";
        }
    #endif
    
#ifdef _WIN32
    HMODULE handle = LoadLibraryA(lib_path.utf8().get_data());
    if (!handle) {
        UtilityFunctions::print("Error loading library '", lib_name, "': Windows error ", (int64_t)GetLastError());
        return nullptr;
    }
#else
    void* handle = dlopen(lib_path.utf8().get_data(), RTLD_LAZY);
    if (!handle) {
        UtilityFunctions::print("Error loading library '", lib_name, "': ", dlerror());
        return nullptr;
    }
#endif
    
    loaded_libraries[lib_name] = (int64_t)handle;
    UtilityFunctions::print("Loaded library: ", lib_name);
    return (void*)handle;
}

void* VisualGasicInstance::get_function_address(void* lib_handle, const String& func_name) {
    if (!lib_handle) return nullptr;
    
#ifdef _WIN32
    void* func_ptr = (void*)GetProcAddress((HMODULE)lib_handle, func_name.utf8().get_data());
    if (!func_ptr) {
        UtilityFunctions::print("Error finding function '", func_name, "': Windows error ", (int64_t)GetLastError());
        return nullptr;
    }
#else
    dlerror(); // Clear any existing error
    void* func_ptr = dlsym(lib_handle, func_name.utf8().get_data());
    
    const char* error = dlerror();
    if (error) {
        UtilityFunctions::print("Error finding function '", func_name, "': ", error);
        return nullptr;
    }
#endif
    
    return func_ptr;
}

Variant VisualGasicInstance::call_ffi_function(DeclareStatement* decl, const Array& args) {
    // Load library if not already loaded
    void* lib_handle = load_library(decl->lib_name);
    if (!lib_handle) {
        UtilityFunctions::print("Error: Could not load library '", decl->lib_name, "'");
        return Variant();
    }
    
    // Get function name (use alias if specified)
    String func_name = decl->alias_name.is_empty() ? decl->name : decl->alias_name;
    
    // Get function pointer
    void* func_ptr = get_function_address(lib_handle, func_name);
    if (!func_ptr) {
        UtilityFunctions::print("Error: Function '", func_name, "' not found in library '", decl->lib_name, "'");
        return Variant();
    }
    
    // Validate argument count
    if (args.size() != decl->param_names.size()) {
        UtilityFunctions::print("Error: FFI function '", func_name, "' expects ", decl->param_names.size(), 
                               " arguments, got ", args.size());
        return Variant();
    }
    if (args.size() > 8) {
        UtilityFunctions::print("FFI: Functions with more than 8 parameters are not supported");
        return Variant();
    }
    
    // Convert arguments to C types and call the function
    // We support common VB6 types: Integer (int), Long (int64), Single (float), Double, String, Boolean
    
    // For simplicity, we'll use a union-based approach for up to 8 parameters
    // This works for most VB6 API calls
    
    union FFIArg {
        int32_t i32;
        int64_t i64;
        float f32;
        double f64;
        const char* str;
        void* ptr;
    };
    
    FFIArg ffi_args[8];
    Vector<CharString> string_storage; // Keep strings alive during call
    
    for (int i = 0; i < args.size() && i < 8; i++) {
        String param_type = decl->param_types[i];
        Variant arg = args[i];
        
        if (param_type.nocasecmp_to("Integer") == 0 || param_type.nocasecmp_to("Short") == 0) {
            ffi_args[i].i32 = (int32_t)arg;
        } else if (param_type.nocasecmp_to("Long") == 0) {
            ffi_args[i].i64 = (int64_t)arg;
        } else if (param_type.nocasecmp_to("Single") == 0) {
            ffi_args[i].f32 = (float)arg;
        } else if (param_type.nocasecmp_to("Double") == 0) {
            ffi_args[i].f64 = (double)arg;
        } else if (param_type.nocasecmp_to("String") == 0) {
            String s = arg;
            string_storage.push_back(s.utf8());
            ffi_args[i].str = string_storage[string_storage.size() - 1].get_data();
        } else if (param_type.nocasecmp_to("Boolean") == 0) {
            ffi_args[i].i32 = (bool)arg ? -1 : 0; // VB6 True = -1
        } else if (param_type.nocasecmp_to("Any") == 0 || param_type.nocasecmp_to("Ptr") == 0) {
            ffi_args[i].i64 = (int64_t)arg;
        } else {
            // Default to pointer/long
            ffi_args[i].i64 = (int64_t)arg;
        }
    }
    
    // Call function based on number of parameters and return type
    // Using function pointer casting for common signatures
    
    Variant result;
    String ret_type = decl->return_type;
    
    // Determine return type handling
    bool returns_void = ret_type.is_empty() || ret_type.nocasecmp_to("Sub") == 0;
    bool returns_int = ret_type.nocasecmp_to("Integer") == 0 || ret_type.nocasecmp_to("Long") == 0;
    bool returns_float = ret_type.nocasecmp_to("Single") == 0;
    bool returns_double = ret_type.nocasecmp_to("Double") == 0;
    bool returns_string = ret_type.nocasecmp_to("String") == 0;
    
    // Call with appropriate signature based on parameter count
    switch (args.size()) {
        case 0: {
            if (returns_void) {
                ((void(*)())func_ptr)();
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)())func_ptr)();
            } else if (returns_float) {
                result = ((float(*)())func_ptr)();
            } else if (returns_double) {
                result = ((double(*)())func_ptr)();
            }
            break;
        }
        case 1: {
            if (returns_void) {
                ((void(*)(int64_t))func_ptr)(ffi_args[0].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t))func_ptr)(ffi_args[0].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t))func_ptr)(ffi_args[0].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t))func_ptr)(ffi_args[0].i64);
            }
            break;
        }
        case 2: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 3: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 4: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 5: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 6: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 7: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
        case 8: {
            if (returns_void) {
                ((void(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64, ffi_args[7].i64);
            } else if (returns_int) {
                result = (int64_t)((int64_t(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64, ffi_args[7].i64);
            } else if (returns_float) {
                result = ((float(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64, ffi_args[7].i64);
            } else if (returns_double) {
                result = ((double(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64, ffi_args[7].i64);
            } else if (returns_string) {
                const char* ret = ((const char*(*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(ffi_args[0].i64, ffi_args[1].i64, ffi_args[2].i64, ffi_args[3].i64, ffi_args[4].i64, ffi_args[5].i64, ffi_args[6].i64, ffi_args[7].i64);
                result = ret ? String(ret) : String();
            }
            break;
        }
    }
    
    return result;
}

void VisualGasicInstance::register_declare(DeclareStatement* decl) {
    if (decl && !decl->name.is_empty()) {
        declared_functions[decl->name] = (int64_t)decl;
        UtilityFunctions::print("Registered FFI function: ", decl->name, " from ", decl->lib_name);
    }
}

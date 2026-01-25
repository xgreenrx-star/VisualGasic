#include "visual_gasic_instance.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <dlfcn.h> // For dynamic library loading on Linux

using namespace VisualGasic;

// Class instantiation and management
Variant VisualGasicInstance::instantiate_class(const String& class_name, const Array& args) {
    if (!class_registry.has(class_name)) {
        UtilityFunctions::print("Error: Class '", class_name, "' not defined");
        return Variant();
    }
    
    ClassDefinition* cls = (ClassDefinition*)((int64_t)class_registry[class_name]);
    
    // Create new object instance
    int obj_id = next_object_id++;
    Dictionary obj_data;
    obj_data["__class__"] = class_name;
    obj_data["__id__"] = obj_id;
    
    // Initialize member variables with defaults
    for (int i = 0; i < cls->members.size(); i++) {
        VariableDefinition* member = cls->members[i];
        if (member->default_value) {
            obj_data[member->name] = evaluate_expression(member->default_value);
        } else {
            // Default initialization based on type
            if (member->type.nocasecmp_to("Integer") == 0 || member->type.nocasecmp_to("Long") == 0) {
                obj_data[member->name] = 0;
            } else if (member->type.nocasecmp_to("String") == 0) {
                obj_data[member->name] = "";
            } else if (member->type.nocasecmp_to("Boolean") == 0) {
                obj_data[member->name] = false;
            } else if (member->type.nocasecmp_to("Variant") == 0) {
                obj_data[member->name] = Variant();
            } else {
                obj_data[member->name] = Variant();
            }
        }
    }
    
    object_instances[obj_id] = obj_data;
    
    // Call Class_Initialize if it exists
    if (cls->class_initialize) {
        Variant ret;
        execute_class_method(cls, cls->class_initialize, obj_id, args, ret);
    }
    
    // Return object ID wrapped in Variant
    return obj_id;
}

bool VisualGasicInstance::get_object_member(int obj_id, const String& member_name, Variant &r_ret) {
    if (!object_instances.has(obj_id)) {
        return false;
    }
    
    Dictionary obj_data = object_instances[obj_id];
    if (obj_data.has(member_name)) {
        r_ret = obj_data[member_name];
        return true;
    }
    
    // Check for property getter
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
    
    // Check for property setter
    PropertyDefinition::PropertyType prop_type;
    if (is_property_accessor(member_name, prop_type)) {
        if (prop_type == PropertyDefinition::PROP_LET || prop_type == PropertyDefinition::PROP_SET) {
            call_property_let(member_name, Array(), value);
            return;
        }
    }
    
    obj_data[member_name] = value;
    object_instances[obj_id] = obj_data; // Update stored object
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
    
    ClassDefinition* cls = (ClassDefinition*)((int64_t)class_registry[class_name]);
    
    // Find method in class
    for (int i = 0; i < cls->methods.size(); i++) {
        if (cls->methods[i]->name.nocasecmp_to(method_name) == 0) {
            Variant ret;
            execute_class_method(cls, cls->methods[i], obj_id, args, ret);
            return ret;
        }
    }
    
    UtilityFunctions::print("Error: Method '", method_name, "' not found in class '", class_name, "'");
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
    
    current_sub = saved_sub;
    
    // Save modified members back to object
    if (object_instances.has(obj_id)) {
        Dictionary obj_data = object_instances[obj_id];
        String class_name = obj_data["__class__"];
        
        if (class_registry.has(class_name)) {
            ClassDefinition* cls_def = (ClassDefinition*)((int64_t)class_registry[class_name]);
            
            for (int i = 0; i < cls_def->members.size(); i++) {
                String member_name = cls_def->members[i]->name;
                if (variables.has(member_name)) {
                    obj_data[member_name] = variables[member_name];
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
    // Note: Properties are typically stored in class definitions, not module level
    // This is a placeholder for module-level property support
    
    return false;
}

Variant VisualGasicInstance::call_property_get(const String& prop_name, const Array& args) {
    // Placeholder for property Get execution
    ModuleNode* root = script->ast_root;
    if (!root) return Variant();
    
    // Would execute Property Get procedure body
    return Variant();
}

void VisualGasicInstance::call_property_let(const String& prop_name, const Array& args, const Variant& value) {
    // Placeholder for property Let execution
    ModuleNode* root = script->ast_root;
    if (!root) return;
    
    // Would execute Property Let procedure body
}

void VisualGasicInstance::call_property_set(const String& prop_name, const Array& args, const Variant& value) {
    // Placeholder for property Set execution (for object assignment)
    ModuleNode* root = script->ast_root;
    if (!root) return;
    
    // Would execute Property Set procedure body
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
    
    void* handle = dlopen(lib_path.utf8().get_data(), RTLD_LAZY);
    
    if (!handle) {
        UtilityFunctions::print("Error loading library '", lib_name, "': ", dlerror());
        return nullptr;
    }
    
    loaded_libraries[lib_name] = (int64_t)handle;
    UtilityFunctions::print("Loaded library: ", lib_name);
    return handle;
}

void* VisualGasicInstance::get_function_address(void* lib_handle, const String& func_name) {
    if (!lib_handle) return nullptr;
    
    dlerror(); // Clear any existing error
    void* func_ptr = dlsym(lib_handle, func_name.utf8().get_data());
    
    const char* error = dlerror();
    if (error) {
        UtilityFunctions::print("Error finding function '", func_name, "': ", error);
        return nullptr;
    }
    
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
    
    // Type marshaling and function invocation
    // This is a complex operation that requires:
    // 1. Converting VB6 types to C types
    // 2. Handling ByVal vs ByRef parameters
    // 3. Calling with correct calling convention (stdcall vs cdecl)
    // 4. Converting return value back to Variant
    
    // For now, provide a stub that shows it's recognized but not fully implemented
    UtilityFunctions::print("FFI call to ", func_name, " in ", decl->lib_name, " - Full FFI marshaling not yet implemented");
    UtilityFunctions::print("  Parameters: ", args.size(), " expected: ", decl->param_names.size());
    UtilityFunctions::print("  Calling convention: ", decl->use_cdecl ? "cdecl" : "stdcall");
    
    // Basic implementation would use libffi or manual assembly for proper calling
    return Variant();
}

void VisualGasicInstance::register_declare(DeclareStatement* decl) {
    if (decl && !decl->name.is_empty()) {
        declared_functions[decl->name] = (int64_t)decl;
        UtilityFunctions::print("Registered FFI function: ", decl->name, " from ", decl->lib_name);
    }
}

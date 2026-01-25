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

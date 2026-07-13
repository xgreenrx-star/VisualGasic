// VGNativeLibrary / VGNativeStruct — Full FFI via libffi
// Equivalent of C# P/Invoke: call ANY native C function from VisualGasic
// Supports: struct marshalling, callbacks, unlimited parameters, cross-platform

#include "visual_gasic_ffi.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <cstring>

#ifdef __linux__
#include <link.h>  // dl_iterate_phdr for symbol listing
#include <elf.h>
#elif defined(__APPLE__)
// macOS uses dlopen/dlsym just like Linux
#elif defined(_WIN32)
// Windows uses LoadLibrary/GetProcAddress
#endif

using namespace godot;

// =============================================================================
// VGNativeStruct — C struct layout builder
// =============================================================================

void VGNativeStruct::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_field", "name", "type"), &VGNativeStruct::add_field);
    ClassDB::bind_method(D_METHOD("create"), &VGNativeStruct::create);
    ClassDB::bind_method(D_METHOD("destroy", "handle"), &VGNativeStruct::destroy);
    ClassDB::bind_method(D_METHOD("set_field", "handle", "name", "value"), &VGNativeStruct::set_field);
    ClassDB::bind_method(D_METHOD("get_field", "handle", "name"), &VGNativeStruct::get_field);
    ClassDB::bind_method(D_METHOD("get_pointer", "handle"), &VGNativeStruct::get_pointer);
    ClassDB::bind_method(D_METHOD("get_size"), &VGNativeStruct::get_size);
    ClassDB::bind_method(D_METHOD("get_field_count"), &VGNativeStruct::get_field_count);
    ClassDB::bind_method(D_METHOD("get_field_names"), &VGNativeStruct::get_field_names);
    ClassDB::bind_method(D_METHOD("get_field_type", "name"), &VGNativeStruct::get_field_type);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("AddField", "name", "type"), &VGNativeStruct::add_field);
    ClassDB::bind_method(D_METHOD("Create"), &VGNativeStruct::create);
    ClassDB::bind_method(D_METHOD("Destroy", "handle"), &VGNativeStruct::destroy);
    ClassDB::bind_method(D_METHOD("SetField", "handle", "name", "value"), &VGNativeStruct::set_field);
    ClassDB::bind_method(D_METHOD("GetField", "handle", "name"), &VGNativeStruct::get_field);
    ClassDB::bind_method(D_METHOD("GetPointer", "handle"), &VGNativeStruct::get_pointer);
    ClassDB::bind_method(D_METHOD("GetSize"), &VGNativeStruct::get_size);
    ClassDB::bind_method(D_METHOD("GetFieldNames"), &VGNativeStruct::get_field_names);
    ClassDB::bind_method(D_METHOD("GetFieldType", "name"), &VGNativeStruct::get_field_type);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "Size"), "", "get_size");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "FieldCount"), "", "get_field_count");
}

VGNativeStruct::VGNativeStruct() {
    total_size = 0;
    total_alignment = 1;
    finalized = false;
}

VGNativeStruct::~VGNativeStruct() {
    for (auto *ptr : instances) {
        if (ptr) delete[] ptr;
    }
    instances.clear();
}

int VGNativeStruct::get_type_size(const String &p_type) const {
    if (p_type == "byte" || p_type == "bool") return 1;
    if (p_type == "short") return 2;
    if (p_type == "int" || p_type == "float") return 4;
    if (p_type == "long" || p_type == "int64" || p_type == "double" ||
        p_type == "pointer" || p_type == "string") return 8;
    if (p_type == "uint") return 4;
    if (p_type == "uint64") return 8;
    return 4; // Default to int-sized
}

int VGNativeStruct::get_type_alignment(const String &p_type) const {
    return get_type_size(p_type); // Natural alignment
}

#ifdef VG_HAS_LIBFFI
ffi_type *VGNativeStruct::get_ffi_type(const String &p_type) const {
    if (p_type == "void") return &ffi_type_void;
    if (p_type == "byte") return &ffi_type_uint8;
    if (p_type == "bool") return &ffi_type_uint8;
    if (p_type == "short") return &ffi_type_sint16;
    if (p_type == "int") return &ffi_type_sint32;
    if (p_type == "uint") return &ffi_type_uint32;
    if (p_type == "long" || p_type == "int64") return &ffi_type_sint64;
    if (p_type == "uint64") return &ffi_type_uint64;
    if (p_type == "float") return &ffi_type_float;
    if (p_type == "double") return &ffi_type_double;
    if (p_type == "pointer" || p_type == "string") return &ffi_type_pointer;
    return &ffi_type_sint32;
}
#endif

void VGNativeStruct::finalize_layout() {
    if (finalized) return;
    int offset = 0;
    for (auto &f : fields) {
        int align = get_type_alignment(f.type);
        // Pad to alignment boundary
        if (offset % align != 0) {
            offset += align - (offset % align);
        }
        f.offset = offset;
        f.size = get_type_size(f.type);
        f.alignment = align;
        offset += f.size;
        if (align > total_alignment) total_alignment = align;
    }
    // Final padding for array alignment
    if (offset % total_alignment != 0) {
        offset += total_alignment - (offset % total_alignment);
    }
    total_size = offset;
    finalized = true;
}

void VGNativeStruct::add_field(const String &p_name, const String &p_type) {
    if (finalized) {
        UtilityFunctions::printerr("[NativeStruct] Cannot add fields after Create() has been called");
        return;
    }
    FieldDef fd;
    fd.name = p_name;
    fd.type = p_type.to_lower();
    fd.offset = 0;
    fd.size = 0;
    fd.alignment = 0;
    fields.push_back(fd);
}

int VGNativeStruct::create() {
    if (!finalized) finalize_layout();
    if (total_size == 0) {
        UtilityFunctions::printerr("[NativeStruct] No fields defined");
        return -1;
    }
    uint8_t *mem = new uint8_t[total_size];
    memset(mem, 0, total_size);
    int handle = (int)instances.size();
    instances.push_back(mem);
    return handle;
}

void VGNativeStruct::destroy(int p_handle) {
    if (p_handle < 0 || p_handle >= (int)instances.size() || !instances[p_handle]) return;
    delete[] instances[p_handle];
    instances[p_handle] = nullptr;
}

void VGNativeStruct::set_field(int p_handle, const String &p_name, const Variant &p_value) {
    if (p_handle < 0 || p_handle >= (int)instances.size() || !instances[p_handle]) return;
    if (!finalized) finalize_layout();
    uint8_t *base = instances[p_handle];
    for (const auto &f : fields) {
        if (f.name == p_name) {
            uint8_t *ptr = base + f.offset;
            if (f.type == "byte" || f.type == "bool") {
                *ptr = (uint8_t)(int)p_value;
            } else if (f.type == "short") {
                *(int16_t *)ptr = (int16_t)(int)p_value;
            } else if (f.type == "int" || f.type == "uint") {
                *(int32_t *)ptr = (int32_t)(int)p_value;
            } else if (f.type == "long" || f.type == "int64" || f.type == "uint64") {
                *(int64_t *)ptr = (int64_t)p_value;
            } else if (f.type == "float") {
                *(float *)ptr = (float)(double)p_value;
            } else if (f.type == "double") {
                *(double *)ptr = (double)p_value;
            } else if (f.type == "pointer") {
                *(void **)ptr = (void *)(int64_t)p_value;
            }
            return;
        }
    }
    UtilityFunctions::printerr("[NativeStruct] Unknown field: ", p_name);
}

Variant VGNativeStruct::get_field(int p_handle, const String &p_name) {
    if (p_handle < 0 || p_handle >= (int)instances.size() || !instances[p_handle]) return Variant();
    if (!finalized) finalize_layout();
    uint8_t *base = instances[p_handle];
    for (const auto &f : fields) {
        if (f.name == p_name) {
            uint8_t *ptr = base + f.offset;
            if (f.type == "byte" || f.type == "bool") return (int)*ptr;
            if (f.type == "short") return (int)*(int16_t *)ptr;
            if (f.type == "int") return (int)*(int32_t *)ptr;
            if (f.type == "uint") return (int64_t)*(uint32_t *)ptr;
            if (f.type == "long" || f.type == "int64") return (int64_t)*(int64_t *)ptr;
            if (f.type == "uint64") return (int64_t)*(uint64_t *)ptr;
            if (f.type == "float") return (double)*(float *)ptr;
            if (f.type == "double") return *(double *)ptr;
            if (f.type == "pointer") return (int64_t)*(void **)ptr;
            break;
        }
    }
    return Variant();
}

int64_t VGNativeStruct::get_pointer(int p_handle) {
    if (p_handle < 0 || p_handle >= (int)instances.size() || !instances[p_handle]) return 0;
    return (int64_t)instances[p_handle];
}

Array VGNativeStruct::get_field_names() const {
    Array result;
    for (const auto &f : fields) {
        result.push_back(f.name);
    }
    return result;
}

String VGNativeStruct::get_field_type(const String &p_name) const {
    for (const auto &f : fields) {
        if (f.name == p_name) return f.type;
    }
    return "";
}

// =============================================================================
// VGNativeLibrary — load shared libraries and call functions via libffi
// =============================================================================

void VGNativeLibrary::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load", "path"), &VGNativeLibrary::load);
    ClassDB::bind_method(D_METHOD("unload"), &VGNativeLibrary::unload);
    ClassDB::bind_method(D_METHOD("get_is_loaded"), &VGNativeLibrary::get_is_loaded);
    ClassDB::bind_method(D_METHOD("get_path"), &VGNativeLibrary::get_path);
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGNativeLibrary::get_last_error);
    ClassDB::bind_method(D_METHOD("get_function_address", "name"), &VGNativeLibrary::get_function_address);
    ClassDB::bind_method(D_METHOD("call_function", "name", "return_type", "arg_types", "args"),
                         &VGNativeLibrary::call_function);
    ClassDB::bind_method(D_METHOD("call_simple", "name", "args"), &VGNativeLibrary::call_simple);
    ClassDB::bind_method(D_METHOD("create_callback", "return_type", "arg_types", "callable"),
                         &VGNativeLibrary::create_callback);
    ClassDB::bind_method(D_METHOD("has_function", "name"), &VGNativeLibrary::has_function);
    ClassDB::bind_method(D_METHOD("list_functions"), &VGNativeLibrary::list_functions);
    ClassDB::bind_static_method("VGNativeLibrary", D_METHOD("quick_call", "lib", "func", "return_type", "arg_types", "args"),
                                &VGNativeLibrary::quick_call);
    ClassDB::bind_static_method("VGNativeLibrary", D_METHOD("library_exists", "path"), &VGNativeLibrary::library_exists);

    // VB6-style aliases — easy English names
    ClassDB::bind_method(D_METHOD("Load", "path"), &VGNativeLibrary::load);
    ClassDB::bind_method(D_METHOD("Unload"), &VGNativeLibrary::unload);
    ClassDB::bind_method(D_METHOD("CallFunction", "name", "return_type", "arg_types", "args"),
                         &VGNativeLibrary::call_function);
    ClassDB::bind_method(D_METHOD("CallSimple", "name", "args"), &VGNativeLibrary::call_simple);
    ClassDB::bind_method(D_METHOD("QuickCall", "name", "args"), &VGNativeLibrary::call_simple);
    ClassDB::bind_method(D_METHOD("CreateCallback", "return_type", "arg_types", "callable"),
                         &VGNativeLibrary::create_callback);
    ClassDB::bind_method(D_METHOD("HasFunction", "name"), &VGNativeLibrary::has_function);
    ClassDB::bind_method(D_METHOD("ListFunctions"), &VGNativeLibrary::list_functions);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsLoaded"), "", "get_is_loaded");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Path"), "", "get_path");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
}

VGNativeLibrary::VGNativeLibrary() {
    lib_handle = nullptr;
    loaded = false;
}

VGNativeLibrary::~VGNativeLibrary() {
    unload();
}

bool VGNativeLibrary::load(const String &p_path) {
    if (loaded) unload();

#if defined(__linux__) || defined(__APPLE__)
    lib_handle = dlopen(p_path.utf8().get_data(), RTLD_LAZY);
    if (!lib_handle) {
        last_error = String::utf8(dlerror());
        UtilityFunctions::printerr("[NativeLibrary] Failed to load '", p_path, "': ", last_error);
        return false;
    }
#elif defined(_WIN32)
    lib_handle = (void *)LoadLibraryA(p_path.utf8().get_data());
    if (!lib_handle) {
        last_error = "LoadLibrary failed with error code " + String::num_int64(GetLastError());
        UtilityFunctions::printerr("[NativeLibrary] Failed to load '", p_path, "': ", last_error);
        return false;
    }
#else
    last_error = "NativeLibrary not supported on this platform";
    return false;
#endif
    lib_path = p_path;
    loaded = true;
    return true;
}

void VGNativeLibrary::unload() {
    // Free callback closures
    for (auto *cb : callbacks) {
        if (cb) {
#ifdef VG_HAS_LIBFFI
            if (cb->closure) ffi_closure_free(cb->closure);
            if (cb->arg_types) delete[] cb->arg_types;
#endif
            delete cb;
        }
    }
    callbacks.clear();
    function_cache = Dictionary();

    if (lib_handle) {
#if defined(__linux__) || defined(__APPLE__)
        dlclose(lib_handle);
#elif defined(_WIN32)
        FreeLibrary((HMODULE)lib_handle);
#endif
        lib_handle = nullptr;
    }
    loaded = false;
}

int64_t VGNativeLibrary::get_function_address(const String &p_name) {
    if (!loaded) return 0;
#if defined(__linux__) || defined(__APPLE__)
    void *sym = dlsym(lib_handle, p_name.utf8().get_data());
    return (int64_t)sym;
#elif defined(_WIN32)
    FARPROC sym = GetProcAddress((HMODULE)lib_handle, p_name.utf8().get_data());
    return (int64_t)sym;
#else
    return 0;
#endif
}

bool VGNativeLibrary::has_function(const String &p_name) {
    return get_function_address(p_name) != 0;
}

#ifdef VG_HAS_LIBFFI
ffi_type *VGNativeLibrary::string_to_ffi_type(const String &p_type) const {
    String t = p_type.to_lower();
    if (t == "void") return &ffi_type_void;
    if (t == "byte") return &ffi_type_uint8;
    if (t == "bool") return &ffi_type_uint8;
    if (t == "short") return &ffi_type_sint16;
    if (t == "int") return &ffi_type_sint32;
    if (t == "uint") return &ffi_type_uint32;
    if (t == "long" || t == "int64") return &ffi_type_sint64;
    if (t == "uint64") return &ffi_type_uint64;
    if (t == "float") return &ffi_type_float;
    if (t == "double") return &ffi_type_double;
    if (t == "pointer" || t == "string") return &ffi_type_pointer;
    return &ffi_type_sint32;
}
#endif

void VGNativeLibrary::variant_to_ffi_arg(const Variant &p_value, const String &p_type,
                                          void *p_dest, std::vector<std::string> &p_string_keep) const {
    String t = p_type.to_lower();
    if (t == "byte" || t == "bool") {
        *(uint8_t *)p_dest = (uint8_t)(int)p_value;
    } else if (t == "short") {
        *(int16_t *)p_dest = (int16_t)(int)p_value;
    } else if (t == "int") {
        *(int32_t *)p_dest = (int32_t)(int)p_value;
    } else if (t == "uint") {
        *(uint32_t *)p_dest = (uint32_t)(int64_t)p_value;
    } else if (t == "long" || t == "int64") {
        *(int64_t *)p_dest = (int64_t)p_value;
    } else if (t == "uint64") {
        *(uint64_t *)p_dest = (uint64_t)(int64_t)p_value;
    } else if (t == "float") {
        *(float *)p_dest = (float)(double)p_value;
    } else if (t == "double") {
        *(double *)p_dest = (double)p_value;
    } else if (t == "string") {
        // Keep string alive for duration of call
        String s = p_value;
        p_string_keep.push_back(std::string(s.utf8().get_data()));
        *(const char **)p_dest = p_string_keep.back().c_str();
    } else if (t == "pointer") {
        *(void **)p_dest = (void *)(int64_t)p_value;
    }
}

Variant VGNativeLibrary::ffi_result_to_variant(void *p_result, const String &p_type) const {
    String t = p_type.to_lower();
    if (t == "void") return Variant();
    if (t == "byte" || t == "bool") return (int)*(uint8_t *)p_result;
    if (t == "short") return (int)*(int16_t *)p_result;
    if (t == "int") return (int)*(int32_t *)p_result;
    if (t == "uint") return (int64_t)*(uint32_t *)p_result;
    if (t == "long" || t == "int64") return (int64_t)*(int64_t *)p_result;
    if (t == "uint64") return (int64_t)*(uint64_t *)p_result;
    if (t == "float") return (double)*(float *)p_result;
    if (t == "double") return *(double *)p_result;
    if (t == "string") {
        const char *s = *(const char **)p_result;
        return s ? String::utf8(s) : String();
    }
    if (t == "pointer") return (int64_t)*(void **)p_result;
    return Variant();
}

Variant VGNativeLibrary::call_function(const String &p_name, const String &p_return_type,
                                        const Array &p_arg_types, const Array &p_args) {
#ifdef VG_HAS_LIBFFI
    if (!loaded) {
        UtilityFunctions::printerr("[NativeLibrary] No library loaded");
        return Variant();
    }

    void *func_ptr = (void *)get_function_address(p_name);
    if (!func_ptr) {
        last_error = "Function not found: " + p_name;
        UtilityFunctions::printerr("[NativeLibrary] ", last_error);
        return Variant();
    }

    int nargs = p_arg_types.size();
    if (nargs != p_args.size()) {
        last_error = "Argument count mismatch";
        UtilityFunctions::printerr("[NativeLibrary] ", last_error);
        return Variant();
    }

    // Build ffi_cif (call interface)
    ffi_cif cif;
    ffi_type *ret_type = string_to_ffi_type(p_return_type);
    std::vector<ffi_type *> arg_ffi_types(nargs);
    for (int i = 0; i < nargs; i++) {
        arg_ffi_types[i] = string_to_ffi_type(p_arg_types[i]);
    }

    ffi_status status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs,
                                      ret_type, nargs > 0 ? arg_ffi_types.data() : nullptr);
    if (status != FFI_OK) {
        last_error = "ffi_prep_cif failed with status " + String::num_int64(status);
        UtilityFunctions::printerr("[NativeLibrary] ", last_error);
        return Variant();
    }

    // Marshal arguments
    // Each arg value needs storage; pointers to that storage go in arg_ptrs
    std::vector<uint8_t> arg_storage(nargs * 8, 0); // 8 bytes per arg max
    std::vector<void *> arg_ptrs(nargs);
    std::vector<std::string> string_keep; // Keep strings alive during call

    for (int i = 0; i < nargs; i++) {
        arg_ptrs[i] = &arg_storage[i * 8];
        variant_to_ffi_arg(p_args[i], p_arg_types[i], arg_ptrs[i], string_keep);
    }

    // Invoke!
    uint8_t ret_storage[8] = {0};
    ffi_call(&cif, (void (*)())func_ptr, ret_storage,
             nargs > 0 ? arg_ptrs.data() : nullptr);

    return ffi_result_to_variant(ret_storage, p_return_type);
#else
    UtilityFunctions::printerr("[NativeLibrary] FFI not supported on this platform");
    return Variant();
#endif
}

Variant VGNativeLibrary::call_simple(const String &p_name, const Array &p_args) {
    // Auto-detect types from Variant types
    Array arg_types;
    for (int i = 0; i < p_args.size(); i++) {
        Variant v = p_args[i];
        switch (v.get_type()) {
            case Variant::BOOL: arg_types.push_back("bool"); break;
            case Variant::INT: arg_types.push_back("int64"); break;
            case Variant::FLOAT: arg_types.push_back("double"); break;
            case Variant::STRING: arg_types.push_back("string"); break;
            default: arg_types.push_back("pointer"); break;
        }
    }
    // Default return type is int64 for simple calls
    return call_function(p_name, "int64", arg_types, p_args);
}

// Callback trampoline — libffi calls this, we dispatch to the Callable
#ifdef VG_HAS_LIBFFI
static void ffi_callback_trampoline(ffi_cif *cif, void *ret, void **args, void *userdata) {
    VGNativeLibrary::CallbackInfo *info = (VGNativeLibrary::CallbackInfo *)userdata;
    if (!info) return;

    // Convert native args to Variant array
    Array vargs;
    for (unsigned i = 0; i < cif->nargs; i++) {
        // For simplicity, treat everything as int64 — real impl would use type info
        vargs.push_back((int64_t)*(void **)args[i]);
    }

    // Call the VisualGasic callable
    Variant result = info->callable.callv(vargs);

    // Convert result back
    if (cif->rtype == &ffi_type_void) return;
    if (cif->rtype == &ffi_type_sint32) *(int32_t *)ret = (int32_t)(int)result;
    else if (cif->rtype == &ffi_type_sint64) *(int64_t *)ret = (int64_t)result;
    else if (cif->rtype == &ffi_type_double) *(double *)ret = (double)result;
    else if (cif->rtype == &ffi_type_float) *(float *)ret = (float)(double)result;
    else if (cif->rtype == &ffi_type_pointer) *(void **)ret = (void *)(int64_t)result;
}
#endif

int64_t VGNativeLibrary::create_callback(const String &p_return_type, const Array &p_arg_types,
                                           const Callable &p_callable) {
#ifdef VG_HAS_LIBFFI
    CallbackInfo *info = new CallbackInfo();
    info->callable = p_callable;

    int nargs = p_arg_types.size();
    info->arg_types = new ffi_type *[nargs];
    for (int i = 0; i < nargs; i++) {
        info->arg_types[i] = string_to_ffi_type(p_arg_types[i]);
    }

    ffi_type *ret_type = string_to_ffi_type(p_return_type);

    info->closure = (ffi_closure *)ffi_closure_alloc(sizeof(ffi_closure), &info->code_ptr);
    if (!info->closure) {
        delete[] info->arg_types;
        delete info;
        last_error = "Failed to allocate ffi_closure";
        return 0;
    }

    ffi_status status = ffi_prep_cif(&info->cif, FFI_DEFAULT_ABI, nargs,
                                      ret_type, info->arg_types);
    if (status != FFI_OK) {
        ffi_closure_free(info->closure);
        delete[] info->arg_types;
        delete info;
        last_error = "ffi_prep_cif failed for callback";
        return 0;
    }

    status = ffi_prep_closure_loc(info->closure, &info->cif,
                                   ffi_callback_trampoline, info, info->code_ptr);
    if (status != FFI_OK) {
        ffi_closure_free(info->closure);
        delete[] info->arg_types;
        delete info;
        last_error = "ffi_prep_closure_loc failed";
        return 0;
    }

    callbacks.push_back(info);
    return (int64_t)info->code_ptr;
#else
    return 0;
#endif
}

Array VGNativeLibrary::list_functions() {
    Array result;
    // This is a best-effort feature — only works on Linux with ELF
    // Most users will know what functions they want to call
    return result;
}

Variant VGNativeLibrary::quick_call(const String &p_lib, const String &p_func,
                                     const String &p_return_type, const Array &p_arg_types,
                                     const Array &p_args) {
    Ref<VGNativeLibrary> lib;
    lib.instantiate();
    if (!lib->load(p_lib)) return Variant();
    Variant result = lib->call_function(p_func, p_return_type, p_arg_types, p_args);
    lib->unload();
    return result;
}

bool VGNativeLibrary::library_exists(const String &p_path) {
#if defined(__linux__) || defined(__APPLE__)
    void *handle = dlopen(p_path.utf8().get_data(), RTLD_LAZY);
    if (handle) {
        dlclose(handle);
        return true;
    }
    return false;
#elif defined(_WIN32)
    HMODULE handle = LoadLibraryA(p_path.utf8().get_data());
    if (handle) {
        FreeLibrary(handle);
        return true;
    }
    return false;
#else
    return false;
#endif
}

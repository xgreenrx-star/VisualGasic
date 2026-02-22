#ifndef VISUAL_GASIC_FFI_H
#define VISUAL_GASIC_FFI_H

// VGNativeCall — Full FFI (Foreign Function Interface) for calling ANY native library
// Uses libffi on Linux/macOS, LoadLibrary+GetProcAddress on Windows
// This is the equivalent of C# P/Invoke or VB6 Declare Function — but cross-platform.
//
// Usage in VisualGasic:
//   ' Load a shared library
//   Dim lib As New NativeLibrary
//   lib.Load "libm.so.6"                         ' Linux
//   lib.Load "msvcrt.dll"                         ' Windows
//
//   ' Call a function directly
//   Dim result As Double
//   result = lib.CallFunction("sqrt", "double", Array("double"), Array(144.0))
//   Print result  ' → 12.0
//
//   ' Define a struct (User-Defined Type for FFI)
//   Dim layout As New NativeStruct
//   layout.AddField "x", "int"
//   layout.AddField "y", "int"
//   layout.AddField "width", "int"
//   layout.AddField "height", "int"
//
//   ' Create an instance and fill it
//   Dim rect As Variant
//   rect = layout.Create()
//   layout.SetField rect, "x", 10
//   layout.SetField rect, "y", 20
//   layout.SetField rect, "width", 800
//   layout.SetField rect, "height", 600
//
//   ' Pass struct pointer to native function
//   lib.CallFunction "GetWindowRect", "int", Array("pointer", "pointer"), _
//                    Array(hWnd, layout.GetPointer(rect))
//
//   ' Read back struct values
//   Print layout.GetField(rect, "width")   ' → 800
//
//   ' Register a callback for native code to call back into VG
//   Dim cb As Variant
//   cb = lib.CreateCallback("void", Array("int", "string"), AddressOf MyHandler)
//
// Supported FFI types:
//   "void", "byte", "short", "int", "long", "float", "double",
//   "string", "pointer", "bool", "int64", "uint", "uint64"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <vector>
#include <string>

#ifdef __linux__
#include <dlfcn.h>
#ifdef VG_HAS_LIBFFI
#include <ffi.h>
#endif
#elif defined(__APPLE__)
#include <dlfcn.h>
#ifdef VG_HAS_LIBFFI
#include <ffi/ffi.h>
#endif
#elif defined(_WIN32)
#include <windows.h>
#ifdef VG_HAS_LIBFFI
// On Windows we use a bundled or system libffi
#include <ffi.h>
#endif
#endif

using namespace godot;

// ─── NativeStruct: define and manipulate C struct layouts ───────────────────
class VGNativeStruct : public RefCounted {
    GDCLASS(VGNativeStruct, RefCounted);

    struct FieldDef {
        String name;
        String type;       // "int", "double", "string", "pointer", etc.
        int offset;
        int size;
        int alignment;
    };

    std::vector<FieldDef> fields;
    int total_size;
    int total_alignment;
    bool finalized;

    // Allocated instances (raw memory)
    std::vector<uint8_t *> instances;

    int get_type_size(const String &p_type) const;
    int get_type_alignment(const String &p_type) const;
#ifdef VG_HAS_LIBFFI
    ffi_type *get_ffi_type(const String &p_type) const;
#endif
    void finalize_layout();

protected:
    static void _bind_methods();

public:
    VGNativeStruct();
    ~VGNativeStruct();

    // Define the struct layout
    void add_field(const String &p_name, const String &p_type);

    // Create an instance (returns an index handle)
    int create();
    void destroy(int p_handle);

    // Field access
    void set_field(int p_handle, const String &p_name, const Variant &p_value);
    Variant get_field(int p_handle, const String &p_name);

    // Raw pointer for passing to native functions
    int64_t get_pointer(int p_handle);

    // Introspection
    int get_size() const { return total_size; }
    int get_field_count() const { return (int)fields.size(); }
    Array get_field_names() const;
    String get_field_type(const String &p_name) const;
};

// ─── NativeLibrary: load shared libraries and call functions ────────────────
class VGNativeLibrary : public RefCounted {
    GDCLASS(VGNativeLibrary, RefCounted);

    void *lib_handle;
    String lib_path;
    String last_error;
    bool loaded;

    // Cached function pointers
    Dictionary function_cache;

    // Callback trampolines (prevent GC of closures bound to native code)
public:
#ifdef VG_HAS_LIBFFI
    struct CallbackInfo {
        ffi_closure *closure;
        ffi_cif cif;
        ffi_type **arg_types;
        void *code_ptr;
        Callable callable;
    };
#else
    struct CallbackInfo {
        void *code_ptr;
        Callable callable;
    };
#endif
private:
    std::vector<CallbackInfo *> callbacks;

#ifdef VG_HAS_LIBFFI
    ffi_type *string_to_ffi_type(const String &p_type) const;
#endif
    void variant_to_ffi_arg(const Variant &p_value, const String &p_type, void *p_dest, std::vector<std::string> &p_string_keep) const;
    Variant ffi_result_to_variant(void *p_result, const String &p_type) const;

protected:
    static void _bind_methods();

public:
    VGNativeLibrary();
    ~VGNativeLibrary();

    // Library management
    bool load(const String &p_path);
    void unload();
    bool get_is_loaded() const { return loaded; }
    String get_path() const { return lib_path; }
    String get_last_error() const { return last_error; }

    // Get a raw function address (for advanced use)
    int64_t get_function_address(const String &p_name);

    // Call a native function with full type info
    // return_type: "void", "int", "double", "string", "pointer", etc.
    // arg_types: Array of type strings
    // args: Array of Variant values
    Variant call_function(const String &p_name, const String &p_return_type,
                          const Array &p_arg_types, const Array &p_args);

    // Convenience: call with auto-detected types (less safe, simpler syntax)
    Variant call_simple(const String &p_name, const Array &p_args);

    // Create a callback closure that native code can call
    // Returns a pointer (as int64) that can be passed to native functions
    int64_t create_callback(const String &p_return_type, const Array &p_arg_types,
                            const Callable &p_callable);

    // Check if a function symbol exists
    bool has_function(const String &p_name);

    // List exported symbols (Linux only, reads ELF)
    Array list_functions();

    // Static convenience: quick one-shot call
    static Variant quick_call(const String &p_lib, const String &p_func,
                              const String &p_return_type, const Array &p_arg_types,
                              const Array &p_args);

    // Static: check if a library can be loaded
    static bool library_exists(const String &p_path);
};

#endif // VISUAL_GASIC_FFI_H

#include <gdextension_interface.h>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <cstring>
#include <string>
#include <iostream>
#include <dlfcn.h>

#include <gdextension_interface.h>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <cstring>
#include <string>
#include <iostream>
#include <dlfcn.h>

extern "C" void godot_cpp_init_variant_bindings();

using namespace godot;
using namespace godot::internal;

// Structure matching godot::String's private _MethodBindings
struct _StringMethodBindings {
    void *from_variant_constructor;
    GDExtensionPtrConstructor constructor_0;
    GDExtensionPtrConstructor constructor_1;
    GDExtensionPtrConstructor constructor_2;
    GDExtensionPtrConstructor constructor_3;
    GDExtensionPtrDestructor destructor;
};

// Directly reference the mangled C++ symbol for String::_method_bindings
extern _StringMethodBindings _ZN5godot6String16_method_bindingsE;

extern "C" void stub_string_new_with_latin1_chars(GDExtensionUninitializedStringPtr r_dest, const char *p_contents) {
    // Store a pointer to a heap-allocated std::string in the native memory area.
    // We assume the native area is at least pointer-sized.
    std::string *s = new std::string(p_contents ? p_contents : "");
    void **slot = (void**)r_dest;
    *slot = (void*)s;
}

extern "C" void stub_string_new_with_latin1_chars_and_len(GDExtensionUninitializedStringPtr r_dest, const char *p_contents, GDExtensionInt p_size) {
    std::string *s = new std::string(p_contents ? std::string(p_contents, (size_t)p_size) : std::string());
    void **slot = (void**)r_dest;
    *slot = (void*)s;
}

extern "C" GDExtensionInt stub_string_new_with_utf8_chars_and_len2(GDExtensionUninitializedStringPtr r_dest, const char *p_contents, GDExtensionInt p_size) {
    std::string *s = new std::string(p_contents ? std::string(p_contents, (size_t)p_size) : std::string());
    void **slot = (void**)r_dest;
    *slot = (void*)s;
    return (GDExtensionInt)s->size();
}

extern "C" GDExtensionInt stub_string_to_utf8_chars(GDExtensionConstStringPtr p_self, char *r_ret, GDExtensionInt p_size) {
    void *vp = nullptr;
    // p_self points to the native memory area where we stored a pointer to std::string
    vp = *((void**)p_self);
    if (!vp) return 0;
    std::string *s = (std::string*)vp;
    GDExtensionInt len = (GDExtensionInt)s->size();
    if (r_ret && p_size > 0) {
        GDExtensionInt copylen = p_size - 1; // leave room for null
        if (copylen > len) copylen = len;
        memcpy(r_ret, s->c_str(), (size_t)copylen);
        r_ret[copylen] = '\0';
    }
    return len;
}

// Minimal constructor and destructor stubs for String's builtin ptr constructor/destructor
extern "C" void stub_string_constructor_default(GDExtensionUninitializedTypePtr p_base, const GDExtensionConstTypePtr *p_args) {
    // Initialize as empty std::string
    std::string *s = new std::string();
    void **slot = (void**)p_base;
    *slot = (void*)s;
}

extern "C" void stub_string_constructor_copy(GDExtensionUninitializedTypePtr p_base, const GDExtensionConstTypePtr *p_args) {
    // p_args[0] points to a native area containing a pointer to std::string
    if (!p_args || !p_args[0]) { stub_string_constructor_default(p_base, p_args); return; }
    void *vp = *((void**)p_args[0]);
    std::string *src = (std::string*)vp;
    if (!src) { stub_string_constructor_default(p_base, p_args); return; }
    std::string *s = new std::string(*src);
    void **slot = (void**)p_base;
    *slot = (void*)s;
}

extern "C" void stub_string_destructor(GDExtensionTypePtr p_base) {
    if (!p_base) return;
    void *vp = *((void**)p_base);
    if (vp) {
        std::string *s = (std::string*)vp;
        delete s;
        *((void**)p_base) = nullptr;
    }
}

// Helper to return constructor pointers for minimal types we stub.
extern "C" GDExtensionPtrConstructor stub_variant_get_ptr_constructor(GDExtensionVariantType p_type, int p_index) {
    if (p_type == GDEXTENSION_VARIANT_TYPE_STRING) {
        if (p_index == 0) return (GDExtensionPtrConstructor)stub_string_constructor_default;
        if (p_index == 1) return (GDExtensionPtrConstructor)stub_string_constructor_copy;
    }
    return nullptr;
}

extern "C" GDExtensionPtrDestructor stub_variant_get_ptr_destructor(GDExtensionVariantType p_type) {
    if (p_type == GDEXTENSION_VARIANT_TYPE_STRING) return (GDExtensionPtrDestructor)stub_string_destructor;
    return nullptr;
}

// Stub for get_variant_from_type_constructor - returns constructors for supported types
extern "C" void stub_string_to_variant_constructor(GDExtensionUninitializedVariantPtr r_dest, GDExtensionTypePtr p_src) {
    // Set type to STRING (type ID 4) and copy the pointer
    memset(r_dest, 0, 24);
    *(uint8_t*)r_dest = GDEXTENSION_VARIANT_TYPE_STRING;
    // Copy the String data (next 8 bytes after type byte)
    memcpy(((uint8_t*)r_dest) + 8, p_src, 8);
}

extern "C" GDExtensionVariantFromTypeConstructorFunc stub_get_variant_from_type_constructor(GDExtensionVariantType p_type) {
    if (p_type == GDEXTENSION_VARIANT_TYPE_STRING) {
        return (GDExtensionVariantFromTypeConstructorFunc)stub_string_to_variant_constructor;
    }
    return nullptr;
}


// Stub for get_variant_to_type_constructor - returns nullptr for all types
extern "C" GDExtensionTypeFromVariantConstructorFunc stub_get_variant_to_type_constructor(GDExtensionVariantType p_type) {
    return nullptr;
}

// Stub for variant_get_ptr_internal_getter - returns nullptr for all types
extern "C" GDExtensionVariantGetInternalPtrFunc stub_variant_get_ptr_internal_getter(GDExtensionVariantType p_type) {
    return nullptr;
}

// Stub for memory allocation - use standard malloc/realloc/free
extern "C" void* stub_mem_alloc(size_t p_bytes) {
    return malloc(p_bytes);
}

extern "C" void* stub_mem_realloc(void *p_ptr, size_t p_bytes) {
    return realloc(p_ptr, p_bytes);
}

extern "C" void stub_mem_free(void *p_ptr) {
    free(p_ptr);
}

// Stub for variant creation
extern "C" void stub_variant_new_nil(GDExtensionUninitializedVariantPtr r_dest) {
    // Variant is 24 bytes, initialize to zero (NIL variant)
    memset(r_dest, 0, 24);
}

extern "C" void stub_variant_new_copy(GDExtensionUninitializedVariantPtr r_dest, GDExtensionConstVariantPtr p_src) {
    // Simple copy of 24 bytes
    memcpy(r_dest, p_src, 24);
}

extern "C" void stub_variant_destroy(GDExtensionVariantPtr p_self) {
    // No-op for now
}

extern "C" GDExtensionVariantType stub_variant_get_type(GDExtensionConstVariantPtr p_self) {
    // First byte of Variant stores the type
    if (!p_self) return GDEXTENSION_VARIANT_TYPE_NIL;
    return (GDExtensionVariantType)(*(uint8_t*)p_self);
}



// Install the stub implementations into godot::internal function pointers.
void install_gde_stubs() {
    gdextension_interface_string_new_with_latin1_chars = stub_string_new_with_latin1_chars;
    gdextension_interface_string_new_with_latin1_chars_and_len = stub_string_new_with_latin1_chars_and_len;
    gdextension_interface_string_new_with_utf8_chars_and_len2 = stub_string_new_with_utf8_chars_and_len2;
    gdextension_interface_string_to_utf8_chars = stub_string_to_utf8_chars;

    // Wire minimal variant constructor/destructor lookups for String so godot::String's
    // builtin constructors/destructor are available in standalone tests.
    gdextension_interface_variant_get_ptr_constructor = stub_variant_get_ptr_constructor;
    gdextension_interface_variant_get_ptr_destructor = stub_variant_get_ptr_destructor;
    gdextension_interface_get_variant_from_type_constructor = stub_get_variant_from_type_constructor;
    gdextension_interface_get_variant_to_type_constructor = stub_get_variant_to_type_constructor;
    gdextension_interface_variant_get_ptr_internal_getter = stub_variant_get_ptr_internal_getter;
    gdextension_interface_mem_alloc = stub_mem_alloc;
    gdextension_interface_mem_realloc = stub_mem_realloc;
    gdextension_interface_mem_free = stub_mem_free;
    gdextension_interface_variant_new_nil = stub_variant_new_nil;
    gdextension_interface_variant_new_copy = stub_variant_new_copy;
    gdextension_interface_variant_destroy = stub_variant_destroy;
    gdextension_interface_variant_get_type = stub_variant_get_type;


    // Call init_variant_bindings to initialize the Variant type constructors
    // This will call our stub_get_variant_from_type_constructor for each type
    godot_cpp_init_variant_bindings();

    // Directly patch String::_method_bindings BEFORE any String objects are created
    _StringMethodBindings *mb = &_ZN5godot6String16_method_bindingsE;
    mb->constructor_0 = (GDExtensionPtrConstructor)stub_string_constructor_default;
    mb->constructor_1 = (GDExtensionPtrConstructor)stub_string_constructor_copy;
    mb->destructor = (GDExtensionPtrDestructor)stub_string_destructor;
    std::cerr << "✓ Patched String::_method_bindings successfully\n";
}

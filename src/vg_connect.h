#ifndef VG_CONNECT_H
#define VG_CONNECT_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/core/error_macros.hpp>

class VisualGasicInstance;

namespace VisualGasicConnect {
	godot::Callable make_handler(VisualGasicInstance *instance, const godot::Variant &handler, const godot::Array &bound_args);

	godot::Dictionary lookup_lambda(int64_t p_id);

	godot::Variant builtin_connect(VisualGasicInstance *instance, const godot::Array &args);
	godot::Variant builtin_object_connect(VisualGasicInstance *instance, godot::Object *source, const godot::Array &args);
	godot::Variant builtin_disconnect(VisualGasicInstance *instance, const godot::Array &args);
	godot::Variant builtin_object_disconnect(VisualGasicInstance *instance, godot::Object *source, const godot::Array &args);
}

#endif // VG_CONNECT_H

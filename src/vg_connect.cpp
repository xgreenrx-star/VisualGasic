#include "vg_connect.h"
#include "visual_gasic_instance.h"

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

HashMap<uint64_t, Dictionary> vg_connect_lambdas;

bool is_vg_lambda(const Variant &v) {
	if (v.get_type() != Variant::DICTIONARY) {
		return false;
	}
	Dictionary d = v;
	return d.has("__vg_lambda") && (bool)d["__vg_lambda"];
}

uint64_t lambda_id_from_dict(const Dictionary &d) {
	if (!d.has("__vg_ast_ptr")) {
		return 0;
	}
	uint64_t id = (uint64_t)d["__vg_ast_ptr"];
	return id != 0 ? id : 1;
}

Error do_connect(Object *source, const Callable &callable, const String &signal) {
	if (!source) {
		return ERR_INVALID_PARAMETER;
	}
	if (!source->has_signal(signal)) {
		UtilityFunctions::print("Runtime Warning: Signal '", signal, "' not found on object");
		return ERR_UNAVAILABLE;
	}
	if (!callable.is_valid()) {
		UtilityFunctions::print("Runtime Warning: Connect handler is not a valid Callable");
		return ERR_INVALID_PARAMETER;
	}
	if (source->is_connected(signal, callable)) {
		return OK;
	}
	return source->connect(signal, callable);
}

Error do_disconnect(Object *source, const Callable &callable, const String &signal) {
	if (!source) {
		return ERR_INVALID_PARAMETER;
	}
	if (source->is_connected(signal, callable)) {
		source->disconnect(signal, callable);
	}
	return OK;
}

} // namespace

namespace VisualGasicConnect {

Dictionary lookup_lambda(int64_t p_id) {
	uint64_t id = (uint64_t)p_id;
	if (!vg_connect_lambdas.has(id)) {
		return Dictionary();
	}
	return vg_connect_lambdas[id];
}

Callable make_handler(VisualGasicInstance *instance, const Variant &handler, const Array &bound_args) {
	Object *owner = instance ? instance->get_owner() : nullptr;
	if (!owner) {
		return Callable();
	}

	// Lambda Dictionary cannot be a Godot bind argument: Object.connect() with a
	// Dictionary bind aborts the VG bytecode frame after returning OK.
	// Store the dict and bind a scalar id instead (same as Callable.bind ints).
	if (is_vg_lambda(handler)) {
		Dictionary d = ((Dictionary)handler).duplicate();
		uint64_t id = lambda_id_from_dict(d);
		vg_connect_lambdas[id] = d;
		Array binds = bound_args.duplicate();
		binds.push_back(String::num_uint64(id));
		binds.push_back(String("__vglambda"));
		return Callable(owner, StringName("_OnSignal")).bindv(binds);
	}

	if (handler.get_type() == Variant::CALLABLE) {
		Callable inner = handler;
		if (bound_args.is_empty()) {
			return inner;
		}
		return inner.bindv(bound_args);
	}

	String method;
	if (handler.get_type() == Variant::STRING || handler.get_type() == Variant::STRING_NAME) {
		method = handler;
	} else {
		method = String(handler);
	}
	Callable cb(owner, StringName(method));
	if (bound_args.is_empty()) {
		return cb;
	}
	return cb.bindv(bound_args);
}

Variant builtin_connect(VisualGasicInstance *instance, const Array &args) {
	Object *owner = instance ? instance->get_owner() : nullptr;
	if (!owner || args.size() < 2) {
		return (int64_t)ERR_INVALID_PARAMETER;
	}
	Object *source = nullptr;
	String signal;
	Variant handler;
	Array bound;
	if (args[0].get_type() == Variant::OBJECT && args.size() >= 3) {
		source = args[0];
		signal = args[1];
		handler = args[2];
		for (int i = 3; i < args.size(); i++) {
			bound.push_back(args[i]);
		}
	} else {
		source = owner;
		signal = args[0];
		handler = args[1];
		for (int i = 2; i < args.size(); i++) {
			bound.push_back(args[i]);
		}
	}
	Callable cb = make_handler(instance, handler, bound);
	return (int64_t)do_connect(source, cb, signal);
}

Variant builtin_object_connect(VisualGasicInstance *instance, Object *source, const Array &args) {
	if (!source || args.size() < 2) {
		return (int64_t)ERR_INVALID_PARAMETER;
	}
	String signal = args[0];
	Variant handler = args[1];
	Array bound;
	for (int i = 2; i < args.size(); i++) {
		bound.push_back(args[i]);
	}
	Callable cb = make_handler(instance, handler, bound);
	return (int64_t)do_connect(source, cb, signal);
}

Variant builtin_disconnect(VisualGasicInstance *instance, const Array &args) {
	Object *owner = instance ? instance->get_owner() : nullptr;
	if (!owner || args.size() < 2) {
		return (int64_t)0;
	}
	Object *source = nullptr;
	String signal;
	Variant handler;
	Array bound;
	if (args[0].get_type() == Variant::OBJECT && args.size() >= 3) {
		source = args[0];
		signal = args[1];
		handler = args[2];
		for (int i = 3; i < args.size(); i++) {
			bound.push_back(args[i]);
		}
	} else {
		source = owner;
		signal = args[0];
		handler = args[1];
		for (int i = 2; i < args.size(); i++) {
			bound.push_back(args[i]);
		}
	}
	Callable cb = make_handler(instance, handler, bound);
	return (int64_t)do_disconnect(source, cb, signal);
}

Variant builtin_object_disconnect(VisualGasicInstance *instance, Object *source, const Array &args) {
	if (!source || args.size() < 2) {
		return (int64_t)0;
	}
	String signal = args[0];
	Variant handler = args[1];
	Array bound;
	for (int i = 2; i < args.size(); i++) {
		bound.push_back(args[i]);
	}
	Callable cb = make_handler(instance, handler, bound);
	return (int64_t)do_disconnect(source, cb, signal);
}

} // namespace VisualGasicConnect

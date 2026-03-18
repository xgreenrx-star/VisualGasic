#ifndef VISUAL_GASIC_BUILTINS_H
#define VISUAL_GASIC_BUILTINS_H

#include "visual_gasic_instance.h"
#include "visual_gasic_ast.h"
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace VisualGasicBuiltins {
    // Called for statement-level calls (CallStatement)
    // Returns true if a builtin handled the call (r_found=true), and optionally writes a return value into r_ret.
    bool call_builtin(VisualGasicInstance *instance, const String &p_method, const Array &p_args, Variant &r_ret, bool &r_found);

    // Called for expression-level calls (CallExpression)
    Variant call_builtin_expr(VisualGasicInstance *instance, CallExpression *call, bool &r_handled);
    // Variant of call_builtin_expr that accepts pre-evaluated argument list.
    Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled);
    // Handle calls where the base is a simple variable name (eg. Clipboard.GetText)
    bool call_builtin_for_base_variable(VisualGasicInstance *instance, const String &p_base_name, const String &p_method, const Array &p_args, Variant &r_ret);
    // Handle calls where the base is an evaluated Variant (object) - returns true if handled and sets r_ret
    bool call_builtin_for_base_object(VisualGasicInstance *instance, const Variant &p_base, const String &p_method, const Array &p_args, Variant &r_ret);
    // Handle calls where the base is any Variant (dictionary, object, etc.)
    bool call_builtin_for_base_variant(VisualGasicInstance *instance, const Variant &p_base, const String &p_method, const Array &p_args, Variant &r_ret);

    // Native OS text-input dialog (zenity/kdialog on Linux).
    // Blocks until the user closes the dialog.  Returns entered text, or
    // empty string on cancel, or p_default if no dialog tool is available.
    String native_input_box(const String &p_prompt, const String &p_title, const String &p_default);
}

#endif // VISUAL_GASIC_BUILTINS_H

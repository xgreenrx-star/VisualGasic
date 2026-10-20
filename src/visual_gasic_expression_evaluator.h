#ifndef VISUAL_GASIC_EXPRESSION_EVALUATOR_H
#define VISUAL_GASIC_EXPRESSION_EVALUATOR_H

#include "visual_gasic_ast.h"
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;
using namespace VisualGasic;

// Forward declaration
class VisualGasicInstance;

class VisualGasicExpressionEvaluator {
public:
    // Context struct to provide access to variables, owner, etc.
    struct Context {
        Dictionary& variables;
        Object* owner;
        Dictionary& open_files;
        Ref<DirAccess>& current_dir;
        String& dir_pattern;
        bool& option_compare_text;
        Vector<Variant>& with_stack;
        VisualGasicInstance* instance; // For VG class instance member access
    };

    static Variant evaluate(ExpressionNode* expr, Context& ctx);
};

// Headless check for the immediate-window evaluator. Runs when
// VG_EXPR_EVAL_SELFTEST=1.
void vg_expression_evaluator_selftest();

#endif // VISUAL_GASIC_EXPRESSION_EVALUATOR_H

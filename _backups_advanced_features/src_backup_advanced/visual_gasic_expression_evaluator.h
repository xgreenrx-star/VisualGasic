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
        // Add more as needed
    };

    static Variant evaluate(ExpressionNode* expr, Context& ctx);
};

#endif // VISUAL_GASIC_EXPRESSION_EVALUATOR_H

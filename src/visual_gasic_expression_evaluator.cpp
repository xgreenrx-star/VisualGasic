#include "visual_gasic_expression_evaluator.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_builtins.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>


Variant VisualGasicExpressionEvaluator::evaluate(ExpressionNode* expr, Context& ctx) {
    if (!expr) return Variant();

    if (expr->type == ExpressionNode::EXPRESSION_IIF) {
        IIfNode* iif = (IIfNode*)expr;
        Variant cond = evaluate(iif->condition, ctx);
        if (cond.booleanize()) {
            return evaluate(iif->true_part, ctx);
        } else {
            return evaluate(iif->false_part, ctx);
        }
    }

    if (expr->type == ExpressionNode::WITH_CONTEXT) {
        if (ctx.with_stack.is_empty()) {
            // No error reporter in context, fallback to print
            UtilityFunctions::print("Invalid use of .Member outside With block");
            return Variant();
        }
        return ctx.with_stack[ctx.with_stack.size() - 1];
    }
    if (expr->type == ExpressionNode::LITERAL) {
        return ((LiteralNode*)expr)->value;
    }
    if (expr->type == ExpressionNode::ME) {
        if (!ctx.owner) return Variant();
        return ctx.owner;
    }
    if (expr->type == ExpressionNode::NEW) {
        NewNode* n = (NewNode*)expr;
        if (n->class_name.nocasecmp_to("MemoryBlock") == 0) {
            int size = 0;
            if (n->args.size() > 0) {
                Variant v = evaluate(n->args[0], ctx);
                size = (int)v;
            }
            PackedByteArray pba;
            pba.resize(size);
            return pba;
        }
        if (n->class_name.nocasecmp_to("Dictionary") == 0) {
            return Dictionary();
        }
        // Custom Structs or Types?
        // Check struct definitions
        // Not available in context, fallback to Variant()
        // Try Godot ClassDB
        if (ClassDB::class_exists(n->class_name)) {
            Object* obj = ClassDB::instantiate(n->class_name);
            if (obj) return obj;
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::VARIABLE) {
        String name = ((VariableNode*)expr)->name;
        if (name.nocasecmp_to("FreeFile") == 0) {
            for(int i=1; i<=255; i++) {
                if (!ctx.open_files.has(i)) return i;
            }
            UtilityFunctions::print("Too many files open");
            return 0;
        }
        if (name.nocasecmp_to("Godot") == 0) {
            return Engine::get_singleton();
        }
        if (ctx.variables.has(name)) return ctx.variables[name];
        if (ctx.owner) {
            Variant ret = ctx.owner->get(name);
            if (ret.get_type() != Variant::NIL) return ret;
            String snake = name.to_snake_case();
            ret = ctx.owner->get(snake);
            if (ret.get_type() != Variant::NIL) return ret;
        }
        if (ctx.owner) {
            Node* owner_node = Object::cast_to<Node>(ctx.owner);
            if (owner_node && owner_node->is_inside_tree()) {
                SceneTree *tree = owner_node->get_tree();
                if (tree) {
                    Node* root = tree->get_root();
                    if (root && root->has_node(name)) {
                        return root->get_node<Node>(name);
                    }
                }
            }
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::MEMBER_ACCESS) {
        MemberAccessNode* ma = (MemberAccessNode*)expr;
        
        // Color.White, Color.Red, etc. — named color constants
        if (ma->base_object->type == ExpressionNode::VARIABLE) {
            String base_name = ((VariableNode*)ma->base_object)->name;
            if (base_name == "Color") {
                return Color::named(ma->member_name);
            }
        }
        
        Variant base = evaluate(ma->base_object, ctx);
        
        // VG class instance (object ID is an integer)
        if (base.get_type() == Variant::INT && ctx.instance) {
            int obj_id = (int)base;
            Variant ret;
            if (ctx.instance->get_object_member(obj_id, ma->member_name, ret)) {
                return ret;
            }
        }
        
        if (base.get_type() == Variant::DICTIONARY) {
            Dictionary d = base;
            if (d.has(ma->member_name)) return d[ma->member_name];
        }
        bool valid = false;
        Variant ret = base.get_named(ma->member_name, valid);
        if (valid && (ret.get_type() != Variant::NIL || base.has_method(ma->member_name))) return ret;
        if (!valid) {
            ret = base.get_named(ma->member_name.to_lower(), valid);
            if (valid) return ret;
        }
        if (base.get_type() == Variant::OBJECT) {
            Object* obj = base;
            String prop_name = ma->member_name;
            if (obj) {
                if (obj->is_class("Node")) {
                    if (prop_name == "Caption") prop_name = "text";
                    if (obj->is_class("Timer")) {
                        if (prop_name == "Interval") {
                            return (double)obj->get("wait_time") * 1000.0;
                        }
                        if (prop_name == "Enabled") {
                            return !Object::cast_to<Timer>(obj)->is_stopped();
                        }
                    }
                    bool is_control = obj->is_class("Control");
                    bool is_2d = obj->is_class("Node2D");
                    bool is_range = obj->is_class("Range");
                    if (is_range) {
                        if (prop_name == "Min") return obj->get("min_value");
                        if (prop_name == "Max") return obj->get("max_value");
                        if (prop_name == "Value") return obj->get("value");
                    }
                    if (is_control || is_2d) {
                        if (prop_name == "Left") {
                            if (is_control) return Object::cast_to<Control>(obj)->get_position().x;
                            if (is_2d) return Object::cast_to<Node2D>(obj)->get_position().x;
                        }
                        if (prop_name == "Top") {
                            if (is_control) return Object::cast_to<Control>(obj)->get_position().y;
                            if (is_2d) return Object::cast_to<Node2D>(obj)->get_position().y;
                        }
                    }
                    if (is_control) {
                        if (prop_name == "Width") return Object::cast_to<Control>(obj)->get_size().x;
                        if (prop_name == "Height") return Object::cast_to<Control>(obj)->get_size().y;
                        if (prop_name == "Visible") return Object::cast_to<Control>(obj)->is_visible();
                        if (obj->is_class("Tree")) {
                            if (prop_name == "Rows") {
                                Tree *t = Object::cast_to<Tree>(obj);
                                return t->get_root() ? t->get_root()->get_child_count() : 0;
                            }
                            if (prop_name == "Cols") {
                                return Object::cast_to<Tree>(obj)->get_columns();
                            }
                        }
                    }
                }
            }
            if (obj) {
                Variant val = obj->get(prop_name);
                if (val.get_type() != Variant::NIL) return val;
                String snake = prop_name.to_snake_case();
                val = obj->get(snake);
                if (val.get_type() != Variant::NIL) return val;
            }
        }
        return Variant();
    }
    // Optional chaining  ?.  —  returns Nil if base is null instead of error
    if (expr->type == ExpressionNode::OPTIONAL_ACCESS) {
        OptionalAccessExpression* oa = (OptionalAccessExpression*)expr;
        Variant base = evaluate(oa->object_expression, ctx);
        if (base.get_type() == Variant::NIL) return Variant();  // Short-circuit: null?.anything == null
        // Otherwise behave like normal member access
        if (base.get_type() == Variant::DICTIONARY) {
            Dictionary d = base;
            if (d.has(oa->member_name)) return d[oa->member_name];
            return Variant();
        }
        bool valid = false;
        Variant ret = base.get_named(oa->member_name, valid);
        if (valid) return ret;
        ret = base.get_named(oa->member_name.to_lower(), valid);
        if (valid) return ret;
        if (base.get_type() == Variant::OBJECT) {
            Object* obj = base;
            if (obj) {
                Variant val = obj->get(oa->member_name);
                if (val.get_type() != Variant::NIL) return val;
                val = obj->get(oa->member_name.to_snake_case());
                if (val.get_type() != Variant::NIL) return val;
            }
        }
        return Variant();
    }
    // Lambda expression —  package as a callable Dictionary
    if (expr->type == ExpressionNode::LAMBDA) {
        // Return a Dictionary that wraps the lambda definition for the runtime to invoke
        LambdaNode* lam = (LambdaNode*)expr;
        Dictionary lambda_obj;
        lambda_obj["__vg_lambda"] = true;
        lambda_obj["__vg_is_arrow"] = lam->is_arrow;
        // Store parameter names
        Array param_names;
        for (int i = 0; i < lam->parameters.size(); i++) {
            param_names.push_back(lam->parameters[i].name);
        }
        lambda_obj["__vg_params"] = param_names;
        // Store pointer to the AST node for later execution (as integer)
        lambda_obj["__vg_ast_ptr"] = (uint64_t)lam;
        return lambda_obj;
    }
    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)expr;
        Variant base = evaluate(aa->base, ctx);
        if (base.get_type() == Variant::DICTIONARY) {
            Dictionary d = base;
            if (aa->indices.size() > 0) {
                Variant key = evaluate(aa->indices[0], ctx);
                if (d.has(key)) return d[key];
                return Variant();
            }
        }
        if (base.get_type() == Variant::ARRAY) {
            Variant container = base;
            for(int i=0; i<aa->indices.size(); i++) {
                if (container.get_type() != Variant::ARRAY) return Variant();
                Array arr = container;
                int idx = evaluate(aa->indices[i], ctx);
                if (idx >= 0 && idx < arr.size()) {
                    container = arr[idx];
                } else {
                    UtilityFunctions::print("Subscript out of range");
                    return Variant();
                }
            }
            return container;
        }
        // Function call fallback omitted for brevity
        return Variant();
    }
    if (expr->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)expr;
        
        // Check if it is an array access (variable with parentheses)
        if (!call->base_object && ctx.variables.has(call->method_name)) {
            Variant v = ctx.variables[call->method_name];
            
            if (v.get_type() == Variant::ARRAY) {
                // Multidimensional array read
                Variant current = v;
                for (int i = 0; i < call->arguments.size(); i++) {
                    if (current.get_type() != Variant::ARRAY) {
                        return Variant();
                    }
                    Array arr = current;
                    Variant idx_var = evaluate(call->arguments[i], ctx);
                    int idx = (int)idx_var;
                    if (idx >= 0 && idx < arr.size()) {
                        current = arr[idx];
                    } else {
                        UtilityFunctions::print("Array subscript out of range");
                        return Variant();
                    }
                }
                return current;
            }
            
            if (v.get_type() == Variant::DICTIONARY) {
                Dictionary d = v;
                if (call->arguments.size() == 1) {
                    Variant key = evaluate(call->arguments[0], ctx);
                    if (d.has(key)) return d[key];
                }
                return Variant();
            }
        }
        
        // For other EXPRESSION_CALL nodes with base_object, evaluate the base and dispatch
        if (call->base_object) {
            Variant base = evaluate(call->base_object, ctx);
            // Evaluate arguments
            Array args;
            for (int i = 0; i < call->arguments.size(); i++) {
                args.push_back(evaluate(call->arguments[i], ctx));
            }
            // Dispatch to builtin handler (handles Dictionary.Item, .Count, .Keys, etc.)
            Variant ret;
            if (ctx.instance && VisualGasicBuiltins::call_builtin_for_base_variant(ctx.instance, base, call->method_name, args, ret)) {
                return ret;
            }
            // Fallback: try Godot method call on object (with snake_case conversion)
            if (base.get_type() == Variant::OBJECT) {
                Object* obj = base;
                if (obj) {
                    if (obj->has_method(call->method_name)) {
                        return obj->callv(call->method_name, args);
                    }
                    String snake = call->method_name.to_snake_case();
                    if (obj->has_method(snake)) {
                        return obj->callv(snake, args);
                    }
                }
            }
            // base_object was set but method could not be dispatched —
            // delegate to the full evaluator which has detailed error reporting
            if (ctx.instance) {
                return ctx.instance->evaluate_expression_full(expr);
            }
            return Variant();
        }

        // For other EXPRESSION_CALL nodes, delegate to the full evaluator
        // which handles builtins (Int, Str, Mid, etc.) and user-defined functions.
        if (ctx.instance) {
            return ctx.instance->evaluate_expression_full(expr);
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        Variant val = evaluate(u->operand, ctx);
        if (u->op.nocasecmp_to("Not") == 0) {
            return !val.booleanize();
        }
        if (u->op == "-") {
            bool valid;
            Variant res;
            Variant::evaluate(Variant::OP_NEGATE, val, Variant(), res, valid);
            return res;
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* bin = (BinaryOpNode*)expr;
        if (bin->op.nocasecmp_to("AndAlso") == 0) {
            Variant l = evaluate(bin->left, ctx);
            if (!l.booleanize()) return false;
            return evaluate(bin->right, ctx).booleanize();
        }
        if (bin->op.nocasecmp_to("OrElse") == 0) {
            Variant l = evaluate(bin->left, ctx);
            if (l.booleanize()) return true;
            return evaluate(bin->right, ctx).booleanize();
        }
        // Null coalescing operator ??  —  short-circuit: skip right if left is non-null
        if (bin->op == "??") {
            Variant l = evaluate(bin->left, ctx);
            if (l.get_type() != Variant::NIL) return l;
            return evaluate(bin->right, ctx);
        }
        Variant l = evaluate(bin->left, ctx);
        Variant r = evaluate(bin->right, ctx);
        String op = bin->op;
        Variant result;
        bool valid;
        if (op == "&") {
            return String(l) + String(r);
        }
        if (op == "**") {
            return UtilityFunctions::pow(l, r);
        }
        if (op == "^") {
            return UtilityFunctions::pow(l, r);
        }
        if (op == "//") {
            double val = (double)l / (double)r;
            return floor(val);
        }
        if (op == "\\") {
            // Integer division
            int64_t li = (int64_t)l;
            int64_t ri = (int64_t)r;
            if (ri == 0) return 0; // Avoid division by zero
            return li / ri;
        }
        if (op.nocasecmp_to("Mod") == 0) {
            // Modulo operator
            int64_t li = (int64_t)l;
            int64_t ri = (int64_t)r;
            if (ri == 0) return 0; // Avoid division by zero
            return li % ri;
        }
        if (op.nocasecmp_to("And") == 0) return l.booleanize() && r.booleanize();
        if (op.nocasecmp_to("Or") == 0) return l.booleanize() || r.booleanize();
        if (op.nocasecmp_to("Xor") == 0) return l.booleanize() != r.booleanize();
        if (op.nocasecmp_to("Is") == 0) {
            bool valid;
            Variant res;
            Variant::evaluate(Variant::OP_EQUAL, l, r, res, valid);
            return res;
        }
        Variant::Operator v_op = Variant::OP_ADD;
        if (op == "+") v_op = Variant::OP_ADD;
        else if (op == "-") v_op = Variant::OP_SUBTRACT;
        else if (op == "*") v_op = Variant::OP_MULTIPLY;
        else if (op == "/") v_op = Variant::OP_DIVIDE;
        else if (op == "=") v_op = Variant::OP_EQUAL;
        else if (op == "<") v_op = Variant::OP_LESS;
        else if (op == ">") v_op = Variant::OP_GREATER;
        else if (op == "<=") v_op = Variant::OP_LESS_EQUAL;
        else if (op == ">=") v_op = Variant::OP_GREATER_EQUAL;
        else if (op == "<>") v_op = Variant::OP_NOT_EQUAL;
        else if (op == "!=") v_op = Variant::OP_NOT_EQUAL;
        Variant::evaluate(v_op, l, r, result, valid);
        return result;
    }
    return Variant();
}

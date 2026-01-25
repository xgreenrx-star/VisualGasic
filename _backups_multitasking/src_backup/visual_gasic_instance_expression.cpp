#include "visual_gasic_instance.h"
#include "visual_gasic_ast.h"
#include "visual_gasic_expression_evaluator.h"

Variant VisualGasicInstance::_evaluate_expression_impl(ExpressionNode* expr) {
	VisualGasicExpressionEvaluator::Context ctx{variables, owner, open_files, current_dir, dir_pattern, option_compare_text, with_stack};
	return VisualGasicExpressionEvaluator::evaluate(expr, ctx);
}

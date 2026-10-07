#include "visual_gasic_instance.h"
#include "visual_gasic_ast.h"

Variant VisualGasicInstance::_evaluate_expression_impl(ExpressionNode* expr) {
	return evaluate_expression(expr);
}

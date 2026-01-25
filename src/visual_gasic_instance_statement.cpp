#include "visual_gasic_instance.h"
#include "visual_gasic_ast.h"

void VisualGasicInstance::_execute_statement_impl(Statement* stmt) {
	if (!stmt) return;
	switch (stmt->type) {
		case STMT_ASSIGNMENT: {
			AssignmentStatement* a = static_cast<AssignmentStatement*>(stmt);
			Variant val = _evaluate_expression_impl(a->value);
			// Handle assignment target properly
			if (a->target) {
				assign_to_target(a->target, val);
			} else {
				// Fallback: no target specified
				raise_error("Assignment has no target");
			}
			break;
		}
		case STMT_CALL: {
			CallStatement* c = static_cast<CallStatement*>(stmt);
			bool found = false;
			Array args;
			for (auto* expr : c->arguments) {
				args.push_back(_evaluate_expression_impl(expr));
			}
			dispatch_builtin_call(c->method_name, args, found);
			break;
		}
		case STMT_IF: {
			IfStatement* i = static_cast<IfStatement*>(stmt);
			if (_evaluate_expression_impl(i->condition).booleanize()) {
				for (Statement* s : i->then_branch) _execute_statement_impl(s);
			} else {
				for (Statement* s : i->else_branch) _execute_statement_impl(s);
			}
			break;
		}
		case STMT_WHILE: {
			WhileStatement* w = static_cast<WhileStatement*>(stmt);
			while (_evaluate_expression_impl(w->condition).booleanize()) {
				for (Statement* s : w->body) _execute_statement_impl(s);
				if (error_state.mode == ErrorState::EXIT_DO) {
					error_state.mode = ErrorState::NONE;
					break;
				}
				if (error_state.mode == ErrorState::CONTINUE_DO || error_state.mode == ErrorState::CONTINUE_WHILE) {
					error_state.mode = ErrorState::NONE;
					continue;
				}
			}
			break;
		}
		case STMT_FOR: {
			ForStatement* f = static_cast<ForStatement*>(stmt);
			Variant start = _evaluate_expression_impl(f->from_val);
			Variant end = _evaluate_expression_impl(f->to_val);
			Variant step = f->step_val ? _evaluate_expression_impl(f->step_val) : Variant(1);
			if (start.get_type() == Variant::INT && end.get_type() == Variant::INT && step.get_type() == Variant::INT) {
				int64_t current = (int64_t)start;
				int64_t end_i = (int64_t)end;
				int64_t step_i = (int64_t)step;
				if (step_i == 0) step_i = 1;
				while (true) {
					bool cond = step_i > 0 ? (current <= end_i) : (current >= end_i);
					if (!cond) break;
					assign_variable(f->variable_name, current);
					for (Statement* s : f->body) _execute_statement_impl(s);
					if (error_state.mode == ErrorState::EXIT_FOR) {
						error_state.mode = ErrorState::NONE;
						break;
					}
					if (error_state.mode == ErrorState::CONTINUE_FOR) {
						error_state.mode = ErrorState::NONE;
					}
					current += step_i;
				}
			} else {
				assign_variable(f->variable_name, start);
				Variant current;
				while (true) {
					if (!get_variable(f->variable_name, current)) break;
					bool cond = false;
					if ((double)step > 0) cond = (double)current <= (double)end;
					else cond = (double)current >= (double)end;
					if (!cond) break;
					for (Statement* s : f->body) _execute_statement_impl(s);
					if (error_state.mode == ErrorState::EXIT_FOR) {
						error_state.mode = ErrorState::NONE;
						break;
					}
					if (error_state.mode == ErrorState::CONTINUE_FOR) {
						error_state.mode = ErrorState::NONE;
					}
					assign_variable(f->variable_name, (double)current + (double)step);
				}
			}
			break;
		}
		case STMT_SELECT: {
			SelectStatement* sel = static_cast<SelectStatement*>(stmt);
			Variant val = _evaluate_expression_impl(sel->expression);
			bool matched = false;
			for (CaseBlock* c : sel->cases) {
				bool case_match = false;
				if (c->values.size() == 0) case_match = true;
				else {
					for (int i = 0; i < c->values.size(); ++i) {
						if (_evaluate_expression_impl(c->values[i]) == val) {
							case_match = true;
							break;
						}
					}
				}
				if (case_match) {
					for (Statement* s : c->body) _execute_statement_impl(s);
					matched = true;
					break;
				}
			}
			break;
		}
		case STMT_EXIT: {
			ExitStatement* ex = static_cast<ExitStatement*>(stmt);
			// Set the appropriate exit mode based on the exit type
			switch (ex->exit_type) {
				case ExitStatement::EXIT_SUB:
				case ExitStatement::EXIT_FUNCTION:
					error_state.mode = ErrorState::EXIT_SUB;
					break;
				case ExitStatement::EXIT_FOR:
					error_state.mode = ErrorState::EXIT_FOR;
					break;
				case ExitStatement::EXIT_DO:
					error_state.mode = ErrorState::EXIT_DO;
					break;
			}
			break;
		}
		default:
			break;
	}
}

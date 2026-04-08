#include "visual_gasic_instance.h"
#include "visual_gasic_ast.h"

void VisualGasicInstance::_execute_statement_impl(Statement* stmt) {
	if (!stmt) return;
	switch (stmt->type) {
		case STMT_ASSIGNMENT: {
			AssignmentStatement* a = static_cast<AssignmentStatement*>(stmt);		if (!a->value) {
			raise_error("Invalid assignment - missing value");
			break;
		}			Variant val = _evaluate_expression_impl(a->value);
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
			if (!found) {
				call_internal(c->method_name, args, found);
			}
			if (!found) {
				raise_error("Sub or Function not defined: " + c->method_name, 35);
			}
			break;
		}
		case STMT_IF: {
			IfStatement* i = static_cast<IfStatement*>(stmt);		if (!i->condition) {
			raise_error("Invalid If statement - missing condition");
			break;
		}			if (_evaluate_expression_impl(i->condition).booleanize()) {
				for (Statement* s : i->then_branch) _execute_statement_impl(s);
			} else {
				for (Statement* s : i->else_branch) _execute_statement_impl(s);
			}
			break;
		}
		case STMT_WHILE: {
			WhileStatement* w = static_cast<WhileStatement*>(stmt);		if (!w->condition) {
			raise_error("Invalid While statement - missing condition");
			break;
		}			while (_evaluate_expression_impl(w->condition).booleanize()) {
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
			ForStatement* f = static_cast<ForStatement*>(stmt);		// Null check: parser may have failed and returned incomplete statement
		if (!f->from_val || !f->to_val) {
			raise_error("Invalid For statement - missing start or end value");
			break;
		}			Variant start = _evaluate_expression_impl(f->from_val);
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
		case STMT_OSCILLATE: {
			OscillateStatement* os = static_cast<OscillateStatement*>(stmt);
			if (!os->from_val || !os->to_val) break;
			Variant from_v = _evaluate_expression_impl(os->from_val);
			Variant to_v = _evaluate_expression_impl(os->to_val);
			Variant step_v = os->step_val ? _evaluate_expression_impl(os->step_val) : Variant(1);
			int cycles_limit = os->cycles_val ? (int)_evaluate_expression_impl(os->cycles_val) : -1;
			assign_variable(os->variable_name, from_v);
			int dir = 1;
			int cyc = 0;
			for (int safety = 0; safety < 10000000; safety++) {
				for (Statement* s : os->body) _execute_statement_impl(s);
				if (error_state.mode == ErrorState::EXIT_OSCILLATE) {
					error_state.mode = ErrorState::NONE;
					goto osc_done;
				}
				if (error_state.mode == ErrorState::CONTINUE_OSCILLATE) {
					error_state.mode = ErrorState::NONE;
				}
				Variant current;
				get_variable(os->variable_name, current);
				Variant dir_v(dir), step_dir, inc_res;
				bool v1, v2;
				Variant::evaluate(Variant::OP_MULTIPLY, step_v, dir_v, step_dir, v1);
				Variant::evaluate(Variant::OP_ADD, current, step_dir, inc_res, v2);
				current = inc_res;
				Variant cmp; bool cv;
				Variant::evaluate(Variant::OP_GREATER_EQUAL, current, to_v, cmp, cv);
				if (cmp.booleanize()) { current = to_v; dir = -1; cyc++; }
				else {
					Variant::evaluate(Variant::OP_LESS_EQUAL, current, from_v, cmp, cv);
					if (cmp.booleanize()) { current = from_v; dir = 1; cyc++; }
				}
				assign_variable(os->variable_name, current);
				if (cycles_limit >= 0 && cyc >= cycles_limit) break;
			}
			osc_done:;
			break;
		}
		case STMT_SELECT: {
			SelectStatement* sel = static_cast<SelectStatement*>(stmt);
			Variant val = _evaluate_expression_impl(sel->expression);
			bool matched = false;
			for (CaseBlock* c : sel->cases) {
				bool case_match = false;
				if (c->is_else) {
					case_match = true;
				} else if (c->values.size() == 0) {
					case_match = true;
				} else {
					for (int i = 0; i < c->values.size(); ++i) {
						Variant case_val = _evaluate_expression_impl(c->values[i]);
						// Check if this is a range (X To Y)
						if (i < c->range_ends.size() && c->range_ends[i] != nullptr) {
							Variant range_end = _evaluate_expression_impl(c->range_ends[i]);
							// val >= case_val AND val <= range_end
							bool valid1, valid2;
							Variant res1, res2;
							Variant::evaluate(Variant::OP_GREATER_EQUAL, val, case_val, res1, valid1);
							Variant::evaluate(Variant::OP_LESS_EQUAL, val, range_end, res2, valid2);
							if (res1.booleanize() && res2.booleanize()) {
								case_match = true;
								break;
							}
						} else {
							// Simple value match
							if (case_val == val) {
								case_match = true;
								break;
							}
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
				case ExitStatement::EXIT_OSCILLATE:
					error_state.mode = ErrorState::EXIT_OSCILLATE;
					break;
			}
			break;
		}
		default:
			break;
	}
}

#include "visual_gasic_instance.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/scene_tree_timer.hpp>
#include <godot_cpp/core/math.hpp>

namespace {
template <typename Visitor>
void visit_ast_blocks(Statement *statement, Visitor visit) {
	switch (statement->type) {
		case STMT_IF: {
			auto *s = static_cast<IfStatement *>(statement);
			visit(s->then_branch); visit(s->else_branch); break;
		}
		case STMT_FOR: visit(static_cast<ForStatement *>(statement)->body); break;
		case STMT_FOR_EACH: visit(static_cast<ForEachStatement *>(statement)->body); break;
		case STMT_WHILE: visit(static_cast<WhileStatement *>(statement)->body); break;
		case STMT_DO: visit(static_cast<DoStatement *>(statement)->body); break;
		case STMT_WITH: visit(static_cast<WithStatement *>(statement)->body); break;
		case STMT_TRY: {
			auto *s = static_cast<TryStatement *>(statement);
			visit(s->try_block); visit(s->catch_block); visit(s->finally_block); break;
		}
		case STMT_SELECT:
			for (CaseBlock *block : static_cast<SelectStatement *>(statement)->cases) visit(block->body);
			break;
		case STMT_OSCILLATE: visit(static_cast<OscillateStatement *>(statement)->body); break;
		case STMT_REPEAT: visit(static_cast<RepeatStatement *>(statement)->body); break;
		case STMT_CYCLE: visit(static_cast<CycleStatement *>(statement)->body); break;
		default: break;
	}
}

void scan_await(const Vector<Statement *> &statements, bool &has_await, Vector<String> &locals, Vector<String> *declarations = nullptr) {
	for (Statement *statement : statements) {
		if (!statement) continue;
		if (statement->type == STMT_AWAIT) has_await = true;
		if (statement->type == STMT_DIM) {
			String name = static_cast<DimStatement *>(statement)->variable_name;
			locals.push_back(name);
			if (declarations) declarations->push_back(name);
		}
		if (statement->type == STMT_FOR) locals.push_back(static_cast<ForStatement *>(statement)->variable_name);
		if (statement->type == STMT_FOR_EACH) {
			auto *s = static_cast<ForEachStatement *>(statement);
			locals.push_back(s->variable_name);
			if (!s->index_variable_name.is_empty()) locals.push_back(s->index_variable_name);
		}
		if (statement->type == STMT_TRY) {
			String name = static_cast<TryStatement *>(statement)->catch_var_name;
			if (!name.is_empty()) locals.push_back(name);
		}
		visit_ast_blocks(statement, [&](const Vector<Statement *> &body) { scan_await(body, has_await, locals, declarations); });
	}
}

bool task_finished(Object *task) {
	return (bool)task->call("get_is_complete") ||
			(task->has_method("get_is_failed") && (bool)task->call("get_is_failed")) ||
			(task->has_method("get_is_cancelled") && (bool)task->call("get_is_cancelled"));
}
}

const VisualGasicInstance::AstAwaitInfo &VisualGasicInstance::get_ast_await_info(SubDefinition *function) {
	if (!ast_await_info.has(function)) {
		AstAwaitInfo info;
		for (const Parameter &parameter : function->parameters) info.locals.push_back(parameter.name);
		if (function->type == SubDefinition::TYPE_FUNCTION) info.locals.push_back(function->name);
		Vector<String> declarations = info.locals;
		scan_await(function->statements, info.has_await, info.locals, &declarations);
		Vector<String> unique;
		for (const String &name : info.locals) {
			bool module_global = false;
			if (!declarations.has(name) && script.is_valid() && script->ast_root) {
				for (VariableDefinition *variable : script->ast_root->variables) {
					if (variable->name.nocasecmp_to(name) == 0) { module_global = true; break; }
				}
			}
			if (module_global) continue;
			if (!unique.has(name)) unique.push_back(name);
		}
		info.locals = unique;
		ast_await_info.insert(function, info);
	}
	return ast_await_info[function];
}

bool VisualGasicInstance::suspend_ast_coroutine(AstCoroutine &coroutine, const Variant &awaited) {
	Node *node = Object::cast_to<Node>(owner);
	if (!node || !node->is_inside_tree()) {
		raise_error("Await requires an owner inside a SceneTree", 5);
		return false;
	}
	Callable callback = Callable(owner, "_vg_resume_ast").bind(coroutine.id);
	Object *source = nullptr;
	StringName signal_name;
	Ref<SceneTreeTimer> timer;
	if (awaited.get_type() == Variant::SIGNAL) {
		Signal signal = awaited;
		source = signal.get_object();
		signal_name = signal.get_name();
	} else if (awaited.get_type() == Variant::INT || awaited.get_type() == Variant::FLOAT) {
		double seconds = awaited;
		if (!Math::is_finite(seconds) || seconds < 0) {
			raise_error("Await duration must be a finite nonnegative number of seconds", 5);
			return false;
		}
		timer = node->get_tree()->create_timer(seconds);
		source = timer.ptr();
		signal_name = "timeout";
	} else if (awaited.get_type() == Variant::OBJECT) {
		source = awaited;
		if (source && source->has_method("get_is_complete")) {
			if (task_finished(source)) {
				if (source->has_method("get_is_failed") && (bool)source->call("get_is_failed")) {
					raise_error(String(source->call("get_error")), 5);
				} else if (source->has_method("get_is_cancelled") && (bool)source->call("get_is_cancelled")) {
					raise_error("Await task was cancelled", 5);
				}
				return false;
			}
			coroutine.awaited = awaited;
			signal_name = "completed";
		}
	}
	if (!source || signal_name == StringName() || !source->has_signal(signal_name)) {
		raise_error("Await expects a Signal, timer duration, or task with a completed signal", 13);
		return false;
	}
	coroutine.locals.clear();
	for (const String &name : coroutine.local_names) {
		if (variables.has(name)) coroutine.locals[name] = variables[name];
	}
	coroutine.contexts = with_stack;
	coroutine.error = error_state;
	ast_coroutines.push_back(coroutine);
	Error err = source->connect(signal_name, callback, Object::CONNECT_ONE_SHOT);
	if (err != OK) {
		ast_coroutines.remove_at(ast_coroutines.size() - 1);
		raise_error("Cannot connect Await continuation (Error " + String::num_int64(err) + ")", 5);
		return false;
	}
	// Completion may race the connection; the ID makes a second notification harmless.
	if (coroutine.awaited.get_type() == Variant::OBJECT && task_finished(source)) callback.call_deferred();
	return true;
}

void VisualGasicInstance::resume_ast_coroutine(int64_t id) {
	int index = -1;
	for (int i = 0; i < ast_coroutines.size(); i++) if (ast_coroutines[i].id == id) { index = i; break; }
	if (index < 0) return;
	AstCoroutine coroutine = ast_coroutines[index];
	ast_coroutines.remove_at(index);
	Dictionary previous;
	for (const String &name : coroutine.local_names) {
		if (variables.has(name)) previous[name] = variables[name];
		if (coroutine.locals.has(name)) variables[name] = coroutine.locals[name];
		else variables.erase(name);
	}
	SubDefinition *previous_sub = current_sub;
	ErrorState previous_error = error_state;
	Vector<Variant> previous_contexts = with_stack;
	String previous_source = debug_bc_source_file;
	current_sub = coroutine.function;
	error_state = coroutine.error;
	with_stack = coroutine.contexts;
	debug_bc_source_file = coroutine.source_file;
	if (coroutine.awaited.get_type() == Variant::OBJECT) {
		Object *task = coroutine.awaited;
		if (task && task->has_method("get_is_failed") && (bool)task->call("get_is_failed")) {
			raise_error(String(task->call("get_error")), 5);
		} else if (task && task->has_method("get_is_cancelled") && (bool)task->call("get_is_cancelled")) {
			raise_error("Await task was cancelled", 5);
		}
		coroutine.awaited = Variant();
	}
	run_ast_coroutine(coroutine);
	if (error_state.has_error && error_state.mode == ErrorState::NONE) report_unhandled_error(coroutine.function->name);
	for (const String &name : coroutine.local_names) {
		if (previous.has(name)) variables[name] = previous[name];
		else variables.erase(name);
	}
	current_sub = previous_sub;
	error_state = previous_error;
	with_stack = previous_contexts;
	debug_bc_source_file = previous_source;
}

void VisualGasicInstance::run_ast_coroutine(AstCoroutine &coroutine) {
	auto push_body = [&](const Vector<Statement *> &body) {
		AstAwaitFrame frame;
		frame.statements = body;
		coroutine.frames.push_back(frame);
	};
	while (!coroutine.frames.is_empty()) {
		const int top = coroutine.frames.size() - 1;
		AstAwaitFrame &frame = coroutine.frames.write[top];
		if (!frame.control) {
			if (top == 0 && error_state.has_error && error_state.mode == ErrorState::GOTO_LABEL) {
				if (coroutine.function->label_map.has(error_state.label)) {
					frame.index = (int)coroutine.function->label_map[error_state.label];
					error_state.has_error = false;
				} else {
					error_state.mode = ErrorState::NONE;
					raise_error("Error handler label not found: " + error_state.label, 5);
				}
			}
			if (error_state.has_error && error_state.mode == ErrorState::RESUME_NEXT) error_state.has_error = false;
			if (error_state.has_error || frame.index >= frame.statements.size()) {
				coroutine.frames.remove_at(top);
				continue;
			}
			Statement *statement = frame.statements[frame.index++];
			if (!statement) continue;
			debug_state.current_line = statement->line;
			debug_state.merged_line = statement->line;
			if (statement->type == STMT_AWAIT) {
				Variant awaited = evaluate_expression(static_cast<AwaitStatement *>(statement)->expression);
				if (!error_state.has_error && suspend_ast_coroutine(coroutine, awaited)) return;
			} else if (statement->type == STMT_IF) {
				auto *s = static_cast<IfStatement *>(statement);
				bool condition = evaluate_expression(s->condition).booleanize();
				if (!error_state.has_error) push_body(condition ? s->then_branch : s->else_branch);
			} else if (statement->type == STMT_FOR || statement->type == STMT_FOR_EACH ||
					statement->type == STMT_WHILE || statement->type == STMT_DO ||
					statement->type == STMT_TRY || statement->type == STMT_WITH) {
				AstAwaitFrame control;
				control.control = statement;
				coroutine.frames.push_back(control);
			} else if (statement->type == STMT_SELECT) {
				auto *s = static_cast<SelectStatement *>(statement);
				Variant value = evaluate_expression(s->expression);
				for (CaseBlock *block : s->cases) {
					bool match = block->is_else;
					for (int j = 0; !match && j < block->values.size(); j++) {
						Variant candidate = evaluate_expression(block->values[j]);
						String op = j < block->comparison_ops.size() ? block->comparison_ops[j] : String();
						if (op.is_empty() && j < block->range_ends.size() && block->range_ends[j]) {
							Variant end = evaluate_expression(block->range_ends[j]);
							match = (double)value >= (double)candidate && (double)value <= (double)end;
						} else {
							Variant::Operator operation = Variant::OP_EQUAL;
							if (op == ">") operation = Variant::OP_GREATER;
							if (op == "<") operation = Variant::OP_LESS;
							if (op == ">=") operation = Variant::OP_GREATER_EQUAL;
							if (op == "<=") operation = Variant::OP_LESS_EQUAL;
							if (op == "<>") operation = Variant::OP_NOT_EQUAL;
							Variant result; bool valid = false;
							Variant::evaluate(operation, value, candidate, result, valid);
							match = valid && result.booleanize();
						}
					}
					if (match) { push_body(block->body); break; }
				}
			} else {
				bool nested_await = false;
				Vector<String> ignored;
				visit_ast_blocks(statement, [&](const Vector<Statement *> &body) { scan_await(body, nested_await, ignored); });
				if (nested_await) raise_error("Await is not supported in this statement context", 5);
				else execute_statement(statement);
				if (jump_target >= 0 && coroutine.frames.size() == 1) {
					coroutine.frames.write[0].index = jump_target + 1;
					jump_target = -1;
				}
			}
			continue;
		}
		Statement *control = frame.control;
		if (control->type == STMT_TRY) {
			auto *s = static_cast<TryStatement *>(control);
			if (frame.phase == 0) { frame.phase = 1; push_body(s->try_block); continue; }
			if (frame.phase == 1 && error_state.has_error && error_state.mode == ErrorState::NONE) {
				if (!s->catch_var_name.is_empty()) {
					Dictionary exception;
					exception["Description"] = error_state.message; exception["Number"] = error_state.code;
					exception["Source"] = "VisualGasic";
					variables[s->catch_var_name] = exception;
				}
				error_state.has_error = false;
				frame.phase = 2;
				push_body(s->catch_block);
				continue;
			}
			if (frame.phase < 3) {
				frame.saved_error = error_state;
				error_state.has_error = false; error_state.mode = ErrorState::NONE;
				frame.phase = 3; push_body(s->finally_block); continue;
			}
			if (!error_state.has_error && error_state.mode == ErrorState::NONE) error_state = frame.saved_error;
			coroutine.frames.remove_at(top);
			continue;
		}
		if (control->type == STMT_WITH) {
			auto *s = static_cast<WithStatement *>(control);
			if (frame.phase == 0) {
				Variant context = evaluate_expression(s->expression);
				if (!error_state.has_error) {
					with_stack.push_back(context); frame.phase = 1; push_body(s->body); continue;
				}
			} else if (!with_stack.is_empty()) with_stack.remove_at(with_stack.size() - 1);
			coroutine.frames.remove_at(top); continue;
		}
		ErrorState::Mode exit_mode = ErrorState::EXIT_FOR, continue_mode = ErrorState::CONTINUE_FOR;
		if (control->type == STMT_WHILE) { exit_mode = ErrorState::EXIT_WHILE; continue_mode = ErrorState::CONTINUE_WHILE; }
		if (control->type == STMT_DO) { exit_mode = ErrorState::EXIT_DO; continue_mode = ErrorState::CONTINUE_DO; }
		if (error_state.has_error) {
			if (error_state.mode == exit_mode) {
				error_state.has_error = false; error_state.mode = ErrorState::NONE;
				coroutine.frames.remove_at(top); continue;
			}
			if (error_state.mode == continue_mode) {
				error_state.has_error = false; error_state.mode = ErrorState::NONE;
			} else { coroutine.frames.remove_at(top); continue; }
		}
		if (++frame.iterations > 10000000) {
			raise_error("Await loop iteration limit exceeded", 5);
			coroutine.frames.remove_at(top); continue;
		}
		if (control->type == STMT_FOR) {
			auto *s = static_cast<ForStatement *>(control);
			if (frame.phase == 0) {
				Variant start = evaluate_expression(s->from_val);
				frame.limit = evaluate_expression(s->to_val);
				frame.step = s->step_val ? evaluate_expression(s->step_val) : Variant(1);
				assign_variable(s->variable_name, start); frame.phase = 1;
			} else {
				Variant result; bool valid = false;
				Variant::evaluate(Variant::OP_ADD, variables[s->variable_name], frame.step, result, valid);
				if (valid) assign_variable(s->variable_name, result);
				else raise_error("Invalid For increment in Await continuation", 13);
			}
			double value = variables[s->variable_name], step = frame.step, limit = frame.limit;
			if (!error_state.has_error && (step >= 0 ? value <= limit : value >= limit)) { push_body(s->body); continue; }
		} else if (control->type == STMT_FOR_EACH) {
			auto *s = static_cast<ForEachStatement *>(control);
			if (frame.phase == 0) {
				Variant collection = evaluate_expression(s->collection);
				if (collection.get_type() == Variant::ARRAY || Variant::can_convert(collection.get_type(), Variant::ARRAY)) frame.items = collection;
				else if (collection.get_type() == Variant::DICTIONARY) frame.items = Dictionary(collection).keys();
				else if (collection.get_type() == Variant::STRING) {
					String text = collection;
					for (int i = 0; i < text.length(); i++) frame.items.push_back(String::chr(text[i]));
				} else raise_error("For Each requires an Array, Dictionary, or String", 13);
				frame.phase = 1;
			}
			if (!error_state.has_error && frame.index < frame.items.size()) {
				assign_variable(s->variable_name, frame.items[frame.index]);
				if (!s->index_variable_name.is_empty()) assign_variable(s->index_variable_name, frame.index);
				frame.index++; push_body(s->body); continue;
			}
		} else if (control->type == STMT_WHILE) {
			auto *s = static_cast<WhileStatement *>(control);
			bool condition = evaluate_expression(s->condition).booleanize();
			if (!error_state.has_error && condition) { push_body(s->body); continue; }
		} else if (control->type == STMT_DO) {
			auto *s = static_cast<DoStatement *>(control);
			bool enter = true;
			if (s->condition_type != DoStatement::NONE && (!s->is_post_condition || frame.phase != 0)) {
				bool condition = evaluate_expression(s->condition).booleanize();
				enter = s->condition_type == DoStatement::WHILE ? condition : !condition;
			}
			frame.phase = 1;
			if (!error_state.has_error && enter) { push_body(s->body); continue; }
		}
		coroutine.frames.remove_at(top);
	}
}

// visual_gasic_causal_graph.cpp — AST-based causal chain report (M6 / Track B).

#include "visual_gasic_causal_graph.h"

#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h"
#include "visual_gasic_ast.h"

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>

using namespace godot;
using namespace VisualGasic;

namespace {

static const int INDENT_WIDTH = 4;
static const int MAX_DEPTH = 20;
static const int MAX_CHARS = 80;

static String truncate_str(const String &s, int max_len = MAX_CHARS / 2) {
	if (s.length() <= max_len) return s;
	return s.substr(0, max_len - 3) + "...";
}

static String expr_to_string(const ExpressionNode *e, int max_len = MAX_CHARS / 2) {
	if (!e) return "";
	switch (e->type) {
		case ExpressionNode::LITERAL: {
			const LiteralNode *l = static_cast<const LiteralNode *>(e);
			Variant v = l->value;
			if (v.get_type() == Variant::STRING) {
				return truncate_str("\"" + String(v) + "\"", max_len);
			}
			if (v.get_type() == Variant::BOOL) {
				return (bool)v ? "True" : "False";
			}
			return truncate_str(String(v), max_len);
		}
		case ExpressionNode::VARIABLE:
			return static_cast<const VariableNode *>(e)->name;
		case ExpressionNode::BINARY_OP: {
			const BinaryOpNode *b = static_cast<const BinaryOpNode *>(e);
			String s = expr_to_string(b->left, max_len) + " " + b->op + " " + expr_to_string(b->right, max_len);
			return truncate_str(s, max_len);
		}
		case ExpressionNode::UNARY_OP: {
			const UnaryOpNode *u = static_cast<const UnaryOpNode *>(e);
			return u->op + expr_to_string(u->operand, max_len);
		}
		case ExpressionNode::EXPRESSION_CALL: {
			const CallExpression *c = static_cast<const CallExpression *>(e);
			String base;
			if (c->base_object) {
				base = expr_to_string(c->base_object, max_len) + ".";
			}
			String args;
			for (int i = 0; i < c->arguments.size(); i++) {
				if (i > 0) args += ", ";
				args += expr_to_string(c->arguments[i], max_len);
			}
			return truncate_str(base + c->method_name + "(" + args + ")", max_len);
		}
		case ExpressionNode::MEMBER_ACCESS: {
			const MemberAccessNode *m = static_cast<const MemberAccessNode *>(e);
			return expr_to_string(m->base_object, max_len) + "." + m->member_name;
		}
		case ExpressionNode::ME:
			return "Me";
		case ExpressionNode::ARRAY_ACCESS: {
			const ArrayAccessNode *a = static_cast<const ArrayAccessNode *>(e);
			String idx = a->indices.size() > 0 ? expr_to_string(a->indices[0], max_len) : "";
			return expr_to_string(a->base, max_len) + "(" + idx + ")";
		}
		default:
			return "?";
	}
}

static String indent_line(int depth, const String &body) {
	String pad;
	for (int i = 0; i < depth * INDENT_WIDTH; i++) pad += " ";
	return pad + body;
}

static bool is_event_suffix(const String &p_lower) {
	static const char *events[] = {
		"click", "dblclick", "mousedown", "mouseup", "mousemove",
		"keydown", "keypress", "keyup", "change", "load", "unload",
		"activate", "deactivate", "resize", "paint", "timer",
		"gotfocus", "lostfocus", "mouseenter", "mouseexit",
		"scroll", "validate", "init", "terminate",
		"bodyentered", "bodyexited", "areaentered", "areaexited",
		"ready", "process", "physicsprocess", "input", nullptr
	};
	for (int i = 0; events[i]; i++) {
		if (p_lower == events[i]) return true;
	}
	return false;
}

static bool is_entry_point_name(const String &name) {
	if (name.contains("_")) {
		int idx = name.rfind("_");
		if (idx > 0 && idx < name.length() - 1) {
			String event_part = name.substr(idx + 1).to_lower();
			if (is_event_suffix(event_part)) return true;
		}
	}
	static const char *extra[] = {
		"Form_Load", "Form_Unload", "Form_Initialize", "Form_Terminate",
		"Class_Initialize", "Class_Terminate", "_ready", "_process", "_input", nullptr
	};
	for (int i = 0; extra[i]; i++) {
		if (name == extra[i]) return true;
	}
	return false;
}

static String describe_entry(const String &name) {
	if (name.contains("_")) {
		int idx = name.rfind("_");
		if (idx > 0) {
			String control = name.substr(0, idx);
			String event_name = name.substr(idx + 1);
			String event_lower = event_name.to_lower();
			if (is_event_suffix(event_lower)) {
				return "User triggers " + control + "." + event_name;
			}
		}
	}
	if (name == "Form_Load" || name == "Class_Initialize") {
		return "Form/Class loads";
	}
	if (name == "_ready" || name == "_process" || name == "_input") {
		return "Godot lifecycle: " + name;
	}
	return "Entry: " + name;
}

static String format_call(const String &target, const Vector<ExpressionNode *> &args, const HashMap<String, SubDefinition *> &procs) {
	String args_str;
	for (int i = 0; i < args.size(); i++) {
		if (i > 0) args_str += ", ";
		args_str += expr_to_string(args[i]);
	}
	String full = target;
	if (args_str.is_empty()) full += "()";
	else full += "(" + args_str + ")";
	if (procs.has(target)) {
		return "Call " + full;
	}
	return full;
}

class CausalWalker {
	HashMap<String, SubDefinition *> procs;
	PackedStringArray lines;

public:
	explicit CausalWalker(const ModuleNode *root) {
		for (int i = 0; i < root->subs.size(); i++) {
			if (root->subs[i]) {
				procs[root->subs[i]->name] = root->subs[i];
			}
		}
	}

	PackedStringArray find_entry_points(const Array &roots) const {
		PackedStringArray entries;
		if (roots.size() > 0) {
			for (int i = 0; i < roots.size(); i++) {
				entries.push_back(String(roots[i]));
			}
			return entries;
		}
		for (const KeyValue<String, SubDefinition *> &kv : procs) {
			if (is_entry_point_name(kv.key)) {
				entries.push_back(kv.key);
			}
		}
		if (entries.is_empty()) {
			for (const KeyValue<String, SubDefinition *> &kv : procs) {
				entries.push_back(kv.key);
			}
		}
		return entries;
	}

	String generate(const Array &roots) {
		PackedStringArray entry_points = find_entry_points(roots);
		for (int i = 0; i < entry_points.size(); i++) {
			const String ep = entry_points[i];
			lines.push_back(describe_entry(ep));
			if (procs.has(ep)) {
				HashSet<String> visited;
				walk_proc(procs[ep], 1, visited);
			}
			if (i < entry_points.size() - 1) {
				lines.push_back("");
			}
		}
		String report;
		for (int i = 0; i < lines.size(); i++) {
			if (i > 0) report += "\n";
			report += lines[i];
		}
		return report;
	}

private:
	void walk_proc(SubDefinition *proc, int depth, HashSet<String> &visited) {
		if (!proc || depth > MAX_DEPTH) {
			if (depth > MAX_DEPTH) {
				lines.push_back(indent_line(depth, "└─ [MAX_DEPTH reached — truncating]"));
			}
			return;
		}
		walk_statements(proc->statements, proc, depth, visited);
	}

	void walk_statements(const Vector<Statement *> &stmts, SubDefinition *proc, int depth, HashSet<String> &visited) {
		for (int i = 0; i < stmts.size(); i++) {
			walk_statement(stmts[i], proc, depth, visited);
		}
	}

	void walk_statement(Statement *stmt, SubDefinition *proc, int depth, HashSet<String> &visited) {
		if (!stmt) return;
		switch (stmt->type) {
			case STMT_IF: {
				const IfStatement *is = static_cast<const IfStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ If " + expr_to_string(is->condition) + " Then"));
				walk_statements(is->then_branch, proc, depth, visited);
				if (is->else_branch.size() > 0) {
					lines.push_back(indent_line(depth, "├─ Else"));
					walk_statements(is->else_branch, proc, depth, visited);
				}
				break;
			}
			case STMT_FOR: {
				const ForStatement *fs = static_cast<const ForStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ Loop over " + fs->variable_name));
				walk_statements(fs->body, proc, depth, visited);
				break;
			}
			case STMT_FOR_EACH: {
				const ForEachStatement *fe = static_cast<const ForEachStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ Loop over " + fe->variable_name));
				walk_statements(fe->body, proc, depth, visited);
				break;
			}
			case STMT_WHILE:
			case STMT_DO: {
				lines.push_back(indent_line(depth, "├─ Loop entry"));
				if (stmt->type == STMT_WHILE) {
					walk_statements(static_cast<const WhileStatement *>(stmt)->body, proc, depth, visited);
				} else {
					walk_statements(static_cast<const DoStatement *>(stmt)->body, proc, depth, visited);
				}
				break;
			}
			case STMT_SELECT: {
				const SelectStatement *sel = static_cast<const SelectStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ Select Case " + expr_to_string(sel->expression)));
				for (int c = 0; c < sel->cases.size(); c++) {
					const CaseBlock *cb = sel->cases[c];
					if (cb->is_else) {
						lines.push_back(indent_line(depth, "├─ Case Else"));
					} else if (cb->values.size() > 0) {
						lines.push_back(indent_line(depth, "├─ Case " + expr_to_string(cb->values[0])));
					}
					walk_statements(cb->body, proc, depth, visited);
				}
				break;
			}
			case STMT_RETURN: {
				const ReturnStatement *rs = static_cast<const ReturnStatement *>(stmt);
				if (rs->return_value) {
					lines.push_back(indent_line(depth, "├─ Returns " + expr_to_string(rs->return_value)));
				}
				break;
			}
			case STMT_EXIT: {
				const ExitStatement *es = static_cast<const ExitStatement *>(stmt);
				String kind = "Sub";
				switch (es->exit_type) {
					case ExitStatement::EXIT_FUNCTION: kind = "Function"; break;
					case ExitStatement::EXIT_FOR: kind = "For"; break;
					case ExitStatement::EXIT_DO: kind = "Do"; break;
					case ExitStatement::EXIT_WHILE: kind = "While"; break;
					default: break;
				}
				lines.push_back(indent_line(depth, "├─ Exit " + kind));
				break;
			}
			case STMT_CALL: {
				const CallStatement *cs = static_cast<const CallStatement *>(stmt);
				String target = cs->method_name;
				if (target.nocasecmp_to("End") == 0) {
					break;
				}
				if (target.nocasecmp_to("MsgBox") == 0) {
					String msg = cs->arguments.size() > 0 ? expr_to_string(cs->arguments[0], 50) : "";
					lines.push_back(indent_line(depth, "├─ MsgBox (" + truncate_str(msg, 50) + ")"));
					break;
				}
				lines.push_back(indent_line(depth, "├─ " + format_call(target, cs->arguments, procs)));
				if (procs.has(target) && !visited.has(target)) {
					visited.insert(target);
					walk_proc(procs[target], depth + 1, visited);
				}
				break;
			}
			case STMT_RAISE_EVENT: {
				const RaiseEventStatement *re = static_cast<const RaiseEventStatement *>(stmt);
				String detail = "RaiseEvent " + re->expression_name;
				if (re->arguments.size() > 0) {
					String args;
					for (int a = 0; a < re->arguments.size(); a++) {
						if (a > 0) args += ", ";
						args += expr_to_string(re->arguments[a]);
					}
					detail += "(" + truncate_str(args) + ")";
				}
				lines.push_back(indent_line(depth, "├─ " + detail));
				lines.push_back(indent_line(depth, "│   └─ [Parent scene connects here]"));
				break;
			}
			case STMT_PRINT: {
				const PrintStatement *ps = static_cast<const PrintStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ Print " + truncate_str(expr_to_string(ps->expression), 50)));
				break;
			}
			case STMT_OPEN: {
				const OpenStatement *os = static_cast<const OpenStatement *>(stmt);
				lines.push_back(indent_line(depth, "├─ File.Open(" + truncate_str(expr_to_string(os->path), 50) + ")"));
				break;
			}
			case STMT_CLOSE:
				lines.push_back(indent_line(depth, "├─ File.Close()"));
				break;
			case STMT_WRITE:
				lines.push_back(indent_line(depth, "├─ File.Write(...)"));
				break;
			case STMT_ASSIGNMENT: {
				const AssignmentStatement *as = static_cast<const AssignmentStatement *>(stmt);
				if (proc && proc->type == SubDefinition::TYPE_FUNCTION && as->target &&
						as->target->type == ExpressionNode::VARIABLE) {
					const VariableNode *vn = static_cast<const VariableNode *>(as->target);
					if (vn->name == proc->name) {
						lines.push_back(indent_line(depth, "├─ Returns " + expr_to_string(as->value)));
						break;
					}
				}
				if (as->target && as->target->type == ExpressionNode::MEMBER_ACCESS) {
					const MemberAccessNode *ma = static_cast<const MemberAccessNode *>(as->target);
					lines.push_back(indent_line(depth, "├─ Set " + expr_to_string(ma->base_object) + "." + ma->member_name));
				}
				break;
			}
			default:
				break;
		}
	}
};

} // namespace

namespace godot {

Dictionary vg_analyze_causal_graph(const String &p_code, const Array &p_roots) {
	Dictionary result;
	result["engine"] = "ast";

	if (p_code.is_empty()) {
		result["ok"] = true;
		result["report"] = "";
		return result;
	}

	VisualGasicTokenizer tokenizer;
	Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(p_code);
	if (tokenizer.has_error) {
		result["ok"] = false;
		Array errors;
		Dictionary err;
		err["line"] = tokenizer.error_line;
		err["column"] = tokenizer.error_column;
		err["message"] = tokenizer.error_message;
		errors.push_back(err);
		result["errors"] = errors;
		result["report"] = "";
		return result;
	}

	VisualGasicParser parser;
	ModuleNode *root = parser.parse(tokens);
	if (parser.errors.size() > 0 || !root) {
		result["ok"] = false;
		Array errors;
		for (int i = 0; i < parser.errors.size(); i++) {
			Dictionary err;
			err["line"] = parser.errors[i].line;
			err["column"] = parser.errors[i].column;
			err["message"] = parser.errors[i].message;
			errors.push_back(err);
		}
		result["errors"] = errors;
		result["report"] = "";
		if (root) delete root;
		return result;
	}

	CausalWalker walker(root);
	String report = walker.generate(p_roots);
	delete root;

	result["ok"] = true;
	result["report"] = report;
	return result;
}

} // namespace godot

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

static SubDefinition *find_proc_ci(const HashMap<String, SubDefinition *> &procs, const String &name) {
	if (name.is_empty()) {
		return nullptr;
	}
	if (procs.has(name)) {
		return procs[name];
	}
	SubDefinition *found = nullptr;
	for (const KeyValue<String, SubDefinition *> &kv : procs) {
		if (kv.key.nocasecmp_to(name) == 0) {
			found = kv.value;
			break;
		}
	}
	return found;
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
	if (find_proc_ci(procs, target)) {
		return "Call " + full;
	}
	return full;
}

class CausalWalker {
	HashMap<String, SubDefinition *> procs;
	HashSet<String> sections;
	PackedStringArray lines;

public:
	explicit CausalWalker(const ModuleNode *root) {
		for (int i = 0; i < root->subs.size(); i++) {
			if (root->subs[i]) {
				procs[root->subs[i]->name] = root->subs[i];
			}
		}
		for (int i = 0; i < root->global_statements.size(); i++) {
			Statement *stmt = root->global_statements[i];
			if (!stmt || stmt->type != STMT_WHENEVER_SECTION) continue;
			const WheneverSectionStatement *ws = static_cast<const WheneverSectionStatement *>(stmt);
			sections.insert(ws->section_name.to_lower());
		}
	}

	PackedStringArray find_entry_points(const Array &roots) const {
		PackedStringArray entries;
		if (roots.size() > 0) {
			for (int i = 0; i < roots.size(); i++) {
				String requested = String(roots[i]);
				SubDefinition *proc = find_proc_ci(procs, requested);
				// A selected Whenever section is rendered by the watcher report.
				if (!proc && sections.has(requested.to_lower())) continue;
				entries.push_back(proc ? proc->name : requested);
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
			SubDefinition *proc = find_proc_ci(procs, ep);
			if (proc) {
				HashSet<String> visited;
				walk_proc(proc, 1, visited);
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
				SubDefinition *callee = find_proc_ci(procs, target);
				if (callee && !visited.has(callee->name)) {
					visited.insert(callee->name);
					walk_proc(callee, depth + 1, visited);
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
					if (vn->name.nocasecmp_to(proc->name) == 0) {
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

static Array risk_flags(bool state_write, bool guard, bool external, bool unresolved) {
	Array risks;
	if (state_write) risks.push_back("state write");
	if (guard) risks.push_back("early-return guard");
	if (external) risks.push_back("external effect");
	if (unresolved) risks.push_back("unresolved target");
	return risks;
}

static bool branch_has_exit(const Vector<Statement *> &stmts) {
	for (int i = 0; i < stmts.size(); i++) {
		Statement *stmt = stmts[i];
		if (!stmt) continue;
		if (stmt->type == STMT_EXIT || stmt->type == STMT_RETURN) return true;
		if (stmt->type == STMT_IF) {
			const IfStatement *is = static_cast<const IfStatement *>(stmt);
			if (branch_has_exit(is->then_branch) || branch_has_exit(is->else_branch)) return true;
		}
	}
	return false;
}

// Machine-readable possible-behavior evidence. Lines are 1-based tokenizer lines.
// A line of 0 with location_known false is a synthetic limit, not a source location.
class EvidenceBuilder {
	const ModuleNode *module;
	HashMap<String, SubDefinition *> procs;
	PackedStringArray source_lines;
	Array roots;
	Array steps;
	Array limitations;
	HashSet<String> seen_limits;
	bool truncated = false;
	int seq = 0;
	String whenever_text;

	void add_limit(const String &text) {
		if (seen_limits.has(text)) return;
		seen_limits.insert(text);
		limitations.push_back(text);
	}

	Dictionary add_step(int root_index, const String &parent_id, const String &kind, int line,
			const String &text, const String &resolution, int target_line, bool target_known,
			bool possible, bool unconditional, const Array &risks, const String &branch = "",
			const String &target_name = "") {
		seq++;
		Dictionary step;
		step["id"] = "s" + String::num_int64(seq);
		step["parent_id"] = parent_id;
		step["root_index"] = root_index;
		step["kind"] = kind;
		step["branch"] = branch;
		step["line"] = line;
		step["location_known"] = line > 0;
		step["text"] = text;
		step["resolution"] = resolution;
		step["target_line"] = target_known ? target_line : 0;
		step["target_known"] = target_known;
		step["target_name"] = target_known ? target_name : "";
		step["possible"] = possible;
		step["unconditional"] = unconditional;
		step["risks"] = risks;
		steps.push_back(step);
		return step;
	}

	void emit_limit(int root_index, const String &parent_id) {
		truncated = true;
		add_limit("MAX_DEPTH reached — truncating");
		Dictionary step = add_step(root_index, parent_id, "limit", 0, "MAX_DEPTH reached — truncating",
				"not_applicable", 0, false, true, false, Array());
		step["location_known"] = false;
		steps[steps.size() - 1] = step;
	}

	String call_args(const Vector<ExpressionNode *> &args) const {
		String out;
		for (int i = 0; i < args.size(); i++) {
			if (i > 0) out += ", ";
			out += expr_to_string(args[i], 120);
		}
		return out;
	}

	void walk_proc(SubDefinition *proc, int root_index, const String &parent_id, int depth, HashSet<String> &stack, const String &branch) {
		if (!proc) return;
		if (depth > MAX_DEPTH) {
			emit_limit(root_index, parent_id);
			return;
		}
		walk_statements(proc->statements, root_index, parent_id, depth, stack, branch);
	}

	void walk_statements(const Vector<Statement *> &stmts, int root_index, const String &parent_id, int depth, HashSet<String> &stack, const String &branch) {
		for (int i = 0; i < stmts.size(); i++) {
			walk_statement(stmts[i], root_index, parent_id, depth, stack, branch);
		}
	}

	void walk_statement(Statement *stmt, int root_index, const String &parent_id, int depth, HashSet<String> &stack, const String &branch) {
		if (!stmt || depth > MAX_DEPTH) {
			if (stmt && depth > MAX_DEPTH) emit_limit(root_index, parent_id);
			return;
		}
		switch (stmt->type) {
			case STMT_IF: {
				const IfStatement *is = static_cast<const IfStatement *>(stmt);
				bool early = branch_has_exit(is->then_branch) || branch_has_exit(is->else_branch);
				Dictionary guard = add_step(root_index, parent_id, "guard", stmt->line,
						"If " + expr_to_string(is->condition, 120) + " Then",
						"not_applicable", 0, false, true, false,
						risk_flags(false, early, false, false), branch);
				String guard_id = String(guard["id"]);
				walk_statements(is->then_branch, root_index, guard_id, depth, stack, "then");
				walk_statements(is->else_branch, root_index, guard_id, depth, stack, "else");
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
				add_step(root_index, parent_id, "exit", stmt->line, "Exit " + kind,
						"not_applicable", 0, false, true, false,
						risk_flags(false, true, false, false), branch);
				break;
			}
			case STMT_ASSIGNMENT: {
				const AssignmentStatement *as = static_cast<const AssignmentStatement *>(stmt);
				if (!as->target || as->target->type != ExpressionNode::VARIABLE) break;
				const VariableNode *vn = static_cast<const VariableNode *>(as->target);
				add_step(root_index, parent_id, "state_write", stmt->line,
						vn->name + String(" = ") + expr_to_string(as->value, 120),
						"not_applicable", 0, false, true, false,
						risk_flags(true, false, false, false), branch);
				break;
			}
			case STMT_CALL:
				walk_call(static_cast<const CallStatement *>(stmt), root_index, parent_id, depth, stack, branch);
				break;
			default:
				break;
		}
	}

	void walk_call(const CallStatement *cs, int root_index, const String &parent_id, int depth, HashSet<String> &stack, const String &branch) {
		String args = call_args(cs->arguments);
		bool external = cs->base_object != nullptr;
		String text;
		if (external) {
			text = expr_to_string(cs->base_object, 80) + "." + cs->method_name + "(" + args + ")";
		} else {
			text = "Call " + cs->method_name + "(" + args + ")";
		}
		SubDefinition *callee = external ? nullptr : find_proc_ci(procs, cs->method_name);
		bool known = callee != nullptr;
		int target_line = known ? callee->line : 0;
		String target_name = known ? callee->name : "";
		Dictionary step = add_step(root_index, parent_id, "call", cs->line, text,
				known ? "resolved" : "unresolved", target_line, known, true, false,
				risk_flags(false, false, external, !known), branch, target_name);
		if (!known) return;
		String stack_key = callee->name.to_lower();
		if (stack.has(stack_key)) {
			truncated = true;
			add_limit("cycle truncated at " + callee->name);
			return;
		}
		stack.insert(stack_key);
		walk_proc(callee, root_index, String(step["id"]), depth + 1, stack, "");
		stack.erase(stack_key);
	}

	String condition_text(const WheneverSectionStatement *ws) const {
		String cond = ws->comparison_operator;
		if (ws->comparison_value) cond += " " + expr_to_string(ws->comparison_value, 120);
		if (ws->comparison_value2) cond += " And " + expr_to_string(ws->comparison_value2, 120);
		return cond;
	}

	String declaration_at(int line) const {
		if (line <= 0 || line > source_lines.size()) return "";
		return source_lines[line - 1].strip_edges();
	}

	bool requested_has(const HashSet<String> &requested_names, const String &name) const {
		return requested_names.has(name.to_lower());
	}

public:
	EvidenceBuilder(const ModuleNode *p_module, const String &source) : module(p_module) {
		source_lines = source.split("\n");
		HashSet<String> folded;
		for (int i = 0; i < module->subs.size(); i++) {
			SubDefinition *sub = module->subs[i];
			if (!sub) continue;
			procs[sub->name] = sub;
			String folded_name = sub->name.to_lower();
			if (folded.has(folded_name)) {
				add_limit("case-insensitive procedure match is ambiguous for " + sub->name);
			}
			folded.insert(folded_name);
		}
		add_limit("Static analysis describes possible behavior, not proof that it ran.");
		add_limit("Dynamic calls, signals, engine callbacks, and external objects stay unresolved. Call sites are located; target locations are not invented.");
		add_limit("Evidence records Whenever roots, guards, early exits, state writes, and calls. Other statements are omitted.");
		add_limit("Walks stop at depth 20 or when a procedure is already on the stack.");
	}

	void build(const Array &requested) {
		HashSet<String> requested_names;
		bool filtered = requested.size() > 0;
		for (int i = 0; i < requested.size(); i++) requested_names.insert(String(requested[i]).to_lower());

		HashSet<String> section_names;
		Vector<WheneverSectionStatement *> watchers;
		for (int i = 0; i < module->global_statements.size(); i++) {
			Statement *stmt = module->global_statements[i];
			if (!stmt || stmt->type != STMT_WHENEVER_SECTION) continue;
			WheneverSectionStatement *ws = static_cast<WheneverSectionStatement *>(stmt);
			section_names.insert(ws->section_name.to_lower());
			bool wanted = !filtered || requested_has(requested_names, ws->section_name);
			if (!wanted) {
				for (int c = 0; c < ws->callback_procedures.size(); c++) {
					if (requested_has(requested_names, ws->callback_procedures[c])) {
						wanted = true;
						break;
					}
				}
			}
			if (wanted) watchers.push_back(ws);
		}

		for (int i = 0; i < watchers.size(); i++) add_whenever(watchers[i]);

		if (filtered) {
			for (int i = 0; i < requested.size(); i++) {
				String name = String(requested[i]);
				if (section_names.has(name.to_lower())) continue;
				SubDefinition *proc = find_proc_ci(procs, name);
				add_event(proc ? proc->name : name);
			}
			return;
		}
		for (const KeyValue<String, SubDefinition *> &kv : procs) {
			if (is_entry_point_name(kv.key)) add_event(kv.key);
		}
	}

	Dictionary to_dictionary() const {
		Dictionary evidence;
		evidence["schema_version"] = 1;
		evidence["line_base"] = 1;
		evidence["ok"] = true;
		evidence["engine"] = "ast";
		evidence["completeness"] = "ast";
		evidence["truncated"] = truncated;
		evidence["limitations"] = limitations;
		evidence["roots"] = roots;
		evidence["steps"] = steps;
		evidence["whenever_text"] = whenever_text;
		return evidence;
	}

private:
	void add_event(const String &name) {
		SubDefinition *proc = find_proc_ci(procs, name);
		Dictionary root;
		root["kind"] = "event";
		root["name"] = proc ? proc->name : name;
		root["section"] = "";
		root["variable"] = "";
		root["condition"] = "";
		root["handler"] = "";
		root["handlers"] = Array();
		root["declaration"] = "";
		root["handler_resolution"] = proc ? "resolved" : "unresolved";
		root["handler_line"] = proc ? proc->line : 0;
		root["line"] = proc ? proc->line : 0;
		root["location_known"] = proc && proc->line > 0;
		roots.push_back(root);
	}

	Dictionary handler_record(const String &callback) const {
		SubDefinition *proc = find_proc_ci(procs, callback);
		Dictionary handler;
		handler["name"] = callback;
		handler["resolution"] = proc ? "resolved" : "unresolved";
		handler["target_name"] = proc ? proc->name : "";
		handler["line"] = proc ? proc->line : 0;
		return handler;
	}

	void add_whenever(WheneverSectionStatement *ws) {
		Array handlers;
		for (int i = 0; i < ws->callback_procedures.size(); i++) {
			handlers.push_back(handler_record(ws->callback_procedures[i]));
		}
		Dictionary first = handlers.size() > 0 ? Dictionary(handlers[0]) : Dictionary();
		String handler = first.is_empty() ? String() : String(first["name"]);
		bool known = !first.is_empty() && String(first["resolution"]) == "resolved";
		Dictionary root;
		root["kind"] = "whenever";
		root["name"] = ws->section_name;
		root["section"] = ws->section_name;
		root["variable"] = ws->variable_name;
		root["condition"] = condition_text(ws);
		root["declaration"] = declaration_at(ws->line);
		root["handler"] = handler;
		root["handlers"] = handlers;
		root["handler_resolution"] = known ? "resolved" : "unresolved";
		root["handler_line"] = known ? int(first["line"]) : 0;
		root["line"] = ws->line;
		root["location_known"] = ws->line > 0;
		int root_index = roots.size();
		roots.push_back(root);
		if (handlers.is_empty()) {
			add_step(root_index, "", "call", ws->line, "Call ()",
					"unresolved", 0, false, true, false,
					risk_flags(false, false, false, true));
			return;
		}
		for (int i = 0; i < handlers.size(); i++) {
			Dictionary recorded = handlers[i];
			String callback = String(recorded["name"]);
			SubDefinition *proc = find_proc_ci(procs, callback);
			if (!proc) {
				add_step(root_index, "", "call", ws->line, "Call " + callback + "()",
						"unresolved", 0, false, true, false,
						risk_flags(false, false, false, true));
				continue;
			}
			HashSet<String> stack;
			stack.insert(proc->name.to_lower());
			walk_proc(proc, root_index, "", 1, stack, "");
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
	EvidenceBuilder evidence(root, p_code);
	evidence.build(p_roots);
	Dictionary evidence_dict = evidence.to_dictionary();
	evidence_dict["report"] = report;
	delete root;

	result["ok"] = true;
	result["report"] = report;
	result["evidence"] = evidence_dict;
	return result;
}

} // namespace godot

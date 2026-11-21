#ifndef VISUAL_GASIC_NAMED_ARGS_H
#define VISUAL_GASIC_NAMED_ARGS_H

// Shared named-argument reordering for bytecode compile and AST evaluation.
// Call sites store argument_names alongside arguments ("x" = x:=expr; empty = positional).

#include "visual_gasic_ast.h"

#include <godot_cpp/variant/utility_functions.hpp>

namespace VisualGasic {

// Reorder args/names onto target->parameters. Clears names on success.
// Returns false on conflict / unknown name / missing required param.
inline bool reorder_named_arguments_onto(SubDefinition *target, Vector<ExpressionNode *> &args, Vector<String> &names, String *r_err = nullptr) {
	auto fail = [&](const String &msg) -> bool {
		if (r_err) {
			*r_err = msg;
		}
		return false;
	};
	if (!target) {
		return fail("Named arguments require a known Sub or Function");
	}
	bool any = false;
	for (int i = 0; i < names.size(); i++) {
		if (!names[i].is_empty()) {
			any = true;
			break;
		}
	}
	if (!any) {
		return true;
	}

	const int n = target->parameters.size();
	Vector<ExpressionNode *> ordered;
	ordered.resize(n);
	Vector<uint8_t> filled;
	filled.resize(n);
	for (int i = 0; i < n; i++) {
		filled.set(i, 0);
	}
	int next_pos = 0;
	for (int i = 0; i < args.size(); i++) {
		String nm = (i < names.size()) ? names[i] : String();
		int slot = -1;
		if (nm.is_empty()) {
			while (next_pos < n && filled[next_pos]) {
				next_pos++;
			}
			slot = next_pos;
			if (slot < n) {
				next_pos++;
			}
		} else {
			for (int p = 0; p < n; p++) {
				if (target->parameters[p].name.nocasecmp_to(nm) == 0) {
					slot = p;
					break;
				}
			}
			if (slot < 0) {
				return fail("Named argument '" + nm + "' is not a parameter of " + target->name);
			}
		}
		if (slot < 0 || slot >= n || filled[slot]) {
			return fail("Named argument position conflict in " + target->name);
		}
		ordered.set(slot, args[i]);
		filled.set(slot, 1);
	}
	int emit_n = n;
	while (emit_n > 0 && !filled[emit_n - 1] && target->parameters[emit_n - 1].is_optional) {
		emit_n--;
	}
	for (int i = 0; i < emit_n; i++) {
		if (!filled[i]) {
			return fail("Missing argument for " + target->name + " parameter " + target->parameters[i].name);
		}
	}
	args.clear();
	for (int i = 0; i < emit_n; i++) {
		args.push_back(ordered[i]);
	}
	names.clear();
	return true;
}

// Bind already-evaluated values by name. Does not evaluate expressions.
// If lvalues is set, the same permutation is applied to those nodes so ByRef
// write-back follows parameter order. The nodes are not evaluated here.
// Same slot rules as reorder_named_arguments_onto.
inline bool reorder_named_values_onto(SubDefinition *target, Array &args, const Vector<String> &names, String *r_err = nullptr, Vector<ExpressionNode *> *lvalues = nullptr) {
	auto fail = [&](const String &msg) -> bool {
		if (r_err) {
			*r_err = msg;
		}
		return false;
	};
	if (!target) {
		return fail("Named arguments require a known Sub or Function");
	}
	bool any = false;
	for (int i = 0; i < names.size(); i++) {
		if (!names[i].is_empty()) {
			any = true;
			break;
		}
	}
	if (!any) {
		return true;
	}

	const int n = target->parameters.size();
	Vector<Variant> ordered;
	ordered.resize(n);
	Vector<ExpressionNode *> ordered_lv;
	const bool track_lv = lvalues != nullptr;
	if (track_lv) {
		ordered_lv.resize(n);
	}
	Vector<uint8_t> filled;
	filled.resize(n);
	for (int i = 0; i < n; i++) {
		filled.set(i, 0);
	}
	int next_pos = 0;
	for (int i = 0; i < args.size(); i++) {
		String nm = (i < names.size()) ? names[i] : String();
		int slot = -1;
		if (nm.is_empty()) {
			while (next_pos < n && filled[next_pos]) {
				next_pos++;
			}
			slot = next_pos;
			if (slot < n) {
				next_pos++;
			}
		} else {
			for (int p = 0; p < n; p++) {
				if (target->parameters[p].name.nocasecmp_to(nm) == 0) {
					slot = p;
					break;
				}
			}
			if (slot < 0) {
				return fail("Named argument '" + nm + "' is not a parameter of " + target->name);
			}
		}
		if (slot < 0 || slot >= n || filled[slot]) {
			return fail("Named argument position conflict in " + target->name);
		}
		ordered.set(slot, args[i]);
		if (track_lv) {
			ExpressionNode *lv = (i < lvalues->size()) ? (*lvalues)[i] : nullptr;
			ordered_lv.set(slot, lv);
		}
		filled.set(slot, 1);
	}
	int emit_n = n;
	while (emit_n > 0 && !filled[emit_n - 1] && target->parameters[emit_n - 1].is_optional) {
		emit_n--;
	}
	for (int i = 0; i < emit_n; i++) {
		if (!filled[i]) {
			return fail("Missing argument for " + target->name + " parameter " + target->parameters[i].name);
		}
	}
	args.clear();
	for (int i = 0; i < emit_n; i++) {
		args.push_back(ordered[i]);
	}
	if (track_lv) {
		lvalues->clear();
		for (int i = 0; i < emit_n; i++) {
			lvalues->push_back(ordered_lv[i]);
		}
	}
	return true;
}

} // namespace VisualGasic

#endif

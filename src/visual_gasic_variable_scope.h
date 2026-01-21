#ifndef VISUAL_GASIC_VARIABLE_SCOPE_H
#define VISUAL_GASIC_VARIABLE_SCOPE_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

class VariableScope {
private:
    HashMap<String, Variant> variables;
    VariableScope* parent_scope;

public:
    VariableScope(VariableScope* p_parent = nullptr) : parent_scope(p_parent) {}

    // Set or update a variable in current scope
    void set_variable(const String& name, const Variant& value) {
        variables[name] = value;
    }

    // Get a variable, searching up the scope chain
    bool get_variable(const String& name, Variant& out_value) {
        if (variables.has(name)) {
            out_value = variables[name];
            return true;
        }
        
        if (parent_scope) {
            return parent_scope->get_variable(name, out_value);
        }
        
        return false;
    }

    // Check if variable exists in current scope
    bool has_variable(const String& name) const {
        return variables.has(name);
    }

    // Check if variable exists anywhere in scope chain
    bool has_variable_recursive(const String& name) const {
        if (variables.has(name)) {
            return true;
        }
        
        if (parent_scope) {
            return parent_scope->has_variable_recursive(name);
        }
        
        return false;
    }

    // Create a new child scope
    VariableScope* create_child_scope() {
        return memnew(VariableScope(this));
    }

    // Get parent scope
    VariableScope* get_parent() const {
        return parent_scope;
    }

    // Clear all variables in this scope
    void clear() {
        variables.clear();
    }

    // Get all variables in current scope (not recursive)
    HashMap<String, Variant> get_all_variables() const {
        return variables;
    }
};

// Scope stack for managing function/block scopes
class ScopeStack {
private:
    Vector<VariableScope*> scope_stack;
    VariableScope* global_scope;

public:
    ScopeStack() {
        global_scope = memnew(VariableScope());
        scope_stack.push_back(global_scope);
    }

    ~ScopeStack() {
        while (scope_stack.size() > 0) {
            pop_scope();
        }
        if (global_scope) {
            memdelete(global_scope);
        }
    }

    VariableScope* push_scope() {
        VariableScope* new_scope = get_current_scope()->create_child_scope();
        scope_stack.push_back(new_scope);
        return new_scope;
    }

    void pop_scope() {
        if (scope_stack.size() > 1) {
            VariableScope* scope = scope_stack[scope_stack.size() - 1];
            scope_stack.remove_at(scope_stack.size() - 1);
            memdelete(scope);
        }
    }

    VariableScope* get_current_scope() {
        return scope_stack[scope_stack.size() - 1];
    }

    VariableScope* get_global_scope() {
        return global_scope;
    }

    void set_variable(const String& name, const Variant& value) {
        get_current_scope()->set_variable(name, value);
    }

    bool get_variable(const String& name, Variant& out_value) {
        return get_current_scope()->get_variable(name, out_value);
    }

    void clear_all() {
        while (scope_stack.size() > 1) {
            pop_scope();
        }
        global_scope->clear();
    }
};

#endif // VISUAL_GASIC_VARIABLE_SCOPE_H

#include "visual_gasic_parser.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <stdio.h>

VisualGasicParser::VisualGasicParser() : current_pos(0) {
}

VisualGasicParser::~VisualGasicParser() {
    // Free any parser-owned nodes that were not transferred to the
    // returned ModuleNode (i.e. parse failure paths that left
    // temporary allocations).
    for (int i = 0; i < allocated_nodes.size(); i++) {
        if (allocated_nodes[i]) delete allocated_nodes[i];
    }
    allocated_nodes.clear();

    for (int i = 0; i < allocated_expr_nodes.size(); i++) {
        if (allocated_expr_nodes[i]) delete allocated_expr_nodes[i];
    }
    allocated_expr_nodes.clear();
}

VisualGasicTokenizer::Token VisualGasicParser::peek(int offset) {
    if (current_pos + offset >= tokens.size()) {
        VisualGasicTokenizer::Token t;
        t.type = VisualGasicTokenizer::TOKEN_EOF;
        return t;
    }
    return tokens[current_pos + offset];
}

VisualGasicTokenizer::Token VisualGasicParser::advance() {
    if (!is_at_end()) current_pos++;
    if (current_pos > 0 && current_pos <= tokens.size()) return tokens[current_pos - 1];
    return peek();
}

bool VisualGasicParser::match(VisualGasicTokenizer::TokenType type) {
    if (check(type)) {
        advance();
        return true;
    }
    return false;
}

bool VisualGasicParser::check(VisualGasicTokenizer::TokenType type) {
    if (is_at_end()) return false;
    return peek().type == type;
}

bool VisualGasicParser::is_at_end() {
    return peek().type == VisualGasicTokenizer::TOKEN_EOF;
}

// Helper needed because I used 'previous' in advance but didn't define it
VisualGasicTokenizer::Token VisualGasicParser::previous() {
    if (current_pos > 0) return tokens[current_pos - 1];
    return VisualGasicTokenizer::Token();
}

void VisualGasicParser::error(const String& message) {
    ParsingError err;
    VisualGasicTokenizer::Token t = peek();
    err.line = t.line;
    err.column = t.column;
    err.message = message;
    errors.push_back(err);
}

// Reimplementing correct logic
ModuleNode* VisualGasicParser::parse(const Vector<VisualGasicTokenizer::Token>& p_tokens) {
    tokens = p_tokens;
    errors.clear();
    current_pos = 0;
    
    ModuleNode* module = new ModuleNode();
    current_module = module;

        while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();
        
        if (t.type == VisualGasicTokenizer::TOKEN_NEWLINE) {
            current_pos++; // Skip top level newlines
            continue;
        }

        // Attribute VB_Name = "..."
        if (t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER && t.value == "Attribute") {
            // Consume Attribute line
            while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                current_pos++;
            }
            continue;
        }

        // Inheritance (Inherits or Extends)
        String t_val_lower = String(t.value).to_lower();
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && (t_val_lower == "inherits" || t_val_lower == "extends")) {
            advance(); // consume keyword
            if (check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
                module->inherits_path = advance().value;
            } else if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                // Treat identifiers as simple class names or resource paths if possible?
                // VisualGasic doesn't have a global class map yet, so this might be just the name string.
                // But Godot usually expects a path for non-global classes.
                module->inherits_path = advance().value;
            } else {
                error("Expected string literal or class name after 'Inherits'");
            }
            continue;
        }
        
        // Event Definition
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).to_lower() == "event") {
            EventDefinition* evt = parse_event(); // We need to add this method in parser.h too or include it inline?
            // parse_event is defined above parse_statement now, but we need to declare it in the class or just add it to ModuleNode
            if (evt) {
                module->events.push_back(evt);
                unregister_node(evt);
            }
            continue;
        }

        if ((t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER || t.type == VisualGasicTokenizer::TOKEN_KEYWORD) && (t.value == "Sub" || t.value == "Function")) {
            SubDefinition* sub = parse_sub();
            if (sub) {
                module->subs.push_back(sub);
                unregister_node(sub);
            }
            continue;
        }

        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && t.value == "Type") {
            StructDefinition* def = parse_struct();
            if (def) {
                module->structs.push_back(def);
                unregister_node(def);
            }
            continue;
        }

        // Variable Declaration (Dim, Public, Private)
        String val = String(t.value).to_lower();
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && (val == "public" || val == "private" || val == "dim")) {
            // Parse DimStatement logic but store as global VariableDefinition
             DimStatement* dim = parse_dim(); // Reuse parse_dim which handles Dim A As Integer
             if (dim) {
                 VariableDefinition* v = static_cast<VariableDefinition*>(register_node(new VariableDefinition()));
                 v->name = dim->variable_name;
                 v->type = dim->type_name; // can be empty
                 v->visibility = (val == "public") ? VIS_PUBLIC : (val == "private" ? VIS_PRIVATE : VIS_DIM);
                 
                 for(int i=0; i<dim->array_sizes.size(); i++) {
                     ExpressionNode* expr = dim->array_sizes[i];
                     if (expr->type == ExpressionNode::LITERAL) {
                         v->array_sizes.push_back((int)((LiteralNode*)expr)->value);
                     } else {
                         // Error: Constant expression required
                         v->array_sizes.push_back(0); 
                     }
                 }
                 
                 module->variables.push_back(v);
                 unregister_node(v);
                        unregister_node(dim);
                        delete dim; // Don't need the statement wrapper
             }
             continue;
        }

        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).to_lower() == "option") {
             advance(); // Eat Option
             if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                 String kw = String(peek().value).to_lower();
                 if (kw == "explicit") {
                     advance(); // Eat Explicit
                     module->option_explicit = true;
                 } else if (kw == "compare") {
                     advance(); // Eat Compare
                     if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                         String mode = String(peek().value).to_lower();
                         if (mode == "text") {
                             module->option_compare_text = true;
                             advance();
                         } else if (mode == "binary") {
                             module->option_compare_text = false;
                             advance();
                         }
                         // else option compare database? ignore or error
                     }
                 }
             }
             // Handle "Option Base 1" etc? Not requested.
             continue;
        }

        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).to_lower() == "const") {
             ConstStatement* c = parse_const();
             if (c) {
                 module->constants.push_back(c);
                 unregister_node(c);
                 // Keep the ConstStatement wrapper as it holds the value expression
             }
             continue;
        }

        // Global Data/Labels support
        bool is_datafile = ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(t.value).to_lower() == "datafile");
        
        if (is_datafile) {
            Statement* s = parse_data_file();
            if (s) {
                module->global_statements.push_back(s);
                unregister_node(s);
            }
            continue;
        }

        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).to_lower() == "data") || 
            (t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER && peek(1).type == VisualGasicTokenizer::TOKEN_COLON)) {
            Statement* s = parse_statement();
            if (s) {
                if (s->type == STMT_DATA || s->type == STMT_LABEL) {
                    module->global_statements.push_back(s);
                } else {
                    unregister_node(s);
                    delete s;
                    error("Only Data and Labels are allowed at module level.");
                }
            }
            continue;
        }

        // Skip unknown
        current_pos++;
    }

    // If parsing recorded errors, free the partially-built AST and
    // return nullptr so callers know parsing failed. This ensures the
    // parser is responsible for cleanup on failure and avoids leaving
    // dangling allocations for higher layers to clean.
    if (errors.size() > 0) {
        delete module;
        // Delete any parser-owned nodes that weren't transferred
        for (int i = 0; i < allocated_nodes.size(); i++) if (allocated_nodes[i]) delete allocated_nodes[i];
        allocated_nodes.clear();
        for (int i = 0; i < allocated_expr_nodes.size(); i++) if (allocated_expr_nodes[i]) delete allocated_expr_nodes[i];
        allocated_expr_nodes.clear();
        return nullptr;
    }

    // Successful parse: ownership of AST nodes should now belong to
    // the ModuleNode and its sub-structures. Clear the allocated_nodes
    // tracker without deleting to avoid double-free.
    allocated_nodes.clear();
    allocated_expr_nodes.clear();

    return module;
}

ASTNode* VisualGasicParser::register_node(ASTNode* p_node) {
    if (p_node) {
        allocated_nodes.push_back(p_node);
        // parser registration (silenced in normal runs)
    }
    return p_node;
}

void VisualGasicParser::unregister_node(ASTNode* p_node) {
    if (!p_node) return;
    for (int i = 0; i < allocated_nodes.size(); i++) {
        if (allocated_nodes[i] == p_node) {
            allocated_nodes.remove_at(i);
            // parser unregister (silenced in normal runs)
            return;
        }
    }
}

ExpressionNode* VisualGasicParser::register_node(ExpressionNode* p_node) {
    if (p_node) {
        allocated_expr_nodes.push_back(p_node);
        // expression registration (silenced in normal runs)
    }
    return p_node;
}

void VisualGasicParser::unregister_node(ExpressionNode* p_node) {
    if (!p_node) return;
    for (int i = 0; i < allocated_expr_nodes.size(); i++) {
        if (allocated_expr_nodes[i] == p_node) {
            allocated_expr_nodes.remove_at(i);
            // expression unregister (silenced in normal runs)
            return;
        }
    }
}

void VisualGasicParser::clear_tracked_nodes() {
    allocated_nodes.clear();
    allocated_expr_nodes.clear();
}

SubDefinition* VisualGasicParser::parse_sub() {
    VisualGasicTokenizer::Token start_token = peek();
    bool is_function = (String(start_token.value).nocasecmp_to("Function") == 0);
    current_pos++; // Eat Sub or Function

    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected procedure name");
        return nullptr;
    }
    
    String name = peek().value;
    current_pos++; // Eat Name

    Vector<Parameter> parameters;

    // Parse Parameters (arg1, arg2)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // Eat (
        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             while (true) {
                 Parameter param;
                 
                 // Modifiers
                 bool modifier_found = true;
                 while (modifier_found) {
                     modifier_found = false;
                     if (peek().type == VisualGasicTokenizer::TOKEN_KEYWORD) {
                         String k = String(peek().value).to_lower();
                         if (k == "optional") {
                             param.is_optional = true;
                             advance();
                             modifier_found = true;
                         } else if (k == "byval") {
                             param.is_by_ref = false; // Default is ByRef(true)
                             advance();
                             modifier_found = true;
                         } else if (k == "byref") {
                             param.is_by_ref = true;
                             advance();
                             modifier_found = true;
                         } else if (k == "paramarray") {
                             param.is_param_array = true;
                             advance();
                             modifier_found = true;
                         }
                     }
                 }

                 if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                     param.name = peek().value;
                     advance();
                     
                     // Handle "As Type"
                     if (peek().type == VisualGasicTokenizer::TOKEN_KEYWORD && String(peek().value).nocasecmp_to("As") == 0) {
                          advance(); // Eat 'As'
                          // Eat Type (Identifier or Keyword like Integer, String)
                          if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                              param.type_hint = peek().value;
                              advance();
                          }
                     }

                     // Handle Default Value (= value) for Optional
                         if (param.is_optional && check(VisualGasicTokenizer::TOKEN_OPERATOR) && String(peek().value) == "=") {
                         advance(); // Eat =
                         ExpressionNode* expr = parse_expression();
                         if (expr && expr->type == ExpressionNode::LITERAL) {
                             param.default_value = ((LiteralNode*)expr)->value;
                         } else {
                             // Complex default values not fully supported in this simplified parser pass, 
                             // usually requires constant folding.
                             // We'll leave as NIL if not literal.
                         }
                         if (expr) { unregister_node(expr); delete expr; }
                     }

                     parameters.push_back(param);
                 } else {
                     UtilityFunctions::print("Parser Error: Expected parameter name");
                 }
                 
                 if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                 break;
             }
        }
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             UtilityFunctions::print("Parser Error: Expected ) after parameters");
        }
    }
    
    // Skip to newline (e.g. ignore "As Variant" for return type roughly for now, or parse it)
    while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
          // Store return type if we want
          current_pos++;
    }

    SubDefinition* sub = static_cast<SubDefinition*>(register_node(new SubDefinition()));
    sub->name = name;
    sub->type = is_function ? SubDefinition::TYPE_FUNCTION : SubDefinition::TYPE_SUB;
    sub->parameters = parameters;

    // Body
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();

        if ((t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER || t.type == VisualGasicTokenizer::TOKEN_KEYWORD) && t.value == "End") {
           VisualGasicTokenizer::Token next = peek(1);
           String end_type = next.value;
           
           if ((is_function && end_type == "Function") || (!is_function && end_type == "Sub")) {
               current_pos += 2; // Eat End Sub/Function
               break;
           }
        }
        
        Statement* stmt = parse_statement();
        if (stmt) {
            sub->statements.push_back(stmt);
            unregister_node(stmt);
        } else {
            current_pos++; // Skip unknown token to avoid infinite loop
        }
    }

    return sub;
}

// Helper declaration
RaiseEventStatement* VisualGasicParser::parse_raise_event() {
    RaiseEventStatement* stmt = static_cast<RaiseEventStatement*>(register_node(new RaiseEventStatement()));
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected event name after RaiseEvent");
        return stmt;
    }
    stmt->expression_name = advance().value;
    
    // Check for arguments (Optional parens in VB sometimes, but let's assume standard call style)
    // RaiseEvent EventName(Arg, Arg)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance();
        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             while (true) {
                 ExpressionNode* arg = parse_expression();
                 if (arg) {
                     stmt->arguments.push_back(arg);
                     unregister_node(arg);
                 }
                
                 if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                     advance();
                 } else {
                     break;
                 }
             }
        }
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    
    return stmt;
}

EventDefinition* VisualGasicParser::parse_event() {
    // Event MyEvent(ByVal x As Integer)
    advance(); // consumes Event
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected identifier for Event");
        return nullptr;
    }
    
    EventDefinition* evt = static_cast<EventDefinition*>(register_node(new EventDefinition()));
    evt->name = advance().value;
    
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance();
        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
            while (true) {
                // Parse Arg
                // ByVal/ByRef optional
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                     String kw = String(peek().value).to_lower();
                     if (kw == "byval" || kw == "byref") advance();
                }
                
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                    String arg_name = advance().value;
                    evt->arguments.push_back(arg_name);
                    
                     // As Type?
                    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "as") {
                        advance();
                        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                             String type_name = advance().value;
                             evt->argument_types.push_back(type_name);
                        } else {
                             evt->argument_types.push_back("Variant");
                        }
                    } else {
                        evt->argument_types.push_back("Variant"); // Default type
                    }
                }
                
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                } else {
                    break;
                }
            }
        }
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    return evt;
}

Statement* VisualGasicParser::parse_statement() {
    if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) {
        return nullptr;
    }
    
    VisualGasicTokenizer::Token t = peek();
    // UtilityFunctions::print("ParseStmt Token: ", t.value, " Type: ", t.type);

    if (t.type == VisualGasicTokenizer::TOKEN_COMMENT) {
        advance();
        return nullptr;
    }
    
    String val = t.value.operator String().to_lower();

    // Only treat reserved words as statements when the tokenizer classified them as KEYWORD.
    if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD) {
        if (val == "enum") {
            parse_enum();
            return nullptr; // Enum is a definition, not a statement
        }
        if (val == "print") {
            return parse_print();
        }
        if (val == "open") return parse_open();
        if (val == "close") return parse_close();
        if (val == "seek") return parse_seek();
        if (val == "kill") return parse_kill();
        if (val == "name") return parse_name();
        if (val == "try") return parse_try();
        if (val == "input") return parse_input(false);
        if (val == "line") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("input") == 0) {
                 return parse_input(true);
            }
        }

        if (val == "var") {
             return parse_dim(); // Helper alias for Var -> Dim
        }

        if (val == "dim") return parse_dim();
        if (val == "static") {
            DimStatement* ds = parse_dim();
            if (ds) ds->is_static = true;
            return ds;
        }
        if (val == "const") return parse_const();
        if (val == "pass") {
            advance();
            return static_cast<PassStatement*>(register_node(new PassStatement()));
        }
        if (val == "doevents") {
            advance();
            return static_cast<DoEventsStatement*>(register_node(new DoEventsStatement()));
        }
        if (val == "data") return parse_data();
        if (val == "datafile") return parse_data_file();
        if (val == "loaddata") return parse_load_data();
        if (val == "read") return parse_read();
        if (val == "restore") return parse_restore();
        if (val == "if") return parse_if();
        if (val == "for") return parse_for();
        if (val == "while") return parse_while();
        if (val == "do") return parse_do();
        if (val == "select") return parse_select();
        if (val == "exit") return parse_exit();
        if (val == "redim") return parse_redim();
        if (val == "with") return parse_with();
        if (val == "return") return parse_return();
        if (val == "continue") return parse_continue();
        if (val == "raise") {
            return parse_raise();
        }
        if (val == "whenever") {
            return parse_whenever();
        }
        
        // Multitasking keywords - async/await/task/parallel
        if (val == "async") {
            advance(); // consume "async"
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && (String(peek().value).nocasecmp_to("sub") == 0 || String(peek().value).nocasecmp_to("function") == 0)) {
                return parse_async_function();
            }
            error("Expected 'Sub' or 'Function' after 'Async'");
            return nullptr;
        }
        if (val == "await") {
            return parse_await();
        }
        if (val == "task") {
            advance(); // consume "task"
            String next_val = String(peek().value).to_lower();
            if (next_val == "run") {
                advance(); // consume "run"
                return parse_task_run();
            } else if (next_val == "wait" || next_val == "waitall" || next_val == "waitany") {
                return parse_task_wait();
            }
            error("Expected 'Run', 'Wait', 'WaitAll', or 'WaitAny' after 'Task'");
            return nullptr;
        }
        if (val == "parallel") {
            advance(); // consume "parallel" 
            String next_val = String(peek().value).to_lower();
            if (next_val == "for") {
                advance(); // consume "for"
                return parse_parallel_for();
            } else if (next_val == "section") {
                advance(); // consume "section"
                return parse_parallel_section();
            }
            error("Expected 'For' or 'Section' after 'Parallel'");
            return nullptr;
        }
        
        // Advanced features - Select Match / Select Case
        if (val == "select") {
            advance(); // consume "select"
            String next_val = String(peek().value).to_lower();
            if (next_val == "match") {
                advance(); // consume "match"
                return parse_pattern_match();
            } else {
                // Regular select case - put token back
                current_pos--;
                return parse_select();
            }
        }
        
        if (val == "suspend") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("whenever") == 0) {
                advance(); // consume "whenever"
                return parse_suspend_whenever();
            }
            error("Expected 'Whenever' after 'Suspend'");
            return nullptr;
        }
        if (val == "resume") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("whenever") == 0) {
                advance(); // consume "whenever"
                return parse_resume_whenever();
            }
            error("Expected 'Whenever' after 'Resume'");
            return nullptr;
        }
        if (val == "raiseevent") {
            advance();
            return parse_raise_event();
        }
        
        if (val == "set") {
            advance(); // Eat Set
            // Parse assignment: Target = Value
            return parse_assignment_or_call();
        }
    }
    if (val == "goto") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String label = peek().value;
            advance();
            GotoStatement* g = static_cast<GotoStatement*>(register_node(new GotoStatement()));
            g->label_name = label;
            return g;
        }
    }

    if (val == "on") {
        advance(); // On
        bool is_error = false;
        // Check for "Error"
        if (String(peek().value).nocasecmp_to("Error") == 0) {
            advance();
            is_error = true;
        }
        
        if (is_error) {
             if (String(peek().value).nocasecmp_to("Resume") == 0) {
                 advance();
                 if (String(peek().value).nocasecmp_to("Next") == 0) {
                     advance();
                     OnErrorStatement* s = static_cast<OnErrorStatement*>(register_node(new OnErrorStatement()));
                     s->mode = OnErrorStatement::RESUME_NEXT;
                     return s;
                 }
             } else if (String(peek().value).nocasecmp_to("Goto") == 0) {
                 advance();
                 if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                     String label = peek().value;
                     advance();
                     OnErrorStatement* s = static_cast<OnErrorStatement*>(register_node(new OnErrorStatement()));
                     s->mode = OnErrorStatement::GOTO_LABEL;
                     s->label_name = label;
                     return s;
                 }
                 // Handle "0" to disable? VB semantics "On Error Goto 0"
                 if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER)) {
                      if ((int)peek().value == 0) {
                           advance();
                           // Treated as disable, or empty label?
                           // For now, let's just ignore or treat as disable.
                           // Actually, we can make it a specific mode or empty label.
                           OnErrorStatement* s = static_cast<OnErrorStatement*>(register_node(new OnErrorStatement()));
                           s->mode = OnErrorStatement::GOTO_LABEL;
                           s->label_name = ""; // Empty label means disable
                           return s;
                      }
                 }
             }
        }
    }

    if (val == "call") {
        advance();
        ExpressionNode* target = nullptr;
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Me") == 0) {
            target = static_cast<ExpressionNode*>(register_node(new ExpressionNode())); target->type = ExpressionNode::ME;
            advance();
        } else if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            VariableNode* v = static_cast<VariableNode*>(register_node(new VariableNode())); v->name = peek().value;
            target = v;
            advance();
        } else { return nullptr; }
        
        while(check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                MemberAccessNode* ma = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode())); ma->base_object = target;
                ma->member_name = peek().value;
                target = ma;
                advance();
            }
        }
        
        // Allow parens: Call Method(Args)
        bool has_parens = false;
        // Check for LPAREN
        VisualGasicTokenizer::Token next_t = peek();
        if (next_t.type == VisualGasicTokenizer::TOKEN_PAREN_OPEN) {
            advance(); 
            has_parens = true;
        }
        
        Vector<ExpressionNode*> args;
        if (has_parens && check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
            advance(); // empty
        } else if (has_parens || !check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
             // Parse args
             do {
                 if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) break;
                 {
                     ExpressionNode* _tmp = parse_expression();
                     if (_tmp) {
                         args.push_back(_tmp);
                         unregister_node(_tmp);
                     }
                 }
                 if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                     advance();
                 } else {
                     break;
                 }
             } while (!is_at_end());
             
             if (has_parens) {
                 if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                     advance();
                 } else {
                     UtilityFunctions::print("Parser Error: Expected )");
                 }
             }
        }
        
        CallStatement* call_stmt = static_cast<CallStatement*>(register_node(new CallStatement()));
        if (target->type == ExpressionNode::MEMBER_ACCESS) {
            MemberAccessNode* ma = (MemberAccessNode*)target;
            call_stmt->base_object = ma->base_object;
            call_stmt->method_name = ma->member_name;
            ma->base_object = nullptr; unregister_node(ma); delete ma;
        } else if (target->type == ExpressionNode::VARIABLE) {
            call_stmt->method_name = ((VariableNode*)target)->name;
            unregister_node(target); delete target;
        } else { unregister_node(target); delete target; unregister_node(call_stmt); delete call_stmt; return nullptr; }

        call_stmt->arguments = args;
        return call_stmt;
    }
    
    if (t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
        // Check for Label: Identifier followed by Colon
        if (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_COLON) {
            String label_name = t.value;
            advance(); // Identifier
            advance(); // Colon
            LabelStatement* l = static_cast<LabelStatement*>(register_node(new LabelStatement()));
            l->name = label_name;
            return l;
        }

        return parse_assignment_or_call();
    }

    if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && t.value.operator String().nocasecmp_to("me") == 0) {
        return parse_assignment_or_call();
    }
    
    // Check for Leading Dot (Implicit With member access)
    if (t.type == VisualGasicTokenizer::TOKEN_OPERATOR && t.value == ".") {
        return parse_assignment_or_call();
    }
    
    current_pos++; // Skip unknown
    return nullptr;
}

// --- Expression Parsing ---

ExpressionNode* VisualGasicParser::parse_expression() {
    ExpressionNode* expr = parse_logical_or();
    
    // Check for inline If (Pythonic Ternary)
    // Value If Condition Else OtherValue
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("If") == 0) {
        advance(); // Eat If
        ExpressionNode* cond = parse_expression(); // Recursive for precedence?
        // Actually usually ternary condition connects to 'Else' tightly.
        // Python: x if c else y
        // c is an expression.
        
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Else") == 0) {
            advance(); // Eat Else
            ExpressionNode* false_part = parse_expression(); // Recursive
            
            // Build IIfNode (Reuse IIfNode structure)
            IIfNode* iif = static_cast<IIfNode*>(register_node(new IIfNode()));
            iif->condition = cond;
            iif->true_part = expr;
            iif->false_part = false_part;
            return iif;
        } else {
            error("Expected 'Else' in inline If expression");
        }
    }
    
    return expr;
}

ExpressionNode* VisualGasicParser::parse_logical_or() {
    ExpressionNode* expr = parse_and();
    while (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = String(peek().value);
        if (op.nocasecmp_to("Or") == 0 || op.nocasecmp_to("Xor") == 0 || op.nocasecmp_to("OrElse") == 0) {
            advance();
            ExpressionNode* right = parse_and();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = op;
            expr = bin;
        } else {
             break;
        }
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_and() {
    ExpressionNode* expr = parse_not();
    while ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_OPERATOR))) {
        String op = String(peek().value);
        if (op.nocasecmp_to("And") == 0 || op.nocasecmp_to("AndAlso") == 0) {
            advance();
            ExpressionNode* right = parse_not();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = op;
            expr = bin;
        } else {
             break;
        }
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_not() {
    if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_OPERATOR)) && String(peek().value).nocasecmp_to("Not") == 0) {
        String op = String(peek().value);
        advance();
        ExpressionNode* operand = parse_not();
        UnaryOpNode* unary = static_cast<UnaryOpNode*>(register_node(new UnaryOpNode()));
        unary->op = op;
        if (operand) {
            ExpressionNode* odup = operand->duplicate();
            if (odup) unary->operand = register_node(odup); else unary->operand = operand;
        } else unary->operand = nullptr;
        return unary;
    }
    return parse_comparison();
}

ExpressionNode* VisualGasicParser::parse_comparison() {
    ExpressionNode* expr = parse_addition();
    
    // Check for Operators and special Keyword 'Is'
    while (true) {
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
            String op = peek().value;
            if (op == "=" || op == "<" || op == ">" || op == "<=" || op == ">=" || op == "<>" || op == "!=") {
                advance();
                ExpressionNode* right = parse_addition();
                BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                if (expr) {
                    ExpressionNode* ldup = expr->duplicate();
                    if (ldup) bin->left = register_node(ldup); else bin->left = expr;
                } else bin->left = nullptr;
                if (right) {
                    ExpressionNode* rdup = right->duplicate();
                    if (rdup) bin->right = register_node(rdup); else bin->right = right;
                } else bin->right = nullptr;
                bin->op = op;
                expr = bin;
                continue;
            }
        }
        
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Is") == 0) {
            advance();
            ExpressionNode* right = parse_addition();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            // Duplicate children when attaching to avoid sharing the same
            // ExpressionNode instance between multiple parents which causes
            // double-delete during AST teardown.
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = "Is";
            expr = bin;
            continue;
        }
        
        break;
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_addition() {
    ExpressionNode* expr = parse_term();
    
    while (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = peek().value;
        if (op == "+" || op == "-" || op == "&") {
            advance();
            ExpressionNode* right = parse_term();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = op;
            expr = bin;
        } else {
            break;
        }
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_term() {
    ExpressionNode* expr = parse_unary();
    
    while (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = peek().value;
        if (op == "*" || op == "/" || op == "//") {
            advance();
            ExpressionNode* right = parse_unary();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = op;
            expr = bin;
        } else {
            break;
        }
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_exponentiation() {
    ExpressionNode* expr = parse_factor();
    
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "**") {
        advance();
        ExpressionNode* right = parse_exponentiation(); // Right Associative
        BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
        if (expr) {
            ExpressionNode* ldup = expr->duplicate();
            if (ldup) bin->left = register_node(ldup); else bin->left = expr;
        } else bin->left = nullptr;
        if (right) {
            ExpressionNode* rdup = right->duplicate();
            if (rdup) bin->right = register_node(rdup); else bin->right = right;
        } else bin->right = nullptr;
        bin->op = "**";
        return bin;
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_unary() {
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "-") {
        advance();
        ExpressionNode* operand = parse_unary();
        UnaryOpNode* u = static_cast<UnaryOpNode*>(register_node(new UnaryOpNode()));
        u->op = "-"; // Unary Minus
        if (operand) {
            ExpressionNode* odup = operand->duplicate();
            if (odup) u->operand = register_node(odup); else u->operand = operand;
        } else u->operand = nullptr;
        return u;
    }
    // Check for Not (Logical Not is usually higher than Relational but lower than Arithmetic? In VB Not is bitwise too)
    // Actually parse_not is separate.
    return parse_exponentiation();
}

ExpressionNode* VisualGasicParser::parse_factor() {
    // Check for Leading Dot (With Context) (e.g. .x)
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
        // This is a MemberAccess on "Implicit With"
        // We handle this by creating a MEMBER_ACCESS with NULL base
        // But parse_call_or_member expects a 'left' node.
        // We can create a dummy WITH_CONTEXT node as base.
        advance(); // Eat .
        
        ExpressionNode* base = static_cast<ExpressionNode*>(register_node(new ExpressionNode()));
        base->type = ExpressionNode::WITH_CONTEXT;
        
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
             MemberAccessNode* ma = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
             ma->base_object = base;
             ma->member_name = peek().value;
             advance();
             
             // Check for more dots? passed back to caller
             // But valid VB is .Prop.SubProp
             // The loop in parse_call_or_member handles that if we return 'ma'.
             return ma;
        } else {
             error("Expected member name after .");
             return nullptr;
        }
    }

    if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER) || 
        check(VisualGasicTokenizer::TOKEN_LITERAL_FLOAT) ||
        check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
        
        LiteralNode* node = static_cast<LiteralNode*>(register_node(new LiteralNode()));
        node->value = peek().value;
        advance();
        return node;
    }
    
    if (check(VisualGasicTokenizer::TOKEN_STRING_INTERP)) {
         String raw = peek().value;
         advance();
         
         ExpressionNode* root = nullptr;
         int start = 0;
         int len = raw.length();
         
         while (start < len) {
             int open = raw.find("{", start);
             if (open == -1) {
                 String remainder = raw.substr(start);
                 if (!remainder.is_empty()) {
                     LiteralNode* lit = static_cast<LiteralNode*>(register_node(new LiteralNode())); lit->value = remainder;
                     if (!root) root = lit;
                     else {
                         BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                         bin->left = root; bin->right = lit; bin->op = "&";
                         root = bin;
                     }
                 }
                 break;
             }
             
             if (open > start) {
                 String prefix = raw.substr(start, open - start);
                 LiteralNode* lit = static_cast<LiteralNode*>(register_node(new LiteralNode())); lit->value = prefix;
                 if (!root) root = lit;
                 else {
                     BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                     bin->left = root; bin->right = lit; bin->op = "&";
                     root = bin;
                 }
             }
             
             int close = raw.find("}", open);
             if (close == -1) {
                 UtilityFunctions::print("Parser Error: Unclosed interpolation brace in string");
                 break;
             }
             
             String expr_str = raw.substr(open + 1, close - open - 1);
             
             VisualGasicTokenizer sub_tok;
             Vector<VisualGasicTokenizer::Token> sub_tokens = sub_tok.tokenize(expr_str);
             VisualGasicParser sub_parser;
             sub_parser.tokens = sub_tokens;
             // We deliberately do not pass full module context here as it's a lightweight parse
             // But if expr uses constants, it might fail? 
             // Variable names are just identifiers, resolved at runtime, so it's fine.
             
             ExpressionNode* sub_expr = sub_parser.parse_expression();
             if (sub_expr) {
                  // Duplicate the sub-parser expression into this parser's ownership
                  ExpressionNode* transferred = nullptr;
                  ExpressionNode* d = sub_expr->duplicate();
                  if (d) transferred = register_node(d); else transferred = sub_expr;
                  if (!root) root = transferred;
                  else {
                      BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                      // root is owned by this parser; transferred is duplicated/registered above
                      bin->left = root; bin->right = transferred; bin->op = "&";
                      root = bin;
                  }
             }
             
             start = close + 1;
         }
         
         if (!root) {
              LiteralNode* empty = static_cast<LiteralNode*>(register_node(new LiteralNode())); empty->value = "";
              return empty;
         }
         return root;
    }


    // Check for True/False/Action Keys/OO
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        String k = peek().value;
        if (k.nocasecmp_to("True") == 0) {
            advance();
            LiteralNode* node = static_cast<LiteralNode*>(register_node(new LiteralNode()));
            node->value = true;
            return node;
        }
        if (k.nocasecmp_to("False") == 0) {
            advance();
            LiteralNode* node = static_cast<LiteralNode*>(register_node(new LiteralNode()));
            node->value = false;
            return node;
        }
        if (k.nocasecmp_to("Me") == 0) {
            advance();
            return static_cast<MeNode*>(register_node(new MeNode()));
        }
        if (k.nocasecmp_to("Super") == 0 || k.nocasecmp_to("MyBase") == 0) {
            advance();
            return static_cast<SuperNode*>(register_node(new SuperNode()));
        }
        if (k.nocasecmp_to("New") == 0) {
            advance();
             if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                 NewNode* n = static_cast<NewNode*>(register_node(new NewNode()));
                 n->class_name = peek().value;
                 advance();
                 
                 // Handle arguments for New Class(Args) - mainly for MemoryBlock
                 if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                     advance(); // Eat (
                     if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                         do {
                             if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) break;
                             {
                                 ExpressionNode* _tmp = parse_expression();
                                 if (_tmp) {
                                     n->args.push_back(_tmp);
                                     unregister_node(_tmp);
                                 }
                             }
                             if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                                 advance();
                             } else {
                                 break;
                             }
                         } while (!is_at_end());
                     }
                     if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) advance();
                 }
                 
                 return n;
             } else {
                 error("Expected Class Name after New");
                 return nullptr;
             }
        }

    }

    // Check for IIf
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("IIf") == 0) {
        advance(); // Eat IIf
        match(VisualGasicTokenizer::TOKEN_PAREN_OPEN);
        ExpressionNode* cond = parse_expression();
        match(VisualGasicTokenizer::TOKEN_COMMA);
        
        // Check optional "True ="
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("True") == 0) {
             if (current_pos+1 < tokens.size() && tokens[current_pos+1].type == VisualGasicTokenizer::TOKEN_OPERATOR && tokens[current_pos+1].value == "=") {
                  advance(); advance(); // Eat True =
             }
        }
        ExpressionNode* true_part = parse_expression();
        match(VisualGasicTokenizer::TOKEN_COMMA);

        // Check optional "False ="
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("False") == 0) {
             if (current_pos+1 < tokens.size() && tokens[current_pos+1].type == VisualGasicTokenizer::TOKEN_OPERATOR && tokens[current_pos+1].value == "=") {
                  advance(); advance(); // Eat False =
             }
        }
        ExpressionNode* false_part = parse_expression();
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
        
        IIfNode* iif = static_cast<IIfNode*>(register_node(new IIfNode()));
        iif->condition = cond;
        iif->true_part = true_part;
        iif->false_part = false_part;
        return iif;
    }
    
    // Check for Nothing
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Nothing") == 0) {
        LiteralNode* node = static_cast<LiteralNode*>(register_node(new LiteralNode()));
        node->value = Variant(); // Nil
        advance();
        return node; 
    }

    // Check for Me
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Me") == 0) {
        advance();
        ExpressionNode* left = static_cast<ExpressionNode*>(register_node(new ExpressionNode()));
        left->type = ExpressionNode::ME;
        
        // Handle member access
        while (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
            advance(); // Eat .
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                MemberAccessNode* member = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
                member->base_object = left;
                member->member_name = peek().value;
                advance();
                left = member;
            } else {
                UtilityFunctions::print("Parser Error: Expected member name after .");
            }
        }
        
        if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
            advance();
            CallExpression* call = static_cast<CallExpression*>(register_node(new CallExpression()));
            if (left->type == ExpressionNode::MEMBER_ACCESS) {
                MemberAccessNode* ma = (MemberAccessNode*)left;
                call->base_object = ma->base_object;
                call->method_name = ma->member_name;
                ma->base_object = nullptr; unregister_node(ma); delete ma;
            } else {
                 // Me(...) call? Invalid?
                 // delete left; 
                 // error("Invalid call target"); return nullptr;
                 // Maybe allow Me() if it means something? No.
            }
            // Args
             if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                while (true) {
                    ExpressionNode* expr = parse_expression();
                    if (expr) { call->arguments.push_back(expr); unregister_node(expr); }
                    if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                    break;
                }
            }
            if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) UtilityFunctions::print("Expected )");
            left = call;
        }
        
        return left;
    }

    // Check for New
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("New") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             NewNode* n = static_cast<NewNode*>(register_node(new NewNode()));
             n->class_name = peek().value;
             advance();
             return n;
        } else {
             error("Expected class name after New");
             return nullptr; 
        }
    }
    
    bool is_ident = check(VisualGasicTokenizer::TOKEN_IDENTIFIER);
    bool is_special_base = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
         String kv = peek().value;
         if (kv.nocasecmp_to("Input") == 0) is_special_base = true;
    }

    if (is_ident || is_special_base) {
        String name = peek().value;
        advance();
        
        ExpressionNode* left = nullptr;

        // Function Call? "Func(x)"
        if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
            advance(); // Eat (
            CallExpression* call = static_cast<CallExpression*>(register_node(new CallExpression()));
            call->method_name = name;
            
            if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                // Parse arguments
                while (true) {
                    ExpressionNode* expr = parse_expression();
                    if (expr) { call->arguments.push_back(expr); unregister_node(expr); }
                    
                    if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                    break;
                }
            }
            
            if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                 UtilityFunctions::print("Parser Error: Expected ) after function call arguments");
            }
            left = call;
        } else {
            // Variable
            VariableNode* node = static_cast<VariableNode*>(register_node(new VariableNode()));
            node->name = name;
            left = node;
        }

        // Check for member access .Field
        while (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
            advance(); // Eat .
            
            // Allow Identifier OR Keyword (e.g. Input, New)
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                MemberAccessNode* member = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
                member->base_object = left;
                member->member_name = peek().value;
                advance();
                left = member;

                // Check for Method Call syntax .Method(Args)
                if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                    advance(); // Eat (
                    CallExpression* call = static_cast<CallExpression*>(register_node(new CallExpression()));
                    call->base_object = member->base_object;
                    call->method_name = member->member_name;
                    member->base_object = nullptr; unregister_node(member); delete member;
                    
                    if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                         while(true) {
                             ExpressionNode* expr = parse_expression();
                             if (expr) { call->arguments.push_back(expr); unregister_node(expr); }
                             
                             if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                             break;
                         }
                    }
                    if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                         UtilityFunctions::print("Parser Error: Expected ) after method call");
                    }
                    left = call;
                }
            } else {
                UtilityFunctions::print("Parser Error: Expected member name after .");
            }
        }

        return left;
    }
    
    if (match(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        ExpressionNode* expr = parse_expression();
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             UtilityFunctions::print("Parser Error: Expected )");
        }
        return expr;
    }
    
    error("Unexpected token in expression: " + String(peek().value));
    advance();
    return nullptr;
}

// --- Statement Parsing ---

WithStatement* VisualGasicParser::parse_with() {
    advance(); // Eat With
    WithStatement* stmt = static_cast<WithStatement*>(register_node(new WithStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->expression = _tmp;
        unregister_node(_tmp);
    }
    
    // Parse Block
    while (!match(VisualGasicTokenizer::TOKEN_EOF)) {
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("End") == 0) {
            VisualGasicTokenizer::Token next = peek(1);
            if (String(next.value).nocasecmp_to("With") == 0) {
                advance(); // Eat End
                advance(); // Eat With
                break;
            }
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else {
             if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
             else if (!is_at_end()) advance();
        }
    }
    return stmt;
}

DimStatement* VisualGasicParser::parse_dim() {
    advance(); // Eat Dim
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        UtilityFunctions::print("Parser Error: Expected variable name after Dim");
        return nullptr;
    }
    
    DimStatement* stmt = static_cast<DimStatement*>(register_node(new DimStatement()));
    stmt->variable_name = peek().value;
    advance();
    
    // Check for Array declaration: Dim A(10) or Dim A(5, 5)
    if (match(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        do {
            {
                ExpressionNode* _tmp = parse_expression();
                if (_tmp) { stmt->array_sizes.push_back(_tmp); unregister_node(_tmp); }
            }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
            } else {
                break;
            }
        } while (!is_at_end() && !check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE));

        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             UtilityFunctions::print("Parser Error: Expected ) in array declaration");
        }
    }
    
    // Optional: As Type
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance(); // Eat As
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             stmt->type_name = peek().value;
             advance();
        } else {
             UtilityFunctions::print("Parser Error: Expected type name after As");
        }
    }

    // Optional: = Initializer
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
        advance(); // Eat =
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->initializer = _tmp;
            unregister_node(_tmp);
        }
    }
    
    return stmt;
}

IfStatement* VisualGasicParser::parse_if() {
    advance(); // Eat If
    
    IfStatement* stmt = static_cast<IfStatement*>(register_node(new IfStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->condition = _tmp;
        unregister_node(_tmp);
    }
    
    bool is_block = false;
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Then") == 0) {
        advance();
    }
    
    // Skip comments to correctly detect block If (If ... Then ' comment \n)
    while (check(VisualGasicTokenizer::TOKEN_COMMENT)) {
        advance();
    }
    
    if (match(VisualGasicTokenizer::TOKEN_NEWLINE)) {
        is_block = true;
    }
    
    if (is_block) {
        IfStatement* current_if_node = stmt;
        Vector<Statement*>* current_branch = &stmt->then_branch;

        while (!is_at_end()) {
            // Check for End If / Else / Elif
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                 String val = peek().value;
                 if (val.nocasecmp_to("End") == 0) {
                      // Check next for If
                      if (peek(1).value.operator String().nocasecmp_to("If") == 0) {
                          advance(); advance(); // Eat End If
                          break;
                      }
                 }
                 if (val.nocasecmp_to("Else") == 0) {
                     advance(); // Eat Else
                     current_branch = &current_if_node->else_branch;
                     continue;
                 }
                 if (val.nocasecmp_to("Elif") == 0 || val.nocasecmp_to("ElseIf") == 0) {
                     advance(); // Eat Elif
                     
                     IfStatement* next_if = static_cast<IfStatement*>(register_node(new IfStatement()));
                     {
                         ExpressionNode* _tmp = parse_expression();
                         next_if->condition = _tmp;
                         unregister_node(_tmp);
                     }
                     
                     if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Then") == 0) {
                        advance();
                     }

                     // Link to previous Else
                     current_if_node->else_branch.push_back(next_if);
                     unregister_node(next_if);
                     
                     // Switch Context
                     current_if_node = next_if;
                     current_branch = &current_if_node->then_branch;
                     
                     continue;
                 }
            }
            
            Statement* s = parse_statement();
            if (s) { current_branch->push_back(s); unregister_node(s); }
            else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else if (check(VisualGasicTokenizer::TOKEN_EOF)) break;
            else advance(); // Skip garbage
        }
    } else {
        // Single line If - Parse one statement
        // Or multiple separated by colon?
        // For now, accept one statement.
        Statement* s = parse_statement();
        if (s) {
            stmt->then_branch.push_back(s);
            unregister_node(s);

            // Check for Else (Single Line)
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Else") == 0) {
                 advance();
                 Statement* el = parse_statement();
                 if (el) { stmt->else_branch.push_back(el); unregister_node(el); }
            }
        }
    }
    
    return stmt;
}

Statement* VisualGasicParser::parse_for() {
    advance(); // Eat For

    // Check for "Each"
    bool is_for_each = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Each") == 0) {
        is_for_each = true;
        advance();
    }
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) return nullptr;
    String var_name = peek().value;
    
    // Check for "For i In list" (Python style)
    if (!is_for_each && peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD && String(peek(1).value).nocasecmp_to("In") == 0) {
        is_for_each = true;
    }

    advance(); // Eat var name

    if (is_for_each) {
        if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) || String(peek().value).nocasecmp_to("In") != 0) {
            error("Expected 'In' after For Each variable");
            return nullptr;
        }
        advance(); // Eat In
        
        ForEachStatement* stmt = static_cast<ForEachStatement*>(register_node(new ForEachStatement()));
        stmt->variable_name = var_name;
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->collection = _tmp;
            unregister_node(_tmp);
        }
        
        while (!match(VisualGasicTokenizer::TOKEN_EOF)) {
             // Handle Next
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Next") == 0) {
                advance();
                // Optional variable name after Next
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) advance();
                break;
            }
            Statement* s = parse_statement();
            if (s) { stmt->body.push_back(s); unregister_node(s); }
            else {
                if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                else if (!is_at_end()) advance(); // Skip garbage
            }
        }
        return stmt;
    }

    // Standard For Loop
    ForStatement* stmt = static_cast<ForStatement*>(register_node(new ForStatement()));
    stmt->variable_name = var_name;
    
    if (!match(VisualGasicTokenizer::TOKEN_OPERATOR)) { // Expect =
        UtilityFunctions::print("Parser Error: Expected = in For");
    }
    
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->from_val = _tmp;
        unregister_node(_tmp);
    }
    
    bool found_to = false;
    VisualGasicTokenizer::Token t_to = peek();
    
    // UtilityFunctions::print("DEBUG FOR: Next token after from_val: ", t_to.value, " Type: ", t_to.type);
    
    if ((t_to.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_to.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)
        && t_to.value.operator String().nocasecmp_to("To") == 0) {
        
        advance();
        found_to = true;
    }
    
    if (found_to) {
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->to_val = _tmp;
            unregister_node(_tmp);
        }
    } else {
        UtilityFunctions::print("Parser Error: Expected To in For statement");
    }
    
    // Step ?
    VisualGasicTokenizer::Token t_step = peek();
    if ((t_step.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_step.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)
        && t_step.value.operator String().nocasecmp_to("Step") == 0) {
        advance();
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->step_val = _tmp;
            unregister_node(_tmp);
        }
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Body
    while (!is_at_end()) {
        if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && peek().value.operator String().nocasecmp_to("Next") == 0) {
            advance();
            // Optional variable name
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) advance();
            break;
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else advance();
    }
    
    return stmt;
}

SelectStatement* VisualGasicParser::parse_select() {
    advance(); // Eat Select
    
    // Check Case
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Case") == 0) {
        advance();
    } else {
        UtilityFunctions::print("Parser Error: Expected Case after Select");
    }
    
    SelectStatement* stmt = static_cast<SelectStatement*>(register_node(new SelectStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->expression = _tmp;
        unregister_node(_tmp);
    }
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();
        
        // End Select
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(t.value).nocasecmp_to("End") == 0) {
            VisualGasicTokenizer::Token next = peek(1);
            if ((next.type == VisualGasicTokenizer::TOKEN_KEYWORD || next.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(next.value).nocasecmp_to("Select") == 0) {
                advance(); // End
                advance(); // Select
                break;
            }
        }
        
        // Case ...
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(t.value).nocasecmp_to("Case") == 0) {
            advance(); // Eat Case
            
            CaseBlock* block = static_cast<CaseBlock*>(register_node(new CaseBlock()));
            
            // Case Else
            if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && String(peek().value).nocasecmp_to("Else") == 0) {
                advance();
                block->is_else = true;
            } else {
                // Parse values: Case 1, 2, 3
                do {
                    {
                        ExpressionNode* _tmp = parse_expression();
                        if (_tmp) { block->values.push_back(_tmp); unregister_node(_tmp); }
                    }
                    if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                    break;
                } while (!is_at_end());
            }
            
            match(VisualGasicTokenizer::TOKEN_NEWLINE);
            
            // Parse Body until next Case or End Select
            while (!is_at_end()) {
                VisualGasicTokenizer::Token next = peek();
                if ((next.type == VisualGasicTokenizer::TOKEN_KEYWORD || next.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(next.value).nocasecmp_to("Case") == 0) break;
                if ((next.type == VisualGasicTokenizer::TOKEN_KEYWORD || next.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(next.value).nocasecmp_to("End") == 0) {
                     VisualGasicTokenizer::Token next2 = peek(1);
                     if (String(next2.value).nocasecmp_to("Select") == 0) break;
                }
                
                Statement* s = parse_statement();
                if (s) { block->body.push_back(s); unregister_node(s); }
                else {
                    if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                    else break; // Avoid infinite loop or move next
                }
            }
            stmt->cases.push_back(block);
            unregister_node(block);
            continue;
        }

        if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) { 
            advance(); 
        } else {
            // Garbage inside parsing Select block (outside Case)?
             current_pos++;
        }
    }
    
    return stmt;
}

WhileStatement* VisualGasicParser::parse_while() {
    advance(); // Eat While
    ExpressionNode* condition = parse_expression();
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    WhileStatement* stmt = static_cast<WhileStatement*>(register_node(new WhileStatement()));
    stmt->condition = condition;
    
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(t.value).nocasecmp_to("Wend") == 0) {
            advance();
            break;
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }
    return stmt;
}

DoStatement* VisualGasicParser::parse_do() {
    advance(); // Eat Do
    
    DoStatement* stmt = static_cast<DoStatement*>(register_node(new DoStatement()));
    
    VisualGasicTokenizer::Token t = peek();
    String val = t.value;
    
    if (val.nocasecmp_to("While") == 0) {
        advance();
        stmt->condition_type = DoStatement::WHILE;
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->condition = _tmp;
            unregister_node(_tmp);
        }
    } else if (val.nocasecmp_to("Until") == 0) {
        advance();
        stmt->condition_type = DoStatement::UNTIL;
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->condition = _tmp;
            unregister_node(_tmp);
        }
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t_loop = peek();
        if ((t_loop.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_loop.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(t_loop.value).nocasecmp_to("Loop") == 0) {
            advance();
            
            // Post-condition
            if (stmt->condition_type == DoStatement::NONE) {
                  VisualGasicTokenizer::Token t_post = peek();
                  if (String(t_post.value).nocasecmp_to("While") == 0) {
                      advance();
                      stmt->condition_type = DoStatement::WHILE;
                      stmt->is_post_condition = true;
                      {
                          ExpressionNode* _tmp = parse_expression();
                          stmt->condition = _tmp;
                          unregister_node(_tmp);
                      }
                  } else if (String(t_post.value).nocasecmp_to("Until") == 0) {
                      advance();
                      stmt->condition_type = DoStatement::UNTIL;
                      stmt->is_post_condition = true;
                      {
                          ExpressionNode* _tmp = parse_expression();
                          stmt->condition = _tmp;
                          unregister_node(_tmp);
                      }
                  }
            }
            break;
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }
    
    return stmt;
}

// In parse_statement, handle Return and Continue.
// Since parse_statement is likely defined before, I need to check where it is.
// I'll search for parse_statement body first or assume I am inserting helper methods or adding to the switch/if chain in parse_statement.
// But first let's see where parse_statement is.
// I was reading parse_assignment_or_call which is CALLED by parse_statement.

// Let's implement parse_return and parse_continue and then hook them up.

Statement* VisualGasicParser::parse_return() {
    advance(); // Eat Return
    ReturnStatement* ret = static_cast<ReturnStatement*>(register_node(new ReturnStatement()));
    if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
        {
            ExpressionNode* _tmp = parse_expression();
            ret->return_value = _tmp;
            unregister_node(_tmp);
        }
    }
    return ret;
}

Statement* VisualGasicParser::parse_continue() {
    advance(); // Eat Continue
    ContinueStatement* c = static_cast<ContinueStatement*>(register_node(new ContinueStatement()));
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        String val = peek().value;
        if (val.nocasecmp_to("For") == 0) {
            c->loop_type = ContinueStatement::FOR;
            advance();
        } else if (val.nocasecmp_to("Do") == 0) {
            c->loop_type = ContinueStatement::DO;
            advance();
        } else if (val.nocasecmp_to("While") == 0) {
            c->loop_type = ContinueStatement::WHILE;
            advance();
        }
    }
    return c;
}

Statement* VisualGasicParser::parse_assignment_or_call() {
    ExpressionNode* head = nullptr;

    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
        advance(); // Eat .
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             MemberAccessNode* ma = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
             ExpressionNode* ctx = static_cast<ExpressionNode*>(register_node(new ExpressionNode()));
             ctx->type = ExpressionNode::WITH_CONTEXT;
             ma->base_object = ctx;
             ma->member_name = peek().value;
             head = ma;
             advance();
        } else {
             UtilityFunctions::print("Parser Error: Expected Identifier after .");
             return nullptr;
        }
    } else {
        String name = peek().value;
        advance();
           if (name.nocasecmp_to("Me") == 0) {
               head = static_cast<ExpressionNode*>(register_node(new ExpressionNode()));
               head->type = ExpressionNode::ME;
           } else {
               VariableNode* var = static_cast<VariableNode*>(register_node(new VariableNode()));
               var->name = name;
               head = var;
           }
    }
    
    // Parse chain of dots and parens to build the L-Value expression
    while(true) {
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                 MemberAccessNode* ma = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
                 ma->base_object = head;
                 ma->member_name = peek().value;
                 head = ma;
                 advance();
            } else {
                 UtilityFunctions::print("Parser Error: Expected Identifier after .");
                 break;
            }
        }
        else if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
             advance(); // Eat (
             ArrayAccessNode* aa = static_cast<ArrayAccessNode*>(register_node(new ArrayAccessNode()));
             aa->base = head;
             
             if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                 while(true) {
                     {
                         ExpressionNode* _tmp = parse_expression();
                         if (_tmp) { aa->indices.push_back(_tmp); unregister_node(_tmp); }
                     }
                     if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                     break;
                 }
             }
             if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                  UtilityFunctions::print("Parser Error: Expected )");
             }
             head = aa;
        } else {
             break;
        }
    }

    if (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = peek().value;
        if (op == "=") {
            advance(); // Eat =
            // Defensive: sometimes tokenizer/positions can leave stray '=' tokens; skip any additional '=' to reach RHS
            while (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
                advance();
            }
             
            if (current_module && current_module->option_explicit && head->type == ExpressionNode::VARIABLE) {
                String var_name = ((VariableNode*)head)->name;
                bool declared = false;
                
                for(int i=0; i<current_module->variables.size(); i++) {
                    if (current_module->variables[i]->name.nocasecmp_to(var_name) == 0) {
                        declared = true; break;
                    }
                }
                if (!declared) {
                     for(int i=0; i<current_module->constants.size(); i++) {
                         if (current_module->constants[i]->name.nocasecmp_to(var_name) == 0) {
                             declared = true; break;
                         }
                     }
                }
            }
            
            AssignmentStatement* assign = static_cast<AssignmentStatement*>(register_node(new AssignmentStatement()));
            assign->target = head;
            {
                ExpressionNode* _tmp = parse_expression();
                assign->value = _tmp;
                unregister_node(_tmp);
            }
            return assign;

        } else if (op == "+=" || op == "-=" || op == "*=" || op == "/=") {
            advance(); // Eat Op
            
            AssignmentStatement* assign = static_cast<AssignmentStatement*>(register_node(new AssignmentStatement()));
            assign->target = head; 
            ExpressionNode* lhs_read = head->duplicate();
            
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            bin->left = lhs_read;
            {
                ExpressionNode* _tmp = parse_expression();
                bin->right = _tmp;
                unregister_node(_tmp);
            }
            
            if (op == "+=") bin->op = "+";
            else if (op == "-=") bin->op = "-";
            else if (op == "*=") bin->op = "*";
            else if (op == "/=") bin->op = "/";
            
            assign->value = bin;
            return assign;

        } else if (op == "++" || op == "--") {
            advance(); // Eat Op

            AssignmentStatement* assign = static_cast<AssignmentStatement*>(register_node(new AssignmentStatement()));
            assign->target = head;
            ExpressionNode* lhs_read = head->duplicate();
            
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            bin->left = lhs_read;
            
            LiteralNode* one = static_cast<LiteralNode*>(register_node(new LiteralNode()));
            one->value = 1;
            bin->right = one;
            
            if (op == "++") bin->op = "+";
            else bin->op = "-";
            
            assign->value = bin;
            return assign;
        }
    }
    
    // Call Statement conversion
            CallStatement* call = static_cast<CallStatement*>(register_node(new CallStatement()));
    
    if (head->type == ExpressionNode::ARRAY_ACCESS) {
        ArrayAccessNode* aa = (ArrayAccessNode*)head;
        ExpressionNode* callee = aa->base;
        aa->base = nullptr; 
        
           // Transfer indices to call arguments and unregister them from the parser tracker
           for (int i = 0; i < aa->indices.size(); i++) {
              ExpressionNode* idx = aa->indices[i];
              if (idx) {
                 call->arguments.push_back(idx);
                 unregister_node(idx);
              }
           }
           aa->indices.clear(); 

           if (callee->type == ExpressionNode::VARIABLE) {
              call->method_name = ((VariableNode*)callee)->name;
              unregister_node(callee); delete callee; 
           } else if (callee->type == ExpressionNode::MEMBER_ACCESS) {
               MemberAccessNode* ma = (MemberAccessNode*)callee;
               call->method_name = ma->member_name;
               call->base_object = ma->base_object;
               ma->base_object = nullptr; 
               unregister_node(ma); delete ma;
           }
           unregister_node(aa); delete aa;
    } else if (head->type == ExpressionNode::VARIABLE) {
         call->method_name = ((VariableNode*)head)->name;
            unregister_node(head); delete head;
    } else if (head->type == ExpressionNode::MEMBER_ACCESS) {
         MemberAccessNode* ma = (MemberAccessNode*)head;
         call->method_name = ma->member_name;
         call->base_object = ma->base_object;
         ma->base_object = nullptr;
            unregister_node(head); delete head;
    } else {
            unregister_node(head); delete head; 
    }
    
    if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF) && 
        !(check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ":")) {
        
        if (!call->arguments.is_empty()) {
             if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
        }
        
        while (true) {
            ExpressionNode* expr = parse_expression();
            if (expr) { call->arguments.push_back(expr); unregister_node(expr); }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
                continue;
            }
            break;
        }
    }

    return call;
}

StructDefinition* VisualGasicParser::parse_struct() {
    advance(); // Eat Type
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        UtilityFunctions::print("Parser Error: Expected struct name after Type");
        return nullptr;
    }
    
    StructDefinition* def = static_cast<StructDefinition*>(register_node(new StructDefinition()));
    def->name = peek().value;
    advance();
    
    // Check for newline
    if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
        advance();
    }
    
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();
        // UtilityFunctions::print("ParseStruct Loop: ", t.value, " Type: ", t.type);

        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("End") == 0) {
            advance();
            if (match(VisualGasicTokenizer::TOKEN_KEYWORD) && String(previous().value).nocasecmp_to("Type") == 0) {
                 break;
            }
            // Ignore stray 'End' inside struct or treat as member if identifier check passes?
            // Actually if we consumed End we must handle it. 
            // If it wasn't End Type, it might be End Sub (Error) or End something else.
            // But for now let's assume if it wasn't End Type, we just continue (missing member name loop will handle)
        }
        
        // Handle Member Definition: Name As Type
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            StructMember member;
            member.name = peek().value;
            advance();
            
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
                advance(); // Eat As
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                    member.type = peek().value;
                    advance();
                }
            } else {
                member.type = "Variant";
            }
            
            def->members.push_back(member);
            // UtilityFunctions::print("Parser: Added member ", member.name, " As ", member.type, " to ", def->name);
            
            // Expect newline
             if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
                advance();
            }
        } else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
             advance();
        } else {
             // Unexpected
             advance(); 
        }
    }
    
    return def;
}

PrintStatement* VisualGasicParser::parse_print() {
    advance(); // Eat Print
    PrintStatement* stmt = static_cast<PrintStatement*>(register_node(new PrintStatement()));
    
    // Check for #1
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "#") {
        advance(); // Eat #
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->file_number = _tmp;
            unregister_node(_tmp);
        }
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            advance();
        }
    }
    
    // Parse expression(s)
    // currently only one supported by AST
    if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF) && !check(VisualGasicTokenizer::TOKEN_COLON)) {
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->expression = _tmp;
            unregister_node(_tmp);
        }
    }
    
    return stmt;
}

OpenStatement* VisualGasicParser::parse_open() {
    advance(); // Eat Open
    
    // Open path For Mode As #Num
    OpenStatement* stmt = static_cast<OpenStatement*>(register_node(new OpenStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->path = _tmp;
        unregister_node(_tmp);
    }
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("For") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String m = peek().value;
            if (m.nocasecmp_to("Input") == 0) stmt->mode = OpenStatement::MODE_INPUT;
            else if (m.nocasecmp_to("Output") == 0) stmt->mode = OpenStatement::MODE_OUTPUT;
            else if (m.nocasecmp_to("Append") == 0) stmt->mode = OpenStatement::MODE_APPEND;
            else UtilityFunctions::print("Parser Error: Unknown Open mode ", m);
            advance();
        }
    }
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "#") {
            advance();
        } 
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->file_number = _tmp;
            unregister_node(_tmp);
        }
    }
    
    return stmt;
}

CloseStatement* VisualGasicParser::parse_close() {
    advance(); // Eat Close
    
    CloseStatement* stmt = static_cast<CloseStatement*>(register_node(new CloseStatement()));
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "#") {
        advance();
    }
    
    if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
         {
             ExpressionNode* _tmp = parse_expression();
             stmt->file_number = _tmp;
             unregister_node(_tmp);
         }
    }
    
    return stmt;
}

SeekStatement* VisualGasicParser::parse_seek() {
    advance(); // Eat Seek
    // Seek #FileNum, Position
    
    SeekStatement* stmt = static_cast<SeekStatement*>(register_node(new SeekStatement()));
    
    // Check #
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "#") {
        advance();
    }
    
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->file_number = _tmp;
        unregister_node(_tmp);
    }
        if (!stmt->file_number) {
        error("Expected file number in Seek statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
        advance();
        } else {
        error("Expected comma after file number in Seek statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->position = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->position) {
        error("Expected position expression in Seek statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    return stmt;
}

KillStatement* VisualGasicParser::parse_kill() {
    advance(); // Eat Kill
    KillStatement* stmt = static_cast<KillStatement*>(register_node(new KillStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->path = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->path) {
        error("Expected path expression in Kill statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    return stmt;
}

NameStatement* VisualGasicParser::parse_name() {
    advance(); // Eat Name
    NameStatement* stmt = static_cast<NameStatement*>(register_node(new NameStatement()));
    
    // Name Old As New
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->old_path = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->old_path) {
        error("Expected old file path in Name statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
    } else {
        error("Expected 'As' in Name statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->new_path = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->new_path) {
        error("Expected new file path in Name statement");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    
    return stmt;
}

DataStatement* VisualGasicParser::parse_data() {
    advance(); // Eat Data
    DataStatement* stmt = static_cast<DataStatement*>(register_node(new DataStatement()));
    
    while (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
        {
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) { stmt->values.push_back(_tmp); unregister_node(_tmp); }
        }
        
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            advance();
        } else {
            break;
        }
    }
    return stmt;
}

ReadStatement* VisualGasicParser::parse_read() {
    advance(); // Eat Read
    ReadStatement* stmt = static_cast<ReadStatement*>(register_node(new ReadStatement()));
    
    while (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
        // Parse L-Values (Variables, Array elements, Properties)
        {
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) { stmt->targets.push_back(_tmp); unregister_node(_tmp); }
        }
        
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            advance();
        } else {
            break;
        }
    }
    return stmt;
}

RestoreStatement* VisualGasicParser::parse_restore() {
    advance(); // Eat Restore
    RestoreStatement* stmt = static_cast<RestoreStatement*>(register_node(new RestoreStatement()));
    
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        stmt->label_name = peek().value;
        advance();
    }
    return stmt;
}

Vector<ExpressionNode*> VisualGasicParser::parse_data_values_from_text(const String& text) {
    Vector<ExpressionNode*> values;
    
    // Wrap to hack reused parser
    VisualGasicTokenizer tokenizer;
    String wrapped_content = "Data " + text;
    Vector<VisualGasicTokenizer::Token> wrapped_tokens = tokenizer.tokenize(wrapped_content);
    
    VisualGasicParser sub_parser;
    ModuleNode* sub_module = sub_parser.parse(wrapped_tokens);
    
    if (sub_parser.errors.size() > 0) {
        UtilityFunctions::print("Error parsing data text: " + sub_parser.errors[0].message);
        if (sub_module) delete sub_module;
        return values;
    }
    
    if (sub_module) {
        for(int i=0; i<sub_module->global_statements.size(); i++) {
            Statement* s = sub_module->global_statements[i];
            if (s->type == STMT_DATA) {
                DataStatement* ds = (DataStatement*)s;
                for(int k=0; k<ds->values.size(); k++) {
                    values.push_back(ds->values[k]);
                    ds->values.write[k] = nullptr; // prevent delete by ModuleNode
                }
            }
        }
        delete sub_module;
    }
    return values;
}

DataStatement* VisualGasicParser::parse_data_file() {
    advance(); // Eat DataFile (or identifier if parsed as such)
    
    String path;
    if (check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
        path = peek().value;
        advance();
    } else {
        error("Expected file path string after DataFile");
        return nullptr;
    }
    
    if (path.begins_with("res://")) {
         // Good
    }
    
    Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
    if (file.is_null()) {
        error("Could not open DataFile: " + path);
        return nullptr;
    }
    
    String content = file->get_as_text();
    file->close();
    
    DataStatement* stmt = static_cast<DataStatement*>(register_node(new DataStatement()));
    stmt->values = parse_data_values_from_text(content);
    return stmt;
}

LoadDataStatement* VisualGasicParser::parse_load_data() {
    advance(); // Eat LoadData
    
    LoadDataStatement* stmt = static_cast<LoadDataStatement*>(register_node(new LoadDataStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->path_expression = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->path_expression) {
        error("Expected string expression for file path after LoadData");
        unregister_node(stmt); delete stmt;
        return nullptr;
    }
    return stmt;
}

InputStatement* VisualGasicParser::parse_input(bool is_line) {
    if (is_line) advance(); // Input token
    else advance(); // Eat Input
    
    InputStatement* stmt = static_cast<InputStatement*>(register_node(new InputStatement()));
    stmt->is_line_input = is_line;
    
    // Check #
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "#") {
        advance();
        stmt->file_number = parse_expression();
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
    } else {
        // Console Input
        // Not supporting prompt string for now: Input "Prompt", var
        if (check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
             // Consume prompt? Or error?
             // BASIC: Input ["Prompt",] var
             advance();
             if (check(VisualGasicTokenizer::TOKEN_COMMA) || check(VisualGasicTokenizer::TOKEN_COLON)) advance(); // semicolon also allowed?
        }
    }
    
    // Variables
    while(true) {
        // Need to parse L-Value expression. 
        // We can reuse parse_expression but we need to verify it's an L-Value later?
        // Or duplicate the logic?
        // parse_expression will parse Variable, Member, Array.
        {
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) { stmt->variables.push_back(_tmp); unregister_node(_tmp); }
        }
        
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            advance();
            continue;
        }
        break;
    }
    
    return stmt;
}

ExitStatement* VisualGasicParser::parse_exit() {
    advance(); // consume Exit
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        String type = String(peek().value).to_lower();
        
        ExitStatement* s = static_cast<ExitStatement*>(register_node(new ExitStatement()));
        bool valid = false;
        
        if (type == "sub") {
            s->exit_type = ExitStatement::EXIT_SUB;
            valid = true;
        } else if (type == "function") {
            s->exit_type = ExitStatement::EXIT_FUNCTION;
            valid = true;
        } else if (type == "for") {
            s->exit_type = ExitStatement::EXIT_FOR;
            valid = true;
        } else if (type == "do") {
            s->exit_type = ExitStatement::EXIT_DO;
            valid = true;
        }
        
        if (valid) {
            advance();
            return s;
        } else {
            unregister_node(s); delete s;
            return nullptr;
        }
    }
    return nullptr; 
}

ConstStatement* VisualGasicParser::parse_const() {
    advance(); // Eat Const
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        UtilityFunctions::print("Parser Error: Expected constant name");
        return nullptr;
    }
    
    ConstStatement* s = static_cast<ConstStatement*>(register_node(new ConstStatement()));
    s->name = peek().value;
    advance();
    
    // Optional As Type (Ignore)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
        advance(); // Eat type name
    }
    
    // = Value
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
        advance();
        {
            ExpressionNode* _tmp = parse_expression();
            s->value = _tmp;
            unregister_node(_tmp);
        }
    } else {
        UtilityFunctions::print("Parser Error: Expected = in Const definition");
    }
    
    return s;
}

ReDimStatement* VisualGasicParser::parse_redim() {
    advance(); // Eat ReDim
    
    ReDimStatement* s = static_cast<ReDimStatement*>(register_node(new ReDimStatement()));
    
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("preserve") == 0) {
        s->preserve = true;
        advance();
    }
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        UtilityFunctions::print("Parser Error: Expected variable name after ReDim");
        unregister_node(s); delete s;
        return nullptr;
    }
    
    s->variable_name = peek().value;
    advance();
    
    // Must be array: (Size)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance();
        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
            while (true) {
                {
                    ExpressionNode* _tmp = parse_expression();
                    if (_tmp) { s->array_sizes.push_back(_tmp); unregister_node(_tmp); }
                }
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                } else {
                    break;
                }
            }
        }
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             UtilityFunctions::print("Parser Error: Expected ')' in ReDim");
        }
    } else {
         UtilityFunctions::print("Parser Error: ReDim expects array bounds like ReDim A(1)");
    }
    
    // Ignore optional 'As Type'
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) advance(); // Eat Type
    }
    
    return s;
}

TryStatement* VisualGasicParser::parse_try() {
    advance(); // Eat Try
    
    TryStatement* s = static_cast<TryStatement*>(register_node(new TryStatement()));
    
    // Parse Try Block
    while (!is_at_end()) {
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             String kwa = String(peek().value).to_lower();
             if (kwa == "catch" || kwa == "finally" || kwa == "end") {
                 if (kwa == "end") {
                     // Check End Try
                     if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD && String(peek(1).value).to_lower() == "try") {
                         break; 
                     }
                 } else {
                     break; // Catch or Finally
                 }
             }
        }
        
        Statement* stmt = parse_statement();
        if (stmt) { s->try_block.push_back(stmt); unregister_node(stmt); }
        else advance(); 
    }
    
    // Catch Block
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "catch") {
        advance(); // Eat Catch
        
        VisualGasicTokenizer::Token vars = peek();
        // Optional Variable? Catch ex As Exception?
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            // Store exception variable name
            s->catch_var_name = peek().value;
            advance(); // Eat ident
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
                 advance(); // Eat As
                 advance(); // Eat Type (Ignore type for now, treating as generic Exception/Variant)
            }
        }
        
        while (!is_at_end()) {
             if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                 String kwa = String(peek().value).to_lower();
                 if (kwa == "finally") {
                     break;
                 }
                 if (kwa == "end") {
                      if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD && String(peek(1).value).to_lower() == "try") {
                          break;
                      }
                 }
             }
             Statement* stmt = parse_statement();
             if (stmt) { s->catch_block.push_back(stmt); unregister_node(stmt); }
             else advance();
        }
    }

    // Finally Block
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "finally") {
        advance(); // Eat Finally
        
        while (!is_at_end()) {
             if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                 String kwa = String(peek().value).to_lower();
                 if (kwa == "end") {
                      if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD && String(peek(1).value).to_lower() == "try") {
                          break;
                      }
                 }
             }
             Statement* stmt = parse_statement();
             if (stmt) { s->finally_block.push_back(stmt); unregister_node(stmt); }
             else advance();
        }
    }

    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance(); // Eat End
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "try") {
            advance(); // Eat Try
        }
    }
    
    return s;
}

RaiseStatement* VisualGasicParser::parse_raise() {
    advance(); // Eat Raise
    RaiseStatement* s = static_cast<RaiseStatement*>(register_node(new RaiseStatement()));
    
    {
        ExpressionNode* _tmp = parse_expression();
        s->error_code = _tmp;
        unregister_node(_tmp);
    }
    if (!s->error_code) {
        error("Expected error code in Raise statement");
    }
    
    if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
        advance();
        {
            ExpressionNode* _tmp = parse_expression();
            s->message = _tmp;
            unregister_node(_tmp);
        }
    }
    
    return s;
}

WheneverSectionStatement* VisualGasicParser::parse_whenever() {
    advance(); // Eat "Whenever"
    
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) || String(peek().value).nocasecmp_to("section") != 0) {
        error("Expected 'Section' after 'Whenever'");
        return nullptr;
    }
    advance(); // Eat "Section"
    
    WheneverSectionStatement* stmt = static_cast<WheneverSectionStatement*>(register_node(new WheneverSectionStatement()));
    
    // Check for optional "Local" scope modifier
    bool is_local = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("local") == 0) {
        is_local = true;
        advance(); // consume "Local"
    }
    
    // Parse section name
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected section name after 'Whenever Section'");
        return nullptr;
    }
    stmt->section_name = peek().value;
    advance();
    
    // Check if this is a complex expression (starts with parentheses)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        // Complex condition expression: Whenever Section Name (expression) CallbackProc
        stmt->variable_name = ""; // No single variable for complex expressions
        
        ExpressionNode* _tmp = parse_expression(); // This will handle the entire parenthetical expression
        stmt->condition_expression = _tmp;
        unregister_node(_tmp);
        
        stmt->comparison_operator = "expression"; // Special marker for complex expressions
    } else {
        // Traditional simple variable monitoring
        // Parse variable name
        if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            error("Expected variable name in Whenever Section");
            return nullptr;
        }
        stmt->variable_name = peek().value;
        advance();
        
        // Parse comparison operator
        if (!check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            error("Expected comparison operator (Changes, Becomes, Exceeds) in Whenever Section");
            return nullptr;
        }
        String op = String(peek().value).to_lower();
        if (op != "changes" && op != "becomes" && op != "exceeds" && op != "below" && op != "between" && op != "contains") {
            error("Expected 'Changes', 'Becomes', 'Exceeds', 'Below', 'Between', or 'Contains' in Whenever Section");
            return nullptr;
        }
        stmt->comparison_operator = peek().value;
        advance();
        
        // Parse comparison value (optional for "Changes")
        if (op != "changes") {
            ExpressionNode* _tmp = parse_expression();
            stmt->comparison_value = _tmp;
            unregister_node(_tmp);
            
            // Handle "Between X And Y" syntax
            if (op == "between") {
                if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) || String(peek().value).nocasecmp_to("and") != 0) {
                    error("Expected 'And' after first value in 'Between' condition");
                    return nullptr;
                }
                advance(); // consume "And"
                
                ExpressionNode* _tmp2 = parse_expression();
                stmt->comparison_value2 = _tmp2;
                unregister_node(_tmp2);
            }
        }
    }
    
    // Parse callback procedure names (support comma-separated list)
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected procedure name in Whenever Section");
        return nullptr;
    }
    
    // Parse first procedure name
    stmt->callback_procedures.push_back(peek().value);
    advance();
    
    // Parse additional procedures if comma-separated
    while (check(VisualGasicTokenizer::TOKEN_COMMA)) {
        advance(); // consume comma
        if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            error("Expected procedure name after comma in Whenever Section");
            return nullptr;
        }
        stmt->callback_procedures.push_back(peek().value);
        advance();
    }
    
    // Set scope information
    stmt->is_local_scope = is_local;
    
    return stmt;
}

SuspendWheneverStatement* VisualGasicParser::parse_suspend_whenever() {
    SuspendWheneverStatement* stmt = static_cast<SuspendWheneverStatement*>(register_node(new SuspendWheneverStatement()));
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected section name after 'Suspend Whenever'");
        return nullptr;
    }
    stmt->section_name = peek().value;
    advance();
    
    return stmt;
}

ResumeWheneverStatement* VisualGasicParser::parse_resume_whenever() {
    ResumeWheneverStatement* stmt = static_cast<ResumeWheneverStatement*>(register_node(new ResumeWheneverStatement()));
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected section name after 'Resume Whenever'");
        return nullptr;
    }
    stmt->section_name = peek().value;
    advance();
    
    return stmt;
}

void VisualGasicParser::parse_enum() {
    // Enum Name
    // Member = Val
    // End Enum
    advance(); // Eat Enum
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
         error("Expected Enum Name");
         return;
    }
    String enum_name = peek().value;
    advance();
    
    EnumDefinition* def = static_cast<EnumDefinition*>(register_node(new EnumDefinition()));
    def->name = enum_name;
    
    int next_val = 0;
    
    while (!is_at_end()) {
         if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) { advance(); continue; }
         
         if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             String k = String(peek().value).to_lower();
             if (k == "end") {
                 advance();
                 if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "enum") {
                     advance();
                     break;
                 }
             }
         }
         
         if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
             String mem_name = peek().value;
             advance();
             
             int val = next_val;
             if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
                 advance();
                 // Expect integer literal or expression (constant)
                 // For now, strict literal/constant
                ExpressionNode* expr = parse_expression();
                if (expr && expr->type == ExpressionNode::LITERAL) {
                    val = (int)((LiteralNode*)expr)->value;
                }
                if (expr) { unregister_node(expr); delete expr; }
             }
             
             EnumValue ev;
             ev.name = mem_name;
             ev.value = val;
             def->values.push_back(ev);
             
             next_val = val + 1;
         } else {
             advance(); // Skip garbage?
         }
    }
    
    if (current_module) {
        current_module->enums.push_back(def);
    } else {
        delete def;
    }
}

// === MULTITASKING PARSING FUNCTIONS ===

AsyncFunctionStatement* VisualGasicParser::parse_async_function() {
    AsyncFunctionStatement* async_func = static_cast<AsyncFunctionStatement*>(register_node(new AsyncFunctionStatement()));
    
    // Should be "Sub" or "Function" 
    bool is_function = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        String kw = String(peek().value).to_lower();
        if (kw == "function") {
            is_function = true;
            advance();
        } else if (kw == "sub") {
            advance();
        } else {
            error("Expected 'Sub' or 'Function' in async declaration");
            return nullptr;
        }
    }
    
    // Function name
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected function name");
        return nullptr;
    }
    async_func->function_name = peek().value;
    advance();
    
    // Parameters
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // (
        while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
            Parameter* param = new Parameter();
            param->name = peek().value;
            advance();
            
            // Type annotation
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "as") {
                advance(); // as
                param->type_hint = peek().value;
                advance();
            }
            
            async_func->parameters.push_back(param);
            
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
            }
        }
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    
    // Return type for functions
    if (is_function && check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "as") {
        advance(); // as
        async_func->return_type = peek().value;
        advance();
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse body
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end")) {
        Statement* stmt = parse_statement();
        if (stmt) {
            async_func->body.push_back(stmt);
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    // End Sub/Function
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String end_kw = String(peek().value).to_lower();
            if ((is_function && end_kw == "function") || (!is_function && end_kw == "sub")) {
                advance();
            }
        }
    }
    
    return async_func;
}

Statement* VisualGasicParser::parse_await() {
    advance(); // consume "await"
    
    // For now, treat await as a special assignment/call
    // Await expression -> result
    ExpressionNode* expr = parse_expression();
    if (!expr) {
        error("Expected expression after 'Await'");
        return nullptr;
    }
    
    // Create await statement using assignment AST
    // Target is a VariableNode for __await_result__
    AssignmentStatement* await_stmt = static_cast<AssignmentStatement*>(register_node(new AssignmentStatement()));
    
    VariableNode* target = new VariableNode();
    target->name = "__await_result__";
    
    await_stmt->target = target;
    await_stmt->value = expr;
    
    return await_stmt;
}

TaskRunStatement* VisualGasicParser::parse_task_run() {
    TaskRunStatement* task = static_cast<TaskRunStatement*>(register_node(new TaskRunStatement()));
    
    // Optional task name
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        task->task_name = peek().value;
        advance();
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse task body until "End Task"
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end")) {
        Statement* stmt = parse_statement();
        if (stmt) {
            task->task_body.push_back(stmt);
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    // End Task
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "task") {
            advance();
        }
    }
    
    return task;
}

TaskWaitStatement* VisualGasicParser::parse_task_wait() {
    TaskWaitStatement* wait_stmt = static_cast<TaskWaitStatement*>(register_node(new TaskWaitStatement()));
    
    String wait_type = String(peek().value).to_lower();
    advance();
    
    if (wait_type == "waitall") {
        wait_stmt->wait_all = true;
    } else if (wait_type == "waitany") {
        wait_stmt->wait_all = false;
    } else {
        wait_stmt->wait_all = true; // default
    }
    
    // Parse task names
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // (
        while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                wait_stmt->task_names.push_back(peek().value);
                advance();
            }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
            }
        }
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    
    return wait_stmt;
}

ParallelForStatement* VisualGasicParser::parse_parallel_for() {
    ParallelForStatement* par_for = static_cast<ParallelForStatement*>(register_node(new ParallelForStatement()));
    
    // Variable name
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected loop variable name");
        return nullptr;
    }
    par_for->variable_name = peek().value;
    advance();
    
    // = (comes as TOKEN_OPERATOR)
    if (!match(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        error("Expected = in Parallel For");
    }
    
    // Start expression
    par_for->start_expr = parse_expression();
    
    // To
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "to") {
        advance();
        par_for->end_expr = parse_expression();
    }
    
    // Optional Step
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "step") {
        advance();
        par_for->step_expr = parse_expression();
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse body
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "next")) {
        Statement* stmt = parse_statement();
        if (stmt) {
            par_for->body.push_back(stmt);
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    // Next
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "next") {
        advance();
    }
    
    return par_for;
}

ParallelSectionStatement* VisualGasicParser::parse_parallel_section() {
    ParallelSectionStatement* par_section = static_cast<ParallelSectionStatement*>(register_node(new ParallelSectionStatement()));
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse section body until "End Section"
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end")) {
        Statement* stmt = parse_statement();
        if (stmt) {
            par_section->section_body.push_back(stmt);
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    // End Section
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "section") {
            advance();
        }
    }
    
    return par_section;
}

// === ADVANCED TYPE SYSTEM PARSING ===

PatternMatchStatement* VisualGasicParser::parse_pattern_match() {
    PatternMatchStatement* match_stmt = static_cast<PatternMatchStatement*>(register_node(new PatternMatchStatement()));
    
    // Parse the expression to match
    match_stmt->expression = parse_expression();
    if (!match_stmt->expression) {
        error("Expected expression in Select Match");
        return nullptr;
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse cases
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end")) {
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "case") {
            MatchCase* match_case = parse_match_case();
            if (match_case) {
                match_stmt->cases.push_back(match_case);
            }
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    // End Select
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "select") {
            advance();
        }
    }
    
    return match_stmt;
}

MatchCase* VisualGasicParser::parse_match_case() {
    MatchCase* match_case = new MatchCase();
    
    advance(); // consume "case"
    
    // Check for Case Else
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "else") {
        advance();
        Pattern* else_pattern = new Pattern();
        else_pattern->type = Pattern::VARIABLE_PATTERN;
        else_pattern->variable_name = "_"; // Wildcard
        match_case->pattern = else_pattern;
    } else {
        match_case->pattern = parse_pattern();
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Parse statements until next Case or End Select
    while (!is_at_end() && !(check(VisualGasicTokenizer::TOKEN_KEYWORD) && 
           (String(peek().value).to_lower() == "case" || String(peek().value).to_lower() == "end"))) {
        Statement* stmt = parse_statement();
        if (stmt) {
            match_case->statements.push_back(stmt);
        } else {
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            else advance();
        }
    }
    
    return match_case;
}

Pattern* VisualGasicParser::parse_pattern() {
    Pattern* pattern = new Pattern();
    
    // Type pattern: Success(value)
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        String type_name = peek().value;
        advance();
        
        if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
            // Type pattern with destructuring
            pattern->type = Pattern::TYPE_PATTERN;
            pattern->type_name = type_name;
            advance(); // (
            
            while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
                Pattern* sub_pattern = new Pattern();
                sub_pattern->type = Pattern::VARIABLE_PATTERN;
                sub_pattern->variable_name = peek().value;
                pattern->sub_patterns.push_back(sub_pattern);
                advance();
                
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                }
            }
            
            match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
        } else {
            // Simple type or variable pattern
            pattern->type = Pattern::VARIABLE_PATTERN;
            pattern->variable_name = type_name;
        }
    } else if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER) || 
               check(VisualGasicTokenizer::TOKEN_LITERAL_FLOAT) ||
               check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
        // Literal pattern - parse the literal directly
        pattern->type = Pattern::LITERAL_PATTERN;
        if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER)) {
            pattern->literal_value = String(peek().value).to_int();
        } else if (check(VisualGasicTokenizer::TOKEN_LITERAL_FLOAT)) {
            pattern->literal_value = String(peek().value).to_float();
        } else {
            pattern->literal_value = peek().value;
        }
        advance();
    } else {
        // Default to literal pattern with expression
        pattern->type = Pattern::LITERAL_PATTERN;
        ExpressionNode* expr = parse_expression();
        if (expr && expr->type == ExpressionNode::LITERAL) {
            LiteralNode* lit = static_cast<LiteralNode*>(expr);
            pattern->literal_value = lit->value;
        }
    }
    
    // Guard clause with When
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "when") {
        advance(); // consume "when"
        pattern->guard_expression = parse_expression();
    }
    
    return pattern;
}

AdvancedType* VisualGasicParser::parse_advanced_type() {
    AdvancedType* type = new AdvancedType();
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected type name");
        return nullptr;
    }
    
    type->base_type = peek().value;
    advance();
    
    // Generic type: List(Of T)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // (
        
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "of") {
            advance(); // of
            type->kind = AdvancedType::GENERIC;
            
            // Parse type parameters
            while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
                AdvancedType* param_type = parse_advanced_type();
                if (param_type) {
                    type->type_parameters.push_back(param_type);
                }
                
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                }
            }
        }
        
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    
    // Optional type: Player? - check for operator "?"
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && String(peek().value) == "?") {
        advance();
        type->is_optional = true;
        type->kind = AdvancedType::OPTIONAL;
    }
    
    return type;
}

SubDefinition* VisualGasicParser::parse_generic_function() {
    SubDefinition* sub = new SubDefinition();
    
    // Function name
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        sub->name = peek().value;
        advance();
    }
    
    // Generic parameters: Function Sort(Of T)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // (
        
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "of") {
            advance(); // of
            
            while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
                GenericTypeParameter* param = new GenericTypeParameter();
                param->name = peek().value;
                advance();
                
                // Type constraints: Where T : IComparable
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "where") {
                    advance(); // where
                    advance(); // T (skip for now)
                    if (check(VisualGasicTokenizer::TOKEN_COLON)) {
                        advance(); // :
                        while (!check(VisualGasicTokenizer::TOKEN_COMMA) && !check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                            param->constraints.push_back(peek().value);
                            advance();
                        }
                    }
                }
                
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                }
            }
        }
        
        match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE);
    }
    
    return sub;
}
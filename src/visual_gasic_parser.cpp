#include "visual_gasic_parser.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <stdio.h>

VisualGasicParser::VisualGasicParser() : current_pos(0), error_count(0) {
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
    error_count++;
    
    // Print the error for debugging
    UtilityFunctions::print("Parser Error: ", message);
    
    // If we've hit too many errors, the parser state is likely corrupted
    if (error_count >= MAX_ERRORS) {
        UtilityFunctions::printerr("Parser Error: Too many errors (", error_count, "), stopping parse to prevent crash");
    }
}

// Error recovery: skip tokens until we reach a statement boundary
// (newline, EOF, or a keyword that starts a new statement)
void VisualGasicParser::synchronize() {
    while (!is_at_end()) {
        // Stop at newline — next line is a new statement
        if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
            advance();
            return;
        }
        if (check(VisualGasicTokenizer::TOKEN_EOF)) return;
        
        // Stop at keywords that start statements
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String kw = String(peek().value).to_lower();
            if (kw == "sub" || kw == "function" || kw == "dim" || kw == "if" ||
                kw == "for" || kw == "do" || kw == "while" || kw == "select" ||
                kw == "end" || kw == "exit" || kw == "return" || kw == "print" ||
                kw == "set" || kw == "let" || kw == "call" || kw == "on" ||
                kw == "goto" || kw == "gosub" || kw == "redim" || kw == "erase" ||
                kw == "open" || kw == "close" || kw == "type" || kw == "enum" ||
                kw == "const" || kw == "public" || kw == "private" || kw == "static") {
                return;
            }
        }
        advance();
    }
}

// Reimplementing correct logic
ModuleNode* VisualGasicParser::parse(const Vector<VisualGasicTokenizer::Token>& p_tokens) {
    // Strip comment tokens so inline comments (e.g. "InitializePriorities ' setup")
    // don't confuse any parser path — comments are purely decorative.
    tokens.clear();
    for (int i = 0; i < p_tokens.size(); i++) {
        if (p_tokens[i].type != VisualGasicTokenizer::TOKEN_COMMENT) {
            tokens.push_back(p_tokens[i]);
        }
    }
    errors.clear();
    error_count = 0;
    current_pos = 0;
    
    ModuleNode* module = new ModuleNode();
    current_module = module;

        while (!is_at_end() && error_count < MAX_ERRORS) {
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

        // Whenever Section at module level - must be registered as global statement
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).to_lower() == "whenever") {
            WheneverSectionStatement* ws = parse_whenever();
            if (ws) {
                module->global_statements.push_back(ws);
                unregister_node(ws);
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

        // Class Definition
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).nocasecmp_to("class") == 0) {
            ClassDefinition* cls = parse_class();
            if (cls) {
                module->class_defs.push_back(cls);
                unregister_node(cls);
            }
            continue;
        }

        // <Flags> attribute for Enum (module-level)
        if (t.type == VisualGasicTokenizer::TOKEN_OPERATOR && String(t.value) == "<") {
            if (current_pos + 2 < (int)tokens.size() &&
                String(tokens[current_pos + 1].value).nocasecmp_to("Flags") == 0 &&
                String(tokens[current_pos + 2].value) == ">") {
                advance(); // <
                advance(); // Flags
                advance(); // >
                while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("enum") == 0) {
                    parse_enum(true);
                }
                continue;
            }
        }

        // Enum Definition (module-level)
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).nocasecmp_to("enum") == 0) {
            parse_enum();
            continue;
        }

        // Export prefix (v4.2.0) — Export Dim x As Integer / Export Public x As String
        String val = String(t.value).to_lower();
        bool pending_export = false;
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && val == "export") {
            pending_export = true;
            advance(); // Eat Export
            while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            t = peek(); // re-read for the Dim/Public/Private that follows
            val = String(t.value).to_lower();
        }

        // Variable Declaration (Dim, Public, Private)
        // But NOT if Public/Private is followed by Sub/Function — those are subs
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && (val == "public" || val == "private" || val == "dim")) {
            // Peek ahead: if Public/Private is followed by Sub/Function, treat as a sub definition
            if (val == "public" || val == "private") {
                VisualGasicTokenizer::Token next_t = peek(1);
                String next_val = String(next_t.value).to_lower();
                if (next_val == "sub" || next_val == "function") {
                    advance(); // Eat Public/Private
                    SubDefinition* sub = parse_sub();
                    if (sub) {
                        module->subs.push_back(sub);
                        unregister_node(sub);
                    }
                    continue;
                }
            }
            // Parse DimStatement logic but store as global VariableDefinition
             DimStatement* dim = parse_dim(); // Reuse parse_dim which handles Dim A As Integer
             if (dim) {
                 VariableDefinition* v = static_cast<VariableDefinition*>(register_node(new VariableDefinition()));
                 v->name = dim->variable_name;
                 v->type = dim->type_name; // can be empty
                 v->visibility = (val == "public") ? VIS_PUBLIC : (val == "private" ? VIS_PRIVATE : VIS_DIM);
                 v->is_with_events = dim->is_with_events; // Propagate WithEvents (v3.5.0)
                 v->is_export = pending_export;            // Export to Inspector (v4.2.0)
                 
                 for(int i=0; i<dim->array_sizes.size(); i++) {
                     ExpressionNode* expr = dim->array_sizes[i];
                     if (expr && expr->type == ExpressionNode::LITERAL) {
                         v->array_sizes.push_back((int)((LiteralNode*)expr)->value);
                     } else {
                         // Error: Constant expression required or null expression
                         v->array_sizes.push_back(0); 
                     }
                 }
                 
                 module->variables.push_back(v);
                 unregister_node(v);
                 
                 // If DimStatement has an initializer or array sizes, also add it to global_statements
                 // so the initialization expression gets executed at runtime
                 // (array sizes may reference constants like MAX_PARTICLES that need evaluation)
                 if (dim->initializer || dim->array_sizes.size() > 0) {
                     module->global_statements.push_back(dim);
                     unregister_node(dim);
                 } else {
                     unregister_node(dim);
                     delete dim; // Don't need the statement wrapper if no initializer
                 }
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

        // Implements at module level (v3.5.0) — store in implements_list
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).nocasecmp_to("implements") == 0) {
            advance(); // Eat Implements
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                module->implements_list.push_back(peek().value);
                advance();
            } else {
                error("Expected interface name after 'Implements'");
            }
            continue;
        }

        // Import at module level (v4.2.0) — Import "path/module.vg"
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).nocasecmp_to("import") == 0) {
            advance(); // Eat Import
            if (check(VisualGasicTokenizer::TOKEN_LITERAL_STRING)) {
                module->imports.push_back(peek().value);
                advance();
            } else if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                // Allow Import ModuleName (no quotes — resolved by convention as ModuleName.vg)
                module->imports.push_back(String(peek().value) + ".vg");
                advance();
            } else {
                error("Expected module path string or identifier after 'Import'");
            }
            continue;
        }

        // ClassName at module level (v4.2.0) — ClassName MyGlobalName
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && String(t.value).nocasecmp_to("classname") == 0) {
            advance(); // Eat ClassName
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                module->class_name_vg = peek().value;
                advance();
            } else {
                error("Expected name after 'ClassName'");
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
            if (s && s->type == STMT_DATA || (s && s->type == STMT_LABEL)) {
                module->global_statements.push_back(s);
            } else if (s) {
                unregister_node(s);
                delete s;
                error("Only Data and Labels are allowed at module level.");
            }
            continue;
        }

        // Skip unknown — use synchronize to find next valid statement boundary
        if (peek().type == VisualGasicTokenizer::TOKEN_ERROR) {
            error("Unexpected character at module level: " + String(peek().value));
            synchronize();
        } else {
            current_pos++;
        }
    }

    // If parsing recorded errors, we still return the module with the
    // successfully-parsed subs.  VB6-style: errors in one Sub should not
    // prevent the rest of the script from running.
    // Clear tracking lists to prevent double-free on parser destruction.
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

    // Accept both identifiers and keywords as procedure names — VB6 allows
    // keywords like "Reset", "Name", etc. as Sub/Function names inside classes.
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER) && !check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
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

                 if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                     param.name = peek().value;
                     advance();
                     
                     // Handle () after ParamArray parameter name (e.g., ParamArray items())
                     if (param.is_param_array && check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                         advance(); // Eat (
                         if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                             advance(); // Eat )
                         }
                     }
                     
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
                     // Skip to closing paren or newline to recover
                     while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_PAREN_CLOSE && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                         advance();
                     }
                     break;
                 }
                 
                 if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                 break;
             }
        }
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             UtilityFunctions::print("Parser Error: Expected ) after parameters");
             // Skip to newline to recover
             while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                 advance();
             }
        }
    }
    
    // Skip to newline — but warn when a Sub (not Function) declares a return type.
    // VB6 rule: only Function can have a return type after the parameter list.
    if (!is_function) {
        // Look for "As" keyword immediately after the closing paren — that means
        // the programmer wrote `Sub Foo() As Boolean` which is invalid VB6/VG.
        if (!is_at_end() && peek().type == VisualGasicTokenizer::TOKEN_KEYWORD
            && String(peek().value).nocasecmp_to("As") == 0) {
            UtilityFunctions::push_warning(
                "[VG] Warning: Sub '" + name + "' has a return type declaration — "
                "did you mean Function? Return type will be ignored.",
                __FUNCTION__, __FILE__, __LINE__);
        }
    }
    while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
          // Store return type if we want
          current_pos++;
    }

    SubDefinition* sub = static_cast<SubDefinition*>(register_node(new SubDefinition()));
    sub->name = name;
    sub->type = is_function ? SubDefinition::TYPE_FUNCTION : SubDefinition::TYPE_SUB;
    sub->parameters = parameters;

    // Body
    while (!is_at_end() && error_count < MAX_ERRORS) {
        VisualGasicTokenizer::Token t = peek();

        // Skip error tokens in Sub/Function body to prevent crashes
        if (t.type == VisualGasicTokenizer::TOKEN_ERROR) {
            error("Unexpected character in " + String(is_function ? "Function" : "Sub") + " " + name + ": " + String(t.value));
            synchronize();
            continue;
        }

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
            
            // Handle any pending statements from multi-declaration (Dim a, b, c As Integer)
            while (!pending_statements.is_empty()) {
                Statement* pending = pending_statements[0];
                pending_statements.remove_at(0);
                sub->statements.push_back(pending);
                // Note: already unregistered in parse_dim
            }
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
    // Bail early if too many errors — prevents cascade crashes
    if (error_count >= MAX_ERRORS) return nullptr;

    if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) {
        return nullptr;
    }

    // Skip TOKEN_ERROR tokens that slipped past _reload() — prevents segfault
    if (peek().type == VisualGasicTokenizer::TOKEN_ERROR) {
        error("Unexpected character: " + String(peek().value));
        synchronize();
        return nullptr;
    }
    
    VisualGasicTokenizer::Token t = peek();
    int statement_line = t.line; // Capture line number for debug support
    // UtilityFunctions::print("ParseStmt Token: ", t.value, " Type: ", t.type);

    if (t.type == VisualGasicTokenizer::TOKEN_COMMENT) {
        advance();
        return nullptr;
    }
    
    String val = t.value.operator String().to_lower();

    // Helper lambda to set line number on statement before returning
    auto set_line = [statement_line](Statement* s) -> Statement* {
        if (s) s->line = statement_line;
        return s;
    };

    // Only treat reserved words as statements when the tokenizer classified them as KEYWORD.
    // <Flags> attribute for Enum (statement-level)
    if (t.type == VisualGasicTokenizer::TOKEN_OPERATOR && String(t.value) == "<") {
        if (current_pos + 2 < (int)tokens.size() &&
            String(tokens[current_pos + 1].value).nocasecmp_to("Flags") == 0 &&
            String(tokens[current_pos + 2].value) == ">") {
            advance(); // <
            advance(); // Flags
            advance(); // >
            while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("enum") == 0) {
                parse_enum(true);
            }
            return nullptr;
        }
    }

    if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD) {
        if (val == "enum") {
            parse_enum();
            return nullptr; // Enum is a definition, not a statement
        }
        if (val == "print") {
            return set_line(parse_print());
        }
        if (val == "open") return set_line(parse_open());
        if (val == "close") return set_line(parse_close());
        if (val == "seek") return set_line(parse_seek());
        if (val == "kill") return set_line(parse_kill());
        if (val == "name") return set_line(parse_name());
        if (val == "try") return set_line(parse_try());
        if (val == "write") return set_line(parse_write());
        // ── v3.3.0: Swap, Get#, Put#, Module, Assert ──
        if (val == "assert") {
            advance(); // Eat Assert
            CallStatement* cs = static_cast<CallStatement*>(register_node(new CallStatement()));
            cs->method_name = "Assert";
            { ExpressionNode* _t = parse_expression(); cs->arguments.push_back(_t); unregister_node(_t); }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
                ExpressionNode* _t = parse_expression();
                cs->arguments.push_back(_t); unregister_node(_t);
            }
            return set_line(cs);
        }
        if (val == "swap") {
            advance(); // Eat Swap
            SwapStatement* swp = static_cast<SwapStatement*>(register_node(new SwapStatement()));
            { ExpressionNode* _t = parse_expression(); swp->left = _t; unregister_node(_t); }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
            { ExpressionNode* _t = parse_expression(); swp->right = _t; unregister_node(_t); }
            return set_line(swp);
        }
        if (val == "get") {
            // Get #filenum, [recno], var
            if (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR && String(tokens[current_pos + 1].value) == "#") {
                advance(); // Eat Get
                advance(); // Eat #
                GetFileStatement* gfs = static_cast<GetFileStatement*>(register_node(new GetFileStatement()));
                { ExpressionNode* _t = parse_expression(); gfs->file_number = _t; unregister_node(_t); }
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                    // Optional record number (can be empty: Get #1, , x)
                    if (!check(VisualGasicTokenizer::TOKEN_COMMA)) {
                        ExpressionNode* _t = parse_expression(); gfs->record_number = _t; unregister_node(_t);
                    }
                }
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
                { ExpressionNode* _t = parse_expression(); gfs->variable = _t; unregister_node(_t); }
                return set_line(gfs);
            }
            // Otherwise fall through to property Get in class context
        }
        if (val == "put") {
            // Put #filenum, [recno], expr
            if (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR && String(tokens[current_pos + 1].value) == "#") {
                advance(); // Eat Put
                advance(); // Eat #
                PutFileStatement* pfs = static_cast<PutFileStatement*>(register_node(new PutFileStatement()));
                { ExpressionNode* _t = parse_expression(); pfs->file_number = _t; unregister_node(_t); }
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance();
                    if (!check(VisualGasicTokenizer::TOKEN_COMMA)) {
                        ExpressionNode* _t = parse_expression(); pfs->record_number = _t; unregister_node(_t);
                    }
                }
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
                { ExpressionNode* _t = parse_expression(); pfs->expression = _t; unregister_node(_t); }
                return set_line(pfs);
            }
        }
        if (val == "module") {
            advance(); // Eat Module
            ModuleStatement* mod = static_cast<ModuleStatement*>(register_node(new ModuleStatement()));
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                mod->module_name = peek().value;
                advance();
            }
            // Parse module body until End Module
            while (!is_at_end()) {
                while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("End") == 0) {
                    if (current_pos + 1 < tokens.size() && String(tokens[current_pos + 1].value).nocasecmp_to("Module") == 0) {
                        advance(); advance(); // Eat End Module
                        break;
                    }
                }
                Statement* s = parse_statement();
                if (s) { unregister_node(s); }
            }
            return set_line(mod);
        }
        if (val == "input") {
            // Check if this is Godot's Input singleton (Input.xxx) rather than VB Input statement
            if (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR && tokens[current_pos + 1].value == ".") {
                // Input.property or Input.method() — treat as identifier, fall through to assignment/call
                return set_line(parse_assignment_or_call());
            }
            return set_line(parse_input(false));
        }
        if (val == "line") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("input") == 0) {
                 return set_line(parse_input(true));
            }
            // Not "Line Input" — treat as VB6-style Line drawing command.
            // Back up so parse_assignment_or_call sees "Line" as the method name.
            current_pos--;
            return set_line(parse_assignment_or_call());
        }
        // VB6-style Circle and Point commands — treat as function calls
        if (val == "circle" || val == "point" || val == "savepicture") {
            current_pos--;
            return set_line(parse_assignment_or_call());
        }
        // VB6 "Error n" statement — raises runtime error with the given number
        if (val == "error") {
            advance();
            // Check if this is the standalone "Error <expr>" statement (not part of "On Error")
            if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
                // Parse the error number expression
                ExpressionNode* err_expr = parse_expression();
                CallStatement* cs = static_cast<CallStatement*>(register_node(new CallStatement()));
                cs->method_name = "Error";
                cs->arguments.push_back(err_expr);
                if (err_expr) unregister_node(err_expr);
                return set_line(cs);
            }
            // "Error" on its own — treat as call with no args
            CallStatement* cs = static_cast<CallStatement*>(register_node(new CallStatement()));
            cs->method_name = "Error";
            return set_line(cs);
        }
        // VB6 "Reset" statement — close all open files
        if (val == "reset") {
            advance();
            CallStatement* cs = static_cast<CallStatement*>(register_node(new CallStatement()));
            cs->method_name = "Reset";
            return set_line(cs);
        }

        if (val == "var") {
             return set_line(parse_dim()); // Helper alias for Var -> Dim
        }

        // Handle Dim with possible comma-separated declarations
        // Dim a, b, c As Integer - VB6 style: only c is Integer, a and b are Variant
        // Dim x As Integer, y As String - each has its own type
        if (val == "dim") {
            // We need to handle this specially to return all the DimStatements
            // Use the pending_dim_statements vector to store extras
            return set_line(parse_dim());
        }
        if (val == "static") {
            DimStatement* ds = parse_dim();
            if (ds) ds->is_static = true;
            return set_line(ds);
        }
        if (val == "const") return set_line(parse_const());
        if (val == "pass") {
            advance();
            return set_line(static_cast<PassStatement*>(register_node(new PassStatement())));
        }
        if (val == "doevents") {
            advance();
            return set_line(static_cast<DoEventsStatement*>(register_node(new DoEventsStatement())));
        }
        if (val == "stop") {
            advance();
            return set_line(static_cast<StopStatement*>(register_node(new StopStatement())));
        }
        if (val == "data") return set_line(parse_data());
        if (val == "datafile") return set_line(parse_data_file());
        if (val == "loaddata") return set_line(parse_load_data());
        if (val == "read") return set_line(parse_read());
        if (val == "restore") return set_line(parse_restore());
        if (val == "cleardata") return set_line(parse_clear_data());
        if (val == "datafromstring") return set_line(parse_data_from_string());
        if (val == "if") return set_line(parse_if());
        if (val == "for") return set_line(parse_for());
        if (val == "while") return set_line(parse_while());
        if (val == "do") return set_line(parse_do());
        if (val == "oscillate") return set_line(parse_oscillate());
        if (val == "repeat") return set_line(parse_repeat());
        if (val == "cycle") return set_line(parse_cycle());
        if (val == "every") return set_line(parse_every());
        if (val == "tween") return set_line(parse_tween());
        if (val == "select") {
            // Peek ahead: "Select Match" → pattern matching, "Select Case" → normal select
            if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD || peek(1).type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
                String next_kw = String(peek(1).value).to_lower();
                if (next_kw == "match") {
                    advance(); // consume "select"
                    advance(); // consume "match"
                    return set_line(parse_pattern_match());
                }
            }
            return set_line(parse_select());
        }
        if (val == "exit") return set_line(parse_exit());
        if (val == "redim") return set_line(parse_redim());
        if (val == "erase") return set_line(parse_erase());
        if (val == "with") return set_line(parse_with());
        if (val == "return") return set_line(parse_return());
        if (val == "continue") return set_line(parse_continue());
        if (val == "raise") {
            return set_line(parse_raise());
        }
        if (val == "whenever") {
            return set_line(parse_whenever());
        }
        
        // Multitasking keywords - async/await/task/parallel
        if (val == "async") {
            advance(); // consume "async"
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && (String(peek().value).nocasecmp_to("sub") == 0 || String(peek().value).nocasecmp_to("function") == 0)) {
                return set_line(parse_async_function());
            }
            error("Expected 'Sub' or 'Function' after 'Async'");
            return nullptr;
        }
        if (val == "await") {
            return set_line(parse_await());
        }
        if (val == "task" || val == "thread") {
            advance(); // consume "task" or "thread" (Thread is an alias for Task)
            // Handle both "Task Run" and "Task.Run" syntax
            if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && String(peek().value) == ".") {
                advance(); // consume "."
            }
            String next_val = String(peek().value).to_lower();
            if (next_val == "run") {
                advance(); // consume "run"
                return set_line(parse_task_run());
            } else if (next_val == "wait" || next_val == "waitall" || next_val == "waitany") {
                return set_line(parse_task_wait());
            }
            error("Expected 'Run', 'Wait', 'WaitAll', or 'WaitAny' after 'Task'/'Thread'");
            return nullptr;
        }
        if (val == "lock") {
            advance(); // consume "lock"
            return set_line(static_cast<Statement*>(register_node(new LockStatement())));
        }
        if (val == "unlock") {
            advance(); // consume "unlock"
            return set_line(static_cast<Statement*>(register_node(new UnlockStatement())));
        }
        if (val == "parallel") {
            advance(); // consume "parallel" 
            String next_val = String(peek().value).to_lower();
            if (next_val == "for") {
                advance(); // consume "for"
                return set_line(parse_parallel_for());
            } else if (next_val == "section") {
                advance(); // consume "section"
                return set_line(parse_parallel_section());
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
                return set_line(parse_pattern_match());
            } else {
                // Regular select case - put token back
                current_pos--;
                return set_line(parse_select());
            }
        }
        
        if (val == "suspend") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("whenever") == 0) {
                advance(); // consume "whenever"
                return set_line(parse_suspend_whenever());
            }
            error("Expected 'Whenever' after 'Suspend'");
            return nullptr;
        }
        if (val == "resume") {
            advance();
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("whenever") == 0) {
                advance(); // consume "whenever"
                return set_line(parse_resume_whenever());
            }
            // Resume Next
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Next") == 0) {
                advance();
                ResumeStatement* s = static_cast<ResumeStatement*>(register_node(new ResumeStatement()));
                s->resume_type = ResumeStatement::RESUME_NEXT;
                return set_line(s);
            }
            // Resume <label>
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                ResumeStatement* s = static_cast<ResumeStatement*>(register_node(new ResumeStatement()));
                s->resume_type = ResumeStatement::RESUME_LABEL;
                s->label_name = peek().value;
                advance();
                return set_line(s);
            }
            // Plain Resume
            {
                ResumeStatement* s = static_cast<ResumeStatement*>(register_node(new ResumeStatement()));
                s->resume_type = ResumeStatement::RESUME_PLAIN;
                return set_line(s);
            }
        }
        if (val == "raiseevent") {
            advance();
            return set_line(parse_raise_event());
        }
        
        if (val == "set") {
            advance(); // Eat Set
            // Parse assignment: Target = Value
            return set_line(parse_assignment_or_call());
        }
    }
    if (val == "goto") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String label = peek().value;
            advance();
            GotoStatement* g = static_cast<GotoStatement*>(register_node(new GotoStatement()));
            g->label_name = label;
            return set_line(g);
        } else {
            error("Expected label name after GoTo");
            synchronize();
            return nullptr;
        }
    }

    if (val == "gosub") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String label = peek().value;
            advance();
            GoSubStatement* gs = static_cast<GoSubStatement*>(register_node(new GoSubStatement()));
            gs->label_name = label;
            return set_line(gs);
        }
    }

    if (val == "implements") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String iface = peek().value;
            advance();
            ImplementsStatement* impl = static_cast<ImplementsStatement*>(register_node(new ImplementsStatement()));
            impl->interface_name = iface;
            return set_line(impl);
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
                     return set_line(s);
                 }
             } else if (String(peek().value).nocasecmp_to("Goto") == 0) {
                 advance();
                 if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                     String label = peek().value;
                     advance();
                     OnErrorStatement* s = static_cast<OnErrorStatement*>(register_node(new OnErrorStatement()));
                     s->mode = OnErrorStatement::GOTO_LABEL;
                     s->label_name = label;
                     return set_line(s);
                 }
                 if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER)) {
                      if ((int)peek().value == 0) {
                           advance();
                           OnErrorStatement* s = static_cast<OnErrorStatement*>(register_node(new OnErrorStatement()));
                           s->mode = OnErrorStatement::GOTO_LABEL;
                           s->label_name = "";
                           return set_line(s);
                      }
                 }
             }
        } else {
            // On expr GoTo label1, label2, ... OR On expr GoSub label1, label2, ...
            // We already consumed "On" and the next token is NOT "Error"
            // Back up: we need the expression. Current token is the first token of the expression.
            ExpressionNode* idx_expr = parse_expression();
            if (idx_expr) {
                String next_kw = String(peek().value);
                if (next_kw.nocasecmp_to("GoTo") == 0 || next_kw.nocasecmp_to("Goto") == 0) {
                    advance(); // Eat GoTo
                    OnGotoStatement* ogs = static_cast<OnGotoStatement*>(register_node(new OnGotoStatement()));
                    ogs->index_expression = idx_expr;
                    unregister_node(idx_expr);
                    // Parse comma-separated labels
                    while (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
                        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                            ogs->labels.push_back(peek().value);
                            advance();
                        }
                        if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
                        else break;
                    }
                    return set_line(ogs);
                } else if (next_kw.nocasecmp_to("GoSub") == 0 || next_kw.nocasecmp_to("Gosub") == 0) {
                    advance(); // Eat GoSub
                    OnGosubStatement* oss = static_cast<OnGosubStatement*>(register_node(new OnGosubStatement()));
                    oss->index_expression = idx_expr;
                    unregister_node(idx_expr);
                    while (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF)) {
                        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                            oss->labels.push_back(peek().value);
                            advance();
                        }
                        if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
                        else break;
                    }
                    return set_line(oss);
                } else {
                    delete idx_expr;
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
                     error("Expected )");
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
        return set_line(call_stmt);
    }
    
    if (t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
        // Handle Debug.Print → routes output to Immediate Window
        if (t.value.operator String().nocasecmp_to("Debug") == 0 
            && current_pos + 2 < tokens.size()
            && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR
            && tokens[current_pos + 1].value == "."
            && tokens[current_pos + 2].value.operator String().nocasecmp_to("Print") == 0) {
            advance(); // consume "Debug"
            advance(); // consume "."
            advance(); // consume "Print"
            PrintStatement* ps = parse_print();
            if (ps) {
                ps->is_debug = true;
                ps->line = statement_line;
            }
            return ps;
        }
        
        // ── Err.Raise → STMT_RAISE (VB6 Err.Raise Number, Source, Description) ──
        if (String(t.value).nocasecmp_to("err") == 0
            && current_pos + 2 < (int)tokens.size()
            && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR
            && tokens[current_pos + 1].value == "."
            && String(tokens[current_pos + 2].value).nocasecmp_to("raise") == 0) {
            advance(); // Eat "Err"
            advance(); // Eat "."
            advance(); // Eat "Raise"
            RaiseStatement* s = static_cast<RaiseStatement*>(register_node(new RaiseStatement()));
            // Parse error code (first argument)
            {
                ExpressionNode* _tmp = parse_expression();
                s->error_code = _tmp;
                unregister_node(_tmp);
            }
            // VB6 Err.Raise signature: Number, [Source], [Description]
            // Skip optional Source parameter (second arg)
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance(); // Eat comma
                // Check for empty source (double comma: Err.Raise 5, , "msg")
                if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                    advance(); // Skip second comma → Description
                    ExpressionNode* _tmp = parse_expression();
                    s->message = _tmp;
                    unregister_node(_tmp);
                } else if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF) && !check(VisualGasicTokenizer::TOKEN_COLON)) {
                    // Source argument present — skip it, look for Description
                    ExpressionNode* _source = parse_expression();
                    if (_source) { delete _source; }
                    if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                        advance(); // Skip comma → Description
                        ExpressionNode* _tmp = parse_expression();
                        s->message = _tmp;
                        unregister_node(_tmp);
                    }
                }
            }
            return set_line(s);
        }

        // Check for Label: Identifier followed by Colon
        if (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_COLON) {
            String label_name = t.value;
            advance(); // Identifier
            advance(); // Colon
            LabelStatement* l = static_cast<LabelStatement*>(register_node(new LabelStatement()));
            l->name = label_name;
            return set_line(l);
        }

        return set_line(parse_assignment_or_call());
    }

    if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && t.value.operator String().nocasecmp_to("me") == 0) {
        return set_line(parse_assignment_or_call());
    }
    
    // Check for Leading Dot (Implicit With member access)
    if (t.type == VisualGasicTokenizer::TOKEN_OPERATOR && t.value == ".") {
        return set_line(parse_assignment_or_call());
    }
    
    // Unrecognized keyword used as a variable name (e.g., Seconds, Frames, Over, etc.)
    // Route to assignment/call handler so keywords can be used as identifiers.
    // BUT: boolean operator keywords (Or, And, Xor, Not) must NOT be treated as
    // identifiers — they indicate a condition continuation from the previous line
    // that the parser failed to consume. Emit a clear error instead of creating
    // a bogus CallStatement that causes Err 35 at runtime.
    if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD) {
        String kw_val = String(t.value);
        if (kw_val.nocasecmp_to("Or") == 0 || kw_val.nocasecmp_to("And") == 0 ||
            kw_val.nocasecmp_to("Xor") == 0 || kw_val.nocasecmp_to("Not") == 0 ||
            kw_val.nocasecmp_to("Eqv") == 0 || kw_val.nocasecmp_to("Imp") == 0) {
            error("Boolean operator '" + kw_val + "' at start of statement is invalid. "
                  "If this was meant to continue a condition, place it on the same line.");
            advance(); // skip the operator keyword to recover
            return nullptr;
        }
        return set_line(parse_assignment_or_call());
    }
    
    current_pos++; // Skip unknown
    return nullptr;
}

// --- Expression Parsing ---

ExpressionNode* VisualGasicParser::parse_expression() {
    ExpressionNode* expr = parse_null_coalesce();
    
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

ExpressionNode* VisualGasicParser::parse_null_coalesce() {
    ExpressionNode* expr = parse_logical_or();
    
    // Check for ?? operator (null coalescing)
    while (check(VisualGasicTokenizer::TOKEN_OPERATOR) && String(peek().value) == "??") {
        advance(); // Eat ??
        ExpressionNode* right = parse_logical_or();
        BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
        if (expr) {
            ExpressionNode* ldup = expr->duplicate();
            if (ldup) bin->left = register_node(ldup); else bin->left = expr;
        } else bin->left = nullptr;
        if (right) {
            ExpressionNode* rdup = right->duplicate();
            if (rdup) bin->right = register_node(rdup); else bin->right = right;
        } else bin->right = nullptr;
        bin->op = "??";
        expr = bin;
    }
    
    return expr;
}

ExpressionNode* VisualGasicParser::parse_logical_or() {
    ExpressionNode* expr = parse_and();
    while (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = String(peek().value);
        if (op.nocasecmp_to("Or") == 0 || op.nocasecmp_to("Xor") == 0 || op.nocasecmp_to("OrElse") == 0 ||
            op.nocasecmp_to("Eqv") == 0 || op.nocasecmp_to("Imp") == 0) {
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
    ExpressionNode* expr = parse_shift();
    
    // Check for Operators and special Keyword 'Is'
    while (true) {
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
            String op = peek().value;
            if (op == "=" || op == "<" || op == ">" || op == "<=" || op == ">=" || op == "<>" || op == "!=") {
                advance();
                ExpressionNode* right = parse_shift();
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
            ExpressionNode* right = parse_shift();
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
        
        // Like operator for pattern matching
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Like") == 0) {
            advance();
            ExpressionNode* right = parse_shift();
            BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
            if (expr) {
                ExpressionNode* ldup = expr->duplicate();
                if (ldup) bin->left = register_node(ldup); else bin->left = expr;
            } else bin->left = nullptr;
            if (right) {
                ExpressionNode* rdup = right->duplicate();
                if (rdup) bin->right = register_node(rdup); else bin->right = right;
            } else bin->right = nullptr;
            bin->op = "Like";
            expr = bin;
            continue;
        }
        
        break;
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_shift() {
    ExpressionNode* expr = parse_addition();
    
    while (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        String op = peek().value;
        if (op == "<<" || op == ">>") {
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
        } else {
            break;
        }
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
    
    while (true) {
        String op;
        bool is_operator = false;
        
        // Check for operator tokens: *, /, //, \, %, or Mod keyword
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR)) {
            String peek_val = peek().value;
            if (peek_val == "*" || peek_val == "/" || peek_val == "//" || peek_val == "\\" || peek_val == "%") {
                op = peek_val;
                is_operator = true;
            }
        } else if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && 
                   String(peek().value).nocasecmp_to("Mod") == 0) {
            // Check for Mod keyword (case insensitive)
            op = "Mod";
            is_operator = true;
        }
        
        if (!is_operator) break;
        
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
    }
    return expr;
}

ExpressionNode* VisualGasicParser::parse_exponentiation() {
    ExpressionNode* expr = parse_factor();
    
    // Handle both ** (Python style) and ^ (VB style) exponentiation
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && (peek().value == "**" || peek().value == "^")) {
        String op = peek().value;
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
        bin->op = op;
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
             
             ExpressionNode* sub_expr = sub_parser.parse_expression();
             if (sub_expr) {
                  // Transfer all expression nodes from sub_parser to this parser
                  // to prevent use-after-free when sub_parser destructor runs
                  for (int si = 0; si < sub_parser.allocated_expr_nodes.size(); si++) {
                      register_node(sub_parser.allocated_expr_nodes[si]);
                  }
                  sub_parser.allocated_expr_nodes.clear();
                  for (int si = 0; si < sub_parser.allocated_nodes.size(); si++) {
                      register_node(sub_parser.allocated_nodes[si]);
                  }
                  sub_parser.allocated_nodes.clear();
                  
                  if (!root) root = sub_expr;
                  else {
                      BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                      bin->left = root; bin->right = sub_expr; bin->op = "&";
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

    // $NodeName / $%UniqueNode shorthand (v4.2.0) — desugar to GetNode("name") call
    if (check(VisualGasicTokenizer::TOKEN_NODE_PATH)) {
        String node_name = peek().value;
        advance();
        
        // Build CallExpression: GetNode("node_name")
        CallExpression* call = static_cast<CallExpression*>(register_node(new CallExpression()));
        call->method_name = "GetNode";
        LiteralNode* arg = static_cast<LiteralNode*>(register_node(new LiteralNode()));
        arg->value = node_name;
        call->arguments.push_back(arg);
        unregister_node(arg);
        return call;
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
            ExpressionNode* left = static_cast<MeNode*>(register_node(new MeNode()));
            
            // Handle member access chain after Me (Me.name, Me.prop, etc.)
            while (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") {
                advance(); // Eat .
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                    MemberAccessNode* member = static_cast<MemberAccessNode*>(register_node(new MemberAccessNode()));
                    member->base_object = left;
                    member->member_name = peek().value;
                    advance();
                    left = member;
                    
                    // Check for method call syntax Me.Method(Args)
                    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                        advance(); // Eat (
                        CallExpression* call = static_cast<CallExpression*>(register_node(new CallExpression()));
                        call->base_object = member->base_object;
                        call->method_name = member->member_name;
                        member->base_object = nullptr; unregister_node(member); delete member;
                        
                        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                            while (true) {
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
                    break;
                }
            }
            return left;
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

    // Check for Lambda expression: Lambda/Fn/Function/Sub(params) [=>] expr
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        String kv = peek().value;
        if (kv.nocasecmp_to("Lambda") == 0 || kv.nocasecmp_to("Fn") == 0 ||
            kv.nocasecmp_to("Function") == 0 || kv.nocasecmp_to("Sub") == 0) {
            // For Function/Sub as lambda, verify '(' follows to distinguish from declarations
            bool needs_paren_check = (kv.nocasecmp_to("Function") == 0 || kv.nocasecmp_to("Sub") == 0);
            if (!needs_paren_check || (current_pos + 1 < tokens.size() && tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                ExpressionNode* lam = parse_lambda();
                if (lam) return lam;
            }
        }
    }

    // Check for New
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("New") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
             NewNode* n = static_cast<NewNode*>(register_node(new NewNode()));
             n->class_name = peek().value;
             advance();

             // Handle arguments for parameterized constructors: New Class(args)
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
             error("Expected class name after New");
             return nullptr; 
        }
    }
    
    // Check for AddressOf <SubName> (VB6 callable reference syntax)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("AddressOf") == 0) {
        advance(); // Eat AddressOf
        if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER) && !check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            error("Expected method name after 'AddressOf'");
            return nullptr;
        }
        String method_name = peek().value;
        advance();
        // Create a UnaryOpNode with op="AddressOf", operand = variable holding method name
        VariableNode* name_node = static_cast<VariableNode*>(register_node(new VariableNode()));
        name_node->name = method_name;
        UnaryOpNode* addr = static_cast<UnaryOpNode*>(register_node(new UnaryOpNode()));
        addr->op = "AddressOf";
        addr->operand = name_node;
        unregister_node(name_node);
        return addr;
    }

    // Check for TypeOf ... Is ... (VB6 type checking syntax)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("TypeOf") == 0) {
        advance(); // Eat TypeOf
        
        // Parse just the variable name, not full expression (to avoid recursion issues)
        if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            error("Expected variable name after 'TypeOf'");
            return nullptr;
        }
        String var_name = peek().value;
        advance();
        
        VariableNode* target = static_cast<VariableNode*>(register_node(new VariableNode()));
        target->name = var_name;
        
        // Expect "Is"
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Is") == 0) {
            advance(); // Eat Is
            
            // Expect type name
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                String type_name = peek().value;
                advance();
                
                // Create a binary operation node for "TypeOf x Is Type"
                BinaryOpNode* typecheck = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                typecheck->op = "Is"; // Use "Is" as the operator
                typecheck->left = target;
                unregister_node(target);
                
                // Create a type node for the right side
                VariableNode* type_node = static_cast<VariableNode*>(register_node(new VariableNode()));
                type_node->name = type_name;
                typecheck->right = type_node;
                unregister_node(type_node);
                
                return typecheck;
            } else {
                error("Expected type name after 'TypeOf ... Is'");
                unregister_node(target);
                delete target;
                return nullptr;
            }
        } else {
            error("Expected 'Is' after 'TypeOf variable'");
            unregister_node(target);
            delete target;
            return nullptr;
        }
    }
    
    bool is_ident = check(VisualGasicTokenizer::TOKEN_IDENTIFIER);
    bool is_special_base = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
         // Treat any unrecognized keyword as an identifier (variable name).
         // Keywords like True, False, Me, Nothing, New, IIf, TypeOf, Lambda
         // are already handled above; operator keywords (Mod, And, Or, Not, Xor)
         // are consumed by higher-precedence parsers.  If they somehow reach here
         // it means the expression structure is wrong — do NOT treat them as
         // variable/function names (that causes Err 35 at runtime).
         String kf = String(peek().value);
         if (kf.nocasecmp_to("Or") == 0 || kf.nocasecmp_to("And") == 0 ||
             kf.nocasecmp_to("Xor") == 0 || kf.nocasecmp_to("Not") == 0 ||
             kf.nocasecmp_to("Eqv") == 0 || kf.nocasecmp_to("Imp") == 0) {
             // Do NOT consume — return nullptr so higher-level parser can handle it
             return nullptr;
         }
         is_special_base = true;
    }

    if (is_ident || is_special_base) {
        String name = peek().value;
        advance();
        
        ExpressionNode* left = nullptr;

        // Check if this is "Me" keyword - should create ME type node
        if (name.nocasecmp_to("Me") == 0) {
            left = static_cast<ExpressionNode*>(register_node(new ExpressionNode()));
            left->type = ExpressionNode::ME;
        }
        // Function Call? "Func(x)"
        else if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
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

        // Check for member access .Field and optional chaining ?.Field
        while ((check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ".") ||
               (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "?.")) {
            bool is_optional = (peek().value == "?.");
            advance(); // Eat . or ?.
            
            // Allow Identifier OR Keyword (e.g. Input, New)
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                if (is_optional) {
                    // Create OptionalAccessExpression for ?. chains
                    OptionalAccessExpression* opt = static_cast<OptionalAccessExpression*>(register_node(new OptionalAccessExpression()));
                    opt->object_expression = left;
                    opt->member_name = peek().value;
                    advance();
                    left = opt;
                } else {
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
                }
            } else {
                error(is_optional ? "Expected member name after ?." : "Expected member name after .");
            }
        }

        return left;
    }
    
    if (match(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        ExpressionNode* expr = parse_expression();
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
             error("Expected )");
        }
        return expr;
    }
    
    // ── Array literal: [expr, expr, ...] ──
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "[") {
        advance(); // Eat [
        ArrayLiteralNode* arr = static_cast<ArrayLiteralNode*>(register_node(new ArrayLiteralNode()));
        while (!check(VisualGasicTokenizer::TOKEN_EOF)) {
            if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "]") {
                advance(); break;
            }
            ExpressionNode* elem = parse_expression();
            if (elem) { arr->elements.push_back(elem); unregister_node(elem); }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
            else if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "]") { advance(); break; }
            else break;
        }
        return arr;
    }
    
    // ── Dictionary literal: {key: val, key: val, ...} ──
    if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "{") {
        advance(); // Eat {
        DictLiteralNode* dict = static_cast<DictLiteralNode*>(register_node(new DictLiteralNode()));
        while (!check(VisualGasicTokenizer::TOKEN_EOF)) {
            if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "}") {
                advance(); break;
            }
            ExpressionNode* key = parse_expression();
            if (check(VisualGasicTokenizer::TOKEN_COLON)) advance(); // Eat :
            else if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == ":") advance();
            ExpressionNode* val = parse_expression();
            if (key && val) {
                dict->keys.push_back(key); unregister_node(key);
                dict->values.push_back(val); unregister_node(val);
            }
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
            else if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "}") { advance(); break; }
            else break;
        }
        return dict;
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
    
    // Check for WithEvents modifier: Dim WithEvents obj As ClassName
    bool with_events = false;
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("WithEvents") == 0) {
        with_events = true;
        advance(); // Eat WithEvents
    }
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER) && !check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        UtilityFunctions::print("Parser Error: Expected variable name after Dim");
        // Skip to end of line to recover
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
            advance();
        }
        return nullptr;
    }
    
    // Helper to parse a single variable declaration (name, optional array bounds, optional type, optional initializer)
    // Returns nullptr on error
    auto parse_single_var = [this]() -> DimStatement* {
        if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER) && !check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            return nullptr;
        }
        
        DimStatement* stmt = static_cast<DimStatement*>(register_node(new DimStatement()));
        stmt->variable_name = peek().value;
        advance();
        
        // Check for Array declaration: A(10), A(5, 5), or A() for dynamic arrays
        if (match(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
            if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                stmt->is_dynamic_array = true;
                advance();
            } else {
                do {
                    ExpressionNode* _tmp = parse_expression();
                    if (_tmp) { stmt->array_sizes.push_back(_tmp); unregister_node(_tmp); }
                    else break;
                    if (check(VisualGasicTokenizer::TOKEN_COMMA)) advance();
                    else break;
                } while (!is_at_end() && !check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE));
                if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                    UtilityFunctions::print("Parser Error: Expected ) in array declaration");
                }
            }
        }
        
        // Optional: As [New] Type
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
            advance(); // Eat As
            
            // Check for "As New ClassName" — VB6 auto-instantiation
            bool is_new = false;
            if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER))
                && String(peek().value).nocasecmp_to("New") == 0) {
                is_new = true;
                advance(); // Eat New
            }
            
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                stmt->type_name = peek().value;
                advance();
                
                // Check for generic type parameter: Collection(Of T)
                if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                    // Peek ahead to see if this is (Of ...) rather than constructor args or array dims
                    int save_pos = current_pos;
                    advance(); // Eat (
                    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Of") == 0) {
                        advance(); // Eat Of
                        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                            stmt->generic_type_param = peek().value;
                            advance();
                        }
                        if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) advance(); // Eat )
                    } else {
                        // Not (Of ...) — rewind so the next section handles it
                        current_pos = save_pos;
                    }
                }
                
                // If "As New ClassName", create a NewNode as the initializer
                if (is_new) {
                    NewNode* nn = static_cast<NewNode*>(register_node(new NewNode()));
                    nn->class_name = stmt->type_name;

                    // Handle arguments for parameterized constructors: Dim x As New Class(args)
                    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
                        advance(); // Eat (
                        if (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
                            do {
                                if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) break;
                                {
                                    ExpressionNode* _tmp = parse_expression();
                                    if (_tmp) {
                                        nn->args.push_back(_tmp);
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

                    stmt->initializer = nn;
                    unregister_node(nn);
                }
            } else {
                UtilityFunctions::print("Parser Error: Expected type name after As");
            }
        }
        
        // Optional: = Initializer
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
            advance(); // Eat =
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) {
                stmt->initializer = _tmp;
                unregister_node(_tmp);
            }
        }
        
        return stmt;
    };
    
    // Parse first variable
    DimStatement* first_stmt = parse_single_var();
    if (!first_stmt) return nullptr;
    first_stmt->is_with_events = with_events;
    
    // Check for comma-separated additional declarations
    // VB6 style: Dim a, b, c As Integer - only c is Integer, a and b are Variant
    // VB.NET style: Dim a As Integer, b As String - each has own type
    while (check(VisualGasicTokenizer::TOKEN_COMMA)) {
        advance(); // Eat comma
        
        DimStatement* extra = parse_single_var();
        if (extra) {
            pending_statements.push_back(extra);
            unregister_node(extra);
        }
    }
    
    return first_stmt;
}

IfStatement* VisualGasicParser::parse_if() {
    advance(); // Eat If
    
    IfStatement* stmt = static_cast<IfStatement*>(register_node(new IfStatement()));
    {
        ExpressionNode* _tmp = parse_expression();
        if (!_tmp) {
            // Failed to parse condition - return null to signal error
            return nullptr;
        }
        stmt->condition = _tmp;
        unregister_node(_tmp);
    }

    // Implicit line continuation for boolean operators in conditions.
    // VB6 allows: If a _\n Or b Then  but VG has no explicit _ continuation.
    // Handle the common pattern where a boolean operator starts the next line:
    //   If someCondition
    //      Or otherCondition Then
    // Without this, "Or" would be parsed as a statement (CallStatement) → Err 35.
    while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
        // Peek past the newline to see if next meaningful token is a boolean operator
        int saved_pos = current_pos;
        advance(); // skip newline
        // Skip additional newlines and comments
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_COMMENT)) {
            advance();
        }
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String kw = String(peek().value);
            if (kw.nocasecmp_to("Or") == 0 || kw.nocasecmp_to("And") == 0 ||
                kw.nocasecmp_to("Xor") == 0 || kw.nocasecmp_to("OrElse") == 0 ||
                kw.nocasecmp_to("AndAlso") == 0 || kw.nocasecmp_to("Eqv") == 0 ||
                kw.nocasecmp_to("Imp") == 0) {
                // Continue parsing: wrap existing condition with the boolean operator
                String op = peek().value;
                advance(); // eat the boolean operator keyword
                ExpressionNode* right = parse_expression();
                if (right) {
                    BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                    bin->left = stmt->condition;
                    bin->right = right;
                    unregister_node(right);
                    bin->op = op;
                    stmt->condition = bin;
                    // Loop again in case there are more continuation lines
                    continue;
                }
            }
        }
        // Not a boolean continuation — restore position and break
        current_pos = saved_pos;
        break;
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
        // Single line If - parse one or more colon-separated statements
        // VB6: If x Then stmt1 : stmt2 : stmt3 [Else stmt4 : stmt5]
        Statement* s = parse_statement();
        if (s) {
            stmt->then_branch.push_back(s);
            unregister_node(s);

            // Parse additional colon-separated statements for then_branch
            while (check(VisualGasicTokenizer::TOKEN_COLON)) {
                advance(); // Eat :
                if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) break;
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Else") == 0) break;
                Statement* extra = parse_statement();
                if (extra) { stmt->then_branch.push_back(extra); unregister_node(extra); }
            }

            // Check for Else (Single Line)
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Else") == 0) {
                advance();
                Statement* el = parse_statement();
                if (el) {
                    stmt->else_branch.push_back(el);
                    unregister_node(el);
                    // Parse additional colon-separated statements for else_branch
                    while (check(VisualGasicTokenizer::TOKEN_COLON)) {
                        advance(); // Eat :
                        if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF)) break;
                        Statement* extra_el = parse_statement();
                        if (extra_el) { stmt->else_branch.push_back(extra_el); unregister_node(extra_el); }
                    }
                }
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
        // Check for "With Index varname" before "In"
        String index_var;
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("With") == 0) {
            advance(); // Eat With
            if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && String(peek().value).nocasecmp_to("Index") == 0) {
                advance(); // Eat Index
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                    index_var = peek().value;
                    advance();
                }
            }
        }
        if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) || String(peek().value).nocasecmp_to("In") != 0) {
            error("Expected 'In' after For Each variable");
            return nullptr;
        }
        advance(); // Eat In
        
        ForEachStatement* stmt = static_cast<ForEachStatement*>(register_node(new ForEachStatement()));
        stmt->variable_name = var_name;
        stmt->index_variable_name = index_var;
        {
            ExpressionNode* _tmp = parse_expression();
            if (!_tmp) {
                error("Failed to parse For Each collection expression");
                // Skip to newline to recover
                while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                    advance();
                }
                return stmt;
            }
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
    
    //Handle optional "As Type" declaration
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance(); // Eat "As"
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            advance(); // Eat type name (Integer, String, etc.)
        }
    }
    
    if (!match(VisualGasicTokenizer::TOKEN_OPERATOR)) { // Expect =
        error("Expected = in For");
        // Skip to newline to recover
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
            advance();
        }
        return stmt;
    }
    
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) {
            stmt->from_val = _tmp;
            unregister_node(_tmp);
        } else {
            error("Failed to parse For start value");
            // Skip to newline to recover
            while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                advance();
            }
            return stmt;
        }
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
            if (_tmp) {
                stmt->to_val = _tmp;
                unregister_node(_tmp);
            } else {
                error("Failed to parse For end value");
                // Skip to newline to recover
                while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
                    advance();
                }
                return stmt;
            }
        }
    } else {
        error("Expected To in For statement");
        // Skip to newline to recover
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
            advance();
        }
        return stmt;
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
    
    // Accept newline OR colon to start the body.
    // Colon enables inline single-line For: For i = 0 To N : stmt : Next
    // This is non-standard VB6 but follows C64 BASIC convention.
    // Prefer the multi-line form for readability; this is supported but not encouraged.
    bool inline_for = check(VisualGasicTokenizer::TOKEN_COLON);
    if (inline_for) advance(); // eat ':'
    else match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    // Body
    int body_depth = 0;
    while (!is_at_end() && error_count < MAX_ERRORS) {
        // Colon separates multiple statements on one line (inline For body)
        if (check(VisualGasicTokenizer::TOKEN_COLON)) { advance(); continue; }

        if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER))) {
            String kw = String(peek().value);
            
            // Check for Next
            if (kw.nocasecmp_to("Next") == 0) {
                advance();
                // Optional variable name
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) advance();
                break;
            }
            
            // Check for block-ending keywords that signal missing Next
            if (kw.nocasecmp_to("End") == 0 || 
                kw.nocasecmp_to("Wend") == 0 ||
                kw.nocasecmp_to("Loop") == 0 ||
                kw.nocasecmp_to("Else") == 0 ||
                kw.nocasecmp_to("ElseIf") == 0 ||
                kw.nocasecmp_to("Case") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'Next' statement for For loop (found '", kw, "')");
                break;
            }
        }
        
        // In inline mode, a newline ends the For body (Next must be on the same line)
        if (inline_for && check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
            UtilityFunctions::print("Parser Error: Missing 'Next' statement for inline For loop");
            break;
        }

        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else advance();
    }
    
    // Check if we hit EOF without finding Next
    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'Next' statement for For loop (reached end of file)");
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
                // Parse values: Case 1, 2, 3 or Case 1 To 10 or Case Is > 100
                do {
                    // Check for "Is" keyword (Case Is > 100)
                    String comp_op = "";
                    if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && 
                        String(peek().value).nocasecmp_to("Is") == 0) {
                        advance(); // consume "Is"
                        
                        // Next should be a comparison operator
                        VisualGasicTokenizer::Token op_tok = peek();
                        if (op_tok.type == VisualGasicTokenizer::TOKEN_OPERATOR) {
                            String op = String(op_tok.value);
                            if (op == ">" || op == "<" || op == ">=" || op == "<=" || op == "<>" || op == "=") {
                                comp_op = op;
                                advance(); // consume operator
                            }
                        }
                    }
                    
                    {
                        ExpressionNode* _tmp = parse_factor(); // Parse just the value, not full expression with operators
                        if (_tmp) { 
                            block->values.push_back(_tmp); 
                            unregister_node(_tmp);
                            block->comparison_ops.push_back(comp_op);
                            
                            // Check for "To" (range) - only valid if not using Is comparison
                            if (comp_op.is_empty() &&
                                (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && 
                                String(peek().value).nocasecmp_to("To") == 0) {
                                advance(); // consume "To"
                                ExpressionNode* range_end = parse_factor();
                                if (range_end) {
                                    block->range_ends.push_back(range_end);
                                    unregister_node(range_end);
                                } else {
                                    block->range_ends.push_back(nullptr);
                                }
                            } else {
                                block->range_ends.push_back(nullptr);
                            }
                        }
                    }
                    if (match(VisualGasicTokenizer::TOKEN_COMMA)) continue;
                    break;
                } while (!is_at_end());
            }
            
            // Accept either newline or colon after Case values
            // Colon enables inline syntax: Case "Scout": e = New Scout
            if (!match(VisualGasicTokenizer::TOKEN_NEWLINE)) {
                match(VisualGasicTokenizer::TOKEN_COLON);
            }
            
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
                    if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) { advance(); continue; }
                    // Colon separates multiple statements on one line (inline Case)
                    if (check(VisualGasicTokenizer::TOKEN_COLON)) { advance(); continue; }
                    break; // Avoid infinite loop
                }
                // After parsing a statement, also consume colon separators for multi-statement inline Cases
                while (check(VisualGasicTokenizer::TOKEN_COLON)) advance();
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
    
    if (!condition) {
        error("Failed to parse While condition");
        // Skip to newline to recover
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) {
            advance();
        }
        WhileStatement* stmt = static_cast<WhileStatement*>(register_node(new WhileStatement()));
        stmt->condition = nullptr;
        return stmt;
    }

    // Implicit line continuation for boolean operators in condition.
    while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
        int saved_pos = current_pos;
        advance();
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_COMMENT)) {
            advance();
        }
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String kw = String(peek().value);
            if (kw.nocasecmp_to("Or") == 0 || kw.nocasecmp_to("And") == 0 ||
                kw.nocasecmp_to("Xor") == 0 || kw.nocasecmp_to("OrElse") == 0 ||
                kw.nocasecmp_to("AndAlso") == 0 || kw.nocasecmp_to("Eqv") == 0 ||
                kw.nocasecmp_to("Imp") == 0) {
                String op = peek().value;
                advance();
                ExpressionNode* right = parse_expression();
                if (right) {
                    BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                    bin->left = condition;
                    bin->right = right;
                    unregister_node(right);
                    bin->op = op;
                    condition = bin;
                    continue;
                }
            }
        }
        current_pos = saved_pos;
        break;
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    WhileStatement* stmt = static_cast<WhileStatement*>(register_node(new WhileStatement()));
    stmt->condition = condition;
    
    while (!is_at_end() && error_count < MAX_ERRORS) {
        VisualGasicTokenizer::Token t = peek();
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t.value);
            
            // Check for Wend
            if (kw.nocasecmp_to("Wend") == 0) {
                advance();
                break;
            }
            
            // Check for block-ending keywords that signal missing Wend
            if (kw.nocasecmp_to("End") == 0 || 
                kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Loop") == 0 ||
                kw.nocasecmp_to("Else") == 0 ||
                kw.nocasecmp_to("ElseIf") == 0 ||
                kw.nocasecmp_to("Case") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'Wend' statement for While loop (found '", kw, "')");
                break;
            }
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }
    
    // Check if we hit EOF without finding Wend
    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'Wend' statement for While loop (reached end of file)");
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
        // Implicit line continuation for boolean operators in condition.
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
            int saved_pos = current_pos;
            advance();
            while (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_COMMENT)) {
                advance();
            }
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                String kw = String(peek().value);
                if (kw.nocasecmp_to("Or") == 0 || kw.nocasecmp_to("And") == 0 ||
                    kw.nocasecmp_to("Xor") == 0 || kw.nocasecmp_to("OrElse") == 0 ||
                    kw.nocasecmp_to("AndAlso") == 0 || kw.nocasecmp_to("Eqv") == 0 ||
                    kw.nocasecmp_to("Imp") == 0) {
                    String op = peek().value;
                    advance();
                    ExpressionNode* right = parse_expression();
                    if (right) {
                        BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                        bin->left = stmt->condition;
                        bin->right = right;
                        unregister_node(right);
                        bin->op = op;
                        stmt->condition = bin;
                        continue;
                    }
                }
            }
            current_pos = saved_pos;
            break;
        }
    } else if (val.nocasecmp_to("Until") == 0) {
        advance();
        stmt->condition_type = DoStatement::UNTIL;
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->condition = _tmp;
            unregister_node(_tmp);
        }
        // Implicit line continuation for boolean operators in condition.
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) {
            int saved_pos = current_pos;
            advance();
            while (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_COMMENT)) {
                advance();
            }
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                String kw = String(peek().value);
                if (kw.nocasecmp_to("Or") == 0 || kw.nocasecmp_to("And") == 0 ||
                    kw.nocasecmp_to("Xor") == 0 || kw.nocasecmp_to("OrElse") == 0 ||
                    kw.nocasecmp_to("AndAlso") == 0 || kw.nocasecmp_to("Eqv") == 0 ||
                    kw.nocasecmp_to("Imp") == 0) {
                    String op = peek().value;
                    advance();
                    ExpressionNode* right = parse_expression();
                    if (right) {
                        BinaryOpNode* bin = static_cast<BinaryOpNode*>(register_node(new BinaryOpNode()));
                        bin->left = stmt->condition;
                        bin->right = right;
                        unregister_node(right);
                        bin->op = op;
                        stmt->condition = bin;
                        continue;
                    }
                }
            }
            current_pos = saved_pos;
            break;
        }
    }
    
    match(VisualGasicTokenizer::TOKEN_NEWLINE);
    
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t_loop = peek();
        if ((t_loop.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_loop.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t_loop.value);
            
            // Check for Loop
            if (kw.nocasecmp_to("Loop") == 0) {
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
            
            // Check for block-ending keywords that signal missing Loop
            if (kw.nocasecmp_to("End") == 0 || 
                kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Wend") == 0 ||
                kw.nocasecmp_to("Else") == 0 ||
                kw.nocasecmp_to("ElseIf") == 0 ||
                kw.nocasecmp_to("Case") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'Loop' statement for Do block (found '", kw, "')");
                break;
            }
        }
        
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }
    
    // Check if we hit EOF without finding Loop
    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'Loop' statement for Do block (reached end of file)");
    }
    
    return stmt;
}

// ── Oscillate i = start To end [Step s] [Cycles n] ... Loop ──
// A ping-pong loop: counts from start → end, then end → start, repeating.
// The variable oscillates between the two bounds, reversing direction each time
// it reaches either limit.  Optional Cycles limits the number of one-way sweeps.
OscillateStatement* VisualGasicParser::parse_oscillate() {
    advance(); // Eat Oscillate

    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected variable name after Oscillate");
        return nullptr;
    }
    OscillateStatement* stmt = static_cast<OscillateStatement*>(register_node(new OscillateStatement()));
    stmt->variable_name = peek().value;
    advance(); // Eat variable name

    // Optional "As Type" declaration
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) advance();
    }

    // Expect "="
    if (!match(VisualGasicTokenizer::TOKEN_OPERATOR)) {
        error("Expected '=' in Oscillate");
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
        return stmt;
    }

    // Parse start value
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->from_val = _tmp; unregister_node(_tmp); }
        else { error("Failed to parse Oscillate start value"); return stmt; }
    }

    // Expect "To"
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) || String(peek().value).nocasecmp_to("To") != 0) {
        error("Expected 'To' in Oscillate");
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
        return stmt;
    }
    advance(); // Eat To

    // Parse end value
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->to_val = _tmp; unregister_node(_tmp); }
        else { error("Failed to parse Oscillate end value"); return stmt; }
    }

    // Optional "Step" clause
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Step") == 0) {
        advance(); // Eat Step
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->step_val = _tmp; unregister_node(_tmp); }
    }

    // Optional "Cycles" clause
    if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) &&
        String(peek().value).nocasecmp_to("Cycles") == 0) {
        advance(); // Eat Cycles
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->cycles_val = _tmp; unregister_node(_tmp); }
    }

    match(VisualGasicTokenizer::TOKEN_NEWLINE);

    // Parse body until "Loop"
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t_loop = peek();
        if ((t_loop.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_loop.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t_loop.value);
            if (kw.nocasecmp_to("Loop") == 0) {
                advance();
                break;
            }
            if (kw.nocasecmp_to("End") == 0 || kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Wend") == 0 || kw.nocasecmp_to("Else") == 0 ||
                kw.nocasecmp_to("ElseIf") == 0 || kw.nocasecmp_to("Case") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'Loop' statement for Oscillate block (found '", kw, "')");
                break;
            }
        }
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }

    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'Loop' statement for Oscillate block (reached end of file)");
    }

    return stmt;
}

// ── Repeat N Times [As counter] ... End Repeat ──
// A simple counted loop that executes the body exactly N times.
// Optional "As varname" exposes a 1-based counter to the body.
RepeatStatement* VisualGasicParser::parse_repeat() {
    advance(); // Eat Repeat

    RepeatStatement* stmt = static_cast<RepeatStatement*>(register_node(new RepeatStatement()));

    // Parse the count expression (e.g., 5, or a variable, or an expression)
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->count_val = _tmp; unregister_node(_tmp); }
        else { error("Expected count expression after Repeat"); return stmt; }
    }

    // Expect "Times"
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) ||
        String(peek().value).nocasecmp_to("Times") != 0) {
        error("Expected 'Times' after Repeat count");
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
        return stmt;
    }
    advance(); // Eat Times

    // Optional "As varname" for the counter variable
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) &&
        String(peek().value).nocasecmp_to("As") == 0) {
        advance(); // Eat As
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            stmt->counter_name = peek().value;
            advance();
        } else {
            error("Expected variable name after 'As' in Repeat");
        }
    }

    match(VisualGasicTokenizer::TOKEN_NEWLINE);

    // Parse body until "End Repeat"
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t_loop = peek();
        if ((t_loop.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_loop.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t_loop.value);
            if (kw.nocasecmp_to("End") == 0) {
                // Check for "End Repeat"
                if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD || peek(1).type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
                    String next_kw = String(peek(1).value);
                    if (next_kw.nocasecmp_to("Repeat") == 0) {
                        advance(); // Eat End
                        advance(); // Eat Repeat
                        break;
                    }
                }
            }
            // Error recovery: bail on unexpected block terminators
            if (kw.nocasecmp_to("Loop") == 0 || kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Wend") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'End Repeat' for Repeat block (found '", kw, "')");
                break;
            }
        }
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }

    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'End Repeat' for Repeat block (reached end of file)");
    }

    return stmt;
}

// ── Cycle Through collection For N As element ... End Cycle ──
// Iterates through a collection in round-robin fashion for a total of N iterations.
// The element variable receives collection[i Mod Len(collection)] each iteration.
CycleStatement* VisualGasicParser::parse_cycle() {
    advance(); // Eat Cycle

    // Expect "Through"
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) ||
        String(peek().value).nocasecmp_to("Through") != 0) {
        error("Expected 'Through' after Cycle");
        return nullptr;
    }
    advance(); // Eat Through

    CycleStatement* stmt = static_cast<CycleStatement*>(register_node(new CycleStatement()));

    // Parse collection expression
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->collection = _tmp; unregister_node(_tmp); }
        else { error("Expected collection expression after 'Cycle Through'"); return stmt; }
    }

    // Expect "For"
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) ||
        String(peek().value).nocasecmp_to("For") != 0) {
        error("Expected 'For' after collection in Cycle Through");
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
        return stmt;
    }
    advance(); // Eat For

    // Parse count expression
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->count_val = _tmp; unregister_node(_tmp); }
        else { error("Expected count expression after 'For' in Cycle Through"); return stmt; }
    }

    // Expect "As varname"
    if (!check(VisualGasicTokenizer::TOKEN_KEYWORD) ||
        String(peek().value).nocasecmp_to("As") != 0) {
        error("Expected 'As variable_name' in Cycle Through");
        while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
        return stmt;
    }
    advance(); // Eat As

    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        stmt->element_name = peek().value;
        advance();
    } else {
        error("Expected variable name after 'As' in Cycle Through");
    }

    match(VisualGasicTokenizer::TOKEN_NEWLINE);

    // Parse body until "End Cycle"
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t_loop = peek();
        if ((t_loop.type == VisualGasicTokenizer::TOKEN_KEYWORD || t_loop.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t_loop.value);
            if (kw.nocasecmp_to("End") == 0) {
                if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD || peek(1).type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
                    String next_kw = String(peek(1).value);
                    if (next_kw.nocasecmp_to("Cycle") == 0) {
                        advance(); // Eat End
                        advance(); // Eat Cycle
                        break;
                    }
                }
            }
            if (kw.nocasecmp_to("Loop") == 0 || kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Wend") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'End Cycle' for Cycle Through block (found '", kw, "')");
                break;
            }
        }
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }

    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'End Cycle' for Cycle Through block (reached end of file)");
    }

    return stmt;
}

// ── Every N Frames/Seconds ... End Every ──
// A conditional guard that executes its body at a regular interval.
// Uses hidden persistent counters to track frame count or elapsed time.
static int every_unique_counter = 0;

EveryStatement* VisualGasicParser::parse_every() {
    advance(); // Eat Every

    EveryStatement* stmt = static_cast<EveryStatement*>(register_node(new EveryStatement()));
    stmt->unique_id = every_unique_counter++;

    // Parse the interval expression
    {
        ExpressionNode* _tmp = parse_expression();
        if (_tmp) { stmt->interval_val = _tmp; unregister_node(_tmp); }
        else { error("Expected interval value after Every"); return stmt; }
    }

    // Expect "Frames" or "Seconds"
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        String unit = String(peek().value);
        if (unit.nocasecmp_to("Frames") == 0 || unit.nocasecmp_to("Frame") == 0) {
            stmt->interval_type = EveryStatement::FRAMES;
            advance();
        } else if (unit.nocasecmp_to("Seconds") == 0 || unit.nocasecmp_to("Second") == 0) {
            stmt->interval_type = EveryStatement::SECONDS;
            advance();
        } else {
            error("Expected 'Frames' or 'Seconds' after interval in Every");
            while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();
            return stmt;
        }
    } else {
        error("Expected 'Frames' or 'Seconds' after interval in Every");
        return stmt;
    }

    match(VisualGasicTokenizer::TOKEN_NEWLINE);

    // Parse body until "End Every"
    while (!is_at_end()) {
        VisualGasicTokenizer::Token t = peek();
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String kw = String(t.value);
            if (kw.nocasecmp_to("End") == 0) {
                if (peek(1).type == VisualGasicTokenizer::TOKEN_KEYWORD || peek(1).type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
                    String next_kw = String(peek(1).value);
                    if (next_kw.nocasecmp_to("Every") == 0) {
                        advance(); // Eat End
                        advance(); // Eat Every
                        break;
                    }
                }
            }
            if (kw.nocasecmp_to("Loop") == 0 || kw.nocasecmp_to("Next") == 0 ||
                kw.nocasecmp_to("Wend") == 0) {
                UtilityFunctions::print("Parser Error: Missing 'End Every' for Every block (found '", kw, "')");
                break;
            }
        }
        Statement* s = parse_statement();
        if (s) { stmt->body.push_back(s); unregister_node(s); }
        else if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        else current_pos++;
    }

    if (is_at_end()) {
        UtilityFunctions::print("Parser Error: Missing 'End Every' for Every block (reached end of file)");
    }

    return stmt;
}

// ── Tween target.prop [From val] To val Over dur [Ease type] [Trans type] ──
TweenStatement* VisualGasicParser::parse_tween() {
    advance(); // Eat Tween

    TweenStatement* stmt = static_cast<TweenStatement*>(register_node(new TweenStatement()));

    // Parse the property path as a dot-chain expression.
    // E.g. Me.Position.X, sprite.Modulate.A, label.Left
    // This produces nested MemberAccessNodes.
    ExpressionNode* prop_expr = parse_expression();
    if (!prop_expr) {
        error("Expected property path after 'Tween'");
        return stmt;
    }

    // Decompose the MemberAccess chain into (target_node, property_path).
    // The leftmost base is the target node; remaining members joined with ":"
    // form the Godot property path.
    if (prop_expr->type != ExpressionNode::MEMBER_ACCESS) {
        error("Tween requires a property path (e.g. Me.Position or sprite.Left)");
        if (prop_expr) { unregister_node(prop_expr); delete prop_expr; }
        return stmt;
    }

    // Walk the MemberAccess chain to extract segments
    Vector<String> segments;
    ExpressionNode* base = prop_expr;
    while (base && base->type == ExpressionNode::MEMBER_ACCESS) {
        MemberAccessNode* ma = (MemberAccessNode*)base;
        segments.push_back(ma->member_name);
        base = ma->base_object;
    }
    // segments is in reverse order (innermost first), base is the root

    if (segments.size() < 1) {
        error("Tween requires at least one property (e.g. Me.Position)");
        if (prop_expr) { unregister_node(prop_expr); delete prop_expr; }
        return stmt;
    }

    // Detach the base from the chain so it won't be deleted with prop_expr
    // Walk down to the deepest MemberAccessNode and detach its base_object
    {
        ExpressionNode* walk = prop_expr;
        ExpressionNode* prev = nullptr;
        while (walk && walk->type == ExpressionNode::MEMBER_ACCESS) {
            MemberAccessNode* ma = (MemberAccessNode*)walk;
            prev = walk;
            walk = ma->base_object;
        }
        // 'prev' is the deepest MemberAccessNode; its base_object is the target node
        if (prev && prev->type == ExpressionNode::MEMBER_ACCESS) {
            MemberAccessNode* deepest = (MemberAccessNode*)prev;
            stmt->target_node = deepest->base_object;
            deepest->base_object = nullptr; // detach so prop_expr delete won't free it
        }
    }

    // Build property path from segments (reversed): "position:x"
    // VB6 property aliasing happens at compile time
    // segments[0] is innermost (e.g. "X"), segments[last] is outermost property (e.g. "Position")
    String prop_path;
    for (int i = segments.size() - 1; i >= 0; i--) {
        if (!prop_path.is_empty()) prop_path += ":";
        prop_path += segments[i];
    }
    stmt->property_path = prop_path;

    // Clean up the MemberAccess chain (target_node was detached)
    unregister_node(prop_expr);
    delete prop_expr;

    // Optional: From <expr>
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("From") == 0) {
        advance(); // Eat From
        ExpressionNode* from_expr = parse_expression();
        if (from_expr) { stmt->from_val = from_expr; unregister_node(from_expr); }
        else { error("Expected expression after 'From'"); return stmt; }
    }

    // Required: To <expr>
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("To") == 0) {
        advance(); // Eat To
        ExpressionNode* to_expr = parse_expression();
        if (to_expr) { stmt->to_val = to_expr; unregister_node(to_expr); }
        else { error("Expected expression after 'To'"); return stmt; }
    } else {
        error("Expected 'To' in Tween statement");
        return stmt;
    }

    // Required: Over <expr>
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Over") == 0) {
        advance(); // Eat Over
        ExpressionNode* dur_expr = parse_expression();
        if (dur_expr) { stmt->duration = dur_expr; unregister_node(dur_expr); }
        else { error("Expected duration expression after 'Over'"); return stmt; }
    } else {
        error("Expected 'Over' in Tween statement");
        return stmt;
    }

    // Optional: Ease <type>  (In, Out, InOut, OutIn)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Ease") == 0) {
        advance(); // Eat Ease
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String ease = peek().value;
            if (ease.nocasecmp_to("In") == 0) stmt->ease_type = 0;
            else if (ease.nocasecmp_to("Out") == 0) stmt->ease_type = 1;
            else if (ease.nocasecmp_to("InOut") == 0) stmt->ease_type = 2;
            else if (ease.nocasecmp_to("OutIn") == 0) stmt->ease_type = 3;
            else { error("Unknown Ease type '" + ease + "' — expected In, Out, InOut, or OutIn"); return stmt; }
            advance();
        } else {
            error("Expected ease type after 'Ease'");
            return stmt;
        }
    }

    // Optional: Trans <type>  (Linear, Sine, Quint, Quart, Quad, Expo, Elastic, Cubic, Circ, Bounce, Back, Spring)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("Trans") == 0) {
        advance(); // Eat Trans
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            String tr = peek().value;
            if (tr.nocasecmp_to("Linear") == 0) stmt->trans_type = 0;
            else if (tr.nocasecmp_to("Sine") == 0) stmt->trans_type = 1;
            else if (tr.nocasecmp_to("Quint") == 0) stmt->trans_type = 2;
            else if (tr.nocasecmp_to("Quart") == 0) stmt->trans_type = 3;
            else if (tr.nocasecmp_to("Quad") == 0) stmt->trans_type = 4;
            else if (tr.nocasecmp_to("Expo") == 0) stmt->trans_type = 5;
            else if (tr.nocasecmp_to("Elastic") == 0) stmt->trans_type = 6;
            else if (tr.nocasecmp_to("Cubic") == 0) stmt->trans_type = 7;
            else if (tr.nocasecmp_to("Circ") == 0) stmt->trans_type = 8;
            else if (tr.nocasecmp_to("Bounce") == 0) stmt->trans_type = 9;
            else if (tr.nocasecmp_to("Back") == 0) stmt->trans_type = 10;
            else if (tr.nocasecmp_to("Spring") == 0) stmt->trans_type = 11;
            else { error("Unknown Trans type '" + tr + "'"); return stmt; }
            advance();
        } else {
            error("Expected transition type after 'Trans'");
            return stmt;
        }
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
        } else if (val.nocasecmp_to("Oscillate") == 0) {
            c->loop_type = ContinueStatement::OSCILLATE;
            advance();
        } else if (val.nocasecmp_to("Repeat") == 0) {
            c->loop_type = ContinueStatement::REPEAT;
            advance();
        } else if (val.nocasecmp_to("Cycle") == 0) {
            c->loop_type = ContinueStatement::CYCLE;
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

        } else if (op == "+=" || op == "-=" || op == "*=" || op == "/=" || op == "&=" || op == "\\=" || op == "^=" || op == "<<=" || op == ">>=") {
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
            else if (op == "&=") bin->op = "&";
            else if (op == "\\=") bin->op = "\\";
            else if (op == "^=") bin->op = "^";
            else if (op == "<<=") bin->op = "<<";
            else if (op == ">>=") bin->op = ">>";
            
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

    // Keyword-based compound assignment: And= Or= Xor= Mod=
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
        String kw = String(peek().value).to_lower();
        if ((kw == "and" || kw == "or" || kw == "xor" || kw == "mod") &&
            current_pos + 1 < (int)tokens.size() &&
            tokens[current_pos + 1].type == VisualGasicTokenizer::TOKEN_OPERATOR &&
            String(tokens[current_pos + 1].value) == "=") {

            String bin_op = peek().value; // Preserve keyword casing
            advance(); // Eat keyword (And/Or/Xor/Mod)
            advance(); // Eat =

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
            bin->op = bin_op;

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
                    
                    // Fixed-length string: As String * 30
                    if (member.type.nocasecmp_to("String") == 0 && check(VisualGasicTokenizer::TOKEN_OPERATOR) && String(peek().value) == "*") {
                        advance(); // Eat *
                        if (check(VisualGasicTokenizer::TOKEN_LITERAL_INTEGER)) {
                            member.fixed_length = String(peek().value).to_int();
                            advance();
                        }
                    }
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

// ── Class ... End Class ──
ClassDefinition* VisualGasicParser::parse_class() {
    advance(); // Eat 'Class'

    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        error("Expected class name after 'Class'");
        return nullptr;
    }

    ClassDefinition* cls = static_cast<ClassDefinition*>(register_node(new ClassDefinition()));
    cls->name = peek().value;
    advance();

    // Skip newlines before checking for Inherits
    while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();

    // Optional: Inherits BaseClass
    if ((check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) && String(peek().value).nocasecmp_to("inherits") == 0) {
        advance(); // Eat Inherits
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
            cls->base_class = peek().value;
            advance();
        }
    }

    // Skip newlines
    while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();

    // Parse class body
    while (!is_at_end() && error_count < MAX_ERRORS) {
        VisualGasicTokenizer::Token t = peek();

        // Skip newlines
        if (t.type == VisualGasicTokenizer::TOKEN_NEWLINE) { advance(); continue; }

        // End Class
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) &&
            String(t.value).nocasecmp_to("end") == 0) {
            VisualGasicTokenizer::Token next = peek(1);
            if (String(next.value).nocasecmp_to("class") == 0) {
                current_pos += 2; // Eat End Class
                break;
            }
        }

        String val = String(t.value).to_lower();

        // Visibility modifier — peek ahead to see what it applies to
        bool is_public_member = true;
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && (val == "public" || val == "private")) {
            is_public_member = (val == "public");
            advance(); // Eat Public/Private
            t = peek();
            val = String(t.value).to_lower();
        }

        // Sub / Function → method
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) &&
            (val == "sub" || val == "function")) {
            SubDefinition* method = parse_sub();
            if (method) {
                // Check for Class_Initialize / Class_Terminate
                if (method->name.nocasecmp_to("Class_Initialize") == 0) {
                    cls->class_initialize = method;
                } else if (method->name.nocasecmp_to("Class_Terminate") == 0) {
                    cls->class_terminate = method;
                }
                cls->methods.push_back(method);
                unregister_node(method);
            }
            continue;
        }

        // Property Get/Let/Set
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && val == "property") {
            PropertyDefinition* prop = parse_property();
            if (prop) {
                cls->properties.push_back(prop);
                unregister_node(prop);
            }
            continue;
        }

        // Dim / member variable
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && val == "dim") {
            DimStatement* dim = parse_dim();
            if (dim) {
                VariableDefinition* v = static_cast<VariableDefinition*>(register_node(new VariableDefinition()));
                v->name = dim->variable_name;
                v->type = dim->type_name;
                v->visibility = is_public_member ? VIS_PUBLIC : VIS_PRIVATE;
                cls->members.push_back(v);
                unregister_node(v);
                unregister_node(dim);
                delete dim;
            }
            continue;
        }

        // Bare identifier with As → member field (no Dim prefix, VB6 style)
        if (t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) {
            String member_name = t.value;
            advance();
            String member_type = "Variant";
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("as") == 0) {
                advance(); // Eat As
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                    member_type = peek().value;
                    advance();
                }
            }
            VariableDefinition* v = static_cast<VariableDefinition*>(register_node(new VariableDefinition()));
            v->name = member_name;
            v->type = member_type;
            v->visibility = is_public_member ? VIS_PUBLIC : VIS_PRIVATE;
            cls->members.push_back(v);
            unregister_node(v);
            continue;
        }

        // Event declaration
        if (t.type == VisualGasicTokenizer::TOKEN_KEYWORD && val == "event") {
            EventDefinition* evt = parse_event();
            if (evt) {
                cls->events.push_back(evt);
                unregister_node(evt);
            }
            continue;
        }

        // Unknown token — skip
        advance();
    }

    return cls;
}

// ── Property Get/Let/Set ... End Property ──
PropertyDefinition* VisualGasicParser::parse_property() {
    advance(); // Eat 'Property'

    PropertyDefinition* prop = static_cast<PropertyDefinition*>(register_node(new PropertyDefinition()));

    // Get / Let / Set
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) || check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        String accessor = String(peek().value).to_lower();
        advance();
        if (accessor == "get") {
            prop->property_type = PropertyDefinition::PROP_GET;
        } else if (accessor == "let") {
            prop->property_type = PropertyDefinition::PROP_LET;
        } else if (accessor == "set") {
            prop->property_type = PropertyDefinition::PROP_SET;
        } else {
            error("Expected Get, Let, or Set after Property");
            return prop;
        }
    }

    // Property name
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        prop->name = peek().value;
        advance();
    }

    // Parameters (for Property Let/Set: includes the value parameter)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // Eat (
        while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
            Parameter param;
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                param.name = peek().value;
                advance();
                if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("as") == 0) {
                    advance();
                    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                        param.type_hint = peek().value;
                        advance();
                    }
                }
                prop->parameters.push_back(param);
            }
            if (!match(VisualGasicTokenizer::TOKEN_COMMA)) break;
        }
        if (check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) advance(); // Eat )
    }

    // Return type for Property Get
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("as") == 0) {
        advance(); // Eat As
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            prop->return_type = peek().value;
            advance();
        }
    }

    // Skip to newline
    while (!is_at_end() && peek().type != VisualGasicTokenizer::TOKEN_NEWLINE) advance();

    // Parse body until End Property
    while (!is_at_end() && error_count < MAX_ERRORS) {
        VisualGasicTokenizer::Token t = peek();

        if (t.type == VisualGasicTokenizer::TOKEN_NEWLINE) { advance(); continue; }

        // End Property
        if ((t.type == VisualGasicTokenizer::TOKEN_KEYWORD || t.type == VisualGasicTokenizer::TOKEN_IDENTIFIER) &&
            String(t.value).nocasecmp_to("end") == 0) {
            VisualGasicTokenizer::Token next = peek(1);
            if (String(next.value).nocasecmp_to("property") == 0) {
                current_pos += 2; // Eat End Property
                break;
            }
        }

        Statement* stmt = parse_statement();
        if (stmt) {
            prop->body.push_back(stmt);
            unregister_node(stmt);
        }
    }

    return prop;
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
    
    // Parse first expression
    if (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF) && !check(VisualGasicTokenizer::TOKEN_COLON)) {
        {
            ExpressionNode* _tmp = parse_expression();
            stmt->expression = _tmp;
            unregister_node(_tmp);
        }
        // Parse additional expressions separated by ; or ,
        while (check(VisualGasicTokenizer::TOKEN_SEMICOLON) || check(VisualGasicTokenizer::TOKEN_COMMA)) {
            bool was_semicolon = check(VisualGasicTokenizer::TOKEN_SEMICOLON);
            advance(); // Eat ; or ,
            // If semicolon at end of line = suppress newline
            if (check(VisualGasicTokenizer::TOKEN_NEWLINE) || check(VisualGasicTokenizer::TOKEN_EOF) || check(VisualGasicTokenizer::TOKEN_COLON)) {
                if (was_semicolon) stmt->suppress_newline = true;
                break;
            }
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) {
                stmt->extra_expressions.push_back(_tmp);
                unregister_node(_tmp);
            }
        }
    }
    
    return stmt;
}

WriteStatement* VisualGasicParser::parse_write() {
    advance(); // Eat Write
    WriteStatement* stmt = static_cast<WriteStatement*>(register_node(new WriteStatement()));

    // Expect #N
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

    // Parse comma-separated expressions
    while (!check(VisualGasicTokenizer::TOKEN_NEWLINE) && !check(VisualGasicTokenizer::TOKEN_EOF) && !check(VisualGasicTokenizer::TOKEN_COLON)) {
        {
            ExpressionNode* _tmp = parse_expression();
            if (_tmp) { stmt->expressions.push_back(_tmp); unregister_node(_tmp); }
        }
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            advance();
            continue;
        }
        break;
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
            else if (m.nocasecmp_to("Binary") == 0) stmt->mode = OpenStatement::MODE_BINARY;
            else if (m.nocasecmp_to("Random") == 0) stmt->mode = OpenStatement::MODE_RANDOM;
            else UtilityFunctions::print("Parser Error: Unknown Open mode ", m);
            advance();
        }
    }
    
    // Len=N for Random mode
    if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) && String(peek().value).nocasecmp_to("Len") == 0) {
        advance(); // Eat Len
        if (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") {
            advance(); // Eat =
            Variant len_val = peek().value;
            stmt->record_length = (int)len_val;
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
        // Check for empty slot (consecutive commas: Data 1,,3)
        if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
            LiteralNode* null_lit = static_cast<LiteralNode*>(register_node(new LiteralNode()));
            null_lit->value = Variant(); // Nothing
            stmt->values.push_back(null_lit);
            unregister_node(null_lit);
            advance(); // eat comma
            continue;
        }
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
        
        // Optional: As TypeName (typed Read coercion)
        String type_name;
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
            advance(); // Eat As
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                type_name = peek().value;
                advance();
            }
        }
        stmt->type_names.push_back(type_name);
        
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

ClearDataStatement* VisualGasicParser::parse_clear_data() {
    advance(); // Eat ClearData
    return static_cast<ClearDataStatement*>(register_node(new ClearDataStatement()));
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

LoadDataStatement* VisualGasicParser::parse_data_from_string() {
    advance(); // Eat DataFromString
    
    LoadDataStatement* stmt = static_cast<LoadDataStatement*>(register_node(new LoadDataStatement()));
    stmt->is_from_string = true;
    {
        ExpressionNode* _tmp = parse_expression();
        stmt->path_expression = _tmp;
        unregister_node(_tmp);
    }
    if (!stmt->path_expression) {
        error("Expected string expression after DataFromString");
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
        } else if (type == "oscillate") {
            s->exit_type = ExitStatement::EXIT_OSCILLATE;
            valid = true;
        } else if (type == "repeat") {
            s->exit_type = ExitStatement::EXIT_REPEAT;
            valid = true;
        } else if (type == "cycle") {
            s->exit_type = ExitStatement::EXIT_CYCLE;
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

EraseStatement* VisualGasicParser::parse_erase() {
    advance(); // Eat Erase
    
    EraseStatement* s = static_cast<EraseStatement*>(register_node(new EraseStatement()));
    
    if (!check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        UtilityFunctions::print("Parser Error: Expected variable name after Erase");
        unregister_node(s); delete s;
        return nullptr;
    }
    
    s->variable_name = peek().value;
    advance();
    
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

void VisualGasicParser::parse_enum(bool p_is_flags) {
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
    def->is_flags = p_is_flags;
    
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
    
    // Parse the signal/coroutine expression to await
    ExpressionNode* expr = parse_expression();
    if (!expr) {
        error("Expected expression after 'Await'");
        return nullptr;
    }
    
    // Create proper AwaitStatement (v4.2.0) — compiler will emit OP_AWAIT
    AwaitStatement* await_stmt = static_cast<AwaitStatement*>(register_node(new AwaitStatement()));
    await_stmt->expression = expr;
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
    
    // End Task / End Thread
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).to_lower() == "end") {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            String et = String(peek().value).to_lower();
            if (et == "task" || et == "thread") {
                advance();
            }
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
    } else if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
        // Support bare identifier: Task Wait SumTask
        wait_stmt->task_names.push_back(peek().value);
        advance();
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
    
    // Handle optional "As Type" declaration (e.g., Parallel For i As Integer = 0 To N)
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance(); // Eat "As"
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            advance(); // Eat type name (Integer, String, etc.)
        }
    }
    
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

// === Lambda Expression Parser ===
// Supports two forms:
//   1. Arrow syntax:  Lambda(x, y) => x + y
//   2. Block syntax:  Function(x, y) ... End Function
ExpressionNode* VisualGasicParser::parse_lambda() {
    String kw = peek().value;
    bool is_sub_lambda = kw.nocasecmp_to("Sub") == 0;
    advance(); // Eat Lambda/Fn/Function/Sub
    
    LambdaNode* lam = static_cast<LambdaNode*>(register_node(new LambdaNode()));
    
    // Parse parameter list: (param1, param2, ...)
    if (check(VisualGasicTokenizer::TOKEN_PAREN_OPEN)) {
        advance(); // Eat (
        while (!check(VisualGasicTokenizer::TOKEN_PAREN_CLOSE) && !is_at_end()) {
            Parameter p;
            p.is_by_ref = false; // Lambdas default to ByVal
            p.is_optional = false;
            p.is_param_array = false;
            
            // Optional ByVal/ByRef
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                String pk = peek().value;
                if (pk.nocasecmp_to("ByVal") == 0) { p.is_by_ref = false; advance(); }
                else if (pk.nocasecmp_to("ByRef") == 0) { p.is_by_ref = true; advance(); }
            }
            
            if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER)) {
                p.name = peek().value;
                advance();
            } else {
                break;
            }
            
            // Optional type hint: As Integer
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
                advance(); // Eat As
                if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
                    p.type_hint = peek().value;
                    advance();
                }
            }
            
            lam->parameters.push_back(p);
            
            if (check(VisualGasicTokenizer::TOKEN_COMMA)) {
                advance();
            } else {
                break;
            }
        }
        if (!match(VisualGasicTokenizer::TOKEN_PAREN_CLOSE)) {
            error("Expected ')' after lambda parameters");
        }
    }
    
    // Optional return type: As Integer
    if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("As") == 0) {
        advance();
        if (check(VisualGasicTokenizer::TOKEN_IDENTIFIER) || check(VisualGasicTokenizer::TOKEN_KEYWORD)) {
            lam->return_type = peek().value;
            advance();
        }
    }
    
    // Determine style: arrow (inline expression) vs block (multi-statement)
    // Arrow if: => present, OR no newline follows (inline expression body)
    // Block if: newline follows with no => (expects End Function / End Sub)
    bool has_arrow = (check(VisualGasicTokenizer::TOKEN_OPERATOR) && peek().value == "=") &&
                     (current_pos + 1 < tokens.size() && tokens[current_pos + 1].value == ">");
    bool has_newline = check(VisualGasicTokenizer::TOKEN_NEWLINE);
    bool is_arrow_style = has_arrow || !has_newline;
    lam->is_arrow = is_arrow_style;
    
    if (is_arrow_style) {
        // Arrow/inline syntax: any keyword with => expr, or inline expr without =>
        // Consume => if present
        if (has_arrow) {
            advance(); // Eat =
            advance(); // Eat >
        }
        
        lam->body_expression = parse_expression();
        if (lam->body_expression) unregister_node(lam->body_expression);
    } else if (is_sub_lambda) {
        // Block Sub lambda: Sub(params) ... End Sub  (newline already confirmed)
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        while (!is_at_end()) {
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("End") == 0) {
                if (current_pos + 1 < tokens.size()) {
                    String next_val = tokens[current_pos + 1].value;
                    if (next_val.nocasecmp_to("Sub") == 0) {
                        advance(); // Eat End
                        advance(); // Eat Sub
                        break;
                    }
                }
            }
            Statement* s = parse_statement();
            if (s) { lam->body_statements.push_back(s); unregister_node(s); }
            else {
                if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                else if (!is_at_end()) advance();
            }
        }
        lam->is_arrow = false;
    } else {
        // Block syntax: Function(params) ... End Function
        // Skip optional newline
        while (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
        
        // Parse body until End Function
        while (!is_at_end()) {
            if (check(VisualGasicTokenizer::TOKEN_KEYWORD) && String(peek().value).nocasecmp_to("End") == 0) {
                if (current_pos + 1 < tokens.size()) {
                    String next_val = tokens[current_pos + 1].value;
                    if (next_val.nocasecmp_to("Function") == 0) {
                        advance(); // Eat End
                        advance(); // Eat Function
                        break;
                    }
                }
            }
            
            Statement* s = parse_statement();
            if (s) { lam->body_statements.push_back(s); unregister_node(s); }
            else {
                if (check(VisualGasicTokenizer::TOKEN_NEWLINE)) advance();
                else if (!is_at_end()) advance();
            }
        }
        
        lam->is_arrow = false;
    }
    
    return lam;
}
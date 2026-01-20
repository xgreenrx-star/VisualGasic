#ifndef VISUAL_GASIC_PARSER_H
#define VISUAL_GASIC_PARSER_H

#include "visual_gasic_tokenizer.h"
#include "visual_gasic_ast.h"

class VisualGasicParser {
    Vector<VisualGasicTokenizer::Token> tokens;
    int current_pos;

    VisualGasicTokenizer::Token peek(int offset = 0);
    VisualGasicTokenizer::Token advance();
    VisualGasicTokenizer::Token previous();
    bool match(VisualGasicTokenizer::TokenType type);
    bool check(VisualGasicTokenizer::TokenType type);
    bool is_at_end();

public:
    struct ParsingError {
        int line;
        int column;
        String message;
    };
    Vector<ParsingError> errors;

    VisualGasicParser();
    ~VisualGasicParser();

    ModuleNode* current_module; // Store reference to module being parsed
    
    ModuleNode* parse(const Vector<VisualGasicTokenizer::Token>& p_tokens);
    static Vector<ExpressionNode*> parse_data_values_from_text(const String& text);

private:
    void error(const String& message);

    SubDefinition* parse_sub();
    StructDefinition* parse_struct();
    EventDefinition* parse_event();
    Statement* parse_statement();
    
    // Detailed statement parsers
    DimStatement* parse_dim();
    ConstStatement* parse_const();
    RaiseEventStatement* parse_raise_event(); // Helper
    IfStatement* parse_if();
    Statement* parse_for();
    WhileStatement* parse_while();
    DoStatement* parse_do();
    SelectStatement* parse_select();
    Statement* parse_return();
    Statement* parse_continue();
    Statement* parse_assignment_or_call();
    
    PrintStatement* parse_print();
    DataStatement* parse_data();
    DataStatement* parse_data_file();
    LoadDataStatement* parse_load_data();
    ReadStatement* parse_read();
    RestoreStatement* parse_restore();
    OpenStatement* parse_open();
    CloseStatement* parse_close();
    SeekStatement* parse_seek();
    KillStatement* parse_kill();
    NameStatement* parse_name();
    TryStatement* parse_try();
    InputStatement* parse_input(bool is_line);
    ExitStatement* parse_exit();
    ReDimStatement* parse_redim();
    WithStatement* parse_with();
    RaiseStatement* parse_raise();
    void parse_enum(); // Parses Enum block

    // Expression parsing
    ExpressionNode* parse_expression(); // Pythonic If-Else
    ExpressionNode* parse_logical_or(); // OR
    ExpressionNode* parse_and();        // AND
    ExpressionNode* parse_not();        // NOT
    ExpressionNode* parse_comparison(); // = < >
    ExpressionNode* parse_addition();   // + - &
    ExpressionNode* parse_term();       // * /
    ExpressionNode* parse_exponentiation(); // ** (Power)
    ExpressionNode* parse_unary();
    ExpressionNode* parse_factor();     // ( ) Lit Var Call unary-

public:
    static String format_iif_to_inline(const String& p_source);
};

#endif // VISUAL_GASIC_PARSER_H

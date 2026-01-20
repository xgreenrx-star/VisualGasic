#ifndef VISUAL_GASIC_TOKENIZER_H
#define VISUAL_GASIC_TOKENIZER_H

#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

class VisualGasicTokenizer {
public:
    enum TokenType {
        TOKEN_EOF,
        TOKEN_NEWLINE,
        TOKEN_IDENTIFIER,
        TOKEN_KEYWORD,
        TOKEN_LITERAL_INTEGER,
        TOKEN_LITERAL_FLOAT,
        TOKEN_LITERAL_STRING,
        TOKEN_STRING_INTERP,
        TOKEN_OPERATOR,
        TOKEN_PAREN_OPEN,
        TOKEN_PAREN_CLOSE,
        TOKEN_COMMA,
        TOKEN_COLON,
        TOKEN_COMMENT,
        TOKEN_ERROR
    };

    struct Token {
        TokenType type;
        Variant value;
        int line;
        int column;
    };

    VisualGasicTokenizer();
    ~VisualGasicTokenizer();

    Vector<Token> tokenize(const String &p_source_code);
    String token_type_to_string(TokenType p_type);

    // Error State
    bool has_error;
    int error_line;
    int error_column;
    String error_message;

    static bool is_digit(char32_t c);
    static bool is_alpha(char32_t c);
    static bool is_alphanumeric(char32_t c);
    static bool is_whitespace(char32_t c);
};

#endif // VISUAL_GASIC_TOKENIZER_H

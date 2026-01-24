#ifndef VISUAL_GASIC_TOKENIZER_H
#define VISUAL_GASIC_TOKENIZER_H

#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

#include <string>

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
        Variant value; // still available for numeric values and later conversions
        std::string text; // textual representation to avoid constructing godot::String during tokenization
        int line;
        int column;
    };

    VisualGasicTokenizer();
    ~VisualGasicTokenizer();

    // Make tokenizer error message a plain std::string to avoid String ctor at construction time
    bool has_error;
    int error_line;
    int error_column;
    std::string error_message;

    Vector<Token> tokenize(const String &p_source_code);
    Vector<Token> tokenize_from_utf8(const std::string &p_utf8);
    String token_type_to_string(TokenType p_type);

    static bool is_digit(char32_t c);
    static bool is_alpha(char32_t c);
    static bool is_alphanumeric(char32_t c);
    static bool is_whitespace(char32_t c);
};

#endif // VISUAL_GASIC_TOKENIZER_H

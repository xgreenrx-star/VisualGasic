#ifndef TOOLS_PARSER_STD_PARSER_H
#define TOOLS_PARSER_STD_PARSER_H

#include <string>
#include <vector>
#include <memory>
#include "standalone_tokenizer.h"

struct WatchEntry {
    std::string var;
    bool once = false;
    bool local = false;
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

struct WheneverBranch {
    std::string pattern;
    std::vector<std::string> body_lines;
};

struct WheneverEntry {
    std::string var;
    int start_line = 0;
    int end_line = 0;
    std::vector<WheneverBranch> branches;
};

struct SubEntry {
    std::string name;
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

struct IfEntry {
    std::string condition; // textual condition
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

struct FunctionEntry {
    std::string name;
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

struct ForEntry {
    std::string var;
    std::string start_expr;
    std::string end_expr;
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

struct WhileEntry {
    std::string condition;
    int start_line = 0;
    int end_line = 0;
    std::vector<std::string> body_lines;
};

// Lightweight AST node types for testing and structured assertions
enum ASTNodeType {
    AST_WATCH,
    AST_WHENEVER,
    AST_SUB,
    AST_IF,
    AST_FUNCTION,
    AST_FOR,
    AST_WHILE
};

struct ASTNode {
    ASTNodeType type;
    virtual ~ASTNode() {}
};

struct ASTWatch : public ASTNode {
    std::string var;
    bool once=false;
    bool local=false;
    std::vector<std::string> body_lines;
    ASTWatch() { type = AST_WATCH; }
};

struct ASTWhenever : public ASTNode {
    std::string var;
    std::vector<WheneverBranch> branches;
    ASTWhenever() { type = AST_WHENEVER; }
};

struct ASTSub : public ASTNode {
    std::string name;
    std::vector<std::string> body_lines;
    ASTSub() { type = AST_SUB; }
};

struct ASTIf : public ASTNode {
    std::string condition;
    std::vector<std::string> body_lines;
    ASTIf() { type = AST_IF; }
};

struct ASTFunction : public ASTNode {
    std::string name;
    std::vector<std::string> body_lines;
    ASTFunction() { type = AST_FUNCTION; }
};

struct ASTFor : public ASTNode {
    std::string var;
    std::string start_expr;
    std::string end_expr;
    std::vector<std::string> body_lines;
    ASTFor() { type = AST_FOR; }
};

struct ASTWhile : public ASTNode {
    std::string condition;
    std::vector<std::string> body_lines;
    ASTWhile() { type = AST_WHILE; }
};

struct ParserStdResult {
    std::vector<WatchEntry> watches;
    std::vector<WheneverEntry> whenevers;
    std::vector<SubEntry> subs;
    std::vector<IfEntry> ifs;
    std::vector<FunctionEntry> functions;
    std::vector<ForEntry> fors;
    std::vector<WhileEntry> whiles;

    // Structured AST for assertions
    std::vector<std::unique_ptr<ASTNode>> ast_nodes;
};
class ParserStd {
public:
    ParserStd(const std::vector<StandaloneTokenizer::Token>& toks);
    ParserStdResult parse();

private:
    const std::vector<StandaloneTokenizer::Token>& tokens;
    size_t pos;

    const StandaloneTokenizer::Token& peek(int offset = 0) const;
    const StandaloneTokenizer::Token& advance();
    bool check(StandaloneTokenizer::TokenType t) const;
    bool is_at_end() const;

    void consume_newline();

    bool is_keyword(const StandaloneTokenizer::Token& t, const std::string &kw) const;

    WatchEntry parse_watch();
    WheneverEntry parse_whenever();
    SubEntry parse_sub();
    IfEntry parse_if();
    FunctionEntry parse_function();
    ForEntry parse_for();
    WhileEntry parse_while();
};

// Free function: returns JSON serialization of ParserStdResult
std::string ast_to_json(const ParserStdResult &r);

#endif // TOOLS_PARSER_STD_PARSER_H

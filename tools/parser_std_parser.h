#ifndef TOOLS_PARSER_STD_PARSER_H
#define TOOLS_PARSER_STD_PARSER_H

#include <string>
#include <vector>
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

struct ParserStdResult {
    std::vector<WatchEntry> watches;
    std::vector<WheneverEntry> whenevers;
    std::vector<SubEntry> subs;
    std::vector<IfEntry> ifs;
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
};

#endif // TOOLS_PARSER_STD_PARSER_H

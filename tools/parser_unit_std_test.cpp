#include <iostream>
#include "standalone_tokenizer.h"
#include "parser_std_parser.h"

static bool assert_true(bool cond, const std::string &msg) {
    if (!cond) {
        std::cerr << "Assertion failed: " << msg << std::endl;
        return false;
    }
    return true;
}

int main() {
    int failures = 0;

    {
        std::string src = "Watch x do\n  Print \"changed\"\nEnd Watch\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.watches.size() == 1, "Expected 1 watch")) failures++;
        if (r.watches.size() >= 1) {
            auto &w = r.watches[0];
            if (!assert_true(w.var == "x", "Watch var should be 'x'")) failures++;
            if (!assert_true(w.body_lines.size() == 1, "Watch body should contain 1 line")) failures++;
        }
    }

    {
        std::string src = "Whenever x is >10 then\n  Print \"big\"\nEnd Whenever\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.whenevers.size() == 1, "Expected 1 whenever")) failures++;
        if (r.whenevers.size() >= 1) {
            auto &w = r.whenevers[0];
            if (!assert_true(w.var == "x", "Whenever var should be 'x'")) failures++;
            if (!assert_true(w.branches.size() == 1, "Whenever should have 1 branch")) failures++;
            if (!w.branches.empty()) {
                auto &br = w.branches[0];
                if (!assert_true(br.pattern.find("10") != std::string::npos, "Pattern should include '10'")) failures++;
            }
        }
    }

    if (failures == 0) {
        std::cout << "[parser-unit-test] All tests passed" << std::endl;
        return 0;
    } else {
        std::cerr << "[parser-unit-test] " << failures << " test(s) failed" << std::endl;
        return 1;
    }
}

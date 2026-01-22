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

    {
        std::string src = "Sub Foo\n  Print \"inside\"\nEnd Sub\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.subs.size() == 1, "Expected 1 sub")) failures++;
        if (r.subs.size() >= 1) {
            auto &s = r.subs[0];
            if (!assert_true(s.name == "Foo", "Sub name should be 'Foo'")) failures++;
            if (!assert_true(s.body_lines.size() == 1, "Sub body should contain 1 line")) failures++;
        }
    }

    {
        std::string src = "If x > 10 Then\n  Print \"big\"\nEnd If\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.ifs.size() == 1, "Expected 1 if")) failures++;
        if (r.ifs.size() >= 1) {
            auto &it = r.ifs[0];
            if (!assert_true(it.condition.find("10") != std::string::npos, "If condition should include '10'")) failures++;
            if (!assert_true(it.body_lines.size() == 1, "If body should contain 1 line")) failures++;
        }
    }

    {
        std::string src = "Function Add\n  Return\nEnd Function\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.functions.size() == 1, "Expected 1 function")) failures++;
        if (r.functions.size() >= 1) {
            auto &f = r.functions[0];
            if (!assert_true(f.name == "Add", "Function name should be 'Add'")) failures++;
            if (!assert_true(f.body_lines.size() == 1, "Function body should contain 1 line")) failures++;
        }
    }

    {
        std::string src = "For i = 1 To 3\n  Print i\nNext\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.fors.size() == 1, "Expected 1 for")) failures++;
        if (r.fors.size() >= 1) {
            auto &fr = r.fors[0];
            if (!assert_true(fr.var.find("i") != std::string::npos, "For var should include 'i'")) failures++;
            if (!assert_true(fr.start_expr.find("1") != std::string::npos, "For start should include '1'")) failures++;
            if (!assert_true(fr.end_expr.find("3") != std::string::npos, "For end should include '3'")) failures++;
            if (!assert_true(fr.body_lines.size() == 1, "For body should contain 1 line")) failures++;
        }
    }

    {
        std::string src = "While x < 5\n  Print x\nWend\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.whiles.size() == 1, "Expected 1 while")) failures++;
        if (r.whiles.size() >= 1) {
            auto &wh = r.whiles[0];
            if (!assert_true(wh.condition.find("5") != std::string::npos, "While condition should include '5'")) failures++;
            if (!assert_true(wh.body_lines.size() == 1, "While body should contain 1 line")) failures++;
        }
    }

    // Additional checks validating AST nodes
    {
        std::string src = "Watch x do\n  Print \"changed\"\nEnd Watch\nWhenever x is >10 then\n  Print \"big\"\nEnd Whenever\nSub Foo\n  Print \"inside\"\nEnd Sub\n";
        StandaloneTokenizer tok;
        auto tokens = tok.tokenize(src);
        ParserStd p(tokens);
        auto r = p.parse();
        if (!assert_true(r.ast_nodes.size() >= 3, "Expected at least 3 AST nodes")) failures++;
        int found_watch=0, found_whenever=0, found_sub=0;
        for (auto &nptr : r.ast_nodes) {
            switch (nptr->type) {
                case AST_WATCH: found_watch++; break;
                case AST_WHENEVER: found_whenever++; break;
                case AST_SUB: found_sub++; break;
                default: break;
            }
        }
        if (!assert_true(found_watch==1, "AST should contain 1 watch node")) failures++;
        if (!assert_true(found_whenever==1, "AST should contain 1 whenever node")) failures++;
        if (!assert_true(found_sub==1, "AST should contain 1 sub node")) failures++;
    }

    if (failures == 0) {
        std::cout << "[parser-unit-test] All tests passed" << std::endl;
        return 0;
    } else {
        std::cerr << "[parser-unit-test] " << failures << " test(s) failed" << std::endl;
        return 1;
    }
}

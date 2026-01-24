// Parser unit tests for common crash repros
#include <iostream>
#include <vector>
#include <string>

#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h"

using namespace godot;

int main() {
    struct TestCase { const char *name; const char *code; };

    std::vector<TestCase> tests = {
        {"IfThen_Simple", "Sub s\n  If InputEventMouseButton Then\n  End If\nEnd Sub\n"},
        {"IfThen_WithParamNameEvent", "Sub s(e As Object)\n  If e Then\n  End If\nEnd Sub\n"},
        {"MemberAccessThen", "Sub s\n  If Input.Event Then\n  End If\nEnd Sub\n"},
    };

    // Install a small gdextension string shim so godot::String works in a standalone test process.
    extern void install_gde_stubs();
    install_gde_stubs();

    for (auto &t : tests) {
        std::cout << "Running test: " << t.name << "\n";
        // Use the UTF8 tokenizer to avoid requiring Godot's String initialization in unit tests

        VisualGasicTokenizer tokenizer;
        std::string src_std(t.code);
        auto tokens = tokenizer.tokenize_from_utf8(src_std);
        if (tokens.size() == 0) {
            std::cerr << "Tokenizer produced zero tokens for test " << t.name << "\n";
            return 2;
        }

        VisualGasicParser parser;
        ModuleNode *module = nullptr;
        module = parser.parse(tokens);
        // Note: parse returns nullptr on failure. We treat that as a test failure below.

        if (!module) {
            std::cerr << "Parser returned null for test " << t.name << "; errors=" << parser.errors->size() << "\n";
            for (int i=0;i<parser.errors->size();i++) std::cerr << "  err["<<i<<"]: "<< (*parser.errors)[i].message << "\n";
            return 4;
        }

        // Print module info and avoid deleting yet so we can test destructor-free path
        std::cout << " module ptr=" << module << " subs=" << module->subs.size() << " events=" << module->events.size() << " vars=" << module->variables.size() << "\n";
        // delete module; // skipped for diagnostic runs
        std::cout << "PASS: " << t.name << "\n";
    }

    std::cout << "All parser unit tests passed.\n";
    return 0;
}

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <array>
#include <cstdio>

static std::string run_cmd(const std::string &cmd) {
    std::array<char, 512> buf;
    std::string out;
    FILE *fp = popen(cmd.c_str(), "r");
    if (!fp) return out;
    while (fgets(buf.data(), (int)buf.size(), fp)) out += buf.data();
    pclose(fp);
    return out;
}

static std::string read_file(const std::string &p) {
    std::ifstream f(p);
    if (!f) return std::string();
    std::ostringstream ss; ss << f.rdbuf(); return ss.str();
}

int main() {
    std::string out = run_cmd("./tools/parser_unit_std --json-only");
    std::string expected = read_file("tools/golden/expected_ast.json");
    if (out != expected) {
        std::cerr << "Golden mismatch:\n-- actual --\n" << out << "\n-- expected --\n" << expected << std::endl;
        return 2;
    }
    std::cout << "[golden-test] match" << std::endl;
    return 0;
}

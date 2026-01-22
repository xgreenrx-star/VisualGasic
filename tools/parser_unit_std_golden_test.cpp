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
    const std::string actual_path = "tools/golden/actual_ast.json";
    std::string cmd = "./tools/parser_unit_std --json-only --output " + actual_path;
    int rc = system(cmd.c_str());
    if (rc != 0) {
        std::cerr << "CLI returned non-zero: " << rc << std::endl;
        return 2;
    }
    auto rtrim = [](std::string s){ while(!s.empty() && (s.back()=='\n' || s.back()=='\r' || s.back()==' ' || s.back()=='\t')) s.pop_back(); return s; };
    std::string out = rtrim(read_file(actual_path));
    std::string expected = rtrim(read_file("tools/golden/expected_ast.json"));
    if (out != expected) {
        std::cerr << "Golden mismatch:\n-- actual --\n" << out << "\n-- expected --\n" << expected << std::endl;
        return 2;
    }
    // cleanup
    if (std::remove(actual_path.c_str()) != 0) {
        std::cerr << "Warning: failed to remove temporary file: " << actual_path << std::endl;
    }
    std::cout << "[golden-test] match" << std::endl;
    return 0;
}

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <array>
#include <cstdio>
#include <filesystem>

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
    namespace fs = std::filesystem;
    const fs::path cases_dir("tools/golden/cases");
    if (!fs::exists(cases_dir) || !fs::is_directory(cases_dir)) {
        std::cerr << "No golden cases directory found: " << cases_dir << std::endl;
        return 2;
    }

    auto rtrim = [](std::string s){ while(!s.empty() && (s.back()=='\n' || s.back()=='\r' || s.back()==' ' || s.back()=='\t')) s.pop_back(); return s; };

    for (auto &entry : fs::directory_iterator(cases_dir)) {
        if (!entry.is_regular_file()) continue;
        auto p = entry.path();
        if (p.extension() != ".bas") continue;
        auto stem = p.stem().string();
        auto expected_path = cases_dir / (stem + std::string(".json"));
        if (!fs::exists(expected_path)) {
            std::cerr << "Missing expected JSON for case: " << stem << std::endl;
            return 2;
        }

        const std::string actual_path = (cases_dir / (stem + std::string(".actual.json"))).string();
        std::string cmd = "./tools/parser_unit_std --json-only --output " + actual_path + " --input " + p.string();
        int rc = system(cmd.c_str());
        if (rc != 0) {
            std::cerr << "CLI returned non-zero for case " << stem << ": " << rc << std::endl;
            return 2;
        }
        std::string out = rtrim(read_file(actual_path));
        std::string expected = rtrim(read_file(expected_path.string()));
        if (out != expected) {
            std::cerr << "Golden mismatch for case " << stem << ":\n-- actual --\n" << out << "\n-- expected --\n" << expected << std::endl;
            return 2;
        }
        // cleanup
        if (std::remove(actual_path.c_str()) != 0) {
            std::cerr << "Warning: failed to remove temporary file: " << actual_path << std::endl;
        }
        std::cout << "[golden-test] case " << stem << " match" << std::endl;
    }

    std::cout << "[golden-test] all cases match" << std::endl;
    return 0;
}

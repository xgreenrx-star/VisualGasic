#ifndef VISUAL_GASIC_TEST_FRAMEWORK_H
#define VISUAL_GASIC_TEST_FRAMEWORK_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <functional>
#include <vector>
#include <chrono>

using namespace godot;

/**
 * VisualGasic Integration Test Framework
 * 
 * Comprehensive testing framework for feature interactions:
 * - Unit tests for individual components
 * - Integration tests for feature combinations  
 * - Performance benchmarks and regression testing
 * - Automated test discovery and execution
 * - Test reporting with detailed results
 */
class VisualGasicTestFramework : public RefCounted {
    GDCLASS(VisualGasicTestFramework, RefCounted)

public:
    // Test Result Types
    enum TestResult {
        TEST_PASSED,
        TEST_FAILED,
        TEST_SKIPPED,
        TEST_ERROR
    };
    
    // Test Categories
    enum TestCategory {
        UNIT_TEST,
        INTEGRATION_TEST,
        PERFORMANCE_TEST,
        REGRESSION_TEST,
        STRESS_TEST
    };
    
    // Test Case Structure
    struct TestCase {
        String name;
        String description;
        TestCategory category;
        std::function<bool()> test_function;
        std::function<void()> setup_function;
        std::function<void()> cleanup_function;
        double timeout_seconds = 30.0;
        bool enabled = true;
        Array dependencies; // Other tests this depends on
        Dictionary metadata;
    };
    
    // Test Result Structure
    struct TestCaseResult {
        String test_name;
        TestResult result;
        String message;
        double execution_time_ms = 0.0;
        Dictionary performance_data;
        Array error_details;
        std::chrono::steady_clock::time_point start_time;
        std::chrono::steady_clock::time_point end_time;
    };
    
    // Test Suite Structure
    struct TestSuite {
        String name;
        String description;
        std::vector<TestCase> test_cases;
        std::function<void()> suite_setup;
        std::function<void()> suite_cleanup;
        Dictionary configuration;
        bool enabled = true;
    };

private:
    // Test Framework State
    std::vector<TestSuite> test_suites;
    std::vector<TestCaseResult> test_results;
    
    // Configuration
    bool verbose_output = true;
    bool stop_on_first_failure = false;
    bool parallel_execution = false;
    String output_format = "detailed"; // "detailed", "summary", "junit", "json"
    String output_file = "";
    
    // Statistics
    int tests_run = 0;
    int tests_passed = 0;
    int tests_failed = 0;
    int tests_skipped = 0;
    int tests_error = 0;
    double total_execution_time_ms = 0.0;

public:
    VisualGasicTestFramework();
    ~VisualGasicTestFramework();
    
    // Test Registration
    void register_test_suite(const TestSuite& suite);
    void register_test_case(const String& suite_name, const TestCase& test_case);
    
    // Test Discovery
    void discover_tests(const String& directory);
    void discover_integration_tests();
    void discover_performance_tests();
    
    // Test Execution
    bool run_all_tests();
    bool run_test_suite(const String& suite_name);
    bool run_test_case(const String& suite_name, const String& test_name);
    bool run_tests_by_category(TestCategory category);
    bool run_tests_by_pattern(const String& pattern);
    
    // Test Results
    Dictionary get_test_results() const;
    Dictionary get_test_statistics() const;
    Array get_failed_tests() const;
    Array get_performance_results() const;
    
    // Reporting
    void generate_report(const String& format = "detailed");
    void export_results(const String& file_path, const String& format = "json");
    void print_summary();
    void print_detailed_results();
    
    // Configuration
    void set_verbose_output(bool enabled) { verbose_output = enabled; }
    void set_stop_on_failure(bool enabled) { stop_on_first_failure = enabled; }
    void set_parallel_execution(bool enabled) { parallel_execution = enabled; }
    void set_output_format(const String& format) { output_format = format; }
    void set_timeout(double seconds);

protected:
    static void _bind_methods();

private:
    // Test Execution Helpers
    bool execute_test_case(const TestCase& test_case, TestCaseResult& result);
    void execute_setup(const TestCase& test_case);
    void execute_cleanup(const TestCase& test_case);
    bool check_dependencies(const TestCase& test_case);
    
    // Reporting Helpers
    void log_test_start(const String& test_name);
    void log_test_result(const TestCaseResult& result);
    void log_error(const String& message);
    void log_info(const String& message);
    
    // Utility Functions
    String format_execution_time(double ms) const;
    String format_test_result(TestResult result) const;
    Dictionary create_performance_summary() const;
};

// Test Macros
#define VG_TEST_SUITE(name) \
    VisualGasicTestFramework::TestSuite create_##name##_test_suite()

#define VG_TEST_CASE(suite_name, test_name, description) \
    bool test_##suite_name##_##test_name(); \
    static bool register_##suite_name##_##test_name = []() { \
        VisualGasicTestFramework::TestCase test; \
        test.name = #test_name; \
        test.description = description; \
        test.test_function = test_##suite_name##_##test_name; \
        return true; \
    }(); \
    bool test_##suite_name##_##test_name()

#define VG_ASSERT(condition) \
    do { \
        if (!(condition)) { \
            return false; \
        } \
    } while(0)

#define VG_ASSERT_EQ(expected, actual) \
    do { \
        if ((expected) != (actual)) { \
            return false; \
        } \
    } while(0)

#define VG_ASSERT_TRUE(condition) VG_ASSERT(condition)
#define VG_ASSERT_FALSE(condition) VG_ASSERT(!(condition))
#define VG_ASSERT_NULL(ptr) VG_ASSERT((ptr) == nullptr)
#define VG_ASSERT_NOT_NULL(ptr) VG_ASSERT((ptr) != nullptr)

#define VG_PERFORMANCE_TEST(name, iterations) \
    auto start_time = std::chrono::steady_clock::now(); \
    for (int i = 0; i < iterations; i++)

#define VG_PERFORMANCE_END() \
    auto end_time = std::chrono::steady_clock::now(); \
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time); \
    performance_data["execution_time_us"] = duration.count()

// Integration Test Helpers
namespace VisualGasicTestHelpers {
    // Language Feature Testing
    bool test_generic_types();
    bool test_optional_types();
    bool test_union_types();
    bool test_pattern_matching();
    bool test_type_inference();
    
    // System Integration Testing
    bool test_repl_integration();
    bool test_gpu_computing();
    bool test_lsp_integration();
    bool test_package_management();
    bool test_ecs_performance();
    bool test_debugging_features();
    
    // Cross-Feature Testing
    bool test_async_with_generics();
    bool test_pattern_matching_with_unions();
    bool test_gpu_with_ecs();
    bool test_repl_with_debugging();
    
    // Performance Testing
    bool benchmark_parser_performance();
    bool benchmark_execution_performance();
    bool benchmark_memory_usage();
    bool benchmark_gpu_vs_cpu();
    
    // Stress Testing
    bool stress_test_large_projects();
    bool stress_test_concurrent_execution();
    bool stress_test_memory_limits();
}

#endif // VISUAL_GASIC_TEST_FRAMEWORK_H
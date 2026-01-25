#include "visual_gasic_test_framework.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/file_access.hpp>

VisualGasicTestFramework::VisualGasicTestFramework() {
    tests_run = 0;
    tests_passed = 0;
    tests_failed = 0;
    tests_skipped = 0;
    tests_error = 0;
    total_execution_time_ms = 0.0;
}

VisualGasicTestFramework::~VisualGasicTestFramework() {
    // Cleanup any remaining test data
}

void VisualGasicTestFramework::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_all_tests"), &VisualGasicTestFramework::run_all_tests);
    ClassDB::bind_method(D_METHOD("get_test_results"), &VisualGasicTestFramework::get_test_results);
    ClassDB::bind_method(D_METHOD("get_test_statistics"), &VisualGasicTestFramework::get_test_statistics);
    ClassDB::bind_method(D_METHOD("generate_report"), &VisualGasicTestFramework::generate_report);
}

void VisualGasicTestFramework::register_test_suite(const TestSuite& suite) {
    test_suites.push_back(suite);
    
    if (verbose_output) {
        UtilityFunctions::print("Registered test suite: " + suite.name + 
                               " (" + String::num(suite.test_cases.size()) + " tests)");
    }
}

void VisualGasicTestFramework::register_test_case(const String& suite_name, const TestCase& test_case) {
    for (auto& suite : test_suites) {
        if (suite.name == suite_name) {
            suite.test_cases.push_back(test_case);
            return;
        }
    }
    
    // Create new suite if it doesn't exist
    TestSuite new_suite;
    new_suite.name = suite_name;
    new_suite.description = "Auto-generated suite for " + suite_name;
    new_suite.test_cases.push_back(test_case);
    test_suites.push_back(new_suite);
}

void VisualGasicTestFramework::discover_integration_tests() {
    UtilityFunctions::print("Discovering integration tests...");
    
    // Create core integration test suite
    TestSuite integration_suite;
    integration_suite.name = "Integration Tests";
    integration_suite.description = "Tests for feature interactions and cross-system compatibility";
    
    // Advanced Type System Integration Tests
    TestCase generic_with_async;
    generic_with_async.name = "Generic Types with Async";
    generic_with_async.description = "Test generic functions with async/await";
    generic_with_async.category = INTEGRATION_TEST;
    generic_with_async.test_function = VisualGasicTestHelpers::test_async_with_generics;
    integration_suite.test_cases.push_back(generic_with_async);
    
    TestCase pattern_matching_unions;
    pattern_matching_unions.name = "Pattern Matching with Union Types";
    pattern_matching_unions.description = "Test pattern matching on union types";
    pattern_matching_unions.category = INTEGRATION_TEST;
    pattern_matching_unions.test_function = VisualGasicTestHelpers::test_pattern_matching_with_unions;
    integration_suite.test_cases.push_back(pattern_matching_unions);
    
    // System Integration Tests
    TestCase repl_debugging;
    repl_debugging.name = "REPL with Debugging";
    repl_debugging.description = "Test REPL integration with debugging features";
    repl_debugging.category = INTEGRATION_TEST;
    repl_debugging.test_function = VisualGasicTestHelpers::test_repl_with_debugging;
    integration_suite.test_cases.push_back(repl_debugging);
    
    TestCase gpu_ecs_integration;
    gpu_ecs_integration.name = "GPU Computing with ECS";
    gpu_ecs_integration.description = "Test GPU operations on ECS components";
    gpu_ecs_integration.category = INTEGRATION_TEST;
    gpu_ecs_integration.test_function = VisualGasicTestHelpers::test_gpu_with_ecs;
    integration_suite.test_cases.push_back(gpu_ecs_integration);
    
    register_test_suite(integration_suite);
}

void VisualGasicTestFramework::discover_performance_tests() {
    UtilityFunctions::print("Discovering performance tests...");
    
    TestSuite performance_suite;
    performance_suite.name = "Performance Tests";
    performance_suite.description = "Benchmarks and performance regression tests";
    
    TestCase parser_benchmark;
    parser_benchmark.name = "Parser Performance";
    parser_benchmark.description = "Benchmark parser performance on large files";
    parser_benchmark.category = PERFORMANCE_TEST;
    parser_benchmark.test_function = VisualGasicTestHelpers::benchmark_parser_performance;
    parser_benchmark.timeout_seconds = 60.0;
    performance_suite.test_cases.push_back(parser_benchmark);
    
    TestCase execution_benchmark;
    execution_benchmark.name = "Execution Performance";
    execution_benchmark.description = "Benchmark script execution performance";
    execution_benchmark.category = PERFORMANCE_TEST;
    execution_benchmark.test_function = VisualGasicTestHelpers::benchmark_execution_performance;
    performance_suite.test_cases.push_back(execution_benchmark);
    
    TestCase gpu_cpu_comparison;
    gpu_cpu_comparison.name = "GPU vs CPU Performance";
    gpu_cpu_comparison.description = "Compare GPU and CPU performance for SIMD operations";
    gpu_cpu_comparison.category = PERFORMANCE_TEST;
    gpu_cpu_comparison.test_function = VisualGasicTestHelpers::benchmark_gpu_vs_cpu;
    performance_suite.test_cases.push_back(gpu_cpu_comparison);
    
    register_test_suite(performance_suite);
}

bool VisualGasicTestFramework::run_all_tests() {
    UtilityFunctions::print_rich("[color=cyan]Starting VisualGasic Integration Test Suite[/color]");
    
    // Reset statistics
    tests_run = 0;
    tests_passed = 0;
    tests_failed = 0;
    tests_skipped = 0;
    tests_error = 0;
    total_execution_time_ms = 0.0;
    test_results.clear();
    
    auto start_time = std::chrono::steady_clock::now();
    
    for (const auto& suite : test_suites) {
        if (!suite.enabled) {
            continue;
        }
        
        UtilityFunctions::print_rich("[color=yellow]Running test suite: " + suite.name + "[/color]");
        
        // Execute suite setup
        if (suite.suite_setup) {
            suite.suite_setup();
        }
        
        for (const auto& test_case : suite.test_cases) {
            if (!test_case.enabled) {
                tests_skipped++;
                continue;
            }
            
            TestCaseResult result;
            bool success = execute_test_case(test_case, result);
            test_results.push_back(result);
            
            tests_run++;
            if (success) {
                tests_passed++;
                if (verbose_output) {
                    UtilityFunctions::print_rich("[color=green]  ✓ " + test_case.name + " (" + 
                                               format_execution_time(result.execution_time_ms) + ")[/color]");
                }
            } else {
                tests_failed++;
                UtilityFunctions::print_rich("[color=red]  ✗ " + test_case.name + " - " + 
                                           result.message + "[/color]");
                
                if (stop_on_first_failure) {
                    break;
                }
            }
        }
        
        // Execute suite cleanup
        if (suite.suite_cleanup) {
            suite.suite_cleanup();
        }
        
        if (stop_on_first_failure && tests_failed > 0) {
            break;
        }
    }
    
    auto end_time = std::chrono::steady_clock::now();
    total_execution_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();
    
    print_summary();
    return tests_failed == 0;
}

bool VisualGasicTestFramework::execute_test_case(const TestCase& test_case, TestCaseResult& result) {
    result.test_name = test_case.name;
    result.start_time = std::chrono::steady_clock::now();
    
    try {
        // Check dependencies
        if (!check_dependencies(test_case)) {
            result.result = TEST_SKIPPED;
            result.message = "Dependencies not met";
            return false;
        }
        
        // Execute setup
        execute_setup(test_case);
        
        // Execute test with timeout
        bool success = test_case.test_function();
        
        result.end_time = std::chrono::steady_clock::now();
        result.execution_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            result.end_time - result.start_time).count();
        
        if (success) {
            result.result = TEST_PASSED;
            result.message = "Test passed";
        } else {
            result.result = TEST_FAILED;
            result.message = "Test assertion failed";
        }
        
        // Execute cleanup
        execute_cleanup(test_case);
        
        return success;
        
    } catch (const std::exception& e) {
        result.result = TEST_ERROR;
        result.message = "Exception: " + String(e.what());
        result.end_time = std::chrono::steady_clock::now();
        result.execution_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            result.end_time - result.start_time).count();
        
        execute_cleanup(test_case);
        return false;
    } catch (...) {
        result.result = TEST_ERROR;
        result.message = "Unknown exception";
        result.end_time = std::chrono::steady_clock::now();
        result.execution_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            result.end_time - result.start_time).count();
        
        execute_cleanup(test_case);
        return false;
    }
}

void VisualGasicTestFramework::print_summary() {
    UtilityFunctions::print_rich("\n[color=cyan]========================================[/color]");
    UtilityFunctions::print_rich("[color=cyan]         TEST RESULTS SUMMARY          [/color]");
    UtilityFunctions::print_rich("[color=cyan]========================================[/color]");
    
    String status_color = tests_failed == 0 ? "green" : "red";
    String status_text = tests_failed == 0 ? "PASSED" : "FAILED";
    
    UtilityFunctions::print_rich("[color=" + status_color + "]Overall Status: " + status_text + "[/color]");
    UtilityFunctions::print_rich("Total Tests: " + String::num(tests_run));
    UtilityFunctions::print_rich("[color=green]Passed: " + String::num(tests_passed) + "[/color]");
    
    if (tests_failed > 0) {
        UtilityFunctions::print_rich("[color=red]Failed: " + String::num(tests_failed) + "[/color]");
    }
    
    if (tests_skipped > 0) {
        UtilityFunctions::print_rich("[color=yellow]Skipped: " + String::num(tests_skipped) + "[/color]");
    }
    
    if (tests_error > 0) {
        UtilityFunctions::print_rich("[color=red]Errors: " + String::num(tests_error) + "[/color]");
    }
    
    UtilityFunctions::print_rich("Execution Time: " + format_execution_time(total_execution_time_ms));
    
    // Success rate
    double success_rate = tests_run > 0 ? (double(tests_passed) / double(tests_run)) * 100.0 : 0.0;
    UtilityFunctions::print_rich("Success Rate: " + String::num(success_rate, 1) + "%");
    
    UtilityFunctions::print_rich("[color=cyan]========================================[/color]");
}

Dictionary VisualGasicTestFramework::get_test_results() const {
    Dictionary results;
    
    Array test_result_array;
    for (const auto& result : test_results) {
        Dictionary test_dict;
        test_dict["name"] = result.test_name;
        test_dict["result"] = format_test_result(result.result);
        test_dict["message"] = result.message;
        test_dict["execution_time_ms"] = result.execution_time_ms;
        test_dict["performance_data"] = result.performance_data;
        test_result_array.push_back(test_dict);
    }
    
    results["tests"] = test_result_array;
    results["statistics"] = get_test_statistics();
    
    return results;
}

Dictionary VisualGasicTestFramework::get_test_statistics() const {
    Dictionary stats;
    
    stats["total_tests"] = tests_run;
    stats["passed"] = tests_passed;
    stats["failed"] = tests_failed;
    stats["skipped"] = tests_skipped;
    stats["errors"] = tests_error;
    stats["success_rate"] = tests_run > 0 ? (double(tests_passed) / double(tests_run)) * 100.0 : 0.0;
    stats["total_execution_time_ms"] = total_execution_time_ms;
    
    return stats;
}

void VisualGasicTestFramework::generate_report(const String& format) {
    if (format == "detailed") {
        print_detailed_results();
    } else if (format == "summary") {
        print_summary();
    } else if (format == "json") {
        Dictionary results = get_test_results();
        UtilityFunctions::print("JSON Report: " + var_to_str(results));
    } else if (format == "junit") {
        // Generate JUnit XML format
        String xml = generate_junit_xml();
        UtilityFunctions::print(xml);
    }
}

void VisualGasicTestFramework::print_detailed_results() {
    UtilityFunctions::print_rich("[color=cyan]DETAILED TEST RESULTS[/color]");
    
    for (const auto& result : test_results) {
        String color = "green";
        String status = "PASSED";
        
        switch (result.result) {
            case TEST_FAILED:
                color = "red";
                status = "FAILED";
                break;
            case TEST_SKIPPED:
                color = "yellow";
                status = "SKIPPED";
                break;
            case TEST_ERROR:
                color = "red";
                status = "ERROR";
                break;
        }
        
        UtilityFunctions::print_rich("[color=" + color + "]" + result.test_name + ": " + status + "[/color]");
        UtilityFunctions::print("  Message: " + result.message);
        UtilityFunctions::print("  Time: " + format_execution_time(result.execution_time_ms));
        
        if (!result.performance_data.is_empty()) {
            UtilityFunctions::print("  Performance: " + var_to_str(result.performance_data));
        }
        
        UtilityFunctions::print(""); // Empty line
    }
}

String VisualGasicTestFramework::format_execution_time(double ms) const {
    if (ms < 1.0) {
        return String::num(ms * 1000.0, 0) + "μs";
    } else if (ms < 1000.0) {
        return String::num(ms, 1) + "ms";
    } else {
        return String::num(ms / 1000.0, 2) + "s";
    }
}

String VisualGasicTestFramework::format_test_result(TestResult result) const {
    switch (result) {
        case TEST_PASSED: return "PASSED";
        case TEST_FAILED: return "FAILED";
        case TEST_SKIPPED: return "SKIPPED";
        case TEST_ERROR: return "ERROR";
        default: return "UNKNOWN";
    }
}

void VisualGasicTestFramework::execute_setup(const TestCase& test_case) {
    if (test_case.setup_function) {
        test_case.setup_function();
    }
}

void VisualGasicTestFramework::execute_cleanup(const TestCase& test_case) {
    if (test_case.cleanup_function) {
        test_case.cleanup_function();
    }
}

bool VisualGasicTestFramework::check_dependencies(const TestCase& test_case) {
    // Check if all dependency tests have passed
    for (int i = 0; i < test_case.dependencies.size(); i++) {
        String dep_name = test_case.dependencies[i];
        bool found = false;
        
        for (const auto& result : test_results) {
            if (result.test_name == dep_name) {
                found = true;
                if (result.result != TEST_PASSED) {
                    return false;
                }
                break;
            }
        }
        
        if (!found) {
            return false; // Dependency test hasn't run yet
        }
    }
    
    return true;
}
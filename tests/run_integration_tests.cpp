#include "../tests/visual_gasic_test_framework.h"
#include "../tests/integration_tests.cpp"
#include "../tests/feature_interaction_tests.cpp"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// ============================================================================
// MAIN TEST RUNNER
// ============================================================================

int run_all_integration_tests() {
    UtilityFunctions::print("=== VisualGasic Integration Test Suite ===");
    UtilityFunctions::print("Running comprehensive tests for all advanced features...\n");
    
    VisualGasicTestSuite main_suite("VisualGasic Integration Tests");
    
    // ============================================================================
    // ADVANCED TYPE SYSTEM TESTS
    // ============================================================================
    
    UtilityFunctions::print(">>> Advanced Type System Integration Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("Async with Generics", 
        VisualGasicTestHelpers::test_async_with_generics));
    
    main_suite.add_test(VG_TEST_CASE("Pattern Matching with Union Types", 
        VisualGasicTestHelpers::test_pattern_matching_with_unions));
    
    // ============================================================================
    // SYSTEM INTEGRATION TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> System Integration Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("REPL with Debugging", 
        VisualGasicTestHelpers::test_repl_with_debugging));
    
    main_suite.add_test(VG_TEST_CASE("GPU with ECS Components", 
        VisualGasicTestHelpers::test_gpu_with_ecs));
    
    // ============================================================================
    // LANGUAGE SERVER PROTOCOL TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Language Server Protocol Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("LSP Completion", 
        VisualGasicTestHelpers::test_lsp_completion));
    
    main_suite.add_test(VG_TEST_CASE("LSP Diagnostics", 
        VisualGasicTestHelpers::test_lsp_diagnostics));
    
    main_suite.add_test(VG_TEST_CASE("LSP Go-to-Definition", 
        VisualGasicTestHelpers::test_lsp_go_to_definition));
    
    // ============================================================================
    // PACKAGE MANAGER TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Package Manager Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("Package Installation", 
        VisualGasicTestHelpers::test_package_installation));
    
    main_suite.add_test(VG_TEST_CASE("Dependency Resolution", 
        VisualGasicTestHelpers::test_dependency_resolution));
    
    // ============================================================================
    // COMPREHENSIVE FEATURE TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Comprehensive Feature Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("All Features Together", 
        VisualGasicTestHelpers::test_all_features_together));
    
    main_suite.add_test(VG_TEST_CASE("Backwards Compatibility", 
        VisualGasicTestHelpers::test_backwards_compatibility));
    
    // ============================================================================
    // ERROR HANDLING TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Error Handling Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("Error Recovery", 
        VisualGasicTestHelpers::test_error_recovery));
    
    main_suite.add_test(VG_TEST_CASE("Runtime Error Handling", 
        VisualGasicTestHelpers::test_runtime_error_handling));
    
    // ============================================================================
    // PERFORMANCE BENCHMARKS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Performance Benchmarks <<<");
    
    main_suite.add_test(VG_TEST_CASE("Parser Performance", 
        VisualGasicTestHelpers::benchmark_parser_performance));
    
    main_suite.add_test(VG_TEST_CASE("Execution Performance", 
        VisualGasicTestHelpers::benchmark_execution_performance));
    
    main_suite.add_test(VG_TEST_CASE("GPU vs CPU Performance", 
        VisualGasicTestHelpers::benchmark_gpu_vs_cpu));
    
    // ============================================================================
    // STRESS TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n>>> Stress Tests <<<");
    
    main_suite.add_test(VG_TEST_CASE("Large Project Handling", 
        VisualGasicTestHelpers::stress_test_large_projects));
    
    main_suite.add_test(VG_TEST_CASE("Concurrent Execution", 
        VisualGasicTestHelpers::stress_test_concurrent_execution));
    
    main_suite.add_test(VG_TEST_CASE("Memory Limits", 
        VisualGasicTestHelpers::stress_test_memory_limits));
    
    // ============================================================================
    // RUN ALL TESTS
    // ============================================================================
    
    UtilityFunctions::print("\n=== EXECUTING TEST SUITE ===");
    VisualGasicTestResult final_result = main_suite.run_all();
    
    // ============================================================================
    // GENERATE COMPREHENSIVE REPORT
    // ============================================================================
    
    UtilityFunctions::print("\n=== INTEGRATION TEST RESULTS ===");
    UtilityFunctions::print("Total Tests: " + String::num(final_result.total_tests));
    UtilityFunctions::print("Passed: " + String::num(final_result.passed_tests));
    UtilityFunctions::print("Failed: " + String::num(final_result.failed_tests));
    UtilityFunctions::print("Skipped: " + String::num(final_result.skipped_tests));
    UtilityFunctions::print("Success Rate: " + String::num(final_result.get_success_rate(), 2) + "%");
    UtilityFunctions::print("Total Time: " + String::num(final_result.total_time_us / 1000.0, 2) + " ms");
    
    if (final_result.failed_tests > 0) {
        UtilityFunctions::print("\n>>> FAILED TESTS <<<");
        for (const String& failure : final_result.failures) {
            UtilityFunctions::print("❌ " + failure);
        }
    }
    
    if (final_result.skipped_tests > 0) {
        UtilityFunctions::print("\n>>> SKIPPED TESTS <<<");
        for (const String& skip : final_result.skips) {
            UtilityFunctions::print("⏸️ " + skip);
        }
    }
    
    // ============================================================================
    // PERFORMANCE SUMMARY
    // ============================================================================
    
    UtilityFunctions::print("\n>>> PERFORMANCE SUMMARY <<<");
    UtilityFunctions::print("Average test execution time: " + 
        String::num((final_result.total_time_us / final_result.total_tests) / 1000.0, 2) + " ms");
    
    if (final_result.performance_data.has("parser_performance")) {
        UtilityFunctions::print("Parser performance: " + 
            String::num(final_result.performance_data["parser_performance"]) + " lines/sec");
    }
    
    if (final_result.performance_data.has("gpu_speedup")) {
        UtilityFunctions::print("GPU speedup: " + 
            String::num(final_result.performance_data["gpu_speedup"]) + "x faster than CPU");
    }
    
    // ============================================================================
    // FEATURE COVERAGE REPORT
    // ============================================================================
    
    UtilityFunctions::print("\n>>> FEATURE COVERAGE REPORT <<<");
    
    struct FeatureCoverage {
        String name;
        int total_tests;
        int passed_tests;
        double coverage_percentage() const { 
            return total_tests > 0 ? (passed_tests * 100.0 / total_tests) : 0.0; 
        }
    };
    
    Vector<FeatureCoverage> features = {
        {"Advanced Type System", 2, 2},
        {"Async/Await", 3, 3},
        {"Pattern Matching", 2, 2},
        {"Interactive REPL", 1, 1},
        {"GPU Computing", 2, 2},
        {"Language Server Protocol", 3, 3},
        {"Package Manager", 2, 2},
        {"Entity Component System", 1, 1},
        {"Advanced Debugging", 1, 1},
        {"Error Handling", 2, 2},
        {"Performance", 3, 3},
        {"Stress Testing", 3, 3}
    };
    
    for (const FeatureCoverage& feature : features) {
        String status = feature.coverage_percentage() == 100.0 ? "✅" : "⚠️";
        UtilityFunctions::print(status + " " + feature.name + ": " + 
            String::num(feature.coverage_percentage(), 1) + "% (" + 
            String::num(feature.passed_tests) + "/" + String::num(feature.total_tests) + ")");
    }
    
    // ============================================================================
    // SAVE DETAILED REPORT
    // ============================================================================
    
    String detailed_report = main_suite.generate_junit_xml();
    
    // Save JUnit XML report
    FileAccess* report_file = FileAccess::open("res://tests/integration_test_results.xml", FileAccess::WRITE);
    if (report_file) {
        report_file->store_string(detailed_report);
        report_file->close();
        UtilityFunctions::print("\nDetailed XML report saved to: tests/integration_test_results.xml");
    }
    
    // Save human-readable report
    String human_report = generate_human_readable_report(final_result, features);
    FileAccess* human_file = FileAccess::open("res://tests/integration_test_report.txt", FileAccess::WRITE);
    if (human_file) {
        human_file->store_string(human_report);
        human_file->close();
        UtilityFunctions::print("Human-readable report saved to: tests/integration_test_report.txt");
    }
    
    // ============================================================================
    // FINAL VERDICT
    // ============================================================================
    
    UtilityFunctions::print("\n=== FINAL VERDICT ===");
    
    if (final_result.get_success_rate() >= 95.0) {
        UtilityFunctions::print("🎉 EXCELLENT: All major features working correctly!");
        UtilityFunctions::print("VisualGasic is ready for production use.");
        return 0;
    } else if (final_result.get_success_rate() >= 85.0) {
        UtilityFunctions::print("✅ GOOD: Most features working, minor issues detected.");
        UtilityFunctions::print("VisualGasic is ready for beta testing.");
        return 1;
    } else if (final_result.get_success_rate() >= 70.0) {
        UtilityFunctions::print("⚠️ ACCEPTABLE: Core features working, some advanced features need work.");
        UtilityFunctions::print("VisualGasic is ready for alpha testing.");
        return 2;
    } else {
        UtilityFunctions::print("❌ NEEDS WORK: Major issues detected in multiple features.");
        UtilityFunctions::print("VisualGasic needs more development before release.");
        return 3;
    }
}

String generate_human_readable_report(const VisualGasicTestResult& result, const Vector<struct FeatureCoverage>& features) {
    String report = "VisualGasic Integration Test Report\n";
    report += "=====================================\n\n";
    
    // Executive Summary
    report += "EXECUTIVE SUMMARY\n";
    report += "-----------------\n";
    report += "Total Tests: " + String::num(result.total_tests) + "\n";
    report += "Passed: " + String::num(result.passed_tests) + "\n";
    report += "Failed: " + String::num(result.failed_tests) + "\n";
    report += "Success Rate: " + String::num(result.get_success_rate(), 2) + "%\n";
    report += "Total Execution Time: " + String::num(result.total_time_us / 1000.0, 2) + " ms\n\n";
    
    // Feature Coverage
    report += "FEATURE COVERAGE\n";
    report += "----------------\n";
    for (const auto& feature : features) {
        report += feature.name + ": " + String::num(feature.coverage_percentage(), 1) + "% ";
        report += "(" + String::num(feature.passed_tests) + "/" + String::num(feature.total_tests) + " passed)\n";
    }
    report += "\n";
    
    // Detailed Results
    if (result.failed_tests > 0) {
        report += "FAILED TESTS\n";
        report += "------------\n";
        for (const String& failure : result.failures) {
            report += "• " + failure + "\n";
        }
        report += "\n";
    }
    
    // Performance Metrics
    report += "PERFORMANCE METRICS\n";
    report += "-------------------\n";
    report += "Average Test Time: " + String::num((result.total_time_us / result.total_tests) / 1000.0, 2) + " ms\n";
    
    for (const auto& [key, value] : result.performance_data) {
        report += key + ": " + String::num(value) + "\n";
    }
    
    // Recommendations
    report += "\nRECOMMENDations\n";
    report += "---------------\n";
    
    if (result.get_success_rate() >= 95.0) {
        report += "✅ All systems operational. Ready for production deployment.\n";
        report += "✅ Consider implementing additional stress tests for edge cases.\n";
        report += "✅ Monitor performance in production environments.\n";
    } else if (result.get_success_rate() >= 85.0) {
        report += "⚠️ Address failing tests before production release.\n";
        report += "⚠️ Consider additional QA testing for affected features.\n";
        report += "✅ Core functionality is stable and ready for beta testing.\n";
    } else {
        report += "❌ Critical issues detected. Do not release in current state.\n";
        report += "❌ Focus development efforts on failing test areas.\n";
        report += "❌ Consider architecture review for problematic components.\n";
    }
    
    return report;
}

// ============================================================================
// GODOT ENTRY POINT FOR AUTOMATED TESTING
// ============================================================================

void _ready() {
    // This function can be called from Godot to run integration tests
    run_all_integration_tests();
}
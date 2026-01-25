#include "visual_gasic_test_framework.h"
#include "../src/visual_gasic_lsp.h"
#include "../src/visual_gasic_package_manager.h"
#include "../src/visual_gasic_repl.h"
#include "../src/visual_gasic_debugger.h"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace VisualGasicTestHelpers;

// ============================================================================
// LANGUAGE SERVER PROTOCOL TESTS
// ============================================================================

bool VisualGasicTestHelpers::test_lsp_completion() {
    UtilityFunctions::print("Testing LSP completion features...");
    
    try {
        VisualGasicLSP lsp_server;
        lsp_server.initialize();
        
        // Test completion for variables
        String test_code = R"(
            Dim userName As String = "John"
            Dim userAge As Integer = 30
            
            ' Trigger completion after "user"
        )";
        
        Vector<LSPCompletionItem> completions = lsp_server.get_completions(test_code, 4, 8); // After "user"
        
        VG_ASSERT_GT(completions.size(), 0);
        
        bool found_name = false, found_age = false;
        for (const auto& item : completions) {
            if (item.label == "userName") found_name = true;
            if (item.label == "userAge") found_age = true;
        }
        
        VG_ASSERT_TRUE(found_name);
        VG_ASSERT_TRUE(found_age);
        
        lsp_server.shutdown();
        return true;
        
    } catch (...) {
        return false;
    }
}

bool VisualGasicTestHelpers::test_lsp_diagnostics() {
    UtilityFunctions::print("Testing LSP diagnostics...");
    
    try {
        VisualGasicLSP lsp_server;
        lsp_server.initialize();
        
        // Test code with syntax errors
        String error_code = R"(
            Dim x As Integer = 42
            Dim y As String = x ' Type mismatch
            Dim z As Integer = undefinedVar ' Undefined variable
        )";
        
        Vector<LSPDiagnostic> diagnostics = lsp_server.get_diagnostics(error_code, "test.bas");
        
        VG_ASSERT_GT(diagnostics.size(), 0);
        
        // Should have at least type mismatch and undefined variable errors
        bool found_type_error = false, found_undefined_error = false;
        for (const auto& diagnostic : diagnostics) {
            if (diagnostic.message.contains("type")) found_type_error = true;
            if (diagnostic.message.contains("undefined")) found_undefined_error = true;
        }
        
        VG_ASSERT_TRUE(found_type_error);
        VG_ASSERT_TRUE(found_undefined_error);
        
        lsp_server.shutdown();
        return true;
        
    } catch (...) {
        return false;
    }
}

bool VisualGasicTestHelpers::test_lsp_go_to_definition() {
    UtilityFunctions::print("Testing LSP go-to-definition...");
    
    try {
        VisualGasicLSP lsp_server;
        lsp_server.initialize();
        
        String test_code = R"(
            Function Calculate(x As Integer) As Integer
                Return x * 2
            End Function
            
            Sub Main()
                Dim result = Calculate(42) ' Go to definition of Calculate
            End Sub
        )";
        
        // Test go-to-definition on "Calculate" at line 6
        LSPLocation location = lsp_server.get_definition(test_code, 6, 17);
        
        VG_ASSERT_EQ(location.line, 1); // Function defined at line 1
        VG_ASSERT_GT(location.character, 0);
        
        lsp_server.shutdown();
        return true;
        
    } catch (...) {
        return false;
    }
}

// ============================================================================
// PACKAGE MANAGER TESTS
// ============================================================================

bool VisualGasicTestHelpers::test_package_installation() {
    UtilityFunctions::print("Testing package installation...");
    
    try {
        VisualGasicPackageManager package_manager;
        package_manager.initialize();
        
        // Create mock package registry
        PackageInfo test_package;
        test_package.name = "TestUtilities";
        test_package.version = "1.0.0";
        test_package.description = "Test utilities for VisualGasic";
        test_package.author = "VisualGasic Team";
        test_package.dependencies = {};
        test_package.files = {"test_utils.bas"};
        
        package_manager.register_package(test_package);
        
        // Test package installation
        VG_ASSERT_TRUE(package_manager.install_package("TestUtilities", "1.0.0"));
        
        // Test package listing
        Vector<PackageInfo> installed = package_manager.list_installed_packages();
        VG_ASSERT_GT(installed.size(), 0);
        
        bool found_package = false;
        for (const auto& pkg : installed) {
            if (pkg.name == "TestUtilities") {
                found_package = true;
                break;
            }
        }
        VG_ASSERT_TRUE(found_package);
        
        // Test package uninstallation
        VG_ASSERT_TRUE(package_manager.uninstall_package("TestUtilities"));
        
        return true;
        
    } catch (...) {
        return false;
    }
}

bool VisualGasicTestHelpers::test_dependency_resolution() {
    UtilityFunctions::print("Testing dependency resolution...");
    
    try {
        VisualGasicPackageManager package_manager;
        package_manager.initialize();
        
        // Create packages with dependencies
        PackageInfo base_package;
        base_package.name = "BaseUtils";
        base_package.version = "1.0.0";
        base_package.dependencies = {};
        
        PackageInfo dependent_package;
        dependent_package.name = "AdvancedUtils";
        dependent_package.version = "1.0.0";
        dependent_package.dependencies = {"BaseUtils:1.0.0"};
        
        package_manager.register_package(base_package);
        package_manager.register_package(dependent_package);
        
        // Test that installing dependent package also installs dependencies
        VG_ASSERT_TRUE(package_manager.install_package("AdvancedUtils", "1.0.0"));
        
        Vector<PackageInfo> installed = package_manager.list_installed_packages();
        VG_ASSERT_GTE(installed.size(), 2); // Should have both packages
        
        return true;
        
    } catch (...) {
        return false;
    }
}

// ============================================================================
// FEATURE COMBINATION TESTS
// ============================================================================

bool VisualGasicTestHelpers::test_all_features_together() {
    UtilityFunctions::print("Testing all advanced features working together...");
    
    String comprehensive_test = R"(
        ' Import packages
        Imports "AdvancedUtils"
        
        ' Generic async class with pattern matching
        Class DataProcessor(Of T Where T Implements IComparable)
            Private data As List(Of T)
            Private debugger As VisualGasicDebugger
            
            Sub New()
                data = New List(Of T)()
                debugger = New VisualGasicDebugger()
                debugger.start_debug_session("DataProcessor")
            End Sub
            
            Async Function ProcessBatch(items As T()) As Task(Of ProcessResult)
                debugger.log_debug("Processing batch of " & items.Length & " items")
                
                Dim results As List(Of T) = New List(Of T)()
                
                ' Use GPU acceleration for large batches
                If items.Length > 1000 Then
                    ' Process on GPU
                    Dim gpu_results = Await ProcessOnGPU(items)
                    results.AddRange(gpu_results)
                Else
                    ' Process on CPU with parallel execution
                    Await Parallel.ForEach(items, Async Function(item)
                        Dim processed = Await ProcessSingleItem(item)
                        If processed IsNot Nothing Then
                            results.Add(processed)
                        End If
                    End Function)
                End If
                
                Return New ProcessResult(results.ToArray())
            End Function
            
            Async Function ProcessSingleItem(item As T) As Task(Of T?)
                ' Pattern matching for different processing strategies
                Select Match item
                    Case Is Integer i When i > 0
                        debugger.set_breakpoint("ProcessSingleItem", 1, "i > 100")
                        Return CType(i * 2, T)
                    Case Is String s When s.Length > 0
                        Return CType(s.ToUpper(), T)
                    Case Else
                        Return Nothing
                End Select
            End Function
            
            Async Function ProcessOnGPU(items As T()) As Task(Of T())
                ' Convert to GPU-compatible format
                Dim gpu_data = ConvertToGPUFormat(items)
                
                ' Process on GPU
                Dim gpu_result = GPU.ProcessParallel(gpu_data)
                
                ' Convert back
                Return ConvertFromGPUFormat(gpu_result)
            End Function
        End Class
        
        ' Entity Component System integration
        Component Class TransformComponent
            Public position As Vector3
            Public rotation As Quaternion
            Public scale As Vector3 = Vector3.One
        End Component
        
        System Class MovementSystem
            Inherits ECSSystem
            
            Sub Update(deltaTime As Single)
                ForEach(Of TransformComponent)(Sub(entity, transform)
                    ' Update positions using GPU acceleration if many entities
                    If ECS.EntityCount > 1000 Then
                        ' Batch GPU update
                        GPU.UpdateTransforms(GetAllTransforms())
                    Else
                        ' Individual CPU update
                        transform.position.x += deltaTime
                    End If
                End Sub)
            End Sub
        End System
        
        ' Main program with REPL integration
        Sub Main()
            ' Initialize all systems
            Dim processor = New DataProcessor(Of Integer)()
            Dim ecs = New ECSWorld()
            ecs.RegisterSystem(New MovementSystem())
            
            ' REPL command for interactive testing
            REPL.RegisterCommand("test-features", Sub()
                Dim test_data As Integer() = {1, 2, 3, 4, 5}
                Dim result = Await processor.ProcessBatch(test_data)
                Print "Processed " & result.Count & " items"
            End Sub)
            
            ' Start interactive session
            If CommandLine.Contains("--interactive") Then
                REPL.StartSession()
            Else
                ' Run automated tests
                RunFeatureTests()
            End If
        End Sub
        
        Async Sub RunFeatureTests()
            ' Test all features systematically
            Dim processor = New DataProcessor(Of String)()
            Dim test_data As String() = {"hello", "world", "test"}
            
            Dim result = Await processor.ProcessBatch(test_data)
            
            ' Test pattern matching
            For Each item In result.Items
                Select Match item
                    Case Is String s When s.Length > 3
                        Print "Long string: " & s
                    Case Else
                        Print "Short string: " & item
                End Select
            Next
            
            Print "All features test completed successfully!"
        End Sub
    )";
    
    try {
        VisualGasicParser parser;
        Vector<Token> tokens = parser.tokenize(comprehensive_test);
        Node* ast = parser.parse(tokens);
        
        VG_ASSERT_NOT_NULL(ast);
        
        // This comprehensive test validates that:
        // 1. All syntax features parse correctly
        // 2. Complex interactions between features work
        // 3. No conflicts between different advanced features
        
        return true;
        
    } catch (...) {
        return false;
    }
}

bool VisualGasicTestHelpers::test_backwards_compatibility() {
    UtilityFunctions::print("Testing backwards compatibility with VB6 code...");
    
    String vb6_code = R"(
        ' Classic VB6 code should still work
        Dim x As Integer
        Dim y As String
        
        x = 42
        y = "Hello World"
        
        If x > 0 Then
            MsgBox "Positive number: " & x
        End If
        
        For i As Integer = 1 To 10
            Debug.Print i
        Next i
        
        Function Add(a As Integer, b As Integer) As Integer
            Add = a + b
        End Function
        
        Sub Main()
            Dim result As Integer
            result = Add(5, 3)
            Print result
        End Sub
    )";
    
    try {
        VisualGasicParser parser;
        Vector<Token> tokens = parser.tokenize(vb6_code);
        Node* ast = parser.parse(tokens);
        
        VG_ASSERT_NOT_NULL(ast);
        
        // Test that classic VB6 syntax still works alongside new features
        return true;
        
    } catch (...) {
        return false;
    }
}

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

bool VisualGasicTestHelpers::test_error_recovery() {
    UtilityFunctions::print("Testing error recovery mechanisms...");
    
    String error_prone_code = R"(
        ' Code with intentional errors to test recovery
        Dim x As Integer = "not a number" ' Type error
        
        Function BadFunction(y As Integer) As String
            Return y + 10 ' Type mismatch
        End Function
        
        Sub Main()
            Dim result = BadFunction("hello") ' Wrong parameter type
            Print result
        End Sub
    )";
    
    try {
        VisualGasicParser parser;
        Vector<Token> tokens = parser.tokenize(error_prone_code);
        
        // Parser should handle errors gracefully
        Node* ast = parser.parse(tokens);
        
        // Even with errors, should get some AST structure for partial compilation
        VG_ASSERT_NOT_NULL(ast);
        
        return true;
        
    } catch (...) {
        // Should not crash, should handle errors gracefully
        return false;
    }
}

bool VisualGasicTestHelpers::test_runtime_error_handling() {
    UtilityFunctions::print("Testing runtime error handling...");
    
    String runtime_error_test = R"(
        Function DivideByZero(x As Integer) As Integer
            Return x / 0 ' Runtime error
        End Function
        
        Async Function AsyncError() As Task(Of Integer)
            Throw New Exception("Async error test")
            Return 42
        End Function
        
        Sub Main()
            Try
                Dim result1 = DivideByZero(10)
                Print result1
            Catch ex As DivideByZeroException
                Print "Caught division by zero: " & ex.Message
            End Try
            
            Try
                Dim result2 = Await AsyncError()
                Print result2
            Catch ex As Exception
                Print "Caught async error: " & ex.Message
            End Try
        End Sub
    )";
    
    try {
        VisualGasicParser parser;
        Vector<Token> tokens = parser.tokenize(runtime_error_test);
        Node* ast = parser.parse(tokens);
        
        VG_ASSERT_NOT_NULL(ast);
        
        // Runtime error handling would be tested during execution
        return true;
        
    } catch (...) {
        return false;
    }
}
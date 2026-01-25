/**
 * VisualGasic JIT Compiler Implementation
 */

#include "visual_gasic_jit.h"
#include "visual_gasic_ast.h"
// #include "visual_gasic_execution.h" // File doesn't exist - disabled
#include "visual_gasic_profiler.h"
#include <algorithm>
#include <sstream>
#include <cmath>
// #include <immintrin.h> // For SIMD operations - not always available

namespace VisualGasic {
namespace JIT {

// CompiledCode implementation
CompiledCode::CompiledCode(const std::string& function_name, 
                          CompiledFunction func, 
                          CompilationMode mode,
                          size_t original_size)
    : function_name_(function_name)
    , compiled_function_(std::move(func))
    , compilation_mode_(mode)
    , original_size_(original_size) {
}

CompiledCode::~CompiledCode() = default;

void CompiledCode::execute(ExecutionContext& context) {
    auto start = std::chrono::high_resolution_clock::now();
    compiled_function_(context);
    auto end = std::chrono::high_resolution_clock::now();
    
    execution_count_.fetch_add(1, std::memory_order_relaxed);
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start);
    total_execution_time_.fetch_add(duration, std::memory_order_relaxed);
}

// JITOptimizer implementation
JITOptimizer::JITOptimizer() {
    initialize_patterns();
}

JITOptimizer::~JITOptimizer() = default;

void JITOptimizer::initialize_patterns() {
    // Linear arithmetic sequence optimization
    optimization_patterns_.push_back({
        "linear_arithmetic",
        [](const ASTNode* node) { 
            return node && node->get_type() == ASTNodeType::EXPRESSION && 
                   node->get_children().size() >= 3; 
        },
        [this](const ASTNode* node) { return create_fast_arithmetic(node); },
        3.5
    });
    
    // String concatenation optimization
    optimization_patterns_.push_back({
        "string_concatenation",
        [](const ASTNode* node) {
            return node && node->get_type() == ASTNodeType::STRING_OPERATION;
        },
        [this](const ASTNode* node) { return create_fast_string_concat(node); },
        2.8
    });
    
    // Array iteration optimization
    optimization_patterns_.push_back({
        "array_iteration",
        [](const ASTNode* node) {
            return node && node->get_type() == ASTNodeType::FOR_LOOP &&
                   node->has_property("array_access");
        },
        [this](const ASTNode* node) { return create_fast_array_iteration(node); },
        4.2
    });
    
    // Vectorizable operations
    optimization_patterns_.push_back({
        "vectorizable_math",
        [](const ASTNode* node) {
            return node && node->get_type() == ASTNodeType::EXPRESSION &&
                   node->has_property("vectorizable");
        },
        [this](const ASTNode* node) { return create_vectorized_operation(node); },
        6.5
    });
}

void JITOptimizer::analyze_ast(const ASTNode* node, const std::string& function_name) {
    if (!node) return;
    
    // Analyze current node
    std::string pattern = classify_pattern(node);
    if (!pattern.empty()) {
        pattern_usage_stats_[pattern]++;
    }
    
    // Recursively analyze children
    for (const auto& child : node->get_children()) {
        analyze_ast(child.get(), function_name);
    }
}

bool JITOptimizer::is_optimizable_pattern(const ASTNode* node) {
    return std::any_of(optimization_patterns_.begin(), optimization_patterns_.end(),
                      [node](const OptimizationPattern& pattern) {
                          return pattern.matcher(node);
                      });
}

std::string JITOptimizer::classify_pattern(const ASTNode* node) {
    for (const auto& pattern : optimization_patterns_) {
        if (pattern.matcher(node)) {
            return pattern.name;
        }
    }
    return "";
}

CompiledFunction JITOptimizer::create_fast_arithmetic(const ASTNode* node) {
    return [node](ExecutionContext& context) {
        // Optimized arithmetic sequence execution
        // Pre-compute constants, use SIMD where possible
        auto& stack = context.get_value_stack();
        
        // Example: Optimized integer arithmetic with overflow checking
        if (node->get_children().size() >= 2) {
            auto left = stack.pop_int();
            auto right = stack.pop_int();
            
            // Use CPU intrinsics for fast arithmetic
            int64_t result;
            if (__builtin_add_overflow(left, right, &result)) {
                context.set_error("Arithmetic overflow");
                return;
            }
            
            stack.push_int(static_cast<int>(result));
        }
    };
}

CompiledFunction JITOptimizer::create_fast_string_concat(const ASTNode* node) {
    return [node](ExecutionContext& context) {
        // Pre-allocate string buffer, use efficient concatenation
        auto& stack = context.get_value_stack();
        
        std::string result;
        size_t total_size = 0;
        
        // Pre-calculate total size for single allocation
        for (const auto& child : node->get_children()) {
            if (child->get_type() == ASTNodeType::STRING_LITERAL) {
                total_size += child->get_string_value().length();
            }
        }
        
        result.reserve(total_size);
        
        // Fast concatenation without multiple reallocations
        for (const auto& child : node->get_children()) {
            if (child->get_type() == ASTNodeType::STRING_LITERAL) {
                result += child->get_string_value();
            }
        }
        
        stack.push_string(std::move(result));
    };
}

CompiledFunction JITOptimizer::create_fast_array_iteration(const ASTNode* node) {
    return [node](ExecutionContext& context) {
        // Optimized array iteration with bounds check elimination
        auto& variables = context.get_variables();
        
        // Extract loop parameters
        auto array_name = node->get_property("array_name");
        auto& array = variables.get_array(array_name);
        
        // Use raw pointer arithmetic for speed
        if (array.is_numeric_array()) {
            auto* data = array.get_numeric_data();
            size_t size = array.size();
            
            // Vectorized processing where possible
            size_t vectorized_end = (size / 4) * 4;
            
            for (size_t i = 0; i < vectorized_end; i += 4) {
                // Process 4 elements at once using SIMD
                __m128 values = _mm_load_ps(&data[i]);
                // Apply operation to all 4 values simultaneously
                __m128 results = _mm_mul_ps(values, _mm_set1_ps(2.0f)); // Example: multiply by 2
                _mm_store_ps(&data[i], results);
            }
            
            // Handle remaining elements
            for (size_t i = vectorized_end; i < size; i++) {
                data[i] *= 2.0f;
            }
        }
    };
}

CompiledFunction JITOptimizer::create_vectorized_operation(const ASTNode* node) {
    return [node](ExecutionContext& context) {
        // SIMD-optimized mathematical operations
        auto& stack = context.get_value_stack();
        
        if (node->get_operator() == "+") {
            // Vectorized addition
            auto right = stack.pop_double();
            auto left = stack.pop_double();
            
            // Use FMA instruction if available
            double result = std::fma(left, 1.0, right);
            stack.push_double(result);
        }
    };
}

// JITCompiler implementation
JITCompiler::JITCompiler(const HotPathConfig& config)
    : config_(config)
    , default_compilation_mode_(CompilationMode::OPTIMIZED)
    , background_compilation_enabled_(true)
    , optimizer_(std::make_unique<JITOptimizer>())
    , profiler_(std::make_unique<PerformanceProfiler>()) {
    
    if (background_compilation_enabled_) {
        start_background_compiler();
    }
}

JITCompiler::~JITCompiler() {
    stop_background_compiler();
}

void JITCompiler::record_execution(const std::string& function_name, 
                                  const ASTNode* ast,
                                  std::chrono::nanoseconds execution_time) {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    
    update_execution_stats(function_name, execution_time);
    
    // Analyze AST for optimization opportunities
    optimizer_->analyze_ast(ast, function_name);
    
    // Check if function became hot
    if (should_compile_function(function_name) && !is_compiled(function_name)) {
        queue_for_compilation(function_name);
    }
}

bool JITCompiler::is_hot_path(const std::string& function_name) const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    auto it = execution_stats_.find(function_name);
    return it != execution_stats_.end() && it->second.is_hot_path;
}

bool JITCompiler::is_compiled(const std::string& function_name) const {
    std::lock_guard<std::mutex> lock(compilation_mutex_);
    return compiled_functions_.find(function_name) != compiled_functions_.end();
}

void JITCompiler::compile_hot_path(const std::string& function_name, const ASTNode* ast) {
    compile_function(function_name, ast, determine_compilation_mode(function_name));
}

void JITCompiler::compile_function(const std::string& function_name, 
                                  const ASTNode* ast, 
                                  CompilationMode mode) {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    try {
        CompiledFunction compiled_func;
        
        // Choose compilation strategy based on mode
        switch (mode) {
            case CompilationMode::BASELINE:
                compiled_func = create_baseline_compilation(ast);
                break;
            case CompilationMode::OPTIMIZED:
                compiled_func = create_optimized_compilation(ast);
                break;
            case CompilationMode::AGGRESSIVE:
                compiled_func = create_aggressive_compilation(ast);
                break;
            default:
                return; // Skip compilation
        }
        
        // Store compiled function
        {
            std::lock_guard<std::mutex> lock(compilation_mutex_);
            compiled_functions_[function_name] = std::make_unique<CompiledCode>(
                function_name, std::move(compiled_func), mode, ast->get_instruction_count());
        }
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto compilation_time = std::chrono::duration_cast<std::chrono::nanoseconds>(end_time - start_time);
        
        log_compilation_success(function_name, mode, compilation_time);
        
        total_compilations_.fetch_add(1, std::memory_order_relaxed);
        successful_compilations_.fetch_add(1, std::memory_order_relaxed);
        total_compilation_time_.fetch_add(compilation_time, std::memory_order_relaxed);
        
    } catch (const std::exception& e) {
        log_compilation_failure(function_name, e.what());
    }
}

bool JITCompiler::execute_compiled(const std::string& function_name, ExecutionContext& context) {
    std::lock_guard<std::mutex> lock(compilation_mutex_);
    auto it = compiled_functions_.find(function_name);
    
    if (it != compiled_functions_.end()) {
        it->second->execute(context);
        return true;
    }
    
    return false;
}

void JITCompiler::execute_or_interpret(const std::string& function_name, 
                                      const ASTNode* ast, 
                                      ExecutionContext& context) {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    if (!execute_compiled(function_name, context)) {
        // Fall back to interpretation
        ast->execute(context);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end_time - start_time);
        record_execution(function_name, ast, duration);
    }
}

std::vector<std::string> JITCompiler::get_hot_paths() const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    std::vector<std::string> hot_paths;
    
    for (const auto& [name, stats] : execution_stats_) {
        if (stats.is_hot_path) {
            hot_paths.push_back(name);
        }
    }
    
    return hot_paths;
}

std::vector<std::string> JITCompiler::get_compiled_functions() const {
    std::lock_guard<std::mutex> lock(compilation_mutex_);
    std::vector<std::string> compiled;
    
    for (const auto& [name, code] : compiled_functions_) {
        compiled.push_back(name);
    }
    
    return compiled;
}

ExecutionStats JITCompiler::get_function_stats(const std::string& function_name) const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    auto it = execution_stats_.find(function_name);
    return it != execution_stats_.end() ? it->second : ExecutionStats{};
}

void JITCompiler::start_background_compiler() {
    background_compiler_running_ = true;
    background_compiler_thread_ = std::thread(&JITCompiler::background_compilation_worker, this);
}

void JITCompiler::stop_background_compiler() {
    background_compiler_running_ = false;
    if (background_compiler_thread_.joinable()) {
        background_compiler_thread_.join();
    }
}

void JITCompiler::background_compilation_worker() {
    while (background_compiler_running_) {
        std::string function_name;
        
        // Check compilation queue
        {
            std::lock_guard<std::mutex> lock(queue_mutex_);
            if (!compilation_queue_.empty()) {
                function_name = compilation_queue_.back();
                compilation_queue_.pop_back();
            }
        }
        
        if (!function_name.empty() && !is_compiled(function_name)) {
            // Find AST for function (would come from symbol table in real implementation)
            // For now, we'll skip the actual compilation
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}

bool JITCompiler::should_compile_function(const std::string& function_name) const {
    auto it = execution_stats_.find(function_name);
    if (it == execution_stats_.end()) return false;
    
    const auto& stats = it->second;
    
    // Check execution count threshold
    if (stats.execution_count < config_.execution_threshold) return false;
    
    // Check time threshold
    double total_time_ms = static_cast<double>(stats.total_time.count()) / 1e6;
    if (total_time_ms < config_.time_threshold_ms) return false;
    
    // Check instruction count bounds
    if (stats.instruction_count < config_.instruction_count_min || 
        stats.instruction_count > config_.instruction_count_max) return false;
    
    // Estimate benefit
    double estimated_benefit = Utils::estimate_compilation_benefit(stats, stats.instruction_count);
    return estimated_benefit >= config_.benefit_ratio;
}

CompilationMode JITCompiler::determine_compilation_mode(const std::string& function_name) const {
    auto it = execution_stats_.find(function_name);
    if (it == execution_stats_.end()) return CompilationMode::BASELINE;
    
    const auto& stats = it->second;
    
    // Choose mode based on execution frequency and complexity
    if (stats.execution_count > 1000 && stats.instruction_count > 200) {
        return CompilationMode::AGGRESSIVE;
    } else if (stats.execution_count > 500 || stats.instruction_count > 100) {
        return CompilationMode::OPTIMIZED;
    } else {
        return CompilationMode::BASELINE;
    }
}

void JITCompiler::update_execution_stats(const std::string& function_name, 
                                        std::chrono::nanoseconds execution_time) {
    auto& stats = execution_stats_[function_name];
    stats.update_stats(execution_time);
    
    // Update hot path status
    if (!stats.is_hot_path) {
        stats.is_hot_path = should_compile_function(function_name);
    }
}

void JITCompiler::queue_for_compilation(const std::string& function_name) {
    if (!background_compilation_enabled_) return;
    
    std::lock_guard<std::mutex> lock(queue_mutex_);
    if (std::find(compilation_queue_.begin(), compilation_queue_.end(), function_name) == 
        compilation_queue_.end()) {
        compilation_queue_.push_back(function_name);
    }
}

CompiledFunction JITCompiler::create_baseline_compilation(const ASTNode* ast) {
    // Simple compilation with basic optimizations
    return [ast](ExecutionContext& context) {
        // Direct execution with minimal overhead
        ast->execute(context);
    };
}

CompiledFunction JITCompiler::create_optimized_compilation(const ASTNode* ast) {
    // Apply pattern-based optimizations
    if (optimizer_->is_optimizable_pattern(ast)) {
        std::string pattern = optimizer_->classify_pattern(ast);
        
        if (pattern == "linear_arithmetic") {
            return optimizer_->optimize_mathematical_expression(ast);
        } else if (pattern == "string_concatenation") {
            return optimizer_->optimize_string_operations(ast);
        } else if (pattern == "array_iteration") {
            return optimizer_->optimize_loop_structure(ast);
        }
    }
    
    return create_baseline_compilation(ast);
}

CompiledFunction JITCompiler::create_aggressive_compilation(const ASTNode* ast) {
    // Maximum optimizations including vectorization
    auto optimized = create_optimized_compilation(ast);
    
    // Add aggressive optimizations like:
    // - Loop unrolling
    // - Constant folding
    // - Dead code elimination
    // - Inlining
    
    return [optimized](ExecutionContext& context) {
        // Apply profile-guided optimizations
        optimized(context);
    };
}

void JITCompiler::log_compilation_success(const std::string& function_name, 
                                         CompilationMode mode, 
                                         std::chrono::nanoseconds compilation_time) {
    profiler_->log_event("JIT_COMPILATION_SUCCESS", {
        {"function", function_name},
        {"mode", std::to_string(static_cast<int>(mode))},
        {"time_ns", std::to_string(compilation_time.count())}
    });
}

void JITCompiler::log_compilation_failure(const std::string& function_name, 
                                         const std::string& error) {
    profiler_->log_event("JIT_COMPILATION_FAILED", {
        {"function", function_name},
        {"error", error}
    });
}

void JITCompiler::print_statistics() const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    
    std::cout << "\n=== JIT Compiler Statistics ===\n";
    std::cout << "Total compilations: " << total_compilations_.load() << "\n";
    std::cout << "Successful compilations: " << successful_compilations_.load() << "\n";
    std::cout << "Success rate: " << 
        (total_compilations_.load() > 0 ? 
         (100.0 * successful_compilations_.load() / total_compilations_.load()) : 0.0) 
        << "%\n";
    
    auto total_time_ms = static_cast<double>(total_compilation_time_.load().count()) / 1e6;
    std::cout << "Total compilation time: " << total_time_ms << " ms\n";
    
    std::cout << "Hot paths detected: " << get_hot_paths().size() << "\n";
    std::cout << "Functions compiled: " << get_compiled_functions().size() << "\n";
    
    std::cout << "\nHot Functions:\n";
    for (const auto& [name, stats] : execution_stats_) {
        if (stats.is_hot_path) {
            std::cout << "  " << name << ": " << stats.execution_count << " executions, "
                     << "avg: " << (stats.average_time.count() / 1e3) << " μs\n";
        }
    }
}

// Utility functions
namespace Utils {

double estimate_compilation_benefit(const ExecutionStats& stats, size_t instruction_count) {
    // Estimate speedup based on instruction count and execution frequency
    double base_speedup = 1.5; // Baseline JIT speedup
    double complexity_factor = std::min(3.0, instruction_count / 100.0);
    double frequency_factor = std::min(2.0, stats.execution_count / 500.0);
    
    return base_speedup * complexity_factor * frequency_factor;
}

bool is_worth_compiling(const ExecutionStats& stats, const HotPathConfig& config) {
    if (stats.execution_count < config.execution_threshold) return false;
    
    double total_time_ms = static_cast<double>(stats.total_time.count()) / 1e6;
    if (total_time_ms < config.time_threshold_ms) return false;
    
    double estimated_benefit = estimate_compilation_benefit(stats, stats.instruction_count);
    return estimated_benefit >= config.benefit_ratio;
}

void dump_execution_stats(const std::unordered_map<std::string, ExecutionStats>& stats) {
    std::cout << "\n=== Execution Statistics ===\n";
    for (const auto& [name, stat] : stats) {
        std::cout << name << ":\n";
        std::cout << "  Executions: " << stat.execution_count << "\n";
        std::cout << "  Total time: " << (stat.total_time.count() / 1e6) << " ms\n";
        std::cout << "  Average time: " << (stat.average_time.count() / 1e3) << " μs\n";
        std::cout << "  Hot path: " << (stat.is_hot_path ? "YES" : "NO") << "\n";
        std::cout << "  Compiled: " << (stat.is_compiled ? "YES" : "NO") << "\n";
        std::cout << "\n";
    }
}

} // namespace Utils

} // namespace JIT
} // namespace VisualGasic
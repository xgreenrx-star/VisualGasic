#ifndef VISUAL_GASIC_GPU_H
#define VISUAL_GASIC_GPU_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/classes/rd_shader_file.hpp>
#include <godot_cpp/classes/rd_shader_spirv.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <functional>
#include <map>

using namespace godot;

/**
 * VisualGasic GPU Computing System
 * 
 * Provides GPU-accelerated computing capabilities including:
 * - SIMD vector operations
 * - Parallel computing with compute shaders
 * - Memory management for GPU buffers
 * - Automatic fallback to CPU when needed
 */
class VisualGasicGPU : public RefCounted {
    GDCLASS(VisualGasicGPU, RefCounted)

public:
    struct ComputeShaderInfo {
        String name;
        String source;
        RID shader_rid;
    };

private:
    RenderingDevice* rendering_device;
    std::map<String, ComputeShaderInfo> compute_cache;

public:
    VisualGasicGPU();
    ~VisualGasicGPU();
    
    // Initialization
    bool initialize();
    
    // SIMD Vector Operations
    Vector<float> simd_vector_add(const Vector<float>& a, const Vector<float>& b);
    Vector<float> simd_vector_multiply(const Vector<float>& a, const Vector<float>& b);
    Vector<float> simd_vector_dot_product(const Vector<float>& a, const Vector<float>& b);
    
    // Parallel Computing
    void parallel_for_gpu(int count, std::function<void(int)> operation);
    Dictionary parallel_map_reduce(const Array& data, 
                                 std::function<Variant(Variant)> map_func,
                                 std::function<Variant(Variant, Variant)> reduce_func);
    
    // Compute Shader Management
    ComputeShaderInfo get_or_create_compute_shader(const String& name, const String& source);
    
    // Shader Source Generation
    String generate_vector_add_shader();
    String generate_vector_multiply_shader();
    String generate_parallel_for_shader();
    String generate_map_reduce_shader();

protected:
    static void _bind_methods() {}

private:
    // GPU Execution Methods
    Vector<float> execute_vector_operation(const String& operation, 
                                          const Vector<float>& a, 
                                          const Vector<float>& b);
    bool create_test_shader();
    void execute_parallel_compute(const ComputeShaderInfo& shader_info, int count);
    Array execute_map_phase(const ComputeShaderInfo& shader_info, const Array& data);
    Variant execute_reduce_phase(const ComputeShaderInfo& shader_info, const Array& mapped_data);
};

#endif // VISUAL_GASIC_GPU_H
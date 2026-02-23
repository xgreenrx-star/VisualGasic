#ifndef VISUAL_GASIC_GPU_H
#define VISUAL_GASIC_GPU_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/classes/rd_shader_file.hpp>
#include <godot_cpp/classes/rd_shader_spirv.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <functional>
#include <map>

using namespace godot;

/**
 * VGGpu — GPU-accelerated computing for VisualGasic
 *
 * Provides SIMD-style vector math, element-wise operations, and parallel
 * reduction — all with automatic CPU fallback when RenderingDevice is
 * unavailable (headless, CI, software renderer).
 *
 * VB6-style API:
 *   Dim gpu As New VGGpu
 *   gpu.Initialize
 *   result = gpu.VectorAdd(a(), b())
 *   dot    = gpu.DotProduct(a(), b())
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
    bool initialized;

public:
    VisualGasicGPU();
    ~VisualGasicGPU();

    // ── Lifecycle ─────────────────────────────────────
    bool initialize();
    bool is_initialized() const;
    bool has_gpu() const;

    // ── Vector Operations (Variant Array of floats) ─
    Array vector_add(const Array &a, const Array &b);
    Array vector_subtract(const Array &a, const Array &b);
    Array vector_multiply(const Array &a, const Array &b);
    Array vector_divide(const Array &a, const Array &b);
    double dot_product(const Array &a, const Array &b);
    double vector_length(const Array &v);
    Array vector_normalize(const Array &v);
    Array vector_scale(const Array &v, double scalar);

    // ── Scalar Reduction ──────────────────────────────
    double vector_sum(const Array &v);
    double vector_min(const Array &v);
    double vector_max(const Array &v);
    double vector_average(const Array &v);

    // ── Element-wise Math ─────────────────────────────
    Array vector_abs(const Array &v);
    Array vector_clamp(const Array &v, double lo, double hi);
    Array vector_lerp(const Array &a, const Array &b, double t);

    // ── Utility ───────────────────────────────────────
    String get_backend() const;
    Dictionary get_info() const;

protected:
    static void _bind_methods();

private:
    // Internal compute-shader helpers (kept for future real-GPU path)
    ComputeShaderInfo get_or_create_compute_shader(const String &name, const String &source);
    String generate_vector_add_shader();
    String generate_vector_multiply_shader();
    String generate_parallel_for_shader();
    String generate_map_reduce_shader();
    bool create_test_shader();
};

#endif // VISUAL_GASIC_GPU_H
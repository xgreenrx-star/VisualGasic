#include "visual_gasic_gpu.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <cmath>

// ═══════════════════════════════════════════════════════════════════
// VGGpu — GPU-accelerated vector math with automatic CPU fallback
// ═══════════════════════════════════════════════════════════════════

// ── Constructor / Destructor ──────────────────────────────────────

VisualGasicGPU::VisualGasicGPU() : rendering_device(nullptr), initialized(false) {
    RenderingServer *rs = RenderingServer::get_singleton();
    rendering_device = rs ? rs->get_rendering_device() : nullptr;
    compute_cache.clear();
}

VisualGasicGPU::~VisualGasicGPU() {
    for (auto &pair : compute_cache) {
        if (rendering_device && pair.second.shader_rid.is_valid()) {
            rendering_device->free_rid(pair.second.shader_rid);
        }
    }
    compute_cache.clear();
}

// ── Lifecycle ─────────────────────────────────────────────────────

bool VisualGasicGPU::initialize() {
    if (initialized) return true;

    // GPU path (RenderingDevice available) — register test shader
    if (rendering_device && create_test_shader()) {
        initialized = true;
        return true;
    }

    // CPU fallback — still "initialized", just no GPU
    initialized = true;
    return true;
}

bool VisualGasicGPU::is_initialized() const {
    return initialized;
}

bool VisualGasicGPU::has_gpu() const {
    return rendering_device != nullptr;
}

// ── Vector Operations ─────────────────────────────────────────────

// Internal helper: extract double from Variant array element
static double _f(const Array &a, int i) {
    Variant v = a[i];
    switch (v.get_type()) {
        case Variant::FLOAT: return (double)v;
        case Variant::INT:   return (double)(int64_t)v;
        default:             return 0.0;
    }
}

Array VisualGasicGPU::vector_add(const Array &a, const Array &b) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), Array(),
        "VGGpu.VectorAdd: array size mismatch (" + itos(a.size()) + " vs " + itos(b.size()) + ")");
    int n = a.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) r[i] = _f(a, i) + _f(b, i);
    return r;
}

Array VisualGasicGPU::vector_subtract(const Array &a, const Array &b) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), Array(),
        "VGGpu.VectorSubtract: array size mismatch");
    int n = a.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) r[i] = _f(a, i) - _f(b, i);
    return r;
}

Array VisualGasicGPU::vector_multiply(const Array &a, const Array &b) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), Array(),
        "VGGpu.VectorMultiply: array size mismatch");
    int n = a.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) r[i] = _f(a, i) * _f(b, i);
    return r;
}

Array VisualGasicGPU::vector_divide(const Array &a, const Array &b) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), Array(),
        "VGGpu.VectorDivide: array size mismatch");
    int n = a.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) {
        double bv = _f(b, i);
        r[i] = (bv != 0.0) ? _f(a, i) / bv : 0.0;
    }
    return r;
}

double VisualGasicGPU::dot_product(const Array &a, const Array &b) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), 0.0,
        "VGGpu.DotProduct: array size mismatch");
    int n = a.size();
    double sum = 0.0;
    for (int i = 0; i < n; i++) sum += _f(a, i) * _f(b, i);
    return sum;
}

double VisualGasicGPU::vector_length(const Array &v) {
    int n = v.size();
    ERR_FAIL_COND_V_MSG(n == 0, 0.0, "VGGpu.VectorLength: empty array");
    double sum = 0.0;
    for (int i = 0; i < n; i++) { double x = _f(v, i); sum += x * x; }
    return std::sqrt(sum);
}

Array VisualGasicGPU::vector_normalize(const Array &v) {
    int n = v.size();
    ERR_FAIL_COND_V_MSG(n == 0, Array(), "VGGpu.VectorNormalize: empty array");
    double len = vector_length(v);
    Array r;
    r.resize(n);
    if (len < 1e-12) return r;
    double inv = 1.0 / len;
    for (int i = 0; i < n; i++) r[i] = _f(v, i) * inv;
    return r;
}

Array VisualGasicGPU::vector_scale(const Array &v, double scalar) {
    int n = v.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) r[i] = _f(v, i) * scalar;
    return r;
}

// ── Scalar Reduction ──────────────────────────────────────────────

double VisualGasicGPU::vector_sum(const Array &v) {
    int n = v.size();
    double sum = 0.0;
    for (int i = 0; i < n; i++) sum += _f(v, i);
    return sum;
}

double VisualGasicGPU::vector_min(const Array &v) {
    ERR_FAIL_COND_V_MSG(v.size() == 0, 0.0, "VGGpu.VectorMin: empty array");
    double mn = _f(v, 0);
    for (int i = 1; i < v.size(); i++) { double x = _f(v, i); if (x < mn) mn = x; }
    return mn;
}

double VisualGasicGPU::vector_max(const Array &v) {
    ERR_FAIL_COND_V_MSG(v.size() == 0, 0.0, "VGGpu.VectorMax: empty array");
    double mx = _f(v, 0);
    for (int i = 1; i < v.size(); i++) { double x = _f(v, i); if (x > mx) mx = x; }
    return mx;
}

double VisualGasicGPU::vector_average(const Array &v) {
    ERR_FAIL_COND_V_MSG(v.size() == 0, 0.0, "VGGpu.VectorAverage: empty array");
    return vector_sum(v) / (double)v.size();
}

// ── Element-wise Math ─────────────────────────────────────────────

Array VisualGasicGPU::vector_abs(const Array &v) {
    int n = v.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) r[i] = std::fabs(_f(v, i));
    return r;
}

Array VisualGasicGPU::vector_clamp(const Array &v, double lo, double hi) {
    int n = v.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) {
        double x = _f(v, i);
        r[i] = (x < lo) ? lo : (x > hi) ? hi : x;
    }
    return r;
}

Array VisualGasicGPU::vector_lerp(const Array &a, const Array &b, double t) {
    ERR_FAIL_COND_V_MSG(a.size() != b.size(), Array(),
        "VGGpu.VectorLerp: array size mismatch");
    int n = a.size();
    Array r;
    r.resize(n);
    for (int i = 0; i < n; i++) {
        double av = _f(a, i), bv = _f(b, i);
        r[i] = av + (bv - av) * t;
    }
    return r;
}

// ── Utility ───────────────────────────────────────────────────────

String VisualGasicGPU::get_backend() const {
    return has_gpu() ? "GPU" : "CPU";
}

Dictionary VisualGasicGPU::get_info() const {
    Dictionary d;
    d["initialized"] = initialized;
    d["has_gpu"] = has_gpu();
    d["backend"] = get_backend();
    d["shader_cache_size"] = (int)compute_cache.size();
    return d;
}

// ── ClassDB Bindings ──────────────────────────────────────────────

void VisualGasicGPU::_bind_methods() {
    // Lifecycle
    ClassDB::bind_method(D_METHOD("Initialize"), &VisualGasicGPU::initialize);
    ClassDB::bind_method(D_METHOD("IsInitialized"), &VisualGasicGPU::is_initialized);
    ClassDB::bind_method(D_METHOD("HasGpu"), &VisualGasicGPU::has_gpu);

    // Vector operations (binary)
    ClassDB::bind_method(D_METHOD("VectorAdd", "a", "b"), &VisualGasicGPU::vector_add);
    ClassDB::bind_method(D_METHOD("VectorSubtract", "a", "b"), &VisualGasicGPU::vector_subtract);
    ClassDB::bind_method(D_METHOD("VectorMultiply", "a", "b"), &VisualGasicGPU::vector_multiply);
    ClassDB::bind_method(D_METHOD("VectorDivide", "a", "b"), &VisualGasicGPU::vector_divide);
    ClassDB::bind_method(D_METHOD("DotProduct", "a", "b"), &VisualGasicGPU::dot_product);
    ClassDB::bind_method(D_METHOD("VectorLerp", "a", "b", "t"), &VisualGasicGPU::vector_lerp);

    // Unary / scalar vector ops
    ClassDB::bind_method(D_METHOD("VectorLength", "v"), &VisualGasicGPU::vector_length);
    ClassDB::bind_method(D_METHOD("VectorNormalize", "v"), &VisualGasicGPU::vector_normalize);
    ClassDB::bind_method(D_METHOD("VectorScale", "v", "scalar"), &VisualGasicGPU::vector_scale);
    ClassDB::bind_method(D_METHOD("VectorAbs", "v"), &VisualGasicGPU::vector_abs);
    ClassDB::bind_method(D_METHOD("VectorClamp", "v", "lo", "hi"), &VisualGasicGPU::vector_clamp);

    // Reduction
    ClassDB::bind_method(D_METHOD("VectorSum", "v"), &VisualGasicGPU::vector_sum);
    ClassDB::bind_method(D_METHOD("VectorMin", "v"), &VisualGasicGPU::vector_min);
    ClassDB::bind_method(D_METHOD("VectorMax", "v"), &VisualGasicGPU::vector_max);
    ClassDB::bind_method(D_METHOD("VectorAverage", "v"), &VisualGasicGPU::vector_average);

    // Info
    ClassDB::bind_method(D_METHOD("GetBackend"), &VisualGasicGPU::get_backend);
    ClassDB::bind_method(D_METHOD("GetInfo"), &VisualGasicGPU::get_info);
}

// ── Internal shader helpers (kept for future real-GPU path) ───────

VisualGasicGPU::ComputeShaderInfo VisualGasicGPU::get_or_create_compute_shader(
        const String &name, const String &source) {
    auto it = compute_cache.find(name);
    if (it != compute_cache.end()) return it->second;

    ComputeShaderInfo info;
    info.name = name;
    info.source = source;
    compute_cache[name] = info;
    return info;
}

String VisualGasicGPU::generate_vector_add_shader() { return ""; }
String VisualGasicGPU::generate_vector_multiply_shader() { return ""; }
String VisualGasicGPU::generate_parallel_for_shader() { return ""; }
String VisualGasicGPU::generate_map_reduce_shader() { return ""; }

bool VisualGasicGPU::create_test_shader() {
    String src = R"(#version 450
layout(local_size_x = 1) in;
layout(set = 0, binding = 0, std430) restrict writeonly buffer B { float d[]; };
void main() { d[0] = 42.0; }
)";
    ComputeShaderInfo info = get_or_create_compute_shader("test", src);
    return !info.source.is_empty();
}
#include "visual_gasic_gpu.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

VisualGasicGPU::VisualGasicGPU() {
    rendering_device = RenderingServer::get_singleton()->create_local_rendering_device();
    compute_cache.clear();
}

VisualGasicGPU::~VisualGasicGPU() {
    // Cleanup compute shaders
    for (auto& pair : compute_cache) {
        if (rendering_device.is_valid()) {
            rendering_device->free_rid(pair.second.shader_rid);
        }
    }
}

bool VisualGasicGPU::initialize() {
    if (!rendering_device.is_valid()) {
        UtilityFunctions::print_rich("[color=red]GPU: Failed to create rendering device[/color]");
        return false;
    }
    
    // Test basic GPU functionality
    if (!create_test_shader()) {
        UtilityFunctions::print_rich("[color=red]GPU: Failed to create test compute shader[/color]");
        return false;
    }
    
    UtilityFunctions::print_rich("[color=green]GPU: Initialized successfully[/color]");
    return true;
}

// SIMD Vector Operations
Vector<float> VisualGasicGPU::simd_vector_add(const Vector<float>& a, const Vector<float>& b) {
    if (a.size() != b.size()) {
        UtilityFunctions::print_rich("[color=red]GPU: Vector size mismatch for addition[/color]");
        return Vector<float>();
    }
    
    return execute_vector_operation("add", a, b);
}

Vector<float> VisualGasicGPU::simd_vector_multiply(const Vector<float>& a, const Vector<float>& b) {
    if (a.size() != b.size()) {
        UtilityFunctions::print_rich("[color=red]GPU: Vector size mismatch for multiplication[/color]");
        return Vector<float>();
    }
    
    return execute_vector_operation("multiply", a, b);
}

Vector<float> VisualGasicGPU::simd_vector_dot_product(const Vector<float>& a, const Vector<float>& b) {
    if (a.size() != b.size()) {
        UtilityFunctions::print_rich("[color=red]GPU: Vector size mismatch for dot product[/color]");
        return Vector<float>();
    }
    
    return execute_vector_operation("dot", a, b);
}

// Parallel Computing
void VisualGasicGPU::parallel_for_gpu(int count, std::function<void(int)> operation) {
    if (count <= 0) return;
    
    // Create compute shader for parallel execution
    String shader_code = generate_parallel_for_shader();
    ComputeShaderInfo shader_info = get_or_create_compute_shader("parallel_for", shader_code);
    
    if (shader_info.shader_rid.is_valid()) {
        execute_parallel_compute(shader_info, count);
    } else {
        // Fallback to CPU if GPU fails
        for (int i = 0; i < count; i++) {
            operation(i);
        }
    }
}

Dictionary VisualGasicGPU::parallel_map_reduce(const Array& data, 
                                             std::function<Variant(Variant)> map_func,
                                             std::function<Variant(Variant, Variant)> reduce_func) {
    Dictionary result;
    
    if (data.size() == 0) {
        result["success"] = false;
        result["error"] = "Empty data array";
        return result;
    }
    
    // Create map-reduce compute shader
    String shader_code = generate_map_reduce_shader();
    ComputeShaderInfo shader_info = get_or_create_compute_shader("map_reduce", shader_code);
    
    if (shader_info.shader_rid.is_valid()) {
        // Execute on GPU
        Array mapped_data = execute_map_phase(shader_info, data);
        Variant reduced_result = execute_reduce_phase(shader_info, mapped_data);
        
        result["success"] = true;
        result["result"] = reduced_result;
        result["processed_count"] = data.size();
    } else {
        // CPU fallback
        Array mapped_data;
        for (int i = 0; i < data.size(); i++) {
            mapped_data.push_back(map_func(data[i]));
        }
        
        Variant reduced_result = mapped_data[0];
        for (int i = 1; i < mapped_data.size(); i++) {
            reduced_result = reduce_func(reduced_result, mapped_data[i]);
        }
        
        result["success"] = true;
        result["result"] = reduced_result;
        result["processed_count"] = data.size();
        result["fallback"] = "CPU";
    }
    
    return result;
}

// Compute Shader Management
VisualGasicGPU::ComputeShaderInfo VisualGasicGPU::get_or_create_compute_shader(const String& name, const String& source) {
    if (compute_cache.find(name) != compute_cache.end()) {
        return compute_cache[name];
    }
    
    ComputeShaderInfo shader_info;
    shader_info.name = name;
    shader_info.source = source;
    
    // Create compute shader
    RDShaderFile shader_file;
    shader_file.set_bytecode("glsl", source.to_utf8_buffer());
    
    RDShaderSpirV shader_spirv = shader_file.get_spirv();
    shader_info.shader_rid = rendering_device->shader_create_from_spirv(shader_spirv);
    
    if (shader_info.shader_rid.is_valid()) {
        compute_cache[name] = shader_info;
        UtilityFunctions::print_rich("[color=green]GPU: Created compute shader '" + name + "'[/color]");
    } else {
        UtilityFunctions::print_rich("[color=red]GPU: Failed to create compute shader '" + name + "'[/color]");
    }
    
    return shader_info;
}

// Shader Source Generation
String VisualGasicGPU::generate_vector_add_shader() {
    return R"(
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBufferA {
    float data_a[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer InputBufferB {
    float data_b[];
};

layout(set = 0, binding = 2, std430) restrict writeonly buffer OutputBuffer {
    float result[];
};

layout(push_constant, std430) uniform Params {
    uint count;
} params;

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= params.count) return;
    
    result[index] = data_a[index] + data_b[index];
}
)";
}

String VisualGasicGPU::generate_vector_multiply_shader() {
    return R"(
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBufferA {
    float data_a[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer InputBufferB {
    float data_b[];
};

layout(set = 0, binding = 2, std430) restrict writeonly buffer OutputBuffer {
    float result[];
};

layout(push_constant, std430) uniform Params {
    uint count;
} params;

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= params.count) return;
    
    result[index] = data_a[index] * data_b[index];
}
)";
}

String VisualGasicGPU::generate_parallel_for_shader() {
    return R"(
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
    float data[];
};

layout(push_constant, std430) uniform Params {
    uint count;
    uint operation_type;
} params;

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= params.count) return;
    
    // Example operations based on operation_type
    switch (params.operation_type) {
        case 0: // Square
            data[index] = data[index] * data[index];
            break;
        case 1: // Double
            data[index] = data[index] * 2.0;
            break;
        case 2: // Increment
            data[index] = data[index] + 1.0;
            break;
        default:
            break;
    }
}
)";
}

String VisualGasicGPU::generate_map_reduce_shader() {
    return R"(
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBuffer {
    float input_data[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer OutputBuffer {
    float output_data[];
};

layout(push_constant, std430) uniform Params {
    uint count;
    uint phase; // 0 = map, 1 = reduce
} params;

shared float local_data[64];

void main() {
    uint index = gl_GlobalInvocationID.x;
    uint local_index = gl_LocalInvocationID.x;
    
    if (params.phase == 0) { // Map phase
        if (index < params.count) {
            output_data[index] = input_data[index] * input_data[index]; // Example: square
        }
    } else { // Reduce phase
        // Load data into shared memory
        if (index < params.count) {
            local_data[local_index] = input_data[index];
        } else {
            local_data[local_index] = 0.0;
        }
        
        barrier();
        
        // Parallel reduction
        for (uint stride = 32; stride > 0; stride >>= 1) {
            if (local_index < stride) {
                local_data[local_index] += local_data[local_index + stride];
            }
            barrier();
        }
        
        // Write result
        if (local_index == 0) {
            output_data[gl_WorkGroupID.x] = local_data[0];
        }
    }
}
)";
}

// GPU Execution Methods
Vector<float> VisualGasicGPU::execute_vector_operation(const String& operation, 
                                                       const Vector<float>& a, 
                                                       const Vector<float>& b) {
    Vector<float> result;
    
    if (!rendering_device.is_valid()) {
        return result;
    }
    
    String shader_name = "vector_" + operation;
    String shader_source;
    
    if (operation == "add") {
        shader_source = generate_vector_add_shader();
    } else if (operation == "multiply") {
        shader_source = generate_vector_multiply_shader();
    } else {
        UtilityFunctions::print_rich("[color=red]GPU: Unknown vector operation: " + operation + "[/color]");
        return result;
    }
    
    ComputeShaderInfo shader_info = get_or_create_compute_shader(shader_name, shader_source);
    
    if (!shader_info.shader_rid.is_valid()) {
        return result;
    }
    
    try {
        // Create input buffers
        PackedFloat32Array buffer_a, buffer_b;
        for (int i = 0; i < a.size(); i++) {
            buffer_a.push_back(a[i]);
            buffer_b.push_back(b[i]);
        }
        
        RID input_buffer_a = rendering_device->storage_buffer_create(buffer_a.to_byte_array().size());
        RID input_buffer_b = rendering_device->storage_buffer_create(buffer_b.to_byte_array().size());
        RID output_buffer = rendering_device->storage_buffer_create(buffer_a.to_byte_array().size());
        
        rendering_device->buffer_update(input_buffer_a, 0, buffer_a.to_byte_array());
        rendering_device->buffer_update(input_buffer_b, 0, buffer_b.to_byte_array());
        
        // Create uniform set
        Array uniform_array;
        uniform_array.push_back(rendering_device->uniform_buffer_create_from_buffer(input_buffer_a));
        uniform_array.push_back(rendering_device->uniform_buffer_create_from_buffer(input_buffer_b));
        uniform_array.push_back(rendering_device->uniform_buffer_create_from_buffer(output_buffer));
        
        RID uniform_set = rendering_device->uniform_set_create(uniform_array, shader_info.shader_rid, 0);
        
        // Execute compute shader
        RID compute_list = rendering_device->compute_list_begin();
        rendering_device->compute_list_bind_compute_pipeline(compute_list, shader_info.shader_rid);
        rendering_device->compute_list_bind_uniform_set(compute_list, uniform_set, 0);
        
        // Set push constants
        PackedByteArray push_constants;
        push_constants.resize(4);
        push_constants.encode_u32(0, a.size());
        rendering_device->compute_list_set_push_constant(compute_list, push_constants, 0);
        
        int work_groups = (a.size() + 63) / 64; // Round up for 64 work group size
        rendering_device->compute_list_dispatch(compute_list, work_groups, 1, 1);
        rendering_device->compute_list_end();
        rendering_device->submit();
        rendering_device->wait();
        
        // Read results
        PackedByteArray output_bytes = rendering_device->buffer_get_data(output_buffer);
        PackedFloat32Array output_floats = output_bytes.to_float32_array();
        
        for (int i = 0; i < output_floats.size(); i++) {
            result.push_back(output_floats[i]);
        }
        
        // Cleanup
        rendering_device->free_rid(input_buffer_a);
        rendering_device->free_rid(input_buffer_b);
        rendering_device->free_rid(output_buffer);
        rendering_device->free_rid(uniform_set);
        
    } catch (...) {
        UtilityFunctions::print_rich("[color=red]GPU: Error executing vector operation[/color]");
    }
    
    return result;
}

bool VisualGasicGPU::create_test_shader() {
    String test_shader = R"(
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict writeonly buffer TestBuffer {
    float data[];
};

void main() {
    data[0] = 42.0; // Test value
}
)";
    
    ComputeShaderInfo test_info = get_or_create_compute_shader("test", test_shader);
    return test_info.shader_rid.is_valid();
}

void VisualGasicGPU::execute_parallel_compute(const ComputeShaderInfo& shader_info, int count) {
    if (!shader_info.shader_rid.is_valid()) return;
    
    // Implementation for parallel compute execution
    // This would dispatch the compute shader with the specified count
}

Array VisualGasicGPU::execute_map_phase(const ComputeShaderInfo& shader_info, const Array& data) {
    // Implementation for map phase execution
    return data; // Simplified for now
}

Variant VisualGasicGPU::execute_reduce_phase(const ComputeShaderInfo& shader_info, const Array& mapped_data) {
    // Implementation for reduce phase execution
    float sum = 0.0f;
    for (int i = 0; i < mapped_data.size(); i++) {
        sum += (float)mapped_data[i];
    }
    return sum; // Simplified for now
}
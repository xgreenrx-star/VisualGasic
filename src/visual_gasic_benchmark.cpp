#include "visual_gasic_benchmark.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/string.hpp>

#include <vector>

void VisualGasicBenchmark::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_cpp_benchmark", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_benchmark);
    ClassDB::bind_method(D_METHOD("run_cpp_arithmetic", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_arithmetic);
    ClassDB::bind_method(D_METHOD("run_cpp_array_sum", "iterations", "size"), &VisualGasicBenchmark::run_cpp_array_sum);
    ClassDB::bind_method(D_METHOD("run_cpp_string_concat", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_string_concat);
    ClassDB::bind_method(D_METHOD("run_cpp_branch", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_branch);
    ClassDB::bind_method(D_METHOD("run_cpp_array_dict", "iterations", "size"), &VisualGasicBenchmark::run_cpp_array_dict);
    ClassDB::bind_method(D_METHOD("run_cpp_interop", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_interop);
    ClassDB::bind_method(D_METHOD("run_cpp_allocations", "iterations", "size"), &VisualGasicBenchmark::run_cpp_allocations);
    ClassDB::bind_method(D_METHOD("run_cpp_allocations_fast", "iterations", "size"), &VisualGasicBenchmark::run_cpp_allocations_fast);
    ClassDB::bind_method(D_METHOD("run_cpp_file_io", "iterations", "size"), &VisualGasicBenchmark::run_cpp_file_io);
}

Dictionary VisualGasicBenchmark::run_cpp_benchmark(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    uint64_t start = Time::get_singleton()->get_ticks_usec();
    int64_t sum = 0;
    for (int64_t i = 0; i < iterations; i++) {
        for (int64_t j = 0; j < inner; j++) {
            sum += j;
        }
    }
    uint64_t end = Time::get_singleton()->get_ticks_usec();

    result["elapsed_us"] = static_cast<int64_t>(end - start);
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_arithmetic(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t i = 0; i < iterations; i++) {
        for (int64_t j = 0; j < inner; j++) {
            sum += (j * 3) - 7;
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_array_sum(int64_t iterations, int64_t size) {
    Dictionary result;
    if (iterations <= 0 || size <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    const int64_t length = size < 0 ? 0 : size;
    std::vector<int64_t> arr(static_cast<size_t>(length));
    for (int64_t i = 0; i < length; i++) {
        arr[static_cast<size_t>(i)] = i;
    }

    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t iter = 0; iter < iterations; iter++) {
        for (int64_t i = 0; i < length; i++) {
            sum += arr[static_cast<size_t>(i)];
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_string_concat(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    String s;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t i = 0; i < iterations; i++) {
        s = "";
        for (int64_t j = 0; j < inner; j++) {
            s += "x";
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = (int64_t)s.length();
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_branch(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t i = 0; i < iterations; i++) {
        int64_t flag = 0;
        for (int64_t j = 0; j < inner; j++) {
            if (flag == 0) {
                sum += j;
                flag = 1;
            } else {
                sum -= j;
                flag = 0;
            }
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_array_dict(int64_t iterations, int64_t size) {
    Dictionary result;
    if (iterations <= 0 || size <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    const int64_t length = size < 0 ? 0 : size;
    std::vector<int64_t> arr(static_cast<size_t>(length));
    std::vector<String> keys(static_cast<size_t>(length));
    Dictionary dict;
    for (int64_t i = 0; i < length; i++) {
        arr[static_cast<size_t>(i)] = i;
        keys[static_cast<size_t>(i)] = String::num_int64(i);
        dict[keys[static_cast<size_t>(i)]] = length - i;
    }

    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t iter = 0; iter < iterations; iter++) {
        for (int64_t i = 0; i < length; i++) {
            sum += arr[static_cast<size_t>(i)];
            Variant v = dict[keys[static_cast<size_t>(i)]];
            sum += (int64_t)v;
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_interop(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    Node *node = memnew(Node);
    int64_t checksum = 0;
    String prefix = "bench_";
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t i = 0; i < iterations; i++) {
        for (int64_t j = 0; j < inner; j++) {
            node->set_name(prefix + String::num_int64(j));
            checksum += node->get_name().length();
        }
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = checksum;
    memdelete(node);
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_allocations(int64_t iterations, int64_t size) {
    Dictionary result;
    if (iterations <= 0 || size <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    const int64_t length = size < 0 ? 0 : size;
    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t iter = 0; iter < iterations; iter++) {
        std::vector<int64_t> arr(static_cast<size_t>(length));
        String text;
        for (int64_t i = 0; i < length; i++) {
            arr[static_cast<size_t>(i)] = iter + i;
            text += "x";
            sum += arr[static_cast<size_t>(i)];
        }
        sum += text.length();
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_allocations_fast(int64_t iterations, int64_t size) {
    Dictionary result;
    if (iterations <= 0 || size <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    const int64_t length = size < 0 ? 0 : size;
    int64_t sum = 0;
    uint64_t start = Time::get_singleton()->get_ticks_usec();
    for (int64_t iter = 0; iter < iterations; iter++) {
        std::vector<int64_t> arr(static_cast<size_t>(length));
        for (int64_t i = 0; i < length; i++) {
            arr[static_cast<size_t>(i)] = i;
        }
        sum += length;
    }
    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = sum;
    return result;
}

Dictionary VisualGasicBenchmark::run_cpp_file_io(int64_t iterations, int64_t size) {
    Dictionary result;
    if (iterations <= 0 || size <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    uint64_t start = Time::get_singleton()->get_ticks_usec();
    String line;
    for (int64_t i = 0; i < size; i++) {
        line += "x";
    }

    Ref<FileAccess> writer = FileAccess::open("user://bench_io_cpp.txt", FileAccess::WRITE);
    if (writer.is_valid()) {
        for (int64_t iter = 0; iter < iterations; iter++) {
            writer->store_line(line);
        }
        writer->close();
    }

    String read_line;
    Ref<FileAccess> reader = FileAccess::open("user://bench_io_cpp.txt", FileAccess::READ);
    if (reader.is_valid()) {
        read_line = reader->get_line();
        reader->close();
    }

    uint64_t elapsed = Time::get_singleton()->get_ticks_usec() - start;
    result["elapsed_us"] = (int64_t)elapsed;
    result["checksum"] = (int64_t)read_line.length();
    return result;
}

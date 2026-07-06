extends SceneTree

const ARITH_ITER := 200
const ARITH_INNER := 1000
const ARRAY_ITER := 200
const ARRAY_SIZE := 1000
const STRING_ITER := 100
const STRING_INNER := 400
const BRANCH_ITER := 200
const BRANCH_INNER := 1000
const ARRAY_DICT_ITER := 120
const ARRAY_DICT_SIZE := 640
const DICT_FAST_ITER := 400
const DICT_FAST_SIZE := 512
const INTEROP_ITER := 60
const INTEROP_INNER := 320
const ALLOC_ITER := 60
const ALLOC_SIZE := 640
const ALLOC_FAST_ITER := 160
const ALLOC_FAST_SIZE := 4096
const FILE_IO_ITER := 32
const FILE_IO_SIZE := 2048

var _vg_script: Script = null

func _get_vg_script() -> Script:
    if _vg_script == null:
        _vg_script = load("res://bench.vg")
    return _vg_script

func run_visual_gasic(func_name: String, args: Array) -> Dictionary:
    var script = _get_vg_script()
    if script == null:
        push_error("Failed to load bench.vg")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var checksum = node.callv(func_name, args)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": checksum}

func run_cpp(method_name: String, args: Array) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    if not bench.has_method(method_name):
        push_error("VisualGasicBenchmark missing method: " + method_name)
        bench.free()
        return {}
    var result_variant = bench.callv(method_name, args)
    bench.free()
    if result_variant is Dictionary:
        return result_variant
    push_warning("C++ benchmark " + method_name + " returned unexpected result.")
    return {}

func bench_gd_arithmetic(iterations: int, inner: int) -> Dictionary:
    var s := 0
    var start := Time.get_ticks_usec()
    for i in iterations:
        for j in inner:
            s += (j * 3) - 7
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": s}

func bench_gd_array_sum(iterations: int, size: int) -> Dictionary:
    var arr := PackedInt64Array()
    arr.resize(size)
    for i in size:
        arr[i] = i
    var s := 0
    var start := Time.get_ticks_usec()
    for _k in iterations:
        for i in size:
            s += arr[i]
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": s}

func bench_gd_string_concat(iterations: int, inner: int) -> Dictionary:
    var s := ""
    var start := Time.get_ticks_usec()
    for _i in iterations:
        s = ""
        for _j in inner:
            s += "x"
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": s.length()}

func bench_gd_branch(iterations: int, inner: int) -> Dictionary:
    var s := 0
    var start := Time.get_ticks_usec()
    for _i in iterations:
        for j in inner:
            if (j & 1) == 0:
                s += j
            else:
                s -= j
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": s}

func bench_gd_array_dict(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var arr := PackedInt64Array()
    arr.resize(size)
    var keys := PackedStringArray()
    keys.resize(size)
    var dict := {}
    for i in size:
        arr[i] = i
        keys[i] = str(i)
        dict[keys[i]] = size - i

    var sum := 0
    var start := Time.get_ticks_usec()
    for _iter in iterations:
        for i in size:
            sum += arr[i]
            sum += int(dict.get(keys[i], 0))
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": sum}

func bench_gd_dict_fast_get(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var dict := {}
    var keys := PackedStringArray()
    keys.resize(size)
    for i in size:
        var key := str(i)
        keys[i] = key
        dict[key] = i

    var sum := 0
    var start := Time.get_ticks_usec()
    for _iter in iterations:
        for i in size:
            sum += int(dict.get(keys[i], 0))
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": sum}

func bench_gd_dict_fast_set(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var dict := {}
    var keys := PackedStringArray()
    keys.resize(size)
    for i in size:
        var key := str(i)
        keys[i] = key
        dict[key] = 0

    var sum := 0
    var start := Time.get_ticks_usec()
    for iter in iterations:
        for i in size:
            var value := iter + i
            dict[keys[i]] = value
            sum += value
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": sum}

func bench_gd_interop(iterations: int, inner: int) -> Dictionary:
    if iterations <= 0 or inner <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var node := Node.new()
    var prefix := "bench_"
    var checksum := 0
    var start := Time.get_ticks_usec()
    for _i in iterations:
        for j in inner:
            node.name = prefix + str(j)
            checksum += node.name.length()
    node.queue_free()
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": checksum}

func bench_gd_allocations(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var sum := 0
    var start := Time.get_ticks_usec()
    for iter in iterations:
        var arr := PackedInt64Array()
        arr.resize(size)
        var text := ""
        for i in size:
            arr[i] = iter + i
            text += "x"
            sum += arr[i]
        sum += text.length()
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": sum}

func bench_gd_allocations_fast(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var sum := 0
    var start := Time.get_ticks_usec()
    for _iter in iterations:
        var arr := PackedInt64Array()
        arr.resize(size)
        for i in size:
            arr[i] = i
        sum += size
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": sum}

func bench_gd_file_io(iterations: int, size: int) -> Dictionary:
    if iterations <= 0 or size <= 0:
        return {"elapsed_us": 0, "checksum": 0}

    var start := Time.get_ticks_usec()
    var line := ""
    for _i in size:
        line += "x"

    var writer := FileAccess.open("user://bench_io_gd.txt", FileAccess.WRITE)
    if writer:
        for _iter in iterations:
            writer.store_line(line)
        writer.close()

    var read_line := ""
    var reader := FileAccess.open("user://bench_io_gd.txt", FileAccess.READ)
    if reader:
        read_line = reader.get_line()
        reader.close()

    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": read_line.length()}

func bench_vg_arithmetic(iterations: int, inner: int) -> Dictionary:
    return run_visual_gasic("BenchArithmetic", [iterations, inner])

func bench_vg_array_sum(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchArraySum", [iterations, size])

func bench_vg_string_concat(iterations: int, inner: int) -> Dictionary:
    return run_visual_gasic("BenchStringConcat", [iterations, inner])

func bench_vg_branch(iterations: int, inner: int) -> Dictionary:
    return run_visual_gasic("BenchBranch", [iterations, inner])

func bench_vg_array_dict(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchArrayDict", [iterations, size])

func bench_vg_dict_fast_get(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchDictFastGet", [iterations, size])

func bench_vg_dict_fast_set(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchDictFastSet", [iterations, size])

func bench_vg_interop(iterations: int, inner: int) -> Dictionary:
    return run_visual_gasic("BenchInterop", [iterations, inner])

func bench_vg_allocations(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchAllocations", [iterations, size])

func bench_vg_allocations_fast(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchAllocationsFast", [iterations, size])

func bench_vg_file_io(iterations: int, size: int) -> Dictionary:
    return run_visual_gasic("BenchFileIO", [iterations, size])

func bench_cpp_arithmetic(iterations: int, inner: int) -> Dictionary:
    return run_cpp("run_cpp_arithmetic", [iterations, inner])

func bench_cpp_array_sum(iterations: int, size: int) -> Dictionary:
    return run_cpp("run_cpp_array_sum", [iterations, size])

func bench_cpp_string_concat(iterations: int, inner: int) -> Dictionary:
    return run_cpp("run_cpp_string_concat", [iterations, inner])

func bench_cpp_branch(iterations: int, inner: int) -> Dictionary:
    return run_cpp("run_cpp_branch", [iterations, inner])

func bench_cpp_array_dict(iterations: int, size: int) -> Dictionary:
    return run_cpp("run_cpp_array_dict", [iterations, size])

func bench_cpp_interop(iterations: int, inner: int) -> Dictionary:
    return run_cpp("run_cpp_interop", [iterations, inner])

func bench_cpp_allocations(iterations: int, size: int) -> Dictionary:
    return run_cpp("run_cpp_allocations", [iterations, size])

func bench_cpp_allocations_fast(iterations: int, size: int) -> Dictionary:
    return run_cpp("run_cpp_allocations_fast", [iterations, size])

func bench_cpp_file_io(iterations: int, size: int) -> Dictionary:
    return run_cpp("run_cpp_file_io", [iterations, size])

func run_workload(name: String, gd_call: Callable, vg_call: Callable, cpp_call: Callable = Callable()) -> Dictionary:
    var entry := {
        "name": name,
        "gd": gd_call.call(),
        "vg": vg_call.call()
    }
    if cpp_call.is_valid():
        entry["cpp"] = cpp_call.call()
    return entry

func _init():
    print("Warmup...")
    bench_gd_arithmetic(10, 100)
    bench_vg_arithmetic(10, 100)
    bench_cpp_arithmetic(10, 100)

    print("Running benchmarks...")
    var results = []

    results.append(run_workload(
        "Arithmetic",
        Callable(self, "bench_gd_arithmetic").bind(ARITH_ITER, ARITH_INNER),
        Callable(self, "bench_vg_arithmetic").bind(ARITH_ITER, ARITH_INNER),
        Callable(self, "bench_cpp_arithmetic").bind(ARITH_ITER, ARITH_INNER)
    ))

    results.append(run_workload(
        "ArraySum",
        Callable(self, "bench_gd_array_sum").bind(ARRAY_ITER, ARRAY_SIZE),
        Callable(self, "bench_vg_array_sum").bind(ARRAY_ITER, ARRAY_SIZE),
        Callable(self, "bench_cpp_array_sum").bind(ARRAY_ITER, ARRAY_SIZE)
    ))

    results.append(run_workload(
        "StringConcat",
        Callable(self, "bench_gd_string_concat").bind(STRING_ITER, STRING_INNER),
        Callable(self, "bench_vg_string_concat").bind(STRING_ITER, STRING_INNER),
        Callable(self, "bench_cpp_string_concat").bind(STRING_ITER, STRING_INNER)
    ))

    results.append(run_workload(
        "Branching",
        Callable(self, "bench_gd_branch").bind(BRANCH_ITER, BRANCH_INNER),
        Callable(self, "bench_vg_branch").bind(BRANCH_ITER, BRANCH_INNER),
        Callable(self, "bench_cpp_branch").bind(BRANCH_ITER, BRANCH_INNER)
    ))

    results.append(run_workload(
        "ArrayDict",
        Callable(self, "bench_gd_array_dict").bind(ARRAY_DICT_ITER, ARRAY_DICT_SIZE),
        Callable(self, "bench_vg_array_dict").bind(ARRAY_DICT_ITER, ARRAY_DICT_SIZE),
        Callable(self, "bench_cpp_array_dict").bind(ARRAY_DICT_ITER, ARRAY_DICT_SIZE)
    ))

    results.append(run_workload(
        "DictFastGet",
        Callable(self, "bench_gd_dict_fast_get").bind(DICT_FAST_ITER, DICT_FAST_SIZE),
        Callable(self, "bench_vg_dict_fast_get").bind(DICT_FAST_ITER, DICT_FAST_SIZE)
    ))

    results.append(run_workload(
        "DictFastSet",
        Callable(self, "bench_gd_dict_fast_set").bind(DICT_FAST_ITER, DICT_FAST_SIZE),
        Callable(self, "bench_vg_dict_fast_set").bind(DICT_FAST_ITER, DICT_FAST_SIZE)
    ))

    results.append(run_workload(
        "Interop",
        Callable(self, "bench_gd_interop").bind(INTEROP_ITER, INTEROP_INNER),
        Callable(self, "bench_vg_interop").bind(INTEROP_ITER, INTEROP_INNER),
        Callable(self, "bench_cpp_interop").bind(INTEROP_ITER, INTEROP_INNER)
    ))

    results.append(run_workload(
        "Allocations",
        Callable(self, "bench_gd_allocations").bind(ALLOC_ITER, ALLOC_SIZE),
        Callable(self, "bench_vg_allocations").bind(ALLOC_ITER, ALLOC_SIZE),
        Callable(self, "bench_cpp_allocations").bind(ALLOC_ITER, ALLOC_SIZE)
    ))

    results.append(run_workload(
        "AllocationsFast",
        Callable(self, "bench_gd_allocations_fast").bind(ALLOC_FAST_ITER, ALLOC_FAST_SIZE),
        Callable(self, "bench_vg_allocations_fast").bind(ALLOC_FAST_ITER, ALLOC_FAST_SIZE),
        Callable(self, "bench_cpp_allocations_fast").bind(ALLOC_FAST_ITER, ALLOC_FAST_SIZE)
    ))

    results.append(run_workload(
        "FileIO",
        Callable(self, "bench_gd_file_io").bind(FILE_IO_ITER, FILE_IO_SIZE),
        Callable(self, "bench_vg_file_io").bind(FILE_IO_ITER, FILE_IO_SIZE),
        Callable(self, "bench_cpp_file_io").bind(FILE_IO_ITER, FILE_IO_SIZE)
    ))

    for r in results:
        print("\n=== ", r["name"], " ===")
        var gd_result: Dictionary = r["gd"]
        var vg_result: Dictionary = r["vg"]
        var has_cpp: bool = r.has("cpp")
        var cpp_result: Dictionary = {}
        if has_cpp:
            cpp_result = r["cpp"]

        print("GDScript: ", gd_result)
        print("VisualGasic: ", vg_result)
        if has_cpp:
            print("C++: ", cpp_result)

        if gd_result.is_empty() or vg_result.is_empty() or (has_cpp and cpp_result.is_empty()):
            push_warning("Skipping " + r["name"] + " due to missing benchmark data.")
            continue

        var gd_sum = gd_result.get("checksum")
        var vg_sum = vg_result.get("checksum")
        var checksums_match = gd_sum == vg_sum
        if has_cpp:
            checksums_match = checksums_match and gd_sum == cpp_result.get("checksum")
        if not checksums_match:
            push_warning("Checksum mismatch detected; results are not comparable.")
            continue

        var gd_us = float(gd_result.get("elapsed_us", 0))
        var vg_us = float(vg_result.get("elapsed_us", 0))
        var cpp_us = INF
        if has_cpp:
            cpp_us = float(cpp_result.get("elapsed_us", 0))

        var fastest = "GDScript"
        var fastest_us = gd_us
        if vg_us < fastest_us:
            fastest = "VisualGasic"
            fastest_us = vg_us
        if has_cpp and cpp_us < fastest_us:
            fastest = "C++"

        var ratio_vg = vg_us / max(1.0, gd_us)
        print("VisualGasic vs GDScript: ", ratio_vg, "x")
        if has_cpp:
            var ratio_cpp = cpp_us / max(1.0, gd_us)
            print("C++ vs GDScript: ", ratio_cpp, "x")
        print("Fastest: ", fastest)

    quit(0)

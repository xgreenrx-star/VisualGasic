extends SceneTree

const ARITH_ITER := 200
const ARITH_INNER := 1000
const ARRAY_ITER := 200
const ARRAY_SIZE := 1000
const STRING_ITER := 100
const STRING_INNER := 400
const BRANCH_ITER := 200
const BRANCH_INNER := 1000

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

func bench_vg_arithmetic(iterations: int, inner: int) -> Dictionary:
    var script = load("res://bench.bas")
    if script == null:
        push_error("Failed to load bench.bas")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var s = node.call("BenchArithmetic", iterations, inner)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": s}

func bench_vg_array_sum(iterations: int, size: int) -> Dictionary:
    var script = load("res://bench.bas")
    if script == null:
        push_error("Failed to load bench.bas")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var s = node.call("BenchArraySum", iterations, size)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": s}

func bench_vg_string_concat(iterations: int, inner: int) -> Dictionary:
    var script = load("res://bench.bas")
    if script == null:
        push_error("Failed to load bench.bas")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var s = node.call("BenchStringConcat", iterations, inner)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": s}

func bench_vg_branch(iterations: int, inner: int) -> Dictionary:
    var script = load("res://bench.bas")
    if script == null:
        push_error("Failed to load bench.bas")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var s = node.call("BenchBranch", iterations, inner)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": s}

func bench_cpp_arithmetic(iterations: int, inner: int) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    var result = bench.run_cpp_arithmetic(iterations, inner)
    bench.queue_free()
    return result

func bench_cpp_array_sum(iterations: int, size: int) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    var result = bench.run_cpp_array_sum(iterations, size)
    bench.queue_free()
    return result

func bench_cpp_string_concat(iterations: int, inner: int) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    var result = bench.run_cpp_string_concat(iterations, inner)
    bench.queue_free()
    return result

func bench_cpp_branch(iterations: int, inner: int) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    var result = bench.run_cpp_branch(iterations, inner)
    bench.queue_free()
    return result

func _init():
    print("Warmup...")
    bench_gd_arithmetic(10, 100)
    bench_vg_arithmetic(10, 100)
    bench_cpp_arithmetic(10, 100)

    print("Running benchmarks...")
    var results = []

    results.append({
        "name": "Arithmetic",
        "gd": bench_gd_arithmetic(ARITH_ITER, ARITH_INNER),
        "vg": bench_vg_arithmetic(ARITH_ITER, ARITH_INNER),
        "cpp": bench_cpp_arithmetic(ARITH_ITER, ARITH_INNER)
    })

    results.append({
        "name": "ArraySum",
        "gd": bench_gd_array_sum(ARRAY_ITER, ARRAY_SIZE),
        "vg": bench_vg_array_sum(ARRAY_ITER, ARRAY_SIZE),
        "cpp": bench_cpp_array_sum(ARRAY_ITER, ARRAY_SIZE)
    })

    results.append({
        "name": "StringConcat",
        "gd": bench_gd_string_concat(STRING_ITER, STRING_INNER),
        "vg": bench_vg_string_concat(STRING_ITER, STRING_INNER),
        "cpp": bench_cpp_string_concat(STRING_ITER, STRING_INNER)
    })

    results.append({
        "name": "Branching",
        "gd": bench_gd_branch(BRANCH_ITER, BRANCH_INNER),
        "vg": bench_vg_branch(BRANCH_ITER, BRANCH_INNER),
        "cpp": bench_cpp_branch(BRANCH_ITER, BRANCH_INNER)
    })

    for r in results:
        print("\n=== ", r["name"], " ===")
        print("GDScript: ", r["gd"])
        print("VisualGasic: ", r["vg"])
        print("C++: ", r["cpp"])

        var gd_sum = r["gd"].get("checksum")
        var vg_sum = r["vg"].get("checksum")
        var cpp_sum = r["cpp"].get("checksum")
        var checksums_match = gd_sum == vg_sum and gd_sum == cpp_sum
        if not checksums_match:
            push_warning("Checksum mismatch detected; results are not comparable.")
            continue

        var gd_us = float(r["gd"].get("elapsed_us", 0))
        var vg_us = float(r["vg"].get("elapsed_us", 0))
        var cpp_us = float(r["cpp"].get("elapsed_us", 0))

        var fastest = "GDScript"
        var fastest_us = gd_us
        if vg_us < fastest_us:
            fastest = "VisualGasic"
            fastest_us = vg_us
        if cpp_us < fastest_us:
            fastest = "C++"

        var ratio_vg = vg_us / max(1.0, gd_us)
        var ratio_cpp = cpp_us / max(1.0, gd_us)
        print("VisualGasic vs GDScript: ", ratio_vg, "x")
        print("C++ vs GDScript: ", ratio_cpp, "x")
        print("Fastest: ", fastest)

    quit(0)

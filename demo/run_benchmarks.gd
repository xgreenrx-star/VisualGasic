extends SceneTree

const ITERATIONS := 200
const INNER := 5000

func bench_gd(iterations: int, inner: int) -> Dictionary:
    var s := 0
    var start := Time.get_ticks_usec()
    for i in iterations:
        for j in inner:
            s += j
    var elapsed := Time.get_ticks_usec() - start
    return {"elapsed_us": elapsed, "checksum": s}

func bench_vg(iterations: int, inner: int) -> Dictionary:
    var script = load("res://bench.bas")
    if script == null:
        push_error("Failed to load bench.bas")
        return {}

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var s = node.call("Bench", iterations, inner)
    var elapsed := Time.get_ticks_usec() - start

    root.remove_child(node)
    node.queue_free()

    return {"elapsed_us": elapsed, "checksum": s}

func bench_cpp(iterations: int, inner: int) -> Dictionary:
    var bench = ClassDB.instantiate("VisualGasicBenchmark")
    if bench == null:
        push_error("Failed to instantiate VisualGasicBenchmark")
        return {}
    var result = bench.run_cpp_benchmark(iterations, inner)
    bench.queue_free()
    return result

func _init():
    print("Warmup...")
    bench_gd(10, 100)
    bench_vg(10, 100)
    bench_cpp(10, 100)

    print("Running benchmarks...")
    var gd = bench_gd(ITERATIONS, INNER)
    var vg = bench_vg(ITERATIONS, INNER)
    var cpp = bench_cpp(ITERATIONS, INNER)

    print("GDScript: ", gd)
    print("VisualGasic: ", vg)
    print("C++: ", cpp)

    if gd.has("elapsed_us") and vg.has("elapsed_us"):
        var ratio_vg = float(vg["elapsed_us"]) / max(1.0, float(gd["elapsed_us"]))
        print("VisualGasic vs GDScript: ", ratio_vg, "x")
    if gd.has("elapsed_us") and cpp.has("elapsed_us"):
        var ratio_cpp = float(cpp["elapsed_us"]) / max(1.0, float(gd["elapsed_us"]))
        print("C++ vs GDScript: ", ratio_cpp, "x")

    quit(0)

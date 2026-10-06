extends RefCounted
class_name DrawBenchConfig

## Shared layout constants — keep identical across GDScript, VG, and C++ workloads.

const GRID_COLS := 50
const CELL := 8
const SPRITE_SIZE := 8
const CIRCLE_RADIUS := 3.0
const LINE_WIDTH := 1.0

const FILL_COLOR := Color(0.2, 0.4, 0.9, 1.0)
const OUTLINE_COLOR := Color(0.9, 0.5, 0.1, 1.0)
const LINE_COLOR := Color(0.1, 0.8, 0.3, 1.0)
const CIRCLE_COLOR := Color(0.8, 0.2, 0.6, 1.0)

const MOVING_OBJECT_COUNT := 500
const MOVING_FRAME_COUNT := 120
const MOVING_WARMUP_FRAMES := 10

static func workload_counts() -> Dictionary:
	return {
		"FilledRects": 2500,
		"OutlineRects": 2500,
		"Lines": 2000,
		"Circles": 1500,
		"Sprites": 2000,
		"Polylines": 800,
		"Mixed": 2500,
		"VectorCanvasUniformRects": 2500,
	}


static func result_error(entry: Dictionary) -> String:
	var lanes: Array[Dictionary] = [
		entry.get("gd", {}), entry.get("vg", {}), entry.get("cpp", {}),
	]
	for lane in lanes:
		if not lane.has("checksum") or not lane.has("elapsed_us"):
			return "Missing benchmark data"
		if lane["elapsed_us"] < 0:
			return "Negative benchmark timing"
	if lanes[0]["checksum"] != lanes[1]["checksum"] or lanes[0]["checksum"] != lanes[2]["checksum"]:
		return "Checksum mismatch"
	if str(entry.get("name", "")).begins_with("Moving"):
		for lane in lanes:
			if lane.get("frames", 0) != MOVING_FRAME_COUNT:
				return "Incorrect measured frame count"
	return ""

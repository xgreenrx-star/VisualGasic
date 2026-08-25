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
	}

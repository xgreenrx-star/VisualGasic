extends RefCounted
class_name DrawBenchWorkloads

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")

static func grid_xy(index: int) -> Vector2:
	var cols := DrawBenchConfig.GRID_COLS
	var cell := float(DrawBenchConfig.CELL)
	return Vector2(float(index % cols) * cell, float(index / cols) * cell)


static func filled_rects(canvas: CanvasItem, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.FILL_COLOR
	for i in count:
		var p := grid_xy(i)
		canvas.draw_rect(Rect2(p.x, p.y, cell, cell), color, true)
		cs += int(p.x) + int(p.y) + DrawBenchConfig.CELL
	return cs


static func outline_rects(canvas: CanvasItem, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.OUTLINE_COLOR
	for i in count:
		var p := grid_xy(i)
		canvas.draw_rect(Rect2(p.x, p.y, cell, cell), color, false)
		cs += int(p.x) + int(p.y) + DrawBenchConfig.CELL
	return cs


static func lines(canvas: CanvasItem, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.LINE_COLOR
	var width := DrawBenchConfig.LINE_WIDTH
	for i in count:
		var p := grid_xy(i)
		canvas.draw_line(p, p + Vector2(cell, cell * 0.5), color, width)
		cs += int(p.x) + int(p.y) + DrawBenchConfig.CELL
	return cs


static func circles(canvas: CanvasItem, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.CIRCLE_COLOR
	var radius := DrawBenchConfig.CIRCLE_RADIUS
	for i in count:
		var p := grid_xy(i)
		canvas.draw_circle(p + Vector2(cell * 0.5, cell * 0.5), radius, color)
		cs += int(p.x) + int(p.y) + int(radius)
	return cs


static func sprites(canvas: CanvasItem, texture: Texture2D, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var size := float(DrawBenchConfig.SPRITE_SIZE)
	for i in count:
		var p := grid_xy(i)
		canvas.draw_texture_rect(texture, Rect2(p.x, p.y, size, size), false)
		cs += int(p.x) + int(p.y) + DrawBenchConfig.SPRITE_SIZE
	return cs


static func polylines(canvas: CanvasItem, count: int) -> int:
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.LINE_COLOR
	var width := DrawBenchConfig.LINE_WIDTH
	for i in count:
		var p := grid_xy(i)
		var pts := PackedVector2Array([
			p,
			p + Vector2(cell, 0),
			p + Vector2(cell, cell),
			p + Vector2(0, cell),
			p,
		])
		canvas.draw_polyline(pts, color, width)
		cs += int(p.x) + int(p.y) + DrawBenchConfig.CELL
	return cs


static func mixed(canvas: CanvasItem, texture: Texture2D, count: int) -> int:
	var cs := 0
	cs += filled_rects(canvas, count)
	cs += lines(canvas, count)
	cs += circles(canvas, count / 2)
	cs += sprites(canvas, texture, count / 2)
	return cs


static func run_workload(canvas: CanvasItem, workload: String, count: int, texture: Texture2D = null) -> int:
	match workload:
		"FilledRects":
			return filled_rects(canvas, count)
		"OutlineRects":
			return outline_rects(canvas, count)
		"Lines":
			return lines(canvas, count)
		"Circles":
			return circles(canvas, count)
		"Sprites":
			return sprites(canvas, texture, count)
		"Polylines":
			return polylines(canvas, count)
		"Mixed":
			return mixed(canvas, texture, count)
		_:
			push_error("Unknown draw workload: " + workload)
			return 0

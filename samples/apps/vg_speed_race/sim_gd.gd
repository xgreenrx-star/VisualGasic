extends Node2D
## GDScript twin of sim_vg.vg — identical particle integrate math.
## Each particle runs SUBSTEPS IntegrateOne calls on locals between array
## loads/stores so the call-path difference is visible (matches vm_gap t_call).

const SUBSTEPS := 24

var workload_mode: int = 0
var count: int = 0
var mode_calls: bool = true
var w: float = 480.0
var h: float = 480.0
var px: Array = []
var py: Array = []
var vx: Array = []
var vy: Array = []
var data_array: Array = []
var data_keys: Array = []
var data_dict: Dictionary = {}
var last_usec: int = 0
var last_checksum: float = 0.0
var dot_color: Color = Color(0.35, 0.75, 1.0, 0.85)
var dirty: bool = true

func integrate_one(x: float, v: float, dt: float) -> float:
	return x + v * dt

func increment_one(value: int) -> int:
	return value + 1

func select_workload(mode: int) -> void:
	workload_mode = mode

func reset(n: int, width: float, height: float, use_calls: bool) -> void:
	count = n
	w = width
	h = height
	mode_calls = use_calls
	px.resize(n)
	py.resize(n)
	vx.resize(n)
	vy.resize(n)
	data_array.resize(n)
	data_keys.resize(n)
	data_dict.clear()
	for i in n:
		var a := float(i) * 0.0174533
		px[i] = width * 0.5 + cos(a) * (40.0 + float(i % 97))
		py[i] = height * 0.5 + sin(a) * (40.0 + float(i % 73))
		vx[i] = cos(a * 1.3) * (40.0 + float(i % 29))
		vy[i] = sin(a * 1.7) * (40.0 + float(i % 31))
		data_array[i] = i
		data_keys[i] = str(i)
		data_dict[data_keys[i]] = i
	dirty = true
	queue_redraw()

func step(dt: float) -> float:
	var t0 := Time.get_ticks_usec()
	var sum := 0.0
	var sub_dt := dt / float(SUBSTEPS)
	if workload_mode == 0:
		if mode_calls:
			for i in count:
				var x: float = float(px[i])
				var y: float = float(py[i])
				var xv: float = float(vx[i])
				var yv: float = float(vy[i])
				for _s in SUBSTEPS:
					x = integrate_one(x, xv, sub_dt)
					y = integrate_one(y, yv, sub_dt)
				if x < 0.0:
					x = -x
					xv = -xv
				elif x > w:
					x = w - (x - w)
					xv = -xv
				if y < 0.0:
					y = -y
					yv = -yv
				elif y > h:
					y = h - (y - h)
					yv = -yv
				px[i] = x
				py[i] = y
				vx[i] = xv
				vy[i] = yv
				sum += x + y
		else:
			for i in count:
				var x: float = float(px[i])
				var y: float = float(py[i])
				var xv: float = float(vx[i])
				var yv: float = float(vy[i])
				for _s in SUBSTEPS:
					x = x + xv * sub_dt
					y = y + yv * sub_dt
				if x < 0.0:
					x = -x
					xv = -xv
				elif x > w:
					x = w - (x - w)
					xv = -xv
				if y < 0.0:
					y = -y
					yv = -yv
				elif y > h:
					y = h - (y - h)
					yv = -yv
				px[i] = x
				py[i] = y
				vx[i] = xv
				vy[i] = yv
				sum += x + y
	else:
		match workload_mode:
			1:
				for _i in count:
					for j in 32:
						sum += (j * 3) - 7
			2:
				for _repeat in 16:
					for i in count:
						sum += int(data_array[i])
			3:
				for _repeat in 4:
					for i in count:
						sum += int(data_dict.get(data_keys[i], 0))
			4:
				for _i in count:
					var flag := 0
					for j in 32:
						if flag == 0:
							sum += j
							flag = 1
						else:
							sum -= j
							flag = 0
			5:
				var text := ""
				for _i in count:
					text = ""
					for _j in 32:
						text += "x"
				sum = text.length()
			6:
				for _i in count:
					for _j in SUBSTEPS:
						if mode_calls:
							sum = increment_one(int(sum))
						else:
							sum += 1
	last_usec = int(Time.get_ticks_usec() - t0)
	last_checksum = sum
	dirty = true
	return sum

## Burn wall-clock budget inside GDScript (one host call → many ticks).
func run_budget(budget_usec: int, dt: float) -> int:
	var t0 := Time.get_ticks_usec()
	var t_end := t0 + budget_usec
	var ticks := 0
	while true:
		step(dt)
		ticks += 1
		if Time.get_ticks_usec() >= t_end:
			break
	# Average µs/tick across the whole budget slice.
	last_usec = int(float(Time.get_ticks_usec() - t0) / float(maxi(ticks, 1)))
	dirty = true
	return ticks

func _draw() -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.09, 0.12), true)
	if workload_mode != 0:
		draw_rect(Rect2(32, h * 0.5 - 12, clampf(float(last_usec) / 1000.0, 4.0, w - 64), 24), dot_color)
		dirty = false
		return
	var r := 2.0
	for i in count:
		draw_circle(Vector2(float(px[i]), float(py[i])), r, dot_color)
	dirty = false

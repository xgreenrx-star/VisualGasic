extends Node
var g: float
var gs: String
var gb: bool
var d: Dictionary
var gacc: float
var gi: int
var gk: int
func _ready():
	g = 1.5; gs = "talk"; d = {}; d["k"] = 2.5
func empty_fn() -> float: return 0
func t_global(n:int)->float:
	var s := 0.0
	for i in range(1,n+1): s = s + g
	return s
func t_gint(n:int)->int:
	gi = 0
	for i in range(1,n+1): gi = gi + 1
	return gi
func t_gint_if(n:int)->int:
	gk = 0
	for i in range(1, n + 1):
		if i > 0:
			gk = gk + 2
	return gk
func t_local(n:int)->float:
	var s := 0.0; var h := 1.5
	for i in range(1,n+1): s = s + h
	return s
func t_getx(n:int)->float:
	var s := 0.0; var p = Vector2(3,4)
	for i in range(1,n+1): s = s + p.x
	return s
func t_getx_typed(n:int)->float:
	var s := 0.0; var p := Vector2(3,4)
	for i in range(1,n+1): s = s + p.x
	return s
func t_sety(n:int)->float:
	var p = Vector2(3,4)
	for i in range(1,n+1): p.y = p.y + 1
	return p.y
func t_dict(n:int)->float:
	var s := 0.0
	for i in range(1,n+1): s = s + d["k"]
	return s
func t_streq(n:int)->int:
	var c := 0
	for i in range(1,n+1):
		if gs == "talk" and not gb: c = c + 1
	return c
func t_call(n:int)->float:
	var s := 0.0
	for i in range(1,n+1): s = s + empty_fn()
	return s
func blend3(a: float, b: float, t: float) -> float: return a + (b - a) * t
func t_call_args(n:int)->float:
	var s := 0.0
	for i in range(1,n+1): s = blend3(s, i, 0.25)
	return s
# GDScript has no ByRef scalars; a two-element Array is its out-parameter idiom.
func polar_step(p: Array, k: float) -> void:
	var t: float = p[0]
	p[0] = p[0] * 0.8 - p[1] * k
	p[1] = p[1] * 0.8 + t * k
func t_call_byref(n:int)->float:
	var p := [1.0, 0.0]
	for i in range(1,n+1): polar_step(p, 0.6)
	return p[0] + p[1]
func add_acc(v: float) -> void: gacc = gacc + v
func t_call_global(n:int)->float:
	gacc = 0.0
	for i in range(1,n+1): add_acc(0.5)
	return gacc
func tag_len(i: int) -> int: return gs.length() + i
func t_call_host(n:int)->int:
	var c := 0
	for i in range(1,n+1): c = c + tag_len(i)
	return c
func t_vec(n:int):
	var v = Vector2(0,0)
	for i in range(1,n+1): v = v + Vector2(1,2)*0.5
	return v
func t_sin(n:int)->float:
	var s := 0.0
	for i in range(1,n+1): s = s + sin(i*0.01)*0.5
	return s
func t_branch(n:int)->int:
	var c := 0
	var k
	for i in range(1,n+1):
		k = i % 7
		if k == 0 or k == 3:
			c = c + 2
		elif k > 4 and not (i % 2 == 0):
			c = c - 1
		else:
			@warning_ignore("integer_division")
			c = c + (i / 4) % 3
	return c
func t_poly(n:int):
	var x
	var acc = 0.0
	for i in range(1,n+1):
		x = i * 0.001
		acc = acc + ((x * 0.5 - 1.25) * x + 3) * x
	return acc

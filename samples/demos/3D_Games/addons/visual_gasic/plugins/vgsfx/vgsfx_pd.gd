# VGSFX PureData primitives.
#
# Port of vendor/bfxr2/js/audio/puredata.js (MIT (c) Stephen Lavelle).
# All functions operate on PackedFloat32Array buffers of equal length.
@tool
class_name VGSFXPD
extends RefCounted

const SAMPLE_RATE: int = 44100
const CONVERSION_FACTOR: float = TAU / float(SAMPLE_RATE)
const COSTABLESIZE: int = 2048

static var _costable: PackedFloat32Array = PackedFloat32Array()
static var _stream_length: int = 0


static func _ensure_table() -> void:
	if _costable.size() == COSTABLESIZE + 1:
		return
	_costable.resize(COSTABLESIZE + 1)
	for i in range(COSTABLESIZE):
		_costable[i] = cos(TAU * float(i) / float(COSTABLESIZE))
	_costable[0] = 1.0
	_costable[COSTABLESIZE] = 1.0
	_costable[COSTABLESIZE / 4] = 0.0
	_costable[3 * COSTABLESIZE / 4] = 0.0
	_costable[COSTABLESIZE / 2] = -1.0


static func set_stream_length_seconds(seconds: float) -> void:
	_stream_length = int(seconds * float(SAMPLE_RATE))


static func get_stream_length_samples() -> int:
	return _stream_length


# Constant signal of given value.
static func pd_c(value: float) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(_stream_length)
	r.fill(value)
	return r


# Build a buffer by sampling f(t) at each time index. f is a Callable taking float→float.
static func pd_fn(f: Callable) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(_stream_length)
	var sr_inv: float = 1.0 / float(SAMPLE_RATE)
	for i in range(_stream_length):
		r[i] = float(f.call(float(i) * sr_inv))
	return r


static func pd_noise() -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(_stream_length)
	for i in range(_stream_length):
		r[i] = randf() * 2.0 - 1.0
	return r


static func _zip(a: PackedFloat32Array, b: PackedFloat32Array, op: int) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size())
	var r := PackedFloat32Array()
	r.resize(n)
	for i in range(n):
		var av: float = a[i] if i < a.size() else 0.0
		var bv: float = b[i] if i < b.size() else 0.0
		match op:
			0: r[i] = av * bv
			1: r[i] = av / bv if bv != 0.0 else 0.0
			2: r[i] = av + bv
	return r


static func pd_mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	return _zip(a, b, 0)


static func pd_div(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	return _zip(a, b, 1)


static func pd_add(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	return _zip(a, b, 2)


static func pd_polyadd(buffers: Array) -> PackedFloat32Array:
	if buffers.is_empty():
		return PackedFloat32Array()
	var n: int = buffers[0].size()
	for b in buffers:
		n = max(n, b.size())
	var r := PackedFloat32Array()
	r.resize(n)
	for i in range(n):
		var s := 0.0
		for buf in buffers:
			if i < buf.size():
				s += buf[i]
		r[i] = s
	return r


static func pd_clip(buffer: PackedFloat32Array, lo: PackedFloat32Array, hi: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	for i in range(n):
		r[i] = max(lo[i], min(buffer[i], hi[i]))
	return r


static func pd_abs(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	for i in range(n):
		r[i] = absf(buffer[i])
	return r


static func pd_sqrt(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	for i in range(n):
		r[i] = sqrt(maxf(buffer[i], 0.0))
	return r


# Cosine oscillator. freq_signal is per-sample frequency in Hz.
static func pd_osc(freq_signal: PackedFloat32Array) -> PackedFloat32Array:
	_ensure_table()
	var n: int = freq_signal.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var phase := 0.0
	var conv: float = CONVERSION_FACTOR
	for i in range(n):
		phase += freq_signal[i] * conv
		while phase >= PI:
			phase -= TAU
		while phase < -PI:
			phase += TAU
		var idxf: float = ((phase + PI) / TAU) * float(COSTABLESIZE)
		var idx1: int = int(idxf) % COSTABLESIZE
		var idx2: int = (idx1 + 1) % COSTABLESIZE
		var frac: float = idxf - float(int(idxf))
		var f1: float = _costable[idx1]
		var f2: float = _costable[idx2]
		r[i] = f1 + frac * (f2 - f1)
	return r


# 1-pole lowpass filter (lop~ in pd).
static func pd_lop(buffer: PackedFloat32Array, freq_signal: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var last: float = buffer[0] if n > 0 else 0.0
	for i in range(n):
		var coef: float = freq_signal[i] * CONVERSION_FACTOR
		coef = clampf(coef, 0.0, 1.0)
		last = coef * buffer[i] + (1.0 - coef) * last
		r[i] = last
	return r


# 1-pole highpass filter (hip~).
static func pd_hip(buffer: PackedFloat32Array, freq_signal: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var last: float = buffer[0] if n > 0 else 0.0
	for i in range(n):
		var f: float = freq_signal[i]
		var coef: float = 1.0 - f * CONVERSION_FACTOR
		coef = clampf(coef, 0.0, 1.0)
		if coef < 1.0:
			var normal := 0.5 * (1.0 + coef)
			var cur: float = buffer[i] + coef * last
			r[i] = normal * (cur - last)
			last = cur
		else:
			r[i] = buffer[i]
	return r


static func _sigbp_qcos(f: float) -> float:
	if f >= -0.5 * PI and f <= 0.5 * PI:
		var g: float = f * f
		return ((g * g * g * (-1.0 / 720.0) + g * g * (1.0 / 24.0)) - g * 0.5) + 1.0
	return 0.0


# 2-pole bandpass filter (bp~).
static func pd_bp(buffer: PackedFloat32Array, freq_signal: PackedFloat32Array, q_signal: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var last: float = buffer[0] if n > 0 else 0.0
	var prev: float = last
	for i in range(n):
		var f: float = freq_signal[i]
		var q: float = q_signal[i]
		if f < 0.001:
			f = 10.0
		if q < 0.0:
			q = 0.0
		var omega: float = f * TAU / float(SAMPLE_RATE)
		var oneminusr: float = 1.0 if q < 0.001 else omega / q
		oneminusr = minf(oneminusr, 1.0)
		var rr: float = 1.0 - oneminusr
		var coef1: float = 2.0 * _sigbp_qcos(omega) * rr
		var coef2: float = -rr * rr
		var gain: float = 2.0 * oneminusr * (oneminusr + rr * omega)
		var input: float = buffer[i]
		var output: float = input + coef1 * last + coef2 * prev
		r[i] = gain * output
		prev = last
		last = output
	return r


# Voltage-controlled bandpass/lowpass filter (vcf~).
static func pd_vcf(buffer: PackedFloat32Array, res_freq_signal: PackedFloat32Array, q_signal: PackedFloat32Array) -> PackedFloat32Array:
	_ensure_table()
	var n: int = buffer.size()
	var r := PackedFloat32Array()
	r.resize(n)
	var re := 0.0
	var im := 0.0
	for i in range(n):
		var q: float = q_signal[i]
		var qinv: float = 1.0 / q if q > 0.0 else 0.0
		var ampcorrect: float = 2.0 - 2.0 / (q + 2.0)
		var cf: float = maxf(res_freq_signal[i] * CONVERSION_FACTOR, 0.0)
		var rr: float = (1.0 - cf * qinv) if qinv > 0.0 else 0.0
		rr = maxf(rr, 0.0)
		var oneminusr: float = 1.0 - rr
		var cfindx: float = cf * (float(COSTABLESIZE) / TAU)
		var idx1: int = int(cfindx) % COSTABLESIZE
		if idx1 < 0:
			idx1 += COSTABLESIZE
		var idx2: int = (idx1 + 1) % COSTABLESIZE
		var frac: float = cfindx - float(int(cfindx))
		var f1: float = _costable[idx1]
		var f2: float = _costable[idx2]
		var coefr: float = rr * (f1 + frac * (f2 - f1))
		var qidx: int = (idx1 - COSTABLESIZE / 4) % COSTABLESIZE
		if qidx < 0:
			qidx += COSTABLESIZE
		var qidx2: int = (qidx + 1) % COSTABLESIZE
		var qf1: float = _costable[qidx]
		var qf2: float = _costable[qidx2]
		var coefi: float = rr * (qf1 + frac * (qf2 - qf1))
		var input_sample: float = buffer[i]
		var re2: float = re
		re = ampcorrect * oneminusr * input_sample + coefr * re2 - coefi * im
		im = coefi * re2 + coefr * im
		if absf(re) < 1e-10:
			re = 0.0
		if absf(im) < 1e-10:
			im = 0.0
		r[i] = re
	return r


# === Curve helpers (from globals.js) ===

# Returns Callable(x) -> float that's the "step" envelope shape.
static func make_step(n: float) -> Callable:
	return func(x: float) -> float:
		if x <= 0.0 or x >= 1.0:
			return 0.0
		return ((x * x * x) * n - x * n) * (1.0 - x) * (-1.5)


# Resize a Callable so its input range [a1,a2] maps to [b1,b2].
static func resize_fn(fn: Callable, a1: float, a2: float, b1: float, b2: float) -> Callable:
	return func(y: float) -> float:
		return float(fn.call((y - b1) / (b2 - b1) * (a2 - a1) + a1))


# Sum a list of Callables into one.
static func add_fns(fns: Array) -> Callable:
	return func(x: float) -> float:
		var s := 0.0
		for fn in fns:
			s += float(fn.call(x))
		return s

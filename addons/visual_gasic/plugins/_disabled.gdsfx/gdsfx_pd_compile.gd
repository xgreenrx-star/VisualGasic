# GDSFX PureData mini-interpreter.
#
# Parses bfxr2's pure-data ".pd canvas" text format and executes the resulting
# DSP graph against an input "envelope_signal" buffer. Compatible with the
# subset of objects used by Footsteppr terrain modules:
#   inlet~, outlet~, *~, /~, +~, sig~, msg, switch~, vcf~, hip~, lop~,
#   noise~, clip~, osc~, bp~, sqrt~
#
# Port of vendor/bfxr2/js/audio/puredata_parser.js (MIT (c) Stephen Lavelle).
@tool
class_name GDSFXPDCompile
extends RefCounted

const GDSFXPD_ := preload("res://addons/visual_gasic/plugins/gdsfx/gdsfx_pd.gd")

# fn_name → {input_slots, parameter_indices, op}
# op identifies which GDSFXPD function to dispatch to.
const FUNCTION_INFO := {
	"outlet~":  {"input_slots": 1, "parameter_indices": [],     "op": "outlet"},
	"inlet~":   {"input_slots": 0, "parameter_indices": [],     "op": "inlet"},
	"*~":       {"input_slots": 2, "parameter_indices": [1],    "op": "mul"},
	"/~":       {"input_slots": 2, "parameter_indices": [1],    "op": "div"},
	"+~":       {"input_slots": 2, "parameter_indices": [1],    "op": "add"},
	"sig~":     {"input_slots": 1, "parameter_indices": [0],    "op": "c"},
	"vcf~":     {"input_slots": 3, "parameter_indices": [2],    "op": "vcf"},
	"hip~":     {"input_slots": 2, "parameter_indices": [1],    "op": "hip"},
	"lop~":     {"input_slots": 2, "parameter_indices": [1],    "op": "lop"},
	"noise~":   {"input_slots": 0, "parameter_indices": [],     "op": "noise"},
	"clip~":    {"input_slots": 3, "parameter_indices": [1, 2], "op": "clip"},
	"osc~":     {"input_slots": 1, "parameter_indices": [0],    "op": "osc"},
	"bp~":      {"input_slots": 3, "parameter_indices": [1, 2], "op": "bp"},
	"sqrt~":    {"input_slots": 1, "parameter_indices": [0],    "op": "sqrt"},
	# Stubs (not part of any audio path in our terrain modules):
	"switch~":  {"input_slots": 0, "parameter_indices": [],     "op": "noop"},
	"msg":      {"input_slots": 1, "parameter_indices": [0],    "op": "c"},
}


# Compiles the source into a Callable: (envelope_signal) -> PackedFloat32Array.
static func compile(src: String) -> Callable:
	src = src.replace(";", "").replace("\r", "")
	var lines := src.split("\n", false)
	var function_calls: Array = []  # Array of [name, arg1, arg2, ...]
	var connections: Array = []     # Array of {from_ob, from_slot, to_ob, to_slot}
	for line in lines:
		var toks: PackedStringArray = (line as String).split(" ", false)
		if toks.size() < 2:
			continue
		match toks[1]:
			"obj":
				if toks.size() >= 5:
					function_calls.append(_slice_str(toks, 4))
			"msg":
				if toks.size() >= 5:
					function_calls.append(["sig~", toks[4]])
			"connect":
				if toks.size() >= 6:
					connections.append({
						"from_ob": int(toks[2]),
						"from_slot": int(toks[3]),
						"to_ob": int(toks[4]),
						"to_slot": int(toks[5]),
					})

	var output_idx: int = -1
	for i in range(function_calls.size()):
		if String(function_calls[i][0]) == "outlet~":
			output_idx = i
			break
	if output_idx == -1:
		push_error("GDSFXPDCompile: no outlet~ found")
		return Callable()

	var program := _build_program(function_calls, connections, output_idx)
	return func(envelope_signal: PackedFloat32Array) -> PackedFloat32Array:
		return _run_program(program, envelope_signal)


# Produces an ordered list of node-execution steps. Each step is:
#   {"node_idx": int, "op": String, "inputs": Array of Array of int (slot → list of source idx),
#    "params": Array (indexed by slot, holds float param or null)}
# Steps are emitted in dependency-first order (leaves first).
static func _build_program(function_calls: Array, connections: Array, output_node_idx: int) -> Array:
	var name_dict := {}
	var counter := [0]
	_assign_names(function_calls, connections, output_node_idx, name_dict, counter)

	# Walk every node we named, in topological order (highest idx → lowest idx).
	# Build steps keyed by node_id.
	var ordered_ids: Array = name_dict.keys()
	ordered_ids.sort_custom(func(a, b): return name_dict[a] > name_dict[b])

	var steps: Array = []
	for nid_v in ordered_ids:
		var nid: int = nid_v
		var call_arr: Array = function_calls[nid]
		var nname: String = String(call_arr[0])
		if not FUNCTION_INFO.has(nname):
			push_error("GDSFXPDCompile: unknown pd object '%s'" % nname)
			continue
		var info: Dictionary = FUNCTION_INFO[nname]
		var slot_count: int = int(info["input_slots"])
		var slot_inputs: Array = []
		for s in range(slot_count):
			slot_inputs.append([])
		# Find connections targeting this node.
		for c in connections:
			if int(c["to_ob"]) == nid and int(c["to_slot"]) < slot_count:
				slot_inputs[int(c["to_slot"])].append(name_dict[int(c["from_ob"])])
		# Constructor arguments → positional slot params.
		var ctor_args: Array = call_arr.slice(1)
		var params := []
		params.resize(slot_count)
		for s in range(slot_count):
			params[s] = null
		var pidxs: Array = info["parameter_indices"]
		# Special-case vcf~ with two ctor args → [null, a, b].
		if nname == "vcf~" and ctor_args.size() == 2:
			params = [null, _to_float(ctor_args[0]), _to_float(ctor_args[1])]
		else:
			for i in range(min(ctor_args.size(), pidxs.size())):
				var slot_i: int = int(pidxs[i])
				if slot_i >= 0 and slot_i < slot_count:
					params[slot_i] = _to_float(ctor_args[i])
		steps.append({
			"node_idx": int(name_dict[nid]),
			"op": String(info["op"]),
			"name": nname,
			"inputs": slot_inputs,  # list of node_idx per slot
			"params": params,
		})
	return steps


static func _assign_names(function_calls: Array, connections: Array, cur_node_idx: int, name_dict: Dictionary, counter: Array) -> void:
	if name_dict.has(cur_node_idx):
		return
	name_dict[cur_node_idx] = counter[0]
	counter[0] += 1
	for c in connections:
		if int(c["to_ob"]) == cur_node_idx:
			_assign_names(function_calls, connections, int(c["from_ob"]), name_dict, counter)


# Execute the compiled program. Each step writes into a slot keyed by node_idx
# in a Dictionary that maps node_idx → PackedFloat32Array.
static func _run_program(program: Array, envelope_signal: PackedFloat32Array) -> PackedFloat32Array:
	var slots: Dictionary = {}
	for step in program:
		var op: String = step["op"]
		var node_idx: int = step["node_idx"]
		var inputs: Array = step["inputs"]
		var params: Array = step["params"]
		var args: Array = []
		for slot in range(inputs.size()):
			var srcs: Array = inputs[slot]
			if srcs.is_empty():
				if params[slot] == null:
					args.append(GDSFXPD_.pd_c(0.0))
				else:
					args.append(GDSFXPD_.pd_c(float(params[slot])))
			elif srcs.size() == 1:
				args.append(slots.get(int(srcs[0]), GDSFXPD_.pd_c(0.0)))
			else:
				var bufs := []
				for s in srcs:
					bufs.append(slots.get(int(s), GDSFXPD_.pd_c(0.0)))
				args.append(GDSFXPD_.pd_polyadd(bufs))

		var result: PackedFloat32Array
		match op:
			"inlet":   result = envelope_signal
			"outlet":  result = args[0]
			"mul":     result = GDSFXPD_.pd_mul(args[0], args[1])
			"div":     result = GDSFXPD_.pd_div(args[0], args[1])
			"add":     result = GDSFXPD_.pd_add(args[0], args[1])
			"c":       result = args[0]
			"noise":   result = GDSFXPD_.pd_noise()
			"osc":     result = GDSFXPD_.pd_osc(args[0])
			"clip":    result = GDSFXPD_.pd_clip(args[0], args[1], args[2])
			"sqrt":    result = GDSFXPD_.pd_sqrt(args[0])
			"lop":     result = GDSFXPD_.pd_lop(args[0], args[1])
			"hip":     result = GDSFXPD_.pd_hip(args[0], args[1])
			"bp":      result = GDSFXPD_.pd_bp(args[0], args[1], args[2])
			"vcf":     result = GDSFXPD_.pd_vcf(args[0], args[1], args[2])
			"noop":    result = GDSFXPD_.pd_c(0.0)
			_:
				push_error("GDSFXPDCompile: unknown op '%s'" % op)
				result = GDSFXPD_.pd_c(0.0)
		slots[node_idx] = result

	# Output node always has node_idx == 0 (assigned first).
	return slots.get(0, PackedFloat32Array())


static func _slice_str(toks: PackedStringArray, start: int) -> Array:
	var r: Array = []
	for i in range(start, toks.size()):
		r.append(toks[i])
	return r


static func _to_float(v) -> float:
	return float(String(v))

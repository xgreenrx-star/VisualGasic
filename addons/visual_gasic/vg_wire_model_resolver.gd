@tool
extends RefCounted
## Labeled 3D wire models in Data: vertex count, edge count, xyz verts, edge pairs.
## Same layout as CarOncoming / CactusModel / SignModel in Vector Fathom.

const MAX_VERTS := 64
const MAX_EDGES := 128

static var _label_re: RegEx
static var _data_re: RegEx


static func _label_rx() -> RegEx:
	if _label_re == null:
		_label_re = RegEx.new()
		_label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	return _label_re


static func _data_rx() -> RegEx:
	if _data_re == null:
		_data_re = RegEx.new()
		_data_re.compile("^\\s*Data\\s+(.+)$")
	return _data_re


static func resolve_at_line(source: String, caret_line: int) -> Dictionary:
	if source.is_empty() or caret_line < 0:
		return {}
	var lines := source.split("\n")
	if caret_line >= lines.size():
		return {}
	var label_line := _find_enclosing_label_line(lines, caret_line)
	if label_line < 0:
		return {}
	var block := _parse_block(lines, label_line)
	if block.is_empty():
		return {}
	if caret_line < label_line or caret_line > int(block["end_line"]):
		return {}
	return block


static func enumerate_blocks(source: String) -> Array:
	var lines := source.split("\n")
	var out: Array = []
	var i := 0
	while i < lines.size():
		if _label_rx().search(lines[i]) != null:
			var block := _parse_block(lines, i)
			if not block.is_empty():
				out.append({
					"label": block["label"],
					"label_line": block["label_line"],
					"end_line": block["end_line"],
					"kind": "wire",
				})
				i = int(block["end_line"]) + 1
				continue
		i += 1
	return out


static func _find_enclosing_label_line(lines: PackedStringArray, caret_line: int) -> int:
	for i in range(mini(caret_line, lines.size() - 1), -1, -1):
		if _label_rx().search(lines[i]) != null:
			return i
	return -1


static func _parse_block(lines: PackedStringArray, label_line: int) -> Dictionary:
	var label_m := _label_rx().search(lines[label_line])
	if label_m == null:
		return {}
	var header_line := _next_data_line(lines, label_line + 1)
	if header_line < 0:
		return {}
	var header_nums := _numbers_on_data_line(lines[header_line])
	if header_nums.size() != 2:
		return {}
	var nv := int(header_nums[0])
	var ne := int(header_nums[1])
	if nv < 2 or nv > MAX_VERTS or ne < 1 or ne > MAX_EDGES:
		return {}
	var need := nv * 3 + ne * 2
	var nums: Array = []
	var num_lines: Array = []
	var end_line := header_line
	var i := header_line + 1
	while i < lines.size() and nums.size() < need:
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("'"):
			i += 1
			continue
		if _label_rx().search(lines[i]) != null:
			break
		if _data_rx().search(lines[i]) == null:
			break
		var row := _numbers_on_data_line(lines[i])
		if row.is_empty():
			break
		for n in row:
			nums.append(n)
			num_lines.append(i)
		end_line = i
		i += 1
	if nums.size() != need:
		return {}
	var verts: PackedVector3Array = PackedVector3Array()
	for v in nv:
		var base := v * 3
		verts.append(Vector3(float(nums[base]), float(nums[base + 1]), float(nums[base + 2])))
	var vert_lines := PackedInt32Array()
	for v in nv:
		var base_i := v * 3
		var same := int(num_lines[base_i]) == int(num_lines[base_i + 1]) and int(num_lines[base_i]) == int(num_lines[base_i + 2])
		var only_three := true
		if same:
			for k in num_lines.size():
				if int(num_lines[k]) == int(num_lines[base_i]) and (k < base_i or k > base_i + 2):
					only_three = false
		if same and only_three:
			vert_lines.append(int(num_lines[base_i]))
		else:
			vert_lines.append(-1)
	var edges: PackedInt32Array = PackedInt32Array()
	var edge_base := nv * 3
	for e in ne:
		var a := int(nums[edge_base + e * 2])
		var b := int(nums[edge_base + e * 2 + 1])
		if a < 0 or b < 0 or a >= nv or b >= nv:
			return {}
		edges.append(a)
		edges.append(b)
	return {
		"kind": "wire",
		"label": label_m.get_string(1),
		"label_line": label_line,
		"header_line": header_line,
		"data_start_line": header_line,
		"data_end_line": end_line,
		"end_line": end_line,
		"vert_count": nv,
		"edge_count": ne,
		"verts": verts,
		"edges": edges,
		"vert_lines": vert_lines,
	}


static func _next_data_line(lines: PackedStringArray, start: int) -> int:
	for i in range(start, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("'"):
			continue
		if _label_rx().search(lines[i]) != null:
			return -1
		if _data_rx().search(lines[i]) != null:
			return i
		return -1
	return -1


static func _numbers_on_data_line(raw: String) -> Array:
	var dm := _data_rx().search(raw)
	if dm == null:
		return []
	var body := dm.get_string(1)
	var comment := body.find("'")
	if comment >= 0:
		body = body.substr(0, comment)
	var out: Array = []
	for part in body.split(","):
		var token := part.strip_edges().replace(" ", "")
		if token.is_empty():
			continue
		if not token.is_valid_float():
			return []
		out.append(float(token))
	return out

@tool
extends RefCounted
## Write .vgd binary files (see docs/manual/vg_data_format.md).

static var _magic: PackedByteArray = PackedByteArray([0x56, 0x47, 0x44, 0x01])

enum Kind {
	RAW = 0,
	GRID_U8 = 1,
	GRID_U16 = 2,
	GRID_F32 = 3,
}


static func write_grid_u8(abs_path: String, width: int, height: int, cells: PackedByteArray, palette_id: int = 255) -> bool:
	return _write(abs_path, Kind.GRID_U8, width, height, 1, palette_id, cells)


static func write_grid_u16(abs_path: String, width: int, height: int, cells: PackedByteArray, palette_id: int = 255) -> bool:
	return _write(abs_path, Kind.GRID_U16, width, height, 2, palette_id, cells)


static func _write(abs_path: String, kind: int, width: int, height: int, elem_size: int, palette_id: int, payload: PackedByteArray) -> bool:
	var dir_path := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_warning("VgdWriter: cannot write " + abs_path)
		return false
	var stride := width * elem_size
	var header := PackedByteArray()
	header.append_array(_magic)
	header.append(kind & 0xFF)
	header.append(0) # flags
	header.append(0)
	header.append(0)
	header.append_array(_u32_le(width))
	header.append_array(_u32_le(height))
	header.append(elem_size & 0xFF)
	header.append(palette_id & 0xFF)
	header.append(0)
	header.append(0)
	header.append_array(_u32_le(stride))
	header.append_array(_u32_le(payload.size()))
	header.append_array(_u32_le(0)) # crc32
	f.store_buffer(header)
	f.store_buffer(payload)
	f.close()
	return true


static func _u32_le(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF])

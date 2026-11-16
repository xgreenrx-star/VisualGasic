extends RefCounted

# Archived. The live yard mesh is presentation.vg _mesh().
# The landing frame rebuilds every draw. Expanding each segment into a
# screen-space ribbon here keeps that loop out of the Visual Gasic interpreter.
const _CORNERS: Array[Vector2] = [
	Vector2(0, -1), Vector2(0, 1), Vector2(1, 1),
	Vector2(0, -1), Vector2(1, 1), Vector2(1, -1),
]

func build(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	edges: PackedVector3Array,
	edge_colors: PackedColorArray,
	face_material: Material,
	line_material: Material
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, face_material)
	if not edges.is_empty():
		var count := (edges.size() / 2) * 6
		var line_vertices := PackedVector3Array()
		var line_normals := PackedVector3Array()
		var line_colors := PackedColorArray()
		var line_uvs := PackedVector2Array()
		line_vertices.resize(count)
		line_normals.resize(count)
		line_colors.resize(count)
		line_uvs.resize(count)
		var cursor := 0
		var i := 0
		while i < edges.size():
			var direction := edges[i + 1] - edges[i]
			for corner in _CORNERS:
				var index := i + int(corner.x)
				line_vertices[cursor] = edges[index]
				line_normals[cursor] = direction
				line_colors[cursor] = edge_colors[index]
				line_uvs[cursor] = Vector2(corner.y, 0)
				cursor += 1
			i += 2
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = line_vertices
		arrays[Mesh.ARRAY_NORMAL] = line_normals
		arrays[Mesh.ARRAY_COLOR] = line_colors
		arrays[Mesh.ARRAY_TEX_UV] = line_uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, line_material)
	return mesh

extends MeshInstance2D
class_name RippleSurface

## Portal oval projected from the wall. The mesh is a fan from the wall
## center, and UVs are that oval, so the ripple stays on the surface.

func _ready() -> void:
	var sh := load("res://portal_ripple.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat
	visible = false

func SetPortal(pts: Array, t: float) -> void:
	if pts.size() < 4:
		visible = false
		return
	var n := pts.size() - 1
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	vertices.append(pts[0])
	uvs.append(Vector2(0.5, 0.5))
	for i in n:
		vertices.append(pts[i + 1])
		var ang := float(i) / float(n) * TAU
		uvs.append(Vector2(0.5 + cos(ang) * 0.5, 0.5 + sin(ang) * 0.5))
	for i in n:
		var a := 1 + i
		var b := 1 + ((i + 1) % n)
		idx.append(0)
		idx.append(a)
		idx.append(b)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = built
	visible = true
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("ripple_time", t)

func HidePortal() -> void:
	visible = false

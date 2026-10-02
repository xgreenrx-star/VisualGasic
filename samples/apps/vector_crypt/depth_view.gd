extends SubViewportContainer
## DepthView — real 3D pass for Vector Crypt neon walls
##
## Why this exists:
##   Main.vg records triangles into VGVectorCanvas2D, then calls
##   `canvas.BuildDepthMesh(...)`. That returns a Godot ArrayMesh.
##   This node shows that mesh in its own SubViewport with a Camera3D so
##   nearer walls correctly hide farther ones (a depth buffer).
##
## Layering (z_index = -1):
##   DepthView draws BEHIND the 2D canvas HUD / gun / captions.
##
## Main.vg drives us each frame via:
##   depth_view.show_mesh(mesh)
##   depth_view.look(x, y, z, yaw, pitch, focal)

var cam: Camera3D
var mesh_inst: MeshInstance3D
var depth_mat: ShaderMaterial

func _ready() -> void:
	offset_right = 960.0
	offset_bottom = 540.0
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	# Private little 3D world just for the facility mesh.
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.glow_enabled = true
	# Paradox-style: sharp neon cores with a thin bloom band, not fog.
	env.glow_intensity = 1.15
	env.glow_strength = 1.05
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.7
	env.glow_hdr_scale = 1.35
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.55)
	env.set_glow_level(3, 0.7)
	env.set_glow_level(4, 0.45)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.65
	var world := WorldEnvironment.new()
	world.environment = env
	vp.add_child(world)
	cam = Camera3D.new()
	cam.fov = 60.84
	cam.near = 0.05
	cam.far = 90.0
	cam.current = true
	vp.add_child(cam)
	mesh_inst = MeshInstance3D.new()
	depth_mat = ShaderMaterial.new()
	depth_mat.shader = load("res://vector_depth.gdshader")
	mesh_inst.material_override = depth_mat
	vp.add_child(mesh_inst)

## Match the VG first-person camera (yaw around Y, pitch up/down).
func look(x: float, y: float, z: float, yaw: float, pitch: float, focal: float) -> void:
	if cam == null:
		return
	var cp := cos(pitch)
	var forward := Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp)
	# focal is VG's projection constant; convert to a FOV Godot understands.
	cam.fov = rad_to_deg(2.0 * atan(270.0 / focal))
	# look_at() put world +X on the left, so Right turned the view left.
	var right := Vector3(0.0, 1.0, 0.0).cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3(1.0, 0.0, 0.0)
	right = right.normalized()
	var up := forward.cross(right).normalized()
	cam.global_transform = Transform3D(Basis(right, up, -forward), Vector3(x, y, z))

## Swap in the mesh Main just built for this frame (or reuse a cached one).
func show_mesh(mesh: Mesh) -> void:
	if mesh_inst == null:
		return
	mesh_inst.mesh = mesh

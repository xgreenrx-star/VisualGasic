extends SceneTree

var image_saved := false
var frames := 0
var elapsed := 0.0
var material: ShaderMaterial

func _initialize() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/opening_ring_study.gdshader")
	rect.material = material
	root.add_child.call_deferred(rect)
	RenderingServer.frame_post_draw.connect(_capture)

func _process(delta: float) -> bool:
	elapsed += delta
	var frame_time := OS.get_environment("ASH_RING_STUDY_TIME")
	var t := elapsed if frame_time.is_empty() else frame_time.to_float()
	material.set_shader_parameter("travel", smoothstep(0.0, 24.0, t))
	return false

func _capture() -> void:
	if image_saved:
		return
	frames += 1
	if frames < 4:
		return
	var output := OS.get_environment("ASH_RING_STUDY_CAPTURE")
	if output.is_empty():
		return
	image_saved = true
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save ring study: %s" % error)
		quit(1)
	else:
		print("RING_STUDY_CAPTURED: ", output)
		quit()

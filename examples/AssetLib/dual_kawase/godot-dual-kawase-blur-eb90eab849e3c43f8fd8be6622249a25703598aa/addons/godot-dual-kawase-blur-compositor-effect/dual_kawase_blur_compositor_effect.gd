@tool
extends CompositorEffect
class_name DualKawaseBlurCompositorEffect


const DUAL_KAWASE_DOWN = preload("res://addons/godot-dual-kawase-blur-compositor-effect/compute_shaders/dual_kawase_down.glsl")
const DUAL_KAWASE_UP = preload("res://addons/godot-dual-kawase-blur-compositor-effect/compute_shaders/dual_kawase_up.glsl")


@export_range(1, 7, 1) var layers: int = 2
@export_range(0.0, 40.0, 1e-3) var offset_multiplier: float = 1.0 :
	set(v):
		offset_multiplier = v
		_update_constants()


var _rd: RenderingDevice

var _pipeline_down: RID
var _pipeline_up: RID

var _shader_down: RID
var _shader_up: RID

var _textures: Array[RID]
var _samplers: Array[RID]

var _layers_tmp := -1
var _size_tmp := Vector2i(-1, -1)

var _constants: PackedByteArray

func _update_constants() -> void:
	var push_constant: PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(offset_multiplier)
	push_constant.push_back(offset_multiplier)
	push_constant.push_back(offset_multiplier)
	push_constant.push_back(offset_multiplier)
	_constants = push_constant.to_byte_array()


func _init() -> void:
	_rd = RenderingServer.get_rendering_device()
	
	_shader_down = _rd.shader_create_from_spirv(DUAL_KAWASE_DOWN.get_spirv())
	_shader_up = _rd.shader_create_from_spirv(DUAL_KAWASE_UP.get_spirv())
	
	_pipeline_down = _rd.compute_pipeline_create(_shader_down)
	_pipeline_up = _rd.compute_pipeline_create(_shader_up)
	
	_update_constants()


func _render_callback(effect_callback_type_: int, render_data: RenderData) -> void:
	if _rd and effect_callback_type_ == effect_callback_type:
		var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size := render_scene_buffers.get_internal_size()
			
			if size.x == 0 and size.y == 0:
				return
			
			if layers != _layers_tmp or size != _size_tmp:
				_setup_buffers(size.x, size.y)
			
			@warning_ignore("integer_division")
			var x_groups := _get_compute_groups_count(size.x, 0)
			@warning_ignore("integer_division")
			var y_groups := _get_compute_groups_count(size.y, 0)
			var z_groups := 1
			
			var view_count := render_scene_buffers.get_view_count()
			for view in range(view_count):
				if layers < 1:
					return
				
				var color_image := render_scene_buffers.get_color_layer(view)
				
				var uniform_set_in := _get_uniform_set(color_image, _textures[0], 0, _shader_down)
				
				var compute_list_in := _rd.compute_list_begin()
				_rd.compute_list_bind_compute_pipeline(compute_list_in, _pipeline_down)
				_rd.compute_list_bind_uniform_set(compute_list_in, uniform_set_in, 0)
				_rd.compute_list_set_push_constant(compute_list_in, _constants, _constants.size())
				_rd.compute_list_dispatch(compute_list_in, x_groups, y_groups, z_groups)
				_rd.compute_list_end()
				
				for layer in range(layers - 1):
					var uniform_set := _get_uniform_set(_textures[layer], _textures[layer + 1], layer, _shader_down)
					var compute_list := _rd.compute_list_begin()
					_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline_down)
					_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
					_rd.compute_list_set_push_constant(compute_list, _constants, _constants.size())
					_rd.compute_list_dispatch(
						compute_list,
						_get_compute_groups_count(size.x, layer), 
						_get_compute_groups_count(size.y, layer),
						z_groups)
					_rd.compute_list_end()
				
				for layer in range(layers - 1, 0, -1):
					var uniform_set := _get_uniform_set(_textures[layer], _textures[layer - 1], layer, _shader_up)
					var compute_list := _rd.compute_list_begin()
					_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline_up)
					_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
					_rd.compute_list_set_push_constant(compute_list, _constants, _constants.size())
					_rd.compute_list_dispatch(
						compute_list,
						_get_compute_groups_count(size.x, layer), 
						_get_compute_groups_count(size.y, layer),
						z_groups)
					_rd.compute_list_end()
				
				var uniform_set_out := _get_uniform_set(_textures[0], color_image, 0, _shader_up)
				
				var compute_list_out := _rd.compute_list_begin()
				_rd.compute_list_bind_compute_pipeline(compute_list_out, _pipeline_up)
				_rd.compute_list_bind_uniform_set(compute_list_out, uniform_set_out, 0)
				_rd.compute_list_set_push_constant(compute_list_out, _constants, _constants.size())
				_rd.compute_list_dispatch(compute_list_out, x_groups, y_groups, z_groups)
				_rd.compute_list_end()


func _get_compute_groups_count(fragments: int, shrink: int, local_group_size: int = 32) -> int:
	return (maxi(1, fragments >> shrink) + 1) / local_group_size + 1


func _get_uniform_set(texture_from: RID, texture_to: RID, layer: int, shader: RID) -> RID:
	var uniform_output_image: RDUniform = RDUniform.new()
	uniform_output_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output_image.binding = 0
	uniform_output_image.add_id(texture_to)
	
	var uniform_input_sampler: RDUniform = RDUniform.new()
	uniform_input_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform_input_sampler.binding = 1
	uniform_input_sampler.add_id(_samplers[layer])
	uniform_input_sampler.add_id(texture_from)
	
	return UniformSetCacheRD.get_cache(shader, 0, [
		uniform_input_sampler,
		uniform_output_image,
	])


func _setup_buffers(w: int, h: int) -> void:
	# Free buffers and textures
	for t in _textures: _rd.free_rid(t)
	for s in _samplers: _rd.free_rid(s)
	
	_textures.clear()
	_samplers.clear()
	
	_layers_tmp = layers
	_size_tmp = Vector2i(w, h)
	
	for i in range(layers):
		w = maxi(1, w >> 1)
		h = maxi(1, h >> 1)
		
		var texture_format := _get_texture_format(w, h)
		
		var texture := _rd.texture_create(texture_format, RDTextureView.new())
		_textures.push_back(texture)
	
	
	for i in range(layers):
		var sampler := _create_sampler()
		_samplers.push_back(sampler)


func _get_texture_format(width: int, height: int) -> RDTextureFormat:
	var texture_format := RDTextureFormat.new()
	texture_format.width = width
	texture_format.height = height
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	return texture_format


func _create_sampler() -> RID:
	var sampler_state := RDSamplerState.new()
	return _rd.sampler_create(sampler_state)


func _create_sampler_uniform(sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform

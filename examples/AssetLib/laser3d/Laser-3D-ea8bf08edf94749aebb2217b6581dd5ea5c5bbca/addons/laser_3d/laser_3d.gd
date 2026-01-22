@tool
@icon("res://addons/laser_3d/icon.svg")

## [b]Laser3D[/b][br]
## A ready-to-use 3D laser beam with collision detection.[br]
##[br]
## Laser3D projects a continuous laser in its forward direction and detects
## collisions using physics queries. It automatically adjusts its visual length
## to stop at the first object hit.[br]
##[br]
## This node works both at runtime and inside the editor, providing an instant
## visual preview without running the game.[br]
##[br]
## [b]Typical Use Cases[/b][br]
## - Weapons (lasers, turrets, sci-fi guns)[br]
## - Line-of-sight and visibility checks[br]
## - Traps, sensors and security systems[br]
## - Targeting and aiming helpers[br]
##[br]
## [b]Features[/b][br]
## - Automatic beam resizing based on collision distance[br]
## - Editor preview with live updates[br]
## - Configurable visual appearance (color, radius, emission)[br]
## - Full control over collision layers and filters[br]
## - Optional collision signal with detailed hit information[br]
##[br]
## Laser3D is self-contained and requires no additional scenes or setup.
class_name Laser3D extends Node3D


# --------------------------------------------------------------
# CONSTANTS
# --------------------------------------------------------------
const LASER_ALWAYS_VISIBLE: int = 0
const LASER_VISIBLE_ON_COLLIDE: int = 1
const LASER_VISIBLE_OFF: int = 2


# --------------------------------------------------------------
# PRIVATE PROPERTIES
# --------------------------------------------------------------
var _ray_cast: RayCast3D = RayCast3D.new()
var _mesh_instance: MeshInstance3D = MeshInstance3D.new()
var _cylinder_mesh: CylinderMesh = CylinderMesh.new()
var _cylinder_material: StandardMaterial3D = StandardMaterial3D.new()
var _editor_preview_mesh_instance: MeshInstance3D = MeshInstance3D.new()
var _editor_preview_cylinder_mesh: CylinderMesh = CylinderMesh.new()
var _editor_preview_cylinder_material: StandardMaterial3D = StandardMaterial3D.new()
var _nodes_ready: bool = false
var _preview_nodes_ready: bool = false
var _current_collider: Object:
	set(value):
		if value != _current_collider:
			collider_changed.emit(_current_collider, value)
		_current_collider = value
var _mesh_visible: bool = false:
	set(value):
		if value != _mesh_visible:
			laser_visible_change.emit(value, get_collider())

		_mesh_visible = value
		_mesh_instance.visible = _mesh_visible

enum laser_visible {LASER_ALWAYS_VISIBLE, LASER_VISIBLE_ON_COLLIDE, LASER_VISIBLE_OFF}

# --------------------------------------------------------------
# SIGNALS
# --------------------------------------------------------------
## Emitted when the laser collides with a physics object during runtime.[br][br]
## 3D laser collision result returns:[br][br]
## [code]collider: Object
## collision_point: Vector3
## collision_face_index: int
## collision_normal: Vector3
## collider_rid: RID
## collider_shape: int[/code]
signal collision_detected(collision_result: LaserResult)


## Emitted when the collider is changed. Useful when you need to know if the collider has moved out of the laser beam's focus.
signal collider_changed(old_collider: Object, new_collider: Object)


## Emitted every time the laser beam becomes visible or invisible.
signal laser_visible_change(laser_visible: bool, collider: Object)


# --------------------------------------------------------------
# EXPORTS
# --------------------------------------------------------------
@export_group("Laser/Visual", "laser_")
## Controls when the laser beam is visible.[br]
##[br]
## - Always Visible: Beam is always rendered[br]
## - Visible On Collide: Beam only appears when hitting something[br]
## - Off: Beam is never rendered
@export var laser_type_visible: laser_visible = LASER_ALWAYS_VISIBLE:
	set(value):
		laser_type_visible = value
		_mesh_visible = _visual_handle()


## Offsets the laser forward direction.[br]
## Useful to avoid clipping with the emitter object.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:m") var laser_forward_offset: float = 0.0


## Laser beam color.[br]
## Affects both albedo and emission color.
@export var laser_color: Color = Color.RED:
	set(value):
		laser_color = value
		_cylinder_material.albedo_color = laser_color
		_cylinder_material.emission = laser_color
		_editor_preview_cylinder_material.albedo_color = laser_color
		_editor_preview_cylinder_material.emission = laser_color


## Emission intensity of the laser beam.
@export_range(0.0, 5.0, 0.01, "or_greater") var laser_emission: float = 20.0:
	set(value):
		laser_emission = value
		_cylinder_material.emission_energy_multiplier = laser_emission
		_editor_preview_cylinder_material.emission_energy_multiplier = laser_emission


## Radius of the laser beam.[br]
## Affects both top and bottom radius of the cylinder mesh.
@export_range(0.01, 0.2, 0.0001, "or_greater") var laser_radius: float = 0.01:
	set(value):
		laser_radius = value
		_cylinder_mesh.top_radius = laser_radius
		_cylinder_mesh.bottom_radius = laser_radius
		_editor_preview_cylinder_mesh.top_radius = laser_radius
		_editor_preview_cylinder_mesh.bottom_radius = laser_radius


## Render layers used by the laser mesh.
@export_flags_3d_render() var laser_layers: int = 1:
	set(value):
		laser_layers = value
		_mesh_instance.layers = laser_layers


@export_group("Laser/Physics", "laser_")
## Enables or disables laser behavior.[br]
##[br]
## When disabled:[br]
## - Collision signals are not emitted[br]
## - Visual beam visibility depends on configuration[br]
##[br]
## Note:[br]
## The RayCast remains active to simulate a physical light beam
## that stops at collision points.
@export var laser_active: bool = true:
	set(value):
		laser_active = value

## If true, the laser ignores its parent when detecting collisions.
@export var laser_exclude_parent: bool = true:
	set(value):
		laser_exclude_parent = value
		_ray_cast.exclude_parent = laser_exclude_parent

## If a 3D node is selected, the laser will point to the assigned 3D node; otherwise, it will point forward.
@export var laser_look_at_target: Node3D:
	set(value):
		laser_look_at_target = value
		if not is_inside_tree(): return
		if is_instance_valid(laser_look_at_target):
			look_at(laser_look_at_target.global_position + laser_look_at_position_offset, Vector3.UP)

## Position shift when laser_look_at_target is set.
@export var laser_look_at_position_offset: Vector3 = Vector3.ZERO:
	set(value):
		laser_look_at_position_offset = value
		if not is_inside_tree(): return
		if is_instance_valid(laser_look_at_target):
			look_at(laser_look_at_target.global_position + laser_look_at_position_offset, Vector3.UP)


## Adds a collision exception so the ray does not report collisions with the specified node.
@export var laser_exceptions: Array[CollisionObject3D] = []:
	set(value):
		laser_exceptions = value
		clear_exceptions()
		for ex in laser_exceptions:
			if ex:
				add_exception(ex)
			
## It does not emit the collision_detected signal if the collision is one of the objects listed here.[br]
## Remember: this is only to prevent the signal from being emitted. Methods with get_collider() will still return the collided object.
@export var laser_exclude_from_the_results_report: Array[CollisionObject3D] = []:
	set(value):
		laser_exclude_from_the_results_report = value

## Maximum distance of the laser beam.[br]
## This controls both RayCast length and visual beam size.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:m") var laser_length: float = 2.0:
	set(value):
		laser_length = value
		_ray_cast.target_position.z = - laser_length


## Allows the RayCast to detect collisions from inside shapes.
@export var laser_hit_from_inside: bool = false:
	set(value):
		laser_hit_from_inside = value
		_ray_cast.hit_from_inside = laser_hit_from_inside


## Allows collision detection on back faces.
@export var laser_hit_back_faces: bool = true:
	set(value):
		laser_hit_back_faces = value
		_ray_cast.hit_back_faces = laser_hit_back_faces


## Physics collision mask used by the laser.
@export_flags_3d_physics() var laser_collision_mask: int = 1:
	set(value):
		laser_collision_mask = value
		_ray_cast.collision_mask = laser_collision_mask


@export_group("Laser/Physics/Collide With", "laser_collide_with")
## If true, the laser can collide with Area3D nodes.
@export var laser_collide_with_areas: bool = false:
	set(value):
		laser_collide_with_areas = value
		_ray_cast.collide_with_areas = laser_collide_with_areas


## If true, the laser can collide with PhysicsBody3D nodes.
@export var laser_collide_with_bodies: bool = true:
	set(value):
		laser_collide_with_bodies = value
		_ray_cast.collide_with_bodies = laser_collide_with_bodies


# --------------------------------------------------------------
# ENGINE METHODS
# --------------------------------------------------------------
func _ready() -> void:
	if Engine.is_editor_hint():
		add_child(_editor_preview_mesh_instance)

	add_child(_mesh_instance)
	add_child(_ray_cast)

	_cylinder_material_default_values()
	_cylinder_mesh_default_values()
	_mesh_instance_default_values()
	_raycast_default_values()

	if Engine.is_editor_hint():
		self.owner = owner
		_ray_cast.owner = self


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_runtime()
	else:
		_editor_preview()


# --------------------------------------------------------------
# PUBLIC METHODS
# --------------------------------------------------------------
## Adds a collision exception so the ray does not report collisions with the specified node.
func add_exception(node: CollisionObject3D) -> void:
	_ray_cast.add_exception(node)


## Removes a collision exception so the ray can report collisions with the specified node.
func remove_exception(node: CollisionObject3D) -> void:
	_ray_cast.remove_exception(node)


## Adds a collision exception so the ray does not report collisions with the specified RID.
func add_exception_rid(rid: RID) -> void:
	_ray_cast.add_exception_rid(rid)


## Removes a collision exception so the ray can report collisions with the specified RID.
func remove_exception_rid(rid: RID) -> void:
	_ray_cast.remove_exception_rid(rid)


## Removes all collision exceptions for this ray.
func clear_exceptions() -> void:
	_ray_cast.clear_exceptions()


## Add a 3D Collision Object to the exception list so that it is not reported in the collision_detected signal.
func add_laser_exclude_from_the_results_report(node: CollisionObject3D) -> void:
	if not laser_exclude_from_the_results_report.has(node):
		laser_exclude_from_the_results_report.append(node)


## Remove a 3D Collision Object from the exception list to be reported in the collision_detected signal.
func remove_laser_exclude_from_the_results_report(node: CollisionObject3D) -> void:
	var index := laser_exclude_from_the_results_report.find(node)
	if index != -1:
		laser_exclude_from_the_results_report.remove_at(index)

	
## Returns the first object that the ray intersects, or null if no object is intersecting the ray (i.e. is_colliding returns false). [br]
## Note: This object is not guaranteed to be a CollisionObject3D. [br]
## For example, if the ray intersects a CSGShape3D or a GridMap, the method will return a CSGShape3D or GridMap instance.
func get_collider() -> Object:
	return _ray_cast.get_collider()


## Returns the collision point at which the ray intersects the closest object, in the global coordinate system. [br]
## If hit_from_inside is true and the ray starts inside of a collision shape, this function will return the origin point of the ray. [br]
## Note: Check that is_colliding returns true before calling this method to ensure the returned point is valid and up-to-date.
func get_collision_point() -> Vector3:
	return _ray_cast.get_collision_point()


## Returns the normal of the intersecting object's shape at the collision point, or Vector3(0, 0, 0) if the ray starts inside the shape and hit_from_inside is true. [br]
## Note: Check that is_colliding returns true before calling this method to ensure the returned normal is valid and up-to-date.
func get_collision_normal() -> Vector3:
	return _ray_cast.get_collision_normal()


## Returns the RID of the first object that the ray intersects, or an empty RID if no object is intersecting the ray (i.e. is_colliding returns false).
func get_collider_rid() -> RID:
	return _ray_cast.get_collider_rid()


## Returns the shape ID of the first object that the ray intersects, or 0 if no object is intersecting the ray (i.e. is_colliding returns false).[br]
## To get the intersected shape node, for a CollisionObject3D target, use:[br]
## [code]
## var target = get_collider() # A CollisionObject3D.[br]
## var shape_id = get_collider_shape() # The shape index in the collider.[br]
## var owner_id = target.shape_find_owner(shape_id) # The owner ID in the collider.[br]
## var shape = target.shape_owner_get_owner(owner_id)
## [/code]
func get_collider_shape() -> int:
	return _ray_cast.get_collider_shape()


## Returns the collision object's face index at the collision point, or -1 if the shape intersecting the ray is not a ConcavePolygonShape3D.
func get_collision_face_index() -> int:
	return _ray_cast.get_collision_face_index()


## Returns whether or not the specified layer of the collision_mask is enabled, given a layer_number between 1 and 32.
func get_collision_mask_value(layer_number: int) -> bool:
	return _ray_cast.get_collision_mask_value(layer_number)


## Returns laser is visible.
func is_laser_visible() -> bool:
	return _mesh_visible


## Returns whether any object is intersecting with the ray's vector (considering the vector length).
func is_colliding() -> bool:
	return _ray_cast.is_colliding()


# --------------------------------------------------------------
# PRIVATE METHODS
# --------------------------------------------------------------
func _runtime() -> void:
	if not is_instance_valid(_mesh_instance) or not is_instance_valid(_ray_cast): return
	await _ensure_ready()

	if is_instance_valid(laser_look_at_target):
		look_at(laser_look_at_target.global_position + laser_look_at_position_offset, Vector3.UP)

	var collider: Object = _ray_cast.get_collider()
	var is_colliding: bool = laser_active and _ray_cast.is_colliding() and collider
	
	_current_collider = collider
	
	if is_colliding and not laser_exclude_from_the_results_report.has(collider):
		var collision_result: LaserResult = LaserResult.new(
			collider,
			_ray_cast.get_collision_point(),
			_ray_cast.get_collision_face_index(),
			_ray_cast.get_collision_normal(),
			_ray_cast.get_collider_rid(),
			_ray_cast.get_collider_shape(),
		)

		collision_detected.emit(collision_result)

	_mesh_visible = _visual_handle()


func _editor_preview() -> void:
	await _ensure_preview_ready()

	if is_instance_valid(laser_look_at_target):
		look_at(laser_look_at_target.global_position + laser_look_at_position_offset, Vector3.UP)

	var debug_height: float = - _ray_cast.target_position.z
	_cylinder_mesh.height = debug_height + laser_forward_offset
	_mesh_instance.position.z = (debug_height + laser_forward_offset) / -2
	_mesh_instance.visible = _visual_handle()


func _visual_handle() -> bool:
	var is_colliding: bool = _ray_cast.is_colliding()

	match laser_type_visible:
		LASER_ALWAYS_VISIBLE:
			_cylinder_height(is_colliding and not Engine.is_editor_hint())
			return true
		LASER_VISIBLE_ON_COLLIDE:
			_cylinder_height(is_colliding and not Engine.is_editor_hint())
			return laser_active and is_colliding or Engine.is_editor_hint()
		LASER_VISIBLE_OFF:
			return false
		_:
			return false


func _ensure_preview_ready() -> void:
	if _preview_nodes_ready:
		return

	if not is_inside_tree(): await tree_entered
	if not is_node_ready(): await ready

	if Engine.is_editor_hint():
		if not _editor_preview_mesh_instance.is_inside_tree(): await _editor_preview_mesh_instance.tree_entered
		if not _editor_preview_mesh_instance.is_node_ready(): await _editor_preview_mesh_instance.ready
		
	if not _ray_cast.is_inside_tree(): await _ray_cast.tree_entered
	if not _ray_cast.is_node_ready(): await _ray_cast.ready

	_preview_nodes_ready = true


func _ensure_ready() -> void:
	if _nodes_ready:
		return

	if not is_inside_tree(): await tree_entered
	if not is_node_ready(): await ready

	if not Engine.is_editor_hint():
		if not _mesh_instance.is_inside_tree(): await _mesh_instance.tree_entered
		if not _mesh_instance.is_node_ready(): await _mesh_instance.ready

	if not _ray_cast.is_inside_tree(): await _ray_cast.tree_entered
	if not _ray_cast.is_node_ready(): await _ray_cast.ready

	_nodes_ready = true


func _cylinder_height(is_colliding: bool) -> void:
	await _ensure_preview_ready()
	await _ensure_ready()

	var hit: Vector3 = _ray_cast.get_collision_point()
	var dist: float = global_position.distance_to(hit)
	var height: float = dist if is_colliding else abs(_ray_cast.target_position.z)

	_cylinder_mesh.height = height + laser_forward_offset
	_mesh_instance.position.z = (height + laser_forward_offset) / -2


func _raycast_default_values() -> void:
	await _ensure_preview_ready()
	await _ensure_ready()

	_ray_cast.name = "ray_cast"
	_ray_cast.exclude_parent = laser_exclude_parent
	_ray_cast.target_position = Vector3(0, 0, -laser_length)
	_ray_cast.collision_mask = laser_collision_mask
	_ray_cast.hit_from_inside = laser_hit_from_inside
	_ray_cast.hit_back_faces = laser_hit_back_faces
	_ray_cast.collide_with_bodies = laser_collide_with_bodies
	_ray_cast.collide_with_areas = laser_collide_with_areas
	_ray_cast.debug_shape_custom_color = Color.RED
	_ray_cast.debug_shape_thickness = 1


func _cylinder_mesh_default_values() -> void:
	await _ensure_ready()
	_cylinder_mesh.top_radius = laser_radius
	_cylinder_mesh.bottom_radius = laser_radius
	_cylinder_mesh.height = 0.001
	_cylinder_mesh.material = _cylinder_material

	if Engine.is_editor_hint():
		await _ensure_preview_ready()
		_editor_preview_cylinder_mesh.top_radius = laser_radius
		_editor_preview_cylinder_mesh.bottom_radius = laser_radius
		_editor_preview_cylinder_mesh.height = 0.001
		_editor_preview_cylinder_mesh.material = _editor_preview_cylinder_material


func _mesh_instance_default_values() -> void:
	await _ensure_ready()
	_mesh_instance.name = "mesh_instance"
	_mesh_instance.mesh = _cylinder_mesh
	_mesh_visible = _visual_handle()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mesh_instance.rotation_degrees.x = -90
	_mesh_instance.layers = laser_layers

	if Engine.is_editor_hint():
		await _ensure_preview_ready()
		_editor_preview_mesh_instance.name = "_editor_preview_mesh_instance"
		_editor_preview_mesh_instance.mesh = _editor_preview_cylinder_mesh
		_editor_preview_mesh_instance.visible = _visual_handle()
		_editor_preview_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_editor_preview_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_editor_preview_mesh_instance.rotation_degrees.x = -90
		_editor_preview_mesh_instance.layers = laser_layers


func _cylinder_material_default_values() -> void:
	await _ensure_ready()
	_cylinder_material.albedo_color = laser_color
	_cylinder_material.emission = laser_color
	_cylinder_material.emission_enabled = true
	_cylinder_material.emission_energy_multiplier = laser_emission
	_cylinder_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	if Engine.is_editor_hint():
		await _ensure_preview_ready()
		_editor_preview_cylinder_material.albedo_color = laser_color
		_editor_preview_cylinder_material.emission = laser_color
		_editor_preview_cylinder_material.emission_enabled = true
		_editor_preview_cylinder_material.emission_energy_multiplier = laser_emission
		_editor_preview_cylinder_material.cull_mode = BaseMaterial3D.CULL_DISABLED

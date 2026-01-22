## 3D laser collision result.[br]
## [code]
## collider: Object
## collision_point: Vector3
## collision_face_index: int
## collision_normal: Vector3
## collider_rid: RID
## collider_shape: int[/code]
class_name LaserResult extends RefCounted


var collider: Object
var collision_point: Vector3
var collision_face_index: int
var collision_normal: Vector3
var collider_rid: RID
var collider_shape: int


func _init(_collider: Object, _collision_point: Vector3, _collision_face_index: int, _collision_normal: Vector3, _collider_rid: RID, _collider_shape: int) -> void:
	collider = _collider
	collision_point = _collision_point
	collision_face_index = _collision_face_index
	collision_normal = _collision_normal
	collider_rid = _collider_rid
	collider_shape = _collider_shape

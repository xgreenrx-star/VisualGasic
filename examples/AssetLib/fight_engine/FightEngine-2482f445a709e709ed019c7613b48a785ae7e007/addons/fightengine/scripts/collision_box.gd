@tool
@abstract
class_name CollisionBox2D
extends Area2D

signal collision(collider: CollisionBox2D)

@export var is_active: bool = true

@export var shape: Shape2D:
	set(value):
		shape = value
		_update_collision_shape()

@onready var collision_shape: CollisionShape2D = CollisionShape2D.new()

func _init() -> void:
	area_entered.connect(_on_area_entered)

func _ready() -> void:
	add_child(collision_shape)
	
	if collision_shape.get_children() == null:
		if Engine.is_editor_hint():
			collision_shape.owner = get_tree().edited_scene_root
	
	_update_collision_shape()

func _update_collision_shape() -> void:
	if not is_instance_valid(collision_shape):
		return
	
	collision_shape.shape = shape

func _on_area_entered(area: Area2D) -> void:
	if area is not CollisionBox2D:
		return
	var box = area as CollisionBox2D
	if not box.is_active or not is_active: return
	collision.emit(box)

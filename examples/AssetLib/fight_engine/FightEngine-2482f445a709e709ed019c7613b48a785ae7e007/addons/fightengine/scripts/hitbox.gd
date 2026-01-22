@tool
class_name HitBox2D
extends CollisionBox2D

signal hit(hurtbox: HurtBox2D)

@export var damage: int = 0
@export var stun: int = 0

func _init() -> void:
	super._init()
	collision.connect(_on_collision)

func _ready() -> void:
	super._ready()
	collision_shape.debug_color = Color(1, 0, 0, 0.8)

func _on_collision(collider: CollisionBox2D) -> void:
	if collider is not HurtBox2D:
		return
	
	var box = collider as HurtBox2D
	hit.emit(box)

@tool
class_name HurtBox2D
extends CollisionBox2D

signal was_hit(hitbox: HitBox2D)

func _init() -> void:
	super._init()
	collision.connect(_on_collision)

func _ready() -> void:
	super._ready()
	collision_shape.debug_color = Color(0, 1, 0, 0.8)

func _on_collision(collision_box: CollisionBox2D) -> void:
	if collision_box is not HitBox2D:
		return
	
	var box = collision_box as HitBox2D
	was_hit.emit(box)

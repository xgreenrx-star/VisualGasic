extends LimboState

@export var anim_player: AnimationPlayer
@export var anim_name: StringName
@export var walk_speed: float = 100.0

var input_vector: Vector2 = Vector2(Input.get_axis("left","right"), Input.get_axis("down", "up"))

func _enter() -> void:
	anim_player.play("moves/"+anim_name)

func _update(delta: float) -> void:
	input_vector = Vector2(Input.get_axis("left","right"), Input.get_axis("down", "up"))
	if input_vector.x != 0:
		agent.velocity.x = walk_speed * input_vector.x * delta
	else:
		agent.velocity.x = 0
		dispatch(EVENT_FINISHED)

func _exit() -> void:
	pass
